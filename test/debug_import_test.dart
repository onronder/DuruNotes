import 'dart:io';

import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart'
    show AppLogger, NoOpLogger;
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show analyticsProvider, loggerProvider;
import 'package:duru_notes/domain/entities/folder.dart' as folder_domain;
import 'package:duru_notes/domain/entities/note.dart' as note_domain;
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/unified_import_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

class _RecordingAnalyticsService extends AnalyticsService {
  final List<Map<String, dynamic>> events = [];

  @override
  void event(String name, {Map<String, dynamic>? properties}) {
    events.add({'name': name, 'properties': properties});
  }
}

class _TestRef implements Ref<Object?> {
  _TestRef(this._logger, this._analytics);

  final AppLogger _logger;
  final AnalyticsService _analytics;

  @override
  ProviderContainer get container =>
      throw UnsupportedError('container not available in tests');

  @override
  T refresh<T>(Refreshable<T> provider) =>
      throw UnsupportedError('refresh not supported');

  @override
  void invalidate(ProviderOrFamily provider) =>
      throw UnsupportedError('invalidate not supported');

  @override
  void notifyListeners() =>
      throw UnsupportedError('notifyListeners not supported');

  @override
  void listenSelf(
    void Function(Object? previous, Object? next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) => throw UnsupportedError('listenSelf not supported');

  @override
  void invalidateSelf() =>
      throw UnsupportedError('invalidateSelf not supported');

  @override
  void onAddListener(void Function() cb) =>
      throw UnsupportedError('onAddListener not supported');

  @override
  void onRemoveListener(void Function() cb) =>
      throw UnsupportedError('onRemoveListener not supported');

  @override
  void onResume(void Function() cb) =>
      throw UnsupportedError('onResume not supported');

  @override
  void onCancel(void Function() cb) =>
      throw UnsupportedError('onCancel not supported');

  @override
  void onDispose(void Function() cb) =>
      throw UnsupportedError('onDispose not supported');

  @override
  T read<T>(ProviderListenable<T> provider) {
    if (identical(provider, loggerProvider)) {
      return _logger as T;
    }
    if (identical(provider, analyticsProvider)) {
      return _analytics as T;
    }
    throw UnsupportedError('No override for $provider');
  }

  @override
  bool exists(ProviderBase<Object?> provider) =>
      throw UnsupportedError('exists not supported');

  @override
  T watch<T>(ProviderListenable<T> provider) =>
      throw UnsupportedError('watch not supported');

  @override
  KeepAliveLink keepAlive() =>
      throw UnsupportedError('keepAlive not supported');

  @override
  ProviderSubscription<T> listen<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
    bool fireImmediately = false,
  }) => throw UnsupportedError('listen not supported');
}

class _FakeNotesRepository implements INotesRepository {
  final List<note_domain.Note> createdNotes = [];

