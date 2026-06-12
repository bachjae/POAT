/// Progress (DESIGN 2.7): trend chart (the Rally Arc as data) + history.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/storage/database.dart';

const _strokes = [
  ('forehand', 'FH'),
  ('backhand', 'BH'),
  ('serve', 'SRV'),
  ('volley', 'VLY'),
  ('footwork', 'FW'),
];

class _StrokeFilter extends Notifier<String> {
  @override
  String build() => 'forehand';

  void set(String id) => state = id;
}

final _strokeFilterProvider =
    NotifierProvider<_StrokeFilter, String>(_StrokeFilter.new);

final _trendProvider = FutureProvider.family<
    List<({DateTime weekStart, double avgScore})>,
    String>((ref, stroke) => ref.watch(repositoryProvider).trendFor(stroke));

final _metricTrendProvider = FutureProvider.family<
    List<({String deviationId, double frequency})>,
    String>((ref, stroke) =>
    ref.watch(repositoryProvider).metricTrendFor(stroke));

final _sessionsProvider = StreamProvider<List<Session>>(
    (ref) => ref.watch(repositoryProvider).watchRecentSessions(limit: 50));

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stroke = ref.watch(_strokeFilterProvider);
    final trend = ref.watch(_trendProvider(stroke));
    final metricTrend = ref.watch(_metricTrendProvider(stroke));
    final sessions = ref.watch(_sessionsProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RcDims.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('PROGRESS', style: RcType.heading),
                  const Spacer(),
                  for (final (id, abbr) in _strokes.take(3))
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _FilterChip(id: id, label: abbr),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.expand_more,
                        color: RcColors.lineDim),
                    onSelected: (id) =>
                        ref.read(_strokeFilterProvider.notifier).set(id),
                    itemBuilder: (context) => [
                      for (final (id, abbr) in _strokes)
                        PopupMenuItem(value: id, child: Text(abbr)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: trend.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (points) => points.isEmpty
                      ? const Center(
                          child: Text('No $_emptyHint sessions yet.',
                              style: RcType.bodyDim))
                      : _TrendChart(points: points),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              const Text('METRIC TRENDS', style: RcType.caption),
              const SizedBox(height: 8),
              metricTrend.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (items) => items.isEmpty
                    ? const SizedBox.shrink()
                    : _MetricTrendBars(items: items),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              const Text('SESSIONS', style: RcType.caption),
              const SizedBox(height: 4),
              Expanded(
                child: sessions.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (rows) => ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) => _SessionRow(row: rows[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _emptyHint = '';
}

class _FilterChip extends ConsumerWidget {
  const _FilterChip({required this.id, required this.label});

  final String id;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_strokeFilterProvider) == id;
    return InkWell(
      onTap: () => ref.read(_strokeFilterProvider.notifier).set(id),
      child: Text(
        label,
        style: RcType.stat.copyWith(
          fontSize: 14,
          color: selected ? RcColors.ballText : RcColors.lineDim,
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<({DateTime weekStart, double avgScore})> points;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].avgScore),
    ];
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            left: BorderSide(color: RcColors.net),
            bottom: BorderSide(color: RcColors.net),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text('${v.round()}',
                  style: RcType.stat.copyWith(
                      fontSize: 11, color: RcColors.lineDim)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (points.length / 3).clamp(1, 10).toDouble(),
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                final d = points[i].weekStart;
                return Text('${d.month}/${d.day}',
                    style: RcType.stat.copyWith(
                        fontSize: 11, color: RcColors.lineDim));
              },
            ),
          ),
        ),
        lineBarsData: [
          // The chart line IS the Rally Arc (signature element use #4).
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: RcColors.ball,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, bar) => spot.x == spots.last.x,
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                radius: 4,
                color: RcColors.ball,
                strokeColor: RcColors.ballText,
                strokeWidth: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal bar chart showing top deviation frequencies for the selected
/// stroke. Bars are colored by severity:
/// ≥ 0.4 → persistent weakness (clay), < 0.15 → rarely an issue (ball).
class _MetricTrendBars extends StatelessWidget {
  const _MetricTrendBars({required this.items});

  final List<({String deviationId, double frequency})> items;

  Color _barColor(double freq) {
    if (freq >= 0.4) return RcColors.clay;
    if (freq <= 0.15) return RcColors.ball;
    return RcColors.net;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    item.deviationId.replaceAll('_', ' '),
                    style: RcType.stat.copyWith(
                        fontSize: 11, color: RcColors.lineDim),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: item.frequency.clamp(0.0, 1.0),
                      backgroundColor: RcColors.net.withValues(alpha: 0.3),
                      color: _barColor(item.frequency),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(item.frequency * 100).round()}%',
                    style: RcType.stat.copyWith(
                        fontSize: 11, color: RcColors.lineDim),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.row});

  final Session row;

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final d = row.startedAt;
    final label = row.type == 'full'
        ? 'Full'
        : row.type[0].toUpperCase() + row.type.substring(1);
    return InkWell(
      onTap: () => context.push('/summary/${row.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: Text(
                  '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}',
                  style: RcType.stat.copyWith(fontSize: 13)),
            ),
            Expanded(child: Text(label, style: RcType.body)),
            SizedBox(
              width: 44,
              child: Text('${row.overallScore.round()}',
                  style: RcType.stat
                      .copyWith(color: RcColors.ballText)),
            ),
            SizedBox(
              width: 48,
              child: Text('${row.durationS ~/ 60}m',
                  style: RcType.stat.copyWith(
                      fontSize: 13, color: RcColors.lineDim)),
            ),
          ],
        ),
      ),
    );
  }
}
