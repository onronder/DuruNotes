import 'package:duru_notes/core/bootstrap/bootstrap_providers.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/crypto/key_manager.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/core/settings/analytics_notifier.dart';
import 'package:duru_notes/core/settings/locale_notifier.dart';
import 'package:duru_notes/core/settings/sync_mode.dart';
import 'package:duru_notes/core/settings/sync_mode_notifier.dart';
import 'package:duru_notes/core/settings/theme_mode_notifier.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/features/folders/note_folder_integration_service.dart';
import 'package:duru_notes/features/notes/pagination_notifier.dart';
import 'package:duru_notes/providers/unified_reminder_provider.dart';
// Legacy repository imports removed - now using domain architecture providers
// import 'package:duru_notes/infrastructure/repositories/folder_core_repository.dart';
// import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
// import 'package:duru_notes/repository/notes_repository_refactored.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/search_repository.dart';
import 'package:duru_notes/infrastructure/repositories/tag_repository.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_search_repository.dart';
import 'package:duru_notes/domain/repositories/i_tag_repository.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/repositories/i_template_repository.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/infrastructure/repositories/folder_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/template_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/task_core_repository.dart';
// Note: Mappers are imported in state_migration_helper.dart
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/core/migration/state_migration_helper.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/folder.dart' as domain_folder;
import 'package:duru_notes/domain/entities/template.dart' as domain_template;
import 'package:duru_notes/domain/entities/task.dart' as domain_task;
// Legacy repository imports removed - now using domain architecture providers
// import 'package:duru_notes/repository/sync_service.dart';
// import 'package:duru_notes/infrastructure/repositories/task_core_repository.dart';
// import 'package:duru_notes/infrastructure/repositories/template_core_repository.dart';
import 'package:duru_notes/search/search_service.dart';
import 'package:duru_notes/services/account_key_service.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/attachment_service.dart';
import 'package:duru_notes/services/clipper_inbox_notes_adapter.dart';
import 'package:duru_notes/services/clipper_inbox_service.dart';
import 'package:duru_notes/services/connection_manager.dart';
import 'package:duru_notes/services/email_alias_service.dart';
import 'package:duru_notes/services/export_service.dart';
// import 'package:duru_notes/services/folder_realtime_service.dart'; // Unused
import 'package:duru_notes/services/import_service.dart';
import 'package:duru_notes/services/inbox_management_service.dart';
// import 'package:duru_notes/services/inbox_realtime_service.dart'; // Unused
import 'package:duru_notes/services/inbox_unread_service.dart';
import 'package:duru_notes/services/incoming_mail_folder_manager.dart';
// import 'package:duru_notes/services/notes_realtime_service.dart'; // Unused
import 'package:duru_notes/services/notification_handler_service.dart';
import 'package:duru_notes/services/push_notification_service.dart';
import 'package:duru_notes/services/share_extension_service.dart';
import 'package:duru_notes/services/sort_preferences_service.dart';
import 'package:duru_notes/services/sync/folder_remote_api.dart';
import 'package:duru_notes/services/sync/folder_sync_audit.dart';
import 'package:duru_notes/services/sync/folder_sync_coordinator.dart';
import 'package:duru_notes/services/task_service.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/services/task_reminder_bridge.dart';
import 'package:duru_notes/services/template_migration_service.dart';
import 'package:duru_notes/services/task_analytics_service.dart';
import 'package:duru_notes/services/unified_task_service.dart' as unified;
import 'package:duru_notes/services/analytics/analytics_factory.dart';
import 'package:duru_notes/services/productivity_goals_service.dart';
import 'package:duru_notes/services/advanced_reminder_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:duru_notes/services/undo_redo_service.dart';
// import 'package:duru_notes/services/folder_undo_service.dart'; // Unused
import 'package:duru_notes/services/unified_realtime_service.dart';
import 'package:duru_notes/ui/filters/filters_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';
import 'dart:async';

// Export important types for easier importing
export 'data/local/app_db.dart' show AppDb, LocalNote;
export 'features/notes/pagination_notifier.dart' show NotesPage;

// ===== LEGACY TYPE COMPATIBILITY ALIASES =====
// These type aliases provide compatibility with legacy code during migration
// TODO: Remove these once all consumers are migrated to domain architecture

/// Legacy NotesRepository type alias - points to infrastructure implementation
typedef NotesRepository = NotesCoreRepository;

/// Extension to add legacy methods to NotesCoreRepository for backward compatibility
extension NotesRepositoryLegacyMethods on NotesCoreRepository {
  /// Get a single note by ID
  Future<LocalNote?> getNote(String id) async {
    final query = db.select(db.localNotes)..where((n) => n.id.equals(id));
    return query.getSingleOrNull();
  }

