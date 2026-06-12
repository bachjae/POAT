/// Lite-mode coach chat: deterministic, session-grounded answers when the
/// Gemma Coach Brain is unavailable.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallycoach/core/brain/lite_coach.dart';
import 'package:rallycoach/core/session/summary_generator.dart';

void main() {
  final catalog = DrillCatalog.fromJsonString(
      File('assets/drills.json').readAsStringSync());

  LiteCoachChat coach({int shots = 42}) => LiteCoachChat(
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
        ),
      );

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
}
