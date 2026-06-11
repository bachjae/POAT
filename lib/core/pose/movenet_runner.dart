/// MoveNet SinglePose inference via tflite_flutter (SPEC §4).
///
/// Thunder (256², default) or Lightning (192², thermal fallback). Runs
/// inside [IsolateInterpreter] so per-frame inference never blocks the UI
/// thread. Device-only by design — excluded from unit tests.
library;

import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../camera/frame_converter.dart';
import '../engine/engine_types.dart';

enum MoveNetVariant {
  thunder('assets/models/movenet_thunder.tflite', 256),
  lightning('assets/models/movenet_lightning.tflite', 192);

  const MoveNetVariant(this.assetPath, this.inputSize);

  final String assetPath;
  final int inputSize;
}

class MoveNetRunner {
  MoveNetRunner._(this.variant, this._interpreter, this._isolate,
      this._inputIsFloat);

  final MoveNetVariant variant;
  final Interpreter _interpreter;
  final IsolateInterpreter _isolate;

  /// f16 variants take float32 input (0–255 range); int8 variants take uint8.
  final bool _inputIsFloat;

  static Future<MoveNetRunner> load(MoveNetVariant variant) async {
    final interpreter = await Interpreter.fromAsset(
      variant.assetPath,
      options: InterpreterOptions()..threads = 2,
    );
    final isolate =
        await IsolateInterpreter.create(address: interpreter.address);
    final inputType = interpreter.getInputTensor(0).type;
    return MoveNetRunner._(
        variant, interpreter, isolate, inputType == TensorType.float32);
  }

  /// Runs pose estimation on an RGB frame already scaled to the model input
  /// size. Returns image-space keypoints for the ORIGINAL frame dimensions.
  Future<PoseFrame> estimate(
    RgbImage rgb, {
    required int timestampMs,
    required int sourceWidth,
    required int sourceHeight,
  }) async {
    final size = variant.inputSize;
    final Object input;
    if (_inputIsFloat) {
      final f = Float32List(size * size * 3);
      for (var i = 0; i < f.length; i++) {
        f[i] = rgb.bytes[i].toDouble();
      }
      input = f.reshape([1, size, size, 3]);
    } else {
      input = rgb.bytes.reshape([1, size, size, 3]);
    }
    // Output: [1, 1, 17, 3] as (y, x, score), normalized 0..1.
    final output = List.generate(
        1, (_) => List.generate(1, (_) => List.generate(17, (_) => List.filled(3, 0.0))));
    await _isolate.run(input, output);
    final kp = <List<double>>[
      for (var i = 0; i < 17; i++)
        [
          output[0][0][i][1] * sourceWidth,
          output[0][0][i][0] * sourceHeight,
          output[0][0][i][2],
        ],
    ];
    return PoseFrame(timestampMs: timestampMs, keypoints: kp);
  }

  Future<void> dispose() async {
    await _isolate.close();
    _interpreter.close();
  }
}
