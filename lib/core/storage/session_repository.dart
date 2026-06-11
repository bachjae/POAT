/// Repository over [AppDatabase] (SPEC §11).
///
/// All multi-row writes run in a transaction; the weekly trend table is
/// upserted on every session insert so reads stay O(weeks), not O(shots).
library;

import 'package:drift/drift.dart';

import 'database.dart';

/// Per-shot data accepted by [SessionRepository.insertSession].
/// `phaseScores` is a pre-serialized JSON map of phase id → score.
typedef SessionShot = ({
  String stroke,
  double score,
  String phaseScores,
  String? topDeviationId,
  int tOffsetMs,
});

class SessionRepository {
  SessionRepository(this.db);

  final AppDatabase db;

  /// Inserts a session plus its shot rows and upserts the weekly trend rows.
  /// `shotsTotal` is derived from [shots]. Returns the new session id.
  Future<int> insertSession({
    required DateTime startedAt,
    required int durationS,
    required String type,
    required String coachId,
    required String skillTier,
    required double overallScore,
    required String summaryGood,
    required String summaryImprove,
    required String drills,
    required List<SessionShot> shots,
    String chatHistory = '[]',
    String headline = '',
    String encouragement = '',
  }) {
    return db.transaction(() async {
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              startedAt: startedAt,
              durationS: durationS,
              type: type,
              coachId: coachId,
              skillTier: skillTier,
              overallScore: overallScore,
              shotsTotal: shots.length,
              summaryGood: summaryGood,
              summaryImprove: summaryImprove,
              drills: drills,
              chatHistory: Value(chatHistory),
              headline: Value(headline),
              encouragement: Value(encouragement),
            ),
          );

      for (final shot in shots) {
        await db.into(db.shotStats).insert(
              ShotStatsCompanion.insert(
                sessionId: sessionId,
                stroke: shot.stroke,
                score: shot.score,
                phaseScores: shot.phaseScores,
                topDeviationId: Value(shot.topDeviationId),
                tOffsetMs: shot.tOffsetMs,
              ),
            );
      }

      final week = weekStartOf(startedAt);
      final byStroke = <String, List<double>>{};
      for (final shot in shots) {
        byStroke.putIfAbsent(shot.stroke, () => []).add(shot.score);
      }
      for (final entry in byStroke.entries) {
        final existing = await (db.select(db.strokeTrends)
              ..where((t) =>
                  t.stroke.equals(entry.key) & t.weekStart.equals(week)))
            .getSingleOrNull();
        final oldCount = existing?.shotCount ?? 0;
        final oldAvg = existing?.avgScore ?? 0;
        final newCount = oldCount + entry.value.length;
        final newSum =
            oldAvg * oldCount + entry.value.fold(0.0, (a, b) => a + b);
        await db.into(db.strokeTrends).insert(
              StrokeTrendsCompanion.insert(
                stroke: entry.key,
                weekStart: week,
                avgScore: newSum / newCount,
                shotCount: newCount,
              ),
              mode: InsertMode.insertOrReplace,
            );
      }

      return sessionId;
    });
  }

  /// Monday 00:00 (local) of the week containing [t].
  static DateTime weekStartOf(DateTime t) =>
      DateTime(t.year, t.month, t.day - (t.weekday - DateTime.monday));

  Stream<List<Session>> watchRecentSessions({int limit = 20}) =>
      (db.select(db.sessions)
            ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
            ..limit(limit))
          .watch();

  Future<Session?> lastSession() => (db.select(db.sessions)
        ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
        ..limit(1))
      .getSingleOrNull();

  Future<Session?> lastSessionOfType(String type) => (db.select(db.sessions)
        ..where((s) => s.type.equals(type))
        ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
        ..limit(1))
      .getSingleOrNull();

  Future<List<ShotStat>> shotsForSession(int id) => (db.select(db.shotStats)
        ..where((s) => s.sessionId.equals(id))
        ..orderBy([(s) => OrderingTerm.asc(s.tOffsetMs)]))
      .get();

  /// Stroke id → average score for the week containing [now].
  Future<Map<String, double>> weeklyAverages(DateTime now) async {
    final rows = await (db.select(db.strokeTrends)
          ..where((t) => t.weekStart.equals(weekStartOf(now))))
        .get();
    return {for (final r in rows) r.stroke: r.avgScore};
  }

  Future<List<({DateTime weekStart, double avgScore})>> trendFor(
      String stroke) async {
    final rows = await (db.select(db.strokeTrends)
          ..where((t) => t.stroke.equals(stroke))
          ..orderBy([(t) => OrderingTerm.asc(t.weekStart)]))
        .get();
    return [
      for (final r in rows) (weekStart: r.weekStart, avgScore: r.avgScore),
    ];
  }

  /// Consecutive calendar days with at least one session, ending today —
  /// or ending yesterday if there is no session yet today.
  Future<int> streakDays(DateTime now) async {
    final rows = await db.select(db.sessions).get();
    final days = <DateTime>{
      for (final r in rows)
        DateTime(r.startedAt.year, r.startedAt.month, r.startedAt.day),
    };
    var cursor = DateTime(now.year, now.month, now.day);
    if (!days.contains(cursor)) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  Future<void> saveChatHistory(int sessionId, String json) async {
    await (db.update(db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(SessionsCompanion(chatHistory: Value(json)));
  }

  Future<String?> getSetting(String key) async {
    final row = await (db.select(db.settings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) =>
      db.into(db.settings).insertOnConflictUpdate(
            SettingsCompanion.insert(key: key, value: value),
          );

  /// Wipes every table. Irreversible; gated behind a confirm dialog in UI.
  Future<void> deleteAllData() => db.transaction(() async {
        await db.delete(db.shotStats).go();
        await db.delete(db.sessions).go();
        await db.delete(db.strokeTrends).go();
        await db.delete(db.settings).go();
      });
}
