# Architectural Decision Record: Security Implementation Strategy

**Status**: Active
**Date**: 2025-10-24
**Author**: System Architecture Review
**Context**: P0-P3 Security Hardening Implementation

---

## Executive Summary

This ADR documents the architectural decisions for implementing userId-based security across the Duru Notes application. The security implementation spans 4 phases (P0-P3) and affects every layer of the application architecture.

**Critical Finding**: The current architecture has a fundamental security vulnerability - no userId filtering at the repository layer allows cross-user data access if an attacker knows another user's note/task/folder ID.

---

## Current Architecture Overview

### Layer Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│  - Widgets (Stateless/Stateful)                             │
│  - Riverpod ConsumerWidgets                                 │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                   Provider Layer                             │
│  - StateNotifierProviders (pagination, filters)             │
│  - StreamProviders (realtime data)                          │
│  - FutureProviders (async operations)                       │
│  - Provider (singletons, services)                          │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                   Service Layer                              │
│  - EnhancedTaskService (task CRUD + reminders)              │
│  - UnifiedSyncService (bidirectional sync)                  │
│  - UnifiedRealtimeService (Supabase realtime)               │
│  - FolderSyncCoordinator (folder-specific sync)             │
│  - EncryptionSyncService (cross-device encryption)          │
│  - AccountKeyService (device-specific encryption)           │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│               Repository Layer (Infrastructure)              │
│  - NotesCoreRepository (implements INotesRepository)        │
│  - TaskCoreRepository (implements ITaskRepository)          │
│  - FolderCoreRepository (implements IFolderRepository)      │
│  - TemplateRepository (implements ITemplateRepository)      │
│  + Mappers: LocalNote → domain.Note                         │
│  + Encryption/Decryption (CryptoBox)                        │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                   Database Layer (Drift)                     │
│  - AppDb (Drift database)                                   │
│  - Tables: LocalNotes, NoteTasks, LocalFolders, etc.        │
│  - PendingOps (sync queue)                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Flow Analysis

### 1. CREATE Flow

```
User Action (UI)
    ↓
ModernEditNoteScreen.saveNote()
    ↓
notesCoreRepository.createOrUpdate()  ← userId validation HERE
    ↓
  ┌─────────────────────────────────────┐
  │ Repository Layer                    │
  │ 1. Get userId from Supabase.auth    │
  │ 2. Encrypt title + body             │
  │ 3. Create LocalNote with userId     │
  │ 4. Insert into AppDb                │
  │ 5. db.enqueue('upsert_note')        │
  └─────────────────────────────────────┘
    ↓
Database + Sync Queue
```

**Security Checkpoint Location**: Repository layer (line 1505-1526 in notes_core_repository.dart)

**Current Implementation**:
```dart
final userId = _supabase.auth.currentUser?.id;
if (userId == null || userId.isEmpty) {
  // ❌ ONLY checks during CREATE, not READ!
  return null;
}
```

**P1 Decision**: ✅ Keep userId validation in Repository.createOrUpdate()
**P2 Decision**: ✅ Make userId non-nullable in LocalNote schema

---

### 2. READ Flow

```
UI requests notes
    ↓
Provider watches domainNotesStreamProvider
    ↓
notesCoreRepository.localNotes()  ← NO userId filtering! 🚨
    ↓
  ┌─────────────────────────────────────┐
  │ Repository Layer                    │
  │ 1. Query: db.select(localNotes)     │
  │    ..where(note.deleted == false)   │
  │    ❌ NO: ..where(note.userId == currentUser) │
  │ 2. Decrypt for each note            │
  │ 3. Map to domain.Note               │
  └─────────────────────────────────────┘
    ↓
Return ALL notes (any user!) 🚨
```

**CRITICAL VULNERABILITY**: Any user can read any note if they know the ID!

**P1 Decision**: ✅ ADD userId filtering to ALL repository read methods:
- `getNoteById(String id)` → `WHERE id = ? AND userId = ?`
- `localNotes()` → `WHERE deleted = false AND userId = ?`
- `getPinnedNotes()` → `WHERE isPinned = true AND userId = ?`
- `listAfter(cursor)` → `WHERE updatedAt < ? AND userId = ?`

Same pattern for Tasks and Folders.

