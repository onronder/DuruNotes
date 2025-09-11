import 'dart:convert';
import 'dart:io';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/attachment_service.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Service for handling shared content from iOS Share Extension and Android intents
class ShareExtensionService {
  // static const String _appGroupId = 'group.com.fittechs.durunotes';  // Reserved for iOS app group sharing

  ShareExtensionService({
    required NotesRepository notesRepository,
    required AttachmentService attachmentService,
    required AppLogger logger,
    required AnalyticsService analytics,
  })  : _notesRepository = notesRepository,
        _attachmentService = attachmentService,
        _logger = logger,
        _analytics = analytics;
  final NotesRepository _notesRepository;
  final AttachmentService _attachmentService;
  final AppLogger _logger;
  final AnalyticsService _analytics;

  static const MethodChannel _channel = MethodChannel('com.fittechs.durunotes/share_extension');

  /// Initialize share extension handling
  Future<void> initialize() async {
    try {
      // Set up method channel for iOS
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Set up Android sharing intent listener
      _initializeAndroidSharing();
      
      // Process any pending shared items on app launch
      await _processSharedItemsOnLaunch();
      
      _logger.info('Share extension service initialized');
    } catch (e) {
      _logger.error('Failed to initialize share extension service', error: e);
    }
  }

  /// Handle method calls from iOS
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'getSharedItems':
        return _getSharedItemsFromAppGroup();
      case 'clearSharedItems':
        return _clearSharedItemsFromAppGroup();
      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: 'Method ${call.method} not implemented',
        );
    }
  }

  /// Initialize Android sharing intent handling
  void _initializeAndroidSharing() {
    // Listen for incoming media (files, images, text, etc.)
    ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        for (final file in files) {
          _handleSharedMedia([file]);
        }
      },
      onError: (dynamic err) {
        _logger.error('Error receiving shared media', error: err);
      },
    );

    // Handle any media that caused the app to start
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        for (final file in files) {
          _handleSharedMedia([file]);
        }
      }
    });
  }

  /// Process shared items on app launch (iOS)
  Future<void> _processSharedItemsOnLaunch() async {
    try {
      if (Platform.isIOS) {
        final sharedItems = await _getSharedItemsFromAppGroup();
        if (sharedItems.isNotEmpty) {
          await _processSharedItems(sharedItems);
          await _clearSharedItemsFromAppGroup();
        }
      }
    } catch (e) {
      _logger.error('Failed to process shared items on launch', error: e);
    }
  }

  /// Get shared items from iOS App Group container
  Future<List<Map<String, dynamic>>> _getSharedItemsFromAppGroup() async {
    try {
      final result = await _channel.invokeMethod('getSharedItems');
      if (result is String) {
        final dynamic decoded = jsonDecode(result);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      _logger.error('Failed to get shared items from app group', error: e);
      return [];
    }
  }

  /// Clear shared items from iOS App Group container
  Future<void> _clearSharedItemsFromAppGroup() async {
    try {
      await _channel.invokeMethod('clearSharedItems');
    } catch (e) {
      _logger.error('Failed to clear shared items from app group', error: e);
    }
  }

  /// Handle shared text content
  Future<void> _handleSharedText(String sharedText) async {
    try {
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

      _logger.info('Successfully processed shared text', data: {
        'title': title,
        'content_length': sharedText.length,
      });
    } catch (e) {
      _logger.error('Failed to handle shared text', error: e);
    }
  }

  /// Handle shared URL content
  Future<void> _handleSharedUrl(String sharedUrl) async {
    try {
      _analytics.event('share_extension.url_received', properties: {
        'url_length': sharedUrl.length,
        'platform': Platform.operatingSystem,
      });

      final uri = Uri.tryParse(sharedUrl);
      final title = uri?.host ?? 'Shared Link';
      
      final noteContent = '''# $title

**Link**: $sharedUrl

*Shared from ${_getSourceAppName()} on ${DateTime.now()}*
''';

      await _createNoteFromSharedContent(
        title: title,
        content: noteContent,
        type: 'url',
      );

      _logger.info('Successfully processed shared URL', data: {
        'title': title,
        'url': sharedUrl,
      });
    } catch (e) {
      _logger.error('Failed to handle shared URL', error: e);
    }
  }

  /// Handle shared media files
  Future<void> _handleSharedMedia(List<SharedMediaFile> sharedFiles) async {
    try {
      _analytics.event('share_extension.media_received', properties: {
        'file_count': sharedFiles.length,
        'platform': Platform.operatingSystem,
      });

      for (final mediaFile in sharedFiles) {
        // Handle different content types based on SharedMediaType
        switch (mediaFile.type) {
          case SharedMediaType.text:
            // For text content, the text is stored in the path field
            await _handleSharedText(mediaFile.path);
          case SharedMediaType.url:
            // For URL content, the URL is stored in the path field
            await _handleSharedUrl(mediaFile.path);
          case SharedMediaType.image:
          case SharedMediaType.video:
          case SharedMediaType.file:
            // For actual files, process as media file
            await _processSharedMediaFile(mediaFile);
        }
      }

      _logger.info('Successfully processed shared media', data: {
        'file_count': sharedFiles.length,
      });
    } catch (e) {
      _logger.error('Failed to handle shared media', error: e);
    }
  }

  /// Process shared items from iOS Share Extension
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

  /// Process shared text item from iOS
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

  /// Process shared URL item from iOS
  Future<void> _processSharedUrlItem(Map<String, dynamic> item) async {
    final title = item['title'] as String? ?? 'Shared Link';
    final url = item['url'] as String? ?? '';
    final content = item['content'] as String? ?? url;
    
    if (url.isNotEmpty) {
      final noteContent = '''# $title

**Link**: $url

${content != url ? '\n**Additional Content**:\n$content' : ''}

*Shared from ${_getSourceAppName()} on ${DateTime.now()}*
''';

      await _createNoteFromSharedContent(
        title: title,
        content: noteContent,
        type: 'url',
      );
    }
  }

  /// Process shared image item from iOS
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
          final attachment = await _attachmentService.uploadFromBytes(
            bytes: imageBytes,
            filename: 'shared_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          
          final url = attachment?.url ?? '';
          final noteContent = '''# $title

![Shared Image]($url)

*Image shared on ${DateTime.now()}*
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

  /// Process shared media file from Android
  Future<void> _processSharedMediaFile(SharedMediaFile mediaFile) async {
    try {
      final file = File(mediaFile.path);
      if (!await file.exists()) return;

      final fileName = mediaFile.path.split('/').last;
      final fileBytes = await file.readAsBytes();
      
      if (mediaFile.type == SharedMediaType.image) {
        // Handle shared image
        final attachment = await _attachmentService.uploadFromBytes(
          bytes: fileBytes,
          filename: fileName,
        );
        
        final url = attachment?.url ?? '';
        final noteContent = '''# Shared Image

![$fileName]($url)

*Shared from ${_getSourceAppName()} on ${DateTime.now()}*
''';

        await _createNoteFromSharedContent(
          title: 'Shared Image',
          content: noteContent,
          type: 'android_image',
        );
      } else {
        // Handle other file types
        final attachment = await _attachmentService.uploadFromBytes(
          bytes: fileBytes,
          filename: fileName,
        );
        
        final url = attachment?.url ?? '';
        final noteContent = '''# Shared File: $fileName

[Download $fileName]($url)

*File shared from ${_getSourceAppName()} on ${DateTime.now()}*
*Size: ${_formatFileSize(fileBytes.length)}*
''';

        await _createNoteFromSharedContent(
          title: 'Shared File: $fileName',
          content: noteContent,
          type: 'android_file',
        );
      }
    } catch (e) {
      _logger.error('Failed to process shared media file', error: e);
    }
  }

  /// Create a note from shared content
  Future<void> _createNoteFromSharedContent({
    required String title,
    required String content,
    required String type,
  }) async {
    try {
      // Add appropriate tags based on content type
      final tags = <String>[];
      String bodyWithTags = content;
      
      // Check if this is an attachment-type content
      if (type == 'image' || type == 'android_image' || 
          type == 'android_file' || type == 'image_error') {
        tags.add('#Attachment');
      }
      
      // Append tags to body if any
      if (tags.isNotEmpty) {
        bodyWithTags = '$content\n\n${tags.join(' ')}';
      }
      
      // Create metadata for the note
      final metadata = <String, dynamic>{
        'source': 'share_extension',
        'share_type': type,
        'platform': Platform.operatingSystem,
        if (tags.isNotEmpty) 'tags': tags.map((t) => t.substring(1)).toList(),
      };
      
      final noteId = await _notesRepository.createOrUpdate(
        title: title,
        body: bodyWithTags,
        metadataJson: metadata,
      );

      _analytics.event('share_extension.note_created', properties: {
        'note_id': noteId,
        'content_type': type,
        'title_length': title.length,
        'content_length': content.length,
        'platform': Platform.operatingSystem,
      });

      _logger.info('Created note from shared content', data: {
        'note_id': noteId,
        'title': title,
        'type': type,
      });
    } catch (e) {
      _logger.error('Failed to create note from shared content', error: e);
      rethrow;
    }
  }

  /// Generate a meaningful title from text content
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

  /// Get the source app name (placeholder for now)
  String _getSourceAppName() {
    // In a full implementation, you could detect the source app
    return 'external app';
  }

  /// Format file size for display
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Shared item data structure
class SharedItem {

  const SharedItem({
    required this.type,
    required this.title,
    required this.content,
    required this.timestamp, this.imagePath,
    this.url,
    this.fileSize,
  });

  factory SharedItem.fromJson(Map<String, dynamic> json) {
    return SharedItem(
      type: json['type'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      imagePath: json['imagePath'] as String?,
      url: json['url'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      fileSize: json['imageSize'] as int? ?? json['fileSize'] as int?,
    );
  }
  final String type;
  final String title;
  final String content;
  final String? imagePath;
  final String? url;
  final DateTime timestamp;
  final int? fileSize;

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'content': content,
      if (imagePath != null) 'imagePath': imagePath,
      if (url != null) 'url': url,
      'timestamp': timestamp.toIso8601String(),
      if (fileSize != null) 'fileSize': fileSize,
    };
  }
}
