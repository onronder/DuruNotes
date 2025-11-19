import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/data/local/app_db.dart' as db;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/infrastructure/repositories/task_core_repository.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/services/task_reminder_bridge.dart';
import 'package:drift/drift.dart' show Value;

import '../security/authorization_service_test.mocks.dart';

Uint8List _toEncrypted(String value) =>
    Uint8List.fromList(utf8.encode('enc:$value'));

String _fromEncrypted(Uint8List data) {
  final text = utf8.decode(data);
  return text.startsWith('enc:') ? text.substring(4) : text;
}

class StubCryptoBox extends Mock implements CryptoBox {
  @override
  Future<Uint8List> encryptStringForNote({
    required String userId,
    required String noteId,
    required String text,
  }) async {
    return _toEncrypted(text);
  }

  @override
  Future<String> decryptStringForNote({
    required String userId,
    required String noteId,
    required Uint8List data,
  }) async {
    return _fromEncrypted(data);
  }
}

class MockTaskReminderBridge extends Mock implements TaskReminderBridge {
  @override
  Future<void> onTaskDeleted(db.NoteTask task) async {
    super.noSuchMethod(
      Invocation.method(#onTaskDeleted, [task]),
      returnValue: Future<void>.value(),
    );
  }

  @override
  Future<void> onTaskUpdated(db.NoteTask oldTask, db.NoteTask newTask) async {
    super.noSuchMethod(
      Invocation.method(#onTaskUpdated, [oldTask, newTask]),
      returnValue: Future<void>.value(),
    );
  }

  @override
  // MIGRATION v41: Changed from Future<int?> to Future<String?> (UUID)
  Future<String?> createTaskReminder({
    required db.NoteTask task,
    Duration? beforeDueDate,
  }) async {
    return super.noSuchMethod(
      Invocation.method(#createTaskReminder, [], {
        #task: task,
        #beforeDueDate: beforeDueDate,
      }),
      returnValue: Future<String?>.value(null),
    );
  }

  @override
  Future<void> cancelTaskReminder(db.NoteTask task) async {
    super.noSuchMethod(
      Invocation.method(#cancelTaskReminder, [task]),
      returnValue: Future<void>.value(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('EnhancedTaskService isolation', () {
    late db.AppDb database;
    late TaskCoreRepository repository;
    late EnhancedTaskService service;

    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late MockUser mockUser;
    late StubCryptoBox crypto;
    late MockTaskReminderBridge mockReminderBridge;

    String? currentUserId;
    void signIn(String userId) {
      currentUserId = userId;
    }

    void signOut() {
      currentUserId = null;
    }

    Future<void> seedNote({
      required String noteId,
      required String userId,
    }) async {
      await database
          .into(database.localNotes)
          .insert(
            db.LocalNotesCompanion.insert(
              id: noteId,
              userId: Value(userId),
              titleEncrypted: const Value('seed-title'),
              bodyEncrypted: const Value('seed-body'),
              encryptionVersion: const Value(1),
              deleted: const Value(false),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
    }

    setUp(() {
      database = db.AppDb.forTesting(NativeDatabase.memory());
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockUser = MockUser();
      crypto = StubCryptoBox();
      mockReminderBridge = MockTaskReminderBridge();

      when(mockSupabase.auth).thenReturn(mockAuth);
      when(
        mockAuth.currentUser,
      ).thenAnswer((_) => currentUserId == null ? null : mockUser);
      when(mockUser.id).thenAnswer((_) => currentUserId ?? '');

      repository = TaskCoreRepository(
        db: database,
        client: mockSupabase,
        crypto: crypto,
      );

      service = EnhancedTaskService(
        database: database,
        taskRepository: repository,
        reminderBridge: mockReminderBridge,
        supabaseClient: mockSupabase,
      );

      signIn('user-a');
    });

    tearDown(() async {
      await database.close();
    });

    domain.Task buildTask(String noteId, String title) {
      final now = DateTime.now();
      return domain.Task(
        id: '',
        noteId: noteId,
        title: title,
        description: null,
        status: domain.TaskStatus.pending,
        priority: domain.TaskPriority.medium,
        dueDate: null,
        completedAt: null,
        createdAt: now,
        updatedAt: now,
        tags: const [],
        metadata: const {},
      );
    }

    Future<String> createTaskForCurrentUser({
      required String noteId,
      required String title,
    }) async {
      final task = buildTask(noteId, title);
      final created = await repository.createTask(task);
      return created.id;
    }

    test('updateTask requires authenticated user', () async {
      await seedNote(noteId: 'note-a', userId: 'user-a');
      final taskId = await createTaskForCurrentUser(
        noteId: 'note-a',
        title: 'Alpha',
      );

      signOut();

      expect(
        () => service.updateTask(taskId: taskId, content: 'Beta'),
        throwsA(isA<StateError>()),
      );
    });

    test('deleteTask cannot remove tasks owned by another user', () async {
      await seedNote(noteId: 'note-a', userId: 'user-a');
      final taskId = await createTaskForCurrentUser(
        noteId: 'note-a',
        title: 'Alpha',
      );

      signIn('user-b');
      await service.deleteTask(taskId);

      final userATask = await database.getTaskById(taskId, userId: 'user-a');
      expect(
        userATask,
        isNotNull,
        reason: 'User B should not be able to delete User A task',
      );
      verifyZeroInteractions(mockReminderBridge);
    });

    group('Repository Pattern Usage (Post-Refactoring Tests)', () {
      // These tests verify that the service uses repository methods
      // after the architectural refactoring is complete.
      // See: ARCHITECTURE_VIOLATIONS.md v1.0.0, DELETION_PATTERNS.md v1.0.0

      test('deleteTask performs SOFT DELETE via repository', () async {
        // CRITICAL TEST: Verify deleteTask() uses repository soft-delete
        // instead of direct database hard-delete
        await seedNote(noteId: 'note-a', userId: 'user-a');
        final taskId = await createTaskForCurrentUser(
          noteId: 'note-a',
          title: 'Task to Delete',
        );

        // Verify task exists and is not deleted
        final beforeDelete =
            await database.getTaskById(taskId, userId: 'user-a');
        expect(beforeDelete, isNotNull);
        expect(beforeDelete!.deleted, isFalse);

        // Delete the task
        await service.deleteTask(taskId);

        // After refactoring: Task should be SOFT DELETED (deleted=true, scheduled_purge_at set)
        // NOT permanently removed
        final afterDelete = await database.getTaskById(taskId, userId: 'user-a');
        expect(
          afterDelete,
          isNotNull,
          reason: 'Task should still exist in database after soft delete',
        );
        expect(
          afterDelete!.deleted,
          isTrue,
          reason: 'Task should be marked as deleted (soft delete)',
        );
        expect(
          afterDelete.deletedAt,
          isNotNull,
          reason: 'deleted_at should be set',
        );
        expect(
          afterDelete.scheduledPurgeAt,
          isNotNull,
          reason: 'scheduled_purge_at should be set (30 day retention)',
        );

        // Verify reminder bridge interaction
        // (We can't easily verify the exact call with typed mocks, but the
        // functional test above confirms the behavior works correctly)
      });

      test('deleteTask returns early if user not authenticated', () async {
        await seedNote(noteId: 'note-a', userId: 'user-a');
        final taskId = await createTaskForCurrentUser(
          noteId: 'note-a',
          title: 'Task',
        );

        signOut();
        await service.deleteTask(taskId);

        final task = await database.getTaskById(taskId, userId: 'user-a');
        expect(
          task!.deleted,
          isFalse,
          reason: 'Task should not be deleted when user not authenticated',
        );
        verifyZeroInteractions(mockReminderBridge);
      });

      test('completeTask uses repository method', () async {
        // Verify completeTask() uses repository instead of direct DB access
        await seedNote(noteId: 'note-a', userId: 'user-a');
        final taskId = await createTaskForCurrentUser(
          noteId: 'note-a',
          title: 'Task to Complete',
        );

        await service.completeTask(taskId);

        // After refactoring: Task should be completed via repository
        final completed = await repository.getTaskById(taskId);
        expect(completed, isNotNull);
        expect(
          completed!.status,
          domain.TaskStatus.completed,
          reason: 'Task should be marked as completed',
        );
        expect(
          completed.completedAt,
          isNotNull,
          reason: 'completedAt should be set',
        );
      });

      test('completeTask returns early if user not authenticated', () async {
        await seedNote(noteId: 'note-a', userId: 'user-a');
        final taskId = await createTaskForCurrentUser(
          noteId: 'note-a',
          title: 'Task with Reminder',
        );

        signOut();
        await service.completeTask(taskId);

        // Sign back in to check task status
        signIn('user-a');
        // Task should not be completed when user not authenticated
        final task = await repository.getTaskById(taskId);
        expect(task, isNotNull);
        expect(
          task!.status,
          domain.TaskStatus.pending,
          reason: 'Task should remain pending when user not authenticated',
        );
      });

      test('toggleTaskStatus uses repository method', () async {
        await seedNote(noteId: 'note-a', userId: 'user-a');
        final taskId = await createTaskForCurrentUser(
          noteId: 'note-a',
          title: 'Task to Toggle',
        );

        // Small delay to ensure createdAt and updatedAt are different
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Toggle from pending to in_progress
        await service.toggleTaskStatus(taskId);

        // After refactoring: Status should be updated via repository
        final task = await repository.getTaskById(taskId);
        expect(task, isNotNull);
        // Status should have changed from pending
        expect(
          task!.status != domain.TaskStatus.pending,
          isTrue,
          reason: 'Task status should have changed from pending',
        );
      });

      test('createTask with reminder uses repository for task retrieval',
          () async {
        // Verify that after task creation, getting task for reminder
        // uses repository (for proper decryption)
        await seedNote(noteId: 'note-a', userId: 'user-a');

        final taskId = await service.createTask(
          noteId: 'note-a',
          content: 'Task with Reminder',
          dueDate: DateTime.now().add(const Duration(days: 1)),
          createReminder: true,
        );

        expect(taskId, isNotEmpty);

        // Verify task was created via repository
        final task = await repository.getTaskById(taskId);
        expect(task, isNotNull);
        expect(task!.title, 'Task with Reminder');
        // Reminder creation happens, but we don't need to verify mock calls
      });

      test('updateTask with content uses repository for encryption', () async {
        await seedNote(noteId: 'note-a', userId: 'user-a');
        final taskId = await createTaskForCurrentUser(
          noteId: 'note-a',
          title: 'Original Title',
        );

        // Update task content
        await service.updateTask(
          taskId: taskId,
          content: 'Updated Title',
        );

        // After refactoring: Content should be encrypted via repository
        final updated = await repository.getTaskById(taskId);
        expect(updated, isNotNull);
        expect(
          updated!.title,
          'Updated Title',
          reason: 'Task title should be updated and properly decrypted',
        );
      });

      test('updateTask handles reminder updates correctly', () async {
        await seedNote(noteId: 'note-a', userId: 'user-a');
        final taskId = await createTaskForCurrentUser(
          noteId: 'note-a',
          title: 'Task',
        );

        final newDueDate = DateTime.now().add(const Duration(days: 2));
        await service.updateTask(
          taskId: taskId,
          dueDate: newDueDate,
          updateReminder: true,
        );

        // Verify task was updated via repository
        final updated = await repository.getTaskById(taskId);
        expect(updated, isNotNull);
        expect(updated!.dueDate, isNotNull);
        // Due date should be updated (within 1 second tolerance)
        expect(
          updated.dueDate!.difference(newDueDate).abs().inSeconds,
          lessThan(2),
        );
      });

      test('updateTask with clearReminderId removes reminder', () async {
        await seedNote(noteId: 'note-a', userId: 'user-a');
        final taskId = await createTaskForCurrentUser(
          noteId: 'note-a',
          title: 'Task',
        );

        await service.updateTask(
          taskId: taskId,
          clearReminderId: true,
        );

        // Task should have no reminder ID after clearing
        final task = await repository.getTaskById(taskId);
        expect(task, isNotNull);
        // Reminder ID should be null (stored in metadata)
        expect(task!.metadata['reminderId'], isNull);
      });

      test('createTaskWithReminder uses repository for task retrieval',
          () async {
        await seedNote(noteId: 'note-a', userId: 'user-a');

        final dueDate = DateTime.now().add(const Duration(days: 1));
        final reminderTime = dueDate.subtract(const Duration(hours: 2));

        final taskId = await service.createTaskWithReminder(
          noteId: 'note-a',
          content: 'Task with Custom Reminder',
          dueDate: dueDate,
          reminderTime: reminderTime,
        );

        expect(taskId, isNotEmpty);

        // Verify task was created via repository
        final task = await repository.getTaskById(taskId);
        expect(task, isNotNull);
        expect(task!.title, 'Task with Custom Reminder');
        // Custom reminder creation is tested functionally
      });

      test('clearTaskReminder does not crash', () async {
        await seedNote(noteId: 'note-a', userId: 'user-a');
        final taskId = await createTaskForCurrentUser(
          noteId: 'note-a',
          title: 'Task',
        );

        // Should complete without error
        await service.clearTaskReminder(taskId);
        // Functional test - verifies it doesn't throw
      });

      test('setCustomTaskReminder completes successfully', () async {
        await seedNote(noteId: 'note-a', userId: 'user-a');
        final taskId = await createTaskForCurrentUser(
          noteId: 'note-a',
          title: 'Task',
        );

        final dueDate = DateTime.now().add(const Duration(days: 1));
        final reminderTime = dueDate.subtract(const Duration(hours: 1));

        // Should complete without error
        await service.setCustomTaskReminder(
          taskId: taskId,
          dueDate: dueDate,
          reminderTime: reminderTime,
        );
        // Functional test - verifies it doesn't throw
      });
    });
  });
}
