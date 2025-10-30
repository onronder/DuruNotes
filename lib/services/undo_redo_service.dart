import 'dart:async';
import 'dart:convert';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents an undoable operation
abstract class UndoableOperation {
  UndoableOperation({
    required this.id,
    required this.timestamp,
    required this.description,
    this.expiresAt,
  });

  final String id;
  final DateTime timestamp;
  final String description;
  final DateTime? expiresAt;

  /// Execute the undo operation
  Future<void> undo();

  /// Execute the redo operation
  Future<void> redo();

  /// Check if this operation has expired
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson();

  /// Create from JSON
  static UndoableOperation? fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'folder_move':
        return FolderMoveOperation.fromJson(json);
      case 'note_folder_change':
        return NoteFolderChangeOperation.fromJson(json);
      case 'batch_folder_change':
        return BatchFolderChangeOperation.fromJson(json);
      default:
        return null;
    }
  }
}

/// Operation for moving a note between folders
class NoteFolderChangeOperation extends UndoableOperation {
  NoteFolderChangeOperation({
    required super.id,
    required super.timestamp,
    required super.description,
    required this.noteId,
    required this.noteTitle,
    required this.previousFolderId,
    required this.previousFolderName,
    required this.newFolderId,
    required this.newFolderName,
    required this.repository,
    super.expiresAt,
  });

  final String noteId;
  final String noteTitle;
  final String? previousFolderId;
  final String? previousFolderName;
  final String? newFolderId;
  final String? newFolderName;
  final dynamic repository; // NotesRepository

  @override
  Future<void> undo() async {
    await repository.moveNoteToFolder(noteId, previousFolderId);
  }

  @override
  Future<void> redo() async {
    await repository.moveNoteToFolder(noteId, newFolderId);
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'note_folder_change',
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'description': description,
    'expiresAt': expiresAt?.toIso8601String(),
    'noteId': noteId,
    'noteTitle': noteTitle,
    'previousFolderId': previousFolderId,
    'previousFolderName': previousFolderName,
    'newFolderId': newFolderId,
    'newFolderName': newFolderName,
  };

  static NoteFolderChangeOperation? fromJson(Map<String, dynamic> json) {
    // Note: repository needs to be injected when restoring
    return null; // Will be handled by service
  }
}

/// Operation for batch moving notes between folders
class BatchFolderChangeOperation extends UndoableOperation {
  BatchFolderChangeOperation({
    required super.id,
    required super.timestamp,
    required super.description,
    required this.noteIds,
    required this.previousFolderIds,
    required this.newFolderId,
    required this.newFolderName,
    required this.repository,
    super.expiresAt,
  });

  final List<String> noteIds;
  final Map<String, String?> previousFolderIds; // noteId -> folderId
  final String? newFolderId;
  final String? newFolderName;
  final dynamic repository; // NotesRepository

  @override
  Future<void> undo() async {
    for (final noteId in noteIds) {
      await repository.moveNoteToFolder(noteId, previousFolderIds[noteId]);
    }
  }

  @override
  Future<void> redo() async {
    for (final noteId in noteIds) {
      await repository.moveNoteToFolder(noteId, newFolderId);
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'batch_folder_change',
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'description': description,
    'expiresAt': expiresAt?.toIso8601String(),
    'noteIds': noteIds,
    'previousFolderIds': previousFolderIds,
    'newFolderId': newFolderId,
    'newFolderName': newFolderName,
  };

  static BatchFolderChangeOperation? fromJson(Map<String, dynamic> json) {
    // Note: repository needs to be injected when restoring
    return null; // Will be handled by service
  }
}

/// Operation for moving folders
class FolderMoveOperation extends UndoableOperation {
  FolderMoveOperation({
    required super.id,
    required super.timestamp,
    required super.description,
    required this.folderId,
    required this.folderName,
    required this.previousParentId,
    required this.newParentId,
    required this.repository,
    super.expiresAt,
  });

  final String folderId;
  final String folderName;
  final String? previousParentId;
  final String? newParentId;
  final dynamic repository; // NotesRepository

  @override
  Future<void> undo() async {
    await repository.moveFolder(folderId, previousParentId);
  }

  @override
  Future<void> redo() async {
    await repository.moveFolder(folderId, newParentId);
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'folder_move',
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'description': description,
    'expiresAt': expiresAt?.toIso8601String(),
    'folderId': folderId,
    'folderName': folderName,
    'previousParentId': previousParentId,
    'newParentId': newParentId,
  };

