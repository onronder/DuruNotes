import 'package:drift/native.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' as domain_task;
import 'package:duru_notes/infrastructure/repositories/folder_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/task_core_repository.dart';
import 'package:duru_notes/services/trash_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/security_test_setup.dart';

/// Test harness for soft delete functionality across all repositories
class _SoftDeleteTestHarness {
  _SoftDeleteTestHarness()
    : db = AppDb.forTesting(NativeDatabase.memory()),
      userId = 'test-user-soft-delete',
      client = _FakeSupabaseClient('test-user-soft-delete'),
      indexer = _StubNoteIndexer() {
    crypto = SecurityTestSetup.createTestCryptoBox();
    notesRepo = NotesCoreRepository(
      db: db,
      crypto: crypto,
      client: client,
      indexer: indexer,
    );
    foldersRepo = FolderCoreRepository(db: db, crypto: crypto, client: client);
    tasksRepo = TaskCoreRepository(db: db, crypto: crypto, client: client);
  }

  final AppDb db;
  final String userId;
  final _FakeSupabaseClient client;
  final NoteIndexer indexer;
  late final CryptoBox crypto;
  late final NotesCoreRepository notesRepo;
  late final FolderCoreRepository foldersRepo;
  late final TaskCoreRepository tasksRepo;

  void dispose() {
    db.close();
  }
}

class _FakeSupabaseClient extends SupabaseClient {
  _FakeSupabaseClient(String userId)
    : _session = Session(
        accessToken: 'token',
        refreshToken: 'refresh',
        tokenType: 'bearer',
        expiresIn: 3600,
        user: User(
          id: userId,
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          email: '$userId@example.com',
          phone: '',
          createdAt: DateTime.utc(2025, 1, 1).toIso8601String(),
          updatedAt: DateTime.utc(2025, 1, 1).toIso8601String(),
          role: 'authenticated',
          identities: const [],
          factors: const [],
        ),
      ),
      super('https://stub.supabase.co', 'anon-key');

  final Session _session;

  @override
  GoTrueClient get auth => _FakeAuthClient(_session);

  @override
  SupabaseQueryBuilder from(String table) {
    throw UnimplementedError('Remote access not required for repository tests');
  }
}

class _FakeAuthClient extends GoTrueClient {
  _FakeAuthClient(this._session);

  final Session _session;

  @override
  User? get currentUser => _session.user;

  @override
  Session? get currentSession => _session;
}

class _StubNoteIndexer implements NoteIndexer {
  @override
  Future<void> clearIndex() async {}

  @override
  Future<void> indexNote(domain.Note note) async {}

  @override
  Future<void> rebuildIndex(List<domain.Note> allNotes) async {}

  @override
  Future<void> removeNoteFromIndex(String noteId) async {}

  @override
  Set<String> findNotesByTag(String tag) => {};

  @override
  Set<String> findNotesLinkingTo(String noteId) => {};

  @override
  Map<String, int> getIndexStats() => const {};

  @override
  Set<String> searchNotes(String query) => {};
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Set up shared preferences mock (required by Supabase)
    SharedPreferences.setMockInitialValues({});

