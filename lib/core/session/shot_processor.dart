/// Incremental, live version of the batch engine pipeline.
///
/// Consumes raw [PoseFrame]s one at a time, maintains a rolling normalized
/// window, and emits a [ShotEvent] once a complete swing window (±1.5s
/// around the wrist-speed peak) is available. Swing windows are specified
/// in MILLISECONDS and converted to frame counts from the observed frame
/// cadence, so detection behaves identically at 10, 15, 24 or 30 fps (the
/// camera throttles fps thermally; frame-count windows silently doubled in
/// duration at low fps). Also tracks player visibility and the rolling
/// majority view bucket, and runs 10-second footwork windows for footwork
/// sessions.
library;

import 'dart:async';
import 'dart:math' as math;

import '../engine/cue_prioritizer.dart';
import '../engine/engine_types.dart';
import '../engine/footwork.dart';
import '../engine/normalizer.dart';
import '../engine/phase_segmenter.dart';
import '../engine/shot_detector.dart';
import '../engine/technique_scorer.dart';

class ShotEvent {
  const ShotEvent({
    required this.stroke,
    required this.score,
    required this.view,
    required this.peakTimestampMs,
    required this.measured,
    required this.wristTrail,
  });

  final Stroke stroke;
  final ShotScore score;
  final ViewBucket view;
  final int peakTimestampMs;
  final Map<String, Map<String, double>> measured;

  /// Normalized wrist positions across the swing window, for the live
  /// Rally Arc trail overlay ([x, y] in torso units).
  final List<List<double>> wristTrail;
}

class FootworkEvent {
  const FootworkEvent({required this.score, required this.window});

  final ShotScore score;
  final FootworkWindow window;
}

/// Player-visibility transitions (lost after [lostAfterFrames] consecutive
/// low-confidence frames; re-acquired on the next good frame).
enum PlayerVisibility { searching, locked, lost }

class ShotStreamProcessor {
  ShotStreamProcessor({
    required this.referenceFor,
    this.leftHanded = false,
    this.footworkMode = false,
    this.bufferFrames = 200,
    this.detectEvery = 5,
    this.lostAfterFrames = 15,
    this.shotWindowMs = 1500,
    this.postWindowMs = 1000,
    this.minGapMs = 1000,
    this.footworkWindowMs = 10000,
  });

  /// Resolves the scoring reference for a detected stroke (skill tier is the
  /// caller's concern).
  final StrokeReference? Function(Stroke stroke) referenceFor;
  final bool leftHanded;
  final bool footworkMode;
  final int bufferFrames;
  final int detectEvery;
  final int lostAfterFrames;

  /// Half-width of the swing window around the wrist-speed peak.
  final int shotWindowMs;

  /// Time required after the peak before a shot is emitted. The
  /// follow-through completes within ~700ms, so 1s keeps the measured
  /// metrics identical to the batch pipeline while the cue still lands
  /// about a second after contact.
  final int postWindowMs;

  /// Minimum separation between two detected peaks.
  final int minGapMs;
  final int footworkWindowMs;

  /// EMA of the inter-frame interval; 33ms (30fps) until measured. Single
  /// outliers are clamped so a dropped frame doesn't stretch the windows.
  double _dtEmaMs = 33.0;

  int _msToFrames(int ms, int lo, int hi) =>
      (ms / _dtEmaMs).round().clamp(lo, hi);

  int get _shotWindowFrames => _msToFrames(shotWindowMs, 8, 120);
  int get _postWindowFrames => _msToFrames(postWindowMs, 5, 90);
  int get _minGapFrames => _msToFrames(minGapMs, 5, 90);

  final _shots = StreamController<ShotEvent>.broadcast();
  final _footwork = StreamController<FootworkEvent>.broadcast();
  final _visibility = StreamController<PlayerVisibility>.broadcast();
  final _swinging = StreamController<bool>.broadcast();

