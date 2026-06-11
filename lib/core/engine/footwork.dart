/// Continuous footwork metrics per 10s window (SPEC §7).
///
/// Port of `python_lab/engine_math.py` — keep in lockstep.
library;

import 'engine_types.dart';
import 'shot_detector.dart';

class FootworkWindow {
  const FootworkWindow({
    required this.splitStepRate,
    required this.stanceWidth,
    required this.recoverySteps,
  });

  /// hops/s
  final double splitStepRate;

  /// torso units
  final double stanceWidth;

  /// lateral direction changes
  final double recoverySteps;

  Map<String, double> toMetricMap() => {
        'split_step_rate': splitStepRate,
        'stance_width': stanceWidth,
        'recovery_steps': recoverySteps,
      };
}

/// [frames]: normalized frames in the window. [rawHipX]: image-space hip-mid
/// x per frame; [torso]: image-space torso length (normalization removes
/// global translation, so lateral motion needs the raw track).
FootworkWindow analyzeFootworkWindow(
  List<TimedKeypoints> frames,
  List<double> rawHipX,
  double torso,
) {
  final n = frames.length;
  if (n < 5) {
    return const FootworkWindow(
        splitStepRate: 0.0, stanceWidth: 0.0, recoverySteps: 0.0);
  }
  var widthSum = 0.0;
  final ankleY = <double>[];
  for (final f in frames) {
    final kp = f.keypoints;
    widthSum += (kp[Kp.leftAnkle][0] - kp[Kp.rightAnkle][0]).abs();
    ankleY.add((kp[Kp.leftAnkle][1] + kp[Kp.rightAnkle][1]) / 2.0);
  }
  final stanceWidth = widthSum / n;

  var base = 0.0;
  for (final y in ankleY) {
    base += y;
  }
  base /= n;
  var hops = 0;
  var inHop = false;
  for (final y in ankleY) {
    if (y > base + 0.06) {
      if (!inHop) {
        hops++;
        inHop = true;
      }
    } else {
      inHop = false;
    }
  }
  final durS = (frames.last.timestampMs - frames.first.timestampMs) / 1000.0;
  final splitStepRate = durS > 0 ? hops / durS : 0.0;

  var steps = 0;
  var prevDir = 0;
  for (var i = 1; i < n; i++) {
    final dx = (rawHipX[i] - rawHipX[i - 1]) / torso;
    if (dx.abs() < 0.01) continue;
    final d = dx > 0 ? 1 : -1;
    if (prevDir != 0 && d != prevDir) steps++;
    prevDir = d;
  }
  return FootworkWindow(
    splitStepRate: splitStepRate,
    stanceWidth: stanceWidth,
    recoverySteps: steps.toDouble(),
  );
}
