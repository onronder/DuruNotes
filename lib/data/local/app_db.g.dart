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
  static const VerificationMeta _titleEncryptedMeta = const VerificationMeta(
    'titleEncrypted',
  );
  @override
  late final GeneratedColumn<String> titleEncrypted = GeneratedColumn<String>(
    'title_encrypted',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bodyEncryptedMeta = const VerificationMeta(
    'bodyEncrypted',
  );
  @override
  late final GeneratedColumn<String> bodyEncrypted = GeneratedColumn<String>(
    'body_encrypted',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _metadataEncryptedMeta = const VerificationMeta(
    'metadataEncrypted',
  );
  @override
  late final GeneratedColumn<String> metadataEncrypted =
      GeneratedColumn<String>(
        'metadata_encrypted',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _encryptionVersionMeta = const VerificationMeta(
    'encryptionVersion',
  );
  @override
  late final GeneratedColumn<int> encryptionVersion = GeneratedColumn<int>(
    'encryption_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledPurgeAtMeta = const VerificationMeta(
    'scheduledPurgeAt',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledPurgeAt =
      GeneratedColumn<DateTime>(
        'scheduled_purge_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
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
  late final GeneratedColumnWithTypeConverter<NoteKind, int> noteType =
      GeneratedColumn<int>(
        'note_type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<NoteKind>($LocalNotesTable.$converternoteType);
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentMetaMeta = const VerificationMeta(
    'attachmentMeta',
  );
  @override
  late final GeneratedColumn<String> attachmentMeta = GeneratedColumn<String>(
    'attachment_meta',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    titleEncrypted,
    bodyEncrypted,
    metadataEncrypted,
    encryptionVersion,
    createdAt,
    updatedAt,
    deleted,
    deletedAt,
    scheduledPurgeAt,
    encryptedMetadata,
    isPinned,
    noteType,
    version,
    userId,
    attachmentMeta,
    metadata,
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
    if (data.containsKey('title_encrypted')) {
      context.handle(
        _titleEncryptedMeta,
        titleEncrypted.isAcceptableOrUnknown(
          data['title_encrypted']!,
          _titleEncryptedMeta,
        ),
      );
    }
    if (data.containsKey('body_encrypted')) {
      context.handle(
        _bodyEncryptedMeta,
        bodyEncrypted.isAcceptableOrUnknown(
          data['body_encrypted']!,
          _bodyEncryptedMeta,
        ),
      );
    }
    if (data.containsKey('metadata_encrypted')) {
      context.handle(
        _metadataEncryptedMeta,
        metadataEncrypted.isAcceptableOrUnknown(
          data['metadata_encrypted']!,
          _metadataEncryptedMeta,
        ),
      );
    }
    if (data.containsKey('encryption_version')) {
      context.handle(
        _encryptionVersionMeta,
        encryptionVersion.isAcceptableOrUnknown(
          data['encryption_version']!,
          _encryptionVersionMeta,
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('scheduled_purge_at')) {
      context.handle(
        _scheduledPurgeAtMeta,
        scheduledPurgeAt.isAcceptableOrUnknown(
          data['scheduled_purge_at']!,
          _scheduledPurgeAtMeta,
        ),
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
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('attachment_meta')) {
      context.handle(
        _attachmentMetaMeta,
        attachmentMeta.isAcceptableOrUnknown(
          data['attachment_meta']!,
          _attachmentMetaMeta,
        ),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
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
      titleEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_encrypted'],
      )!,
      bodyEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_encrypted'],
      )!,
      metadataEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_encrypted'],
      ),
      encryptionVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}encryption_version'],
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
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      scheduledPurgeAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_purge_at'],
      ),
      encryptedMetadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_metadata'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      noteType: $LocalNotesTable.$converternoteType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}note_type'],
        )!,
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      attachmentMeta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_meta'],
      ),
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      ),
    );
  }

  @override
  $LocalNotesTable createAlias(String alias) {
    return $LocalNotesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<NoteKind, int, int> $converternoteType =
      const EnumIndexConverter<NoteKind>(NoteKind.values);
}

class LocalNote extends DataClass implements Insertable<LocalNote> {
  final String id;
  final String titleEncrypted;
  final String bodyEncrypted;
  final String? metadataEncrypted;
  final int encryptionVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;
  final DateTime? deletedAt;
  final DateTime? scheduledPurgeAt;
  final String? encryptedMetadata;
  final bool isPinned;
  final NoteKind noteType;
  final int version;
  final String? userId;
  final String? attachmentMeta;
  final String? metadata;
  const LocalNote({
    required this.id,
    required this.titleEncrypted,
    required this.bodyEncrypted,
    this.metadataEncrypted,
    required this.encryptionVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    this.deletedAt,
    this.scheduledPurgeAt,
    this.encryptedMetadata,
    required this.isPinned,
    required this.noteType,
    required this.version,
    this.userId,
    this.attachmentMeta,
    this.metadata,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title_encrypted'] = Variable<String>(titleEncrypted);
    map['body_encrypted'] = Variable<String>(bodyEncrypted);
    if (!nullToAbsent || metadataEncrypted != null) {
      map['metadata_encrypted'] = Variable<String>(metadataEncrypted);
    }
    map['encryption_version'] = Variable<int>(encryptionVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || scheduledPurgeAt != null) {
      map['scheduled_purge_at'] = Variable<DateTime>(scheduledPurgeAt);
    }
    if (!nullToAbsent || encryptedMetadata != null) {
      map['encrypted_metadata'] = Variable<String>(encryptedMetadata);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    {
      map['note_type'] = Variable<int>(
        $LocalNotesTable.$converternoteType.toSql(noteType),
      );
    }
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || attachmentMeta != null) {
      map['attachment_meta'] = Variable<String>(attachmentMeta);
    }
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    return map;
  }

  LocalNotesCompanion toCompanion(bool nullToAbsent) {
    return LocalNotesCompanion(
      id: Value(id),
      titleEncrypted: Value(titleEncrypted),
      bodyEncrypted: Value(bodyEncrypted),
      metadataEncrypted: metadataEncrypted == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataEncrypted),
      encryptionVersion: Value(encryptionVersion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      scheduledPurgeAt: scheduledPurgeAt == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledPurgeAt),
      encryptedMetadata: encryptedMetadata == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedMetadata),
      isPinned: Value(isPinned),
      noteType: Value(noteType),
      version: Value(version),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      attachmentMeta: attachmentMeta == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentMeta),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
    );
  }

  factory LocalNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalNote(
      id: serializer.fromJson<String>(json['id']),
      titleEncrypted: serializer.fromJson<String>(json['titleEncrypted']),
      bodyEncrypted: serializer.fromJson<String>(json['bodyEncrypted']),
      metadataEncrypted: serializer.fromJson<String?>(
        json['metadataEncrypted'],
      ),
      encryptionVersion: serializer.fromJson<int>(json['encryptionVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      scheduledPurgeAt: serializer.fromJson<DateTime?>(
        json['scheduledPurgeAt'],
      ),
      encryptedMetadata: serializer.fromJson<String?>(
        json['encryptedMetadata'],
      ),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      noteType: $LocalNotesTable.$converternoteType.fromJson(
        serializer.fromJson<int>(json['noteType']),
      ),
      version: serializer.fromJson<int>(json['version']),
      userId: serializer.fromJson<String?>(json['userId']),
      attachmentMeta: serializer.fromJson<String?>(json['attachmentMeta']),
      metadata: serializer.fromJson<String?>(json['metadata']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'titleEncrypted': serializer.toJson<String>(titleEncrypted),
      'bodyEncrypted': serializer.toJson<String>(bodyEncrypted),
      'metadataEncrypted': serializer.toJson<String?>(metadataEncrypted),
      'encryptionVersion': serializer.toJson<int>(encryptionVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'scheduledPurgeAt': serializer.toJson<DateTime?>(scheduledPurgeAt),
      'encryptedMetadata': serializer.toJson<String?>(encryptedMetadata),
      'isPinned': serializer.toJson<bool>(isPinned),
      'noteType': serializer.toJson<int>(
        $LocalNotesTable.$converternoteType.toJson(noteType),
      ),
      'version': serializer.toJson<int>(version),
      'userId': serializer.toJson<String?>(userId),
      'attachmentMeta': serializer.toJson<String?>(attachmentMeta),
      'metadata': serializer.toJson<String?>(metadata),
    };
  }

  LocalNote copyWith({
    String? id,
    String? titleEncrypted,
    String? bodyEncrypted,
    Value<String?> metadataEncrypted = const Value.absent(),
    int? encryptionVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<DateTime?> scheduledPurgeAt = const Value.absent(),
    Value<String?> encryptedMetadata = const Value.absent(),
    bool? isPinned,
    NoteKind? noteType,
    int? version,
    Value<String?> userId = const Value.absent(),
    Value<String?> attachmentMeta = const Value.absent(),
    Value<String?> metadata = const Value.absent(),
  }) => LocalNote(
    id: id ?? this.id,
    titleEncrypted: titleEncrypted ?? this.titleEncrypted,
    bodyEncrypted: bodyEncrypted ?? this.bodyEncrypted,
    metadataEncrypted: metadataEncrypted.present
        ? metadataEncrypted.value
        : this.metadataEncrypted,
    encryptionVersion: encryptionVersion ?? this.encryptionVersion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    scheduledPurgeAt: scheduledPurgeAt.present
        ? scheduledPurgeAt.value
        : this.scheduledPurgeAt,
    encryptedMetadata: encryptedMetadata.present
        ? encryptedMetadata.value
        : this.encryptedMetadata,
    isPinned: isPinned ?? this.isPinned,
    noteType: noteType ?? this.noteType,
    version: version ?? this.version,
    userId: userId.present ? userId.value : this.userId,
    attachmentMeta: attachmentMeta.present
        ? attachmentMeta.value
        : this.attachmentMeta,
    metadata: metadata.present ? metadata.value : this.metadata,
  );
  LocalNote copyWithCompanion(LocalNotesCompanion data) {
    return LocalNote(
      id: data.id.present ? data.id.value : this.id,
      titleEncrypted: data.titleEncrypted.present
          ? data.titleEncrypted.value
          : this.titleEncrypted,
      bodyEncrypted: data.bodyEncrypted.present
          ? data.bodyEncrypted.value
          : this.bodyEncrypted,
      metadataEncrypted: data.metadataEncrypted.present
          ? data.metadataEncrypted.value
          : this.metadataEncrypted,
      encryptionVersion: data.encryptionVersion.present
          ? data.encryptionVersion.value
          : this.encryptionVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      scheduledPurgeAt: data.scheduledPurgeAt.present
          ? data.scheduledPurgeAt.value
          : this.scheduledPurgeAt,
      encryptedMetadata: data.encryptedMetadata.present
          ? data.encryptedMetadata.value
          : this.encryptedMetadata,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      noteType: data.noteType.present ? data.noteType.value : this.noteType,
      version: data.version.present ? data.version.value : this.version,
      userId: data.userId.present ? data.userId.value : this.userId,
      attachmentMeta: data.attachmentMeta.present
          ? data.attachmentMeta.value
          : this.attachmentMeta,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalNote(')
          ..write('id: $id, ')
          ..write('titleEncrypted: $titleEncrypted, ')
          ..write('bodyEncrypted: $bodyEncrypted, ')
          ..write('metadataEncrypted: $metadataEncrypted, ')
          ..write('encryptionVersion: $encryptionVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('scheduledPurgeAt: $scheduledPurgeAt, ')
          ..write('encryptedMetadata: $encryptedMetadata, ')
          ..write('isPinned: $isPinned, ')
          ..write('noteType: $noteType, ')
          ..write('version: $version, ')
          ..write('userId: $userId, ')
          ..write('attachmentMeta: $attachmentMeta, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    titleEncrypted,
    bodyEncrypted,
    metadataEncrypted,
    encryptionVersion,
    createdAt,
    updatedAt,
    deleted,
    deletedAt,
    scheduledPurgeAt,
    encryptedMetadata,
    isPinned,
    noteType,
    version,
    userId,
    attachmentMeta,
    metadata,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalNote &&
          other.id == this.id &&
          other.titleEncrypted == this.titleEncrypted &&
          other.bodyEncrypted == this.bodyEncrypted &&
          other.metadataEncrypted == this.metadataEncrypted &&
          other.encryptionVersion == this.encryptionVersion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.deletedAt == this.deletedAt &&
          other.scheduledPurgeAt == this.scheduledPurgeAt &&
          other.encryptedMetadata == this.encryptedMetadata &&
          other.isPinned == this.isPinned &&
          other.noteType == this.noteType &&
          other.version == this.version &&
          other.userId == this.userId &&
          other.attachmentMeta == this.attachmentMeta &&
          other.metadata == this.metadata);
}

class LocalNotesCompanion extends UpdateCompanion<LocalNote> {
  final Value<String> id;
  final Value<String> titleEncrypted;
  final Value<String> bodyEncrypted;
  final Value<String?> metadataEncrypted;
  final Value<int> encryptionVersion;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<DateTime?> deletedAt;
  final Value<DateTime?> scheduledPurgeAt;
  final Value<String?> encryptedMetadata;
  final Value<bool> isPinned;
  final Value<NoteKind> noteType;
  final Value<int> version;
  final Value<String?> userId;
  final Value<String?> attachmentMeta;
  final Value<String?> metadata;
  final Value<int> rowid;
  const LocalNotesCompanion({
    this.id = const Value.absent(),
    this.titleEncrypted = const Value.absent(),
    this.bodyEncrypted = const Value.absent(),
    this.metadataEncrypted = const Value.absent(),
    this.encryptionVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.scheduledPurgeAt = const Value.absent(),
    this.encryptedMetadata = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.noteType = const Value.absent(),
    this.version = const Value.absent(),
    this.userId = const Value.absent(),
    this.attachmentMeta = const Value.absent(),
    this.metadata = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalNotesCompanion.insert({
    required String id,
    this.titleEncrypted = const Value.absent(),
    this.bodyEncrypted = const Value.absent(),
    this.metadataEncrypted = const Value.absent(),
    this.encryptionVersion = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.scheduledPurgeAt = const Value.absent(),
    this.encryptedMetadata = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.noteType = const Value.absent(),
    this.version = const Value.absent(),
    this.userId = const Value.absent(),
    this.attachmentMeta = const Value.absent(),
    this.metadata = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalNote> custom({
    Expression<String>? id,
    Expression<String>? titleEncrypted,
    Expression<String>? bodyEncrypted,
    Expression<String>? metadataEncrypted,
    Expression<int>? encryptionVersion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? scheduledPurgeAt,
    Expression<String>? encryptedMetadata,
    Expression<bool>? isPinned,
    Expression<int>? noteType,
    Expression<int>? version,
    Expression<String>? userId,
    Expression<String>? attachmentMeta,
    Expression<String>? metadata,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (titleEncrypted != null) 'title_encrypted': titleEncrypted,
      if (bodyEncrypted != null) 'body_encrypted': bodyEncrypted,
      if (metadataEncrypted != null) 'metadata_encrypted': metadataEncrypted,
      if (encryptionVersion != null) 'encryption_version': encryptionVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (scheduledPurgeAt != null) 'scheduled_purge_at': scheduledPurgeAt,
      if (encryptedMetadata != null) 'encrypted_metadata': encryptedMetadata,
      if (isPinned != null) 'is_pinned': isPinned,
      if (noteType != null) 'note_type': noteType,
      if (version != null) 'version': version,
      if (userId != null) 'user_id': userId,
      if (attachmentMeta != null) 'attachment_meta': attachmentMeta,
      if (metadata != null) 'metadata': metadata,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalNotesCompanion copyWith({
    Value<String>? id,
    Value<String>? titleEncrypted,
    Value<String>? bodyEncrypted,
    Value<String?>? metadataEncrypted,
    Value<int>? encryptionVersion,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<DateTime?>? deletedAt,
    Value<DateTime?>? scheduledPurgeAt,
    Value<String?>? encryptedMetadata,
    Value<bool>? isPinned,
    Value<NoteKind>? noteType,
    Value<int>? version,
    Value<String?>? userId,
    Value<String?>? attachmentMeta,
    Value<String?>? metadata,
    Value<int>? rowid,
  }) {
    return LocalNotesCompanion(
      id: id ?? this.id,
      titleEncrypted: titleEncrypted ?? this.titleEncrypted,
      bodyEncrypted: bodyEncrypted ?? this.bodyEncrypted,
      metadataEncrypted: metadataEncrypted ?? this.metadataEncrypted,
      encryptionVersion: encryptionVersion ?? this.encryptionVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      scheduledPurgeAt: scheduledPurgeAt ?? this.scheduledPurgeAt,
      encryptedMetadata: encryptedMetadata ?? this.encryptedMetadata,
      isPinned: isPinned ?? this.isPinned,
      noteType: noteType ?? this.noteType,
      version: version ?? this.version,
      userId: userId ?? this.userId,
      attachmentMeta: attachmentMeta ?? this.attachmentMeta,
      metadata: metadata ?? this.metadata,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (titleEncrypted.present) {
      map['title_encrypted'] = Variable<String>(titleEncrypted.value);
    }
    if (bodyEncrypted.present) {
      map['body_encrypted'] = Variable<String>(bodyEncrypted.value);
    }
    if (metadataEncrypted.present) {
      map['metadata_encrypted'] = Variable<String>(metadataEncrypted.value);
    }
    if (encryptionVersion.present) {
      map['encryption_version'] = Variable<int>(encryptionVersion.value);
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
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (scheduledPurgeAt.present) {
      map['scheduled_purge_at'] = Variable<DateTime>(scheduledPurgeAt.value);
    }
    if (encryptedMetadata.present) {
      map['encrypted_metadata'] = Variable<String>(encryptedMetadata.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (noteType.present) {
      map['note_type'] = Variable<int>(
        $LocalNotesTable.$converternoteType.toSql(noteType.value),
      );
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (attachmentMeta.present) {
      map['attachment_meta'] = Variable<String>(attachmentMeta.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
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
          ..write('titleEncrypted: $titleEncrypted, ')
          ..write('bodyEncrypted: $bodyEncrypted, ')
          ..write('metadataEncrypted: $metadataEncrypted, ')
          ..write('encryptionVersion: $encryptionVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('scheduledPurgeAt: $scheduledPurgeAt, ')
          ..write('encryptedMetadata: $encryptedMetadata, ')
          ..write('isPinned: $isPinned, ')
          ..write('noteType: $noteType, ')
          ..write('version: $version, ')
          ..write('userId: $userId, ')
          ..write('attachmentMeta: $attachmentMeta, ')
          ..write('metadata: $metadata, ')
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
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    userId,
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
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
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
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
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
  final String userId;
  final DateTime createdAt;
  const PendingOp({
    required this.id,
    required this.entityId,
    required this.kind,
    this.payload,
    required this.userId,
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
    map['user_id'] = Variable<String>(userId);
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
      userId: Value(userId),
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
      userId: serializer.fromJson<String>(json['userId']),
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
      'userId': serializer.toJson<String>(userId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingOp copyWith({
    int? id,
    String? entityId,
    String? kind,
    Value<String?> payload = const Value.absent(),
    String? userId,
    DateTime? createdAt,
  }) => PendingOp(
    id: id ?? this.id,
    entityId: entityId ?? this.entityId,
    kind: kind ?? this.kind,
    payload: payload.present ? payload.value : this.payload,
    userId: userId ?? this.userId,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingOp copyWithCompanion(PendingOpsCompanion data) {
    return PendingOp(
      id: data.id.present ? data.id.value : this.id,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      userId: data.userId.present ? data.userId.value : this.userId,
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
          ..write('userId: $userId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, entityId, kind, payload, userId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingOp &&
          other.id == this.id &&
          other.entityId == this.entityId &&
          other.kind == this.kind &&
          other.payload == this.payload &&
          other.userId == this.userId &&
          other.createdAt == this.createdAt);
}

class PendingOpsCompanion extends UpdateCompanion<PendingOp> {
  final Value<int> id;
  final Value<String> entityId;
  final Value<String> kind;
  final Value<String?> payload;
  final Value<String> userId;
  final Value<DateTime> createdAt;
  const PendingOpsCompanion({
    this.id = const Value.absent(),
    this.entityId = const Value.absent(),
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.userId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PendingOpsCompanion.insert({
    this.id = const Value.absent(),
    required String entityId,
    required String kind,
    this.payload = const Value.absent(),
    required String userId,
    this.createdAt = const Value.absent(),
  }) : entityId = Value(entityId),
       kind = Value(kind),
       userId = Value(userId);
  static Insertable<PendingOp> custom({
    Expression<int>? id,
    Expression<String>? entityId,
    Expression<String>? kind,
    Expression<String>? payload,
    Expression<String>? userId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityId != null) 'entity_id': entityId,
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (userId != null) 'user_id': userId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PendingOpsCompanion copyWith({
    Value<int>? id,
    Value<String>? entityId,
    Value<String>? kind,
    Value<String?>? payload,
    Value<String>? userId,
    Value<DateTime>? createdAt,
  }) {
    return PendingOpsCompanion(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      userId: userId ?? this.userId,
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
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
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
          ..write('userId: $userId, ')
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
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [noteId, tag, userId];
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
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
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
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
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
  final String userId;
  const NoteTag({
    required this.noteId,
    required this.tag,
    required this.userId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id'] = Variable<String>(noteId);
    map['tag'] = Variable<String>(tag);
    map['user_id'] = Variable<String>(userId);
    return map;
  }

  NoteTagsCompanion toCompanion(bool nullToAbsent) {
    return NoteTagsCompanion(
      noteId: Value(noteId),
      tag: Value(tag),
      userId: Value(userId),
    );
  }

  factory NoteTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteTag(
      noteId: serializer.fromJson<String>(json['noteId']),
      tag: serializer.fromJson<String>(json['tag']),
      userId: serializer.fromJson<String>(json['userId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId': serializer.toJson<String>(noteId),
      'tag': serializer.toJson<String>(tag),
      'userId': serializer.toJson<String>(userId),
    };
  }

  NoteTag copyWith({String? noteId, String? tag, String? userId}) => NoteTag(
    noteId: noteId ?? this.noteId,
    tag: tag ?? this.tag,
    userId: userId ?? this.userId,
  );
  NoteTag copyWithCompanion(NoteTagsCompanion data) {
    return NoteTag(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      tag: data.tag.present ? data.tag.value : this.tag,
      userId: data.userId.present ? data.userId.value : this.userId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteTag(')
          ..write('noteId: $noteId, ')
          ..write('tag: $tag, ')
          ..write('userId: $userId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(noteId, tag, userId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteTag &&
          other.noteId == this.noteId &&
          other.tag == this.tag &&
          other.userId == this.userId);
}

class NoteTagsCompanion extends UpdateCompanion<NoteTag> {
  final Value<String> noteId;
  final Value<String> tag;
  final Value<String> userId;
  final Value<int> rowid;
  const NoteTagsCompanion({
    this.noteId = const Value.absent(),
    this.tag = const Value.absent(),
    this.userId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteTagsCompanion.insert({
    required String noteId,
    required String tag,
    required String userId,
    this.rowid = const Value.absent(),
  }) : noteId = Value(noteId),
       tag = Value(tag),
       userId = Value(userId);
  static Insertable<NoteTag> custom({
    Expression<String>? noteId,
    Expression<String>? tag,
    Expression<String>? userId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (noteId != null) 'note_id': noteId,
      if (tag != null) 'tag': tag,
      if (userId != null) 'user_id': userId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteTagsCompanion copyWith({
    Value<String>? noteId,
    Value<String>? tag,
    Value<String>? userId,
    Value<int>? rowid,
  }) {
    return NoteTagsCompanion(
      noteId: noteId ?? this.noteId,
      tag: tag ?? this.tag,
      userId: userId ?? this.userId,
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
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
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
          ..write('userId: $userId, ')
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
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    targetTitle,
    targetId,
    userId,
  ];
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
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
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
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
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
  final String userId;
  const NoteLink({
    required this.sourceId,
    required this.targetTitle,
    this.targetId,
    required this.userId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['target_title'] = Variable<String>(targetTitle);
    if (!nullToAbsent || targetId != null) {
      map['target_id'] = Variable<String>(targetId);
    }
    map['user_id'] = Variable<String>(userId);
    return map;
  }

  NoteLinksCompanion toCompanion(bool nullToAbsent) {
    return NoteLinksCompanion(
      sourceId: Value(sourceId),
      targetTitle: Value(targetTitle),
      targetId: targetId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetId),
      userId: Value(userId),
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
      userId: serializer.fromJson<String>(json['userId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'targetTitle': serializer.toJson<String>(targetTitle),
      'targetId': serializer.toJson<String?>(targetId),
      'userId': serializer.toJson<String>(userId),
    };
  }

  NoteLink copyWith({
    String? sourceId,
    String? targetTitle,
    Value<String?> targetId = const Value.absent(),
    String? userId,
  }) => NoteLink(
    sourceId: sourceId ?? this.sourceId,
    targetTitle: targetTitle ?? this.targetTitle,
    targetId: targetId.present ? targetId.value : this.targetId,
    userId: userId ?? this.userId,
  );
  NoteLink copyWithCompanion(NoteLinksCompanion data) {
    return NoteLink(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      targetTitle: data.targetTitle.present
          ? data.targetTitle.value
          : this.targetTitle,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      userId: data.userId.present ? data.userId.value : this.userId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteLink(')
          ..write('sourceId: $sourceId, ')
          ..write('targetTitle: $targetTitle, ')
          ..write('targetId: $targetId, ')
          ..write('userId: $userId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sourceId, targetTitle, targetId, userId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteLink &&
          other.sourceId == this.sourceId &&
          other.targetTitle == this.targetTitle &&
          other.targetId == this.targetId &&
          other.userId == this.userId);
}

class NoteLinksCompanion extends UpdateCompanion<NoteLink> {
  final Value<String> sourceId;
  final Value<String> targetTitle;
  final Value<String?> targetId;
  final Value<String> userId;
  final Value<int> rowid;
  const NoteLinksCompanion({
    this.sourceId = const Value.absent(),
    this.targetTitle = const Value.absent(),
    this.targetId = const Value.absent(),
    this.userId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteLinksCompanion.insert({
    required String sourceId,
    required String targetTitle,
    this.targetId = const Value.absent(),
    required String userId,
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       targetTitle = Value(targetTitle),
       userId = Value(userId);
  static Insertable<NoteLink> custom({
    Expression<String>? sourceId,
    Expression<String>? targetTitle,
    Expression<String>? targetId,
    Expression<String>? userId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (targetTitle != null) 'target_title': targetTitle,
      if (targetId != null) 'target_id': targetId,
      if (userId != null) 'user_id': userId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteLinksCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? targetTitle,
    Value<String?>? targetId,
    Value<String>? userId,
    Value<int>? rowid,
  }) {
    return NoteLinksCompanion(
      sourceId: sourceId ?? this.sourceId,
      targetTitle: targetTitle ?? this.targetTitle,
      targetId: targetId ?? this.targetId,
      userId: userId ?? this.userId,
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
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
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
          ..write('userId: $userId, ')
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
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => const Uuid().v4(),
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
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
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
  static const VerificationMeta _titleEncryptedMeta = const VerificationMeta(
    'titleEncrypted',
  );
  @override
  late final GeneratedColumn<Uint8List> titleEncrypted =
      GeneratedColumn<Uint8List>(
        'title_encrypted',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _bodyEncryptedMeta = const VerificationMeta(
    'bodyEncrypted',
  );
  @override
  late final GeneratedColumn<Uint8List> bodyEncrypted =
      GeneratedColumn<Uint8List>(
        'body_encrypted',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _locationNameEncryptedMeta =
      const VerificationMeta('locationNameEncrypted');
  @override
  late final GeneratedColumn<Uint8List> locationNameEncrypted =
      GeneratedColumn<Uint8List>(
        'location_name_encrypted',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _encryptionVersionMeta = const VerificationMeta(
    'encryptionVersion',
  );
  @override
  late final GeneratedColumn<int> encryptionVersion = GeneratedColumn<int>(
    'encryption_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledPurgeAtMeta = const VerificationMeta(
    'scheduledPurgeAt',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledPurgeAt =
      GeneratedColumn<DateTime>(
        'scheduled_purge_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
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
    userId,
    title,
    body,
    titleEncrypted,
    bodyEncrypted,
    locationNameEncrypted,
    encryptionVersion,
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
    updatedAt,
    deletedAt,
    scheduledPurgeAt,
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
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
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
    if (data.containsKey('title_encrypted')) {
      context.handle(
        _titleEncryptedMeta,
        titleEncrypted.isAcceptableOrUnknown(
          data['title_encrypted']!,
          _titleEncryptedMeta,
        ),
      );
    }
    if (data.containsKey('body_encrypted')) {
      context.handle(
        _bodyEncryptedMeta,
        bodyEncrypted.isAcceptableOrUnknown(
          data['body_encrypted']!,
          _bodyEncryptedMeta,
        ),
      );
    }
    if (data.containsKey('location_name_encrypted')) {
      context.handle(
        _locationNameEncryptedMeta,
        locationNameEncrypted.isAcceptableOrUnknown(
          data['location_name_encrypted']!,
          _locationNameEncryptedMeta,
        ),
      );
    }
    if (data.containsKey('encryption_version')) {
      context.handle(
        _encryptionVersionMeta,
        encryptionVersion.isAcceptableOrUnknown(
          data['encryption_version']!,
          _encryptionVersionMeta,
        ),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('scheduled_purge_at')) {
      context.handle(
        _scheduledPurgeAtMeta,
        scheduledPurgeAt.isAcceptableOrUnknown(
          data['scheduled_purge_at']!,
          _scheduledPurgeAtMeta,
        ),
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
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      titleEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}title_encrypted'],
      ),
      bodyEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}body_encrypted'],
      ),
      locationNameEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}location_name_encrypted'],
      ),
      encryptionVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}encryption_version'],
      ),
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
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      scheduledPurgeAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_purge_at'],
      ),
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
  final String id;
  final String noteId;

  /// User ID who owns this reminder (P0.5 SECURITY: prevents cross-user access)
  final String userId;
  final String title;
  final String body;
  final Uint8List? titleEncrypted;
  final Uint8List? bodyEncrypted;
  final Uint8List? locationNameEncrypted;
  final int? encryptionVersion;
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
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final DateTime? scheduledPurgeAt;
  final DateTime? lastTriggered;
  final int triggerCount;
  const NoteReminder({
    required this.id,
    required this.noteId,
    required this.userId,
    required this.title,
    required this.body,
    this.titleEncrypted,
    this.bodyEncrypted,
    this.locationNameEncrypted,
    this.encryptionVersion,
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
    this.updatedAt,
    this.deletedAt,
    this.scheduledPurgeAt,
    this.lastTriggered,
    required this.triggerCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['note_id'] = Variable<String>(noteId);
    map['user_id'] = Variable<String>(userId);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || titleEncrypted != null) {
      map['title_encrypted'] = Variable<Uint8List>(titleEncrypted);
    }
    if (!nullToAbsent || bodyEncrypted != null) {
      map['body_encrypted'] = Variable<Uint8List>(bodyEncrypted);
    }
    if (!nullToAbsent || locationNameEncrypted != null) {
      map['location_name_encrypted'] = Variable<Uint8List>(
        locationNameEncrypted,
      );
    }
    if (!nullToAbsent || encryptionVersion != null) {
      map['encryption_version'] = Variable<int>(encryptionVersion);
    }
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
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || scheduledPurgeAt != null) {
      map['scheduled_purge_at'] = Variable<DateTime>(scheduledPurgeAt);
    }
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
      userId: Value(userId),
      title: Value(title),
      body: Value(body),
      titleEncrypted: titleEncrypted == null && nullToAbsent
          ? const Value.absent()
          : Value(titleEncrypted),
      bodyEncrypted: bodyEncrypted == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyEncrypted),
      locationNameEncrypted: locationNameEncrypted == null && nullToAbsent
          ? const Value.absent()
          : Value(locationNameEncrypted),
      encryptionVersion: encryptionVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptionVersion),
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
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      scheduledPurgeAt: scheduledPurgeAt == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledPurgeAt),
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
      id: serializer.fromJson<String>(json['id']),
      noteId: serializer.fromJson<String>(json['noteId']),
      userId: serializer.fromJson<String>(json['userId']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      titleEncrypted: serializer.fromJson<Uint8List?>(json['titleEncrypted']),
      bodyEncrypted: serializer.fromJson<Uint8List?>(json['bodyEncrypted']),
      locationNameEncrypted: serializer.fromJson<Uint8List?>(
        json['locationNameEncrypted'],
      ),
      encryptionVersion: serializer.fromJson<int?>(json['encryptionVersion']),
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
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      scheduledPurgeAt: serializer.fromJson<DateTime?>(
        json['scheduledPurgeAt'],
      ),
      lastTriggered: serializer.fromJson<DateTime?>(json['lastTriggered']),
      triggerCount: serializer.fromJson<int>(json['triggerCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteId': serializer.toJson<String>(noteId),
      'userId': serializer.toJson<String>(userId),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'titleEncrypted': serializer.toJson<Uint8List?>(titleEncrypted),
      'bodyEncrypted': serializer.toJson<Uint8List?>(bodyEncrypted),
      'locationNameEncrypted': serializer.toJson<Uint8List?>(
        locationNameEncrypted,
      ),
      'encryptionVersion': serializer.toJson<int?>(encryptionVersion),
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
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'scheduledPurgeAt': serializer.toJson<DateTime?>(scheduledPurgeAt),
      'lastTriggered': serializer.toJson<DateTime?>(lastTriggered),
      'triggerCount': serializer.toJson<int>(triggerCount),
    };
  }

  NoteReminder copyWith({
    String? id,
    String? noteId,
    String? userId,
    String? title,
    String? body,
    Value<Uint8List?> titleEncrypted = const Value.absent(),
    Value<Uint8List?> bodyEncrypted = const Value.absent(),
    Value<Uint8List?> locationNameEncrypted = const Value.absent(),
    Value<int?> encryptionVersion = const Value.absent(),
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
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<DateTime?> scheduledPurgeAt = const Value.absent(),
    Value<DateTime?> lastTriggered = const Value.absent(),
    int? triggerCount,
  }) => NoteReminder(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    body: body ?? this.body,
    titleEncrypted: titleEncrypted.present
        ? titleEncrypted.value
        : this.titleEncrypted,
    bodyEncrypted: bodyEncrypted.present
        ? bodyEncrypted.value
        : this.bodyEncrypted,
    locationNameEncrypted: locationNameEncrypted.present
        ? locationNameEncrypted.value
        : this.locationNameEncrypted,
    encryptionVersion: encryptionVersion.present
        ? encryptionVersion.value
        : this.encryptionVersion,
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
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    scheduledPurgeAt: scheduledPurgeAt.present
        ? scheduledPurgeAt.value
        : this.scheduledPurgeAt,
    lastTriggered: lastTriggered.present
        ? lastTriggered.value
        : this.lastTriggered,
    triggerCount: triggerCount ?? this.triggerCount,
  );
  NoteReminder copyWithCompanion(NoteRemindersCompanion data) {
    return NoteReminder(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      userId: data.userId.present ? data.userId.value : this.userId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      titleEncrypted: data.titleEncrypted.present
          ? data.titleEncrypted.value
          : this.titleEncrypted,
      bodyEncrypted: data.bodyEncrypted.present
          ? data.bodyEncrypted.value
          : this.bodyEncrypted,
      locationNameEncrypted: data.locationNameEncrypted.present
          ? data.locationNameEncrypted.value
          : this.locationNameEncrypted,
      encryptionVersion: data.encryptionVersion.present
          ? data.encryptionVersion.value
          : this.encryptionVersion,
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
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      scheduledPurgeAt: data.scheduledPurgeAt.present
          ? data.scheduledPurgeAt.value
          : this.scheduledPurgeAt,
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
          ..write('userId: $userId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('titleEncrypted: $titleEncrypted, ')
          ..write('bodyEncrypted: $bodyEncrypted, ')
          ..write('locationNameEncrypted: $locationNameEncrypted, ')
          ..write('encryptionVersion: $encryptionVersion, ')
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
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('scheduledPurgeAt: $scheduledPurgeAt, ')
          ..write('lastTriggered: $lastTriggered, ')
          ..write('triggerCount: $triggerCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    noteId,
    userId,
    title,
    body,
    $driftBlobEquality.hash(titleEncrypted),
    $driftBlobEquality.hash(bodyEncrypted),
    $driftBlobEquality.hash(locationNameEncrypted),
    encryptionVersion,
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
    updatedAt,
    deletedAt,
    scheduledPurgeAt,
    lastTriggered,
    triggerCount,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteReminder &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.userId == this.userId &&
          other.title == this.title &&
          other.body == this.body &&
          $driftBlobEquality.equals(
            other.titleEncrypted,
            this.titleEncrypted,
          ) &&
          $driftBlobEquality.equals(other.bodyEncrypted, this.bodyEncrypted) &&
          $driftBlobEquality.equals(
            other.locationNameEncrypted,
            this.locationNameEncrypted,
          ) &&
          other.encryptionVersion == this.encryptionVersion &&
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
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.scheduledPurgeAt == this.scheduledPurgeAt &&
          other.lastTriggered == this.lastTriggered &&
          other.triggerCount == this.triggerCount);
}

class NoteRemindersCompanion extends UpdateCompanion<NoteReminder> {
  final Value<String> id;
  final Value<String> noteId;
  final Value<String> userId;
  final Value<String> title;
  final Value<String> body;
  final Value<Uint8List?> titleEncrypted;
  final Value<Uint8List?> bodyEncrypted;
  final Value<Uint8List?> locationNameEncrypted;
  final Value<int?> encryptionVersion;
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
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<DateTime?> scheduledPurgeAt;
  final Value<DateTime?> lastTriggered;
  final Value<int> triggerCount;
  final Value<int> rowid;
  const NoteRemindersCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.userId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.titleEncrypted = const Value.absent(),
    this.bodyEncrypted = const Value.absent(),
    this.locationNameEncrypted = const Value.absent(),
    this.encryptionVersion = const Value.absent(),
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
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.scheduledPurgeAt = const Value.absent(),
    this.lastTriggered = const Value.absent(),
    this.triggerCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteRemindersCompanion.insert({
    this.id = const Value.absent(),
    required String noteId,
    required String userId,
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.titleEncrypted = const Value.absent(),
    this.bodyEncrypted = const Value.absent(),
    this.locationNameEncrypted = const Value.absent(),
    this.encryptionVersion = const Value.absent(),
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
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.scheduledPurgeAt = const Value.absent(),
    this.lastTriggered = const Value.absent(),
    this.triggerCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : noteId = Value(noteId),
       userId = Value(userId),
       type = Value(type);
  static Insertable<NoteReminder> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<String>? userId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<Uint8List>? titleEncrypted,
    Expression<Uint8List>? bodyEncrypted,
    Expression<Uint8List>? locationNameEncrypted,
    Expression<int>? encryptionVersion,
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
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? scheduledPurgeAt,
    Expression<DateTime>? lastTriggered,
    Expression<int>? triggerCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (userId != null) 'user_id': userId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (titleEncrypted != null) 'title_encrypted': titleEncrypted,
      if (bodyEncrypted != null) 'body_encrypted': bodyEncrypted,
      if (locationNameEncrypted != null)
        'location_name_encrypted': locationNameEncrypted,
      if (encryptionVersion != null) 'encryption_version': encryptionVersion,
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
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (scheduledPurgeAt != null) 'scheduled_purge_at': scheduledPurgeAt,
      if (lastTriggered != null) 'last_triggered': lastTriggered,
      if (triggerCount != null) 'trigger_count': triggerCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteRemindersCompanion copyWith({
    Value<String>? id,
    Value<String>? noteId,
    Value<String>? userId,
    Value<String>? title,
    Value<String>? body,
    Value<Uint8List?>? titleEncrypted,
    Value<Uint8List?>? bodyEncrypted,
    Value<Uint8List?>? locationNameEncrypted,
    Value<int?>? encryptionVersion,
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
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<DateTime?>? scheduledPurgeAt,
    Value<DateTime?>? lastTriggered,
    Value<int>? triggerCount,
    Value<int>? rowid,
  }) {
    return NoteRemindersCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      titleEncrypted: titleEncrypted ?? this.titleEncrypted,
      bodyEncrypted: bodyEncrypted ?? this.bodyEncrypted,
      locationNameEncrypted:
          locationNameEncrypted ?? this.locationNameEncrypted,
      encryptionVersion: encryptionVersion ?? this.encryptionVersion,
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
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      scheduledPurgeAt: scheduledPurgeAt ?? this.scheduledPurgeAt,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      triggerCount: triggerCount ?? this.triggerCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (titleEncrypted.present) {
      map['title_encrypted'] = Variable<Uint8List>(titleEncrypted.value);
    }
    if (bodyEncrypted.present) {
      map['body_encrypted'] = Variable<Uint8List>(bodyEncrypted.value);
    }
    if (locationNameEncrypted.present) {
      map['location_name_encrypted'] = Variable<Uint8List>(
        locationNameEncrypted.value,
      );
    }
    if (encryptionVersion.present) {
      map['encryption_version'] = Variable<int>(encryptionVersion.value);
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (scheduledPurgeAt.present) {
      map['scheduled_purge_at'] = Variable<DateTime>(scheduledPurgeAt.value);
    }
    if (lastTriggered.present) {
      map['last_triggered'] = Variable<DateTime>(lastTriggered.value);
    }
    if (triggerCount.present) {
      map['trigger_count'] = Variable<int>(triggerCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteRemindersCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('userId: $userId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('titleEncrypted: $titleEncrypted, ')
          ..write('bodyEncrypted: $bodyEncrypted, ')
          ..write('locationNameEncrypted: $locationNameEncrypted, ')
          ..write('encryptionVersion: $encryptionVersion, ')
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
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('scheduledPurgeAt: $scheduledPurgeAt, ')
          ..write('lastTriggered: $lastTriggered, ')
          ..write('triggerCount: $triggerCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteTasksTable extends NoteTasks
    with TableInfo<$NoteTasksTable, NoteTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentEncryptedMeta = const VerificationMeta(
    'contentEncrypted',
  );
  @override
  late final GeneratedColumn<String> contentEncrypted = GeneratedColumn<String>(
    'content_encrypted',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelsEncryptedMeta = const VerificationMeta(
    'labelsEncrypted',
  );
  @override
  late final GeneratedColumn<String> labelsEncrypted = GeneratedColumn<String>(
    'labels_encrypted',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesEncryptedMeta = const VerificationMeta(
    'notesEncrypted',
  );
  @override
  late final GeneratedColumn<String> notesEncrypted = GeneratedColumn<String>(
    'notes_encrypted',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptionVersionMeta = const VerificationMeta(
    'encryptionVersion',
  );
  @override
  late final GeneratedColumn<int> encryptionVersion = GeneratedColumn<int>(
    'encryption_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TaskStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: Constant(TaskStatus.open.index),
      ).withConverter<TaskStatus>($NoteTasksTable.$converterstatus);
  @override
  late final GeneratedColumnWithTypeConverter<TaskPriority, int> priority =
      GeneratedColumn<int>(
        'priority',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: Constant(TaskPriority.medium.index),
      ).withConverter<TaskPriority>($NoteTasksTable.$converterpriority);
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedByMeta = const VerificationMeta(
    'completedBy',
  );
  @override
  late final GeneratedColumn<String> completedBy = GeneratedColumn<String>(
    'completed_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reminderIdMeta = const VerificationMeta(
    'reminderId',
  );
  @override
  late final GeneratedColumn<String> reminderId = GeneratedColumn<String>(
    'reminder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estimatedMinutesMeta = const VerificationMeta(
    'estimatedMinutes',
  );
  @override
  late final GeneratedColumn<int> estimatedMinutes = GeneratedColumn<int>(
    'estimated_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actualMinutesMeta = const VerificationMeta(
    'actualMinutes',
  );
  @override
  late final GeneratedColumn<int> actualMinutes = GeneratedColumn<int>(
    'actual_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentTaskIdMeta = const VerificationMeta(
    'parentTaskId',
  );
  @override
  late final GeneratedColumn<String> parentTaskId = GeneratedColumn<String>(
    'parent_task_id',
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledPurgeAtMeta = const VerificationMeta(
    'scheduledPurgeAt',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledPurgeAt =
      GeneratedColumn<DateTime>(
        'scheduled_purge_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    userId,
    contentEncrypted,
    labelsEncrypted,
    notesEncrypted,
    encryptionVersion,
    status,
    priority,
    dueDate,
    completedAt,
    completedBy,
    position,
    contentHash,
    reminderId,
    estimatedMinutes,
    actualMinutes,
    parentTaskId,
    createdAt,
    updatedAt,
    deleted,
    deletedAt,
    scheduledPurgeAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('content_encrypted')) {
      context.handle(
        _contentEncryptedMeta,
        contentEncrypted.isAcceptableOrUnknown(
          data['content_encrypted']!,
          _contentEncryptedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentEncryptedMeta);
    }
    if (data.containsKey('labels_encrypted')) {
      context.handle(
        _labelsEncryptedMeta,
        labelsEncrypted.isAcceptableOrUnknown(
          data['labels_encrypted']!,
          _labelsEncryptedMeta,
        ),
      );
    }
    if (data.containsKey('notes_encrypted')) {
      context.handle(
        _notesEncryptedMeta,
        notesEncrypted.isAcceptableOrUnknown(
          data['notes_encrypted']!,
          _notesEncryptedMeta,
        ),
      );
    }
    if (data.containsKey('encryption_version')) {
      context.handle(
        _encryptionVersionMeta,
        encryptionVersion.isAcceptableOrUnknown(
          data['encryption_version']!,
          _encryptionVersionMeta,
        ),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('completed_by')) {
      context.handle(
        _completedByMeta,
        completedBy.isAcceptableOrUnknown(
          data['completed_by']!,
          _completedByMeta,
        ),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('reminder_id')) {
      context.handle(
        _reminderIdMeta,
        reminderId.isAcceptableOrUnknown(data['reminder_id']!, _reminderIdMeta),
      );
    }
    if (data.containsKey('estimated_minutes')) {
      context.handle(
        _estimatedMinutesMeta,
        estimatedMinutes.isAcceptableOrUnknown(
          data['estimated_minutes']!,
          _estimatedMinutesMeta,
        ),
      );
    }
    if (data.containsKey('actual_minutes')) {
      context.handle(
        _actualMinutesMeta,
        actualMinutes.isAcceptableOrUnknown(
          data['actual_minutes']!,
          _actualMinutesMeta,
        ),
      );
    }
    if (data.containsKey('parent_task_id')) {
      context.handle(
        _parentTaskIdMeta,
        parentTaskId.isAcceptableOrUnknown(
          data['parent_task_id']!,
          _parentTaskIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('scheduled_purge_at')) {
      context.handle(
        _scheduledPurgeAtMeta,
        scheduledPurgeAt.isAcceptableOrUnknown(
          data['scheduled_purge_at']!,
          _scheduledPurgeAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteTask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      contentEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_encrypted'],
      )!,
      labelsEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}labels_encrypted'],
      ),
      notesEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes_encrypted'],
      ),
      encryptionVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}encryption_version'],
      )!,
      status: $NoteTasksTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      priority: $NoteTasksTable.$converterpriority.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}priority'],
        )!,
      ),
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      completedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_by'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      reminderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_id'],
      ),
      estimatedMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_minutes'],
      ),
      actualMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_minutes'],
      ),
      parentTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_task_id'],
      ),
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
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      scheduledPurgeAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_purge_at'],
      ),
    );
  }

  @override
  $NoteTasksTable createAlias(String alias) {
    return $NoteTasksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TaskStatus, int, int> $converterstatus =
      const EnumIndexConverter<TaskStatus>(TaskStatus.values);
  static JsonTypeConverter2<TaskPriority, int, int> $converterpriority =
      const EnumIndexConverter<TaskPriority>(TaskPriority.values);
}

class NoteTask extends DataClass implements Insertable<NoteTask> {
  /// Unique identifier for the task
  final String id;

  /// Reference to parent note ID
  final String noteId;

  /// User ID who owns this task (mirrors parent note ownership)
  final String userId;
  final String contentEncrypted;
  final String? labelsEncrypted;
  final String? notesEncrypted;
  final int encryptionVersion;

  /// Task completion status
  final TaskStatus status;

  /// Task priority level
  final TaskPriority priority;

  /// Optional due date for the task
  final DateTime? dueDate;

  /// Date when task was completed
  final DateTime? completedAt;

  /// User who completed the task (for shared notes)
  final String? completedBy;

  /// Line number or position in note (for sync with markdown)
  final int position;

  /// Hash of the task text for deduplication
  final String contentHash;

  /// Optional reminder ID if a reminder is set for this task
  /// MIGRATION v41: Changed from INTEGER to TEXT (UUID) to match NoteReminders.id
  final String? reminderId;

  /// Time estimate in minutes
  final int? estimatedMinutes;

  /// Actual time spent in minutes
  final int? actualMinutes;

  /// Parent task ID for subtasks
  final String? parentTaskId;

  /// Creation timestamp
  final DateTime createdAt;

  /// Last modification timestamp
  final DateTime updatedAt;

  /// Soft delete flag
  final bool deleted;

  /// Soft delete timestamps (Migration 40)
  final DateTime? deletedAt;
  final DateTime? scheduledPurgeAt;
  const NoteTask({
    required this.id,
    required this.noteId,
    required this.userId,
    required this.contentEncrypted,
    this.labelsEncrypted,
    this.notesEncrypted,
    required this.encryptionVersion,
    required this.status,
    required this.priority,
    this.dueDate,
    this.completedAt,
    this.completedBy,
    required this.position,
    required this.contentHash,
    this.reminderId,
    this.estimatedMinutes,
    this.actualMinutes,
    this.parentTaskId,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    this.deletedAt,
    this.scheduledPurgeAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['note_id'] = Variable<String>(noteId);
    map['user_id'] = Variable<String>(userId);
    map['content_encrypted'] = Variable<String>(contentEncrypted);
    if (!nullToAbsent || labelsEncrypted != null) {
      map['labels_encrypted'] = Variable<String>(labelsEncrypted);
    }
    if (!nullToAbsent || notesEncrypted != null) {
      map['notes_encrypted'] = Variable<String>(notesEncrypted);
    }
    map['encryption_version'] = Variable<int>(encryptionVersion);
    {
      map['status'] = Variable<int>(
        $NoteTasksTable.$converterstatus.toSql(status),
      );
    }
    {
      map['priority'] = Variable<int>(
        $NoteTasksTable.$converterpriority.toSql(priority),
      );
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || completedBy != null) {
      map['completed_by'] = Variable<String>(completedBy);
    }
    map['position'] = Variable<int>(position);
    map['content_hash'] = Variable<String>(contentHash);
    if (!nullToAbsent || reminderId != null) {
      map['reminder_id'] = Variable<String>(reminderId);
    }
    if (!nullToAbsent || estimatedMinutes != null) {
      map['estimated_minutes'] = Variable<int>(estimatedMinutes);
    }
    if (!nullToAbsent || actualMinutes != null) {
      map['actual_minutes'] = Variable<int>(actualMinutes);
    }
    if (!nullToAbsent || parentTaskId != null) {
      map['parent_task_id'] = Variable<String>(parentTaskId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || scheduledPurgeAt != null) {
      map['scheduled_purge_at'] = Variable<DateTime>(scheduledPurgeAt);
    }
    return map;
  }

  NoteTasksCompanion toCompanion(bool nullToAbsent) {
    return NoteTasksCompanion(
      id: Value(id),
      noteId: Value(noteId),
      userId: Value(userId),
      contentEncrypted: Value(contentEncrypted),
      labelsEncrypted: labelsEncrypted == null && nullToAbsent
          ? const Value.absent()
          : Value(labelsEncrypted),
      notesEncrypted: notesEncrypted == null && nullToAbsent
          ? const Value.absent()
          : Value(notesEncrypted),
      encryptionVersion: Value(encryptionVersion),
      status: Value(status),
      priority: Value(priority),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      completedBy: completedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(completedBy),
      position: Value(position),
      contentHash: Value(contentHash),
      reminderId: reminderId == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderId),
      estimatedMinutes: estimatedMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedMinutes),
      actualMinutes: actualMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(actualMinutes),
      parentTaskId: parentTaskId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentTaskId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      scheduledPurgeAt: scheduledPurgeAt == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledPurgeAt),
    );
  }

  factory NoteTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteTask(
      id: serializer.fromJson<String>(json['id']),
      noteId: serializer.fromJson<String>(json['noteId']),
      userId: serializer.fromJson<String>(json['userId']),
      contentEncrypted: serializer.fromJson<String>(json['contentEncrypted']),
      labelsEncrypted: serializer.fromJson<String?>(json['labelsEncrypted']),
      notesEncrypted: serializer.fromJson<String?>(json['notesEncrypted']),
      encryptionVersion: serializer.fromJson<int>(json['encryptionVersion']),
      status: $NoteTasksTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      priority: $NoteTasksTable.$converterpriority.fromJson(
        serializer.fromJson<int>(json['priority']),
      ),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      completedBy: serializer.fromJson<String?>(json['completedBy']),
      position: serializer.fromJson<int>(json['position']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      reminderId: serializer.fromJson<String?>(json['reminderId']),
      estimatedMinutes: serializer.fromJson<int?>(json['estimatedMinutes']),
      actualMinutes: serializer.fromJson<int?>(json['actualMinutes']),
      parentTaskId: serializer.fromJson<String?>(json['parentTaskId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      scheduledPurgeAt: serializer.fromJson<DateTime?>(
        json['scheduledPurgeAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteId': serializer.toJson<String>(noteId),
      'userId': serializer.toJson<String>(userId),
      'contentEncrypted': serializer.toJson<String>(contentEncrypted),
      'labelsEncrypted': serializer.toJson<String?>(labelsEncrypted),
      'notesEncrypted': serializer.toJson<String?>(notesEncrypted),
      'encryptionVersion': serializer.toJson<int>(encryptionVersion),
      'status': serializer.toJson<int>(
        $NoteTasksTable.$converterstatus.toJson(status),
      ),
      'priority': serializer.toJson<int>(
        $NoteTasksTable.$converterpriority.toJson(priority),
      ),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'completedBy': serializer.toJson<String?>(completedBy),
      'position': serializer.toJson<int>(position),
      'contentHash': serializer.toJson<String>(contentHash),
      'reminderId': serializer.toJson<String?>(reminderId),
      'estimatedMinutes': serializer.toJson<int?>(estimatedMinutes),
      'actualMinutes': serializer.toJson<int?>(actualMinutes),
      'parentTaskId': serializer.toJson<String?>(parentTaskId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'scheduledPurgeAt': serializer.toJson<DateTime?>(scheduledPurgeAt),
    };
  }

  NoteTask copyWith({
    String? id,
    String? noteId,
    String? userId,
    String? contentEncrypted,
    Value<String?> labelsEncrypted = const Value.absent(),
    Value<String?> notesEncrypted = const Value.absent(),
    int? encryptionVersion,
    TaskStatus? status,
    TaskPriority? priority,
    Value<DateTime?> dueDate = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    Value<String?> completedBy = const Value.absent(),
    int? position,
    String? contentHash,
    Value<String?> reminderId = const Value.absent(),
    Value<int?> estimatedMinutes = const Value.absent(),
    Value<int?> actualMinutes = const Value.absent(),
    Value<String?> parentTaskId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<DateTime?> scheduledPurgeAt = const Value.absent(),
  }) => NoteTask(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    userId: userId ?? this.userId,
    contentEncrypted: contentEncrypted ?? this.contentEncrypted,
    labelsEncrypted: labelsEncrypted.present
        ? labelsEncrypted.value
        : this.labelsEncrypted,
    notesEncrypted: notesEncrypted.present
        ? notesEncrypted.value
        : this.notesEncrypted,
    encryptionVersion: encryptionVersion ?? this.encryptionVersion,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    completedBy: completedBy.present ? completedBy.value : this.completedBy,
    position: position ?? this.position,
    contentHash: contentHash ?? this.contentHash,
    reminderId: reminderId.present ? reminderId.value : this.reminderId,
    estimatedMinutes: estimatedMinutes.present
        ? estimatedMinutes.value
        : this.estimatedMinutes,
    actualMinutes: actualMinutes.present
        ? actualMinutes.value
        : this.actualMinutes,
    parentTaskId: parentTaskId.present ? parentTaskId.value : this.parentTaskId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    scheduledPurgeAt: scheduledPurgeAt.present
        ? scheduledPurgeAt.value
        : this.scheduledPurgeAt,
  );
  NoteTask copyWithCompanion(NoteTasksCompanion data) {
    return NoteTask(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      userId: data.userId.present ? data.userId.value : this.userId,
      contentEncrypted: data.contentEncrypted.present
          ? data.contentEncrypted.value
          : this.contentEncrypted,
      labelsEncrypted: data.labelsEncrypted.present
          ? data.labelsEncrypted.value
          : this.labelsEncrypted,
      notesEncrypted: data.notesEncrypted.present
          ? data.notesEncrypted.value
          : this.notesEncrypted,
      encryptionVersion: data.encryptionVersion.present
          ? data.encryptionVersion.value
          : this.encryptionVersion,
      status: data.status.present ? data.status.value : this.status,
      priority: data.priority.present ? data.priority.value : this.priority,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      completedBy: data.completedBy.present
          ? data.completedBy.value
          : this.completedBy,
      position: data.position.present ? data.position.value : this.position,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      reminderId: data.reminderId.present
          ? data.reminderId.value
          : this.reminderId,
      estimatedMinutes: data.estimatedMinutes.present
          ? data.estimatedMinutes.value
          : this.estimatedMinutes,
      actualMinutes: data.actualMinutes.present
          ? data.actualMinutes.value
          : this.actualMinutes,
      parentTaskId: data.parentTaskId.present
          ? data.parentTaskId.value
          : this.parentTaskId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      scheduledPurgeAt: data.scheduledPurgeAt.present
          ? data.scheduledPurgeAt.value
          : this.scheduledPurgeAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteTask(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('userId: $userId, ')
          ..write('contentEncrypted: $contentEncrypted, ')
          ..write('labelsEncrypted: $labelsEncrypted, ')
          ..write('notesEncrypted: $notesEncrypted, ')
          ..write('encryptionVersion: $encryptionVersion, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('dueDate: $dueDate, ')
          ..write('completedAt: $completedAt, ')
          ..write('completedBy: $completedBy, ')
          ..write('position: $position, ')
          ..write('contentHash: $contentHash, ')
          ..write('reminderId: $reminderId, ')
          ..write('estimatedMinutes: $estimatedMinutes, ')
          ..write('actualMinutes: $actualMinutes, ')
          ..write('parentTaskId: $parentTaskId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('scheduledPurgeAt: $scheduledPurgeAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    noteId,
    userId,
    contentEncrypted,
    labelsEncrypted,
    notesEncrypted,
    encryptionVersion,
    status,
    priority,
    dueDate,
    completedAt,
    completedBy,
    position,
    contentHash,
    reminderId,
    estimatedMinutes,
    actualMinutes,
    parentTaskId,
    createdAt,
    updatedAt,
    deleted,
    deletedAt,
    scheduledPurgeAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteTask &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.userId == this.userId &&
          other.contentEncrypted == this.contentEncrypted &&
          other.labelsEncrypted == this.labelsEncrypted &&
          other.notesEncrypted == this.notesEncrypted &&
          other.encryptionVersion == this.encryptionVersion &&
          other.status == this.status &&
          other.priority == this.priority &&
          other.dueDate == this.dueDate &&
          other.completedAt == this.completedAt &&
          other.completedBy == this.completedBy &&
          other.position == this.position &&
          other.contentHash == this.contentHash &&
          other.reminderId == this.reminderId &&
          other.estimatedMinutes == this.estimatedMinutes &&
          other.actualMinutes == this.actualMinutes &&
          other.parentTaskId == this.parentTaskId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.deletedAt == this.deletedAt &&
          other.scheduledPurgeAt == this.scheduledPurgeAt);
}

class NoteTasksCompanion extends UpdateCompanion<NoteTask> {
  final Value<String> id;
  final Value<String> noteId;
  final Value<String> userId;
  final Value<String> contentEncrypted;
  final Value<String?> labelsEncrypted;
  final Value<String?> notesEncrypted;
  final Value<int> encryptionVersion;
  final Value<TaskStatus> status;
  final Value<TaskPriority> priority;
  final Value<DateTime?> dueDate;
  final Value<DateTime?> completedAt;
  final Value<String?> completedBy;
  final Value<int> position;
  final Value<String> contentHash;
  final Value<String?> reminderId;
  final Value<int?> estimatedMinutes;
  final Value<int?> actualMinutes;
  final Value<String?> parentTaskId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<DateTime?> deletedAt;
  final Value<DateTime?> scheduledPurgeAt;
  final Value<int> rowid;
  const NoteTasksCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.userId = const Value.absent(),
    this.contentEncrypted = const Value.absent(),
    this.labelsEncrypted = const Value.absent(),
    this.notesEncrypted = const Value.absent(),
    this.encryptionVersion = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.completedBy = const Value.absent(),
    this.position = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.reminderId = const Value.absent(),
    this.estimatedMinutes = const Value.absent(),
    this.actualMinutes = const Value.absent(),
    this.parentTaskId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.scheduledPurgeAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteTasksCompanion.insert({
    required String id,
    required String noteId,
    required String userId,
    required String contentEncrypted,
    this.labelsEncrypted = const Value.absent(),
    this.notesEncrypted = const Value.absent(),
    this.encryptionVersion = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.completedBy = const Value.absent(),
    this.position = const Value.absent(),
    required String contentHash,
    this.reminderId = const Value.absent(),
    this.estimatedMinutes = const Value.absent(),
    this.actualMinutes = const Value.absent(),
    this.parentTaskId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.scheduledPurgeAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       noteId = Value(noteId),
       userId = Value(userId),
       contentEncrypted = Value(contentEncrypted),
       contentHash = Value(contentHash);
  static Insertable<NoteTask> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<String>? userId,
    Expression<String>? contentEncrypted,
    Expression<String>? labelsEncrypted,
    Expression<String>? notesEncrypted,
    Expression<int>? encryptionVersion,
    Expression<int>? status,
    Expression<int>? priority,
    Expression<DateTime>? dueDate,
    Expression<DateTime>? completedAt,
    Expression<String>? completedBy,
    Expression<int>? position,
    Expression<String>? contentHash,
    Expression<String>? reminderId,
    Expression<int>? estimatedMinutes,
    Expression<int>? actualMinutes,
    Expression<String>? parentTaskId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? scheduledPurgeAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (userId != null) 'user_id': userId,
      if (contentEncrypted != null) 'content_encrypted': contentEncrypted,
      if (labelsEncrypted != null) 'labels_encrypted': labelsEncrypted,
      if (notesEncrypted != null) 'notes_encrypted': notesEncrypted,
      if (encryptionVersion != null) 'encryption_version': encryptionVersion,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (dueDate != null) 'due_date': dueDate,
      if (completedAt != null) 'completed_at': completedAt,
      if (completedBy != null) 'completed_by': completedBy,
      if (position != null) 'position': position,
      if (contentHash != null) 'content_hash': contentHash,
      if (reminderId != null) 'reminder_id': reminderId,
      if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
      if (actualMinutes != null) 'actual_minutes': actualMinutes,
      if (parentTaskId != null) 'parent_task_id': parentTaskId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (scheduledPurgeAt != null) 'scheduled_purge_at': scheduledPurgeAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteTasksCompanion copyWith({
    Value<String>? id,
    Value<String>? noteId,
    Value<String>? userId,
    Value<String>? contentEncrypted,
    Value<String?>? labelsEncrypted,
    Value<String?>? notesEncrypted,
    Value<int>? encryptionVersion,
    Value<TaskStatus>? status,
    Value<TaskPriority>? priority,
    Value<DateTime?>? dueDate,
    Value<DateTime?>? completedAt,
    Value<String?>? completedBy,
    Value<int>? position,
    Value<String>? contentHash,
    Value<String?>? reminderId,
    Value<int?>? estimatedMinutes,
    Value<int?>? actualMinutes,
    Value<String?>? parentTaskId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<DateTime?>? deletedAt,
    Value<DateTime?>? scheduledPurgeAt,
    Value<int>? rowid,
  }) {
    return NoteTasksCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      userId: userId ?? this.userId,
      contentEncrypted: contentEncrypted ?? this.contentEncrypted,
      labelsEncrypted: labelsEncrypted ?? this.labelsEncrypted,
      notesEncrypted: notesEncrypted ?? this.notesEncrypted,
      encryptionVersion: encryptionVersion ?? this.encryptionVersion,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      position: position ?? this.position,
      contentHash: contentHash ?? this.contentHash,
      reminderId: reminderId ?? this.reminderId,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      scheduledPurgeAt: scheduledPurgeAt ?? this.scheduledPurgeAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (contentEncrypted.present) {
      map['content_encrypted'] = Variable<String>(contentEncrypted.value);
    }
    if (labelsEncrypted.present) {
      map['labels_encrypted'] = Variable<String>(labelsEncrypted.value);
    }
    if (notesEncrypted.present) {
      map['notes_encrypted'] = Variable<String>(notesEncrypted.value);
    }
    if (encryptionVersion.present) {
      map['encryption_version'] = Variable<int>(encryptionVersion.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $NoteTasksTable.$converterstatus.toSql(status.value),
      );
    }
    if (priority.present) {
      map['priority'] = Variable<int>(
        $NoteTasksTable.$converterpriority.toSql(priority.value),
      );
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (completedBy.present) {
      map['completed_by'] = Variable<String>(completedBy.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (reminderId.present) {
      map['reminder_id'] = Variable<String>(reminderId.value);
    }
    if (estimatedMinutes.present) {
      map['estimated_minutes'] = Variable<int>(estimatedMinutes.value);
    }
    if (actualMinutes.present) {
      map['actual_minutes'] = Variable<int>(actualMinutes.value);
    }
    if (parentTaskId.present) {
      map['parent_task_id'] = Variable<String>(parentTaskId.value);
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
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (scheduledPurgeAt.present) {
      map['scheduled_purge_at'] = Variable<DateTime>(scheduledPurgeAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTasksCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('userId: $userId, ')
          ..write('contentEncrypted: $contentEncrypted, ')
          ..write('labelsEncrypted: $labelsEncrypted, ')
          ..write('notesEncrypted: $notesEncrypted, ')
          ..write('encryptionVersion: $encryptionVersion, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('dueDate: $dueDate, ')
          ..write('completedAt: $completedAt, ')
          ..write('completedBy: $completedBy, ')
          ..write('position: $position, ')
          ..write('contentHash: $contentHash, ')
          ..write('reminderId: $reminderId, ')
          ..write('estimatedMinutes: $estimatedMinutes, ')
          ..write('actualMinutes: $actualMinutes, ')
          ..write('parentTaskId: $parentTaskId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('scheduledPurgeAt: $scheduledPurgeAt, ')
          ..write('rowid: $rowid')
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
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledPurgeAtMeta = const VerificationMeta(
    'scheduledPurgeAt',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledPurgeAt =
      GeneratedColumn<DateTime>(
        'scheduled_purge_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
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
    deletedAt,
    scheduledPurgeAt,
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
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('scheduled_purge_at')) {
      context.handle(
        _scheduledPurgeAtMeta,
        scheduledPurgeAt.isAcceptableOrUnknown(
          data['scheduled_purge_at']!,
          _scheduledPurgeAtMeta,
        ),
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
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
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
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      scheduledPurgeAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_purge_at'],
      ),
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

  /// User ID who owns this folder
  final String userId;

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

  /// Soft delete timestamps (Migration 40)
  final DateTime? deletedAt;
  final DateTime? scheduledPurgeAt;
  const LocalFolder({
    required this.id,
    required this.userId,
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
    this.deletedAt,
    this.scheduledPurgeAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
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
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || scheduledPurgeAt != null) {
      map['scheduled_purge_at'] = Variable<DateTime>(scheduledPurgeAt);
    }
    return map;
  }

  LocalFoldersCompanion toCompanion(bool nullToAbsent) {
    return LocalFoldersCompanion(
      id: Value(id),
      userId: Value(userId),
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
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      scheduledPurgeAt: scheduledPurgeAt == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledPurgeAt),
    );
  }

  factory LocalFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFolder(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
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
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      scheduledPurgeAt: serializer.fromJson<DateTime?>(
        json['scheduledPurgeAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
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
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'scheduledPurgeAt': serializer.toJson<DateTime?>(scheduledPurgeAt),
    };
  }

  LocalFolder copyWith({
    String? id,
    String? userId,
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
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<DateTime?> scheduledPurgeAt = const Value.absent(),
  }) => LocalFolder(
    id: id ?? this.id,
    userId: userId ?? this.userId,
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
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    scheduledPurgeAt: scheduledPurgeAt.present
        ? scheduledPurgeAt.value
        : this.scheduledPurgeAt,
  );
  LocalFolder copyWithCompanion(LocalFoldersCompanion data) {
    return LocalFolder(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
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
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      scheduledPurgeAt: data.scheduledPurgeAt.present
          ? data.scheduledPurgeAt.value
          : this.scheduledPurgeAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFolder(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
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
          ..write('deletedAt: $deletedAt, ')
          ..write('scheduledPurgeAt: $scheduledPurgeAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
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
    deletedAt,
    scheduledPurgeAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFolder &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.parentId == this.parentId &&
          other.path == this.path &&
          other.sortOrder == this.sortOrder &&
          other.color == this.color &&
          other.icon == this.icon &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.deletedAt == this.deletedAt &&
          other.scheduledPurgeAt == this.scheduledPurgeAt);
}

class LocalFoldersCompanion extends UpdateCompanion<LocalFolder> {
  final Value<String> id;
  final Value<String> userId;
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
  final Value<DateTime?> deletedAt;
  final Value<DateTime?> scheduledPurgeAt;
  final Value<int> rowid;
  const LocalFoldersCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
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
    this.deletedAt = const Value.absent(),
    this.scheduledPurgeAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFoldersCompanion.insert({
    required String id,
    required String userId,
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
    this.deletedAt = const Value.absent(),
    this.scheduledPurgeAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       name = Value(name),
       path = Value(path),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalFolder> custom({
    Expression<String>? id,
    Expression<String>? userId,
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
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? scheduledPurgeAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
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
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (scheduledPurgeAt != null) 'scheduled_purge_at': scheduledPurgeAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
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
    Value<DateTime?>? deletedAt,
    Value<DateTime?>? scheduledPurgeAt,
    Value<int>? rowid,
  }) {
    return LocalFoldersCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
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
      deletedAt: deletedAt ?? this.deletedAt,
      scheduledPurgeAt: scheduledPurgeAt ?? this.scheduledPurgeAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
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
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (scheduledPurgeAt.present) {
      map['scheduled_purge_at'] = Variable<DateTime>(scheduledPurgeAt.value);
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
          ..write('userId: $userId, ')
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
          ..write('deletedAt: $deletedAt, ')
          ..write('scheduledPurgeAt: $scheduledPurgeAt, ')
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    noteId,
    folderId,
    addedAt,
    updatedAt,
    userId,
  ];
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
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
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
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

  /// Last update timestamp for sorting and performance indexes
  final DateTime updatedAt;

  /// User ID who owns this relationship
  final String userId;
  const NoteFolder({
    required this.noteId,
    required this.folderId,
    required this.addedAt,
    required this.updatedAt,
    required this.userId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id'] = Variable<String>(noteId);
    map['folder_id'] = Variable<String>(folderId);
    map['added_at'] = Variable<DateTime>(addedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['user_id'] = Variable<String>(userId);
    return map;
  }

  NoteFoldersCompanion toCompanion(bool nullToAbsent) {
    return NoteFoldersCompanion(
      noteId: Value(noteId),
      folderId: Value(folderId),
      addedAt: Value(addedAt),
      updatedAt: Value(updatedAt),
      userId: Value(userId),
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
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      userId: serializer.fromJson<String>(json['userId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId': serializer.toJson<String>(noteId),
      'folderId': serializer.toJson<String>(folderId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'userId': serializer.toJson<String>(userId),
    };
  }

  NoteFolder copyWith({
    String? noteId,
    String? folderId,
    DateTime? addedAt,
    DateTime? updatedAt,
    String? userId,
  }) => NoteFolder(
    noteId: noteId ?? this.noteId,
    folderId: folderId ?? this.folderId,
    addedAt: addedAt ?? this.addedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    userId: userId ?? this.userId,
  );
  NoteFolder copyWithCompanion(NoteFoldersCompanion data) {
    return NoteFolder(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      userId: data.userId.present ? data.userId.value : this.userId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteFolder(')
          ..write('noteId: $noteId, ')
          ..write('folderId: $folderId, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('userId: $userId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(noteId, folderId, addedAt, updatedAt, userId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteFolder &&
          other.noteId == this.noteId &&
          other.folderId == this.folderId &&
          other.addedAt == this.addedAt &&
          other.updatedAt == this.updatedAt &&
          other.userId == this.userId);
}

class NoteFoldersCompanion extends UpdateCompanion<NoteFolder> {
  final Value<String> noteId;
  final Value<String> folderId;
  final Value<DateTime> addedAt;
  final Value<DateTime> updatedAt;
  final Value<String> userId;
  final Value<int> rowid;
  const NoteFoldersCompanion({
    this.noteId = const Value.absent(),
    this.folderId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.userId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteFoldersCompanion.insert({
    required String noteId,
    required String folderId,
    required DateTime addedAt,
    this.updatedAt = const Value.absent(),
    required String userId,
    this.rowid = const Value.absent(),
  }) : noteId = Value(noteId),
       folderId = Value(folderId),
       addedAt = Value(addedAt),
       userId = Value(userId);
  static Insertable<NoteFolder> custom({
    Expression<String>? noteId,
    Expression<String>? folderId,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? userId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (noteId != null) 'note_id': noteId,
      if (folderId != null) 'folder_id': folderId,
      if (addedAt != null) 'added_at': addedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (userId != null) 'user_id': userId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteFoldersCompanion copyWith({
    Value<String>? noteId,
    Value<String>? folderId,
    Value<DateTime>? addedAt,
    Value<DateTime>? updatedAt,
    Value<String>? userId,
    Value<int>? rowid,
  }) {
    return NoteFoldersCompanion(
      noteId: noteId ?? this.noteId,
      folderId: folderId ?? this.folderId,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
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
          ..write('updatedAt: $updatedAt, ')
          ..write('userId: $userId, ')
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
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    userId,
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
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
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
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
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

  /// User ID who owns this saved search
  /// Nullable to support migration scenarios where userId is populated later
  final String? userId;

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
    this.userId,
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
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
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
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
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
      userId: serializer.fromJson<String?>(json['userId']),
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
      'userId': serializer.toJson<String?>(userId),
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
    Value<String?> userId = const Value.absent(),
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
    userId: userId.present ? userId.value : this.userId,
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
      userId: data.userId.present ? data.userId.value : this.userId,
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
          ..write('userId: $userId, ')
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
    userId,
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
          other.userId == this.userId &&
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
  final Value<String?> userId;
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
    this.userId = const Value.absent(),
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
    this.userId = const Value.absent(),
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
    Expression<String>? userId,
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
      if (userId != null) 'user_id': userId,
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
    Value<String?>? userId,
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
      userId: userId ?? this.userId,
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
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
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
          ..write('userId: $userId, ')
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

class $LocalTemplatesTable extends LocalTemplates
    with TableInfo<$LocalTemplatesTable, LocalTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _isSystemMeta = const VerificationMeta(
    'isSystem',
  );
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
    'is_system',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_system" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
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
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    title,
    body,
    tags,
    isSystem,
    category,
    description,
    icon,
    sortOrder,
    metadata,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('is_system')) {
      context.handle(
        _isSystemMeta,
        isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      isSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_system'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalTemplatesTable createAlias(String alias) {
    return $LocalTemplatesTable(attachedDatabase, alias);
  }
}

class LocalTemplate extends DataClass implements Insertable<LocalTemplate> {
  /// Unique identifier for the template
  final String id;

  /// User ID who owns this template (null for system templates)
  final String? userId;

  /// Template title
  final String title;

  /// Template body/content
  final String body;

  /// Associated tags (JSON array)
  final String tags;

  /// Whether this is a system template (true) or user-created (false)
  final bool isSystem;

  /// Template category (work, personal, meeting, etc.)
  final String category;

  /// Short description for the template
  final String description;

  /// Icon identifier for UI display
  final String icon;

  /// Display order in template picker
  final int sortOrder;

  /// Additional metadata (JSON)
  final String? metadata;

  /// Creation timestamp
  final DateTime createdAt;

  /// Last modification timestamp
  final DateTime updatedAt;
  const LocalTemplate({
    required this.id,
    this.userId,
    required this.title,
    required this.body,
    required this.tags,
    required this.isSystem,
    required this.category,
    required this.description,
    required this.icon,
    required this.sortOrder,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['tags'] = Variable<String>(tags);
    map['is_system'] = Variable<bool>(isSystem);
    map['category'] = Variable<String>(category);
    map['description'] = Variable<String>(description);
    map['icon'] = Variable<String>(icon);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalTemplatesCompanion toCompanion(bool nullToAbsent) {
    return LocalTemplatesCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      title: Value(title),
      body: Value(body),
      tags: Value(tags),
      isSystem: Value(isSystem),
      category: Value(category),
      description: Value(description),
      icon: Value(icon),
      sortOrder: Value(sortOrder),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTemplate(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      tags: serializer.fromJson<String>(json['tags']),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
      category: serializer.fromJson<String>(json['category']),
      description: serializer.fromJson<String>(json['description']),
      icon: serializer.fromJson<String>(json['icon']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      metadata: serializer.fromJson<String?>(json['metadata']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'tags': serializer.toJson<String>(tags),
      'isSystem': serializer.toJson<bool>(isSystem),
      'category': serializer.toJson<String>(category),
      'description': serializer.toJson<String>(description),
      'icon': serializer.toJson<String>(icon),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'metadata': serializer.toJson<String?>(metadata),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalTemplate copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    String? title,
    String? body,
    String? tags,
    bool? isSystem,
    String? category,
    String? description,
    String? icon,
    int? sortOrder,
    Value<String?> metadata = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LocalTemplate(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    title: title ?? this.title,
    body: body ?? this.body,
    tags: tags ?? this.tags,
    isSystem: isSystem ?? this.isSystem,
    category: category ?? this.category,
    description: description ?? this.description,
    icon: icon ?? this.icon,
    sortOrder: sortOrder ?? this.sortOrder,
    metadata: metadata.present ? metadata.value : this.metadata,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalTemplate copyWithCompanion(LocalTemplatesCompanion data) {
    return LocalTemplate(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      tags: data.tags.present ? data.tags.value : this.tags,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
      category: data.category.present ? data.category.value : this.category,
      description: data.description.present
          ? data.description.value
          : this.description,
      icon: data.icon.present ? data.icon.value : this.icon,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTemplate(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('tags: $tags, ')
          ..write('isSystem: $isSystem, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    title,
    body,
    tags,
    isSystem,
    category,
    description,
    icon,
    sortOrder,
    metadata,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTemplate &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.title == this.title &&
          other.body == this.body &&
          other.tags == this.tags &&
          other.isSystem == this.isSystem &&
          other.category == this.category &&
          other.description == this.description &&
          other.icon == this.icon &&
          other.sortOrder == this.sortOrder &&
          other.metadata == this.metadata &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalTemplatesCompanion extends UpdateCompanion<LocalTemplate> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String> title;
  final Value<String> body;
  final Value<String> tags;
  final Value<bool> isSystem;
  final Value<String> category;
  final Value<String> description;
  final Value<String> icon;
  final Value<int> sortOrder;
  final Value<String?> metadata;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalTemplatesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.tags = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.category = const Value.absent(),
    this.description = const Value.absent(),
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.metadata = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTemplatesCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    required String title,
    required String body,
    this.tags = const Value.absent(),
    this.isSystem = const Value.absent(),
    required String category,
    required String description,
    required String icon,
    this.sortOrder = const Value.absent(),
    this.metadata = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       body = Value(body),
       category = Value(category),
       description = Value(description),
       icon = Value(icon),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalTemplate> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? tags,
    Expression<bool>? isSystem,
    Expression<String>? category,
    Expression<String>? description,
    Expression<String>? icon,
    Expression<int>? sortOrder,
    Expression<String>? metadata,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (tags != null) 'tags': tags,
      if (isSystem != null) 'is_system': isSystem,
      if (category != null) 'category': category,
      if (description != null) 'description': description,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (metadata != null) 'metadata': metadata,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTemplatesCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String>? title,
    Value<String>? body,
    Value<String>? tags,
    Value<bool>? isSystem,
    Value<String>? category,
    Value<String>? description,
    Value<String>? icon,
    Value<int>? sortOrder,
    Value<String?>? metadata,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalTemplatesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      tags: tags ?? this.tags,
      isSystem: isSystem ?? this.isSystem,
      category: category ?? this.category,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('tags: $tags, ')
          ..write('isSystem: $isSystem, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, LocalAttachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _filenameMeta = const VerificationMeta(
    'filename',
  );
  @override
  late final GeneratedColumn<String> filename = GeneratedColumn<String>(
    'filename',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    noteId,
    filename,
    mimeType,
    size,
    url,
    localPath,
    createdAt,
    metadata,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAttachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('filename')) {
      context.handle(
        _filenameMeta,
        filename.isAcceptableOrUnknown(data['filename']!, _filenameMeta),
      );
    } else if (isInserting) {
      context.missing(_filenameMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
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
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalAttachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAttachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      filename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filename'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class LocalAttachment extends DataClass implements Insertable<LocalAttachment> {
  /// Unique identifier for the attachment
  final String id;

  /// User ID who owns this attachment (SECURITY: prevents cross-user access)
  final String userId;

  /// Reference to parent note ID
  final String noteId;

  /// Original file name
  final String filename;

  /// MIME type (image/png, application/pdf, etc.)
  final String mimeType;

  /// File size in bytes
  final int size;

  /// Remote URL if uploaded to cloud storage
  final String? url;

  /// Local file path if stored locally
  final String? localPath;

  /// Upload/creation timestamp
  final DateTime createdAt;

  /// Additional metadata (JSON)
  final String metadata;
  const LocalAttachment({
    required this.id,
    required this.userId,
    required this.noteId,
    required this.filename,
    required this.mimeType,
    required this.size,
    this.url,
    this.localPath,
    required this.createdAt,
    required this.metadata,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['note_id'] = Variable<String>(noteId);
    map['filename'] = Variable<String>(filename);
    map['mime_type'] = Variable<String>(mimeType);
    map['size'] = Variable<int>(size);
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['metadata'] = Variable<String>(metadata);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      userId: Value(userId),
      noteId: Value(noteId),
      filename: Value(filename),
      mimeType: Value(mimeType),
      size: Value(size),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      createdAt: Value(createdAt),
      metadata: Value(metadata),
    );
  }

  factory LocalAttachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAttachment(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      noteId: serializer.fromJson<String>(json['noteId']),
      filename: serializer.fromJson<String>(json['filename']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      size: serializer.fromJson<int>(json['size']),
      url: serializer.fromJson<String?>(json['url']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      metadata: serializer.fromJson<String>(json['metadata']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'noteId': serializer.toJson<String>(noteId),
      'filename': serializer.toJson<String>(filename),
      'mimeType': serializer.toJson<String>(mimeType),
      'size': serializer.toJson<int>(size),
      'url': serializer.toJson<String?>(url),
      'localPath': serializer.toJson<String?>(localPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'metadata': serializer.toJson<String>(metadata),
    };
  }

  LocalAttachment copyWith({
    String? id,
    String? userId,
    String? noteId,
    String? filename,
    String? mimeType,
    int? size,
    Value<String?> url = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    DateTime? createdAt,
    String? metadata,
  }) => LocalAttachment(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    noteId: noteId ?? this.noteId,
    filename: filename ?? this.filename,
    mimeType: mimeType ?? this.mimeType,
    size: size ?? this.size,
    url: url.present ? url.value : this.url,
    localPath: localPath.present ? localPath.value : this.localPath,
    createdAt: createdAt ?? this.createdAt,
    metadata: metadata ?? this.metadata,
  );
  LocalAttachment copyWithCompanion(AttachmentsCompanion data) {
    return LocalAttachment(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      filename: data.filename.present ? data.filename.value : this.filename,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      size: data.size.present ? data.size.value : this.size,
      url: data.url.present ? data.url.value : this.url,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttachment(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('noteId: $noteId, ')
          ..write('filename: $filename, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('url: $url, ')
          ..write('localPath: $localPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    noteId,
    filename,
    mimeType,
    size,
    url,
    localPath,
    createdAt,
    metadata,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAttachment &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.noteId == this.noteId &&
          other.filename == this.filename &&
          other.mimeType == this.mimeType &&
          other.size == this.size &&
          other.url == this.url &&
          other.localPath == this.localPath &&
          other.createdAt == this.createdAt &&
          other.metadata == this.metadata);
}

class AttachmentsCompanion extends UpdateCompanion<LocalAttachment> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> noteId;
  final Value<String> filename;
  final Value<String> mimeType;
  final Value<int> size;
  final Value<String?> url;
  final Value<String?> localPath;
  final Value<DateTime> createdAt;
  final Value<String> metadata;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.noteId = const Value.absent(),
    this.filename = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.size = const Value.absent(),
    this.url = const Value.absent(),
    this.localPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.metadata = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    required String id,
    required String userId,
    required String noteId,
    required String filename,
    required String mimeType,
    required int size,
    this.url = const Value.absent(),
    this.localPath = const Value.absent(),
    required DateTime createdAt,
    this.metadata = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       noteId = Value(noteId),
       filename = Value(filename),
       mimeType = Value(mimeType),
       size = Value(size),
       createdAt = Value(createdAt);
  static Insertable<LocalAttachment> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? noteId,
    Expression<String>? filename,
    Expression<String>? mimeType,
    Expression<int>? size,
    Expression<String>? url,
    Expression<String>? localPath,
    Expression<DateTime>? createdAt,
    Expression<String>? metadata,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (noteId != null) 'note_id': noteId,
      if (filename != null) 'filename': filename,
      if (mimeType != null) 'mime_type': mimeType,
      if (size != null) 'size': size,
      if (url != null) 'url': url,
      if (localPath != null) 'local_path': localPath,
      if (createdAt != null) 'created_at': createdAt,
      if (metadata != null) 'metadata': metadata,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? noteId,
    Value<String>? filename,
    Value<String>? mimeType,
    Value<int>? size,
    Value<String?>? url,
    Value<String?>? localPath,
    Value<DateTime>? createdAt,
    Value<String>? metadata,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      noteId: noteId ?? this.noteId,
      filename: filename ?? this.filename,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      url: url ?? this.url,
      localPath: localPath ?? this.localPath,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (filename.present) {
      map['filename'] = Variable<String>(filename.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('noteId: $noteId, ')
          ..write('filename: $filename, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('url: $url, ')
          ..write('localPath: $localPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('metadata: $metadata, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InboxItemsTable extends InboxItems
    with TableInfo<$InboxItemsTable, InboxItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InboxItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _isProcessedMeta = const VerificationMeta(
    'isProcessed',
  );
  @override
  late final GeneratedColumn<bool> isProcessed = GeneratedColumn<bool>(
    'is_processed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_processed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _processedAtMeta = const VerificationMeta(
    'processedAt',
  );
  @override
  late final GeneratedColumn<DateTime> processedAt = GeneratedColumn<DateTime>(
    'processed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    sourceType,
    payload,
    createdAt,
    isProcessed,
    noteId,
    processedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inbox_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<InboxItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('is_processed')) {
      context.handle(
        _isProcessedMeta,
        isProcessed.isAcceptableOrUnknown(
          data['is_processed']!,
          _isProcessedMeta,
        ),
      );
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    }
    if (data.containsKey('processed_at')) {
      context.handle(
        _processedAtMeta,
        processedAt.isAcceptableOrUnknown(
          data['processed_at']!,
          _processedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InboxItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InboxItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      isProcessed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_processed'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      ),
      processedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}processed_at'],
      ),
    );
  }

  @override
  $InboxItemsTable createAlias(String alias) {
    return $InboxItemsTable(attachedDatabase, alias);
  }
}

class InboxItem extends DataClass implements Insertable<InboxItem> {
  /// Unique identifier for the inbox item
  final String id;

  /// User ID who owns this item
  final String userId;

  /// Source type: 'email_in' or 'web'
  final String sourceType;

  /// Payload data as JSON string
  final String payload;

  /// Creation timestamp
  final DateTime createdAt;

  /// Whether this item has been processed into a note
  final bool isProcessed;

  /// Reference to note ID if processed
  final String? noteId;

  /// When the item was processed
  final DateTime? processedAt;
  const InboxItem({
    required this.id,
    required this.userId,
    required this.sourceType,
    required this.payload,
    required this.createdAt,
    required this.isProcessed,
    this.noteId,
    this.processedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['source_type'] = Variable<String>(sourceType);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_processed'] = Variable<bool>(isProcessed);
    if (!nullToAbsent || noteId != null) {
      map['note_id'] = Variable<String>(noteId);
    }
    if (!nullToAbsent || processedAt != null) {
      map['processed_at'] = Variable<DateTime>(processedAt);
    }
    return map;
  }

  InboxItemsCompanion toCompanion(bool nullToAbsent) {
    return InboxItemsCompanion(
      id: Value(id),
      userId: Value(userId),
      sourceType: Value(sourceType),
      payload: Value(payload),
      createdAt: Value(createdAt),
      isProcessed: Value(isProcessed),
      noteId: noteId == null && nullToAbsent
          ? const Value.absent()
          : Value(noteId),
      processedAt: processedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(processedAt),
    );
  }

  factory InboxItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InboxItem(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isProcessed: serializer.fromJson<bool>(json['isProcessed']),
      noteId: serializer.fromJson<String?>(json['noteId']),
      processedAt: serializer.fromJson<DateTime?>(json['processedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'sourceType': serializer.toJson<String>(sourceType),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isProcessed': serializer.toJson<bool>(isProcessed),
      'noteId': serializer.toJson<String?>(noteId),
      'processedAt': serializer.toJson<DateTime?>(processedAt),
    };
  }

  InboxItem copyWith({
    String? id,
    String? userId,
    String? sourceType,
    String? payload,
    DateTime? createdAt,
    bool? isProcessed,
    Value<String?> noteId = const Value.absent(),
    Value<DateTime?> processedAt = const Value.absent(),
  }) => InboxItem(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    sourceType: sourceType ?? this.sourceType,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    isProcessed: isProcessed ?? this.isProcessed,
    noteId: noteId.present ? noteId.value : this.noteId,
    processedAt: processedAt.present ? processedAt.value : this.processedAt,
  );
  InboxItem copyWithCompanion(InboxItemsCompanion data) {
    return InboxItem(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isProcessed: data.isProcessed.present
          ? data.isProcessed.value
          : this.isProcessed,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      processedAt: data.processedAt.present
          ? data.processedAt.value
          : this.processedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InboxItem(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('sourceType: $sourceType, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('isProcessed: $isProcessed, ')
          ..write('noteId: $noteId, ')
          ..write('processedAt: $processedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    sourceType,
    payload,
    createdAt,
    isProcessed,
    noteId,
    processedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InboxItem &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.sourceType == this.sourceType &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.isProcessed == this.isProcessed &&
          other.noteId == this.noteId &&
          other.processedAt == this.processedAt);
}

class InboxItemsCompanion extends UpdateCompanion<InboxItem> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> sourceType;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<bool> isProcessed;
  final Value<String?> noteId;
  final Value<DateTime?> processedAt;
  final Value<int> rowid;
  const InboxItemsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isProcessed = const Value.absent(),
    this.noteId = const Value.absent(),
    this.processedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InboxItemsCompanion.insert({
    required String id,
    required String userId,
    required String sourceType,
    required String payload,
    required DateTime createdAt,
    this.isProcessed = const Value.absent(),
    this.noteId = const Value.absent(),
    this.processedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       sourceType = Value(sourceType),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<InboxItem> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? sourceType,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<bool>? isProcessed,
    Expression<String>? noteId,
    Expression<DateTime>? processedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (sourceType != null) 'source_type': sourceType,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (isProcessed != null) 'is_processed': isProcessed,
      if (noteId != null) 'note_id': noteId,
      if (processedAt != null) 'processed_at': processedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InboxItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? sourceType,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<bool>? isProcessed,
    Value<String?>? noteId,
    Value<DateTime?>? processedAt,
    Value<int>? rowid,
  }) {
    return InboxItemsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sourceType: sourceType ?? this.sourceType,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      isProcessed: isProcessed ?? this.isProcessed,
      noteId: noteId ?? this.noteId,
      processedAt: processedAt ?? this.processedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isProcessed.present) {
      map['is_processed'] = Variable<bool>(isProcessed.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (processedAt.present) {
      map['processed_at'] = Variable<DateTime>(processedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InboxItemsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('sourceType: $sourceType, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('isProcessed: $isProcessed, ')
          ..write('noteId: $noteId, ')
          ..write('processedAt: $processedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuickCaptureQueueEntriesTable extends QuickCaptureQueueEntries
    with TableInfo<$QuickCaptureQueueEntriesTable, QuickCaptureQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuickCaptureQueueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadEncryptedMeta = const VerificationMeta(
    'payloadEncrypted',
  );
  @override
  late final GeneratedColumn<String> payloadEncrypted = GeneratedColumn<String>(
    'payload_encrypted',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _processedMeta = const VerificationMeta(
    'processed',
  );
  @override
  late final GeneratedColumn<bool> processed = GeneratedColumn<bool>(
    'processed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("processed" IN (0, 1))',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _processedAtMeta = const VerificationMeta(
    'processedAt',
  );
  @override
  late final GeneratedColumn<DateTime> processedAt = GeneratedColumn<DateTime>(
    'processed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptionVersionMeta = const VerificationMeta(
    'encryptionVersion',
  );
  @override
  late final GeneratedColumn<int> encryptionVersion = GeneratedColumn<int>(
    'encryption_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    payloadEncrypted,
    platform,
    retryCount,
    processed,
    createdAt,
    updatedAt,
    processedAt,
    encryptionVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quick_capture_queue_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuickCaptureQueueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('payload_encrypted')) {
      context.handle(
        _payloadEncryptedMeta,
        payloadEncrypted.isAcceptableOrUnknown(
          data['payload_encrypted']!,
          _payloadEncryptedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadEncryptedMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('processed')) {
      context.handle(
        _processedMeta,
        processed.isAcceptableOrUnknown(data['processed']!, _processedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('processed_at')) {
      context.handle(
        _processedAtMeta,
        processedAt.isAcceptableOrUnknown(
          data['processed_at']!,
          _processedAtMeta,
        ),
      );
    }
    if (data.containsKey('encryption_version')) {
      context.handle(
        _encryptionVersionMeta,
        encryptionVersion.isAcceptableOrUnknown(
          data['encryption_version']!,
          _encryptionVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuickCaptureQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuickCaptureQueueEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      payloadEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_encrypted'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      ),
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      processed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}processed'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      processedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}processed_at'],
      ),
      encryptionVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}encryption_version'],
      )!,
    );
  }

  @override
  $QuickCaptureQueueEntriesTable createAlias(String alias) {
    return $QuickCaptureQueueEntriesTable(attachedDatabase, alias);
  }
}

class QuickCaptureQueueEntry extends DataClass
    implements Insertable<QuickCaptureQueueEntry> {
  final String id;
  final String userId;
  final String payloadEncrypted;
  final String? platform;
  final int retryCount;
  final bool processed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? processedAt;
  final int encryptionVersion;
  const QuickCaptureQueueEntry({
    required this.id,
    required this.userId,
    required this.payloadEncrypted,
    this.platform,
    required this.retryCount,
    required this.processed,
    required this.createdAt,
    required this.updatedAt,
    this.processedAt,
    required this.encryptionVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['payload_encrypted'] = Variable<String>(payloadEncrypted);
    if (!nullToAbsent || platform != null) {
      map['platform'] = Variable<String>(platform);
    }
    map['retry_count'] = Variable<int>(retryCount);
    map['processed'] = Variable<bool>(processed);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || processedAt != null) {
      map['processed_at'] = Variable<DateTime>(processedAt);
    }
    map['encryption_version'] = Variable<int>(encryptionVersion);
    return map;
  }

  QuickCaptureQueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return QuickCaptureQueueEntriesCompanion(
      id: Value(id),
      userId: Value(userId),
      payloadEncrypted: Value(payloadEncrypted),
      platform: platform == null && nullToAbsent
          ? const Value.absent()
          : Value(platform),
      retryCount: Value(retryCount),
      processed: Value(processed),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      processedAt: processedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(processedAt),
      encryptionVersion: Value(encryptionVersion),
    );
  }

  factory QuickCaptureQueueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuickCaptureQueueEntry(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      payloadEncrypted: serializer.fromJson<String>(json['payloadEncrypted']),
      platform: serializer.fromJson<String?>(json['platform']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      processed: serializer.fromJson<bool>(json['processed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      processedAt: serializer.fromJson<DateTime?>(json['processedAt']),
      encryptionVersion: serializer.fromJson<int>(json['encryptionVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'payloadEncrypted': serializer.toJson<String>(payloadEncrypted),
      'platform': serializer.toJson<String?>(platform),
      'retryCount': serializer.toJson<int>(retryCount),
      'processed': serializer.toJson<bool>(processed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'processedAt': serializer.toJson<DateTime?>(processedAt),
      'encryptionVersion': serializer.toJson<int>(encryptionVersion),
    };
  }

  QuickCaptureQueueEntry copyWith({
    String? id,
    String? userId,
    String? payloadEncrypted,
    Value<String?> platform = const Value.absent(),
    int? retryCount,
    bool? processed,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> processedAt = const Value.absent(),
    int? encryptionVersion,
  }) => QuickCaptureQueueEntry(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    payloadEncrypted: payloadEncrypted ?? this.payloadEncrypted,
    platform: platform.present ? platform.value : this.platform,
    retryCount: retryCount ?? this.retryCount,
    processed: processed ?? this.processed,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    processedAt: processedAt.present ? processedAt.value : this.processedAt,
    encryptionVersion: encryptionVersion ?? this.encryptionVersion,
  );
  QuickCaptureQueueEntry copyWithCompanion(
    QuickCaptureQueueEntriesCompanion data,
  ) {
    return QuickCaptureQueueEntry(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      payloadEncrypted: data.payloadEncrypted.present
          ? data.payloadEncrypted.value
          : this.payloadEncrypted,
      platform: data.platform.present ? data.platform.value : this.platform,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      processed: data.processed.present ? data.processed.value : this.processed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      processedAt: data.processedAt.present
          ? data.processedAt.value
          : this.processedAt,
      encryptionVersion: data.encryptionVersion.present
          ? data.encryptionVersion.value
          : this.encryptionVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuickCaptureQueueEntry(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('payloadEncrypted: $payloadEncrypted, ')
          ..write('platform: $platform, ')
          ..write('retryCount: $retryCount, ')
          ..write('processed: $processed, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('processedAt: $processedAt, ')
          ..write('encryptionVersion: $encryptionVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    payloadEncrypted,
    platform,
    retryCount,
    processed,
    createdAt,
    updatedAt,
    processedAt,
    encryptionVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuickCaptureQueueEntry &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.payloadEncrypted == this.payloadEncrypted &&
          other.platform == this.platform &&
          other.retryCount == this.retryCount &&
          other.processed == this.processed &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.processedAt == this.processedAt &&
          other.encryptionVersion == this.encryptionVersion);
}

class QuickCaptureQueueEntriesCompanion
    extends UpdateCompanion<QuickCaptureQueueEntry> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> payloadEncrypted;
  final Value<String?> platform;
  final Value<int> retryCount;
  final Value<bool> processed;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> processedAt;
  final Value<int> encryptionVersion;
  final Value<int> rowid;
  const QuickCaptureQueueEntriesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.payloadEncrypted = const Value.absent(),
    this.platform = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.processed = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.processedAt = const Value.absent(),
    this.encryptionVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuickCaptureQueueEntriesCompanion.insert({
    required String id,
    required String userId,
    required String payloadEncrypted,
    this.platform = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.processed = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.processedAt = const Value.absent(),
    this.encryptionVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       payloadEncrypted = Value(payloadEncrypted);
  static Insertable<QuickCaptureQueueEntry> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? payloadEncrypted,
    Expression<String>? platform,
    Expression<int>? retryCount,
    Expression<bool>? processed,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? processedAt,
    Expression<int>? encryptionVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (payloadEncrypted != null) 'payload_encrypted': payloadEncrypted,
      if (platform != null) 'platform': platform,
      if (retryCount != null) 'retry_count': retryCount,
      if (processed != null) 'processed': processed,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (processedAt != null) 'processed_at': processedAt,
      if (encryptionVersion != null) 'encryption_version': encryptionVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuickCaptureQueueEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? payloadEncrypted,
    Value<String?>? platform,
    Value<int>? retryCount,
    Value<bool>? processed,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? processedAt,
    Value<int>? encryptionVersion,
    Value<int>? rowid,
  }) {
    return QuickCaptureQueueEntriesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      payloadEncrypted: payloadEncrypted ?? this.payloadEncrypted,
      platform: platform ?? this.platform,
      retryCount: retryCount ?? this.retryCount,
      processed: processed ?? this.processed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      processedAt: processedAt ?? this.processedAt,
      encryptionVersion: encryptionVersion ?? this.encryptionVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (payloadEncrypted.present) {
      map['payload_encrypted'] = Variable<String>(payloadEncrypted.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (processed.present) {
      map['processed'] = Variable<bool>(processed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (processedAt.present) {
      map['processed_at'] = Variable<DateTime>(processedAt.value);
    }
    if (encryptionVersion.present) {
      map['encryption_version'] = Variable<int>(encryptionVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuickCaptureQueueEntriesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('payloadEncrypted: $payloadEncrypted, ')
          ..write('platform: $platform, ')
          ..write('retryCount: $retryCount, ')
          ..write('processed: $processed, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('processedAt: $processedAt, ')
          ..write('encryptionVersion: $encryptionVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuickCaptureWidgetCacheEntriesTable
    extends QuickCaptureWidgetCacheEntries
    with
        TableInfo<
          $QuickCaptureWidgetCacheEntriesTable,
          QuickCaptureWidgetCacheEntry
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuickCaptureWidgetCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataEncryptedMeta = const VerificationMeta(
    'dataEncrypted',
  );
  @override
  late final GeneratedColumn<String> dataEncrypted = GeneratedColumn<String>(
    'data_encrypted',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _encryptionVersionMeta = const VerificationMeta(
    'encryptionVersion',
  );
  @override
  late final GeneratedColumn<int> encryptionVersion = GeneratedColumn<int>(
    'encryption_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    dataEncrypted,
    updatedAt,
    encryptionVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quick_capture_widget_cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuickCaptureWidgetCacheEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('data_encrypted')) {
      context.handle(
        _dataEncryptedMeta,
        dataEncrypted.isAcceptableOrUnknown(
          data['data_encrypted']!,
          _dataEncryptedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dataEncryptedMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('encryption_version')) {
      context.handle(
        _encryptionVersionMeta,
        encryptionVersion.isAcceptableOrUnknown(
          data['encryption_version']!,
          _encryptionVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  QuickCaptureWidgetCacheEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuickCaptureWidgetCacheEntry(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      dataEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_encrypted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      encryptionVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}encryption_version'],
      )!,
    );
  }

  @override
  $QuickCaptureWidgetCacheEntriesTable createAlias(String alias) {
    return $QuickCaptureWidgetCacheEntriesTable(attachedDatabase, alias);
  }
}

class QuickCaptureWidgetCacheEntry extends DataClass
    implements Insertable<QuickCaptureWidgetCacheEntry> {
  final String userId;
  final String dataEncrypted;
  final DateTime updatedAt;
  final int encryptionVersion;
  const QuickCaptureWidgetCacheEntry({
    required this.userId,
    required this.dataEncrypted,
    required this.updatedAt,
    required this.encryptionVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['data_encrypted'] = Variable<String>(dataEncrypted);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['encryption_version'] = Variable<int>(encryptionVersion);
    return map;
  }

  QuickCaptureWidgetCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return QuickCaptureWidgetCacheEntriesCompanion(
      userId: Value(userId),
      dataEncrypted: Value(dataEncrypted),
      updatedAt: Value(updatedAt),
      encryptionVersion: Value(encryptionVersion),
    );
  }

  factory QuickCaptureWidgetCacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuickCaptureWidgetCacheEntry(
      userId: serializer.fromJson<String>(json['userId']),
      dataEncrypted: serializer.fromJson<String>(json['dataEncrypted']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      encryptionVersion: serializer.fromJson<int>(json['encryptionVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'dataEncrypted': serializer.toJson<String>(dataEncrypted),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'encryptionVersion': serializer.toJson<int>(encryptionVersion),
    };
  }

  QuickCaptureWidgetCacheEntry copyWith({
    String? userId,
    String? dataEncrypted,
    DateTime? updatedAt,
    int? encryptionVersion,
  }) => QuickCaptureWidgetCacheEntry(
    userId: userId ?? this.userId,
    dataEncrypted: dataEncrypted ?? this.dataEncrypted,
    updatedAt: updatedAt ?? this.updatedAt,
    encryptionVersion: encryptionVersion ?? this.encryptionVersion,
  );
  QuickCaptureWidgetCacheEntry copyWithCompanion(
    QuickCaptureWidgetCacheEntriesCompanion data,
  ) {
    return QuickCaptureWidgetCacheEntry(
      userId: data.userId.present ? data.userId.value : this.userId,
      dataEncrypted: data.dataEncrypted.present
          ? data.dataEncrypted.value
          : this.dataEncrypted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      encryptionVersion: data.encryptionVersion.present
          ? data.encryptionVersion.value
          : this.encryptionVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuickCaptureWidgetCacheEntry(')
          ..write('userId: $userId, ')
          ..write('dataEncrypted: $dataEncrypted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('encryptionVersion: $encryptionVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(userId, dataEncrypted, updatedAt, encryptionVersion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuickCaptureWidgetCacheEntry &&
          other.userId == this.userId &&
          other.dataEncrypted == this.dataEncrypted &&
          other.updatedAt == this.updatedAt &&
          other.encryptionVersion == this.encryptionVersion);
}

class QuickCaptureWidgetCacheEntriesCompanion
    extends UpdateCompanion<QuickCaptureWidgetCacheEntry> {
  final Value<String> userId;
  final Value<String> dataEncrypted;
  final Value<DateTime> updatedAt;
  final Value<int> encryptionVersion;
  final Value<int> rowid;
  const QuickCaptureWidgetCacheEntriesCompanion({
    this.userId = const Value.absent(),
    this.dataEncrypted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.encryptionVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuickCaptureWidgetCacheEntriesCompanion.insert({
    required String userId,
    required String dataEncrypted,
    this.updatedAt = const Value.absent(),
    this.encryptionVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       dataEncrypted = Value(dataEncrypted);
  static Insertable<QuickCaptureWidgetCacheEntry> custom({
    Expression<String>? userId,
    Expression<String>? dataEncrypted,
    Expression<DateTime>? updatedAt,
    Expression<int>? encryptionVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (dataEncrypted != null) 'data_encrypted': dataEncrypted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (encryptionVersion != null) 'encryption_version': encryptionVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuickCaptureWidgetCacheEntriesCompanion copyWith({
    Value<String>? userId,
    Value<String>? dataEncrypted,
    Value<DateTime>? updatedAt,
    Value<int>? encryptionVersion,
    Value<int>? rowid,
  }) {
    return QuickCaptureWidgetCacheEntriesCompanion(
      userId: userId ?? this.userId,
      dataEncrypted: dataEncrypted ?? this.dataEncrypted,
      updatedAt: updatedAt ?? this.updatedAt,
      encryptionVersion: encryptionVersion ?? this.encryptionVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (dataEncrypted.present) {
      map['data_encrypted'] = Variable<String>(dataEncrypted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (encryptionVersion.present) {
      map['encryption_version'] = Variable<int>(encryptionVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuickCaptureWidgetCacheEntriesCompanion(')
          ..write('userId: $userId, ')
          ..write('dataEncrypted: $dataEncrypted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('encryptionVersion: $encryptionVersion, ')
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
  late final $NoteTasksTable noteTasks = $NoteTasksTable(this);
  late final $LocalFoldersTable localFolders = $LocalFoldersTable(this);
  late final $NoteFoldersTable noteFolders = $NoteFoldersTable(this);
  late final $SavedSearchesTable savedSearches = $SavedSearchesTable(this);
  late final $LocalTemplatesTable localTemplates = $LocalTemplatesTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $InboxItemsTable inboxItems = $InboxItemsTable(this);
  late final $QuickCaptureQueueEntriesTable quickCaptureQueueEntries =
      $QuickCaptureQueueEntriesTable(this);
  late final $QuickCaptureWidgetCacheEntriesTable
  quickCaptureWidgetCacheEntries = $QuickCaptureWidgetCacheEntriesTable(this);
  late final Index idxNoteFoldersNote = Index(
    'idx_note_folders_note',
    'CREATE INDEX idx_note_folders_note ON note_folders (note_id)',
  );
  late final Index idxNoteFoldersFolder = Index(
    'idx_note_folders_folder',
    'CREATE INDEX idx_note_folders_folder ON note_folders (folder_id)',
  );
  late final Index idxNoteFoldersFolderUpdated = Index(
    'idx_note_folders_folder_updated',
    'CREATE INDEX idx_note_folders_folder_updated ON note_folders (folder_id, updated_at)',
  );
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
    noteTasks,
    localFolders,
    noteFolders,
    savedSearches,
    localTemplates,
    attachments,
    inboxItems,
    quickCaptureQueueEntries,
    quickCaptureWidgetCacheEntries,
    idxNoteFoldersNote,
    idxNoteFoldersFolder,
    idxNoteFoldersFolderUpdated,
  ];
}

typedef $$LocalNotesTableCreateCompanionBuilder =
    LocalNotesCompanion Function({
      required String id,
      Value<String> titleEncrypted,
      Value<String> bodyEncrypted,
      Value<String?> metadataEncrypted,
      Value<int> encryptionVersion,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<bool> deleted,
      Value<DateTime?> deletedAt,
      Value<DateTime?> scheduledPurgeAt,
      Value<String?> encryptedMetadata,
      Value<bool> isPinned,
      Value<NoteKind> noteType,
      Value<int> version,
      Value<String?> userId,
      Value<String?> attachmentMeta,
      Value<String?> metadata,
      Value<int> rowid,
    });
typedef $$LocalNotesTableUpdateCompanionBuilder =
    LocalNotesCompanion Function({
      Value<String> id,
      Value<String> titleEncrypted,
      Value<String> bodyEncrypted,
      Value<String?> metadataEncrypted,
      Value<int> encryptionVersion,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<DateTime?> deletedAt,
      Value<DateTime?> scheduledPurgeAt,
      Value<String?> encryptedMetadata,
      Value<bool> isPinned,
      Value<NoteKind> noteType,
      Value<int> version,
      Value<String?> userId,
      Value<String?> attachmentMeta,
      Value<String?> metadata,
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

  ColumnFilters<String> get titleEncrypted => $composableBuilder(
    column: $table.titleEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyEncrypted => $composableBuilder(
    column: $table.bodyEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataEncrypted => $composableBuilder(
    column: $table.metadataEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledPurgeAt => $composableBuilder(
    column: $table.scheduledPurgeAt,
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

  ColumnWithTypeConverterFilters<NoteKind, NoteKind, int> get noteType =>
      $composableBuilder(
        column: $table.noteType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentMeta => $composableBuilder(
    column: $table.attachmentMeta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
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

  ColumnOrderings<String> get titleEncrypted => $composableBuilder(
    column: $table.titleEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyEncrypted => $composableBuilder(
    column: $table.bodyEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataEncrypted => $composableBuilder(
    column: $table.metadataEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledPurgeAt => $composableBuilder(
    column: $table.scheduledPurgeAt,
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

  ColumnOrderings<int> get noteType => $composableBuilder(
    column: $table.noteType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentMeta => $composableBuilder(
    column: $table.attachmentMeta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
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

  GeneratedColumn<String> get titleEncrypted => $composableBuilder(
    column: $table.titleEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bodyEncrypted => $composableBuilder(
    column: $table.bodyEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadataEncrypted => $composableBuilder(
    column: $table.metadataEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledPurgeAt => $composableBuilder(
    column: $table.scheduledPurgeAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedMetadata => $composableBuilder(
    column: $table.encryptedMetadata,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumnWithTypeConverter<NoteKind, int> get noteType =>
      $composableBuilder(column: $table.noteType, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get attachmentMeta => $composableBuilder(
    column: $table.attachmentMeta,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);
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
                Value<String> titleEncrypted = const Value.absent(),
                Value<String> bodyEncrypted = const Value.absent(),
                Value<String?> metadataEncrypted = const Value.absent(),
                Value<int> encryptionVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime?> scheduledPurgeAt = const Value.absent(),
                Value<String?> encryptedMetadata = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<NoteKind> noteType = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> attachmentMeta = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalNotesCompanion(
                id: id,
                titleEncrypted: titleEncrypted,
                bodyEncrypted: bodyEncrypted,
                metadataEncrypted: metadataEncrypted,
                encryptionVersion: encryptionVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deleted: deleted,
                deletedAt: deletedAt,
                scheduledPurgeAt: scheduledPurgeAt,
                encryptedMetadata: encryptedMetadata,
                isPinned: isPinned,
                noteType: noteType,
                version: version,
                userId: userId,
                attachmentMeta: attachmentMeta,
                metadata: metadata,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> titleEncrypted = const Value.absent(),
                Value<String> bodyEncrypted = const Value.absent(),
                Value<String?> metadataEncrypted = const Value.absent(),
                Value<int> encryptionVersion = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime?> scheduledPurgeAt = const Value.absent(),
                Value<String?> encryptedMetadata = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<NoteKind> noteType = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> attachmentMeta = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalNotesCompanion.insert(
                id: id,
                titleEncrypted: titleEncrypted,
                bodyEncrypted: bodyEncrypted,
                metadataEncrypted: metadataEncrypted,
                encryptionVersion: encryptionVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deleted: deleted,
                deletedAt: deletedAt,
                scheduledPurgeAt: scheduledPurgeAt,
                encryptedMetadata: encryptedMetadata,
                isPinned: isPinned,
                noteType: noteType,
                version: version,
                userId: userId,
                attachmentMeta: attachmentMeta,
                metadata: metadata,
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
      required String userId,
      Value<DateTime> createdAt,
    });
typedef $$PendingOpsTableUpdateCompanionBuilder =
    PendingOpsCompanion Function({
      Value<int> id,
      Value<String> entityId,
      Value<String> kind,
      Value<String?> payload,
      Value<String> userId,
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
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

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

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
                Value<String> userId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PendingOpsCompanion(
                id: id,
                entityId: entityId,
                kind: kind,
                payload: payload,
                userId: userId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entityId,
                required String kind,
                Value<String?> payload = const Value.absent(),
                required String userId,
                Value<DateTime> createdAt = const Value.absent(),
              }) => PendingOpsCompanion.insert(
                id: id,
                entityId: entityId,
                kind: kind,
                payload: payload,
                userId: userId,
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
      required String userId,
      Value<int> rowid,
    });
typedef $$NoteTagsTableUpdateCompanionBuilder =
    NoteTagsCompanion Function({
      Value<String> noteId,
      Value<String> tag,
      Value<String> userId,
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
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

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);
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
                Value<String> userId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteTagsCompanion(
                noteId: noteId,
                tag: tag,
                userId: userId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String noteId,
                required String tag,
                required String userId,
                Value<int> rowid = const Value.absent(),
              }) => NoteTagsCompanion.insert(
                noteId: noteId,
                tag: tag,
                userId: userId,
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
      required String userId,
      Value<int> rowid,
    });
typedef $$NoteLinksTableUpdateCompanionBuilder =
    NoteLinksCompanion Function({
      Value<String> sourceId,
      Value<String> targetTitle,
      Value<String?> targetId,
      Value<String> userId,
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
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

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);
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
                Value<String> userId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteLinksCompanion(
                sourceId: sourceId,
                targetTitle: targetTitle,
                targetId: targetId,
                userId: userId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required String targetTitle,
                Value<String?> targetId = const Value.absent(),
                required String userId,
                Value<int> rowid = const Value.absent(),
              }) => NoteLinksCompanion.insert(
                sourceId: sourceId,
                targetTitle: targetTitle,
                targetId: targetId,
                userId: userId,
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
      Value<String> id,
      required String noteId,
      required String userId,
      Value<String> title,
      Value<String> body,
      Value<Uint8List?> titleEncrypted,
      Value<Uint8List?> bodyEncrypted,
      Value<Uint8List?> locationNameEncrypted,
      Value<int?> encryptionVersion,
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
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
      Value<DateTime?> scheduledPurgeAt,
      Value<DateTime?> lastTriggered,
      Value<int> triggerCount,
      Value<int> rowid,
    });
typedef $$NoteRemindersTableUpdateCompanionBuilder =
    NoteRemindersCompanion Function({
      Value<String> id,
      Value<String> noteId,
      Value<String> userId,
      Value<String> title,
      Value<String> body,
      Value<Uint8List?> titleEncrypted,
      Value<Uint8List?> bodyEncrypted,
      Value<Uint8List?> locationNameEncrypted,
      Value<int?> encryptionVersion,
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
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
      Value<DateTime?> scheduledPurgeAt,
      Value<DateTime?> lastTriggered,
      Value<int> triggerCount,
      Value<int> rowid,
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
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
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

  ColumnFilters<Uint8List> get titleEncrypted => $composableBuilder(
    column: $table.titleEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bodyEncrypted => $composableBuilder(
    column: $table.bodyEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get locationNameEncrypted => $composableBuilder(
    column: $table.locationNameEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledPurgeAt => $composableBuilder(
    column: $table.scheduledPurgeAt,
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
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
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

  ColumnOrderings<Uint8List> get titleEncrypted => $composableBuilder(
    column: $table.titleEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bodyEncrypted => $composableBuilder(
    column: $table.bodyEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get locationNameEncrypted => $composableBuilder(
    column: $table.locationNameEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledPurgeAt => $composableBuilder(
    column: $table.scheduledPurgeAt,
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
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<Uint8List> get titleEncrypted => $composableBuilder(
    column: $table.titleEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get bodyEncrypted => $composableBuilder(
    column: $table.bodyEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get locationNameEncrypted => $composableBuilder(
    column: $table.locationNameEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
    builder: (column) => column,
  );

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

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledPurgeAt => $composableBuilder(
    column: $table.scheduledPurgeAt,
    builder: (column) => column,
  );

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
                Value<String> id = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<Uint8List?> titleEncrypted = const Value.absent(),
                Value<Uint8List?> bodyEncrypted = const Value.absent(),
                Value<Uint8List?> locationNameEncrypted = const Value.absent(),
                Value<int?> encryptionVersion = const Value.absent(),
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
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime?> scheduledPurgeAt = const Value.absent(),
                Value<DateTime?> lastTriggered = const Value.absent(),
                Value<int> triggerCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteRemindersCompanion(
                id: id,
                noteId: noteId,
                userId: userId,
                title: title,
                body: body,
                titleEncrypted: titleEncrypted,
                bodyEncrypted: bodyEncrypted,
                locationNameEncrypted: locationNameEncrypted,
                encryptionVersion: encryptionVersion,
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
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                scheduledPurgeAt: scheduledPurgeAt,
                lastTriggered: lastTriggered,
                triggerCount: triggerCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String noteId,
                required String userId,
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<Uint8List?> titleEncrypted = const Value.absent(),
                Value<Uint8List?> bodyEncrypted = const Value.absent(),
                Value<Uint8List?> locationNameEncrypted = const Value.absent(),
                Value<int?> encryptionVersion = const Value.absent(),
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
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime?> scheduledPurgeAt = const Value.absent(),
                Value<DateTime?> lastTriggered = const Value.absent(),
                Value<int> triggerCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteRemindersCompanion.insert(
                id: id,
                noteId: noteId,
                userId: userId,
                title: title,
                body: body,
                titleEncrypted: titleEncrypted,
                bodyEncrypted: bodyEncrypted,
                locationNameEncrypted: locationNameEncrypted,
                encryptionVersion: encryptionVersion,
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
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                scheduledPurgeAt: scheduledPurgeAt,
                lastTriggered: lastTriggered,
                triggerCount: triggerCount,
                rowid: rowid,
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
typedef $$NoteTasksTableCreateCompanionBuilder =
    NoteTasksCompanion Function({
      required String id,
      required String noteId,
      required String userId,
      required String contentEncrypted,
      Value<String?> labelsEncrypted,
      Value<String?> notesEncrypted,
      Value<int> encryptionVersion,
      Value<TaskStatus> status,
      Value<TaskPriority> priority,
      Value<DateTime?> dueDate,
      Value<DateTime?> completedAt,
      Value<String?> completedBy,
      Value<int> position,
      required String contentHash,
      Value<String?> reminderId,
      Value<int?> estimatedMinutes,
      Value<int?> actualMinutes,
      Value<String?> parentTaskId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<DateTime?> deletedAt,
      Value<DateTime?> scheduledPurgeAt,
      Value<int> rowid,
    });
typedef $$NoteTasksTableUpdateCompanionBuilder =
    NoteTasksCompanion Function({
      Value<String> id,
      Value<String> noteId,
      Value<String> userId,
      Value<String> contentEncrypted,
      Value<String?> labelsEncrypted,
      Value<String?> notesEncrypted,
      Value<int> encryptionVersion,
      Value<TaskStatus> status,
      Value<TaskPriority> priority,
      Value<DateTime?> dueDate,
      Value<DateTime?> completedAt,
      Value<String?> completedBy,
      Value<int> position,
      Value<String> contentHash,
      Value<String?> reminderId,
      Value<int?> estimatedMinutes,
      Value<int?> actualMinutes,
      Value<String?> parentTaskId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<DateTime?> deletedAt,
      Value<DateTime?> scheduledPurgeAt,
      Value<int> rowid,
    });

class $$NoteTasksTableFilterComposer
    extends Composer<_$AppDb, $NoteTasksTable> {
  $$NoteTasksTableFilterComposer({
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

  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentEncrypted => $composableBuilder(
    column: $table.contentEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get labelsEncrypted => $composableBuilder(
    column: $table.labelsEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notesEncrypted => $composableBuilder(
    column: $table.notesEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TaskStatus, TaskStatus, int> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<TaskPriority, TaskPriority, int>
  get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedBy => $composableBuilder(
    column: $table.completedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedMinutes => $composableBuilder(
    column: $table.estimatedMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualMinutes => $composableBuilder(
    column: $table.actualMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentTaskId => $composableBuilder(
    column: $table.parentTaskId,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledPurgeAt => $composableBuilder(
    column: $table.scheduledPurgeAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteTasksTableOrderingComposer
    extends Composer<_$AppDb, $NoteTasksTable> {
  $$NoteTasksTableOrderingComposer({
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

  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentEncrypted => $composableBuilder(
    column: $table.contentEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get labelsEncrypted => $composableBuilder(
    column: $table.labelsEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notesEncrypted => $composableBuilder(
    column: $table.notesEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedBy => $composableBuilder(
    column: $table.completedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedMinutes => $composableBuilder(
    column: $table.estimatedMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualMinutes => $composableBuilder(
    column: $table.actualMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentTaskId => $composableBuilder(
    column: $table.parentTaskId,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledPurgeAt => $composableBuilder(
    column: $table.scheduledPurgeAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteTasksTableAnnotationComposer
    extends Composer<_$AppDb, $NoteTasksTable> {
  $$NoteTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get contentEncrypted => $composableBuilder(
    column: $table.contentEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get labelsEncrypted => $composableBuilder(
    column: $table.labelsEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notesEncrypted => $composableBuilder(
    column: $table.notesEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TaskStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TaskPriority, int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get completedBy => $composableBuilder(
    column: $table.completedBy,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estimatedMinutes => $composableBuilder(
    column: $table.estimatedMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualMinutes => $composableBuilder(
    column: $table.actualMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentTaskId => $composableBuilder(
    column: $table.parentTaskId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledPurgeAt => $composableBuilder(
    column: $table.scheduledPurgeAt,
    builder: (column) => column,
  );
}

class $$NoteTasksTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $NoteTasksTable,
          NoteTask,
          $$NoteTasksTableFilterComposer,
          $$NoteTasksTableOrderingComposer,
          $$NoteTasksTableAnnotationComposer,
          $$NoteTasksTableCreateCompanionBuilder,
          $$NoteTasksTableUpdateCompanionBuilder,
          (NoteTask, BaseReferences<_$AppDb, $NoteTasksTable, NoteTask>),
          NoteTask,
          PrefetchHooks Function()
        > {
  $$NoteTasksTableTableManager(_$AppDb db, $NoteTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> contentEncrypted = const Value.absent(),
                Value<String?> labelsEncrypted = const Value.absent(),
                Value<String?> notesEncrypted = const Value.absent(),
                Value<int> encryptionVersion = const Value.absent(),
                Value<TaskStatus> status = const Value.absent(),
                Value<TaskPriority> priority = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> completedBy = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<String?> reminderId = const Value.absent(),
                Value<int?> estimatedMinutes = const Value.absent(),
                Value<int?> actualMinutes = const Value.absent(),
                Value<String?> parentTaskId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime?> scheduledPurgeAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteTasksCompanion(
                id: id,
                noteId: noteId,
                userId: userId,
                contentEncrypted: contentEncrypted,
                labelsEncrypted: labelsEncrypted,
                notesEncrypted: notesEncrypted,
                encryptionVersion: encryptionVersion,
                status: status,
                priority: priority,
                dueDate: dueDate,
                completedAt: completedAt,
                completedBy: completedBy,
                position: position,
                contentHash: contentHash,
                reminderId: reminderId,
                estimatedMinutes: estimatedMinutes,
                actualMinutes: actualMinutes,
                parentTaskId: parentTaskId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deleted: deleted,
                deletedAt: deletedAt,
                scheduledPurgeAt: scheduledPurgeAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String noteId,
                required String userId,
                required String contentEncrypted,
                Value<String?> labelsEncrypted = const Value.absent(),
                Value<String?> notesEncrypted = const Value.absent(),
                Value<int> encryptionVersion = const Value.absent(),
                Value<TaskStatus> status = const Value.absent(),
                Value<TaskPriority> priority = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> completedBy = const Value.absent(),
                Value<int> position = const Value.absent(),
                required String contentHash,
                Value<String?> reminderId = const Value.absent(),
                Value<int?> estimatedMinutes = const Value.absent(),
                Value<int?> actualMinutes = const Value.absent(),
                Value<String?> parentTaskId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime?> scheduledPurgeAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteTasksCompanion.insert(
                id: id,
                noteId: noteId,
                userId: userId,
                contentEncrypted: contentEncrypted,
                labelsEncrypted: labelsEncrypted,
                notesEncrypted: notesEncrypted,
                encryptionVersion: encryptionVersion,
                status: status,
                priority: priority,
                dueDate: dueDate,
                completedAt: completedAt,
                completedBy: completedBy,
                position: position,
                contentHash: contentHash,
                reminderId: reminderId,
                estimatedMinutes: estimatedMinutes,
                actualMinutes: actualMinutes,
                parentTaskId: parentTaskId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deleted: deleted,
                deletedAt: deletedAt,
                scheduledPurgeAt: scheduledPurgeAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoteTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $NoteTasksTable,
      NoteTask,
      $$NoteTasksTableFilterComposer,
      $$NoteTasksTableOrderingComposer,
      $$NoteTasksTableAnnotationComposer,
      $$NoteTasksTableCreateCompanionBuilder,
      $$NoteTasksTableUpdateCompanionBuilder,
      (NoteTask, BaseReferences<_$AppDb, $NoteTasksTable, NoteTask>),
      NoteTask,
      PrefetchHooks Function()
    >;
typedef $$LocalFoldersTableCreateCompanionBuilder =
    LocalFoldersCompanion Function({
      required String id,
      required String userId,
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
      Value<DateTime?> deletedAt,
      Value<DateTime?> scheduledPurgeAt,
      Value<int> rowid,
    });
typedef $$LocalFoldersTableUpdateCompanionBuilder =
    LocalFoldersCompanion Function({
      Value<String> id,
      Value<String> userId,
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
      Value<DateTime?> deletedAt,
      Value<DateTime?> scheduledPurgeAt,
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledPurgeAt => $composableBuilder(
    column: $table.scheduledPurgeAt,
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledPurgeAt => $composableBuilder(
    column: $table.scheduledPurgeAt,
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

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

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

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledPurgeAt => $composableBuilder(
    column: $table.scheduledPurgeAt,
    builder: (column) => column,
  );
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
                Value<String> userId = const Value.absent(),
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
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime?> scheduledPurgeAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFoldersCompanion(
                id: id,
                userId: userId,
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
                deletedAt: deletedAt,
                scheduledPurgeAt: scheduledPurgeAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
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
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime?> scheduledPurgeAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFoldersCompanion.insert(
                id: id,
                userId: userId,
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
                deletedAt: deletedAt,
                scheduledPurgeAt: scheduledPurgeAt,
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
      Value<DateTime> updatedAt,
      required String userId,
      Value<int> rowid,
    });
typedef $$NoteFoldersTableUpdateCompanionBuilder =
    NoteFoldersCompanion Function({
      Value<String> noteId,
      Value<String> folderId,
      Value<DateTime> addedAt,
      Value<DateTime> updatedAt,
      Value<String> userId,
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
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

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);
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
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteFoldersCompanion(
                noteId: noteId,
                folderId: folderId,
                addedAt: addedAt,
                updatedAt: updatedAt,
                userId: userId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String noteId,
                required String folderId,
                required DateTime addedAt,
                Value<DateTime> updatedAt = const Value.absent(),
                required String userId,
                Value<int> rowid = const Value.absent(),
              }) => NoteFoldersCompanion.insert(
                noteId: noteId,
                folderId: folderId,
                addedAt: addedAt,
                updatedAt: updatedAt,
                userId: userId,
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
      Value<String?> userId,
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
      Value<String?> userId,
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
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

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

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
                Value<String?> userId = const Value.absent(),
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
                userId: userId,
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
                Value<String?> userId = const Value.absent(),
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
                userId: userId,
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
typedef $$LocalTemplatesTableCreateCompanionBuilder =
    LocalTemplatesCompanion Function({
      required String id,
      Value<String?> userId,
      required String title,
      required String body,
      Value<String> tags,
      Value<bool> isSystem,
      required String category,
      required String description,
      required String icon,
      Value<int> sortOrder,
      Value<String?> metadata,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalTemplatesTableUpdateCompanionBuilder =
    LocalTemplatesCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String> title,
      Value<String> body,
      Value<String> tags,
      Value<bool> isSystem,
      Value<String> category,
      Value<String> description,
      Value<String> icon,
      Value<int> sortOrder,
      Value<String?> metadata,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalTemplatesTableFilterComposer
    extends Composer<_$AppDb, $LocalTemplatesTable> {
  $$LocalTemplatesTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
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

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
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
}

class $$LocalTemplatesTableOrderingComposer
    extends Composer<_$AppDb, $LocalTemplatesTable> {
  $$LocalTemplatesTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
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

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
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
}

class $$LocalTemplatesTableAnnotationComposer
    extends Composer<_$AppDb, $LocalTemplatesTable> {
  $$LocalTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $LocalTemplatesTable,
          LocalTemplate,
          $$LocalTemplatesTableFilterComposer,
          $$LocalTemplatesTableOrderingComposer,
          $$LocalTemplatesTableAnnotationComposer,
          $$LocalTemplatesTableCreateCompanionBuilder,
          $$LocalTemplatesTableUpdateCompanionBuilder,
          (
            LocalTemplate,
            BaseReferences<_$AppDb, $LocalTemplatesTable, LocalTemplate>,
          ),
          LocalTemplate,
          PrefetchHooks Function()
        > {
  $$LocalTemplatesTableTableManager(_$AppDb db, $LocalTemplatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTemplatesCompanion(
                id: id,
                userId: userId,
                title: title,
                body: body,
                tags: tags,
                isSystem: isSystem,
                category: category,
                description: description,
                icon: icon,
                sortOrder: sortOrder,
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                required String title,
                required String body,
                Value<String> tags = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                required String category,
                required String description,
                required String icon,
                Value<int> sortOrder = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalTemplatesCompanion.insert(
                id: id,
                userId: userId,
                title: title,
                body: body,
                tags: tags,
                isSystem: isSystem,
                category: category,
                description: description,
                icon: icon,
                sortOrder: sortOrder,
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $LocalTemplatesTable,
      LocalTemplate,
      $$LocalTemplatesTableFilterComposer,
      $$LocalTemplatesTableOrderingComposer,
      $$LocalTemplatesTableAnnotationComposer,
      $$LocalTemplatesTableCreateCompanionBuilder,
      $$LocalTemplatesTableUpdateCompanionBuilder,
      (
        LocalTemplate,
        BaseReferences<_$AppDb, $LocalTemplatesTable, LocalTemplate>,
      ),
      LocalTemplate,
      PrefetchHooks Function()
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      required String id,
      required String userId,
      required String noteId,
      required String filename,
      required String mimeType,
      required int size,
      Value<String?> url,
      Value<String?> localPath,
      required DateTime createdAt,
      Value<String> metadata,
      Value<int> rowid,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> noteId,
      Value<String> filename,
      Value<String> mimeType,
      Value<int> size,
      Value<String?> url,
      Value<String?> localPath,
      Value<DateTime> createdAt,
      Value<String> metadata,
      Value<int> rowid,
    });

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDb, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDb, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDb, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get filename =>
      $composableBuilder(column: $table.filename, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $AttachmentsTable,
          LocalAttachment,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (
            LocalAttachment,
            BaseReferences<_$AppDb, $AttachmentsTable, LocalAttachment>,
          ),
          LocalAttachment,
          PrefetchHooks Function()
        > {
  $$AttachmentsTableTableManager(_$AppDb db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<String> filename = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                userId: userId,
                noteId: noteId,
                filename: filename,
                mimeType: mimeType,
                size: size,
                url: url,
                localPath: localPath,
                createdAt: createdAt,
                metadata: metadata,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String noteId,
                required String filename,
                required String mimeType,
                required int size,
                Value<String?> url = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                required DateTime createdAt,
                Value<String> metadata = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                userId: userId,
                noteId: noteId,
                filename: filename,
                mimeType: mimeType,
                size: size,
                url: url,
                localPath: localPath,
                createdAt: createdAt,
                metadata: metadata,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $AttachmentsTable,
      LocalAttachment,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (
        LocalAttachment,
        BaseReferences<_$AppDb, $AttachmentsTable, LocalAttachment>,
      ),
      LocalAttachment,
      PrefetchHooks Function()
    >;
typedef $$InboxItemsTableCreateCompanionBuilder =
    InboxItemsCompanion Function({
      required String id,
      required String userId,
      required String sourceType,
      required String payload,
      required DateTime createdAt,
      Value<bool> isProcessed,
      Value<String?> noteId,
      Value<DateTime?> processedAt,
      Value<int> rowid,
    });
typedef $$InboxItemsTableUpdateCompanionBuilder =
    InboxItemsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> sourceType,
      Value<String> payload,
      Value<DateTime> createdAt,
      Value<bool> isProcessed,
      Value<String?> noteId,
      Value<DateTime?> processedAt,
      Value<int> rowid,
    });

class $$InboxItemsTableFilterComposer
    extends Composer<_$AppDb, $InboxItemsTable> {
  $$InboxItemsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
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

  ColumnFilters<bool> get isProcessed => $composableBuilder(
    column: $table.isProcessed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InboxItemsTableOrderingComposer
    extends Composer<_$AppDb, $InboxItemsTable> {
  $$InboxItemsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
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

  ColumnOrderings<bool> get isProcessed => $composableBuilder(
    column: $table.isProcessed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InboxItemsTableAnnotationComposer
    extends Composer<_$AppDb, $InboxItemsTable> {
  $$InboxItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isProcessed => $composableBuilder(
    column: $table.isProcessed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => column,
  );
}

class $$InboxItemsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $InboxItemsTable,
          InboxItem,
          $$InboxItemsTableFilterComposer,
          $$InboxItemsTableOrderingComposer,
          $$InboxItemsTableAnnotationComposer,
          $$InboxItemsTableCreateCompanionBuilder,
          $$InboxItemsTableUpdateCompanionBuilder,
          (InboxItem, BaseReferences<_$AppDb, $InboxItemsTable, InboxItem>),
          InboxItem,
          PrefetchHooks Function()
        > {
  $$InboxItemsTableTableManager(_$AppDb db, $InboxItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InboxItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InboxItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InboxItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> isProcessed = const Value.absent(),
                Value<String?> noteId = const Value.absent(),
                Value<DateTime?> processedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InboxItemsCompanion(
                id: id,
                userId: userId,
                sourceType: sourceType,
                payload: payload,
                createdAt: createdAt,
                isProcessed: isProcessed,
                noteId: noteId,
                processedAt: processedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String sourceType,
                required String payload,
                required DateTime createdAt,
                Value<bool> isProcessed = const Value.absent(),
                Value<String?> noteId = const Value.absent(),
                Value<DateTime?> processedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InboxItemsCompanion.insert(
                id: id,
                userId: userId,
                sourceType: sourceType,
                payload: payload,
                createdAt: createdAt,
                isProcessed: isProcessed,
                noteId: noteId,
                processedAt: processedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InboxItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $InboxItemsTable,
      InboxItem,
      $$InboxItemsTableFilterComposer,
      $$InboxItemsTableOrderingComposer,
      $$InboxItemsTableAnnotationComposer,
      $$InboxItemsTableCreateCompanionBuilder,
      $$InboxItemsTableUpdateCompanionBuilder,
      (InboxItem, BaseReferences<_$AppDb, $InboxItemsTable, InboxItem>),
      InboxItem,
      PrefetchHooks Function()
    >;
typedef $$QuickCaptureQueueEntriesTableCreateCompanionBuilder =
    QuickCaptureQueueEntriesCompanion Function({
      required String id,
      required String userId,
      required String payloadEncrypted,
      Value<String?> platform,
      Value<int> retryCount,
      Value<bool> processed,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> processedAt,
      Value<int> encryptionVersion,
      Value<int> rowid,
    });
typedef $$QuickCaptureQueueEntriesTableUpdateCompanionBuilder =
    QuickCaptureQueueEntriesCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> payloadEncrypted,
      Value<String?> platform,
      Value<int> retryCount,
      Value<bool> processed,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> processedAt,
      Value<int> encryptionVersion,
      Value<int> rowid,
    });

class $$QuickCaptureQueueEntriesTableFilterComposer
    extends Composer<_$AppDb, $QuickCaptureQueueEntriesTable> {
  $$QuickCaptureQueueEntriesTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadEncrypted => $composableBuilder(
    column: $table.payloadEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get processed => $composableBuilder(
    column: $table.processed,
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

  ColumnFilters<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuickCaptureQueueEntriesTableOrderingComposer
    extends Composer<_$AppDb, $QuickCaptureQueueEntriesTable> {
  $$QuickCaptureQueueEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadEncrypted => $composableBuilder(
    column: $table.payloadEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get processed => $composableBuilder(
    column: $table.processed,
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

  ColumnOrderings<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuickCaptureQueueEntriesTableAnnotationComposer
    extends Composer<_$AppDb, $QuickCaptureQueueEntriesTable> {
  $$QuickCaptureQueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get payloadEncrypted => $composableBuilder(
    column: $table.payloadEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get processed =>
      $composableBuilder(column: $table.processed, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
    builder: (column) => column,
  );
}

class $$QuickCaptureQueueEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $QuickCaptureQueueEntriesTable,
          QuickCaptureQueueEntry,
          $$QuickCaptureQueueEntriesTableFilterComposer,
          $$QuickCaptureQueueEntriesTableOrderingComposer,
          $$QuickCaptureQueueEntriesTableAnnotationComposer,
          $$QuickCaptureQueueEntriesTableCreateCompanionBuilder,
          $$QuickCaptureQueueEntriesTableUpdateCompanionBuilder,
          (
            QuickCaptureQueueEntry,
            BaseReferences<
              _$AppDb,
              $QuickCaptureQueueEntriesTable,
              QuickCaptureQueueEntry
            >,
          ),
          QuickCaptureQueueEntry,
          PrefetchHooks Function()
        > {
  $$QuickCaptureQueueEntriesTableTableManager(
    _$AppDb db,
    $QuickCaptureQueueEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuickCaptureQueueEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$QuickCaptureQueueEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$QuickCaptureQueueEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> payloadEncrypted = const Value.absent(),
                Value<String?> platform = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<bool> processed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> processedAt = const Value.absent(),
                Value<int> encryptionVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuickCaptureQueueEntriesCompanion(
                id: id,
                userId: userId,
                payloadEncrypted: payloadEncrypted,
                platform: platform,
                retryCount: retryCount,
                processed: processed,
                createdAt: createdAt,
                updatedAt: updatedAt,
                processedAt: processedAt,
                encryptionVersion: encryptionVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String payloadEncrypted,
                Value<String?> platform = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<bool> processed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> processedAt = const Value.absent(),
                Value<int> encryptionVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuickCaptureQueueEntriesCompanion.insert(
                id: id,
                userId: userId,
                payloadEncrypted: payloadEncrypted,
                platform: platform,
                retryCount: retryCount,
                processed: processed,
                createdAt: createdAt,
                updatedAt: updatedAt,
                processedAt: processedAt,
                encryptionVersion: encryptionVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuickCaptureQueueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $QuickCaptureQueueEntriesTable,
      QuickCaptureQueueEntry,
      $$QuickCaptureQueueEntriesTableFilterComposer,
      $$QuickCaptureQueueEntriesTableOrderingComposer,
      $$QuickCaptureQueueEntriesTableAnnotationComposer,
      $$QuickCaptureQueueEntriesTableCreateCompanionBuilder,
      $$QuickCaptureQueueEntriesTableUpdateCompanionBuilder,
      (
        QuickCaptureQueueEntry,
        BaseReferences<
          _$AppDb,
          $QuickCaptureQueueEntriesTable,
          QuickCaptureQueueEntry
        >,
      ),
      QuickCaptureQueueEntry,
      PrefetchHooks Function()
    >;
typedef $$QuickCaptureWidgetCacheEntriesTableCreateCompanionBuilder =
    QuickCaptureWidgetCacheEntriesCompanion Function({
      required String userId,
      required String dataEncrypted,
      Value<DateTime> updatedAt,
      Value<int> encryptionVersion,
      Value<int> rowid,
    });
typedef $$QuickCaptureWidgetCacheEntriesTableUpdateCompanionBuilder =
    QuickCaptureWidgetCacheEntriesCompanion Function({
      Value<String> userId,
      Value<String> dataEncrypted,
      Value<DateTime> updatedAt,
      Value<int> encryptionVersion,
      Value<int> rowid,
    });

class $$QuickCaptureWidgetCacheEntriesTableFilterComposer
    extends Composer<_$AppDb, $QuickCaptureWidgetCacheEntriesTable> {
  $$QuickCaptureWidgetCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataEncrypted => $composableBuilder(
    column: $table.dataEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuickCaptureWidgetCacheEntriesTableOrderingComposer
    extends Composer<_$AppDb, $QuickCaptureWidgetCacheEntriesTable> {
  $$QuickCaptureWidgetCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataEncrypted => $composableBuilder(
    column: $table.dataEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuickCaptureWidgetCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDb, $QuickCaptureWidgetCacheEntriesTable> {
  $$QuickCaptureWidgetCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get dataEncrypted => $composableBuilder(
    column: $table.dataEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
    builder: (column) => column,
  );
}

class $$QuickCaptureWidgetCacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $QuickCaptureWidgetCacheEntriesTable,
          QuickCaptureWidgetCacheEntry,
          $$QuickCaptureWidgetCacheEntriesTableFilterComposer,
          $$QuickCaptureWidgetCacheEntriesTableOrderingComposer,
          $$QuickCaptureWidgetCacheEntriesTableAnnotationComposer,
          $$QuickCaptureWidgetCacheEntriesTableCreateCompanionBuilder,
          $$QuickCaptureWidgetCacheEntriesTableUpdateCompanionBuilder,
          (
            QuickCaptureWidgetCacheEntry,
            BaseReferences<
              _$AppDb,
              $QuickCaptureWidgetCacheEntriesTable,
              QuickCaptureWidgetCacheEntry
            >,
          ),
          QuickCaptureWidgetCacheEntry,
          PrefetchHooks Function()
        > {
  $$QuickCaptureWidgetCacheEntriesTableTableManager(
    _$AppDb db,
    $QuickCaptureWidgetCacheEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuickCaptureWidgetCacheEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$QuickCaptureWidgetCacheEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$QuickCaptureWidgetCacheEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> dataEncrypted = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> encryptionVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuickCaptureWidgetCacheEntriesCompanion(
                userId: userId,
                dataEncrypted: dataEncrypted,
                updatedAt: updatedAt,
                encryptionVersion: encryptionVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String dataEncrypted,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> encryptionVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuickCaptureWidgetCacheEntriesCompanion.insert(
                userId: userId,
                dataEncrypted: dataEncrypted,
                updatedAt: updatedAt,
                encryptionVersion: encryptionVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuickCaptureWidgetCacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $QuickCaptureWidgetCacheEntriesTable,
      QuickCaptureWidgetCacheEntry,
      $$QuickCaptureWidgetCacheEntriesTableFilterComposer,
      $$QuickCaptureWidgetCacheEntriesTableOrderingComposer,
      $$QuickCaptureWidgetCacheEntriesTableAnnotationComposer,
      $$QuickCaptureWidgetCacheEntriesTableCreateCompanionBuilder,
      $$QuickCaptureWidgetCacheEntriesTableUpdateCompanionBuilder,
      (
        QuickCaptureWidgetCacheEntry,
        BaseReferences<
          _$AppDb,
          $QuickCaptureWidgetCacheEntriesTable,
          QuickCaptureWidgetCacheEntry
        >,
      ),
      QuickCaptureWidgetCacheEntry,
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
  $$NoteTasksTableTableManager get noteTasks =>
      $$NoteTasksTableTableManager(_db, _db.noteTasks);
  $$LocalFoldersTableTableManager get localFolders =>
      $$LocalFoldersTableTableManager(_db, _db.localFolders);
  $$NoteFoldersTableTableManager get noteFolders =>
      $$NoteFoldersTableTableManager(_db, _db.noteFolders);
  $$SavedSearchesTableTableManager get savedSearches =>
      $$SavedSearchesTableTableManager(_db, _db.savedSearches);
  $$LocalTemplatesTableTableManager get localTemplates =>
      $$LocalTemplatesTableTableManager(_db, _db.localTemplates);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
  $$InboxItemsTableTableManager get inboxItems =>
      $$InboxItemsTableTableManager(_db, _db.inboxItems);
  $$QuickCaptureQueueEntriesTableTableManager get quickCaptureQueueEntries =>
      $$QuickCaptureQueueEntriesTableTableManager(
        _db,
        _db.quickCaptureQueueEntries,
      );
  $$QuickCaptureWidgetCacheEntriesTableTableManager
  get quickCaptureWidgetCacheEntries =>
      $$QuickCaptureWidgetCacheEntriesTableTableManager(
        _db,
        _db.quickCaptureWidgetCacheEntries,
      );
}
