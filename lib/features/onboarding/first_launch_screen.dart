/// First launch — "Meet your coach" (DESIGN 2.0, bundled-model edition).
///
/// The brain ships inside the install, so this is a one-time on-device
/// unpack with progress, not a download. No wifi, ever. If the build has no
/// bundled model (or the RAM gate fails) the screen explains Lite mode.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/brain/model_manager.dart';
import '../../shared/widgets/rally_arc.dart';
import '../../shared/widgets/rc_widgets.dart';

class FirstLaunchScreen extends ConsumerStatefulWidget {
  const FirstLaunchScreen({super.key});

  @override
  ConsumerState<FirstLaunchScreen> createState() => _FirstLaunchScreenState();
}

class _FirstLaunchScreenState extends ConsumerState<FirstLaunchScreen> {
  double _progress = 0;
  BrainStatus? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final manager = await ref.read(modelManagerProvider.future);
      final status = await manager.status;
      if (status == BrainStatus.ready) {
        setState(() => _status = BrainStatus.ready);
        return;
      }
      if (status == BrainStatus.absent && manager.liteOnly) {
        setState(() => _status = BrainStatus.absent);
        return;
      }
      await for (final p in manager.prepare()) {
        if (!mounted) return;
        setState(() => _progress = p);
      }
      if (!mounted) return;
      ref.invalidate(brainStatusProvider);
      setState(() => _status = BrainStatus.ready);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = BrainStatus.failed;
        _error = 'Setup paused — restart the app to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _status == BrainStatus.ready;
    final liteOnly = _status == BrainStatus.absent;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RcDims.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const RallyArc(width: 140, height: 44),
              const SizedBox(height: 24),
              const Text('MEET YOUR\nCOACH', style: RcType.display),
              const SizedBox(height: 20),
              const Text(
                "RallyCoach's brain is already on your phone — it shipped "
                'inside the app. One quick setup now, then it works '
                'anywhere. No wifi, no cloud, forever. Nothing you do is '
                'ever uploaded.',
                style: RcType.body,
              ),
              const Spacer(),
              if (liteOnly) ...[
                const Text('LITE MODE', style: RcType.heading),
                const SizedBox(height: 8),
                const Text(
                  'This build runs the rules-only coach. Every drill, cue '
                  'and summary still works — fully offline.',
                  style: RcType.bodyDim,
                ),
              ] else if (_error != null) ...[
                Text(_error!,
                    style: RcType.body.copyWith(color: RcColors.clay)),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(ready ? 'BRAIN READY' : 'GEMMA COACH BRAIN',
                        style: RcType.stat.copyWith(
                            color: ready
                                ? RcColors.ballText
                                : RcColors.lineDim)),
                    StatText(value: '${(_progress * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(RcDims.radius),
                  child: LinearProgressIndicator(
                    value: ready ? 1.0 : _progress,
                    minHeight: 4,
                    backgroundColor: RcColors.net,
                    valueColor:
                        const AlwaysStoppedAnimation(RcColors.ball),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              RcPrimaryButton(
                label: ready || liteOnly
                    ? 'Start playing'
                    : 'Practice while it unpacks',
                onPressed: () => context.go('/home'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
