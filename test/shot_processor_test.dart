/// Drives recorded keypoint streams through the live processor and asserts
/// it reproduces the batch pipeline's verdicts (SPEC §15 integration test).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallycoach/core/engine/engine_types.dart';
import 'package:rallycoach/core/engine/technique_scorer.dart';
import 'package:rallycoach/core/session/shot_processor.dart';

List<PoseFrame> _framesFrom(Map<String, dynamic> vector) => [
      for (final f in vector['input_frames'] as List)
        PoseFrame(
          timestampMs: f['t'] as int,
          keypoints: [
            for (final p in f['kp'] as List)
              [for (final v in p as List) (v as num).toDouble()],
          ],
        ),
    ];

StrokeReference _loadReference(String stroke) {
  final json = jsonDecode(
          File('assets/reference/$stroke.json').readAsStringSync())
      as Map<String, dynamic>;
  return StrokeReference.fromJson(
      json['skill_levels']['intermediate'] as Map<String, dynamic>);
}

void main() {
  final vectors = jsonDecode(
          File('test/fixtures/engine_vectors.json').readAsStringSync())
      as Map<String, dynamic>;

  for (final rawCase in vectors['pipeline'] as List) {
    final c = rawCase as Map<String, dynamic>;
    final expected = c['expected'] as Map<String, dynamic>;
    test('live processor matches batch pipeline: ${c['name']}', () async {
      final processor = ShotStreamProcessor(
        referenceFor: (stroke) =>
            stroke == Stroke.footwork ? null : _loadReference(stroke.id),
      );
      final events = <ShotEvent>[];
      final sub = processor.shots.listen(events.add);
      for (final frame in _framesFrom(c)) {
        processor.feed(frame);
      }
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events.length, 1, reason: 'exactly one shot expected');
      final event = events.single;
      expect(event.stroke.id, expected['stroke']);
      expect(event.view.id, expected['view']);
      expect(event.score.score,
          closeTo((expected['score'] as num).toDouble(), 0.5));
      expect([for (final d in event.score.deviations) d.id],
          expected['deviation_ids']);
      expect(event.wristTrail.length, greaterThan(45));
      await processor.dispose();
    });
  }

  test('visibility transitions: searching -> locked -> lost', () async {
    final vector =
        (vectors['pipeline'] as List).first as Map<String, dynamic>;
    final frames = _framesFrom(vector);
    final processor = ShotStreamProcessor(
        referenceFor: (_) => _loadReference('forehand'));
    final transitions = <PlayerVisibility>[];
    final sub = processor.visibility.listen(transitions.add);

    expect(processor.currentVisibility, PlayerVisibility.searching);
    for (final f in frames.take(20)) {
      processor.feed(f);
    }
    // 15 consecutive low-confidence frames lose the player.
    final blind = [
      for (var i = 0; i < 16; i++)
        PoseFrame(timestampMs: 100000 + i * 33, keypoints: [
          for (var k = 0; k < Kp.count; k++) [0.0, 0.0, 0.05],
        ]),
    ];
    blind.forEach(processor.feed);
    processor.feed(frames[20]);
    await Future<void>.delayed(Duration.zero);
    expect(transitions,
        [PlayerVisibility.locked, PlayerVisibility.lost, PlayerVisibility.locked]);
    await sub.cancel();
    await processor.dispose();
  });

  test('footwork mode emits scored 10s windows', () async {
    final fw = vectors['footwork'] as Map<String, dynamic>;
    final frames = _framesFrom(fw);
    final processor = ShotStreamProcessor(
      footworkMode: true,
      bufferFrames: 400,
      // The fixture spans 9,966 ms (300 frames @30fps), fractionally
      // under the production 10s window.
      footworkWindowMs: 9900,
      referenceFor: (s) =>
          s == Stroke.footwork ? _loadReference('footwork') : null,
    );
    final events = <FootworkEvent>[];
    final sub = processor.footworkWindows.listen(events.add);
    for (final f in frames) {
      processor.feed(f);
    }
    // The fixture spans exactly 10s, so the first frame opens the window
    // and the 10s mark closes it once.
    await Future<void>.delayed(Duration.zero);
    expect(events.length, 1);
    final exp = fw['expected'] as Map<String, dynamic>;
    expect(events.single.window.stanceWidth,
        closeTo((exp['stance_width'] as num).toDouble(), 0.05));
    expect(events.single.score.score, greaterThan(0));
    await sub.cancel();
    await processor.dispose();
  });

  test('recurrence counting over last 10 shots', () {
    final processor = ShotStreamProcessor(referenceFor: (_) => null);
    const dev = MetricDeviation(
      phase: 'contact',
      id: 'elbow_angle',
      value: 100,
      ideal: [120, 150],
      direction: 'low',
      severity: 0.5,
      weight: 0.3,
      cue: '',
    );
    for (var i = 0; i < 12; i++) {
      processor.recordShotDeviations([dev]);
    }
    processor.recordShotDeviations([]);
    expect(processor.recurrenceCounts()['elbow_angle'], 9);
  });
}
