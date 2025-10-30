import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/infrastructure/repositories/task_core_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('TaskCoreRepository user isolation', () {
    late AppDb db;
    late TaskCoreRepository repository;
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late MockUser mockUser;
    late StubCryptoBox crypto;

    User? activeUser;
    String? currentUserId;

    void signIn(String userId) {
      currentUserId = userId;
      activeUser = mockUser;
    }

    void signOut() {
      activeUser = null;
      currentUserId = null;
    }

    setUp(() {
      db = AppDb.forTesting(NativeDatabase.memory());
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockUser = MockUser();
      crypto = StubCryptoBox();

      when(mockSupabase.auth).thenReturn(mockAuth);
      when(mockAuth.currentUser).thenAnswer((_) => activeUser);
      when(mockUser.id).thenAnswer((_) => currentUserId ?? '');

      repository = TaskCoreRepository(
        db: db,
        client: mockSupabase,
        crypto: crypto,
      );

      signIn('user-a');
    });

    tearDown(() async {
      await db.close();
    });

    domain.Task task0({
      required String noteId,
      String id = '',
      String title = 'Task Title',
    }) {
      final now = DateTime.now();
      return domain.Task(
        id: id,
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

    Future<void> insertNote({
      required String noteId,
      required String userId,
    }) async {
      await db
          .into(db.localNotes)
          .insert(
            LocalNotesCompanion.insert(
              id: noteId,
              userId: Value(userId),
              titleEncrypted: const Value('seed-title'),
              bodyEncrypted: const Value('seed-body'),
              encryptionVersion: const Value(1),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
    }

    test('createTask throws when no authenticated user', () async {
      signOut();
      await insertNote(noteId: 'note-1', userId: 'user-a');

      expect(
        () => repository.createTask(task0(noteId: 'note-1')),
        throwsA(isA<StateError>()),
      );
    });

    test('getAllTasks returns tasks only for current user', () async {
      await insertNote(noteId: 'note-a', userId: 'user-a');
      await insertNote(noteId: 'note-b', userId: 'user-b');

      final userATask = await repository.createTask(
        task0(noteId: 'note-a', title: 'A'),
      );

      signIn('user-b');
      final userBTask = await repository.createTask(
        task0(noteId: 'note-b', title: 'B'),
      );

      signIn('user-a');
      final tasksForA = await repository.getAllTasks();
      expect(tasksForA.map((t) => t.id), [userATask.id]);

      signIn('user-b');
      final tasksForB = await repository.getAllTasks();
      expect(tasksForB.map((t) => t.id), [userBTask.id]);
    });

    test('getTaskById enforces ownership', () async {
      await insertNote(noteId: 'note-a', userId: 'user-a');
      final task = await repository.createTask(
        task0(noteId: 'note-a', title: 'Secret Task'),
      );

      signIn('user-b');
      final foreignLookup = await repository.getTaskById(task.id);
      expect(
        foreignLookup,
        isNull,
        reason: 'Foreign user must not access another user task',
      );

      signIn('user-a');
      final ownedLookup = await repository.getTaskById(task.id);
      expect(ownedLookup, isNotNull);
      expect(ownedLookup!.title, 'Secret Task');
    });
  });
}
