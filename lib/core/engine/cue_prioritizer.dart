/// Cue selection + rate limiting (SPEC §8).
///
/// [pickCue] is a port of `python_lab/engine_math.py` (parity-tested);
/// [CueRateLimiter] implements the speaking rules around it.
library;

import 'engine_types.dart';

/// Highest weight × severity × recurrence, suppressing recently spoken metric
/// ids. [recurrenceCounts]: metric id → occurrences in the last 10 shots.
MetricDeviation? pickCue(
  List<MetricDeviation> deviations,
  Set<String> recentMetricIds,
  Map<String, int> recurrenceCounts,
) {
  MetricDeviation? best;
  var bestV = -1.0;
  for (final d in deviations) {
    if (recentMetricIds.contains(d.id)) continue;
    final rec = 1.0 + 0.15 * (recurrenceCounts[d.id] ?? 0);
    final v = d.weight * d.severity * rec;
    if (v > bestV) {
      bestV = v;
      best = d;
    }
  }
  return best;
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
