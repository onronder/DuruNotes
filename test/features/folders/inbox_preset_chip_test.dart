import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/features/folders/folder_filter_chips.dart';
import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/features/folders/providers/folders_integration_providers.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart';
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart'
    as folder_state;
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/services/providers/services_providers.dart';
import 'package:duru_notes/services/undo_redo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duru_notes/core/providers/auth_providers.dart'
    show userIdProvider;

class _FakeFolderRepository implements IFolderRepository {
  _FakeFolderRepository({
    required List<domain.Folder> folders,
    Map<String, int>? noteCounts,
  }) : _folders = List<domain.Folder>.from(folders),
       _noteCounts = Map<String, int>.from(noteCounts ?? const {});

  final List<domain.Folder> _folders;
  final Map<String, int> _noteCounts;
  String? lastRequestedFolderId;
  domain.Folder? lastReturnedFolder;

  @override
  Future<domain.Folder?> getFolder(String id) async {
    lastRequestedFolderId = id;
    try {
      final found = _folders.firstWhere((folder) => folder.id == id);
      lastReturnedFolder = found;
      return found;
    } catch (_) {
      lastReturnedFolder = null;
      return null;
    }
  }

  @override
  Future<List<domain.Folder>> listFolders() async {
    return List<domain.Folder>.unmodifiable(_folders);
  }

  @override
  Future<List<domain.Folder>> getRootFolders() async {
    return _folders.where((folder) => folder.parentId == null).toList();
  }

  @override
  Future<domain.Folder?> findFolderByName(String name) async {
    try {
      return _folders.firstWhere(
        (folder) => folder.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> getNotesCountInFolder(String folderId) async {
    return _noteCounts[folderId] ?? 0;
  }

  @override
  Future<Map<String, int>> getFolderNoteCounts() async {
    return Map<String, int>.from(_noteCounts);
  }

  // The remaining interface methods are not needed for these tests.
  @override
  Future<domain.Folder> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) => throw UnimplementedError();

  @override
  Future<String> createOrUpdateFolder({
    required String name,
    String? id,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
  }) => throw UnimplementedError();

  @override
  Future<void> renameFolder(String folderId, String newName) =>
      throw UnimplementedError();

  @override
  Future<void> moveFolder(String folderId, String? newParentId) =>
      throw UnimplementedError();

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

class _TestNotesCoreRepository extends Fake implements NotesCoreRepository {
  _TestNotesCoreRepository(this._noteCounts);

  final Map<String, int> _noteCounts;

  @override
  Future<int> getNotesCountInFolder(String folderId) async {
    return _noteCounts[folderId] ?? 0;
  }
}

class _InboxChipTestHarness {
  _InboxChipTestHarness({
    required List<domain.Folder> folders,
    Map<String, int>? noteCounts,
    int unfiledCount = 0,
  }) : _noteCounts = Map<String, int>.from(noteCounts ?? const {}),
       _unfiledCount = unfiledCount {
    folderRepository = _FakeFolderRepository(
      folders: folders,
      noteCounts: noteCounts,
    );
    notesRepository = _TestNotesCoreRepository(_noteCounts);
    trackingNotifier = _TrackingCurrentFolderNotifier();

    container = ProviderContainer(
      overrides: [
        folderCoreRepositoryProvider.overrideWithValue(folderRepository),
        folderRepositoryProvider.overrideWithValue(folderRepository),
        notesCoreRepositoryProvider.overrideWithValue(notesRepository),
        folder_state.currentFolderProvider.overrideWith(
          (ref) => trackingNotifier,
        ),
        userIdProvider.overrideWithValue('inbox-test-user'),
        undoRedoServiceProvider.overrideWith((ref) => _StubUndoRedoService()),
        rootFoldersProvider.overrideWith(
          (ref) async => const <domain.Folder>[],
        ),
        unfiledNotesCountProvider.overrideWith((ref) async => _unfiledCount),
      ],
    );
  }

  final Map<String, int> _noteCounts;
  late final _FakeFolderRepository folderRepository;
  late final _TestNotesCoreRepository notesRepository;
  late final _TrackingCurrentFolderNotifier trackingNotifier;
  final int _unfiledCount;
  late final ProviderContainer container;

  Widget buildWidget() {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: FolderFilterChips(
            showCreateOption: false,
            padding: EdgeInsets.all(8),
          ),
        ),
      ),
    );
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(buildWidget());
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> dispose() async {
    container.dispose();
  }
}

class _TrackingCurrentFolderNotifier extends CurrentFolderNotifier {
  domain.Folder? lastSetFolder;

