import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/services/note_link_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NoteLinkParser parser;
  late InMemoryNotesRepository notesRepository;

  setUp(() {
    const userId = 'user-123';
    notesRepository = InMemoryNotesRepository(
      userId: userId,
      notes: [
        Note(
          id: '11111111-1111-1111-1111-111111111111',
          title: 'Launch Checklist',
          body: 'Ensure thrusters are calibrated.',
          createdAt: DateTime.utc(2025, 10, 19),
          updatedAt: DateTime.utc(2025, 10, 20),
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: userId,
          tags: const ['checklist'],
        ),
        Note(
          id: '22222222-2222-2222-2222-222222222222',
          title: 'Mission Briefing',
          body: 'Details about Project Mercury.',
          createdAt: DateTime.utc(2025, 10, 20),
          updatedAt: DateTime.utc(2025, 10, 21),
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: userId,
          tags: const ['briefing'],
        ),
        Note(
          id: '33333333-3333-3333-3333-333333333333',
          title: 'Other User Note',
          body: 'Should never be visible to current user.',
          createdAt: DateTime.utc(2025, 10, 21),
          updatedAt: DateTime.utc(2025, 10, 22),
          deleted: false,
          isPinned: false,
          noteType: NoteKind.note,
          version: 1,
          userId: 'user-456',
        ),
      ],
    );

    parser = NoteLinkParser(logger: const _NoOpLogger());
  });

  test(
    'extractLinks returns only links belonging to current user notes',
    () async {
      const content = '''
Today we reviewed @[Launch Checklist] prior to ignition.
Engineers updated [[Mission Briefing]] with the new timeline.
See @33333333-3333-3333-3333-333333333333 for cross-team reference.
''';

      final links = await parser.extractLinks(content, notesRepository);

      expect(links, hasLength(3));

      final wikiLink = links.firstWhere((l) => l['type'] == 'wiki_link');
      expect(wikiLink['id'], '22222222-2222-2222-2222-222222222222');

      final atMention = links.firstWhere((l) => l['type'] == 'at_mention');
      expect(atMention['id'], '11111111-1111-1111-1111-111111111111');

      final atId = links.firstWhere((l) => l['type'] == 'at_id');
      // Note belongs to a different user, so title should fall back to "Unknown Note"
      expect(atId['title'], 'Unknown Note');
      expect(atId['id'], '33333333-3333-3333-3333-333333333333');
    },
  );

  test(
    'searchNotesByTitle prioritizes prefix matches before fuzzy matches',
    () async {
      final matches = await parser.searchNotesByTitle(
        'mission',
        notesRepository,
        limit: 5,
      );

      expect(matches, hasLength(1));
      expect(matches.first.id, '22222222-2222-2222-2222-222222222222');

      final fallbackMatches = await parser.searchNotesByTitle(
        'check',
        notesRepository,
      );
      expect(
        fallbackMatches.map((note) => note.id),
        contains('11111111-1111-1111-1111-111111111111'),
      );
    },
  );
}

class InMemoryNotesRepository implements INotesRepository {
  InMemoryNotesRepository({required this.userId, required List<Note> notes})
    : _notes = List.unmodifiable(notes);

  final String userId;
  final List<Note> _notes;

  List<Note> get _userNotes =>
      _notes.where((note) => note.userId == userId && !note.deleted).toList();

  @override
  Future<Note?> getNoteById(String id) async {
    try {
      return _userNotes.firstWhere((note) => note.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<List<Note>> localNotes() async => _userNotes;

  // Unused members throw to surface accidental usage in tests.
  @override
  Future<Note?> createOrUpdate({
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
  }) => throw UnimplementedError();

  @override
  Future<void> deleteNote(String id) => throw UnimplementedError();

  @override
  Future<DateTime?> getLastSyncTime() => throw UnimplementedError();

  @override
  Future<List<Note>> getPinnedNotes() => throw UnimplementedError();

  @override
  Future<List<String>> getNoteIdsInFolder(String folderId) =>
      throw UnimplementedError();

  @override
  Future<int> getNotesCountInFolder(String folderId) =>
      throw UnimplementedError();

  @override
  Future<List<Note>> getRecentlyViewedNotes({int limit = 5}) =>
      throw UnimplementedError();

  @override
  Future<List<Note>> list({int? limit}) => throw UnimplementedError();

  @override
  Future<List<Note>> listAfter(DateTime? cursor, {int limit = 20}) =>
      throw UnimplementedError();

  @override
  Future<List<Note>> localNotesForSync() => throw UnimplementedError();

  @override
  Future<void> pullSince(DateTime? since) => throw UnimplementedError();

  @override
  Future<void> pushAllPending() => throw UnimplementedError();

  @override
  Future<void> setNotePin(String noteId, bool isPinned) =>
      throw UnimplementedError();

  @override
  Future<void> sync() => throw UnimplementedError();

  @override
  Future<void> toggleNotePin(String noteId) => throw UnimplementedError();

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
  }) => throw UnimplementedError();

  @override
  Stream<List<Note>> watchNotes({
    String? folderId,
    List<String>? anyTags,
    List<String>? noneTags,
    bool pinnedFirst = true,
  }) => const Stream.empty();
}

class _NoOpLogger implements AppLogger {
  const _NoOpLogger();

  @override
  void breadcrumb(String message, {Map<String, dynamic>? data}) {}

  @override
  void debug(String message, {Map<String, dynamic>? data}) {}

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {}

  @override
  Future<void> flush() async {}

  @override
  void info(String message, {Map<String, dynamic>? data}) {}

  @override
  void warn(String message, {Map<String, dynamic>? data}) {}

  @override
  void warning(String message, {Map<String, dynamic>? data}) {}
}