---

### 3. UPDATE Flow

```
User edits note
    ↓
notesCoreRepository.updateLocalNote()
    ↓
  ┌─────────────────────────────────────┐
  │ Repository Layer                    │
  │ 1. Get existing note                │
  │    ❌ NO userId check!               │
  │ 2. Re-encrypt changed fields        │
  │ 3. Update LocalNote                 │
  │ 4. db.enqueue('upsert_note')        │
  └─────────────────────────────────────┘
    ↓
Database + Sync Queue
```

**P1 Decision**: ✅ ADD userId validation in updateLocalNote():
```dart
final existing = await (db.select(db.localNotes)
  ..where((note) => note.id.equals(id))
  ..where((note) => note.userId.equals(currentUserId))) // NEW!
  .getSingleOrNull();

if (existing == null) {
  throw UnauthorizedException('Note not found or access denied');
}
```

---

### 4. DELETE Flow

```
User deletes note
    ↓
notesCoreRepository.deleteNote()  → calls updateLocalNote(deleted: true)
    ↓
[Same flow as UPDATE]
```

**P1 Decision**: ✅ Inherits userId validation from updateLocalNote()

---

### 5. SYNC Flow (Local → Remote)

```
Background sync triggered
    ↓
unifiedSyncService.syncAll()
    ↓
notesCoreRepository.pushAllPending()
    ↓
  ┌─────────────────────────────────────┐
  │ For each PendingOp:                 │
  │ 1. Get LocalNote from DB            │
  │    ❌ NO userId validation!          │
  │ 2. Read userId from LocalNote       │
  │ 3. Encrypt & push to Supabase       │
  │    ✅ Supabase RLS checks userId    │
  └─────────────────────────────────────┘
    ↓
Supabase (RLS enforced)
```

**Defense Layers**:
1. ❌ No check in repository (vulnerability!)
2. ✅ Supabase RLS enforces userId match (backup defense)

**P1 Decision**: ✅ ADD userId validation in _pushNoteOp():
```dart
final localNote = await (db.select(db.localNotes)
  ..where((n) => n.id.equals(noteId))
  ..where((n) => n.userId.equals(currentUserId))) // NEW!
  .getSingleOrNull();

if (localNote == null) {
  // Note doesn't exist OR belongs to different user
  return true; // Skip this operation
}
```

---

### 6. SYNC Flow (Remote → Local)

```
Background sync triggered
    ↓
notesCoreRepository.pullSince(lastSyncTime)
    ↓
  ┌─────────────────────────────────────┐
  │ Repository Layer                    │
  │ 1. Fetch from Supabase:             │
  │    SELECT * FROM notes              │
  │    WHERE user_id = ? AND updated_at > ? │
  │    ✅ Supabase RLS filters by userId │
  │ 2. For each remote note:            │
  │    - Decrypt title_enc, props_enc   │
  │    - Create/update LocalNote        │
  │      WITH userId from remote record │
  │ 3. Index note for search            │
  └─────────────────────────────────────┘
    ↓
Database (correctly userId-filtered)
```

**Security**: ✅ Supabase RLS ensures only user's notes are returned
**P1 Decision**: ✅ No changes needed (already secure)

---

### 7. REALTIME Flow

```
Supabase change event
    ↓
unifiedRealtimeService._handleChange()
    ↓
  ┌─────────────────────────────────────┐
  │ Realtime Filter Applied:            │
  │ .onPostgresChanges(                 │
  │   filter: PostgresChangeFilter(    │
  │     column: 'user_id',              │
  │     value: userId  ✅               │
  │   ))                                │
  └─────────────────────────────────────┘
    ↓
Event emitted to notesStream
    ↓
Providers update UI
```

**Security**: ✅ userId filter applied at subscription level
**P1 Decision**: ✅ No changes needed (already secure)

---

## Critical Architectural Questions - ANSWERED

### 1. Layer Separation: Where should userId validation happen?

**DECISION**: Defense-in-Depth Strategy

