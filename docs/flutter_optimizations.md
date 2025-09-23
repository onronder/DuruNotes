# Flutter Data Layer Optimization Recommendations

## 1. Drift Query Optimization

### Batch Operations for Better Performance
```dart
// Instead of individual operations
for (final task in tasks) {
  await db.updateTask(task);
}

// Use batch operations
await db.batch((batch) {
  for (final task in tasks) {
    batch.update(
      db.noteTasks,
      task.toCompanion(false),
      where: (t) => t.id.equals(task.id),
    );
  }
});
```

### Compiled Queries for Frequent Operations
```dart
// Define compiled queries in AppDb class
late final Selectable<NoteTask> _watchOpenTasksQuery = select(noteTasks)
  ..where((t) => t.status.equals(TaskStatus.open.index) & t.deleted.equals(false))
  ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]);

Stream<List<NoteTask>> watchOpenTasks() => _watchOpenTasksQuery.watch();
```

### Optimized Hierarchical Queries
```dart
// Use CTEs for hierarchical data
Future<List<TaskHierarchy>> getTaskHierarchy(String noteId) async {
  return customSelect('''
    WITH RECURSIVE task_hierarchy AS (
      SELECT *, 0 as level FROM note_tasks
      WHERE note_id = ? AND parent_task_id IS NULL AND deleted = 0

      UNION ALL

      SELECT t.*, h.level + 1 FROM note_tasks t
      JOIN task_hierarchy h ON t.parent_task_id = h.id
      WHERE t.deleted = 0
    )
    SELECT * FROM task_hierarchy ORDER BY level, position
  ''', variables: [Variable.withString(noteId)]).get();
}
```

## 2. State Management Optimization

### Selective Stream Subscriptions
```dart
class OptimizedTaskProvider extends StateNotifier<TaskState> {
  StreamSubscription<List<NoteTask>>? _taskSubscription;

  void watchTasksForNote(String noteId) {
    _taskSubscription?.cancel();

    // Only subscribe to specific note's tasks
    _taskSubscription = db.select(db.noteTasks)
      .where((t) => t.noteId.equals(noteId) & t.deleted.equals(false))
      .watch()
      .listen((tasks) {
        // Use freezed/immutable state updates
        state = state.copyWith(tasks: tasks);
      });
  }

  @override
  void dispose() {
    _taskSubscription?.cancel();
    super.dispose();
  }
}
```

### Efficient Riverpod Providers
```dart
// Use family providers for parameterized data
final tasksForNoteProvider = StreamProvider.family<List<NoteTask>, String>(
  (ref, noteId) {
    final db = ref.watch(databaseProvider);
    return db.watchTasksForNote(noteId);
  },
);

// Use autoDispose for memory efficiency
final taskProvider = StreamProvider.autoDispose.family<NoteTask?, String>(
  (ref, taskId) {
    final db = ref.watch(databaseProvider);
    return db.watchTask(taskId);
  },
);
```

## 3. Real-time Updates Without Performance Impact

### Debounced Sync Operations
```dart
class OptimizedSyncService {
  final Map<String, Timer?> _syncTimers = {};

  void scheduleSync(String noteId, String content) {
    _syncTimers[noteId]?.cancel();

    _syncTimers[noteId] = Timer(
      const Duration(milliseconds: 500),
      () => _performSync(noteId, content),
    );
  }

  Future<void> _performSync(String noteId, String content) async {
    // Use isolate for CPU-intensive operations
    final syncResult = await compute(_syncTasksInIsolate, SyncParams(
      noteId: noteId,
      content: content,
      existingTasks: await db.getTasksForNote(noteId),
    ));

    // Apply results in main isolate
    await _applySyncResults(syncResult);
  }
}

// Run in isolate to avoid blocking UI
static Future<SyncResult> _syncTasksInIsolate(SyncParams params) async {
  // Parse tasks and calculate changes without database access
  return SyncResult(/* ... */);
}
```

### Selective Widget Rebuilds
```dart
class TaskItemWidget extends ConsumerWidget {
  const TaskItemWidget({Key? key, required this.taskId}) : super(key: key);

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only rebuild when specific task changes
    final taskAsync = ref.watch(taskProvider(taskId));

    return taskAsync.when(
      data: (task) => task != null
        ? _buildTaskItem(task)
        : const SizedBox.shrink(),
      loading: () => const TaskItemSkeleton(),
      error: (_, __) => const TaskItemError(),
    );
  }
}
```

## 4. Memory Management for Large Datasets

### Lazy Loading with Pagination
```dart
class PaginatedTaskList extends ConsumerStatefulWidget {
  @override
  _PaginatedTaskListState createState() => _PaginatedTaskListState();
}

class _PaginatedTaskListState extends ConsumerState<PaginatedTaskList> {
  static const _pageSize = 50;
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(paginatedTasksProvider(_currentPage));

    return tasksAsync.when(
      data: (tasks) => ListView.builder(
        itemCount: tasks.length + 1, // +1 for loading indicator
        itemBuilder: (context, index) {
          if (index == tasks.length) {
            // Load more when reaching end
            return _buildLoadMoreButton();
          }
          return TaskItemWidget(taskId: tasks[index].id);
        },
      ),
      loading: () => const TaskListSkeleton(),
      error: (error, stack) => TaskListError(error: error),
    );
  }
}

final paginatedTasksProvider = FutureProvider.family<List<NoteTask>, int>(
  (ref, page) async {
    final db = ref.watch(databaseProvider);
    return db.getTasksPaginated(
      offset: page * _pageSize,
      limit: _pageSize,
    );
  },
);
```

