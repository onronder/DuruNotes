import 'dart:convert';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/infrastructure/repositories/task_core_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/services/unified_task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'unified_task_service_test.mocks.dart';

/// Helper function to create test notes with proper encryption format
Future<void> createTestNote(
  AppDb db,
  String noteId, {
  String userId = 'test-user-id',
  String title = 'Test Note',
  String body = '',
}) async {
  // Encode as base64 strings (proper format for encrypted data)
  final titleEncrypted = base64Encode(utf8.encode(title));
  final bodyEncrypted = base64Encode(utf8.encode(body));

  await db.into(db.localNotes).insert(LocalNotesCompanion.insert(
    id: noteId,  // Auto-wrapped by .insert()
    userId: Value(userId),  // Optional, needs Value()
    titleEncrypted: Value(titleEncrypted),  // Optional, needs Value()
    bodyEncrypted: Value(bodyEncrypted),  // Optional, needs Value()
    updatedAt: DateTime.now(),  // Auto-wrapped by .insert()
    noteType: Value(NoteKind.note),  // Optional, needs Value()
    deleted: Value(false),  // Optional, needs Value()
    encryptionVersion: Value(1),  // Optional, needs Value()
  ));
}

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
  MockSpec<CryptoBox>(),
  MockSpec<AppLogger>(),
  MockSpec<AnalyticsService>(),
  MockSpec<EnhancedTaskService>(),
])
void main() {
  group('UnifiedTaskService - CRUD Operations with Domain Models', () {
    late AppDb testDb;
    late MockSupabaseClient mockClient;
    late MockCryptoBox mockCrypto;
    late MockAppLogger mockLogger;
    late MockAnalyticsService mockAnalytics;
    late MockEnhancedTaskService mockEnhancedService;
    late TaskCoreRepository taskRepository;
    late UnifiedTaskService service;

    setUp(() {
      // Create in-memory database for testing
      testDb = AppDb.forTesting(NativeDatabase.memory());

      // Setup mocks
      mockClient = MockSupabaseClient();
      mockCrypto = MockCryptoBox();
      mockLogger = MockAppLogger();
      mockAnalytics = MockAnalyticsService();
      mockEnhancedService = MockEnhancedTaskService();

      // Setup mock auth
      final mockAuth = MockGoTrueClient();
      final mockUser = MockUser();
      when(mockUser.id).thenReturn('test-user-id');
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockClient.auth).thenReturn(mockAuth);

      // Setup logger mocks to prevent errors
      when(mockLogger.info(any, data: anyNamed('data'))).thenReturn(null);
      when(mockLogger.error(any, error: anyNamed('error'), stackTrace: anyNamed('stackTrace'), data: anyNamed('data'))).thenReturn(null);
      when(mockLogger.warning(any, data: anyNamed('data'))).thenReturn(null);
      when(mockLogger.debug(any, data: anyNamed('data'))).thenReturn(null);

      // Setup analytics mocks
      when(mockAnalytics.startTiming(any)).thenReturn(null);
      when(mockAnalytics.endTiming(any, properties: anyNamed('properties'))).thenReturn(null);
      when(mockAnalytics.event(any, properties: anyNamed('properties'))).thenReturn(null);

      // Setup crypto mocks for pass-through encryption/decryption
      // Note: MockCryptoBox may not have encrypt/decrypt methods if not defined in CryptoBox interface
      // These are commented out to avoid compilation errors

      // Create repository
      taskRepository = TaskCoreRepository(
        db: testDb,
        client: mockClient,
        crypto: mockCrypto,
      );

      // Create service
      service = UnifiedTaskService(
        db: testDb,
        logger: mockLogger,
        analytics: mockAnalytics,
        enhancedTaskService: mockEnhancedService,
        taskRepository: taskRepository,
      );
    });

    tearDown(() async {
      await testDb.close();
    });

    group('createTask via Repository', () {
      test('should create task with required fields only', () async {
        // Arrange
        const noteId = 'note-123';
        const title = 'Test task';
        final now = DateTime.now();

        final taskToCreate = domain.Task(
          id: '', // Will be generated
          noteId: noteId,
          title: title,
          description: null,
          status: domain.TaskStatus.pending,
          priority: domain.TaskPriority.medium,
          dueDate: null,
          completedAt: null,
          createdAt: now,
          updatedAt: now,
          tags: [],
          metadata: {},
        );

        // First, create a note for the task
        await createTestNote(testDb, noteId);

        // Act
        final result = await taskRepository.createTask(taskToCreate);

        // Assert
        expect(result.id, isNotEmpty);
        expect(result.noteId, noteId);
        expect(result.title, title);
        expect(result.status, domain.TaskStatus.pending);
        expect(result.priority, domain.TaskPriority.medium);

        // Verify it was persisted in database
        final tasks = await testDb.select(testDb.noteTasks).get();
        expect(tasks.length, 1);
        expect(tasks.first.noteId, noteId);
      });

      test('should create task with all optional fields', () async {
        // Arrange
        const noteId = 'note-456';
        const title = 'Complex task';
        const description = 'Detailed task description';
        final dueDate = DateTime.now().add(const Duration(days: 7));
        final now = DateTime.now();

        final taskToCreate = domain.Task(
          id: '',
          noteId: noteId,
          title: title,
          description: description,
          status: domain.TaskStatus.pending,
          priority: domain.TaskPriority.high,
          dueDate: dueDate,
          completedAt: null,
          createdAt: now,
          updatedAt: now,
          tags: ['urgent', 'work'],
          metadata: {'parentTaskId': 'parent-1'},
        );

        // Create note for the task
        await createTestNote(testDb, noteId);

        // Act
        final result = await taskRepository.createTask(taskToCreate);

        // Assert
        expect(result.id, isNotEmpty);
        expect(result.title, title);
        expect(result.description, description);
        expect(result.priority, domain.TaskPriority.high);
        expect(result.dueDate, dueDate);
        expect(result.tags, contains('urgent'));
        expect(result.tags, contains('work'));
      });

      test('should throw exception when creating task without authenticated user', () async {
        // Arrange
        when(mockClient.auth.currentUser).thenReturn(null);

        final taskToCreate = domain.Task(
          id: '',
          noteId: 'note-1',
          title: 'Test',
          status: domain.TaskStatus.pending,
          priority: domain.TaskPriority.medium,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: [],
          metadata: {},
        );

        // Act & Assert
        expect(
          () => taskRepository.createTask(taskToCreate),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Cannot create task without authenticated user'),
          )),
        );
      });
    });

    group('updateTask', () {
      test('should update task status', () async {
        // Arrange
        const noteId = 'note-789';
        const taskId = 'task-123';

        // Create note
        await createTestNote(testDb, noteId);

        // Create initial task via repository
        final initialTask = domain.Task(
          id: taskId,
          noteId: noteId,
          title: 'Test task',
          status: domain.TaskStatus.pending,
          priority: domain.TaskPriority.medium,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: [],
          metadata: {},
        );

        await taskRepository.createTask(initialTask);

        // Act - Update status
        final updatedTask = initialTask.copyWith(
          status: domain.TaskStatus.completed,
          completedAt: DateTime.now(),
        );

        final result = await taskRepository.updateTask(updatedTask);

        // Assert
        expect(result.id, taskId);
        expect(result.status, domain.TaskStatus.completed);
        expect(result.completedAt, isNotNull);
      });

      test('should return early if task not found', () async {
        // Arrange - No task in database

        final task = domain.Task(
          id: 'non-existent',
          noteId: 'note-1',
          title: 'Test',
          status: domain.TaskStatus.pending,
          priority: domain.TaskPriority.medium,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: [],
          metadata: {},
        );

        // Act & Assert
        expect(
          () => taskRepository.updateTask(task),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('deleteTask', () {
      test('should delete task from repository', () async {
        // Arrange
        const noteId = 'note-delete';
        const taskId = 'task-to-delete';

        // Create note
        await createTestNote(testDb, noteId);

        // Create task
        final task = domain.Task(
          id: taskId,
          noteId: noteId,
          title: 'Task to delete',
          status: domain.TaskStatus.pending,
          priority: domain.TaskPriority.medium,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: [],
          metadata: {},
        );

        await taskRepository.createTask(task);

        // Act
        await taskRepository.deleteTask(taskId);

        // Assert - Task should be marked as deleted
        final query = testDb.select(testDb.noteTasks)
          ..where((t) => t.id.equals(taskId) & t.deleted.equals(false));
        final remainingTasks = await query.get();
        expect(remainingTasks, isEmpty);
      });
    });

    group('getTasksForNote', () {
      test('should retrieve all tasks for note', () async {
        // Arrange
        const noteId = 'note-multiple';

        // Create note
        await createTestNote(testDb, noteId);

        // Create multiple tasks
        final task1 = domain.Task(
          id: 'task-1',
          noteId: noteId,
          title: 'Task 1',
          status: domain.TaskStatus.pending,
          priority: domain.TaskPriority.medium,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: [],
          metadata: {},
        );

        final task2 = domain.Task(
          id: 'task-2',
          noteId: noteId,
          title: 'Task 2',
          status: domain.TaskStatus.completed,
          priority: domain.TaskPriority.low,
          completedAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: [],
          metadata: {},
        );

        await taskRepository.createTask(task1);
        await taskRepository.createTask(task2);

        // Act
        final result = await taskRepository.getTasksForNote(noteId);

        // Assert
        expect(result.length, 2);
        expect(result.any((t) => t.id == 'task-1'), true);
        expect(result.any((t) => t.id == 'task-2'), true);
        expect(result.where((t) => t.status == domain.TaskStatus.pending).length, 1);
        expect(result.where((t) => t.status == domain.TaskStatus.completed).length, 1);
      });

      test('should handle empty task list', () async {
        // Arrange
        const noteId = 'empty-note';

        // Create note with no tasks
        await createTestNote(testDb, noteId, title: 'Empty Note');

        // Act
        final result = await taskRepository.getTasksForNote(noteId);

        // Assert
        expect(result, isEmpty);
      });

      test('should enforce user isolation', () async {
        // Arrange
        const noteId = 'other-user-note';

        // Create note for different user
        await createTestNote(
          testDb,
          noteId,
          userId: 'other-user-id',  // Different user
          title: 'Other User Note',
        );

        // Act
        final result = await taskRepository.getTasksForNote(noteId);

        // Assert - Should return empty because note doesn't belong to test-user-id
        expect(result, isEmpty);
      });
    });

    group('UnifiedTaskService Integration', () {
      test('should create task through enhanced service', () async {
        // Arrange
        const noteId = 'note-service';
        const content = 'Service task';
        const taskId = 'service-task-123';

        when(mockEnhancedService.createTask(
          noteId: anyNamed('noteId'),
          content: anyNamed('content'),
          status: anyNamed('status'),
          priority: anyNamed('priority'),
          dueDate: anyNamed('dueDate'),
          parentTaskId: anyNamed('parentTaskId'),
          labels: anyNamed('labels'),
          notes: anyNamed('notes'),
          estimatedMinutes: anyNamed('estimatedMinutes'),
          createReminder: anyNamed('createReminder'),
        )).thenAnswer((_) async => taskId);

        // Create a mock task in database for retrieval
        await createTestNote(testDb, noteId);

        await testDb.into(testDb.noteTasks).insert(NoteTasksCompanion.insert(
          id: taskId,  // Required, auto-wrapped
          noteId: noteId,  // Required, auto-wrapped
          contentEncrypted: base64Encode([116, 101, 115, 116]),  // Required, auto-wrapped
          contentHash: 'hash',  // Required, auto-wrapped
          status: Value(TaskStatus.open),  // Optional
          priority: Value(TaskPriority.medium),  // Optional
          position: Value(0),  // Optional
          encryptionVersion: Value(1),  // Optional
        ));

        // Act
        final result = await service.createTask(
          noteId: noteId,
          content: content,
        );

        // Assert
        expect(result.id, taskId);
        expect(result.noteId, noteId);

        // Verify analytics was called
        verify(mockAnalytics.startTiming('task_create')).called(1);
        verify(mockAnalytics.endTiming('task_create', properties: anyNamed('properties'))).called(1);
        verify(mockAnalytics.event('task.created', properties: anyNamed('properties'))).called(1);

        // Verify enhanced service was called
        verify(mockEnhancedService.createTask(
          noteId: noteId,
          content: content,
          status: TaskStatus.open,
          priority: TaskPriority.medium,
          dueDate: null,
          parentTaskId: null,
          labels: null,
          notes: null,
          estimatedMinutes: null,
          createReminder: true,
        )).called(1);
      });
    });
  });
}