```
┌──────────────────────────────────────────────────────────┐
│ Layer            │ Validation Type      │ P1  │ P2  │ P3 │
├──────────────────────────────────────────────────────────┤
│ UI Layer         │ Display only         │  -  │  -  │  - │
│ Provider Layer   │ None (trusts lower)  │  -  │  -  │  - │
│ Service Layer    │ Business logic only  │  -  │  -  │  ✅ │ ← P3: Security middleware
│ Repository Layer │ PRIMARY ENFORCEMENT  │  ✅ │  ✅ │  ✅ │ ← P1: Add filtering
│ Database Layer   │ Schema constraints   │  -  │  ✅ │  ✅ │ ← P2: Non-nullable userId
│ Supabase RLS     │ BACKUP DEFENSE       │  ✅ │  ✅ │  ✅ │ ← Already in place
└──────────────────────────────────────────────────────────┘
```

**Rationale**:
- **Repository = Primary**: All data access goes through repositories
- **Supabase RLS = Backup**: Defense if local code bypassed
- **P3 Service Middleware**: Centralize validation to prevent duplicate code
- **UI/Provider**: Trust lower layers (keep UI simple)

---

### 2. State Management: Provider Invalidation Strategy

**CURRENT PROBLEM**: Manual invalidation in `_invalidateAllProviders()`:
```dart
// 27 providers invalidated manually - easy to forget new ones!
ref.invalidate(notesCoreRepositoryProvider);
ref.invalidate(taskCoreRepositoryProvider);
// ... 25 more lines
```

**P0 STATUS**: ✅ Works but not sustainable

**P3 DECISION**: Implement Automatic Lifecycle Management

```dart
// NEW: Auto-Invalidation Provider (P3)
final autoInvalidatingRepositoryProvider = Provider.family<Repository, String>(
  (ref, userId) {
    // Automatically creates new instance per userId
    // Old userId instances garbage collected
    return Repository(userId: userId);
  }
);

// Usage:
final userId = ref.watch(userIdProvider); // Changes on login/logout
final repo = ref.watch(autoInvalidatingRepositoryProvider(userId));
// ✅ Automatic invalidation when userId changes!
```

**P3 Migration Strategy**:
1. Create `UserIdProvider` (single source of truth)
2. Convert all data providers to `.family<T, String>` parameterized by userId
3. Remove manual invalidation code
4. Add provider lifecycle tests

---

### 3. Service Orchestration: How do security changes affect services?

#### A. UnifiedSyncService (bidirectional sync)

**Current**: No userId validation in sync logic
**P1 Change**: Add userId checks in pushAllPending() and pullSince()

```dart
// P1: Add to UnifiedSyncService
Future<void> syncAll() async {
  final currentUserId = _supabase.auth.currentUser?.id;
  if (currentUserId == null) {
    throw UnauthorizedException('Cannot sync without authenticated user');
  }

  // Validate all pending ops belong to current user before pushing
  await _validatePendingOps(currentUserId); // NEW!

  await pushAllPending();
  await pullSince(lastSync);
}

Future<void> _validatePendingOps(String userId) async {
  final ops = await db.getPendingOps();
  for (final op in ops) {
    final entity = await _getEntity(op.entityId);
    if (entity?.userId != userId) {
      // Delete invalid pending op (prevents syncing other user's data)
      await db.deletePendingByIds([op.id]);
    }
  }
}
```

#### B. UnifiedRealtimeService (subscriptions)

**Current**: ✅ Already filters by userId at subscription level
**P1 Change**: None needed (already secure)

#### C. EnhancedTaskService (task operations)

**Current**: Wraps TaskCoreRepository, some direct AppDb access
**P1 Change**: Ensure all operations go through repository

```dart
// BEFORE (P0):
await _db.completeTask(taskId, completedBy: userId);

// AFTER (P1):
final task = await _taskRepository.getTaskById(taskId); // ✅ userId filtered
if (task != null) {
  await _taskRepository.completeTask(taskId);
}
```

#### D. FolderSyncCoordinator (folder sync)

**Current**: Implements conflict resolution for folders
**P1 Change**: Add userId validation in conflict resolution

```dart
// P1: Add userId check in handleRealtimeUpdate()
Future<void> handleRealtimeUpdate(Map<String, dynamic> payload) async {
  final remoteUserId = payload['user_id'];
  final currentUserId = _supabase.auth.currentUser?.id;

  if (remoteUserId != currentUserId) {
    // Different user - ignore (shouldn't happen with RLS)
    _logger.warning('Received folder update for different user');
    return;
  }

  // Continue with conflict resolution...
}
```

