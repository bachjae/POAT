/// Session state machine + the live coaching loop (SPEC §12).
///
/// idle → setup(detecting player) → calibrating? → live ⇄ paused →
/// ending(flush) → summary(compute + persist) → idle.
///
/// Per shot: the deterministic rule cue speaks first (live tier, always
/// available); the Coach Brain races a 4-second deadline in the background
/// and, when it returns a cue that passes the validator BEFORE the rule cue
/// has been spoken, replaces it in the newest-wins queue (SPEC §9.2).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../brain/cue_validator.dart';
import '../brain/llm_runner.dart';
import '../brain/prompt_builder.dart';
import '../coach/personality.dart';
import '../coach/tts_coach.dart';
import '../engine/cue_prioritizer.dart';
import '../engine/engine_types.dart';
import '../engine/reference_library.dart';
import '../pose/pose_source.dart';
import '../storage/session_repository.dart';
import 'calibration.dart';
import 'shot_processor.dart';
import 'summary_generator.dart';

enum SessionPhase { idle, setup, calibrating, live, paused, ending, summary }

class SessionConfig {
  const SessionConfig({
    required this.type,
    required this.coachId,
    this.skillTier,
    this.leftHanded = false,
  });

  /// Stroke id or 'full'.
  final String type;
  final String coachId;

  /// Null on the very first session — triggers the 10-shot calibration.
  final String? skillTier;
  final bool leftHanded;
}

class LiveStats {
  const LiveStats({
    required this.shots,
    required this.lastScore,
    required this.avgScore,
  });

  final int shots;
  final int lastScore;
  final int avgScore;

  static const zero = LiveStats(shots: 0, lastScore: 0, avgScore: 0);
}

class SessionResult {
  const SessionResult({required this.sessionId, required this.summary});

  final int sessionId;
  final SessionSummaryData summary;
}

class SessionOrchestrator {
  SessionOrchestrator({
    required this.poseSource,
    required this.coach,
    required this.bank,
    required this.references,
    required this.repository,
    required this.catalog,
    required this.config,
    this.brain,
    this.prompts,
    this.validator,
    DateTime Function()? clock,
    this.brainDeadline = const Duration(seconds: 4),
    math.Random? rng,
  })  : _clock = clock ?? DateTime.now,
        _rng = rng ?? math.Random() {
    _tier = config.skillTier ?? 'intermediate';
    _calibrating = config.skillTier == null;
    processor = ShotStreamProcessor(
      referenceFor: (stroke) => references.referenceFor(stroke, _tier),
      leftHanded: config.leftHanded,
      footworkMode: config.type == Stroke.footwork.id,
    );
  }

  final PoseSource poseSource;
  final TtsCoach coach;
  final PhraseBank bank;
  final ReferenceLibrary references;
  final SessionRepository repository;
  final DrillCatalog catalog;
  final SessionConfig config;

  /// Lite mode when null — the rule engine carries every cue.
  final LlmRunner? brain;
  final PromptBuilder? prompts;
  final CueValidator? validator;
  final Duration brainDeadline;

  late final ShotStreamProcessor processor;
  final DateTime Function() _clock;
  final math.Random _rng;

  final _phase = StreamController<SessionPhase>.broadcast();
  final _stats = StreamController<LiveStats>.broadcast();

  Stream<SessionPhase> get phase => _phase.stream;
  Stream<LiveStats> get stats => _stats.stream;

  SessionPhase _current = SessionPhase.idle;
  SessionPhase get currentPhase => _current;
  LiveStats _liveStats = LiveStats.zero;
  LiveStats get currentStats => _liveStats;

  late String _tier;
  late bool _calibrating;
  String get skillTier => _tier;
  bool get isCalibrating => _calibrating;

  final List<SummaryShot> _shots = [];
  final List<double> _recentScores = [];
  final List<String> _recentCueTexts = [];
  int _spokenCueCount = 0;
  DateTime? _startedAt;
  DateTime? _lostSince;
  bool _userPaused = false;