### Efficient List Management
```dart
class VirtualizedTaskList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Use Slivers for efficient list rendering
        Consumer(
          builder: (context, ref, child) {
            final tasksAsync = ref.watch(allTasksProvider);

            return tasksAsync.when(
              data: (tasks) => SliverList.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  // Only build visible items
                  return TaskItemWidget(taskId: tasks[index].id);
                },
              ),
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => SliverFillRemaining(
                child: TaskListError(error: error),
              ),
            );
          },
        ),
      ],
    );
  }
}
```

## 5. Encrypted Data Handling Optimization

### Efficient Encryption/Decryption
```dart
class OptimizedEncryptionService {
  // Cache decrypted data with expiry
  final Map<String, CachedData> _decryptionCache = {};

  Future<String> decryptTitle(Uint8List encryptedTitle) async {
    final key = base64Encode(encryptedTitle);
    final cached = _decryptionCache[key];

    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    // Use isolate for CPU-intensive decryption
    final decrypted = await compute(_decryptInIsolate, encryptedTitle);

    _decryptionCache[key] = CachedData(
      data: decrypted,
      expiry: DateTime.now().add(const Duration(minutes: 5)),
    );

    return decrypted;
  }

  // Batch encryption for sync operations
  Future<List<EncryptedNote>> encryptNotes(List<LocalNote> notes) async {
    final chunks = _chunkList(notes, 10); // Process in chunks
    final results = <EncryptedNote>[];

    for (final chunk in chunks) {
      final encrypted = await compute(_encryptChunkInIsolate, chunk);
      results.addAll(encrypted);
    }

    return results;
  }
}

class CachedData {
  final String data;
  final DateTime expiry;

  CachedData({required this.data, required this.expiry});

  bool get isExpired => DateTime.now().isAfter(expiry);
}
```

## 6. Testing Strategies

### Unit Tests for Data Layer
```dart
void main() {
  group('AppDb Tests', () {
    late AppDb db;

    setUp(() async {
      db = AppDb.memory(); // In-memory database for tests
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('should create and retrieve task', (tester) async {
      final noteId = 'test-note-id';
      final taskContent = 'Test task content';

      final taskId = await db.createTask(NoteTasksCompanion.insert(
        noteId: noteId,
        content: taskContent,
        contentHash: generateHash(taskContent),
      ));

      final task = await db.getTaskById(taskId);
      expect(task, isNotNull);
      expect(task!.content, equals(taskContent));
    });
  });
}
```

### Widget Tests with Mock Data
```dart
void main() {
  group('TaskItemWidget Tests', () {
    testWidgets('should display task content correctly', (tester) async {
      final mockTask = NoteTask(
        id: 'test-id',
        noteId: 'note-id',
        content: 'Test Task',
        status: TaskStatus.open,
        // ... other fields
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskProvider('test-id').overrideWith(
              (ref) => Stream.value(mockTask),
            ),
          ],
          child: MaterialApp(
            home: TaskItemWidget(taskId: 'test-id'),
          ),
        ),
      );

      expect(find.text('Test Task'), findsOneWidget);
    });
  });
}
```

### Integration Tests for Sync
```dart
void main() {
  group('Sync Integration Tests', () {
    testWidgets('should sync tasks bidirectionally', (tester) async {
      final testBinding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

      // Test offline -> online sync
      await tester.pumpWidget(MyApp());

      // Create task offline
      await tester.tap(find.byKey(const Key('add_task_button')));
      await tester.enterText(find.byKey(const Key('task_input')), 'Test Task');
      await tester.tap(find.byKey(const Key('save_task_button')));

      // Simulate network coming online
      await testBinding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/connectivity',
        // ... connectivity change message
      );

      // Wait for sync to complete
      await tester.pumpAndSettle();

      // Verify task exists in remote database
      // ... verification logic
    });
  });
}
```

## 7. Performance Monitoring

### Custom Performance Metrics
```dart
class TaskSyncMetrics {
  static const _methodChannel = MethodChannel('app.duru.metrics');

  static void trackSyncPerformance({
    required String operation,
    required Duration duration,
    required int itemCount,
  }) {
    _methodChannel.invokeMethod('trackMetric', {
      'name': 'task_sync_performance',
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      'item_count': itemCount,
    });
  }

  static void trackMemoryUsage() {
    final info = ProcessInfo.currentRss;
    _methodChannel.invokeMethod('trackMetric', {
      'name': 'memory_usage',
      'rss_bytes': info,
    });
  }
}
```

These optimizations focus on Flutter-specific performance patterns while maintaining the robust architecture you've already built.