#### E. EncryptionSyncService (cross-device encryption)

**Current**: Manages encrypted keys in `user_keys` table
**P1 Change**: Already userId-scoped (no changes)

---

### 4. Feature Integration: Cross-feature userId propagation

#### A. Notes ↔ Tasks (NoteTasks table)

**Current Relationship**:
```sql
CREATE TABLE note_tasks (
  id TEXT PRIMARY KEY,
  note_id TEXT NOT NULL,  -- References notes(id)
  -- ❌ NO user_id column in NoteTasks!
);
```

**CRITICAL ISSUE**: Tasks inherit userId from parent note, but:
1. No direct userId column in NoteTasks
2. Orphaned tasks if note is deleted
3. Cannot filter tasks by userId without JOIN

**P1 DECISION**: ADD userId to NoteTasks

```sql
-- P1 Migration:
ALTER TABLE note_tasks ADD COLUMN user_id TEXT;

-- Backfill from parent note:
UPDATE note_tasks
SET user_id = (SELECT user_id FROM local_notes WHERE id = note_tasks.note_id);

-- P2: Make non-nullable:
ALTER TABLE note_tasks ALTER COLUMN user_id SET NOT NULL;
```

**Repository Changes**:
```dart
// P1: Add userId filtering to task queries
Future<List<domain.Task>> getTasksForNote(String noteId) async {
  final currentUserId = client.auth.currentUser?.id;

  final localTasks = await (db.select(db.noteTasks)
    ..where((t) => t.noteId.equals(noteId))
    ..where((t) => t.userId.equals(currentUserId))) // NEW!
    .get();

  return await _decryptTasks(localTasks);
}
```

**Cascade Deletion**:
```dart
// Ensure tasks are deleted when note is deleted
@override
Future<void> deleteNote(String id) async {
  // 1. Delete all tasks for this note
  await _taskRepository.deleteTasksForNote(id);

  // 2. Delete the note
  await updateLocalNote(id, deleted: true);
}
```

#### B. Notes ↔ Folders (NoteFolders junction table)

**Current**: Junction table for many-to-many relationship

```sql
CREATE TABLE note_folders (
  note_id TEXT NOT NULL,
  folder_id TEXT NOT NULL,
  PRIMARY KEY (note_id, folder_id)
);
```

**ISSUE**: No userId in junction table (relies on parent tables)

**P1 DECISION**: Keep as-is (userId validated through notes/folders tables)
**P2 DECISION**: Consider denormalizing userId for performance

**Folder Hierarchy userId Validation**:
```dart
// P1: Validate folder hierarchy belongs to user
Future<void> moveNoteToFolder(String noteId, String folderId) async {
  final currentUserId = _supabase.auth.currentUser?.id;

  // Validate note belongs to user
  final note = await getNoteById(noteId);
  if (note == null) throw NotFoundException('Note not found');

  // Validate folder belongs to user
  final folder = await _folderRepository.getFolderById(folderId);
  if (folder == null) throw NotFoundException('Folder not found');

  // Now safe to move
  await db.moveNoteToFolder(noteId, folderId);
}
```

#### C. Notes ↔ Reminders

**Current**: Reminders stored in `reminders` table with `note_id`

**P1 DECISION**: Add userId to reminders table (same pattern as NoteTasks)

#### D. Tasks ↔ Reminders

**Current**: Tasks reference reminders via `reminder_id` column

**P1 DECISION**: Validate reminder userId matches task userId during creation

---

### 5. Error Handling: userId Security Errors

**P1-P3 Error Taxonomy**:

```dart
// P1: New exception hierarchy
class SecurityException implements Exception {
  final String message;
  final String? userId;
  final String? entityId;

  SecurityException(this.message, {this.userId, this.entityId});
}

class UnauthorizedException extends SecurityException {
  UnauthorizedException(String message, {String? userId, String? entityId})
    : super(message, userId: userId, entityId: entityId);
}

class UserIdMismatchException extends SecurityException {
  final String expectedUserId;
  final String actualUserId;

  UserIdMismatchException({
    required this.expectedUserId,
    required this.actualUserId,
    String? entityId,
  }) : super(
    'userId mismatch: expected $expectedUserId, got $actualUserId',
    userId: actualUserId,
    entityId: entityId,
  );
}
```

