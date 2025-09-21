import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/services/undo_redo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNotesRepository extends Mock implements NotesRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UndoRedoService', () {
    late UndoRedoService service;
    late MockNotesRepository mockRepository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockRepository = MockNotesRepository();
      service = UndoRedoService(
        repository: mockRepository,
        userId: 'test_user',
        defaultExpiration: const Duration(seconds: 30),
      );
    });

    tearDown(() {
      service.dispose();
    });

    group('Note Folder Operations', () {
      test('should record note folder change operation', () {
        service.recordNoteFolderChange(
          noteId: 'note1',
          noteTitle: 'Test Note',
          previousFolderId: 'folder1',
          previousFolderName: 'Folder 1',
          newFolderId: 'folder2',
          newFolderName: 'Folder 2',
        );

        expect(service.canUndo, isTrue);
        expect(service.canRedo, isFalse);
        expect(service.lastUndoOperation, isNotNull);
        expect(service.lastUndoOperation!.description, contains('Test Note'));
      });

      test('should undo note folder change', () async {
        // Setup mock
        when(mockRepository.moveNoteToFolder('note1', 'folder1'))
            .thenAnswer((_) async => {});

        service.recordNoteFolderChange(
          noteId: 'note1',
          noteTitle: 'Test Note',
          previousFolderId: 'folder1',
          previousFolderName: 'Folder 1',
          newFolderId: 'folder2',
          newFolderName: 'Folder 2',
        );

        final result = await service.undo();

        expect(result, isTrue);
        expect(service.canUndo, isFalse);
        expect(service.canRedo, isTrue);
        verify(mockRepository.moveNoteToFolder('note1', 'folder1')).called(1);
      });

      test('should redo note folder change', () async {
        // Setup mock
        when(mockRepository.moveNoteToFolder(any, any))
            .thenAnswer((_) async => {});

        service.recordNoteFolderChange(
          noteId: 'note1',
          noteTitle: 'Test Note',
          previousFolderId: 'folder1',
          previousFolderName: 'Folder 1',
          newFolderId: 'folder2',
          newFolderName: 'Folder 2',
        );

        await service.undo();
        final result = await service.redo();

        expect(result, isTrue);
        expect(service.canUndo, isTrue);
        expect(service.canRedo, isFalse);
        verify(mockRepository.moveNoteToFolder('note1', 'folder2')).called(1);
      });

      test('should handle unfiling (moving to null folder)', () {
        service.recordNoteFolderChange(
          noteId: 'note1',
          noteTitle: 'Test Note',
          previousFolderId: 'folder1',
          previousFolderName: 'Folder 1',
          newFolderId: null,
          newFolderName: null,
        );

        expect(service.lastUndoOperation!.description, contains('Unfiled'));
      });
    });

    group('Batch Operations', () {
      test('should record batch folder change operation', () {
        service.recordBatchFolderChange(
          noteIds: ['note1', 'note2', 'note3'],
          previousFolderIds: {
            'note1': 'folder1',
            'note2': 'folder2',
            'note3': null,
          },
          newFolderId: 'folder3',
          newFolderName: 'Folder 3',
        );

        expect(service.canUndo, isTrue);
        expect(service.lastUndoOperation!.description, contains('3 notes'));
      });

      test('should undo batch folder change', () async {
        // Setup mock
        when(mockRepository.moveNoteToFolder(any, any))
            .thenAnswer((_) async => {});

        service.recordBatchFolderChange(
          noteIds: ['note1', 'note2'],
          previousFolderIds: {
            'note1': 'folder1',
            'note2': 'folder2',
          },
          newFolderId: 'folder3',
          newFolderName: 'Folder 3',
        );

        await service.undo();

        verify(mockRepository.moveNoteToFolder('note1', 'folder1')).called(1);
        verify(mockRepository.moveNoteToFolder('note2', 'folder2')).called(1);
      });

      test('should handle batch unfiling', () {
        service.recordBatchFolderChange(
          noteIds: ['note1', 'note2'],
          previousFolderIds: {
            'note1': 'folder1',
            'note2': 'folder2',
          },
          newFolderId: null,
          newFolderName: null,
        );

        expect(service.lastUndoOperation!.description,
            contains('Unfiled 2 notes'));
      });
    });

    group('Stack Management', () {
      test('should limit stack size', () {
        final smallService = UndoRedoService(
          repository: mockRepository,
          userId: 'test_user',
          maxStackSize: 3,
        );

        // Add 5 operations
        for (int i = 0; i < 5; i++) {
          smallService.recordNoteFolderChange(
            noteId: 'note$i',
            noteTitle: 'Note $i',
            previousFolderId: null,
            previousFolderName: null,
            newFolderId: 'folder$i',
            newFolderName: 'Folder $i',
          );
        }

        // Stack should only contain last 3
        expect(smallService.lastUndoOperation!.description, contains('Note 4'));

        smallService.dispose();
      });

      test('should clear redo stack on new operation', () async {
        when(mockRepository.moveNoteToFolder(any, any))
            .thenAnswer((_) async => {});

        service.recordNoteFolderChange(
          noteId: 'note1',
          noteTitle: 'Note 1',
          previousFolderId: 'folder1',
          previousFolderName: 'Folder 1',
          newFolderId: 'folder2',
          newFolderName: 'Folder 2',
        );

        await service.undo();
        expect(service.canRedo, isTrue);

        service.recordNoteFolderChange(
          noteId: 'note2',
          noteTitle: 'Note 2',
          previousFolderId: null,
          previousFolderName: null,
          newFolderId: 'folder3',
          newFolderName: 'Folder 3',
        );

        expect(service.canRedo, isFalse);
      });

      test('should clear all history', () {
        service.recordNoteFolderChange(
          noteId: 'note1',
          noteTitle: 'Note 1',
          previousFolderId: null,
          previousFolderName: null,
          newFolderId: 'folder1',
          newFolderName: 'Folder 1',
        );

        expect(service.canUndo, isTrue);

        service.clearHistory();

        expect(service.canUndo, isFalse);
        expect(service.canRedo, isFalse);
      });
    });

    group('Expiration', () {
      test('should not execute expired operations', () async {
        final shortExpiryService = UndoRedoService(
          repository: mockRepository,
          userId: 'test_user',
          defaultExpiration: const Duration(milliseconds: 1),
        );

        shortExpiryService.recordNoteFolderChange(
          noteId: 'note1',
          noteTitle: 'Note 1',
          previousFolderId: 'folder1',
          previousFolderName: 'Folder 1',
          newFolderId: 'folder2',
          newFolderName: 'Folder 2',
        );

        // Wait for expiration
        await Future.delayed(const Duration(milliseconds: 10));

        final result = await shortExpiryService.undo();

        expect(result, isFalse);
        expect(shortExpiryService.canUndo, isFalse);

        shortExpiryService.dispose();
      });
    });

    group('Folder Move Operations', () {
      test('should record folder move operation', () {
        service.recordFolderMove(
          folderId: 'folder1',
          folderName: 'Subfolder',
          previousParentId: null,
          newParentId: 'parent1',
        );

        expect(service.canUndo, isTrue);
        expect(
            service.lastUndoOperation!.description, contains('Moved folder'));
      });

      test('should undo folder move', () async {
        when(mockRepository.moveFolder('folder1', null))
            .thenAnswer((_) async => {});

        service.recordFolderMove(
          folderId: 'folder1',
          folderName: 'Subfolder',
          previousParentId: null,
          newParentId: 'parent1',
        );

        await service.undo();

        verify(mockRepository.moveFolder('folder1', null)).called(1);
      });
    });
  });
}
