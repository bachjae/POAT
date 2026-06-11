/// Rule-based session summary (SPEC §12).
///
/// Pure function of the per-shot scores — no LLM, no I/O. The Coach Brain
/// later rewrites these facts in the coach's voice; this layer guarantees a
/// correct summary even if the language model is unavailable.
library;

import 'dart:convert';

import '../engine/engine_types.dart';

/// One scored shot as fed to the summary generator.
typedef SummaryShot = ({Stroke stroke, ShotScore score, int tOffsetMs});

/// Display labels for every metric id in the reference library.
const Map<String, String> metricLabels = {
  'shoulder_turn': 'Shoulder turn',
  'knee_flexion': 'Knee bend',
  'trunk_tilt': 'Balanced posture',
  'elbow_angle': 'Arm shape',
  'hip_shoulder_sep': 'Hip-shoulder coil',
  'contact_in_front': 'Contact out in front',
  'contact_height': 'Contact height',
  'wrist_finish_height': 'High finish',
  'prep_before_contact_ms': 'Early preparation',
  'split_step_rate': 'Split step',
  'stance_width': 'Wide base',
  'recovery_steps': 'Recovery footwork',
};

/// Short titles used for improvement items.
const Map<String, String> _improvementTitles = {
  'shoulder_turn': 'Shoulder turn timing',
  'knee_flexion': 'Knee bend',
  'trunk_tilt': 'Body balance',
  'elbow_angle': 'Arm extension',
  'hip_shoulder_sep': 'Hip-shoulder coil',
  'contact_in_front': 'Contact point',
  'contact_height': 'Contact height',
  'wrist_finish_height': 'Follow-through height',
  'prep_before_contact_ms': 'Preparation timing',
  'split_step_rate': 'Split step habit',
  'stance_width': 'Stance width',
  'recovery_steps': 'Recovery footwork',
};

/// Direction word per metric: (below ideal band, above ideal band).
const Map<String, (String, String)> _directionWords = {
  'shoulder_turn': ('late', 'over-rotated'),
  'knee_flexion': ('cramped', 'too upright'),
  'trunk_tilt': ('leaning back', 'leaning over'),
  'elbow_angle': ('cramped', 'overextended'),
  'hip_shoulder_sep': ('under-coiled', 'over-coiled'),
  'contact_in_front': ('late', 'too early'),
  'contact_height': ('low', 'overreaching'),
  'wrist_finish_height': ('low', 'high'),
  'prep_before_contact_ms': ('late', 'rushed'),
  'split_step_rate': ('missed', 'mistimed'),
  'stance_width': ('narrow', 'wide'),
  'recovery_steps': ('short', 'overrun'),
};

class Drill {
  const Drill({
    required this.id,
    required this.title,
    required this.minutes,
    required this.description,
    required this.fixes,
  });

  factory Drill.fromJson(Map<String, dynamic> json) => Drill(
        id: json['id'] as String,
        title: json['title'] as String,
        minutes: json['minutes'] as int,
        description: json['description'] as String,
        fixes: [for (final f in json['fixes'] as List) f as String],
      );

  final String id;
  final String title;
  final int minutes;
  final String description;

  /// Deviation ids this drill addresses.
  final List<String> fixes;
}

/// The static drill table bundled at `assets/drills.json`.
class DrillCatalog {
  const DrillCatalog(this.drills);

  factory DrillCatalog.fromJsonString(String json) {
    final root = jsonDecode(json) as Map<String, dynamic>;
    return DrillCatalog([
      for (final d in root['drills'] as List)
        Drill.fromJson(d as Map<String, dynamic>),
    ]);
  }

  final List<Drill> drills;

  /// Drills whose `fixes` match any of [ids], in [ids] order, deduped.
  List<Drill> forDeviations(List<String> ids) {
    final out = <Drill>[];
    final seen = <String>{};
    for (final id in ids) {
      for (final drill in drills) {
        if (drill.fixes.contains(id) && seen.add(drill.id)) out.add(drill);
      }
    }
    return out;
  }
}

class SessionSummaryData {
  const SessionSummaryData({
    required this.overallScore,
    required this.strengths,
    required this.improvements,
    required this.drillIds,
    required this.scoreTrendDescription,
  });

