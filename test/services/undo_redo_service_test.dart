import 'package:duru_notes/services/undo_redo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MoveNoteCall {
  _MoveNoteCall(this.noteId, this.folderId);

  final String noteId;
  final String? folderId;
}

class _MoveFolderCall {
  _MoveFolderCall(this.folderId, this.parentId);

  final String folderId;
  final String? parentId;
}

class _RecordingRepository {
  final List<_MoveNoteCall> moveNoteCalls = [];
  final List<_MoveFolderCall> moveFolderCalls = [];

  Future<void> moveNoteToFolder(String noteId, String? folderId) async {
    moveNoteCalls.add(_MoveNoteCall(noteId, folderId));
  }

  Future<void> moveFolder(String folderId, String? parentId) async {
    moveFolderCalls.add(_MoveFolderCall(folderId, parentId));
  }
}

class _UndoRedoHarness {
  _UndoRedoHarness._(this.repository, this.service);

  final _RecordingRepository repository;
  final UndoRedoService service;

  static Future<_UndoRedoHarness> create({
    Duration expiration = const Duration(seconds: 30),
    int maxStackSize = 50,
    String userId = 'test-user',
  }) async {
    final repository = _RecordingRepository();
    final service = UndoRedoService(
      repository: repository,
      userId: userId,
      maxStackSize: maxStackSize,
      defaultExpiration: expiration,
    );
    await _flushAsync();
    return _UndoRedoHarness._(repository, service);
  }

  Future<void> flush() => _flushAsync();

  void dispose() => service.dispose();
}

