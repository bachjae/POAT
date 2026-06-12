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
    this.mirror = false,
  });

  final PoseFrame? frame;
  final int sourceWidth;
  final int sourceHeight;

  /// True for the selfie camera: its preview is mirrored, while keypoints
  /// are in unmirrored sensor space.
  final bool mirror;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _SkeletonPainter(frame, sourceWidth, sourceHeight, mirror),
        size: Size.infinite,
      );
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter(this.frame, this.sourceWidth, this.sourceHeight, this.mirror);

  final PoseFrame? frame;
  final int sourceWidth;
  final int sourceHeight;
  final bool mirror;

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
      final x = mirror ? sourceWidth - p[0] : p[0];
      return Offset(
          x / sourceWidth * size.width, p[1] / sourceHeight * size.height);
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
  bool shouldRepaint(_SkeletonPainter old) =>
      old.frame != frame || old.mirror != mirror;
}
