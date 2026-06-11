/// View-invariant normalization (SPEC §5).
///
/// Port of `python_lab/engine_math.py` — keep in lockstep.
library;

import 'dart:math' as math;

import 'engine_types.dart';

List<double> _mid(List<double> a, List<double> b) =>
    [(a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0];

double _dist(List<double> a, List<double> b) {
  final dx = a[0] - b[0];
  final dy = a[1] - b[1];
  return math.sqrt(dx * dx + dy * dy);
}

/// Interior angle at [b] in degrees (0..180).
double angleDeg(List<double> a, List<double> b, List<double> c) {
  final v1x = a[0] - b[0], v1y = a[1] - b[1];
  final v2x = c[0] - b[0], v2y = c[1] - b[1];
  final n1 = math.sqrt(v1x * v1x + v1y * v1y);
  final n2 = math.sqrt(v2x * v2x + v2y * v2y);
  if (n1 < 1e-9 || n2 < 1e-9) return 0.0;
  var cosv = (v1x * v2x + v1y * v2y) / (n1 * n2);
  cosv = cosv.clamp(-1.0, 1.0);
  return math.acos(cosv) * 180.0 / math.pi;
}

/// Translate hip-mid to origin, scale by torso length, flip y up.
/// Returns null when core joints are below confidence.
NormalizedFrame? normalizeFrame(int timestampMs, List<List<double>> kp) {
  for (final idx in [Kp.leftShoulder, Kp.rightShoulder, Kp.leftHip, Kp.rightHip]) {
    if (kp[idx][2] < kMinKeypointConf) return null;
  }
  final hipMid = _mid(kp[Kp.leftHip], kp[Kp.rightHip]);
  final shoMid = _mid(kp[Kp.leftShoulder], kp[Kp.rightShoulder]);
  final torso = _dist(hipMid, shoMid);
  if (torso < 1e-6) return null;
  final out = <List<double>>[
    for (final p in kp)
      [(p[0] - hipMid[0]) / torso, -(p[1] - hipMid[1]) / torso],
  ];
  final (view, ratio) = classifyView(kp, torso);
  return NormalizedFrame(
    timestampMs: timestampMs,
    keypoints: out,
    torso: torso,
    view: view,
    shoulderWidthRatio: ratio,
  );
}

/// View bucket from shoulder-width foreshortening + nose visibility.
(ViewBucket, double) classifyView(List<List<double>> kp, double torso) {
  final width = _dist(kp[Kp.leftShoulder], kp[Kp.rightShoulder]);
  final ratio = width / torso;
  final noseVisible = kp[Kp.nose][2] >= kMinKeypointConf;
  final shoMidX = (kp[Kp.leftShoulder][0] + kp[Kp.rightShoulder][0]) / 2.0;
  final noseLeft = kp[Kp.nose][0] < shoMidX;
  if (ratio >= 0.75) {
    return (noseVisible ? ViewBucket.front : ViewBucket.back, ratio);
  }
  if (ratio <= 0.45) {
    return (noseLeft ? ViewBucket.sideLeft : ViewBucket.sideRight, ratio);
  }
  return (noseLeft ? ViewBucket.diagonalLeft : ViewBucket.diagonalRight, ratio);
}

const _mirrorSwap = [0, 2, 1, 4, 3, 6, 5, 8, 7, 10, 9, 12, 11, 14, 13, 16, 15];

/// Mirror a normalized frame for left-handed players: negate x and swap L/R.
List<List<double>> mirrorNormalized(List<List<double>> nkp) => [
      for (var i = 0; i < Kp.count; i++)
        [-nkp[_mirrorSwap[i]][0], nkp[_mirrorSwap[i]][1]],
    ];

/// Relative joint angles (view-robust) from a normalized frame.
/// Dominant side is RIGHT after handedness mirroring.
JointAngles jointAngles(List<List<double>> nkp) {
  final shoMid = _mid(nkp[Kp.leftShoulder], nkp[Kp.rightShoulder]);
  final trunkDx = shoMid[0];
  final trunkDy = shoMid[1];
  final trunkTilt = (math.atan2(trunkDx, trunkDy) * 180.0 / math.pi).abs();
  final shoVecX = nkp[Kp.rightShoulder][0] - nkp[Kp.leftShoulder][0];
  final shoVecY = nkp[Kp.rightShoulder][1] - nkp[Kp.leftShoulder][1];
  final hipVecX = nkp[Kp.rightHip][0] - nkp[Kp.leftHip][0];
  final hipVecY = nkp[Kp.rightHip][1] - nkp[Kp.leftHip][1];
  return JointAngles(
    elbowAngle: angleDeg(
        nkp[Kp.rightShoulder], nkp[Kp.rightElbow], nkp[Kp.rightWrist]),
    kneeFlexion:
        angleDeg(nkp[Kp.rightHip], nkp[Kp.rightKnee], nkp[Kp.rightAnkle]),
    trunkTilt: trunkTilt,
    shoulderLineDeg: math.atan2(shoVecY, shoVecX) * 180.0 / math.pi,
    hipLineDeg: math.atan2(hipVecY, hipVecX) * 180.0 / math.pi,
    wristX: nkp[Kp.rightWrist][0],
    wristY: nkp[Kp.rightWrist][1],
  );
}

double wrapDeg(double diff) {
  var d = diff;
  while (d > 180.0) {
    d -= 360.0;
  }
  while (d < -180.0) {
    d += 360.0;
  }
  return d;
}
