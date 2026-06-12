/// Session summary (DESIGN 2.5): hero score with arc underline, what
/// worked / work on / try next, chat entry, GO AGAIN.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/session/session_insights.dart';
import '../../core/session/summary_generator.dart';
import '../../core/storage/database.dart';
import '../../shared/widgets/rally_arc.dart';
import '../../shared/widgets/rc_widgets.dart';

final _sessionProvider = FutureProvider.family<Session?, int>((ref, id) async {
  final sessions =
      await ref.watch(repositoryProvider).watchRecentSessions(limit: 500).first;
  for (final s in sessions) {
    if (s.id == id) return s;
  }
  return null;
});

final _deltaProvider = FutureProvider.family<double?, int>((ref, id) async {
  final session = await ref.watch(_sessionProvider(id).future);
  if (session == null) return null;
  final sessions =
      await ref.watch(repositoryProvider).watchRecentSessions(limit: 500).first;
  for (final s in sessions) {
    if (s.type == session.type && s.startedAt.isBefore(session.startedAt)) {
      return session.overallScore - s.overallScore;
    }
  }
  return null;
});

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(_sessionProvider(sessionId));
    final delta = ref.watch(_deltaProvider(sessionId)).value;
    final catalog = ref.watch(drillCatalogProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SESSION COMPLETE'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Session not found')),
        data: (s) => s == null
            ? const Center(child: Text('Session not found'))
            : _Body(session: s, delta: delta, catalog: catalog),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.session, this.delta, this.catalog});

  final Session session;
  final double? delta;
  final DrillCatalog? catalog;

  @override
  Widget build(BuildContext context) {
    final good = (jsonDecode(session.summaryGood) as List).cast<String>();
    final improve = (jsonDecode(session.summaryImprove) as List)
        .cast<Map<String, dynamic>>();
    final drillIds = (jsonDecode(session.drills) as List).cast<String>();
    final highlights = (jsonDecode(session.highlights) as List)
        .cast<Map<String, dynamic>>();
    SessionInsights? insights;
    if (session.insights.isNotEmpty) {
      try {
        insights = SessionInsights.fromJson(
            jsonDecode(session.insights) as Map<String, dynamic>);
      } catch (_) {
        // Pre-v4 session — the summary stands without the deep sections.
      }
    }
    final drills = catalog == null
        ? const <Drill>[]
        : [
            for (final d in catalog!.drills)
              if (drillIds.contains(d.id)) d,
          ];
    final typeLabel = session.type == 'full'
        ? 'Full analysis'
        : session.type[0].toUpperCase() + session.type.substring(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(RcDims.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$typeLabel · ${session.durationS ~/ 60} min · '
            '${session.shotsTotal} ${session.type == 'footwork' ? 'windows' : 'shots'}',
            style: RcType.caption,
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                _CountUpScore(score: session.overallScore.round()),
                const RallyArc(width: 120, height: 24),
                if (delta != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${delta! >= 0 ? '+' : ''}${delta!.round()} vs last '
                    '${session.type} session',
                    style: RcType.caption,
                  ),
                ],
                if (session.headline.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(session.headline, style: RcType.body),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Hairline(),
          const SizedBox(height: 16),
          const Text('WHAT WORKED', style: RcType.heading),
          const SizedBox(height: 8),
          if (good.isEmpty)
            const Text('Keep hitting — strengths show up with volume.',
                style: RcType.bodyDim)
          else
            for (final g in good)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('· $g', style: RcType.body),
              ),
          const SizedBox(height: 16),
          const Hairline(),
          const SizedBox(height: 16),
          const Text('WORK ON', style: RcType.heading),
          const SizedBox(height: 8),
          for (var i = 0; i < improve.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1} ',
                      style: RcType.stat.copyWith(color: RcColors.clay)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(improve[i]['title'] as String,
                            style: RcType.body
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text(improve[i]['detail'] as String,
                            style: RcType.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (session.encouragement.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(session.encouragement, style: RcType.bodyDim),
          ],
          if (insights != null) _InsightsSection(insights: insights),
          const SizedBox(height: 16),
          const Hairline(),
          const SizedBox(height: 16),
          const Text('TRY NEXT', style: RcType.heading),
          const SizedBox(height: 8),
          for (final d in drills)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${d.title} · ${d.minutes} min', style: RcType.body),
                    const SizedBox(height: 4),
                    Text(d.description, style: RcType.caption),
                  ],
                ),
              ),
            ),
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Hairline(),
            const SizedBox(height: 16),
            const Text('HIGHLIGHTS', style: RcType.heading),
            const SizedBox(height: 8),
            for (final h in highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '· Shot ${h['shotIndex']} at ${_formatOffset(h['tOffsetMs'] as int)}',
                  style: RcType.body,
                ),
              ),
          ],
          const SizedBox(height: 16),
          RcOutlineButton(
            label: '💬 Ask your coach',
            onPressed: () => context.push('/chat/${session.id}'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: RcOutlineButton(
                  label: 'Done',
                  onPressed: () => context.go('/home'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RcPrimaryButton(
                  label: 'Go again',
                  onPressed: () => context.pushReplacement('/camera'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

String _formatOffset(int ms) {
  final s = ms ~/ 1000;
  final mm = (s ~/ 60).toString().padLeft(2, '0');
  final ss = (s % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

/// The deep-analysis block: score timeline, session stats, stroke
/// breakdown, swing-phase bars, and the goal outcome. Every number is
/// measured (computed by [computeSessionInsights]) — this is the same data
/// the coach chat is grounded in, so "Ask your coach" can expand on any of
/// it.
class _InsightsSection extends StatelessWidget {
  const _InsightsSection({required this.insights});

  final SessionInsights insights;

  @override
  Widget build(BuildContext context) {
    final i = insights;
    final weakest = i.weakestPhase;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (i.timeline.length >= 2) ...[
          const SizedBox(height: 16),
          const Hairline(),
          const SizedBox(height: 16),
          const Text('HOW IT WENT', style: RcType.heading),
          const SizedBox(height: 8),
          _TimelineBars(timeline: i.timeline),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('start', style: RcType.caption),
              Text('end', style: RcType.caption),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            _StatChip(
                label: 'CONSISTENCY', value: '${i.consistency.round()}'),
            const SizedBox(width: 8),
            _StatChip(label: 'BEST STREAK', value: '${i.bestCleanStreak}'),
            const SizedBox(width: 8),
            if (i.bestShotIndex >= 0)
              _StatChip(
                  label: 'BEST SHOT',
                  value: '${i.bestShotScore.round()} · '
                      '${_formatOffset(i.bestShotOffsetMs)}'),
          ],
        ),
        if (i.strokes.length > 1) ...[
          const SizedBox(height: 16),
          const Hairline(),
          const SizedBox(height: 16),
          const Text('BY STROKE', style: RcType.heading),
          const SizedBox(height: 8),
          for (final e in i.strokes.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      e.key[0].toUpperCase() + e.key.substring(1),
                      style: RcType.body,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${e.value.count} shots',
                      style: RcType.caption,
                    ),
                  ),
                  Text(
                    'avg ${e.value.avgScore.round()} · '
                    'best ${e.value.bestScore.round()}',
                    style: RcType.stat.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
        if (i.phaseAverages.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Hairline(),
          const SizedBox(height: 16),
          const Text('SWING PHASES', style: RcType.heading),
          const SizedBox(height: 8),
          for (final e in i.phaseAverages.entries)
            _PhaseBar(
              label: phaseLabels[e.key] ?? e.key,
              score: e.value,
              isWeakest: e.key == weakest && i.phaseAverages.length > 1,
            ),
          if (weakest != null && i.phaseAverages.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${phaseLabels[weakest] ?? weakest} is costing you the '
                'most — ask your coach why.',
                style: RcType.caption.copyWith(color: RcColors.clay),
              ),
            ),
        ],
        if (i.focus != null) ...[
          const SizedBox(height: 12),
          Text(
            i.focus!.improved
                ? 'Goal ${i.focus!.metricId.replaceAll('_', ' ')}: missed '
                    '${(i.focus!.firstHalfRate * 100).round()}% early → '
                    '${(i.focus!.secondHalfRate * 100).round()}% late. '
                    'It\'s working.'
                : 'Goal ${i.focus!.metricId.replaceAll('_', ' ')}: still at '
                    '${(i.focus!.secondHalfRate * 100).round()}% late in '
                    'the session — keep it as the focus.',
            style: RcType.body,
          ),
        ],
      ],
    );
  }
}

/// Vertical mini-bars of the per-segment average scores (0–100).
class _TimelineBars extends StatelessWidget {
  const _TimelineBars({required this.timeline});

  final List<double> timeline;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var s = 0; s < timeline.length; s++) ...[
            if (s > 0) const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${timeline[s].round()}',
                      style: RcType.stat.copyWith(
                          fontSize: 10, color: RcColors.lineDim)),
                  const SizedBox(height: 2),
                  Container(
                    height: (timeline[s].clamp(0, 100) / 100) * 40,
                    decoration: BoxDecoration(
                      color: RcColors.ball,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: RcColors.net),
          borderRadius: BorderRadius.circular(RcDims.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: RcType.caption.copyWith(fontSize: 10)),
            Text(value, style: RcType.stat.copyWith(fontSize: 14)),
          ],
        ),
      );
}

class _PhaseBar extends StatelessWidget {
  const _PhaseBar({
    required this.label,
    required this.score,
    required this.isWeakest,
  });

  final String label;
  final double score;
  final bool isWeakest;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(label, style: RcType.caption)),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (score / 100).clamp(0.0, 1.0),
                  backgroundColor: RcColors.net.withValues(alpha: 0.3),
                  color: isWeakest ? RcColors.clay : RcColors.ball,
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 30,
              child: Text('${score.round()}',
                  style: RcType.stat.copyWith(fontSize: 12),
                  textAlign: TextAlign.end),
            ),
          ],
        ),
      );
}

/// Score counts up over 400ms (DESIGN motion rules); instant when the
/// platform asks for reduced motion.
class _CountUpScore extends StatelessWidget {
  const _CountUpScore({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Text('$score', style: RcType.statHero);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score.toDouble()),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutExpo,
      builder: (context, v, _) =>
          Text('${v.round()}', style: RcType.statHero),
    );
  }
}