  Stream<ShotEvent> get shots => _shots.stream;
  Stream<FootworkEvent> get footworkWindows => _footwork.stream;
  Stream<PlayerVisibility> get visibility => _visibility.stream;

  /// True while the wrist is moving at swing speed; false once it has been
  /// calm again for a few frames. Drives the TTS swing mute (SPEC §8) so
  /// the coach never talks over a stroke.
  Stream<bool> get swinging => _swinging.stream;

  final List<TimedKeypoints> _buffer = [];
  final List<double> _rawHipX = [];
  final List<double> _torsos = [];
  final Map<String, int> _viewCounts = {};
  final List<String> _viewWindow = [];

  int _framesSinceDetect = 0;
  int _lowConfStreak = 0;
  int _lastEmittedPeakTs = -1;
  int _footworkWindowStartTs = -1;
  int _footworkStartIndex = 0;
  PlayerVisibility _currentVisibility = PlayerVisibility.searching;

  /// Swing-mute hysteresis: enter at shot-detector speed, leave after the
  /// wrist stays calm for [_swingCalmFramesNeeded] consecutive frames.
  static const double _swingStartSpeed = 6.0;
  static const double _swingEndSpeed = 2.0;
  static const int _swingCalmFramesNeeded = 6;
  bool _swingActive = false;
  int _swingCalmFrames = 0;

  ViewBucket get majorityView {
    String? best;
    var bestCount = -1;
    _viewCounts.forEach((k, v) {
      if (v > bestCount) {
        bestCount = v;
        best = k;
      }
    });
    return best == null ? ViewBucket.sideRight : ViewBucket.fromId(best!);
  }

  PlayerVisibility get currentVisibility => _currentVisibility;

  void _setVisibility(PlayerVisibility v) {
    if (v == _currentVisibility) return;
    _currentVisibility = v;
    _visibility.add(v);
  }

  void feed(PoseFrame frame) {
    final n = normalizeFrame(frame.timestampMs, frame.keypoints);
    if (n == null) {
      _lowConfStreak++;
      if (_lowConfStreak >= lostAfterFrames &&
          _currentVisibility == PlayerVisibility.locked) {
        _setVisibility(PlayerVisibility.lost);
      }
      return;
    }
    _lowConfStreak = 0;
    _setVisibility(PlayerVisibility.locked);

    final kp = leftHanded ? mirrorNormalized(n.keypoints) : n.keypoints;
    if (_buffer.isNotEmpty) {
      final dt = (n.timestampMs - _buffer.last.timestampMs)
          .clamp(10, 200)
          .toDouble();
      _dtEmaMs += 0.1 * (dt - _dtEmaMs);
      _trackSwing(_buffer.last, n.timestampMs, kp);
    }
    _buffer.add(TimedKeypoints(timestampMs: n.timestampMs, keypoints: kp));
    final hipMidX =
        (frame.keypoints[Kp.leftHip][0] + frame.keypoints[Kp.rightHip][0]) /
            2.0;
    _rawHipX.add(hipMidX);
    _torsos.add(n.torso);
    _viewWindow.add(n.view.id);
    _viewCounts[n.view.id] = (_viewCounts[n.view.id] ?? 0) + 1;
    if (_viewWindow.length > 90) {
      final old = _viewWindow.removeAt(0);
      final c = _viewCounts[old]! - 1;
      if (c == 0) {
        _viewCounts.remove(old);
      } else {
        _viewCounts[old] = c;
      }
    }
    if (_buffer.length > bufferFrames) {
      _buffer.removeAt(0);
      _rawHipX.removeAt(0);
      _torsos.removeAt(0);
      if (_footworkStartIndex > 0) _footworkStartIndex--;
    }

    if (footworkMode) {
      _maybeEmitFootworkWindow();
      return;
    }

    _framesSinceDetect++;
    if (_framesSinceDetect >= detectEvery) {
      _framesSinceDetect = 0;
      _detect();
    }
  }

