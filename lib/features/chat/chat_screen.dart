/// Ask your coach (DESIGN 2.6): post-session Q&A grounded in this session.
///
/// Coach replies render as margin notes (ball-green left rail, no bubble),
/// streaming in. Lite mode gets an honest explainer instead of a fake chat.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/brain/coach_chat.dart';
import '../../core/storage/database.dart';

final _sessionProvider = FutureProvider.family<Session?, int>((ref, id) async {
  final sessions =
      await ref.watch(repositoryProvider).watchRecentSessions(limit: 500).first;
  for (final s in sessions) {
    if (s.id == id) return s;
  }
  return null;
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = [];
  String _streaming = '';
  bool _busy = false;
  CoachChat? _chat;
  Session? _session;
  bool _liteMode = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final session =
        await ref.read(_sessionProvider(widget.sessionId).future);
    if (session == null || !mounted) return;
    final runner = await ref.read(llmRunnerProvider.future);
    final prompts = await ref.read(promptBuilderProvider.future);
    final bank =
        await ref.read(phraseBankProvider(session.coachId).future);
    setState(() {
      _session = session;
      _messages = session.chatHistory.isEmpty
          ? []
          : ChatMessage.decodeHistory(session.chatHistory);
      if (runner == null) {
        _liteMode = true;
        return;
      }
      final shots = jsonEncode({
        'type': session.type,
        'score': session.overallScore.round(),
        'shots': session.shotsTotal,
        'duration_min': session.durationS ~/ 60,
        'what_worked': jsonDecode(session.summaryGood),
        'work_on': jsonDecode(session.summaryImprove),
        'skill_tier': session.skillTier,
      });
      _chat = CoachChat(
        runner: runner,
        prompts: prompts,
        personalityName: bank.personality.name,
        personalityStyle: bank.personality.style,
        sessionJson: shots,
        historyJson: '[]',
      );
    });
  }

  String? get _topDeviation {
    final s = _session;
    if (s == null) return null;
    final improve =
        (jsonDecode(s.summaryImprove) as List).cast<Map<String, dynamic>>();
    return improve.isEmpty ? null : improve.first['deviationId'] as String?;
  }

  Future<void> _ask(String question) async {
    final chat = _chat;
    if (chat == null || _busy || question.trim().isEmpty) return;
    _controller.clear();
    setState(() {
      _busy = true;
      _streaming = '';
      _messages = [
        ..._messages,
        ChatMessage(role: 'player', text: question.trim()),
      ];
    });
    try {
      await for (final token
          in chat.ask(question.trim(), _messages)) {
        if (!mounted) return;
        setState(() => _streaming += token);
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    } catch (_) {
      _streaming = _streaming.isEmpty
          ? 'The coach brain hit a snag — try that again.'
          : _streaming;
    }
    if (!mounted) return;
    setState(() {
      _messages = [
        ..._messages,
        ChatMessage(role: 'coach', text: _streaming),
      ];
      _streaming = '';
      _busy = false;
    });
    await ref.read(repositoryProvider).saveChatHistory(
        widget.sessionId, ChatMessage.encodeHistory(_messages));
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final title = session == null
        ? 'COACH'
        : '${session.coachId.replaceAll('_', ' ').toUpperCase()} · '
            '${session.type.toUpperCase()}';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            const Divider(),
            Expanded(
              child: _liteMode
                  ? const Padding(
                      padding: EdgeInsets.all(RcDims.screenPadding),
                      child: Center(
                        child: Text(
                          'Coach chat needs the Coach Brain, which is not '
                          'active on this device. Your summary above has '
                          'the full breakdown.',
                          style: RcType.bodyDim,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(RcDims.screenPadding),
                      children: [
                        for (final m in _messages)
                          m.role == 'player'
                              ? _PlayerBubble(text: m.text)
                              : _CoachNote(text: m.text),
                        if (_streaming.isNotEmpty)
                          _CoachNote(text: _streaming),
                      ],
                    ),
            ),
            if (!_liteMode) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final chip
                        in CoachChat.suggestionChips(_topDeviation))
                      ActionChip(
                        label: Text(chip, style: RcType.caption),
                        side: const BorderSide(color: RcColors.net),
                        onPressed: _busy ? null : () => _ask(chip),
                      ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: RcType.body,
                        decoration: const InputDecoration(
                          hintText: 'Ask about this session…',
                          hintStyle: RcType.bodyDim,
                          border: InputBorder.none,
                        ),
                        onSubmitted: _ask,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send,
                          color:
                              _busy ? RcColors.net : RcColors.ballText),
                      onPressed: _busy ? null : () => _ask(_controller.text),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayerBubble extends StatelessWidget {
  const _PlayerBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: RcColors.courtRaised,
            borderRadius: BorderRadius.all(Radius.circular(RcDims.radius)),
          ),
          child: Text(text, style: RcType.body),
        ),
      );
}

/// Coach reply: plain text with a ball-green left rail — a margin note,
/// not a bubble. "Not measured —" prefixes render dimmed.
class _CoachNote extends StatelessWidget {
  const _CoachNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final notMeasured = text.startsWith('Not measured —');
    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 24),
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: RcColors.ball, width: 2)),
      ),
      child: Text(
        text,
        style: notMeasured ? RcType.bodyDim : RcType.body,
      ),
    );
  }
}
