import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/monitoring/task_sync_metrics.dart';
import 'package:duru_notes/core/utils/hash_utils.dart';
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

  group('stableTaskHash', () {
    test('normalizes content before hashing', () {
      const noteId = 'note-123';
      const original = '  Review   Launch Checklist  ';
      const variant = 'review launch    checklist';

      final hashA = stableTaskHash(noteId, original);
      final hashB = stableTaskHash(noteId, variant);

      expect(hashA, equals(hashB));
    });

    test('hash differs when content changes materially', () {
      const noteId = 'note-123';

      final hashA = stableTaskHash(noteId, 'Prepare beta launch');
      final hashB = stableTaskHash(noteId, 'Prepare GA launch');

      expect(hashA, isNot(equals(hashB)));
    });
  });

  group('TaskSyncMetrics duplicate tracking', () {
    late TaskSyncMetrics metrics;

    setUp(() {
      metrics = TaskSyncMetrics.instance;
      metrics.clearMetrics();
    });

    test('records duplicate detections per note', () {
      final syncId = metrics.startSync(
        noteId: 'note-1',
        syncType: 'markdown_sync',
        metadata: {'source': 'block_editor'},
      );

      metrics.recordDuplicate(
        noteId: 'note-1',
        taskId: 'task-A',
        duplicateId: 'task-A-dup',
        reason: 'matching content hash',
      );

      metrics.endSync(syncId: syncId, success: true, taskCount: 3);

      final health = metrics.getHealthMetrics();
      final noteMetrics = metrics.getNoteMetrics('note-1');

      expect(health['totalDuplicatesFound'], equals(1));
      expect(health['notesWithDuplicates'], equals(1));
      expect(noteMetrics['duplicatesFound'], equals(1));
      expect(noteMetrics['syncCount'], equals(1));
    });

    test('aggregates duplicates across multiple syncs', () async {
      final firstSync = metrics.startSync(
        noteId: 'note-42',
        syncType: 'markdown_sync',
        metadata: const {'run': 1},
      );
      metrics.recordDuplicate(
        noteId: 'note-42',
        taskId: 'task-1',
        duplicateId: 'task-1-copy',
      );
      metrics.endSync(syncId: firstSync, success: true, taskCount: 5);

      // Ensure distinct sync identifiers by waiting for the next millisecond
      await Future<void>.delayed(const Duration(milliseconds: 2));

      final secondSync = metrics.startSync(
        noteId: 'note-42',
        syncType: 'markdown_sync',
        metadata: const {'run': 2},
      );
      metrics.recordDuplicate(
        noteId: 'note-42',
        taskId: 'task-2',
        duplicateId: 'task-2-copy',
      );
      metrics.recordDuplicate(
        noteId: 'note-42',
        taskId: 'task-3',
        duplicateId: 'task-3-copy',
      );
      metrics.endSync(syncId: secondSync, success: true, taskCount: 6);

      final health = metrics.getHealthMetrics();
      final noteMetrics = metrics.getNoteMetrics('note-42');

      expect(health['totalDuplicatesFound'], equals(3));
      expect(health['notesWithDuplicates'], equals(1));
      expect(noteMetrics['duplicatesFound'], equals(3));
      expect(noteMetrics['syncCount'], equals(2));
      expect(noteMetrics['successCount'], equals(2));
    });
  });

  group('TaskCoreRepository duplicate prevention', () {
    late db.AppDb database;
    late TaskCoreRepository repository;
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late MockUser mockUser;
    late _StubCryptoBox crypto;

    const noteId = 'note-42';
    const userId = 'user-42';

    domain.Task buildTask(String title) {
      final now = DateTime.now();
      return domain.Task(
        id: '',
        noteId: noteId,
        title: title,
        description: null,
        status: domain.TaskStatus.pending,
        priority: domain.TaskPriority.medium,
        dueDate: null,
        completedAt: null,
        createdAt: now,
        updatedAt: now,
        tags: const [],
        metadata: const {},
      );
    }

    setUp(() async {
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

      await database
          .into(database.localNotes)
          .insert(
            db.LocalNotesCompanion.insert(
              id: noteId,
              titleEncrypted: const Value('enc-title'),
              bodyEncrypted: const Value('enc-body'),
              encryptionVersion: const Value(1),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              userId: Value(userId),
              deleted: const Value(false),
            ),
          );

      TaskSyncMetrics.instance.clearMetrics();
    });

    tearDown(() async {
      await database.close();
    });

    test('reuses existing task when normalized content matches', () async {
      final first = await repository.createTask(
        buildTask('  Review   Launch Checklist  '),
      );

      final second = await repository.createTask(
        buildTask('review launch checklist'),
      );

      expect(second.id, equals(first.id));

      final stored = await database.getTasksForNote(noteId, userId: userId);

      expect(stored.length, 1);
      expect(
        stored.single.contentHash,
        stableTaskHash(noteId, 'review launch checklist'),
      );

      final health = TaskSyncMetrics.instance.getHealthMetrics();
      expect(health['totalDuplicatesFound'], equals(1));
      expect(health['notesWithDuplicates'], equals(1));
    });

    test('allows distinct tasks when content differs materially', () async {
      await repository.createTask(buildTask('Ship Alpha build'));
      await repository.createTask(buildTask('Ship Beta build'));

      final stored = await database.getTasksForNote(noteId, userId: userId);

      expect(stored.length, 2);

      final health = TaskSyncMetrics.instance.getHealthMetrics();
      expect(health['totalDuplicatesFound'], equals(0));
    });
  });
}
