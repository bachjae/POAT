/// Deep post-session analytics — pure function of the per-shot scores.
///
/// Computed once in `SessionOrchestrator.end()`, persisted as JSON on the
/// session row, and consumed by the summary screen, the Coach Brain chat
/// grounding, and the Lite coach. Like [generateSessionSummary] this layer
/// is deterministic and LLM-free: every number here is measured, so both
/// coach tiers can quote it without inventing anything.
library;

import 'dart:math' as math;

import 'summary_generator.dart';

/// Display labels for swing phases (reference-library ids + 'timing').
const Map<String, String> phaseLabels = {
  'preparation': 'Preparation',
  'backswing': 'Backswing',
  'contact': 'Contact',
  'follow_through': 'Follow-through',
  'timing': 'Timing',
  'window': 'Movement',
};

/// Per-stroke aggregate over the session.
class StrokeInsight {
  const StrokeInsight({
    required this.count,
    required this.avgScore,
    required this.bestScore,
    required this.worstScore,
  });

  factory StrokeInsight.fromJson(Map<String, dynamic> json) => StrokeInsight(
        count: json['count'] as int,
        avgScore: (json['avg'] as num).toDouble(),
        bestScore: (json['best'] as num).toDouble(),
        worstScore: (json['worst'] as num).toDouble(),
      );

  final int count;
  final double avgScore;
  final double bestScore;
  final double worstScore;

  Map<String, dynamic> toJson() => {
        'count': count,
        'avg': avgScore,
        'best': bestScore,
        'worst': worstScore,
      };
}

/// How one metric behaved across the whole session.
class MetricInsight {
  const MetricInsight({
    required this.id,
    required this.deviatedCount,
    required this.inRangeRate,
    required this.dominantDirection,
    required this.firstHalfRate,
    required this.secondHalfRate,
  });

  factory MetricInsight.fromJson(Map<String, dynamic> json) => MetricInsight(
        id: json['id'] as String,
        deviatedCount: json['deviated'] as int,
        inRangeRate: (json['in_range'] as num).toDouble(),
        dominantDirection: json['direction'] as String,
        firstHalfRate: (json['h1'] as num).toDouble(),
        secondHalfRate: (json['h2'] as num).toDouble(),
      );

  final String id;
  final int deviatedCount;

  /// Fraction of shots where this metric stayed in the ideal band (0–1).
  final double inRangeRate;

  /// 'low' or 'high' — whichever side the player missed on more often.
  final String dominantDirection;

  /// Deviation rate in the first half of the session (0–1).
  final double firstHalfRate;

  /// Deviation rate in the second half of the session (0–1).
  final double secondHalfRate;

  /// 'improving' when the deviation rate dropped through the session,
  /// 'worsening' when it climbed, otherwise 'steady'.
  String get trend {
    final diff = secondHalfRate - firstHalfRate;
    if (diff <= -0.15) return 'improving';
    if (diff >= 0.15) return 'worsening';
    return 'steady';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviated': deviatedCount,
        'in_range': _round3(inRangeRate),
        'direction': dominantDirection,
        'h1': _round3(firstHalfRate),
        'h2': _round3(secondHalfRate),
        'trend': trend,
      };
}

/// Outcome of the session goal/focus metric, when one was set.
class FocusOutcome {
  const FocusOutcome({
    required this.metricId,
    required this.firstHalfRate,
    required this.secondHalfRate,
  });

  factory FocusOutcome.fromJson(Map<String, dynamic> json) => FocusOutcome(
        metricId: json['metric'] as String,
        firstHalfRate: (json['h1'] as num).toDouble(),
        secondHalfRate: (json['h2'] as num).toDouble(),
      );

  final String metricId;
  final double firstHalfRate;
  final double secondHalfRate;

  bool get improved => secondHalfRate < firstHalfRate - 0.05;

  Map<String, dynamic> toJson() => {
        'metric': metricId,
        'h1': _round3(firstHalfRate),
        'h2': _round3(secondHalfRate),
        'improved': improved,
      };
}

class SessionInsights {
  const SessionInsights({
    required this.strokes,
    required this.phaseAverages,
    required this.metrics,
    required this.timeline,
    required this.consistency,
    required this.bestCleanStreak,
    required this.bestShotIndex,
    required this.bestShotScore,
    required this.bestShotOffsetMs,
    this.focus,
  });

