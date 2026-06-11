/// Runs the 16 adversarial fixtures from python_lab against the validator
/// and pins the asset lexicon to the fixtures copy so they cannot drift.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallycoach/core/brain/cue_validator.dart';

void main() {
  final fixtures = jsonDecode(
          File('test/fixtures/validator_cases.json').readAsStringSync())
      as Map<String, dynamic>;
  final assetJson =
      File('assets/prompts/cue_lexicon.json').readAsStringSync();

  test('asset lexicon deep-equals the fixtures lexicon', () {
    final asset = jsonDecode(assetJson) as Map<String, dynamic>;
    expect(asset['lexicon'], fixtures['lexicon']);
    expect(asset['max_words'], fixtures['max_words']);
  });

  final validator = CueValidator.fromJsonString(assetJson);

  for (final rawCase in fixtures['cases'] as List) {
    final c = rawCase as Map<String, dynamic>;
    test('${c['expect']}: ${c['reason']}', () {
      final verdict = validator.validate(
        c['cue'] as String,
        deviatedMetricIds: {
          for (final id in c['deviated'] as List) id as String,
        },
        recentCues: [for (final r in c['recent'] as List) r as String],
      );
      expect(verdict.accepted, c['expect'] == 'accept',
          reason: 'cue: "${c['cue']}" — ${verdict.reason}');
    });
  }
}