  final List<StreamSubscription<Object?>> _subs = [];

  void _setPhase(SessionPhase p) {
    if (p == _current) return;
    _current = p;
    if (!_phase.isClosed) _phase.add(p);
  }

  /// Camera-setup screen entered; pose source starts and we wait for lock.
  Future<void> beginSetup() async {
    _setPhase(SessionPhase.setup);
    _subs.add(coach.captions.listen((c) {
      if (c.kind == CoachUtteranceKind.cue) _spokenCueCount++;
    }));
    _subs.add(processor.visibility.listen(_onVisibility));
    _subs.add(processor.shots.listen(_onShot));
    _subs.add(processor.footworkWindows.listen(_onFootworkWindow));
    _subs.add(poseSource.frames.listen(processor.feed));
    // Load the model during setup so the first shot isn't cold (SPEC §9.1).
    final b = brain;
    if (b != null) {
      unawaited(() async {
        try {
          if (await b.isAvailable()) await b.warmUp();
        } catch (_) {
          // Brain stays cold; Lite cues carry the session.
        }
      }());
    }
    await poseSource.start();
  }

  /// User tapped BEGIN on the setup screen.
  void beginLive() {
    _startedAt = _clock();
    _setPhase(_calibrating ? SessionPhase.calibrating : SessionPhase.live);
    coach.submit(bank.pick('system:session_start', _rng),
        CoachUtteranceKind.system);
  }

  void pause() {
    _userPaused = true;
    _setPhase(SessionPhase.paused);
    coach.submit(bank.pick('system:paused', _rng), CoachUtteranceKind.system);
  }

  void resume() {
    _userPaused = false;
    _setPhase(_calibrating ? SessionPhase.calibrating : SessionPhase.live);
  }

  void _onVisibility(PlayerVisibility v) {
    switch (v) {
      case PlayerVisibility.locked:
        if (_current == SessionPhase.setup) {
          coach.submit(
              bank.pick('system:see_you', _rng), CoachUtteranceKind.system);
        } else if (_current == SessionPhase.paused && !_userPaused) {
          resume();
        }
        _lostSince = null;
      case PlayerVisibility.lost:
        if (_current == SessionPhase.live ||
            _current == SessionPhase.calibrating) {
          coach.submit(
              bank.pick('system:lost_you', _rng), CoachUtteranceKind.system);
          _lostSince = _clock();
        }
      case PlayerVisibility.searching:
        break;
    }
  }

  /// Player out of frame >10s auto-pauses (SPEC §12). Driven by the UI
  /// ticker so no internal timer is needed.
  void tick() {
    final lost = _lostSince;
    if (lost != null &&
        !_userPaused &&
        (_current == SessionPhase.live ||
            _current == SessionPhase.calibrating) &&
        _clock().difference(lost).inSeconds > 10) {
      _setPhase(SessionPhase.paused);
    }
  }

  void _onShot(ShotEvent event) {
    if (_current != SessionPhase.live &&
        _current != SessionPhase.calibrating) {
      return;
    }
    final startedAt = _startedAt ?? _clock();
    _shots.add((
      stroke: event.stroke,
      score: event.score,
      tOffsetMs: _clock().difference(startedAt).inMilliseconds,
    ));
    processor.recordShotDeviations(event.score.deviations);
    _recentScores.add(event.score.score);
    if (_recentScores.length > 10) _recentScores.removeAt(0);

    final scores = [for (final s in _shots) s.score.score];
    _liveStats = LiveStats(
      shots: _shots.length,
      lastScore: event.score.score.round(),
      avgScore:
          (scores.reduce((a, b) => a + b) / scores.length).round(),
    );
    if (!_stats.isClosed) _stats.add(_liveStats);

    if (_calibrating && _shots.length >= 10) {
      _tier = skillTierForScores(scores);
      _calibrating = false;
      unawaited(repository.setSetting('skill_tier', _tier));
      _setPhase(SessionPhase.live);
    }

    _speakForShot(event);
  }

