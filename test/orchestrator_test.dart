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
}
