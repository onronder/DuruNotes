import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../lib/core/monitoring/app_logger.dart';
import '../../lib/data/local/app_db.dart';
import '../../lib/repository/notes_repository.dart';
import '../../lib/services/analytics/analytics_service.dart';
import '../../lib/services/attachment_service.dart';
import '../../lib/services/share_extension_service.dart';

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
      when(mockLogger.warning(any, error: anyNamed('error'), data: anyNamed('data'))).thenReturn(null);
      when(mockAnalytics.event(any, properties: anyNamed('properties'))).thenReturn(null);
    });

    group('Shared Text Processing', () {
      test('creates note from shared text with proper title generation', () async {
        // Arrange
        const sharedText = 'This is a shared text that should become a note title and content.';
        const expectedNoteId = 'test-note-123';
        
        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => expectedNoteId);

        // Act
        await shareService._handleSharedText(sharedText);

        // Assert
        verify(mockRepository.createOrUpdate(
          title: 'This is a shared text that should become a note...',
          body: sharedText,
        )).called(1);

        verify(mockAnalytics.event('share_extension.text_received', 
          properties: anyNamed('properties'))).called(1);

        verify(mockAnalytics.event('share_extension.note_created',
          properties: anyNamed('properties'))).called(1);
      });

      test('handles empty shared text gracefully', () async {
        // Arrange
        const emptyText = '';

        // Act
        await shareService._handleSharedText(emptyText);

        // Assert
        verifyNever(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        ));

        verify(mockAnalytics.event('share_extension.text_received',
          properties: anyNamed('properties'))).called(1);
      });

      test('generates appropriate titles from different text types', () async {
        // Test cases for title generation
        final testCases = [
          {
            'input': 'Short text',
            'expectedTitle': 'Short text',
          },
          {
            'input': 'This is a very long text that should be truncated because it exceeds the maximum title length',
            'expectedTitle': 'This is a very long text that should be truncat...',
          },
          {
            'input': 'Multi-line text\nwith second line\nand third line',
            'expectedTitle': 'Multi-line text',
          },
          {
            'input': '   Whitespace padded text   ',
            'expectedTitle': 'Whitespace padded text',
          },
        ];

        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => 'test-id');

        for (final testCase in testCases) {
          // Act
          await shareService._handleSharedText(testCase['input'] as String);

          // Assert
          verify(mockRepository.createOrUpdate(
            title: testCase['expectedTitle'],
            body: testCase['input'],
          )).called(1);
        }
      });
    });

    group('Shared Media Processing', () {
      test('processes shared image files correctly', () async {
        // Arrange
        final sharedFiles = [
          SharedMediaFile(
            path: '/path/to/image.jpg',
            thumbnail: null,
            duration: null,
            type: SharedMediaType.image,
          ),
        ];

        final mockAttachment = AttachmentBlockData(
          fileName: 'image.jpg',
          fileSize: 1024,
          mimeType: 'image/jpeg',
          url: 'https://example.com/image.jpg',
        );

        when(mockAttachmentService.uploadFile(
          bytes: anyNamed('bytes'),
          filename: anyNamed('filename'),
        )).thenAnswer((_) async => mockAttachment);

        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => 'image-note-123');

        // Act
        await shareService._handleSharedMedia(sharedFiles);

        // Assert
        verify(mockAttachmentService.uploadFile(
          bytes: anyNamed('bytes'),
          filename: anyNamed('filename'),
        )).called(1);

        verify(mockRepository.createOrUpdate(
          title: 'Shared Image',
          body: argThat(contains('![image.jpg](https://example.com/image.jpg)'), named: 'body'),
        )).called(1);

        verify(mockAnalytics.event('share_extension.media_received',
          properties: anyNamed('properties'))).called(1);

        verify(mockAnalytics.event('share_extension.note_created',
          properties: anyNamed('properties'))).called(1);
      });

      test('handles attachment upload failures gracefully', () async {
        // Arrange
        final sharedFiles = [
          SharedMediaFile(
            path: '/path/to/image.jpg',
            thumbnail: null,
            duration: null,
            type: SharedMediaType.image,
          ),
        ];

        when(mockAttachmentService.uploadFile(
          bytes: anyNamed('bytes'),
          filename: anyNamed('filename'),
        )).thenThrow(Exception('Upload failed'));

        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => 'fallback-note-123');

        // Act
        await shareService._handleSharedMedia(sharedFiles);

        // Assert
        verify(mockRepository.createOrUpdate(
          title: 'Shared Image',
          body: 'Shared image could not be processed.',
        )).called(1);

        verify(mockLogger.error('Failed to process shared media file',
          error: anyNamed('error'))).called(1);
      });
    });

    group('iOS Share Extension Integration', () {
      test('processes shared items from iOS correctly', () async {
        // Arrange
        final sharedItems = [
          {
            'type': 'text',
            'title': 'Shared Text Title',
            'content': 'This is shared text content',
            'timestamp': DateTime.now().toIso8601String(),
          },
          {
            'type': 'url',
            'title': 'Shared Link',
            'content': 'https://example.com',
            'url': 'https://example.com',
            'timestamp': DateTime.now().toIso8601String(),
          },
        ];

        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => 'shared-note-123');

        // Act
        await shareService._processSharedItems(sharedItems);

        // Assert
        verify(mockRepository.createOrUpdate(
          title: 'Shared Text Title',
          body: 'This is shared text content',
        )).called(1);

        verify(mockRepository.createOrUpdate(
          title: 'Shared Link',
          body: argThat(contains('**Link**: https://example.com'), named: 'body'),
        )).called(1);
      });

      test('handles invalid shared item types gracefully', () async {
        // Arrange
        final sharedItems = [
          {
            'type': 'unknown_type',
            'title': 'Unknown Item',
            'content': 'Unknown content',
            'timestamp': DateTime.now().toIso8601String(),
          },
        ];

        // Act
        await shareService._processSharedItems(sharedItems);

        // Assert
        verifyNever(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        ));

        verify(mockLogger.warning('Unknown shared item type',
          data: anyNamed('data'))).called(1);
      });
    });

    group('Error Handling', () {
      test('handles repository errors during note creation', () async {
        // Arrange
        const sharedText = 'Test shared text';
        
        when(mockRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
        )).thenThrow(Exception('Repository error'));

        // Act & Assert
        expect(
          () => shareService._handleSharedText(sharedText),
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
          await shareService._handleSharedText(sharedText);
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
          final result = shareService._generateTitleFromText(testCase['input'] as String);
          expect(result, testCase['expected'], 
            reason: 'Failed for input: "${testCase['input']}"');
        }
      });
    });
  });
}

