/// Swing segmentation + classification (SPEC §6).
///
/// Port of `python_lab/engine_math.py` — keep in lockstep.
library;

import 'dart:math' as math;

import 'engine_types.dart';
import 'normalizer.dart';

class TimedKeypoints {
  const TimedKeypoints({required this.timestampMs, required this.keypoints});

  final int timestampMs;

  /// Normalized (and handedness-mirrored) 17 × [x, y].
  final List<List<double>> keypoints;
}

double _dist(List<double> a, List<double> b) {
  final dx = a[0] - b[0];
  final dy = a[1] - b[1];
  return math.sqrt(dx * dx + dy * dy);
}

/// Dominant-wrist speed in torso-units/second; speeds[0] = 0.
List<double> wristSpeeds(List<TimedKeypoints> frames) {
  final speeds = <double>[0.0];
  for (var i = 1; i < frames.length; i++) {
    final a = frames[i - 1];
    final b = frames[i];
    final dt = (b.timestampMs - a.timestampMs) / 1000.0;
    if (dt <= 0) {
      speeds.add(0.0);
      continue;
    }
    speeds.add(
        _dist(a.keypoints[Kp.rightWrist], b.keypoints[Kp.rightWrist]) / dt);
  }
  return speeds;
}

/// Validates a candidate swing window against kinematic sanity checks
/// (1:1 mirror of `validate_shot_window` in python_lab/engine_math.py).
///
/// Rejects tracking glitches without rejecting real swings. The window span
/// is parameter-determined (peak ± `window` frames ≈ 3 s at 30 fps), so the
/// duration gate only catches dropped-frame blowups, and the post/pre speed
/// ratio only catches one-sided windows (post-peak tracking loss) — real
/// follow-throughs are routinely FASTER than the windup (ratio > 1).
/// 1. Wall-clock span must be 400–4000 ms.
/// 2. Speed at peak±3 frames must be < 85% of peak speed (apex shape).
/// 3. Post-peak mean / pre-peak mean must be in [0.05, 5.0].
bool _validateShotWindow(
  List<TimedKeypoints> frames,
  ShotWindow shot,
  List<double> speeds,
) {
  final s = shot.start, p = shot.peak, e = shot.end;

  // Rule 1: duration gate (dropped-frame blowups only).
  final durationMs = frames[e].timestampMs - frames[s].timestampMs;
  if (durationMs < 400 || durationMs > 4000) return false;

  // Rule 2: apex shape — neighbors at ±3 frames must drop below 85% of peak.
  final peakSpeed = speeds[p];
  if (peakSpeed <= 0) return false;
  final leftIdx = math.max(s, p - 3);
  final rightIdx = math.min(e, p + 3);
  if (speeds[leftIdx] >= 0.85 * peakSpeed) return false;
  if (speeds[rightIdx] >= 0.85 * peakSpeed) return false;

  // Rule 3: one-sided window gate.
  var preSum = 0.0, preCount = 0;
  for (var i = s; i < p; i++) {
    preSum += speeds[i];
    preCount++;
  }
  var postSum = 0.0, postCount = 0;
  for (var i = p + 1; i <= e; i++) {
    postSum += speeds[i];
    postCount++;
  }
  if (preCount > 0 && postCount > 0 && preSum > 0) {
    final ratio = (postSum / postCount) / (preSum / preCount);
    if (ratio < 0.05 || ratio > 5.0) return false;
  }

  return true;
}

/// Wrist-speed peaks above an adaptive threshold → candidate swing windows.
List<ShotWindow> detectShots(
  List<TimedKeypoints> frames, {
  double baseThreshold = 6.0,
  int window = 45,
  int minGap = 30,
}) {
  final speeds = wristSpeeds(frames);
  final n = speeds.length;
  if (n < 10) return [];
  var mean = 0.0;
  for (final s in speeds) {
    mean += s;
  }
  mean /= n;
  var variance = 0.0;
  for (final s in speeds) {
    variance += (s - mean) * (s - mean);
  }
  variance /= n;
  final threshold = math.max(baseThreshold, mean + 2.5 * math.sqrt(variance));
  final shots = <ShotWindow>[];
  var i = 1;
  while (i < n - 1) {
    if (speeds[i] >= threshold &&
        speeds[i] >= speeds[i - 1] &&
        speeds[i] >= speeds[i + 1]) {
      if (shots.isNotEmpty && i - shots.last.peak < minGap) {
        if (speeds[i] > shots.last.peakSpeed) {
          shots[shots.length - 1] = ShotWindow(
            peak: i,
            start: math.max(0, i - window),
            end: math.min(n - 1, i + window),
            peakSpeed: speeds[i],
          );
        }
        i++;
        continue;
      }
      shots.add(ShotWindow(
        peak: i,
        start: math.max(0, i - window),
        end: math.min(n - 1, i + window),
        peakSpeed: speeds[i],
      ));
    }
    i++;
  }
  shots.removeWhere((shot) => !_validateShotWindow(frames, shot, speeds));
  return shots;
}

