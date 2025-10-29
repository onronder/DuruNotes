import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/events/mutation_event_bus.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/core/monitoring/trace_context.dart';
import 'package:duru_notes/core/utils/hash_utils.dart';
import 'package:duru_notes/data/local/app_db.dart' hide NoteLink;
import 'package:duru_notes/data/remote/secure_api_wrapper.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/note_link.dart';
import 'package:duru_notes/infrastructure/mappers/note_mapper.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/services/performance/performance_monitor.dart';
import 'package:duru_notes/services/security/security_audit_trail.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide SortBy;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Core notes repository implementation
class NotesCoreRepository implements INotesRepository {
  NotesCoreRepository({
    required this.db,
    required this.crypto,
    required SupabaseClient client,
    required NoteIndexer indexer,
    SecureApiWrapper? secureApi,
  }) : _supabase = client,
       _indexer = indexer,
       _secureApi = secureApi ?? SecureApiWrapper(client),
       _logger = LoggerFactory.instance;

  final AppDb db;
  final CryptoBox crypto;
  final SupabaseClient _supabase;
  final NoteIndexer _indexer;
  final SecureApiWrapper _secureApi;
  final AppLogger _logger;
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final SecurityAuditTrail _securityAuditTrail = SecurityAuditTrail();
  final _uuid = const Uuid();
  static const _lastSyncKey = 'notes_core_repository.last_sync_at';

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  String? _requireUserId({required String method, Map<String, dynamic>? data}) {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      final error = StateError('Unauthenticated access');
      _logger.warning('$method called without authenticated user', data: data);
      _captureRepositoryException(
        method: method,
        error: error,
        stackTrace: StackTrace.current,
        data: data,
        level: SentryLevel.warning,
      );
      return null;
    }
    return userId;
  }

  Future<void> _enqueuePendingOp({
    required String entityId,
    required String kind,
    String? payload,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      _logger.warning(
        'Skipping enqueue - no authenticated user',
        data: {'entityId': entityId, 'kind': kind},
      );
      return;
    }

    await db.enqueue(
      userId: userId,
      entityId: entityId,
      kind: kind,
      payload: payload,
    );
  }

  void _captureRepositoryException({
    required String method,
    required Object error,
    required StackTrace stackTrace,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.error,
  }) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.level = level;
          scope.setTag('layer', 'repository');
          scope.setTag('repository', 'NotesCoreRepository');
          scope.setTag('method', method);
          if (data != null && data.isNotEmpty) {
            scope.setContexts('payload', data);
          }
        },
      ),
    );
  }

  Future<List<String>> _loadTags(String noteId) async {
    try {
      final tagRecords = await (db.select(
        db.noteTags,
      )..where((t) => t.noteId.equals(noteId))).get();
      return tagRecords.map((t) => t.tag).toList();
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load tags for note',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      _captureRepositoryException(
        method: '_loadTags',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      return const <String>[];
    }
  }

  Future<List<NoteLink>> _loadDomainLinks(String noteId) async {
    try {
      final linkRecords = await (db.select(
        db.noteLinks,
      )..where((l) => l.sourceId.equals(noteId))).get();
      return linkRecords.map(NoteMapper.linkToDomain).toList();
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load links for note',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      _captureRepositoryException(
        method: '_loadDomainLinks',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      return const <NoteLink>[];
    }
  }

  Future<domain.Note?> _hydrateDomainNote(LocalNote localNote) async {
    try {
      final tags = await _loadTags(localNote.id);
      final links = await _loadDomainLinks(localNote.id);

      // Decrypt title and body
      final userId = localNote.userId ?? _supabase.auth.currentUser?.id ?? '';
      String title = '';
      String body = '';

      try {
        if (localNote.titleEncrypted.isNotEmpty) {
          // CRITICAL FIX: Old notes have RAW JSON strings, not base64-encoded encrypted data
          // Check if titleEncrypted contains raw JSON (legacy format)
          final titleEncrypted = localNote.titleEncrypted.trim();
          _logger.debug(
            '📝 Decrypting title for note ${localNote.id}: length=${titleEncrypted.length}, preview=${titleEncrypted.substring(0, min(50, titleEncrypted.length))}',
          );

          if (titleEncrypted.startsWith('{') &&
              titleEncrypted.contains('"title"')) {
            // Raw JSON format - extract title directly without decryption
            try {
              final parsed = jsonDecode(titleEncrypted) as Map<String, dynamic>;
              title = parsed['title'] as String? ?? '';
              _logger.debug(
                'Extracted title from raw JSON (legacy format) for note ${localNote.id}',
              );
            } catch (e) {
              _logger.warning(
                'Failed to parse raw JSON title for note ${localNote.id}: $e',
              );
              title = titleEncrypted; // Show as-is if parsing fails
            }
          } else {
            // Modern format - base64-encoded encrypted data
            try {
              final titleData = base64.decode(titleEncrypted);

              // Try to decrypt as string first (correct format)
              try {
                title = await crypto.decryptStringForNote(
                  userId: userId,
                  noteId: localNote.id,
                  data: titleData,
                );
                _logger.debug(
                  '✅ Decrypted title successfully: "${title.substring(0, min(50, title.length))}"',
                );
              } catch (stringError) {
                _logger.error(
                  '❌ String decryption failed for note ${localNote.id}: $stringError',
                );
                // FALLBACK: Try decrypting as JSON (transitional format)
                try {
                  final titleJson = await crypto.decryptJsonForNote(
                    userId: userId,
                    noteId: localNote.id,
                    data: titleData,
                  );
                  title = titleJson['title'] as String? ?? '';
                  _logger.debug(
                    'Decrypted title using JSON format for note ${localNote.id}',
                  );
                } catch (jsonError) {
                  _logger.warning(
                    'Failed to decrypt title for note ${localNote.id}: $stringError',
                  );
                  throw stringError;
                }
              }
            } catch (decodeError) {
              _logger.warning(
                'Failed to base64 decode title for note ${localNote.id}: $decodeError',
              );
            }
          }
        }
      } catch (e) {
        _logger.warning('Failed to process title for note ${localNote.id}: $e');
      }

      if (title.isEmpty && localNote.titleEncrypted.isNotEmpty) {
        _logger.error(
          '⚠️ Title is EMPTY after decryption for note ${localNote.id}',
        );
      }

      try {
        if (localNote.bodyEncrypted.isNotEmpty) {
          // Modern format - base64-encoded encrypted data
          try {
            final bodyData = base64.decode(localNote.bodyEncrypted);
            body = await crypto.decryptStringForNote(
              userId: userId,
              noteId: localNote.id,
              data: bodyData,
            );
          } catch (decodeError) {
            _logger.warning(
              'Failed to base64 decode body for note ${localNote.id}: $decodeError',
            );
          }
        }
      } catch (e) {
        _logger.warning('Failed to decrypt body for note ${localNote.id}: $e');
      }

      final folderId = await _getFolderIdForNote(localNote.id);

      return NoteMapper.toDomain(
        localNote,
        title: title,
        body: body,
        folderId: folderId,
        tags: tags,
        links: links,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to hydrate local note to domain',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': localNote.id},
      );
      _captureRepositoryException(
        method: '_hydrateDomainNote',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': localNote.id},
      );
      return null;
    }
  }

  Future<List<domain.Note>> _hydrateDomainNotes(
    List<LocalNote> localNotes,
  ) async {
    final List<domain.Note> notes = [];
    for (final localNote in localNotes) {
      final hydrated = await _hydrateDomainNote(localNote);
      if (hydrated != null && _shouldDisplayNote(hydrated)) {
        notes.add(hydrated);
      }
    }
    return notes;
  }

  Map<String, dynamic>? _tryDecodeJson(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore malformed JSON – return null so callers can fallback
    }
    return null;
  }

  bool _shouldDisplayNote(domain.Note note) {
    final metadata = _tryDecodeJson(note.metadata);
    if (metadata == null) {
      return true;
    }

    final isSystem = metadata['system'] == true;
    final isStandaloneTasks =
        metadata['standaloneTasks'] == true ||
        metadata['standalone_tasks'] == true;

    return !(isSystem && isStandaloneTasks);
  }

  List<Map<String, String?>> _serializeLinks(List<NoteLink> links) {
    if (links.isEmpty) {
      return const [];
    }

    return links
        .map(
          (link) => {
            'title': link.linkText ?? link.toNoteId,
            'id': link.toNoteId.isEmpty ? null : link.toNoteId,
          },
        )
        .toList();
  }

  List<Map<String, String?>> _serializeLinkReferences(
    List<domain.NoteLinkReference> links,
  ) {
    if (links.isEmpty) {
      return const [];
    }

    return links
        .map((link) => {'title': link.targetTitle, 'id': link.targetId})
        .toList();
  }

  Map<String, dynamic> _buildPropsPayload({
    required String body,
    required List<String> tags,
    required bool isPinned,
    String? folderId,
    String? metadata,
    String? attachmentMeta,
    List<Map<String, String?>>? links,
    int? version,
    bool? deleted,
  }) {
    final props = <String, dynamic>{
      'body': body,
      'tags': tags,
      'isPinned': isPinned,
      if (folderId != null) 'folderId': folderId,
      if (metadata != null) 'metadata': _tryDecodeJson(metadata) ?? metadata,
      if (attachmentMeta != null)
        'attachmentMeta': _tryDecodeJson(attachmentMeta) ?? attachmentMeta,
      if (links != null) 'links': links,
      if (version != null) 'version': version,
      if (deleted != null) 'deleted': deleted,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    // Remove any null values that might remain after decoding
    props.removeWhere((key, value) => value == null);
    return props;
  }

  Future<Uint8List> _encryptTitlePayload({
    required String userId,
    required String noteId,
    required String title,
  }) {
    // FIX: Encrypt title as STRING, not JSON object
    // Before: encrypted as {"title": "..."} causing display issues
    // After: encrypted as plain string
    return crypto.encryptStringForNote(
      userId: userId,
      noteId: noteId,
      text: title,
    );
  }

  Future<Uint8List> _encryptPropsPayload({
    required String userId,
    required String noteId,
    required Map<String, dynamic> props,
  }) {
    return crypto.encryptJsonForNote(
      userId: userId,
      noteId: noteId,
      json: props,
    );
  }

  Future<String?> _getFolderIdForNote(String noteId) async {
    final relation = await (db.select(
      db.noteFolders,
    )..where((nf) => nf.noteId.equals(noteId))).getSingleOrNull();
    return relation?.folderId;
  }

  Future<void> _setLastSyncTime(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, timestamp.toUtc().toIso8601String());
  }

  Future<DateTime?> _readLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSyncKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  bool _isNoteOp(String kind) =>
      kind == 'upsert_note' || kind == 'delete_note' || kind == 'delete';

  bool _isFolderOp(String kind) =>
      kind == 'upsert_folder' || kind == 'delete_folder';

  bool _isTaskOp(String kind) => kind == 'upsert_task' || kind == 'delete_task';

  bool _isTemplateOp(String kind) =>
      kind == 'upsert_template' || kind == 'delete_template';

  Future<bool> _executeWithRetry({
    required String operation,
    required Future<void> Function() run,
    Map<String, dynamic>? metadata,
    int maxAttempts = 3,
  }) async {
    var attempt = 0;
    while (attempt < maxAttempts) {
      attempt++;
      try {
        await run();
        return true;
      } on RateLimitException catch (e) {
        if (attempt >= maxAttempts) {
          _logger.warning(
            'Rate limit exceeded for $operation after $attempt attempts',
            data: {...?metadata, 'retryAfter': e.retryAfter?.toIso8601String()},
          );
          return false;
        }

        final delay = _computeRetryDelay(e.retryAfter, attempt);
        await Future<void>.delayed(delay);
      } on ApiException catch (e, stackTrace) {
        _logger.error(
          'API error during $operation',
          error: e,
          stackTrace: stackTrace,
          data: {...?metadata, 'code': e.code, 'message': e.message},
        );
        return false;
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to execute $operation',
          error: error,
          stackTrace: stackTrace,
          data: metadata,
        );
        _captureRepositoryException(
          method: operation,
          error: error,
          stackTrace: stackTrace,
          data: metadata,
          level: SentryLevel.warning,
        );
        return false;
      }
    }
    return false;
  }

  Duration _computeRetryDelay(DateTime? retryAfter, int attempt) {
    if (retryAfter != null) {
      final target = retryAfter.toUtc();
      final now = DateTime.now().toUtc();
      final diff = target.difference(now);
      if (!diff.isNegative) {
        return diff;
      }
    }
    final baseMillis = 200 * (1 << (attempt - 1));
    final cappedMillis = baseMillis > 2000 ? 2000 : baseMillis;
    return Duration(milliseconds: cappedMillis);
  }

  Future<String> _decryptTaskField({
    required String encrypted,
    required String userId,
    required String noteId,
  }) async {
    final data = Uint8List.fromList(utf8.encode(encrypted));
    return crypto.decryptStringForNote(
      userId: userId,
      noteId: noteId,
      data: data,
    );
  }

  Future<String?> _decryptOptionalTaskField({
    String? encrypted,
    required String userId,
    required String noteId,
  }) async {
    if (encrypted == null || encrypted.isEmpty) {
      return null;
    }

    final data = Uint8List.fromList(utf8.encode(encrypted));
    return crypto.decryptStringForNote(
      userId: userId,
      noteId: noteId,
      data: data,
    );
  }

  Future<List<String>> _decryptTaskTags({
    String? encrypted,
    required String userId,
    required String noteId,
  }) async {
    final decrypted = await _decryptOptionalTaskField(
      encrypted: encrypted,
      userId: userId,
      noteId: noteId,
    );

    if (decrypted == null || decrypted.isEmpty) {
      return const <String>[];
    }

    try {
      final decoded = jsonDecode(decrypted);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {
      // Swallow JSON errors – return empty list so sync can continue
    }
    return const <String>[];
  }

  String _mapTaskStatusToRemote(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return 'completed';
      case TaskStatus.cancelled:
        return 'cancelled';
      case TaskStatus.open:
      default:
        return 'open';
    }
  }

  TaskStatus _mapRemoteTaskStatus(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return TaskStatus.completed;
      case 'cancelled':
        return TaskStatus.cancelled;
      default:
        return TaskStatus.open;
    }
  }

  TaskPriority _mapRemoteTaskPriority(int priority) {
    var index = priority;
    if (index < 0) index = 0;
    if (index >= TaskPriority.values.length) {
      index = TaskPriority.values.length - 1;
    }
    return TaskPriority.values[index];
  }

  Future<String> _encryptTemplateField({
    required String userId,
    required String templateId,
    required String value,
  }) async {
    final bytes = await crypto.encryptStringForNote(
      userId: userId,
      noteId: templateId,
      text: value,
    );
    return utf8.decode(bytes);
  }

  Future<String?> _decryptTemplateField({
    String? encrypted,
    required String userId,
    required String templateId,
  }) async {
    if (encrypted == null || encrypted.isEmpty) {
      return null;
    }

    final data = Uint8List.fromList(utf8.encode(encrypted));
    return crypto.decryptStringForNote(
      userId: userId,
      noteId: templateId,
      data: data,
    );
  }

  Future<bool> _pushNoteOp(PendingOp op) async {
    final noteId = op.entityId;
    try {
      final localNote = await (db.select(
        db.localNotes,
      )..where((n) => n.id.equals(noteId))).getSingleOrNull();

      if (localNote == null &&
          op.kind != 'delete' &&
          op.kind != 'delete_note') {
        _logger.warning(
          'Pending note operation references missing note',
          data: {'noteId': noteId, 'kind': op.kind},
        );
        return true;
      }

      final userId = localNote?.userId ?? _supabase.auth.currentUser?.id ?? '';
      if (userId.isEmpty) {
        _logger.warning(
          'Cannot push note operation without authenticated user',
          data: {'noteId': noteId, 'kind': op.kind},
        );
        return false;
      }

      domain.Note? domainNote;
      if (localNote != null) {
        domainNote = await _hydrateDomainNote(localNote);
      }

      final isDeletion =
          op.kind == 'delete' ||
          op.kind == 'delete_note' ||
          (domainNote?.deleted ?? localNote?.deleted ?? false);

      final title = domainNote?.title ?? '';
      final body = domainNote?.body ?? '';
      final tags =
          domainNote?.tags ??
          (localNote != null ? await _loadTags(noteId) : const <String>[]);
      final folderId =
          domainNote?.folderId ?? await _getFolderIdForNote(noteId);
      final metadata = domainNote?.metadata ?? localNote?.metadata;
      final attachmentMeta =
          domainNote?.attachmentMeta ?? localNote?.attachmentMeta;
      final version = domainNote?.version ?? localNote?.version ?? 1;
      final isPinned = domainNote?.isPinned ?? (localNote?.isPinned ?? false);

      final List<Map<String, String?>> linksPayload;
      if (domainNote != null) {
        linksPayload = _serializeLinkReferences(domainNote.links);
      } else if (localNote != null) {
        final storedLinks = await _loadDomainLinks(noteId);
        linksPayload = _serializeLinks(storedLinks);
      } else {
        linksPayload = const [];
      }

      final props = _buildPropsPayload(
        body: body,
        tags: tags,
        isPinned: isPinned,
        folderId: folderId,
        metadata: metadata,
        attachmentMeta: attachmentMeta,
        links: linksPayload,
        version: version,
        deleted: isDeletion,
      );

      final titleEnc = await _encryptTitlePayload(
        userId: userId,
        noteId: noteId,
        title: title,
      );

      final propsEnc = await _encryptPropsPayload(
        userId: userId,
        noteId: noteId,
        props: props,
      );

      // Get createdAt from domain note or local note to preserve timestamp
      final createdAt = domainNote?.createdAt ?? localNote?.createdAt;

      final upsertSuccess = await _executeWithRetry(
        operation: 'notes.upsert',
        metadata: {'noteId': noteId, 'deleted': isDeletion, 'kind': op.kind},
        run: () => _secureApi.upsertEncryptedNote(
          id: noteId,
          titleEnc: titleEnc,
          propsEnc: propsEnc,
          deleted: isDeletion,
          createdAt: createdAt,
        ),
      );

      if (!upsertSuccess) {
        return false;
      }

      if (isDeletion || folderId == null || folderId.isEmpty) {
        await _executeWithRetry(
          operation: 'noteFolders.delete',
          metadata: {'noteId': noteId, 'folderId': folderId},
          run: () => _secureApi.deleteNoteFolderRelation(
            noteId: noteId,
            folderId: folderId,
          ),
        );
      } else {
        await _executeWithRetry(
          operation: 'noteFolders.upsert',
          metadata: {'noteId': noteId, 'folderId': folderId},
          run: () => _secureApi.upsertNoteFolderRelation(
            noteId: noteId,
            folderId: folderId,
          ),
        );
      }

      return true;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to push note operation',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId, 'kind': op.kind},
      );
      _captureRepositoryException(
        method: '_pushNoteOp',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId, 'kind': op.kind},
      );
      return false;
    }
  }

  Future<bool> _pushFolderOp(PendingOp op) async {
    final folderId = op.entityId;
    try {
      final localFolder = await db.getFolderById(folderId);
      final isDeletion =
          op.kind == 'delete_folder' || localFolder?.deleted == true;

      if (localFolder == null && !isDeletion) {
        _logger.warning(
          'Pending folder operation references missing folder',
          data: {'folderId': folderId, 'kind': op.kind},
        );
        return true;
      }

      final userId =
          localFolder?.userId ?? _supabase.auth.currentUser?.id ?? '';
      if (userId.isEmpty) {
        _logger.warning(
          'Cannot push folder operation without authenticated user',
          data: {'folderId': folderId, 'kind': op.kind},
        );
        return false;
      }

      final name = localFolder?.name ?? '';
      final props = <String, dynamic>{
        'parentId': localFolder?.parentId,
        'color': localFolder?.color,
        'icon': localFolder?.icon,
        'description': localFolder?.description,
        'sortOrder': localFolder?.sortOrder,
        'path': localFolder?.path,
        'deleted': isDeletion,
        'updatedAt': (localFolder?.updatedAt ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
      }..removeWhere((key, value) => value == null);

      final nameEnc = await crypto.encryptJsonForNote(
        userId: userId,
        noteId: folderId,
        json: {'name': name},
      );

      final propsEnc = await crypto.encryptJsonForNote(
        userId: userId,
        noteId: folderId,
        json: props,
      );

      final success = await _executeWithRetry(
        operation: 'folders.upsert',
        metadata: {'folderId': folderId, 'kind': op.kind},
        run: () => _secureApi.upsertEncryptedFolder(
          id: folderId,
          nameEnc: nameEnc,
          propsEnc: propsEnc,
          deleted: isDeletion,
        ),
      );

      return success;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to push folder operation',
        error: error,
        stackTrace: stackTrace,
        data: {'folderId': folderId, 'kind': op.kind},
      );
      _captureRepositoryException(
        method: '_pushFolderOp',
        error: error,
        stackTrace: stackTrace,
        data: {'folderId': folderId, 'kind': op.kind},
      );
      return false;
    }
  }

  Future<bool> _pushTaskOp(PendingOp op) async {
    final taskId = op.entityId;
    try {
      if (op.kind == 'delete_task') {
        return await _executeWithRetry(
          operation: 'tasks.delete',
          metadata: {'taskId': taskId},
          run: () => _secureApi.deleteNoteTask(id: taskId),
        );
      }

      final userId = _supabase.auth.currentUser?.id ?? '';
      if (userId.isEmpty) {
        _logger.warning(
          'Cannot push task operation without authenticated user',
          data: {'taskId': taskId, 'kind': op.kind},
        );
        return false;
      }

      final localTask = await db.getTaskById(taskId, userId: userId);
      if (localTask == null) {
        _logger.warning(
          'Pending task operation references missing task',
          data: {'taskId': taskId, 'kind': op.kind},
        );
        return true;
      }

      final content = await _decryptTaskField(
        encrypted: localTask.contentEncrypted,
        userId: userId,
        noteId: localTask.noteId,
      );

      final notes = await _decryptOptionalTaskField(
        encrypted: localTask.notesEncrypted,
        userId: userId,
        noteId: localTask.noteId,
      );

      final tags = await _decryptTaskTags(
        encrypted: localTask.labelsEncrypted,
        userId: userId,
        noteId: localTask.noteId,
      );

      final metadata = <String, dynamic>{
        'estimatedMinutes': localTask.estimatedMinutes,
        'actualMinutes': localTask.actualMinutes,
        'reminderId': localTask.reminderId,
        'contentHash': localTask.contentHash,
        'position': localTask.position,
        'createdAt': localTask.createdAt.toIso8601String(),
        'updatedAt': localTask.updatedAt.toIso8601String(),
        if (localTask.completedBy != null) 'completedBy': localTask.completedBy,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (localTask.parentTaskId != null)
          'parentTaskId': localTask.parentTaskId,
      }..removeWhere((key, value) => value == null);

      final labels = tags.isNotEmpty ? <String, dynamic>{'labels': tags} : null;

      return await _executeWithRetry(
        operation: 'tasks.upsert',
        metadata: {
          'taskId': taskId,
          'noteId': localTask.noteId,
          'kind': op.kind,
        },
        run: () => _secureApi.upsertNoteTask(
          id: localTask.id,
          noteId: localTask.noteId,
          content: content,
          status: _mapTaskStatusToRemote(localTask.status),
          priority: localTask.priority.index,
          position: localTask.position,
          dueDate: localTask.dueDate,
          completedAt: localTask.completedAt,
          parentId: localTask.parentTaskId,
          labels: labels,
          metadata: metadata,
          deleted: localTask.deleted,
        ),
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to push task operation',
        error: error,
        stackTrace: stackTrace,
        data: {'taskId': taskId, 'kind': op.kind},
      );
      _captureRepositoryException(
        method: '_pushTaskOp',
        error: error,
        stackTrace: stackTrace,
        data: {'taskId': taskId, 'kind': op.kind},
      );
      return false;
    }
  }

  Future<bool> _pushTemplateOp(PendingOp op) async {
    final templateId = op.entityId;
    try {
      if (op.kind == 'delete_template') {
        return await _executeWithRetry(
          operation: 'templates.delete',
          metadata: {'templateId': templateId},
          run: () => _secureApi.deleteTemplate(id: templateId),
        );
      }

      final localTemplate = await db.getTemplate(templateId);
      if (localTemplate == null) {
        _logger.warning(
          'Pending template operation references missing template',
          data: {'templateId': templateId, 'kind': op.kind},
        );
        return true;
      }

      if (localTemplate.isSystem) {
        _logger.debug(
          'Skipping remote sync for system template',
          data: {'templateId': templateId},
        );
        return true;
      }

      final userId =
          localTemplate.userId ?? _supabase.auth.currentUser?.id ?? '';
      if (userId.isEmpty) {
        _logger.warning(
          'Cannot push template operation without authenticated user',
          data: {'templateId': templateId, 'kind': op.kind},
        );
        return false;
      }

      final titleEnc = await _encryptTemplateField(
        userId: userId,
        templateId: templateId,
        value: localTemplate.title,
      );

      final bodyEnc = await _encryptTemplateField(
        userId: userId,
        templateId: templateId,
        value: localTemplate.body,
      );

      final tagsJson = localTemplate.tags.isNotEmpty
          ? localTemplate.tags
          : '[]';
      final tagsEnc = tagsJson.isNotEmpty
          ? await _encryptTemplateField(
              userId: userId,
              templateId: templateId,
              value: tagsJson,
            )
          : null;

      final descriptionEnc = localTemplate.description.isNotEmpty
          ? await _encryptTemplateField(
              userId: userId,
              templateId: templateId,
              value: localTemplate.description,
            )
          : null;

      final propsEnc =
          localTemplate.metadata != null && localTemplate.metadata!.isNotEmpty
          ? await _encryptTemplateField(
              userId: userId,
              templateId: templateId,
              value: localTemplate.metadata!,
            )
          : null;

      return await _executeWithRetry(
        operation: 'templates.upsert',
        metadata: {'templateId': templateId, 'userId': userId, 'kind': op.kind},
        run: () => _secureApi.upsertTemplate(
          id: templateId,
          userId: userId,
          titleEnc: titleEnc,
          bodyEnc: bodyEnc,
          tagsEnc: tagsEnc,
          isSystem: localTemplate.isSystem,
          category: localTemplate.category,
          descriptionEnc: descriptionEnc,
          icon: localTemplate.icon,
          sortOrder: localTemplate.sortOrder,
          propsEnc: propsEnc,
          deleted: false,
        ),
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to push template operation',
        error: error,
        stackTrace: stackTrace,
        data: {'templateId': templateId, 'kind': op.kind},
      );
      _captureRepositoryException(
        method: '_pushTemplateOp',
        error: error,
        stackTrace: stackTrace,
        data: {'templateId': templateId, 'kind': op.kind},
      );
      return false;
    }
  }

  Future<void> _applyRemoteNote(Map<String, dynamic> remoteNote) async {
    final noteId = remoteNote['id'] as String;
    try {
      final userId =
          remoteNote['user_id'] as String? ??
          _supabase.auth.currentUser?.id ??
          '';
      if (userId.isEmpty) {
        throw StateError('Missing user id for remote note $noteId');
      }

      final titleEnc = remoteNote['title_enc'];
      final propsEnc = remoteNote['props_enc'];

      Map<String, dynamic> titleJson = const {};
      Map<String, dynamic> propsJson = const {};

      if (titleEnc is Uint8List) {
        titleJson = await crypto.decryptJsonForNote(
          userId: userId,
          noteId: noteId,
          data: titleEnc,
        );
      }

      if (propsEnc is Uint8List) {
        propsJson = await crypto.decryptJsonForNote(
          userId: userId,
          noteId: noteId,
          data: propsEnc,
        );
      }

      final title = titleJson['title']?.toString() ?? '';
      final body = propsJson['body']?.toString() ?? '';
      final tags =
          (propsJson['tags'] as List?)?.map((tag) => tag.toString()).toList() ??
          const <String>[];
      final linksJson = propsJson['links'];
      final isPinned = propsJson['isPinned'] as bool? ?? false;
      final folderId = propsJson['folderId']?.toString();
      final metadata = propsJson['metadata'];
      final attachmentMeta = propsJson['attachmentMeta'];
      final deleted =
          remoteNote['deleted'] == true || propsJson['deleted'] == true;
      final version =
          (propsJson['version'] as num?)?.toInt() ??
          (remoteNote['version'] as num?)?.toInt() ??
          1;
      // PRODUCTION SAFETY: Fail fast on invalid timestamps instead of silent corruption
      // Using DateTime.now() as fallback would create incorrect note ages
      final createdAtStr = remoteNote['created_at']?.toString();
      final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
      if (createdAt == null) {
        _logger.error(
          'Invalid created_at timestamp from remote - skipping note',
          data: {'noteId': noteId, 'created_at_value': createdAtStr},
        );
        unawaited(Sentry.captureMessage(
          'Timestamp corruption prevented: Invalid created_at from remote',
          level: SentryLevel.warning,
        ));
        return; // Skip this note instead of corrupting local data
      }

      final updatedAtStr = remoteNote['updated_at']?.toString();
      final updatedAt = updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null;
      if (updatedAt == null) {
        _logger.error(
          'Invalid updated_at timestamp from remote - skipping note',
          data: {'noteId': noteId, 'updated_at_value': updatedAtStr},
        );
        unawaited(Sentry.captureMessage(
          'Timestamp corruption prevented: Invalid updated_at from remote',
          level: SentryLevel.warning,
        ));
        return; // Skip this note instead of corrupting local data
      }
      final noteTypeIndex =
          (remoteNote['note_type'] as num?)?.toInt() ??
          (propsJson['noteType'] as num?)?.toInt() ??
          NoteKind.note.index;
      final noteType =
          NoteKind.values[noteTypeIndex.clamp(0, NoteKind.values.length - 1)];

      final titleEncryptedBytes = await crypto.encryptStringForNote(
        userId: userId,
        noteId: noteId,
        text: title,
      );
      final bodyEncryptedBytes = await crypto.encryptStringForNote(
        userId: userId,
        noteId: noteId,
        text: body,
      );

      final localNote = LocalNote(
        id: noteId,
        titleEncrypted: base64.encode(titleEncryptedBytes),
        bodyEncrypted: base64.encode(bodyEncryptedBytes),
        createdAt: createdAt,
        updatedAt: updatedAt,
        deleted: deleted,
        userId: userId,
        noteType: noteType,
        isPinned: isPinned,
        version: version,
        attachmentMeta: attachmentMeta is String
            ? attachmentMeta
            : attachmentMeta != null
            ? jsonEncode(attachmentMeta)
            : null,
        metadata: metadata is String
            ? metadata
            : metadata != null
            ? jsonEncode(metadata)
            : null,
        encryptedMetadata: null,
        encryptionVersion: 1,
      );

      await db.upsertNote(localNote);
      await db.replaceTagsForNote(noteId, tags.toSet());

      if (linksJson is List) {
        final linkMaps = linksJson.map<Map<String, String?>>((link) {
          if (link is Map) {
            return {
              'title':
                  link['title']?.toString() ?? link['targetTitle']?.toString(),
              'id': link['id']?.toString() ?? link['targetId']?.toString(),
            };
          }
          return {'title': link.toString(), 'id': null};
        }).toList();
        await db.replaceLinksForNote(noteId, linkMaps);
      } else {
        await db.replaceLinksForNote(noteId, const []);
      }

      if (folderId != null && folderId.isNotEmpty) {
        await db.moveNoteToFolder(noteId, folderId, expectedUserId: userId);
      } else {
        await db.moveNoteToFolder(noteId, null, expectedUserId: userId);
      }

      final domainNote = await getNoteById(noteId);
      if (domainNote != null) {
        await _indexer.indexNote(domainNote);
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to apply remote note',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      _captureRepositoryException(
        method: '_applyRemoteNote',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
    }
  }

  Future<void> _applyRemoteFolder(Map<String, dynamic> remoteFolder) async {
    final folderId = remoteFolder['id'] as String;
    try {
      final userId =
          remoteFolder['user_id'] as String? ??
          _supabase.auth.currentUser?.id ??
          '';
      if (userId.isEmpty) {
        throw StateError('Missing user id for remote folder $folderId');
      }

      final nameEnc = remoteFolder['name_enc'];
      final propsEnc = remoteFolder['props_enc'];

      Map<String, dynamic> nameJson = const {};
      Map<String, dynamic> propsJson = const {};

      if (nameEnc is Uint8List) {
        nameJson = await crypto.decryptJsonForNote(
          userId: userId,
          noteId: folderId,
          data: nameEnc,
        );
      }

      if (propsEnc is Uint8List) {
        propsJson = await crypto.decryptJsonForNote(
          userId: userId,
          noteId: folderId,
          data: propsEnc,
        );
      }

      final name = nameJson['name']?.toString() ?? '';
      final parentId = propsJson['parentId']?.toString();
      final color = propsJson['color']?.toString();
      final icon = propsJson['icon']?.toString();
      final description = propsJson['description']?.toString() ?? '';
      final path = propsJson['path']?.toString() ?? '';
      final sortOrder = (propsJson['sortOrder'] as num?)?.toInt() ?? 0;
      final deleted =
          remoteFolder['deleted'] == true || propsJson['deleted'] == true;

      // PRODUCTION SAFETY: Fail fast on invalid timestamps
      final createdAtStr = remoteFolder['created_at']?.toString();
      final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
      if (createdAt == null) {
        _logger.error(
          'Invalid created_at timestamp from remote folder - skipping',
          data: {'folderId': folderId, 'created_at_value': createdAtStr},
        );
        unawaited(Sentry.captureMessage(
          'Timestamp corruption prevented: Invalid folder created_at',
          level: SentryLevel.warning,
        ));
        return;
      }

      final updatedAtStr = remoteFolder['updated_at']?.toString();
      final updatedAt = updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null;
      if (updatedAt == null) {
        _logger.error(
          'Invalid updated_at timestamp from remote folder - skipping',
          data: {'folderId': folderId, 'updated_at_value': updatedAtStr},
        );
        unawaited(Sentry.captureMessage(
          'Timestamp corruption prevented: Invalid folder updated_at',
          level: SentryLevel.warning,
        ));
        return;
      }

      final localFolder = LocalFolder(
        id: folderId,
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
      );

      await db.upsertFolder(localFolder);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to apply remote folder',
        error: error,
        stackTrace: stackTrace,
        data: {'folderId': folderId},
      );
      _captureRepositoryException(
        method: '_applyRemoteFolder',
        error: error,
        stackTrace: stackTrace,
        data: {'folderId': folderId},
      );
    }
  }

  Future<void> _applyRemoteTask(Map<String, dynamic> remoteTask) async {
    final taskId = remoteTask['id'] as String?;
    final noteId = remoteTask['note_id'] as String?;
    if (taskId == null || noteId == null || noteId.isEmpty) {
      _logger.warning('Remote task missing identifiers', data: remoteTask);
      return;
    }

    final userId =
        remoteTask['user_id'] as String? ??
        _supabase.auth.currentUser?.id ??
        '';
    if (userId.isEmpty) {
      _logger.warning(
        'Unable to apply remote task without user id',
        data: {'taskId': taskId},
      );
      return;
    }

    final deleted = remoteTask['deleted'] as bool? ?? false;
    if (deleted) {
      await db.deleteTaskById(taskId, userId);
      return;
    }

    final content = remoteTask['content'] as String? ?? '';
    final metadataRaw = remoteTask['metadata'];
    final metadata = metadataRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(metadataRaw)
        : <String, dynamic>{};

    final labelsRaw = remoteTask['labels'];
    final tags = <String>[];
    if (labelsRaw is Map && labelsRaw['labels'] is List) {
      tags.addAll((labelsRaw['labels'] as List).map((e) => e.toString()));
    }

    final description = metadata['notes'] as String?;

    final contentEnc = utf8.decode(
      await crypto.encryptStringForNote(
        userId: userId,
        noteId: noteId,
        text: content,
      ),
    );

    final notesEnc = description != null && description.isNotEmpty
        ? utf8.decode(
            await crypto.encryptStringForNote(
              userId: userId,
              noteId: noteId,
              text: description,
            ),
          )
        : null;

    final tagsJson = tags.isNotEmpty ? jsonEncode(tags) : null;
    final labelsEnc = tagsJson != null
        ? utf8.decode(
            await crypto.encryptStringForNote(
              userId: userId,
              noteId: noteId,
              text: tagsJson,
            ),
          )
        : null;

    final status = _mapRemoteTaskStatus(
      (remoteTask['status'] as String? ?? 'open'),
    );
    final priority = _mapRemoteTaskPriority(
      remoteTask['priority'] as int? ?? 1,
    );
    final position = remoteTask['position'] as int? ?? 0;

    final dueDate = remoteTask['due_date'] != null
        ? DateTime.tryParse(remoteTask['due_date'] as String)
        : null;
    final completedAt = remoteTask['completed_at'] != null
        ? DateTime.tryParse(remoteTask['completed_at'] as String)
        : null;

    final companion = NoteTasksCompanion(
      id: Value(taskId),
      noteId: Value(noteId),
      contentEncrypted: Value(contentEnc),
      notesEncrypted: Value(notesEnc),
      labelsEncrypted: Value(labelsEnc),
      status: Value(status),
      priority: Value(priority),
      dueDate: Value(dueDate),
      completedAt: Value(completedAt),
      completedBy: Value(metadata['completedBy'] as String?),
      position: Value(position),
      contentHash: Value(
        metadata['contentHash'] as String? ?? stableTaskHash(noteId, content),
      ),
      reminderId: Value((metadata['reminderId'] as num?)?.toInt()),
      estimatedMinutes: Value((metadata['estimatedMinutes'] as num?)?.toInt()),
      actualMinutes: Value((metadata['actualMinutes'] as num?)?.toInt()),
      parentTaskId: Value(
        remoteTask['parent_id'] as String? ??
            metadata['parentTaskId'] as String?,
      ),
      createdAt: Value(
        () {
          final createdAtStr = remoteTask['created_at'] as String?;
          final parsed = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
          if (parsed == null) {
            _logger.error(
              'Invalid created_at timestamp from remote task - using current time',
              data: {'taskId': taskId, 'created_at_value': createdAtStr},
            );
            unawaited(Sentry.captureMessage(
              'Timestamp fallback: Invalid task created_at',
              level: SentryLevel.warning,
            ));
          }
          return parsed ?? DateTime.now().toUtc();
        }(),
      ),
      updatedAt: Value(
        () {
          final updatedAtStr = remoteTask['updated_at'] as String?;
          final parsed = updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null;
          if (parsed == null) {
            _logger.error(
              'Invalid updated_at timestamp from remote task - using current time',
              data: {'taskId': taskId, 'updated_at_value': updatedAtStr},
            );
            unawaited(Sentry.captureMessage(
              'Timestamp fallback: Invalid task updated_at',
              level: SentryLevel.warning,
            ));
          }
          return parsed ?? DateTime.now().toUtc();
        }(),
      ),
      deleted: const Value(false),
      encryptionVersion: const Value(1),
    );

    await db.into(db.noteTasks).insertOnConflictUpdate(companion);
  }

  Future<void> _applyRemoteTemplate(Map<String, dynamic> remoteTemplate) async {
    final templateId = remoteTemplate['id'] as String?;
    if (templateId == null) {
      _logger.warning('Remote template missing id', data: remoteTemplate);
      return;
    }

    final deleted = remoteTemplate['deleted'] as bool? ?? false;
    if (deleted) {
      await db.deleteTemplate(templateId);
      return;
    }

    final userId =
        remoteTemplate['user_id'] as String? ??
        _supabase.auth.currentUser?.id ??
        '';
    if (userId.isEmpty) {
      _logger.warning(
        'Unable to apply remote template without user id',
        data: {'templateId': templateId},
      );
      return;
    }

    final title =
        await _decryptTemplateField(
          encrypted: remoteTemplate['title_enc'] as String?,
          userId: userId,
          templateId: templateId,
        ) ??
        'Untitled Template';

    final body =
        await _decryptTemplateField(
          encrypted: remoteTemplate['body_enc'] as String?,
          userId: userId,
          templateId: templateId,
        ) ??
        '';

    final tags =
        await _decryptTemplateField(
          encrypted: remoteTemplate['tags_enc'] as String?,
          userId: userId,
          templateId: templateId,
        ) ??
        '[]';

    final description =
        await _decryptTemplateField(
          encrypted: remoteTemplate['description_enc'] as String?,
          userId: userId,
          templateId: templateId,
        ) ??
        'Template description';

    final metadata = await _decryptTemplateField(
      encrypted: remoteTemplate['props_enc'] as String?,
      userId: userId,
      templateId: templateId,
    );

    final localTemplate = LocalTemplate(
      id: templateId,
      userId: userId,
      title: title,
      body: body,
      tags: tags,
      isSystem: remoteTemplate['is_system'] as bool? ?? false,
      category: remoteTemplate['category'] as String? ?? 'general',
      description: description,
      icon: remoteTemplate['icon'] as String? ?? 'description',
      sortOrder: remoteTemplate['sort_order'] as int? ?? 0,
      metadata: metadata,
      createdAt: () {
        final createdAtStr = remoteTemplate['created_at'] as String?;
        final parsed = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
        if (parsed == null) {
          _logger.error(
            'Invalid created_at timestamp from remote template - using current time',
            data: {'templateId': templateId, 'created_at_value': createdAtStr},
          );
          unawaited(Sentry.captureMessage(
            'Timestamp fallback: Invalid template created_at',
            level: SentryLevel.warning,
          ));
        }
        return parsed ?? DateTime.now().toUtc();
      }(),
      updatedAt: () {
        final updatedAtStr = remoteTemplate['updated_at'] as String?;
        final parsed = updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null;
        if (parsed == null) {
          _logger.error(
            'Invalid updated_at timestamp from remote template - using current time',
            data: {'templateId': templateId, 'updated_at_value': updatedAtStr},
          );
          unawaited(Sentry.captureMessage(
            'Timestamp fallback: Invalid template updated_at',
            level: SentryLevel.warning,
          ));
        }
        return parsed ?? DateTime.now().toUtc();
      }(),
    );

    await db.upsertTemplate(localTemplate);
  }

  Future<void> _syncNoteFolderRelations() async {
    try {
      final relations = await _secureApi.fetchNoteFolderRelations();
      await db.transaction(() async {
        await db.delete(db.noteFolders).go();
        for (final relation in relations) {
          final noteId = relation['note_id'] as String?;
          final folderId = relation['folder_id'] as String?;
          final relationUserId = relation['user_id'] as String?;
          if (noteId == null) continue;
          await db.moveNoteToFolder(
            noteId,
            folderId,
            expectedUserId: relationUserId,
          );
        }
      });
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to sync note-folder relations',
        error: error,
        stackTrace: stackTrace,
      );
      _captureRepositoryException(
        method: '_syncNoteFolderRelations',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  // Expose client for compatibility
  SupabaseClient get client => _supabase;

  @override
  Future<domain.Note?> getNoteById(String id) async {
    try {
      final userId = _requireUserId(
        method: 'getNoteById',
        data: {'noteId': id},
      );
      if (userId == null) {
        return null;
      }

      final localNote =
          await (db.select(db.localNotes)..where(
                (note) => note.id.equals(id) & note.userId.equals(userId),
              ))
              .getSingleOrNull();

      if (localNote == null) {
        return null;
      }

      return await _hydrateDomainNote(localNote);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to get note by id',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': id},
      );
      _captureRepositoryException(
        method: 'getNoteById',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': id},
      );
      return null;
    }
  }

  @override
  Future<domain.Note?> createOrUpdate({
    required String title,
    required String body,
    String? id,
    String? folderId,
    List<String> tags = const [],
    List<Map<String, String?>> links = const [],
    Map<String, dynamic>? attachmentMeta,
    Map<String, dynamic>? metadataJson,
    bool? isPinned,
    DateTime? createdAt, // SYNC FIX: Allow sync to preserve remote timestamps
    DateTime? updatedAt, // SYNC FIX: Allow sync to preserve remote timestamps
  }) async {
    final noteId = id ?? _uuid.v4();
    final traceId = TraceContext.currentNoteSaveTrace;

    try {
      final existingNote = await (db.select(
        db.localNotes,
      )..where((note) => note.id.equals(noteId))).getSingleOrNull();

      final now = DateTime.now().toUtc();
      // SYNC FIX: Use provided timestamps if available (from sync), otherwise use now (user creation)
      final finalCreatedAt = createdAt ?? existingNote?.createdAt ?? now;
      // TIMESTAMP FIX: Preserve existing updated_at unless explicitly provided or creating new note
      final finalUpdatedAt = updatedAt ?? existingNote?.updatedAt ?? now;
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _logger.warning(
          'createOrUpdate called without authenticated user',
          data: {'noteId': noteId, 'hasIncomingId': id != null},
        );
        final authorizationError = StateError(
          'Cannot create note without authenticated user',
        );
        _logger.warning(
          'Cannot create note without authenticated user',
          data: {'noteId': noteId, 'hasIncomingId': id != null},
        );
        _captureRepositoryException(
          method: 'createOrUpdate',
          error: authorizationError,
          stackTrace: StackTrace.current,
          data: {'noteId': noteId, 'hasIncomingId': id != null},
          level: SentryLevel.warning,
        );
        return null;
      }

      _logger.info(
        'Creating/updating note locally',
        data: {
          'noteId': noteId,
          'isUpdate': existingNote != null,
          'titleLength': title.length,
          'bodyLength': body.length,
          'isPinnedIncoming': isPinned,
          'attachmentMetaProvided': attachmentMeta != null,
          if (traceId != null) 'traceId': traceId,
        },
      );
      debugPrint(
        '[NotesCoreRepository] createOrUpdate noteId=$noteId '
        'isUpdate=${existingNote != null} titleLen=${title.length} '
        'bodyLen=${body.length} traceId=${traceId ?? "none"}',
      );

      // Encrypt title and body
      final titleEncryptedBytes = await crypto.encryptStringForNote(
        userId: userId,
        noteId: noteId,
        text: title,
      );
      final bodyEncryptedBytes = await crypto.encryptStringForNote(
        userId: userId,
        noteId: noteId,
        text: body,
      );

      // CRITICAL FIX: Use base64.encode() for binary encrypted data, NOT utf8.decode()
      // Encrypted bytes are NOT valid UTF-8 text and will be corrupted
      await db.upsertNote(
        LocalNote(
          id: noteId,
          titleEncrypted: base64.encode(titleEncryptedBytes),
          bodyEncrypted: base64.encode(bodyEncryptedBytes),
          deleted: false,
          createdAt: finalCreatedAt, // SYNC FIX: Use preserved remote timestamp
          updatedAt: finalUpdatedAt, // SYNC FIX: Use preserved remote timestamp
          userId: userId,
          noteType: NoteKind.note,
          version: (existingNote?.version ?? 0) + 1,
          attachmentMeta: attachmentMeta != null
              ? jsonEncode(attachmentMeta)
              : existingNote?.attachmentMeta,
          metadata: metadataJson != null
              ? jsonEncode(metadataJson)
              : existingNote?.metadata,
          isPinned: isPinned ?? existingNote?.isPinned ?? false,
          encryptionVersion: 1,
        ),
      );

      // Update folder relationship if provided
      if (folderId != null) {
        await db.moveNoteToFolder(noteId, folderId, expectedUserId: userId);
      }

      // Update tags
      await db.replaceTagsForNote(noteId, tags.toSet());

      // Update links - persist bidirectional relationships
      // Always call to handle both setting and clearing links
      await db.replaceLinksForNote(noteId, links);

      // Index the note - get fresh domain Note
      final noteToIndex = await getNoteById(noteId);
      if (noteToIndex != null) {
        await _indexer.indexNote(noteToIndex);
      }

      // Enqueue for sync
      await _enqueuePendingOp(entityId: noteId, kind: 'upsert_note');

      MutationEventBus.instance.emitNote(
        kind: existingNote != null
            ? MutationKind.updated
            : MutationKind.created,
        noteId: noteId,
        traceId: traceId,
        metadata: {
          'hasFolder': folderId != null,
          'tagCount': tags.length,
          'isPinned': isPinned ?? existingNote?.isPinned ?? false,
        },
      );

      _logger.info(
        'Note persisted locally and queued for sync',
        data: {
          'noteId': noteId,
          'hasFolderId': folderId != null,
          'tagCount': tags.length,
          if (traceId != null) 'traceId': traceId,
        },
      );
      debugPrint(
        '[NotesCoreRepository] note persisted noteId=$noteId '
        'folder=${folderId ?? "null"} tagCount=${tags.length} traceId=${traceId ?? "none"}',
      );

      return await getNoteById(noteId);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to create or update note',
        error: error,
        stackTrace: stackTrace,
        data: {
          'noteId': noteId,
          'hasIncomingId': id != null,
          'folderId': folderId,
          'tagCount': tags.length,
          if (traceId != null) 'traceId': traceId,
        },
      );
      debugPrint(
        '[NotesCoreRepository] createOrUpdate failed noteId=$noteId traceId=${traceId ?? "none"} -> $error',
      );
      _captureRepositoryException(
        method: 'createOrUpdate',
        error: error,
        stackTrace: stackTrace,
        data: {
          'noteId': noteId,
          'hasIncomingId': id != null,
          'folderId': folderId,
          'tagCount': tags.length,
        },
      );
      rethrow;
    }
  }

  @override
  Future<void> updateLocalNote(
    String id, {
    String? title,
    String? body,
    bool? deleted,
    String? folderId,
    bool updateFolder = false,
    Map<String, dynamic>? attachmentMeta,
    Map<String, dynamic>? metadata,
    List<Map<String, String?>>? links,
    bool? isPinned,
  }) async {
    final traceId = TraceContext.currentNoteSaveTrace;

    try {
      final existing = await (db.select(
        db.localNotes,
      )..where((note) => note.id.equals(id))).getSingleOrNull();

      if (existing == null) {
        final missingError = StateError('Note not found');
        _logger.warning(
          'Attempted to update non-existent note',
          data: {'noteId': id},
        );
        _captureRepositoryException(
          method: 'updateLocalNote',
          error: missingError,
          stackTrace: StackTrace.current,
          data: {'noteId': id, if (traceId != null) 'traceId': traceId},
          level: SentryLevel.warning,
        );
        return;
      }

      final currentUserId = _requireUserId(
        method: 'updateLocalNote',
        data: {'noteId': id},
      );

      final noteOwnerId = existing.userId;

      if (noteOwnerId != null &&
          currentUserId != null &&
          noteOwnerId != currentUserId) {
        _logger.warning(
          'updateLocalNote blocked for mismatched user',
          data: {
            'noteId': id,
            'noteOwner': noteOwnerId,
            'requestedBy': currentUserId,
          },
        );
        return;
      }

      final activeUserId = noteOwnerId ?? currentUserId;

      if (activeUserId == null || activeUserId.isEmpty) {
        _logger.warning(
          'updateLocalNote aborted - unable to resolve active user',
          data: {'noteId': id},
        );
        return;
      }

      // Encrypt title and body if provided, otherwise keep existing
      String titleEncrypted = existing.titleEncrypted;
      String bodyEncrypted = existing.bodyEncrypted;

      if (title != null) {
        final titleEncryptedBytes = await crypto.encryptStringForNote(
          userId: activeUserId,
          noteId: id,
          text: title,
        );
        titleEncrypted = base64.encode(titleEncryptedBytes);
      }

      if (body != null) {
        final bodyEncryptedBytes = await crypto.encryptStringForNote(
          userId: activeUserId,
          noteId: id,
          text: body,
        );
        bodyEncrypted = base64.encode(bodyEncryptedBytes);
      }

      await db.upsertNote(
        LocalNote(
          id: id,
          titleEncrypted: titleEncrypted,
          bodyEncrypted: bodyEncrypted,
          deleted: deleted ?? existing.deleted,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now().toUtc(),
          userId: existing.userId,
          noteType: existing.noteType,
          version: existing.version + 1,
          attachmentMeta: attachmentMeta != null
              ? jsonEncode(attachmentMeta)
              : existing.attachmentMeta,
          metadata: metadata != null ? jsonEncode(metadata) : existing.metadata,
          isPinned: isPinned ?? existing.isPinned,
          encryptionVersion: existing.encryptionVersion,
        ),
      );

      // Update folder relationship when explicitly requested
      if (updateFolder) {
        await db.moveNoteToFolder(
          id,
          folderId,
          expectedUserId: existing.userId ?? activeUserId,
        );
      }

      // Update links if provided - persist bidirectional relationships
      // Call unconditionally to handle clearing links (empty list)
      if (links != null) {
        await db.replaceLinksForNote(id, links);
      }

      // Re-index the note - get fresh domain Note
      final noteToIndex = await getNoteById(id);
      if (noteToIndex != null) {
        await _indexer.indexNote(noteToIndex);
      }

      // Enqueue for sync
      await _enqueuePendingOp(
        entityId: id,
        kind: deleted == true ? 'delete' : 'upsert_note',
      );

      MutationEventBus.instance.emitNote(
        kind: deleted == true ? MutationKind.deleted : MutationKind.updated,
        noteId: id,
        traceId: traceId,
        metadata: {
          'deleted': deleted == true,
          if (folderId != null) 'folderId': folderId,
        },
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to update local note',
        error: error,
        stackTrace: stackTrace,
        data: {
          'noteId': id,
          'markedDeleted': deleted == true,
          if (traceId != null) 'traceId': traceId,
        },
      );
      _captureRepositoryException(
        method: 'updateLocalNote',
        error: error,
        stackTrace: stackTrace,
        data: {
          'noteId': id,
          'markedDeleted': deleted == true,
          if (traceId != null) 'traceId': traceId,
        },
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteNote(String id) async {
    await updateLocalNote(id, deleted: true);
  }

  @override
  /// Get all local notes for sync (includes system notes like standalone task container)
  Future<List<domain.Note>> localNotesForSync() async {
    try {
      final userId = _requireUserId(method: 'localNotesForSync');
      if (userId == null) {
        return const <domain.Note>[];
      }

      final localNotes =
          await (db.select(db.localNotes)
                ..where(
                  (note) =>
                      note.deleted.equals(false) & note.userId.equals(userId),
                )
                ..orderBy([
                  (note) => OrderingTerm(
                    expression: note.updatedAt,
                    mode: OrderingMode.desc,
                  ),
                ]))
              .get();

      // For sync, include ALL notes (even system notes) - don't filter by _shouldDisplayNote
      final List<domain.Note> notes = [];
      for (final localNote in localNotes) {
        final hydrated = await _hydrateDomainNote(localNote);
        if (hydrated != null) {
          notes.add(hydrated); // Include ALL notes for sync
        }
      }
      return notes;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load local notes for sync',
        error: error,
        stackTrace: stackTrace,
      );
      _captureRepositoryException(
        method: 'localNotesForSync',
        error: error,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get local notes for UI display (filters out system notes)
  @override
  Future<List<domain.Note>> localNotes() async {
    try {
      final userId = _requireUserId(method: 'localNotes');
      if (userId == null) {
        return const <domain.Note>[];
      }

      final localNotes =
          await (db.select(db.localNotes)
                ..where(
                  (note) =>
                      note.deleted.equals(false) & note.userId.equals(userId),
                )
                ..orderBy([
                  (note) => OrderingTerm(
                    expression: note.isPinned,
                    mode: OrderingMode.desc,
                  ),
                  (note) => OrderingTerm(
                    expression: note.updatedAt,
                    mode: OrderingMode.desc,
                  ),
                ]))
              .get();

      return await _hydrateDomainNotes(localNotes);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load local notes',
        error: error,
        stackTrace: stackTrace,
      );
      _captureRepositoryException(
        method: 'localNotes',
        error: error,
        stackTrace: stackTrace,
      );
      return const <domain.Note>[];
    }
  }

  @override
  Future<List<domain.Note>> getRecentlyViewedNotes({int limit = 5}) async {
    try {
      final userId = _requireUserId(
        method: 'getRecentlyViewedNotes',
        data: {'limit': limit},
      );
      if (userId == null) {
        return const <domain.Note>[];
      }

      final localNotes =
          await (db.select(db.localNotes)
                ..where(
                  (note) =>
                      note.deleted.equals(false) & note.userId.equals(userId),
                )
                ..orderBy([
                  (note) => OrderingTerm(
                    expression: note.updatedAt,
                    mode: OrderingMode.desc,
                  ),
                ])
                ..limit(limit))
              .get();

      return await _hydrateDomainNotes(localNotes);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load recently viewed notes',
        error: error,
        stackTrace: stackTrace,
        data: {'limit': limit},
      );
      _captureRepositoryException(
        method: 'getRecentlyViewedNotes',
        error: error,
        stackTrace: stackTrace,
        data: {'limit': limit},
      );
      return const <domain.Note>[];
    }
  }

  @override
  Future<List<domain.Note>> listAfter(
    DateTime? cursor, {
    int limit = 20,
  }) async {
    try {
      final userId = _requireUserId(
        method: 'listAfter',
        data: {'cursor': cursor?.toIso8601String(), 'limit': limit},
      );
      if (userId == null) {
        return const <domain.Note>[];
      }

      final query = db.select(db.localNotes)
        ..where(
          (note) => note.deleted.equals(false) & note.userId.equals(userId),
        );

      if (cursor != null) {
        query.where((note) => note.updatedAt.isSmallerThanValue(cursor));
      }

      final localNotes =
          await (query
                ..orderBy([
                  (note) => OrderingTerm(
                    expression: note.isPinned,
                    mode: OrderingMode.desc,
                  ),
                  (note) => OrderingTerm(
                    expression: note.updatedAt,
                    mode: OrderingMode.desc,
                  ),
                ])
                ..limit(limit))
              .get();

      return await _hydrateDomainNotes(localNotes);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to list notes after cursor',
        error: error,
        stackTrace: stackTrace,
        data: {'cursor': cursor?.toIso8601String(), 'limit': limit},
      );
      _captureRepositoryException(
        method: 'listAfter',
        error: error,
        stackTrace: stackTrace,
        data: {'cursor': cursor?.toIso8601String(), 'limit': limit},
      );
      return const <domain.Note>[];
    }
  }

  @override
  Future<void> toggleNotePin(String noteId) async {
    try {
      final userId = _requireUserId(
        method: 'toggleNotePin',
        data: {'noteId': noteId},
      );
      if (userId == null) {
        return;
      }

      final localNote =
          await (db.select(db.localNotes)..where(
                (note) =>
                    db.noteIsVisible(note) &
                    note.id.equals(noteId) &
                    note.userId.equals(userId),
              ))
              .getSingleOrNull();

      if (localNote == null) {
        _logger.warning(
          'toggleNotePin attempted on missing or unauthorized note',
          data: {'noteId': noteId, 'userId': userId},
        );
        return;
      }

      final updatedNote = localNote.copyWith(
        isPinned: !localNote.isPinned,
        updatedAt: DateTime.now(),
      );

      await db.upsertNote(updatedNote);
      await _enqueuePendingOp(entityId: noteId, kind: 'upsert_note');

      MutationEventBus.instance.emitNote(
        kind: MutationKind.updated,
        noteId: noteId,
        metadata: const {'pinToggled': true},
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to toggle note pin state',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      _captureRepositoryException(
        method: 'toggleNotePin',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );
      rethrow;
    }
  }

  @override
  Future<void> setNotePin(String noteId, bool isPinned) async {
    try {
      final userId = _requireUserId(
        method: 'setNotePin',
        data: {'noteId': noteId, 'isPinned': isPinned},
      );
      if (userId == null) {
        return;
      }

      final localNote =
          await (db.select(db.localNotes)..where(
                (note) =>
                    db.noteIsVisible(note) &
                    note.id.equals(noteId) &
                    note.userId.equals(userId),
              ))
              .getSingleOrNull();

      if (localNote == null) {
        _logger.warning(
          'setNotePin attempted on missing or unauthorized note',
          data: {'noteId': noteId, 'userId': userId, 'isPinned': isPinned},
        );
        return;
      }

      if (localNote.isPinned == isPinned) {
        _logger.debug(
          'setNotePin no-op for note already in desired state',
          data: {'noteId': noteId, 'userId': userId, 'isPinned': isPinned},
        );
        return;
      }

      final updatedNote = localNote.copyWith(
        isPinned: isPinned,
        updatedAt: DateTime.now(),
      );

      await db.upsertNote(updatedNote);
      await _enqueuePendingOp(entityId: noteId, kind: 'upsert_note');

      MutationEventBus.instance.emitNote(
        kind: MutationKind.updated,
        noteId: noteId,
        metadata: {'pinSet': isPinned},
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to set note pin state',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId, 'isPinned': isPinned},
      );
      _captureRepositoryException(
        method: 'setNotePin',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': noteId, 'isPinned': isPinned},
      );
      rethrow;
    }
  }

  @override
  Future<List<domain.Note>> getPinnedNotes() async {
    try {
      final userId = _requireUserId(method: 'getPinnedNotes');
      if (userId == null) {
        return const <domain.Note>[];
      }

      final query = db.select(db.localNotes)
        ..where(
          (note) =>
              db.noteIsVisible(note) &
              note.userId.equals(userId) &
              note.isPinned.equals(true),
        )
        ..orderBy([
          (note) =>
              OrderingTerm(expression: note.isPinned, mode: OrderingMode.desc),
          (note) =>
              OrderingTerm(expression: note.updatedAt, mode: OrderingMode.desc),
        ]);

      final localNotes = await query.get();
      return await _hydrateDomainNotes(localNotes);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to get pinned notes',
        error: error,
        stackTrace: stackTrace,
      );
      _captureRepositoryException(
        method: 'getPinnedNotes',
        error: error,
        stackTrace: stackTrace,
      );
      return const <domain.Note>[];
    }
  }

  @override
  Stream<List<domain.Note>> watchNotes({
    String? folderId,
    List<String>? anyTags,
    List<String>? noneTags,
    bool pinnedFirst = true,
  }) {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      _logger.warning(
        'watchNotes called without authenticated user',
        data: {
          'folderId': folderId,
          'anyTagsCount': anyTags?.length ?? 0,
          'noneTagsCount': noneTags?.length ?? 0,
          'pinnedFirst': pinnedFirst,
        },
      );
      return Stream.value(const <domain.Note>[]);
    }

    // Build query with filters
    return (db.select(db.localNotes)
          ..where((n) => n.deleted.equals(false) & n.userId.equals(userId))
          ..orderBy([
            if (pinnedFirst)
              (n) =>
                  OrderingTerm(expression: n.isPinned, mode: OrderingMode.desc),
            (n) =>
                OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch()
        .asyncMap((localNotes) async {
          try {
            return await _hydrateDomainNotes(localNotes);
          } catch (error, stackTrace) {
            _logger.error(
              'Failed to hydrate notes for watch stream',
              error: error,
              stackTrace: stackTrace,
              data: {
                'folderId': folderId,
                'anyTagsCount': anyTags?.length ?? 0,
                'noneTagsCount': noneTags?.length ?? 0,
                'pinnedFirst': pinnedFirst,
              },
            );
            _captureRepositoryException(
              method: 'watchNotes',
              error: error,
              stackTrace: stackTrace,
              data: {
                'folderId': folderId,
                'anyTagsCount': anyTags?.length ?? 0,
                'noneTagsCount': noneTags?.length ?? 0,
                'pinnedFirst': pinnedFirst,
              },
            );
            return const <domain.Note>[];
          }
        });
  }

  @override
  Future<List<domain.Note>> list({int? limit}) async {
    try {
      final userId = _requireUserId(method: 'list', data: {'limit': limit});
      if (userId == null) {
        return const <domain.Note>[];
      }

      final query = db.select(db.localNotes)
        ..where(
          (note) => note.deleted.equals(false) & note.userId.equals(userId),
        )
        ..orderBy([
          (note) =>
              OrderingTerm(expression: note.isPinned, mode: OrderingMode.desc),
          (note) =>
              OrderingTerm(expression: note.updatedAt, mode: OrderingMode.desc),
        ]);

      if (limit != null) {
        query.limit(limit);
      }

      final localNotes = await query.get();
      return await _hydrateDomainNotes(localNotes);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to list notes',
        error: error,
        stackTrace: stackTrace,
        data: {'limit': limit},
      );
      _captureRepositoryException(
        method: 'list',
        error: error,
        stackTrace: stackTrace,
        data: {'limit': limit},
      );
      return const <domain.Note>[];
    }
  }

  @override
  Future<void> sync() async {
    await pushAllPending();
    final lastSync = await getLastSyncTime();
    await pullSince(lastSync);
  }

  @override
  Future<void> pushAllPending() async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        _logger.warning(
          'Cannot push pending operations - no authenticated user',
        );
        await _securityAuditTrail.logAccess(
          resource: 'pending_ops.dequeue',
          granted: false,
          reason: 'unauthenticated',
        );
        return;
      }

      final pendingOps = await _performanceMonitor.measure<List<PendingOp>>(
        'sync.pending_ops.dequeue',
        () => db.getPendingOpsForUser(userId),
      );
      await _securityAuditTrail.logAccess(
        resource: 'pending_ops.dequeue',
        granted: true,
        reason: 'count=${pendingOps.length}',
      );
      _performanceMonitor.recordMetric(
        'sync.pending_ops.depth',
        pendingOps.length.toDouble(),
        unit: 'ops',
      );

      if (pendingOps.isEmpty) {
        _logger.debug('No pending operations to sync');
        return;
      }

      final noteOps = <PendingOp>[];
      final folderOps = <PendingOp>[];
      final taskOps = <PendingOp>[];
      final templateOps = <PendingOp>[];
      final unknownOps = <PendingOp>[];

      for (final op in pendingOps) {
        if (_isNoteOp(op.kind)) {
          noteOps.add(op);
        } else if (_isFolderOp(op.kind)) {
          folderOps.add(op);
        } else if (_isTaskOp(op.kind)) {
          taskOps.add(op);
        } else if (_isTemplateOp(op.kind)) {
          templateOps.add(op);
        } else {
          unknownOps.add(op);
        }
      }

      final processedIds = <int>[];

      for (final op in noteOps) {
        if (await _pushNoteOp(op)) {
          processedIds.add(op.id);
        }
      }

      for (final op in folderOps) {
        if (await _pushFolderOp(op)) {
          processedIds.add(op.id);
        }
      }

      for (final op in taskOps) {
        if (await _pushTaskOp(op)) {
          processedIds.add(op.id);
        }
      }

      for (final op in templateOps) {
        if (await _pushTemplateOp(op)) {
          processedIds.add(op.id);
        }
      }

      for (final op in unknownOps) {
        _logger.warning(
          'Unsupported pending operation kind encountered',
          data: {'id': op.id, 'kind': op.kind},
        );
      }

      if (processedIds.isNotEmpty) {
        await db.deletePendingByIds(userId: userId, ids: processedIds);
        _logger.info(
          'Processed ${processedIds.length} pending operations',
          data: {'remaining': pendingOps.length - processedIds.length},
        );
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to push pending operations',
        error: error,
        stackTrace: stackTrace,
      );
      _captureRepositoryException(
        method: 'pushAllPending',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> pullSince(DateTime? since) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _logger.warning(
          'Cannot pull remote updates without authenticated user',
          data: {'since': since?.toIso8601String()},
        );
        return;
      }

      final remoteNotes = await _secureApi.fetchEncryptedNotes(since: since);
      for (final note in remoteNotes) {
        try {
          await _applyRemoteNote(note);
        } catch (error, stackTrace) {
          _logger.error(
            'Failed to apply remote note',
            error: error,
            stackTrace: stackTrace,
            data: {'noteId': note['id']},
          );
          _captureRepositoryException(
            method: '_applyRemoteNote',
            error: error,
            stackTrace: stackTrace,
            data: {'noteId': note['id']},
            level: SentryLevel.warning,
          );
        }
      }

      final remoteFolders = await _secureApi.fetchEncryptedFolders(
        since: since,
      );
      for (final folder in remoteFolders) {
        try {
          await _applyRemoteFolder(folder);
        } catch (error, stackTrace) {
          _logger.error(
            'Failed to apply remote folder',
            error: error,
            stackTrace: stackTrace,
            data: {'folderId': folder['id']},
          );
          _captureRepositoryException(
            method: '_applyRemoteFolder',
            error: error,
            stackTrace: stackTrace,
            data: {'folderId': folder['id']},
            level: SentryLevel.warning,
          );
        }
      }

      final remoteTasks = await _secureApi.fetchNoteTasks(since: since);
      for (final task in remoteTasks) {
        try {
          await _applyRemoteTask(task);
        } catch (error, stackTrace) {
          _logger.error(
            'Failed to apply remote task',
            error: error,
            stackTrace: stackTrace,
            data: {'taskId': task['id']},
          );
          _captureRepositoryException(
            method: '_applyRemoteTask',
            error: error,
            stackTrace: stackTrace,
            data: {'taskId': task['id']},
            level: SentryLevel.warning,
          );
        }
      }

      final remoteTemplates = await _secureApi.fetchTemplates(since: since);
      for (final template in remoteTemplates) {
        try {
          await _applyRemoteTemplate(template);
        } catch (error, stackTrace) {
          _logger.error(
            'Failed to apply remote template',
            error: error,
            stackTrace: stackTrace,
            data: {'templateId': template['id']},
          );
          _captureRepositoryException(
            method: '_applyRemoteTemplate',
            error: error,
            stackTrace: stackTrace,
            data: {'templateId': template['id']},
            level: SentryLevel.warning,
          );
        }
      }

      await _syncNoteFolderRelations();
      await _setLastSyncTime(DateTime.now().toUtc());
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to pull remote updates',
        error: error,
        stackTrace: stackTrace,
        data: {'since': since?.toIso8601String()},
      );
      _captureRepositoryException(
        method: 'pullSince',
        error: error,
        stackTrace: stackTrace,
        data: {'since': since?.toIso8601String()},
      );
      rethrow;
    }
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    return _readLastSyncTime();
  }

  @override
  Future<int> getNotesCountInFolder(String folderId) async {
    try {
      final userId = _requireUserId(
        method: 'getNotesCountInFolder',
        data: {'folderId': folderId},
      );
      if (userId == null) {
        return 0;
      }

      final query =
          db.select(db.noteFolders).join([
            innerJoin(
              db.localNotes,
              db.localNotes.id.equalsExp(db.noteFolders.noteId),
            ),
          ])..where(
            db.noteFolders.folderId.equals(folderId) &
                db.localNotes.userId.equals(userId) &
                db.noteIsVisible(db.localNotes),
          );

      final results = await query.get();
      return results.length;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to get notes count in folder',
        error: error,
        stackTrace: stackTrace,
        data: {'folderId': folderId},
      );
      _captureRepositoryException(
        method: 'getNotesCountInFolder',
        error: error,
        stackTrace: stackTrace,
        data: {'folderId': folderId},
      );
      return 0;
    }
  }

  @override
  Future<List<String>> getNoteIdsInFolder(String folderId) async {
    try {
      final userId = _requireUserId(
        method: 'getNoteIdsInFolder',
        data: {'folderId': folderId},
      );
      if (userId == null) {
        return const <String>[];
      }

      final query =
          db.select(db.noteFolders).join([
            innerJoin(
              db.localNotes,
              db.localNotes.id.equalsExp(db.noteFolders.noteId),
            ),
          ])..where(
            db.noteFolders.folderId.equals(folderId) &
                db.localNotes.userId.equals(userId) &
                db.noteIsVisible(db.localNotes),
          );

      final relations = await query
          .map((row) => row.readTable(db.noteFolders))
          .get();

      return relations.map((relation) => relation.noteId).toList();
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to get note IDs in folder',
        error: error,
        stackTrace: stackTrace,
        data: {'folderId': folderId},
      );
      _captureRepositoryException(
        method: 'getNoteIdsInFolder',
        error: error,
        stackTrace: stackTrace,
        data: {'folderId': folderId},
      );
      return const <String>[];
    }
  }
}
