import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Service for handling note-folder integration operations with analytics and recent folder tracking
class NoteFolderIntegrationService {
  NoteFolderIntegrationService({
    required IFolderRepository folderRepository,
    required this.analyticsService,
  }) : _folderRepository = folderRepository,
       _logger = LoggerFactory.instance;

  final IFolderRepository _folderRepository;
  final AnalyticsService analyticsService;
  final AppLogger _logger;

  static const String _recentFoldersKey = 'recent_folders';
  static const String _folderFilterKey = 'folder_filter_preference';
  static const String _includeSubfoldersKey = 'include_subfolders';
  static const int _maxRecentFolders = 5;

  /// Get recent folders list
  Future<List<String>> getRecentFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentFolders = prefs.getStringList(_recentFoldersKey) ?? [];

      _logger.debug(
        'Retrieved recent folders',
        data: {'count': recentFolders.length, 'folders': recentFolders},
      );

      return recentFolders;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get recent folders',
        error: e,
        stackTrace: stackTrace,
        data: {'operation': 'getRecentFolders'},
      );

      await Sentry.captureException(e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Add folder to recent folders list
  Future<void> addToRecentFolders(String folderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentFolders = List<String>.from(
        prefs.getStringList(_recentFoldersKey) ?? [],
      );

      // Remove if already exists to avoid duplicates
      recentFolders.remove(folderId);

      // Add to beginning
      recentFolders.insert(0, folderId);

      // Keep only the most recent ones
      if (recentFolders.length > _maxRecentFolders) {
        recentFolders.removeRange(_maxRecentFolders, recentFolders.length);
      }

      await prefs.setStringList(_recentFoldersKey, recentFolders);

      _logger.info(
        'Added folder to recent folders',
        data: {'folderId': folderId, 'recentCount': recentFolders.length},
      );

      // Track analytics
      analyticsService.event(
        'folder_recent_added',
        properties: {
          'folder_id': folderId,
          'recent_count': recentFolders.length,
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to add folder to recent folders',
        error: e,
        stackTrace: stackTrace,
        data: {'folderId': folderId},
      );

      await Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  /// Move multiple notes to a folder with progress tracking
  Future<BatchMoveResult> moveNotesToFolder({
    required List<String> noteIds,
    required String? folderId,
    void Function(double progress)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      _logger.info(
        'Starting batch move operation',
        data: {'noteCount': noteIds.length, 'targetFolderId': folderId},
      );

      var successCount = 0;
      var errorCount = 0;
      final errors = <String>[];

      for (int i = 0; i < noteIds.length; i++) {
        final noteId = noteIds[i];

        try {
          if (folderId != null) {
            await _folderRepository.addNoteToFolder(noteId, folderId);
          } else {
            await _folderRepository.removeNoteFromFolder(noteId);
          }

          successCount++;

          _logger.debug(
            'Moved note successfully',
            data: {'noteId': noteId, 'folderId': folderId},
          );
        } catch (e) {
          errorCount++;
          final errorMsg = 'Failed to move note $noteId: $e';
          errors.add(errorMsg);

          _logger.warning(
            errorMsg,
            data: {'noteId': noteId, 'folderId': folderId},
          );
        }

        // Update progress
        onProgress?.call((i + 1) / noteIds.length);
      }

      // Add to recent folders if successful
      if (folderId != null && successCount > 0) {
        await addToRecentFolders(folderId);
      }

      final result = BatchMoveResult(
        successCount: successCount,
        errorCount: errorCount,
        errors: errors,
        duration: stopwatch.elapsed,
      );

      _logger.info(
        'Completed batch move operation',
        data: {
          'successCount': successCount,
          'errorCount': errorCount,
          'duration': stopwatch.elapsedMilliseconds,
        },
      );

      // Track analytics
      analyticsService.event(
        'notes_batch_moved',
        properties: {
          'note_count': noteIds.length,
          'success_count': successCount,
          'error_count': errorCount,
          'target_folder_id': folderId,
          'duration_ms': stopwatch.elapsedMilliseconds,
        },
      );

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();

      _logger.error(
        'Batch move operation failed',
        error: e,
        stackTrace: stackTrace,
        data: {
          'noteIds': noteIds,
          'folderId': folderId,
          'duration': stopwatch.elapsedMilliseconds,
        },
      );

      await Sentry.captureException(e, stackTrace: stackTrace);

      return BatchMoveResult(
        successCount: 0,
        errorCount: noteIds.length,
        errors: ['Operation failed: $e'],
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Get folder filter preference
  Future<String?> getFolderFilterPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_folderFilterKey);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get folder filter preference',
        error: e,
        stackTrace: stackTrace,
      );

      await Sentry.captureException(e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Set folder filter preference
  Future<void> setFolderFilterPreference(String? folderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (folderId != null) {
        await prefs.setString(_folderFilterKey, folderId);
      } else {
        await prefs.remove(_folderFilterKey);
      }

      _logger.info(
        'Set folder filter preference',
        data: {'folderId': folderId},
      );

      // Track analytics
      analyticsService.event(
        'folder_filter_changed',
        properties: {
          'folder_id': folderId,
          'action': folderId != null ? 'set' : 'cleared',
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to set folder filter preference',
        error: e,
        stackTrace: stackTrace,
        data: {'folderId': folderId},
      );

      await Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  /// Get include subfolders preference
  Future<bool> getIncludeSubfoldersPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_includeSubfoldersKey) ?? true;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get include subfolders preference',
        error: e,
        stackTrace: stackTrace,
      );

      await Sentry.captureException(e, stackTrace: stackTrace);
      return true;
    }
  }

  /// Set include subfolders preference
  Future<void> setIncludeSubfoldersPreference(bool include) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_includeSubfoldersKey, include);

      _logger.info(
        'Set include subfolders preference',
        data: {'include': include},
      );

      // Track analytics
      analyticsService.event(
        'include_subfolders_changed',
        properties: {'include': include},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to set include subfolders preference',
        error: e,
        stackTrace: stackTrace,
        data: {'include': include},
      );

      await Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  /// Get folders hierarchy for display in picker
  Future<List<LocalFolder>> getFoldersHierarchy() async {
    try {
      final domainFolders = await _folderRepository.listFolders();

      _logger.debug(
        'Retrieved folders hierarchy',
        data: {'folderCount': domainFolders.length},
      );

      // Convert domain.Folder to LocalFolder for compatibility
      return domainFolders
          .map(
            (df) => LocalFolder(
              id: df.id,
              userId: df.userId,
              name: df.name,
              parentId: df.parentId,
              path: '', // path is computed by database triggers
              color: df.color ?? '#048ABF',
              icon: df.icon ?? 'folder',
              description: df.description ?? '',
              sortOrder: df.sortOrder,
              createdAt: df.createdAt,
              updatedAt: df.updatedAt,
              deleted: false,
            ),
          )
          .toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get folders hierarchy',
        error: e,
        stackTrace: stackTrace,
      );

      await Sentry.captureException(e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Clear all recent folders
  Future<void> clearRecentFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentFoldersKey);

      _logger.info('Cleared recent folders');

      // Track analytics
      analyticsService.event('recent_folders_cleared');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to clear recent folders',
        error: e,
        stackTrace: stackTrace,
      );

      await Sentry.captureException(e, stackTrace: stackTrace);
    }
  }
}

/// Result of a batch move operation
class BatchMoveResult {
  const BatchMoveResult({
    required this.successCount,
    required this.errorCount,
    required this.errors,
    required this.duration,
  });

  final int successCount;
  final int errorCount;
  final List<String> errors;
  final Duration duration;

  bool get hasErrors => errorCount > 0;
  bool get isPartialSuccess => successCount > 0 && errorCount > 0;
  bool get isCompleteSuccess => successCount > 0 && errorCount == 0;
  bool get isCompleteFailure => successCount == 0 && errorCount > 0;

  String getStatusMessage() {
    if (isCompleteSuccess) {
      return '$successCount note${successCount == 1 ? '' : 's'} moved successfully';
    } else if (isCompleteFailure) {
      return 'Failed to move notes';
    } else if (isPartialSuccess) {
      return '$successCount moved, $errorCount failed';
    } else {
      return 'No notes processed';
    }
  }
}