  /// Mean of shot scores; 0 if the session had no shots.
  final double overallScore;

  /// Up to 3 "what worked" strings, e.g. 'Contact out in front 81%'.
  final List<String> strengths;

  /// Up to 3 issues by summed severity × weight, worst first.
  final List<({String title, String detail, String deviationId})> improvements;

  /// Up to 2 drill ids matching the top improvements, in improvement order.
  final List<String> drillIds;

  /// 'improving through the session', 'steady', or
  /// 'fading late in the session'.
  final String scoreTrendDescription;
}

/// Builds the deterministic summary for a finished session.
/// [type] is a stroke id or 'full'; [durationS] is the session length.
SessionSummaryData generateSessionSummary({
  required List<SummaryShot> shots,
  required String type,
  required int durationS,
  required DrillCatalog catalog,
}) {
  final total = shots.length;
  final overall = total == 0
      ? 0.0
      : shots.fold(0.0, (a, s) => a + s.score.score) / total;

  // Per metric: which shots deviated, summed severity × weight, and the
  // low/high direction tally.
  final deviatedShots = <String, Set<int>>{};
  final issueWeight = <String, double>{};
  final lowCount = <String, int>{};
  final highCount = <String, int>{};
  for (var i = 0; i < total; i++) {
    for (final d in shots[i].score.deviations) {
      deviatedShots.putIfAbsent(d.id, () => {}).add(i);
      issueWeight[d.id] = (issueWeight[d.id] ?? 0) + d.severity * d.weight;
      if (d.direction == 'low') {
        lowCount[d.id] = (lowCount[d.id] ?? 0) + 1;
      } else {
        highCount[d.id] = (highCount[d.id] ?? 0) + 1;
      }
    }
  }

  // Strengths: highest in-range rate, at least 60% consistent.
  final rates = <String, double>{
    for (final e in deviatedShots.entries)
      e.key: 1 - e.value.length / total,
  };
  final strengthIds = rates.keys.toList()
    ..sort((a, b) {
      final byRate = rates[b]!.compareTo(rates[a]!);
      return byRate != 0 ? byRate : a.compareTo(b);
    });
  final strengths = [
    for (final id in strengthIds)
      if (rates[id]! >= 0.6)
        '${metricLabels[id] ?? id} ${(rates[id]! * 100).round()}%',
  ].take(3).toList();

  // Improvements: worst summed severity × weight first.
  final issueIds = issueWeight.keys.toList()
    ..sort((a, b) {
      final byWeight = issueWeight[b]!.compareTo(issueWeight[a]!);
      return byWeight != 0 ? byWeight : a.compareTo(b);
    });
  final improvements = [
    for (final id in issueIds.take(3))
      (
        title: _improvementTitles[id] ?? id,
        detail: _detailFor(id, deviatedShots[id]!.length, total,
            (lowCount[id] ?? 0) >= (highCount[id] ?? 0)),
        deviationId: id,
      ),
  ];

  final drillIds = catalog
      .forDeviations([for (final i in improvements) i.deviationId])
      .take(2)
      .map((d) => d.id)
      .toList();

  return SessionSummaryData(
    overallScore: overall,
    strengths: strengths,
    improvements: improvements,
    drillIds: drillIds,
    scoreTrendDescription: _trendDescription(shots),
  );
}

String _detailFor(String id, int deviated, int total, bool majorityLow) {
  final words = _directionWords[id] ?? ('low', 'high');
  final word = majorityLow ? words.$1 : words.$2;
  return '$word on $deviated of $total shots';
}

/// Compares mean score of the first half of shots vs the second half;
/// a gap over 4 points either way is called out.
String _trendDescription(List<SummaryShot> shots) {
  final half = shots.length ~/ 2;
  if (half == 0) return 'steady';
  final first = shots.sublist(0, half);
  final second = shots.sublist(half);
  double mean(List<SummaryShot> xs) =>
      xs.fold(0.0, (a, s) => a + s.score.score) / xs.length;
  final diff = mean(second) - mean(first);
  if (diff > 4) return 'improving through the session';
  if (diff < -4) return 'fading late in the session';
  return 'steady';
}