**Error Handling Strategy**:

```dart
// Repository layer (P1)
Future<domain.Note?> getNoteById(String id) async {
  try {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw UnauthorizedException('No authenticated user');
    }

    final localNote = await (db.select(db.localNotes)
      ..where((note) => note.id.equals(id))
      ..where((note) => note.userId.equals(currentUserId)))
      .getSingleOrNull();

    if (localNote == null) {
      // Could be: note doesn't exist OR belongs to different user
      // Don't leak information about which case it is
      return null;
    }

    return await _hydrateDomainNote(localNote);
  } catch (e, stack) {
    _logger.error('Failed to get note', error: e, stackTrace: stack);
    _captureSecurityException(e, stack, noteId: id);
    rethrow;
  }
}

// UI layer (display generic error)
try {
  final note = await repository.getNoteById(noteId);
  if (note == null) {
    showError('Note not found'); // Generic message
    return;
  }
} on UnauthorizedException {
  showError('Please sign in to continue');
} on SecurityException {
  showError('Access denied');
}
```

**Sync Error Handling**:

```dart
// P1: Handle userId mismatches during sync
Future<void> _applyRemoteNote(Map<String, dynamic> remoteNote) async {
  final remoteUserId = remoteNote['user_id'];
  final currentUserId = _supabase.auth.currentUser?.id;

  if (remoteUserId != currentUserId) {
    // This should NEVER happen with proper RLS
    _logger.error('CRITICAL: Received note for different user!', data: {
      'expected': currentUserId,
      'received': remoteUserId,
      'noteId': remoteNote['id'],
    });

    await Sentry.captureException(
      UserIdMismatchException(
        expectedUserId: currentUserId!,
        actualUserId: remoteUserId,
        entityId: remoteNote['id'],
      ),
    );

    // Skip this note (don't apply to local DB)
    return;
  }

  // Continue with normal sync...
}
```

---

## P1-P3 Implementation Roadmap

### Phase 1: Repository Layer Filtering (P1)

**Goal**: Add userId filtering to ALL repository read/write operations

**Changes**:
1. Add userId validation to all repository methods
2. Add userId column to NoteTasks table
3. Backfill userId for existing tasks
4. Update all queries to filter by userId

**Implementation Pattern**:
```dart
// Template for all repository methods
Future<T?> getEntityById(String id) async {
  final currentUserId = _getCurrentUserId();
  _validateUserId(currentUserId);

  final entity = await (db.select(db.table)
    ..where((e) => e.id.equals(id))
    ..where((e) => e.userId.equals(currentUserId))) // ALWAYS add this
    .getSingleOrNull();

  return entity != null ? _mapToDomain(entity) : null;
}
```

**Breaking Changes**: None (only restricts unauthorized access)

**Testing**: Security integration tests for each repository

---

### Phase 2: Non-Nullable userId (P2)

**Goal**: Make userId required at database level

**Changes**:
1. Update Drift schema: `userId TEXT NOT NULL`
2. Migration to backfill missing userIds
3. Update all create operations to require userId
4. Remove nullable userId handling code

**Migration Script**:
```dart
// P2 Migration
class Migration18_NonNullableUserId extends Migration {
  @override
  Future<void> run(Migrator m) async {
    // 1. Add userId where missing (from current session)
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw MigrationException('Cannot migrate: no authenticated user');
    }

    await m.database.customStatement('''
      UPDATE local_notes SET user_id = ? WHERE user_id IS NULL;
      UPDATE note_tasks SET user_id = ? WHERE user_id IS NULL;
      UPDATE local_folders SET user_id = ? WHERE user_id IS NULL;
    ''', [currentUserId, currentUserId, currentUserId]);

    // 2. Make columns non-nullable
    await m.alterTable(TableMigration(
      localNotes,
      columnTransformer: {
        localNotes.userId: localNotes.userId.withConstraint(NotNullConstraint()),
      },
    ));
  }
}
```

**Breaking Changes**: Apps with old data may crash if migration fails

**Rollback Strategy**: Keep nullable version in v1, migrate in v2

