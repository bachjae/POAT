/// Phase segmentation by kinematic events (SPEC §7).
///
/// Port of `python_lab/engine_math.py` — keep in lockstep.
library;

import 'engine_types.dart';
import 'normalizer.dart';
import 'shot_detector.dart';

/// Serve: racket-drop = lowest wrist point AFTER the trophy and before
/// contact. Trophy = first frame the dominant wrist rises above shoulder
/// height. (The generic rearmost-projection rule picks the address stance
/// for serves, so this overrides it.)
int serveBackswingFrame(List<TimedKeypoints> frames, int start, int peak) {
  if (peak - start < 2) return start;
  var trophyI = start;
  for (var i = start; i <= peak; i++) {
    final kp = frames[i].keypoints;
    final shoMidY = (kp[Kp.leftShoulder][1] + kp[Kp.rightShoulder][1]) / 2.0;
    if (kp[Kp.rightWrist][1] >= shoMidY) {
      trophyI = i;
      break;
    }
  }
  var bestI = trophyI;
  var bestY = double.infinity;
  for (var i = trophyI; i <= peak; i++) {
    final y = frames[i].keypoints[Kp.rightWrist][1];
    if (y < bestY) {
      bestY = y;
      bestI = i;
    }
  }
  return bestI;
}

/// Mean shoulder-line angle over a centered window — damps keypoint jitter
/// so prep-onset detection doesn't fire on noise.
double _smoothedShoulderDeg(List<TimedKeypoints> frames, int i, {int half = 2}) {
  final lo = i - half < 0 ? 0 : i - half;
  final hi = i + half > frames.length - 1 ? frames.length - 1 : i + half;
  var total = 0.0;
  double? base;
  var count = 0;
  for (var j = lo; j <= hi; j++) {
    final a = jointAngles(frames[j].keypoints).shoulderLineDeg;
    base ??= a;
    total += base + wrapDeg(a - base);
    count++;
  }
  return total / count;
}

/// Smoothed shoulder-line angular speed (deg/s) at frame [i].
double trunkRotationSpeed(List<TimedKeypoints> frames, int i) {
  if (i == 0) return 0.0;
  final a = _smoothedShoulderDeg(frames, i - 1);
  final b = _smoothedShoulderDeg(frames, i);
  final dt = (frames[i].timestampMs - frames[i - 1].timestampMs) / 1000.0;
  if (dt <= 0) return 0.0;
  return wrapDeg(b - a).abs() / dt;
}

/// Boundary events per SPEC §7.
ShotPhases segmentPhases(
  List<TimedKeypoints> frames,
  ShotWindow shot,
  Stroke stroke, {
  double trunkSpeedThreshold = 90.0,
}) {
  final s = shot.start, p = shot.peak, e = shot.end;
  final bw = stroke == Stroke.serve
      ? serveBackswingFrame(frames, s, p)
      : backswingFrame(frames, s, p);
  // Prep onset: two consecutive frames of sustained trunk rotation, so a
  // single noisy frame can't trigger it.
  var prep = bw;
  for (var i = s; i < bw; i++) {
    if (trunkRotationSpeed(frames, i) > trunkSpeedThreshold &&
        trunkRotationSpeed(frames, i + 1) > trunkSpeedThreshold) {
      prep = i;
      break;
    }
  }
  final speeds = wristSpeeds(frames);
  final peakSpeed = speeds[p];
  var followEnd = e;
  for (var i = p + 1; i <= e; i++) {
    if (speeds[i] < 0.2 * peakSpeed) {
      followEnd = i;
      break;
    }
  }
  return ShotPhases(prep: prep, backswing: bw, contact: p, followEnd: followEnd);
}
