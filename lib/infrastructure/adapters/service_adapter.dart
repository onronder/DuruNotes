import 'dart:convert';

import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Adapter to enable services to work with both local and domain models
class ServiceAdapter {
  ServiceAdapter({
    required this.db,
    required this.client,
    required this.useDomainModels,
    required this.crypto,
  }) : _logger = LoggerFactory.instance;

  final AppDb db;
  final SupabaseClient client;
  final bool useDomainModels;
  final CryptoBox crypto;
  final AppLogger _logger;

  /// Process note data for services
  dynamic processNote(dynamic note) {
    return note;
  }

  /// Process task data for services
  dynamic processTask(dynamic task) {
    return task;
  }

  /// Process folder data for services
  dynamic processFolder(dynamic folder) {
    return folder;
  }

  /// Process a list of notes
  List<dynamic> processNotes(List<dynamic> notes) {
    return notes.map((note) => processNote(note)).toList();
  }

  /// Process a list of tasks
  List<dynamic> processTasks(List<dynamic> tasks) {
    return tasks.map((task) => processTask(task)).toList();
  }

  /// Process a list of folders
  List<dynamic> processFolders(List<dynamic> folders) {
    return folders.map((folder) => processFolder(folder)).toList();
  }

  /// Get note data for sync
  Map<String, dynamic> getNoteDataForSync(dynamic note) {
    if (note is domain.Note) {
      return {
        'id': note.id,
        'title': note.title,
        'body': note.body,
        'folder_id': note.folderId,
        'is_pinned': note.isPinned,
        'version': note.version,
        'tags': note.tags,
        'created_at': note.createdAt.toIso8601String(),
        'updated_at': note.updatedAt.toIso8601String(),
        'user_id': note.userId,
        'deleted': note.deleted,
        'deleted_at': note.deletedAt?.toIso8601String(),
        'scheduled_purge_at': note.scheduledPurgeAt?.toIso8601String(),
        'note_type': note.noteType.index,
      };
    } else if (note is LocalNote) {
      throw UnsupportedError('LocalNote sync requires domain models');
    }
    throw ArgumentError('Unknown note type: ${note.runtimeType}');
  }