---

### Phase 3: Security Middleware & Automation (P3)

**Goal**: Centralize security validation and automate provider lifecycle

**A. Security Middleware Layer**:

```dart
// NEW: Security middleware between Service → Repository
class SecurityMiddleware {
  final String currentUserId;
  final AppLogger _logger;

  SecurityMiddleware({required this.currentUserId, required AppLogger logger})
    : _logger = logger;

  /// Wrap repository call with userId validation
  Future<T> execute<T>({
    required String operation,
    required Future<T> Function() repositoryCall,
    String? entityId,
  }) async {
    // 1. Validate user is authenticated
    if (currentUserId.isEmpty) {
      throw UnauthorizedException('No authenticated user');
    }

    // 2. Execute repository call (already has userId filtering)
    try {
      return await repositoryCall();
    } catch (e, stack) {
      // 3. Enhanced logging with security context
      _logger.error('Repository operation failed',
        error: e,
        stackTrace: stack,
        data: {
          'operation': operation,
          'userId': currentUserId,
          if (entityId != null) 'entityId': entityId,
        },
      );
      rethrow;
    }
  }
}

// Usage in services:
class EnhancedNoteService {
  final NotesCoreRepository _repository;
  final SecurityMiddleware _security;

  Future<domain.Note?> getNote(String id) async {
    return _security.execute(
      operation: 'getNote',
      entityId: id,
      repositoryCall: () => _repository.getNoteById(id),
    );
  }
}
```

**B. Automatic Provider Lifecycle**:

```dart
// P3: Replace manual invalidation with automatic userId-based providers

// Single source of truth for userId
final currentUserIdProvider = Provider<String>((ref) {
  final auth = ref.watch(authStateChangesProvider);
  return auth?.user?.id ?? '';
});

// Auto-invalidating repository (family provider)
final noteRepositoryProvider = Provider.family<NotesCoreRepository, String>(
  (ref, userId) {
    if (userId.isEmpty) {
      throw UnauthorizedException('No user');
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
    final repository = ref.watch(noteRepositoryProvider(userId));
    // ✅ Automatically gets new repository when userId changes!
  }
}
```

**C. Automated Provider Registration**:

```dart
// P3: Annotate providers for auto-invalidation
@UserScoped() // NEW: Custom annotation
final notesCoreRepositoryProvider = Provider<NotesCoreRepository>(...);

// Code generator creates:
void invalidateUserScopedProviders(WidgetRef ref) {
  ref.invalidate(notesCoreRepositoryProvider);
  ref.invalidate(taskCoreRepositoryProvider);
  // ... all @UserScoped providers
}
```

---

## Security Design Patterns

### Pattern 1: Repository Filtering Template

```dart
/// Template for adding userId filtering to any query
Future<T?> secureGetById<T>(
  String id,
  SelectStatement<Table, Entity> Function() queryBuilder,
  T Function(Entity) mapper,
) async {
  final userId = _getCurrentUserId();
  _validateUserId(userId);

  final entity = await (queryBuilder()
    ..where((e) => e.id.equals(id))
    ..where((e) => e.userId.equals(userId))) // Security filter
    .getSingleOrNull();

  return entity != null ? mapper(entity) : null;
}
```

### Pattern 2: Service-Level userId Injection

```dart
/// Services receive userId at construction (not runtime lookup)
class SecureNoteService {
  final String userId; // Injected via DI
  final NotesCoreRepository _repository;

  SecureNoteService({
    required this.userId,
    required NotesCoreRepository repository,
  }) : _repository = repository;

  // All operations scoped to injected userId
  Future<domain.Note> createNote(String title, String body) async {
    return _repository.createOrUpdate(
      title: title,
      body: body,
      userId: userId, // From constructor
    );
  }
}
```

### Pattern 3: Fail-Fast Validation

```dart
/// Validate userId BEFORE any database operations
void _validateUserId(String? userId) {
  if (userId == null || userId.isEmpty) {
    throw UnauthorizedException('Missing userId');
  }
}

// Usage at entry of every repository method:
Future<domain.Note?> getNoteById(String id) async {
  final userId = _getCurrentUserId();
  _validateUserId(userId); // FAIL FAST

  // Continue with database operations...
}
```

---

