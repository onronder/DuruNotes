import 'dart:typed_data';
import 'package:duru_notes/core/crypto/crypto_box.dart';

/// Helper for verifying encryption roundtrips
///
/// Shared between sync_encryption_helper and base_reminder_service
/// to avoid code duplication in CRITICAL #7 verification logic.
class EncryptionVerificationHelper {
  /// Verify that encrypted data decrypts back to the original value
  ///
  /// Returns a [VerificationResult] indicating success or failure with details.
  ///
  /// This is the core verification logic extracted from:
  /// - sync_encryption_helper.dart (lines 127-230)
  /// - base_reminder_service.dart (lines 367-427)
  static Future<VerificationResult> verifyField({
    required CryptoBox cryptoBox,
    required String userId,
    required String noteId,
    required String originalValue,
    required Uint8List encryptedValue,
    required String fieldName,
  }) async {
    try {
      final decrypted = await cryptoBox.decryptStringForNote(
        userId: userId,
        noteId: noteId,
        data: encryptedValue,
      );

      if (decrypted == originalValue) {
        return VerificationResult.success();
      } else {
        return VerificationResult.mismatch(
          fieldName: fieldName,
          originalLength: originalValue.length,
          decryptedLength: decrypted.length,
        );
      }
    } catch (error, stackTrace) {
      return VerificationResult.error(
        fieldName: fieldName,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Result of encryption verification
class VerificationResult {
  final bool success;
  final String? fieldName;
  final int? originalLength;
  final int? decryptedLength;
  final Object? error;
  final StackTrace? stackTrace;

  VerificationResult._({
    required this.success,
    this.fieldName,
    this.originalLength,
    this.decryptedLength,
    this.error,
    this.stackTrace,
  });

  factory VerificationResult.success() {
    return VerificationResult._(success: true);
  }

  factory VerificationResult.mismatch({
    required String fieldName,
    required int originalLength,
    required int decryptedLength,
  }) {
    return VerificationResult._(
      success: false,
      fieldName: fieldName,
      originalLength: originalLength,
      decryptedLength: decryptedLength,
    );
  }

  factory VerificationResult.error({
    required String fieldName,
    required Object error,
    StackTrace? stackTrace,
  }) {
    return VerificationResult._(
      success: false,
      fieldName: fieldName,
      error: error,
      stackTrace: stackTrace,
    );
  }

  bool get isMismatch => !success && error == null;
  bool get isError => !success && error != null;
}
