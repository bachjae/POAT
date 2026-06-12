/// YUV420 / BGRA8888 → RGB conversion with rotation to upright, an
/// aspect-preserving letterbox, and nearest-neighbor scale to the MoveNet
/// input size. Pure Dart so it is unit-testable and isolate-safe.
///
/// MoveNet is trained on upright, undistorted people. Camera streams arrive
/// in SENSOR orientation (usually landscape) and rarely square, so feeding
/// them raw both rotates and stretches the player — pose confidence
/// collapses and shot detection dies. [ConvertedFrame] carries the
/// letterbox mapping so keypoints can be projected back into upright
/// source coordinates exactly.
///
/// The output→source mapping is separable per axis, so each conversion
/// builds two small lookup tables (one per output axis) and the per-pixel
/// inner loop is pure index arithmetic — no calls, no divisions. The naive
/// per-pixel mapping was a measurable chunk of the live pose budget.
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

/// A model-input image plus the mapping back to upright source pixels.
///
/// `upright` source space is the camera frame AFTER rotation (the way the
/// player actually stands). A keypoint at normalized model coords (nx, ny)
/// maps back as:
///   x = (nx * image.width  - padX) / scale
///   y = (ny * image.height - padY) / scale
class ConvertedFrame {
  const ConvertedFrame({
    required this.image,
    required this.uprightWidth,
    required this.uprightHeight,
    required this.scale,
    required this.padX,
    required this.padY,
  });

  final RgbImage image;

  /// Source dimensions after rotation to upright.
  final int uprightWidth;
  final int uprightHeight;

  /// Upright-source → model-input scale factor (letterbox preserving).
  final double scale;

  /// Letterbox margins in model-input pixels.
  final double padX;
  final double padY;
}

(double, double, double) _letterbox(
    int width, int height, int rotationDegrees, int outSize) {
  final rw = rotationDegrees % 180 == 0 ? width : height;
  final rh = rotationDegrees % 180 == 0 ? height : width;
  final scale = rw > rh ? outSize / rw : outSize / rh;
  final padX = (outSize - rw * scale) / 2.0;
  final padY = (outSize - rh * scale) / 2.0;
  return (scale, padX, padY);
}

/// Per-axis output→source index tables. The rotation sends one output axis
/// to source-x and the other to source-y:
///   rot 0:   sx = col[ox], sy = row[oy]
///   rot 90:  sx = row[oy], sy = col[ox]
///   rot 180: sx = col[ox], sy = row[oy]
///   rot 270: sx = row[oy], sy = col[ox]
/// so [swapped] is true for 90/270. Entries are -1 in letterbox padding.
class _AxisMaps {
  _AxisMaps(this.col, this.row, this.swapped);

  final Int32List col;
  final Int32List row;
  final bool swapped;
}

_AxisMaps _buildAxisMaps({
  required int width,
  required int height,
  required int rotationDegrees,
  required int outSize,
  required double scale,
  required double padX,
  required double padY,
}) {
  final rw = rotationDegrees % 180 == 0 ? width : height;
  final rh = rotationDegrees % 180 == 0 ? height : width;
  final col = Int32List(outSize);
  final row = Int32List(outSize);
  for (var ox = 0; ox < outSize; ox++) {
    final rx = ((ox - padX) / scale).floor();
    col[ox] = rx < 0 || rx >= rw
        ? -1
        : switch (rotationDegrees) {
            90 => height - 1 - rx, // → sy
            180 => width - 1 - rx, // → sx
            270 => rx, // → sy
            _ => rx, // → sx
          };
  }
  for (var oy = 0; oy < outSize; oy++) {
    final ry = ((oy - padY) / scale).floor();
    row[oy] = ry < 0 || ry >= rh
        ? -1
        : switch (rotationDegrees) {
            90 => ry, // → sx
            180 => height - 1 - ry, // → sy
            270 => width - 1 - ry, // → sx
            _ => ry, // → sy
          };
  }
  return _AxisMaps(col, row, rotationDegrees % 180 != 0);
}

