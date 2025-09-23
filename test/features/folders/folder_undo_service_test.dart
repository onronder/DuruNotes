import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/repository/folder_repository.dart';
import 'package:duru_notes/services/folder_undo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'folder_undo_service_test.mocks.dart';

// Generate mocks for testing
@GenerateMocks([FolderRepository])
void main() {
  group('FolderUndoService Tests', () {
    late FolderUndoService undoService;
    late MockFolderRepository mockRepository;

    setUp(() {
      mockRepository = MockFolderRepository();
      undoService = FolderUndoService(mockRepository);
    });

    tearDown(() {
      undoService.dispose();
    });

    test('addDeleteOperation creates undo operation', () async {
      final folder = LocalFolder(
        id: 'test-folder',
        name: 'Test Folder',
        parentId: null,
        path: '/Test Folder',
        sortOrder: 0,
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      final operationId = await undoService.addDeleteOperation(
        folder: folder,
        affectedNotes: ['note-1', 'note-2'],
        affectedChildFolders: [],
      );

      expect(operationId, isNotNull);
      expect(undoService.currentHistory.length, equals(1));

      final operation = undoService.currentHistory.first;
      expect(operation.type, equals(FolderUndoType.delete));
      expect(operation.originalFolder.id, equals('test-folder'));
      expect(operation.affectedNotes, equals(['note-1', 'note-2']));
    });

    test('addMoveOperation creates undo operation', () async {
      final folder = LocalFolder(
        id: 'test-folder',
        name: 'Test Folder',
        parentId: 'new-parent',
        path: '/New Parent/Test Folder',
        sortOrder: 0,
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      final operationId = await undoService.addMoveOperation(
        folder: folder,
        originalParentId: 'old-parent',
      );

      expect(operationId, isNotNull);
      expect(undoService.currentHistory.length, equals(1));

      final operation = undoService.currentHistory.first;
      expect(operation.type, equals(FolderUndoType.move));
      expect(operation.originalFolder.id, equals('test-folder'));
      expect(operation.originalParentId, equals('old-parent'));
    });

    test('addRenameOperation creates undo operation', () async {
      final folder = LocalFolder(
        id: 'test-folder',
        name: 'New Name',
        parentId: null,
        path: '/New Name',
        sortOrder: 0,
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      final operationId = await undoService.addRenameOperation(
        folder: folder,
        originalName: 'Old Name',
      );

      expect(operationId, isNotNull);
      expect(undoService.currentHistory.length, equals(1));

      final operation = undoService.currentHistory.first;
      expect(operation.type, equals(FolderUndoType.rename));
      expect(operation.originalFolder.id, equals('test-folder'));
      expect(operation.originalName, equals('Old Name'));
    });

    test('getLatestOperation returns most recent operation', () async {
      final folder1 = LocalFolder(
        id: 'folder-1',
        name: 'Folder 1',
        parentId: null,
        path: '/Folder 1',
        sortOrder: 0,
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      final folder2 = LocalFolder(
        id: 'folder-2',
        name: 'Folder 2',
        parentId: null,
        path: '/Folder 2',
        sortOrder: 0,
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      await undoService.addDeleteOperation(
        folder: folder1,
        affectedNotes: [],
        affectedChildFolders: [],
      );

      await Future.delayed(const Duration(milliseconds: 10));

      await undoService.addDeleteOperation(
        folder: folder2,
        affectedNotes: [],
        affectedChildFolders: [],
      );

      final latest = undoService.getLatestOperation();
      expect(latest?.originalFolder.id, equals('folder-2'));
    });

    test('clearHistory removes all operations', () async {
      final folder = LocalFolder(
        id: 'test-folder',
        name: 'Test Folder',
        parentId: null,
        path: '/Test Folder',
        sortOrder: 0,
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      await undoService.addDeleteOperation(
        folder: folder,
        affectedNotes: [],
        affectedChildFolders: [],
      );

      expect(undoService.currentHistory.length, equals(1));

      undoService.clearHistory();

      expect(undoService.currentHistory.length, equals(0));
    });

    test('operations expire after 5 minutes', () {
      final expiredOperation = FolderUndoOperation(
        id: 'expired-op',
        type: FolderUndoType.delete,
        timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
        originalFolder: LocalFolder(
          id: 'test-folder',
          name: 'Test Folder',
          parentId: null,
          path: '/Test Folder',
          sortOrder: 0,
          description: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
        ),
      );

      expect(expiredOperation.isExpired, isTrue);
    });

    test('fresh operations are not expired', () {
      final freshOperation = FolderUndoOperation(
        id: 'fresh-op',
        type: FolderUndoType.delete,
        timestamp: DateTime.now(),
        originalFolder: LocalFolder(
          id: 'test-folder',
          name: 'Test Folder',
          parentId: null,
          path: '/Test Folder',
          sortOrder: 0,
          description: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deleted: false,
        ),
      );

      expect(freshOperation.isExpired, isFalse);
    });

    test('undo operation fails for expired operations', () async {
      final folder = LocalFolder(
        id: 'test-folder',
        name: 'Test Folder',
        parentId: null,
        path: '/Test Folder',
        sortOrder: 0,
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      await undoService.addDeleteOperation(
        folder: folder,
        affectedNotes: [],
        affectedChildFolders: [],
      );

      final operation = undoService.currentHistory.first;

      // Mock the operation as expired
      final expiredOperation = FolderUndoOperation(
        id: operation.id,
        type: operation.type,
        timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
        originalFolder: operation.originalFolder,
      );

      // Replace with expired operation
      undoService.clearHistory();

      // Try to undo expired operation
      final success = await undoService.undoOperation(expiredOperation.id);
      expect(success, isFalse);
    });

    test('description returns correct format for different operation types', () {
      final folder = LocalFolder(
        id: 'test-folder',
        name: 'Test Folder',
        parentId: null,
        path: '/Test Folder',
        sortOrder: 0,
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      final deleteOp = FolderUndoOperation(
        id: 'delete-op',
        type: FolderUndoType.delete,
        timestamp: DateTime.now(),
        originalFolder: folder,
      );
      expect(deleteOp.description, equals('Delete folder "Test Folder"'));

      final moveOp = FolderUndoOperation(
        id: 'move-op',
        type: FolderUndoType.move,
        timestamp: DateTime.now(),
        originalFolder: folder,
      );
      expect(moveOp.description, equals('Move folder "Test Folder"'));

      final renameOp = FolderUndoOperation(
        id: 'rename-op',
        type: FolderUndoType.rename,
        timestamp: DateTime.now(),
        originalFolder: folder,
      );
      expect(renameOp.description, equals('Rename folder to "Test Folder"'));
    });

    test('history stream emits updates', () async {
      final folder = LocalFolder(
        id: 'test-folder',
        name: 'Test Folder',
        parentId: null,
        path: '/Test Folder',
        sortOrder: 0,
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      // Listen to history stream
      final historyEvents = <List<FolderUndoOperation>>[];
      final subscription = undoService.historyStream.listen(historyEvents.add);

      // Add operation
      await undoService.addDeleteOperation(
        folder: folder,
        affectedNotes: [],
        affectedChildFolders: [],
      );

      // Wait for stream emission
      await Future.delayed(const Duration(milliseconds: 100));

      expect(historyEvents.length, greaterThan(0));
      expect(historyEvents.last.length, equals(1));

      await subscription.cancel();
    });
  });
}