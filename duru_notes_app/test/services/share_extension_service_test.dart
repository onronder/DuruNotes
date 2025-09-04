import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../lib/core/monitoring/app_logger.dart';
import '../../lib/data/local/app_db.dart';
import '../../lib/models/note_block.dart';
import '../../lib/repository/notes_repository.dart';
import '../../lib/services/analytics/analytics_service.dart';
import '../../lib/services/attachment_service.dart';
import '../../lib/services/share_extension_service.dart';
import 'share_extension_service_test.mocks.dart';

@GenerateMocks([
  NotesRepository,
  AttachmentService,
  AppLogger,
  AnalyticsService,
])
void main() {
  group('ShareExtensionService Tests', () {
    late MockNotesRepository mockRepository;
    late MockAttachmentService mockAttachmentService;
    late MockAppLogger mockLogger;
    late MockAnalyticsService mockAnalytics;
    late ShareExtensionService shareService;

    setUp(() {
      mockRepository = MockNotesRepository();
      mockAttachmentService = MockAttachmentService();
      mockLogger = MockAppLogger();
      mockAnalytics = MockAnalyticsService();

      shareService = ShareExtensionService(
        notesRepository: mockRepository,
        attachmentService: mockAttachmentService,
        logger: mockLogger,
        analytics: mockAnalytics,
      );

      // Setup default mock behaviors
      when(mockLogger.info(any, data: anyNamed('data'))).thenReturn(null);
      when(mockLogger.debug(any, data: anyNamed('data'))).thenReturn(null);
      when(mockLogger.error(any, error: anyNamed('error'), data: anyNamed('data'))).thenReturn(null);
      when(mockLogger.warning(any, data: anyNamed('data'))).thenReturn(null);
      when(mockAnalytics.event(any, properties: anyNamed('properties'))).thenReturn(null);
    });

    group('Shared Text Processing', () {
      test('creates note from shared text', () async {
        // Arrange
        const sharedText = 'This is a shared text message';
        const expectedTitle = 'This is a shared text message';
        
        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => 'note123');

        // Act
        await shareService.handleSharedText(sharedText);

        // Assert
        verify(mockRepository.createOrUpdate(
          title: expectedTitle,
          body: sharedText,
        )).called(1);
        
        verify(mockAnalytics.event('share_extension.text_received',
          properties: anyNamed('properties'))).called(1);
        verify(mockAnalytics.event('share_extension.note_created',
          properties: anyNamed('properties'))).called(1);
      });

      test('handles empty shared text gracefully', () async {
        // Arrange
        const sharedText = '';
        
        // Act
        await shareService.handleSharedText(sharedText);

        // Assert
        verifyNever(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        ));
        
        verify(mockAnalytics.event('share_extension.text_received',
          properties: anyNamed('properties'))).called(1);
      });

      test('truncates long titles to 50 characters', () async {
        // Arrange
        const longText = 'This is a very long text that should be truncated when used as a title because it exceeds the maximum allowed length';
        const expectedTitle = 'This is a very long text that should be truncat...';
        
        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => 'note123');

        // Act
        await shareService.handleSharedText(longText);

        // Assert
        verify(mockRepository.createOrUpdate(
          title: expectedTitle,
          body: longText,
        )).called(1);
      });

      test('uses first line as title for multi-line text', () async {
        // Arrange
        const multiLineText = 'First line title\nSecond line content\nThird line content';
        const expectedTitle = 'First line title';
        
        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => 'note123');

        // Act
        await shareService.handleSharedText(multiLineText);

        // Assert
        verify(mockRepository.createOrUpdate(
          title: expectedTitle,
          body: multiLineText,
        )).called(1);
      });
    });

    group('Shared Media Processing', () {
      test('processes shared image files', () async {
        // Arrange
        final mediaFile = SharedMediaFile(
          path: '/tmp/test_image.jpg',
          thumbnail: null,
          duration: null,
          type: SharedMediaType.image,
        );
        
        when(mockAttachmentService.uploadAttachment(
          any,
          any,
          any,
        )).thenAnswer((_) async => 'https://example.com/image.jpg');
        
        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => 'note123');

        // Act
        await shareService.handleSharedMedia([mediaFile]);

        // Assert
        verify(mockAttachmentService.uploadAttachment(
          any,
          any,
          any,
        )).called(1);
        
        verify(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).called(1);
        
        verify(mockAnalytics.event('share_extension.media_received',
          properties: anyNamed('properties'))).called(1);
      });

      test('handles multiple media files', () async {
        // Arrange
        final mediaFiles = [
          SharedMediaFile(
            path: '/tmp/image1.jpg',
            thumbnail: null,
            duration: null,
            type: SharedMediaType.image,
          ),
          SharedMediaFile(
            path: '/tmp/image2.png',
            thumbnail: null,
            duration: null,
            type: SharedMediaType.image,
          ),
        ];
        
        when(mockAttachmentService.uploadAttachment(
          any,
          any,
          any,
        )).thenAnswer((_) async => 'https://example.com/image.jpg');
        
        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => 'note123');

        // Act
        await shareService.handleSharedMedia(mediaFiles);

        // Assert
        verify(mockAttachmentService.uploadAttachment(
          any,
          any,
          any,
        )).called(2);
        
        verify(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).called(2);
      });

      test('handles video files', () async {
        // Arrange
        final videoFile = SharedMediaFile(
          path: '/tmp/video.mp4',
          thumbnail: null,
          duration: 120, // 2 minutes
          type: SharedMediaType.video,
        );
        
        when(mockAttachmentService.uploadAttachment(
          any,
          any,
          any,
        )).thenAnswer((_) async => 'https://example.com/video.mp4');
        
        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => 'note123');

        // Act
        await shareService.handleSharedMedia([videoFile]);

        // Assert
        verify(mockAttachmentService.uploadAttachment(
          any,
          any,
          any,
        )).called(1);
        
        verify(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).called(1);
      });

      test('handles generic files', () async {
        // Arrange
        final genericFile = SharedMediaFile(
          path: '/tmp/document.pdf',
          thumbnail: null,
          duration: null,
          type: SharedMediaType.file,
        );
        
        when(mockAttachmentService.uploadAttachment(
          any,
          any,
          any,
        )).thenAnswer((_) async => 'https://example.com/document.pdf');
        
        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => 'note123');

        // Act
        await shareService.handleSharedMedia([genericFile]);

        // Assert
        verify(mockAttachmentService.uploadAttachment(
          any,
          any,
          any,
        )).called(1);
        
        verify(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).called(1);
      });
    });

    group('Error Handling', () {
      test('handles repository errors gracefully', () async {
        // Arrange
        const sharedText = 'Test text';
        
        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenThrow(Exception('Database error'));

        // Act & Assert
        expect(
          () async => await shareService.handleSharedText(sharedText),
          throwsException,
        );
        
        verify(mockLogger.error('Failed to handle shared text',
          error: anyNamed('error'))).called(1);
      });

      test('logs analytics events even when processing fails', () async {
        // Arrange
        const sharedText = 'Test text';
        
        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenThrow(Exception('Processing failed'));

        // Act
        try {
          await shareService.handleSharedText(sharedText);
        } catch (e) {
          // Expected to throw
        }

        // Assert
        verify(mockAnalytics.event('share_extension.text_received',
          properties: anyNamed('properties'))).called(1);
      });
    });

    group('Title Generation', () {
      test('generates meaningful titles from various text inputs', () {
        final testCases = [
          {
            'input': 'Simple title',
            'expected': 'Simple title',
          },
          {
            'input': 'A very long title that exceeds the fifty character limit and should be truncated',
            'expected': 'A very long title that exceeds the fifty charac...',
          },
          {
            'input': 'Multi-line\ncontent here',
            'expected': 'Multi-line',
          },
          {
            'input': '   Trimmed   content   ',
            'expected': 'Trimmed   content',
          },
          {
            'input': '',
            'expected': 'Shared Note',
          },
        ];

        for (final testCase in testCases) {
          final result = shareService.generateTitleFromText(testCase['input'] as String);
          expect(result, testCase['expected'], 
            reason: 'Failed for input: "${testCase['input']}"');
        }
      });
    });
  });
}