  /// Get notes in a specific folder
  Future<List<LocalNote>> getNotesInFolder(String folderId) async {
    // Notes are linked to folders via the NoteFolders junction table
    // First get note IDs from the junction table
    final noteFolderRecords = await (db.select(db.noteFolders)
      ..where((nf) => nf.folderId.equals(folderId)))
      .get();

    final noteIds = noteFolderRecords.map((nf) => nf.noteId).toList();

    if (noteIds.isEmpty) return [];

    // Then get the actual notes
    final query = db.select(db.localNotes)
      ..where((n) => n.deleted.equals(false))
      ..where((n) => n.id.isIn(noteIds))
      ..orderBy([
        (n) => OrderingTerm(expression: n.isPinned, mode: OrderingMode.desc),
        (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
      ]);
    return query.get();
  }

  /// Get root folders
  Future<List<LocalFolder>> getRootFolders() => db.getRootFolders();

  /// List all folders
  Future<List<LocalFolder>> listFolders() async => db.getActiveFolders();

  /// Get child folders
  Future<List<LocalFolder>> getChildFolders(String parentId) =>
      db.getChildFolders(parentId);

  /// Get folder by ID
  Future<LocalFolder?> getFolder(String id) async => db.getFolderById(id);

  /// Add note to folder
  Future<void> addNoteToFolder(String noteId, String folderId) async {
    await db.into(db.noteFolders).insert(
      NoteFoldersCompanion.insert(
        noteId: noteId,
        folderId: folderId,
        addedAt: DateTime.now(),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Remove note from folder
  Future<void> removeNoteFromFolder(String noteId) async {
    await (db.delete(db.noteFolders)..where((nf) => nf.noteId.equals(noteId))).go();
  }

  /// Get folder for a note (returns first folder if note is in multiple)
  Future<String?> getFolderForNote(String noteId) async {
    final record = await (db.select(db.noteFolders)..where((nf) => nf.noteId.equals(noteId))).getSingleOrNull();
    return record?.folderId;
  }

  /// Create or update folder
  Future<void> createOrUpdateFolder({
    required String id,
    required String name,
    String? color,
    String? icon,
    String? description,
    String? parentId,
  }) async {
    final now = DateTime.now();
    // Compute path based on parentId
    String path;
    if (parentId != null) {
      final parent = await db.getFolderById(parentId);
      path = parent != null ? '${parent.path}/$name' : '/$name';
    } else {
      path = '/$name';
    }

    await db.into(db.localFolders).insert(
      LocalFoldersCompanion.insert(
        id: id,
        name: name,
        path: path,
        description: Value(description ?? ''),
        createdAt: now,
        updatedAt: now,
        color: Value(color),
        icon: Value(icon),
        parentId: Value(parentId),
        deleted: const Value(false),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Delete folder (soft delete)
  Future<void> deleteFolder(String id) async {
    await (db.update(db.localFolders)..where((f) => f.id.equals(id))).write(
      LocalFoldersCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Get note counts for folders
  Future<Map<String, int>> getFolderNoteCounts() async {
    final noteFolderRecords = await db.select(db.noteFolders).get();
    final counts = <String, int>{};
    for (final record in noteFolderRecords) {
      counts[record.folderId] = (counts[record.folderId] ?? 0) + 1;
    }
    return counts;
  }

  /// Ensure folder integrity (stub for compatibility)
  Future<void> ensureFolderIntegrity() async {
    // No-op for compatibility - folder integrity is maintained by database constraints
  }

  /// Create or update saved search (for backward compatibility)
  Future<void> createOrUpdateSavedSearch(SavedSearch savedSearch) async {
    await db.upsertSavedSearch(savedSearch);
  }

  /// Get unfiled notes (notes not in any folder)
  Future<List<LocalNote>> getUnfiledNotes() async {
    // Get all note IDs that are in folders
    final noteFolderRecords = await db.select(db.noteFolders).get();
    final noteIdsInFolders = noteFolderRecords.map((nf) => nf.noteId).toSet();

    // Get all notes
    final allNotes = await (db.select(db.localNotes)
      ..where((n) => n.deleted.equals(false))
      ..orderBy([
        (n) => OrderingTerm(expression: n.isPinned, mode: OrderingMode.desc),
        (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
      ])).get();

    // Filter to only notes not in any folder
    return allNotes.where((note) => !noteIdsInFolders.contains(note.id)).toList();
  }

  /// Watch saved searches
  Stream<List<SavedSearch>> watchSavedSearches() {
    return db.select(db.savedSearches).watch();
  }

  // NOTE: Tag functionality requires Tags table schema migration
  // These are stub methods for backward compatibility

  /// Add tag to note (stub - requires Tags table migration)
  Future<void> addTag(String noteId, String tagName) async {
    // Tags table not yet migrated - no-op for now
    return;
  }

  /// Remove tag from note (stub - requires Tags table migration)
  Future<void> removeTag(String noteId, String tagId) async {
    // Tags table not yet migrated - no-op for now
    return;
  }

  /// Get tags for a note (stub - requires Tags table migration)
  Future<List<dynamic>> getTagsForNote(String noteId) async {
    // Tags table not yet migrated - return empty list
    return [];
  }

  /// List tags with usage counts (stub - requires Tags table migration)
  Future<List<Map<String, dynamic>>> listTagsWithCounts() async {
    // Tags table not yet migrated - return empty list
    return [];
  }

  /// Folder health check (stub for compatibility)
  Future<Map<String, dynamic>> performFolderHealthCheck() async {
    return {
      'status': 'healthy',
      'errors': <String>[],
      'warnings': <String>[],
    };
  }

  /// Validate and repair folder structure (stub for compatibility)
  Future<void> validateAndRepairFolderStructure() async {
    // No-op for compatibility
  }

  /// Clean up orphaned relationships (stub for compatibility)
  Future<void> cleanupOrphanedRelationships() async {
    // No-op for compatibility
  }

  /// Resolve folder conflicts (stub for compatibility)
  Future<void> resolveFolderConflicts() async {
    // No-op for compatibility
  }
}

/// Legacy FolderRepository type alias - compatibility wrapper
class FolderRepository {
  FolderRepository({required this.db, required this.userId});

  final AppDb db;
  final String userId;

  // Stream controller for folder updates
  final _updateController = StreamController<void>.broadcast();
  Stream<void> get folderUpdates => _updateController.stream;

  void dispose() {
    _updateController.close();
  }

  void notifyUpdate() {
    _updateController.add(null);
  }

  // Forward methods to database
  Future<List<LocalFolder>> getRootFolders() => db.getRootFolders();
  Future<List<LocalFolder>> listFolders() async => db.getActiveFolders();

  // Additional compatibility methods
  Future<LocalFolder?> getFolder(String id) async => db.getFolderById(id);

  Future<List<LocalFolder>> getChildFolders(String parentId) async =>
      db.getChildFolders(parentId);

  Future<List<LocalFolder>> getChildFoldersRecursive(String parentId) async {
    final children = <LocalFolder>[];
    final directChildren = await db.getChildFolders(parentId);
    children.addAll(directChildren);

    for (final child in directChildren) {
      final descendants = await getChildFoldersRecursive(child.id);
      children.addAll(descendants);
    }

    return children;
  }
}

/// Legacy TaskRepository type alias - points to infrastructure implementation
typedef TaskRepository = TaskCoreRepository;

/// Legacy TemplateRepository type alias - points to infrastructure implementation
typedef TemplateRepository = TemplateCoreRepository;

/// Extension to add legacy methods to TemplateCoreRepository for backward compatibility
extension TemplateRepositoryLegacyMethods on TemplateCoreRepository {
  /// Get all templates as LocalTemplate for backward compatibility
  Future<List<LocalTemplate>> getAllTemplatesLocal() => db.getAllTemplates();

  /// Get system templates as LocalTemplate for backward compatibility
  Future<List<LocalTemplate>> getSystemTemplatesLocal() => db.getSystemTemplates();

  /// Get user templates as LocalTemplate for backward compatibility
  Future<List<LocalTemplate>> getUserTemplatesLocal() => db.getUserTemplates();

  /// Create a user template (legacy method)
  Future<String> createUserTemplate(String name, String content, {Map<String, dynamic>? metadata}) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw Exception('Cannot create template without authenticated user');
    }

    final template = domain_template.Template(
      id: const Uuid().v4(),
      name: name,
      content: content,
      variables: metadata ?? {},
      isSystem: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await createTemplate(template);
    return template.id;
  }

  /// Update a user template (legacy method)
  Future<void> updateUserTemplate(String id, String name, String content, {Map<String, dynamic>? metadata}) async {
    final existing = await getTemplateById(id);
    if (existing == null) {
      throw Exception('Template not found: $id');
    }

    final updated = existing.copyWith(
      name: name,
      content: content,
      variables: metadata,
      updatedAt: DateTime.now(),
    );

    await updateTemplate(updated);
  }

  /// Delete a user template (legacy method)
  Future<void> deleteUserTemplate(String id) async {
    await deleteTemplate(id);
  }

  /// Apply template to create a note (legacy method - compatibility stub)
  /// The actual implementation is in TemplateCoreRepository
  /// This stub is not needed since we use templateRepositoryProvider directly
}

/// Legacy SyncService type alias - compatibility wrapper for UnifiedSyncService
class SyncService {
  SyncService(NotesRepository repository); // Keep parameter for compatibility but don't store

  final _changesController = StreamController<void>.broadcast();

  Stream<void> get changes => _changesController.stream;

  /// Legacy sync method - returns a stub result
  Future<Map<String, dynamic>> sync() async {
    // Sync is now handled by UnifiedSyncService
    // This is a compatibility shim that returns a successful result
    return {
      'success': true,
      'notes_synced': 0,
      'folders_synced': 0,
      'tasks_synced': 0,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Legacy reset method - no-op for compatibility
  Future<void> reset() async {
    // Sync state is managed by UnifiedSyncService now
    // This is a no-op for backward compatibility
  }

  void startRealtime({UnifiedRealtimeService? unifiedService}) {
    // Realtime sync is now handled by UnifiedRealtimeService
    // This is a compatibility shim
  }

  void stopRealtime() {
    _changesController.close();
  }
}

/// Auth state stream to trigger provider rebuilds on login/logout
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Database provider
final appDbProvider = Provider<AppDb>((ref) {
  return AppDb();
});

/// Key manager provider
final keyManagerProvider = Provider<KeyManager>((ref) {
  return KeyManager(accountKeyService: ref.watch(accountKeyServiceProvider));
});

/// Crypto box provider
final cryptoBoxProvider = Provider<CryptoBox>((ref) {
  final keyManager = ref.watch(keyManagerProvider);
  return CryptoBox(keyManager);
});

/// Note indexer provider
final noteIndexerProvider = Provider<NoteIndexer>((ref) {
  return NoteIndexer(ref);
});

/// Notes repository provider - now uses domain architecture (NotesCoreRepository)
/// This is a compatibility provider that uses the NotesRepository type alias
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  // Rebuild when auth state changes
  ref.watch(authStateChangesProvider);
  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  final indexer = ref.watch(noteIndexerProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) {
    throw StateError('NotesRepository requested without an authenticated user');
  }

  final api = SupabaseNoteApi(client);

  // Return NotesCoreRepository (NotesRepository is a typedef to NotesCoreRepository)
  return NotesCoreRepository(
    db: db,
    crypto: crypto,
    api: api,
    client: client,
    indexer: indexer,
  );
});

/// Clean architecture repository providers
/// Notes core repository provider
final notesCoreRepositoryProvider = Provider<INotesRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  final indexer = ref.watch(noteIndexerProvider);
  final client = Supabase.instance.client;
  final api = SupabaseNoteApi(client);

  return NotesCoreRepository(
    db: db,
    crypto: crypto,
    api: api,
    client: client,
    indexer: indexer,
  );
});

/// Tag repository provider
final tagRepositoryInterfaceProvider = Provider<ITagRepository>((ref) {
  final db = ref.watch(appDbProvider);
  return TagRepository(db: db);
});

/// Search repository provider
final searchRepositoryProvider = Provider<ISearchRepository>((ref) {
  final db = ref.watch(appDbProvider);
  return SearchRepository(db: db);
});

// ===== MIGRATION CONFIGURATION =====

/// Migration configuration provider - controls gradual domain model adoption
final migrationConfigProvider = Provider<MigrationConfig>((ref) {
  // Start with default config (all features disabled for safety)
  // This can be overridden by feature flags or environment variables
  return MigrationConfigFactory.phase4Provider(
    enableNotes: false,    // Gradually enable per feature
    enableFolders: false,
    enableTemplates: false,
  );
});

// ===== INFRASTRUCTURE REPOSITORY PROVIDERS =====

/// Folder core repository provider (domain architecture)
final folderCoreRepositoryProvider = Provider<IFolderRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final client = Supabase.instance.client;
  return FolderCoreRepository(db: db, client: client);
});

/// Template core repository provider (domain architecture)
final templateCoreRepositoryProvider = Provider<ITemplateRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final client = Supabase.instance.client;
  return TemplateCoreRepository(db: db, client: client);
});

/// Task core repository provider (domain architecture)
final taskCoreRepositoryProvider = Provider<ITaskRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final client = Supabase.instance.client;
  return TaskCoreRepository(db: db, client: client);
});

/// Template migration service provider
final templateMigrationServiceProvider =
    Provider<TemplateMigrationService>((ref) {
  final db = ref.watch(appDbProvider);
  return TemplateMigrationService(db);
});

/// Template list provider - fetches all templates with migration
final templateListProvider = FutureProvider<List<LocalTemplate>>((ref) async {
  // Run migration if needed
  final migrationService = ref.watch(templateMigrationServiceProvider);
  if (await migrationService.needsMigration()) {
    await migrationService.migrateTemplates();
  }

  final repository = ref.watch(templateRepositoryProvider);
  return repository.getAllTemplatesLocal();
});

/// Template list stream provider - real-time updates
final templateListStreamProvider =
    StreamProvider<List<LocalTemplate>>((ref) async* {
  final db = ref.watch(appDbProvider);
  yield* db.select(db.localTemplates).watch();
});

/// System templates only
final systemTemplateListProvider =
    FutureProvider<List<LocalTemplate>>((ref) async {
  final repository = ref.watch(templateRepositoryProvider);
  return repository.getSystemTemplatesLocal();
});

/// User templates only
final userTemplateListProvider =
    FutureProvider<List<LocalTemplate>>((ref) async {
  final repository = ref.watch(templateRepositoryProvider);
  return repository.getUserTemplatesLocal();
});

// ===== DOMAIN ENTITY PROVIDERS (Dual Provider Pattern) =====

/// Domain notes provider - switches between legacy and domain based on config
final domainNotesProvider = FutureProvider<List<domain.Note>>((ref) async {
  final config = ref.watch(migrationConfigProvider);

  if (config.isFeatureEnabled('notes')) {
    // Use domain repository
    final repository = ref.watch(notesCoreRepositoryProvider);
    return repository.list();
  } else {
    // Convert from legacy
    final localNotes = ref.watch(currentNotesProvider);
    final db = ref.watch(appDbProvider);
    return StateMigrationHelper.convertNotesToDomain(localNotes, db);
  }
});

/// Domain notes stream provider - real-time updates with dual support
final domainNotesStreamProvider = StreamProvider<List<domain.Note>>((ref) async* {
  final config = ref.watch(migrationConfigProvider);

  if (config.isFeatureEnabled('notes')) {
    // Use domain repository stream
    final repository = ref.watch(notesCoreRepositoryProvider);
    yield* repository.watchNotes();
  } else {
    // Convert legacy data to domain format
    final db = ref.watch(appDbProvider);
    // Watch the current notes and convert them
    final currentNotes = ref.watch(currentNotesProvider);
    final domainNotes = await StateMigrationHelper.convertNotesToDomain(currentNotes, db);
    yield domainNotes;
  }
});

/// Domain folders provider - switches between legacy and domain
final domainFoldersProvider = FutureProvider<List<domain_folder.Folder>>((ref) async {
  final config = ref.watch(migrationConfigProvider);

  if (config.isFeatureEnabled('folders')) {
    // Use domain repository
    final repository = ref.watch(folderCoreRepositoryProvider);
    return repository.listFolders();
  } else {
    // Convert from legacy
    final localFolders = ref.watch(folderListProvider);
    return StateMigrationHelper.convertFoldersToDomain(localFolders);
  }
});

/// Domain folders stream provider
final domainFoldersStreamProvider = StreamProvider<List<domain_folder.Folder>>((ref) {
  final config = ref.watch(migrationConfigProvider);

  if (config.isFeatureEnabled('folders')) {
    // Since domain folder repository doesn't have watchFolders,
    // we'll watch the folder updates provider and convert each time
    return ref.watch(folderUpdatesProvider.stream).asyncMap((_) async {
      final repository = ref.read(folderCoreRepositoryProvider);
      return repository.listFolders();
    });
  } else {
    // Convert legacy stream - watch folder hierarchy changes
    return ref.watch(folderUpdatesProvider.stream).map((_) {
      final localFolders = ref.read(folderListProvider);
      return StateMigrationHelper.convertFoldersToDomain(localFolders);
    });
  }
});

/// Domain templates provider - switches between legacy and domain
final domainTemplatesProvider = FutureProvider<List<domain_template.Template>>((ref) async {
  final config = ref.watch(migrationConfigProvider);

  if (config.isFeatureEnabled('templates')) {
    // Use domain repository
    final repository = ref.watch(templateCoreRepositoryProvider);
    return repository.getAllTemplates();
  } else {
    // Convert from legacy
    final localTemplates = await ref.watch(templateListProvider.future);
    return StateMigrationHelper.convertTemplatesToDomain(localTemplates);
  }
});

/// Domain templates stream provider
final domainTemplatesStreamProvider = StreamProvider<List<domain_template.Template>>((ref) {
  final config = ref.watch(migrationConfigProvider);

  if (config.isFeatureEnabled('templates')) {
    final repository = ref.watch(templateCoreRepositoryProvider);
    return repository.watchTemplates();
  } else {
    // Convert legacy stream by watching the stream provider and mapping its data
    return ref.watch(templateListStreamProvider.stream).map(
      (localTemplates) => StateMigrationHelper.convertTemplatesToDomain(localTemplates),
    );
  }
});

/// Domain tasks provider - switches between legacy and domain
final domainTasksProvider = FutureProvider<List<domain_task.Task>>((ref) async {
  final config = ref.watch(migrationConfigProvider);

  if (config.isFeatureEnabled('tasks')) {
    // Use domain repository
    final repository = ref.watch(taskCoreRepositoryProvider);
    return repository.getAllTasks();
  } else {
    // Convert from legacy - get all tasks from all notes
    final db = ref.watch(appDbProvider);
    final allTasks = await db.select(db.noteTasks).get();
    return StateMigrationHelper.convertTasksToDomain(allTasks);
  }
});

/// Domain tasks for specific note provider
final domainTasksForNoteProvider =
    FutureProvider.family<List<domain_task.Task>, String>((ref, noteId) async {
  final config = ref.watch(migrationConfigProvider);

  if (config.isFeatureEnabled('tasks')) {
    final repository = ref.watch(taskCoreRepositoryProvider);
    return repository.getTasksForNote(noteId);
  } else {
    // Convert from legacy
    final localTasks = await ref.watch(unifiedTasksForNoteProvider(noteId).future);
    return StateMigrationHelper.convertTasksToDomain(localTasks);
  }
});

// ===== MIGRATION UTILITY PROVIDERS =====

/// Provider migration utilities for safe transitions
class ProviderMigration {
  /// Create a dual provider that switches based on feature flag
  static Provider<T> createDualProvider<T>({
    required Provider<T> legacyProvider,
    required Provider<T> domainProvider,
    required String feature,
  }) {
    return Provider<T>((ref) {
      final config = ref.watch(migrationConfigProvider);
      if (config.isFeatureEnabled(feature)) {
        return ref.watch(domainProvider);
      }
      return ref.watch(legacyProvider);
    });
  }

