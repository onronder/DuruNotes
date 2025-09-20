import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/bidirectional_task_sync_service.dart';
import 'package:duru_notes/services/task_service.dart';
import 'package:duru_notes/services/note_task_coordinator.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/monitoring/task_sync_metrics.dart';

@GenerateMocks([
  AppDb,
  TaskService,
  AppLogger,
])
import 'no_duplicate_tasks_test.mocks.dart';

void main() {
  late MockAppDb mockDb;
  late MockTaskService mockTaskService;
  late BidirectionalTaskSyncService bidirectionalSync;
  late NoteTaskCoordinator coordinator;
  
  setUp(() {
    mockDb = MockAppDb();
    mockTaskService = MockTaskService();
    
    bidirectionalSync = BidirectionalTaskSyncService(
      database: mockDb,
      taskService: mockTaskService,
    );
    
    coordinator = NoteTaskCoordinator(
      database: mockDb,
      bidirectionalSync: bidirectionalSync,
    );
    
    // Clear metrics before each test
    TaskSyncMetrics.instance.clearMetrics();
  });
  
  group('No Duplicate Tasks', () {
    test('should not create duplicate tasks when opening note with tasks', () async {
      const noteId = 'note-123';
      const noteContent = '''
# My Note
- [ ] Task 1
- [x] Task 2
- [ ] Task 3
''';
      
      final note = LocalNote(
        id: noteId,
        title: 'My Note',
        body: noteContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isDeleted: false,
        deletedAt: null,
        syncStatus: 'synced',
        lastSyncedAt: DateTime.now(),
        version: 1,
        conflictResolution: null,
        deviceId: 'device-1',
        userId: 'user-1',
        isArchived: false,
        archivedAt: null,
        colorHex: null,
        backgroundHex: null,
        fontSize: null,
        fontFamily: null,
        reminderTime: null,
        reminderStatus: null,
        reminderError: null,
        reminderType: null,
        reminderMetadata: null,
      );
      
      // Mock database responses
      when(mockDb.getNote(noteId)).thenAnswer((_) async => note);
      when(mockDb.watchNote(noteId)).thenAnswer((_) => Stream.value(note));
      when(mockDb.getTasksForNote(noteId)).thenAnswer((_) async => []);
      
      // Mock task creation
      when(mockTaskService.createTask(
        noteId: anyNamed('noteId'),
        content: anyNamed('content'),
        status: anyNamed('status'),
        priority: anyNamed('priority'),
        position: anyNamed('position'),
        dueDate: anyNamed('dueDate'),
        parentTaskId: anyNamed('parentTaskId'),
        labels: anyNamed('labels'),
        notes: anyNamed('notes'),
        estimatedMinutes: anyNamed('estimatedMinutes'),
      )).thenAnswer((invocation) async {
        final content = invocation.namedArguments[#content] as String;
        final position = invocation.namedArguments[#position] as int;
        return 'task_${noteId}_${position}_${content.hashCode}';
      });
      
      // Start watching note (simulates opening note in editor)
      await coordinator.startWatchingNote(noteId);
      
      // Wait for initial sync
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify tasks were created exactly once
      verify(mockTaskService.createTask(
        noteId: noteId,
        content: 'Task 1',
        status: any,
        priority: any,
        position: any,
      )).called(1);
      
      verify(mockTaskService.createTask(
        noteId: noteId,
        content: 'Task 2',
        status: any,
        priority: any,
        position: any,
      )).called(1);
      
      verify(mockTaskService.createTask(
        noteId: noteId,
        content: 'Task 3',
        status: any,
        priority: any,
        position: any,
      )).called(1);
      
      // Check metrics
      final metrics = TaskSyncMetrics.instance.getHealthMetrics();
      expect(metrics['totalDuplicatesFound'], equals(0));
      
      // Clean up
      await coordinator.stopWatchingNote(noteId);
    });
    
    test('should not create duplicate when rapidly opening/closing note', () async {
      const noteId = 'note-456';
      const noteContent = '- [ ] Single task';
      
      final note = LocalNote(
        id: noteId,
        title: 'Test',
        body: noteContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isDeleted: false,
        deletedAt: null,
        syncStatus: 'synced',
        lastSyncedAt: DateTime.now(),
        version: 1,
        conflictResolution: null,
        deviceId: 'device-1',
        userId: 'user-1',
        isArchived: false,
        archivedAt: null,
        colorHex: null,
        backgroundHex: null,
        fontSize: null,
        fontFamily: null,
        reminderTime: null,
        reminderStatus: null,
        reminderError: null,
        reminderType: null,
        reminderMetadata: null,
      );
      
      when(mockDb.getNote(noteId)).thenAnswer((_) async => note);
      when(mockDb.watchNote(noteId)).thenAnswer((_) => Stream.value(note));
      when(mockDb.getTasksForNote(noteId)).thenAnswer((_) async => []);
      
      when(mockTaskService.createTask(
        noteId: anyNamed('noteId'),
        content: anyNamed('content'),
        status: anyNamed('status'),
        priority: anyNamed('priority'),
        position: anyNamed('position'),
        dueDate: anyNamed('dueDate'),
        parentTaskId: anyNamed('parentTaskId'),
        labels: anyNamed('labels'),
        notes: anyNamed('notes'),
        estimatedMinutes: anyNamed('estimatedMinutes'),
      )).thenAnswer((_) async => 'task-single');
      
      // Rapidly open and close note multiple times
      for (int i = 0; i < 5; i++) {
        await coordinator.startWatchingNote(noteId);
        await Future.delayed(const Duration(milliseconds: 10));
        await coordinator.stopWatchingNote(noteId);
      }
      
      // Wait for any pending operations
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Verify task was created only once
      verify(mockTaskService.createTask(
        noteId: noteId,
        content: 'Single task',
        status: any,
        priority: any,
        position: any,
      )).called(1);
      
      // Check no duplicates were detected
      final metrics = TaskSyncMetrics.instance.getHealthMetrics();
      expect(metrics['totalDuplicatesFound'], equals(0));
    });
    
    test('should use stable IDs based on content hash', () async {
      const noteId = 'note-789';
      const content1 = '- [ ] Task with specific content';
      const content2 = '- [ ] Another task';
      
      // Generate expected IDs
      final expectedId1 = bidirectionalSync.generateStableTaskId(
        noteId: noteId,
        content: 'Task with specific content',
        lineNumber: 0,
      );
      
      final expectedId2 = bidirectionalSync.generateStableTaskId(
        noteId: noteId,
        content: 'Another task',
        lineNumber: 1,
      );
      
      // IDs should be deterministic
      final regeneratedId1 = bidirectionalSync.generateStableTaskId(
        noteId: noteId,
        content: 'Task with specific content',
        lineNumber: 0,
      );
      
      expect(regeneratedId1, equals(expectedId1));
      expect(expectedId1, isNot(equals(expectedId2)));
      
      // IDs should be valid and consistent format
      expect(expectedId1, matches(RegExp(r'^[a-f0-9\-]+$')));
      expect(expectedId2, matches(RegExp(r'^[a-f0-9\-]+$')));
    });
    
    test('should handle task updates without creating duplicates', () async {
      const noteId = 'note-update';
      const initialContent = '- [ ] Original task';
      const updatedContent = '- [x] Original task';
      
      final existingTask = NoteTask(
        id: 'existing-task-id',
        noteId: noteId,
        content: 'Original task',
        status: TaskStatus.open,
        priority: TaskPriority.medium,
        position: 0,
        contentHash: 'hash1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );
      
      final note = LocalNote(
        id: noteId,
        title: 'Test',
        body: updatedContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isDeleted: false,
        deletedAt: null,
        syncStatus: 'synced',
        lastSyncedAt: DateTime.now(),
        version: 1,
        conflictResolution: null,
        deviceId: 'device-1',
        userId: 'user-1',
        isArchived: false,
        archivedAt: null,
        colorHex: null,
        backgroundHex: null,
        fontSize: null,
        fontFamily: null,
        reminderTime: null,
        reminderStatus: null,
        reminderError: null,
        reminderType: null,
        reminderMetadata: null,
      );
      
      when(mockDb.getNote(noteId)).thenAnswer((_) async => note);
      when(mockDb.getTasksForNote(noteId)).thenAnswer((_) async => [existingTask]);
      
      when(mockTaskService.updateTask(
        taskId: anyNamed('taskId'),
        content: anyNamed('content'),
        status: anyNamed('status'),
        priority: anyNamed('priority'),
        dueDate: anyNamed('dueDate'),
        labels: anyNamed('labels'),
        notes: anyNamed('notes'),
        estimatedMinutes: anyNamed('estimatedMinutes'),
        actualMinutes: anyNamed('actualMinutes'),
        completedAt: anyNamed('completedAt'),
        reminderId: anyNamed('reminderId'),
        clearReminderId: anyNamed('clearReminderId'),
      )).thenAnswer((_) async {});
      
      // Sync the updated content
      await bidirectionalSync.syncFromNoteToTasks(noteId, updatedContent);
      
      // Verify update was called, not create
      verify(mockTaskService.updateTask(
        taskId: existingTask.id,
        content: any,
        status: TaskStatus.completed,
      )).called(1);
      
      verifyNever(mockTaskService.createTask(
        noteId: any,
        content: any,
        status: any,
        priority: any,
        position: any,
      ));
      
      // Check no duplicates
      final metrics = TaskSyncMetrics.instance.getHealthMetrics();
      expect(metrics['totalDuplicatesFound'], equals(0));
    });
    
    test('should detect and report duplicate attempts', () async {
      const noteId = 'note-dup';
      const noteContent = '''
- [ ] Task 1
- [ ] Task 1
'''; // Intentional duplicate
      
      final note = LocalNote(
        id: noteId,
        title: 'Test',
        body: noteContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isDeleted: false,
        deletedAt: null,
        syncStatus: 'synced',
        lastSyncedAt: DateTime.now(),
        version: 1,
        conflictResolution: null,
        deviceId: 'device-1',
        userId: 'user-1',
        isArchived: false,
        archivedAt: null,
        colorHex: null,
        backgroundHex: null,
        fontSize: null,
        fontFamily: null,
        reminderTime: null,
        reminderStatus: null,
        reminderError: null,
        reminderType: null,
        reminderMetadata: null,
      );
      
      when(mockDb.getNote(noteId)).thenAnswer((_) async => note);
      when(mockDb.getTasksForNote(noteId)).thenAnswer((_) async => []);
      
      when(mockTaskService.createTask(
        noteId: anyNamed('noteId'),
        content: anyNamed('content'),
        status: anyNamed('status'),
        priority: anyNamed('priority'),
        position: anyNamed('position'),
        dueDate: anyNamed('dueDate'),
        parentTaskId: anyNamed('parentTaskId'),
        labels: anyNamed('labels'),
        notes: anyNamed('notes'),
        estimatedMinutes: anyNamed('estimatedMinutes'),
      )).thenAnswer((_) async => 'task-id');
      
      // Sync with duplicate content
      await bidirectionalSync.syncFromNoteToTasks(noteId, noteContent);
      
      // Check metrics detected the duplicate
      final noteMetrics = TaskSyncMetrics.instance.getNoteMetrics(noteId);
      expect(noteMetrics['duplicatesFound'], greaterThan(0));
      
      // Tasks should still be created (with different IDs due to line numbers)
      verify(mockTaskService.createTask(
        noteId: noteId,
        content: 'Task 1',
        status: any,
        priority: any,
        position: any,
      )).called(2); // Both tasks created despite same content
    });
  });
  
  group('Performance', () {
    test('should complete sync quickly for large notes', () async {
      const noteId = 'note-perf';
      
      // Generate a large note with many tasks
      final tasks = List.generate(100, (i) => '- [ ] Task $i').join('\n');
      final noteContent = '# Large Note\n$tasks';
      
      final note = LocalNote(
        id: noteId,
        title: 'Large Note',
        body: noteContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isDeleted: false,
        deletedAt: null,
        syncStatus: 'synced',
        lastSyncedAt: DateTime.now(),
        version: 1,
        conflictResolution: null,
        deviceId: 'device-1',
        userId: 'user-1',
        isArchived: false,
        archivedAt: null,
        colorHex: null,
        backgroundHex: null,
        fontSize: null,
        fontFamily: null,
        reminderTime: null,
        reminderStatus: null,
        reminderError: null,
        reminderType: null,
        reminderMetadata: null,
      );
      
      when(mockDb.getNote(noteId)).thenAnswer((_) async => note);
      when(mockDb.getTasksForNote(noteId)).thenAnswer((_) async => []);
      when(mockTaskService.createTask(
        noteId: anyNamed('noteId'),
        content: anyNamed('content'),
        status: anyNamed('status'),
        priority: anyNamed('priority'),
        position: anyNamed('position'),
        dueDate: anyNamed('dueDate'),
        parentTaskId: anyNamed('parentTaskId'),
        labels: anyNamed('labels'),
        notes: anyNamed('notes'),
        estimatedMinutes: anyNamed('estimatedMinutes'),
      )).thenAnswer((_) async => 'task-id');
      
      final stopwatch = Stopwatch()..start();
      await bidirectionalSync.syncFromNoteToTasks(noteId, noteContent);
      stopwatch.stop();
      
      // Should complete within reasonable time
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      
      // Check performance metrics
      final perfStats = TaskSyncMetrics.instance.getPerformanceStats();
      expect(perfStats['maxDuration'], lessThan(1000));
    });
  });
}
