/// Temporal keypoint smoothing for the live camera path (SPEC §4).
///
/// MoveNet jitters a few pixels per frame even on a still subject; at torso
/// scale that jitter becomes phantom wrist speed, which is exactly the
/// signal the shot detector thresholds on. A One-Euro filter removes the
/// jitter while staying responsive during real swings (its cutoff rises
/// with speed, so fast motion passes through with minimal lag).
///
/// Pure Dart, no Flutter imports — unit-testable. Applied only in the
/// device camera path; recorded test streams feed the engine raw so the
/// batch/live parity fixtures stay byte-identical.
library;

import 'dart:math' as math;

import '../engine/engine_types.dart';

class _LowPass {
  double? _y;

  double filter(double x, double alpha) {
    final y = _y;
    final out = y == null ? x : alpha * x + (1 - alpha) * y;
    _y = out;
    return out;
  }

  void reset() => _y = null;
}

/// One-Euro filter for a single scalar signal.
class OneEuroFilter {
  OneEuroFilter({
    this.minCutoff = 1.5,
    this.beta = 10.0,
    this.dCutoff = 1.0,
  });

  /// Cutoff at rest, Hz. Lower = smoother but laggier when still.
  final double minCutoff;

  /// Speed coefficient: how fast the cutoff opens up with motion. Speeds
  /// are expressed in frame-diagonals/second (unit-free); a swing peaks at
  /// several diag/s, so beta 10 fully opens the filter mid-swing while
  /// alternating-sign jitter (whose smoothed derivative is ~0) stays at
  /// [minCutoff].
  final double beta;

  /// Cutoff for the derivative estimate, Hz.
  final double dCutoff;

  final _x = _LowPass();
  final _dx = _LowPass();
  double? _lastValue;

  static double _alpha(double cutoff, double dtS) {
    final tau = 1.0 / (2 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / dtS);
  }

  double filter(double value, double dtS) {
    if (dtS <= 0) return _lastValue ?? value;
    final prev = _lastValue;
    final rawDeriv = prev == null ? 0.0 : (value - prev) / dtS;
    _lastValue = value;
    final deriv = _dx.filter(rawDeriv, _alpha(dCutoff, dtS));
    final cutoff = minCutoff + beta * deriv.abs();
    return _x.filter(value, _alpha(cutoff, dtS));
  }

  void reset() {
    _x.reset();
    _dx.reset();
    _lastValue = null;
  }
}

/// Smooths all 17 keypoints of a [PoseFrame] stream.
///
/// Confidence handling: a keypoint below [holdBelowConf] keeps its last
/// smoothed position (a one-frame occlusion shouldn't teleport the wrist)
/// while its RAW confidence passes through, so downstream gating still
/// sees the truth. After [resetAfterMs] without frames, or [holdMaxFrames]
/// consecutive low-confidence frames for a keypoint, the filters reset so
/// a re-acquired player doesn't get dragged from a stale position.
class PoseSmoother {
  PoseSmoother({
    this.holdBelowConf = 0.2,
    this.holdMaxFrames = 8,
    this.resetAfterMs = 500,
    double minCutoff = 1.5,
    double beta = 10.0,
  })  : _fx = List.generate(Kp.count,
            (_) => OneEuroFilter(minCutoff: minCutoff, beta: beta)),
        _fy = List.generate(Kp.count,
            (_) => OneEuroFilter(minCutoff: minCutoff, beta: beta));

  final double holdBelowConf;
  final int holdMaxFrames;
  final int resetAfterMs;

  final List<OneEuroFilter> _fx;
  final List<OneEuroFilter> _fy;
  final List<List<double>?> _lastGood = List.filled(Kp.count, null);
  final List<int> _heldFrames = List.filled(Kp.count, 0);
  int? _lastTimestampMs;
  double _diagonal = 1.0;

  PoseFrame smooth(PoseFrame frame, {required int width, required int height}) {
    _diagonal = math.sqrt((width * width + height * height).toDouble());
    final last = _lastTimestampMs;
    final dtMs = last == null ? 0 : frame.timestampMs - last;
    _lastTimestampMs = frame.timestampMs;
    if (last != null && (dtMs <= 0 || dtMs > resetAfterMs)) {
      reset();
      _lastTimestampMs = frame.timestampMs;
    }
    final dtS = dtMs <= 0 ? 1.0 / 30.0 : dtMs / 1000.0;

    final out = <List<double>>[];
    for (var i = 0; i < Kp.count; i++) {
      final p = frame.keypoints[i];
      final conf = p[2];
      if (conf < holdBelowConf) {
        final held = _lastGood[i];
        _heldFrames[i]++;
        if (held == null || _heldFrames[i] > holdMaxFrames) {
          _fx[i].reset();
          _fy[i].reset();
          _lastGood[i] = null;
          out.add([p[0], p[1], conf]);
        } else {
          out.add([held[0], held[1], conf]);
        }
        continue;
      }
      _heldFrames[i] = 0;
      // Filter in diagonal units so One-Euro betas are resolution-free.
      final x = _fx[i].filter(p[0] / _diagonal, dtS) * _diagonal;
      final y = _fy[i].filter(p[1] / _diagonal, dtS) * _diagonal;
      _lastGood[i] = [x, y];
      out.add([x, y, conf]);
    }
    return PoseFrame(timestampMs: frame.timestampMs, keypoints: out);
  }

  void reset() {
    for (var i = 0; i < Kp.count; i++) {
      _fx[i].reset();
      _fy[i].reset();
      _lastGood[i] = null;
      _heldFrames[i] = 0;
    }
    _lastTimestampMs = null;
  }
}