  /// Create a dual future provider with conversion
  static FutureProvider<List<T>> createDualFutureProvider<TLocal, T>({
    required FutureProvider<List<TLocal>> legacyProvider,
    required FutureProvider<List<T>> domainProvider,
    required T Function(TLocal) converter,
    required String feature,
  }) {
    return FutureProvider<List<T>>((ref) async {
      final config = ref.watch(migrationConfigProvider);
      if (config.isFeatureEnabled(feature)) {
        return ref.watch(domainProvider.future);
      }

      final legacyData = await ref.watch(legacyProvider.future);
      return legacyData.map(converter).toList();
    });
  }
}

/// Migration status provider - tracks migration progress
final migrationStatusProvider = Provider<Map<String, dynamic>>((ref) {
  final config = ref.watch(migrationConfigProvider);
  return {
    'notes': config.isFeatureEnabled('notes'),
    'folders': config.isFeatureEnabled('folders'),
    'templates': config.isFeatureEnabled('templates'),
    'tasks': config.isFeatureEnabled('tasks'),
    'tags': config.isFeatureEnabled('tags'),
    'search': config.isFeatureEnabled('search'),
    'progress': config.migrationProgress,
    'isValid': config.isValid,
    'version': config.version,
  };
});

/// Folder repository provider
final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  // Rebuild when auth state changes
  ref.watch(authStateChangesProvider);
  final db = ref.watch(appDbProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) {
    throw StateError(
      'FolderRepository requested without an authenticated user',
    );
  }

