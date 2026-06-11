/// Renders the three real prompt templates and asserts every slot fills.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallycoach/core/brain/prompt_builder.dart';
import 'package:rallycoach/core/engine/engine_types.dart';

void main() {
  late PromptBuilder builder;

  setUpAll(() async {
    builder = await PromptBuilder.load(
        (path) async => File(path).readAsString());
  });

  const deviation = MetricDeviation(
    phase: 'contact',
    id: 'elbow_angle',
    value: 108.0,
    ideal: [120, 155],
    direction: 'low',
    severity: 0.34,
    weight: 0.3,
    cue: "extend through contact — arm's too bent",
  );

  test('shot cue prompt renders fully', () {
    final prompt = builder.shotCue(
      personalityName: 'Coach K',
      personalityStyle: 'Direct, no fluff.',
      skillTier: 'intermediate',
      handedness: 'right',
      sessionType: 'forehand',
      stroke: 'forehand',
      score: 64,
      deviations: const [deviation],
      recurrence: const {'elbow_angle': 7},
      shotNumber: 28,
      trend: -4.0,
      recentCues: const ['stay low through the hit'],
    );
    expect(prompt, isNot(contains(RegExp(r'\{[a-z_]+\}'))));
    expect(prompt, contains('Coach K'));
    expect(prompt, contains('elbow_angle'));
    expect(prompt, contains('recurring: 7 of last 10'));
    expect(prompt, contains('-4.0'));
    expect(prompt, contains('max 12 words'));
  });

  test('session summary prompt renders fully', () {
    final prompt = builder.sessionSummary(
      personalityName: 'Maya',
      personalityStyle: 'Encouraging, warm.',
      sessionType: 'forehand',
      durationMin: 24,
      shotsTotal: 34,
      score: 68,
      scoreDelta: 6.0,
      strokeAverages: const {'forehand': 68.2},
      strengths: const ['Contact out in front 81%'],
      recurringDeviations: const [
        (id: 'shoulder_turn', occurrences: 19, phase: 'preparation'),
        (id: 'elbow_angle', occurrences: 9, phase: 'contact'),
      ],
      trendDescription: 'fading late in the session',
    );
    expect(prompt, isNot(contains(RegExp(r'\{[a-z_]+\}'))));
    expect(prompt, contains('"work_on": array of exactly 2'));
    expect(prompt, contains('(shoulder_turn, 19, preparation)'));
    expect(prompt, contains('+6.0'));
  });

  test('chat system prompt renders fully and keeps grounding rule', () {
    final prompt = builder.chatSystem(
      personalityName: 'Doc',
      personalityStyle: 'Analytical, precise.',
      sessionJson: '{"type":"serve","score":61}',
      historyJson: '[]',
    );
    expect(prompt, isNot(contains(RegExp(r'\{[a-z_]+\}'))));
    expect(prompt, contains('Not measured — '));
    expect(prompt, contains('{"type":"serve","score":61}'));
  });

  test('throws on unfilled slot when a template key is missing', () {
    final broken = PromptBuilder(templates: const {
      kShotCueTemplate: 'Hello {nonexistent_slot}',
      kSessionSummaryTemplate: '',
      kChatSystemTemplate: '',
    });
    expect(
      () => broken.shotCue(
        personalityName: 'x',
        personalityStyle: 'x',
        skillTier: 'x',
        handedness: 'x',
        sessionType: 'x',
        stroke: 'x',
        score: 0,
        deviations: const [],
        recurrence: const {},
        shotNumber: 1,
        trend: 0,
        recentCues: const [],
      ),
      throwsStateError,
    );
  });
}