  void _trackSwing(
      TimedKeypoints prev, int timestampMs, List<List<double>> kp) {
    final dtS = (timestampMs - prev.timestampMs) / 1000.0;
    if (dtS <= 0) return;
    final a = prev.keypoints[Kp.rightWrist];
    final b = kp[Kp.rightWrist];
    final dx = b[0] - a[0], dy = b[1] - a[1];
    final speed = math.sqrt(dx * dx + dy * dy) / dtS;
    if (!_swingActive) {
      if (speed >= _swingStartSpeed) {
        _swingActive = true;
        _swingCalmFrames = 0;
        if (!_swinging.isClosed) _swinging.add(true);
      }
      return;
    }
    if (speed < _swingEndSpeed) {
      _swingCalmFrames++;
      if (_swingCalmFrames >= _swingCalmFramesNeeded) {
        _swingActive = false;
        if (!_swinging.isClosed) _swinging.add(false);
      }
    } else {
      _swingCalmFrames = 0;
    }
  }

  void _detect() {
    final shots = detectShots(_buffer,
        window: _shotWindowFrames, minGap: _minGapFrames);
    for (final shot in shots) {
      final peakTs = _buffer[shot.peak].timestampMs;
      if (peakTs <= _lastEmittedPeakTs) continue;
      // Wait until enough post-peak frames have arrived.
      if (shot.peak + _postWindowFrames > _buffer.length - 1) continue;
      _lastEmittedPeakTs = peakTs;

      final stroke = classifyShot(_buffer, shot);
      final reference = referenceFor(stroke);
      final phases = segmentPhases(_buffer, shot, stroke);
      final address = jointAngles(_buffer[shot.start].keypoints);
      final measured = measureMetrics(_buffer, phases, address);
      final view = majorityView;
      final score = reference == null
          ? const ShotScore(score: 0, phaseScores: {}, deviations: [])
          : scoreShot(measured, reference, view);
      _shots.add(ShotEvent(
        stroke: stroke,
        score: score,
        view: view,
        peakTimestampMs: peakTs,
        measured: measured,
        wristTrail: [
          for (var i = shot.start; i <= shot.end; i++)
            _buffer[i].keypoints[Kp.rightWrist],
        ],
      ));
    }
  }

  void _maybeEmitFootworkWindow() {
    final nowTs = _buffer.last.timestampMs;
    if (_footworkWindowStartTs < 0) {
      _footworkWindowStartTs = nowTs;
      _footworkStartIndex = _buffer.length - 1;
      return;
    }
    if (nowTs - _footworkWindowStartTs < footworkWindowMs) return;
    final frames = _buffer.sublist(_footworkStartIndex);
    final rawX = _rawHipX.sublist(_footworkStartIndex);
    final torso = _torsos.isEmpty ? 1.0 : _torsos.last;
    final window = analyzeFootworkWindow(frames, rawX, torso);
    final reference = referenceFor(Stroke.footwork);
    final score = reference == null
        ? const ShotScore(score: 0, phaseScores: {}, deviations: [])
        : scoreShot({'window': window.toMetricMap()}, reference,
            majorityView);
    _footwork.add(FootworkEvent(score: score, window: window));
    _footworkWindowStartTs = nowTs;
    _footworkStartIndex = _buffer.length - 1;
  }

  /// Recurrence of each deviated metric over the last [n] emitted shots —
  /// feeds [pickCue] and the Brain prompt context.
  final List<List<String>> _recentShotDeviations = [];

  void recordShotDeviations(List<MetricDeviation> deviations) {
    _recentShotDeviations.add([for (final d in deviations) d.id]);
    if (_recentShotDeviations.length > 10) _recentShotDeviations.removeAt(0);
  }

  Map<String, int> recurrenceCounts() {
    final counts = <String, int>{};
    for (final shot in _recentShotDeviations) {
      for (final id in shot.toSet()) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> dispose() async {
    await _shots.close();
    await _footwork.close();
    await _visibility.close();
    await _swinging.close();
  }
}
