# Security Design Patterns: P1-P3 Implementation Templates

**Version**: 1.0
**Last Updated**: 2025-10-24
**Purpose**: Code templates and patterns for implementing userId-based security

---

## Table of Contents

1. [Core Patterns](#core-patterns)
2. [Repository Layer Patterns](#repository-layer-patterns)
3. [Service Layer Patterns](#service-layer-patterns)
4. [Provider Layer Patterns](#provider-layer-patterns)
5. [Error Handling Patterns](#error-handling-patterns)
6. [Testing Patterns](#testing-patterns)
7. [Code Review Checklist](#code-review-checklist)
8. [Common Pitfalls](#common-pitfalls)

---

## Core Patterns

### Pattern 1: Fail-Fast Validation

**Purpose**: Catch security violations immediately before any database operations

**Template**:

```dart
/// Always validate userId at the start of every repository method
void _validateUserId(String? userId) {
  if (userId == null || userId.isEmpty) {
    throw UnauthorizedException(
      'No authenticated user',
      stackTrace: StackTrace.current,
    );
  }
}

// Usage:
Future<domain.Note?> getNoteById(String id) async {
  final userId = _getCurrentUserId();
  _validateUserId(userId); // FAIL FAST - before any queries!

  // Continue with database operations...
}
```

**Benefits**:
- Prevents wasted database queries
- Clear error messages
- Consistent validation across all methods

**When to Use**: Start of EVERY repository method

---

### Pattern 2: Defense-in-Depth Filtering

**Purpose**: Apply userId filter at every query level (don't trust previous filters)

**Template**:

```dart
/// Always add userId filter to WHERE clause
Future<T?> secureQueryById<T>({
  required String id,
  required String userId,
  required SimpleSelectStatement<Table, Entity> query,
  required T Function(Entity) mapper,
}) async {
  final entity = await (query
    ..where((e) => e.id.equals(id))
    ..where((e) => e.userId.equals(userId))) // ALWAYS filter by userId
    .getSingleOrNull();

  return entity != null ? mapper(entity) : null;
}

// Usage:
Future<domain.Note?> getNoteById(String id) async {
  final userId = _getCurrentUserId();
  _validateUserId(userId);

  return secureQueryById(
    id: id,
    userId: userId,
    query: db.select(db.localNotes),
    mapper: _hydrateDomainNote,
  );
}
```

**Benefits**:
- Impossible to forget userId filter
- Centralized security logic
- Type-safe queries

**When to Use**: ALL database queries that return user data

---

### Pattern 3: Explicit userId Injection

**Purpose**: Pass userId explicitly instead of runtime lookup (testability + clarity)

**Template**:

```dart
// ❌ BAD: Runtime lookup (hard to test, implicit dependency)
class NoteService {
  Future<Note> createNote(String title) async {
    final userId = Supabase.instance.client.auth.currentUser?.id; // Hidden dependency!
    return repository.create(userId: userId, title: title);
  }
}

// ✅ GOOD: Constructor injection (testable, explicit)
class NoteService {
  final String userId; // Explicit dependency
  final NoteRepository repository;

  NoteService({
    required this.userId, // Injected at construction
    required this.repository,
  });

  Future<Note> createNote(String title) async {
    // userId is known and validated at service creation
    return repository.create(userId: userId, title: title);
  }
}
```

**Benefits**:
- Easier to test (mock userId)
- Explicit dependencies
- Clearer code

**When to Use**: Service layer and above (Repository layer can use runtime lookup)

---

### Pattern 4: Secure-by-Default API

**Purpose**: Make it impossible to call methods insecurely

**Template**:

```dart
// ❌ BAD: userId is optional (can forget to pass it)
Future<List<Note>> getNotes({String? userId}) async {
  final query = db.select(db.notes);
  if (userId != null) {
    query.where((n) => n.userId.equals(userId));
  }
  return query.get();
}

// ✅ GOOD: userId is required (can't forget)
Future<List<Note>> getNotes(String userId) async {
  _validateUserId(userId);

  return (db.select(db.notes)
    ..where((n) => n.userId.equals(userId))) // Always filtered
    .get();
}
```

**Benefits**:
- Compiler enforces security
- Can't accidentally call insecurely
- Clear API contract

**When to Use**: ALL repository methods that access user data

---

## Repository Layer Patterns

### Pattern 5: Repository Method Template

**Purpose**: Standard structure for all repository CRUD methods

**Template**:

```dart
/// TEMPLATE: Repository Read Method
Future<T?> getEntityById<T>(String id) async {
  final String traceId = 'get_entity_$id'; // For debugging

  try {
    // STEP 1: Get and validate userId
    final userId = _getCurrentUserId();
    _validateUserId(userId);

    // STEP 2: Query with userId filter
    final entity = await (db.select(db.table)
      ..where((e) => e.id.equals(id))
      ..where((e) => e.userId.equals(userId))) // ALWAYS add this
      .getSingleOrNull();

    // STEP 3: Return null if not found (don't leak information)
    if (entity == null) {
      return null;
    }

    // STEP 4: Map to domain (with decryption if needed)
    return await _mapToDomain(entity);

  } catch (error, stackTrace) {
    // STEP 5: Log and report errors
    _logger.error('Failed to get entity', error: error, stackTrace: stackTrace);
    _captureRepositoryException(
      method: 'getEntityById',
      error: error,
      stackTrace: stackTrace,
      data: {'id': id, 'traceId': traceId},
    );

    // STEP 6: Return safe default or rethrow
    return null; // For reads, return null
    // rethrow; // For writes, rethrow
  }
}

/// TEMPLATE: Repository Write Method
Future<void> updateEntity(String id, {...}) async {
  try {
    // STEP 1: Get and validate userId
    final userId = _getCurrentUserId();
    _validateUserId(userId);

    // STEP 2: Verify entity exists AND belongs to user
    final existing = await (db.select(db.table)
      ..where((e) => e.id.equals(id))
      ..where((e) => e.userId.equals(userId)))
      .getSingleOrNull();

    if (existing == null) {
      throw UnauthorizedException('Entity not found or access denied');
    }

    // STEP 3: Perform update
    await db.updateEntity(id, {...});

    // STEP 4: Enqueue for sync
    await db.enqueue(id, 'upsert_entity');

    // STEP 5: Emit mutation event (for UI updates)
    MutationEventBus.instance.emitEntity(
      kind: MutationKind.updated,
      entityId: id,
    );

  } catch (error, stackTrace) {
    _logger.error('Failed to update entity', error: error, stackTrace: stackTrace);
    _captureRepositoryException(
      method: 'updateEntity',
      error: error,
      stackTrace: stackTrace,
      data: {'id': id},
    );
    rethrow; // Don't swallow write errors
  }
}
```

**Apply This Template To**:
- `getNoteById()`, `getTaskById()`, `getFolderById()`
- `localNotes()`, `getAllTasks()`, `getAllFolders()`
- `updateLocalNote()`, `updateTask()`, `updateFolder()`
- `deleteNote()`, `deleteTask()`, `deleteFolder()`

---

### Pattern 6: Secure Stream Queries

**Purpose**: Apply userId filtering to reactive queries (watchNotes, etc.)

**Template**:

```dart
/// TEMPLATE: Secure watch stream
Stream<List<domain.Note>> watchNotes() {
  try {
    // STEP 1: Get and validate userId
    final userId = _getCurrentUserId();
    _validateUserId(userId);

    // STEP 2: Create query with userId filter
    return (db.select(db.localNotes)
      ..where((note) => note.deleted.equals(false))
      ..where((note) => note.userId.equals(userId)) // ALWAYS filter
      ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
      .watch()
      .asyncMap((localNotes) async {
        // STEP 3: Map to domain entities
        return await _hydrateDomainNotes(localNotes);
      });

  } catch (error, stackTrace) {
    _logger.error('Failed to create watch stream', error: error, stackTrace: stackTrace);
    return Stream.error(error, stackTrace);
  }
}
```

**Critical**: Stream queries must filter by userId to prevent cross-user data leaks

---

### Pattern 7: Secure Pagination

**Purpose**: Apply userId filtering with cursor-based pagination

**Template**:

```dart
/// TEMPLATE: Paginated query with userId filter
Future<List<domain.Note>> listAfter(
  DateTime? cursor, {
  int limit = 20,
}) async {
  try {
    final userId = _getCurrentUserId();
    _validateUserId(userId);

    // Build query with userId filter
    final query = db.select(db.localNotes)
      ..where((note) => note.deleted.equals(false))
      ..where((note) => note.userId.equals(userId)); // ALWAYS filter

    // Add cursor filter if provided
    if (cursor != null) {
      query.where((note) => note.updatedAt.isSmallerThanValue(cursor));
    }

    // Execute with limit
    final localNotes = await (query
      ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])
      ..limit(limit))
      .get();

    return await _hydrateDomainNotes(localNotes);

  } catch (error, stackTrace) {
    _logger.error('Failed to paginate notes', error: error, stackTrace: stackTrace);
    return const <domain.Note>[];
  }
}
```

**Key Points**:
- userId filter applies BEFORE cursor/limit
- Prevents paginating through other users' data
- Maintains pagination performance with indexed userId

---

### Pattern 8: Secure Sync Operations

**Purpose**: Validate userId during push/pull sync operations

**Template**:

```dart
/// TEMPLATE: Secure push operation
Future<bool> _pushEntityOp(PendingOp op) async {
  final entityId = op.entityId;

  try {
    // STEP 1: Validate current user
    final currentUserId = _getCurrentUserId();
    _validateUserId(currentUserId);

    // STEP 2: Get entity with userId filter
    final entity = await (db.select(db.table)
      ..where((e) => e.id.equals(entityId))
      ..where((e) => e.userId.equals(currentUserId))) // Filter by userId
      .getSingleOrNull();

    // STEP 3: Handle missing/unauthorized entity
    if (entity == null && op.kind != 'delete') {
      _logger.warning('Pending op references missing or unauthorized entity', data: {
        'opId': op.id,
        'kind': op.kind,
        'entityId': entityId,
        'userId': currentUserId,
      });
      return true; // Skip this operation (don't retry)
    }

    // STEP 4: Encrypt and push to Supabase
    final encrypted = await _encryptEntity(entity);
    await _supabase.from('table_name').upsert(encrypted);

    return true; // Success

  } catch (error, stackTrace) {
    _logger.error('Failed to push entity', error: error, stackTrace: stackTrace);
    return false; // Will retry
  }
}

/// TEMPLATE: Secure pull operation
Future<void> _applyRemoteEntity(Map<String, dynamic> remote) async {
  try {
    // STEP 1: Validate userId matches current user
    final remoteUserId = remote['user_id'];
    final currentUserId = _getCurrentUserId();

    if (remoteUserId != currentUserId) {
      // This should NEVER happen with proper RLS
      _logger.error('CRITICAL: Received entity for different user!', data: {
        'expected': currentUserId,
        'received': remoteUserId,
        'entityId': remote['id'],
      });

      await Sentry.captureException(
        UserIdMismatchException(
          expectedUserId: currentUserId!,
          actualUserId: remoteUserId,
          entityId: remote['id'],
        ),
      );

      return; // Skip this entity
    }

    // STEP 2: Decrypt remote entity
    final decrypted = await _decryptEntity(remote);

    // STEP 3: Upsert into local database
    await db.upsertEntity(decrypted);

  } catch (error, stackTrace) {
    _logger.error('Failed to apply remote entity', error: error, stackTrace: stackTrace);
    _captureRepositoryException(...);
  }
}
```

**Defense Layers**:
1. Local: userId filter in _pushEntityOp()
2. Remote: Supabase RLS filters by userId
3. Pull: Validate remoteUserId in _applyRemoteEntity()

---

## Service Layer Patterns

### Pattern 9: Service Method Wrapper

**Purpose**: Standard service method structure with security validation

**Template**:

```dart
/// TEMPLATE: Service method with security checks
class SecureEntityService {
  final String userId; // Injected at construction
  final EntityRepository repository;
  final AppLogger _logger;

  SecureEntityService({
    required this.userId,
    required this.repository,
    AppLogger? logger,
  }) : _logger = logger ?? LoggerFactory.instance {
    // Validate userId at construction
    if (userId.isEmpty) {
      throw UnauthorizedException('Service requires authenticated user');
    }
  }

  Future<Entity> performOperation({required String entityId}) async {
    try {
      // STEP 1: Log operation start
      _logger.debug('Starting operation', data: {'entityId': entityId, 'userId': userId});

      // STEP 2: Validate preconditions
      _validatePreconditions(entityId);

      // STEP 3: Call repository (already has userId filtering)
      final entity = await repository.getEntityById(entityId);

      if (entity == null) {
        throw NotFoundException('Entity not found');
      }

      // STEP 4: Perform business logic
      final result = await _businessLogic(entity);

      // STEP 5: Log success
      _logger.info('Operation completed', data: {'entityId': entityId});

      return result;

    } on SecurityException {
      // Security errors - don't retry
      _logger.error('Security error in operation', data: {'entityId': entityId, 'userId': userId});
      rethrow;
    } catch (error, stackTrace) {
      // Other errors - log and rethrow
      _logger.error('Operation failed', error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  void _validatePreconditions(String entityId) {
    if (entityId.isEmpty) {
      throw ArgumentError('entityId cannot be empty');
    }
    // Additional validation...
  }

  Future<Entity> _businessLogic(Entity entity) async {
    // Service-specific logic here
    return entity;
  }
}
```

---

### Pattern 10: Service-Level userId Validation

**Purpose**: Ensure service operations match authenticated user

**Template**:

```dart
/// TEMPLATE: Service with runtime userId validation
class EnhancedEntityService {
  final EntityRepository _repository;
  final SupabaseClient _supabase;

  // Getter for current userId (validated each time)
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<Entity> updateEntity({
    required String entityId,
    required Map<String, dynamic> updates,
  }) async {
    // STEP 1: Validate current user matches service scope
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      throw UnauthorizedException('No authenticated user');
    }

    // STEP 2: Get entity (repository filters by userId)
    final entity = await _repository.getEntityById(entityId);
    if (entity == null) {
      throw NotFoundException('Entity not found');
    }

    // STEP 3: Update entity
    return await _repository.updateEntity(entity.copyWith(...updates));
  }
}
```

**Use This When**: Service doesn't have userId injected at construction

---

## Provider Layer Patterns

### Pattern 11: Family Provider Pattern

**Purpose**: Automatic provider invalidation on userId change

**Template**:

```dart
/// TEMPLATE: Family provider scoped to userId

// Step 1: Create userId provider (single source of truth)
final currentUserIdProvider = Provider<String>((ref) {
  final auth = ref.watch(authStateChangesProvider);
  return auth?.user?.id ?? '';
});

// Step 2: Convert repository to family provider
final entityRepositoryProvider = Provider.family<EntityRepository, String>(
  (ref, userId) {
    // Validate userId
    if (userId.isEmpty) {
      throw UnauthorizedException('No authenticated user');
    }

    // Create repository scoped to userId
    return EntityRepository(
      db: ref.watch(appDbProvider),
      client: ref.watch(supabaseClientProvider),
      userId: userId, // Scoped!
    );
  },
);

// Step 3: Convert service to family provider
final entityServiceProvider = Provider.family<EntityService, String>(
  (ref, userId) {
    return EntityService(
      userId: userId,
      repository: ref.watch(entityRepositoryProvider(userId)),
    );
  },
);

// Step 4: Convert stream provider to family provider
final entityStreamProvider = StreamProvider.family<List<Entity>, String>(
  (ref, userId) {
    final repository = ref.watch(entityRepositoryProvider(userId));
    return repository.watchEntities();
  },
);

// Usage in UI:
class EntityListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current userId
    final userId = ref.watch(currentUserIdProvider);

    // Watch entities (auto-invalidates when userId changes!)
    final entitiesAsync = ref.watch(entityStreamProvider(userId));

    return entitiesAsync.when(
      data: (entities) => ListView.builder(...),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => ErrorWidget(error),
    );
  }
}
```

**Benefits**:
- Automatic invalidation on userId change
- No manual provider cleanup needed
- Type-safe userId propagation

---

### Pattern 12: Provider Disposal Pattern

**Purpose**: Properly clean up resources when providers are disposed

**Template**:

```dart
/// TEMPLATE: Provider with proper disposal

final entityServiceProvider = Provider.family<EntityService, String>(
  (ref, userId) {
    final service = EntityService(userId: userId, ...);

    // Dispose when provider is disposed
    ref.onDispose(() {
      service.dispose();
    });

    return service;
  },
);

// Service with disposable resources
class EntityService {
  final StreamController<Event> _controller = StreamController.broadcast();
  Timer? _timer;

  void dispose() {
    _controller.close();
    _timer?.cancel();
  }
}
```

---

## Error Handling Patterns

### Pattern 13: Security Exception Hierarchy

**Purpose**: Structured security error types

**Template**:

```dart
/// TEMPLATE: Security exception hierarchy

/// Base security exception
class SecurityException implements Exception {
  final String message;
  final String? userId;
  final String? entityId;
  final StackTrace? stackTrace;

  SecurityException(
    this.message, {
    this.userId,
    this.entityId,
    this.stackTrace,
  });

  @override
  String toString() => 'SecurityException: $message';
}

/// User is not authenticated
class UnauthorizedException extends SecurityException {
  UnauthorizedException(
    String message, {
    String? userId,
    String? entityId,
    StackTrace? stackTrace,
  }) : super(message, userId: userId, entityId: entityId, stackTrace: stackTrace);

  @override
  String toString() => 'UnauthorizedException: $message';
}

/// userId mismatch (different user than expected)
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

/// Entity not found (or access denied - don't leak information)
class NotFoundException extends SecurityException {
  NotFoundException(
    String message, {
    String? entityId,
  }) : super(message, entityId: entityId);
}

/// Rate limiting or quota exceeded
class RateLimitException extends SecurityException {
  final Duration retryAfter;

  RateLimitException(
    String message, {
    required this.retryAfter,
    String? userId,
  }) : super(message, userId: userId);
}
```

---

### Pattern 14: Security Error Handling

**Purpose**: Consistent error handling across all layers

**Template**:

```dart
/// TEMPLATE: Repository error handling
Future<T?> repositoryMethod<T>() async {
  try {
    // Repository operation...
  } on SecurityException catch (error, stackTrace) {
    // Security errors - log and rethrow (don't retry)
    _logger.error('Security error', error: error, stackTrace: stackTrace);
    _captureRepositoryException(
      method: 'repositoryMethod',
      error: error,
      stackTrace: stackTrace,
      level: SentryLevel.warning, // Security errors are warnings
    );
    rethrow;
  } catch (error, stackTrace) {
    // Other errors - log and return safe default
    _logger.error('Repository error', error: error, stackTrace: stackTrace);
    _captureRepositoryException(
      method: 'repositoryMethod',
      error: error,
      stackTrace: stackTrace,
    );
    return null; // Safe default for reads
  }
}

/// TEMPLATE: Service error handling
Future<T> serviceMethod<T>() async {
  try {
    // Service operation...
  } on UnauthorizedException catch (error) {
    // User not authenticated - redirect to login
    _logger.warning('Unauthorized access attempt');
    _navigationService.showLoginScreen();
    rethrow;
  } on NotFoundException catch (error) {
    // Entity not found - show user-friendly message
    _logger.info('Entity not found', data: {'entityId': error.entityId});
    throw UserFriendlyException('Item not found');
  } on SecurityException catch (error, stackTrace) {
    // Other security errors - show generic message
    _logger.error('Security error', error: error, stackTrace: stackTrace);
    throw UserFriendlyException('Access denied');
  } catch (error, stackTrace) {
    // Unexpected errors - show generic message and report
    _logger.error('Unexpected error', error: error, stackTrace: stackTrace);
    await Sentry.captureException(error, stackTrace: stackTrace);
    throw UserFriendlyException('Something went wrong');
  }
}

/// TEMPLATE: UI error handling
Widget build(BuildContext context, WidgetRef ref) {
  final entitiesAsync = ref.watch(entityStreamProvider(userId));

  return entitiesAsync.when(
    data: (entities) => EntityList(entities: entities),
    loading: () => LoadingIndicator(),
    error: (error, stackTrace) {
      // Handle different error types
      if (error is UnauthorizedException) {
        return ErrorView(
          message: 'Please sign in to continue',
          action: TextButton(
            onPressed: () => ref.read(authServiceProvider).signIn(),
            child: Text('Sign In'),
          ),
        );
      } else if (error is SecurityException) {
        return ErrorView(message: 'Access denied');
      } else {
        return ErrorView(message: 'Something went wrong');
      }
    },
  );
}
```

---

## Testing Patterns

### Pattern 15: Security Test Template

**Purpose**: Standard structure for security tests

**Template**:

```dart
/// TEMPLATE: Security test

// Setup test helpers
Future<void> authenticateAs(String userId) async {
  await tester.pumpAndSettle();
  // Mock authentication
  when(mockAuth.currentUser).thenReturn(User(id: userId));
}

Future<Entity> createEntityForUser(String userId, String data) async {
  await authenticateAs(userId);
  return await repository.createEntity(data: data);
}

// Test 1: userId filtering works
testWidgets('getEntityById filters by userId', (tester) async {
  // Setup: Create entities for two users
  final user1Entity = await createEntityForUser('user1', 'Data 1');
  final user2Entity = await createEntityForUser('user2', 'Data 2');

  // Act: User1 tries to access their entity
  await authenticateAs('user1');
  final result1 = await repository.getEntityById(user1Entity.id);

  // Assert: User1 can access their entity
  expect(result1, isNotNull);
  expect(result1!.id, equals(user1Entity.id));

  // Act: User1 tries to access user2's entity
  final result2 = await repository.getEntityById(user2Entity.id);

  // Assert: User1 cannot access user2's entity
  expect(result2, isNull);
});

// Test 2: Unauthenticated access blocked
testWidgets('repository methods throw UnauthorizedException when not authenticated', (tester) async {
  // Setup: Clear authentication
  when(mockAuth.currentUser).thenReturn(null);

  // Act & Assert: Repository method throws
  expect(
    () => repository.getEntityById('any-id'),
    throwsA(isA<UnauthorizedException>()),
  );
});

// Test 3: Cross-user write blocked
testWidgets('updateEntity blocks cross-user access', (tester) async {
  // Setup: User2 creates entity
  await authenticateAs('user2');
  final entity = await repository.createEntity(data: 'Data');

  // Act: User1 tries to update user2's entity
  await authenticateAs('user1');

  // Assert: Update throws UnauthorizedException
  expect(
    () => repository.updateEntity(entity.id, data: 'Modified'),
    throwsA(isA<UnauthorizedException>()),
  );
});

// Test 4: Sync validates userId
testWidgets('sync skips invalid pending ops', (tester) async {
  // Setup: User1 creates entity, pending op added
  await authenticateAs('user1');
  final entity = await repository.createEntity(data: 'Data');

  // Verify pending op exists
  var ops = await db.getPendingOps();
  expect(ops, hasLength(1));

  // Act: User2 syncs (different user)
  await authenticateAs('user2');
  await syncService.syncAll();

  // Assert: Invalid op was cleaned up
  ops = await db.getPendingOps();
  expect(ops, isEmpty);
});
```

---

### Pattern 16: Integration Test Template

**Purpose**: End-to-end security testing

**Template**:

```dart
/// TEMPLATE: End-to-end security test

testWidgets('complete user workflow respects userId isolation', (tester) async {
  // User 1 workflow
  await authenticateAs('user1');

  // User1 creates entities
  final user1Note = await notesRepository.createOrUpdate(
    title: 'User1 Note',
    body: 'Private data',
  );
  final user1Task = await tasksRepository.createTask(domain.Task(
    noteId: user1Note!.id,
    title: 'User1 Task',
    // ...
  ));

  // User1 can see their own entities
  var notes = await notesRepository.localNotes();
  expect(notes, hasLength(1));
  var tasks = await tasksRepository.getAllTasks();
  expect(tasks, hasLength(1));

  // User 2 workflow
  await authenticateAs('user2');

  // User2 cannot see user1's entities
  notes = await notesRepository.localNotes();
  expect(notes, isEmpty);
  tasks = await tasksRepository.getAllTasks();
  expect(tasks, isEmpty);

  // User2 cannot access user1's entities directly
  final note = await notesRepository.getNoteById(user1Note.id);
  expect(note, isNull);
  final task = await tasksRepository.getTaskById(user1Task.id);
  expect(task, isNull);

  // User2 creates their own entities
  final user2Note = await notesRepository.createOrUpdate(
    title: 'User2 Note',
    body: 'Different data',
  );

  // User2 can see only their entities
  notes = await notesRepository.localNotes();
  expect(notes, hasLength(1));
  expect(notes.first.title, equals('User2 Note'));

  // User 1 still cannot see user2's entities
  await authenticateAs('user1');
  final user2NoteFromUser1 = await notesRepository.getNoteById(user2Note!.id);
  expect(user2NoteFromUser1, isNull);
});
```

---

## Code Review Checklist

### Pre-Review Checklist (Author)

**Before submitting PR, verify**:

- [ ] All repository methods have `_validateUserId()` call
- [ ] All queries include `.where((e) => e.userId.equals(userId))`
- [ ] No direct database access bypassing repositories
- [ ] Service methods use repository methods (not direct DB)
- [ ] Error handling follows patterns (SecurityException hierarchy)
- [ ] Tests cover both authorized and unauthorized cases
- [ ] No console.log or print statements with sensitive data
- [ ] Migration script tested on staging database
- [ ] Documentation updated (if API contracts changed)

### Security Review Checklist (Reviewer)

**Code Review Focus Areas**:

#### 1. Repository Layer
- [ ] Every query has userId filter
- [ ] userId validation happens at method start
- [ ] No nullable userId handling in P2+ code
- [ ] Write operations verify entity ownership
- [ ] Sync operations validate userId matches

#### 2. Service Layer
- [ ] Services use repositories (not direct DB access)
- [ ] No hardcoded userId values
- [ ] Error handling doesn't leak information
- [ ] Business logic doesn't bypass security

#### 3. Provider Layer
- [ ] Family providers use userId parameter
- [ ] No manual provider invalidation in P3+ code
- [ ] Provider disposal implemented correctly

#### 4. Testing
- [ ] Tests authenticate before repository calls
- [ ] Cross-user access tests included
- [ ] Unauthenticated access tests included
- [ ] Sync validation tests included

#### 5. Security
- [ ] No SQL injection vulnerabilities
- [ ] No information leakage in error messages
- [ ] Rate limiting applied where needed
- [ ] Sensitive data not logged

---

## Common Pitfalls

### Pitfall 1: Forgetting userId Filter

**Problem**:
```dart
// ❌ VULNERABLE: Missing userId filter
Future<List<Note>> getAllNotes() async {
  return await (db.select(db.notes)
    ..where((n) => n.deleted.equals(false)))
    .get();
}
```

**Solution**:
```dart
// ✅ SECURE: Always include userId filter
Future<List<Note>> getAllNotes() async {
  final userId = _getCurrentUserId();
  _validateUserId(userId);

  return await (db.select(db.notes)
    ..where((n) => n.deleted.equals(false))
    ..where((n) => n.userId.equals(userId))) // REQUIRED!
    .get();
}
```

---

### Pitfall 2: Bypassing Repository Layer

**Problem**:
```dart
// ❌ VULNERABLE: Direct database access
class NoteService {
  Future<void> deleteNote(String noteId) async {
    await _db.deleteNoteById(noteId); // No userId check!
  }
}
```

**Solution**:
```dart
// ✅ SECURE: Use repository
class NoteService {
  Future<void> deleteNote(String noteId) async {
    await _repository.deleteNote(noteId); // Repository checks userId
  }
}
```

---

### Pitfall 3: Information Leakage in Errors

**Problem**:
```dart
// ❌ VULNERABLE: Error reveals entity existence
Future<Note?> getNoteById(String id) async {
  final note = await db.getNoteById(id);
  if (note.userId != currentUserId) {
    throw Exception('Note belongs to different user'); // Leaks information!
  }
  return note;
}
```

**Solution**:
```dart
// ✅ SECURE: Generic error message
Future<Note?> getNoteById(String id) async {
  final note = await (db.select(db.notes)
    ..where((n) => n.id.equals(id))
    ..where((n) => n.userId.equals(currentUserId)))
    .getSingleOrNull();

  return note; // null if not found OR unauthorized (don't leak info)
}
```

---

### Pitfall 4: Runtime userId Lookup in Tests

**Problem**:
```dart
// ❌ FRAGILE: Relies on global auth state
test('should create note', () async {
  final note = await repository.createNote('Title'); // Which user?
});
```

**Solution**:
```dart
// ✅ EXPLICIT: Mock authentication first
test('should create note', () async {
  await authenticateAs('user1'); // Explicit user context
  final note = await repository.createNote('Title');
  expect(note.userId, equals('user1'));
});
```

---

### Pitfall 5: Manual Provider Invalidation

**Problem**:
```dart
// ❌ FRAGILE: Easy to forget new providers
void onLogout() {
  ref.invalidate(notesProvider);
  ref.invalidate(tasksProvider);
  // Forgot to invalidate foldersProvider!
}
```

**Solution**:
```dart
// ✅ AUTOMATIC: Family providers auto-invalidate
final notesProvider = Provider.family<NotesRepo, String>((ref, userId) {
  return NotesRepo(userId: userId);
});

// When userId changes, ALL family providers auto-invalidate!
```

---

### Pitfall 6: Nullable userId in P2+

**Problem**:
```dart
// ❌ WRONG: P2 should have non-nullable userId
class LocalNote {
  final String? userId; // P2: Should be non-nullable!
}
```

**Solution**:
```dart
// ✅ CORRECT: P2 enforces non-null
class LocalNote {
  final String userId; // Required in P2+
}
```

---

## Conclusion

These patterns provide a comprehensive guide for implementing userId-based security in Duru Notes. Key principles:

1. **Defense-in-Depth**: Multiple layers validate userId
2. **Fail-Fast**: Validate early, fail early
3. **Secure-by-Default**: Make it hard to write insecure code
4. **Explicit is Better**: Inject userId, don't lookup at runtime
5. **Test Everything**: Security must be tested

**Next Steps**:
1. Use these templates when implementing P1-P3
2. Refer to patterns during code review
3. Update patterns as new scenarios emerge
4. Train team on security patterns