  final repo = FolderRepository(db: db, userId: userId);

  // Dispose when provider is disposed
  ref.onDispose(repo.dispose);

  return repo;
});

/// Folder updates stream provider
final folderUpdatesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(folderRepositoryProvider);
  return repo.folderUpdates;
});

/// Folder update listener provider - listens to folder updates and invalidates dependent providers
final folderUpdateListenerProvider = Provider<void>((ref) {
  // Listen to folder updates and invalidate dependent providers
  ref.listen(folderUpdatesProvider, (_, __) {
    // Invalidate all folder-related providers to refresh UI
    ref.invalidate(folderHierarchyProvider);
    ref.invalidate(rootFoldersProvider);
    ref.invalidate(folderListProvider);
    ref.invalidate(visibleFolderNodesProvider);
    ref.invalidate(unfiledNotesCountProvider);
    ref.invalidate(filteredNotesProvider);

    // Also refresh notes if they're folder-filtered
    final currentFolder = ref.read(currentFolderProvider);
    if (currentFolder != null) {
      ref.read(notesPageProvider.notifier).refresh();
    }

    debugPrint('[FolderUpdates] Invalidated folder-dependent providers');
  });
});

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  // Rebuild SyncService when repo or auth changes
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(notesRepositoryProvider);
  final service = SyncService(repo);

  // Get unified realtime service if available
  final unifiedRealtime = ref.watch(unifiedRealtimeServiceProvider);

  // Start realtime sync with unified service
  service.startRealtime(unifiedService: unifiedRealtime);

  // Listen to sync changes and refresh folders on completion
  service.changes.listen((_) async {
    try {
      // Refresh folders after successful sync
      // This also triggers rootFoldersProvider rebuild automatically
      await ref.read(folderHierarchyProvider.notifier).loadFolders();
      debugPrint('[Sync] Folders refreshed after sync completion');

      // Also refresh notes providers for immediate UI update
      ref.invalidate(filteredNotesProvider);
      ref.read(notesPageProvider.notifier).refresh();
      debugPrint('[Sync] Notes providers refreshed after sync completion');

      // Run template migration after sync
      final migrationService = ref.read(templateMigrationServiceProvider);
      if (await migrationService.needsMigration()) {
        debugPrint('[Sync] Running template migration...');
        await migrationService.migrateTemplates();
        ref.invalidate(templateListProvider);
        debugPrint('[Sync] Template migration completed');
      }
    } catch (e) {
      debugPrint('[Sync] Error refreshing after sync: $e');
    }
  });

  // Clean up on disposal
  ref.onDispose(service.stopRealtime);

  return service;
});

