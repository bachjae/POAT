/// Racquet tracking — the second tracker (SPEC §5a).
///
/// MoveNet has no racquet keypoints. A held racquet is, to first order, a
/// rigid extension of the forearm: it leaves the hand at the wrist and
/// continues along the elbow→wrist line. [racquetPose] returns a 3-point
/// racquet skeleton (handle butt at the hand, throat, frame tip) in the same
/// normalized torso units as the body — estimated from the forearm when no
/// optical detector is present, or taken straight from a detector when one is.
/// Everything downstream (metrics, scoring, cues) is identical either way, so
/// bundling a racquet detector model later is a drop-in upgrade.
///
/// 1:1 port of the racquet section of `python_lab/engine_math.py` — keep in
/// lockstep; the shared vectors assert parity.
library;

import 'dart:math' as math;

import 'engine_types.dart';
import 'normalizer.dart';
import 'shot_detector.dart';

/// Frame tip sits ~1.35 torso units beyond the hand: an adult torso
/// (hip-mid→shoulder-mid) is ~0.5 m and an adult racquet ~0.685 m.
const double kRacquetLen = 1.35;
const double kRacquetThroatFrac = 0.32;

double _dist(List<double> a, List<double> b) {
  final dx = a[0] - b[0];
  final dy = a[1] - b[1];
  return math.sqrt(dx * dx + dy * dy);
}

/// 3-point racquet skeleton `[handle, throat, tip]` in normalized units.
///
/// [detected]: optional `[handle, throat, tip]` from an optical racquet
/// detector (already normalized to torso units); when given it is returned
/// as-is. Otherwise the racquet is estimated as a rigid forearm extension
/// (dominant = right wrist after handedness mirroring).
List<List<double>> racquetPose(List<List<double>> nkp,
    {List<List<double>>? detected}) {
  if (detected != null) {
    return [List.of(detected[0]), List.of(detected[1]), List.of(detected[2])];
  }
  final wrist = nkp[Kp.rightWrist];
  final elbow = nkp[Kp.rightElbow];
  final dx = wrist[0] - elbow[0], dy = wrist[1] - elbow[1];
  final norm = math.sqrt(dx * dx + dy * dy);
  double ux, uy;
  if (norm < 1e-9) {
    ux = 0.0;
    uy = 1.0; // degenerate forearm → assume racquet points up
  } else {
    ux = dx / norm;
    uy = dy / norm;
  }
  final handle = [wrist[0], wrist[1]];
  final throat = [
    wrist[0] + ux * kRacquetLen * kRacquetThroatFrac,
    wrist[1] + uy * kRacquetLen * kRacquetThroatFrac,
  ];
  final tip = [wrist[0] + ux * kRacquetLen, wrist[1] + uy * kRacquetLen];
  return [handle, throat, tip];
}

/// Shaft angle from vertical (court-up), 0..180°. 0 = tip points straight up,
/// 90 = shaft horizontal, 180 = tip points down. The racquet's orientation
/// relative to the body's vertical axis — what the coach means by "where the
/// racquet is pointing" (the open/closed face twist itself needs a real
/// detector and is documented as not pose-sensible).
double racquetAngleDeg(List<List<double>> pose) {
  final handle = pose[0], tip = pose[2];
  final sx = tip[0] - handle[0], sy = tip[1] - handle[1];
  return (math.atan2(sx, sy) * 180.0 / math.pi).abs();
}

/// Racquet metric values at a single normalized frame.
({double angle, double height, double tipX}) racquetMetricsAt(
    List<List<double>> nkp,
    {List<List<double>>? detected}) {
  final pose = racquetPose(nkp, detected: detected);
  return (angle: racquetAngleDeg(pose), height: pose[2][1], tipX: pose[2][0]);
}

/// How sure we are a racquet was actually swung (0..1).
///
/// [detectedPresence]: optional mean per-frame presence score from an optical
/// detector over the swing window — authoritative when present. Without a
/// detector we fall back to a pose-only plausibility: a genuine stroke sweeps
/// the (estimated) racquet head through a long arc with an extending arm,
/// whereas an empty-hand gesture keeps the hand near the body. This DOES NOT
/// fully replace an object detector (it cannot see whether a racquet exists),
/// but it lets the coach hedge instead of confidently mis-coaching a non-shot.
double racquetConfidence(List<TimedKeypoints> frames, ShotWindow shot,
    {double? detectedPresence}) {
  if (detectedPresence != null) return detectedPresence.clamp(0.0, 1.0);
  final s = shot.start, e = shot.end, p = shot.peak;
  var tipPath = 0.0;
  var prev = racquetPose(frames[s].keypoints)[2];
  for (var i = s + 1; i <= e; i++) {
    final cur = racquetPose(frames[i].keypoints)[2];
    tipPath += _dist(prev, cur);
    prev = cur;
  }
  // A full stroke sweeps the head several torso lengths; ~3.5 units saturates.
  final sweepTerm = (tipPath / 3.5).clamp(0.0, 1.0);
  final contactElbow = jointAngles(frames[p].keypoints).elbowAngle;
  final extTerm = ((contactElbow - 70.0) / 80.0).clamp(0.0, 1.0);
  return (0.65 * sweepTerm + 0.35 * extTerm).clamp(0.0, 1.0);
}
