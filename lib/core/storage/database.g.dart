// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSMeta = const VerificationMeta(
    'durationS',
  );
  @override
  late final GeneratedColumn<int> durationS = GeneratedColumn<int>(
    'duration_s',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coachIdMeta = const VerificationMeta(
    'coachId',
  );
  @override
  late final GeneratedColumn<String> coachId = GeneratedColumn<String>(
    'coach_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skillTierMeta = const VerificationMeta(
    'skillTier',
  );
  @override
  late final GeneratedColumn<String> skillTier = GeneratedColumn<String>(
    'skill_tier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _overallScoreMeta = const VerificationMeta(
    'overallScore',
  );
  @override
  late final GeneratedColumn<double> overallScore = GeneratedColumn<double>(
    'overall_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shotsTotalMeta = const VerificationMeta(
    'shotsTotal',
  );
  @override
  late final GeneratedColumn<int> shotsTotal = GeneratedColumn<int>(
    'shots_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryGoodMeta = const VerificationMeta(
    'summaryGood',
  );
  @override
  late final GeneratedColumn<String> summaryGood = GeneratedColumn<String>(
    'summary_good',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryImproveMeta = const VerificationMeta(
    'summaryImprove',
  );
  @override
  late final GeneratedColumn<String> summaryImprove = GeneratedColumn<String>(
    'summary_improve',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _drillsMeta = const VerificationMeta('drills');
  @override
  late final GeneratedColumn<String> drills = GeneratedColumn<String>(
    'drills',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chatHistoryMeta = const VerificationMeta(
    'chatHistory',
  );
  @override
  late final GeneratedColumn<String> chatHistory = GeneratedColumn<String>(
    'chat_history',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _headlineMeta = const VerificationMeta(
    'headline',
  );
  @override
  late final GeneratedColumn<String> headline = GeneratedColumn<String>(
    'headline',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _encouragementMeta = const VerificationMeta(
    'encouragement',
  );
  @override
  late final GeneratedColumn<String> encouragement = GeneratedColumn<String>(
    'encouragement',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    durationS,
    type,
    coachId,
    skillTier,
    overallScore,
    shotsTotal,
    summaryGood,
    summaryImprove,
    drills,
    chatHistory,
    headline,
    encouragement,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('duration_s')) {
      context.handle(
        _durationSMeta,
        durationS.isAcceptableOrUnknown(data['duration_s']!, _durationSMeta),
      );
    } else if (isInserting) {
      context.missing(_durationSMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('coach_id')) {
      context.handle(
        _coachIdMeta,
        coachId.isAcceptableOrUnknown(data['coach_id']!, _coachIdMeta),
      );
    } else if (isInserting) {
      context.missing(_coachIdMeta);
    }
    if (data.containsKey('skill_tier')) {
      context.handle(
        _skillTierMeta,
        skillTier.isAcceptableOrUnknown(data['skill_tier']!, _skillTierMeta),
      );
    } else if (isInserting) {
      context.missing(_skillTierMeta);
    }
    if (data.containsKey('overall_score')) {
      context.handle(
        _overallScoreMeta,
        overallScore.isAcceptableOrUnknown(
          data['overall_score']!,
          _overallScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_overallScoreMeta);
    }
    if (data.containsKey('shots_total')) {
      context.handle(
        _shotsTotalMeta,
        shotsTotal.isAcceptableOrUnknown(data['shots_total']!, _shotsTotalMeta),
      );
    } else if (isInserting) {
      context.missing(_shotsTotalMeta);
    }
    if (data.containsKey('summary_good')) {
      context.handle(
        _summaryGoodMeta,
        summaryGood.isAcceptableOrUnknown(
          data['summary_good']!,
          _summaryGoodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryGoodMeta);
    }
    if (data.containsKey('summary_improve')) {
      context.handle(
        _summaryImproveMeta,
        summaryImprove.isAcceptableOrUnknown(
          data['summary_improve']!,
          _summaryImproveMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryImproveMeta);
    }
    if (data.containsKey('drills')) {
      context.handle(
        _drillsMeta,
        drills.isAcceptableOrUnknown(data['drills']!, _drillsMeta),
      );
    } else if (isInserting) {
      context.missing(_drillsMeta);
    }
    if (data.containsKey('chat_history')) {
      context.handle(
        _chatHistoryMeta,
        chatHistory.isAcceptableOrUnknown(
          data['chat_history']!,
          _chatHistoryMeta,
        ),
      );
    }
    if (data.containsKey('headline')) {
      context.handle(
        _headlineMeta,
        headline.isAcceptableOrUnknown(data['headline']!, _headlineMeta),
      );
    }
    if (data.containsKey('encouragement')) {
      context.handle(
        _encouragementMeta,
        encouragement.isAcceptableOrUnknown(
          data['encouragement']!,
          _encouragementMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      durationS: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_s'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      coachId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}coach_id'],
      )!,
      skillTier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skill_tier'],
      )!,
      overallScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}overall_score'],
      )!,
      shotsTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shots_total'],
      )!,
      summaryGood: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_good'],
      )!,
      summaryImprove: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_improve'],
      )!,
      drills: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}drills'],
      )!,
      chatHistory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chat_history'],
      )!,
      headline: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headline'],
      )!,
      encouragement: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encouragement'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final int id;
  final DateTime startedAt;
  final int durationS;

  /// Stroke id ('forehand', …) or 'full' for a full-game session.
  final String type;
  final String coachId;
  final String skillTier;
  final double overallScore;
  final int shotsTotal;

  /// JSON array of strings.
  final String summaryGood;

  /// JSON array of {title, detail, deviationId}.
  final String summaryImprove;

  /// JSON array of drill ids.
  final String drills;

  /// JSON array of {role, text}.
  final String chatHistory;
  final String headline;
  final String encouragement;
  const Session({
    required this.id,
    required this.startedAt,
    required this.durationS,
    required this.type,
    required this.coachId,
    required this.skillTier,
    required this.overallScore,
    required this.shotsTotal,
    required this.summaryGood,
    required this.summaryImprove,
    required this.drills,
    required this.chatHistory,
    required this.headline,
    required this.encouragement,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['duration_s'] = Variable<int>(durationS);
    map['type'] = Variable<String>(type);
    map['coach_id'] = Variable<String>(coachId);
    map['skill_tier'] = Variable<String>(skillTier);
    map['overall_score'] = Variable<double>(overallScore);
    map['shots_total'] = Variable<int>(shotsTotal);
    map['summary_good'] = Variable<String>(summaryGood);
    map['summary_improve'] = Variable<String>(summaryImprove);
    map['drills'] = Variable<String>(drills);
    map['chat_history'] = Variable<String>(chatHistory);
    map['headline'] = Variable<String>(headline);
    map['encouragement'] = Variable<String>(encouragement);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      durationS: Value(durationS),
      type: Value(type),
      coachId: Value(coachId),
      skillTier: Value(skillTier),
      overallScore: Value(overallScore),
      shotsTotal: Value(shotsTotal),
      summaryGood: Value(summaryGood),
      summaryImprove: Value(summaryImprove),
      drills: Value(drills),
      chatHistory: Value(chatHistory),
      headline: Value(headline),
      encouragement: Value(encouragement),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<int>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      durationS: serializer.fromJson<int>(json['durationS']),
      type: serializer.fromJson<String>(json['type']),
      coachId: serializer.fromJson<String>(json['coachId']),
      skillTier: serializer.fromJson<String>(json['skillTier']),
      overallScore: serializer.fromJson<double>(json['overallScore']),
      shotsTotal: serializer.fromJson<int>(json['shotsTotal']),
      summaryGood: serializer.fromJson<String>(json['summaryGood']),
      summaryImprove: serializer.fromJson<String>(json['summaryImprove']),
      drills: serializer.fromJson<String>(json['drills']),
      chatHistory: serializer.fromJson<String>(json['chatHistory']),
      headline: serializer.fromJson<String>(json['headline']),
      encouragement: serializer.fromJson<String>(json['encouragement']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'durationS': serializer.toJson<int>(durationS),
      'type': serializer.toJson<String>(type),
      'coachId': serializer.toJson<String>(coachId),
      'skillTier': serializer.toJson<String>(skillTier),
      'overallScore': serializer.toJson<double>(overallScore),
      'shotsTotal': serializer.toJson<int>(shotsTotal),
      'summaryGood': serializer.toJson<String>(summaryGood),
      'summaryImprove': serializer.toJson<String>(summaryImprove),
      'drills': serializer.toJson<String>(drills),
      'chatHistory': serializer.toJson<String>(chatHistory),
      'headline': serializer.toJson<String>(headline),
      'encouragement': serializer.toJson<String>(encouragement),
    };
  }

  Session copyWith({
    int? id,
    DateTime? startedAt,
    int? durationS,
    String? type,
    String? coachId,
    String? skillTier,
    double? overallScore,
    int? shotsTotal,
    String? summaryGood,
    String? summaryImprove,
    String? drills,
    String? chatHistory,
    String? headline,
    String? encouragement,
  }) => Session(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    durationS: durationS ?? this.durationS,
    type: type ?? this.type,
    coachId: coachId ?? this.coachId,
    skillTier: skillTier ?? this.skillTier,
    overallScore: overallScore ?? this.overallScore,
    shotsTotal: shotsTotal ?? this.shotsTotal,
    summaryGood: summaryGood ?? this.summaryGood,
    summaryImprove: summaryImprove ?? this.summaryImprove,
    drills: drills ?? this.drills,
    chatHistory: chatHistory ?? this.chatHistory,
    headline: headline ?? this.headline,
    encouragement: encouragement ?? this.encouragement,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      durationS: data.durationS.present ? data.durationS.value : this.durationS,
      type: data.type.present ? data.type.value : this.type,
      coachId: data.coachId.present ? data.coachId.value : this.coachId,
      skillTier: data.skillTier.present ? data.skillTier.value : this.skillTier,
      overallScore: data.overallScore.present
          ? data.overallScore.value
          : this.overallScore,
      shotsTotal: data.shotsTotal.present
          ? data.shotsTotal.value
          : this.shotsTotal,
      summaryGood: data.summaryGood.present
          ? data.summaryGood.value
          : this.summaryGood,
      summaryImprove: data.summaryImprove.present
          ? data.summaryImprove.value
          : this.summaryImprove,
      drills: data.drills.present ? data.drills.value : this.drills,
      chatHistory: data.chatHistory.present
          ? data.chatHistory.value
          : this.chatHistory,
      headline: data.headline.present ? data.headline.value : this.headline,
      encouragement: data.encouragement.present
          ? data.encouragement.value
          : this.encouragement,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationS: $durationS, ')
          ..write('type: $type, ')
          ..write('coachId: $coachId, ')
          ..write('skillTier: $skillTier, ')
          ..write('overallScore: $overallScore, ')
          ..write('shotsTotal: $shotsTotal, ')
          ..write('summaryGood: $summaryGood, ')
          ..write('summaryImprove: $summaryImprove, ')
          ..write('drills: $drills, ')
          ..write('chatHistory: $chatHistory, ')
          ..write('headline: $headline, ')
          ..write('encouragement: $encouragement')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    durationS,
    type,
    coachId,
    skillTier,
    overallScore,
    shotsTotal,
    summaryGood,
    summaryImprove,
    drills,
    chatHistory,
    headline,
    encouragement,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.durationS == this.durationS &&
          other.type == this.type &&
          other.coachId == this.coachId &&
          other.skillTier == this.skillTier &&
          other.overallScore == this.overallScore &&
          other.shotsTotal == this.shotsTotal &&
          other.summaryGood == this.summaryGood &&
          other.summaryImprove == this.summaryImprove &&
          other.drills == this.drills &&
          other.chatHistory == this.chatHistory &&
          other.headline == this.headline &&
          other.encouragement == this.encouragement);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<int> id;
  final Value<DateTime> startedAt;
  final Value<int> durationS;
  final Value<String> type;
  final Value<String> coachId;
  final Value<String> skillTier;
  final Value<double> overallScore;
  final Value<int> shotsTotal;
  final Value<String> summaryGood;
  final Value<String> summaryImprove;
  final Value<String> drills;
  final Value<String> chatHistory;
  final Value<String> headline;
  final Value<String> encouragement;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.durationS = const Value.absent(),
    this.type = const Value.absent(),
    this.coachId = const Value.absent(),
    this.skillTier = const Value.absent(),
    this.overallScore = const Value.absent(),
    this.shotsTotal = const Value.absent(),
    this.summaryGood = const Value.absent(),
    this.summaryImprove = const Value.absent(),
    this.drills = const Value.absent(),
    this.chatHistory = const Value.absent(),
    this.headline = const Value.absent(),
    this.encouragement = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startedAt,
    required int durationS,
    required String type,
    required String coachId,
    required String skillTier,
    required double overallScore,
    required int shotsTotal,
    required String summaryGood,
    required String summaryImprove,
    required String drills,
    this.chatHistory = const Value.absent(),
    this.headline = const Value.absent(),
    this.encouragement = const Value.absent(),
  }) : startedAt = Value(startedAt),
       durationS = Value(durationS),
       type = Value(type),
       coachId = Value(coachId),
       skillTier = Value(skillTier),
       overallScore = Value(overallScore),
       shotsTotal = Value(shotsTotal),
       summaryGood = Value(summaryGood),
       summaryImprove = Value(summaryImprove),
       drills = Value(drills);
  static Insertable<Session> custom({
    Expression<int>? id,
    Expression<DateTime>? startedAt,
    Expression<int>? durationS,
    Expression<String>? type,
    Expression<String>? coachId,
    Expression<String>? skillTier,
    Expression<double>? overallScore,
    Expression<int>? shotsTotal,
    Expression<String>? summaryGood,
    Expression<String>? summaryImprove,
    Expression<String>? drills,
    Expression<String>? chatHistory,
    Expression<String>? headline,
    Expression<String>? encouragement,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (durationS != null) 'duration_s': durationS,
      if (type != null) 'type': type,
      if (coachId != null) 'coach_id': coachId,
      if (skillTier != null) 'skill_tier': skillTier,
      if (overallScore != null) 'overall_score': overallScore,
      if (shotsTotal != null) 'shots_total': shotsTotal,
      if (summaryGood != null) 'summary_good': summaryGood,
      if (summaryImprove != null) 'summary_improve': summaryImprove,
      if (drills != null) 'drills': drills,
      if (chatHistory != null) 'chat_history': chatHistory,
      if (headline != null) 'headline': headline,
      if (encouragement != null) 'encouragement': encouragement,
    });
  }

  SessionsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? startedAt,
    Value<int>? durationS,
    Value<String>? type,
    Value<String>? coachId,
    Value<String>? skillTier,
    Value<double>? overallScore,
    Value<int>? shotsTotal,
    Value<String>? summaryGood,
    Value<String>? summaryImprove,
    Value<String>? drills,
    Value<String>? chatHistory,
    Value<String>? headline,
    Value<String>? encouragement,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      durationS: durationS ?? this.durationS,
      type: type ?? this.type,
      coachId: coachId ?? this.coachId,
      skillTier: skillTier ?? this.skillTier,
      overallScore: overallScore ?? this.overallScore,
      shotsTotal: shotsTotal ?? this.shotsTotal,
      summaryGood: summaryGood ?? this.summaryGood,
      summaryImprove: summaryImprove ?? this.summaryImprove,
      drills: drills ?? this.drills,
      chatHistory: chatHistory ?? this.chatHistory,
      headline: headline ?? this.headline,
      encouragement: encouragement ?? this.encouragement,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (durationS.present) {
      map['duration_s'] = Variable<int>(durationS.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (coachId.present) {
      map['coach_id'] = Variable<String>(coachId.value);
    }
    if (skillTier.present) {
      map['skill_tier'] = Variable<String>(skillTier.value);
    }
    if (overallScore.present) {
      map['overall_score'] = Variable<double>(overallScore.value);
    }
    if (shotsTotal.present) {
      map['shots_total'] = Variable<int>(shotsTotal.value);
    }
    if (summaryGood.present) {
      map['summary_good'] = Variable<String>(summaryGood.value);
    }
    if (summaryImprove.present) {
      map['summary_improve'] = Variable<String>(summaryImprove.value);
    }
    if (drills.present) {
      map['drills'] = Variable<String>(drills.value);
    }
    if (chatHistory.present) {
      map['chat_history'] = Variable<String>(chatHistory.value);
    }
    if (headline.present) {
      map['headline'] = Variable<String>(headline.value);
    }
    if (encouragement.present) {
      map['encouragement'] = Variable<String>(encouragement.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationS: $durationS, ')
          ..write('type: $type, ')
          ..write('coachId: $coachId, ')
          ..write('skillTier: $skillTier, ')
          ..write('overallScore: $overallScore, ')
          ..write('shotsTotal: $shotsTotal, ')
          ..write('summaryGood: $summaryGood, ')
          ..write('summaryImprove: $summaryImprove, ')
          ..write('drills: $drills, ')
          ..write('chatHistory: $chatHistory, ')
          ..write('headline: $headline, ')
          ..write('encouragement: $encouragement')
          ..write(')'))
        .toString();
  }
}

class $ShotStatsTable extends ShotStats
    with TableInfo<$ShotStatsTable, ShotStat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShotStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _strokeMeta = const VerificationMeta('stroke');
  @override
  late final GeneratedColumn<String> stroke = GeneratedColumn<String>(
    'stroke',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phaseScoresMeta = const VerificationMeta(
    'phaseScores',
  );
  @override
  late final GeneratedColumn<String> phaseScores = GeneratedColumn<String>(
    'phase_scores',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topDeviationIdMeta = const VerificationMeta(
    'topDeviationId',
  );
  @override
  late final GeneratedColumn<String> topDeviationId = GeneratedColumn<String>(
    'top_deviation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tOffsetMsMeta = const VerificationMeta(
    'tOffsetMs',
  );
  @override
  late final GeneratedColumn<int> tOffsetMs = GeneratedColumn<int>(
    't_offset_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    stroke,
    score,
    phaseScores,
    topDeviationId,
    tOffsetMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shot_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShotStat> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('stroke')) {
      context.handle(
        _strokeMeta,
        stroke.isAcceptableOrUnknown(data['stroke']!, _strokeMeta),
      );
    } else if (isInserting) {
      context.missing(_strokeMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('phase_scores')) {
      context.handle(
        _phaseScoresMeta,
        phaseScores.isAcceptableOrUnknown(
          data['phase_scores']!,
          _phaseScoresMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_phaseScoresMeta);
    }
    if (data.containsKey('top_deviation_id')) {
      context.handle(
        _topDeviationIdMeta,
        topDeviationId.isAcceptableOrUnknown(
          data['top_deviation_id']!,
          _topDeviationIdMeta,
        ),
      );
    }
    if (data.containsKey('t_offset_ms')) {
      context.handle(
        _tOffsetMsMeta,
        tOffsetMs.isAcceptableOrUnknown(data['t_offset_ms']!, _tOffsetMsMeta),
      );
    } else if (isInserting) {
      context.missing(_tOffsetMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShotStat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShotStat(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      stroke: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stroke'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      )!,
      phaseScores: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phase_scores'],
      )!,
      topDeviationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}top_deviation_id'],
      ),
      tOffsetMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}t_offset_ms'],
      )!,
    );
  }

  @override
  $ShotStatsTable createAlias(String alias) {
    return $ShotStatsTable(attachedDatabase, alias);
  }
}