  @override
  Future<note_domain.Note?> createOrUpdate({
    required String title,
    required String body,
    String? id,
    String? folderId,
    List<String> tags = const [],
    List<Map<String, String?>> links = const [],
    Map<String, dynamic>? attachmentMeta,
    Map<String, dynamic>? metadataJson,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    final timestamp = DateTime.now();
    final note = note_domain.Note(
      id: id ?? 'note-${createdNotes.length + 1}',
      title: title,
      body: body,
      createdAt: createdAt ?? timestamp,
      updatedAt: updatedAt ?? timestamp,
      deleted: false,
      isPinned: isPinned ?? false,
      noteType: NoteKind.note,
      folderId: folderId,
      version: 1,
      userId: 'user-test',
      attachmentMeta: attachmentMeta?.toString(),
      metadata: metadataJson?.toString(),
      encryptedMetadata: null,
      tags: tags,
      links: const [],
    );
    createdNotes.add(note);
    return note;
  }

  @override
  Future<List<note_domain.Note>> localNotes() async =>
      List<note_domain.Note>.unmodifiable(createdNotes);

  // Remaining methods throw since they aren't used in tests.
  @override
  Future<note_domain.Note?> getNoteById(String id) =>
      throw UnsupportedError('getNoteById not supported');
  @override
  Future<void> updateLocalNote(
    String id, {
    String? title,
    String? body,
    bool? deleted,
    String? folderId,
    bool updateFolder = false,
    Map<String, dynamic>? attachmentMeta,
    Map<String, dynamic>? metadata,
    List<Map<String, String?>>? links,
    bool? isPinned,
    DateTime? updatedAt,
  }) => throw UnsupportedError('updateLocalNote not supported');
  @override
  Future<void> deleteNote(String id) =>
      throw UnsupportedError('deleteNote not supported');
  @override
  Future<List<note_domain.Note>> localNotesForSync() =>
      throw UnsupportedError('localNotesForSync not supported');
  @override
  Future<List<note_domain.Note>> getRecentlyViewedNotes({int limit = 5}) =>
      throw UnsupportedError('getRecentlyViewedNotes not supported');
  @override
  Future<List<note_domain.Note>> listAfter(
    DateTime? cursor, {
    int limit = 20,
  }) => throw UnsupportedError('listAfter not supported');
  @override
  Future<void> toggleNotePin(String noteId) =>
      throw UnsupportedError('toggleNotePin not supported');
  @override
  Future<void> setNotePin(String noteId, bool isPinned) =>
      throw UnsupportedError('setNotePin not supported');
  @override
  Future<List<note_domain.Note>> getPinnedNotes() =>
      throw UnsupportedError('getPinnedNotes not supported');
  @override
  Stream<List<note_domain.Note>> watchNotes({
    String? folderId,
    List<String>? anyTags,
    List<String>? noneTags,
    bool pinnedFirst = true,
  }) => throw UnsupportedError('watchNotes not supported');
  @override
  Future<List<note_domain.Note>> list({int? limit}) =>
      throw UnsupportedError('list not supported');
  @override
  Future<int> getNotesCountInFolder(String folderId) =>
      throw UnsupportedError('getNotesCountInFolder not supported');
  @override
  Future<List<String>> getNoteIdsInFolder(String folderId) =>
      throw UnsupportedError('getNoteIdsInFolder not supported');
  @override
  Future<void> sync() => throw UnsupportedError('sync not supported');
  @override
  Future<void> pushAllPending() =>
      throw UnsupportedError('pushAllPending not supported');
  @override
  Future<void> pullSince(DateTime? since) =>
      throw UnsupportedError('pullSince not supported');
  @override
  Future<DateTime?> getLastSyncTime() =>
      throw UnsupportedError('getLastSyncTime not supported');
}

class _FakeFolderRepository implements IFolderRepository {
  final List<folder_domain.Folder> folders = [];

  @override
  Future<List<folder_domain.Folder>> listFolders() async =>
      List<folder_domain.Folder>.unmodifiable(folders);

