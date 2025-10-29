import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/data/local/app_db.dart' as db;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/infrastructure/repositories/task_core_repository.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/services/task_reminder_bridge.dart';
import 'package:drift/drift.dart' show Value;

import '../security/authorization_service_test.mocks.dart';

Uint8List _toEncrypted(String value) =>
    Uint8List.fromList(utf8.encode('enc:$value'));

String _fromEncrypted(Uint8List data) {
  final text = utf8.decode(data);
  return text.startsWith('enc:') ? text.substring(4) : text;
}

class StubCryptoBox extends Mock implements CryptoBox {
  @override
  Future<Uint8List> encryptStringForNote({
    required String userId,
    required String noteId,
    required String text,
  }) async {
    return _toEncrypted(text);
  }

  @override
  Future<String> decryptStringForNote({
    required String userId,
    required String noteId,
    required Uint8List data,
  }) async {
    return _fromEncrypted(data);
  }
}

class MockTaskReminderBridge extends Mock implements TaskReminderBridge {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('EnhancedTaskService isolation', () {
    late db.AppDb database;
    late TaskCoreRepository repository;
    late EnhancedTaskService service;

    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late MockUser mockUser;
    late StubCryptoBox crypto;
    late MockTaskReminderBridge mockReminderBridge;

    String? currentUserId;
    void signIn(String userId) {
      currentUserId = userId;
    }

    void signOut() {
      currentUserId = null;
    }

    Future<void> seedNote({
      required String noteId,
      required String userId,
    }) async {
      await database.into(database.localNotes).insert(
        db.LocalNotesCompanion.insert(
          id: noteId,
          userId: Value(userId),
          titleEncrypted: const Value('seed-title'),
          bodyEncrypted: const Value('seed-body'),
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
      crypto = StubCryptoBox();
      mockReminderBridge = MockTaskReminderBridge();

      when(mockSupabase.auth).thenReturn(mockAuth);
      when(mockAuth.currentUser)
          .thenAnswer((_) => currentUserId == null ? null : mockUser);
      when(mockUser.id).thenAnswer((_) => currentUserId ?? '');

      repository = TaskCoreRepository(
        db: database,
        client: mockSupabase,
        crypto: crypto,
      );

      service = EnhancedTaskService(
        database: database,
        taskRepository: repository,
        reminderBridge: mockReminderBridge,
        supabaseClient: mockSupabase,
      );

      signIn('user-a');
    });

    tearDown(() async {
      await database.close();
    });

    domain.Task buildTask(String noteId, String title) {
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

    Future<String> createTaskForCurrentUser({
      required String noteId,
      required String title,
    }) async {
      final task = buildTask(noteId, title);
      final created = await repository.createTask(task);
      return created.id;
    }

    test('updateTask requires authenticated user', () async {
      await seedNote(noteId: 'note-a', userId: 'user-a');
      final taskId =
          await createTaskForCurrentUser(noteId: 'note-a', title: 'Alpha');

      signOut();

      expect(
        () => service.updateTask(taskId: taskId, content: 'Beta'),
        throwsA(isA<StateError>()),
      );
    });

    test('deleteTask cannot remove tasks owned by another user', () async {
      await seedNote(noteId: 'note-a', userId: 'user-a');
      final taskId =
          await createTaskForCurrentUser(noteId: 'note-a', title: 'Alpha');

      signIn('user-b');
      await service.deleteTask(taskId);

      final userATask =
          await database.getTaskById(taskId, userId: 'user-a');
      expect(userATask, isNotNull,
          reason: 'User B should not be able to delete User A task');
      verifyZeroInteractions(mockReminderBridge);
    });
  });
}
