import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duru_notes_app/models/note_block.dart';
import 'package:duru_notes_app/core/monitoring/app_logger.dart';

import 'package:duru_notes_app/services/analytics/analytics_sentry.dart';

/// Exception thrown when a file exceeds the maximum allowed size
class AttachmentSizeException implements Exception {
  final String message;
  final int fileSizeBytes;
  final int maxSizeBytes;

  const AttachmentSizeException(
    this.message, {
    required this.fileSizeBytes,
    required this.maxSizeBytes,
  });

  @override
  String toString() => 'AttachmentSizeException: $message';
}

/// A service responsible for handling file attachments. It provides a
/// convenience method to pick a file from the device, compute a
/// content-based hash, upload it to a Supabase Storage bucket and return
/// an [AttachmentBlockData] with the user friendly filename and the
/// public URL. The service will avoid re-uploading duplicate files by
/// naming objects based on the SHA‑256 hash of their content. Encryption
/// of attachments is beyond the scope of this service and can be added
/// separately if desired.
class AttachmentService {
  AttachmentService(this.client, {this.bucket = 'attachments'});

  /// The Supabase client used to access the Storage API.
  final SupabaseClient client;
  
  // Local instances to avoid import conflicts
  final _logger = LoggerFactory.instance;
  final _analytics = AnalyticsFactory.instance;

  /// The name of the Supabase Storage bucket where attachments are stored.
  final String bucket;

  /// Maximum file size allowed for attachments (50MB)
  static const int maxFileSize = 50 * 1024 * 1024; // 50MB in bytes

  /// Image file extensions that support compression
  static const Set<String> compressibleImageTypes = {
    '.jpg', '.jpeg', '.png', '.webp'
  };

  /// Opens a file picker so the user can choose a file, then uploads the
  /// selected file to Supabase Storage if it does not already exist. The
  /// returned [AttachmentBlockData] contains the original filename and
  /// the public URL of the uploaded object. If the user cancels the
  /// picker or an error occurs, this method returns `null`.
  Future<AttachmentBlockData?> pickAndUpload() async {
    // Allow the user to pick a single file. Use withData to get the bytes
    // directly so that we can compute a hash without reading from disk.
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.first;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      return null;
    }

    // Validate file size
    if (bytes.length > maxFileSize) {
      final fileSizeMB = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      final maxSizeMB = (maxFileSize / (1024 * 1024)).toStringAsFixed(0);
      
      _logger.warn('File size exceeds limit', data: {
        'file_name': file.name,
        'file_size_bytes': bytes.length,
        'file_size_mb': fileSizeMB,
        'max_size_mb': maxSizeMB,
      });

      _analytics.event('attachment.size_limit_exceeded', properties: {
        'file_size_mb': double.parse(fileSizeMB),
        'max_size_mb': double.parse(maxSizeMB),
        'file_extension': p.extension(file.name).toLowerCase(),
      });

      throw AttachmentSizeException(
        'File size ($fileSizeMB MB) exceeds the maximum allowed size of $maxSizeMB MB.',
        fileSizeBytes: bytes.length,
        maxSizeBytes: maxFileSize,
      );
    }

    _logger.breadcrumb('Attachment file selected', data: {
      'file_name': file.name,
      'file_size_bytes': bytes.length,
      'file_size_mb': (bytes.length / (1024 * 1024)).toStringAsFixed(2),
    });
    // Compute a SHA‑256 digest of the file contents to use as a unique key.
    final digest = crypto.sha256.convert(bytes);
    final hash = digest.toString();
    // Preserve the original file extension so that the storage object
    // retains a recognizable type. If no extension, leave it empty.
    final ext = p.extension(file.name);
    final objectPath = ext.isNotEmpty ? '$hash$ext' : hash;
    // Attempt to upload the file. Use upsert: false to avoid overwriting
    // existing files with the same hash. If the file already exists, the
    // storage API will throw an error which we catch and ignore.
    try {
      await client.storage
          .from(bucket)
          .uploadBinary(objectPath, bytes, fileOptions: const FileOptions(upsert: false));
    } catch (e) {
      // Ignore "already exists" errors. Other errors should be rethrown.
      final msg = e.toString();
      if (!msg.contains('already exists')) {
        rethrow;
      }
    }
    // Generate a public URL for the uploaded file. If your bucket is not
    // public, you may need to create a signed URL instead.
    final urlResponse = client.storage.from(bucket).getPublicUrl(objectPath);
    final publicUrl = urlResponse;
    return AttachmentBlockData(filename: file.name, url: publicUrl);
  }

  /// Uploads a file from bytes (for shared content) to Supabase Storage.
  /// This method is useful when handling shared files from other apps.
  /// Returns the AttachmentBlockData with filename and URL if successful,
  /// or null if upload fails.
  Future<AttachmentBlockData?> uploadFromBytes({
    required String filename,
    required Uint8List bytes,
  }) async {
    try {
      // Compute a SHA‑256 digest of the file contents to use as a unique key.
      final digest = crypto.sha256.convert(bytes);
      final hash = digest.toString();
      
      // Preserve the original file extension so that the storage object
      // retains a recognizable type. If no extension, leave it empty.
      final ext = p.extension(filename);
      final objectPath = ext.isNotEmpty ? '$hash$ext' : hash;
      
      // Attempt to upload the file. Use upsert: false to avoid overwriting
      // existing files with the same hash. If the file already exists, the
      // storage API will throw an error which we catch and ignore.
      try {
        await client.storage
            .from(bucket)
            .uploadBinary(objectPath, bytes, fileOptions: const FileOptions(upsert: false));
      } catch (e) {
        // Ignore "already exists" errors. Other errors should be rethrown.
        final msg = e.toString();
        if (!msg.contains('already exists')) {
          rethrow;
        }
      }
      
      // Generate a public URL for the uploaded file. If your bucket is not
      // public, you may need to create a signed URL instead.
      final urlResponse = client.storage.from(bucket).getPublicUrl(objectPath);
      final publicUrl = urlResponse;
      
      return AttachmentBlockData(filename: filename, url: publicUrl);
    } on Exception {
      // Return null on any error
      return null;
    }
  }

  /// Validate file size before processing
  static bool isFileSizeValid(int sizeBytes) {
    return sizeBytes <= maxFileSize;
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

  /// Check if file type supports compression
  static bool supportsCompression(String filename) {
    final ext = p.extension(filename).toLowerCase();
    return compressibleImageTypes.contains(ext);
  }

  /// Get maximum allowed file size in MB
  static double get maxFileSizeMB => maxFileSize / (1024 * 1024);
}

/// Provider for AttachmentService
final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  return AttachmentService(Supabase.instance.client);
});