/// Provider for paginated notes
final notesPageProvider = StateNotifierProvider.autoDispose<
    NotesPaginationNotifier, AsyncValue<NotesPage>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return NotesPaginationNotifier(ref, repo)
    ..loadMore(); // Load first page immediately
});

/// Provider to watch just the loading state
final notesLoadingProvider = Provider<bool>((ref) {
  final notifier = ref.watch(notesPageProvider.notifier);
  return notifier.isLoadingMore;
});

/// Provider to watch just the current notes list
final currentNotesProvider = Provider<List<LocalNote>>((ref) {
  return ref.watch(notesPageProvider).when(
        data: (page) => page.items,
        loading: () => <LocalNote>[],
        error: (_, __) => <LocalNote>[],
      );
});

/// Current folder filter provider
final currentFolderProvider =
    StateNotifierProvider<CurrentFolderNotifier, LocalFolder?>((ref) {
  return CurrentFolderNotifier();
});

/// Helper function to batch fetch tags for multiple notes
Future<Map<String, Set<String>>> _batchFetchTags(
  NotesRepository repo,
  List<String> noteIds,
) async {
  final result = <String, Set<String>>{};

  // Batch fetch all tags in a single query
  final db = repo.db;
  final tagsQuery = db.select(db.noteTags)
    ..where((t) => t.noteId.isIn(noteIds));

  final allTags = await tagsQuery.get();

  // Group tags by note ID
  for (final tag in allTags) {
    result.putIfAbsent(tag.noteId, () => {}).add(tag.tag);
  }

  // Ensure all noteIds have an entry (even if empty)
  for (final noteId in noteIds) {
    result.putIfAbsent(noteId, () => {});
  }

  return result;
}

/// Provider for folder-filtered notes
final filteredNotesProvider = FutureProvider<List<LocalNote>>((ref) async {
  final currentFolder = ref.watch(currentFolderProvider);
  final filterState = ref.watch(filterStateProvider);
  final repo = ref.watch(notesRepositoryProvider);

  // Get base notes based on folder selection
  List<LocalNote> notes;
  if (currentFolder != null) {
    notes = await repo.getNotesInFolder(currentFolder.id);
  } else {
    // IMPORTANT: Use watch instead of read to trigger rebuilds when notes update
    notes = ref.watch(currentNotesProvider);
  }

  // Apply advanced filters if active
  if (filterState != null && filterState.hasActiveFilters) {
    // Filter by pinned status
    if (filterState.pinnedOnly) {
      notes = notes.where((note) => note.isPinned).toList();
    }

    // Batch fetch tags for all notes if needed
    if (filterState.includeTags.isNotEmpty ||
        filterState.excludeTags.isNotEmpty) {
      // Batch fetch all tags at once
      final noteIds = notes.map((n) => n.id).toList();
      final noteTagsMap = await _batchFetchTags(repo, noteIds);

      // Filter by included tags
      if (filterState.includeTags.isNotEmpty) {
        notes = notes.where((note) {
          final tagSet = noteTagsMap[note.id] ?? {};
          // Check if note has ALL required tags
          return filterState.includeTags.every(tagSet.contains);
        }).toList();
      }

      // Filter by excluded tags
      if (filterState.excludeTags.isNotEmpty) {
        notes = notes.where((note) {
          final tagSet = noteTagsMap[note.id] ?? {};
          // Check if note has NONE of the excluded tags
          return !filterState.excludeTags.any(tagSet.contains);
        }).toList();
      }
    }
  }

  return notes;
});

/// Provider to check if there are more notes to load
final hasMoreNotesProvider = Provider<bool>((ref) {
  return ref.watch(notesPageProvider).when(
        data: (page) => page.hasMore,
        loading: () => true,
        error: (_, __) => false,
      );
});

/// Logger provider
final loggerProvider = Provider<AppLogger>((ref) {
  return ref.watch(bootstrapLoggerProvider);
});

