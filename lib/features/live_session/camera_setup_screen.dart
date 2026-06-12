/// Camera setup (DESIGN 2.3, landscape): prop the phone, get locked, BEGIN.
library;

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/engine/engine_types.dart';
import '../../core/session/shot_processor.dart';
import '../../shared/widgets/rc_widgets.dart';
import '../../shared/widgets/skeleton_overlay.dart';

class CameraSetupScreen extends ConsumerStatefulWidget {
  const CameraSetupScreen({super.key});

  @override
  ConsumerState<CameraSetupScreen> createState() => _CameraSetupScreenState();
}

class _CameraSetupScreenState extends ConsumerState<CameraSetupScreen> {
  ActiveSession? _session;
  PlayerVisibility _visibility = PlayerVisibility.searching;
  PoseFrame? _lastFrame;
  String? _error;
  StreamSubscription<Object?>? _visSub;
  StreamSubscription<PoseFrame>? _frameSub;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    WakelockPlus.enable();
    _start();
  }

  Future<void> _start() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() => _error = status.isPermanentlyDenied
            ? 'Camera permission denied.\nGo to Settings → Apps → RallyCoach → Permissions and enable Camera.'
            : 'Camera permission is required to coach your technique.');
      }
      return;
    }
    try {
      final session =
          await ref.read(activeSessionProvider.notifier).start();
      _visSub = session.orchestrator.processor.visibility
          .listen((v) => setState(() => _visibility = v));
      _frameSub = session.poseSource.frames
          .listen((f) => setState(() => _lastFrame = f));
      await session.orchestrator.beginSetup();
      if (mounted) setState(() => _session = session);
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'Camera unavailable — check the camera permission and retry.');
      }
    }
  }

  @override
  void dispose() {
    _visSub?.cancel();
    _frameSub?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _close() async {
    // Reset orientation BEFORE popping so the previous screen never
    // briefly renders in landscape (causes RenderFlex overflow).
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await ref.read(activeSessionProvider.notifier).stop();
    await WakelockPlus.disable();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final controller = session?.cameraSource?.controller;
    final source = session?.cameraSource;
    final locked = _visibility == PlayerVisibility.locked;
    final view = session?.orchestrator.processor.majorityView;

    return Scaffold(
      backgroundColor: RcColors.line,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            Opacity(opacity: 0.8, child: CameraPreview(controller))
          else
            Center(
              child: Text(
                _error ?? 'Starting camera…',
                style: RcType.body.copyWith(color: RcColors.court),
                textAlign: TextAlign.center,
              ),
            ),
          if (_lastFrame != null && source?.lastSourceSize != null)
            SkeletonOverlay(
              frame: _lastFrame,
              sourceWidth: source!.lastSourceSize!.width,
              sourceHeight: source.lastSourceSize!.height,
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: RcColors.court),
                      onPressed: _close,
                    ),
                  ),
                  const Spacer(),
                  RcStatusChip(
                    text: locked
                        ? 'I CAN SEE YOU — view: ${view?.id.replaceAll('_', ' ') ?? ''}'
                        : 'Prop the phone and step onto court',
                    dotColor: locked ? RcColors.ballText : RcColors.lineDim,
                    pulsing: !locked,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 220,
                    child: RcPrimaryButton(
                      label: 'Begin',
                      onPressed: session == null
                          ? null
                          : () {
                              session.orchestrator.beginLive();
                              context.pushReplacement('/live');
                            },
                    ),
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