class ShotStat extends DataClass implements Insertable<ShotStat> {
  final int id;
  final int sessionId;
  final String stroke;
  final double score;

  /// JSON map of phase id → score.
  final String phaseScores;
  final String? topDeviationId;

  /// Milliseconds from session start to this shot's contact.
  final int tOffsetMs;
  const ShotStat({
    required this.id,
    required this.sessionId,
    required this.stroke,
    required this.score,
    required this.phaseScores,
    this.topDeviationId,
    required this.tOffsetMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['stroke'] = Variable<String>(stroke);
    map['score'] = Variable<double>(score);
    map['phase_scores'] = Variable<String>(phaseScores);
    if (!nullToAbsent || topDeviationId != null) {
      map['top_deviation_id'] = Variable<String>(topDeviationId);
    }
    map['t_offset_ms'] = Variable<int>(tOffsetMs);
    return map;
  }

  ShotStatsCompanion toCompanion(bool nullToAbsent) {
    return ShotStatsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      stroke: Value(stroke),
      score: Value(score),
      phaseScores: Value(phaseScores),
      topDeviationId: topDeviationId == null && nullToAbsent
          ? const Value.absent()
          : Value(topDeviationId),
      tOffsetMs: Value(tOffsetMs),
    );
  }

  factory ShotStat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShotStat(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      stroke: serializer.fromJson<String>(json['stroke']),
      score: serializer.fromJson<double>(json['score']),
      phaseScores: serializer.fromJson<String>(json['phaseScores']),
      topDeviationId: serializer.fromJson<String?>(json['topDeviationId']),
      tOffsetMs: serializer.fromJson<int>(json['tOffsetMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'stroke': serializer.toJson<String>(stroke),
      'score': serializer.toJson<double>(score),
      'phaseScores': serializer.toJson<String>(phaseScores),
      'topDeviationId': serializer.toJson<String?>(topDeviationId),
      'tOffsetMs': serializer.toJson<int>(tOffsetMs),
    };
  }

  ShotStat copyWith({
    int? id,
    int? sessionId,
    String? stroke,
    double? score,
    String? phaseScores,
    Value<String?> topDeviationId = const Value.absent(),
    int? tOffsetMs,
  }) => ShotStat(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    stroke: stroke ?? this.stroke,
    score: score ?? this.score,
    phaseScores: phaseScores ?? this.phaseScores,
    topDeviationId: topDeviationId.present
        ? topDeviationId.value
        : this.topDeviationId,
    tOffsetMs: tOffsetMs ?? this.tOffsetMs,
  );
  ShotStat copyWithCompanion(ShotStatsCompanion data) {
    return ShotStat(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      stroke: data.stroke.present ? data.stroke.value : this.stroke,
      score: data.score.present ? data.score.value : this.score,
      phaseScores: data.phaseScores.present
          ? data.phaseScores.value
          : this.phaseScores,
      topDeviationId: data.topDeviationId.present
          ? data.topDeviationId.value
          : this.topDeviationId,
      tOffsetMs: data.tOffsetMs.present ? data.tOffsetMs.value : this.tOffsetMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShotStat(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('stroke: $stroke, ')
          ..write('score: $score, ')
          ..write('phaseScores: $phaseScores, ')
          ..write('topDeviationId: $topDeviationId, ')
          ..write('tOffsetMs: $tOffsetMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    stroke,
    score,
    phaseScores,
    topDeviationId,
    tOffsetMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShotStat &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.stroke == this.stroke &&
          other.score == this.score &&
          other.phaseScores == this.phaseScores &&
          other.topDeviationId == this.topDeviationId &&
          other.tOffsetMs == this.tOffsetMs);
}

class ShotStatsCompanion extends UpdateCompanion<ShotStat> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<String> stroke;
  final Value<double> score;
  final Value<String> phaseScores;
  final Value<String?> topDeviationId;
  final Value<int> tOffsetMs;
  const ShotStatsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.stroke = const Value.absent(),
    this.score = const Value.absent(),
    this.phaseScores = const Value.absent(),
    this.topDeviationId = const Value.absent(),
    this.tOffsetMs = const Value.absent(),
  });
  ShotStatsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required String stroke,
    required double score,
    required String phaseScores,
    this.topDeviationId = const Value.absent(),
    required int tOffsetMs,
  }) : sessionId = Value(sessionId),
       stroke = Value(stroke),
       score = Value(score),
       phaseScores = Value(phaseScores),
       tOffsetMs = Value(tOffsetMs);
  static Insertable<ShotStat> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<String>? stroke,
    Expression<double>? score,
    Expression<String>? phaseScores,
    Expression<String>? topDeviationId,
    Expression<int>? tOffsetMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (stroke != null) 'stroke': stroke,
      if (score != null) 'score': score,
      if (phaseScores != null) 'phase_scores': phaseScores,
      if (topDeviationId != null) 'top_deviation_id': topDeviationId,
      if (tOffsetMs != null) 't_offset_ms': tOffsetMs,
    });
  }

  ShotStatsCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<String>? stroke,
    Value<double>? score,
    Value<String>? phaseScores,
    Value<String?>? topDeviationId,
    Value<int>? tOffsetMs,
  }) {
    return ShotStatsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      stroke: stroke ?? this.stroke,
      score: score ?? this.score,
      phaseScores: phaseScores ?? this.phaseScores,
      topDeviationId: topDeviationId ?? this.topDeviationId,
      tOffsetMs: tOffsetMs ?? this.tOffsetMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (stroke.present) {
      map['stroke'] = Variable<String>(stroke.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (phaseScores.present) {
      map['phase_scores'] = Variable<String>(phaseScores.value);
    }
    if (topDeviationId.present) {
      map['top_deviation_id'] = Variable<String>(topDeviationId.value);
    }
    if (tOffsetMs.present) {
      map['t_offset_ms'] = Variable<int>(tOffsetMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShotStatsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('stroke: $stroke, ')
          ..write('score: $score, ')
          ..write('phaseScores: $phaseScores, ')
          ..write('topDeviationId: $topDeviationId, ')
          ..write('tOffsetMs: $tOffsetMs')
          ..write(')'))
        .toString();
  }
}

class $StrokeTrendsTable extends StrokeTrends
    with TableInfo<$StrokeTrendsTable, StrokeTrend> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StrokeTrendsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _strokeMeta = const VerificationMeta('stroke');
  @override
  late final GeneratedColumn<String> stroke = GeneratedColumn<String>(
    'stroke',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekStartMeta = const VerificationMeta(
    'weekStart',
  );
  @override
  late final GeneratedColumn<DateTime> weekStart = GeneratedColumn<DateTime>(
    'week_start',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avgScoreMeta = const VerificationMeta(
    'avgScore',
  );
  @override
  late final GeneratedColumn<double> avgScore = GeneratedColumn<double>(
    'avg_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shotCountMeta = const VerificationMeta(
    'shotCount',
  );
  @override
  late final GeneratedColumn<int> shotCount = GeneratedColumn<int>(
    'shot_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    stroke,
    weekStart,
    avgScore,
    shotCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stroke_trends';
  @override
  VerificationContext validateIntegrity(
    Insertable<StrokeTrend> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('stroke')) {
      context.handle(
        _strokeMeta,
        stroke.isAcceptableOrUnknown(data['stroke']!, _strokeMeta),
      );
    } else if (isInserting) {
      context.missing(_strokeMeta);
    }
    if (data.containsKey('week_start')) {
      context.handle(
        _weekStartMeta,
        weekStart.isAcceptableOrUnknown(data['week_start']!, _weekStartMeta),
      );
    } else if (isInserting) {
      context.missing(_weekStartMeta);
    }
    if (data.containsKey('avg_score')) {
      context.handle(
        _avgScoreMeta,
        avgScore.isAcceptableOrUnknown(data['avg_score']!, _avgScoreMeta),
      );
    } else if (isInserting) {
      context.missing(_avgScoreMeta);
    }
    if (data.containsKey('shot_count')) {
      context.handle(
        _shotCountMeta,
        shotCount.isAcceptableOrUnknown(data['shot_count']!, _shotCountMeta),
      );
    } else if (isInserting) {
      context.missing(_shotCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {stroke, weekStart};
  @override
  StrokeTrend map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StrokeTrend(
      stroke: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stroke'],
      )!,
      weekStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}week_start'],
      )!,
      avgScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_score'],
      )!,
      shotCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shot_count'],
      )!,
    );
  }

  @override
  $StrokeTrendsTable createAlias(String alias) {
    return $StrokeTrendsTable(attachedDatabase, alias);
  }
}

