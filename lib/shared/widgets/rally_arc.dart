/// The Rally Arc — the signature element.
///
/// A single 2.5dp ball-green arc drawn like a ball-flight path. It appears
/// in exactly four places: splash, live wrist-trail, summary underline, and
/// the progress chart line. Nowhere else.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

class RallyArc extends StatefulWidget {
  const RallyArc({
    super.key,
    this.width = 120,
    this.height = 36,
    this.animate = true,
    this.duration = const Duration(milliseconds: 600),
    this.strokeWidth = 2.5,
  });

  final double width;
  final double height;

  /// Draw-in animation (easeOutExpo). Renders static when false or when
  /// the platform requests reduced motion.
  final bool animate;
  final Duration duration;
  final double strokeWidth;

  @override
  State<RallyArc> createState() => _RallyArcState();
}

class _RallyArcState extends State<RallyArc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!widget.animate || reduceMotion) {
      return CustomPaint(
        size: Size(widget.width, widget.height),
        painter: _ArcPainter(progress: 1.0, strokeWidth: widget.strokeWidth),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size(widget.width, widget.height),
        painter: _ArcPainter(
          progress: Curves.easeOutExpo.transform(_controller.value),
          strokeWidth: widget.strokeWidth,
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress, required this.strokeWidth});

  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = RcColors.ball
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * 0.95)
      ..quadraticBezierTo(
        size.width * 0.45,
        -size.height * 0.55,
        size.width,
        size.height * 0.85,
      );
    final metrics = path.computeMetrics().first;
    canvas.drawPath(
        metrics.extractPath(0, metrics.length * progress), paint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.strokeWidth != strokeWidth;
}

/// The live wrist-trail variant: draws a fading polyline of recent wrist
/// positions (normalized 0..1 coordinates mapped into the widget size).
class WristTrail extends StatelessWidget {
  const WristTrail({super.key, required this.points, this.strokeWidth = 2.5});

  /// Most-recent-last wrist positions in view-space fractions (0..1).
  /// Each point fades by age; the painter expects ≤ ~36 points (1.2s @30fps).
  final List<Offset> points;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _TrailPainter(points: points, strokeWidth: strokeWidth),
        size: Size.infinite,
      );
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.points, required this.strokeWidth});

  final List<Offset> points;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    for (var i = 1; i < points.length; i++) {
      final age = (points.length - i) / points.length;
      final paint = Paint()
        ..color = RcColors.ball.withValues(alpha: (1.0 - age).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(points[i - 1].dx * size.width, points[i - 1].dy * size.height),
        Offset(points[i].dx * size.width, points[i].dy * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) => old.points != points;
}