  factory SessionInsights.fromJson(Map<String, dynamic> json) =>
      SessionInsights(
        strokes: {
          for (final e in (json['strokes'] as Map<String, dynamic>).entries)
            e.key: StrokeInsight.fromJson(e.value as Map<String, dynamic>),
        },
        phaseAverages: {
          for (final e in (json['phases'] as Map<String, dynamic>).entries)
            e.key: (e.value as num).toDouble(),
        },
        metrics: [
          for (final m in json['metrics'] as List)
            MetricInsight.fromJson(m as Map<String, dynamic>),
        ],
        timeline: [
          for (final t in json['timeline'] as List) (t as num).toDouble(),
        ],
        consistency: (json['consistency'] as num).toDouble(),
        bestCleanStreak: json['best_streak'] as int,
        bestShotIndex: json['best_shot_index'] as int,
        bestShotScore: (json['best_shot_score'] as num).toDouble(),
        bestShotOffsetMs: json['best_shot_offset_ms'] as int,
        focus: json['focus'] == null
            ? null
            : FocusOutcome.fromJson(json['focus'] as Map<String, dynamic>),
      );

  /// Stroke id → aggregate. Single-stroke sessions have one entry.
  final Map<String, StrokeInsight> strokes;

  /// Phase id → mean phase score over all shots that scored that phase.
  final Map<String, double> phaseAverages;

  /// Every metric that deviated at least once, worst in-range rate first.
  final List<MetricInsight> metrics;

  /// Mean score per session segment (up to 6 equal buckets, in time order).
  final List<double> timeline;

  /// 0–100: how tightly grouped the shot scores were (100 = identical).
  final double consistency;

  /// Longest run of consecutive shots with no deviations at all.
  final int bestCleanStreak;

  /// Index (0-based) / score / time offset of the highest-scoring shot;
  /// index is -1 when the session had no shots.
  final int bestShotIndex;
  final double bestShotScore;
  final int bestShotOffsetMs;

  /// Present when the session had a goal metric.
  final FocusOutcome? focus;

  /// Weakest phase by average score, or null when nothing was scored.
  String? get weakestPhase => _extremePhase((a, b) => a < b);

  /// Strongest phase by average score, or null when nothing was scored.
  String? get strongestPhase => _extremePhase((a, b) => a > b);

  String? _extremePhase(bool Function(double, double) wins) {
    String? best;
    double? bestV;
    // Sorted keys so ties resolve deterministically.
    for (final id in phaseAverages.keys.toList()..sort()) {
      final v = phaseAverages[id]!;
      if (bestV == null || wins(v, bestV)) {
        bestV = v;
        best = id;
      }
    }
    return best;
  }

  Map<String, dynamic> toJson() => {
        'strokes': {for (final e in strokes.entries) e.key: e.value.toJson()},
        'phases': {
          for (final e in phaseAverages.entries) e.key: _round3(e.value),
        },
        'metrics': [for (final m in metrics) m.toJson()],
        'timeline': [for (final t in timeline) _round3(t)],
        'consistency': _round3(consistency),
        'best_streak': bestCleanStreak,
        'best_shot_index': bestShotIndex,
        'best_shot_score': _round3(bestShotScore),
        'best_shot_offset_ms': bestShotOffsetMs,
        'focus': focus?.toJson(),
      };
}

double _round3(double v) => (v * 1000).roundToDouble() / 1000;

