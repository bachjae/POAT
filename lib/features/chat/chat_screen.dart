/// Ask your coach (DESIGN 2.6): post-session Q&A grounded in this session.
///
/// Coach replies render as margin notes (ball-green left rail, no bubble),
/// streaming in. With the Coach Brain loaded the Gemma runner answers; in
/// Lite mode the deterministic [LiteCoachChat] answers from the stored
/// session facts instead — chat always works, and a small banner says
/// which coach is talking.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/brain/coach_chat.dart';
import '../../core/brain/lite_coach.dart';
import '../../core/session/session_insights.dart';
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

  /// Streams the coach's answer — Gemma-backed or Lite, set in [_init].
  Stream<String> Function(String question, List<ChatMessage> prior)? _coachAsk;
  Session? _session;
  bool _liteMode = false;
  bool _hasPhaseData = false;
  bool _hasHistory = false;

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
    final catalog = await ref.read(drillCatalogProvider.future);
    final history = await ref
        .read(repositoryProvider)
        .historyAggregates(excludeSessionId: session.id);
    if (!mounted) return;
    SessionInsights? insights;
    if (session.insights.isNotEmpty) {
      try {
        insights = SessionInsights.fromJson(
            jsonDecode(session.insights) as Map<String, dynamic>);
      } catch (_) {
        // Pre-v4 or malformed row — the coach answers from the summary.
      }
    }
    setState(() {
      _session = session;
      _hasPhaseData = insights?.phaseAverages.isNotEmpty ?? false;
      _hasHistory = history.isNotEmpty;
      _messages = session.chatHistory.isEmpty
          ? []
          : ChatMessage.decodeHistory(session.chatHistory);
      final improvements = [
        for (final i in (jsonDecode(session.summaryImprove) as List)
            .cast<Map<String, dynamic>>())
          (
            title: i['title'] as String? ?? '',
            detail: i['detail'] as String? ?? '',
            deviationId: i['deviationId'] as String? ?? '',
          ),
      ];
      if (runner == null) {
        _liteMode = true;
        final lite = LiteCoachChat(
          coachName: bank.personality.name,
          catalog: catalog,
          facts: LiteSessionFacts(
            type: session.type,
            score: session.overallScore.round(),
            shots: session.shotsTotal,
            durationMin: session.durationS ~/ 60,
            skillTier: session.skillTier,
            strengths:
                (jsonDecode(session.summaryGood) as List).cast<String>(),
            improvements: improvements,
            insights: insights,
            history: [
              for (final h in history)
                (
                  date: h['date'] as String,
                  type: h['type'] as String,
                  score: h['score'] as int,
                  shots: h['shots'] as int,
                ),
            ],
          ),
        );
        _coachAsk = lite.ask;
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
        if (insights != null) 'insights': insights.toJson(),
      });
      final chat = CoachChat(
        runner: runner,
        prompts: prompts,
        personalityName: bank.personality.name,
        personalityStyle: bank.personality.style,
        sessionJson: shots,
        historyJson: jsonEncode(history),
      );
      _coachAsk = chat.ask;
    });
  }

  String? get _topDeviation {
    final s = _session;
    if (s == null) return null;
    final improve =
        (jsonDecode(s.summaryImprove) as List).cast<Map<String, dynamic>>();
    return improve.isEmpty ? null : improve.first['deviationId'] as String?;
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  Future<void> _ask(String question) async {
    final ask = _coachAsk;
    if (ask == null || _busy || question.trim().isEmpty) return;
    // The asker appends 'Player: <question>' itself — pass only the
    // PRIOR transcript or the question shows up twice in the prompt.
    final prior = _messages;
    _controller.clear();
    setState(() {
      _busy = true;
      _streaming = '';
      _messages = [
        ...prior,
        ChatMessage(role: 'player', text: question.trim()),
      ];
    });
    try {
      await for (final token in ask(question.trim(), prior)) {
        if (!mounted) return;
        setState(() => _streaming += token);
        _scrollToEnd();
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
            if (_liteMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, size: 14, color: RcColors.ballText),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Lite coach — instant answers from this '
                        'session\'s measured data.',
                        style: RcType.caption,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(RcDims.screenPadding),
                children: [
                  for (final m in _messages)
                    m.role == 'player'
                        ? _PlayerBubble(text: m.text)
                        : _CoachNote(text: m.text),
                  if (_streaming.isNotEmpty) _CoachNote(text: _streaming),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final chip in CoachChat.suggestionChips(
                    _topDeviation,
                    hasPhaseData: _hasPhaseData,
                    hasHistory: _hasHistory,
                  ))
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
                        color: _busy ? RcColors.net : RcColors.ballText),
                    onPressed: _busy ? null : () => _ask(_controller.text),
                  ),
                ],
              ),
            ),
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
