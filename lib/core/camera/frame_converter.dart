/// YUV420 / BGRA8888 → RGB conversion + nearest-neighbor downscale to the
/// MoveNet input size. Pure Dart so it is unit-testable and isolate-safe.
///
/// Frames are Uint8List in memory, released after inference — nothing in
/// this path ever touches disk (PRD privacy requirement).
library;

import 'dart:typed_data';

/// Packed RGB image bytes (3 bytes/pixel, row-major).
class RgbImage {
  const RgbImage({required this.width, required this.height, required this.bytes});

  final int width;
  final int height;
  final Uint8List bytes;
}

/// Android camera stream planes (Y, U, V) → RGB at [outSize]×[outSize].
RgbImage yuv420ToRgb({
  required int width,
  required int height,
  required Uint8List yPlane,
  required Uint8List uPlane,
  required Uint8List vPlane,
  required int yRowStride,
  required int uvRowStride,
  required int uvPixelStride,
  required int outSize,
}) {
  final out = Uint8List(outSize * outSize * 3);
  var o = 0;
  for (var oy = 0; oy < outSize; oy++) {
    final sy = (oy * height) ~/ outSize;
    for (var ox = 0; ox < outSize; ox++) {
      final sx = (ox * width) ~/ outSize;
      final yv = yPlane[sy * yRowStride + sx];
      final uvIndex = (sy >> 1) * uvRowStride + (sx >> 1) * uvPixelStride;
      final u = uPlane[uvIndex] - 128;
      final v = vPlane[uvIndex] - 128;
      var r = yv + (1.370705 * v).round();
      var g = yv - (0.337633 * u).round() - (0.698001 * v).round();
      var b = yv + (1.732446 * u).round();
      out[o++] = r < 0 ? 0 : (r > 255 ? 255 : r);
      out[o++] = g < 0 ? 0 : (g > 255 ? 255 : g);
      out[o++] = b < 0 ? 0 : (b > 255 ? 255 : b);
    }
  }
  return RgbImage(width: outSize, height: outSize, bytes: out);
}

/// iOS camera stream BGRA8888 → RGB at [outSize]×[outSize].
RgbImage bgraToRgb({
  required int width,
  required int height,
  required Uint8List bgra,
  required int rowStride,
  required int outSize,
}) {
  final out = Uint8List(outSize * outSize * 3);
  var o = 0;
  for (var oy = 0; oy < outSize; oy++) {
    final sy = (oy * height) ~/ outSize;
    for (var ox = 0; ox < outSize; ox++) {
      final sx = (ox * width) ~/ outSize;
      final p = sy * rowStride + sx * 4;
      out[o++] = bgra[p + 2];
      out[o++] = bgra[p + 1];
      out[o++] = bgra[p];
    }
  }
  return RgbImage(width: outSize, height: outSize, bytes: out);
}
