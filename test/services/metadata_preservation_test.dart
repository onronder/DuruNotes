import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/data/local/app_db.dart' as db;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/infrastructure/repositories/task_core_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../security/authorization_service_test.mocks.dart';

Uint8List _encode(String value) =>
    Uint8List.fromList(utf8.encode('enc:$value'));

String _decode(Uint8List data) {
  final text = utf8.decode(data);
  return text.startsWith('enc:') ? text.substring(4) : text;
}

class _StubCryptoBox extends Mock implements CryptoBox {
  @override
  Future<Uint8List> encryptStringForNote({
    required String userId,
    required String noteId,
    required String text,
  }) async => _encode(text);

  @override
  Future<String> decryptStringForNote({
    required String userId,
    required String noteId,
    required Uint8List data,
  }) async => _decode(data);

  @override
  Future<Uint8List> encryptJsonForNote({
    required String userId,
    required String noteId,
    required Map<String, dynamic> json,
  }) async => _encode(jsonEncode(json));

  @override
  Future<Map<String, dynamic>> decryptJsonForNote({
    required String userId,
    required String noteId,
    required Uint8List data,
  }) async => jsonDecode(_decode(data)) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task metadata preservation', () {
    late db.AppDb database;
    late TaskCoreRepository repository;
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late MockUser mockUser;
    late _StubCryptoBox crypto;

    const noteId = 'note-123';
    const userId = 'user-123';

    domain.Task buildTask({
      required String id,
      required DateTime timestamp,
      List<String> tags = const [],
      Map<String, dynamic> metadata = const {},
      String title = 'Original Task',
      String? description = 'Preserve this description',
    }) {
      return domain.Task(
        id: id,
        noteId: noteId,
        title: title,
        description: description,
        status: domain.TaskStatus.pending,
        priority: domain.TaskPriority.high,
        dueDate: timestamp.add(const Duration(days: 2)),
        completedAt: null,
        createdAt: timestamp,
        updatedAt: timestamp,
        tags: tags,
        metadata: metadata,
      );
    }

    Future<void> seedNote() async {
      await database
          .into(database.localNotes)
          .insert(
            db.LocalNotesCompanion.insert(
              id: noteId,
              userId: const Value(userId),
              titleEncrypted: const Value('enc-title'),
              bodyEncrypted: const Value('enc-body'),
              encryptionVersion: const Value(1),
              deleted: const Value(false),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
    }

    setUp(() {
      database = db.AppDb.forTesting(NativeDatabase.memory());
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockUser = MockUser();
      crypto = _StubCryptoBox();

      when(mockSupabase.auth).thenReturn(mockAuth);
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.id).thenReturn(userId);

      repository = TaskCoreRepository(
        db: database,
        client: mockSupabase,
        crypto: crypto,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'updating task content retains labels and structured metadata',
      () async {
        await seedNote();
        final createdAt = DateTime.utc(2025, 1, 24);
        final task = buildTask(
          id: '',
          timestamp: createdAt,
          tags: const ['urgent', 'work'],
          metadata: const {
            'estimatedMinutes': 45,
            'actualMinutes': 15,
            'parentTaskId': 'parent-42',
          },
        );

        final created = await repository.createTask(task);
        final original = await repository.getTaskById(created.id);
        expect(original, isNotNull);
        expect(original!.tags, equals(['urgent', 'work']));
        expect(original.metadata['estimatedMinutes'], 45);
        expect(original.metadata['parentTaskId'], 'parent-42');

        final updated = original.copyWith(
          title: 'Updated Task Content',
          description: 'Preserve this description',
        );

        final result = await repository.updateTask(updated);

        expect(result.title, 'Updated Task Content');
        expect(result.description, 'Preserve this description');
        expect(
          result.tags,
          equals(['urgent', 'work']),
          reason: 'Labels must survive content edits',
        );
        expect(result.metadata['estimatedMinutes'], 45);
        expect(result.metadata['actualMinutes'], 15);
        expect(result.metadata['parentTaskId'], 'parent-42');
        expect(result.metadata['contentHash'], isNotEmpty);
        expect(
          DateTime.parse(
            result.metadata['updatedAt'] as String,
          ).isAfter(DateTime.parse(original.metadata['updatedAt'] as String)),
          isTrue,
          reason: 'Updated timestamp should advance after content change',
        );
      },
    );

    test('reminder metadata is preserved across updates', () async {
      await seedNote();
      final timestamp = DateTime.utc(2025, 2, 10);
      final created = await repository.createTask(
        buildTask(
          id: '',
          timestamp: timestamp,
          metadata: const {'estimatedMinutes': 30},
        ),
      );

      // Simulate reminder linkage performed by EnhancedTaskService
      await database.updateTask(
        created.id,
        userId,
        db.NoteTasksCompanion(
          reminderId: const Value('reminder-99'), // MIGRATION v41: UUID String
          updatedAt: Value(timestamp),
        ),
      );

      final withReminder = await repository.getTaskById(created.id);
      expect(withReminder?.metadata['reminderId'], 'reminder-99'); // MIGRATION v41: UUID String

      final updated = withReminder!.copyWith(
        title: 'Moved task to new section',
      );
      final result = await repository.updateTask(updated);

      expect(
        result.metadata['reminderId'],
        'reminder-99',
        reason: 'Reminder linkage must not be cleared by content updates',
      );
      expect(result.metadata['estimatedMinutes'], 30);
    });

    test('reordering task keeps position metadata intact', () async {
      await seedNote();
      final timestamp = DateTime.utc(2025, 3, 4, 12);

      final created = await repository.createTask(
        buildTask(
          id: '',
          timestamp: timestamp,
          metadata: const {'position': 2, 'estimatedMinutes': 20},
          title: 'Task before reorder',
        ),
      );

      // Simulate a reorder operation that adjusts position column directly
      await database.updateTask(
        created.id,
        userId,
        db.NoteTasksCompanion(
          position: const Value(4),
          updatedAt: Value(timestamp.add(const Duration(minutes: 1))),
        ),
      );

      final reordered = await repository.getTaskById(created.id);
      expect(reordered?.metadata['position'], 4);

      final updated = reordered!.copyWith(
        title: 'Reordered task still with metadata',
      );
      final result = await repository.updateTask(updated);

      expect(
        result.metadata['position'],
        4,
        reason: 'Position metadata should persist through updates',
      );
      expect(result.metadata['estimatedMinutes'], 20);
    });
  });
}
