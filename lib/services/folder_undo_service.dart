import 'dart:async';
import 'dart:collection';

import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/repository/folder_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final LocalFolder originalFolder;
  final String? originalParentId;
  final List<String> affectedNotes;
  final List<LocalFolder> affectedChildFolders;
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
  FolderUndoService(this._folderRepository);

  final FolderRepository _folderRepository;
  final Queue<FolderUndoOperation> _undoHistory = Queue<FolderUndoOperation>();
  final StreamController<List<FolderUndoOperation>> _historyController =
      StreamController<List<FolderUndoOperation>>.broadcast();

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
    required LocalFolder folder,
    required List<String> affectedNotes,
    required List<LocalFolder> affectedChildFolders,
  }) async {
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

    debugPrint('📝 Added delete operation for folder: ${folder.name}');
    return operationId;
  }

  /// Add a folder move operation to undo history
  Future<String> addMoveOperation({
    required LocalFolder folder,
    required String? originalParentId,
  }) async {
    final operationId = DateTime.now().millisecondsSinceEpoch.toString();

    final operation = FolderUndoOperation(
      id: operationId,
      type: FolderUndoType.move,
      timestamp: DateTime.now(),
      originalFolder: folder,
      originalParentId: originalParentId,
    );

    _addOperation(operation);

    debugPrint('📝 Added move operation for folder: ${folder.name}');
    return operationId;
  }

  /// Add a folder rename operation to undo history
  Future<String> addRenameOperation({
    required LocalFolder folder,
    required String originalName,
  }) async {
    final operationId = DateTime.now().millisecondsSinceEpoch.toString();

    final operation = FolderUndoOperation(
      id: operationId,
      type: FolderUndoType.rename,
      timestamp: DateTime.now(),
      originalFolder: folder,
      originalName: originalName,
    );

    _addOperation(operation);

    debugPrint('📝 Added rename operation for folder: ${folder.name}');
    return operationId;
  }

  /// Undo a specific operation by ID
  Future<bool> undoOperation(String operationId) async {
    final operation = _undoHistory
        .where((op) => op.id == operationId && !op.isExpired)
        .firstOrNull;

    if (operation == null) {
      debugPrint('❌ Cannot undo: Operation not found or expired');
      return false;
    }

    try {
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

      debugPrint('✅ Successfully undid operation: ${operation.description}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to undo operation: $e');
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
    _undoHistory.clear();
    _notifyHistoryChanged();
    debugPrint('🧹 Cleared folder undo history');
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
    _notifyHistoryChanged();
  }

  void _notifyHistoryChanged() {
    _historyController.add(currentHistory);
  }

  Future<void> _undoDeleteOperation(FolderUndoOperation operation) async {
    // Restore the original folder
    final restoredFolder = await _folderRepository.createLocalFolder(
      id: operation.originalFolder.id,
      name: operation.originalFolder.name,
      parentId: operation.originalParentId,
      color: operation.originalFolder.color,
      icon: operation.originalFolder.icon,
      description: operation.originalFolder.description,
    );

    if (restoredFolder == null) {
      throw Exception('Failed to restore folder');
    }

    // Restore child folders
    for (final childFolder in operation.affectedChildFolders) {
      await _folderRepository.createLocalFolder(
        id: childFolder.id,
        name: childFolder.name,
        parentId: childFolder.parentId,
        color: childFolder.color,
        icon: childFolder.icon,
        description: childFolder.description,
      );
    }

    // Move affected notes back to the restored folder
    for (final noteId in operation.affectedNotes) {
      await _folderRepository.moveNoteToFolder(
        noteId: noteId,
        folderId: operation.originalFolder.id,
      );
    }
  }

  Future<void> _undoMoveOperation(FolderUndoOperation operation) async {
    // Move the folder back to its original parent
    await _folderRepository.moveFolder(
      folderId: operation.originalFolder.id,
      newParentId: operation.originalParentId,
    );
  }

  Future<void> _undoRenameOperation(FolderUndoOperation operation) async {
    // Restore the original name
    if (operation.originalName != null) {
      await _folderRepository.renameFolder(
        folderId: operation.originalFolder.id,
        newName: operation.originalName!,
      );
    }
  }
}

/// Provider for the folder undo service
final folderUndoServiceProvider = Provider<FolderUndoService>((ref) {
  final folderRepository = ref.watch(folderRepositoryProvider);
  return FolderUndoService(folderRepository);
});

/// Provider for watching undo history
final folderUndoHistoryProvider = StreamProvider<List<FolderUndoOperation>>((ref) {
  final undoService = ref.watch(folderUndoServiceProvider);
  return undoService.historyStream;
});