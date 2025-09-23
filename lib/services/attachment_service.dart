import 'dart:typed_data';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/models/note_block.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Attachment size limits
class AttachmentLimits {
  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50MB
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10MB
  static const int maxVideoSizeBytes = 100 * 1024 * 1024; // 100MB

  static const List<String> supportedImageTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
  ];

  static const List<String> supportedVideoTypes = [
    'video/mp4',
    'video/mov',
    'video/avi',
  ];

  static const List<String> supportedDocumentTypes = [
    'application/pdf',
    'text/plain',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  ];
}

/// Exception thrown when attachment operations fail
class AttachmentException implements Exception {
  const AttachmentException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => 'AttachmentException: $message';
}

/// Exception for file size violations
class AttachmentSizeException extends AttachmentException {
  const AttachmentSizeException(super.message, this.actualSize, this.maxSize)
      : super(code: 'FILE_TOO_LARGE');
  final int actualSize;
  final int maxSize;
}

/// Attachment service for handling file uploads and downloads
class AttachmentService {
  AttachmentService(this._ref, {
    SupabaseClient? client,
  })  : _client = client ?? Supabase.instance.client;

  final Ref _ref;
  final SupabaseClient _client;
  AppLogger get _logger => _ref.read(loggerProvider);
  AnalyticsService get _analytics => _ref.read(analyticsProvider);

  /// Pick and upload a file from device
  Future<AttachmentBlockData?> pickAndUpload() async {
    try {
      _analytics.startTiming('attachment_pick_upload');

      final result = await FilePicker.platform.pickFiles(withData: true);

      if (result == null || result.files.isEmpty) {
        _analytics.endTiming(
          'attachment_pick_upload',
          properties: {'success': false, 'reason': 'cancelled'},
        );
        return null;
      }

      final file = result.files.first;

      if (file.bytes == null) {
        throw const AttachmentException('Failed to read file data');
      }

      return await uploadFromBytes(bytes: file.bytes!, filename: file.name);
    } catch (e) {
      _logger.error('Failed to pick and upload file', error: e);
      _analytics.endTiming(
        'attachment_pick_upload',
        properties: {'success': false, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Upload file from bytes
  Future<AttachmentBlockData?> uploadFromBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      _validateFile(bytes, filename);

      _analytics.startTiming('attachment_upload');

      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw const AttachmentException('User not authenticated');
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFilename = '${timestamp}_$filename';
      final storagePath = '$userId/attachments/$uniqueFilename';

      // Upload to Supabase Storage
      await _client.storage
          .from('attachments')
          .uploadBinary(storagePath, bytes);

      // Get public URL
      final url = _client.storage.from('attachments').getPublicUrl(storagePath);

      final mimeType = _getMimeType(filename);

      final attachment = AttachmentBlockData(
        fileName: filename,
        fileSize: bytes.length,
        mimeType: mimeType,
        url: url,
      );

      _analytics.endTiming(
        'attachment_upload',
        properties: {
          'success': true,
          'file_size': bytes.length,
          'mime_type': mimeType,
        },
      );

      _analytics.featureUsed(
        'attachment_upload',
        properties: {
          'file_type': mimeType.split('/').first,
          'file_size_mb': (bytes.length / (1024 * 1024)).round(),
        },
      );

      _logger.info(
        'File uploaded successfully',
        data: {
          'filename': filename,
          'size': bytes.length,
          'mime_type': mimeType,
        },
      );

      return attachment;
    } catch (e) {
      _logger.error(
        'Failed to upload file',
        error: e,
        data: {'filename': filename, 'size': bytes.length},
      );

      _analytics.endTiming(
        'attachment_upload',
        properties: {'success': false, 'error': e.toString()},
      );

      _analytics.trackError(
        'Attachment upload failed',
        properties: {'filename': filename, 'size': bytes.length},
      );

      rethrow;
    }
  }

  /// Download attachment from URL
  Future<Uint8List?> download(String url) async {
    try {
      _analytics.startTiming('attachment_download');

      // For Supabase storage URLs, we can use the storage client
      if (url.contains('supabase') && url.contains('storage')) {
        final uri = Uri.parse(url);
        final pathSegments = uri.pathSegments;

        if (pathSegments.length >= 3) {
          final bucket = pathSegments[2];
          final path = pathSegments.skip(3).join('/');

          final bytes = await _client.storage.from(bucket).download(path);

          _analytics.endTiming(
            'attachment_download',
            properties: {'success': true, 'size': bytes.length},
          );

          return bytes;
        }
      }

      // Fallback to HTTP client
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;

        _analytics.endTiming(
          'attachment_download',
          properties: {'success': true, 'size': bytes.length},
        );

        return bytes;
      } else {
        throw AttachmentException(
          'Download failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.error(
        'Failed to download attachment',
        error: e,
        data: {'url': url},
      );

      _analytics.endTiming(
        'attachment_download',
        properties: {'success': false, 'error': e.toString()},
      );

      return null;
    }
  }

  /// Delete attachment from storage
  Future<bool> delete(String url) async {
    try {
      if (url.contains('supabase') && url.contains('storage')) {
        final uri = Uri.parse(url);
        final pathSegments = uri.pathSegments;

        if (pathSegments.length >= 3) {
          final bucket = pathSegments[2];
          final path = pathSegments.skip(3).join('/');

          await _client.storage.from(bucket).remove([path]);

          _analytics.featureUsed('attachment_delete');
          _logger.info('Attachment deleted', data: {'url': url});
          return true;
        }
      }

      return false;
    } catch (e) {
      _logger.error(
        'Failed to delete attachment',
        error: e,
        data: {'url': url},
      );
      return false;
    }
  }

  /// Validate file before upload
  void _validateFile(Uint8List bytes, String filename) {
    // Check file size
    if (bytes.length > AttachmentLimits.maxFileSizeBytes) {
      throw AttachmentSizeException(
        'File size exceeds limit',
        bytes.length,
        AttachmentLimits.maxFileSizeBytes,
      );
    }

    final mimeType = _getMimeType(filename);

    // Check specific type limits
    if (AttachmentLimits.supportedImageTypes.contains(mimeType) &&
        bytes.length > AttachmentLimits.maxImageSizeBytes) {
      throw AttachmentSizeException(
        'Image size exceeds limit',
        bytes.length,
        AttachmentLimits.maxImageSizeBytes,
      );
    }

    if (AttachmentLimits.supportedVideoTypes.contains(mimeType) &&
        bytes.length > AttachmentLimits.maxVideoSizeBytes) {
      throw AttachmentSizeException(
        'Video size exceeds limit',
        bytes.length,
        AttachmentLimits.maxVideoSizeBytes,
      );
    }
  }

  /// Get MIME type from filename
  String _getMimeType(String filename) {
    final extension = filename.split('.').last.toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/mov';
      case 'avi':
        return 'video/avi';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  /// Check if file type is supported
  bool isSupported(String mimeType) {
    return AttachmentLimits.supportedImageTypes.contains(mimeType) ||
        AttachmentLimits.supportedVideoTypes.contains(mimeType) ||
        AttachmentLimits.supportedDocumentTypes.contains(mimeType);
  }

  /// Get human-readable file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}

// Provider for attachment service is defined in providers.dart
