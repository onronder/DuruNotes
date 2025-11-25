import 'dart:convert';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain_task;
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart';
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/attachment_service.dart';
import 'package:duru_notes/services/providers/services_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for coordinating trash operations across repositories
/// Phase 1.1: Soft Delete & Trash System
class TrashService {
  TrashService(
    this._ref, {
    INotesRepository? notesRepository,
    IFolderRepository? folderRepository,
    ITaskRepository? taskRepository,
    bool notesRepositoryProvided = false,
    bool folderRepositoryProvided = false,
    bool taskRepositoryProvided = false,
  })  : _notesRepository = notesRepository,
        _folderRepository = folderRepository,
        _taskRepository = taskRepository,
        _notesRepositoryProvided = notesRepositoryProvided || notesRepository != null,
        _folderRepositoryProvided = folderRepositoryProvided || folderRepository != null,
        _taskRepositoryProvided = taskRepositoryProvided || taskRepository != null;

  final Ref _ref;
  final INotesRepository? _notesRepository;
  final IFolderRepository? _folderRepository;
  final ITaskRepository? _taskRepository;
  final bool _notesRepositoryProvided;
  final bool _folderRepositoryProvided;
  final bool _taskRepositoryProvided;

  AppLogger get _logger => _ref.read(loggerProvider);
  AttachmentService get _attachmentService => _ref.read(attachmentServiceProvider);
  AnalyticsService get _analytics => _ref.read(analyticsProvider);

  /// Lazily get notes repository from provider
  INotesRepository get _notesRepo {
    if (_notesRepositoryProvided) {
      final repo = _notesRepository;
      if (repo == null) {
        throw StateError(
          'TrashService: notesRepositoryProvided is true but notesRepository is null. '
          'Either pass a non-null repository or set the flag to false.',
        );
      }
      return repo;
    }
    return _ref.read(notesCoreRepositoryProvider);
  }

  /// Lazily get folder repository from provider
  IFolderRepository get _folderRepo {
    if (_folderRepositoryProvided) {
      final repo = _folderRepository;
      if (repo == null) {
        throw StateError(
          'TrashService: folderRepositoryProvided is true but folderRepository is null. '
          'Either pass a non-null repository or set the flag to false.',
        );
      }
      return repo;
    }
    return _ref.read(folderCoreRepositoryProvider);
  }

  /// Lazily get task repository from provider (nullable)
  /// Returns null if explicitly injected as null OR if provider unavailable
  ITaskRepository? get _taskRepo {
    // If explicitly provided (even if null), use that value
    if (_taskRepositoryProvided) {
      return _taskRepository;
    }
    // Otherwise try to get from provider
    try {
      return _ref.read(taskCoreRepositoryProvider);
    } catch (e) {
      _logger.warning('Task repository not available: $e');
      return null;
    }
  }

  /// Standard retention period for soft-deleted items (30 days)
  static const Duration retentionPeriod = Duration(days: 30);

  /// Calculate scheduled purge timestamp based on deletion time
  DateTime calculateScheduledPurgeAt(DateTime deletedAt) {
    return deletedAt.add(retentionPeriod);
  }

  /// Calculate days remaining until auto-purge
  int daysUntilPurge(DateTime scheduledPurgeAt) {
    final now = DateTime.now();
    final difference = scheduledPurgeAt.difference(now);
    return difference.inDays;
  }

  /// Check if an item is overdue for purging
  bool isOverdueForPurge(DateTime scheduledPurgeAt) {
    return scheduledPurgeAt.isBefore(DateTime.now());
  }