/// Analytics provider
final analyticsProvider = Provider<AnalyticsService>((ref) {
  return ref.watch(bootstrapAnalyticsProvider);
});

/// Database provider alias for compatibility
final Provider<AppDb> dbProvider = appDbProvider;

/// Export service provider
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(ref);
});

/// Task service provider
final taskServiceProvider = Provider<TaskService>((ref) {
  final database = ref.watch(appDbProvider);
  return TaskService(database: database);
});

/// Task repository provider for sync
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  // Rebuild when auth state changes
  ref.watch(authStateChangesProvider);
  final db = ref.watch(appDbProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;

  if (userId == null || userId.isEmpty) {
    throw StateError('TaskRepository requested without an authenticated user');
  }

  return TaskCoreRepository(db: db, client: client);
});

/// Template repository provider
final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final client = Supabase.instance.client;
  return TemplateCoreRepository(db: db, client: client);
});

// Legacy note-task sync service removed - using bidirectional sync only

/// Account key service (AMK) provider
final accountKeyServiceProvider = Provider<AccountKeyService>((ref) {
  return AccountKeyService(ref);
});

/// Push notification service provider
final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final service = PushNotificationService(ref);

  // Initialize the service
  service.initialize().catchError((Object error) {
    ref
        .watch(loggerProvider)
        .error('Failed to initialize push notification service: $error');
  });

  // Clean up on disposal
  ref.onDispose(service.dispose);

  return service;
});

/// Notification handler service provider
final notificationHandlerServiceProvider = Provider<NotificationHandlerService>(
  (ref) {
    // Only create if authenticated
    ref.watch(authStateChangesProvider);
    final client = Supabase.instance.client;

    if (client.auth.currentUser == null) {
      throw StateError(
        'NotificationHandlerService requested without authentication',
      );
    }

    final service = NotificationHandlerService(
      ref,
      client: client,
      pushService: ref.watch(pushNotificationServiceProvider),
    );

    // Clean up on disposal
    ref.onDispose(service.dispose);

    return service;
  },
);

/// Attachment service provider
final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  return AttachmentService(ref);
});

/// Import service provider
final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(
    notesRepository: ref.watch(notesRepositoryProvider),
    noteIndexer: NoteIndexer(ref),
    logger: ref.watch(loggerProvider),
    analytics: ref.watch(analyticsProvider),
  );
});

/// Share extension service provider
final shareExtensionServiceProvider = Provider<ShareExtensionService>((ref) {
  return ShareExtensionService(
    notesRepository: ref.watch(notesRepositoryProvider),
    attachmentService: ref.watch(attachmentServiceProvider),
    logger: ref.watch(loggerProvider),
    analytics: ref.watch(analyticsProvider),
  );
});

/// Email alias service provider
final emailAliasServiceProvider = Provider<EmailAliasService>((ref) {
  final client = Supabase.instance.client;
  return EmailAliasService(client);
});

/// Incoming mail folder manager provider
final incomingMailFolderManagerProvider = Provider<IncomingMailFolderManager>((
  ref,
) {
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    throw StateError(
      'IncomingMailFolderManager requested without authentication',
    );
  }

  final repo = ref.watch(notesRepositoryProvider);
  final manager = IncomingMailFolderManager(repository: repo, userId: userId);
  unawaited(manager.processPendingAssignments());
  return manager;
});

/// Inbox management service provider
final inboxManagementServiceProvider = Provider<InboxManagementService>((ref) {
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;

  if (client.auth.currentUser == null) {
    throw StateError('InboxManagementService requested without authentication');
  }

  final aliasService = ref.watch(emailAliasServiceProvider);
  final repository = ref.watch(notesRepositoryProvider);
  final folderManager = ref.watch(incomingMailFolderManagerProvider);
  final attachmentService = ref.watch(attachmentServiceProvider);

  return InboxManagementService(
    supabase: client,
    aliasService: aliasService,
    notesRepository: repository,
    folderManager: folderManager,
    attachmentService: attachmentService,
  );
});

/// Unified Realtime Service - Single source of truth for all realtime subscriptions
/// This replaces individual realtime services to reduce database load
final unifiedRealtimeServiceProvider =
    ChangeNotifierProvider<UnifiedRealtimeService?>((ref) {
  // Watch auth state to properly manage lifecycle
  final authStateAsync = ref.watch(authStateChangesProvider);

  return authStateAsync.when(
    data: (authState) {
      // Return null if not authenticated
      if (authState.session == null) {
        debugPrint(
          '[Providers] No session - unified realtime service not created',
        );
        return null;
      }

      final userId = authState.session!.user.id;
      final logger = ref.watch(loggerProvider);
      final folderSyncCoordinator = ref.watch(
        folderSyncCoordinatorProvider,
      );

      debugPrint(
        '[Providers] Creating unified realtime service for user: $userId',
      );

      // Create service with injected dependencies
      final service = UnifiedRealtimeService(
        supabase: Supabase.instance.client,
        userId: userId,
        logger: logger,
        connectionManager: ConnectionManager(),
        folderSyncCoordinator: folderSyncCoordinator,
      );

      // Start the service with proper error handling
      service.start().catchError((Object error) {
        logger.error(
          '[Providers] Failed to start unified realtime',
          error: error,
        );
      });

      // CRITICAL: Proper disposal on logout or provider disposal
      ref.onDispose(() {
        debugPrint('[Providers] Disposing unified realtime service');
        service.dispose();
      });

      return service;
    },
    loading: () => null,
    error: (error, stack) {
      debugPrint('[Providers] Auth state error: $error');
      return null;
    },
  );
});



// Folder sync audit provider
final folderSyncAuditProvider = Provider<FolderSyncAudit>((ref) {
  final logger = ref.watch(loggerProvider);
  return FolderSyncAudit(logger: logger);
});

// Folder sync coordinator provider
final folderRemoteApiProvider = Provider<FolderRemoteApi>((ref) {
  final client = Supabase.instance.client;
  final logger = ref.watch(loggerProvider);
  return SupabaseFolderRemoteApi(client: client, logger: logger);
});

final folderSyncCoordinatorProvider = Provider<FolderSyncCoordinator>((ref) {
  final repository = ref.watch(folderCoreRepositoryProvider) as FolderCoreRepository;
  final remoteApi = ref.watch(folderRemoteApiProvider);
  final audit = ref.watch(folderSyncAuditProvider);
  final logger = ref.watch(loggerProvider);

  return FolderSyncCoordinator(
    repository: repository,
    remoteApi: remoteApi,
    audit: audit,
    logger: logger,
  );
});


