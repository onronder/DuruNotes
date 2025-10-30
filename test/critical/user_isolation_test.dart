import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/models/note_kind.dart';

void main() {
  group('🚨 CRITICAL: User Isolation (Database Layer)', () {
    late AppDb db;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      db = AppDb.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> seedNote({
      required String id,
      required String userId,
      bool deleted = false,
    }) async {
      final timestamp = DateTime.now();
      await db
          .into(db.localNotes)
          .insert(
            LocalNotesCompanion.insert(
              id: id,
              userId: Value(userId),
              titleEncrypted: const Value('Encrypted Title'),
              bodyEncrypted: const Value('Encrypted Body'),
              encryptionVersion: const Value(1),
              noteType: Value(NoteKind.note),
              deleted: Value(deleted),
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
    }

    Future<void> seedTask({
      required String id,
      required String noteId,
      required String userId,
      TaskStatus status = TaskStatus.open,
    }) async {
      await db
          .into(db.noteTasks)
          .insert(
            NoteTasksCompanion.insert(
              id: id,
              noteId: noteId,
              userId: userId,
              contentEncrypted: 'Encrypted $id',
              contentHash: 'hash-$id',
              status: Value(status),
              position: const Value(0),
              priority: const Value(TaskPriority.medium),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );
    }

    Future<void> seedReminder({
      required int id,
      required String noteId,
      required String userId,
    }) async {
      await db
          .into(db.noteReminders)
          .insert(
            NoteRemindersCompanion.insert(
              id: Value(id),
              noteId: noteId,
              userId: userId,
              type: ReminderType.time,
            ),
          );
    }

    test('getAllTasks returns tasks only for the requesting user', () async {
      await seedNote(id: 'note-a', userId: 'user-a');
      await seedNote(id: 'note-b', userId: 'user-b');

      await seedTask(id: 'task-a-1', noteId: 'note-a', userId: 'user-a');
      await seedTask(id: 'task-b-1', noteId: 'note-b', userId: 'user-b');

      final userATasks = await db.getAllTasks('user-a');
      expect(userATasks.map((t) => t.id), ['task-a-1']);

      final userBTasks = await db.getAllTasks('user-b');
      expect(userBTasks.map((t) => t.id), ['task-b-1']);
    });

    test('getTaskById enforces user ownership', () async {
      await seedNote(id: 'note-a', userId: 'user-a');
      await seedTask(id: 'task-a-1', noteId: 'note-a', userId: 'user-a');

      final owned = await db.getTaskById('task-a-1', userId: 'user-a');
      expect(owned, isNotNull, reason: 'Owner should retrieve their task');

      final unauthorized = await db.getTaskById('task-a-1', userId: 'user-b');
      expect(
        unauthorized,
        isNull,
        reason: 'Foreign users must not retrieve another user task',
      );
    });

    test('updateTask refuses cross-user modifications', () async {
      await seedNote(id: 'note-a', userId: 'user-a');
      await seedTask(id: 'task-a-1', noteId: 'note-a', userId: 'user-a');

      // Attempt update with wrong user
      await db.updateTask(
        'task-a-1',
        'user-b',
        const NoteTasksCompanion(priority: Value(TaskPriority.high)),
      );

      final task = await db.getTaskById('task-a-1', userId: 'user-a');
      expect(
        task!.priority,
        TaskPriority.medium,
        reason: 'Cross-user update must be ignored',
      );

      // Owner update should succeed
      await db.updateTask(
        'task-a-1',
        'user-a',
        const NoteTasksCompanion(priority: Value(TaskPriority.high)),
      );

      final updated = await db.getTaskById('task-a-1', userId: 'user-a');
      expect(updated!.priority, TaskPriority.high);
    });

    test('deleteTasksForNote only removes tasks for matching user', () async {
      await seedNote(id: 'note-a', userId: 'user-a');
      await seedNote(id: 'note-b', userId: 'user-b');
      await seedTask(id: 'task-a-1', noteId: 'note-a', userId: 'user-a');
      await seedTask(id: 'task-a-2', noteId: 'note-a', userId: 'user-a');
      await seedTask(id: 'task-b-1', noteId: 'note-b', userId: 'user-b');

      await db.deleteTasksForNote('note-a', 'user-b');

      final remainingForA = await db.getAllTasks('user-a');
      expect(
        remainingForA.length,
        2,
        reason: 'Foreign delete must not remove owner tasks',
      );

      await db.deleteTasksForNote('note-a', 'user-a');
      final afterOwnerDelete = await db.getAllTasks('user-a');
      expect(afterOwnerDelete, isEmpty);
      final userBTasks = await db.getAllTasks('user-b');
      expect(userBTasks.map((t) => t.id), ['task-b-1']);
    });

    test('reminders remain isolated per user', () async {
      await seedNote(id: 'note-a', userId: 'user-a');
      await seedNote(id: 'note-b', userId: 'user-b');
      await seedReminder(id: 1, noteId: 'note-a', userId: 'user-a');
      await seedReminder(id: 2, noteId: 'note-b', userId: 'user-b');

      final userAReminders = await (db.select(
        db.noteReminders,
      )..where((r) => r.userId.equals('user-a'))).get();
      final userBReminders = await (db.select(
        db.noteReminders,
      )..where((r) => r.userId.equals('user-b'))).get();

      expect(userAReminders.map((r) => r.id), [1]);
      expect(userBReminders.map((r) => r.id), [2]);
    });

    test('clearAll purges every user-scoped table', () async {
      await seedNote(id: 'note-a', userId: 'user-a');
      await seedTask(id: 'task-a-1', noteId: 'note-a', userId: 'user-a');
      await seedReminder(id: 1, noteId: 'note-a', userId: 'user-a');

      await db.clearAll();

      expect(await db.select(db.localNotes).get(), isEmpty);
      expect(await db.select(db.noteTasks).get(), isEmpty);
      expect(await db.select(db.noteReminders).get(), isEmpty);
    });
  });
}
