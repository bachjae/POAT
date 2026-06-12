/// Long-lived pose inference isolate (SPEC §4).
///
/// Owns the entire per-frame hot path off the UI isolate: camera bytes →
/// upright letterboxed RGB → MoveNet invoke → keypoints in upright source
/// coordinates. Messages in both directions are flat typed-data buffers,
/// which copy across isolates in microseconds.
///
/// This replaces tflite's [IsolateInterpreter], which required the input
/// tensor as nested Lists — ~200k boxed doubles serialized per frame, slower
/// than the inference itself — while the pixel conversion still ran on the
/// UI thread. Together those pushed effective pose throughput below 1 fps
/// on real devices ("standing in frame and it couldn't detect me").
///
/// Device-only by design — excluded from unit tests.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../camera/frame_converter.dart';

/// One camera frame's bytes + geometry, ready to cross the isolate boundary.
class PoseFrameRequest {
  PoseFrameRequest.yuv420({
    required int width,
    required int height,
    required Uint8List yPlane,
    required Uint8List uPlane,
    required Uint8List vPlane,
    required int yRowStride,
    required int uvRowStride,
    required int uvPixelStride,
    required int rotationDegrees,
  }) : _message = <Object>[
          _kYuv,
          width,
          height,
          rotationDegrees,
          yPlane,
          uPlane,
          vPlane,
          yRowStride,
          uvRowStride,
          uvPixelStride,
        ];

  PoseFrameRequest.bgra8888({
    required int width,
    required int height,
    required Uint8List bgra,
    required int rowStride,
    required int rotationDegrees,
  }) : _message = <Object>[_kBgra, width, height, rotationDegrees, bgra, rowStride];

  final List<Object> _message;

  static const _kYuv = 0;
  static const _kBgra = 1;
}

/// Spawns and talks to the worker. One request in flight at a time (the
/// camera source already drops frames while inference runs).
class PoseIsolate {
  PoseIsolate._(this._isolate, this._commands, this._responses);

  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _responses;
  Completer<Float32List>? _pending;
  bool _disposed = false;

  /// [interpreterAddress] is the UI-isolate Interpreter's native address;
  /// the worker reattaches via [Interpreter.fromAddress] and never closes it
  /// (the spawner keeps ownership).
  static Future<PoseIsolate> spawn({
    required int interpreterAddress,
    required int inputSize,
    required bool inputIsFloat,
  }) async {
    final responses = ReceivePort();
    final isolate = await Isolate.spawn(
      _workerMain,
      [responses.sendPort, interpreterAddress, inputSize, inputIsFloat],
      debugName: 'pose-inference',
    );
    final ready = Completer<SendPort>();
    late final PoseIsolate worker;
    responses.listen((Object? message) {
      if (!ready.isCompleted) {
        ready.complete(message as SendPort);
        return;
      }
      final pending = worker._pending;
      worker._pending = null;
      if (pending == null) return;
      if (message is Float32List) {
        pending.complete(message);
      } else {
        pending.completeError(StateError('pose isolate: $message'));
      }
    });
    final commands = await ready.future;
    return worker = PoseIsolate._(isolate, commands, responses);
  }

  /// Returns 17 × (x, y, score) flattened, in UPRIGHT source coordinates
  /// (letterbox already undone by the worker).
  Future<Float32List> infer(PoseFrameRequest request) {
    assert(_pending == null, 'one frame in flight at a time');
    if (_disposed) return Future.error(StateError('pose isolate disposed'));
    final completer = Completer<Float32List>();
    _pending = completer;
    _commands.send(request._message);
    return completer.future;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pending?.completeError(StateError('pose isolate disposed'));
    _pending = null;
    _commands.send(null);
    _responses.close();
    _isolate.kill(priority: Isolate.beforeNextEvent);
  }
}

Future<void> _workerMain(List<Object> init) async {
  final replies = init[0] as SendPort;
  final interpreter =
      Interpreter.fromAddress(init[1] as int, allocated: true);
  final inputSize = init[2] as int;
  final inputIsFloat = init[3] as bool;

  final commands = ReceivePort();
  replies.send(commands.sendPort);

  // Reused across frames so the float path allocates once, not per frame.
  final floatInput =
      inputIsFloat ? Float32List(inputSize * inputSize * 3) : null;

  await for (final Object? message in commands) {
    if (message == null) break;
    try {
      final msg = message as List<Object>;
      final kind = msg[0] as int;
      final width = msg[1] as int;
      final height = msg[2] as int;
      final rotation = msg[3] as int;
      final ConvertedFrame converted;
      if (kind == PoseFrameRequest._kYuv) {
        converted = yuv420ToRgb(
          width: width,
          height: height,
          yPlane: msg[4] as Uint8List,
          uPlane: msg[5] as Uint8List,
          vPlane: msg[6] as Uint8List,
          yRowStride: msg[7] as int,
          uvRowStride: msg[8] as int,
          uvPixelStride: msg[9] as int,
          outSize: inputSize,
          rotationDegrees: rotation,
        );
      } else {
        converted = bgraToRgb(
          width: width,
          height: height,
          bgra: msg[4] as Uint8List,
          rowStride: msg[5] as int,
          outSize: inputSize,
          rotationDegrees: rotation,
        );
      }

      final rgb = converted.image.bytes;
      final Uint8List tensorBytes;
      if (floatInput != null) {
        // f16 variants take float32 input in the 0–255 range.
        for (var i = 0; i < floatInput.length; i++) {
          floatInput[i] = rgb[i].toDouble();
        }
        tensorBytes = floatInput.buffer.asUint8List();
      } else {
        tensorBytes = rgb;
      }
      interpreter.getInputTensor(0).data = tensorBytes;
      interpreter.invoke();
      final outBytes = interpreter.getOutputTensor(0).data;
      // Output: [1, 1, 17, 3] float32 as (y, x, score), normalized 0..1.
      final raw =
          outBytes.buffer.asFloat32List(outBytes.offsetInBytes, 17 * 3);
      final kp = Float32List(17 * 3);
      for (var i = 0; i < 17; i++) {
        kp[i * 3] =
            ((raw[i * 3 + 1] * inputSize) - converted.padX) / converted.scale;
        kp[i * 3 + 1] =
            ((raw[i * 3] * inputSize) - converted.padY) / converted.scale;
        kp[i * 3 + 2] = raw[i * 3 + 2];
      }
      replies.send(kp);
    } catch (e) {
      replies.send('$e');
    }
  }
  commands.close();
}
