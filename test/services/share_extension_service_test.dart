import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/models/note_block.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/attachment_service.dart';
import 'package:duru_notes/services/share_extension_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'share_extension_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<NotesCoreRepository>(),
  MockSpec<AttachmentService>(),
  MockSpec<AppLogger>(),
  MockSpec<AnalyticsService>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ShareExtensionService shareService;
  late MockNotesCoreRepository mockNotesRepository;
  late MockAttachmentService mockAttachmentService;
  late MockAppLogger mockLogger;
  late MockAnalyticsService mockAnalytics;

  setUp(() {
    mockNotesRepository = MockNotesCoreRepository();
    mockAttachmentService = MockAttachmentService();
    mockLogger = MockAppLogger();
    mockAnalytics = MockAnalyticsService();

    when(mockLogger.info(any, data: anyNamed('data'))).thenReturn(null);
    when(mockLogger.warning(any, data: anyNamed('data'))).thenReturn(null);
    when(mockLogger.error(
      any,
      error: anyNamed('error'),
      stackTrace: anyNamed('stackTrace'),
      data: anyNamed('data'),
    )).thenReturn(null);

    when(mockAnalytics.event(any, properties: anyNamed('properties')))
        .thenReturn(null);
    when(mockAnalytics.featureUsed(any, properties: anyNamed('properties')))
        .thenReturn(null);
    when(mockAnalytics.startTiming(any)).thenReturn(null);
    when(mockAnalytics.endTiming(any, properties: anyNamed('properties')))
        .thenReturn(null);

    ReceiveSharingIntent.setMockValues(
      initialMedia: const [],
      mediaStream: const Stream<List<SharedMediaFile>>.empty(),
    );

    shareService = ShareExtensionService(
      notesRepository: mockNotesRepository,
      attachmentService: mockAttachmentService,
      logger: mockLogger,
      analytics: mockAnalytics,
    );
  });

  group('ReceiveSharingIntent integration', () {
    test('creates note when text is shared', () async {
      final controller = StreamController<List<SharedMediaFile>>();
      ReceiveSharingIntent.setMockValues(
        initialMedia: const [],
        mediaStream: controller.stream,
      );

      when(mockNotesRepository.createOrUpdate(
        title: anyNamed('title'),
        body: anyNamed('body'),
        tags: anyNamed('tags'),
        metadataJson: anyNamed('metadataJson'),
      )).thenAnswer((invocation) async => domain.Note(
            id: 'shared-text-note',
            title: invocation.namedArguments[#title] as String,
            body: invocation.namedArguments[#body] as String,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            deleted: false,
            isPinned: false,
            noteType: NoteKind.note,
            version: 1,
            userId: 'user-123',
          ));

      await shareService.initialize();

      controller.add([
        SharedMediaFile(
          path: 'Action items for today',
          type: SharedMediaType.text,
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(mockNotesRepository.createOrUpdate(
        title: anyNamed('title'),
        body: argThat(contains('Action items'), named: 'body'),
        tags: anyNamed('tags'),
        metadataJson: anyNamed('metadataJson'),
      )).called(1);
      verify(mockAnalytics.event('share_extension.text_received', properties: anyNamed('properties')))
          .called(1);

      await controller.close();
    });

    test('uploads image attachment and creates note', () async {
      final controller = StreamController<List<SharedMediaFile>>();
      ReceiveSharingIntent.setMockValues(
        initialMedia: const [],
        mediaStream: controller.stream,
      );

      final tempImage = File('${Directory.systemTemp.path}/shared_image.jpg')
        ..writeAsBytesSync(List<int>.filled(10, 1));

      when(mockAttachmentService.uploadFromBytes(
        bytes: anyNamed('bytes'),
        filename: anyNamed('filename'),
      )).thenAnswer((_) async => AttachmentBlockData(
            fileName: 'shared_image.jpg',
            fileSize: 10,
            mimeType: 'image/jpeg',
            url: 'https://example.com/shared_image.jpg',
          ));

      when(mockNotesRepository.createOrUpdate(
        title: anyNamed('title'),
        body: anyNamed('body'),
        tags: anyNamed('tags'),
        metadataJson: anyNamed('metadataJson'),
      )).thenAnswer((invocation) async => domain.Note(
            id: 'shared-image-note',
            title: invocation.namedArguments[#title] as String,
            body: invocation.namedArguments[#body] as String,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            deleted: false,
            isPinned: false,
            noteType: NoteKind.note,
            version: 1,
            userId: 'user-123',
          ));

      await shareService.initialize();

      controller.add([
        SharedMediaFile(
          path: tempImage.path,
          type: SharedMediaType.image,
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(mockAttachmentService.uploadFromBytes(
        bytes: anyNamed('bytes'),
        filename: anyNamed('filename'),
      )).called(1);
      verify(mockNotesRepository.createOrUpdate(
        title: anyNamed('title'),
        body: argThat(contains('Shared Image'), named: 'body'),
        tags: anyNamed('tags'),
        metadataJson: anyNamed('metadataJson'),
      )).called(1);
      await controller.close();
      if (tempImage.existsSync()) {
        tempImage.deleteSync();
      }
    });

    test('uploads file attachment and creates note', () async {
      final controller = StreamController<List<SharedMediaFile>>();
      ReceiveSharingIntent.setMockValues(
        initialMedia: const [],
        mediaStream: controller.stream,
      );

      final tempFile = File('${Directory.systemTemp.path}/shared.txt')
        ..writeAsBytesSync(utf8.encode('Quarterly metrics attached'));

      when(mockAttachmentService.uploadFromBytes(
        bytes: anyNamed('bytes'),
        filename: anyNamed('filename'),
      )).thenAnswer((_) async => AttachmentBlockData(
            fileName: 'shared.txt',
            fileSize: tempFile.lengthSync(),
            mimeType: 'text/plain',
            url: 'https://example.com/shared.txt',
          ));

      when(mockNotesRepository.createOrUpdate(
        title: anyNamed('title'),
        body: anyNamed('body'),
        tags: anyNamed('tags'),
        metadataJson: anyNamed('metadataJson'),
      )).thenAnswer((invocation) async => domain.Note(
            id: 'shared-file-note',
            title: invocation.namedArguments[#title] as String,
            body: invocation.namedArguments[#body] as String,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            deleted: false,
            isPinned: false,
            noteType: NoteKind.note,
            version: 1,
            userId: 'user-123',
          ));

      await shareService.initialize();

      controller.add([
        SharedMediaFile(
          path: tempFile.path,
          type: SharedMediaType.file,
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(mockAttachmentService.uploadFromBytes(
        bytes: anyNamed('bytes'),
        filename: anyNamed('filename'),
      )).called(1);
      verify(mockNotesRepository.createOrUpdate(
        title: anyNamed('title'),
        body: argThat(contains('Shared File'), named: 'body'),
        tags: anyNamed('tags'),
        metadataJson: anyNamed('metadataJson'),
      )).called(1);

      await controller.close();
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    });
  });
}
