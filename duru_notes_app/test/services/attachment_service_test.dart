
import 'package:flutter_test/flutter_test.dart';
import 'package:duru_notes_app/services/attachment_service.dart';

void main() {
  group('AttachmentService', () {
    group('File Size Validation', () {
      test('isFileSizeValid returns true for files under limit', () {
        expect(AttachmentService.isFileSizeValid(1024), isTrue); // 1KB
        expect(AttachmentService.isFileSizeValid(1024 * 1024), isTrue); // 1MB
        expect(AttachmentService.isFileSizeValid(AttachmentService.maxFileSize - 1), isTrue);
      });

      test('isFileSizeValid returns false for files over limit', () {
        expect(AttachmentService.isFileSizeValid(AttachmentService.maxFileSize + 1), isFalse);
        expect(AttachmentService.isFileSizeValid(100 * 1024 * 1024), isFalse); // 100MB
      });

      test('maxFileSize is 50MB', () {
        expect(AttachmentService.maxFileSize, equals(50 * 1024 * 1024));
        expect(AttachmentService.maxFileSizeMB, equals(50.0));
      });
    });

    group('File Size Formatting', () {
      test('formatFileSize formats bytes correctly', () {
        expect(AttachmentService.formatFileSize(512), equals('512 B'));
        expect(AttachmentService.formatFileSize(1024), equals('1.0 KB'));
        expect(AttachmentService.formatFileSize(1536), equals('1.5 KB'));
        expect(AttachmentService.formatFileSize(1024 * 1024), equals('1.0 MB'));
        expect(AttachmentService.formatFileSize((2.5 * 1024 * 1024).round()), equals('2.5 MB'));
        expect(AttachmentService.formatFileSize(1024 * 1024 * 1024), equals('1.0 GB'));
      });
    });

    group('Compression Support', () {
      test('supportsCompression returns true for image formats', () {
        expect(AttachmentService.supportsCompression('photo.jpg'), isTrue);
        expect(AttachmentService.supportsCompression('IMAGE.JPEG'), isTrue);
        expect(AttachmentService.supportsCompression('screenshot.png'), isTrue);
        expect(AttachmentService.supportsCompression('avatar.webp'), isTrue);
      });

      test('supportsCompression returns false for non-image formats', () {
        expect(AttachmentService.supportsCompression('document.pdf'), isFalse);
        expect(AttachmentService.supportsCompression('data.json'), isFalse);
        expect(AttachmentService.supportsCompression('video.mp4'), isFalse);
        expect(AttachmentService.supportsCompression('audio.mp3'), isFalse);
        expect(AttachmentService.supportsCompression('archive.zip'), isFalse);
      });
    });

    group('Constants', () {
      test('compressibleImageTypes contains expected formats', () {
        expect(AttachmentService.compressibleImageTypes, contains('.jpg'));
        expect(AttachmentService.compressibleImageTypes, contains('.jpeg'));
        expect(AttachmentService.compressibleImageTypes, contains('.png'));
        expect(AttachmentService.compressibleImageTypes, contains('.webp'));
        expect(AttachmentService.compressibleImageTypes.length, equals(4));
      });
    });
  });

  group('AttachmentSizeException', () {
    test('creates exception with correct message and properties', () {
      const fileSizeBytes = 60 * 1024 * 1024; // 60MB
      const maxSizeBytes = 50 * 1024 * 1024; // 50MB
      const message = 'File too large';

      final exception = AttachmentSizeException(
        message,
        fileSizeBytes: fileSizeBytes,
        maxSizeBytes: maxSizeBytes,
      );

      expect(exception.message, equals(message));
      expect(exception.fileSizeBytes, equals(fileSizeBytes));
      expect(exception.maxSizeBytes, equals(maxSizeBytes));
      expect(exception.toString(), contains(message));
    });
  });

  group('Integration Scenarios', () {
    test('typical file size validation workflow', () {
      // Simulate different file sizes
      const smallFileSize = 5 * 1024 * 1024; // 5MB
      const largeFileSize = 60 * 1024 * 1024; // 60MB

      // Small file should pass
      expect(AttachmentService.isFileSizeValid(smallFileSize), isTrue);
      expect(
        AttachmentService.formatFileSize(smallFileSize),
        equals('5.0 MB'),
      );

      // Large file should fail
      expect(AttachmentService.isFileSizeValid(largeFileSize), isFalse);
      expect(
        AttachmentService.formatFileSize(largeFileSize),
        equals('60.0 MB'),
      );
    });

    test('file type and compression workflow', () {
      const jpegFile = 'vacation-photo.jpg';
      const pdfFile = 'document.pdf';

      // JPEG should support compression
      expect(AttachmentService.supportsCompression(jpegFile), isTrue);

      // PDF should not support compression
      expect(AttachmentService.supportsCompression(pdfFile), isFalse);
    });
  });
}
