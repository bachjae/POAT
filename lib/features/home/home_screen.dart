/// Home (DESIGN 2.1): last session card, streak, weekly stats, START CTA.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/storage/database.dart';
import '../../shared/widgets/rally_arc.dart';
import '../../shared/widgets/rc_widgets.dart';

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];
const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

final _lastSessionProvider = FutureProvider<Session?>(
    (ref) => ref.watch(repositoryProvider).lastSession());
final _streakProvider = FutureProvider<int>(
    (ref) => ref.watch(repositoryProvider).streakDays(DateTime.now()));
final _weeklyProvider = FutureProvider<Map<String, double>>(
    (ref) => ref.watch(repositoryProvider).weeklyAverages(DateTime.now()));

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(_lastSessionProvider);
    final streak = ref.watch(_streakProvider);
    final weekly = ref.watch(_weeklyProvider);
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RcDims.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('RALLYCOACH', style: RcType.heading),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: RcColors.lineDim),
                    onPressed: () => context.go('/profile'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${_days[now.weekday - 1]} · ${_months[now.month - 1]} ${now.day}',
                style: RcType.caption,
              ),
              const SizedBox(height: 8),
              last.when(
                loading: () => const SizedBox(height: 120),
                error: (_, _) => const SizedBox.shrink(),
                data: (session) => session == null
                    ? const _EmptyCourt()
                    : _LastSessionCard(session: session),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('STREAK  ', style: RcType.caption),
                  streak.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (days) => Row(children: [
                      StreakDots(days: days.clamp(0, 7)),
                      const SizedBox(width: 8),
                      StatText(
                          value: '$days ${days == 1 ? 'day' : 'days'}',
                          size: 14),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Hairline(),
              const SizedBox(height: 16),
              const Text('THIS WEEK', style: RcType.caption),
              const SizedBox(height: 8),
              weekly.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (averages) => averages.isEmpty
                    ? const Text('No sessions yet this week.',
                        style: RcType.bodyDim)
                    : _WeeklyStats(averages: averages),
              ),
              const Spacer(),
              RcPrimaryButton(
                label: 'Start session',
                onPressed: () => context.push('/setup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LastSessionCard extends StatelessWidget {
  const _LastSessionCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final label = session.type == 'full'
        ? 'Full analysis'
        : session.type[0].toUpperCase() + session.type.substring(1);
    return Card(
      child: InkWell(
        onTap: () => context.push('/summary/${session.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LAST SESSION', style: RcType.caption),
              const SizedBox(height: 4),
              Text('$label · ${session.durationS ~/ 60} min',
                  style: RcType.body),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${session.overallScore.round()}',
                      style: RcType.statHero),
                  const SizedBox(width: 16),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: RallyArc(width: 90, height: 28, animate: false),
                  ),
                ],
              ),
              if (session.headline.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('"${session.headline}"', style: RcType.bodyDim),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyStats extends StatelessWidget {
  const _WeeklyStats({required this.averages});

  final Map<String, double> averages;

  static const _abbr = {
    'forehand': 'FH', 'backhand': 'BH', 'serve': 'SRV',
    'volley': 'VLY', 'footwork': 'FW', 'full': 'FULL',
  };

  @override
  Widget build(BuildContext context) {
    final entries = averages.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final lowest = entries.isEmpty
        ? null
        : entries.reduce((a, b) => a.value <= b.value ? a : b).key;
    return Wrap(
      spacing: 20,
      children: [
        for (final e in entries)
          StatText(
            label: _abbr[e.key] ?? e.key.toUpperCase(),
            value: '${e.value.round()}',
            color: e.key == lowest && entries.length > 1
                ? RcColors.clay
                : RcColors.line,
          ),
      ],
    );
  }
}

class _EmptyCourt extends StatelessWidget {
  const _EmptyCourt();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RallyArc(width: 110, height: 32),
              SizedBox(height: 12),
              Text('No sessions yet. The court is waiting.',
                  style: RcType.body),
            ],
          ),
        ),
      );
}
