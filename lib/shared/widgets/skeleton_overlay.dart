/// Pose skeleton overlay drawn in court-line white over the camera preview.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/engine/engine_types.dart';

const _bones = [
  (Kp.leftShoulder, Kp.rightShoulder),
  (Kp.leftShoulder, Kp.leftElbow),
  (Kp.leftElbow, Kp.leftWrist),
  (Kp.rightShoulder, Kp.rightElbow),
  (Kp.rightElbow, Kp.rightWrist),
  (Kp.leftShoulder, Kp.leftHip),
  (Kp.rightShoulder, Kp.rightHip),
  (Kp.leftHip, Kp.rightHip),
  (Kp.leftHip, Kp.leftKnee),
  (Kp.leftKnee, Kp.leftAnkle),
  (Kp.rightHip, Kp.rightKnee),
  (Kp.rightKnee, Kp.rightAnkle),
];

class SkeletonOverlay extends StatelessWidget {
  const SkeletonOverlay({
    super.key,
    required this.frame,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  final PoseFrame? frame;
  final int sourceWidth;
  final int sourceHeight;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _SkeletonPainter(frame, sourceWidth, sourceHeight),
        size: Size.infinite,
      );
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter(this.frame, this.sourceWidth, this.sourceHeight);

  final PoseFrame? frame;
  final int sourceWidth;
  final int sourceHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame;
    if (f == null || sourceWidth == 0 || sourceHeight == 0) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    Offset? mapped(int i) {
      final p = f.keypoints[i];
      if (p[2] < kMinKeypointConf) return null;
      return Offset(
          p[0] / sourceWidth * size.width, p[1] / sourceHeight * size.height);
    }

    for (final (a, b) in _bones) {
      final pa = mapped(a);
      final pb = mapped(b);
      if (pa == null || pb == null) continue;
      canvas.drawLine(pa, pb, paint);
    }
    for (var i = 0; i < Kp.count; i++) {
      final p = mapped(i);
      if (p == null) continue;
      canvas.drawCircle(p, 3, Paint()..color = RcColors.ball);
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) => old.frame != frame;
}