/// Android camera stream planes (Y, U, V) → upright RGB letterboxed into
/// [outSize]×[outSize]. [rotationDegrees] (0/90/180/270, clockwise) is how
/// far the sensor image must be rotated to stand upright.
ConvertedFrame yuv420ToRgb({
  required int width,
  required int height,
  required Uint8List yPlane,
  required Uint8List uPlane,
  required Uint8List vPlane,
  required int yRowStride,
  required int uvRowStride,
  required int uvPixelStride,
  required int outSize,
  int rotationDegrees = 0,
}) {
  final (scale, padX, padY) = _letterbox(width, height, rotationDegrees, outSize);
  final maps = _buildAxisMaps(
    width: width,
    height: height,
    rotationDegrees: rotationDegrees,
    outSize: outSize,
    scale: scale,
    padX: padX,
    padY: padY,
  );
  final col = maps.col, row = maps.row;
  final swapped = maps.swapped;
  final out = Uint8List(outSize * outSize * 3); // Padding stays black (0).
  var o = 0;
  for (var oy = 0; oy < outSize; oy++) {
    final b = row[oy];
    if (b < 0) {
      o += outSize * 3;
      continue;
    }
    for (var ox = 0; ox < outSize; ox++) {
      final a = col[ox];
      if (a < 0) {
        o += 3;
        continue;
      }
      final sx = swapped ? b : a;
      final sy = swapped ? a : b;
      final yv = yPlane[sy * yRowStride + sx];
      final uvIndex = (sy >> 1) * uvRowStride + (sx >> 1) * uvPixelStride;
      final u = uPlane[uvIndex] - 128;
      final v = vPlane[uvIndex] - 128;
      var r = yv + (1.370705 * v).round();
      var g = yv - (0.337633 * u).round() - (0.698001 * v).round();
      var b2 = yv + (1.732446 * u).round();
      out[o++] = r < 0 ? 0 : (r > 255 ? 255 : r);
      out[o++] = g < 0 ? 0 : (g > 255 ? 255 : g);
      out[o++] = b2 < 0 ? 0 : (b2 > 255 ? 255 : b2);
    }
  }
  return ConvertedFrame(
    image: RgbImage(width: outSize, height: outSize, bytes: out),
    uprightWidth: rotationDegrees % 180 == 0 ? width : height,
    uprightHeight: rotationDegrees % 180 == 0 ? height : width,
    scale: scale,
    padX: padX,
    padY: padY,
  );
}

/// iOS camera stream BGRA8888 → upright RGB letterboxed into
/// [outSize]×[outSize].
ConvertedFrame bgraToRgb({
  required int width,
  required int height,
  required Uint8List bgra,
  required int rowStride,
  required int outSize,
  int rotationDegrees = 0,
}) {
  final (scale, padX, padY) = _letterbox(width, height, rotationDegrees, outSize);
  final maps = _buildAxisMaps(
    width: width,
    height: height,
    rotationDegrees: rotationDegrees,
    outSize: outSize,
    scale: scale,
    padX: padX,
    padY: padY,
  );
  final col = maps.col, row = maps.row;
  final swapped = maps.swapped;
  final out = Uint8List(outSize * outSize * 3);
  var o = 0;
  for (var oy = 0; oy < outSize; oy++) {
    final b = row[oy];
    if (b < 0) {
      o += outSize * 3;
      continue;
    }
    for (var ox = 0; ox < outSize; ox++) {
      final a = col[ox];
      if (a < 0) {
        o += 3;
        continue;
      }
      final sx = swapped ? b : a;
      final sy = swapped ? a : b;
      final p = sy * rowStride + sx * 4;
      out[o++] = bgra[p + 2];
      out[o++] = bgra[p + 1];
      out[o++] = bgra[p];
    }
  }
  return ConvertedFrame(
    image: RgbImage(width: outSize, height: outSize, bytes: out),
    uprightWidth: rotationDegrees % 180 == 0 ? width : height,
    uprightHeight: rotationDegrees % 180 == 0 ? height : width,
    scale: scale,
    padX: padX,
    padY: padY,
  );
}