  static FolderMoveOperation? fromJson(Map<String, dynamic> json) {
    // Note: repository needs to be injected when restoring
    return null; // Will be handled by service
  }
}

/// Service for managing undo/redo operations
class UndoRedoService extends ChangeNotifier {
  UndoRedoService({
    required this.repository,
    required this.userId,
    this.maxStackSize = 50,
    this.defaultExpiration = const Duration(seconds: 30),
  }) : _logger = LoggerFactory.instance {
    _init();
  }

  final dynamic repository; // NotesRepository
  final String userId;
  final int maxStackSize;
  final Duration defaultExpiration;
  final AppLogger _logger;

  final List<UndoableOperation> _undoStack = [];
  final List<UndoableOperation> _redoStack = [];
  Timer? _cleanupTimer;
  SharedPreferences? _prefs;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  UndoableOperation? get lastUndoOperation =>
      _undoStack.isNotEmpty ? _undoStack.last : null;
  UndoableOperation? get lastRedoOperation =>
      _redoStack.isNotEmpty ? _redoStack.last : null;

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPersistedOperations();

    // Start cleanup timer for expired operations
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _cleanupExpiredOperations();
    });
  }

  /// Add an undoable operation to the stack
  void addOperation(UndoableOperation operation) {
    // Clear redo stack when new operation is added
    _redoStack.clear();

    // Add to undo stack
    _undoStack.add(operation);

    // Trim stack if it exceeds max size
    if (_undoStack.length > maxStackSize) {
      _undoStack.removeAt(0);
    }

    // Persist to storage
    unawaited(_persistOperations());

    // Notify listeners
    notifyListeners();

    _logger.debug('Added undo operation: ${operation.description}');
  }

  /// Record a note folder change operation
  void recordNoteFolderChange({
    required String noteId,
    required String noteTitle,
    required String? previousFolderId,
    required String? previousFolderName,
    required String? newFolderId,
    required String? newFolderName,
  }) {
    final operation = NoteFolderChangeOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      description: newFolderId == null
          ? 'Unfiled "$noteTitle"'
          : 'Moved "$noteTitle" to ${newFolderName ?? "folder"}',
      noteId: noteId,
      noteTitle: noteTitle,
      previousFolderId: previousFolderId,
      previousFolderName: previousFolderName,
      newFolderId: newFolderId,
      newFolderName: newFolderName,
      repository: repository,
      expiresAt: DateTime.now().add(defaultExpiration),
    );

    addOperation(operation);
  }

  /// Record a batch folder change operation
  void recordBatchFolderChange({
    required List<String> noteIds,
    required Map<String, String?> previousFolderIds,
    required String? newFolderId,
    required String? newFolderName,
  }) {
    final count = noteIds.length;
    final operation = BatchFolderChangeOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      description: newFolderId == null
          ? 'Unfiled $count notes'
          : 'Moved $count notes to ${newFolderName ?? "folder"}',
      noteIds: noteIds,
      previousFolderIds: previousFolderIds,
      newFolderId: newFolderId,
      newFolderName: newFolderName,
      repository: repository,
      expiresAt: DateTime.now().add(defaultExpiration),
    );

    addOperation(operation);
  }

  /// Record a folder move operation
  void recordFolderMove({
    required String folderId,
    required String folderName,
    required String? previousParentId,
    required String? newParentId,
  }) {
    final operation = FolderMoveOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      description: 'Moved folder "$folderName"',
      folderId: folderId,
      folderName: folderName,
      previousParentId: previousParentId,
      newParentId: newParentId,
      repository: repository,
      expiresAt: DateTime.now().add(defaultExpiration),
    );

    addOperation(operation);
  }

  /// Undo the last operation
  Future<bool> undo() async {
    if (!canUndo) return false;

    final operation = _undoStack.removeLast();

    // Check if operation has expired
    if (operation.isExpired) {
      _logger.debug('Operation expired: ${operation.description}');
      notifyListeners();
      return false;
    }

    try {
      await operation.undo();
      _redoStack.add(operation);

      // Trim redo stack if needed
      if (_redoStack.length > maxStackSize) {
        _redoStack.removeAt(0);
      }

      await _persistOperations();
      notifyListeners();

      _logger.debug('Undid operation: ${operation.description}');
      return true;
    } catch (e, stack) {
      _logger.error('Failed to undo operation', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Redo the last undone operation
  Future<bool> redo() async {
    if (!canRedo) return false;

    final operation = _redoStack.removeLast();

    // Check if operation has expired
    if (operation.isExpired) {
      _logger.debug('Operation expired: ${operation.description}');
      notifyListeners();
      return false;
    }

    try {
      await operation.redo();
      _undoStack.add(operation);

      await _persistOperations();
      notifyListeners();

      _logger.debug('Redid operation: ${operation.description}');
      return true;
    } catch (e, stack) {
      _logger.error('Failed to redo operation', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Clear all undo/redo history
  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
    unawaited(_persistOperations());
    notifyListeners();
  }

  /// Clean up expired operations
  void _cleanupExpiredOperations() {
    _undoStack.removeWhere((op) => op.isExpired);
    _redoStack.removeWhere((op) => op.isExpired);

    if (_undoStack.isEmpty || _redoStack.isEmpty) {
      notifyListeners();
    }
  }

  /// Persist operations to storage
  Future<void> _persistOperations() async {
    try {
      final undoJson = _undoStack
          .where((op) => !op.isExpired)
          .map((op) => op.toJson())
          .toList();
      final redoJson = _redoStack
          .where((op) => !op.isExpired)
          .map((op) => op.toJson())
          .toList();

      await _prefs?.setString('undo_stack_$userId', jsonEncode(undoJson));
      await _prefs?.setString('redo_stack_$userId', jsonEncode(redoJson));
    } catch (e) {
      _logger.error('Failed to persist undo/redo operations', error: e);
    }
  }

  /// Load persisted operations from storage
  Future<void> _loadPersistedOperations() async {
    try {
      final undoJson = _prefs?.getString('undo_stack_$userId');
      final redoJson = _prefs?.getString('redo_stack_$userId');

      if (undoJson != null) {
        final undoList = jsonDecode(undoJson) as List;
        for (final json in undoList) {
          final operation = _recreateOperation(json as Map<String, dynamic>);
          if (operation != null && !operation.isExpired) {
            _undoStack.add(operation);
          }
        }
      }

      if (redoJson != null) {
        final redoList = jsonDecode(redoJson) as List;
        for (final json in redoList) {
          final operation = _recreateOperation(json as Map<String, dynamic>);
          if (operation != null && !operation.isExpired) {
            _redoStack.add(operation);
          }
        }
      }

      notifyListeners();
    } catch (e) {
      _logger.error('Failed to load persisted operations', error: e);
    }
  }

  /// Recreate operation from JSON with repository injection
  UndoableOperation? _recreateOperation(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'note_folder_change':
        return NoteFolderChangeOperation(
          id: json['id'] as String,
          timestamp: DateTime.parse(json['timestamp'] as String),
          description: json['description'] as String,
          noteId: json['noteId'] as String,
          noteTitle: json['noteTitle'] as String,
          previousFolderId: json['previousFolderId'] as String?,
          previousFolderName: json['previousFolderName'] as String?,
          newFolderId: json['newFolderId'] as String?,
          newFolderName: json['newFolderName'] as String?,
          repository: repository,
          expiresAt: json['expiresAt'] != null
              ? DateTime.parse(json['expiresAt'] as String)
              : null,
        );
      case 'batch_folder_change':
        return BatchFolderChangeOperation(
          id: json['id'] as String,
          timestamp: DateTime.parse(json['timestamp'] as String),
          description: json['description'] as String,
          noteIds: List<String>.from(json['noteIds'] as List),
          previousFolderIds: Map<String, String?>.from(
            json['previousFolderIds'] as Map,
          ),
          newFolderId: json['newFolderId'] as String?,
          newFolderName: json['newFolderName'] as String?,
          repository: repository,
          expiresAt: json['expiresAt'] != null
              ? DateTime.parse(json['expiresAt'] as String)
              : null,
        );
      case 'folder_move':
        return FolderMoveOperation(
          id: json['id'] as String,
          timestamp: DateTime.parse(json['timestamp'] as String),
          description: json['description'] as String,
          folderId: json['folderId'] as String,
          folderName: json['folderName'] as String,
          previousParentId: json['previousParentId'] as String?,
          newParentId: json['newParentId'] as String?,
          repository: repository,
          expiresAt: json['expiresAt'] != null
              ? DateTime.parse(json['expiresAt'] as String)
              : null,
        );
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }
}
