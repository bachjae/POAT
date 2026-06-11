/// Coach chat grounding, streaming, and history round-trips.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallycoach/core/brain/coach_chat.dart';
import 'package:rallycoach/core/brain/llm_runner.dart';
import 'package:rallycoach/core/brain/prompt_builder.dart';

void main() {
  late PromptBuilder prompts;

  setUpAll(() async {
    prompts =
        await PromptBuilder.load((path) async => File(path).readAsString());
  });

  CoachChat chat(FakeLlmRunner runner) => CoachChat(
        runner: runner,
        prompts: prompts,
        personalityName: 'Doc',
        personalityStyle: 'Analytical, precise.',
        sessionJson: '{"type":"forehand","score":68,"shots":34}',
        historyJson: '[{"type":"serve","score":61}]',
      );

  test('prompt grounds the question in session data and transcript', () async {
    final runner = FakeLlmRunner(responses: ['Your contact slipped late.']);
    final prior = [
      const ChatMessage(role: 'player', text: 'how was my forehand?'),
      const ChatMessage(role: 'coach', text: 'Strong early, fading late.'),
    ];
    await chat(runner).ask('why was it fading?', prior).join();

    final prompt = runner.prompts.single;
    expect(prompt, contains('{"type":"forehand","score":68,"shots":34}'));
    expect(prompt, contains('Player: how was my forehand?'));
    expect(prompt, contains('Coach: Strong early, fading late.'));
    expect(prompt, contains('Player: why was it fading?'));
    expect(prompt.trim(), endsWith('Coach:'));
    expect(prompt, contains('Not measured — '));
  });

  test('streams tokens through unchanged', () async {
    final runner = FakeLlmRunner(responses: ['shoulder turn got later as you tired']);
    final pieces = await chat(runner).ask('why?', const []).toList();
    expect(pieces.length, greaterThan(1));
    expect(pieces.join(), 'shoulder turn got later as you tired');
  });

  test('history JSON round-trips', () {
    final history = [
      const ChatMessage(role: 'player', text: 'why?'),
      const ChatMessage(role: 'coach', text: 'Fatigue pattern.'),
    ];
    final decoded = ChatMessage.decodeHistory(ChatMessage.encodeHistory(history));
    expect(decoded.length, 2);
    expect(decoded.first.role, 'player');
    expect(decoded.last.text, 'Fatigue pattern.');
  });

  test('suggestion chips seed from top deviation', () {
    expect(CoachChat.suggestionChips('shoulder_turn'),
        contains('What drill helps my shoulder turn?'));
    expect(CoachChat.suggestionChips(null).length, 2);
  });
}