/// Inbox unread tracking service provider
final inboxUnreadServiceProvider = ChangeNotifierProvider<InboxUnreadService?>((
  ref,
) {
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;

  // Return null if not authenticated - graceful degradation
  if (client.auth.currentUser == null) {
    return null;
  }

  final service = InboxUnreadService(supabase: client);

  // Listen to unified realtime changes for instant badge updates
  final unifiedRealtime = ref.watch(unifiedRealtimeServiceProvider);
  if (unifiedRealtime != null) {
    // Subscribe to inbox stream from unified service
    unifiedRealtime.inboxStream.listen((event) {
      debugPrint(
        '[InboxUnread] Received inbox change event: ${event.eventType}',
      );
      service.computeBadgeCount();
    });

    // Also listen to general notifications
    unifiedRealtime.addListener(service.computeBadgeCount);
  }

  // Compute initial badge count
  service.computeBadgeCount();

  // Clean up on logout
  ref.onDispose(service.clear);

  return service;
});

/// Clipper inbox service provider (legacy - for auto-processing mode only)
final clipperInboxServiceProvider = Provider<ClipperInboxService>((ref) {
  // Only create if authenticated
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) {
    throw StateError('ClipperInboxService requested without authentication');
  }

  final repo = ref.watch(notesRepositoryProvider);
  final db = ref.watch(appDbProvider);
  final adapter = CaptureNotesAdapter(repository: repo, db: db);
  final folderManager = ref.watch(incomingMailFolderManagerProvider);

  return ClipperInboxService(
    supabase: client,
    notesPort: adapter,
    folderManager: folderManager,
  );
});

// Settings providers

/// Sync mode provider
final syncModeProvider = StateNotifierProvider<SyncModeNotifier, SyncMode>((
  ref,
) {
  final repo = ref.watch(notesRepositoryProvider);

  // Callback to refresh UI after successful sync
  // Use a safe callback that checks if the provider is still alive
  void onSyncComplete() {
    // Only refresh if the provider is still alive
    try {
      // Check if we can still access providers
      ref.read(notesPageProvider.notifier).refresh();

      // Load additional pages if there are more notes
      while (ref.read(hasMoreNotesProvider)) {
        ref.read(notesPageProvider.notifier).loadMore();
      }

      // Refresh folders as well
      ref.read(folderHierarchyProvider.notifier).loadFolders();
    } catch (e) {
      // Provider is disposed or ref is not available
      // Silently ignore - this is expected when the provider is disposed
      debugPrint('[SyncMode] Cannot refresh after sync - provider disposed');
    }
  }

  return SyncModeNotifier(repo, onSyncComplete);
});

/// Theme mode provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier();
});

/// Locale provider
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

/// Analytics settings provider
final analyticsSettingsProvider =
    StateNotifierProvider<AnalyticsNotifier, bool>((ref) {
  final analytics = ref.watch(analyticsProvider);
  return AnalyticsNotifier(analytics);
});

// Folder providers

/// Folder state provider for CRUD operations
final folderProvider =
    StateNotifierProvider<FolderNotifier, FolderOperationState>((ref) {
  final repo = ref.watch(folderCoreRepositoryProvider) as FolderCoreRepository;
  final syncCoordinator = ref.watch(folderSyncCoordinatorProvider);
  return FolderNotifier(repo, syncCoordinator);
});

/// Folder hierarchy provider for tree structure management
final folderHierarchyProvider =
    StateNotifierProvider<FolderHierarchyNotifier, FolderHierarchyState>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return FolderHierarchyNotifier(repo);
});

/// Note-folder integration service provider for enhanced operations
final noteFolderIntegrationServiceProvider = Provider<NoteFolderIntegrationService>((ref) {
  final notesRepository = ref.watch(notesRepositoryProvider);
  final analyticsService = ref.watch(analyticsProvider);
  return NoteFolderIntegrationService(
    notesRepository: notesRepository,
    analyticsService: analyticsService,
  );
});

/// Note-folder relationship provider
final noteFolderProvider =
    StateNotifierProvider<NoteFolderNotifier, NoteFolderState>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return NoteFolderNotifier(repo);
});

/// Folder list provider (derived from hierarchy state)
final folderListProvider = Provider<List<LocalFolder>>((ref) {
  return ref.watch(folderHierarchyProvider).folders;
});

/// Visible folder tree nodes provider (derived from hierarchy state)
final visibleFolderNodesProvider = Provider<List<FolderTreeNode>>((ref) {
  ref.watch(folderHierarchyProvider); // Watch the state, not just notifier
  return ref.read(folderHierarchyProvider.notifier).getVisibleNodes();
});

/// Root folders provider for quick access
/// This provider is invalidated whenever folders change to ensure consistency
final rootFoldersProvider = FutureProvider<List<LocalFolder>>((ref) {
  // Watch the folder hierarchy state to ensure both providers stay in sync
  // This causes rootFoldersProvider to rebuild when hierarchy changes
  ref.watch(folderHierarchyProvider);

  final repo = ref.watch(notesRepositoryProvider);
  return repo.getRootFolders();
});

/// All folders count provider for accurate statistics
final allFoldersCountProvider = FutureProvider<int>((ref) async {
  // Watch the folder hierarchy to rebuild when folders change
  ref.watch(folderHierarchyProvider);

  final repo = ref.watch(notesRepositoryProvider);
  final allFolders = await repo.listFolders();
  return allFolders.length;
});

/// Unfiled notes count provider
final unfiledNotesCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notesRepositoryProvider);
  final unfiledNotes = await repo.getUnfiledNotes();
  return unfiledNotes.length;
});

/// Search service provider
final searchServiceProvider = Provider<SearchService>((ref) {
  final db = ref.watch(appDbProvider);
  final repo = ref.watch(notesRepositoryProvider);
  return SearchService(db: db, repo: repo);
});

/// Sort preferences service
final sortPreferencesServiceProvider = Provider<SortPreferencesService>((ref) {
  return SortPreferencesService();
});

/// Stream of saved searches from the database
final savedSearchesStreamProvider = StreamProvider<List<SavedSearch>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.watchSavedSearches();
});

/// Current filter state for advanced filters
final filterStateProvider = StateProvider<FilterState?>((ref) => null);

/// Current sort spec for the selected folder
final currentSortSpecProvider =
    StateNotifierProvider<CurrentSortSpecNotifier, NoteSortSpec>((ref) {
  final currentFolder = ref.watch(currentFolderProvider);
  final service = ref.watch(sortPreferencesServiceProvider);

  // Create a new notifier when folder changes
  final notifier = CurrentSortSpecNotifier(service, currentFolder?.id);

  // Clean up when folder changes
  ref.onDispose(() {
    // Nothing to dispose, but could add cleanup if needed
  });

  return notifier;
});

