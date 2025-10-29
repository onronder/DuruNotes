import 'dart:convert';

import 'package:duru_notes/core/monitoring/app_logger.dart'
    show AppLogger, NoOpLogger;
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/domain/entities/note.dart' as note_domain;
import 'package:duru_notes/domain/entities/task.dart' as task_domain;
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart';
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/services/deep_link_service.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class _TestRef implements Ref<Object?> {
  _TestRef(this._logger);
  final AppLogger _logger;

  @override
  ProviderContainer get container =>
      throw UnsupportedError('container is not available in tests');

  @override
  T refresh<T>(Refreshable<T> provider) =>
      throw UnsupportedError('refresh not supported in tests');

  @override
  void invalidate(ProviderOrFamily provider) =>
      throw UnsupportedError('invalidate not supported in tests');

  @override
  void notifyListeners() =>
      throw UnsupportedError('notifyListeners not supported in tests');

  @override
  void listenSelf(
    void Function(Object? previous, Object? next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) => throw UnsupportedError('listenSelf not supported in tests');

  @override
  void invalidateSelf() =>
      throw UnsupportedError('invalidateSelf not supported in tests');

  @override
  void onAddListener(void Function() cb) =>
      throw UnsupportedError('onAddListener not supported in tests');

  @override
  void onRemoveListener(void Function() cb) =>
      throw UnsupportedError('onRemoveListener not supported in tests');

  @override
  void onResume(void Function() cb) =>
      throw UnsupportedError('onResume not supported in tests');

  @override
  void onCancel(void Function() cb) =>
      throw UnsupportedError('onCancel not supported in tests');

  @override
  void onDispose(void Function() cb) =>
      throw UnsupportedError('onDispose not supported in tests');

  @override
  T read<T>(ProviderListenable<T> provider) {
    if (identical(provider, loggerProvider)) {
      return _logger as T;
    }
    throw UnsupportedError('No override registered for $provider');
  }

  @override
  bool exists(ProviderBase<Object?> provider) =>
      throw UnsupportedError('exists not supported in tests');

  @override
  T watch<T>(ProviderListenable<T> provider) =>
      throw UnsupportedError('watch not supported in tests');

  @override
  KeepAliveLink keepAlive() =>
      throw UnsupportedError('keepAlive not supported in tests');

  @override
  ProviderSubscription<T> listen<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
    bool fireImmediately = false,
  }) => throw UnsupportedError('listen not supported in tests');
}

class _MockTaskRepository extends Mock implements ITaskRepository {
  final Map<String, task_domain.Task?> tasks = <String, task_domain.Task?>{};

  @override
  Future<task_domain.Task?> getTaskById(String id) =>
      super.noSuchMethod(
            Invocation.method(#getTaskById, [id]),
            returnValue: Future.value(tasks[id]),
            returnValueForMissingStub: Future.value(tasks[id]),
          )
          as Future<task_domain.Task?>;
}

class _MockNotesCoreRepository extends Mock implements NotesCoreRepository {
  final Map<String, note_domain.Note?> notes = <String, note_domain.Note?>{};

  @override
  Future<note_domain.Note?> getNoteById(String id) =>
      super.noSuchMethod(
            Invocation.method(#getNoteById, [id]),
            returnValue: Future<note_domain.Note?>.value(notes[id]),
            returnValueForMissingStub: Future<note_domain.Note?>.value(notes[id]),
          )
          as Future<note_domain.Note?>;
}

class _MockEnhancedTaskService extends Mock implements EnhancedTaskService {
  @override
  Future<void> handleTaskNotificationAction({
    required String action,
    required String payload,
  }) =>
      super.noSuchMethod(
            Invocation.method(#handleTaskNotificationAction, [], {
              #action: action,
              #payload: payload,
            }),
            returnValue: Future<void>.value(),
            returnValueForMissingStub: Future<void>.value(),
          )
          as Future<void>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _TestRef testRef;
  late _MockTaskRepository mockTaskRepository;
  late _MockNotesCoreRepository mockNotesRepository;
  late _MockEnhancedTaskService mockEnhancedTaskService;
  late DeepLinkService service;

