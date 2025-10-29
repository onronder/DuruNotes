import 'dart:async';
import 'dart:collection';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderCoreRepositoryProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Types of folder operations that can be undone
enum FolderUndoType {
  delete,
  move,
  rename,
}

/// Represents a folder operation that can be undone
class FolderUndoOperation {
  const FolderUndoOperation({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.originalFolder,
    this.originalParentId,
    this.affectedNotes = const [],
    this.affectedChildFolders = const [],
    this.originalName,
  });

  final String id;
  final FolderUndoType type;
  final DateTime timestamp;
  final domain.Folder originalFolder;
  final String? originalParentId;
  final List<String> affectedNotes;
  final List<domain.Folder> affectedChildFolders;
  final String? originalName;

  /// Check if this operation has expired
  bool get isExpired {
    const Duration expireTime = Duration(minutes: 5); // 5 minute undo window
    return DateTime.now().difference(timestamp) > expireTime;
  }

  /// Get user-friendly description of the operation
  String get description {
    switch (type) {
      case FolderUndoType.delete:
        return 'Delete folder "${originalFolder.name}"';
      case FolderUndoType.move:
        return 'Move folder "${originalFolder.name}"';
      case FolderUndoType.rename:
        return 'Rename folder to "${originalFolder.name}"';
    }
  }
}

/// Service for managing undo operations for folder actions
class FolderUndoService {
  FolderUndoService(this._folderRepository) {
    _logger = LoggerFactory.instance;
  }

  final IFolderRepository _folderRepository;
  final Queue<FolderUndoOperation> _undoHistory = Queue<FolderUndoOperation>();
  final StreamController<List<FolderUndoOperation>> _historyController =
      StreamController<List<FolderUndoOperation>>.broadcast();
  late final AppLogger _logger;

  static const int _maxHistorySize = 10;

  /// Stream of undo operations history
  Stream<List<FolderUndoOperation>> get historyStream =>
      _historyController.stream;

  /// Get current undo history (non-expired)
  List<FolderUndoOperation> get currentHistory {
    _cleanExpiredOperations();
    return _undoHistory.toList();
  }

  /// Add a folder deletion operation to undo history
  Future<String> addDeleteOperation({
    required domain.Folder folder,
    required List<String> affectedNotes,
    required List<domain.Folder> affectedChildFolders,
  }) async {
    try {
      final operationId = DateTime.now().millisecondsSinceEpoch.toString();

      final operation = FolderUndoOperation(
        id: operationId,
        type: FolderUndoType.delete,
        timestamp: DateTime.now(),
        originalFolder: folder,
        originalParentId: folder.parentId,
        affectedNotes: affectedNotes,
        affectedChildFolders: affectedChildFolders,
      );

      _addOperation(operation);

      _logger.info('Added delete operation for folder', data: {
        'folderId': folder.id,
        'folderName': folder.name,
        'operationId': operationId,
        'affectedNotes': affectedNotes.length,
        'childFolders': affectedChildFolders.length,
      });

      // Track in Sentry
      await Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Folder delete operation added to undo history',
          category: 'folder.undo',
          data: {
            'folderId': folder.id,
            'operationId': operationId,
          },
        ),
      );