  void _onFootworkWindow(FootworkEvent event) {
    if (_current != SessionPhase.live &&
        _current != SessionPhase.calibrating) {
      return;
    }
    _shots.add((
      stroke: Stroke.footwork,
      score: event.score,
      tOffsetMs:
          _clock().difference(_startedAt ?? _clock()).inMilliseconds,
    ));
    processor.recordShotDeviations(event.score.deviations);
    final scores = [for (final s in _shots) s.score.score];
    _liveStats = LiveStats(
      shots: _shots.length,
      lastScore: event.score.score.round(),
      avgScore: (scores.reduce((a, b) => a + b) / scores.length).round(),
    );
    if (!_stats.isClosed) _stats.add(_liveStats);
    _speakForShot(ShotEvent(
      stroke: Stroke.footwork,
      score: event.score,
      view: processor.majorityView,
      peakTimestampMs: 0,
      measured: const {},
      wristTrail: const [],
    ));
  }

  void _speakForShot(ShotEvent event) {
    final deviations = event.score.deviations;
    if (deviations.isEmpty) {
      coach.submit(bank.pick(
          _rng.nextBool() ? 'encourage' : 'ack', _rng),
          CoachUtteranceKind.encouragement);
      return;
    }
    final picked = pickCue(
      deviations,
      coach.suppressedMetricIds(),
      processor.recurrenceCounts(),
    );
    if (picked == null) {
      // Everything deviated was cued recently; acknowledge effort instead.
      coach.submit(bank.pick('ack', _rng), CoachUtteranceKind.encouragement);
      return;
    }
    final ruleText = bank.cueFor(picked.id, picked.direction, _rng,
        fallback: picked.cue);
    final cueCountAtSubmit = _spokenCueCount;
    coach.submit(ruleText, CoachUtteranceKind.cue, metricId: picked.id);
    _rememberCue(ruleText);

    final b = brain;
    if (b != null && prompts != null && validator != null) {
      unawaited(_raceBrainCue(event, picked, cueCountAtSubmit));
    }
  }

  Future<void> _raceBrainCue(
      ShotEvent event, MetricDeviation picked, int cueCountAtSubmit) async {
    try {
      if (!await brain!.isAvailable()) return;
      final trend = _scoreTrend();
      final prompt = prompts!.shotCue(
        personalityName: bank.personality.name,
        personalityStyle: bank.personality.style,
        skillTier: _tier,
        handedness: config.leftHanded ? 'left' : 'right',
        sessionType: config.type,
        stroke: event.stroke.id,
        score: event.score.score.round(),
        deviations: event.score.deviations.take(3).toList(),
        recurrence: processor.recurrenceCounts(),
        shotNumber: _shots.length,
        trend: trend,
        recentCues: List.of(_recentCueTexts),
      );
      final reply = await brain!.generate(prompt,
          maxTokens: 60, deadline: brainDeadline);
      final verdict = validator!.validate(
        reply,
        deviatedMetricIds: {for (final d in event.score.deviations) d.id},
        recentCues: _recentCueTexts,
      );
      if (!verdict.accepted) return;
      // Replace only while the rule cue is still queued; once spoken, a
      // second cue for the same shot would double-talk.
      if (_spokenCueCount > cueCountAtSubmit) return;
      coach.submit(reply.trim(), CoachUtteranceKind.cue, metricId: picked.id);
      _rememberCue(reply.trim());
    } on TimeoutException {
      // Rule cue already queued — deadline elapsed, nothing to do.
    } catch (_) {
      // Brain errors never disturb the session.
    }
  }

  void _rememberCue(String text) {
    _recentCueTexts.add(text);
    if (_recentCueTexts.length > 3) _recentCueTexts.removeAt(0);
  }

