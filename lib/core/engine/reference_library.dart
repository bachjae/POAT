/// Loads the bundled per-stroke reference JSONs (assets/reference/).
library;

import 'dart:convert';

import 'engine_types.dart';
import 'technique_scorer.dart';

class ReferenceLibrary {
  ReferenceLibrary._(this._byStrokeTier);

  /// stroke id -> tier -> reference.
  final Map<String, Map<String, StrokeReference>> _byStrokeTier;

  static const tiers = ['beginner', 'intermediate', 'advanced'];

  static Future<ReferenceLibrary> load(
      Future<String> Function(String assetPath) loadAsset) async {
    final byStroke = <String, Map<String, StrokeReference>>{};
    for (final stroke in Stroke.values) {
      final raw = jsonDecode(await loadAsset('assets/reference/${stroke.id}.json'))
          as Map<String, dynamic>;
      final levels = raw['skill_levels'] as Map<String, dynamic>;
      byStroke[stroke.id] = {
        for (final tier in levels.keys)
          tier: StrokeReference.fromJson(levels[tier] as Map<String, dynamic>),
      };
    }
    return ReferenceLibrary._(byStroke);
  }

  StrokeReference? referenceFor(Stroke stroke, String tier) =>
      _byStrokeTier[stroke.id]?[tier] ?? _byStrokeTier[stroke.id]?['intermediate'];
}