/// Decision rules over the swing window (frames normalized + mirrored).
///
/// Returns `(stroke, confidence)` where confidence (0–1) reflects how
/// strongly the discriminating signal supports the label. Forehand/backhand
/// labels with confidence below 0.45 are downgraded to [Stroke.footwork].
///
/// When [majorityView] is a side view, trunk-rotation direction during the
/// prep-to-backswing phase is used instead of the wrist-X heuristic for
/// forehand/backhand disambiguation (wrist-X collapses in side projection).
(Stroke, double) classifyShot(
  List<TimedKeypoints> frames,
  ShotWindow shot, {
  ViewBucket? majorityView,
}) {
  final s = shot.start, p = shot.peak;
  final windowLen = (p - s + 1).clamp(1, 1 << 30);
  final peakKp = frames[p].keypoints;

  var bothUpCount = 0;
  for (var i = s; i <= p; i++) {
    final kp = frames[i].keypoints;
    if (kp[Kp.leftWrist][1] > kp[Kp.leftShoulder][1] &&
        kp[Kp.rightWrist][1] > kp[Kp.rightShoulder][1]) {
      bothUpCount++;
    }
  }
  final overhead = peakKp[Kp.rightWrist][1] > peakKp[Kp.nose][1];
  if (bothUpCount > 0 && overhead) {
    final serveConf = (bothUpCount / windowLen).clamp(0.0, 1.0);
    return (Stroke.serve, serveConf);
  }

  var minX = double.infinity, maxX = double.negativeInfinity;
  for (var i = s; i <= p; i++) {
    final x = frames[i].keypoints[Kp.rightWrist][0];
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
  }
  final horizRange = maxX - minX;
  if (horizRange < 0.9) {
    final volleyConf = (1.0 - horizRange / 0.9).clamp(0.0, 1.0);
    return (Stroke.volley, volleyConf);
  }

  final bwI = backswingFrame(frames, s, p);

  // Side views: trunk-rotation direction is more reliable than wrist-X
  // position (which collapses in side projection).
  if (majorityView?.isSide ?? false) {
    final startSho = jointAngles(frames[s].keypoints).shoulderLineDeg;
    final bwSho = jointAngles(frames[bwI].keypoints).shoulderLineDeg;
    final delta = wrapDeg(bwSho - startSho);
    // Positive delta → shoulders coil clockwise (overhead view) → forehand.
    final sideConf = (delta.abs().clamp(0.0, 20.0) / 20.0);
    final stroke = delta > 0 ? Stroke.forehand : Stroke.backhand;
    if (sideConf < 0.25) return (Stroke.footwork, sideConf);
    return (stroke, sideConf);
  }

  // Front / diagonal views: wrist-X backswing heuristic.
  final bwX = frames[bwI].keypoints[Kp.rightWrist][0];
  final fbConf = (bwX.abs().clamp(0.0, 1.2) / 1.2);
  final stroke = bwX >= 0.0 ? Stroke.forehand : Stroke.backhand;
  // Low-confidence forehand/backhand in ambiguous side views; downgrade to
  // footwork cues rather than coaching on a mislabelled stroke.
  if (fbConf < 0.45) return (Stroke.footwork, fbConf);
  return (stroke, fbConf);
}

/// Wrist rearmost point: min projection onto the swing direction at peak.
int backswingFrame(List<TimedKeypoints> frames, int start, int peak) {
  if (peak - start < 2) return start;
  final a = frames[math.max(start, peak - 3)].keypoints[Kp.rightWrist];
  final b = frames[peak].keypoints[Kp.rightWrist];
  var dx = b[0] - a[0], dy = b[1] - a[1];
  final norm = math.sqrt(dx * dx + dy * dy);
  if (norm < 1e-9) return start;
  dx /= norm;
  dy /= norm;
  var bestI = start;
  var bestV = double.infinity;
  for (var i = start; i <= peak; i++) {
    final w = frames[i].keypoints[Kp.rightWrist];
    final v = w[0] * dx + w[1] * dy;
    if (v < bestV) {
      bestV = v;
      bestI = i;
    }
  }
  return bestI;
}