    // Initialize Supabase for tests (FolderMapper uses Supabase.instance)
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-anon-key',
      );
    }
  });

  group('Soft Delete - NotesCoreRepository', () {
    late _SoftDeleteTestHarness harness;

    setUp(() {
      harness = _SoftDeleteTestHarness();
    });

    tearDown(() {
      harness.dispose();
    });

    test('deleteNote sets deletedAt and scheduledPurgeAt timestamps', () async {
      // Create a note
      final note = await harness.notesRepo.createOrUpdate(
        title: 'Test Note',
        body: 'Test Body',
      );
      expect(note, isNotNull);
      expect(note!.deleted, isFalse);
      expect(note.deletedAt, isNull);
      expect(note.scheduledPurgeAt, isNull);

      final beforeDelete = DateTime.now();

      // Delete the note
      await harness.notesRepo.deleteNote(note.id);

      // Verify timestamps were set
      final deletedNotes = await harness.notesRepo.getDeletedNotes();
      expect(deletedNotes, hasLength(1));

      final deletedNote = deletedNotes.first;
      expect(deletedNote.deleted, isTrue);
      expect(deletedNote.deletedAt, isNotNull);
      expect(deletedNote.scheduledPurgeAt, isNotNull);

      // Verify deletedAt is approximately now
      expect(
        deletedNote.deletedAt!.isAfter(
          beforeDelete.subtract(const Duration(seconds: 1)),
        ),
        isTrue,
      );
      expect(
        deletedNote.deletedAt!.isBefore(
          DateTime.now().add(const Duration(seconds: 1)),
        ),
        isTrue,
      );

      // Verify scheduledPurgeAt is 30 days after deletedAt
      final expectedPurgeAt = deletedNote.deletedAt!.add(
        TrashService.retentionPeriod,
      );
      expect(
        deletedNote.scheduledPurgeAt!
                .difference(expectedPurgeAt)
                .abs()
                .inSeconds <
            1,
        isTrue,
      );
    });

    test('getDeletedNotes returns only soft-deleted notes', () async {
      // Create three notes
      await harness.notesRepo.createOrUpdate(
        title: 'Active Note 1',
        body: 'Body 1',
      );
      final note2 = await harness.notesRepo.createOrUpdate(
        title: 'To Delete 1',
        body: 'Body 2',
      );
      final note3 = await harness.notesRepo.createOrUpdate(
        title: 'To Delete 2',
        body: 'Body 3',
      );

      // Delete two notes
      await harness.notesRepo.deleteNote(note2!.id);
      await harness.notesRepo.deleteNote(note3!.id);

      // Verify getDeletedNotes returns only deleted ones
      final deletedNotes = await harness.notesRepo.getDeletedNotes();
      expect(deletedNotes, hasLength(2));
      expect(deletedNotes.map((n) => n.id), containsAll([note2.id, note3.id]));
      expect(deletedNotes.every((n) => n.deleted), isTrue);
      expect(deletedNotes.every((n) => n.deletedAt != null), isTrue);

      // Verify localNotes excludes deleted notes
      final activeNotes = await harness.notesRepo.localNotes();
      expect(activeNotes, hasLength(1));
      expect(activeNotes.first.title, 'Active Note 1');
    });

    test('permanentlyDeleteNote removes note from database', () async {
      // Create and delete a note
      final note = await harness.notesRepo.createOrUpdate(
        title: 'To Permanently Delete',
        body: 'Body',
      );
      await harness.notesRepo.deleteNote(note!.id);

      // Verify it's in trash
      var deletedNotes = await harness.notesRepo.getDeletedNotes();
      expect(deletedNotes, hasLength(1));

      // Permanently delete
      await harness.notesRepo.permanentlyDeleteNote(note.id);

      // Verify it's completely gone
      deletedNotes = await harness.notesRepo.getDeletedNotes();
      expect(deletedNotes, isEmpty);

      final allNotes = await harness.notesRepo.localNotes();
      expect(allNotes, isEmpty);

      final fetchedNote = await harness.notesRepo.getNoteById(note.id);
      expect(fetchedNote, isNull);
    });

    test('restoreNote clears deletion timestamps', () async {
      // Create and delete a note
      final note = await harness.notesRepo.createOrUpdate(
        title: 'To Restore',
        body: 'Body',
      );
      await harness.notesRepo.deleteNote(note!.id);

      // Verify it's deleted with timestamps
      var deletedNotes = await harness.notesRepo.getDeletedNotes();
      expect(deletedNotes.first.deleted, isTrue);
      expect(deletedNotes.first.deletedAt, isNotNull);
      expect(deletedNotes.first.scheduledPurgeAt, isNotNull);

      // Restore the note using the proper restore method
      await harness.notesRepo.restoreNote(note.id);

      // Verify note is restored and timestamps are cleared
      final restoredNote = await harness.notesRepo.getNoteById(note.id);
      expect(restoredNote, isNotNull);
      expect(restoredNote!.deleted, isFalse);
      // restoreNote() should clear both deletion timestamps
      expect(
        restoredNote.deletedAt,
        isNull,
        reason: 'restoreNote() should clear deletedAt timestamp',
      );
      expect(
        restoredNote.scheduledPurgeAt,
        isNull,
        reason: 'restoreNote() should clear scheduledPurgeAt timestamp',
      );

      // Verify it's back in active notes
      final activeNotes = await harness.notesRepo.localNotes();
      expect(activeNotes, hasLength(1));
      expect(activeNotes.first.id, note.id);

      // Verify it's not in deleted notes
      deletedNotes = await harness.notesRepo.getDeletedNotes();
      expect(deletedNotes, isEmpty);
    });
  });

  group('Soft Delete - FolderCoreRepository', () {
    late _SoftDeleteTestHarness harness;

    setUp(() {
      harness = _SoftDeleteTestHarness();
    });

    tearDown(() {
      harness.dispose();
    });

    test(
      'deleteFolder sets deletedAt and scheduledPurgeAt timestamps',
      () async {
        // Create a folder
        final folderId = await harness.foldersRepo.createOrUpdateFolder(
          name: 'Test Folder',
        );

        final folder = await harness.foldersRepo.getFolder(folderId);
        expect(folder, isNotNull);
        expect(folder!.deletedAt, isNull);

        final beforeDelete = DateTime.now();

        // Delete the folder
        await harness.foldersRepo.deleteFolder(folderId);

        // Verify timestamps were set
        final deletedFolders = await harness.foldersRepo.getDeletedFolders();
        expect(deletedFolders, hasLength(1));

        final deletedFolder = deletedFolders.first;
        expect(deletedFolder.deletedAt, isNotNull);
        expect(deletedFolder.scheduledPurgeAt, isNotNull);

        // Verify deletedAt is approximately now
        expect(
          deletedFolder.deletedAt!.isAfter(
            beforeDelete.subtract(const Duration(seconds: 1)),
          ),
          isTrue,
        );

        // Verify scheduledPurgeAt is 30 days after deletedAt
        final expectedPurgeAt = deletedFolder.deletedAt!.add(
          TrashService.retentionPeriod,
        );
        expect(
          deletedFolder.scheduledPurgeAt!
                  .difference(expectedPurgeAt)
                  .abs()
                  .inSeconds <
              1,
          isTrue,
        );
      },
    );

    test('getDeletedFolders returns only soft-deleted folders', () async {
      // Create three folders
      await harness.foldersRepo.createOrUpdateFolder(name: 'Active Folder');
      final folder2Id = await harness.foldersRepo.createOrUpdateFolder(
        name: 'To Delete 1',
      );
      final folder3Id = await harness.foldersRepo.createOrUpdateFolder(
        name: 'To Delete 2',
      );

      // Delete two folders
      await harness.foldersRepo.deleteFolder(folder2Id);
      await harness.foldersRepo.deleteFolder(folder3Id);

      // Verify getDeletedFolders returns only deleted ones
      final deletedFolders = await harness.foldersRepo.getDeletedFolders();
      expect(deletedFolders, hasLength(2));
      expect(
        deletedFolders.map((f) => f.id),
        containsAll([folder2Id, folder3Id]),
      );
      expect(deletedFolders.every((f) => f.deletedAt != null), isTrue);

      // Verify listFolders excludes deleted folders
      final activeFolders = await harness.foldersRepo.listFolders();
      expect(activeFolders, hasLength(1));
      expect(activeFolders.first.name, 'Active Folder');
    });

    test('permanentlyDeleteFolder removes folder from database', () async {
      // Create and delete a folder
      final folderId = await harness.foldersRepo.createOrUpdateFolder(
        name: 'To Permanently Delete',
      );
      await harness.foldersRepo.deleteFolder(folderId);

      // Verify it's in trash
      var deletedFolders = await harness.foldersRepo.getDeletedFolders();
      expect(deletedFolders, hasLength(1));

      // Permanently delete
      await harness.foldersRepo.permanentlyDeleteFolder(folderId);

      // Verify it's completely gone
      deletedFolders = await harness.foldersRepo.getDeletedFolders();
      expect(deletedFolders, isEmpty);

      final allFolders = await harness.foldersRepo.listFolders();
      expect(allFolders, isEmpty);

      final fetchedFolder = await harness.foldersRepo.getFolder(folderId);
      expect(fetchedFolder, isNull);
    });

    test('restoreFolder clears deletion timestamps', () async {
      // Create and delete a folder
      final folderId = await harness.foldersRepo.createOrUpdateFolder(
        name: 'To Restore',
      );
      await harness.foldersRepo.deleteFolder(folderId);

      // Verify it's deleted with timestamps
      var deletedFolders = await harness.foldersRepo.getDeletedFolders();
      expect(deletedFolders.first.deletedAt, isNotNull);
      expect(deletedFolders.first.scheduledPurgeAt, isNotNull);

      // Restore the folder
      await harness.foldersRepo.restoreFolder(folderId);

      // Verify timestamps are cleared
      final restoredFolder = await harness.foldersRepo.getFolder(folderId);
      expect(restoredFolder, isNotNull);
      expect(restoredFolder!.deletedAt, isNull);
      expect(restoredFolder.scheduledPurgeAt, isNull);

      // Verify it's back in active folders
      final activeFolders = await harness.foldersRepo.listFolders();
      expect(activeFolders, hasLength(1));
      expect(activeFolders.first.id, folderId);

      // Verify it's not in deleted folders
      deletedFolders = await harness.foldersRepo.getDeletedFolders();
      expect(deletedFolders, isEmpty);
    });
  });

  group('Soft Delete - TaskCoreRepository', () {
    late _SoftDeleteTestHarness harness;
    late String containerNoteId;

    setUp(() async {
      harness = _SoftDeleteTestHarness();
      // Create a standalone task container note
      final note = await harness.notesRepo.createOrUpdate(
        title: 'Standalone Tasks',
        body: '',
      );
      containerNoteId = note!.id;
    });

    tearDown(() {
      harness.dispose();
    });

    domain_task.Task buildTask(String title, String noteId) {
      final now = DateTime.now();
      return domain_task.Task(
        id: '', // Will be generated
        noteId: noteId,
        title: title,
        status: domain_task.TaskStatus.pending,
        priority: domain_task.TaskPriority.medium,
        createdAt: now,
        updatedAt: now,
        tags: const [],
        metadata: const {},
      );
    }

    test('deleteTask sets deletedAt and scheduledPurgeAt timestamps', () async {
      // Create a task
      final createdTask = await harness.tasksRepo.createTask(
        buildTask('Test Task', containerNoteId),
      );

      final task = await harness.tasksRepo.getTaskById(createdTask.id);
      expect(task, isNotNull);
      expect(task!.deletedAt, isNull);

      final beforeDelete = DateTime.now();

      // Delete the task
      await harness.tasksRepo.deleteTask(createdTask.id);

      // Verify timestamps were set
      final deletedTasks = await harness.tasksRepo.getDeletedTasks();
      expect(deletedTasks, hasLength(1));

      final deletedTask = deletedTasks.first;
      expect(deletedTask.deletedAt, isNotNull);
      expect(deletedTask.scheduledPurgeAt, isNotNull);

      // Verify deletedAt is approximately now
      expect(
        deletedTask.deletedAt!.isAfter(
          beforeDelete.subtract(const Duration(seconds: 1)),
        ),
        isTrue,
      );

      // Verify scheduledPurgeAt is 30 days after deletedAt
      final expectedPurgeAt = deletedTask.deletedAt!.add(
        TrashService.retentionPeriod,
      );
      expect(
        deletedTask.scheduledPurgeAt!
                .difference(expectedPurgeAt)
                .abs()
                .inSeconds <
            1,
        isTrue,
      );
    });

    test('getDeletedTasks returns only soft-deleted tasks', () async {
      // Create three tasks
      await harness.tasksRepo.createTask(
        buildTask('Active Task', containerNoteId),
      );
      final task2 = await harness.tasksRepo.createTask(
        buildTask('To Delete 1', containerNoteId),
      );
      final task3 = await harness.tasksRepo.createTask(
        buildTask('To Delete 2', containerNoteId),
      );

      // Delete two tasks
      await harness.tasksRepo.deleteTask(task2.id);
      await harness.tasksRepo.deleteTask(task3.id);

      // Verify getDeletedTasks returns only deleted ones
      final deletedTasks = await harness.tasksRepo.getDeletedTasks();
      expect(deletedTasks, hasLength(2));
      expect(deletedTasks.map((t) => t.id), containsAll([task2.id, task3.id]));
      expect(deletedTasks.every((t) => t.deletedAt != null), isTrue);

      // Verify getTasksForNote excludes deleted tasks
      final activeTasks = await harness.tasksRepo.getTasksForNote(
        containerNoteId,
      );
      expect(activeTasks, hasLength(1));
      expect(activeTasks.first.title, 'Active Task');
    });

    test('permanentlyDeleteTask removes task from database', () async {
      // Create and delete a task
      final task = await harness.tasksRepo.createTask(
        buildTask('To Permanently Delete', containerNoteId),
      );
      await harness.tasksRepo.deleteTask(task.id);

      // Verify it's in trash
      var deletedTasks = await harness.tasksRepo.getDeletedTasks();
      expect(deletedTasks, hasLength(1));

      // Permanently delete
      await harness.tasksRepo.permanentlyDeleteTask(task.id);

      // Verify it's completely gone
      deletedTasks = await harness.tasksRepo.getDeletedTasks();
      expect(deletedTasks, isEmpty);

      final allTasks = await harness.tasksRepo.getTasksForNote(containerNoteId);
      expect(allTasks, isEmpty);

      final fetchedTask = await harness.tasksRepo.getTaskById(task.id);
      expect(fetchedTask, isNull);
    });

    test('restoreTask clears deletion timestamps', () async {
      // Create and delete a task
      final task = await harness.tasksRepo.createTask(
        buildTask('To Restore', containerNoteId),
      );
      await harness.tasksRepo.deleteTask(task.id);

      // Verify it's deleted with timestamps
      var deletedTasks = await harness.tasksRepo.getDeletedTasks();
      expect(deletedTasks.first.deletedAt, isNotNull);
      expect(deletedTasks.first.scheduledPurgeAt, isNotNull);

      // Restore the task
      await harness.tasksRepo.restoreTask(task.id);

      // Verify timestamps are cleared
      final restoredTask = await harness.tasksRepo.getTaskById(task.id);
      expect(restoredTask, isNotNull);
      expect(restoredTask!.deletedAt, isNull);
      expect(restoredTask.scheduledPurgeAt, isNull);

      // Verify it's back in active tasks
      final activeTasks = await harness.tasksRepo.getTasksForNote(
        containerNoteId,
      );
      expect(activeTasks, hasLength(1));
      expect(activeTasks.first.id, task.id);

      // Verify it's not in deleted tasks
      deletedTasks = await harness.tasksRepo.getDeletedTasks();
      expect(deletedTasks, isEmpty);
    });
  });
}