## Monitoring & Observability

### P1-P3 Security Metrics

```dart
/// Track security violations for monitoring
class SecurityMetrics {
  static void recordUnauthorizedAccess({
    required String operation,
    required String entityType,
    String? entityId,
    String? attemptedUserId,
  }) {
    Sentry.captureException(
      UnauthorizedException('Unauthorized access attempt'),
      hint: Hint.withMap({
        'operation': operation,
        'entityType': entityType,
        'entityId': entityId,
        'attemptedUserId': attemptedUserId,
      }),
    );

    // Also log for analytics
    analytics.logEvent('security_violation', {
      'type': 'unauthorized_access',
      'operation': operation,
      'entity_type': entityType,
    });
  }
}
```

### Recommended Alerts

1. **High-Priority**: userId mismatch during sync (indicates RLS failure)
2. **Medium-Priority**: Null userId in read operations (indicates validation gap)
3. **Low-Priority**: Failed authorization attempts (normal user errors)

---

## Testing Strategy

### P1 Security Integration Tests

```dart
// Test repository userId filtering
testWidgets('getNoteById filters by userId', (tester) async {
  // Setup: Create notes for two different users
  final user1Note = await createNoteForUser('user1', 'Title 1');
  final user2Note = await createNoteForUser('user2', 'Title 2');

  // Act: User1 tries to read User2's note
  authenticateAs('user1');
  final result = await repository.getNoteById(user2Note.id);

  // Assert: User1 cannot access User2's note
  expect(result, isNull);
});
```

### P2 Migration Tests

```dart
// Test non-nullable userId migration
testWidgets('migration backfills userId', (tester) async {
  // Setup: Create note with null userId (old schema)
  await createLegacyNoteWithNullUserId('note1');

  // Act: Run migration
  await runMigration18_NonNullableUserId();

  // Assert: userId backfilled from current user
  final note = await db.getNoteById('note1');
  expect(note.userId, equals(currentUser.id));
  expect(note.userId, isNotNull);
});
```

### P3 Provider Lifecycle Tests

```dart
// Test automatic provider invalidation
testWidgets('providers invalidate on userId change', (tester) async {
  final container = ProviderContainer();

  // Setup: Watch repository with user1
  final userId1 = 'user1';
  final repo1 = container.read(noteRepositoryProvider(userId1));

  // Act: Change userId
  final userId2 = 'user2';
  final repo2 = container.read(noteRepositoryProvider(userId2));

  // Assert: Different repository instances
  expect(repo1, isNot(same(repo2)));
  expect(repo1.userId, equals(userId1));
  expect(repo2.userId, equals(userId2));
});
```

---

## Rollback Procedures

### P1 Rollback (Repository Filtering)

**Symptom**: Users cannot access their own data
**Action**:
1. Deploy hotfix removing userId filtering
2. Investigate: Are userIds correctly populated in DB?
3. Re-deploy with fix

**Safe Rollback**: YES (removes added security, doesn't break functionality)

### P2 Rollback (Non-Nullable userId)

**Symptom**: App crashes on migration or data access
**Action**:
1. Release new version with nullable userId schema
2. Users re-install to get old schema
3. Investigate migration failures

**Safe Rollback**: PARTIAL (requires app update)

### P3 Rollback (Security Middleware)

**Symptom**: Performance degradation or unexpected errors
**Action**:
1. Feature flag to disable middleware
2. Monitor performance metrics
3. Fix issues and re-enable

**Safe Rollback**: YES (middleware is optional layer)

---

## Conclusion

This ADR establishes the architectural foundation for implementing userId-based security across Duru Notes. The phased approach (P0-P3) allows for incremental rollout while maintaining system stability.

**Key Decisions**:
1. ✅ Repository layer is PRIMARY enforcement point for userId security
2. ✅ Supabase RLS is BACKUP defense layer
3. ✅ P1 adds userId filtering to all queries
4. ✅ P2 makes userId non-nullable at database level
5. ✅ P3 adds security middleware and automates provider lifecycle

**Next Steps**:
1. Review SERVICE_INTEGRATION_GUIDE.md for service-specific changes
2. Review SECURITY_DESIGN_PATTERNS.md for implementation templates
3. Begin P1 implementation with repository filtering
