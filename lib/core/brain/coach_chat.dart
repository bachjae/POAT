/// Post-session Q&A chat over one session's data (SPEC §9).
///
/// Stateless per question: every [CoachChat.ask] re-composes the chat
/// system prompt + a plain-text transcript + the new question, so the
/// runner needs no session memory of its own.
library;

// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'llm_runner.dart';
import 'prompt_builder.dart';

/// One chat turn. [role] is `'player'` or `'coach'`.
class ChatMessage {
  const ChatMessage({required this.role, required this.text});

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String,
        text: json['text'] as String,
      );

  final String role;
  final String text;

  Map<String, dynamic> toJson() => {'role': role, 'text': text};

  /// Encodes a transcript for persistence.
  static String encodeHistory(List<ChatMessage> messages) =>
      jsonEncode([for (final m in messages) m.toJson()]);

  /// Decodes a transcript persisted by [encodeHistory].
  static List<ChatMessage> decodeHistory(String json) => [
        for (final m in jsonDecode(json) as List<dynamic>)
          ChatMessage.fromJson(m as Map<String, dynamic>)
      ];
}

/// Streams coach answers about a single finished session.
class CoachChat {
  CoachChat({
    required LlmRunner runner,
    required PromptBuilder prompts,
    required String personalityName,
    required String personalityStyle,
    required String sessionJson,
    required String historyJson,
  })  : _runner = runner,
        _prompts = prompts,
        _personalityName = personalityName,
        _personalityStyle = personalityStyle,
        _sessionJson = sessionJson,
        _historyJson = historyJson;

  final LlmRunner _runner;
  final PromptBuilder _prompts;
  final String _personalityName;
  final String _personalityStyle;
  final String _sessionJson;
  final String _historyJson;

  static const int _maxTokens = 700;

  /// Streams the coach's answer to [question], given the prior
  /// [priorMessages] transcript of this chat.
  Stream<String> ask(String question, List<ChatMessage> priorMessages) {
    final system = _prompts.chatSystem(
      personalityName: _personalityName,
      personalityStyle: _personalityStyle,
      sessionJson: _sessionJson,
      historyJson: _historyJson,
    );
    final transcript = StringBuffer();
    for (final m in priorMessages) {
      transcript.writeln(m.role == 'player' ? 'Player: ${m.text}' : 'Coach: ${m.text}');
    }
    final prompt = '$system\n\n$transcript'
        'Player: $question\n'
        'Coach:';
    return _runner.generateStream(prompt, maxTokens: _maxTokens);
  }

  /// Suggested question chips for the chat entry screen, seeded with the
  /// session's most recurrent deviation (if any). [hasPhaseData] adds a
  /// swing-phase chip and [hasHistory] a progress chip — both grounded in
  /// data the coach can actually answer from.
  static List<String> suggestionChips(
    String? topDeviationId, {
    bool hasPhaseData = false,
    bool hasHistory = false,
  }) {
    final chips = <String>[];
    if (topDeviationId == null) {
      chips.addAll(const [
        'How did I do overall?',
        'What should I work on next?',
      ]);
    } else {
      final name = topDeviationId.replaceAll('_', ' ');
      chips.addAll([
        'Why does my $name matter?',
        'What drill helps my $name?',
        'How did I do overall?',
      ]);
    }
    if (hasPhaseData) chips.add('Where in my swing am I losing points?');
    if (hasHistory) chips.add('Am I improving?');
    return chips;
  }
}