  double _scoreTrend() {
    if (_recentScores.length < 4) return 0;
    final half = _recentScores.length ~/ 2;
    final early = _recentScores.take(half);
    final late_ = _recentScores.skip(half);
    return late_.reduce((a, b) => a + b) / late_.length -
        early.reduce((a, b) => a + b) / early.length;
  }

  /// Ends the session: flush, summarize, persist. Returns the stored id.
  Future<SessionResult> end() async {
    _setPhase(SessionPhase.ending);
    coach.submit(
        bank.pick('system:session_end', _rng), CoachUtteranceKind.system);
    await poseSource.stop();

    final startedAt = _startedAt ?? _clock();
    final durationS = _clock().difference(startedAt).inSeconds;
    final summary = generateSessionSummary(
      shots: _shots,
      type: config.type,
      durationS: durationS,
      catalog: catalog,
    );

    var headline = '';
    var encouragement = '';
    final b = brain;
    if (b != null && prompts != null && _shots.isNotEmpty) {
      (headline, encouragement) = await _brainSummary(summary, durationS);
    }

    final sessionId = await repository.insertSession(
      startedAt: startedAt,
      durationS: durationS,
      type: config.type,
      coachId: config.coachId,
      skillTier: _tier,
      overallScore: summary.overallScore,
      summaryGood: jsonEncode(summary.strengths),
      summaryImprove: jsonEncode([
        for (final i in summary.improvements)
          {'title': i.title, 'detail': i.detail, 'deviationId': i.deviationId},
      ]),
      drills: jsonEncode(summary.drillIds),
      headline: headline,
      encouragement: encouragement,
      shots: [
        for (final s in _shots)
          (
            stroke: s.stroke.id,
            score: s.score.score,
            phaseScores: jsonEncode(s.score.phaseScores),
            topDeviationId: s.score.deviations.isEmpty
                ? null
                : s.score.deviations.first.id,
            tOffsetMs: s.tOffsetMs,
          ),
      ],
    );
    _setPhase(SessionPhase.summary);
    return SessionResult(sessionId: sessionId, summary: summary);
  }

  Future<(String, String)> _brainSummary(
      SessionSummaryData summary, int durationS) async {
    try {
      if (!await brain!.isAvailable()) return ('', '');
      final strokeAverages = <String, List<double>>{};
      for (final s in _shots) {
        strokeAverages.putIfAbsent(s.stroke.id, () => []).add(s.score.score);
      }
      final prompt = prompts!.sessionSummary(
        personalityName: bank.personality.name,
        personalityStyle: bank.personality.style,
        sessionType: config.type,
        durationMin: (durationS / 60).round(),
        shotsTotal: _shots.length,
        score: summary.overallScore.round(),
        scoreDelta: 0,
        strokeAverages: strokeAverages.map((k, v) =>
            MapEntry(k, v.reduce((a, b) => a + b) / v.length)),
        strengths: summary.strengths,
        recurringDeviations: [
          for (final i in summary.improvements)
            (
              id: i.deviationId,
              occurrences: int.tryParse(
                      RegExp(r'\d+').firstMatch(i.detail)?.group(0) ?? '') ??
                  0,
              phase: '',
            ),
        ],
        trendDescription: summary.scoreTrendDescription,
      );
      final reply = await brain!.generate(prompt,
          maxTokens: 700, deadline: const Duration(seconds: 20));
      final json = jsonDecode(
          reply.substring(reply.indexOf('{'), reply.lastIndexOf('}') + 1));
      if (json is! Map<String, dynamic>) return ('', '');
      return (
        (json['headline'] as String?) ?? '',
        (json['encouragement'] as String?) ?? '',
      );
    } catch (_) {
      return ('', ''); // Rule-based summary stands on its own.
    }
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await processor.dispose();
    await _phase.close();
    await _stats.close();
  }
}
