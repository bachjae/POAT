/// Live camera → MoveNet pose stream (SPEC §3).
///
/// Frames flow camera → pose isolate (rotate/letterbox/convert + MoveNet)
/// → smooth → PoseFrame and are discarded; no `File` writes exist anywhere
/// in this path (PRD privacy requirement). Frames are rotated upright before
/// inference (MoveNet is trained on upright people — feeding raw sensor
/// orientation is why detection used to fail on mounted phones) and
/// letterboxed so the player is never stretched. Output keypoints are
/// One-Euro smoothed to kill estimator jitter without lagging real swings.
///
/// Supports the back camera (default, court-mount) and the front/selfie
/// camera (so the player can watch what the app detects); [switchCamera]
/// flips live during setup.
///
/// FPS throttles 24/15/10 and the thermal listener drops to Lightning@10
/// on serious throttling. Device-only by design — excluded from unit tests.
library;

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:thermal/thermal.dart';

import '../engine/engine_types.dart';
import '../pose/movenet_runner.dart';
import '../pose/pose_smoother.dart';
import '../pose/pose_source.dart';

const _orientationDegrees = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

class CameraPoseSource implements PoseSource {
  CameraPoseSource({this.targetFps = 24, bool preferFrontCamera = false})
      : _preferFront = preferFrontCamera;

  int targetFps;

  final _frames = StreamController<PoseFrame>.broadcast();
  final _smoother = PoseSmoother();
  List<CameraDescription>? _cameras;
  CameraController? _controller;
  CameraDescription? _camera;
  MoveNetRunner? _runner;
  StreamSubscription<ThermalStatus>? _thermalSub;
  int _lastFrameMs = 0;
  bool _inferring = false;
  Future<void>? _inFlight;
  bool _thermalFallback = false;
  bool _preferFront;
  bool _switching = false;

  @override
  Stream<PoseFrame> get frames => _frames.stream;

  /// Exposed for the camera-preview widget.
  CameraController? get controller => _controller;

  /// Dimensions of the UPRIGHT frame the keypoints are expressed in (set
  /// after the first streamed image) — the skeleton overlay maps through
  /// these.
  ({int width, int height})? lastSourceSize;

  bool get thermalFallbackActive => _thermalFallback;

  /// True when the selfie camera is active — the preview is mirrored, so
  /// overlays must mirror to match.
  bool get isFrontCamera =>
      _camera?.lensDirection == CameraLensDirection.front;

  /// True when the device has both a front and a back camera.
  bool get canSwitchCamera {
    final cams = _cameras;
    if (cams == null) return false;
    return cams.any((c) => c.lensDirection == CameraLensDirection.front) &&
        cams.any((c) => c.lensDirection == CameraLensDirection.back);
  }

  @override
  Future<void> start() async {
    _cameras = await availableCameras();
    _runner = await MoveNetRunner.load(MoveNetVariant.thunder);
    _thermalSub = Thermal().onThermalStatusChanged.listen(_onThermal);
    await _startController();
  }

  CameraDescription _pickCamera() {
    final cams = _cameras!;
    final wanted = _preferFront
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    return cams.firstWhere((c) => c.lensDirection == wanted,
        orElse: () => cams.first);
  }

  Future<void> _startController() async {
    final camera = _pickCamera();
    _camera = camera;
    final controller = CameraController(
      camera,
      // 720p: enough pixel density that the player still spans a useful
      // share of the MoveNet crop from fence-mount distance.
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );
    _controller = controller;
    await controller.initialize();
    await controller.startImageStream(_onImage);
  }

  /// Flips between the back and selfie cameras without tearing down the
  /// runner or the frames stream (subscribers keep flowing).
  Future<void> switchCamera() async {
    if (_switching || !canSwitchCamera) return;
    _switching = true;
    try {
      _preferFront = !_preferFront;
      final old = _controller;
      _controller = null;
      if (old != null) {
        if (old.value.isStreamingImages) await old.stopImageStream();
        await old.dispose();
      }
      try {
        await _inFlight;
      } catch (_) {}
      _smoother.reset();
      await _startController();
    } finally {
      _switching = false;
    }
  }

  /// Degrees the sensor image must be rotated clockwise to be upright in
  /// the current device orientation (google_mlkit reference math).
  int _rotationDegrees() {
    final camera = _camera;
    final controller = _controller;
    if (camera == null || controller == null) return 0;
    final sensor = camera.sensorOrientation;
    if (Platform.isIOS) return sensor;
    final device =
        _orientationDegrees[controller.value.deviceOrientation] ?? 0;
    return camera.lensDirection == CameraLensDirection.front
        ? (sensor + device) % 360
        : (sensor - device + 360) % 360;
  }

  Future<void> _onThermal(ThermalStatus status) async {
    final serious = status.index >= ThermalStatus.severe.index;
    if (serious && !_thermalFallback) {
      _thermalFallback = true;
      targetFps = 10;
      final old = _runner;
      _runner = await MoveNetRunner.load(MoveNetVariant.lightning);
      // The in-flight estimate may still hold the old interpreter.
      try {
        await _inFlight;
      } catch (_) {}
      await old?.dispose();
    } else if (!serious && !_thermalFallback) {
      // Mid-tier throttle: shed frames before shedding model accuracy.
      targetFps = status.index >= ThermalStatus.moderate.index ? 15 : 24;
    }
  }

  Future<void> _onImage(CameraImage image) async {
    final runner = _runner;
    if (runner == null || _inferring || _switching) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastFrameMs < 1000 ~/ targetFps) return;
    _lastFrameMs = nowMs;
    _inferring = true;
    final work = _processImage(image, runner, nowMs);
    _inFlight = work;
    try {
      await work;
    } catch (_) {
      // A failed frame (e.g. mid camera-switch or runner teardown) is
      // dropped; the stream keeps flowing.
    } finally {
      _inferring = false;
    }
  }

  Future<void> _processImage(
      CameraImage image, MoveNetRunner runner, int nowMs) async {
    final rotation = _rotationDegrees();
    final upright = rotation % 180 == 0
        ? (width: image.width, height: image.height)
        : (width: image.height, height: image.width);
    lastSourceSize = upright;
    final PoseFrame pose;
    if (image.format.group == ImageFormatGroup.bgra8888) {
      pose = await runner.estimateBgra8888(
        width: image.width,
        height: image.height,
        bgra: image.planes[0].bytes,
        rowStride: image.planes[0].bytesPerRow,
        rotationDegrees: rotation,
        timestampMs: nowMs,
      );
    } else {
      pose = await runner.estimateYuv420(
        width: image.width,
        height: image.height,
        yPlane: image.planes[0].bytes,
        uPlane: image.planes[1].bytes,
        vPlane: image.planes[2].bytes,
        yRowStride: image.planes[0].bytesPerRow,
        uvRowStride: image.planes[1].bytesPerRow,
        uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
        rotationDegrees: rotation,
        timestampMs: nowMs,
      );
    }
    final smoothed = _smoother.smooth(
      pose,
      width: upright.width,
      height: upright.height,
    );
    if (!_frames.isClosed) _frames.add(smoothed);
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
    final runner = _runner;
    _runner = null;
    try {
      await _inFlight;
    } catch (_) {}
    await runner?.dispose();
    _smoother.reset();
  }
}
