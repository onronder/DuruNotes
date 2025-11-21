import 'dart:typed_data';

import 'package:duru_notes/core/monitoring/app_logger.dart' as app_logger;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/models/note_block.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/attachment_service.dart';
import 'package:duru_notes/services/share_extension_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareExtensionService', () {
    late _FakeNotesRepository notesRepository;
    late _FakeAttachmentService attachmentService;
    late AnalyticsService analytics;
    late ShareExtensionService service;

    setUp(() {
      app_logger.LoggerFactory.initialize();
      notesRepository = _FakeNotesRepository();
      attachmentService = _FakeAttachmentService();
      analytics = AnalyticsService();
      service = ShareExtensionService(
        notesRepository: notesRepository,
        attachmentService: attachmentService,
        logger: app_logger.LoggerFactory.instance,
        analytics: analytics,
      );
    });

    test('persists shared text items with metadata and tags', () async {
      final items = [
        {
          'type': 'text',
          'title': 'Shared Text',
          'content': 'Hello from #ShareExtension!',
          'timestamp': DateTime(2025, 1, 1).toIso8601String(),
        },
      ];

      await service.processSharedItemsForTesting(items);

      expect(notesRepository.saved.length, 1);
      final saved = notesRepository.saved.first;
      expect(saved.title, 'Shared Text');
      expect(saved.body, contains('#ShareExtension'));
      expect(saved.tags, contains('shareextension'));
      expect(saved.metadata['source'], 'share_extension');
      expect(saved.metadata['share_type'], 'text');
    });

    test('persists shared url items with link payload', () async {
      final items = [
        {
          'type': 'url',
          'title': 'Example',
          'url': 'https://example.com',
          'content': 'context body',
          'timestamp': DateTime(2025, 1, 1).toIso8601String(),
        },
      ];

      await service.processSharedItemsForTesting(items);

      expect(notesRepository.saved.length, 1);
      final saved = notesRepository.saved.first;
      expect(saved.title, 'Example');
      expect(saved.body, contains('https://example.com'));
      expect(saved.metadata['share_type'], 'url');
    });
  });
}

class _CapturedNote {
  _CapturedNote({
    required this.title,
    required this.body,
    required this.tags,
    required this.metadata,
  });

  final String title;
  final String body;
  final List<String> tags;
  final Map<String, dynamic> metadata;
}

class _FakeNotesRepository implements INotesRepository {
  final List<_CapturedNote> saved = [];
  int _counter = 0;

  @override
  Future<domain.Note?> createOrUpdate({
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
    saved.add(
      _CapturedNote(
        title: title,
        body: body,
        tags: tags,
        metadata: metadataJson ?? const {},
      ),
    );
    final noteId = (id ?? 'note-${++_counter}');
    return domain.Note(
      id: noteId,
      title: title,
      body: body,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      deleted: false,
      isPinned: false,
      noteType: NoteKind.note,
      version: 1,
      userId: 'test-user',
      tags: tags,
      links: const [],
    );
  }

  // Remaining interface methods throw to catch unexpected usage in tests.
  @override
  Future<void> deleteNote(String id) => throw UnimplementedError();

  @override
  Future<domain.Note?> getNoteById(String id) => throw UnimplementedError();

  @override
  Future<List<domain.Note>> getDeletedNotes() => throw UnimplementedError();

  @override
  Future<List<String>> getNoteIdsInFolder(String folderId) =>
      throw UnimplementedError();

  @override
  Future<int> getNotesCountInFolder(String folderId) =>
      throw UnimplementedError();

  @override
  Future<List<domain.Note>> getPinnedNotes() => throw UnimplementedError();

  @override
  Future<List<domain.Note>> list({int? limit}) => throw UnimplementedError();

  @override
  Future<List<domain.Note>> listAfter(DateTime? cursor, {int limit = 20}) =>
      throw UnimplementedError();

  @override
  Future<List<domain.Note>> localNotes() => throw UnimplementedError();

  @override
  Future<List<domain.Note>> localNotesForSync() => throw UnimplementedError();

  @override
  Future<List<domain.Note>> getRecentlyViewedNotes({int limit = 5}) =>
      throw UnimplementedError();

  @override
  Future<void> permanentlyDeleteNote(String id) => throw UnimplementedError();

  @override
  Future<void> pullSince(DateTime? since) => throw UnimplementedError();

  @override
  Future<void> pushAllPending() => throw UnimplementedError();

  @override
  Future<void> restoreNote(String id) => throw UnimplementedError();

  @override
  Future<void> setNotePin(String noteId, bool isPinned) =>
      throw UnimplementedError();

  @override
  Future<void> sync() => throw UnimplementedError();

  @override
  Future<void> toggleNotePin(String noteId) => throw UnimplementedError();

  @override
  Future<domain.Note?> updateLocalNote(
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
  }) => throw UnimplementedError();

  @override
  Future<DateTime?> getLastSyncTime() => throw UnimplementedError();

  @override
  Stream<List<domain.Note>> watchNotes({
    String? folderId,
    List<String>? anyTags,
    List<String>? noneTags,
    bool pinnedFirst = true,
  }) => throw UnimplementedError();

  @override
  Future<int> anonymizeAllNotesForUser(String userId) async => 0;
}

class _FakeAttachmentService implements AttachmentUploader {
  @override
  Future<AttachmentBlockData?> uploadFromBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    return null;
  }
}
