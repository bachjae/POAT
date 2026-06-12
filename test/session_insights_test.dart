import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:rallycoach/core/engine/engine_types.dart';
import 'package:rallycoach/core/session/session_insights.dart';
import 'package:rallycoach/core/session/summary_generator.dart';

MetricDeviation dev(
  String id, {
  String direction = 'low',
  double severity = 0.5,
  double weight = 0.3,
  String phase = 'contact',
}) =>
    MetricDeviation(
      phase: phase,
      id: id,
      value: 0,
      ideal: const [0, 1],
      direction: direction,
      severity: severity,
      weight: weight,
      cue: '',
    );

SummaryShot mkShot(
  double score, {
  Stroke stroke = Stroke.forehand,
  List<MetricDeviation> deviations = const [],
  Map<String, double> phaseScores = const {},
  int tOffsetMs = 0,
}) =>
    (
      stroke: stroke,
      score: ShotScore(
          score: score, phaseScores: phaseScores, deviations: deviations),
      tOffsetMs: tOffsetMs,
    );

void main() {
  // 12 shots: forehands improving 50→72, two backhands at 40/60.
  // shoulder_turn deviates on the first 6 (improving), elbow_angle on the
  // last 4 (worsening). Shots 7-9 (indices 6..8) are clean.
  List<SummaryShot> fabricate() => [
        for (var i = 0; i < 10; i++)
          mkShot(
            50.0 + 2 * i + (i >= 5 ? 4 : 0),
            deviations: [
              if (i < 6) dev('shoulder_turn', phase: 'preparation'),
              if (i >= 9) dev('elbow_angle', direction: 'high'),
            ],
            phaseScores: {
              'preparation': 80,
              'contact': 60.0 + i,
            },
            tOffsetMs: i * 30000,
          ),
        mkShot(40,
            stroke: Stroke.backhand,
            deviations: [dev('elbow_angle', direction: 'high')],
            tOffsetMs: 300000),
        mkShot(60, stroke: Stroke.backhand, tOffsetMs: 330000),
      ];

  test('per-stroke aggregates count, average and extremes', () {
    final i = computeSessionInsights(shots: fabricate());
    expect(i.strokes.keys, containsAll(['forehand', 'backhand']));
    final fh = i.strokes['forehand']!;
    expect(fh.count, 10);
    expect(fh.bestScore, 72);
    expect(fh.worstScore, 50);
    final bh = i.strokes['backhand']!;
    expect(bh.count, 2);
    expect(bh.avgScore, closeTo(50, 1e-9));
  });

  test('phase averages and weakest/strongest phase', () {
    final i = computeSessionInsights(shots: fabricate());
    expect(i.phaseAverages['preparation'], closeTo(80, 1e-9));
    expect(i.phaseAverages['contact'], closeTo(64.5, 1e-9));
    expect(i.weakestPhase, 'contact');
    expect(i.strongestPhase, 'preparation');
  });

  test('metric insights track rate, direction and half-session trend', () {
    final i = computeSessionInsights(shots: fabricate());
    final shoulder = i.metrics.firstWhere((m) => m.id == 'shoulder_turn');
    expect(shoulder.deviatedCount, 6);
    expect(shoulder.inRangeRate, closeTo(0.5, 1e-9));
    expect(shoulder.dominantDirection, 'low');
    // All 6 misses are in the first half of 12 shots.
    expect(shoulder.firstHalfRate, closeTo(1.0, 1e-9));
    expect(shoulder.secondHalfRate, closeTo(0.0, 1e-9));
    expect(shoulder.trend, 'improving');

    final elbow = i.metrics.firstWhere((m) => m.id == 'elbow_angle');
    expect(elbow.dominantDirection, 'high');
    expect(elbow.trend, 'worsening');
  });

  test('metrics are ordered worst in-range rate first', () {
    final i = computeSessionInsights(shots: fabricate());
    expect(i.metrics.first.id, 'shoulder_turn');
    final rates = [for (final m in i.metrics) m.inRangeRate];
    expect(rates, orderedEquals([...rates]..sort()));
  });

  test('timeline buckets shots into at most six segments in time order', () {
    final i = computeSessionInsights(shots: fabricate());
    expect(i.timeline, hasLength(6));
    // 12 shots → 6 buckets of 2: first bucket (50+52)/2, last (40+60)/2.
    expect(i.timeline.first, closeTo(51, 1e-9));
    expect(i.timeline.last, closeTo(50, 1e-9));
  });

  test('small sessions get one bucket per shot', () {
    final i = computeSessionInsights(
        shots: [mkShot(40), mkShot(60), mkShot(80)]);
    expect(i.timeline, [40, 60, 80]);
  });

  test('consistency is 100 for identical scores and drops with spread', () {
    final flat = computeSessionInsights(
        shots: [for (var i = 0; i < 5; i++) mkShot(70)]);
    expect(flat.consistency, 100);
    final wild = computeSessionInsights(
        shots: [mkShot(10), mkShot(90), mkShot(10), mkShot(90)]);
    expect(wild.consistency, lessThan(flat.consistency));
  });

  test('best clean streak counts consecutive deviation-free shots', () {
    final i = computeSessionInsights(shots: fabricate());
    // Indices 6,7,8 forehands are clean; index 9 deviates; index 11 clean.
    expect(i.bestCleanStreak, 3);
  });

  test('best shot index, score and time offset', () {
    final i = computeSessionInsights(shots: fabricate());
    expect(i.bestShotIndex, 9);
    expect(i.bestShotScore, 72);
    expect(i.bestShotOffsetMs, 270000);
  });

  test('focus outcome reports goal-metric half rates', () {
    final i = computeSessionInsights(
        shots: fabricate(), goalMetricId: 'shoulder_turn');
    expect(i.focus, isNotNull);
    expect(i.focus!.metricId, 'shoulder_turn');
    expect(i.focus!.firstHalfRate, closeTo(1.0, 1e-9));
    expect(i.focus!.secondHalfRate, closeTo(0.0, 1e-9));
    expect(i.focus!.improved, isTrue);
  });

  test('no goal means no focus outcome', () {
    expect(computeSessionInsights(shots: fabricate()).focus, isNull);
  });

  test('empty session produces safe zero insights', () {
    final i = computeSessionInsights(shots: const []);
    expect(i.strokes, isEmpty);
    expect(i.metrics, isEmpty);
    expect(i.timeline, isEmpty);
    expect(i.consistency, 0);
    expect(i.bestCleanStreak, 0);
    expect(i.bestShotIndex, -1);
    expect(i.weakestPhase, isNull);
  });

  test('JSON round-trip preserves every field', () {
    final i = computeSessionInsights(
        shots: fabricate(), goalMetricId: 'shoulder_turn');
    final restored = SessionInsights.fromJson(
        jsonDecode(jsonEncode(i.toJson())) as Map<String, dynamic>);
    expect(restored.strokes['forehand']!.count, 10);
    expect(restored.strokes['backhand']!.avgScore, closeTo(50, 1e-3));
    expect(restored.phaseAverages['contact'], closeTo(64.5, 1e-3));
    expect(restored.metrics.first.id, i.metrics.first.id);
    expect(restored.metrics.first.trend, i.metrics.first.trend);
    expect(restored.timeline, hasLength(6));
    expect(restored.consistency, closeTo(i.consistency, 1e-3));
    expect(restored.bestCleanStreak, 3);
    expect(restored.bestShotIndex, 9);
    expect(restored.bestShotOffsetMs, 270000);
    expect(restored.focus!.metricId, 'shoulder_turn');
    expect(restored.focus!.improved, isTrue);
    expect(restored.weakestPhase, 'contact');
  });
}