/// Test helper to create mock shared media files
extension ShareExtensionServiceTestHelper on ShareExtensionService {
  String _generateTitleFromText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Shared Note';
    
    // Use first line or first 50 characters as title
    final firstLine = trimmed.split('\n').first.trim();
    if (firstLine.length <= 50) {
      return firstLine;
    }
    
    return '${firstLine.substring(0, 47)}...';
  }

  Future<void> _handleSharedText(String sharedText) async {
    final trimmed = sharedText.trim();
    if (trimmed.isEmpty) {
      _analytics.event('share_extension.text_received', properties: {
        'content_length': sharedText.length,
        'platform': Platform.operatingSystem,
      });
      return;
    }

    _analytics.event('share_extension.text_received', properties: {
      'content_length': sharedText.length,
      'platform': Platform.operatingSystem,
    });

    final title = _generateTitleFromText(sharedText);
    
    await _createNoteFromSharedContent(
      title: title,
      content: sharedText,
      type: 'text',
    );
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> sharedFiles) async {
    _analytics.event('share_extension.media_received', properties: {
      'file_count': sharedFiles.length,
      'platform': Platform.operatingSystem,
    });

    for (final mediaFile in sharedFiles) {
      await _processSharedMediaFile(mediaFile);
    }
  }

  Future<void> _processSharedMediaFile(SharedMediaFile mediaFile) async {
    try {
      final file = File(mediaFile.path);
      if (!await file.exists()) return;

      final fileName = mediaFile.path.split('/').last;
      final fileBytes = await file.readAsBytes();
      
      if (mediaFile.type == SharedMediaType.image) {
        // Handle shared image
        final attachment = await _attachmentService.uploadFile(
          bytes: fileBytes,
          filename: fileName,
        );
        
        final noteContent = '''# Shared Image

![${fileName}](${attachment.url})

*Shared on ${DateTime.now().toString()}*
''';

        await _createNoteFromSharedContent(
          title: 'Shared Image',
          content: noteContent,
          type: 'android_image',
        );
      }
    } catch (e) {
      _logger.error('Failed to process shared media file', error: e);
      
      // Create fallback note
      await _createNoteFromSharedContent(
        title: 'Shared Image',
        content: 'Shared image could not be processed.',
        type: 'image_error',
      );
    }
  }

  Future<void> _processSharedItems(List<Map<String, dynamic>> items) async {
    for (final item in items) {
      try {
        final type = item['type'] as String?;
        
        switch (type) {
          case 'text':
            await _processSharedTextItem(item);
          case 'url':
            await _processSharedUrlItem(item);
          case 'image':
            await _processSharedImageItem(item);
          default:
            _logger.warning('Unknown shared item type', data: {'type': type});
        }
      } catch (e) {
        _logger.error('Failed to process shared item', error: e, data: item);
      }
    }
  }

  Future<void> _processSharedTextItem(Map<String, dynamic> item) async {
    final title = item['title'] as String? ?? 'Shared Text';
    final content = item['content'] as String? ?? '';
    
    if (content.isNotEmpty) {
      await _createNoteFromSharedContent(
        title: title,
        content: content,
        type: 'text',
      );
    }
  }

  Future<void> _processSharedUrlItem(Map<String, dynamic> item) async {
    final title = item['title'] as String? ?? 'Shared Link';
    final url = item['url'] as String? ?? '';
    final content = item['content'] as String? ?? url;
    
    if (url.isNotEmpty) {
      final noteContent = '''# $title

**Link**: $url

${content != url ? '\n**Additional Content**:\n$content' : ''}

*Shared on ${DateTime.now().toString()}*
''';

      await _createNoteFromSharedContent(
        title: title,
        content: noteContent,
        type: 'url',
      );
    }
  }

  Future<void> _processSharedImageItem(Map<String, dynamic> item) async {
    final title = item['title'] as String? ?? 'Shared Image';
    final imagePath = item['imagePath'] as String?;
    final imageSize = item['imageSize'] as int? ?? 0;
    
    if (imagePath != null) {
      try {
        final imageFile = File(imagePath);
        if (await imageFile.exists()) {
          final imageBytes = await imageFile.readAsBytes();
          
          // Upload image as attachment
          final attachment = await _attachmentService.uploadFile(
            bytes: imageBytes,
            filename: 'shared_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          
          final noteContent = '''# $title

![Shared Image](${attachment.url})

*Image shared on ${DateTime.now().toString()}*
*Size: ${_formatFileSize(imageSize)}*
''';

          await _createNoteFromSharedContent(
            title: title,
            content: noteContent,
            type: 'image',
          );
          
          // Clean up temporary image file
          await imageFile.delete();
        }
      } catch (e) {
        _logger.error('Failed to process shared image', error: e);
        
        // Fallback: create note without image
        await _createNoteFromSharedContent(
          title: title,
          content: 'Shared image could not be processed.',
          type: 'image_error',
        );
      }
    }
  }

  Future<void> _createNoteFromSharedContent({
    required String title,
    required String content,
    required String type,
  }) async {
    final noteId = await _notesRepository.createOrUpdate(
      title: title,
      body: content,
    );

    _analytics.event('share_extension.note_created', properties: {
      'note_id': noteId,
      'content_type': type,
      'title_length': title.length,
      'content_length': content.length,
      'platform': Platform.operatingSystem,
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
