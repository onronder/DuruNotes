// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $LocalNotesTable extends LocalNotes
    with TableInfo<$LocalNotesTable, LocalNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _encryptedMetadataMeta = const VerificationMeta(
    'encryptedMetadata',
  );
  @override
  late final GeneratedColumn<String> encryptedMetadata =
      GeneratedColumn<String>(
        'encrypted_metadata',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    body,
    updatedAt,
    deleted,
    encryptedMetadata,
    isPinned,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalNote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('encrypted_metadata')) {
      context.handle(
        _encryptedMetadataMeta,
        encryptedMetadata.isAcceptableOrUnknown(
          data['encrypted_metadata']!,
          _encryptedMetadataMeta,
        ),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalNote(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      encryptedMetadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_metadata'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
    );
  }

  @override
  $LocalNotesTable createAlias(String alias) {
    return $LocalNotesTable(attachedDatabase, alias);
  }
}

class LocalNote extends DataClass implements Insertable<LocalNote> {
  final String id;
  final String title;
  final String body;
  final DateTime updatedAt;
  final bool deleted;
  final String? encryptedMetadata;
  final bool isPinned;
  const LocalNote({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
    required this.deleted,
    this.encryptedMetadata,
    required this.isPinned,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || encryptedMetadata != null) {
      map['encrypted_metadata'] = Variable<String>(encryptedMetadata);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    return map;
  }

  LocalNotesCompanion toCompanion(bool nullToAbsent) {
    return LocalNotesCompanion(
      id: Value(id),
      title: Value(title),
      body: Value(body),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      encryptedMetadata: encryptedMetadata == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedMetadata),
      isPinned: Value(isPinned),
    );
  }

