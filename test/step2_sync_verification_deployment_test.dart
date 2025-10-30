import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/sync/sync_integrity_validator.dart'
    show ValidationIssueType;
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/core/providers/database_providers.dart'
    show appDbProvider;
import 'package:duru_notes/features/notes/providers/notes_repository_providers.dart'
    show supabaseNoteApiProvider;
import 'package:duru_notes/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/providers/sync_verification_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase/supabase.dart';

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

class _FakeSupabaseNoteApi extends SupabaseNoteApi {
  _FakeSupabaseNoteApi(
    this._noteIds,
    this._folderIds,
    this._notes, {
    Set<String>? taskIds,
    List<Map<String, dynamic>>? tasks,
    Set<String>? attachmentIds,
    List<Map<String, dynamic>>? attachments,
  }) : _taskIds = taskIds ?? const {},
       _tasks = tasks ?? const [],
       _attachmentIds = attachmentIds ?? const {},
       _attachments = attachments ?? const [],
       super(SupabaseClient('https://stub.supabase.co', 'stub-key'));

  final Set<String> _noteIds;
  final Set<String> _folderIds;
  final List<Map<String, dynamic>> _notes;
  final Set<String> _taskIds;
  final List<Map<String, dynamic>> _tasks;
  final Set<String> _attachmentIds;
  final List<Map<String, dynamic>> _attachments;

  @override
  Future<Set<String>> fetchAllActiveIds() async => _noteIds;

  @override
  Future<Set<String>> fetchAllActiveFolderIds() async => _folderIds;

  @override
  Future<List<Map<String, dynamic>>> fetchEncryptedNotes({
    DateTime? since,
  }) async => _notes;

  @override
  Future<Set<String>> fetchAllActiveTaskIds() async => _taskIds;

  @override
  Future<List<Map<String, dynamic>>> fetchNoteTasks({DateTime? since}) async =>
      _tasks;

  @override
  Future<Set<String>> fetchAllActiveAttachmentIds() async => _attachmentIds;

  @override
  Future<List<Map<String, dynamic>>> fetchAttachments({
    DateTime? since,
  }) async => _attachments;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 2 Sync Verification Deployment', () {
    late AppDb db;

