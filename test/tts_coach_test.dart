/// TtsCoach queue behavior: newest-wins, rate limits, system interrupts,
/// caption mirroring, and swing hard-mute.
library;


import 'package:flutter_test/flutter_test.dart';
import 'package:rallycoach/core/coach/tts_coach.dart';
import 'package:rallycoach/core/engine/cue_prioritizer.dart';

class FakeSpeechEngine implements SpeechEngine {
  final List<String> spoken = [];
  final List<String> stops = [];
  Duration speakDuration = Duration.zero;
  bool _speaking = false;

  @override
  Future<void> configure({required double pitch, required double rate}) async {}

  @override
  Future<void> speak(String text) async {
    _speaking = true;
    spoken.add(text);
    if (speakDuration > Duration.zero) {
      await Future<void>.delayed(speakDuration);
    }
    _speaking = false;
  }

  @override
  Future<void> stop() async {
    stops.add('stop');
    _speaking = false;
  }

  @override
  bool get isSpeaking => _speaking;
}

void main() {
  late FakeSpeechEngine engine;
  late DateTime now;
  late TtsCoach coach;

  setUp(() {
    engine = FakeSpeechEngine();
    now = DateTime(2026, 6, 11, 12, 0, 0);
    coach = TtsCoach(engine, CueRateLimiter(), clock: () => now);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('speaks a cue and mirrors it to captions first', () async {
    final captions = <CaptionEvent>[];
    coach.captions.listen(captions.add);
    coach.submit('extend through contact', CoachUtteranceKind.cue,
        metricId: 'elbow_angle');
    await settle();
    expect(engine.spoken, ['extend through contact']);
    expect(captions.single.text, 'extend through contact');
    expect(captions.single.kind, CoachUtteranceKind.cue);
  });

  test('rate limit: second cue within 6s stays queued, speaks after', () async {
    coach.submit('cue one', CoachUtteranceKind.cue, metricId: 'a');
    await settle();
    coach.submit('cue two', CoachUtteranceKind.cue, metricId: 'b');
    await settle();
    expect(engine.spoken, ['cue one']);

    now = now.add(const Duration(seconds: 7));
    coach.submit('cue three', CoachUtteranceKind.cue, metricId: 'c');
    await settle();
    expect(engine.spoken, ['cue one', 'cue three']);
  });

  test('newest wins: queued cue is replaced before speaking', () async {
    coach.submit('first', CoachUtteranceKind.cue, metricId: 'a');
    await settle();
    coach.submit('stale', CoachUtteranceKind.cue, metricId: 'b');
    coach.submit('fresh', CoachUtteranceKind.cue, metricId: 'c');
    now = now.add(const Duration(seconds: 7));
    coach.submit('freshest', CoachUtteranceKind.cue, metricId: 'd');
    await settle();
    expect(engine.spoken, ['first', 'freshest']);
  });

  test('system bypasses limiter and interrupts current speech', () async {
    coach.submit('a cue', CoachUtteranceKind.cue, metricId: 'a');
    await settle();
    coach.submit('I lost you — step back into frame',
        CoachUtteranceKind.system);
    await settle();
    expect(engine.stops, isNotEmpty);
    expect(engine.spoken.last, 'I lost you — step back into frame');
  });

  test('swing in progress mutes and drops the queue', () async {
    coach.onSwingStart();
    coach.submit('mid-swing cue', CoachUtteranceKind.cue, metricId: 'a');
    await settle();
    expect(engine.spoken, isEmpty);
    coach.onSwingEnd();
    await settle();
    // The queued cue was dropped at swing start, not deferred.
    expect(engine.spoken, isEmpty);

    coach.submit('after swing', CoachUtteranceKind.cue, metricId: 'b');
    await settle();
    expect(engine.spoken, ['after swing']);
  });

  test('filler capped at one per 30s', () async {
    coach.submit('stay loose', CoachUtteranceKind.filler);
    await settle();
    now = now.add(const Duration(seconds: 10));
    coach.submit('next ball', CoachUtteranceKind.filler);
    await settle();
    expect(engine.spoken, ['stay loose']);

    now = now.add(const Duration(seconds: 31));
    coach.submit('reset now', CoachUtteranceKind.filler);
    await settle();
    expect(engine.spoken, ['stay loose', 'reset now']);
  });

  test('suppressed metric ids reflect recent cues', () async {
    coach.submit('cue', CoachUtteranceKind.cue, metricId: 'elbow_angle');
    await settle();
    expect(coach.suppressedMetricIds(), contains('elbow_angle'));
    expect(coach.recentMetricIds(), ['elbow_angle']);
  });

  test('captions arrive in spoken order', () async {
    final captions = <String>[];
    coach.captions.listen((c) => captions.add(c.text));
    coach.submit('one', CoachUtteranceKind.cue, metricId: 'a');
    await settle();
    now = now.add(const Duration(seconds: 7));
    coach.submit('two', CoachUtteranceKind.encouragement);
    await settle();
    coach.submit('sys', CoachUtteranceKind.system);
    await settle();
    expect(captions, ['one', 'two', 'sys']);
    expect(engine.spoken, ['one', 'two', 'sys']);
  });
}
