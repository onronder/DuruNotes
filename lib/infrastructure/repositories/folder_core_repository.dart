import 'package:drift/drift.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/infrastructure/mappers/folder_mapper.dart';
import 'package:duru_notes/infrastructure/mappers/note_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Core folder repository implementation
class FolderCoreRepository implements IFolderRepository {
  FolderCoreRepository({
    required this.db,
    required this.client,
  })  : _logger = LoggerFactory.instance;

  final AppDb db;
  final SupabaseClient client;
  final AppLogger _logger;
  final _uuid = const Uuid();

  @override
  Future<domain.Folder?> getFolder(String id) async {
    try {
      final localFolder = await db.getFolderById(id);
      if (localFolder == null) return null;

      return FolderMapper.toDomain(localFolder);
    } catch (e, stack) {
      _logger.error('Failed to get folder by id: $id', error: e, stackTrace: stack);
      return null;
    }
  }

  @override
  Future<List<domain.Folder>> listFolders() async {
    try {
      final localFolders = await db.allFolders();
      return FolderMapper.toDomainList(localFolders);
    } catch (e, stack) {
      _logger.error('Failed to list all folders', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<List<domain.Folder>> getRootFolders() async {
    try {
      final localFolders = await db.getRootFolders();
      return FolderMapper.toDomainList(localFolders);
    } catch (e, stack) {
      _logger.error('Failed to get root folders', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<domain.Folder> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().toUtc();
      final userId = client.auth.currentUser?.id;

      if (userId == null || userId.isEmpty) {
        throw Exception('Cannot create folder without authenticated user');
      }

      final localFolder = LocalFolder(
        id: id,
        name: name,
        parentId: parentId,
        path: parentId != null ? '' : '/$name', // Will be updated by trigger
        color: color ?? '#048ABF',
        icon: icon ?? 'folder',
        description: description ?? '',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
        deleted: false,
      );

      await db.upsertFolder(localFolder);

      // Enqueue for sync
      await db.enqueue(id, 'upsert_folder');

      return FolderMapper.toDomain(localFolder);
    } catch (e, stack) {
      _logger.error('Failed to create folder: $name', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<String> createOrUpdateFolder({
    required String name,
    String? id,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
  }) async {
    try {
      final folderId = id ?? _uuid.v4();
      final existingFolder = await db.getFolderById(folderId);
      final now = DateTime.now().toUtc();
      final userId = client.auth.currentUser?.id;

      if (userId == null || userId.isEmpty) {
        throw Exception('Cannot create/update folder without authenticated user');
      }

      final localFolder = LocalFolder(
        id: folderId,
        name: name,
        parentId: parentId,
        path: existingFolder?.path ?? (parentId != null ? '' : '/$name'), // Will be updated by trigger
        color: color ?? existingFolder?.color ?? '#048ABF',
        icon: icon ?? existingFolder?.icon ?? 'folder',
        description: description ?? existingFolder?.description ?? '',
        sortOrder: sortOrder ?? existingFolder?.sortOrder ?? 0,
        createdAt: existingFolder?.createdAt ?? now,
        updatedAt: now,
        deleted: existingFolder?.deleted ?? false,
      );

      await db.upsertFolder(localFolder);

      // Enqueue for sync
      await db.enqueue(folderId, 'upsert_folder');

      return folderId;
    } catch (e, stack) {
      _logger.error('Failed to create/update folder: $name', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> renameFolder(String folderId, String newName) async {
    try {
      final existingFolder = await db.getFolderById(folderId);
      if (existingFolder == null) {
        throw Exception('Folder not found: $folderId');
      }

      final updatedFolder = LocalFolder(
        id: existingFolder.id,
        name: newName,
        parentId: existingFolder.parentId,
        path: existingFolder.path, // Will be updated by trigger
        color: existingFolder.color,
        icon: existingFolder.icon,
        description: existingFolder.description,
        sortOrder: existingFolder.sortOrder,
        createdAt: existingFolder.createdAt,
        updatedAt: DateTime.now().toUtc(),
        deleted: existingFolder.deleted,
      );

      await db.upsertFolder(updatedFolder);

      // Enqueue for sync
      await db.enqueue(folderId, 'upsert_folder');
    } catch (e, stack) {
      _logger.error('Failed to rename folder: $folderId to $newName', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> moveFolder(String folderId, String? newParentId) async {
    try {
      final existingFolder = await db.getFolderById(folderId);
      if (existingFolder == null) {
        throw Exception('Folder not found: $folderId');
      }

      // Validate that we're not creating a circular reference
      if (newParentId != null && await _wouldCreateCircularReference(folderId, newParentId)) {
        throw Exception('Moving folder would create circular reference');
      }

      final updatedFolder = LocalFolder(
        id: existingFolder.id,
        name: existingFolder.name,
        parentId: newParentId,
        path: existingFolder.path, // Will be updated by trigger
        color: existingFolder.color,
        icon: existingFolder.icon,
        description: existingFolder.description,
        sortOrder: existingFolder.sortOrder,
        createdAt: existingFolder.createdAt,
        updatedAt: DateTime.now().toUtc(),
        deleted: existingFolder.deleted,
      );

      await db.upsertFolder(updatedFolder);

      // Enqueue for sync
      await db.enqueue(folderId, 'upsert_folder');
    } catch (e, stack) {
      _logger.error('Failed to move folder: $folderId to parent $newParentId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    try {
      // First, move all notes in this folder to unfiled
      await _moveNotesToUnfiled(folderId);

      // Move all child folders to parent or root
      final childFolders = await db.getChildFolders(folderId);
      final parentFolder = await db.getFolderById(folderId);
      final newParentId = parentFolder?.parentId;

      for (final child in childFolders) {
        await moveFolder(child.id, newParentId);
      }

      // Now delete the folder itself
      await db.transaction(() async {
        // Remove folder-note relationships
        await db.removeNoteFromFolder(folderId);

        // Delete the folder
        await (db.delete(db.localFolders)
          ..where((f) => f.id.equals(folderId)))
          .go();
      });

      // Enqueue for sync deletion
      await db.enqueue(folderId, 'delete_folder');
    } catch (e, stack) {
      _logger.error('Failed to delete folder: $folderId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<List<domain.Note>> getNotesInFolder(String folderId) async {
    try {
      final localNotes = await db.getNotesInFolder(folderId);

      // Convert to domain entities with tags and links
      final List<domain.Note> domainNotes = [];
      for (final localNote in localNotes) {
        // Query tags directly from note_tags table
        final tagRecords = await (db.select(db.noteTags)
              ..where((t) => t.noteId.equals(localNote.id)))
            .get();
        final tags = tagRecords.map((t) => t.tag).toList();

        // Query links directly from note_links table
        final linkRecords = await (db.select(db.noteLinks)
              ..where((l) => l.sourceId.equals(localNote.id)))
            .get();
        final domainLinks = linkRecords.map(NoteMapper.linkToDomain).toList();

        domainNotes.add(NoteMapper.toDomain(
          localNote,
          tags: tags,
          links: domainLinks,
        ));
      }

      return domainNotes;
    } catch (e, stack) {
      _logger.error('Failed to get notes in folder: $folderId', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<List<domain.Note>> getUnfiledNotes() async {
    try {
      // Get notes with no folder assignment using the NoteFolders junction table
      final noteIdsWithFolders = await (db.select(db.noteFolders)
            .map((nf) => nf.noteId))
          .get();

      final localNotes = await (db.select(db.localNotes)
            ..where((note) =>
                note.id.isNotIn(noteIdsWithFolders) &
                note.deleted.equals(false)))
          .get();

      // Convert to domain entities with tags and links
      final List<domain.Note> domainNotes = [];
      for (final localNote in localNotes) {
        // Query tags directly from note_tags table
        final tagRecords = await (db.select(db.noteTags)
              ..where((t) => t.noteId.equals(localNote.id)))
            .get();
        final tags = tagRecords.map((t) => t.tag).toList();

        // Query links directly from note_links table
        final linkRecords = await (db.select(db.noteLinks)
              ..where((l) => l.sourceId.equals(localNote.id)))
            .get();
        final domainLinks = linkRecords.map(NoteMapper.linkToDomain).toList();

        domainNotes.add(NoteMapper.toDomain(
          localNote,
          tags: tags,
          links: domainLinks,
        ));
      }

      return domainNotes;
    } catch (e, stack) {
      _logger.error('Failed to get unfiled notes', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<void> addNoteToFolder(String noteId, String folderId) async {
    try {
      await db.moveNoteToFolder(noteId, folderId);

      // Enqueue note update for sync
      await db.enqueue(noteId, 'upsert_note');
    } catch (e, stack) {
      _logger.error('Failed to add note $noteId to folder $folderId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> moveNoteToFolder(String noteId, String? folderId) async {
    try {
      await db.moveNoteToFolder(noteId, folderId);

      // Enqueue note update for sync
      await db.enqueue(noteId, 'upsert_note');
    } catch (e, stack) {
      _logger.error('Failed to move note $noteId to folder $folderId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> removeNoteFromFolder(String noteId) async {
    try {
      await db.removeNoteFromFolder(noteId);

      // Enqueue note update for sync
      await db.enqueue(noteId, 'upsert_note');
    } catch (e, stack) {
      _logger.error('Failed to remove note $noteId from folder', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<Map<String, int>> getFolderNoteCounts() async {
    try {
      return await db.getFolderNoteCounts();
    } catch (e, stack) {
      _logger.error('Failed to get folder note counts', error: e, stackTrace: stack);
      return {};
    }
  }

  @override
  Future<domain.Folder?> getFolderForNote(String noteId) async {
    try {
      final localFolder = await db.getFolderForNote(noteId);
      if (localFolder == null) return null;

      return FolderMapper.toDomain(localFolder);
    } catch (e, stack) {
      _logger.error('Failed to get folder for note: $noteId', error: e, stackTrace: stack);
      return null;
    }
  }

  @override
  Future<List<domain.Folder>> getChildFolders(String parentId) async {
    try {
      final localFolders = await db.getChildFolders(parentId);
      return FolderMapper.toDomainList(localFolders);
    } catch (e, stack) {
      _logger.error('Failed to get child folders for: $parentId', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<List<domain.Folder>> getChildFoldersRecursive(String parentId) async {
    try {
      final localFolders = await db.getFolderSubtree(parentId);
      return FolderMapper.toDomainList(localFolders);
    } catch (e, stack) {
      _logger.error('Failed to get child folders recursively for: $parentId', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<void> ensureFolderIntegrity() async {
    try {
      _logger.info('Starting folder integrity check');

      // Check for orphaned notes (notes referencing non-existent folders)
      await _fixOrphanedNotes();

      // Check for circular references in folder hierarchy
      await _fixCircularReferences();

      // Validate folder hierarchy depth
      await _validateFolderDepth();

      _logger.info('Folder integrity check completed');
    } catch (e, stack) {
      _logger.error('Failed to ensure folder integrity', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> performFolderHealthCheck() async {
    try {
      final results = <String, dynamic>{};

      // Count total folders
      final allFolders = await db.allFolders();
      results['total_folders'] = allFolders.length;

      // Count root folders
      final rootFolders = await db.getRootFolders();
      results['root_folders'] = rootFolders.length;

      // Check for orphaned notes
      final orphanedNotes = await _findOrphanedNotes();
      results['orphaned_notes'] = orphanedNotes.length;

      // Check for circular references
      final circularRefs = await _findCircularReferences();
      results['circular_references'] = circularRefs.length;

      // Check folder depths
      final maxDepth = await _calculateMaxFolderDepth();
      results['max_folder_depth'] = maxDepth;

      // Overall health score
      final healthScore = _calculateHealthScore(results);
      results['health_score'] = healthScore;
      results['status'] = healthScore >= 0.9 ? 'healthy' :
                         healthScore >= 0.7 ? 'warning' : 'critical';

      results['timestamp'] = DateTime.now().toIso8601String();

      return results;
    } catch (e, stack) {
      _logger.error('Failed to perform folder health check', error: e, stackTrace: stack);
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'error',
      };
    }
  }

  @override
  Future<void> validateAndRepairFolderStructure() async {
    try {
      _logger.info('Starting folder structure validation and repair');

      // Fix orphaned notes
      await _fixOrphanedNotes();

      // Fix circular references
      await _fixCircularReferences();

      // Validate and fix folder depths
      await _validateFolderDepth();

      // Update folder note counts
      await _updateFolderNoteCounts();

      _logger.info('Folder structure validation and repair completed');
    } catch (e, stack) {
      _logger.error('Failed to validate and repair folder structure', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> cleanupOrphanedRelationships() async {
    try {
      _logger.info('Starting cleanup of orphaned relationships');

      // Remove note-folder relationships where folder doesn't exist
      await db.transaction(() async {
        final orphanedRelations = await db.getAllNoteFolderRelationships();

        for (final relation in orphanedRelations) {
          final folderExists = await db.getFolderById(relation.folderId) != null;
          final noteExists = await (db.select(db.localNotes)
                ..where((n) => n.id.equals(relation.noteId)))
              .getSingleOrNull() != null;

          if (!folderExists || !noteExists) {
            await (db.delete(db.noteFolders)
              ..where((nf) => nf.noteId.equals(relation.noteId) &
                             nf.folderId.equals(relation.folderId)))
              .go();
          }
        }
      });

      _logger.info('Cleanup of orphaned relationships completed');
    } catch (e, stack) {
      _logger.error('Failed to cleanup orphaned relationships', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> resolveFolderConflicts() async {
    try {
      _logger.info('Starting folder conflict resolution');

      // Find and resolve duplicate folder names in same parent
      await _resolveDuplicateFolderNames();

      // Fix invalid parent references
      await _fixInvalidParentReferences();

      _logger.info('Folder conflict resolution completed');
    } catch (e, stack) {
      _logger.error('Failed to resolve folder conflicts', error: e, stackTrace: stack);
      rethrow;
    }
  }

  // Private helper methods

  Future<bool> _wouldCreateCircularReference(String folderId, String parentId) async {
    String? currentParentId = parentId;

    while (currentParentId != null) {
      if (currentParentId == folderId) {
        return true;
      }
      final parentFolder = await db.getFolderById(currentParentId);
      currentParentId = parentFolder?.parentId;
    }

    return false;
  }

  Future<void> _moveNotesToUnfiled(String folderId) async {
    final noteIds = await db.getNoteIdsInFolder(folderId);
    for (final noteId in noteIds) {
      await db.moveNoteToFolder(noteId, null);
    }
  }

  Future<List<String>> _findOrphanedNotes() async {
    // Find notes with folder references that don't exist in the folders table
    final noteFolderRels = await db.select(db.noteFolders).get();

    final orphanedNotes = <String>[];

    for (final rel in noteFolderRels) {
      final folderExists = await db.getFolderById(rel.folderId) != null;
      if (!folderExists) {
        orphanedNotes.add(rel.noteId);
      }
    }

    return orphanedNotes;
  }

  Future<void> _fixOrphanedNotes() async {
    final orphanedNotes = await _findOrphanedNotes();

    for (final noteId in orphanedNotes) {
      await db.moveNoteToFolder(noteId, null);
    }

    _logger.info('Fixed ${orphanedNotes.length} orphaned notes');
  }

  Future<List<String>> _findCircularReferences() async {
    final allFolders = await db.allFolders();
    final circularRefs = <String>[];

    for (final folder in allFolders) {
      if (folder.parentId != null &&
          await _wouldCreateCircularReference(folder.id, folder.parentId!)) {
        circularRefs.add(folder.id);
      }
    }

    return circularRefs;
  }

  Future<void> _fixCircularReferences() async {
    final circularRefs = await _findCircularReferences();

    for (final folderId in circularRefs) {
      await moveFolder(folderId, null); // Move to root
    }

    _logger.info('Fixed ${circularRefs.length} circular references');
  }

  Future<int> _calculateMaxFolderDepth() async {
    final allFolders = await db.allFolders();
    int maxDepth = 0;

    for (final folder in allFolders) {
      final depth = await db.getFolderDepth(folder.id);
      if (depth > maxDepth) {
        maxDepth = depth;
      }
    }

    return maxDepth;
  }

  Future<void> _validateFolderDepth() async {
    const maxAllowedDepth = 10;
    final allFolders = await db.allFolders();

    for (final folder in allFolders) {
      final depth = await db.getFolderDepth(folder.id);
      if (depth > maxAllowedDepth) {
        // Move deeply nested folders to root
        await moveFolder(folder.id, null);
        _logger.warning('Moved deeply nested folder ${folder.name} to root');
      }
    }
  }

  Future<void> _updateFolderNoteCounts() async {
    final allFolders = await db.allFolders();

    for (final folder in allFolders) {
      await db.getNotesCountInFolder(folder.id);
    }
  }

  Future<void> _resolveDuplicateFolderNames() async {
    final allFolders = await db.allFolders();
    final foldersByParent = <String?, List<LocalFolder>>{};

    // Group folders by parent
    for (final folder in allFolders) {
      foldersByParent.putIfAbsent(folder.parentId, () => []).add(folder);
    }

    // Check for duplicates within each parent
    for (final parentId in foldersByParent.keys) {
      final folders = foldersByParent[parentId]!;
      final nameGroups = <String, List<LocalFolder>>{};

      for (final folder in folders) {
        nameGroups.putIfAbsent(folder.name, () => []).add(folder);
      }

      // Rename duplicates
      for (final name in nameGroups.keys) {
        final duplicates = nameGroups[name]!;
        if (duplicates.length > 1) {
          for (int i = 1; i < duplicates.length; i++) {
            final newName = '${duplicates[i].name} (${i + 1})';
            await renameFolder(duplicates[i].id, newName);
          }
        }
      }
    }
  }

  Future<void> _fixInvalidParentReferences() async {
    final allFolders = await db.allFolders();

    for (final folder in allFolders) {
      if (folder.parentId != null) {
        final parentExists = await db.getFolderById(folder.parentId!) != null;
        if (!parentExists) {
          await moveFolder(folder.id, null); // Move to root
        }
      }
    }
  }

  double _calculateHealthScore(Map<String, dynamic> results) {
    double score = 1.0;

    // Penalize orphaned notes
    final orphanedNotes = results['orphaned_notes'] as int? ?? 0;
    score -= (orphanedNotes * 0.1).clamp(0.0, 0.3);

    // Penalize circular references
    final circularRefs = results['circular_references'] as int? ?? 0;
    score -= (circularRefs * 0.2).clamp(0.0, 0.5);

    // Penalize excessive depth
    final maxDepth = results['max_folder_depth'] as int? ?? 0;
    if (maxDepth > 10) {
      score -= 0.2;
    } else if (maxDepth > 7) {
      score -= 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  // ===== Legacy method aliases for backward compatibility =====

  /// Alias for getFolder() - returns LocalFolder for backward compatibility
  Future<LocalFolder?> getFolderById(String id) async {
    final folder = await getFolder(id);
    if (folder == null) return null;
    return FolderMapper.toInfrastructure(folder);
  }

  /// Alias for listFolders() - returns LocalFolders for backward compatibility
  Future<List<LocalFolder>> getAllFolders() async {
    final folders = await listFolders();
    return FolderMapper.toInfrastructureList(folders);
  }

  /// Alias for createFolder() - returns LocalFolder for backward compatibility
  Future<LocalFolder> createLocalFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) async {
    final folder = await createFolder(
      name: name,
      parentId: parentId,
      color: color,
      icon: icon,
      description: description,
    );
    return FolderMapper.toInfrastructure(folder);
  }

  /// Alias for createOrUpdateFolder() - for backward compatibility
  Future<void> updateLocalFolder(LocalFolder folder) async {
    await createOrUpdateFolder(
      id: folder.id,
      name: folder.name,
      parentId: folder.parentId,
      color: folder.color,
      icon: folder.icon,
      description: folder.description,
    );
  }

  /// Alias for deleteFolder() - for backward compatibility
  Future<void> deleteLocalFolder(String folderId) async {
    await deleteFolder(folderId);
  }
}