  // Methods below throw since tests don't exercise folder creation.
  @override
  Future<folder_domain.Folder?> getFolder(String id) =>
      throw UnsupportedError('getFolder not supported');
  @override
  Future<List<folder_domain.Folder>> getRootFolders() =>
      throw UnsupportedError('getRootFolders not supported');
  @override
  Future<folder_domain.Folder> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) => throw UnsupportedError('createFolder not supported');
  @override
  Future<String> createOrUpdateFolder({
    required String name,
    String? id,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
  }) => throw UnsupportedError('createOrUpdateFolder not supported');
  @override
  Future<void> renameFolder(String folderId, String newName) =>
      throw UnsupportedError('renameFolder not supported');
  @override
  Future<void> moveFolder(String folderId, String? newParentId) =>
      throw UnsupportedError('moveFolder not supported');
  @override
  Future<void> deleteFolder(String folderId) =>
      throw UnsupportedError('deleteFolder not supported');
  @override
  Future<List<note_domain.Note>> getNotesInFolder(String folderId) =>
      throw UnsupportedError('getNotesInFolder not supported');
  @override
  Future<List<note_domain.Note>> getUnfiledNotes() =>
      throw UnsupportedError('getUnfiledNotes not supported');
  @override
  Future<void> addNoteToFolder(String noteId, String folderId) =>
      throw UnsupportedError('addNoteToFolder not supported');
  @override
  Future<void> moveNoteToFolder(String noteId, String? folderId) =>
      throw UnsupportedError('moveNoteToFolder not supported');
  @override
  Future<void> removeNoteFromFolder(String noteId) =>
      throw UnsupportedError('removeNoteFromFolder not supported');
  @override
  Future<Map<String, int>> getFolderNoteCounts() =>
      throw UnsupportedError('getFolderNoteCounts not supported');
  @override
  Future<folder_domain.Folder?> getFolderForNote(String noteId) =>
      throw UnsupportedError('getFolderForNote not supported');
  @override
  Future<List<folder_domain.Folder>> getChildFolders(String parentId) =>
      throw UnsupportedError('getChildFolders not supported');
  @override
  Future<List<folder_domain.Folder>> getChildFoldersRecursive(
    String parentId,
  ) => throw UnsupportedError('getChildFoldersRecursive not supported');
  @override
  Future<folder_domain.Folder?> findFolderByName(String name) =>
      throw UnsupportedError('findFolderByName not supported');
  @override
  Future<int> getFolderDepth(String folderId) =>
      throw UnsupportedError('getFolderDepth not supported');
  @override
  Future<List<String>> getNoteIdsInFolder(String folderId) =>
      throw UnsupportedError('getNoteIdsInFolder not supported');
  @override
  Future<int> getNotesCountInFolder(String folderId) =>
      throw UnsupportedError('getNotesCountInFolder not supported');
  @override
  Future<void> ensureFolderIntegrity() =>
      throw UnsupportedError('ensureFolderIntegrity not supported');
  @override
  Future<Map<String, dynamic>> performFolderHealthCheck() =>
      throw UnsupportedError('performFolderHealthCheck not supported');
  @override
  Future<void> validateAndRepairFolderStructure() =>
      throw UnsupportedError('validateAndRepairFolderStructure not supported');
  @override
  Future<void> cleanupOrphanedRelationships() =>
      throw UnsupportedError('cleanupOrphanedRelationships not supported');
  @override
  Future<void> resolveFolderConflicts() =>
      throw UnsupportedError('resolveFolderConflicts not supported');
  @override
  String? getCurrentUserId() => 'user-test';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeNotesRepository notesRepository;
  late _FakeFolderRepository folderRepository;
  late _RecordingAnalyticsService analytics;
  late _TestRef testRef;
  late UnifiedImportService service;

  setUp(() {
    notesRepository = _FakeNotesRepository();
    folderRepository = _FakeFolderRepository();
    analytics = _RecordingAnalyticsService();
    testRef = _TestRef(const NoOpLogger(), analytics);

    service = UnifiedImportService(
      ref: testRef,
      notesRepository: notesRepository,
      folderRepository: folderRepository,
      migrationConfig: MigrationConfig.developmentConfig(),
    );
  });

  group('UnifiedImportService debug behaviors', () {
    test('returns error for unsupported file type', () async {
      final tempDir = Directory.systemTemp.createTempSync('debug_import');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final file = File(path.join(tempDir.path, 'unsupported.xyz'))
        ..writeAsStringSync('unsupported');

      final result = await service.importFromFile(file: file);

      expect(result.success, isFalse);
      expect(result.errors, isNotEmpty);
      expect(notesRepository.createdNotes, isEmpty);
    });

    test('imports simple markdown note', () async {
      final tempDir = Directory.systemTemp.createTempSync('debug_import_md');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final file = File(path.join(tempDir.path, 'note.md'))
        ..writeAsStringSync('# Title\nBody content');

      final result = await service.importFromFile(file: file);

      expect(result.success, isTrue);
      expect(result.importedNotes, 1);
      expect(notesRepository.createdNotes.length, 1);
      final created = notesRepository.createdNotes.single;
      expect(created.title, contains('Title'));
      expect(created.body, contains('Body content'));
      expect(
        analytics.events.any(
          (event) =>
              event['name'] == 'notes_imported' && event['properties'] != null,
        ),
        isTrue,
      );
    });
  });
}