  /// Get task data for sync
  ///
  /// SECURITY FIX: Tasks are now encrypted before sending to Supabase
  /// - Encrypts content (title), notes (description), labels (tags), and metadata
  /// - Writes to BOTH encrypted and plaintext columns during migration period
  /// - Uses note-specific key derivation for XChaCha20-Poly1305 AEAD cipher
  Future<Map<String, dynamic>> getTaskDataForSync(dynamic task) async {
    if (task is domain.Task) {
      final metadata = _buildTaskMetadata(task);
      final labels = _buildTaskLabels(task.tags);
      final position = _readInt(task.metadata['position']) ?? 0;
      final parentTaskId = task.metadata['parentTaskId'] as String?;
      final deleted =
          task.deletedAt != null || (_readBool(task.metadata['deleted']) ?? false);

      // Get user ID for encryption
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _logger.error('Cannot encrypt task without authenticated user');
        throw StateError('Not authenticated');
      }

      // Encrypt content (title) - REQUIRED
      final contentEncryptedBytes = await crypto.encryptStringForNote(
        userId: userId,
        noteId: task.noteId,
        text: task.title,
      );
      final contentEncrypted = base64.encode(contentEncryptedBytes);

      // Encrypt notes (description) - OPTIONAL
      String? notesEncrypted;
      if (task.description != null && task.description!.isNotEmpty) {
        final notesEncryptedBytes = await crypto.encryptStringForNote(
          userId: userId,
          noteId: task.noteId,
          text: task.description!,
        );
        notesEncrypted = base64.encode(notesEncryptedBytes);
      }

      // Encrypt labels (tags) - OPTIONAL
      String? labelsEncrypted;
      if (labels.isNotEmpty) {
        final labelsJson = jsonEncode(labels);
        final labelsEncryptedBytes = await crypto.encryptStringForNote(
          userId: userId,
          noteId: task.noteId,
          text: labelsJson,
        );
        labelsEncrypted = base64.encode(labelsEncryptedBytes);
      }

      // Encrypt metadata - OPTIONAL
      String? metadataEncrypted;
      if (metadata.isNotEmpty) {
        final metadataJson = jsonEncode(metadata);
        final metadataEncryptedBytes = await crypto.encryptStringForNote(
          userId: userId,
          noteId: task.noteId,
          text: metadataJson,
        );
        metadataEncrypted = base64.encode(metadataEncryptedBytes);
      }

      // MIGRATION PERIOD: Write to BOTH encrypted and plaintext columns
      // This allows rollback and gradual migration
      return {
        'id': task.id,
        'note_id': task.noteId,
        'user_id': userId,

        // ENCRYPTED COLUMNS (new)
        'content_enc': contentEncrypted,
        'notes_enc': notesEncrypted,
        'labels_enc': labelsEncrypted,
        'metadata_enc': metadataEncrypted,
        'encryption_version': 1,

        // PLAINTEXT COLUMNS (deprecated, will be removed in Phase 1.4)
        'content': task.title,
        'labels': labels,
        'metadata': metadata,

        // Non-encrypted fields
        'status': _mapDomainTaskStatus(task.status),
        'priority': _mapDomainTaskPriority(task.priority),
        'position': position,
        'due_date': task.dueDate?.toIso8601String(),
        'completed_at': task.completedAt?.toIso8601String(),
        'parent_id': parentTaskId,
        'created_at': task.createdAt.toIso8601String(),
        'updated_at': task.updatedAt.toIso8601String(),
        'deleted': deleted,
        'deleted_at': task.deletedAt?.toIso8601String(),
        'scheduled_purge_at': task.scheduledPurgeAt?.toIso8601String(),
      };
    } else if (task is NoteTask) {
      throw UnsupportedError('NoteTask sync requires domain models');
    }
    throw ArgumentError('Unknown task type: ${task.runtimeType}');
  }

  /// Get folder data for sync
  Map<String, dynamic> getFolderDataForSync(dynamic folder) {
    if (folder is domain.Folder) {
      return {
        'id': folder.id,
        'user_id': folder.userId,
        'name': folder.name,
        'parent_id': folder.parentId,
        'color': folder.color,
        'icon': folder.icon,
        'sort_order': folder.sortOrder,
        'created_at': folder.createdAt.toIso8601String(),
        'updated_at': folder.updatedAt.toIso8601String(),
        'deleted': folder.deletedAt != null,
        'deleted_at': folder.deletedAt?.toIso8601String(),
        'scheduled_purge_at': folder.scheduledPurgeAt?.toIso8601String(),
      };
    } else if (folder is LocalFolder) {
      return {
        'id': folder.id,
        'user_id': folder.userId,
        'name': folder.name,
        'parent_id': folder.parentId,
        'color': folder.color,
        'icon': folder.icon,
        'sort_order': folder.sortOrder,
        'created_at': folder.createdAt.toIso8601String(),
        'updated_at': folder.updatedAt.toIso8601String(),
        'deleted': folder.deleted,
        'deleted_at': folder.deletedAt?.toIso8601String(),
        'scheduled_purge_at': folder.scheduledPurgeAt?.toIso8601String(),
      };
    }
    throw ArgumentError('Unknown folder type: ${folder.runtimeType}');
  }

  /// Create note from sync data
  dynamic createNoteFromSync(Map<String, dynamic> data) {
    if (useDomainModels) {
      return domain.Note(
        id: data['id'] as String,
        title: (data['title'] ?? '') as String,
        body: (data['body'] ?? data['content'] ?? '') as String,
        folderId: data['folder_id'] as String?,
        isPinned: (data['is_pinned'] ?? false) as bool,
        version: (data['version'] ?? 1) as int,
        tags: data['tags'] != null
            ? List<String>.from(data['tags'] as List<dynamic>)
            : const <String>[],
        links: [], // Links need to be populated separately
        createdAt: data['created_at'] != null
            ? DateTime.parse(data['created_at'] as String)
            : DateTime.now().toUtc(),
        updatedAt: DateTime.parse(data['updated_at'] as String),
        userId: (data['user_id'] ?? '') as String,
        deleted: ((data['deleted'] ?? false) as bool) ||
            data['deleted_at'] != null,
        deletedAt: data['deleted_at'] != null
            ? DateTime.parse(data['deleted_at'] as String)
            : null,
        scheduledPurgeAt: data['scheduled_purge_at'] != null
            ? DateTime.parse(data['scheduled_purge_at'] as String)
            : null,
        noteType: data['note_type'] != null
            ? NoteKind.values[data['note_type'] as int]
            : NoteKind.note,
        encryptedMetadata: data['encrypted_metadata'] as String?,
        attachmentMeta: data['attachment_meta'] as String?,
        metadata: data['metadata'] as String?,
      );
    } else {
      // For local model, we'd need to create using companion
      // This is handled by the repository layer
      _logger.warning(
        'Creating LocalNote from sync should be handled by repository',
      );
      return data;
    }
  }

  /// Create task from sync data
  ///
  /// SECURITY FIX: Tasks are now decrypted when downloading from Supabase
  /// - Tries to decrypt from encrypted columns first (content_enc, notes_enc, labels_enc, metadata_enc)
  /// - Falls back to plaintext columns if encrypted columns are empty (migration period)
  /// - Uses note-specific key derivation for XChaCha20-Poly1305 AEAD cipher
  Future<dynamic> createTaskFromSync(Map<String, dynamic> data) async {
    if (useDomainModels) {
      // Get user ID for decryption
      final userId = client.auth.currentUser?.id;
      final noteId = data['note_id'] as String;

      // MIGRATION PERIOD: Try encrypted columns first, fallback to plaintext
      String title;
      String? description;
      List<String>? tags;
      Map<String, dynamic> metadata;

      // Decrypt content (title)
      if (data['content_enc'] != null && userId != null) {
        try {
          final contentEncBase64 = data['content_enc'] as String;
          final contentEncBytes = base64.decode(contentEncBase64);
          title = await crypto.decryptStringForNote(
            userId: userId,
            noteId: noteId,
            data: contentEncBytes,
          );
        } catch (e) {
          _logger.warning(
            'Failed to decrypt task content, falling back to plaintext: $e',
          );
          title = (data['content'] ?? '') as String;
        }
      } else {
        // Fallback to plaintext during migration period
        title = (data['content'] ?? '') as String;
      }

      // Decrypt notes (description)
      if (data['notes_enc'] != null && userId != null) {
        try {
          final notesEncBase64 = data['notes_enc'] as String;
          final notesEncBytes = base64.decode(notesEncBase64);
          description = await crypto.decryptStringForNote(
            userId: userId,
            noteId: noteId,
            data: notesEncBytes,
          );
        } catch (e) {
          _logger.warning(
            'Failed to decrypt task notes, falling back to plaintext: $e',
          );
          description = null; // Will be extracted from metadata below
        }
      }

      // Decrypt labels (tags)
      if (data['labels_enc'] != null && userId != null) {
        try {
          final labelsEncBase64 = data['labels_enc'] as String;
          final labelsEncBytes = base64.decode(labelsEncBase64);
          final labelsJson = await crypto.decryptStringForNote(
            userId: userId,
            noteId: noteId,
            data: labelsEncBytes,
          );
          final decoded = jsonDecode(labelsJson);
          tags = _normalizeStringList(decoded);
        } catch (e) {
          _logger.warning(
            'Failed to decrypt task labels, falling back to plaintext: $e',
          );
          tags = null; // Will be extracted below
        }
      }

      // Decrypt metadata
      if (data['metadata_enc'] != null && userId != null) {
        try {
          final metadataEncBase64 = data['metadata_enc'] as String;
          final metadataEncBytes = base64.decode(metadataEncBase64);
          final metadataJson = await crypto.decryptStringForNote(
            userId: userId,
            noteId: noteId,
            data: metadataEncBytes,
          );
          metadata = _parseMetadata(metadataJson);
        } catch (e) {
          _logger.warning(
            'Failed to decrypt task metadata, falling back to plaintext: $e',
          );
          metadata = _parseMetadata(data['metadata']);
        }
      } else {
        // Fallback to plaintext during migration period
        metadata = _parseMetadata(data['metadata']);
      }

      // Populate metadata with additional fields
      metadata['position'] ??= data['position'];
      metadata['parentTaskId'] ??= data['parent_id'];
      final deletedFlag = _readBool(data['deleted']) ?? false;
      metadata['deleted'] = deletedFlag || data['deleted_at'] != null;
      if (data['deleted_at'] != null) {
        metadata['deletedAt'] = data['deleted_at'];
      }
      if (data['scheduled_purge_at'] != null) {
        metadata['scheduledPurgeAt'] = data['scheduled_purge_at'];
      }
      metadata['userId'] ??= (data['user_id'] as String?) ?? userId ?? '';
      metadata.removeWhere((key, value) => value == null);

      // Extract description and tags if not already decrypted
      description ??= _extractDescription(metadata, data['notes']);
      tags ??=
          _extractTags(data['labels']) ?? _normalizeStringList(data['tags']);

      return domain.Task(
        id: data['id'] as String,
        noteId: noteId,
        title: title,
        description: description,
        status: _parseDomainTaskStatus(data['status'] as String?),
        priority: _parseDomainTaskPriority(data['priority']),
        dueDate: data['due_date'] != null
            ? DateTime.parse(data['due_date'] as String)
            : null,
        completedAt: data['completed_at'] != null
            ? DateTime.parse(data['completed_at'] as String)
            : null,
        createdAt: _parseTimestamp(data['created_at']),
        updatedAt: _parseTimestamp(data['updated_at']),
        deletedAt: data['deleted_at'] != null
            ? DateTime.parse(data['deleted_at'] as String)
            : null,
        scheduledPurgeAt: data['scheduled_purge_at'] != null
            ? DateTime.parse(data['scheduled_purge_at'] as String)
            : null,
        tags: tags ?? const <String>[],
        metadata: metadata,
      );
    } else {
      // For local model, handled by repository
      _logger.warning(
        'Creating NoteTask from sync should be handled by repository',
      );
      return data;
    }
  }

  /// Create folder from sync data
  dynamic createFolderFromSync(Map<String, dynamic> data) {
    if (useDomainModels) {
      return domain.Folder(
        id: data['id'] as String,
        name: data['name'] as String,
        parentId: data['parent_id'] as String?,
        color: data['color'] as String?,
        icon: data['icon'] as String?,
        description: data['description'] as String?,
        sortOrder: (data['sort_order'] ?? 0) as int,
        createdAt: DateTime.parse(data['created_at'] as String),
        updatedAt: DateTime.parse(data['updated_at'] as String),
        deletedAt: data['deleted_at'] != null
            ? DateTime.parse(data['deleted_at'] as String)
            : null,
        scheduledPurgeAt: data['scheduled_purge_at'] != null
            ? DateTime.parse(data['scheduled_purge_at'] as String)
            : null,
        userId: (data['user_id'] ?? '') as String,
      );
    } else {
      // For local model, handled by repository
      _logger.warning(
        'Creating LocalFolder from sync should be handled by repository',
      );
      return data;
    }
  }

  // Private helper methods

  String _mapDomainTaskStatus(domain.TaskStatus status) {
    switch (status) {
      case domain.TaskStatus.pending:
        return 'open';
      case domain.TaskStatus.inProgress:
        return 'open';
      case domain.TaskStatus.completed:
        return 'completed';
      case domain.TaskStatus.cancelled:
        return 'cancelled';
    }
  }

  int _mapDomainTaskPriority(domain.TaskPriority priority) => priority.index;

  domain.TaskStatus _parseDomainTaskStatus(String? status) {
    switch (status) {
      case 'open':
        return domain.TaskStatus.pending;
      case 'completed':
        return domain.TaskStatus.completed;
      case 'cancelled':
        return domain.TaskStatus.cancelled;
      default:
        return domain.TaskStatus.pending;
    }
  }

  domain.TaskPriority _parseDomainTaskPriority(dynamic priority) {
    if (priority is int) {
      return domain.TaskPriority.values[priority.clamp(
        0,
        domain.TaskPriority.values.length - 1,
      )];
    }
    switch (priority) {
      case 'low':
        return domain.TaskPriority.low;
      case 'high':
        return domain.TaskPriority.high;
      case 'urgent':
        return domain.TaskPriority.urgent;
      default:
        return domain.TaskPriority.medium;
    }
  }

  Map<String, dynamic> _buildTaskMetadata(domain.Task task) {
    final metadata = Map<String, dynamic>.from(task.metadata);
    if (task.description != null && task.description!.isNotEmpty) {
      metadata['description'] = task.description;
    }
    metadata['deleted'] = task.deletedAt != null;
    if (task.deletedAt != null) {
      metadata['deletedAt'] = task.deletedAt!.toIso8601String();
    }
    if (task.scheduledPurgeAt != null) {
      metadata['scheduledPurgeAt'] = task.scheduledPurgeAt!.toIso8601String();
    }
    metadata.removeWhere((_, value) => value == null);
    return metadata;
  }

  List<String> _buildTaskLabels(List<String> tags) {
    return tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }

  String? _extractDescription(
    Map<String, dynamic> metadata,
    dynamic legacyField,
  ) {
    final fromMetadata = metadata['description'] ?? metadata['notes'];
    if (fromMetadata is String && fromMetadata.isNotEmpty) {
      return fromMetadata;
    }
    if (legacyField is String && legacyField.isNotEmpty) {
      return legacyField;
    }
    return null;
  }

  List<String>? _extractTags(dynamic labels) {
    if (labels is List) {
      return _normalizeStringList(labels);
    } else if (labels is Map<String, dynamic>) {
      final values = labels['tags'];
      final parsed = _normalizeStringList(values);
      if (parsed != null && parsed.isNotEmpty) {
        return parsed;
      }
    } else if (labels is String && labels.isNotEmpty) {
      try {
        final decoded = jsonDecode(labels);
        final parsed = _normalizeStringList(decoded);
        if (parsed != null && parsed.isNotEmpty) {
          return parsed;
        }
      } catch (_) {
        // Ignore JSON parsing errors and fall back below
      }
      return labels
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
    }
    return _normalizeStringList(labels);
  }

  Map<String, dynamic> _parseMetadata(dynamic metadata) {
    if (metadata is Map<String, dynamic>) {
      return Map<String, dynamic>.from(metadata);
    }
    if (metadata is Map) {
      return metadata.map((key, value) => MapEntry(key.toString(), value));
    }
    if (metadata is String && metadata.isNotEmpty) {
      try {
        final decoded = jsonDecode(metadata);
        if (decoded is Map<String, dynamic>) {
          return Map<String, dynamic>.from(decoded);
        }
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        // Ignore invalid JSON payloads
      }
    }
    return <String, dynamic>{};
  }

  List<String>? _normalizeStringList(dynamic value) {
    if (value is List) {
      final result = value
          .map((entry) => entry?.toString() ?? '')
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList();
      return result.isEmpty ? null : result;
    }
    if (value is String && value.isNotEmpty) {
      return value
          .split(',')
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList();
    }
    return null;
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String && value.isNotEmpty) {
      return int.tryParse(value);
    }
    return null;
  }

  bool? _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is int) {
      if (value == 1) return true;
      if (value == 0) return false;
    }
    if (value is String && value.isNotEmpty) {
      final normalized = value.toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return null;
  }
}