  factory LocalNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalNote(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      encryptedMetadata: serializer.fromJson<String?>(
        json['encryptedMetadata'],
      ),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'encryptedMetadata': serializer.toJson<String?>(encryptedMetadata),
      'isPinned': serializer.toJson<bool>(isPinned),
    };
  }

  LocalNote copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? updatedAt,
    bool? deleted,
    Value<String?> encryptedMetadata = const Value.absent(),
    bool? isPinned,
  }) => LocalNote(
    id: id ?? this.id,
    title: title ?? this.title,
    body: body ?? this.body,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    encryptedMetadata: encryptedMetadata.present
        ? encryptedMetadata.value
        : this.encryptedMetadata,
    isPinned: isPinned ?? this.isPinned,
  );
  LocalNote copyWithCompanion(LocalNotesCompanion data) {
    return LocalNote(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      encryptedMetadata: data.encryptedMetadata.present
          ? data.encryptedMetadata.value
          : this.encryptedMetadata,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalNote(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('encryptedMetadata: $encryptedMetadata, ')
          ..write('isPinned: $isPinned')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    body,
    updatedAt,
    deleted,
    encryptedMetadata,
    isPinned,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalNote &&
          other.id == this.id &&
          other.title == this.title &&
          other.body == this.body &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.encryptedMetadata == this.encryptedMetadata &&
          other.isPinned == this.isPinned);
}

class LocalNotesCompanion extends UpdateCompanion<LocalNote> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> body;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<String?> encryptedMetadata;
  final Value<bool> isPinned;
  final Value<int> rowid;
  const LocalNotesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.encryptedMetadata = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalNotesCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.encryptedMetadata = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt);
  static Insertable<LocalNote> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? body,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<String>? encryptedMetadata,
    Expression<bool>? isPinned,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (encryptedMetadata != null) 'encrypted_metadata': encryptedMetadata,
      if (isPinned != null) 'is_pinned': isPinned,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalNotesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? body,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<String?>? encryptedMetadata,
    Value<bool>? isPinned,
    Value<int>? rowid,
  }) {
    return LocalNotesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      encryptedMetadata: encryptedMetadata ?? this.encryptedMetadata,
      isPinned: isPinned ?? this.isPinned,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (encryptedMetadata.present) {
      map['encrypted_metadata'] = Variable<String>(encryptedMetadata.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalNotesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('encryptedMetadata: $encryptedMetadata, ')
          ..write('isPinned: $isPinned, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingOpsTable extends PendingOps
    with TableInfo<$PendingOpsTable, PendingOp> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingOpsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityId,
    kind,
    payload,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_ops';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingOp> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingOp map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingOp(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingOpsTable createAlias(String alias) {
    return $PendingOpsTable(attachedDatabase, alias);
  }
}

class PendingOp extends DataClass implements Insertable<PendingOp> {
  final int id;
  final String entityId;
  final String kind;
  final String? payload;
  final DateTime createdAt;
  const PendingOp({
    required this.id,
    required this.entityId,
    required this.kind,
    this.payload,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_id'] = Variable<String>(entityId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingOpsCompanion toCompanion(bool nullToAbsent) {
    return PendingOpsCompanion(
      id: Value(id),
      entityId: Value(entityId),
      kind: Value(kind),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      createdAt: Value(createdAt),
    );
  }

  factory PendingOp.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingOp(
      id: serializer.fromJson<int>(json['id']),
      entityId: serializer.fromJson<String>(json['entityId']),
      kind: serializer.fromJson<String>(json['kind']),
      payload: serializer.fromJson<String?>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityId': serializer.toJson<String>(entityId),
      'kind': serializer.toJson<String>(kind),
      'payload': serializer.toJson<String?>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingOp copyWith({
    int? id,
    String? entityId,
    String? kind,
    Value<String?> payload = const Value.absent(),
    DateTime? createdAt,
  }) => PendingOp(
    id: id ?? this.id,
    entityId: entityId ?? this.entityId,
    kind: kind ?? this.kind,
    payload: payload.present ? payload.value : this.payload,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingOp copyWithCompanion(PendingOpsCompanion data) {
    return PendingOp(
      id: data.id.present ? data.id.value : this.id,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingOp(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entityId, kind, payload, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingOp &&
          other.id == this.id &&
          other.entityId == this.entityId &&
          other.kind == this.kind &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt);
}

class PendingOpsCompanion extends UpdateCompanion<PendingOp> {
  final Value<int> id;
  final Value<String> entityId;
  final Value<String> kind;
  final Value<String?> payload;
  final Value<DateTime> createdAt;
  const PendingOpsCompanion({
    this.id = const Value.absent(),
    this.entityId = const Value.absent(),
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PendingOpsCompanion.insert({
    this.id = const Value.absent(),
    required String entityId,
    required String kind,
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : entityId = Value(entityId),
       kind = Value(kind);
  static Insertable<PendingOp> custom({
    Expression<int>? id,
    Expression<String>? entityId,
    Expression<String>? kind,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityId != null) 'entity_id': entityId,
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PendingOpsCompanion copyWith({
    Value<int>? id,
    Value<String>? entityId,
    Value<String>? kind,
    Value<String?>? payload,
    Value<DateTime>? createdAt,
  }) {
    return PendingOpsCompanion(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingOpsCompanion(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $NoteTagsTable extends NoteTags with TableInfo<$NoteTagsTable, NoteTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [noteId, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {noteId, tag};
  @override
  NoteTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteTag(
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
    );
  }

  @override
  $NoteTagsTable createAlias(String alias) {
    return $NoteTagsTable(attachedDatabase, alias);
  }
}

class NoteTag extends DataClass implements Insertable<NoteTag> {
  final String noteId;
  final String tag;
  const NoteTag({required this.noteId, required this.tag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id'] = Variable<String>(noteId);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  NoteTagsCompanion toCompanion(bool nullToAbsent) {
    return NoteTagsCompanion(noteId: Value(noteId), tag: Value(tag));
  }

  factory NoteTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteTag(
      noteId: serializer.fromJson<String>(json['noteId']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId': serializer.toJson<String>(noteId),
      'tag': serializer.toJson<String>(tag),
    };
  }

  NoteTag copyWith({String? noteId, String? tag}) =>
      NoteTag(noteId: noteId ?? this.noteId, tag: tag ?? this.tag);
  NoteTag copyWithCompanion(NoteTagsCompanion data) {
    return NoteTag(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteTag(')
          ..write('noteId: $noteId, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(noteId, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteTag &&
          other.noteId == this.noteId &&
          other.tag == this.tag);
}

class NoteTagsCompanion extends UpdateCompanion<NoteTag> {
  final Value<String> noteId;
  final Value<String> tag;
  final Value<int> rowid;
  const NoteTagsCompanion({
    this.noteId = const Value.absent(),
    this.tag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteTagsCompanion.insert({
    required String noteId,
    required String tag,
    this.rowid = const Value.absent(),
  }) : noteId = Value(noteId),
       tag = Value(tag);
  static Insertable<NoteTag> custom({
    Expression<String>? noteId,
    Expression<String>? tag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (noteId != null) 'note_id': noteId,
      if (tag != null) 'tag': tag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteTagsCompanion copyWith({
    Value<String>? noteId,
    Value<String>? tag,
    Value<int>? rowid,
  }) {
    return NoteTagsCompanion(
      noteId: noteId ?? this.noteId,
      tag: tag ?? this.tag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTagsCompanion(')
          ..write('noteId: $noteId, ')
          ..write('tag: $tag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteLinksTable extends NoteLinks
    with TableInfo<$NoteLinksTable, NoteLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetTitleMeta = const VerificationMeta(
    'targetTitle',
  );
  @override
  late final GeneratedColumn<String> targetTitle = GeneratedColumn<String>(
    'target_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [sourceId, targetTitle, targetId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('target_title')) {
      context.handle(
        _targetTitleMeta,
        targetTitle.isAcceptableOrUnknown(
          data['target_title']!,
          _targetTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetTitleMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId, targetTitle};
  @override
  NoteLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteLink(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      targetTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_title'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      ),
    );
  }

  @override
  $NoteLinksTable createAlias(String alias) {
    return $NoteLinksTable(attachedDatabase, alias);
  }
}

class NoteLink extends DataClass implements Insertable<NoteLink> {
  final String sourceId;
  final String targetTitle;
  final String? targetId;
  const NoteLink({
    required this.sourceId,
    required this.targetTitle,
    this.targetId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['target_title'] = Variable<String>(targetTitle);
    if (!nullToAbsent || targetId != null) {
      map['target_id'] = Variable<String>(targetId);
    }
    return map;
  }

  NoteLinksCompanion toCompanion(bool nullToAbsent) {
    return NoteLinksCompanion(
      sourceId: Value(sourceId),
      targetTitle: Value(targetTitle),
      targetId: targetId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetId),
    );
  }

  factory NoteLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteLink(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      targetTitle: serializer.fromJson<String>(json['targetTitle']),
      targetId: serializer.fromJson<String?>(json['targetId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'targetTitle': serializer.toJson<String>(targetTitle),
      'targetId': serializer.toJson<String?>(targetId),
    };
  }

  NoteLink copyWith({
    String? sourceId,
    String? targetTitle,
    Value<String?> targetId = const Value.absent(),
  }) => NoteLink(
    sourceId: sourceId ?? this.sourceId,
    targetTitle: targetTitle ?? this.targetTitle,
    targetId: targetId.present ? targetId.value : this.targetId,
  );
  NoteLink copyWithCompanion(NoteLinksCompanion data) {
    return NoteLink(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      targetTitle: data.targetTitle.present
          ? data.targetTitle.value
          : this.targetTitle,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteLink(')
          ..write('sourceId: $sourceId, ')
          ..write('targetTitle: $targetTitle, ')
          ..write('targetId: $targetId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sourceId, targetTitle, targetId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteLink &&
          other.sourceId == this.sourceId &&
          other.targetTitle == this.targetTitle &&
          other.targetId == this.targetId);
}

class NoteLinksCompanion extends UpdateCompanion<NoteLink> {
  final Value<String> sourceId;
  final Value<String> targetTitle;
  final Value<String?> targetId;
  final Value<int> rowid;
  const NoteLinksCompanion({
    this.sourceId = const Value.absent(),
    this.targetTitle = const Value.absent(),
    this.targetId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteLinksCompanion.insert({
    required String sourceId,
    required String targetTitle,
    this.targetId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       targetTitle = Value(targetTitle);
  static Insertable<NoteLink> custom({
    Expression<String>? sourceId,
    Expression<String>? targetTitle,
    Expression<String>? targetId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (targetTitle != null) 'target_title': targetTitle,
      if (targetId != null) 'target_id': targetId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteLinksCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? targetTitle,
    Value<String?>? targetId,
    Value<int>? rowid,
  }) {
    return NoteLinksCompanion(
      sourceId: sourceId ?? this.sourceId,
      targetTitle: targetTitle ?? this.targetTitle,
      targetId: targetId ?? this.targetId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (targetTitle.present) {
      map['target_title'] = Variable<String>(targetTitle.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteLinksCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('targetTitle: $targetTitle, ')
          ..write('targetId: $targetId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteRemindersTable extends NoteReminders
    with TableInfo<$NoteRemindersTable, NoteReminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteRemindersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ReminderType, int> type =
      GeneratedColumn<int>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<ReminderType>($NoteRemindersTable.$convertertype);
  static const VerificationMeta _remindAtMeta = const VerificationMeta(
    'remindAt',
  );
  @override
  late final GeneratedColumn<DateTime> remindAt = GeneratedColumn<DateTime>(
    'remind_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _radiusMeta = const VerificationMeta('radius');
  @override
  late final GeneratedColumn<double> radius = GeneratedColumn<double>(
    'radius',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationNameMeta = const VerificationMeta(
    'locationName',
  );
  @override
  late final GeneratedColumn<String> locationName = GeneratedColumn<String>(
    'location_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RecurrencePattern, int>
  recurrencePattern =
      GeneratedColumn<int>(
        'recurrence_pattern',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: Constant(RecurrencePattern.none.index),
      ).withConverter<RecurrencePattern>(
        $NoteRemindersTable.$converterrecurrencePattern,
      );
  static const VerificationMeta _recurrenceEndDateMeta = const VerificationMeta(
    'recurrenceEndDate',
  );
  @override
  late final GeneratedColumn<DateTime> recurrenceEndDate =
      GeneratedColumn<DateTime>(
        'recurrence_end_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _recurrenceIntervalMeta =
      const VerificationMeta('recurrenceInterval');
  @override
  late final GeneratedColumn<int> recurrenceInterval = GeneratedColumn<int>(
    'recurrence_interval',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _snoozedUntilMeta = const VerificationMeta(
    'snoozedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> snoozedUntil = GeneratedColumn<DateTime>(
    'snoozed_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snoozeCountMeta = const VerificationMeta(
    'snoozeCount',
  );
  @override
  late final GeneratedColumn<int> snoozeCount = GeneratedColumn<int>(
    'snooze_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _notificationTitleMeta = const VerificationMeta(
    'notificationTitle',
  );
  @override
  late final GeneratedColumn<String> notificationTitle =
      GeneratedColumn<String>(
        'notification_title',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _notificationBodyMeta = const VerificationMeta(
    'notificationBody',
  );
  @override
  late final GeneratedColumn<String> notificationBody = GeneratedColumn<String>(
    'notification_body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notificationImageMeta = const VerificationMeta(
    'notificationImage',
  );
  @override
  late final GeneratedColumn<String> notificationImage =
      GeneratedColumn<String>(
        'notification_image',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _timeZoneMeta = const VerificationMeta(
    'timeZone',
  );
  @override
  late final GeneratedColumn<String> timeZone = GeneratedColumn<String>(
    'time_zone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastTriggeredMeta = const VerificationMeta(
    'lastTriggered',
  );
  @override
  late final GeneratedColumn<DateTime> lastTriggered =
      GeneratedColumn<DateTime>(
        'last_triggered',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _triggerCountMeta = const VerificationMeta(
    'triggerCount',
  );
  @override
  late final GeneratedColumn<int> triggerCount = GeneratedColumn<int>(
    'trigger_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    title,
    body,
    type,
    remindAt,
    isActive,
    latitude,
    longitude,
    radius,
    locationName,
    recurrencePattern,
    recurrenceEndDate,
    recurrenceInterval,
    snoozedUntil,
    snoozeCount,
    notificationTitle,
    notificationBody,
    notificationImage,
    timeZone,
    createdAt,
    lastTriggered,
    triggerCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteReminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('remind_at')) {
      context.handle(
        _remindAtMeta,
        remindAt.isAcceptableOrUnknown(data['remind_at']!, _remindAtMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('radius')) {
      context.handle(
        _radiusMeta,
        radius.isAcceptableOrUnknown(data['radius']!, _radiusMeta),
      );
    }
    if (data.containsKey('location_name')) {
      context.handle(
        _locationNameMeta,
        locationName.isAcceptableOrUnknown(
          data['location_name']!,
          _locationNameMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_end_date')) {
      context.handle(
        _recurrenceEndDateMeta,
        recurrenceEndDate.isAcceptableOrUnknown(
          data['recurrence_end_date']!,
          _recurrenceEndDateMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_interval')) {
      context.handle(
        _recurrenceIntervalMeta,
        recurrenceInterval.isAcceptableOrUnknown(
          data['recurrence_interval']!,
          _recurrenceIntervalMeta,
        ),
      );
    }
    if (data.containsKey('snoozed_until')) {
      context.handle(
        _snoozedUntilMeta,
        snoozedUntil.isAcceptableOrUnknown(
          data['snoozed_until']!,
          _snoozedUntilMeta,
        ),
      );
    }
    if (data.containsKey('snooze_count')) {
      context.handle(
        _snoozeCountMeta,
        snoozeCount.isAcceptableOrUnknown(
          data['snooze_count']!,
          _snoozeCountMeta,
        ),
      );
    }
    if (data.containsKey('notification_title')) {
      context.handle(
        _notificationTitleMeta,
        notificationTitle.isAcceptableOrUnknown(
          data['notification_title']!,
          _notificationTitleMeta,
        ),
      );
    }
    if (data.containsKey('notification_body')) {
      context.handle(
        _notificationBodyMeta,
        notificationBody.isAcceptableOrUnknown(
          data['notification_body']!,
          _notificationBodyMeta,
        ),
      );
    }
    if (data.containsKey('notification_image')) {
      context.handle(
        _notificationImageMeta,
        notificationImage.isAcceptableOrUnknown(
          data['notification_image']!,
          _notificationImageMeta,
        ),
      );
    }
    if (data.containsKey('time_zone')) {
      context.handle(
        _timeZoneMeta,
        timeZone.isAcceptableOrUnknown(data['time_zone']!, _timeZoneMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('last_triggered')) {
      context.handle(
        _lastTriggeredMeta,
        lastTriggered.isAcceptableOrUnknown(
          data['last_triggered']!,
          _lastTriggeredMeta,
        ),
      );
    }
    if (data.containsKey('trigger_count')) {
      context.handle(
        _triggerCountMeta,
        triggerCount.isAcceptableOrUnknown(
          data['trigger_count']!,
          _triggerCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteReminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteReminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      type: $NoteRemindersTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}type'],
        )!,
      ),
      remindAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remind_at'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      radius: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}radius'],
      ),
      locationName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_name'],
      ),
      recurrencePattern: $NoteRemindersTable.$converterrecurrencePattern
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.int,
              data['${effectivePrefix}recurrence_pattern'],
            )!,
          ),
      recurrenceEndDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recurrence_end_date'],
      ),
      recurrenceInterval: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recurrence_interval'],
      )!,
      snoozedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}snoozed_until'],
      ),
      snoozeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snooze_count'],
      )!,
      notificationTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notification_title'],
      ),
      notificationBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notification_body'],
      ),
      notificationImage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notification_image'],
      ),
      timeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastTriggered: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_triggered'],
      ),
      triggerCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trigger_count'],
      )!,
    );
  }

  @override
  $NoteRemindersTable createAlias(String alias) {
    return $NoteRemindersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ReminderType, int, int> $convertertype =
      const EnumIndexConverter<ReminderType>(ReminderType.values);
  static JsonTypeConverter2<RecurrencePattern, int, int>
  $converterrecurrencePattern = const EnumIndexConverter<RecurrencePattern>(
    RecurrencePattern.values,
  );
}

class NoteReminder extends DataClass implements Insertable<NoteReminder> {
  final int id;
  final String noteId;
  final String title;
  final String body;
  final ReminderType type;
  final DateTime? remindAt;
  final bool isActive;
  final double? latitude;
  final double? longitude;
  final double? radius;
  final String? locationName;
  final RecurrencePattern recurrencePattern;
  final DateTime? recurrenceEndDate;
  final int recurrenceInterval;
  final DateTime? snoozedUntil;
  final int snoozeCount;
  final String? notificationTitle;
  final String? notificationBody;
  final String? notificationImage;
  final String? timeZone;
  final DateTime createdAt;
  final DateTime? lastTriggered;
  final int triggerCount;
  const NoteReminder({
    required this.id,
    required this.noteId,
    required this.title,
    required this.body,
    required this.type,
    this.remindAt,
    required this.isActive,
    this.latitude,
    this.longitude,
    this.radius,
    this.locationName,
    required this.recurrencePattern,
    this.recurrenceEndDate,
    required this.recurrenceInterval,
    this.snoozedUntil,
    required this.snoozeCount,
    this.notificationTitle,
    this.notificationBody,
    this.notificationImage,
    this.timeZone,
    required this.createdAt,
    this.lastTriggered,
    required this.triggerCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['note_id'] = Variable<String>(noteId);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    {
      map['type'] = Variable<int>(
        $NoteRemindersTable.$convertertype.toSql(type),
      );
    }
    if (!nullToAbsent || remindAt != null) {
      map['remind_at'] = Variable<DateTime>(remindAt);
    }
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || radius != null) {
      map['radius'] = Variable<double>(radius);
    }
    if (!nullToAbsent || locationName != null) {
      map['location_name'] = Variable<String>(locationName);
    }
    {
      map['recurrence_pattern'] = Variable<int>(
        $NoteRemindersTable.$converterrecurrencePattern.toSql(
          recurrencePattern,
        ),
      );
    }
    if (!nullToAbsent || recurrenceEndDate != null) {
      map['recurrence_end_date'] = Variable<DateTime>(recurrenceEndDate);
    }
    map['recurrence_interval'] = Variable<int>(recurrenceInterval);
    if (!nullToAbsent || snoozedUntil != null) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil);
    }
    map['snooze_count'] = Variable<int>(snoozeCount);
    if (!nullToAbsent || notificationTitle != null) {
      map['notification_title'] = Variable<String>(notificationTitle);
    }
    if (!nullToAbsent || notificationBody != null) {
      map['notification_body'] = Variable<String>(notificationBody);
    }
    if (!nullToAbsent || notificationImage != null) {
      map['notification_image'] = Variable<String>(notificationImage);
    }
    if (!nullToAbsent || timeZone != null) {
      map['time_zone'] = Variable<String>(timeZone);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastTriggered != null) {
      map['last_triggered'] = Variable<DateTime>(lastTriggered);
    }
    map['trigger_count'] = Variable<int>(triggerCount);
    return map;
  }

  NoteRemindersCompanion toCompanion(bool nullToAbsent) {
    return NoteRemindersCompanion(
      id: Value(id),
      noteId: Value(noteId),
      title: Value(title),
      body: Value(body),
      type: Value(type),
      remindAt: remindAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remindAt),
      isActive: Value(isActive),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      radius: radius == null && nullToAbsent
          ? const Value.absent()
          : Value(radius),
      locationName: locationName == null && nullToAbsent
          ? const Value.absent()
          : Value(locationName),
      recurrencePattern: Value(recurrencePattern),
      recurrenceEndDate: recurrenceEndDate == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceEndDate),
      recurrenceInterval: Value(recurrenceInterval),
      snoozedUntil: snoozedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntil),
      snoozeCount: Value(snoozeCount),
      notificationTitle: notificationTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(notificationTitle),
      notificationBody: notificationBody == null && nullToAbsent
          ? const Value.absent()
          : Value(notificationBody),
      notificationImage: notificationImage == null && nullToAbsent
          ? const Value.absent()
          : Value(notificationImage),
      timeZone: timeZone == null && nullToAbsent
          ? const Value.absent()
          : Value(timeZone),
      createdAt: Value(createdAt),
      lastTriggered: lastTriggered == null && nullToAbsent
          ? const Value.absent()
          : Value(lastTriggered),
      triggerCount: Value(triggerCount),
    );
  }

  factory NoteReminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteReminder(
      id: serializer.fromJson<int>(json['id']),
      noteId: serializer.fromJson<String>(json['noteId']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      type: $NoteRemindersTable.$convertertype.fromJson(
        serializer.fromJson<int>(json['type']),
      ),
      remindAt: serializer.fromJson<DateTime?>(json['remindAt']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      radius: serializer.fromJson<double?>(json['radius']),
      locationName: serializer.fromJson<String?>(json['locationName']),
      recurrencePattern: $NoteRemindersTable.$converterrecurrencePattern
          .fromJson(serializer.fromJson<int>(json['recurrencePattern'])),
      recurrenceEndDate: serializer.fromJson<DateTime?>(
        json['recurrenceEndDate'],
      ),
      recurrenceInterval: serializer.fromJson<int>(json['recurrenceInterval']),
      snoozedUntil: serializer.fromJson<DateTime?>(json['snoozedUntil']),
      snoozeCount: serializer.fromJson<int>(json['snoozeCount']),
      notificationTitle: serializer.fromJson<String?>(
        json['notificationTitle'],
      ),
      notificationBody: serializer.fromJson<String?>(json['notificationBody']),
      notificationImage: serializer.fromJson<String?>(
        json['notificationImage'],
      ),
      timeZone: serializer.fromJson<String?>(json['timeZone']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastTriggered: serializer.fromJson<DateTime?>(json['lastTriggered']),
      triggerCount: serializer.fromJson<int>(json['triggerCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'noteId': serializer.toJson<String>(noteId),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'type': serializer.toJson<int>(
        $NoteRemindersTable.$convertertype.toJson(type),
      ),
      'remindAt': serializer.toJson<DateTime?>(remindAt),
      'isActive': serializer.toJson<bool>(isActive),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'radius': serializer.toJson<double?>(radius),
      'locationName': serializer.toJson<String?>(locationName),
      'recurrencePattern': serializer.toJson<int>(
        $NoteRemindersTable.$converterrecurrencePattern.toJson(
          recurrencePattern,
        ),
      ),
      'recurrenceEndDate': serializer.toJson<DateTime?>(recurrenceEndDate),
      'recurrenceInterval': serializer.toJson<int>(recurrenceInterval),
      'snoozedUntil': serializer.toJson<DateTime?>(snoozedUntil),
      'snoozeCount': serializer.toJson<int>(snoozeCount),
      'notificationTitle': serializer.toJson<String?>(notificationTitle),
      'notificationBody': serializer.toJson<String?>(notificationBody),
      'notificationImage': serializer.toJson<String?>(notificationImage),
      'timeZone': serializer.toJson<String?>(timeZone),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastTriggered': serializer.toJson<DateTime?>(lastTriggered),
      'triggerCount': serializer.toJson<int>(triggerCount),
    };
  }

  NoteReminder copyWith({
    int? id,
    String? noteId,
    String? title,
    String? body,
    ReminderType? type,
    Value<DateTime?> remindAt = const Value.absent(),
    bool? isActive,
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    Value<double?> radius = const Value.absent(),
    Value<String?> locationName = const Value.absent(),
    RecurrencePattern? recurrencePattern,
    Value<DateTime?> recurrenceEndDate = const Value.absent(),
    int? recurrenceInterval,
    Value<DateTime?> snoozedUntil = const Value.absent(),
    int? snoozeCount,
    Value<String?> notificationTitle = const Value.absent(),
    Value<String?> notificationBody = const Value.absent(),
    Value<String?> notificationImage = const Value.absent(),
    Value<String?> timeZone = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> lastTriggered = const Value.absent(),
    int? triggerCount,
  }) => NoteReminder(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    title: title ?? this.title,
    body: body ?? this.body,
    type: type ?? this.type,
    remindAt: remindAt.present ? remindAt.value : this.remindAt,
    isActive: isActive ?? this.isActive,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    radius: radius.present ? radius.value : this.radius,
    locationName: locationName.present ? locationName.value : this.locationName,
    recurrencePattern: recurrencePattern ?? this.recurrencePattern,
    recurrenceEndDate: recurrenceEndDate.present
        ? recurrenceEndDate.value
        : this.recurrenceEndDate,
    recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
    snoozedUntil: snoozedUntil.present ? snoozedUntil.value : this.snoozedUntil,
    snoozeCount: snoozeCount ?? this.snoozeCount,
    notificationTitle: notificationTitle.present
        ? notificationTitle.value
        : this.notificationTitle,
    notificationBody: notificationBody.present
        ? notificationBody.value
        : this.notificationBody,
    notificationImage: notificationImage.present
        ? notificationImage.value
        : this.notificationImage,
    timeZone: timeZone.present ? timeZone.value : this.timeZone,
    createdAt: createdAt ?? this.createdAt,
    lastTriggered: lastTriggered.present
        ? lastTriggered.value
        : this.lastTriggered,
    triggerCount: triggerCount ?? this.triggerCount,
  );
  NoteReminder copyWithCompanion(NoteRemindersCompanion data) {
    return NoteReminder(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      type: data.type.present ? data.type.value : this.type,
      remindAt: data.remindAt.present ? data.remindAt.value : this.remindAt,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      radius: data.radius.present ? data.radius.value : this.radius,
      locationName: data.locationName.present
          ? data.locationName.value
          : this.locationName,
      recurrencePattern: data.recurrencePattern.present
          ? data.recurrencePattern.value
          : this.recurrencePattern,
      recurrenceEndDate: data.recurrenceEndDate.present
          ? data.recurrenceEndDate.value
          : this.recurrenceEndDate,
      recurrenceInterval: data.recurrenceInterval.present
          ? data.recurrenceInterval.value
          : this.recurrenceInterval,
      snoozedUntil: data.snoozedUntil.present
          ? data.snoozedUntil.value
          : this.snoozedUntil,
      snoozeCount: data.snoozeCount.present
          ? data.snoozeCount.value
          : this.snoozeCount,
      notificationTitle: data.notificationTitle.present
          ? data.notificationTitle.value
          : this.notificationTitle,
      notificationBody: data.notificationBody.present
          ? data.notificationBody.value
          : this.notificationBody,
      notificationImage: data.notificationImage.present
          ? data.notificationImage.value
          : this.notificationImage,
      timeZone: data.timeZone.present ? data.timeZone.value : this.timeZone,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastTriggered: data.lastTriggered.present
          ? data.lastTriggered.value
          : this.lastTriggered,
      triggerCount: data.triggerCount.present
          ? data.triggerCount.value
          : this.triggerCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteReminder(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('type: $type, ')
          ..write('remindAt: $remindAt, ')
          ..write('isActive: $isActive, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('radius: $radius, ')
          ..write('locationName: $locationName, ')
          ..write('recurrencePattern: $recurrencePattern, ')
          ..write('recurrenceEndDate: $recurrenceEndDate, ')
          ..write('recurrenceInterval: $recurrenceInterval, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('snoozeCount: $snoozeCount, ')
          ..write('notificationTitle: $notificationTitle, ')
          ..write('notificationBody: $notificationBody, ')
          ..write('notificationImage: $notificationImage, ')
          ..write('timeZone: $timeZone, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastTriggered: $lastTriggered, ')
          ..write('triggerCount: $triggerCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    noteId,
    title,
    body,
    type,
    remindAt,
    isActive,
    latitude,
    longitude,
    radius,
    locationName,
    recurrencePattern,
    recurrenceEndDate,
    recurrenceInterval,
    snoozedUntil,
    snoozeCount,
    notificationTitle,
    notificationBody,
    notificationImage,
    timeZone,
    createdAt,
    lastTriggered,
    triggerCount,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteReminder &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.title == this.title &&
          other.body == this.body &&
          other.type == this.type &&
          other.remindAt == this.remindAt &&
          other.isActive == this.isActive &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.radius == this.radius &&
          other.locationName == this.locationName &&
          other.recurrencePattern == this.recurrencePattern &&
          other.recurrenceEndDate == this.recurrenceEndDate &&
          other.recurrenceInterval == this.recurrenceInterval &&
          other.snoozedUntil == this.snoozedUntil &&
          other.snoozeCount == this.snoozeCount &&
          other.notificationTitle == this.notificationTitle &&
          other.notificationBody == this.notificationBody &&
          other.notificationImage == this.notificationImage &&
          other.timeZone == this.timeZone &&
          other.createdAt == this.createdAt &&
          other.lastTriggered == this.lastTriggered &&
          other.triggerCount == this.triggerCount);
}

class NoteRemindersCompanion extends UpdateCompanion<NoteReminder> {
  final Value<int> id;
  final Value<String> noteId;
  final Value<String> title;
  final Value<String> body;
  final Value<ReminderType> type;
  final Value<DateTime?> remindAt;
  final Value<bool> isActive;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<double?> radius;
  final Value<String?> locationName;
  final Value<RecurrencePattern> recurrencePattern;
  final Value<DateTime?> recurrenceEndDate;
  final Value<int> recurrenceInterval;
  final Value<DateTime?> snoozedUntil;
  final Value<int> snoozeCount;
  final Value<String?> notificationTitle;
  final Value<String?> notificationBody;
  final Value<String?> notificationImage;
  final Value<String?> timeZone;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastTriggered;
  final Value<int> triggerCount;
  const NoteRemindersCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.type = const Value.absent(),
    this.remindAt = const Value.absent(),
    this.isActive = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.radius = const Value.absent(),
    this.locationName = const Value.absent(),
    this.recurrencePattern = const Value.absent(),
    this.recurrenceEndDate = const Value.absent(),
    this.recurrenceInterval = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.snoozeCount = const Value.absent(),
    this.notificationTitle = const Value.absent(),
    this.notificationBody = const Value.absent(),
    this.notificationImage = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastTriggered = const Value.absent(),
    this.triggerCount = const Value.absent(),
  });
  NoteRemindersCompanion.insert({
    this.id = const Value.absent(),
    required String noteId,
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    required ReminderType type,
    this.remindAt = const Value.absent(),
    this.isActive = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.radius = const Value.absent(),
    this.locationName = const Value.absent(),
    this.recurrencePattern = const Value.absent(),
    this.recurrenceEndDate = const Value.absent(),
    this.recurrenceInterval = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.snoozeCount = const Value.absent(),
    this.notificationTitle = const Value.absent(),
    this.notificationBody = const Value.absent(),
    this.notificationImage = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastTriggered = const Value.absent(),
    this.triggerCount = const Value.absent(),
  }) : noteId = Value(noteId),
       type = Value(type);
  static Insertable<NoteReminder> custom({
    Expression<int>? id,
    Expression<String>? noteId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? type,
    Expression<DateTime>? remindAt,
    Expression<bool>? isActive,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? radius,
    Expression<String>? locationName,
    Expression<int>? recurrencePattern,
    Expression<DateTime>? recurrenceEndDate,
    Expression<int>? recurrenceInterval,
    Expression<DateTime>? snoozedUntil,
    Expression<int>? snoozeCount,
    Expression<String>? notificationTitle,
    Expression<String>? notificationBody,
    Expression<String>? notificationImage,
    Expression<String>? timeZone,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastTriggered,
    Expression<int>? triggerCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (type != null) 'type': type,
      if (remindAt != null) 'remind_at': remindAt,
      if (isActive != null) 'is_active': isActive,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (radius != null) 'radius': radius,
      if (locationName != null) 'location_name': locationName,
      if (recurrencePattern != null) 'recurrence_pattern': recurrencePattern,
      if (recurrenceEndDate != null) 'recurrence_end_date': recurrenceEndDate,
      if (recurrenceInterval != null) 'recurrence_interval': recurrenceInterval,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
      if (snoozeCount != null) 'snooze_count': snoozeCount,
      if (notificationTitle != null) 'notification_title': notificationTitle,
      if (notificationBody != null) 'notification_body': notificationBody,
      if (notificationImage != null) 'notification_image': notificationImage,
      if (timeZone != null) 'time_zone': timeZone,
      if (createdAt != null) 'created_at': createdAt,
      if (lastTriggered != null) 'last_triggered': lastTriggered,
      if (triggerCount != null) 'trigger_count': triggerCount,
    });
  }

  NoteRemindersCompanion copyWith({
    Value<int>? id,
    Value<String>? noteId,
    Value<String>? title,
    Value<String>? body,
    Value<ReminderType>? type,
    Value<DateTime?>? remindAt,
    Value<bool>? isActive,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<double?>? radius,
    Value<String?>? locationName,
    Value<RecurrencePattern>? recurrencePattern,
    Value<DateTime?>? recurrenceEndDate,
    Value<int>? recurrenceInterval,
    Value<DateTime?>? snoozedUntil,
    Value<int>? snoozeCount,
    Value<String?>? notificationTitle,
    Value<String?>? notificationBody,
    Value<String?>? notificationImage,
    Value<String?>? timeZone,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastTriggered,
    Value<int>? triggerCount,
  }) {
    return NoteRemindersCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      remindAt: remindAt ?? this.remindAt,
      isActive: isActive ?? this.isActive,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      locationName: locationName ?? this.locationName,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      notificationTitle: notificationTitle ?? this.notificationTitle,
      notificationBody: notificationBody ?? this.notificationBody,
      notificationImage: notificationImage ?? this.notificationImage,
      timeZone: timeZone ?? this.timeZone,
      createdAt: createdAt ?? this.createdAt,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      triggerCount: triggerCount ?? this.triggerCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(
        $NoteRemindersTable.$convertertype.toSql(type.value),
      );
    }
    if (remindAt.present) {
      map['remind_at'] = Variable<DateTime>(remindAt.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (radius.present) {
      map['radius'] = Variable<double>(radius.value);
    }
    if (locationName.present) {
      map['location_name'] = Variable<String>(locationName.value);
    }
    if (recurrencePattern.present) {
      map['recurrence_pattern'] = Variable<int>(
        $NoteRemindersTable.$converterrecurrencePattern.toSql(
          recurrencePattern.value,
        ),
      );
    }
    if (recurrenceEndDate.present) {
      map['recurrence_end_date'] = Variable<DateTime>(recurrenceEndDate.value);
    }
    if (recurrenceInterval.present) {
      map['recurrence_interval'] = Variable<int>(recurrenceInterval.value);
    }
    if (snoozedUntil.present) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil.value);
    }
    if (snoozeCount.present) {
      map['snooze_count'] = Variable<int>(snoozeCount.value);
    }
    if (notificationTitle.present) {
      map['notification_title'] = Variable<String>(notificationTitle.value);
    }
    if (notificationBody.present) {
      map['notification_body'] = Variable<String>(notificationBody.value);
    }
    if (notificationImage.present) {
      map['notification_image'] = Variable<String>(notificationImage.value);
    }
    if (timeZone.present) {
      map['time_zone'] = Variable<String>(timeZone.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastTriggered.present) {
      map['last_triggered'] = Variable<DateTime>(lastTriggered.value);
    }
    if (triggerCount.present) {
      map['trigger_count'] = Variable<int>(triggerCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteRemindersCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('type: $type, ')
          ..write('remindAt: $remindAt, ')
          ..write('isActive: $isActive, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('radius: $radius, ')
          ..write('locationName: $locationName, ')
          ..write('recurrencePattern: $recurrencePattern, ')
          ..write('recurrenceEndDate: $recurrenceEndDate, ')
          ..write('recurrenceInterval: $recurrenceInterval, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('snoozeCount: $snoozeCount, ')
          ..write('notificationTitle: $notificationTitle, ')
          ..write('notificationBody: $notificationBody, ')
          ..write('notificationImage: $notificationImage, ')
          ..write('timeZone: $timeZone, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastTriggered: $lastTriggered, ')
          ..write('triggerCount: $triggerCount')
          ..write(')'))
        .toString();
  }
}

class $LocalFoldersTable extends LocalFolders
    with TableInfo<$LocalFoldersTable, LocalFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    parentId,
    path,
    sortOrder,
    color,
    icon,
    description,
    createdAt,
    updatedAt,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFolder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $LocalFoldersTable createAlias(String alias) {
    return $LocalFoldersTable(attachedDatabase, alias);
  }
}

class LocalFolder extends DataClass implements Insertable<LocalFolder> {
  /// Unique identifier for the folder
  final String id;

  /// Display name of the folder
  final String name;

  /// Parent folder ID for hierarchy (null for root folders)
  final String? parentId;

  /// Full path from root (e.g., "/Work/Projects/2024")
  final String path;

  /// Display order within parent folder
  final int sortOrder;

  /// Optional color for folder display (hex format)
  final String? color;

  /// Optional icon name for folder display
  final String? icon;

  /// Folder description/notes
  final String description;

  /// Creation timestamp
  final DateTime createdAt;

  /// Last modification timestamp
  final DateTime updatedAt;

  /// Soft delete flag
  final bool deleted;
  const LocalFolder({
    required this.id,
    required this.name,
    this.parentId,
    required this.path,
    required this.sortOrder,
    this.color,
    this.icon,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['path'] = Variable<String>(path);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    map['description'] = Variable<String>(description);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  LocalFoldersCompanion toCompanion(bool nullToAbsent) {
    return LocalFoldersCompanion(
      id: Value(id),
      name: Value(name),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      path: Value(path),
      sortOrder: Value(sortOrder),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      description: Value(description),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
    );
  }

  factory LocalFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFolder(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      path: serializer.fromJson<String>(json['path']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      color: serializer.fromJson<String?>(json['color']),
      icon: serializer.fromJson<String?>(json['icon']),
      description: serializer.fromJson<String>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'parentId': serializer.toJson<String?>(parentId),
      'path': serializer.toJson<String>(path),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'color': serializer.toJson<String?>(color),
      'icon': serializer.toJson<String?>(icon),
      'description': serializer.toJson<String>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  LocalFolder copyWith({
    String? id,
    String? name,
    Value<String?> parentId = const Value.absent(),
    String? path,
    int? sortOrder,
    Value<String?> color = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
  }) => LocalFolder(
    id: id ?? this.id,
    name: name ?? this.name,
    parentId: parentId.present ? parentId.value : this.parentId,
    path: path ?? this.path,
    sortOrder: sortOrder ?? this.sortOrder,
    color: color.present ? color.value : this.color,
    icon: icon.present ? icon.value : this.icon,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );
  LocalFolder copyWithCompanion(LocalFoldersCompanion data) {
    return LocalFolder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      path: data.path.present ? data.path.value : this.path,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      color: data.color.present ? data.color.value : this.color,
      icon: data.icon.present ? data.icon.value : this.icon,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFolder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('path: $path, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    parentId,
    path,
    sortOrder,
    color,
    icon,
    description,
    createdAt,
    updatedAt,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFolder &&
          other.id == this.id &&
          other.name == this.name &&
          other.parentId == this.parentId &&
          other.path == this.path &&
          other.sortOrder == this.sortOrder &&
          other.color == this.color &&
          other.icon == this.icon &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted);
}

class LocalFoldersCompanion extends UpdateCompanion<LocalFolder> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> parentId;
  final Value<String> path;
  final Value<int> sortOrder;
  final Value<String?> color;
  final Value<String?> icon;
  final Value<String> description;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<int> rowid;
  const LocalFoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.parentId = const Value.absent(),
    this.path = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.color = const Value.absent(),
    this.icon = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFoldersCompanion.insert({
    required String id,
    required String name,
    this.parentId = const Value.absent(),
    required String path,
    this.sortOrder = const Value.absent(),
    this.color = const Value.absent(),
    this.icon = const Value.absent(),
    this.description = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       path = Value(path),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalFolder> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? parentId,
    Expression<String>? path,
    Expression<int>? sortOrder,
    Expression<String>? color,
    Expression<String>? icon,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (path != null) 'path': path,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? parentId,
    Value<String>? path,
    Value<int>? sortOrder,
    Value<String?>? color,
    Value<String?>? icon,
    Value<String>? description,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return LocalFoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      path: path ?? this.path,
      sortOrder: sortOrder ?? this.sortOrder,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('path: $path, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteFoldersTable extends NoteFolders
    with TableInfo<$NoteFoldersTable, NoteFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [noteId, folderId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {noteId};
  @override
  NoteFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteFolder(
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $NoteFoldersTable createAlias(String alias) {
    return $NoteFoldersTable(attachedDatabase, alias);
  }
}

class NoteFolder extends DataClass implements Insertable<NoteFolder> {
  /// Note ID (foreign key to local_notes)
  final String noteId;

  /// Folder ID (foreign key to local_folders)
  final String folderId;

  /// When the note was added to this folder
  final DateTime addedAt;
  const NoteFolder({
    required this.noteId,
    required this.folderId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id'] = Variable<String>(noteId);
    map['folder_id'] = Variable<String>(folderId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  NoteFoldersCompanion toCompanion(bool nullToAbsent) {
    return NoteFoldersCompanion(
      noteId: Value(noteId),
      folderId: Value(folderId),
      addedAt: Value(addedAt),
    );
  }

  factory NoteFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteFolder(
      noteId: serializer.fromJson<String>(json['noteId']),
      folderId: serializer.fromJson<String>(json['folderId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId': serializer.toJson<String>(noteId),
      'folderId': serializer.toJson<String>(folderId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  NoteFolder copyWith({String? noteId, String? folderId, DateTime? addedAt}) =>
      NoteFolder(
        noteId: noteId ?? this.noteId,
        folderId: folderId ?? this.folderId,
        addedAt: addedAt ?? this.addedAt,
      );
  NoteFolder copyWithCompanion(NoteFoldersCompanion data) {
    return NoteFolder(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteFolder(')
          ..write('noteId: $noteId, ')
          ..write('folderId: $folderId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(noteId, folderId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteFolder &&
          other.noteId == this.noteId &&
          other.folderId == this.folderId &&
          other.addedAt == this.addedAt);
}

class NoteFoldersCompanion extends UpdateCompanion<NoteFolder> {
  final Value<String> noteId;
  final Value<String> folderId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const NoteFoldersCompanion({
    this.noteId = const Value.absent(),
    this.folderId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteFoldersCompanion.insert({
    required String noteId,
    required String folderId,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : noteId = Value(noteId),
       folderId = Value(folderId),
       addedAt = Value(addedAt);
  static Insertable<NoteFolder> custom({
    Expression<String>? noteId,
    Expression<String>? folderId,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (noteId != null) 'note_id': noteId,
      if (folderId != null) 'folder_id': folderId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteFoldersCompanion copyWith({
    Value<String>? noteId,
    Value<String>? folderId,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return NoteFoldersCompanion(
      noteId: noteId ?? this.noteId,
      folderId: folderId ?? this.folderId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteFoldersCompanion(')
          ..write('noteId: $noteId, ')
          ..write('folderId: $folderId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedSearchesTable extends SavedSearches
    with TableInfo<$SavedSearchesTable, SavedSearch> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedSearchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchTypeMeta = const VerificationMeta(
    'searchType',
  );
  @override
  late final GeneratedColumn<String> searchType = GeneratedColumn<String>(
    'search_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _parametersMeta = const VerificationMeta(
    'parameters',
  );
  @override
  late final GeneratedColumn<String> parameters = GeneratedColumn<String>(
    'parameters',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usageCountMeta = const VerificationMeta(
    'usageCount',
  );
  @override
  late final GeneratedColumn<int> usageCount = GeneratedColumn<int>(
    'usage_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    query,
    searchType,
    parameters,
    sortOrder,
    color,
    icon,
    isPinned,
    createdAt,
    lastUsedAt,
    usageCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_searches';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedSearch> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('search_type')) {
      context.handle(
        _searchTypeMeta,
        searchType.isAcceptableOrUnknown(data['search_type']!, _searchTypeMeta),
      );
    }
    if (data.containsKey('parameters')) {
      context.handle(
        _parametersMeta,
        parameters.isAcceptableOrUnknown(data['parameters']!, _parametersMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    }
    if (data.containsKey('usage_count')) {
      context.handle(
        _usageCountMeta,
        usageCount.isAcceptableOrUnknown(data['usage_count']!, _usageCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedSearch map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedSearch(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      )!,
      searchType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_type'],
      )!,
      parameters: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parameters'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      ),
      usageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}usage_count'],
      )!,
    );
  }

  @override
  $SavedSearchesTable createAlias(String alias) {
    return $SavedSearchesTable(attachedDatabase, alias);
  }
}

class SavedSearch extends DataClass implements Insertable<SavedSearch> {
  /// Unique identifier for the saved search
  final String id;

  /// Display name for the search
  final String name;

  /// The search query/pattern
  final String query;

  /// Search type: 'text', 'tag', 'folder', 'date_range', 'compound'
  final String searchType;

  /// Optional parameters as JSON (e.g., date ranges, folder IDs, etc.)
  final String? parameters;

  /// Display order for the saved searches
  final int sortOrder;

  /// Optional color for display (hex format)
  final String? color;

  /// Optional icon name for display
  final String? icon;

  /// Whether this search is pinned/favorited
  final bool isPinned;

  /// Creation timestamp
  final DateTime createdAt;

  /// Last used timestamp
  final DateTime? lastUsedAt;

  /// Usage count for sorting by frequency
  final int usageCount;
  const SavedSearch({
    required this.id,
    required this.name,
    required this.query,
    required this.searchType,
    this.parameters,
    required this.sortOrder,
    this.color,
    this.icon,
    required this.isPinned,
    required this.createdAt,
    this.lastUsedAt,
    required this.usageCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['query'] = Variable<String>(query);
    map['search_type'] = Variable<String>(searchType);
    if (!nullToAbsent || parameters != null) {
      map['parameters'] = Variable<String>(parameters);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    }
    map['usage_count'] = Variable<int>(usageCount);
    return map;
  }

  SavedSearchesCompanion toCompanion(bool nullToAbsent) {
    return SavedSearchesCompanion(
      id: Value(id),
      name: Value(name),
      query: Value(query),
      searchType: Value(searchType),
      parameters: parameters == null && nullToAbsent
          ? const Value.absent()
          : Value(parameters),
      sortOrder: Value(sortOrder),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      isPinned: Value(isPinned),
      createdAt: Value(createdAt),
      lastUsedAt: lastUsedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAt),
      usageCount: Value(usageCount),
    );
  }

  factory SavedSearch.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedSearch(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      query: serializer.fromJson<String>(json['query']),
      searchType: serializer.fromJson<String>(json['searchType']),
      parameters: serializer.fromJson<String?>(json['parameters']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      color: serializer.fromJson<String?>(json['color']),
      icon: serializer.fromJson<String?>(json['icon']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUsedAt: serializer.fromJson<DateTime?>(json['lastUsedAt']),
      usageCount: serializer.fromJson<int>(json['usageCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'query': serializer.toJson<String>(query),
      'searchType': serializer.toJson<String>(searchType),
      'parameters': serializer.toJson<String?>(parameters),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'color': serializer.toJson<String?>(color),
      'icon': serializer.toJson<String?>(icon),
      'isPinned': serializer.toJson<bool>(isPinned),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
      'usageCount': serializer.toJson<int>(usageCount),
    };
  }

  SavedSearch copyWith({
    String? id,
    String? name,
    String? query,
    String? searchType,
    Value<String?> parameters = const Value.absent(),
    int? sortOrder,
    Value<String?> color = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    bool? isPinned,
    DateTime? createdAt,
    Value<DateTime?> lastUsedAt = const Value.absent(),
    int? usageCount,
  }) => SavedSearch(
    id: id ?? this.id,
    name: name ?? this.name,
    query: query ?? this.query,
    searchType: searchType ?? this.searchType,
    parameters: parameters.present ? parameters.value : this.parameters,
    sortOrder: sortOrder ?? this.sortOrder,
    color: color.present ? color.value : this.color,
    icon: icon.present ? icon.value : this.icon,
    isPinned: isPinned ?? this.isPinned,
    createdAt: createdAt ?? this.createdAt,
    lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
    usageCount: usageCount ?? this.usageCount,
  );
  SavedSearch copyWithCompanion(SavedSearchesCompanion data) {
    return SavedSearch(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      query: data.query.present ? data.query.value : this.query,
      searchType: data.searchType.present
          ? data.searchType.value
          : this.searchType,
      parameters: data.parameters.present
          ? data.parameters.value
          : this.parameters,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      color: data.color.present ? data.color.value : this.color,
      icon: data.icon.present ? data.icon.value : this.icon,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
      usageCount: data.usageCount.present
          ? data.usageCount.value
          : this.usageCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedSearch(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('query: $query, ')
          ..write('searchType: $searchType, ')
          ..write('parameters: $parameters, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('isPinned: $isPinned, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('usageCount: $usageCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    query,
    searchType,
    parameters,
    sortOrder,
    color,
    icon,
    isPinned,
    createdAt,
    lastUsedAt,
    usageCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedSearch &&
          other.id == this.id &&
          other.name == this.name &&
          other.query == this.query &&
          other.searchType == this.searchType &&
          other.parameters == this.parameters &&
          other.sortOrder == this.sortOrder &&
          other.color == this.color &&
          other.icon == this.icon &&
          other.isPinned == this.isPinned &&
          other.createdAt == this.createdAt &&
          other.lastUsedAt == this.lastUsedAt &&
          other.usageCount == this.usageCount);
}

class SavedSearchesCompanion extends UpdateCompanion<SavedSearch> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> query;
  final Value<String> searchType;
  final Value<String?> parameters;
  final Value<int> sortOrder;
  final Value<String?> color;
  final Value<String?> icon;
  final Value<bool> isPinned;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastUsedAt;
  final Value<int> usageCount;
  final Value<int> rowid;
  const SavedSearchesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.query = const Value.absent(),
    this.searchType = const Value.absent(),
    this.parameters = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.color = const Value.absent(),
    this.icon = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.usageCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedSearchesCompanion.insert({
    required String id,
    required String name,
    required String query,
    this.searchType = const Value.absent(),
    this.parameters = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.color = const Value.absent(),
    this.icon = const Value.absent(),
    this.isPinned = const Value.absent(),
    required DateTime createdAt,
    this.lastUsedAt = const Value.absent(),
    this.usageCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       query = Value(query),
       createdAt = Value(createdAt);
  static Insertable<SavedSearch> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? query,
    Expression<String>? searchType,
    Expression<String>? parameters,
    Expression<int>? sortOrder,
    Expression<String>? color,
    Expression<String>? icon,
    Expression<bool>? isPinned,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUsedAt,
    Expression<int>? usageCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (query != null) 'query': query,
      if (searchType != null) 'search_type': searchType,
      if (parameters != null) 'parameters': parameters,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
      if (isPinned != null) 'is_pinned': isPinned,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (usageCount != null) 'usage_count': usageCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedSearchesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? query,
    Value<String>? searchType,
    Value<String?>? parameters,
    Value<int>? sortOrder,
    Value<String?>? color,
    Value<String?>? icon,
    Value<bool>? isPinned,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastUsedAt,
    Value<int>? usageCount,
    Value<int>? rowid,
  }) {
    return SavedSearchesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      query: query ?? this.query,
      searchType: searchType ?? this.searchType,
      parameters: parameters ?? this.parameters,
      sortOrder: sortOrder ?? this.sortOrder,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      usageCount: usageCount ?? this.usageCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (searchType.present) {
      map['search_type'] = Variable<String>(searchType.value);
    }
    if (parameters.present) {
      map['parameters'] = Variable<String>(parameters.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (usageCount.present) {
      map['usage_count'] = Variable<int>(usageCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedSearchesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('query: $query, ')
          ..write('searchType: $searchType, ')
          ..write('parameters: $parameters, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('isPinned: $isPinned, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('usageCount: $usageCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $LocalNotesTable localNotes = $LocalNotesTable(this);
  late final $PendingOpsTable pendingOps = $PendingOpsTable(this);
  late final $NoteTagsTable noteTags = $NoteTagsTable(this);
  late final $NoteLinksTable noteLinks = $NoteLinksTable(this);
  late final $NoteRemindersTable noteReminders = $NoteRemindersTable(this);
  late final $LocalFoldersTable localFolders = $LocalFoldersTable(this);
  late final $NoteFoldersTable noteFolders = $NoteFoldersTable(this);
  late final $SavedSearchesTable savedSearches = $SavedSearchesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localNotes,
    pendingOps,
    noteTags,
    noteLinks,
    noteReminders,
    localFolders,
    noteFolders,
    savedSearches,
  ];
}

typedef $$LocalNotesTableCreateCompanionBuilder =
    LocalNotesCompanion Function({
      required String id,
      Value<String> title,
      Value<String> body,
      required DateTime updatedAt,
      Value<bool> deleted,
      Value<String?> encryptedMetadata,
      Value<bool> isPinned,
      Value<int> rowid,
    });
typedef $$LocalNotesTableUpdateCompanionBuilder =
    LocalNotesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> body,
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<String?> encryptedMetadata,
      Value<bool> isPinned,
      Value<int> rowid,
    });

class $$LocalNotesTableFilterComposer
    extends Composer<_$AppDb, $LocalNotesTable> {
  $$LocalNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedMetadata => $composableBuilder(
    column: $table.encryptedMetadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalNotesTableOrderingComposer
    extends Composer<_$AppDb, $LocalNotesTable> {
  $$LocalNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedMetadata => $composableBuilder(
    column: $table.encryptedMetadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalNotesTableAnnotationComposer
    extends Composer<_$AppDb, $LocalNotesTable> {
  $$LocalNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get encryptedMetadata => $composableBuilder(
    column: $table.encryptedMetadata,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);
}

class $$LocalNotesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $LocalNotesTable,
          LocalNote,
          $$LocalNotesTableFilterComposer,
          $$LocalNotesTableOrderingComposer,
          $$LocalNotesTableAnnotationComposer,
          $$LocalNotesTableCreateCompanionBuilder,
          $$LocalNotesTableUpdateCompanionBuilder,
          (LocalNote, BaseReferences<_$AppDb, $LocalNotesTable, LocalNote>),
          LocalNote,
          PrefetchHooks Function()
        > {
  $$LocalNotesTableTableManager(_$AppDb db, $LocalNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String?> encryptedMetadata = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalNotesCompanion(
                id: id,
                title: title,
                body: body,
                updatedAt: updatedAt,
                deleted: deleted,
                encryptedMetadata: encryptedMetadata,
                isPinned: isPinned,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<String?> encryptedMetadata = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalNotesCompanion.insert(
                id: id,
                title: title,
                body: body,
                updatedAt: updatedAt,
                deleted: deleted,
                encryptedMetadata: encryptedMetadata,
                isPinned: isPinned,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $LocalNotesTable,
      LocalNote,
      $$LocalNotesTableFilterComposer,
      $$LocalNotesTableOrderingComposer,
      $$LocalNotesTableAnnotationComposer,
      $$LocalNotesTableCreateCompanionBuilder,
      $$LocalNotesTableUpdateCompanionBuilder,
      (LocalNote, BaseReferences<_$AppDb, $LocalNotesTable, LocalNote>),
      LocalNote,
      PrefetchHooks Function()
    >;
typedef $$PendingOpsTableCreateCompanionBuilder =
    PendingOpsCompanion Function({
      Value<int> id,
      required String entityId,
      required String kind,
      Value<String?> payload,
      Value<DateTime> createdAt,
    });
typedef $$PendingOpsTableUpdateCompanionBuilder =
    PendingOpsCompanion Function({
      Value<int> id,
      Value<String> entityId,
      Value<String> kind,
      Value<String?> payload,
      Value<DateTime> createdAt,
    });

class $$PendingOpsTableFilterComposer
    extends Composer<_$AppDb, $PendingOpsTable> {
  $$PendingOpsTableFilterComposer({
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

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingOpsTableOrderingComposer
    extends Composer<_$AppDb, $PendingOpsTable> {
  $$PendingOpsTableOrderingComposer({
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

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingOpsTableAnnotationComposer
    extends Composer<_$AppDb, $PendingOpsTable> {
  $$PendingOpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingOpsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $PendingOpsTable,
          PendingOp,
          $$PendingOpsTableFilterComposer,
          $$PendingOpsTableOrderingComposer,
          $$PendingOpsTableAnnotationComposer,
          $$PendingOpsTableCreateCompanionBuilder,
          $$PendingOpsTableUpdateCompanionBuilder,
          (PendingOp, BaseReferences<_$AppDb, $PendingOpsTable, PendingOp>),
          PendingOp,
          PrefetchHooks Function()
        > {
  $$PendingOpsTableTableManager(_$AppDb db, $PendingOpsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingOpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingOpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingOpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PendingOpsCompanion(
                id: id,
                entityId: entityId,
                kind: kind,
                payload: payload,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entityId,
                required String kind,
                Value<String?> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PendingOpsCompanion.insert(
                id: id,
                entityId: entityId,
                kind: kind,
                payload: payload,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingOpsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $PendingOpsTable,
      PendingOp,
      $$PendingOpsTableFilterComposer,
      $$PendingOpsTableOrderingComposer,
      $$PendingOpsTableAnnotationComposer,
      $$PendingOpsTableCreateCompanionBuilder,
      $$PendingOpsTableUpdateCompanionBuilder,
      (PendingOp, BaseReferences<_$AppDb, $PendingOpsTable, PendingOp>),
      PendingOp,
      PrefetchHooks Function()
    >;
typedef $$NoteTagsTableCreateCompanionBuilder =
    NoteTagsCompanion Function({
      required String noteId,
      required String tag,
      Value<int> rowid,
    });
typedef $$NoteTagsTableUpdateCompanionBuilder =
    NoteTagsCompanion Function({
      Value<String> noteId,
      Value<String> tag,
      Value<int> rowid,
    });

class $$NoteTagsTableFilterComposer extends Composer<_$AppDb, $NoteTagsTable> {
  $$NoteTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteTagsTableOrderingComposer
    extends Composer<_$AppDb, $NoteTagsTable> {
  $$NoteTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteTagsTableAnnotationComposer
    extends Composer<_$AppDb, $NoteTagsTable> {
  $$NoteTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);
}

class $$NoteTagsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $NoteTagsTable,
          NoteTag,
          $$NoteTagsTableFilterComposer,
          $$NoteTagsTableOrderingComposer,
          $$NoteTagsTableAnnotationComposer,
          $$NoteTagsTableCreateCompanionBuilder,
          $$NoteTagsTableUpdateCompanionBuilder,
          (NoteTag, BaseReferences<_$AppDb, $NoteTagsTable, NoteTag>),
          NoteTag,
          PrefetchHooks Function()
        > {
  $$NoteTagsTableTableManager(_$AppDb db, $NoteTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> noteId = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteTagsCompanion(noteId: noteId, tag: tag, rowid: rowid),
          createCompanionCallback:
              ({
                required String noteId,
                required String tag,
                Value<int> rowid = const Value.absent(),
              }) => NoteTagsCompanion.insert(
                noteId: noteId,
                tag: tag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoteTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $NoteTagsTable,
      NoteTag,
      $$NoteTagsTableFilterComposer,
      $$NoteTagsTableOrderingComposer,
      $$NoteTagsTableAnnotationComposer,
      $$NoteTagsTableCreateCompanionBuilder,
      $$NoteTagsTableUpdateCompanionBuilder,
      (NoteTag, BaseReferences<_$AppDb, $NoteTagsTable, NoteTag>),
      NoteTag,
      PrefetchHooks Function()
    >;
typedef $$NoteLinksTableCreateCompanionBuilder =
    NoteLinksCompanion Function({
      required String sourceId,
      required String targetTitle,
      Value<String?> targetId,
      Value<int> rowid,
    });
typedef $$NoteLinksTableUpdateCompanionBuilder =
    NoteLinksCompanion Function({
      Value<String> sourceId,
      Value<String> targetTitle,
      Value<String?> targetId,
      Value<int> rowid,
    });

class $$NoteLinksTableFilterComposer
    extends Composer<_$AppDb, $NoteLinksTable> {
  $$NoteLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetTitle => $composableBuilder(
    column: $table.targetTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteLinksTableOrderingComposer
    extends Composer<_$AppDb, $NoteLinksTable> {
  $$NoteLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetTitle => $composableBuilder(
    column: $table.targetTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteLinksTableAnnotationComposer
    extends Composer<_$AppDb, $NoteLinksTable> {
  $$NoteLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get targetTitle => $composableBuilder(
    column: $table.targetTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);
}

class $$NoteLinksTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $NoteLinksTable,
          NoteLink,
          $$NoteLinksTableFilterComposer,
          $$NoteLinksTableOrderingComposer,
          $$NoteLinksTableAnnotationComposer,
          $$NoteLinksTableCreateCompanionBuilder,
          $$NoteLinksTableUpdateCompanionBuilder,
          (NoteLink, BaseReferences<_$AppDb, $NoteLinksTable, NoteLink>),
          NoteLink,
          PrefetchHooks Function()
        > {
  $$NoteLinksTableTableManager(_$AppDb db, $NoteLinksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<String> targetTitle = const Value.absent(),
                Value<String?> targetId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteLinksCompanion(
                sourceId: sourceId,
                targetTitle: targetTitle,
                targetId: targetId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required String targetTitle,
                Value<String?> targetId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteLinksCompanion.insert(
                sourceId: sourceId,
                targetTitle: targetTitle,
                targetId: targetId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoteLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $NoteLinksTable,
      NoteLink,
      $$NoteLinksTableFilterComposer,
      $$NoteLinksTableOrderingComposer,
      $$NoteLinksTableAnnotationComposer,
      $$NoteLinksTableCreateCompanionBuilder,
      $$NoteLinksTableUpdateCompanionBuilder,
      (NoteLink, BaseReferences<_$AppDb, $NoteLinksTable, NoteLink>),
      NoteLink,
      PrefetchHooks Function()
    >;
typedef $$NoteRemindersTableCreateCompanionBuilder =
    NoteRemindersCompanion Function({
      Value<int> id,
      required String noteId,
      Value<String> title,
      Value<String> body,
      required ReminderType type,
      Value<DateTime?> remindAt,
      Value<bool> isActive,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<double?> radius,
      Value<String?> locationName,
      Value<RecurrencePattern> recurrencePattern,
      Value<DateTime?> recurrenceEndDate,
      Value<int> recurrenceInterval,
      Value<DateTime?> snoozedUntil,
      Value<int> snoozeCount,
      Value<String?> notificationTitle,
      Value<String?> notificationBody,
      Value<String?> notificationImage,
      Value<String?> timeZone,
      Value<DateTime> createdAt,
      Value<DateTime?> lastTriggered,
      Value<int> triggerCount,
    });
typedef $$NoteRemindersTableUpdateCompanionBuilder =
    NoteRemindersCompanion Function({
      Value<int> id,
      Value<String> noteId,
      Value<String> title,
      Value<String> body,
      Value<ReminderType> type,
      Value<DateTime?> remindAt,
      Value<bool> isActive,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<double?> radius,
      Value<String?> locationName,
      Value<RecurrencePattern> recurrencePattern,
      Value<DateTime?> recurrenceEndDate,
      Value<int> recurrenceInterval,
      Value<DateTime?> snoozedUntil,
      Value<int> snoozeCount,
      Value<String?> notificationTitle,
      Value<String?> notificationBody,
      Value<String?> notificationImage,
      Value<String?> timeZone,
      Value<DateTime> createdAt,
      Value<DateTime?> lastTriggered,
      Value<int> triggerCount,
    });

class $$NoteRemindersTableFilterComposer
    extends Composer<_$AppDb, $NoteRemindersTable> {
  $$NoteRemindersTableFilterComposer({
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

  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ReminderType, ReminderType, int> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get radius => $composableBuilder(
    column: $table.radius,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationName => $composableBuilder(
    column: $table.locationName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RecurrencePattern, RecurrencePattern, int>
  get recurrencePattern => $composableBuilder(
    column: $table.recurrencePattern,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get recurrenceEndDate => $composableBuilder(
    column: $table.recurrenceEndDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recurrenceInterval => $composableBuilder(
    column: $table.recurrenceInterval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozeCount => $composableBuilder(
    column: $table.snoozeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notificationTitle => $composableBuilder(
    column: $table.notificationTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notificationBody => $composableBuilder(
    column: $table.notificationBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notificationImage => $composableBuilder(
    column: $table.notificationImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastTriggered => $composableBuilder(
    column: $table.lastTriggered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get triggerCount => $composableBuilder(
    column: $table.triggerCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteRemindersTableOrderingComposer
    extends Composer<_$AppDb, $NoteRemindersTable> {
  $$NoteRemindersTableOrderingComposer({
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

  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get radius => $composableBuilder(
    column: $table.radius,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationName => $composableBuilder(
    column: $table.locationName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recurrencePattern => $composableBuilder(
    column: $table.recurrencePattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recurrenceEndDate => $composableBuilder(
    column: $table.recurrenceEndDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recurrenceInterval => $composableBuilder(
    column: $table.recurrenceInterval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozeCount => $composableBuilder(
    column: $table.snoozeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notificationTitle => $composableBuilder(
    column: $table.notificationTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notificationBody => $composableBuilder(
    column: $table.notificationBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notificationImage => $composableBuilder(
    column: $table.notificationImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastTriggered => $composableBuilder(
    column: $table.lastTriggered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get triggerCount => $composableBuilder(
    column: $table.triggerCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteRemindersTableAnnotationComposer
    extends Composer<_$AppDb, $NoteRemindersTable> {
  $$NoteRemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReminderType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get remindAt =>
      $composableBuilder(column: $table.remindAt, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get radius =>
      $composableBuilder(column: $table.radius, builder: (column) => column);

  GeneratedColumn<String> get locationName => $composableBuilder(
    column: $table.locationName,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<RecurrencePattern, int>
  get recurrencePattern => $composableBuilder(
    column: $table.recurrencePattern,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get recurrenceEndDate => $composableBuilder(
    column: $table.recurrenceEndDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get recurrenceInterval => $composableBuilder(
    column: $table.recurrenceInterval,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snoozeCount => $composableBuilder(
    column: $table.snoozeCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notificationTitle => $composableBuilder(
    column: $table.notificationTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notificationBody => $composableBuilder(
    column: $table.notificationBody,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notificationImage => $composableBuilder(
    column: $table.notificationImage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timeZone =>
      $composableBuilder(column: $table.timeZone, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastTriggered => $composableBuilder(
    column: $table.lastTriggered,
    builder: (column) => column,
  );

  GeneratedColumn<int> get triggerCount => $composableBuilder(
    column: $table.triggerCount,
    builder: (column) => column,
  );
}

class $$NoteRemindersTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $NoteRemindersTable,
          NoteReminder,
          $$NoteRemindersTableFilterComposer,
          $$NoteRemindersTableOrderingComposer,
          $$NoteRemindersTableAnnotationComposer,
          $$NoteRemindersTableCreateCompanionBuilder,
          $$NoteRemindersTableUpdateCompanionBuilder,
          (
            NoteReminder,
            BaseReferences<_$AppDb, $NoteRemindersTable, NoteReminder>,
          ),
          NoteReminder,
          PrefetchHooks Function()
        > {
  $$NoteRemindersTableTableManager(_$AppDb db, $NoteRemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteRemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteRemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteRemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<ReminderType> type = const Value.absent(),
                Value<DateTime?> remindAt = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<double?> radius = const Value.absent(),
                Value<String?> locationName = const Value.absent(),
                Value<RecurrencePattern> recurrencePattern =
                    const Value.absent(),
                Value<DateTime?> recurrenceEndDate = const Value.absent(),
                Value<int> recurrenceInterval = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<int> snoozeCount = const Value.absent(),
                Value<String?> notificationTitle = const Value.absent(),
                Value<String?> notificationBody = const Value.absent(),
                Value<String?> notificationImage = const Value.absent(),
                Value<String?> timeZone = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastTriggered = const Value.absent(),
                Value<int> triggerCount = const Value.absent(),
              }) => NoteRemindersCompanion(
                id: id,
                noteId: noteId,
                title: title,
                body: body,
                type: type,
                remindAt: remindAt,
                isActive: isActive,
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                locationName: locationName,
                recurrencePattern: recurrencePattern,
                recurrenceEndDate: recurrenceEndDate,
                recurrenceInterval: recurrenceInterval,
                snoozedUntil: snoozedUntil,
                snoozeCount: snoozeCount,
                notificationTitle: notificationTitle,
                notificationBody: notificationBody,
                notificationImage: notificationImage,
                timeZone: timeZone,
                createdAt: createdAt,
                lastTriggered: lastTriggered,
                triggerCount: triggerCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String noteId,
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                required ReminderType type,
                Value<DateTime?> remindAt = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<double?> radius = const Value.absent(),
                Value<String?> locationName = const Value.absent(),
                Value<RecurrencePattern> recurrencePattern =
                    const Value.absent(),
                Value<DateTime?> recurrenceEndDate = const Value.absent(),
                Value<int> recurrenceInterval = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<int> snoozeCount = const Value.absent(),
                Value<String?> notificationTitle = const Value.absent(),
                Value<String?> notificationBody = const Value.absent(),
                Value<String?> notificationImage = const Value.absent(),
                Value<String?> timeZone = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastTriggered = const Value.absent(),
                Value<int> triggerCount = const Value.absent(),
              }) => NoteRemindersCompanion.insert(
                id: id,
                noteId: noteId,
                title: title,
                body: body,
                type: type,
                remindAt: remindAt,
                isActive: isActive,
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                locationName: locationName,
                recurrencePattern: recurrencePattern,
                recurrenceEndDate: recurrenceEndDate,
                recurrenceInterval: recurrenceInterval,
                snoozedUntil: snoozedUntil,
                snoozeCount: snoozeCount,
                notificationTitle: notificationTitle,
                notificationBody: notificationBody,
                notificationImage: notificationImage,
                timeZone: timeZone,
                createdAt: createdAt,
                lastTriggered: lastTriggered,
                triggerCount: triggerCount,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoteRemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $NoteRemindersTable,
      NoteReminder,
      $$NoteRemindersTableFilterComposer,
      $$NoteRemindersTableOrderingComposer,
      $$NoteRemindersTableAnnotationComposer,
      $$NoteRemindersTableCreateCompanionBuilder,
      $$NoteRemindersTableUpdateCompanionBuilder,
      (
        NoteReminder,
        BaseReferences<_$AppDb, $NoteRemindersTable, NoteReminder>,
      ),
      NoteReminder,
      PrefetchHooks Function()
    >;
typedef $$LocalFoldersTableCreateCompanionBuilder =
    LocalFoldersCompanion Function({
      required String id,
      required String name,
      Value<String?> parentId,
      required String path,
      Value<int> sortOrder,
      Value<String?> color,
      Value<String?> icon,
      Value<String> description,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$LocalFoldersTableUpdateCompanionBuilder =
    LocalFoldersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> parentId,
      Value<String> path,
      Value<int> sortOrder,
      Value<String?> color,
      Value<String?> icon,
      Value<String> description,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<int> rowid,
    });

class $$LocalFoldersTableFilterComposer
    extends Composer<_$AppDb, $LocalFoldersTable> {
  $$LocalFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalFoldersTableOrderingComposer
    extends Composer<_$AppDb, $LocalFoldersTable> {
  $$LocalFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalFoldersTableAnnotationComposer
    extends Composer<_$AppDb, $LocalFoldersTable> {
  $$LocalFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$LocalFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $LocalFoldersTable,
          LocalFolder,
          $$LocalFoldersTableFilterComposer,
          $$LocalFoldersTableOrderingComposer,
          $$LocalFoldersTableAnnotationComposer,
          $$LocalFoldersTableCreateCompanionBuilder,
          $$LocalFoldersTableUpdateCompanionBuilder,
          (
            LocalFolder,
            BaseReferences<_$AppDb, $LocalFoldersTable, LocalFolder>,
          ),
          LocalFolder,
          PrefetchHooks Function()
        > {
  $$LocalFoldersTableTableManager(_$AppDb db, $LocalFoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFoldersCompanion(
                id: id,
                name: name,
                parentId: parentId,
                path: path,
                sortOrder: sortOrder,
                color: color,
                icon: icon,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> parentId = const Value.absent(),
                required String path,
                Value<int> sortOrder = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String> description = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFoldersCompanion.insert(
                id: id,
                name: name,
                parentId: parentId,
                path: path,
                sortOrder: sortOrder,
                color: color,
                icon: icon,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $LocalFoldersTable,
      LocalFolder,
      $$LocalFoldersTableFilterComposer,
      $$LocalFoldersTableOrderingComposer,
      $$LocalFoldersTableAnnotationComposer,
      $$LocalFoldersTableCreateCompanionBuilder,
      $$LocalFoldersTableUpdateCompanionBuilder,
      (LocalFolder, BaseReferences<_$AppDb, $LocalFoldersTable, LocalFolder>),
      LocalFolder,
      PrefetchHooks Function()
    >;
typedef $$NoteFoldersTableCreateCompanionBuilder =
    NoteFoldersCompanion Function({
      required String noteId,
      required String folderId,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$NoteFoldersTableUpdateCompanionBuilder =
    NoteFoldersCompanion Function({
      Value<String> noteId,
      Value<String> folderId,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$NoteFoldersTableFilterComposer
    extends Composer<_$AppDb, $NoteFoldersTable> {
  $$NoteFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteFoldersTableOrderingComposer
    extends Composer<_$AppDb, $NoteFoldersTable> {
  $$NoteFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteFoldersTableAnnotationComposer
    extends Composer<_$AppDb, $NoteFoldersTable> {
  $$NoteFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$NoteFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $NoteFoldersTable,
          NoteFolder,
          $$NoteFoldersTableFilterComposer,
          $$NoteFoldersTableOrderingComposer,
          $$NoteFoldersTableAnnotationComposer,
          $$NoteFoldersTableCreateCompanionBuilder,
          $$NoteFoldersTableUpdateCompanionBuilder,
          (NoteFolder, BaseReferences<_$AppDb, $NoteFoldersTable, NoteFolder>),
          NoteFolder,
          PrefetchHooks Function()
        > {
  $$NoteFoldersTableTableManager(_$AppDb db, $NoteFoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> noteId = const Value.absent(),
                Value<String> folderId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteFoldersCompanion(
                noteId: noteId,
                folderId: folderId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String noteId,
                required String folderId,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => NoteFoldersCompanion.insert(
                noteId: noteId,
                folderId: folderId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoteFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $NoteFoldersTable,
      NoteFolder,
      $$NoteFoldersTableFilterComposer,
      $$NoteFoldersTableOrderingComposer,
      $$NoteFoldersTableAnnotationComposer,
      $$NoteFoldersTableCreateCompanionBuilder,
      $$NoteFoldersTableUpdateCompanionBuilder,
      (NoteFolder, BaseReferences<_$AppDb, $NoteFoldersTable, NoteFolder>),
      NoteFolder,
      PrefetchHooks Function()
    >;
typedef $$SavedSearchesTableCreateCompanionBuilder =
    SavedSearchesCompanion Function({
      required String id,
      required String name,
      required String query,
      Value<String> searchType,
      Value<String?> parameters,
      Value<int> sortOrder,
      Value<String?> color,
      Value<String?> icon,
      Value<bool> isPinned,
      required DateTime createdAt,
      Value<DateTime?> lastUsedAt,
      Value<int> usageCount,
      Value<int> rowid,
    });
typedef $$SavedSearchesTableUpdateCompanionBuilder =
    SavedSearchesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> query,
      Value<String> searchType,
      Value<String?> parameters,
      Value<int> sortOrder,
      Value<String?> color,
      Value<String?> icon,
      Value<bool> isPinned,
      Value<DateTime> createdAt,
      Value<DateTime?> lastUsedAt,
      Value<int> usageCount,
      Value<int> rowid,
    });

class $$SavedSearchesTableFilterComposer
    extends Composer<_$AppDb, $SavedSearchesTable> {
  $$SavedSearchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchType => $composableBuilder(
    column: $table.searchType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parameters => $composableBuilder(
    column: $table.parameters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usageCount => $composableBuilder(
    column: $table.usageCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedSearchesTableOrderingComposer
    extends Composer<_$AppDb, $SavedSearchesTable> {
  $$SavedSearchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchType => $composableBuilder(
    column: $table.searchType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parameters => $composableBuilder(
    column: $table.parameters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usageCount => $composableBuilder(
    column: $table.usageCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedSearchesTableAnnotationComposer
    extends Composer<_$AppDb, $SavedSearchesTable> {
  $$SavedSearchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<String> get searchType => $composableBuilder(
    column: $table.searchType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parameters => $composableBuilder(
    column: $table.parameters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get usageCount => $composableBuilder(
    column: $table.usageCount,
    builder: (column) => column,
  );
}

class $$SavedSearchesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SavedSearchesTable,
          SavedSearch,
          $$SavedSearchesTableFilterComposer,
          $$SavedSearchesTableOrderingComposer,
          $$SavedSearchesTableAnnotationComposer,
          $$SavedSearchesTableCreateCompanionBuilder,
          $$SavedSearchesTableUpdateCompanionBuilder,
          (
            SavedSearch,
            BaseReferences<_$AppDb, $SavedSearchesTable, SavedSearch>,
          ),
          SavedSearch,
          PrefetchHooks Function()
        > {
  $$SavedSearchesTableTableManager(_$AppDb db, $SavedSearchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedSearchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedSearchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedSearchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> query = const Value.absent(),
                Value<String> searchType = const Value.absent(),
                Value<String?> parameters = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<int> usageCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedSearchesCompanion(
                id: id,
                name: name,
                query: query,
                searchType: searchType,
                parameters: parameters,
                sortOrder: sortOrder,
                color: color,
                icon: icon,
                isPinned: isPinned,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                usageCount: usageCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String query,
                Value<String> searchType = const Value.absent(),
                Value<String?> parameters = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<int> usageCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedSearchesCompanion.insert(
                id: id,
                name: name,
                query: query,
                searchType: searchType,
                parameters: parameters,
                sortOrder: sortOrder,
                color: color,
                icon: icon,
                isPinned: isPinned,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                usageCount: usageCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedSearchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SavedSearchesTable,
      SavedSearch,
      $$SavedSearchesTableFilterComposer,
      $$SavedSearchesTableOrderingComposer,
      $$SavedSearchesTableAnnotationComposer,
      $$SavedSearchesTableCreateCompanionBuilder,
      $$SavedSearchesTableUpdateCompanionBuilder,
      (SavedSearch, BaseReferences<_$AppDb, $SavedSearchesTable, SavedSearch>),
      SavedSearch,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$LocalNotesTableTableManager get localNotes =>
      $$LocalNotesTableTableManager(_db, _db.localNotes);
  $$PendingOpsTableTableManager get pendingOps =>
      $$PendingOpsTableTableManager(_db, _db.pendingOps);
  $$NoteTagsTableTableManager get noteTags =>
      $$NoteTagsTableTableManager(_db, _db.noteTags);
  $$NoteLinksTableTableManager get noteLinks =>
      $$NoteLinksTableTableManager(_db, _db.noteLinks);
  $$NoteRemindersTableTableManager get noteReminders =>
      $$NoteRemindersTableTableManager(_db, _db.noteReminders);
  $$LocalFoldersTableTableManager get localFolders =>
      $$LocalFoldersTableTableManager(_db, _db.localFolders);
  $$NoteFoldersTableTableManager get noteFolders =>
      $$NoteFoldersTableTableManager(_db, _db.noteFolders);
  $$SavedSearchesTableTableManager get savedSearches =>
      $$SavedSearchesTableTableManager(_db, _db.savedSearches);
}