class StrokeTrend extends DataClass implements Insertable<StrokeTrend> {
  final String stroke;

  /// Monday 00:00 (local) of the week this row aggregates.
  final DateTime weekStart;
  final double avgScore;
  final int shotCount;
  const StrokeTrend({
    required this.stroke,
    required this.weekStart,
    required this.avgScore,
    required this.shotCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['stroke'] = Variable<String>(stroke);
    map['week_start'] = Variable<DateTime>(weekStart);
    map['avg_score'] = Variable<double>(avgScore);
    map['shot_count'] = Variable<int>(shotCount);
    return map;
  }

  StrokeTrendsCompanion toCompanion(bool nullToAbsent) {
    return StrokeTrendsCompanion(
      stroke: Value(stroke),
      weekStart: Value(weekStart),
      avgScore: Value(avgScore),
      shotCount: Value(shotCount),
    );
  }

  factory StrokeTrend.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StrokeTrend(
      stroke: serializer.fromJson<String>(json['stroke']),
      weekStart: serializer.fromJson<DateTime>(json['weekStart']),
      avgScore: serializer.fromJson<double>(json['avgScore']),
      shotCount: serializer.fromJson<int>(json['shotCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'stroke': serializer.toJson<String>(stroke),
      'weekStart': serializer.toJson<DateTime>(weekStart),
      'avgScore': serializer.toJson<double>(avgScore),
      'shotCount': serializer.toJson<int>(shotCount),
    };
  }

  StrokeTrend copyWith({
    String? stroke,
    DateTime? weekStart,
    double? avgScore,
    int? shotCount,
  }) => StrokeTrend(
    stroke: stroke ?? this.stroke,
    weekStart: weekStart ?? this.weekStart,
    avgScore: avgScore ?? this.avgScore,
    shotCount: shotCount ?? this.shotCount,
  );
  StrokeTrend copyWithCompanion(StrokeTrendsCompanion data) {
    return StrokeTrend(
      stroke: data.stroke.present ? data.stroke.value : this.stroke,
      weekStart: data.weekStart.present ? data.weekStart.value : this.weekStart,
      avgScore: data.avgScore.present ? data.avgScore.value : this.avgScore,
      shotCount: data.shotCount.present ? data.shotCount.value : this.shotCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StrokeTrend(')
          ..write('stroke: $stroke, ')
          ..write('weekStart: $weekStart, ')
          ..write('avgScore: $avgScore, ')
          ..write('shotCount: $shotCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(stroke, weekStart, avgScore, shotCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StrokeTrend &&
          other.stroke == this.stroke &&
          other.weekStart == this.weekStart &&
          other.avgScore == this.avgScore &&
          other.shotCount == this.shotCount);
}

class StrokeTrendsCompanion extends UpdateCompanion<StrokeTrend> {
  final Value<String> stroke;
  final Value<DateTime> weekStart;
  final Value<double> avgScore;
  final Value<int> shotCount;
  final Value<int> rowid;
  const StrokeTrendsCompanion({
    this.stroke = const Value.absent(),
    this.weekStart = const Value.absent(),
    this.avgScore = const Value.absent(),
    this.shotCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StrokeTrendsCompanion.insert({
    required String stroke,
    required DateTime weekStart,
    required double avgScore,
    required int shotCount,
    this.rowid = const Value.absent(),
  }) : stroke = Value(stroke),
       weekStart = Value(weekStart),
       avgScore = Value(avgScore),
       shotCount = Value(shotCount);
  static Insertable<StrokeTrend> custom({
    Expression<String>? stroke,
    Expression<DateTime>? weekStart,
    Expression<double>? avgScore,
    Expression<int>? shotCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (stroke != null) 'stroke': stroke,
      if (weekStart != null) 'week_start': weekStart,
      if (avgScore != null) 'avg_score': avgScore,
      if (shotCount != null) 'shot_count': shotCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StrokeTrendsCompanion copyWith({
    Value<String>? stroke,
    Value<DateTime>? weekStart,
    Value<double>? avgScore,
    Value<int>? shotCount,
    Value<int>? rowid,
  }) {
    return StrokeTrendsCompanion(
      stroke: stroke ?? this.stroke,
      weekStart: weekStart ?? this.weekStart,
      avgScore: avgScore ?? this.avgScore,
      shotCount: shotCount ?? this.shotCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (stroke.present) {
      map['stroke'] = Variable<String>(stroke.value);
    }
    if (weekStart.present) {
      map['week_start'] = Variable<DateTime>(weekStart.value);
    }
    if (avgScore.present) {
      map['avg_score'] = Variable<double>(avgScore.value);
    }
    if (shotCount.present) {
      map['shot_count'] = Variable<int>(shotCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StrokeTrendsCompanion(')
          ..write('stroke: $stroke, ')
          ..write('weekStart: $weekStart, ')
          ..write('avgScore: $avgScore, ')
          ..write('shotCount: $shotCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $ShotStatsTable shotStats = $ShotStatsTable(this);
  late final $StrokeTrendsTable strokeTrends = $StrokeTrendsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sessions,
    shotStats,
    strokeTrends,
    settings,
  ];
}

typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      Value<int> id,
      required DateTime startedAt,
      required int durationS,
      required String type,
      required String coachId,
      required String skillTier,
      required double overallScore,
      required int shotsTotal,
      required String summaryGood,
      required String summaryImprove,
      required String drills,
      Value<String> chatHistory,
      Value<String> headline,
      Value<String> encouragement,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<int> id,
      Value<DateTime> startedAt,
      Value<int> durationS,
      Value<String> type,
      Value<String> coachId,
      Value<String> skillTier,
      Value<double> overallScore,
      Value<int> shotsTotal,
      Value<String> summaryGood,
      Value<String> summaryImprove,
      Value<String> drills,
      Value<String> chatHistory,
      Value<String> headline,
      Value<String> encouragement,
    });

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ShotStatsTable, List<ShotStat>>
  _shotStatsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.shotStats,
    aliasName: 'sessions__id__shot_stats__session_id',
  );

  $$ShotStatsTableProcessedTableManager get shotStatsRefs {
    final manager = $$ShotStatsTableTableManager(
      $_db,
      $_db.shotStats,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_shotStatsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationS => $composableBuilder(
    column: $table.durationS,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coachId => $composableBuilder(
    column: $table.coachId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skillTier => $composableBuilder(
    column: $table.skillTier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get overallScore => $composableBuilder(
    column: $table.overallScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shotsTotal => $composableBuilder(
    column: $table.shotsTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryGood => $composableBuilder(
    column: $table.summaryGood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryImprove => $composableBuilder(
    column: $table.summaryImprove,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get drills => $composableBuilder(
    column: $table.drills,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chatHistory => $composableBuilder(
    column: $table.chatHistory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headline => $composableBuilder(
    column: $table.headline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encouragement => $composableBuilder(
    column: $table.encouragement,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> shotStatsRefs(
    Expression<bool> Function($$ShotStatsTableFilterComposer f) f,
  ) {
    final $$ShotStatsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shotStats,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotStatsTableFilterComposer(
            $db: $db,
            $table: $db.shotStats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationS => $composableBuilder(
    column: $table.durationS,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coachId => $composableBuilder(
    column: $table.coachId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skillTier => $composableBuilder(
    column: $table.skillTier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get overallScore => $composableBuilder(
    column: $table.overallScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shotsTotal => $composableBuilder(
    column: $table.shotsTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryGood => $composableBuilder(
    column: $table.summaryGood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryImprove => $composableBuilder(
    column: $table.summaryImprove,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get drills => $composableBuilder(
    column: $table.drills,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chatHistory => $composableBuilder(
    column: $table.chatHistory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headline => $composableBuilder(
    column: $table.headline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encouragement => $composableBuilder(
    column: $table.encouragement,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get durationS =>
      $composableBuilder(column: $table.durationS, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get coachId =>
      $composableBuilder(column: $table.coachId, builder: (column) => column);

  GeneratedColumn<String> get skillTier =>
      $composableBuilder(column: $table.skillTier, builder: (column) => column);

  GeneratedColumn<double> get overallScore => $composableBuilder(
    column: $table.overallScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get shotsTotal => $composableBuilder(
    column: $table.shotsTotal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryGood => $composableBuilder(
    column: $table.summaryGood,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryImprove => $composableBuilder(
    column: $table.summaryImprove,
    builder: (column) => column,
  );

  GeneratedColumn<String> get drills =>
      $composableBuilder(column: $table.drills, builder: (column) => column);

  GeneratedColumn<String> get chatHistory => $composableBuilder(
    column: $table.chatHistory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get headline =>
      $composableBuilder(column: $table.headline, builder: (column) => column);

  GeneratedColumn<String> get encouragement => $composableBuilder(
    column: $table.encouragement,
    builder: (column) => column,
  );

  Expression<T> shotStatsRefs<T extends Object>(
    Expression<T> Function($$ShotStatsTableAnnotationComposer a) f,
  ) {
    final $$ShotStatsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shotStats,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotStatsTableAnnotationComposer(
            $db: $db,
            $table: $db.shotStats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, $$SessionsTableReferences),
          Session,
          PrefetchHooks Function({bool shotStatsRefs})
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> durationS = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> coachId = const Value.absent(),
                Value<String> skillTier = const Value.absent(),
                Value<double> overallScore = const Value.absent(),
                Value<int> shotsTotal = const Value.absent(),
                Value<String> summaryGood = const Value.absent(),
                Value<String> summaryImprove = const Value.absent(),
                Value<String> drills = const Value.absent(),
                Value<String> chatHistory = const Value.absent(),
                Value<String> headline = const Value.absent(),
                Value<String> encouragement = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                startedAt: startedAt,
                durationS: durationS,
                type: type,
                coachId: coachId,
                skillTier: skillTier,
                overallScore: overallScore,
                shotsTotal: shotsTotal,
                summaryGood: summaryGood,
                summaryImprove: summaryImprove,
                drills: drills,
                chatHistory: chatHistory,
                headline: headline,
                encouragement: encouragement,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime startedAt,
                required int durationS,
                required String type,
                required String coachId,
                required String skillTier,
                required double overallScore,
                required int shotsTotal,
                required String summaryGood,
                required String summaryImprove,
                required String drills,
                Value<String> chatHistory = const Value.absent(),
                Value<String> headline = const Value.absent(),
                Value<String> encouragement = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                startedAt: startedAt,
                durationS: durationS,
                type: type,
                coachId: coachId,
                skillTier: skillTier,
                overallScore: overallScore,
                shotsTotal: shotsTotal,
                summaryGood: summaryGood,
                summaryImprove: summaryImprove,
                drills: drills,
                chatHistory: chatHistory,
                headline: headline,
                encouragement: encouragement,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shotStatsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (shotStatsRefs) db.shotStats],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (shotStatsRefs)
                    await $_getPrefetchedData<
                      Session,
                      $SessionsTable,
                      ShotStat
                    >(
                      currentTable: table,
                      referencedTable: $$SessionsTableReferences
                          ._shotStatsRefsTable(db),
                      managerFromTypedResult: (p0) => $$SessionsTableReferences(
                        db,
                        table,
                        p0,
                      ).shotStatsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, $$SessionsTableReferences),
      Session,
      PrefetchHooks Function({bool shotStatsRefs})
    >;
typedef $$ShotStatsTableCreateCompanionBuilder =
    ShotStatsCompanion Function({
      Value<int> id,
      required int sessionId,
      required String stroke,
      required double score,
      required String phaseScores,
      Value<String?> topDeviationId,
      required int tOffsetMs,
    });
typedef $$ShotStatsTableUpdateCompanionBuilder =
    ShotStatsCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<String> stroke,
      Value<double> score,
      Value<String> phaseScores,
      Value<String?> topDeviationId,
      Value<int> tOffsetMs,
    });

final class $$ShotStatsTableReferences
    extends BaseReferences<_$AppDatabase, $ShotStatsTable, ShotStat> {
  $$ShotStatsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias('shot_stats__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShotStatsTableFilterComposer
    extends Composer<_$AppDatabase, $ShotStatsTable> {
  $$ShotStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stroke => $composableBuilder(
    column: $table.stroke,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phaseScores => $composableBuilder(
    column: $table.phaseScores,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topDeviationId => $composableBuilder(
    column: $table.topDeviationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tOffsetMs => $composableBuilder(
    column: $table.tOffsetMs,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShotStatsTable> {
  $$ShotStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stroke => $composableBuilder(
    column: $table.stroke,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phaseScores => $composableBuilder(
    column: $table.phaseScores,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topDeviationId => $composableBuilder(
    column: $table.topDeviationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tOffsetMs => $composableBuilder(
    column: $table.tOffsetMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShotStatsTable> {
  $$ShotStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get stroke =>
      $composableBuilder(column: $table.stroke, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<String> get phaseScores => $composableBuilder(
    column: $table.phaseScores,
    builder: (column) => column,
  );

  GeneratedColumn<String> get topDeviationId => $composableBuilder(
    column: $table.topDeviationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tOffsetMs =>
      $composableBuilder(column: $table.tOffsetMs, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShotStatsTable,
          ShotStat,
          $$ShotStatsTableFilterComposer,
          $$ShotStatsTableOrderingComposer,
          $$ShotStatsTableAnnotationComposer,
          $$ShotStatsTableCreateCompanionBuilder,
          $$ShotStatsTableUpdateCompanionBuilder,
          (ShotStat, $$ShotStatsTableReferences),
          ShotStat,
          PrefetchHooks Function({bool sessionId})
        > {
  $$ShotStatsTableTableManager(_$AppDatabase db, $ShotStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShotStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShotStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShotStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<String> stroke = const Value.absent(),
                Value<double> score = const Value.absent(),
                Value<String> phaseScores = const Value.absent(),
                Value<String?> topDeviationId = const Value.absent(),
                Value<int> tOffsetMs = const Value.absent(),
              }) => ShotStatsCompanion(
                id: id,
                sessionId: sessionId,
                stroke: stroke,
                score: score,
                phaseScores: phaseScores,
                topDeviationId: topDeviationId,
                tOffsetMs: tOffsetMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required String stroke,
                required double score,
                required String phaseScores,
                Value<String?> topDeviationId = const Value.absent(),
                required int tOffsetMs,
              }) => ShotStatsCompanion.insert(
                id: id,
                sessionId: sessionId,
                stroke: stroke,
                score: score,
                phaseScores: phaseScores,
                topDeviationId: topDeviationId,
                tOffsetMs: tOffsetMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ShotStatsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$ShotStatsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$ShotStatsTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ShotStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShotStatsTable,
      ShotStat,
      $$ShotStatsTableFilterComposer,
      $$ShotStatsTableOrderingComposer,
      $$ShotStatsTableAnnotationComposer,
      $$ShotStatsTableCreateCompanionBuilder,
      $$ShotStatsTableUpdateCompanionBuilder,
      (ShotStat, $$ShotStatsTableReferences),
      ShotStat,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$StrokeTrendsTableCreateCompanionBuilder =
    StrokeTrendsCompanion Function({
      required String stroke,
      required DateTime weekStart,
      required double avgScore,
      required int shotCount,
      Value<int> rowid,
    });
typedef $$StrokeTrendsTableUpdateCompanionBuilder =
    StrokeTrendsCompanion Function({
      Value<String> stroke,
      Value<DateTime> weekStart,
      Value<double> avgScore,
      Value<int> shotCount,
      Value<int> rowid,
    });

class $$StrokeTrendsTableFilterComposer
    extends Composer<_$AppDatabase, $StrokeTrendsTable> {
  $$StrokeTrendsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get stroke => $composableBuilder(
    column: $table.stroke,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get weekStart => $composableBuilder(
    column: $table.weekStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgScore => $composableBuilder(
    column: $table.avgScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shotCount => $composableBuilder(
    column: $table.shotCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StrokeTrendsTableOrderingComposer
    extends Composer<_$AppDatabase, $StrokeTrendsTable> {
  $$StrokeTrendsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get stroke => $composableBuilder(
    column: $table.stroke,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get weekStart => $composableBuilder(
    column: $table.weekStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgScore => $composableBuilder(
    column: $table.avgScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shotCount => $composableBuilder(
    column: $table.shotCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StrokeTrendsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StrokeTrendsTable> {
  $$StrokeTrendsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get stroke =>
      $composableBuilder(column: $table.stroke, builder: (column) => column);

  GeneratedColumn<DateTime> get weekStart =>
      $composableBuilder(column: $table.weekStart, builder: (column) => column);

  GeneratedColumn<double> get avgScore =>
      $composableBuilder(column: $table.avgScore, builder: (column) => column);

  GeneratedColumn<int> get shotCount =>
      $composableBuilder(column: $table.shotCount, builder: (column) => column);
}

class $$StrokeTrendsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StrokeTrendsTable,
          StrokeTrend,
          $$StrokeTrendsTableFilterComposer,
          $$StrokeTrendsTableOrderingComposer,
          $$StrokeTrendsTableAnnotationComposer,
          $$StrokeTrendsTableCreateCompanionBuilder,
          $$StrokeTrendsTableUpdateCompanionBuilder,
          (
            StrokeTrend,
            BaseReferences<_$AppDatabase, $StrokeTrendsTable, StrokeTrend>,
          ),
          StrokeTrend,
          PrefetchHooks Function()
        > {
  $$StrokeTrendsTableTableManager(_$AppDatabase db, $StrokeTrendsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StrokeTrendsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StrokeTrendsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StrokeTrendsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> stroke = const Value.absent(),
                Value<DateTime> weekStart = const Value.absent(),
                Value<double> avgScore = const Value.absent(),
                Value<int> shotCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StrokeTrendsCompanion(
                stroke: stroke,
                weekStart: weekStart,
                avgScore: avgScore,
                shotCount: shotCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String stroke,
                required DateTime weekStart,
                required double avgScore,
                required int shotCount,
                Value<int> rowid = const Value.absent(),
              }) => StrokeTrendsCompanion.insert(
                stroke: stroke,
                weekStart: weekStart,
                avgScore: avgScore,
                shotCount: shotCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StrokeTrendsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StrokeTrendsTable,
      StrokeTrend,
      $$StrokeTrendsTableFilterComposer,
      $$StrokeTrendsTableOrderingComposer,
      $$StrokeTrendsTableAnnotationComposer,
      $$StrokeTrendsTableCreateCompanionBuilder,
      $$StrokeTrendsTableUpdateCompanionBuilder,
      (
        StrokeTrend,
        BaseReferences<_$AppDatabase, $StrokeTrendsTable, StrokeTrend>,
      ),
      StrokeTrend,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$ShotStatsTableTableManager get shotStats =>
      $$ShotStatsTableTableManager(_db, _db.shotStats);
  $$StrokeTrendsTableTableManager get strokeTrends =>
      $$StrokeTrendsTableTableManager(_db, _db.strokeTrends);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
