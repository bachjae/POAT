/// Core types for the technique engine.
///
/// This library is a 1:1 port of `python_lab/engine_math.py`; the shared
/// vectors in `test/fixtures/engine_vectors.json` assert parity within ±0.5.
/// Keep both sides in sync — any change here must be mirrored in Python and
/// the vectors regenerated.
library;

/// MoveNet SinglePose keypoint indices (17 points).
abstract final class Kp {
  static const nose = 0;
  static const leftEye = 1;
  static const rightEye = 2;
  static const leftEar = 3;
  static const rightEar = 4;
  static const leftShoulder = 5;
  static const rightShoulder = 6;
  static const leftElbow = 7;
  static const rightElbow = 8;
  static const leftWrist = 9;
  static const rightWrist = 10;
  static const leftHip = 11;
  static const rightHip = 12;
  static const leftKnee = 13;
  static const rightKnee = 14;
  static const leftAnkle = 15;
  static const rightAnkle = 16;
  static const count = 17;
}

const double kMinKeypointConf = 0.3;

enum ViewBucket {
  sideLeft('side_left'),
  sideRight('side_right'),
  front('front'),
  back('back'),
  diagonalLeft('diagonal_left'),
  diagonalRight('diagonal_right');

  const ViewBucket(this.id);
  final String id;

  bool get isSide => this == sideLeft || this == sideRight;
  bool get isDiagonal => this == diagonalLeft || this == diagonalRight;

  static ViewBucket fromId(String id) =>
      values.firstWhere((v) => v.id == id);
}

/// A raw pose estimate for one camera frame (image space, y down).
class PoseFrame {
  PoseFrame({required this.timestampMs, required this.keypoints})
      : assert(keypoints.length == Kp.count);

  final int timestampMs;

  /// 17 × [x, y, confidence] in image pixels.
  final List<List<double>> keypoints;
}

/// Hip-centered, torso-scaled, y-up frame (SPEC §5).
class NormalizedFrame {
  NormalizedFrame({
    required this.timestampMs,
    required this.keypoints,
    required this.torso,
    required this.view,
    required this.shoulderWidthRatio,
  });

  final int timestampMs;

  /// 17 × [x, y] in torso units, hip-mid origin, y up.
  final List<List<double>> keypoints;

  /// Image-space torso length in pixels (needed by the footwork analyzer).
  final double torso;
  final ViewBucket view;
  final double shoulderWidthRatio;
}

class JointAngles {
  const JointAngles({
    required this.elbowAngle,
    required this.kneeFlexion,
    required this.trunkTilt,
    required this.shoulderLineDeg,
    required this.hipLineDeg,
    required this.wristX,
    required this.wristY,
  });

  final double elbowAngle;
  final double kneeFlexion;
  final double trunkTilt;
  final double shoulderLineDeg;
  final double hipLineDeg;
  final double wristX;
  final double wristY;

  /// Torso units above hip-mid (same value as [wristY]; named per metric id).
  double get wristHeight => wristY;
}

enum Stroke {
  forehand('forehand'),
  backhand('backhand'),
  serve('serve'),
  volley('volley'),
  footwork('footwork');

  const Stroke(this.id);
  final String id;

  static Stroke fromId(String id) => values.firstWhere((s) => s.id == id);
}

class ShotWindow {
  const ShotWindow({
    required this.start,
    required this.peak,
    required this.end,
    required this.peakSpeed,
  });

  final int start;
  final int peak;
  final int end;
  final double peakSpeed;
}

class ShotPhases {
  const ShotPhases({
    required this.prep,
    required this.backswing,
    required this.contact,
    required this.followEnd,
  });

  final int prep;
  final int backswing;
  final int contact;
  final int followEnd;
}

class MetricDeviation {
  const MetricDeviation({
    required this.phase,
    required this.id,
    required this.value,
    required this.ideal,
    required this.direction,
    required this.severity,
    required this.weight,
    required this.cue,
  });

  final String phase;
  final String id;
  final double value;
  final List<double> ideal;

  /// 'low' or 'high'.
  final String direction;

  /// 0..1, how far outside the ideal band (1 = scored zero).
  final double severity;
  final double weight;

  /// Deterministic rule-engine cue text for this deviation.
  final String cue;
}

class ShotScore {
  const ShotScore({
    required this.score,
    required this.phaseScores,
    required this.deviations,
  });

  final double score;
  final Map<String, double> phaseScores;

  /// Sorted by severity × weight, descending (stable).
  final List<MetricDeviation> deviations;
}