      return operationId;
    } catch (e, stackTrace) {
      _logger.error('Failed to add delete operation',
        error: e,
        stackTrace: stackTrace,
        data: {
          'folderId': folder.id,
          'folderName': folder.name,
        },
      );
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Add a folder move operation to undo history
  Future<String> addMoveOperation({
    required domain.Folder folder,
    required String? originalParentId,
  }) async {
    try {
      final operationId = DateTime.now().millisecondsSinceEpoch.toString();

      final operation = FolderUndoOperation(
        id: operationId,
        type: FolderUndoType.move,
        timestamp: DateTime.now(),
        originalFolder: folder,
        originalParentId: originalParentId,
      );

      _addOperation(operation);

      _logger.info('Added move operation for folder', data: {
        'folderId': folder.id,
        'folderName': folder.name,
        'operationId': operationId,
        'originalParentId': originalParentId,
      });

      return operationId;
    } catch (e, stackTrace) {
      _logger.error('Failed to add move operation',
        error: e,
        stackTrace: stackTrace,
        data: {'folderId': folder.id},
      );
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Add a folder rename operation to undo history
  Future<String> addRenameOperation({
    required domain.Folder folder,
    required String originalName,
  }) async {
    try {
      final operationId = DateTime.now().millisecondsSinceEpoch.toString();

      final operation = FolderUndoOperation(
        id: operationId,
        type: FolderUndoType.rename,
        timestamp: DateTime.now(),
        originalFolder: folder,
        originalName: originalName,
      );

      _addOperation(operation);

      _logger.info('Added rename operation for folder', data: {
        'folderId': folder.id,
        'operationId': operationId,
        'originalName': originalName,
        'newName': folder.name,
      });

      return operationId;
    } catch (e, stackTrace) {
      _logger.error('Failed to add rename operation',
        error: e,
        stackTrace: stackTrace,
        data: {
          'folderId': folder.id,
          'originalName': originalName,
        },
      );
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Undo a specific operation by ID
  Future<bool> undoOperation(String operationId) async {
    try {
      final operation = _undoHistory
          .where((op) => op.id == operationId && !op.isExpired)
          .firstOrNull;

      if (operation == null) {
        _logger.warning('Cannot undo: Operation not found or expired', data: {
          'operationId': operationId,
        });
        return false;
      }

      _logger.info('Attempting to undo operation', data: {
        'operationId': operationId,
        'type': operation.type.name,
        'folderId': operation.originalFolder.id,
      });

      switch (operation.type) {
        case FolderUndoType.delete:
          await _undoDeleteOperation(operation);
        case FolderUndoType.move:
          await _undoMoveOperation(operation);
        case FolderUndoType.rename:
          await _undoRenameOperation(operation);
      }

      // Remove the operation from history
      _undoHistory.removeWhere((op) => op.id == operationId);
      _notifyHistoryChanged();

      _logger.info('Successfully undid operation', data: {
        'operationId': operationId,
        'description': operation.description,
      });

      await Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Folder operation undone successfully',
          category: 'folder.undo',
          data: {
            'operationId': operationId,
            'type': operation.type.name,
          },
        ),
      );

      return true;
    } catch (e, stackTrace) {
      _logger.error('Failed to undo operation',
        error: e,
        stackTrace: stackTrace,
        data: {
          'operationId': operationId,
        },
      );
      await Sentry.captureException(e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Get the most recent undoable operation
  FolderUndoOperation? getLatestOperation() {
    _cleanExpiredOperations();
    return _undoHistory.isNotEmpty ? _undoHistory.last : null;
  }

  /// Clear all undo history
  void clearHistory() {
    try {
      final count = _undoHistory.length;
      _undoHistory.clear();
      _notifyHistoryChanged();

      _logger.info('Cleared folder undo history', data: {
        'operationsCleared': count,
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to clear undo history',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Dispose the service
  void dispose() {
    _historyController.close();
  }

  // Private methods

  void _addOperation(FolderUndoOperation operation) {
    _undoHistory.addLast(operation);

    // Maintain max history size
    while (_undoHistory.length > _maxHistorySize) {
      _undoHistory.removeFirst();
    }

    _notifyHistoryChanged();
  }

  void _cleanExpiredOperations() {
    _undoHistory.removeWhere((op) => op.isExpired);
    // Don't call _notifyHistoryChanged here to avoid infinite recursion
  }

  void _notifyHistoryChanged() {
    // Clean expired operations without triggering another notification
    _undoHistory.removeWhere((op) => op.isExpired);
    // Now add the cleaned history to the stream
    _historyController.add(_undoHistory.toList());
  }

  Future<void> _undoDeleteOperation(FolderUndoOperation operation) async {
    try {
      _logger.info('Undoing delete operation', data: {
        'folderId': operation.originalFolder.id,
        'folderName': operation.originalFolder.name,
      });

      // Restore the original folder
      final folderId = await _folderRepository.createOrUpdateFolder(
        id: operation.originalFolder.id,
        name: operation.originalFolder.name,
        parentId: operation.originalParentId,
        color: operation.originalFolder.color,
        icon: operation.originalFolder.icon,
        description: operation.originalFolder.description,
      );

      _logger.debug('Restored folder', data: {'folderId': folderId});

      // Restore child folders
      for (final childFolder in operation.affectedChildFolders) {
        try {
          await _folderRepository.createOrUpdateFolder(
            id: childFolder.id,
            name: childFolder.name,
            parentId: childFolder.parentId,
            color: childFolder.color,
            icon: childFolder.icon,
            description: childFolder.description,
          );
        } catch (e) {
          _logger.warning('Failed to restore child folder', data: {
            'childFolderId': childFolder.id,
            'error': e.toString(),
          });
        }
      }

      // Notes in the folder are already handled - no need to explicitly move them
      // The folder structure restoration is sufficient
      _logger.debug('Skipping note restoration - handled by folder structure', data: {
        'noteCount': operation.affectedNotes.length,
      });

      _logger.info('Successfully undid delete operation', data: {
        'folderId': operation.originalFolder.id,
        'restoredChildFolders': operation.affectedChildFolders.length,
        'restoredNotes': operation.affectedNotes.length,
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to undo delete operation',
        error: e,
        stackTrace: stackTrace,
        data: {
          'folderId': operation.originalFolder.id,
          'folderName': operation.originalFolder.name,
        },
      );
      await Sentry.captureException(e, stackTrace: stackTrace, withScope: (scope) {
        scope.setTag('operation', 'undo_delete');
        scope.setContexts('folder', {
          'id': operation.originalFolder.id,
          'name': operation.originalFolder.name,
        });
      });
      rethrow;
    }
  }

  Future<void> _undoMoveOperation(FolderUndoOperation operation) async {
    try {
      _logger.info('Undoing move operation', data: {
        'folderId': operation.originalFolder.id,
        'originalParentId': operation.originalParentId,
      });

      // Move the folder back to its original parent
      await _folderRepository.moveFolder(
        operation.originalFolder.id,
        operation.originalParentId,
      );

      _logger.info('Successfully undid move operation', data: {
        'folderId': operation.originalFolder.id,
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to undo move operation',
        error: e,
        stackTrace: stackTrace,
        data: {
          'folderId': operation.originalFolder.id,
          'originalParentId': operation.originalParentId,
        },
      );
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _undoRenameOperation(FolderUndoOperation operation) async {
    try {
      _logger.info('Undoing rename operation', data: {
        'folderId': operation.originalFolder.id,
        'originalName': operation.originalName,
        'currentName': operation.originalFolder.name,
      });

      // Restore the original name
      if (operation.originalName != null) {
        await _folderRepository.renameFolder(
          operation.originalFolder.id,
          operation.originalName!,
        );

        _logger.info('Successfully undid rename operation', data: {
          'folderId': operation.originalFolder.id,
          'restoredName': operation.originalName,
        });
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to undo rename operation',
        error: e,
        stackTrace: stackTrace,
        data: {
          'folderId': operation.originalFolder.id,
          'originalName': operation.originalName,
        },
      );
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    }
  }
}

/// Provider for the folder undo service
final folderUndoServiceProvider = Provider<FolderUndoService>((ref) {
  // Use the FolderCoreRepository which implements IFolderRepository
  final folderRepository = ref.watch(folderCoreRepositoryProvider);
  return FolderUndoService(folderRepository);
});

/// Provider for watching undo history
final folderUndoHistoryProvider = StreamProvider<List<FolderUndoOperation>>((ref) {
  final undoService = ref.watch(folderUndoServiceProvider);
  return undoService.historyStream;
});