  /// Get all deleted items across all repositories
  Future<TrashContents> getAllDeletedItems() async {
    try {
      final results = await Future.wait([
        _getDeletedNotes(),
        _getDeletedFolders(),
        _getDeletedTasks(),
      ]);

      final notes = results[0] as List<Note>;
      final folders = results[1] as List<domain.Folder>;
      final tasks = results[2] as List<domain_task.Task>;

      return TrashContents(
        notes: notes,
        folders: folders,
        tasks: tasks,
        retrievedAt: DateTime.now(),
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to retrieve deleted items',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<List<Note>> _getDeletedNotes() async {
    try {
      // Use dedicated getDeletedNotes() method from interface
      return await _notesRepo.getDeletedNotes();
    } catch (e, stack) {
      _logger.error('Failed to fetch deleted notes', error: e, stackTrace: stack);
      return [];
    }
  }

  Future<List<domain.Folder>> _getDeletedFolders() async {
    try {
      return await _folderRepo.getDeletedFolders();
    } catch (e, stack) {
      _logger.error('Failed to fetch deleted folders', error: e, stackTrace: stack);
      return [];
    }
  }

  Future<List<domain_task.Task>> _getDeletedTasks() async {
    final repo = _taskRepo;
    if (repo == null) return [];
    try {
      return await repo.getDeletedTasks();
    } catch (e, stack) {
      _logger.error('Failed to fetch deleted tasks', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Permanently delete a single note with analytics tracking
  ///
  /// Includes best-effort deletion of voice recording audio files from Supabase Storage.
  /// Audio deletion failures are logged but do not block note deletion.
  Future<void> permanentlyDeleteNote(String noteId) async {
    try {
      _logger.info('Permanently deleting note: $noteId');

      // Get note first to check for voice recordings
      final note = await _notesRepo.getNoteById(noteId);
      if (note != null && note.attachmentMeta != null && note.attachmentMeta!.isNotEmpty) {
        await _deleteVoiceRecordingsForNote(note);
      }

      // Delete the note from database
      await _notesRepo.permanentlyDeleteNote(noteId);

      // Track analytics
      _trackDeletion('note', 1);

      _logger.info('Successfully permanently deleted note: $noteId');
    } catch (e, stack) {
      _logger.error(
        'Failed to permanently delete note: $noteId',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Best-effort deletion of voice recording files from Supabase Storage
  ///
  /// Parses note.attachmentMeta.voiceRecordings and deletes each audio file.
  /// Logs errors but does not throw - deletion failures should not block note purge.
  Future<void> _deleteVoiceRecordingsForNote(Note note) async {
    int successCount = 0;
    int failureCount = 0;

    try {
      final metaData = jsonDecode(note.attachmentMeta!) as Map<String, dynamic>;
      final voiceRecordings = metaData['voiceRecordings'] as List<dynamic>?;

      if (voiceRecordings == null || voiceRecordings.isEmpty) {
        return;
      }

      _logger.info(
        'Deleting ${voiceRecordings.length} voice recording(s) for note ${note.id}',
      );

      // Delete each voice recording (best-effort)
      for (final recording in voiceRecordings) {
        final url = recording['url'] as String?;
        if (url == null || url.isEmpty) {
          continue;
        }

        try {
          final deleted = await _attachmentService.delete(url);
          if (deleted) {
            successCount++;
            _logger.breadcrumb(
              'Deleted voice recording',
              data: {'url': url, 'note_id': note.id},
            );
          } else {
            failureCount++;
            _logger.warning(
              'Failed to delete voice recording (returned false)',
              data: {'url': url, 'note_id': note.id},
            );
          }
        } catch (e) {
          failureCount++;
          _logger.warning(
            'Error deleting voice recording',
            data: {'url': url, 'note_id': note.id, 'error': e.toString()},
          );
        }
      }

      _logger.info(
        'Voice recording cleanup complete for note ${note.id}: '
        '$successCount succeeded, $failureCount failed',
      );

      // Track analytics if any deletions failed
      if (failureCount > 0) {
        _analytics.trackError(
          'Voice recording deletion failed',
          properties: {
            'note_id': note.id,
            'failure_count': failureCount,
            'success_count': successCount,
            'total_recordings': successCount + failureCount,
          },
        );
      }
    } catch (e) {
      // Log parsing errors but don't throw - this shouldn't block note deletion
      _logger.warning(
        'Failed to parse voice recordings for cleanup',
        data: {'note_id': note.id, 'error': e.toString()},
      );
    }
  }

  /// Restore a single note from trash
  Future<void> restoreNote(String noteId) async {
    try {
      _logger.info('Restoring note: $noteId');
      await _notesRepo.restoreNote(noteId);
      _logger.info('Successfully restored note: $noteId');
    } catch (e, stack) {
      _logger.error(
        'Failed to restore note: $noteId',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Permanently delete a single folder with analytics tracking
  Future<void> permanentlyDeleteFolder(String folderId) async {
    try {
      _logger.info('Permanently deleting folder: $folderId');
      await _folderRepo.permanentlyDeleteFolder(folderId);

      // Track analytics
      _trackDeletion('folder', 1);

      _logger.info('Successfully permanently deleted folder: $folderId');
    } catch (e, stack) {
      _logger.error(
        'Failed to permanently delete folder: $folderId',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Restore a folder (optionally with its contents)
  Future<void> restoreFolder(String folderId, {bool restoreContents = false}) async {
    try {
      _logger.info('Restoring folder: $folderId (restoreContents=$restoreContents)');
      await _folderRepo.restoreFolder(folderId, restoreContents: restoreContents);
      _logger.info('Successfully restored folder: $folderId');
    } catch (e, stack) {
      _logger.error(
        'Failed to restore folder: $folderId',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Permanently delete a single task with analytics tracking
  Future<void> permanentlyDeleteTask(String taskId) async {
    final repo = _taskRepo;
    if (repo == null) {
      throw StateError('Task repository not available');
    }

    try {
      _logger.info('Permanently deleting task: $taskId');
      await repo.permanentlyDeleteTask(taskId);

      // Track analytics
      _trackDeletion('task', 1);

      _logger.info('Successfully permanently deleted task: $taskId');
    } catch (e, stack) {
      _logger.error(
        'Failed to permanently delete task: $taskId',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Restore a task from trash
  Future<void> restoreTask(String taskId) async {
    final repo = _taskRepo;
    if (repo == null) {
      throw StateError('Task repository not available');
    }

    try {
      _logger.info('Restoring task: $taskId');
      await repo.restoreTask(taskId);
      _logger.info('Successfully restored task: $taskId');
    } catch (e, stack) {
      _logger.error(
        'Failed to restore task: $taskId',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Empty entire trash with bulk deletion orchestration
  Future<BulkDeleteResult> emptyTrash() async {
    _logger.info('Starting empty trash operation');

    int successCount = 0;
    int failureCount = 0;
    final errors = <String, dynamic>{};

    try {
      final contents = await getAllDeletedItems();
      final totalItems = contents.totalCount;

      _logger.info('Found $totalItems items to permanently delete');

      // Delete notes
      for (final note in contents.notes) {
        try {
          await permanentlyDeleteNote(note.id);
          successCount++;
        } catch (e) {
          failureCount++;
          errors['note_${note.id}'] = e.toString();
        }
      }

      // Delete folders
      for (final folder in contents.folders) {
        try {
          await permanentlyDeleteFolder(folder.id);
          successCount++;
        } catch (e) {
          failureCount++;
          errors['folder_${folder.id}'] = e.toString();
        }
      }

      // Delete tasks
      for (final task in contents.tasks) {
        try {
          await permanentlyDeleteTask(task.id);
          successCount++;
        } catch (e) {
          failureCount++;
          errors['task_${task.id}'] = e.toString();
        }
      }

      _logger.info(
        'Empty trash completed: $successCount succeeded, $failureCount failed',
      );

      return BulkDeleteResult(
        successCount: successCount,
        failureCount: failureCount,
        errors: errors,
        completedAt: DateTime.now(),
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to empty trash',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Get trash statistics for analytics
  Future<TrashStatistics> getTrashStatistics() async {
    try {
      final contents = await getAllDeletedItems();

      int overdueCount = 0;
      int within7Days = 0;
      int within14Days = 0;
      int within30Days = 0;

      final now = DateTime.now();

      // Analyze notes
      for (final note in contents.notes) {
        if (note.scheduledPurgeAt != null) {
          final daysUntil = daysUntilPurge(note.scheduledPurgeAt!);
          if (isOverdueForPurge(note.scheduledPurgeAt!)) {
            overdueCount++;
          } else if (daysUntil <= 7) {
            within7Days++;
          } else if (daysUntil <= 14) {
            within14Days++;
          } else if (daysUntil <= 30) {
            within30Days++;
          }
        }
      }

      // Analyze folders
      for (final folder in contents.folders) {
        if (folder.scheduledPurgeAt != null) {
          final daysUntil = daysUntilPurge(folder.scheduledPurgeAt!);
          if (isOverdueForPurge(folder.scheduledPurgeAt!)) {
            overdueCount++;
          } else if (daysUntil <= 7) {
            within7Days++;
          } else if (daysUntil <= 14) {
            within14Days++;
          } else if (daysUntil <= 30) {
            within30Days++;
          }
        }
      }

      // Analyze tasks
      for (final task in contents.tasks) {
        if (task.scheduledPurgeAt != null) {
          final daysUntil = daysUntilPurge(task.scheduledPurgeAt!);
          if (isOverdueForPurge(task.scheduledPurgeAt!)) {
            overdueCount++;
          } else if (daysUntil <= 7) {
            within7Days++;
          } else if (daysUntil <= 14) {
            within14Days++;
          } else if (daysUntil <= 30) {
            within30Days++;
          }
        }
      }

      return TrashStatistics(
        totalItems: contents.totalCount,
        notesCount: contents.notes.length,
        foldersCount: contents.folders.length,
        tasksCount: contents.tasks.length,
        overdueForPurgeCount: overdueCount,
        purgeWithin7Days: within7Days,
        purgeWithin14Days: within14Days,
        purgeWithin30Days: within30Days,
        generatedAt: now,
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to generate trash statistics',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Track deletion analytics (placeholder for future analytics integration)
  void _trackDeletion(String itemType, int count) {
    _logger.breadcrumb(
      'Permanent deletion tracked',
      data: {
        'item_type': itemType,
        'count': count,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
}

/// Container for all trash contents
class TrashContents {
  const TrashContents({
    required this.notes,
    required this.folders,
    required this.tasks,
    required this.retrievedAt,
  });

  final List<Note> notes;
  final List<domain.Folder> folders;
  final List<domain_task.Task> tasks;
  final DateTime retrievedAt;

  int get totalCount => notes.length + folders.length + tasks.length;
}

/// Result of bulk delete operations
class BulkDeleteResult {
  const BulkDeleteResult({
    required this.successCount,
    required this.failureCount,
    required this.errors,
    required this.completedAt,
  });

  final int successCount;
  final int failureCount;
  final Map<String, dynamic> errors;
  final DateTime completedAt;

  bool get hasFailures => failureCount > 0;
  bool get allSucceeded => failureCount == 0;
}

/// Trash statistics for analytics
class TrashStatistics {
  const TrashStatistics({
    required this.totalItems,
    required this.notesCount,
    required this.foldersCount,
    required this.tasksCount,
    required this.overdueForPurgeCount,
    required this.purgeWithin7Days,
    required this.purgeWithin14Days,
    required this.purgeWithin30Days,
    required this.generatedAt,
  });

  final int totalItems;
  final int notesCount;
  final int foldersCount;
  final int tasksCount;
  final int overdueForPurgeCount;
  final int purgeWithin7Days;
  final int purgeWithin14Days;
  final int purgeWithin30Days;
  final DateTime generatedAt;
}
