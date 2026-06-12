/// Lite-mode coach chat: deterministic, session-grounded answers when the
/// Gemma Coach Brain is unavailable.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallycoach/core/brain/lite_coach.dart';
import 'package:rallycoach/core/session/session_insights.dart';
import 'package:rallycoach/core/session/summary_generator.dart';

void main() {
  final catalog = DrillCatalog.fromJsonString(
      File('assets/drills.json').readAsStringSync());

  LiteCoachChat coach({
    int shots = 42,
    SessionInsights? insights,
    List<({String date, String type, int score, int shots})> history =
        const [],
  }) =>
      LiteCoachChat(
        coachName: 'Maya',
        catalog: catalog,
        tokenDelay: Duration.zero,
        facts: LiteSessionFacts(
          type: 'forehand',
          score: 71,
          shots: shots,
          durationMin: 18,
          skillTier: 'intermediate',
          strengths: const ['Contact out in front 81%'],
          improvements: const [
            (
              title: 'Shoulder turn timing',
              detail: 'late on 19 of 42 shots',
              deviationId: 'shoulder_turn',
            ),
            (
              title: 'Knee bend',
              detail: 'too upright on 12 of 42 shots',
              deviationId: 'knee_flexion',
            ),
          ],
          insights: insights,
          history: history,
        ),
      );

  final insights = SessionInsights(
    strokes: const {
      'forehand': StrokeInsight(
          count: 30, avgScore: 72, bestScore: 91, worstScore: 48),
      'backhand': StrokeInsight(
          count: 12, avgScore: 61, bestScore: 80, worstScore: 40),
    },
    phaseAverages: const {
      'preparation': 82,
      'contact': 64,
      'follow_through': 71,
    },
    metrics: const [
      MetricInsight(
        id: 'shoulder_turn',
        deviatedCount: 19,
        inRangeRate: 0.55,
        dominantDirection: 'low',
        firstHalfRate: 0.6,
        secondHalfRate: 0.3,
      ),
    ],
    timeline: const [62, 66, 70, 74],
    consistency: 78,
    bestCleanStreak: 4,
    bestShotIndex: 22,
    bestShotScore: 91,
    bestShotOffsetMs: 750000,
  );

  const history = [
    (date: '2026-06-10', type: 'forehand', score: 64, shots: 38),
    (date: '2026-06-08', type: 'serve', score: 58, shots: 25),
  ];

  test('overall recap quotes the measured numbers', () {
    final a = coach().answer('How did I do overall?');
    expect(a, contains('42 shots'));
    expect(a, contains('71'));
    expect(a, contains('18 minutes'));
    expect(a, contains('Shoulder turn timing'.toLowerCase()));
  });

  test('work-on question lists improvements worst-first with a tip', () {
    final a = coach().answer('What should I work on next?');
    expect(a, contains('1. Shoulder turn timing'));
    expect(a, contains('2. Knee bend'));
    expect(a, contains('late on 19 of 42 shots'));
  });

  test('drill question maps the top deviation to the catalog', () {
    final a = coach().answer('What drill helps my shoulder turn?');
    expect(a, contains('Turn-before-bounce drill'));
  });

  test('drill question without a metric uses the session priorities', () {
    final a = coach().answer('Give me drills to practice');
    expect(a, contains('Turn-before-bounce drill'));
    expect(a, contains('Chair-touch drill'));
  });

  test('why question explains the metric and cites this session', () {
    final a = coach().answer('Why does my shoulder turn matter?');
    expect(a.toLowerCase(), contains('shoulder turn'));
    expect(a, contains('late on 19 of 42 shots'));
  });

  test('metric mention reports its status even when it was a strength', () {
    final a = coach().answer('How was my contact point?');
    expect(a, contains('81%'));
  });

  test('strengths question reads from what worked', () {
    final a = coach().answer('What worked well today?');
    expect(a, contains('Contact out in front 81%'));
  });

  test('zero-shot session is reported honestly', () {
    final a = coach(shots: 0).answer('How did I do?');
    expect(a.toLowerCase(), contains('didn\'t register any shots'));
  });

  test('ask() streams the exact answer word by word', () async {
    final c = coach();
    final tokens = await c.ask('How did I do overall?', const []).toList();
    expect(tokens.join(), c.answer('How did I do overall?'));
    expect(tokens.length, greaterThan(5));
  });

  test('stroke question reads the per-stroke breakdown', () {
    final a = coach(insights: insights).answer('How was my backhand?');
    expect(a, contains('12'));
    expect(a, contains('61'));
    expect(a, contains('weakest stroke'));
    final b = coach(insights: insights).answer('How was my forehand today?');
    expect(b, contains('72'));
    expect(b, contains('strongest stroke'));
  });

  test('stroke not in the session is reported honestly', () {
    final a = coach(insights: insights).answer('How were my volleys?');
    expect(a, contains('No volleys registered'));
  });

  test('phase question names the weakest swing phase', () {
    final a = coach(insights: insights)
        .answer('Where in my swing am I losing points?');
    expect(a, contains('contact 64'));
    expect(a, contains('Contact is where you\'re losing the most'));
  });

  test('timeline question reads the session arc and best streak', () {
    final a = coach(insights: insights)
        .answer('Did I get better toward the end?');
    expect(a, contains('62'));
    expect(a, contains('74'));
    expect(a, contains('stronger as the session went'));
    expect(a, contains('4 clean shots in a row'));
  });

  test('metric plus time words gives the half-session trend', () {
    final a = coach(insights: insights)
        .answer('Did my shoulder turn improve toward the end?');
    expect(a, contains('60%'));
    expect(a, contains('30%'));
    expect(a, contains('correction stuck'));
  });

  test('consistency question quotes the index', () {
    final a = coach(insights: insights).answer('How consistent was I?');
    expect(a, contains('Consistency 78'));
    expect(a, contains('clean streak: 4'));
  });

  test('best shot question points at the exact shot and time', () {
    final a = coach(insights: insights).answer('What was my best shot?');
    expect(a, contains('number 23'));
    expect(a, contains('12:30'));
    expect(a, contains('91'));
  });

  test('progress question compares against the last same-type session', () {
    final a = coach(insights: insights, history: history)
        .answer('Am I improving compared to last session?');
    expect(a, contains('64'));
    expect(a, contains('up 7'));
    expect(a, contains('averaged 61'));
  });

  test('progress question without history sets the baseline', () {
    final a = coach(insights: insights).answer('Am I improving?');
    expect(a, contains('first stored session'));
    expect(a, contains('71'));
  });

  test('deep questions on a pre-insights session degrade gracefully', () {
    final a = coach().answer('Where in my swing am I losing points?');
    expect(a, contains('didn\'t store the deep breakdown'));
    expect(a, contains('42 shots'));
  });
}
