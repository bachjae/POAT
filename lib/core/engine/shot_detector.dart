/// Swing segmentation + classification (SPEC §6).
///
/// Port of `python_lab/engine_math.py` — keep in lockstep.
library;

import 'dart:math' as math;

import 'engine_types.dart';

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
  return shots;
}

/// Decision rules over the swing window (frames normalized + mirrored).
Stroke classifyShot(List<TimedKeypoints> frames, ShotWindow shot) {
  final s = shot.start, p = shot.peak;
  final peakKp = frames[p].keypoints;
  var bothUp = false;
  for (var i = s; i <= p; i++) {
    final kp = frames[i].keypoints;
    if (kp[Kp.leftWrist][1] > kp[Kp.leftShoulder][1] &&
        kp[Kp.rightWrist][1] > kp[Kp.rightShoulder][1]) {
      bothUp = true;
      break;
    }
  }
  final overhead = peakKp[Kp.rightWrist][1] > peakKp[Kp.nose][1];
  if (bothUp && overhead) return Stroke.serve;

  var minX = double.infinity, maxX = double.negativeInfinity;
  for (var i = s; i <= p; i++) {
    final x = frames[i].keypoints[Kp.rightWrist][0];
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
  }
  if (maxX - minX < 0.9) return Stroke.volley;

  final bwI = backswingFrame(frames, s, p);
  final bwX = frames[bwI].keypoints[Kp.rightWrist][0];
  return bwX >= 0.0 ? Stroke.forehand : Stroke.backhand;
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
