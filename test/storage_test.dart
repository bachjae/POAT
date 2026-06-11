import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rallycoach/core/storage/database.dart';
import 'package:rallycoach/core/storage/session_repository.dart';

// Thursday 2024-05-16; Monday of that week is 2024-05-13.
final base = DateTime(2024, 5, 16, 10);
final monday = DateTime(2024, 5, 13);

SessionShot shot(String stroke, double score, {int tOffsetMs = 0}) => (
      stroke: stroke,
      score: score,
      phaseScores: '{}',
      topDeviationId: null,
      tOffsetMs: tOffsetMs,
    );

void main() {
  late AppDatabase db;
  late SessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SessionRepository(db);
  });

  tearDown(() => db.close());

  Future<int> addSession({
    required DateTime at,
    String type = 'forehand',
    List<SessionShot> shots = const [],
    double overall = 50,
  }) =>
      repo.insertSession(
        startedAt: at,
        durationS: 600,
        type: type,
        coachId: 'sloane',
        skillTier: 'intermediate',
        overallScore: overall,
        summaryGood: '[]',
        summaryImprove: '[]',
        drills: '[]',
        shots: shots,
      );

  test('insertSession persists session fields, defaults and shots', () async {
    final id = await addSession(
      at: base,
      shots: [shot('forehand', 60), shot('forehand', 70, tOffsetMs: 5000)],
    );

    final session = await repo.lastSession();
    expect(session, isNotNull);
    expect(session!.id, id);
    expect(session.shotsTotal, 2);
    expect(session.chatHistory, '[]');
    expect(session.headline, '');
    expect(session.encouragement, '');

    final shots = await repo.shotsForSession(id);
    expect(shots, hasLength(2));
    expect(shots.first.score, 60);
    expect(shots.last.tOffsetMs, 5000);
    expect(shots.first.topDeviationId, isNull);
  });

  test('watchRecentSessions emits newest first and honors limit', () async {
    await addSession(at: base, type: 'forehand');
    await addSession(at: base.add(const Duration(hours: 2)), type: 'serve');
    await addSession(
        at: base.subtract(const Duration(hours: 2)), type: 'backhand');

    final recent = await repo.watchRecentSessions(limit: 10).first;
    expect([for (final s in recent) s.type], ['serve', 'forehand', 'backhand']);

    final limited = await repo.watchRecentSessions(limit: 2).first;
    expect(limited, hasLength(2));
    expect(limited.first.type, 'serve');
  });

  test('lastSessionOfType returns newest of that type only', () async {
    await addSession(at: base, type: 'forehand', overall: 40);
    await addSession(
        at: base.add(const Duration(hours: 1)), type: 'forehand', overall: 55);
    await addSession(at: base.add(const Duration(hours: 2)), type: 'serve');

    final fh = await repo.lastSessionOfType('forehand');
    expect(fh!.overallScore, 55);
    expect(await repo.lastSessionOfType('volley'), isNull);
  });

  test('weeklyAverages reports current week per stroke', () async {
    await addSession(
      at: base,
      shots: [shot('forehand', 60), shot('forehand', 70), shot('backhand', 80)],
    );

    final averages = await repo.weeklyAverages(base);
    expect(averages, {'forehand': 65.0, 'backhand': 80.0});

    // A different week sees nothing.
    final nextWeek = await repo.weeklyAverages(base.add(const Duration(days: 7)));
    expect(nextWeek, isEmpty);
  });

  test('trendFor upserts via weighted mean across same-week inserts',
      () async {
    await addSession(at: base, shots: [shot('forehand', 60), shot('forehand', 70)]);
    // Two days later, same calendar week.
    await addSession(
        at: base.add(const Duration(days: 2)), shots: [shot('forehand', 80)]);

    final trend = await repo.trendFor('forehand');
    expect(trend, hasLength(1));
    expect(trend.single.weekStart, monday);
    // (65 * 2 + 80) / 3
    expect(trend.single.avgScore, closeTo(70.0, 1e-9));

    // A later week appends a second row, ordered by week.
    await addSession(
        at: base.add(const Duration(days: 7)), shots: [shot('forehand', 90)]);
    final trend2 = await repo.trendFor('forehand');
    expect(trend2, hasLength(2));
    expect(trend2.first.weekStart, monday);
    expect(trend2.last.weekStart, monday.add(const Duration(days: 7)));
    expect(trend2.last.avgScore, 90.0);
  });

  test('streakDays counts consecutive days ending today', () async {
    await addSession(at: base);
    await addSession(at: base.subtract(const Duration(days: 1)));
    await addSession(at: base.subtract(const Duration(days: 2)));
    expect(await repo.streakDays(base), 3);
  });

  test('streakDays breaks on a gap', () async {
    await addSession(at: base);
    await addSession(at: base.subtract(const Duration(days: 2)));
    expect(await repo.streakDays(base), 1);
  });

  test('streakDays counts from yesterday when today has no session',
      () async {
    await addSession(at: base.subtract(const Duration(days: 1)));
    await addSession(at: base.subtract(const Duration(days: 2)));
    expect(await repo.streakDays(base), 2);
  });

  test('streakDays is zero with no recent sessions', () async {
    expect(await repo.streakDays(base), 0);
    await addSession(at: base.subtract(const Duration(days: 3)));
    expect(await repo.streakDays(base), 0);
  });

  test('saveChatHistory replaces the stored transcript', () async {
    final id = await addSession(at: base);
    const json = '[{"role":"user","text":"why was my forehand late?"}]';
    await repo.saveChatHistory(id, json);
    final session = await repo.lastSession();
    expect(session!.chatHistory, json);
  });

  test('settings helpers get, set and overwrite', () async {
    expect(await repo.getSetting('coach_id'), isNull);
    await repo.setSetting('coach_id', 'sloane');
    expect(await repo.getSetting('coach_id'), 'sloane');
    await repo.setSetting('coach_id', 'viktor');
    expect(await repo.getSetting('coach_id'), 'viktor');
  });

  test('deleteAllData wipes every table', () async {
    final id = await addSession(at: base, shots: [shot('forehand', 60)]);
    await repo.setSetting('coach_id', 'sloane');

    await repo.deleteAllData();

    expect(await repo.lastSession(), isNull);
    expect(await repo.shotsForSession(id), isEmpty);
    expect(await repo.trendFor('forehand'), isEmpty);
    expect(await repo.getSetting('coach_id'), isNull);
    expect(await repo.streakDays(base), 0);
  });
}
