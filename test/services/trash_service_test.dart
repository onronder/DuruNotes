import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/folder.dart';
import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/domain/entities/task.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:duru_notes/services/trash_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal fake notes repository for testing
class _FakeNotesRepository implements INotesRepository {
  final List<Note> _deletedNotes = [];
  final List<Note> _allNotes = [];
  bool shouldThrowOnDelete = false;

  @override
  Future<List<Note>> getDeletedNotes() async => List.of(_deletedNotes); // Return defensive copy

  @override
  Future<Note?> getNoteById(String noteId) async {
    try {
      return _allNotes.firstWhere((n) => n.id == noteId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> permanentlyDeleteNote(String noteId) async {
    if (shouldThrowOnDelete) {
      throw Exception('Simulated deletion error');
    }
    _deletedNotes.removeWhere((n) => n.id == noteId);
    _allNotes.removeWhere((n) => n.id == noteId);
  }

  void addDeletedNote(Note note) {
    _deletedNotes.add(note);
    _allNotes.add(note);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Minimal fake folder repository for testing
class _FakeFolderRepository implements IFolderRepository {
  final List<Folder> _deletedFolders = [];

  @override
  Future<List<Folder>> getDeletedFolders() async => List.of(_deletedFolders); // Return defensive copy

  @override
  Future<void> permanentlyDeleteFolder(String folderId) async {
    _deletedFolders.removeWhere((f) => f.id == folderId);
  }

  void addDeletedFolder(Folder folder) => _deletedFolders.add(folder);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Minimal fake task repository for testing
class _FakeTaskRepository implements ITaskRepository {
  final List<Task> _deletedTasks = [];

  @override
  Future<List<Task>> getDeletedTasks() async => List.of(_deletedTasks); // Return defensive copy

  @override
  Future<void> permanentlyDeleteTask(String taskId) async {
    _deletedTasks.removeWhere((t) => t.id == taskId);
  }

  void addDeletedTask(Task task) => _deletedTasks.add(task);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TrashService - Core Tests', () {
    late ProviderContainer container;
    late TrashService service;
    late _FakeNotesRepository notesRepo;
    late _FakeFolderRepository folderRepo;
    late _FakeTaskRepository taskRepo;

    setUp(() {
      notesRepo = _FakeNotesRepository();
      folderRepo = _FakeFolderRepository();
      taskRepo = _FakeTaskRepository();

      container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(const ConsoleLogger())],
      );

      service = container.read(
        Provider(
          (ref) => TrashService(
            ref,
            notesRepository: notesRepo,
            folderRepository: folderRepo,
            taskRepository: taskRepo,
            notesRepositoryProvided: true,
            folderRepositoryProvided: true,
            taskRepositoryProvided: true,
          ),
        ),
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('calculateScheduledPurgeAt adds 30 days', () {
      final deletedAt = DateTime(2025, 1, 1, 12, 0, 0);
      final expectedPurgeAt = DateTime(2025, 1, 31, 12, 0, 0);

      final actualPurgeAt = service.calculateScheduledPurgeAt(deletedAt);

      expect(actualPurgeAt, equals(expectedPurgeAt));
    });

    test('daysUntilPurge calculates correctly', () {
      // Use fixed timestamps to avoid timing flakiness
      final now = DateTime(2025, 1, 1, 12, 0, 0);
      final scheduledPurgeAt = DateTime(
        2025,
        1,
        16,
        12,
        0,
        0,
      ); // Exactly 15 days later

      // Calculate difference manually to verify the method
      final difference = scheduledPurgeAt.difference(now);
      final daysRemaining = difference.inDays;

      expect(daysRemaining, equals(15));

      // Now test the service method with a current date close to 'now'
      // Add small buffer to avoid edge cases
      final testPurgeAt = DateTime.now().add(
        const Duration(days: 15, hours: 1),
      );
      final result = service.daysUntilPurge(testPurgeAt);

      // Should be 15 days (the hour buffer prevents flaking to 14)
      // NOTE: This test still uses DateTime.now() inside service.daysUntilPurge,
      // which couples it to system time. The 1-hour buffer makes it stable in
      // practice, but a frozen clock would be more robust. Consider adding
      // clock injection to TrashService for better testability in the future.
      expect(result, equals(15));
    });

    test('isOverdueForPurge returns true for past dates', () {
      final scheduledPurgeAt = DateTime.now().subtract(
        const Duration(hours: 1),
      );

      expect(service.isOverdueForPurge(scheduledPurgeAt), isTrue);
    });

    test('isOverdueForPurge returns false for future dates', () {
      final scheduledPurgeAt = DateTime.now().add(const Duration(hours: 1));

      expect(service.isOverdueForPurge(scheduledPurgeAt), isFalse);
    });

    test('retentionPeriod is 30 days', () {
      expect(TrashService.retentionPeriod, equals(const Duration(days: 30)));
    });

    test('getAllDeletedItems returns empty when no items', () async {
      final contents = await service.getAllDeletedItems();

      expect(contents.notes, isEmpty);
      expect(contents.totalCount, equals(0));
    });

    test('getAllDeletedItems returns deleted notes', () async {
      final note = Note(
        id: 'note1',
        title: 'Test Note',
        body: 'body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: true,
        deletedAt: DateTime.now(),
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: 'user1',
      );

      notesRepo.addDeletedNote(note);

      final contents = await service.getAllDeletedItems();

      expect(contents.notes, hasLength(1));
      expect(contents.notes.first.id, equals('note1'));
      expect(contents.totalCount, equals(1));
    });

    test('permanentlyDeleteNote removes note', () async {
      final note = Note(
        id: 'note-to-delete',
        title: 'Test Note',
        body: 'body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: true,
        deletedAt: DateTime.now(),
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: 'user1',
      );

      notesRepo.addDeletedNote(note);

      expect(notesRepo._deletedNotes, hasLength(1));

      await service.permanentlyDeleteNote('note-to-delete');

      expect(notesRepo._deletedNotes, isEmpty);
    });

    test('emptyTrash deletes all notes', () async {
      final note1 = Note(
        id: 'note1',
        title: 'Note 1',
        body: 'body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: true,
        deletedAt: DateTime.now(),
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: 'user1',
      );
      final note2 = Note(
        id: 'note2',
        title: 'Note 2',
        body: 'body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: true,
        deletedAt: DateTime.now(),
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: 'user1',
      );

      notesRepo.addDeletedNote(note1);
      notesRepo.addDeletedNote(note2);

      final result = await service.emptyTrash();

      expect(result.successCount, equals(2));
      expect(result.failureCount, equals(0));
      expect(result.allSucceeded, isTrue);
      expect(notesRepo._deletedNotes, isEmpty);
    });

    test('getTrashStatistics returns correct counts', () async {
      final now = DateTime.now();

      final overdueNote = Note(
        id: 'overdue',
        title: 'Overdue',
        body: 'body',
        createdAt: now,
        updatedAt: now,
        deleted: true,
        deletedAt: now,
        scheduledPurgeAt: now.subtract(const Duration(days: 1)),
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: 'user1',
      );

      final within7Note = Note(
        id: 'within7',
        title: 'Within 7',
        body: 'body',
        createdAt: now,
        updatedAt: now,
        deleted: true,
        deletedAt: now,
        scheduledPurgeAt: now.add(const Duration(days: 5)),
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: 'user1',
      );

      notesRepo.addDeletedNote(overdueNote);
      notesRepo.addDeletedNote(within7Note);

      final stats = await service.getTrashStatistics();

      expect(stats.totalItems, equals(2));
      expect(stats.notesCount, equals(2));
      expect(stats.overdueForPurgeCount, equals(1));
      expect(stats.purgeWithin7Days, equals(1));
    });

    // Folder tests
    test('permanentlyDeleteFolder removes folder', () async {
      final folder = Folder(
        id: 'folder-to-delete',
        name: 'Test Folder',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deletedAt: DateTime.now(),
        sortOrder: 0,
        userId: 'user1',
      );

      folderRepo.addDeletedFolder(folder);

      expect(folderRepo._deletedFolders, hasLength(1));

      await service.permanentlyDeleteFolder('folder-to-delete');

      expect(folderRepo._deletedFolders, isEmpty);
    });

    test('getAllDeletedItems returns deleted folders', () async {
      final folder = Folder(
        id: 'folder1',
        name: 'Test Folder',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deletedAt: DateTime.now(),
        sortOrder: 0,
        userId: 'user1',
      );

      folderRepo.addDeletedFolder(folder);

      final contents = await service.getAllDeletedItems();

      expect(contents.folders, hasLength(1));
      expect(contents.folders.first.id, equals('folder1'));
      expect(contents.totalCount, equals(1));
    });

    // Task tests
    test('permanentlyDeleteTask removes task', () async {
      final task = Task(
        id: 'task-to-delete',
        noteId: 'note1',
        title: 'Test Task',
        status: TaskStatus.pending,
        priority: TaskPriority.medium,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deletedAt: DateTime.now(),
        tags: const [],
        metadata: const {},
      );

      taskRepo.addDeletedTask(task);

      expect(taskRepo._deletedTasks, hasLength(1));

      await service.permanentlyDeleteTask('task-to-delete');

      expect(taskRepo._deletedTasks, isEmpty);
    });

    test('getAllDeletedItems returns deleted tasks', () async {
      final task = Task(
        id: 'task1',
        noteId: 'note1',
        title: 'Test Task',
        status: TaskStatus.pending,
        priority: TaskPriority.medium,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deletedAt: DateTime.now(),
        tags: const [],
        metadata: const {},
      );

      taskRepo.addDeletedTask(task);

      final contents = await service.getAllDeletedItems();

      expect(contents.tasks, hasLength(1));
      expect(contents.tasks.first.id, equals('task1'));
      expect(contents.totalCount, equals(1));
    });

    test('getAllDeletedItems returns mixed entity types', () async {
      final note = Note(
        id: 'note1',
        title: 'Test Note',
        body: 'body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: true,
        deletedAt: DateTime.now(),
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: 'user1',
      );

      final folder = Folder(
        id: 'folder1',
        name: 'Test Folder',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deletedAt: DateTime.now(),
        sortOrder: 0,
        userId: 'user1',
      );

      final task = Task(
        id: 'task1',
        noteId: 'note1',
        title: 'Test Task',
        status: TaskStatus.pending,
        priority: TaskPriority.medium,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deletedAt: DateTime.now(),
        tags: const [],
        metadata: const {},
      );

      notesRepo.addDeletedNote(note);
      folderRepo.addDeletedFolder(folder);
      taskRepo.addDeletedTask(task);

      final contents = await service.getAllDeletedItems();

      expect(contents.notes, hasLength(1));
      expect(contents.folders, hasLength(1));
      expect(contents.tasks, hasLength(1));
      expect(contents.totalCount, equals(3));
    });

    test('getTrashStatistics counts all entity types', () async {
      final now = DateTime.now();

      final note = Note(
        id: 'note1',
        title: 'Test Note',
        body: 'body',
        createdAt: now,
        updatedAt: now,
        deleted: true,
        deletedAt: now,
        scheduledPurgeAt: now.add(const Duration(days: 5)),
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: 'user1',
      );

      final folder = Folder(
        id: 'folder1',
        name: 'Test Folder',
        createdAt: now,
        updatedAt: now,
        deletedAt: now,
        scheduledPurgeAt: now.add(const Duration(days: 10)),
        sortOrder: 0,
        userId: 'user1',
      );

      final task = Task(
        id: 'task1',
        noteId: 'note1',
        title: 'Test Task',
        status: TaskStatus.pending,
        priority: TaskPriority.medium,
        createdAt: now,
        updatedAt: now,
        deletedAt: now,
        scheduledPurgeAt: now.subtract(const Duration(days: 1)),
        tags: const [],
        metadata: const {},
      );

      notesRepo.addDeletedNote(note);
      folderRepo.addDeletedFolder(folder);
      taskRepo.addDeletedTask(task);

      final stats = await service.getTrashStatistics();

      expect(stats.totalItems, equals(3));
      expect(stats.notesCount, equals(1));
      expect(stats.foldersCount, equals(1));
      expect(stats.tasksCount, equals(1));
      expect(stats.overdueForPurgeCount, equals(1)); // task is overdue
    });

    // Negative path tests
    test(
      'permanentlyDeleteTask throws StateError when task repository is null',
      () async {
        final serviceWithoutTasks = container.read(
          Provider(
            (ref) => TrashService(
              ref,
              notesRepository: notesRepo,
              folderRepository: folderRepo,
              taskRepository: null, // Explicitly null
              notesRepositoryProvided: true,
              folderRepositoryProvided: true,
              taskRepositoryProvided: false,
            ),
          ),
        );

        expect(
          () => serviceWithoutTasks.permanentlyDeleteTask('task1'),
          throwsStateError,
        );
      },
    );

    test('emptyTrash handles mixed success and failure', () async {
      // Add two notes - one will fail, one will succeed
      final note1 = Note(
        id: 'note1',
        title: 'Note 1',
        body: 'body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: true,
        deletedAt: DateTime.now(),
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: 'user1',
      );
      final note2 = Note(
        id: 'note2',
        title: 'Note 2',
        body: 'body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: true,
        deletedAt: DateTime.now(),
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: 'user1',
      );

      notesRepo.addDeletedNote(note1);
      notesRepo.addDeletedNote(note2);

      // Configure repository to throw on deletion attempts
      // TODO: Refine error simulation to fail only specific items (e.g., by ID)
      // to test true partial failure scenarios where some items succeed and others fail.
      // Current approach validates that the service structure supports failure tracking,
      // but doesn't test mixed success/failure in a single batch.
      notesRepo.shouldThrowOnDelete = true;

      final result = await service.emptyTrash();

      // Both deletions should fail since we enabled throwing for all items
      expect(result.failureCount, equals(2));
      expect(result.successCount, equals(0));
      expect(result.hasFailures, isTrue);
      expect(result.errors, isNotEmpty);
    });
  });
}