/// Computes the full insight set for a finished session.
SessionInsights computeSessionInsights({
  required List<SummaryShot> shots,
  String? goalMetricId,
}) {
  final total = shots.length;

  // Per-stroke aggregates.
  final strokeScores = <String, List<double>>{};
  for (final s in shots) {
    strokeScores.putIfAbsent(s.stroke.id, () => []).add(s.score.score);
  }
  final strokes = <String, StrokeInsight>{
    for (final e in strokeScores.entries)
      e.key: StrokeInsight(
        count: e.value.length,
        avgScore: _mean(e.value),
        bestScore: e.value.reduce(math.max),
        worstScore: e.value.reduce(math.min),
      ),
  };

  // Phase averages over the shots that scored each phase.
  final phaseSums = <String, double>{};
  final phaseCounts = <String, int>{};
  for (final s in shots) {
    for (final e in s.score.phaseScores.entries) {
      phaseSums[e.key] = (phaseSums[e.key] ?? 0) + e.value;
      phaseCounts[e.key] = (phaseCounts[e.key] ?? 0) + 1;
    }
  }
  final phaseAverages = <String, double>{
    for (final e in phaseSums.entries) e.key: e.value / phaseCounts[e.key]!,
  };

  // Per-metric deviation behavior, split into session halves for the trend.
  final half = total ~/ 2;
  final deviated = <String, int>{};
  final firstHalfDeviated = <String, int>{};
  final secondHalfDeviated = <String, int>{};
  final lowCount = <String, int>{};
  for (var i = 0; i < total; i++) {
    final ids = {for (final d in shots[i].score.deviations) d.id};
    for (final d in shots[i].score.deviations) {
      if (d.direction == 'low') lowCount[d.id] = (lowCount[d.id] ?? 0) + 1;
    }
    for (final id in ids) {
      deviated[id] = (deviated[id] ?? 0) + 1;
      if (i < half) {
        firstHalfDeviated[id] = (firstHalfDeviated[id] ?? 0) + 1;
      } else {
        secondHalfDeviated[id] = (secondHalfDeviated[id] ?? 0) + 1;
      }
    }
  }
  final secondHalfLen = total - half;
  final metrics = [
    for (final id in deviated.keys.toList()..sort())
      MetricInsight(
        id: id,
        deviatedCount: deviated[id]!,
        inRangeRate: 1 - deviated[id]! / total,
        dominantDirection:
            (lowCount[id] ?? 0) * 2 >= deviated[id]! ? 'low' : 'high',
        firstHalfRate: half == 0 ? 0 : (firstHalfDeviated[id] ?? 0) / half,
        secondHalfRate: secondHalfLen == 0
            ? 0
            : (secondHalfDeviated[id] ?? 0) / secondHalfLen,
      ),
  ]..sort((a, b) {
      final byRate = a.inRangeRate.compareTo(b.inRangeRate);
      return byRate != 0 ? byRate : a.id.compareTo(b.id);
    });

  // Score timeline in up to 6 equal segments.
  final segments = math.min(6, total);
  final timeline = <double>[];
  for (var seg = 0; seg < segments; seg++) {
    final start = (seg * total / segments).floor();
    final end = ((seg + 1) * total / segments).floor();
    timeline.add(_mean([
      for (var i = start; i < math.max(end, start + 1); i++)
        shots[i].score.score,
    ]));
  }

  // Consistency from the score standard deviation.
  final allScores = [for (final s in shots) s.score.score];
  var consistency = 0.0;
  if (total > 0) {
    final m = _mean(allScores);
    final variance =
        _mean([for (final v in allScores) (v - m) * (v - m)]);
    consistency = (100 - 2 * math.sqrt(variance)).clamp(0.0, 100.0);
  }

  // Longest clean streak + best shot.
  var bestStreak = 0;
  var run = 0;
  var bestIdx = -1;
  var bestScore = 0.0;
  for (var i = 0; i < total; i++) {
    if (shots[i].score.deviations.isEmpty) {
      run++;
      if (run > bestStreak) bestStreak = run;
    } else {
      run = 0;
    }
    if (bestIdx < 0 || shots[i].score.score > bestScore) {
      bestIdx = i;
      bestScore = shots[i].score.score;
    }
  }

  FocusOutcome? focus;
  if (goalMetricId != null && total > 0) {
    focus = FocusOutcome(
      metricId: goalMetricId,
      firstHalfRate:
          half == 0 ? 0 : (firstHalfDeviated[goalMetricId] ?? 0) / half,
      secondHalfRate: secondHalfLen == 0
          ? 0
          : (secondHalfDeviated[goalMetricId] ?? 0) / secondHalfLen,
    );
  }

  return SessionInsights(
    strokes: strokes,
    phaseAverages: phaseAverages,
    metrics: metrics,
    timeline: timeline,
    consistency: consistency,
    bestCleanStreak: bestStreak,
    bestShotIndex: bestIdx,
    bestShotScore: bestIdx < 0 ? 0 : bestScore,
    bestShotOffsetMs: bestIdx < 0 ? 0 : shots[bestIdx].tOffsetMs,
    focus: focus,
  );
}

double _mean(List<double> xs) =>
    xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