  T reader<T>(ProviderListenable<T> provider) {
    if (identical(provider, taskRepositoryProvider)) {
      return mockTaskRepository as T;
    }
    if (identical(provider, notesCoreRepositoryProvider)) {
      return mockNotesRepository as T;
    }
    if (identical(provider, enhancedTaskServiceProvider)) {
      return mockEnhancedTaskService as T;
    }
    throw UnsupportedError('No override for $provider');
  }

  task_domain.Task buildTask({required String id, required String noteId}) {
    final now = DateTime.now();
    return task_domain.Task(
      id: id,
      noteId: noteId,
      title: 'Follow up',
      description: null,
      status: task_domain.TaskStatus.pending,
      priority: task_domain.TaskPriority.medium,
      dueDate: null,
      completedAt: null,
      createdAt: now,
      updatedAt: now,
      tags: const [],
      metadata: const {},
    );
  }

  setUp(() {
    testRef = _TestRef(const NoOpLogger());
    mockTaskRepository = _MockTaskRepository();
    mockNotesRepository = _MockNotesCoreRepository();
    mockEnhancedTaskService = _MockEnhancedTaskService();

    service = DeepLinkService(testRef, read: reader);
  });

  group('handleDeepLink', () {
    testWidgets('shows warning when task lookup fails', (tester) async {
      const taskId = 'task-missing';
      mockTaskRepository.tasks[taskId] = null;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => service.handleDeepLink(
                    context: context,
                    payload: jsonEncode({
                      'type': 'task_reminder',
                      'taskId': taskId,
                      'noteId': 'note-1',
                    }),
                  ),
                  child: const Text('Trigger'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Task not found or has been deleted'), findsOneWidget);
      verify(mockTaskRepository.getTaskById(taskId)).called(1);
      verifyZeroInteractions(mockNotesRepository);
    });

    testWidgets('shows warning when note lookup fails', (tester) async {
      const taskId = 'task-123';
      const noteId = 'note-missing';

      final task = buildTask(id: taskId, noteId: noteId);
      mockTaskRepository.tasks[taskId] = task;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => service.handleDeepLink(
                    context: context,
                    payload: jsonEncode({
                      'type': 'task',
                      'taskId': taskId,
                      'noteId': noteId,
                    }),
                  ),
                  child: const Text('Trigger'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Note not found or has been deleted'), findsOneWidget);
      verify(mockTaskRepository.getTaskById(taskId)).called(1);
      verify(mockNotesRepository.getNoteById(noteId)).called(1);
    });
  });

  group('handleTaskNotificationAction', () {
    test('delegates to EnhancedTaskService', () async {
      mockTaskRepository.tasks.clear();

      await service.handleTaskNotificationAction(
        action: 'complete_task',
        payload: '{"taskId":"task-42"}',
      );

      verify(
        mockEnhancedTaskService.handleTaskNotificationAction(
          action: 'complete_task',
          payload: '{"taskId":"task-42"}',
        ),
      ).called(1);
    });
  });

  group('deep link builders', () {
    test('createTaskDeepLink encodes parameters', () {
      final link = service.createTaskDeepLink('task-1', noteId: 'note-1');
      expect(link, startsWith('durunotes://task?data='));
      final encoded = link.split('data=').last;
      final decoded = jsonDecode(Uri.decodeComponent(encoded)) as Map;
      expect(decoded['type'], equals('task'));
      expect(decoded['taskId'], equals('task-1'));
      expect(decoded['noteId'], equals('note-1'));
    });

    test('createNoteDeepLink encodes note id', () {
      final link = service.createNoteDeepLink('note-42');
      final encoded = link.split('data=').last;
      final decoded = jsonDecode(Uri.decodeComponent(encoded)) as Map;
      expect(decoded['type'], equals('note'));
      expect(decoded['noteId'], equals('note-42'));
    });
  });
}
