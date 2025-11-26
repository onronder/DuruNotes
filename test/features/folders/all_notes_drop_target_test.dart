import 'package:duru_notes/core/providers/auth_providers.dart'
    show userIdProvider;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/features/folders/folder_filter_chips.dart';
import 'package:duru_notes/features/folders/providers/folders_integration_providers.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart';
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart'
    as folder_state;
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/services/providers/services_providers.dart';
import 'package:duru_notes/services/undo_redo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingFolderRepository implements IFolderRepository {
  final Map<String, String?> noteFolderAssignments = {};
  final List<String> removeNoteCalls = [];
  final List<Map<String, dynamic>> getFolderForNoteCalls = [];

  @override
  Future<domain.Folder?> getFolder(String id) async => null;

  @override
  Future<domain.Folder?> getFolderForNote(String noteId) async {
    getFolderForNoteCalls.add({'noteId': noteId});
    final folderId = noteFolderAssignments[noteId];
    if (folderId == null) return null;
    return domain.Folder(
      id: folderId,
      name: 'Folder $folderId',
      parentId: null,
      color: null,
      icon: null,
      description: null,
      sortOrder: 0,
      createdAt: DateTime.utc(2025, 1, 1),
      updatedAt: DateTime.utc(2025, 1, 1),
      userId: 'user-1',
    );
  }

  @override
  Future<void> removeNoteFromFolder(String noteId) async {
    removeNoteCalls.add(noteId);
    noteFolderAssignments[noteId] = null;
  }

  // Unused members return defaults/no-ops
  @override
  Future<String> createOrUpdateFolder({
    required String name,
    String? id,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
  }) async => id ?? name;
  @override
  Future<void> addNoteToFolder(String noteId, String folderId) async {}
  @override
  Future<void> cleanupOrphanedRelationships() async {}
  @override
  Future<domain.Folder> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) => throw UnimplementedError();
  @override
  Future<void> deleteFolder(String folderId) async {}
  @override
  Future<List<domain.Folder>> getChildFolders(String parentId) async =>
      const [];
  @override
  Future<List<domain.Folder>> getChildFoldersRecursive(String parentId) async =>
      const [];
  @override
  Future<int> getFolderDepth(String folderId) async => 0;
  @override
  Future<Map<String, dynamic>> performFolderHealthCheck() async => const {};
  @override
  Future<List<domain.Folder>> getRootFolders() async => const [];
  @override
  Future<List<String>> getNoteIdsInFolder(String folderId) async => const [];
  @override
  Future<List<domain.Note>> getNotesInFolder(String folderId) async => const [];
  @override
  Future<List<domain.Note>> getUnfiledNotes() async => const [];
  @override
  Future<void> moveFolder(String folderId, String? newParentId) async {}
  @override
  Future<void> moveNoteToFolder(String noteId, String? folderId) async {}
  @override
  Future<Map<String, int>> getFolderNoteCounts() async => const {};
  @override
  Future<int> getNotesCountInFolder(String folderId) async => 0;
  @override
  Future<void> resolveFolderConflicts() async {}
  @override
  Future<void> renameFolder(String folderId, String newName) async {}
  @override
  Future<void> ensureFolderIntegrity() async {}
  @override
  Future<void> validateAndRepairFolderStructure() async {}
  @override
  Future<domain.Folder?> findFolderByName(String name) async => null;
  @override
  Future<List<domain.Folder>> listFolders() async => const [];
  @override
  Future<List<domain.Folder>> getDeletedFolders() async => const [];
  @override
  Future<void> restoreFolder(
    String folderId, {
    bool restoreContents = false,
  }) async {}

  @override
  Future<void> permanentlyDeleteFolder(String folderId) async {}
  @override
  String? getCurrentUserId() => 'user-1';

  @override
  Future<int> anonymizeAllFoldersForUser(String userId) async => 0;
}

class _AllNotesHarness {
  _AllNotesHarness({int unfiledCount = 0}) {
    folderRepository = _RecordingFolderRepository();
    undoService = _MockUndoRedoService();
    mockNotesRepository = _MockNotesCoreRepository();

    container = ProviderContainer(
      overrides: [
        folderCoreRepositoryProvider.overrideWithValue(folderRepository),
        folderRepositoryProvider.overrideWithValue(folderRepository),
        notesCoreRepositoryProvider.overrideWithValue(mockNotesRepository),
        undoRedoServiceProvider.overrideWith((ref) => undoService),
        folder_state.currentFolderProvider.overrideWith(
          (ref) => _TrackingCurrentFolderNotifier(),
        ),
        rootFoldersProvider.overrideWith((_) async => const <domain.Folder>[]),
        unfiledNotesCountProvider.overrideWith((_) async => unfiledCount),
        userIdProvider.overrideWithValue('user-1'),
      ],
    );
  }

