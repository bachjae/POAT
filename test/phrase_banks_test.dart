/// Validates the three shipped phrase banks against the SPEC §8 contract.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rallycoach/core/coach/personality.dart';

const _cueSlots = [
  'cue:shoulder_turn:low', 'cue:shoulder_turn:high',
  'cue:knee_flexion:low', 'cue:knee_flexion:high',
  'cue:trunk_tilt:low', 'cue:trunk_tilt:high',
  'cue:elbow_angle:low', 'cue:elbow_angle:high',
  'cue:hip_shoulder_sep:low', 'cue:hip_shoulder_sep:high',
  'cue:contact_in_front:low', 'cue:contact_in_front:high',
  'cue:contact_height:low', 'cue:contact_height:high',
  'cue:wrist_finish_height:low', 'cue:wrist_finish_height:high',
  'cue:prep_before_contact_ms:low', 'cue:prep_before_contact_ms:high',
  'cue:split_step_rate:low', 'cue:split_step_rate:high',
  'cue:stance_width:low', 'cue:stance_width:high',
  'cue:recovery_steps:low', 'cue:recovery_steps:high',
];

const _otherSlots = [
  'encourage', 'ack', 'filler',
  'system:see_you', 'system:lost_you', 'system:paused',
  'system:session_start', 'system:session_end', 'system:limited_view',
  'milestone:best', 'milestone:streak',
  'checkin:up', 'checkin:down', 'checkin:steady',
];

void main() {
  final banks = {
    for (final id in coachIds)
      id: PhraseBank.fromJsonString(
          File('assets/phrases/$id.json').readAsStringSync()),
  };

  test('all three coaches load with distinct voice parameters', () {
    expect(banks.length, 3);
    final pitches = {for (final b in banks.values) b.personality.pitch};
    expect(pitches.length, 3, reason: 'pitches must differ');
    for (final b in banks.values) {
      expect(b.personality.preview, isNotEmpty);
      expect(b.personality.style, isNotEmpty);
    }
  });

  for (final entry in banks.entries) {
    final id = entry.key;
    final bank = entry.value;
    test('$id: covers every slot with valid phrases', () {
      for (final slot in [..._cueSlots, ..._otherSlots]) {
        final variants = bank.variantsFor(slot);
        expect(variants, isNotEmpty, reason: '$id missing $slot');
        if (slot.startsWith('cue:')) {
          expect(variants.length, greaterThanOrEqualTo(10),
              reason: '$id $slot needs >=10 variants');
        } else {
          expect(variants.length, greaterThanOrEqualTo(4));
        }
        for (final v in variants) {
          expect(v.split(' ').length, lessThanOrEqualTo(8),
              reason: '$id $slot: "$v" exceeds 8 words');
          expect(v.contains(RegExp(r'\d')), isFalse,
              reason: '$id $slot: "$v" contains digits');
        }
      }
    });
  }

  test('PRD-exact system strings are the first variants', () {
    for (final bank in banks.values) {
      expect(bank.variantsFor('system:see_you').first, 'I can see you');
      expect(bank.variantsFor('system:lost_you').first,
          'I lost you — step back into frame');
      expect(bank.variantsFor('system:paused').first,
          'Paused — step back in when ready');
    }
  });

  test('pick never repeats the same variant twice in a row', () {
    final bank = banks['maya']!;
    final rng = math.Random(7);
    String? last;
    for (var i = 0; i < 200; i++) {
      final v = bank.pick('encourage', rng);
      expect(v, isNot(last));
      last = v;
    }
  });

  test('cueFor falls back to the engine cue for unknown slots', () {
    final bank = banks['doc']!;
    expect(
      bank.cueFor('nonexistent_metric', 'low', math.Random(1),
          fallback: 'engine cue text'),
      'engine cue text',
    );
    expect(
      bank.cueFor('elbow_angle', 'low', math.Random(1), fallback: 'x'),
      isNot('x'),
    );
  });
}
