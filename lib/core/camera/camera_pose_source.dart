/// Live camera → MoveNet pose stream (SPEC §3).
///
/// Frames flow camera → convert → MoveNet → PoseFrame and are discarded;
/// no `File` writes exist anywhere in this path (PRD privacy requirement).
/// FPS throttles 24/15/10 and the thermal listener drops to Lightning@10
/// on serious throttling. Device-only by design — excluded from unit tests.
library;

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:thermal/thermal.dart';

import '../engine/engine_types.dart';
import '../pose/movenet_runner.dart';
import '../pose/pose_source.dart';
import 'frame_converter.dart';

class CameraPoseSource implements PoseSource {
  CameraPoseSource({this.targetFps = 15});

  int targetFps;

  final _frames = StreamController<PoseFrame>.broadcast();
  CameraController? _controller;
  MoveNetRunner? _runner;
  StreamSubscription<ThermalStatus>? _thermalSub;
  int _lastFrameMs = 0;
  bool _inferring = false;
  bool _thermalFallback = false;

  @override
  Stream<PoseFrame> get frames => _frames.stream;

  /// Exposed for the camera-preview widget.
  CameraController? get controller => _controller;

  /// Dimensions of the frames the keypoints are expressed in (set after the
  /// first streamed image) — the skeleton overlay maps through these.
  ({int width, int height})? lastSourceSize;

  bool get thermalFallbackActive => _thermalFallback;

  @override
  Future<void> start() async {
    final cameras = await availableCameras();
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _controller = CameraController(
      back,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();
    _runner = await MoveNetRunner.load(MoveNetVariant.thunder);
    _thermalSub = Thermal().onThermalStatusChanged.listen(_onThermal);
    await _controller!.startImageStream(_onImage);
  }

  Future<void> _onThermal(ThermalStatus status) async {
    final serious = status.index >= ThermalStatus.severe.index;
    if (serious && !_thermalFallback) {
      _thermalFallback = true;
      targetFps = 10;
      final old = _runner;
      _runner = await MoveNetRunner.load(MoveNetVariant.lightning);
      await old?.dispose();
    }
  }

  Future<void> _onImage(CameraImage image) async {
    final runner = _runner;
    if (runner == null || _inferring) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastFrameMs < 1000 ~/ targetFps) return;
    _lastFrameMs = nowMs;
    lastSourceSize = (width: image.width, height: image.height);
    _inferring = true;
    try {
      final RgbImage rgb;
      if (image.format.group == ImageFormatGroup.bgra8888) {
        rgb = bgraToRgb(
          width: image.width,
          height: image.height,
          bgra: image.planes[0].bytes,
          rowStride: image.planes[0].bytesPerRow,
          outSize: runner.variant.inputSize,
        );
      } else {
        rgb = yuv420ToRgb(
          width: image.width,
          height: image.height,
          yPlane: image.planes[0].bytes,
          uPlane: image.planes[1].bytes,
          vPlane: image.planes[2].bytes,
          yRowStride: image.planes[0].bytesPerRow,
          uvRowStride: image.planes[1].bytesPerRow,
          uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
          outSize: runner.variant.inputSize,
        );
      }
      final pose = await runner.estimate(
        rgb,
        timestampMs: nowMs,
        sourceWidth: image.width,
        sourceHeight: image.height,
      );
      if (!_frames.isClosed) _frames.add(pose);
    } finally {
      _inferring = false;
    }
  }

  @override
  Future<void> stop() async {
    await _thermalSub?.cancel();
    final c = _controller;
    _controller = null;
    if (c != null) {
      if (c.value.isStreamingImages) await c.stopImageStream();
      await c.dispose();
    }
    await _runner?.dispose();
    _runner = null;
  }
}
