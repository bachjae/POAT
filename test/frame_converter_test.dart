/// Rotation + letterbox mapping of the camera frame converter, verified
/// pixel-for-pixel against a PIL reference implementation offline.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallycoach/core/camera/frame_converter.dart';

void main() {
  // 4×2 BGRA source; R channel encodes the pixel as 16x+y, G=100, B=200.
  const w = 4, h = 2;
  final bgra = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = (y * w + x) * 4;
      bgra[p] = 200; // B
      bgra[p + 1] = 100; // G
      bgra[p + 2] = 16 * x + y; // R
      bgra[p + 3] = 255; // A
    }
  }

  int red(ConvertedFrame f, int ox, int oy) =>
      f.image.bytes[(oy * f.image.width + ox) * 3];

  test('rotation 0 letterboxes 4×2 into the middle of a 4×4 square', () {
    final f = bgraToRgb(
        width: w, height: h, bgra: bgra, rowStride: w * 4, outSize: 4);
    expect(f.uprightWidth, w);
    expect(f.uprightHeight, h);
    expect(f.scale, 1.0);
    expect(f.padX, 0.0);
    expect(f.padY, 1.0);
    // Top and bottom rows are letterbox black.
    expect(red(f, 0, 0), 0);
    expect(red(f, 3, 3), 0);
    // Content rows are the source rows.
    expect(red(f, 0, 1), 16 * 0 + 0);
    expect(red(f, 3, 1), 16 * 3 + 0);
    expect(red(f, 2, 2), 16 * 2 + 1);
  });

  test('rotation 90 produces an upright 2×4 column, pillarboxed', () {
    final f = bgraToRgb(
        width: w,
        height: h,
        bgra: bgra,
        rowStride: w * 4,
        outSize: 4,
        rotationDegrees: 90);
    expect(f.uprightWidth, h);
    expect(f.uprightHeight, w);
    expect(f.scale, 1.0);
    expect(f.padX, 1.0);
    expect(f.padY, 0.0);
    // Pillarbox columns are black.
    expect(red(f, 0, 0), 0);
    expect(red(f, 3, 3), 0);
    // 90° CW: rotated(rx, ry) = source(ry, h-1-rx); output ox = rx + padX.
    expect(red(f, 1, 0), 16 * 0 + 1); // rx=0, ry=0 → src(0, 1)
    expect(red(f, 2, 0), 16 * 0 + 0); // rx=1, ry=0 → src(0, 0)
    expect(red(f, 1, 3), 16 * 3 + 1); // rx=0, ry=3 → src(3, 1)
    expect(red(f, 2, 3), 16 * 3 + 0); // rx=1, ry=3 → src(3, 0)
  });

  test('rotation 180 flips both axes', () {
    final f = bgraToRgb(
        width: w,
        height: h,
        bgra: bgra,
        rowStride: w * 4,
        outSize: 4,
        rotationDegrees: 180);
    expect(red(f, 0, 1), 16 * 3 + 1); // rx=0, ry=0 → src(3, 1)
    expect(red(f, 3, 2), 16 * 0 + 0); // rx=3, ry=1 → src(0, 0)
  });

  test('rotation 270 mirrors the 90 case', () {
    final f = bgraToRgb(
        width: w,
        height: h,
        bgra: bgra,
        rowStride: w * 4,
        outSize: 4,
        rotationDegrees: 270);
    // 270°: rotated(rx, ry) = source(w-1-ry, rx); output ox = rx + padX.
    expect(red(f, 1, 0), 16 * 3 + 0); // rx=0, ry=0 → src(3, 0)
    expect(red(f, 2, 3), 16 * 0 + 1); // rx=1, ry=3 → src(0, 1)
  });

  test('keypoint back-mapping inverts the letterbox', () {
    final f = bgraToRgb(
        width: w,
        height: h,
        bgra: bgra,
        rowStride: w * 4,
        outSize: 4,
        rotationDegrees: 90);
    // A model hit at normalized (0.5, 0.5) of the 4×4 input → upright
    // source coords ((2 - padX) / scale, (2 - padY) / scale) = (1, 2).
    final x = (0.5 * 4 - f.padX) / f.scale;
    final y = (0.5 * 4 - f.padY) / f.scale;
    expect(x, 1.0);
    expect(y, 2.0);
  });
}
