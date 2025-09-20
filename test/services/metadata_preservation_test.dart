import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/bidirectional_task_sync_service.dart';
import 'package:duru_notes/services/enhanced_bidirectional_sync.dart';
import 'package:duru_notes/services/task_service.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'dart:convert';

@GenerateMocks([
  AppDb,
  TaskService,
  AppLogger,
])
import 'metadata_preservation_test.mocks.dart';

void main() {
  late MockAppDb mockDb;
  late MockTaskService mockTaskService;
  late BidirectionalTaskSyncService bidirectionalSync;
  late EnhancedBidirectionalSync enhancedSync;
  
  setUp(() {
    mockDb = MockAppDb();
    mockTaskService = MockTaskService();
    
    bidirectionalSync = BidirectionalTaskSyncService(
      database: mockDb,
      taskService: mockTaskService,
    );
    
    enhancedSync = EnhancedBidirectionalSync(
      database: mockDb,
      taskService: mockTaskService,
    );
  });
  
  group('Metadata Preservation', () {
    test('should preserve labels when task content is edited', () async {
      const noteId = 'note-123';
      const taskId = 'task-456';
      const originalContent = '- [ ] Original task text';
      const updatedContent = '- [ ] Updated task text';
      
      final existingTask = NoteTask(
        id: taskId,
        noteId: noteId,
        content: 'Original task text',
        status: TaskStatus.open,
        priority: TaskPriority.medium,
        position: 0,
        contentHash: 'hash1',
        labels: jsonEncode(['important', 'work']),
        notes: 'Some notes about this task',
        estimatedMinutes: 30,
        reminderId: 42,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );
      
      final note = LocalNote(
        id: noteId,
        title: 'Test Note',
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
      
      // Verify that update was called with preserved metadata
      verify(mockTaskService.updateTask(
        taskId: taskId,
        content: 'Updated task text',
        status: TaskStatus.open,
        labels: {'labels': ['important', 'work']},
        notes: 'Some notes about this task',
        estimatedMinutes: 30,
        reminderId: 42,
      )).called(1);
    });
    
    test('should preserve reminder when task is moved', () async {
      const noteId = 'note-789';
      const taskId = 'task-abc';
      
      final existingTask = NoteTask(
        id: taskId,
        noteId: noteId,
        content: 'Task to move',
        status: TaskStatus.open,
        priority: TaskPriority.high,
        position: 2, // Original position
        contentHash: 'hash1',
        reminderId: 99,
        dueDate: DateTime.now().add(const Duration(days: 1)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );
      
      // Task moved to different position
      const updatedContent = '''
- [ ] Some other task
- [ ] Another task
- [ ] Yet another task
- [ ] Task to move
- [ ] Final task
''';
      
      final note = LocalNote(
        id: noteId,
        title: 'Test Note',
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
      
      // Mock task creation for new tasks
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
      )).thenAnswer((_) async => 'new-task-id');
      
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
      
      // Sync with moved task
      await bidirectionalSync.syncFromNoteToTasks(noteId, updatedContent);
      
      // Verify reminder was preserved despite position change
      verify(mockTaskService.updateTask(
        taskId: taskId,
        content: 'Task to move',
        status: TaskStatus.open,
        reminderId: 99,
      )).called(1);
    });
    
    test('should preserve time estimates when task is marked complete', () async {
      const noteId = 'note-def';
      const taskId = 'task-ghi';
      
      final existingTask = NoteTask(
        id: taskId,
        noteId: noteId,
        content: 'Task with estimate',
        status: TaskStatus.open,
        priority: TaskPriority.medium,
        position: 0,
        contentHash: 'hash1',
        estimatedMinutes: 45,
        actualMinutes: 30,
        notes: 'Implementation details',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );
      
      // Task marked as complete
      const updatedContent = '- [x] Task with estimate';
      
      final note = LocalNote(
        id: noteId,
        title: 'Test Note',
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
      
      // Sync with completed task
      await bidirectionalSync.syncFromNoteToTasks(noteId, updatedContent);
      
      // Verify time estimates were preserved
      verify(mockTaskService.updateTask(
        taskId: taskId,
        content: 'Task with estimate',
        status: TaskStatus.completed,
        estimatedMinutes: 45,
        actualMinutes: 30,
        notes: 'Implementation details',
      )).called(1);
    });
    
    test('should match tasks with minor text changes', () async {
      const noteId = 'note-match';
      const taskId = 'task-match';
      
      final existingTask = NoteTask(
        id: taskId,
        noteId: noteId,
        content: 'Buy milk and bread',
        status: TaskStatus.open,
        priority: TaskPriority.medium,
        position: 0,
        contentHash: 'hash1',
        labels: jsonEncode(['shopping']),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );
      
      // Minor text change
      const updatedContent = '- [ ] Buy milk and bread from store';
      
      final note = LocalNote(
        id: noteId,
        title: 'Shopping',
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
      
      // Sync with slightly modified content
      await bidirectionalSync.syncFromNoteToTasks(noteId, updatedContent);
      
      // Verify task was matched and labels preserved
      verify(mockTaskService.updateTask(
        taskId: taskId,
        content: 'Buy milk and bread from store',
        status: TaskStatus.open,
        labels: {'labels': ['shopping']},
      )).called(1);
    });
  });
  
  group('Enhanced Sync with ID Embedding', () {
    test('should embed task IDs in note content', () async {
      const noteId = 'note-embed';
      const originalContent = '''
- [ ] Task 1
- [ ] Task 2
- [ ] Task 3
''';
      
      final note = LocalNote(
        id: noteId,
        title: 'Test',
        body: originalContent,
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
      
      // Mock note update to capture embedded content
      String? capturedContent;
      when(mockDb.updateNote(
        any,
        any,
      )).thenAnswer((invocation) async {
        final companion = invocation.positionalArguments[1] as LocalNotesCompanion;
        if (companion.body.present) {
          capturedContent = companion.body.value;
        }
      });
      
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
      
      // Initialize enhanced sync
      await enhancedSync.initializeSync(noteId);
      
      // Verify IDs were embedded
      expect(capturedContent, isNotNull);
      expect(capturedContent!, contains('<!-- task-id:'));
      
      // Each task should have an embedded ID
      final lines = capturedContent!.split('\n');
      int embeddedCount = 0;
      for (final line in lines) {
        if (line.contains('<!-- task-id:')) {
          embeddedCount++;
        }
      }
      expect(embeddedCount, equals(3));
    });
    
    test('should use embedded IDs for stable tracking', () async {
      const noteId = 'note-stable';
      const embeddedContent = '''
- [ ] Task A <!-- task-id:abc123 -->
- [ ] Task B <!-- task-id:def456 -->
- [ ] Task C <!-- task-id:ghi789 -->
''';
      
      // Simulate tasks being reordered
      const reorderedContent = '''
- [ ] Task C <!-- task-id:ghi789 -->
- [ ] Task A <!-- task-id:abc123 -->
- [ ] Task B <!-- task-id:def456 -->
''';
      
      final existingTasks = [
        NoteTask(
          id: 'abc123',
          noteId: noteId,
          content: 'Task A',
          status: TaskStatus.open,
          priority: TaskPriority.medium,
          position: 0,
          contentHash: 'hash1',
          labels: jsonEncode(['labelA']),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
        ),
        NoteTask(
          id: 'def456',
          noteId: noteId,
          content: 'Task B',
          status: TaskStatus.open,
          priority: TaskPriority.medium,
          position: 1,
          contentHash: 'hash2',
          labels: jsonEncode(['labelB']),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
        ),
        NoteTask(
          id: 'ghi789',
          noteId: noteId,
          content: 'Task C',
          status: TaskStatus.open,
          priority: TaskPriority.medium,
          position: 2,
          contentHash: 'hash3',
          labels: jsonEncode(['labelC']),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
        ),
      ];
      
      when(mockDb.getTasksForNote(noteId)).thenAnswer((_) async => existingTasks);
      
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
      
      // Sync with reordered tasks
      await enhancedSync.syncFromNoteToTasks(noteId, reorderedContent);
      
      // Verify all tasks were matched by their embedded IDs
      // and labels were preserved despite reordering
      verify(mockTaskService.updateTask(
        taskId: 'abc123',
        content: 'Task A',
        labels: {'labels': ['labelA']},
      )).called(1);
      
      verify(mockTaskService.updateTask(
        taskId: 'def456',
        content: 'Task B',
        labels: {'labels': ['labelB']},
      )).called(1);
      
      verify(mockTaskService.updateTask(
        taskId: 'ghi789',
        content: 'Task C',
        labels: {'labels': ['labelC']},
      )).called(1);
    });
  });
  
  group('Content Similarity', () {
    test('should calculate correct similarity scores', () {
      final sync = bidirectionalSync;
      
      // Identical strings
      expect(
        sync.calculateContentSimilarity('Hello world', 'Hello world'),
        equals(1.0),
      );
      
      // Case insensitive
      expect(
        sync.calculateContentSimilarity('Hello World', 'hello world'),
        equals(1.0),
      );
      
      // Partial match
      expect(
        sync.calculateContentSimilarity('Buy milk', 'Buy milk and bread'),
        greaterThan(0.5),
      );
      
      // No match
      expect(
        sync.calculateContentSimilarity('Apple', 'Orange'),
        equals(0.0),
      );
      
      // Empty strings
      expect(
        sync.calculateContentSimilarity('', ''),
        equals(0.0),
      );
    });
  });
}
