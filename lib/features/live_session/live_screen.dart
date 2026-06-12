/// Live session (DESIGN 2.4, landscape) — glanceable from 10 meters.
///
/// A scoreboard, a trail, a voice: camera feed, skeleton + Rally Arc wrist
/// trail, caption bar mirroring every spoken cue, giant mono stats. No
/// rings, no gauges, no confetti.
library;

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/engine/engine_types.dart';
import '../../core/session/orchestrator.dart';
import '../../core/session/shot_processor.dart';
import '../../core/session/summary_generator.dart';
import '../../shared/widgets/rally_arc.dart';
import '../../shared/widgets/rc_widgets.dart';
import '../../shared/widgets/skeleton_overlay.dart';

class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  String _caption = '';
  LiveStats _stats = LiveStats.zero;
  SessionPhase _phase = SessionPhase.live;
  PoseFrame? _lastFrame;
  List<Offset> _trail = const [];
  DateTime? _trailAt;
  bool _lastFlash = false;
  late final DateTime _startedAt;
  Timer? _ticker;
  final List<StreamSubscription<Object?>> _subs = [];
  final List<Map<String, dynamic>> _highlights = [];

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    final session = ref.read(activeSessionProvider);
    if (session != null) {
      _subs.add(session.coach.captions
          .listen((c) => setState(() => _caption = c.text)));
      _subs.add(session.orchestrator.stats.listen(_onStats));
      _subs.add(session.orchestrator.phase
          .listen((p) => setState(() => _phase = p)));
      _subs.add(session.orchestrator.processor.shots.listen(_onShot));
      _subs.add(session.poseSource.frames
          .listen((f) => setState(() => _lastFrame = f)));
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = ref.read(activeSessionProvider);
      s?.orchestrator.tick();
      // Fade the wrist trail 1.2s after the swing.
      if (_trailAt != null &&
          DateTime.now().difference(_trailAt!).inMilliseconds > 1200 &&
          _trail.isNotEmpty) {
        setState(() => _trail = const []);
      }
      setState(() {});
    });
  }

  void _onStats(LiveStats stats) {
    setState(() {
      _stats = stats;
      _lastFlash = true;
    });
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _lastFlash = false);
    });
  }

  void _onShot(ShotEvent event) {
    // Normalized wrist coords (torso units, hip origin) → rough view-space
    // fractions for the trail overlay; mirrored to match a selfie preview.
    final mirror =
        ref.read(activeSessionProvider)?.cameraSource?.isFrontCamera ?? false;
    final xSign = mirror ? -0.12 : 0.12;
    setState(() {
      _trail = [
        for (final p in event.wristTrail)
          Offset(0.5 + p[0] * xSign, 0.55 - p[1] * 0.18),
      ];
      _trailAt = DateTime.now();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _end() async {
    final session = ref.read(activeSessionProvider);
    if (session == null) {
      if (mounted) context.go('/home');
      return;
    }
    final result = await session.orchestrator.end(highlights: _highlights);
    await ref.read(activeSessionProvider.notifier).stop();
    await WakelockPlus.disable();
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    if (mounted) context.pushReplacement('/summary/${result.sessionId}');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    final controller = session?.cameraSource?.controller;
    final source = session?.cameraSource;
    final paused = _phase == SessionPhase.paused;
    final elapsed = DateTime.now().difference(_startedAt);
    final mm = '${elapsed.inMinutes}'.padLeft(2, '0');
    final ss = '${elapsed.inSeconds % 60}'.padLeft(2, '0');
    final type = session?.orchestrator.config.type ?? 'session';

    return Scaffold(
      backgroundColor: RcColors.line,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            Opacity(
                opacity: paused ? 0.4 : 0.85,
                child: CameraPreview(controller)),
          if (!paused && _lastFrame != null && source?.lastSourceSize != null)
            SkeletonOverlay(
              frame: _lastFrame,
              sourceWidth: source!.lastSourceSize!.width,
              sourceHeight: source.lastSourceSize!.height,
              mirror: source.isFrontCamera,
            ),
          if (!paused && _trail.length > 1) WristTrail(points: _trail),
          if (session?.cameraSource?.thermalFallbackActive ?? false)
            Positioned(
              top: 12,
              right: 64,
              child: Text('Cooling down — analysis simplified',
                  style: RcType.caption.copyWith(color: RcColors.clay)),
            ),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(type.toUpperCase(),
                          style: RcType.heading
                              .copyWith(color: RcColors.court, fontSize: 16)),
                      if (_stats.isSessionBest && _lastFlash) ...[
                        const SizedBox(width: 12),
                        Text('NEW BEST',
                            style: RcType.heading.copyWith(
                                color: RcColors.ball, fontSize: 16)),
                      ],
                      const Spacer(),
                      Text('$mm:$ss',
                          style: RcType.stat.copyWith(
                              color: RcColors.court.withValues(alpha: 0.8))),
                      IconButton(
                        icon: Icon(paused ? Icons.play_arrow : Icons.pause,
                            color: RcColors.court),
                        onPressed: () {
                          final o = session?.orchestrator;
                          if (o == null) return;
                          paused ? o.resume() : o.pause();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmark_border,
                            color: RcColors.court),
                        onPressed: () {
                          final offsetMs = DateTime.now()
                              .difference(_startedAt)
                              .inMilliseconds;
                          setState(() {
                            _highlights.add({
                              'tOffsetMs': offsetMs,
                              'shotIndex':
                                  session?.orchestrator.currentStats.shots ?? 0,
                            });
                          });
                          HapticFeedback.lightImpact();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.stop_circle_outlined,
                            color: RcColors.ball),
                        onPressed: _end,
                      ),
                    ],
                  ),
                  if (!paused && _stats.focusMetricId != null)
                    Text(
                      'FOCUS · '
                      '${(metricLabels[_stats.focusMetricId] ?? _stats.focusMetricId!.replaceAll('_', ' ')).toUpperCase()}',
                      style: RcType.caption.copyWith(
                          color: RcColors.ball,
                          fontWeight: FontWeight.w700),
                    ),
                  const Spacer(),
                  Center(
                      child: CaptionBar(
                          text: paused
                              ? 'PAUSED — step back in when ready'
                              : _caption)),
                  const SizedBox(height: 12),
                  if (!paused && _stats.recentScores.length >= 2) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: _ScoreSparkline(scores: _stats.recentScores),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _LiveStat(label: 'SHOTS', value: '${_stats.shots}'),
                      _LiveStat(
                        label: 'LAST',
                        value: '${_stats.lastScore}',
                        highlight: _lastFlash,
                      ),
                      _LiveStat(label: 'AVG', value: '${_stats.avgScore}'),
                      _LiveStat(
                        label: 'STREAK',
                        value: '${_stats.cleanStreak}',
                        highlight: _stats.cleanStreak >= 3,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Last-12-shots score bars — readable from across the court: taller and
/// greener is better, clay marks the below-average dips.
class _ScoreSparkline extends StatelessWidget {
  const _ScoreSparkline({required this.scores});

  final List<int> scores;

  @override
  Widget build(BuildContext context) {
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    return SizedBox(
      height: 28,
      width: 12.0 * scores.length,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var s = 0; s < scores.length; s++) ...[
            if (s > 0) const SizedBox(width: 3),
            Container(
              width: 9,
              height: 4 + (scores[s].clamp(0, 100) / 100) * 24,
              decoration: BoxDecoration(
                color: scores[s] >= avg
                    ? RcColors.ball
                    : RcColors.court.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveStat extends StatelessWidget {
  const _LiveStat(
      {required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label,
              style: RcType.caption
                  .copyWith(color: RcColors.court.withValues(alpha: 0.7))),
          const SizedBox(width: 8),
          // LAST flashes ball-green for 800ms on each shot (DESIGN 2.4).
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: RcType.stat.copyWith(
              fontSize: 32,
              color: highlight ? RcColors.ball : RcColors.court,
            ),
            child: Text(value),
          ),
        ],
      );
}
