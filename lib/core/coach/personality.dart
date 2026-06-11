/// Coach personalities and their phrase banks (PRD FR-8).
///
/// Three coaches ship as JSON banks in `assets/phrases/`: Maya (encouraging),
/// Coach K (direct), Doc (analytical). Each bank carries voice parameters
/// for TTS plus phrase variants per cue slot so live coaching never sounds
/// robotic. The deterministic engine cue text is always available as a
/// fallback when a slot is missing.
library;

import 'dart:convert';
import 'dart:math' as math;

const coachIds = ['maya', 'coach_k', 'doc'];

class Personality {
  const Personality({
    required this.id,
    required this.name,
    required this.tagline,
    required this.style,
    required this.preview,
    required this.pitch,
    required this.rate,
  });

  final String id;
  final String name;
  final String tagline;

  /// One-line voice description, injected into Brain prompts.
  final String style;

  /// Short line spoken when the coach chip is tapped (1s voice preview).
  final String preview;
  final double pitch;
  final double rate;
}

class PhraseBank {
  PhraseBank._(this.personality, this._phrases);

  factory PhraseBank.fromJsonString(String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final phrases = <String, List<String>>{
      for (final e in (decoded['phrases'] as Map<String, dynamic>).entries)
        e.key: (e.value as List).cast<String>(),
    };
    return PhraseBank._(
      Personality(
        id: decoded['id'] as String,
        name: decoded['name'] as String,
        tagline: decoded['tagline'] as String,
        style: decoded['style'] as String,
        preview: decoded['preview'] as String,
        pitch: (decoded['pitch'] as num).toDouble(),
        rate: (decoded['rate'] as num).toDouble(),
      ),
      phrases,
    );
  }

  static Future<PhraseBank> load(
    String coachId,
    Future<String> Function(String assetPath) loadAsset,
  ) async =>
      PhraseBank.fromJsonString(
          await loadAsset('assets/phrases/$coachId.json'));

  final Personality personality;
  final Map<String, List<String>> _phrases;
  final Map<String, int> _lastIndex = {};

  /// Variant for a technique cue. Falls back to the deterministic engine
  /// cue when the slot is missing from the bank.
  String cueFor(
    String metricId,
    String direction,
    math.Random rng, {
    required String fallback,
  }) {
    final slot = 'cue:$metricId:$direction';
    if (!_phrases.containsKey(slot)) return fallback;
    return pick(slot, rng);
  }

  /// Variant from a named slot (encourage / ack / filler / system:*).
  /// Never returns the same variant twice in a row for a slot.
  String pick(String slot, math.Random rng) {
    final variants = _phrases[slot];
    if (variants == null || variants.isEmpty) {
      throw ArgumentError('Unknown phrase slot: $slot');
    }
    if (variants.length == 1) return variants.first;
    var index = rng.nextInt(variants.length);
    if (index == _lastIndex[slot]) {
      index = (index + 1) % variants.length;
    }
    _lastIndex[slot] = index;
    return variants[index];
  }

  /// All slots in the bank (used by validation tests).
  Iterable<String> get slots => _phrases.keys;

  List<String> variantsFor(String slot) =>
      List.unmodifiable(_phrases[slot] ?? const []);
}
