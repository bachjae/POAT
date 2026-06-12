import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:rallycoach/core/engine/engine_types.dart';
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

SummaryShot mkShot(double score, List<MetricDeviation> deviations) => (
      stroke: Stroke.forehand,
      score: ShotScore(
          score: score, phaseScores: const {}, deviations: deviations),
      tOffsetMs: 0,
    );

void main() {
  final catalog = DrillCatalog.fromJsonString(
      File('assets/drills.json').readAsStringSync());

  // 10 shots: shoulder_turn deviates on 7 (worst issue), elbow_angle on 5,
  // contact_in_front on 2 (a strength at 80%), knee_flexion on 1 (90%).
  // First half scores 50, second half 60 -> improving.
  List<SummaryShot> fabricate() => [
        for (var i = 0; i < 10; i++)
          mkShot(i < 5 ? 50 : 60, [
            if (i < 7) dev('shoulder_turn', severity: 0.8, weight: 0.3),
            if (i < 5) dev('elbow_angle', severity: 0.5, weight: 0.3),
            if (i < 2) dev('contact_in_front', severity: 0.2, weight: 0.3),
            if (i < 1) dev('knee_flexion', severity: 0.5, weight: 0.2),
          ]),
      ];

  test('overallScore is the mean of shot scores', () {
    final summary = generateSessionSummary(
        shots: fabricate(), type: 'forehand', durationS: 900, catalog: catalog);
    expect(summary.overallScore, closeTo(55.0, 1e-9));
  });

  test('strengths are the most consistent metrics at >=60% in-range', () {
    final summary = generateSessionSummary(
        shots: fabricate(), type: 'forehand', durationS: 900, catalog: catalog);
    // knee_flexion 90%, contact_in_front 80%; elbow (50%) and shoulder (30%)
    // fall below the 60% bar.
    expect(summary.strengths,
        ['Knee bend 90%', 'Contact out in front 80%']);
  });

  test('improvements rank by summed severity x weight with direction words',
      () {
    final summary = generateSessionSummary(
        shots: fabricate(), type: 'forehand', durationS: 900, catalog: catalog);
    expect(summary.improvements, hasLength(3));

    final top = summary.improvements[0];
    expect(top.deviationId, 'shoulder_turn');
    expect(top.title, 'Shoulder turn timing');
    expect(top.detail, 'late on 7 of 10 shots');

    final second = summary.improvements[1];
    expect(second.deviationId, 'elbow_angle');
    expect(second.detail, 'cramped on 5 of 10 shots');

    // contact_in_front (0.12) edges out knee_flexion (0.10).
    expect(summary.improvements[2].deviationId, 'contact_in_front');
  });

  test('high-direction majority picks the high phrasing', () {
    final shots = [
      for (var i = 0; i < 4; i++)
        mkShot(50, [
          dev('wrist_finish_height',
              direction: 'high', severity: 0.6, weight: 0.25,
              phase: 'follow_through'),
        ]),
    ];
    final summary = generateSessionSummary(
        shots: shots, type: 'forehand', durationS: 300, catalog: catalog);
    expect(summary.improvements.first.detail, 'high on 4 of 4 shots');
  });

  test('drillIds map top improvement deviations, up to 2, deduped', () {
    final summary = generateSessionSummary(
        shots: fabricate(), type: 'forehand', durationS: 900, catalog: catalog);
    // shoulder_turn -> early_turn, elbow_angle -> shadow_swing.
    expect(summary.drillIds, ['early_turn', 'shadow_swing']);
  });

  test('DrillCatalog.forDeviations interleaves one drill per id, deduped',
      () {
    // early_turn and two_bounce_prep both fix shoulder_turn AND prep; the
    // shared drills appear once, breadth-first across the two ids.
    final drills =
        catalog.forDeviations(['shoulder_turn', 'prep_before_contact_ms']);
    expect([for (final d in drills) d.id],
        ['early_turn', 'two_bounce_prep', 'backhand_coil']);
    expect(catalog.drills, hasLength(24));
    expect(catalog.forDeviations(['unknown_metric']), isEmpty);

    // Breadth before depth: two ids -> first drill of each, not two for one.
    final spread = catalog.forDeviations(['shoulder_turn', 'knee_flexion']);
    expect([for (final d in spread.take(2)) d.id],
        ['early_turn', 'low_base']);
  });

  test('score trend description compares halves with a 4-point band', () {
    SessionSummaryData summarize(List<double> scores) =>
        generateSessionSummary(
          shots: [for (final s in scores) mkShot(s, const [])],
          type: 'forehand',
          durationS: 300,
          catalog: catalog,
        );

    expect(summarize([50, 50, 60, 60]).scoreTrendDescription,
        'improving through the session');
    expect(summarize([70, 70, 60, 60]).scoreTrendDescription,
        'fading late in the session');
    expect(summarize([60, 62, 61, 63]).scoreTrendDescription, 'steady');
    // Exactly 4 points apart is still steady.
    expect(summarize([60, 60, 64, 64]).scoreTrendDescription, 'steady');
  });

  test('empty session yields zero score and empty lists', () {
    final summary = generateSessionSummary(
        shots: const [], type: 'full', durationS: 0, catalog: catalog);
    expect(summary.overallScore, 0);
    expect(summary.strengths, isEmpty);
    expect(summary.improvements, isEmpty);
    expect(summary.drillIds, isEmpty);
    expect(summary.scoreTrendDescription, 'steady');
  });
}