    setUp(() async {
      db = AppDb.forTesting(NativeDatabase.memory());
      await _seedLocalData(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('sync integrity validator provider enforces authenticated guard', () {
      final container = ProviderContainer(
        overrides: [
          appDbProvider.overrideWithValue(db),
          loggerProvider.overrideWithValue(const _NoOpLogger()),
          supabaseNoteApiProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(syncIntegrityValidatorProvider),
        throwsStateError,
      );
    });

    test(
      'sync integrity validator succeeds with consistent remote dataset',
      () async {
        final remoteNote = {
          'id': 'note-alpha',
          'title_encrypted': 'enc::Launch Checklist',
          'encrypted_metadata': null,
        };
        final remoteTask = {
          'id': 'task-alpha',
          'note_id': 'note-alpha',
          'deleted': false,
        };
        final remoteAttachment = {
          'id': 'attachment-alpha',
          'user_id': 'user-123',
          'note_id': 'note-alpha',
          'file_name': 'checklist.pdf',
          'size': 2048,
          'deleted': false,
        };

        final fakeApi = _FakeSupabaseNoteApi(
          {'note-alpha'},
          {'folder-mercury'},
          [remoteNote],
          taskIds: {'task-alpha'},
          tasks: [remoteTask],
          attachmentIds: {'attachment-alpha'},
          attachments: [remoteAttachment],
        );

        final container = ProviderContainer(
          overrides: [
            appDbProvider.overrideWithValue(db),
            loggerProvider.overrideWithValue(const _NoOpLogger()),
            supabaseNoteApiProvider.overrideWithValue(fakeApi),
          ],
        );
        addTearDown(container.dispose);

        final validator = container.read(syncIntegrityValidatorProvider);
        final result = await validator.validateSyncIntegrity();

        expect(
          result.isValid,
          isTrue,
          reason: [
            'Expected sync integrity validation to succeed, but encountered issues:',
            ...result.issues.map((issue) => '- ${issue.description}'),
          ].join('\n'),
        );
        expect(result.issues, isEmpty);
      },
    );

    test('sync integrity validator detects remote task drift', () async {
      final remoteNote = {
        'id': 'note-alpha',
        'title_encrypted': 'enc::Launch Checklist',
        'encrypted_metadata': null,
      };

      final fakeApi = _FakeSupabaseNoteApi(
        {'note-alpha'},
        {'folder-mercury'},
        [remoteNote],
        taskIds: const {}, // Missing local task
      );

      final container = ProviderContainer(
        overrides: [
          appDbProvider.overrideWithValue(db),
          loggerProvider.overrideWithValue(const _NoOpLogger()),
          supabaseNoteApiProvider.overrideWithValue(fakeApi),
        ],
      );
      addTearDown(container.dispose);

      final validator = container.read(syncIntegrityValidatorProvider);
      final result = await validator.validateSyncIntegrity();

      expect(result.isValid, isFalse);
      expect(
        result.issues.any(
          (issue) =>
              issue.type == ValidationIssueType.missingRemote &&
              issue.affectedTable == 'note_tasks',
        ),
        isTrue,
      );
    });

    test('sync integrity validator detects attachment drift', () async {
      final remoteNote = {
        'id': 'note-alpha',
        'title_encrypted': 'enc::Launch Checklist',
        'encrypted_metadata': null,
      };

      final fakeApi = _FakeSupabaseNoteApi(
        {'note-alpha'},
        {'folder-mercury'},
        [remoteNote],
        taskIds: {'task-alpha'},
        tasks: const [
          {'id': 'task-alpha', 'note_id': 'note-alpha', 'deleted': false},
        ],
        attachmentIds: const {}, // Missing local attachment
        attachments: const [],
      );

      final container = ProviderContainer(
        overrides: [
          appDbProvider.overrideWithValue(db),
          loggerProvider.overrideWithValue(const _NoOpLogger()),
          supabaseNoteApiProvider.overrideWithValue(fakeApi),
        ],
      );
      addTearDown(container.dispose);

      final validator = container.read(syncIntegrityValidatorProvider);
      final result = await validator.validateSyncIntegrity();

      expect(result.isValid, isFalse);
      expect(
        result.issues.any(
          (issue) =>
              issue.type == ValidationIssueType.missingRemote &&
              issue.affectedTable == 'attachments',
        ),
        isTrue,
      );
    });

    test('sync integrity validator detects folder count drift', () async {
      final remoteNote = {
        'id': 'note-alpha',
        'title_encrypted': 'enc::Launch Checklist',
        'encrypted_metadata': null,
      };

      final fakeApi = _FakeSupabaseNoteApi(
        {'note-alpha'},
        const {}, // Remote missing folder
        [remoteNote],
        taskIds: {'task-alpha'},
        tasks: const [
          {'id': 'task-alpha', 'note_id': 'note-alpha', 'deleted': false},
        ],
        attachmentIds: {'attachment-alpha'},
        attachments: const [
          {
            'id': 'attachment-alpha',
            'user_id': 'user-123',
            'note_id': 'note-alpha',
            'file_name': 'checklist.pdf',
            'size': 2048,
            'deleted': false,
          },
        ],
      );

      final container = ProviderContainer(
        overrides: [
          appDbProvider.overrideWithValue(db),
          loggerProvider.overrideWithValue(const _NoOpLogger()),
          supabaseNoteApiProvider.overrideWithValue(fakeApi),
        ],
      );
      addTearDown(container.dispose);

      final validator = container.read(syncIntegrityValidatorProvider);
      final result = await validator.validateSyncIntegrity();

      expect(result.isValid, isFalse);
      expect(
        result.issues.any(
          (issue) =>
              issue.type == ValidationIssueType.countMismatch &&
              issue.affectedTable == 'folders',
        ),
        isTrue,
      );
    });
  });
}

Future<void> _seedLocalData(AppDb db) async {
  final now = DateTime.utc(2025, 10, 26);

  await db
      .into(db.localFolders)
      .insert(
        LocalFoldersCompanion.insert(
          id: 'folder-mercury',
          userId: 'user-123',
          name: 'Project Mercury',
          path: '/Project Mercury',
          sortOrder: const Value(0),
          createdAt: now,
          updatedAt: now,
          deleted: const Value(false),
        ),
      );

  await db
      .into(db.localNotes)
      .insert(
        LocalNotesCompanion.insert(
          id: 'note-alpha',
          userId: const Value('user-123'),
          titleEncrypted: const Value('enc::Launch Checklist'),
          bodyEncrypted: const Value('enc::Checklist Body'),
          createdAt: now,
          updatedAt: now,
          deleted: const Value(false),
          noteType: Value(NoteKind.note),
          isPinned: const Value(false),
          version: const Value(1),
          encryptionVersion: const Value(1),
        ),
      );

  await db
      .into(db.noteTasks)
      .insert(
        NoteTasksCompanion.insert(
          id: 'task-alpha',
          noteId: 'note-alpha',
          userId: 'user-123',
          contentEncrypted: 'enc::Review engines',
          contentHash: 'hash::task-alpha',
          position: const Value(0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  await db
      .into(db.attachments)
      .insert(
        AttachmentsCompanion.insert(
          id: 'attachment-alpha',
          userId: 'user-123',
          noteId: 'note-alpha',
          filename: 'checklist.pdf',
          mimeType: 'application/pdf',
          size: 2048,
          createdAt: now,
        ),
      );
}
