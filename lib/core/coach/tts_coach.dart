/// Queue-managed spoken coaching (SPEC §8).
///
/// One utterance at a time, max 1 per 6s, queue length 1 with newest-wins,
/// hard-mute while a swing is in progress, and every utterance mirrored to
/// the caption stream BEFORE speech starts (deaf/HoH usable end-to-end).
/// System messages ("I lost you") bypass the limiter and interrupt.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../engine/cue_prioritizer.dart';

enum CoachUtteranceKind { cue, encouragement, acknowledgment, filler, system }

class CaptionEvent {
  const CaptionEvent({required this.text, required this.kind, required this.at});

  final String text;
  final CoachUtteranceKind kind;
  final DateTime at;
}

/// Thin platform seam so the queue logic is unit-testable.
abstract class SpeechEngine {
  Future<void> configure({required double pitch, required double rate});

  Future<void> speak(String text);

  Future<void> stop();

  bool get isSpeaking;
}

/// flutter_tts wiring — device-only by design (OS offline voices).
class FlutterTtsEngine implements SpeechEngine {
  FlutterTtsEngine() {
    _tts.awaitSpeakCompletion(true);
    _tts.setStartHandler(() => _speaking = true);
    _tts.setCompletionHandler(() => _speaking = false);
    _tts.setCancelHandler(() => _speaking = false);
    _tts.setErrorHandler((_) => _speaking = false);
  }

  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  @override
  Future<void> configure({required double pitch, required double rate}) async {
    await _tts.setPitch(pitch);
    await _tts.setSpeechRate(rate * 0.5); // flutter_tts normal speed ~0.5.
  }

  @override
  Future<void> speak(String text) async {
    _speaking = true;
    await _tts.speak(text);
    _speaking = false;
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _speaking = false;
  }

  @override
  bool get isSpeaking => _speaking;
}

class _Pending {
  _Pending(this.text, this.kind, this.metricId);

  final String text;
  final CoachUtteranceKind kind;
  final String? metricId;
}

class TtsCoach {
  TtsCoach(this._engine, this._limiter, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final SpeechEngine _engine;
  final CueRateLimiter _limiter;
  final DateTime Function() _clock;

  final _captions = StreamController<CaptionEvent>.broadcast();
  _Pending? _queued;
  bool _speaking = false;
  int _lastFillerMs = -1 << 30;
  bool _disposed = false;

  static const int _fillerIntervalMs = 30000;

  /// Every spoken utterance, mirrored before speech starts.
  Stream<CaptionEvent> get captions => _captions.stream;

  /// Metric ids that must not be cued right now (recently spoken).
  Set<String> suppressedMetricIds() =>
      _limiter.suppressedMetricIds(_nowMs());

  List<String> recentMetricIds() => _limiter.recentMetricIds();

  int _nowMs() => _clock().millisecondsSinceEpoch;

  /// Queue length 1, newest wins. System utterances bypass the rate limiter
  /// and interrupt any current speech.
  void submit(String text, CoachUtteranceKind kind, {String? metricId}) {
    if (_disposed || text.isEmpty) return;
    if (kind == CoachUtteranceKind.system) {
      unawaited(_speakSystem(text));
      return;
    }
    // Hard-mute: cues raised mid-swing are stale by the time the swing
    // ends (the next shot event supersedes them), so drop rather than defer.
    if (_limiter.swingInProgress) return;
    if (kind == CoachUtteranceKind.filler &&
        _nowMs() - _lastFillerMs < _fillerIntervalMs) {
      return;
    }
    _queued = _Pending(text, kind, metricId);
    unawaited(_drain());
  }

  /// Hard-mute: drop anything queued and let nothing speak mid-swing.
  void onSwingStart() {
    _limiter.swingInProgress = true;
    _queued = null;
  }

  void onSwingEnd() {
    _limiter.swingInProgress = false;
    unawaited(_drain());
  }

  /// Best-effort haptic tap; speech must never depend on the services
  /// binding being up (plain unit tests construct TtsCoach directly).
  static void _haptic(Future<void> Function() impact) {
    try {
      unawaited(impact().catchError((Object _) {}));
    } catch (_) {
      // No binding / no vibrator — the voice still works.
    }
  }

  Future<void> _speakSystem(String text) async {
    await _engine.stop();
    _haptic(HapticFeedback.mediumImpact);
    _emit(text, CoachUtteranceKind.system);
    _speaking = true;
    try {
      await _engine.speak(text);
    } finally {
      _speaking = false;
    }
    await _drain();
  }

  Future<void> _drain() async {
    if (_disposed || _speaking) return;
    final next = _queued;
    if (next == null) return;
    final now = _nowMs();
    if (!_limiter.canSpeak(now)) return;
    _queued = null;
    _limiter.recordUtterance(now, metricId: next.metricId);
    if (next.kind == CoachUtteranceKind.filler) _lastFillerMs = now;
    _emit(next.text, next.kind);
    if (next.kind == CoachUtteranceKind.cue) {
      _haptic(HapticFeedback.lightImpact);
    }
    _speaking = true;
    try {
      await _engine.speak(next.text);
    } finally {
      _speaking = false;
    }
    // A newer utterance may have arrived and become speakable meanwhile.
    unawaited(_drain());
  }

  void _emit(String text, CoachUtteranceKind kind) {
    if (!_captions.isClosed) {
      _captions.add(CaptionEvent(text: text, kind: kind, at: _clock()));
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _queued = null;
    await _engine.stop();
    await _captions.close();
  }
}
