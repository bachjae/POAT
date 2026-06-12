/// Local persistence for RallyCoach (SPEC §11).
///
/// Drift schema for sessions, per-shot stats, the materialized weekly
/// stroke-trend table, and a key/value settings store. By design there are
/// no video or image columns anywhere — nothing visual is ever persisted.
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// One completed coaching session. JSON-typed columns hold pre-serialized
/// strings; (de)serialization is the caller's responsibility.
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get durationS => integer()();

  /// Stroke id ('forehand', …) or 'full' for a full-game session.
  TextColumn get type => text()();
  TextColumn get coachId => text()();
  TextColumn get skillTier => text()();
  RealColumn get overallScore => real()();
  IntColumn get shotsTotal => integer()();

  /// JSON array of strings.
  TextColumn get summaryGood => text()();

  /// JSON array of {title, detail, deviationId}.
  TextColumn get summaryImprove => text()();

  /// JSON array of drill ids.
  TextColumn get drills => text()();

  /// JSON array of {role, text}.
  TextColumn get chatHistory => text().withDefault(const Constant('[]'))();
  TextColumn get headline => text().withDefault(const Constant(''))();
  TextColumn get encouragement => text().withDefault(const Constant(''))();

  /// JSON array of {tOffsetMs, shotIndex} bookmarks from the live screen.
  TextColumn get highlights => text().withDefault(const Constant('[]'))();

  /// JSON array of stroke ids for multi-stroke sequences, e.g.
  /// ['forehand','backhand']. Empty array means single-stroke session.
  TextColumn get strokeSequence =>
      text().withDefault(const Constant('[]'))();
}

/// One scored shot within a session.
class ShotStats extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  TextColumn get stroke => text()();
  RealColumn get score => real()();

  /// JSON map of phase id → score.
  TextColumn get phaseScores => text()();
  TextColumn get topDeviationId => text().nullable()();

  /// Milliseconds from session start to this shot's contact.
  IntColumn get tOffsetMs => integer()();
}

/// Per-stroke weekly averages, materialized at insert time so the progress
/// charts never scan the shot table.
class StrokeTrends extends Table {
  TextColumn get stroke => text()();

  /// Monday 00:00 (local) of the week this row aggregates.
  DateTimeColumn get weekStart => dateTime()();
  RealColumn get avgScore => real()();
  IntColumn get shotCount => integer()();

  @override
  Set<Column<Object>> get primaryKey => {stroke, weekStart};
}

/// A coaching goal the player wants to improve in upcoming sessions.
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get metricId => text()();
  TextColumn get stroke => text()();
  RealColumn get targetRate => real()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get active =>
      boolean().withDefault(const Constant(true))();
}

/// Simple key/value store for app settings.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [Sessions, ShotStats, StrokeTrends, Settings, Goals])
class AppDatabase extends _$AppDatabase {
  /// Tests pass `NativeDatabase.memory()`; production uses [AppDatabase.open].
  AppDatabase(super.executor);

  /// Opens the on-device database file via drift_flutter's lazy connection.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'rallycoach'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(sessions, sessions.highlights);
      }
      if (from < 3) {
        await m.createTable(goals);
        await m.addColumn(sessions, sessions.strokeSequence);
      }
    },
  );
}
