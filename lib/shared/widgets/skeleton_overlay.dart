/// Pose skeleton overlay drawn in court-line white over the camera preview.
///
/// The dominant arm also carries the live RACQUET tracker: a handle→tip shaft
/// (the forearm-extension estimate from `lib/core/engine/racquet.dart`, the
/// same model the engine scores) drawn in ball green so the player can see the
/// racquet the coach is reading.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/engine/engine_types.dart';
import '../../core/engine/racquet.dart';

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
    this.leftHanded = false,
  });

  final PoseFrame? frame;
  final int sourceWidth;
  final int sourceHeight;

  /// True for the selfie camera: its preview is mirrored, while keypoints
  /// are in unmirrored sensor space.
  final bool mirror;

  /// Dominant hand the racquet is drawn on (left wrist/elbow when true).
  final bool leftHanded;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter:
            _SkeletonPainter(frame, sourceWidth, sourceHeight, mirror, leftHanded),
        size: Size.infinite,
      );
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter(this.frame, this.sourceWidth, this.sourceHeight, this.mirror,
      this.leftHanded);

  final PoseFrame? frame;
  final int sourceWidth;
  final int sourceHeight;
  final bool mirror;
  final bool leftHanded;

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame;
    if (f == null || sourceWidth == 0 || sourceHeight == 0) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    Offset mapXy(double imgX, double imgY) {
      final x = mirror ? sourceWidth - imgX : imgX;
      return Offset(
          x / sourceWidth * size.width, imgY / sourceHeight * size.height);
    }

    Offset? mapped(int i) {
      final p = f.keypoints[i];
      if (p[2] < kMinKeypointConf) return null;
      return mapXy(p[0], p[1]);
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

    _paintRacquet(canvas, f, mapXy);
  }

  /// Draws the racquet shaft (handle→tip) on the dominant arm using the same
  /// forearm-extension model the engine scores, scaled into image pixels by
  /// the measured torso length.
  void _paintRacquet(
      Canvas canvas, PoseFrame f, Offset Function(double, double) mapXy) {
    final elbowI = leftHanded ? Kp.leftElbow : Kp.rightElbow;
    final wristI = leftHanded ? Kp.leftWrist : Kp.rightWrist;
    final elbow = f.keypoints[elbowI];
    final wrist = f.keypoints[wristI];
    if (elbow[2] < kMinKeypointConf || wrist[2] < kMinKeypointConf) return;

    var dx = wrist[0] - elbow[0], dy = wrist[1] - elbow[1];
    final norm = math.sqrt(dx * dx + dy * dy);
    if (norm < 1e-6) return;
    dx /= norm;
    dy /= norm;

    // Racquet length in image pixels = kRacquetLen × torso (hip-mid →
    // shoulder-mid); fall back to a forearm multiple if the trunk is unseen.
    final lSho = f.keypoints[Kp.leftShoulder], rSho = f.keypoints[Kp.rightShoulder];
    final lHip = f.keypoints[Kp.leftHip], rHip = f.keypoints[Kp.rightHip];
    double lengthPx;
    if (lSho[2] >= kMinKeypointConf &&
        rSho[2] >= kMinKeypointConf &&
        lHip[2] >= kMinKeypointConf &&
        rHip[2] >= kMinKeypointConf) {
      final shoX = (lSho[0] + rSho[0]) / 2, shoY = (lSho[1] + rSho[1]) / 2;
      final hipX = (lHip[0] + rHip[0]) / 2, hipY = (lHip[1] + rHip[1]) / 2;
      final torso = math.sqrt(
          (shoX - hipX) * (shoX - hipX) + (shoY - hipY) * (shoY - hipY));
      lengthPx = kRacquetLen * torso;
    } else {
      lengthPx = norm * 2.7; // ~racquet:forearm ratio
    }

    final handle = mapXy(wrist[0], wrist[1]);
    final throat =
        mapXy(wrist[0] + dx * lengthPx * kRacquetThroatFrac,
            wrist[1] + dy * lengthPx * kRacquetThroatFrac);
    final tip = mapXy(wrist[0] + dx * lengthPx, wrist[1] + dy * lengthPx);

    final shaft = Paint()
      ..color = RcColors.ball.withValues(alpha: 0.95)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(handle, throat, shaft);
    canvas.drawLine(throat, tip, shaft);
    // Open ellipse for the frame head, oriented along the shaft.
    final headLen = (tip - throat).distance;
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(math.atan2(tip.dy - handle.dy, tip.dx - handle.dx));
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset.zero, width: headLen * 0.9, height: headLen * 0.6),
      Paint()
        ..color = RcColors.ball.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) =>
      old.frame != frame ||
      old.mirror != mirror ||
      old.leftHanded != leftHanded;
}