  late final ProviderContainer container;
  late final _RecordingFolderRepository folderRepository;
  late final _MockUndoRedoService undoService;
  late final _MockNotesCoreRepository mockNotesRepository;

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  void dispose() => container.dispose();
}

class _MockNotesCoreRepository extends Mock implements NotesCoreRepository {}

class _MockUndoRedoService extends Mock implements UndoRedoService {
  @override
  Future<bool> undo() =>
      super.noSuchMethod(
            Invocation.method(#undo, []),
            returnValue: Future<bool>.value(true),
            returnValueForMissingStub: Future<bool>.value(true),
          )
          as Future<bool>;
}

class _TrackingCurrentFolderNotifier extends CurrentFolderNotifier {}

LocalNote _buildLocalNote(String id) {
  final timestamp = DateTime.utc(2025, 1, 1);
  return LocalNote(
    id: id,
    titleEncrypted: 'title-$id',
    bodyEncrypted: 'body-$id',
    metadataEncrypted: null,
    encryptionVersion: 1,
    createdAt: timestamp,
    updatedAt: timestamp,
    deleted: false,
    encryptedMetadata: null,
    isPinned: false,
    noteType: NoteKind.note,
    version: 1,
    userId: 'user-1',
    attachmentMeta: null,
    metadata: null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(const {});

  testWidgets('shows All Notes chip by default', (tester) async {
    final harness = _AllNotesHarness();
    addTearDown(harness.dispose);

    await harness.pump(
      tester,
      const FolderFilterChips(showCreateOption: false),
    );

    final scope = tester.element(find.byType(FolderFilterChips));
    final label = AppLocalizations.of(scope).notesListTitle;

    expect(find.text(label), findsOneWidget);
    expect(find.byIcon(Icons.notes), findsOneWidget);
  });

  testWidgets('unfiles a single note via drag-and-drop', (tester) async {
    final harness = _AllNotesHarness();
    addTearDown(harness.dispose);
    final note = _buildLocalNote('note-1');
    harness.folderRepository.noteFolderAssignments['note-1'] = 'folder-a';

    await harness.pump(
      tester,
      Column(
        children: [
          const FolderFilterChips(showCreateOption: false),
          Draggable<LocalNote>(
            data: note,
            feedback: const Material(child: Text('dragging')),
            child: const Text('drag me'),
          ),
        ],
      ),
    );

    final scope = tester.element(find.byType(FolderFilterChips));
    final label = AppLocalizations.of(scope).notesListTitle;

    final drag = await tester.startGesture(
      tester.getCenter(find.text('drag me')),
    );
    await drag.moveTo(tester.getCenter(find.text(label)));
    await tester.pump(const Duration(milliseconds: 50));
    await drag.up();
    await tester.pump(const Duration(milliseconds: 200));

    expect(harness.folderRepository.removeNoteCalls, ['note-1']);
    expect(harness.folderRepository.noteFolderAssignments['note-1'], isNull);
  });

  testWidgets('unfiles batch of notes via drag-and-drop', (tester) async {
    final harness = _AllNotesHarness();
    addTearDown(harness.dispose);
    final noteA = _buildLocalNote('note-a');
    final noteB = _buildLocalNote('note-b');
    harness.folderRepository.noteFolderAssignments.addAll({
      'note-a': 'folder-1',
      'note-b': 'folder-2',
    });

    await harness.pump(
      tester,
      Column(
        children: [
          const FolderFilterChips(showCreateOption: false),
          Draggable<List<LocalNote>>(
            data: [noteA, noteB],
            feedback: const Material(child: Text('batch')),
            child: const Text('drag batch'),
          ),
        ],
      ),
    );

    final scope = tester.element(find.byType(FolderFilterChips));
    final label = AppLocalizations.of(scope).notesListTitle;

    final drag = await tester.startGesture(
      tester.getCenter(find.text('drag batch')),
    );
    await drag.moveTo(tester.getCenter(find.text(label)));
    await tester.pump(const Duration(milliseconds: 50));
    await drag.up();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      harness.folderRepository.removeNoteCalls,
      containsAll(['note-a', 'note-b']),
    );
  });

  testWidgets('shows hover affordance while dragging over All Notes', (
    tester,
  ) async {
    final harness = _AllNotesHarness();
    addTearDown(harness.dispose);
    final note = _buildLocalNote('note-hover');

    await harness.pump(
      tester,
      Column(
        children: [
          const FolderFilterChips(showCreateOption: false),
          Draggable<LocalNote>(
            data: note,
            feedback: const Material(child: Text('dragging')),
            child: const Text('drag me'),
          ),
        ],
      ),
    );

    final scope = tester.element(find.byType(FolderFilterChips));
    final label = AppLocalizations.of(scope).notesListTitle;

    final drag = await tester.startGesture(
      tester.getCenter(find.text('drag me')),
    );
    await drag.moveTo(tester.getCenter(find.text(label)));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);

    await drag.up();
    await tester.pump(const Duration(milliseconds: 200));
  });
}