  @override
  void setCurrentFolder(domain.Folder? folder) {
    lastSetFolder = folder;
    super.setCurrentFolder(folder);
  }
}

domain.Folder _buildFolder({required String id, required String name}) {
  final now = DateTime.utc(2025, 1, 1);
  return domain.Folder(
    id: id,
    name: name,
    parentId: null,
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
    userId: 'test-user',
    color: null,
    icon: null,
    description: null,
  );
}

class _NoopRepository {
  Future<void> moveNoteToFolder(String noteId, String? folderId) async {}
  Future<void> moveFolder(String folderId, String? parentId) async {}
}

class _StubUndoRedoService extends UndoRedoService {
  _StubUndoRedoService()
    : super(
        repository: _NoopRepository(),
        userId: 'inbox-test-user',
        maxStackSize: 1,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(const {});

  testWidgets('Inbox chip stays hidden when incoming mail folder is missing', (
    tester,
  ) async {
    final harness = _InboxChipTestHarness(folders: const []);
    addTearDown(harness.dispose);

    await harness.pump(tester);

    expect(find.text('Inbox'), findsNothing);
  });

  testWidgets('Inbox chip hidden when inbox empty and filter inactive', (
    tester,
  ) async {
    final incomingFolder = _buildFolder(id: 'incoming', name: 'Incoming Mail');
    final harness = _InboxChipTestHarness(
      folders: [incomingFolder],
      noteCounts: const {'incoming': 0},
    );
    addTearDown(harness.dispose);

    await harness.pump(tester);

    expect(find.text('Inbox'), findsNothing);
  });

  testWidgets('Inbox chip shows count when inbox has notes', (tester) async {
    final incomingFolder = _buildFolder(id: 'incoming', name: 'Incoming Mail');
    final harness = _InboxChipTestHarness(
      folders: [incomingFolder],
      noteCounts: const {'incoming': 3},
    );
    addTearDown(harness.dispose);

    await harness.pump(tester);

    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('Inbox chip toggles filter on tap', (tester) async {
    final incomingFolder = _buildFolder(id: 'incoming', name: 'Incoming Mail');
    final harness = _InboxChipTestHarness(
      folders: [incomingFolder],
      noteCounts: const {'incoming': 2},
    );
    addTearDown(harness.dispose);

    expectLater(
      harness.folderRepository.getFolder(incomingFolder.id),
      completion(isNotNull),
    );

    await harness.pump(tester);

    expect(find.text('Inbox'), findsOneWidget);
    final inboxFinder = find.text('Inbox');

    await tester.tap(inboxFinder);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(milliseconds: 200));

    expect(harness.container.read(isInboxFilterActiveProvider), isTrue);
    expect(harness.folderRepository.lastRequestedFolderId, incomingFolder.id);
    expect(
      harness.folderRepository.lastReturnedFolder,
      isNotNull,
      reason: 'Expected getFolder to return the incoming folder',
    );
    expect(
      harness.trackingNotifier.lastSetFolder?.id,
      incomingFolder.id,
      reason: 'Notifier should receive the target folder id',
    );
    final currentAfterTap = harness.container.read(
      folder_state.currentFolderProvider,
    );
    expect(
      currentAfterTap,
      isNotNull,
      reason: 'Inbox filter should set current folder when toggled on',
    );
    expect(currentAfterTap!.id, incomingFolder.id);

    await tester.tap(inboxFinder);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(milliseconds: 200));

    expect(harness.container.read(isInboxFilterActiveProvider), isFalse);
    expect(harness.container.read(folder_state.currentFolderProvider), isNull);
  });

  testWidgets('Inbox chip remains visible when active with zero items', (
    tester,
  ) async {
    final incomingFolder = _buildFolder(id: 'incoming', name: 'Incoming Mail');
    final harness = _InboxChipTestHarness(
      folders: [incomingFolder],
      noteCounts: const {'incoming': 0},
    );
    addTearDown(harness.dispose);

    harness.container.read(isInboxFilterActiveProvider.notifier).state = true;
    harness.container
        .read(folder_state.currentFolderProvider.notifier)
        .setCurrentFolder(incomingFolder);

    await harness.pump(tester);

    expect(find.text('Inbox'), findsOneWidget);
    expect(harness.container.read(isInboxFilterActiveProvider), isTrue);
    expect(
      harness.container.read(folder_state.currentFolderProvider)?.id,
      incomingFolder.id,
    );
  });
}
