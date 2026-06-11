/// Technique scoring against the bundled reference library (SPEC §7).
///
/// Port of `python_lab/engine_math.py` — keep in lockstep.
library;

import 'engine_types.dart';
import 'normalizer.dart';
import 'shot_detector.dart';

class ReferenceMetric {
  const ReferenceMetric({
    required this.id,
    required this.ideal,
    required this.weight,
    required this.views,
    required this.cueLow,
    required this.cueHigh,
    this.tolerance,
  });

  factory ReferenceMetric.fromJson(Map<String, dynamic> json) =>
      ReferenceMetric(
        id: json['id'] as String,
        ideal: [for (final v in json['ideal'] as List) (v as num).toDouble()],
        weight: (json['weight'] as num).toDouble(),
        views: [for (final v in json['views'] as List) v as String],
        cueLow: json['cue_low'] as String,
        cueHigh: json['cue_high'] as String,
        tolerance: (json['tolerance'] as num?)?.toDouble(),
      );

  final String id;
  final List<double> ideal;
  final double weight;
  final List<String> views;
  final String cueLow;
  final String cueHigh;
  final double? tolerance;
}

/// One skill tier of a stroke reference: phases → metrics, plus timing.
class StrokeReference {
  const StrokeReference({required this.phases, required this.timing});

  factory StrokeReference.fromJson(Map<String, dynamic> json) =>
      StrokeReference(
        phases: {
          for (final e in (json['phases'] as Map<String, dynamic>).entries)
            e.key: [
              for (final m in (e.value as Map<String, dynamic>)['metrics'] as List)
                ReferenceMetric.fromJson(m as Map<String, dynamic>),
            ],
        },
        timing: {
          for (final e in (json['timing'] as Map<String, dynamic>? ?? {}).entries)
            e.key: [for (final v in e.value as List) (v as num).toDouble()],
        },
      );

  final Map<String, List<ReferenceMetric>> phases;
  final Map<String, List<double>> timing;
}

/// Measured values per phase. Preparation-phase quality is the LOADED
/// position, so its metrics are measured at the backswing frame; the prep
/// onset index feeds timing only.
Map<String, Map<String, double>> measureMetrics(
  List<TimedKeypoints> frames,
  ShotPhases phases,
  JointAngles addressAngles,
) {
  final bwA = jointAngles(frames[phases.backswing].keypoints);
  final prepA = bwA;
  final ctA = jointAngles(frames[phases.contact].keypoints);
  final ftA = jointAngles(frames[phases.followEnd].keypoints);

  double turn(JointAngles a) =>
      wrapDeg(a.shoulderLineDeg - addressAngles.shoulderLineDeg).abs();
  double hipTurn(JointAngles a) =>
      wrapDeg(a.hipLineDeg - addressAngles.hipLineDeg).abs();

  final prepMs = frames[phases.contact].timestampMs -
      frames[phases.prep].timestampMs;

  return {
    'preparation': {
      'shoulder_turn': turn(prepA),
      'knee_flexion': prepA.kneeFlexion,
      'trunk_tilt': prepA.trunkTilt,
    },
    'backswing': {
      'elbow_angle': bwA.elbowAngle,
      'hip_shoulder_sep': (turn(bwA) - hipTurn(bwA)).abs(),
      'shoulder_turn': turn(bwA),
    },
    'contact': {
      'elbow_angle': ctA.elbowAngle,
      'contact_in_front': ctA.wristX,
      'knee_flexion': ctA.kneeFlexion,
      'contact_height': ctA.wristHeight,
    },
    'follow_through': {
      'wrist_finish_height': ftA.wristHeight,
      'trunk_tilt': ftA.trunkTilt,
    },
    'timing': {'prep_before_contact_ms': prepMs.toDouble()},
  };
}

/// 100 inside [lo, hi]; linear falloff to 0 at `tolerance` beyond the edge
/// (default tolerance = range width).
double scoreMetric(double value, List<double> ideal, [double? tolerance]) {
  final lo = ideal[0], hi = ideal[1];
  var tol = tolerance ?? (hi - lo);
  if (tol <= 0) tol = 1.0;
  if (lo <= value && value <= hi) return 100.0;
  final dev = value < lo ? lo - value : value - hi;
  final s = 100.0 - (dev / tol) * 100.0;
  return s < 0.0 ? 0.0 : s;
}

bool viewAllowed(ViewBucket view, List<String> views) {
  for (final v in views) {
    if (v == view.id) return true;
    if (v == 'diagonal_*' && view.isDiagonal) return true;
    if (v == 'side_*' && view.isSide) return true;
  }
  return false;
}

/// Weighted phase scores → 0–100 shot score + deviation list for cues.
/// Metrics whose views don't include the current view are skipped (SPEC §5).
ShotScore scoreShot(
  Map<String, Map<String, double>> measured,
  StrokeReference reference,
  ViewBucket view,
) {
  final phaseScores = <String, double>{};
  final deviations = <MetricDeviation>[];
  var totalW = 0.0, totalWs = 0.0;
  for (final entry in reference.phases.entries) {
    final phase = entry.key;
    var pW = 0.0, pWs = 0.0;
    for (final metric in entry.value) {
      if (!viewAllowed(view, metric.views)) continue;
      final phaseMeasured = measured[phase];
      if (phaseMeasured == null) continue;
      final value = phaseMeasured[metric.id];
      if (value == null) continue;
      final sc = scoreMetric(value, metric.ideal, metric.tolerance);
      pW += metric.weight;
      pWs += metric.weight * sc;
      if (sc < 100.0) {
        final direction = value < metric.ideal[0] ? 'low' : 'high';
        deviations.add(MetricDeviation(
          phase: phase,
          id: metric.id,
          value: value,
          ideal: metric.ideal,
          direction: direction,
          severity: (100.0 - sc) / 100.0,
          weight: metric.weight,
          cue: direction == 'low' ? metric.cueLow : metric.cueHigh,
        ));
      }
    }
    if (pW > 0) {
      phaseScores[phase] = pWs / pW;
      totalW += pW;
      totalWs += pWs;
    }
  }
  final timingIdeal = reference.timing['prep_before_contact_ms'];
  final timingMeasured = measured['timing']?['prep_before_contact_ms'];
  if (timingIdeal != null && timingMeasured != null) {
    final sc = scoreMetric(timingMeasured, timingIdeal);
    phaseScores['timing'] = sc;
    totalW += 0.5;
    totalWs += 0.5 * sc;
    if (sc < 100.0) {
      deviations.add(MetricDeviation(
        phase: 'timing',
        id: 'prep_before_contact_ms',
        value: timingMeasured,
        ideal: timingIdeal,
        direction: timingMeasured < timingIdeal[0] ? 'low' : 'high',
        severity: (100.0 - sc) / 100.0,
        weight: 0.5,
        cue: timingMeasured < timingIdeal[0]
            ? 'start the preparation earlier'
            : "don't rush — let the swing breathe",
      ));
    }
  }
  final score = totalW > 0 ? totalWs / totalW : 0.0;
  // Stable sort by impact, descending (Python's sort is stable; Dart's is
  // not, so tie-break on original index to keep parity).
  final indexed = deviations.asMap().entries.toList();
  indexed.sort((a, b) {
    final cmp = (b.value.severity * b.value.weight)
        .compareTo(a.value.severity * a.value.weight);
    return cmp != 0 ? cmp : a.key.compareTo(b.key);
  });
  return ShotScore(
    score: score,
    phaseScores: phaseScores,
    deviations: [for (final e in indexed) e.value],
  );
}
