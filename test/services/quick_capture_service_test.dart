import 'dart:io';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/domain/entities/quick_capture_queue_item.dart';
import 'package:duru_notes/domain/entities/quick_capture_widget_cache.dart';
import 'package:duru_notes/domain/entities/template.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_quick_capture_repository.dart';
import 'package:duru_notes/domain/repositories/i_template_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/attachment_service.dart';
import 'package:duru_notes/services/quick_capture_service.dart';
import 'package:duru_notes/services/quick_capture_widget_syncer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'quick_capture_service_test.mocks.dart';

String _isoWithoutMicros(DateTime input) =>
    '${input.toUtc().toIso8601String().split('.').first}Z';

@GenerateMocks([
  INotesRepository,
  ITemplateRepository,
  IQuickCaptureRepository,
  AnalyticsService,
  AppLogger,
  SupabaseClient,
  GoTrueClient,
  User,
  AttachmentService,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuickCaptureService', () {
    const userId = 'user-123';

    late MockINotesRepository notesRepository;
    late MockITemplateRepository templateRepository;
    late MockIQuickCaptureRepository quickCaptureRepository;
    late MockAnalyticsService analyticsService;
    late MockAppLogger logger;
    late MockSupabaseClient supabaseClient;
    late MockGoTrueClient authClient;
    late MockUser user;
    late QuickCaptureService service;
    late FakeQuickCaptureWidgetSyncer widgetSyncer;

    late Note repositoryNote;
    late String longBody;
    late String expectedSnippet;
    late DateTime noteCreatedAt;
    late DateTime noteUpdatedAt;

    setUp(() {
      notesRepository = MockINotesRepository();
      templateRepository = MockITemplateRepository();
      quickCaptureRepository = MockIQuickCaptureRepository();
      analyticsService = MockAnalyticsService();
      logger = MockAppLogger();
      supabaseClient = MockSupabaseClient();
      authClient = MockGoTrueClient();
      user = MockUser();

      when(supabaseClient.auth).thenReturn(authClient);
      when(authClient.currentUser).thenReturn(user);
      when(user.id).thenReturn(userId);

      longBody = List.filled(200, 'A').join();
      expectedSnippet = '${longBody.substring(0, 137)}...';
      noteCreatedAt = DateTime.utc(2025, 1, 1, 9, 30, 45, 123, 456);
      noteUpdatedAt = DateTime.utc(2025, 1, 1, 10, 30, 45, 456, 789);
      repositoryNote = Note(
        id: 'note-1',
        title: 'Last capture',
        body: longBody,
        createdAt: noteCreatedAt,
        updatedAt: noteUpdatedAt,
        deleted: false,
        isPinned: false,
        noteType: NoteKind.note,
        version: 1,
        userId: userId,
        encryptedMetadata: null,
        folderId: null,
        attachmentMeta: null,
        metadata: null,
      );

      when(
        notesRepository.list(limit: anyNamed('limit')),
      ).thenAnswer((_) async => [repositoryNote]);

      when(
        quickCaptureRepository.upsertWidgetCache(any),
      ).thenAnswer((_) async {});
      when(
        quickCaptureRepository.enqueueCapture(
          userId: anyNamed('userId'),
          payload: anyNamed('payload'),
          platform: anyNamed('platform'),
        ),
      ).thenAnswer(
        (_) async => QuickCaptureQueueItem(
          id: 'queued',
          userId: userId,
          payload: const {'text': 'queued'},
          createdAt: DateTime.now(),
        ),
      );

      widgetSyncer = FakeQuickCaptureWidgetSyncer();

      service = QuickCaptureService(
        notesRepository: notesRepository,
        templateRepository: templateRepository,
        quickCaptureRepository: quickCaptureRepository,
        analyticsService: analyticsService,
        logger: logger,
        supabaseClient: supabaseClient,
        widgetSyncer: widgetSyncer,
      );
    });

    test('captureNote creates note and refreshes widget cache', () async {
      when(
        notesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
          tags: anyNamed('tags'),
          metadataJson: anyNamed('metadataJson'),
        ),
      ).thenAnswer((_) async => repositoryNote);

      final result = await service.captureNote(text: 'Quick capture body');

      expect(result.success, isTrue);
      expect(result.noteId, equals(repositoryNote.id));

      verify(
        notesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
          tags: anyNamed('tags'),
          metadataJson: anyNamed('metadataJson'),
        ),
      ).called(1);

      expect(widgetSyncer.syncCalls, 1);
      expect(widgetSyncer.lastUserId, userId);

      final payload = widgetSyncer.lastPayload;
      expect(payload, isNotNull);
      expect(payload!['userId'], equals(userId));

      final updatedAt = payload['updatedAt'] as String;
      expect(updatedAt.endsWith('Z'), isTrue);
      expect(updatedAt.contains('.'), isFalse);

      final captures = payload['recentCaptures'] as List<dynamic>;
      expect(captures, hasLength(1));
      final capture = captures.first as Map<String, dynamic>;

      expect(capture['id'], equals(repositoryNote.id));
      expect(capture['title'], equals(repositoryNote.title));
      expect(capture['snippet'], equals(expectedSnippet));

      final createdAtIso = capture['createdAt'] as String;
      final updatedAtIso = capture['updatedAt'] as String;
      expect(createdAtIso, equals(_isoWithoutMicros(noteCreatedAt)));
      expect(updatedAtIso, equals(_isoWithoutMicros(noteUpdatedAt)));

      expect(createdAtIso.contains('.'), isFalse);
      expect(updatedAtIso.contains('.'), isFalse);
      expect(createdAtIso.endsWith('Z'), isTrue);
      expect(updatedAtIso.endsWith('Z'), isTrue);

      final capturedCache =
          verify(
                quickCaptureRepository.upsertWidgetCache(captureAny),
              ).captured.single
              as QuickCaptureWidgetCache;
      expect(capturedCache.userId, equals(userId));
      expect(capturedCache.payload, equals(payload));

      verify(
        analyticsService.event(
          'quick_capture.note_created',
          properties: anyNamed('properties'),
        ),
      ).called(1);
    });

    test(
      'captureNote queues entry when repository throws SocketException',
      () async {
        when(
          notesRepository.createOrUpdate(
            title: anyNamed('title'),
            body: anyNamed('body'),
            tags: anyNamed('tags'),
            metadataJson: anyNamed('metadataJson'),
          ),
        ).thenThrow(const SocketException('Offline'));

        final result = await service.captureNote(text: 'Offline capture');

        expect(result.success, isFalse);
        expect(result.metadata?['queued'], isTrue);
        verify(
          quickCaptureRepository.enqueueCapture(
            userId: anyNamed('userId'),
            payload: anyNamed('payload'),
            platform: anyNamed('platform'),
          ),
        ).called(1);
      },
    );

    test(
      'processPendingCaptures processes queue and clears processed items',
      () async {
        final queueItem = QuickCaptureQueueItem(
          id: 'queue-1',
          userId: userId,
          payload: const {
            'text': 'Queued note',
            'tags': ['queue'],
            'metadata': {'queued': true},
          },
          createdAt: DateTime.now(),
        );

        when(
          quickCaptureRepository.getPendingCaptures(
            userId: anyNamed('userId'),
            limit: anyNamed('limit'),
          ),
        ).thenAnswer((_) async => [queueItem]);

        when(
          notesRepository.createOrUpdate(
            title: anyNamed('title'),
            body: anyNamed('body'),
            tags: anyNamed('tags'),
            metadataJson: anyNamed('metadataJson'),
          ),
        ).thenAnswer(
          (_) async => Note(
            id: 'note-queued',
            title: 'Queued',
            body: 'Queued note',
            createdAt: DateTime.utc(2025, 1, 2, 8),
            updatedAt: DateTime.now(),
            deleted: false,
            isPinned: false,
            noteType: NoteKind.note,
            version: 1,
            userId: userId,
            encryptedMetadata: null,
            folderId: null,
            attachmentMeta: null,
            metadata: null,
          ),
        );

        when(
          quickCaptureRepository.clearProcessedCaptures(
            userId: anyNamed('userId'),
            olderThan: anyNamed('olderThan'),
          ),
        ).thenAnswer((_) async {});

        final processed = await service.processPendingCaptures();

        expect(processed, equals(1));
        verify(
          quickCaptureRepository.markCaptureProcessed(
            id: 'queue-1',
            processed: true,
            processedAt: anyNamed('processedAt'),
          ),
        ).called(1);
        verify(
          quickCaptureRepository.clearProcessedCaptures(
            userId: anyNamed('userId'),
            olderThan: anyNamed('olderThan'),
          ),
        ).called(1);
      },
    );

    test('getTemplates delegates to template repository', () async {
      final template = Template(
        id: 'template-1',
        name: 'Meeting',
        content: '## Meeting Notes',
        variables: const {},
        isSystem: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      when(
        templateRepository.getAllTemplates(),
      ).thenAnswer((_) async => [template]);

      final templates = await service.getTemplates();

      expect(templates, hasLength(1));
      expect(templates.single.id, equals('template-1'));
    });
  });
}

class FakeQuickCaptureWidgetSyncer extends QuickCaptureWidgetSyncer {
  int syncCalls = 0;
  String? lastUserId;
  Map<String, dynamic>? lastPayload;

  @override
  Future<void> clear() async {}

  @override
  Future<void> sync({
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    syncCalls += 1;
    lastUserId = userId;
    lastPayload = Map<String, dynamic>.from(payload);
  }
}
