# Service Integration Guide: P1-P3 Security Implementation

**Version**: 1.0
**Last Updated**: 2025-10-24
**Status**: Implementation Ready

---

## Table of Contents

1. [Repository Layer Changes](#repository-layer-changes)
2. [Service Layer Changes](#service-layer-changes)
3. [Provider Layer Changes](#provider-layer-changes)
4. [API Contract Updates](#api-contract-updates)
5. [Migration Strategy](#migration-strategy)
6. [Testing Requirements](#testing-requirements)

---

## Repository Layer Changes

### 1. NotesCoreRepository

**File**: `lib/infrastructure/repositories/notes_core_repository.dart`

#### P1 Changes: Add userId Filtering

```dart
// ===== READ OPERATIONS =====

@override
Future<domain.Note?> getNoteById(String id) async {
  try {
    final currentUserId = _getCurrentUserId(); // NEW!
    _validateUserId(currentUserId); // NEW!

    final localNote = await (db.select(db.localNotes)
      ..where((note) => note.id.equals(id))
      ..where((note) => note.userId.equals(currentUserId))) // NEW!
      .getSingleOrNull();

    if (localNote == null) {
      return null;
    }

    return await _hydrateDomainNote(localNote);
  } catch (error, stackTrace) {
    _logger.error('Failed to get note by id', error: error, stackTrace: stackTrace);
    _captureRepositoryException(...);
    return null;
  }
}

Future<List<domain.Note>> localNotes() async {
  try {
    final currentUserId = _getCurrentUserId(); // NEW!
    _validateUserId(currentUserId); // NEW!

    final localNotes = await (db.select(db.localNotes)
      ..where((note) => note.deleted.equals(false))
      ..where((note) => note.userId.equals(currentUserId))) // NEW!
      ..orderBy([...])
      .get();

    return await _hydrateDomainNotes(localNotes);
  } catch (error, stackTrace) {
    // Error handling...
  }
}

@override
Future<List<domain.Note>> getPinnedNotes() async {
  try {
    final currentUserId = _getCurrentUserId(); // NEW!
    _validateUserId(currentUserId); // NEW!

    final localNotes = await (db.select(db.localNotes)
      ..where((note) => note.deleted.equals(false))
      ..where((note) => note.isPinned.equals(true))
      ..where((note) => note.userId.equals(currentUserId))) // NEW!
      .get();

    return await _hydrateDomainNotes(localNotes);
  } catch (error, stackTrace) {
    // Error handling...
  }
}

@override
Future<List<domain.Note>> listAfter(DateTime? cursor, {int limit = 20}) async {
  try {
    final currentUserId = _getCurrentUserId(); // NEW!
    _validateUserId(currentUserId); // NEW!

    final query = db.select(db.localNotes)
      ..where((note) => note.deleted.equals(false))
      ..where((note) => note.userId.equals(currentUserId)); // NEW!

    if (cursor != null) {
      query.where((note) => note.updatedAt.isSmallerThanValue(cursor));
    }

    final localNotes = await (query
      ..orderBy([...])
      ..limit(limit))
      .get();

    return await _hydrateDomainNotes(localNotes);
  } catch (error, stackTrace) {
    // Error handling...
  }
}

// ===== WRITE OPERATIONS =====

@override
Future<void> updateLocalNote(String id, {...}) async {
  final traceId = TraceContext.currentNoteSaveTrace;

  try {
    final currentUserId = _getCurrentUserId(); // NEW!
    _validateUserId(currentUserId); // NEW!

    final existing = await (db.select(db.localNotes)
      ..where((note) => note.id.equals(id))
      ..where((note) => note.userId.equals(currentUserId))) // NEW!
      .getSingleOrNull();

    if (existing == null) {
      throw UnauthorizedException('Note not found or access denied'); // NEW!
    }

    // Continue with update logic...
  } catch (error, stackTrace) {
    // Error handling...
  }
}

// ===== SYNC OPERATIONS =====

Future<bool> _pushNoteOp(PendingOp op) async {
  final noteId = op.entityId;
  try {
    final currentUserId = _getCurrentUserId(); // NEW!
    _validateUserId(currentUserId); // NEW!

    final localNote = await (db.select(db.localNotes)
      ..where((n) => n.id.equals(noteId))
      ..where((n) => n.userId.equals(currentUserId))) // NEW!
      .getSingleOrNull();

    if (localNote == null && op.kind != 'delete' && op.kind != 'delete_note') {
      _logger.warning('Pending note operation references missing or unauthorized note');
      return true; // Skip this operation
    }

    // Continue with sync logic...
  } catch (error, stackTrace) {
    // Error handling...
  }
}

// ===== HELPER METHODS (ADD THESE) =====

/// Get current authenticated userId
String? _getCurrentUserId() {
  return _supabase.auth.currentUser?.id;
}

/// Validate userId is present
void _validateUserId(String? userId) {
  if (userId == null || userId.isEmpty) {
    throw UnauthorizedException('No authenticated user');
  }
}
```

#### P2 Changes: Update Create Operations

```dart
@override
Future<domain.Note?> createOrUpdate({...}) async {
  final noteId = id ?? _uuid.v4();
  final traceId = TraceContext.currentNoteSaveTrace;

  try {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      // P2: Stricter enforcement (non-nullable userId required)
      throw UnauthorizedException('Cannot create note without authenticated user');
    }

    // P2: userId is now guaranteed non-null
    await db.upsertNote(
      LocalNote(
        id: noteId,
        userId: userId, // P2: Non-nullable field
        // ... other fields
      ),
    );

    // Continue...
  } catch (error, stackTrace) {
    // Error handling...
  }
}
```

#### Impact Summary

- **Breaking Changes**: None (only restricts unauthorized access)
- **New Exceptions**: `UnauthorizedException`, `UserIdMismatchException`
- **Performance**: Minimal (adds one WHERE clause per query)
- **Testing**: Update tests to authenticate before repository calls

---

### 2. TaskCoreRepository

**File**: `lib/infrastructure/repositories/task_core_repository.dart`

#### P1 Changes: Add userId Filtering + NoteTasks userId Column

**Step 1: Database Migration**

```dart
// NEW MIGRATION: add userId to note_tasks table
class Migration17_AddUserIdToNoteTasks extends Migration {
  @override
  Future<void> run(Migrator m, Database db) async {
    // 1. Add userId column (nullable initially)
    await m.addColumn(
      db.noteTasks,
      db.noteTasks.userId,
    );

    // 2. Backfill userId from parent note
    await m.database.customStatement('''
      UPDATE note_tasks
      SET user_id = (
        SELECT user_id
        FROM local_notes
        WHERE local_notes.id = note_tasks.note_id
      )
      WHERE user_id IS NULL;
    ''');

    // 3. Delete orphaned tasks (parent note deleted)
    await m.database.customStatement('''
      DELETE FROM note_tasks
      WHERE user_id IS NULL;
    ''');

    // Note: P2 will make userId non-nullable
  }
}
```

**Step 2: Update Schema**

```dart
// lib/data/local/app_db.dart
class NoteTasks extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get userId => text().nullable()(); // P1: Add this
  // ... other columns

  @override
  Set<Column> get primaryKey => {id};
}
```

**Step 3: Update Repository Methods**

```dart
@override
Future<List<domain.Task>> getTasksForNote(String noteId) async {
  try {
    final currentUserId = _getCurrentUserId(); // NEW!
    _validateUserId(currentUserId); // NEW!

    final localTasks = await (db.select(db.noteTasks)
      ..where((t) => t.noteId.equals(noteId))
      ..where((t) => t.userId.equals(currentUserId))) // NEW!
      .get();

    return await _decryptTasks(localTasks);
  } catch (e, stack) {
    _logger.error('Failed to get tasks for note', error: e, stackTrace: stack);
    _captureRepositoryException(...);
    return const <domain.Task>[];
  }
}

@override
Future<List<domain.Task>> getAllTasks() async {
  try {
    final currentUserId = _getCurrentUserId(); // NEW!
    _validateUserId(currentUserId); // NEW!

    final localTasks = await (db.select(db.noteTasks)
      ..where((t) => t.deleted.equals(false))
      ..where((t) => t.userId.equals(currentUserId))) // NEW!
      .get();

    return await _decryptTasks(localTasks);
  } catch (e, stack) {
    _logger.error('Failed to get all tasks', error: e, stackTrace: stack);
    return const <domain.Task>[];
  }
}

@override
Future<domain.Task?> getTaskById(String id) async {
  try {
    final currentUserId = _getCurrentUserId(); // NEW!
    _validateUserId(currentUserId); // NEW!

    final localTask = await (db.select(db.noteTasks)
      ..where((t) => t.id.equals(id))
      ..where((t) => t.userId.equals(currentUserId))) // NEW!
      .getSingleOrNull();

    if (localTask == null) return null;

    return await _decryptTask(localTask);
  } catch (e, stack) {
    _logger.error('Failed to get task by id', error: e, stackTrace: stack);
    return null;
  }
}

@override
Future<domain.Task> createTask(domain.Task task) async {
  try {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw UnauthorizedException('Cannot create task without authenticated user');
    }

    // Create task companion with userId
    final taskCompanion = NoteTasksCompanion(
      id: Value(taskToCreate.id),
      noteId: Value(taskToCreate.noteId),
      userId: Value(userId), // NEW!
      // ... other fields
    );

    await db.createTask(taskCompanion);
    // Continue...
  } catch (e, stack) {
    _logger.error('Failed to create task', error: e, stackTrace: stack);
    rethrow;
  }
}

// Add helper methods (same as NotesCoreRepository)
String? _getCurrentUserId() { /* ... */ }
void _validateUserId(String? userId) { /* ... */ }
```

#### P2 Changes: Make NoteTasks.userId Non-Nullable

```dart
// Migration 18: Make userId non-nullable
class Migration18_NonNullableTaskUserId extends Migration {
  @override
  Future<void> run(Migrator m, Database db) async {
    // Verify no null userIds remain
    final nullCount = await m.database.customSelect(
      'SELECT COUNT(*) as count FROM note_tasks WHERE user_id IS NULL',
    ).getSingle();

    if (nullCount['count'] as int > 0) {
      throw MigrationException(
        'Cannot migrate: ${nullCount['count']} tasks have null userId',
      );
    }

    // Make userId non-nullable
    await m.alterTable(TableMigration(
      noteTasks,
      columnTransformer: {
        noteTasks.userId: noteTasks.userId.withConstraint(NotNullConstraint()),
      },
    ));
  }
}

// Update schema
class NoteTasks extends Table {
  TextColumn get userId => text()(); // P2: Remove .nullable()
  // ... other columns
}
```

#### Impact Summary

- **Breaking Changes**: Tasks without userId will be inaccessible (security fix, not regression)
- **Database Changes**: Adds `userId` column to `note_tasks` table
- **Performance**: Minimal (indexed userId column)
- **Data Migration**: Backfills userId from parent note

---

### 3. FolderCoreRepository

**File**: `lib/infrastructure/repositories/folder_core_repository.dart`

**P1 Changes**: Same pattern as NotesCoreRepository

```dart
@override
Future<LocalFolder?> getFolderById(String id) async {
  final currentUserId = _getCurrentUserId();
  _validateUserId(currentUserId);

  return await (db.select(db.localFolders)
    ..where((f) => f.id.equals(id))
    ..where((f) => f.userId.equals(currentUserId)))
    .getSingleOrNull();
}

@override
Future<List<LocalFolder>> getAllFolders() async {
  final currentUserId = _getCurrentUserId();
  _validateUserId(currentUserId);

  return await (db.select(db.localFolders)
    ..where((f) => f.deleted.equals(false))
    ..where((f) => f.userId.equals(currentUserId)))
    .get();
}

// Similar changes for:
// - getRootFolders()
// - getSubfolders(parentId)
// - createFolder()
// - updateFolder()
```

---

### 4. TemplateRepository

**File**: `lib/infrastructure/repositories/template_core_repository.dart`

**P1 Changes**: Add userId filtering with special handling for system templates

```dart
@override
Future<List<LocalTemplate>> getAllTemplates() async {
  final currentUserId = _getCurrentUserId();
  _validateUserId(currentUserId);

  return await (db.select(db.localTemplates)
    // System templates (isSystem = true) are visible to all users
    // User templates (isSystem = false) filtered by userId
    ..where((t) =>
      t.isSystem.equals(true) |
      t.userId.equals(currentUserId)))
    .get();
}

@override
Future<List<LocalTemplate>> getUserTemplates() async {
  final currentUserId = _getCurrentUserId();
  _validateUserId(currentUserId);

  return await (db.select(db.localTemplates)
    ..where((t) => t.isSystem.equals(false))
    ..where((t) => t.userId.equals(currentUserId)))
    .get();
}

@override
Future<List<LocalTemplate>> getSystemTemplates() async {
  // System templates don't need userId filtering
  return await (db.select(db.localTemplates)
    ..where((t) => t.isSystem.equals(true)))
    .get();
}
```

---

## Service Layer Changes

### 1. UnifiedSyncService

**File**: `lib/services/unified_sync_service.dart`

#### P1 Changes: Add Pending Ops Validation

```dart
class UnifiedSyncService {
  // ...

  Future<SyncResult> syncAll() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null || currentUserId.isEmpty) {
        return SyncResult.failure('No authenticated user');
      }

      // NEW: Validate pending ops before pushing
      await _validateAndCleanPendingOps(currentUserId);

      // Push local changes to remote
      await _notesRepository.pushAllPending();
      await _foldersRepository.pushAllPending();
      await _tasksRepository.pushAllPending();

      // Pull remote changes to local
      final lastSync = await _getLastSyncTime();
      await _notesRepository.pullSince(lastSync);
      await _foldersRepository.pullSince(lastSync);
      await _tasksRepository.pullSince(lastSync);

      return SyncResult.success();
    } catch (e, stack) {
      _logger.error('Sync failed', error: e, stackTrace: stack);
      return SyncResult.failure(e.toString());
    }
  }

  /// NEW: Validate pending ops belong to current user
  /// Delete invalid ops to prevent syncing other users' data
  Future<void> _validateAndCleanPendingOps(String currentUserId) async {
    final ops = await _db.getPendingOps();
    final invalidOps = <int>[];

    for (final op in ops) {
      String? entityUserId;

      // Check entity belongs to current user
      if (_isNoteOp(op.kind)) {
        final note = await _db.getNoteById(op.entityId);
        entityUserId = note?.userId;
      } else if (_isFolderOp(op.kind)) {
        final folder = await _db.getFolderById(op.entityId);
        entityUserId = folder?.userId;
      } else if (_isTaskOp(op.kind)) {
        final task = await _db.getTaskById(op.entityId);
        entityUserId = task?.userId;
      }

      // If entity doesn't exist or belongs to different user, mark for deletion
      if (entityUserId == null || entityUserId != currentUserId) {
        _logger.warning('Invalid pending op detected', data: {
          'opId': op.id,
          'kind': op.kind,
          'entityId': op.entityId,
          'expectedUserId': currentUserId,
          'actualUserId': entityUserId,
        });
        invalidOps.add(op.id);
      }
    }

    // Delete invalid ops
    if (invalidOps.isNotEmpty) {
      await _db.deletePendingByIds(invalidOps);
      _logger.info('Cleaned up ${invalidOps.length} invalid pending ops');
    }
  }

  bool _isNoteOp(String kind) =>
    kind == 'upsert_note' || kind == 'delete_note' || kind == 'delete';
  bool _isFolderOp(String kind) =>
    kind == 'upsert_folder' || kind == 'delete_folder';
  bool _isTaskOp(String kind) =>
    kind == 'upsert_task' || kind == 'delete_task';
}
```

#### P3 Changes: Add Security Middleware

```dart
class UnifiedSyncService {
  final SecurityMiddleware _security; // NEW!

  UnifiedSyncService({
    required SecurityMiddleware security,
    // ... other dependencies
  }) : _security = security;

  Future<SyncResult> syncAll() async {
    // Wrap entire sync operation in security middleware
    return _security.execute(
      operation: 'syncAll',
      repositoryCall: () => _performSync(),
    );
  }

  Future<SyncResult> _performSync() async {
    // Original sync logic...
  }
}
```

---

### 2. UnifiedRealtimeService

**File**: `lib/services/unified_realtime_service.dart`

#### P1 Status: ✅ Already Secure

The UnifiedRealtimeService already filters by userId at subscription level:

```dart
Future<RealtimeChannel> _createChannel() async {
  return _supabase
    .channel('unified_changes_$userId')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notes',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId, // ✅ Already filtering by userId!
      ),
      callback: (payload) => _handleChange(DatabaseTableType.notes, payload),
    )
    // Same for folders, tasks...
}
```

**No P1 Changes Required**.

#### P1 Enhancement: Add userId Validation in Event Handler

```dart
void _handleChange(DatabaseTableType table, PostgresChangePayload payload) {
  if (_disposed) return;

  try {
    // NEW: Validate event belongs to current user (defense-in-depth)
    final eventUserId = payload.newRecord['user_id'];
    if (eventUserId != userId) {
      _logger.error('CRITICAL: Received event for different user!', data: {
        'expected': userId,
        'received': eventUserId,
        'table': table.name,
      });

      await Sentry.captureException(
        UserIdMismatchException(
          expectedUserId: userId,
          actualUserId: eventUserId,
          entityId: payload.newRecord['id'],
        ),
      );

      return; // Skip this event
    }

    // Continue with normal event processing...
  } catch (error, stack) {
    _logger.error('Error handling change event', error: error, stackTrace: stack);
  }
}
```

---

### 3. EnhancedTaskService

**File**: `lib/services/enhanced_task_service.dart`

#### P1 Changes: Ensure Repository-Only Access

**Current Issue**: Service directly accesses AppDb in some methods

```dart
// BEFORE (P0):
Future<void> completeTask(String taskId, {String? completedBy}) async {
  await _db.completeTask(taskId, completedBy: completedBy); // ❌ Direct DB access
}

// AFTER (P1):
Future<void> completeTask(String taskId, {String? completedBy}) async {
  // ✅ Go through repository (has userId filtering)
  final task = await _taskRepository.getTaskById(taskId);
  if (task == null) {
    throw NotFoundException('Task not found');
  }

  await _taskRepository.completeTask(taskId);

  // Reminder handling...
}
```

**Apply Same Pattern To**:
- `toggleTaskStatus()`
- `deleteTask()`
- `updateTask()`
- `getSubtasks()`

#### P2 Changes: Require userId in Constructor

```dart
// P2: Inject userId at service construction
class EnhancedTaskService {
  final String userId; // NEW!
  final AppDb _db;
  final ITaskRepository _taskRepository;
  final TaskReminderBridge _reminderBridge;

  EnhancedTaskService({
    required this.userId, // NEW!
    required AppDb database,
    required ITaskRepository taskRepository,
    required TaskReminderBridge reminderBridge,
  }) : _db = database,
       _taskRepository = taskRepository,
       _reminderBridge = reminderBridge;

  // All operations now scoped to userId
  Future<String> createTask({...}) async {
    // Validate userId matches authenticated user
    final currentUserId = _taskRepository.client.auth.currentUser?.id;
    if (currentUserId != userId) {
      throw UnauthorizedException('userId mismatch');
    }

    // Continue with task creation...
  }
}
```

---

### 4. FolderSyncCoordinator

**File**: `lib/services/sync/folder_sync_coordinator.dart`

#### P1 Changes: Add userId Validation in Conflict Resolution

```dart
Future<void> handleRealtimeUpdate(Map<String, dynamic> payload) async {
  try {
    // NEW: Validate userId before processing
    final remoteUserId = payload['user_id'];
    final currentUserId = _supabase.auth.currentUser?.id;

    if (remoteUserId != currentUserId) {
      _logger.error('CRITICAL: Received folder update for different user!', data: {
        'expected': currentUserId,
        'received': remoteUserId,
        'folderId': payload['id'],
      });

      await Sentry.captureException(
        UserIdMismatchException(
          expectedUserId: currentUserId!,
          actualUserId: remoteUserId,
          entityId: payload['id'],
        ),
      );

      return; // Skip this update
    }

    // Continue with conflict resolution...
  } catch (error, stack) {
    _logger.error('Failed to handle folder realtime update', error: error, stackTrace: stack);
  }
}
```

---

## Provider Layer Changes

### P0 Status: Manual Provider Invalidation

**Current Implementation**: `lib/app/app.dart` line 1177

```dart
void _invalidateAllProviders(WidgetRef ref) {
  try {
    // Repository providers
    ref.invalidate(notesCoreRepositoryProvider);
    ref.invalidate(taskCoreRepositoryProvider);
    ref.invalidate(folderCoreRepositoryProvider);
    // ... 24 more providers manually invalidated
  } catch (e) {
    debugPrint('[AuthWrapper] Error invalidating providers: $e');
  }
}
```

**P0 Issues**:
1. Manual list - easy to forget new providers
2. No compile-time safety
3. Hard to maintain as app grows

### P3 Solution: Automatic Provider Lifecycle

#### Step 1: Create userId Provider (Single Source of Truth)

```dart
// NEW: lib/core/providers/auth_providers.dart
final currentUserIdProvider = Provider<String>((ref) {
  final auth = ref.watch(authStateChangesProvider);
  final userId = auth?.user?.id ?? '';

  // Log userId changes for debugging
  ref.listen(authStateChangesProvider, (previous, next) {
    final prevUserId = previous?.user?.id;
    final nextUserId = next?.user?.id;

    if (prevUserId != nextUserId) {
      debugPrint('[Auth] userId changed: $prevUserId → $nextUserId');
    }
  });

  return userId;
});
```

#### Step 2: Convert Providers to Family Providers

```dart
// BEFORE (P0):
final notesCoreRepositoryProvider = Provider<NotesCoreRepository>((ref) {
  return NotesCoreRepository(
    db: ref.watch(appDbProvider),
    crypto: ref.watch(cryptoBoxProvider),
    client: ref.watch(supabaseClientProvider),
    indexer: ref.watch(noteIndexerProvider),
  );
});

// AFTER (P3):
final notesCoreRepositoryProvider = Provider.family<NotesCoreRepository, String>(
  (ref, userId) {
    if (userId.isEmpty) {
      throw UnauthorizedException('No authenticated user');
    }

    return NotesCoreRepository(
      db: ref.watch(appDbProvider),
      crypto: ref.watch(cryptoBoxProvider),
      client: ref.watch(supabaseClientProvider),
      indexer: ref.watch(noteIndexerProvider),
      userId: userId, // Scoped to userId!
    );
  },
);

// Consumer usage (auto-invalidates on userId change):
class NotesListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    // ✅ Automatically gets new repository when userId changes!
    final repository = ref.watch(notesCoreRepositoryProvider(userId));

    // Continue...
  }
}
```

#### Step 3: Update ALL Data Providers

**Providers to Update**:
1. `notesCoreRepositoryProvider`
2. `taskCoreRepositoryProvider`
3. `folderCoreRepositoryProvider`
4. `templateCoreRepositoryProvider`
5. `domainNotesProvider`
6. `domainNotesStreamProvider`
7. `domainTasksProvider`
8. `domainTasksStreamProvider`
9. `domainFoldersProvider`
10. `domainFoldersStreamProvider`
11. `enhancedTaskServiceProvider`
12. `unifiedSyncServiceProvider`
13. All feature-specific providers

**Pattern for StreamProviders**:

```dart
// BEFORE:
final domainNotesStreamProvider = StreamProvider<List<domain.Note>>((ref) {
  final repository = ref.watch(notesCoreRepositoryProvider);
  return repository.watchNotes();
});

// AFTER (P3):
final domainNotesStreamProvider = StreamProvider.family<List<domain.Note>, String>(
  (ref, userId) {
    final repository = ref.watch(notesCoreRepositoryProvider(userId));
    return repository.watchNotes();
  },
);
```

#### Step 4: Remove Manual Invalidation

```dart
// P3: Delete _invalidateAllProviders() method entirely!
// No longer needed - providers auto-invalidate when userId changes
```

---

## API Contract Updates

### Repository Interface Changes

#### INotesRepository (P1)

```dart
// No signature changes - userId filtering is internal implementation detail
// All existing code continues to work

abstract class INotesRepository {
  // Unchanged signatures:
  Future<domain.Note?> getNoteById(String id);
  Future<List<domain.Note>> localNotes();
  Future<void> deleteNote(String id);
  // ...

  // Behavior change: Now filters by authenticated user's userId
}
```

#### ITaskRepository (P1)

```dart
// Same pattern - no signature changes
// userId filtering is transparent to callers

abstract class ITaskRepository {
  Future<List<domain.Task>> getTasksForNote(String noteId);
  Future<domain.Task?> getTaskById(String id);
  // ...
}
```

### Service Interface Changes

#### EnhancedTaskService (P2)

```dart
// P2: Add userId parameter to constructor (BREAKING CHANGE)

// BEFORE:
final taskService = EnhancedTaskService(
  database: db,
  taskRepository: taskRepo,
  reminderBridge: bridge,
);

// AFTER:
final taskService = EnhancedTaskService(
  userId: currentUserId, // NEW REQUIRED PARAMETER
  database: db,
  taskRepository: taskRepo,
  reminderBridge: bridge,
);
```

**Migration Path**: Use Provider.family to inject userId automatically:

```dart
final enhancedTaskServiceProvider = Provider.family<EnhancedTaskService, String>(
  (ref, userId) {
    return EnhancedTaskService(
      userId: userId,
      database: ref.watch(appDbProvider),
      taskRepository: ref.watch(taskCoreRepositoryProvider(userId)),
      reminderBridge: ref.watch(taskReminderBridgeProvider),
    );
  },
);
```

---

## Migration Strategy

### Phase 1: Repository Filtering (Week 1-2)

**Day 1-3**: Update Repository Layer
- Add `_getCurrentUserId()` and `_validateUserId()` helper methods
- Update all read methods with userId filtering
- Update all write methods with userId validation
- Add userId column to NoteTasks table

**Day 4-5**: Update Tests
- Add authentication setup to all repository tests
- Test userId filtering works correctly
- Test unauthorized access is blocked

**Day 6-7**: Code Review & QA
- Security code review
- Integration testing
- Performance testing (ensure no regression)

### Phase 2: Non-Nullable userId (Week 3)

**Day 1**: Create Database Migration
- Write migration to backfill userId
- Test migration on staging database
- Prepare rollback procedure

**Day 2**: Update Schema
- Remove `.nullable()` from userId columns
- Update all create operations
- Remove null-checking code

**Day 3-4**: Migration Testing
- Test migration on clean database
- Test migration with existing data
- Test rollback procedure

**Day 5**: Deploy & Monitor
- Deploy to production
- Monitor error logs for migration issues
- Be ready to rollback if issues arise

### Phase 3: Security Middleware (Week 4-5)

**Week 4**: Implement Middleware Layer
- Create SecurityMiddleware class
- Update services to use middleware
- Convert providers to family providers
- Remove manual invalidation code

**Week 5**: Testing & Rollout
- Comprehensive integration testing
- Performance benchmarks
- Gradual rollout with feature flags
- Monitor for issues

---

## Testing Requirements

### P1 Security Tests

#### Test 1: userId Filtering Works

```dart
testWidgets('repository filters by userId', (tester) async {
  // Setup: Create notes for two users
  await createNoteForUser('user1', 'Note 1');
  await createNoteForUser('user2', 'Note 2');

  // Act: Authenticate as user1
  await authenticateAs('user1');
  final notes = await repository.localNotes();

  // Assert: Only user1's notes returned
  expect(notes, hasLength(1));
  expect(notes.first.title, equals('Note 1'));
});
```

#### Test 2: Unauthorized Access Blocked

```dart
testWidgets('getNoteById blocks cross-user access', (tester) async {
  // Setup: User2 creates a note
  await authenticateAs('user2');
  final note = await repository.createOrUpdate(title: 'Secret', body: 'Data');

  // Act: User1 tries to access user2's note
  await authenticateAs('user1');
  final result = await repository.getNoteById(note.id);

  // Assert: Access denied
  expect(result, isNull);
});
```

#### Test 3: Sync Validation Works

```dart
testWidgets('sync skips invalid pending ops', (tester) async {
  // Setup: User1 creates note, then user2 logs in
  await authenticateAs('user1');
  final note = await repository.createOrUpdate(title: 'Test', body: 'Body');

  // Manually add invalid pending op (simulating data corruption)
  await db.enqueue(note.id, 'upsert_note');

  // Act: User2 syncs
  await authenticateAs('user2');
  await syncService.syncAll();

  // Assert: Invalid op was cleaned up
  final ops = await db.getPendingOps();
  expect(ops, isEmpty);
});
```

### P2 Migration Tests

```dart
testWidgets('migration backfills userId', (tester) async {
  // Setup: Create task with null userId (old schema)
  await createLegacyTaskWithNullUserId('task1');

  // Act: Run migration
  await runMigration17_AddUserIdToNoteTasks();

  // Assert: userId backfilled
  final task = await db.getTaskById('task1');
  expect(task.userId, equals(currentUser.id));
  expect(task.userId, isNotNull);
});

testWidgets('migration deletes orphaned tasks', (tester) async {
  // Setup: Create task with deleted parent note
  await createOrphanedTask('task1');

  // Act: Run migration
  await runMigration17_AddUserIdToNoteTasks();

  // Assert: Orphaned task deleted
  final task = await db.getTaskById('task1');
  expect(task, isNull);
});
```

### P3 Provider Tests

```dart
testWidgets('providers auto-invalidate on userId change', (tester) async {
  final container = ProviderContainer();

  // Act: Watch repository with user1
  final userId1 = 'user1';
  final repo1 = container.read(notesCoreRepositoryProvider(userId1));

  // Act: Change to user2
  final userId2 = 'user2';
  final repo2 = container.read(notesCoreRepositoryProvider(userId2));

  // Assert: Different instances
  expect(identical(repo1, repo2), isFalse);
});
```

---

## Conclusion

This guide provides a comprehensive roadmap for implementing userId-based security across all layers of the Duru Notes application. The phased approach ensures:

1. **P1**: Core security (repository filtering) rolled out first
2. **P2**: Database constraints enforced after P1 is stable
3. **P3**: Developer experience improvements (middleware, auto-lifecycle)

Each phase builds on the previous, allowing for incremental testing and rollback if issues arise.

**Next Steps**:
1. Review SECURITY_DESIGN_PATTERNS.md for implementation templates
2. Begin P1 implementation with NotesCoreRepository
3. Follow test-driven development (write tests first!)
4. Deploy P1 to staging before production
