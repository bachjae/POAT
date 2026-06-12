/// Cue selection + rate limiting (SPEC §8).
///
/// [pickCue] is a port of `python_lab/engine_math.py` (parity-tested);
/// [CueRateLimiter] implements the speaking rules around it.
/// [SessionFocusManager] tracks a persistent deviation focus across a session.
library;

import 'engine_types.dart';

/// Highest weight × severity × recurrence, suppressing recently spoken metric
/// ids. [recurrenceCounts]: metric id → occurrences in the last 10 shots.
/// If [focusId] is non-null, that metric's effective score is boosted 1.5× —
/// high-severity deviations elsewhere can still win.
MetricDeviation? pickCue(
  List<MetricDeviation> deviations,
  Set<String> recentMetricIds,
  Map<String, int> recurrenceCounts, {
  String? focusId,
}) {
  MetricDeviation? best;
  var bestV = -1.0;
  for (final d in deviations) {
    if (recentMetricIds.contains(d.id)) continue;
    final rec = 1.0 + 0.15 * (recurrenceCounts[d.id] ?? 0);
    final focus = focusId != null && d.id == focusId ? 1.5 : 1.0;
    final v = d.weight * d.severity * rec * focus;
    if (v > bestV) {
      bestV = v;
      best = d;
    }
  }
  return best;
}

/// Tracks a persistent session focus: the most-recurring deviation that the
/// coach emphasises across multiple cues.
///
/// The focus persists for [budgetShots] shots, or until the metric improves
/// (recurrence < 3 in last 10). A new focus is only adopted when a metric has
/// appeared in at least 3 of the last 10 shots. [setFocus] seeds an initial
/// focus from a session goal.
class SessionFocusManager {
  SessionFocusManager({this.budgetShots = 8});

  final int budgetShots;
  String? _focusId;
  int _shotsSinceFocus = 0;

  String? get focusId => _focusId;

  void setFocus(String metricId) {
    _focusId = metricId;
    _shotsSinceFocus = 0;
  }

  /// Update state for one shot. Returns the current focus id (possibly null).
  String? update(Map<String, int> recurrenceCounts) {
    _shotsSinceFocus++;

    if (_focusId != null) {
      final rec = recurrenceCounts[_focusId!] ?? 0;
      if (rec < 3 || _shotsSinceFocus >= budgetShots) {
        _focusId = null;
        _shotsSinceFocus = 0;
      }
    }

    if (_focusId == null) {
      String? best;
      var bestCount = 0;
      for (final entry in recurrenceCounts.entries) {
        if (entry.value > bestCount) {
          bestCount = entry.value;
          best = entry.key;
        }
      }
      if (bestCount >= 3) {
        _focusId = best;
        _shotsSinceFocus = 0;
      }
    }

    return _focusId;
  }

  void reset() {
    _focusId = null;
    _shotsSinceFocus = 0;
  }
}

/// Enforces the speaking rules: max 1 utterance / 6s, no metric repeated
/// within the last 3 cues or 45s, hard-mute while a swing is in progress.
class CueRateLimiter {
  CueRateLimiter({
    this.minIntervalMs = 6000,
    this.metricSuppressMs = 45000,
    this.suppressLastN = 3,
  });

  final int minIntervalMs;
  final int metricSuppressMs;
  final int suppressLastN;

  int _lastUtteranceMs = -1 << 30;
  final List<({String metricId, int atMs})> _history = [];
  bool swingInProgress = false;

  /// Metric ids that may not be cued right now.
  Set<String> suppressedMetricIds(int nowMs) {
    final ids = <String>{};
    final recent = _history.length <= suppressLastN
        ? _history
        : _history.sublist(_history.length - suppressLastN);
    for (final h in recent) {
      ids.add(h.metricId);
    }
    for (final h in _history) {
      if (nowMs - h.atMs < metricSuppressMs) ids.add(h.metricId);
    }
    return ids;
  }

  bool canSpeak(int nowMs) =>
      !swingInProgress && nowMs - _lastUtteranceMs >= minIntervalMs;

  void recordUtterance(int nowMs, {String? metricId}) {
    _lastUtteranceMs = nowMs;
    if (metricId != null) {
      _history.add((metricId: metricId, atMs: nowMs));
      if (_history.length > 50) _history.removeAt(0);
    }
  }

  List<String> recentMetricIds() => [
        for (final h in (_history.length <= suppressLastN
            ? _history
            : _history.sublist(_history.length - suppressLastN)))
          h.metricId,
      ];

  void reset() {
    _lastUtteranceMs = -1 << 30;
    _history.clear();
    swingInProgress = false;
  }
}