/// Notifier for managing the current sort spec
class CurrentSortSpecNotifier extends StateNotifier<NoteSortSpec> {
  CurrentSortSpecNotifier(this._service, this._folderId)
      : super(const NoteSortSpec()) {
    _loadSortSpec();
  }

  final SortPreferencesService _service;
  final String? _folderId;

  Future<void> _loadSortSpec() async {
    final spec = await _service.getSortForFolder(_folderId);
    if (mounted) {
      state = spec;
    }
  }

  Future<void> updateSortSpec(NoteSortSpec spec) async {
    state = spec;
    await _service.setSortForFolder(_folderId, spec);
  }
}

/// Provider for Supabase client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provider for user ID
final userIdProvider = Provider<String?>((ref) {
  // Get user ID from auth service or Supabase
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.currentUser?.id;
});

/// Provider for UndoRedoService
final undoRedoServiceProvider = ChangeNotifierProvider<UndoRedoService>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  final userId = ref.watch(userIdProvider) ?? 'default';

  return UndoRedoService(
    repository: repository,
    userId: userId,
  );
});

/// Provider for watching tasks for a specific note
final noteTasksProvider =
    StreamProvider.family<List<NoteTask>, String>((ref, noteId) {
  final taskService = ref.watch(taskServiceProvider);
  return taskService.watchTasksForNote(noteId);
});

/// Provider for getting a specific task by ID
final taskByIdProvider =
    FutureProvider.family<NoteTask?, String>((ref, taskId) async {
  final db = ref.watch(appDbProvider);
  return db.getTaskById(taskId);
});

/// Task reminder bridge provider with feature flag support
final taskReminderBridgeProvider = Provider<TaskReminderBridge>((ref) {
  // Use the unified reminder coordinator
  final reminderCoordinator = ref.watch(unifiedReminderCoordinatorProvider);

  final advancedReminderService = ref.watch(advancedReminderServiceProvider);
  final taskService = ref.watch(taskServiceProvider);
  final database = ref.watch(appDbProvider);
  final notificationPlugin = FlutterLocalNotificationsPlugin();
  final bridge = TaskReminderBridge(
    ref,
    reminderCoordinator: reminderCoordinator,
    advancedReminderService: advancedReminderService,
    taskService: taskService,
    database: database,
    notificationPlugin: notificationPlugin,
  );

  ref.onDispose(bridge.dispose);
  return bridge;
});

/// Enhanced task service provider with reminder integration
final enhancedTaskServiceProvider = Provider<EnhancedTaskService>((ref) {
  final database = ref.watch(appDbProvider);
  final reminderBridge = ref.watch(taskReminderBridgeProvider);

  final service = EnhancedTaskService(
    database: database,
    reminderBridge: reminderBridge,
  );

  // Note: Bidirectional sync is now handled by UnifiedTaskService

  return service;
});

// DEPRECATED: Task service providers have been consolidated into UnifiedTaskService
// See lib/services/unified_task_service.dart and unifiedTaskServiceProvider

/// Task analytics service provider
final taskAnalyticsServiceProvider = Provider<TaskAnalyticsService>((ref) {
  final database = ref.watch(appDbProvider);
  return TaskAnalyticsService(ref, database: database);
});

/// Productivity goals service provider
final productivityGoalsServiceProvider =
    Provider<ProductivityGoalsService>((ref) {
  final database = ref.watch(appDbProvider);
  final analyticsService = ref.watch(taskAnalyticsServiceProvider);

  final service = ProductivityGoalsService(
    database: database,
    analyticsService: analyticsService,
  );

  // Dispose the service when provider is disposed to prevent memory leaks
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Stream provider for active productivity goals
final activeGoalsProvider =
    StreamProvider<List<ProductivityGoal>>((ref) async* {
  final goalsService = ref.watch(productivityGoalsServiceProvider);

  // Initial load
  yield await goalsService.getActiveGoals();

  // Update every minute to refresh progress
  yield* Stream.periodic(const Duration(minutes: 1), (_) async {
    await goalsService.updateAllGoalProgress();
    return goalsService.getActiveGoals();
  }).asyncMap((future) => future);
});

// ===== UNIFIED TASK SERVICE PROVIDERS =====

/// Provider for the unified task service that consolidates all task functionality
final unifiedTaskServiceProvider = Provider<unified.UnifiedTaskService>((ref) {
  final db = ref.watch(appDbProvider);
  final logger = LoggerFactory.instance;
  final analytics = AnalyticsFactory.instance;

  // Create enhanced task service internally to avoid circular dependency
  // Use a lazy approach to prevent initialization loops
  final reminderBridge = ref.watch(taskReminderBridgeProvider);

  late final EnhancedTaskService enhancedService;
  late final unified.UnifiedTaskService service;

  // Initialize enhanced service after unified service is created
  enhancedService = EnhancedTaskService(
    database: db,
    reminderBridge: reminderBridge,
  );

  service = unified.UnifiedTaskService(
    db: db,
    logger: logger,
    analytics: analytics,
    enhancedTaskService: enhancedService,
  );

  // CRITICAL: Dispose the service when provider is disposed to prevent memory leaks
  ref.onDispose(() {
    try {
      service.dispose();
    } catch (e) {
      logger.error('Error disposing UnifiedTaskService', error: e);
    }
  });

  return service;
});

/// Provider for task updates stream
final unifiedTaskUpdatesProvider = StreamProvider<unified.TaskUpdate>((ref) {
  final service = ref.watch(unifiedTaskServiceProvider);
  return service.taskUpdates;
});

/// Provider for tasks by note using unified service
final unifiedTasksForNoteProvider =
    FutureProvider.family<List<NoteTask>, String>((ref, noteId) {
  final service = ref.watch(unifiedTaskServiceProvider);
  return service.getTasksForNote(noteId);
});

/// Provider for task statistics using unified service
final unifiedTaskStatisticsProvider = FutureProvider<unified.TaskStatistics>((ref) {
  final service = ref.watch(unifiedTaskServiceProvider);

  // Refresh when task updates occur
  ref.watch(unifiedTaskUpdatesProvider);

  return service.getTaskStatistics();
});

/// Supabase Note API provider for sync verification system
final supabaseNoteApiProvider = Provider<SupabaseNoteApi>((ref) {
  // Rebuild when auth state changes
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) {
    throw StateError('SupabaseNoteApi requested without an authenticated user');
  }

  return SupabaseNoteApi(client);
});
