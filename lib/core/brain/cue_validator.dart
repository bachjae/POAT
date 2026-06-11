/// LLM cue output gate (SPEC §9.4).
///
/// Every spoken cue the model produces must pass this validator before TTS;
/// rejected cues fall back to the deterministic rule-engine cue. The lexicon
/// ships as `assets/prompts/cue_lexicon.json` and is asserted (in tests) to
/// deep-equal the copy in `test/fixtures/validator_cases.json`, whose 16
/// adversarial cases this class must pass.
library;

import 'dart:convert';

final RegExp _kDigit = RegExp(r'\d');
final RegExp _kNonLetter = RegExp(r"[^a-z']+");

/// Accepts a cue only if it is short, number-free, non-repetitive, and
/// grounded in a metric that actually deviated.
class CueValidator {
  CueValidator({required this.lexicon, this.maxWords = 14});

  /// Parses `{"lexicon": {keyword: [metric ids]}, "max_words": N}` — the
  /// shape of `assets/prompts/cue_lexicon.json`.
  factory CueValidator.fromJsonString(String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final raw = decoded['lexicon'] as Map<String, dynamic>;
    return CueValidator(
      lexicon: raw.map((k, v) =>
          MapEntry(k, (v as List<dynamic>).cast<String>())),
      maxWords: decoded['max_words'] as int? ?? 14,
    );
  }

  /// keyword (lowercase) → metric ids it may refer to.
  final Map<String, List<String>> lexicon;
  final int maxWords;

  /// Validates [cue] against the measured [deviatedMetricIds] and the
  /// [recentCues] already spoken. Rejection reasons are stable strings
  /// (logged, never spoken).
  ({bool accepted, String reason}) validate(
    String cue, {
    required Set<String> deviatedMetricIds,
    required List<String> recentCues,
  }) {
    final trimmed = cue.trim();
    if (trimmed.isEmpty) {
      return (accepted: false, reason: 'empty output');
    }
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length > maxWords) {
      return (accepted: false, reason: 'over $maxWords words');
    }
    if (_kDigit.hasMatch(trimmed)) {
      return (accepted: false, reason: 'contains numbers');
    }
    final lower = trimmed.toLowerCase();
    for (final recent in recentCues) {
      if (recent.trim().toLowerCase() == lower) {
        return (accepted: false, reason: 'duplicates a recent cue');
      }
    }

    // Keyword grounding: at least one lexicon keyword must map to a metric
    // that actually deviated. Keywords mapping ONLY to non-deviated metrics
    // mean the cue contradicts what was measured.
    var mappedAny = false;
    for (final word in words) {
      final key = word.toLowerCase().replaceAll(_kNonLetter, '');
      final metricIds = lexicon[key];
      if (metricIds == null) continue;
      mappedAny = true;
      if (metricIds.any(deviatedMetricIds.contains)) {
        return (accepted: true, reason: 'maps to deviated metric');
      }
    }
    return (
      accepted: false,
      reason: mappedAny ? 'contradicts measurements' : 'no metric keyword',
    );
  }
}
