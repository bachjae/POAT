/// Riverpod wiring for the app's long-lived services.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/brain/cue_validator.dart';
import '../core/brain/llm_runner.dart';
import '../core/brain/model_manager.dart';
import '../core/brain/prompt_builder.dart';
import '../core/coach/personality.dart';
import '../core/coach/tts_coach.dart';
import '../core/engine/cue_prioritizer.dart';
import '../core/engine/reference_library.dart';
import '../core/pose/pose_source.dart';
import '../core/camera/camera_pose_source.dart';
import '../core/session/orchestrator.dart';
import '../core/session/summary_generator.dart';
import '../core/storage/database.dart';
import '../core/storage/session_repository.dart';

Future<String> _loadAsset(String path) => rootBundle.loadString(path);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = Provider<SessionRepository>(
    (ref) => SessionRepository(ref.watch(databaseProvider)));

final referenceLibraryProvider =
    FutureProvider<ReferenceLibrary>((ref) => ReferenceLibrary.load(_loadAsset));

final drillCatalogProvider = FutureProvider<DrillCatalog>(
    (ref) async => DrillCatalog.fromJsonString(
        await _loadAsset('assets/drills.json')));

final promptBuilderProvider =
    FutureProvider<PromptBuilder>((ref) => PromptBuilder.load(_loadAsset));

final cueValidatorProvider = FutureProvider<CueValidator>((ref) async =>
    CueValidator.fromJsonString(
        await _loadAsset('assets/prompts/cue_lexicon.json')));

final modelManagerProvider = FutureProvider<ModelManager>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return ModelManager.production(
      targetDir: Directory('${dir.path}/models'));
});

final brainStatusProvider = FutureProvider<BrainStatus>((ref) async {
  final manager = await ref.watch(modelManagerProvider.future);
  return manager.status;
});

/// Null in Lite mode (model absent / RAM gate / not yet prepared).
/// Prefers the imported Pro model when available.
final llmRunnerProvider = FutureProvider<LlmRunner?>((ref) async {
  final manager = await ref.watch(modelManagerProvider.future);
  final proReady = (await manager.proStatus) == BrainStatus.ready;
  final bundledReady =
      (await manager.status) == BrainStatus.ready && !manager.liteOnly;
  if (!proReady && !bundledReady) return null;
  final runner = GemmaLlmRunner(
    modelManager: manager,
    modelPathOverride: proReady ? manager.proModelFilePath : null,
  );
  ref.onDispose(runner.dispose);
  return runner;
});

final phraseBankProvider = FutureProvider.family<PhraseBank, String>(
    (ref, coachId) => PhraseBank.load(coachId, _loadAsset));

/// Draft configuration assembled across the setup screens.
class SessionDraft {
  const SessionDraft({
    this.type = 'full',
    this.coachId = 'maya',
    this.strokeSequence = const [],
    this.goalMetricId,
  });

  final String type;
  final String coachId;

  /// Ordered list of up to 3 strokes for multi-stroke sessions. Empty =
  /// single-stroke (uses [type]).
  final List<String> strokeSequence;

  /// Optional goal metric to pre-seed the focus manager.
  final String? goalMetricId;

  SessionDraft copyWith({
    String? type,
    String? coachId,
    List<String>? strokeSequence,
    Object? goalMetricId = _sentinel,
  }) =>
      SessionDraft(
        type: type ?? this.type,
        coachId: coachId ?? this.coachId,
        strokeSequence: strokeSequence ?? this.strokeSequence,
        goalMetricId:
            goalMetricId == _sentinel ? this.goalMetricId : goalMetricId as String?,
      );
}

const _sentinel = Object();

class SessionDraftNotifier extends Notifier<SessionDraft> {
  @override
  SessionDraft build() => const SessionDraft();

  void setType(String type) => state = state.copyWith(type: type);

  void setCoach(String coachId) => state = state.copyWith(coachId: coachId);

  /// Toggles [stroke] in the sequence (max 3). Single-stroke drills ('full',
  /// 'footwork') are mutually exclusive with multi-stroke sequences.
  void toggleStroke(String stroke) {
    final current = List<String>.from(state.strokeSequence);
    if (current.contains(stroke)) {
      current.remove(stroke);
      final newType = current.isEmpty ? state.type : current.first;
      state = state.copyWith(strokeSequence: current, type: newType);
    } else {
      if (stroke == 'full' || stroke == 'footwork') {
        state = state.copyWith(type: stroke, strokeSequence: []);
      } else if (current.length < 3) {
        current.add(stroke);
        state = state.copyWith(
            strokeSequence: current, type: current.first);
      }
    }
  }

  void setGoalMetricId(String? metricId) =>
      state = state.copyWith(goalMetricId: metricId);
}

final sessionDraftProvider =
    NotifierProvider<SessionDraftNotifier, SessionDraft>(
        SessionDraftNotifier.new);

/// The active session's moving parts, built when camera setup opens and
/// torn down after the summary is stored.
class ActiveSession {
  ActiveSession({
    required this.orchestrator,
    required this.coach,
    required this.poseSource,
    required this.bank,
  });

  final SessionOrchestrator orchestrator;
  final TtsCoach coach;
  final PoseSource poseSource;
  final PhraseBank bank;

  CameraPoseSource? get cameraSource =>
      poseSource is CameraPoseSource ? poseSource as CameraPoseSource : null;

  Future<void> dispose() async {
    await orchestrator.dispose();
    await coach.dispose();
    await poseSource.stop();
  }
}

class ActiveSessionNotifier extends Notifier<ActiveSession?> {
  @override
  ActiveSession? build() => null;

  Future<ActiveSession> start() async {
    await stop();
    final draft = ref.read(sessionDraftProvider);
    final repository = ref.read(repositoryProvider);
    final bank = await ref.read(phraseBankProvider(draft.coachId).future);
    final references = await ref.read(referenceLibraryProvider.future);
    final catalog = await ref.read(drillCatalogProvider.future);
    final brain = await ref.read(llmRunnerProvider.future);
    final prompts = await ref.read(promptBuilderProvider.future);
    final validator = await ref.read(cueValidatorProvider.future);
    final skillTier = await repository.getSetting('skill_tier');
    final leftHanded =
        (await repository.getSetting('left_handed')) == 'true';
    final useFrontCamera =
        (await repository.getSetting('use_front_camera')) == 'true';

    final engine = FlutterTtsEngine();
    await engine.configure(
        pitch: bank.personality.pitch, rate: bank.personality.rate);
    final coach = TtsCoach(engine, CueRateLimiter());
    final poseSource =
        CameraPoseSource(preferFrontCamera: useFrontCamera);
    final orchestrator = SessionOrchestrator(
      poseSource: poseSource,
      coach: coach,
      bank: bank,
      references: references,
      repository: repository,
      catalog: catalog,
      config: SessionConfig(
        type: draft.type,
        coachId: draft.coachId,
        skillTier: skillTier,
        leftHanded: leftHanded,
        strokeSequence: draft.strokeSequence,
        goalMetricId: draft.goalMetricId,
      ),
      brain: brain,
      prompts: prompts,
      validator: validator,
      rng: math.Random(),
    );
    final session = ActiveSession(
      orchestrator: orchestrator,
      coach: coach,
      poseSource: poseSource,
      bank: bank,
    );
    state = session;
    return session;
  }

  Future<void> stop() async {
    final s = state;
    state = null;
    await s?.dispose();
  }
}

final activeSessionProvider =
    NotifierProvider<ActiveSessionNotifier, ActiveSession?>(
        ActiveSessionNotifier.new);
