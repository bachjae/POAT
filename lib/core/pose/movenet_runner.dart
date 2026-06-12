/// MoveNet SinglePose inference via tflite_flutter (SPEC §4).
///
/// Thunder (256², default) or Lightning (192², thermal fallback). The
/// interpreter runs with XNNPACK + 4 threads (several× faster than the
/// plain CPU path on the f16 models) inside a dedicated [PoseIsolate]:
/// camera bytes go in as flat typed data, keypoints come back as 51 floats,
/// and neither pixel conversion nor inference ever touches the UI thread.
/// Device-only by design — excluded from unit tests.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../engine/engine_types.dart';
import 'pose_isolate.dart';

enum MoveNetVariant {
  thunder('assets/models/movenet_thunder.tflite', 256),
  lightning('assets/models/movenet_lightning.tflite', 192);

  const MoveNetVariant(this.assetPath, this.inputSize);

  final String assetPath;
  final int inputSize;
}

class MoveNetRunner {
  MoveNetRunner._(this.variant, this._worker);

  final MoveNetVariant variant;
  final PoseIsolate _worker;

  static Future<MoveNetRunner> load(MoveNetVariant variant) async {
    // Load model bytes in the main isolate — rootBundle is platform-channel-
    // backed and can only be called here. The bytes are passed to the worker
    // which creates its own Interpreter (with XNNPACK) in its own OS thread.
    final modelData = await rootBundle.load(variant.assetPath);
    final modelBytes = modelData.buffer.asUint8List();

    // Quick synchronous probe to determine the input tensor type. We close
    // this interpreter immediately; the worker creates the real one.
    final probe = Interpreter.fromBuffer(modelBytes);
    final inputIsFloat = probe.getInputTensor(0).type == TensorType.float32;
    probe.close();

    final worker = await PoseIsolate.spawn(
      modelBytes: modelBytes,
      inputSize: variant.inputSize,
      inputIsFloat: inputIsFloat,
    );
    return MoveNetRunner._(variant, worker);
  }

  /// Android YUV420 camera frame → keypoints in UPRIGHT source coordinates
  /// (rotation + letterbox undone), so they overlay the preview and feed the
  /// engine in the player's real geometry.
  Future<PoseFrame> estimateYuv420({
    required int width,
    required int height,
    required Uint8List yPlane,
    required Uint8List uPlane,
    required Uint8List vPlane,
    required int yRowStride,
    required int uvRowStride,
    required int uvPixelStride,
    required int rotationDegrees,
    required int timestampMs,
  }) async {
    final kp = await _worker.infer(PoseFrameRequest.yuv420(
      width: width,
      height: height,
      yPlane: yPlane,
      uPlane: uPlane,
      vPlane: vPlane,
      yRowStride: yRowStride,
      uvRowStride: uvRowStride,
      uvPixelStride: uvPixelStride,
      rotationDegrees: rotationDegrees,
    ));
    return _toPoseFrame(kp, timestampMs);
  }

  /// iOS BGRA8888 camera frame → keypoints in UPRIGHT source coordinates.
  Future<PoseFrame> estimateBgra8888({
    required int width,
    required int height,
    required Uint8List bgra,
    required int rowStride,
    required int rotationDegrees,
    required int timestampMs,
  }) async {
    final kp = await _worker.infer(PoseFrameRequest.bgra8888(
      width: width,
      height: height,
      bgra: bgra,
      rowStride: rowStride,
      rotationDegrees: rotationDegrees,
    ));
    return _toPoseFrame(kp, timestampMs);
  }

  PoseFrame _toPoseFrame(Float32List kp, int timestampMs) => PoseFrame(
        timestampMs: timestampMs,
        keypoints: [
          for (var i = 0; i < 17; i++)
            [kp[i * 3], kp[i * 3 + 1], kp[i * 3 + 2]],
        ],
      );

  Future<void> dispose() async {
    await _worker.dispose();
  }
}
