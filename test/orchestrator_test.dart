/// Full session loop: fixture pose stream → engine → cues → Brain race →
/// persistence, with every hardware seam faked.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallycoach/core/brain/cue_validator.dart';
import 'package:rallycoach/core/brain/llm_runner.dart';
import 'package:rallycoach/core/brain/prompt_builder.dart';
import 'package:rallycoach/core/coach/personality.dart';
import 'package:rallycoach/core/coach/tts_coach.dart';
import 'package:rallycoach/core/engine/cue_prioritizer.dart';
import 'package:rallycoach/core/engine/engine_types.dart';
import 'package:rallycoach/core/engine/reference_library.dart';
import 'package:rallycoach/core/pose/pose_source.dart';
import 'package:rallycoach/core/session/orchestrator.dart';
import 'package:rallycoach/core/session/summary_generator.dart';
import 'package:rallycoach/core/storage/database.dart';
import 'package:rallycoach/core/storage/session_repository.dart';

class RecordingSpeechEngine implements SpeechEngine {
  final List<String> spoken = [];

  @override
  Future<void> configure({required double pitch, required double rate}) async {}

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}

  @override
  bool get isSpeaking => false;
}

List<PoseFrame> _vectorFrames(String name) {
  final vectors = jsonDecode(
          File('test/fixtures/engine_vectors.json').readAsStringSync())
      as Map<String, dynamic>;
  final c = (vectors['pipeline'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((v) => v['name'] == name);
  return [
    for (final f in c['input_frames'] as List)
      PoseFrame(
        timestampMs: f['t'] as int,
        keypoints: [
          for (final p in f['kp'] as List)
            [for (final v in p as List) (v as num).toDouble()],
        ],
      ),
  ];
}

Future<void> settle([int turns = 20]) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late AppDatabase db;
  late SessionRepository repository;
  late RecordingSpeechEngine engine;
  late TtsCoach coach;
  late DateTime now;
  late ReferenceLibrary references;
  late PhraseBank bank;
  late PromptBuilder prompts;
  late CueValidator validator;
  late DrillCatalog catalog;

  setUpAll(() async {
    references =
        await ReferenceLibrary.load((p) async => File(p).readAsString());
    bank = PhraseBank.fromJsonString(
        File('assets/phrases/coach_k.json').readAsStringSync());
    prompts =
        await PromptBuilder.load((p) async => File(p).readAsString());
    validator = CueValidator.fromJsonString(
        File('assets/prompts/cue_lexicon.json').readAsStringSync());
    catalog = DrillCatalog.fromJsonString(
        File('assets/drills.json').readAsStringSync());
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = SessionRepository(db);
    engine = RecordingSpeechEngine();
    now = DateTime(2026, 6, 11, 9, 0);
    coach = TtsCoach(engine, CueRateLimiter(), clock: () => now);
  });

  tearDown(() async {
    await db.close();
  });

  SessionOrchestrator orchestrator({LlmRunner? brain, bool loop = false}) =>
      SessionOrchestrator(
        poseSource: FixturePoseSource(
            _vectorFrames('forehand_diagonal_q0.5_s12'),
            loop: loop),
        coach: coach,
        bank: bank,
        references: references,
        repository: repository,
        catalog: catalog,
        config: const SessionConfig(
          type: 'forehand',
          coachId: 'coach_k',
          skillTier: 'intermediate',
        ),
        brain: brain,
        prompts: prompts,
        validator: validator,
        clock: () => now,
        rng: math.Random(3),
      );

  test('lite-mode session end to end: setup, lock, cue, persist', () async {
    final o = orchestrator();
    final phases = <SessionPhase>[];
    o.phase.listen(phases.add);

    await o.beginSetup();
    await settle();
    expect(engine.spoken, isNotEmpty,
        reason: 'player lock announces "I can see you"');
    expect(bank.variantsFor('system:see_you'), contains(engine.spoken.first));

    o.beginLive();
    await settle(250);

    expect(o.currentStats.shots, 1);
    expect(o.currentStats.lastScore, greaterThan(0));
    // The deviated swing produced a spoken technique cue.
    final cueTexts = engine.spoken.skip(2);
    expect(cueTexts, isNotEmpty);

    now = now.add(const Duration(minutes: 12));
    final result = await o.end();
    expect(o.currentPhase, SessionPhase.summary);
    expect(result.summary.overallScore, greaterThan(0));
    expect(result.summary.improvements, isNotEmpty);

    final stored = await repository.lastSession();
    expect(stored, isNotNull);
    expect(stored!.type, 'forehand');
    expect(stored.shotsTotal, 1);
    expect(stored.durationS, 12 * 60);
    final shots = await repository.shotsForSession(result.sessionId);
    expect(shots.single.stroke, 'forehand');

    // Deep tracking: the full deviation list rides along with each shot…
    final deviations = jsonDecode(shots.single.deviations) as List;
    expect(deviations, isNotEmpty,
        reason: 'the deviated fixture swing stores every deviation');
    expect((deviations.first as Map)['id'], shots.single.topDeviationId);
    expect((deviations.first as Map).keys,
        containsAll(['id', 'phase', 'direction', 'severity']));
    // …and the computed insights blob persists with the session.
    final insights =
        jsonDecode(stored.insights) as Map<String, dynamic>;
    expect((insights['strokes'] as Map).keys, contains('forehand'));
    expect(insights['timeline'], hasLength(1));
    expect(insights['best_shot_index'], 0);
    await o.dispose();
  });

  test('brain cue replaces a queued rule cue when validated in time',
      () async {
    final brain = FakeLlmRunner(
        fallbackResponse: 'Turn the shoulders sooner, stay smooth');
    // Exactly two shots: the base fixture plus a time-shifted copy, so no
    // third rule cue can clobber the queued brain replacement.
    final base = _vectorFrames('forehand_diagonal_q0.5_s12');
    final shift = base.last.timestampMs + 500;
    final twoShots = [
      ...base,
      for (final f in base)
        PoseFrame(timestampMs: f.timestampMs + shift, keypoints: f.keypoints),
    ];
    final o = SessionOrchestrator(
      poseSource: FixturePoseSource(twoShots),
      coach: coach,
      bank: bank,
      references: references,
      repository: repository,
      catalog: catalog,
      config: const SessionConfig(
          type: 'forehand', coachId: 'coach_k', skillTier: 'intermediate'),
      brain: brain,
      prompts: prompts,
      validator: validator,
      clock: () => now,
      rng: math.Random(3),
    );
    await o.beginSetup();
    await settle();
    o.beginLive();
    await settle(700);

    expect(o.currentStats.shots, 2);
    expect(brain.prompts.length, 2, reason: 'brain raced both shots');
    // Shot 1's rule cue spoke instantly (fresh limiter) so its brain reply
    // was discarded; shot 2's rule cue is still queued inside the 6s window
    // and the validated brain cue replaced it.
    expect(engine.spoken.join(' '),
        isNot(contains('Turn the shoulders sooner')));
    now = now.add(const Duration(seconds: 7));
    coach.onSwingEnd();
    await settle();
    expect(engine.spoken.last, 'Turn the shoulders sooner, stay smooth',
        reason: 'queued rule cue was replaced by the brain cue');
    await o.dispose();
  });

  test('brain summary headline lands in the stored session', () async {
    final brain = FakeLlmRunner(responses: [
      'irrelevant cue that will be rejected 123',
      '{"headline": "Strong base, late shoulders", '
          '"what_worked": ["Contact"], "work_on": ["Turn"], '
          '"encouragement": "Your contact held up all session."}',
    ]);
    final o = orchestrator(brain: brain);
    await o.beginSetup();
    await settle();
    o.beginLive();
    await settle(250);
    expect(o.currentStats.shots, 1, reason: 'shot must land before end()');
    final result = await o.end();
    final stored = await repository.lastSession();
    expect(stored!.headline, 'Strong base, late shoulders');
    expect(stored.encouragement, 'Your contact held up all session.');
    expect(result.sessionId, stored.id);
    await o.dispose();
  });

  test('calibration: tier resolves after ten shots', () async {
    final o = SessionOrchestrator(
      poseSource: FixturePoseSource(
          _vectorFrames('forehand_diagonal_q0.5_s12'),
          loop: true),
      coach: coach,
      bank: bank,
      references: references,
      repository: repository,
      catalog: catalog,
      config: const SessionConfig(
          type: 'forehand', coachId: 'maya', skillTier: null),
      clock: () => now,
      rng: math.Random(5),
    );
    expect(o.isCalibrating, isTrue);
    await o.beginSetup();
    await settle();
    o.beginLive();
    expect(o.currentPhase, SessionPhase.calibrating);

    while (o.currentStats.shots < 10) {
      now = now.add(const Duration(seconds: 1));
      await settle(50);
    }
    expect(o.isCalibrating, isFalse);
    expect(o.currentPhase, SessionPhase.live);
    expect(ReferenceLibrary.tiers, contains(o.skillTier));
    expect(await repository.getSetting('skill_tier'), o.skillTier);
    await o.end();
    await o.dispose();
  });

  test('focus manager pre-seeded by goal appears in brain prompt', () async {
    final brain = FakeLlmRunner(
        fallbackResponse: 'turn those shoulders sooner stay smooth');
    final promptsCapture = <String>[];
    final capturingBrain = _CapturingLlmRunner(brain, promptsCapture);
    final o = SessionOrchestrator(
      poseSource: FixturePoseSource(
          _vectorFrames('forehand_diagonal_q0.5_s12'),
          loop: true),
      coach: coach,
      bank: bank,
      references: references,
      repository: repository,
      catalog: catalog,
      config: const SessionConfig(
        type: 'forehand',
        coachId: 'coach_k',
        skillTier: 'intermediate',
        goalMetricId: 'elbow_angle',
      ),
      brain: capturingBrain,
      prompts: prompts,
      validator: validator,
      clock: () => now,
      rng: math.Random(7),
    );
    await o.beginSetup();
    await settle();
    o.beginLive();
    await settle(250);
    expect(o.currentStats.shots, greaterThan(0));
    expect(promptsCapture, isNotEmpty,
        reason: 'brain should have been called at least once');
    expect(promptsCapture.any((p) => p.contains('Goal: elbow_angle')), isTrue,
        reason: 'goal metric injected into brain prompt');
    await o.end();
    await o.dispose();
  });

  test('ten-shot check-in milestone speaks the running average', () async {
    // Exactly ten time-shifted copies of the fixture swing → ten shots.
    final base = _vectorFrames('forehand_diagonal_q0.5_s12');
    final span = base.last.timestampMs + 500;
    final tenShots = [
      for (var copy = 0; copy < 10; copy++)
        for (final f in base)
          PoseFrame(
              timestampMs: f.timestampMs + span * copy,
              keypoints: f.keypoints),
    ];
    final o = SessionOrchestrator(
      poseSource: FixturePoseSource(tenShots),
      coach: coach,
      bank: bank,
      references: references,
      repository: repository,
      catalog: catalog,
      config: const SessionConfig(
          type: 'forehand', coachId: 'coach_k', skillTier: 'intermediate'),
      clock: () => now,
      rng: math.Random(3),
    );
    final lastScores = <int>{};
    var avgAt10 = -1;
    o.stats.listen((s) {
      lastScores.add(s.lastScore);
      if (s.shots == 10) avgAt10 = s.avgScore;
    });
    await o.beginSetup();
    await settle();
    o.beginLive();
    while (o.currentStats.shots < 10) {
      now = now.add(const Duration(seconds: 2));
      await settle(50);
    }
    expect(lastScores, hasLength(1),
        reason: 'identical fixture copies must score identically');
    // Clear the rate-limiter window so the queued milestone drains.
    now = now.add(const Duration(seconds: 7));
    coach.onSwingEnd();
    await settle();

    // Identical scores → flat trend → one of the steady check-in lines,
    // with the measured average substituted in.
    final expected = [
      for (final v in bank.variantsFor('checkin:steady'))
        v.replaceAll('{avg}', '$avgAt10'),
    ];
    expect(engine.spoken.last, isIn(expected));
    final stats = o.currentStats;
    expect(stats.recentScores, hasLength(10));
    expect(stats.strokeCounts['forehand'], 10);
    await o.end();
    await o.dispose();
  });

  test('two-stroke sequence transitions after 20 shots and announces', () async {
    final twoShots = _vectorFrames('forehand_diagonal_q0.5_s12');
    final o = SessionOrchestrator(
      poseSource: FixturePoseSource(twoShots, loop: true),
      coach: coach,
      bank: bank,
      references: references,
      repository: repository,
      catalog: catalog,
      config: const SessionConfig(
        type: 'forehand',
        coachId: 'coach_k',
        skillTier: 'intermediate',
        strokeSequence: ['forehand', 'backhand'],
      ),
      clock: () => now,
      rng: math.Random(11),
    );
    await o.beginSetup();
    await settle();
    o.beginLive();

    // Drive shots until the transition fires (budget = 20).
    while (o.currentStats.shots < 20) {
      now = now.add(const Duration(seconds: 2));
      await settle(50);
    }
    // One more settle to let the transition announcement queue.
    await settle(20);

    final spokenJoined = engine.spoken.join(' ');
    expect(
      spokenJoined,
      anyOf(
        contains('backhand'),
        contains('Backhand'),
      ),
      reason: 'stroke_transition phrase announced with next stroke name',
    );

    final result = await o.end();
    final stored = await repository.lastSession();
    expect(jsonDecode(stored!.strokeSequence),
        equals(['forehand', 'backhand']),
        reason: 'sequence persisted in session row');
    expect(result.sessionId, stored.id);
    await o.dispose();
  });
}

/// Wraps a FakeLlmRunner and captures all generated prompts.
class _CapturingLlmRunner implements LlmRunner {
  _CapturingLlmRunner(this._inner, this._captured);
  final LlmRunner _inner;
  final List<String> _captured;

  @override
  Future<bool> isAvailable() => _inner.isAvailable();

  @override
  Future<void> warmUp() => _inner.warmUp();

  @override
  Future<String> generate(String prompt,
      {required int maxTokens,
      double temperature = 0.4,
      Duration? deadline}) {
    _captured.add(prompt);
    return _inner.generate(prompt,
        maxTokens: maxTokens, temperature: temperature, deadline: deadline);
  }

  @override
  Stream<String> generateStream(String prompt,
      {required int maxTokens, double temperature = 0.4}) {
    _captured.add(prompt);
    return _inner.generateStream(prompt,
        maxTokens: maxTokens, temperature: temperature);
  }

  @override
  Future<void> dispose() => _inner.dispose();
}