Future<void> _flushAsync() async {
  // Allow async initialisation/persistence work to complete.
  await pumpEventQueue();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  group('UndoRedoService', () {
    test('records note folder changes and exposes undo state', () async {
      final harness = await _UndoRedoHarness.create();
      addTearDown(harness.dispose);

      harness.service.recordNoteFolderChange(
        noteId: 'note-1',
        noteTitle: 'Test Note',
        previousFolderId: 'folder-a',
        previousFolderName: 'Folder A',
        newFolderId: 'folder-b',
        newFolderName: 'Folder B',
      );

      expect(harness.service.canUndo, isTrue);
      expect(harness.service.canRedo, isFalse);
      expect(
        harness.service.lastUndoOperation?.description,
        contains('Folder B'),
      );
    });

    test('undo note folder change restores previous folder', () async {
      final harness = await _UndoRedoHarness.create();
      addTearDown(harness.dispose);

      harness.service.recordNoteFolderChange(
        noteId: 'note-1',
        noteTitle: 'Test Note',
        previousFolderId: 'folder-a',
        previousFolderName: 'Folder A',
        newFolderId: 'folder-b',
        newFolderName: 'Folder B',
      );

      final result = await harness.service.undo();

      expect(result, isTrue);
      expect(harness.repository.moveNoteCalls, hasLength(1));
      expect(harness.repository.moveNoteCalls.single.folderId, 'folder-a');
      expect(harness.service.canUndo, isFalse);
      expect(harness.service.canRedo, isTrue);
    });

    test('redo note folder change reapplies destination folder', () async {
      final harness = await _UndoRedoHarness.create();
      addTearDown(harness.dispose);

      harness.service.recordNoteFolderChange(
        noteId: 'note-1',
        noteTitle: 'Test Note',
        previousFolderId: 'folder-a',
        previousFolderName: 'Folder A',
        newFolderId: 'folder-b',
        newFolderName: 'Folder B',
      );

      expect(await harness.service.undo(), isTrue);
      harness.repository.moveNoteCalls.clear();

      expect(await harness.service.redo(), isTrue);
      expect(harness.repository.moveNoteCalls, hasLength(1));
      expect(harness.repository.moveNoteCalls.single.folderId, 'folder-b');
      expect(harness.service.canUndo, isTrue);
      expect(harness.service.canRedo, isFalse);
    });

    test('recordNoteFolderChange handles unfiling descriptions', () async {
      final harness = await _UndoRedoHarness.create();
      addTearDown(harness.dispose);

      harness.service.recordNoteFolderChange(
        noteId: 'note-1',
        noteTitle: 'Test Note',
        previousFolderId: 'folder-a',
        previousFolderName: 'Folder A',
        newFolderId: null,
        newFolderName: null,
      );

      expect(harness.service.lastUndoOperation, isNotNull);
      expect(
        harness.service.lastUndoOperation!.description,
        contains('Unfiled'),
      );
    });

    test('records batch folder change with correct description', () async {
      final harness = await _UndoRedoHarness.create();
      addTearDown(harness.dispose);

      harness.service.recordBatchFolderChange(
        noteIds: const ['note-1', 'note-2', 'note-3'],
        previousFolderIds: const {
          'note-1': 'folder-a',
          'note-2': 'folder-b',
          'note-3': null,
        },
        newFolderId: 'folder-c',
        newFolderName: 'Folder C',
      );

      expect(harness.service.canUndo, isTrue);
      expect(
        harness.service.lastUndoOperation?.description,
        contains('Folder C'),
      );
    });

    test('undo batch folder change restores previous folders', () async {
      final harness = await _UndoRedoHarness.create();
      addTearDown(harness.dispose);

      harness.service.recordBatchFolderChange(
        noteIds: const ['note-1', 'note-2'],
        previousFolderIds: const {'note-1': 'folder-a', 'note-2': 'folder-b'},
        newFolderId: 'folder-c',
        newFolderName: 'Folder C',
      );

      final result = await harness.service.undo();

      expect(result, isTrue);
      expect(harness.repository.moveNoteCalls, hasLength(2));
      expect(harness.repository.moveNoteCalls[0].folderId, 'folder-a');
      expect(harness.repository.moveNoteCalls[1].folderId, 'folder-b');
      expect(harness.service.canRedo, isTrue);
    });

    test(
      'redo batch folder change reapplies new folder to all notes',
      () async {
        final harness = await _UndoRedoHarness.create();
        addTearDown(harness.dispose);

        harness.service.recordBatchFolderChange(
          noteIds: const ['note-1', 'note-2'],
          previousFolderIds: const {'note-1': 'folder-a', 'note-2': 'folder-b'},
          newFolderId: 'folder-c',
          newFolderName: 'Folder C',
        );

        expect(await harness.service.undo(), isTrue);
        harness.repository.moveNoteCalls.clear();

        expect(await harness.service.redo(), isTrue);
        expect(harness.repository.moveNoteCalls, hasLength(2));
        expect(harness.repository.moveNoteCalls[0].folderId, 'folder-c');
        expect(harness.repository.moveNoteCalls[1].folderId, 'folder-c');
        expect(harness.service.canUndo, isTrue);
        expect(harness.service.canRedo, isFalse);
      },
    );

    test('new operation clears redo stack', () async {
      final harness = await _UndoRedoHarness.create();
      addTearDown(harness.dispose);

      harness.service.recordNoteFolderChange(
        noteId: 'note-1',
        noteTitle: 'Note 1',
        previousFolderId: null,
        previousFolderName: null,
        newFolderId: 'folder-a',
        newFolderName: 'Folder A',
      );

      expect(await harness.service.undo(), isTrue);
      expect(harness.service.canRedo, isTrue);

      harness.service.recordNoteFolderChange(
        noteId: 'note-2',
        noteTitle: 'Note 2',
        previousFolderId: null,
        previousFolderName: null,
        newFolderId: 'folder-b',
        newFolderName: 'Folder B',
      );

      expect(harness.service.canRedo, isFalse);
      expect(harness.service.canUndo, isTrue);
    });

    test('clearHistory empties undo and redo stacks', () async {
      final harness = await _UndoRedoHarness.create();
      addTearDown(harness.dispose);

      harness.service.recordNoteFolderChange(
        noteId: 'note-1',
        noteTitle: 'Note 1',
        previousFolderId: null,
        previousFolderName: null,
        newFolderId: 'folder-a',
        newFolderName: 'Folder A',
      );

      expect(harness.service.canUndo, isTrue);

      harness.service.clearHistory();

      expect(harness.service.canUndo, isFalse);
      expect(harness.service.canRedo, isFalse);
    });

    test('respects max stack size by trimming earliest operations', () async {
      final harness = await _UndoRedoHarness.create(maxStackSize: 3);
      addTearDown(harness.dispose);

      for (var i = 0; i < 5; i++) {
        harness.service.recordNoteFolderChange(
          noteId: 'note-$i',
          noteTitle: 'Note $i',
          previousFolderId: null,
          previousFolderName: null,
          newFolderId: 'folder-$i',
          newFolderName: 'Folder $i',
        );
      }

      expect(harness.service.canUndo, isTrue);
      expect(
        harness.service.lastUndoOperation?.description,
        contains('Note 4'),
      );

      await harness.service.undo();
      expect(
        harness.service.lastUndoOperation?.description,
        contains('Note 3'),
      );
      await harness.service.undo();
      expect(
        harness.service.lastUndoOperation?.description,
        contains('Note 2'),
      );
      await harness.service.undo();
      expect(harness.service.canUndo, isFalse);
    });

    test('expired operations do not execute during undo', () async {
      final harness = await _UndoRedoHarness.create(
        expiration: const Duration(milliseconds: 1),
      );
      addTearDown(harness.dispose);

      harness.service.recordNoteFolderChange(
        noteId: 'note-1',
        noteTitle: 'Note 1',
        previousFolderId: 'folder-a',
        previousFolderName: 'Folder A',
        newFolderId: 'folder-b',
        newFolderName: 'Folder B',
      );

      await Future<void>.delayed(const Duration(milliseconds: 5));

      final result = await harness.service.undo();

      expect(result, isFalse);
      expect(harness.repository.moveNoteCalls, isEmpty);
      expect(harness.service.canUndo, isFalse);
    });

    test('records folder moves and provides undo support', () async {
      final harness = await _UndoRedoHarness.create();
      addTearDown(harness.dispose);

      harness.service.recordFolderMove(
        folderId: 'folder-1',
        folderName: 'Child Folder',
        previousParentId: null,
        newParentId: 'parent-1',
      );

      expect(harness.service.canUndo, isTrue);
      expect(
        harness.service.lastUndoOperation?.description,
        contains('Moved folder'),
      );

      final result = await harness.service.undo();

      expect(result, isTrue);
      expect(harness.repository.moveFolderCalls, hasLength(1));
      expect(harness.repository.moveFolderCalls.single.parentId, isNull);
    });

    test('undo history persists and rehydrates from storage', () async {
      final firstHarness = await _UndoRedoHarness.create(
        userId: 'persist-user',
      );

      firstHarness.service.recordNoteFolderChange(
        noteId: 'note-1',
        noteTitle: 'Persistent Note',
        previousFolderId: 'folder-a',
        previousFolderName: 'Folder A',
        newFolderId: 'folder-b',
        newFolderName: 'Folder B',
      );

      await firstHarness.flush();
      firstHarness.dispose();

      final secondHarness = await _UndoRedoHarness.create(
        userId: 'persist-user',
      );
      addTearDown(secondHarness.dispose);

      expect(secondHarness.service.canUndo, isTrue);
      expect(
        secondHarness.service.lastUndoOperation?.description,
        contains('Folder B'),
      );

      await secondHarness.service.undo();

      expect(secondHarness.repository.moveNoteCalls, hasLength(1));
      expect(
        secondHarness.repository.moveNoteCalls.single.folderId,
        'folder-a',
      );
    });
  });
}
