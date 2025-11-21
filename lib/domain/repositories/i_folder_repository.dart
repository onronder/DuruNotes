import 'package:duru_notes/domain/entities/folder.dart';
import 'package:duru_notes/domain/entities/note.dart';

/// Domain interface for folder operations
abstract class IFolderRepository {
  /// Get a folder by ID
  Future<Folder?> getFolder(String id);

  /// List all folders
  Future<List<Folder>> listFolders();

  /// Get root-level folders
  Future<List<Folder>> getRootFolders();

  /// Create a new folder
  Future<Folder> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  });

  /// Create or update a folder
  Future<String> createOrUpdateFolder({
    required String name,
    String? id,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
  });

  /// Rename a folder
  Future<void> renameFolder(String folderId, String newName);

  /// Move a folder to a new parent
  Future<void> moveFolder(String folderId, String? newParentId);

  /// Delete a folder
  Future<void> deleteFolder(String folderId);

  /// Get all soft-deleted folders for Trash view (Phase 1.1)
  Future<List<Folder>> getDeletedFolders();

  /// Restore a soft-deleted folder from trash (Phase 1.1)
  Future<void> restoreFolder(String folderId, {bool restoreContents = false});

  /// Permanently delete a folder (hard delete, cannot be undone)
  /// This removes the folder from the database entirely
  Future<void> permanentlyDeleteFolder(String folderId);

  /// Get notes in a folder
  Future<List<Note>> getNotesInFolder(String folderId);

  /// Get unfiled notes (no folder)
  Future<List<Note>> getUnfiledNotes();

  /// Add a note to a folder
  Future<void> addNoteToFolder(String noteId, String folderId);

  /// Move a note to a folder
  Future<void> moveNoteToFolder(String noteId, String? folderId);

  /// Remove a note from its folder
  Future<void> removeNoteFromFolder(String noteId);

  /// Get folder note counts
  Future<Map<String, int>> getFolderNoteCounts();

  /// Get the folder for a specific note
  Future<Folder?> getFolderForNote(String noteId);

  /// Get child folders
  Future<List<Folder>> getChildFolders(String parentId);

  /// Get child folders recursively
  Future<List<Folder>> getChildFoldersRecursive(String parentId);

  /// Find a folder by name
  Future<Folder?> findFolderByName(String name);

  /// Get folder hierarchy depth
  Future<int> getFolderDepth(String folderId);

  /// Get note IDs in a folder
  Future<List<String>> getNoteIdsInFolder(String folderId);

  /// Get notes count in a folder
  Future<int> getNotesCountInFolder(String folderId);

  /// Folder maintenance operations
  Future<void> ensureFolderIntegrity();
  Future<Map<String, dynamic>> performFolderHealthCheck();
  Future<void> validateAndRepairFolderStructure();
  Future<void> cleanupOrphanedRelationships();
  Future<void> resolveFolderConflicts();

  /// Get current user ID (for user-specific operations)
  String? getCurrentUserId();

  /// GDPR Article 17: Anonymize all folders for a user by overwriting encrypted data
  ///
  /// This method irreversibly overwrites all encrypted content with random data,
  /// making the original content permanently inaccessible. This is part of the
  /// GDPR Right to Erasure implementation.
  ///
  /// **Security**: Uses DoD 5220.22-M 3-pass overwrite pattern
  ///
  /// Returns the count of folders anonymized.
  Future<int> anonymizeAllFoldersForUser(String userId);
}
