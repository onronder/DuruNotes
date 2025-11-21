import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/services/folder_undo_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingFolderRepository implements IFolderRepository {
  final List<Map<String, dynamic>> createOrUpdateCalls = [];
  final List<Map<String, dynamic>> moveFolderCalls = [];
  final List<Map<String, dynamic>> renameFolderCalls = [];

  @override
  Future<String> createOrUpdateFolder({
    required String name,
    String? id,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
  }) async {
    createOrUpdateCalls.add({
      'id': id,
      'name': name,
      'parentId': parentId,
      'color': color,
      'icon': icon,
      'description': description,
      'sortOrder': sortOrder,
    });
    return id ?? name;
  }

  @override
  Future<void> moveFolder(String folderId, String? newParentId) async {
    moveFolderCalls.add({'folderId': folderId, 'parentId': newParentId});
  }

  @override
  Future<void> renameFolder(String folderId, String newName) async {
    renameFolderCalls.add({'folderId': folderId, 'name': newName});
  }

  // The remaining interface members are not required for these tests.
  @override
  Future<domain.Folder?> getFolder(String id) async => null;
  @override
  Future<List<domain.Folder>> listFolders() async => const [];
  @override
  Future<List<domain.Folder>> getRootFolders() async => const [];
  @override
  Future<domain.Folder?> findFolderByName(String name) async => null;
  @override
  Future<int> getNotesCountInFolder(String folderId) async => 0;
  @override
  Future<Map<String, int>> getFolderNoteCounts() async => const {};
  @override
  Future<domain.Folder> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) => throw UnimplementedError();
  @override
  Future<void> deleteFolder(String folderId) => throw UnimplementedError();
  @override
  Future<List<domain.Note>> getNotesInFolder(String folderId) async => const [];
  @override
  Future<List<domain.Note>> getUnfiledNotes() async => const [];
  @override
  Future<void> addNoteToFolder(String noteId, String folderId) =>
      throw UnimplementedError();
  @override
  Future<void> moveNoteToFolder(String noteId, String? folderId) =>
      throw UnimplementedError();
  @override
  Future<void> removeNoteFromFolder(String noteId) =>
      throw UnimplementedError();
  @override
  Future<domain.Folder?> getFolderForNote(String noteId) async => null;
  @override
  Future<List<domain.Folder>> getChildFolders(String parentId) async =>
      const [];
  @override
  Future<List<domain.Folder>> getChildFoldersRecursive(String parentId) async =>
      const [];
  @override
  Future<int> getFolderDepth(String folderId) async => 0;
  @override
  Future<List<String>> getNoteIdsInFolder(String folderId) async => const [];
  @override
  Future<void> ensureFolderIntegrity() async {}
  @override
  Future<Map<String, dynamic>> performFolderHealthCheck() async => const {};
  @override
  Future<void> validateAndRepairFolderStructure() async {}
  @override
  Future<void> cleanupOrphanedRelationships() async {}
  @override
  Future<void> resolveFolderConflicts() async {}
  @override
  String? getCurrentUserId() => 'test-user';
  @override
  Future<List<domain.Folder>> getDeletedFolders() async => const [];
  @override
  Future<void> restoreFolder(String folderId, {bool restoreContents = false}) async {}

  @override
  Future<void> permanentlyDeleteFolder(String folderId) async {}

  @override
  Future<int> anonymizeAllFoldersForUser(String userId) async => 0;
}

domain.Folder _buildFolder({
  required String id,
  required String name,
  String? parentId,
  String? color,
  String? icon,
}) {
  final now = DateTime.utc(2025, 1, 1);
  return domain.Folder(
    id: id,
    name: name,
    parentId: parentId,
    color: color,
    icon: icon,
    description: 'desc-$id',
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
    userId: 'user-1',
  );
}

void main() {
  group('FolderUndoService', () {
    late _RecordingFolderRepository repository;
    late FolderUndoService service;

    setUp(() {
      repository = _RecordingFolderRepository();
      service = FolderUndoService(repository);
    });

    tearDown(() {
      service.dispose();
    });

    test('addDeleteOperation enqueues operation with metadata', () async {
      final folder = _buildFolder(id: 'root', name: 'Root');
      final child = _buildFolder(id: 'child', name: 'Child', parentId: 'root');

      final id = await service.addDeleteOperation(
        folder: folder,
        affectedNotes: const ['n-1', 'n-2'],
        affectedChildFolders: [child],
      );

      expect(id, isNotEmpty);
      final history = service.currentHistory;
      expect(history, hasLength(1));
      final op = history.single;
      expect(op.type, FolderUndoType.delete);
      expect(op.originalFolder.id, 'root');
      expect(op.affectedNotes, ['n-1', 'n-2']);
      expect(op.affectedChildFolders.single.id, 'child');
    });

    test('undoOperation restores deleted folder and children', () async {
      final folder = _buildFolder(id: 'root', name: 'Root', color: 'blue');
      final child = _buildFolder(id: 'child', name: 'Child', parentId: 'root');

      final opId = await service.addDeleteOperation(
        folder: folder,
        affectedNotes: const ['n-1'],
        affectedChildFolders: [child],
      );

      final result = await service.undoOperation(opId);

      expect(result, isTrue);
      expect(service.currentHistory, isEmpty);
      expect(repository.createOrUpdateCalls, hasLength(2));
      final parentCall = repository.createOrUpdateCalls.firstWhere(
        (call) => call['id'] == 'root',
      );
      expect(parentCall['color'], equals('blue'));
      final childCall = repository.createOrUpdateCalls.firstWhere(
        (call) => call['id'] == 'child',
      );
      expect(childCall['parentId'], equals('root'));
    });

    test('undoOperation restores previous parent for move', () async {
      final folder = _buildFolder(id: 'organizer', name: 'Organizer');

      final opId = await service.addMoveOperation(
        folder: folder,
        originalParentId: 'previous-parent',
      );

      final result = await service.undoOperation(opId);

      expect(result, isTrue);
      expect(repository.moveFolderCalls, hasLength(1));
      final call = repository.moveFolderCalls.single;
      expect(call['folderId'], 'organizer');
      expect(call['parentId'], 'previous-parent');
    });

    test('undoOperation restores original folder name after rename', () async {
      final renamed = _buildFolder(id: 'root', name: 'Renamed Root');

      final opId = await service.addRenameOperation(
        folder: renamed,
        originalName: 'Original Root',
      );

      final result = await service.undoOperation(opId);

      expect(result, isTrue);
      expect(repository.renameFolderCalls, hasLength(1));
      final call = repository.renameFolderCalls.single;
      expect(call['folderId'], 'root');
      expect(call['name'], 'Original Root');
    });

    test('history stream emits updates when operations change', () async {
      final folder = _buildFolder(id: 'root', name: 'Root');
      final emissions = <List<FolderUndoOperation>>[];
      final sub = service.historyStream.listen(emissions.add);

      final opId = await service.addDeleteOperation(
        folder: folder,
        affectedNotes: const [],
        affectedChildFolders: const [],
      );

      await service.undoOperation(opId);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      // Expect two emissions: one after add, one after undo/removal.
      expect(emissions, hasLength(greaterThanOrEqualTo(2)));
      expect(emissions.first, hasLength(1));
      expect(emissions.last, isEmpty);
    });
  });
}
