/// Session summary (DESIGN 2.5): hero score with arc underline, what
/// worked / work on / try next, chat entry, GO AGAIN.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
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
