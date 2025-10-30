/// Custom exceptions for encryption-related errors
///
/// These exceptions provide clear error messages and recovery suggestions
/// for encryption failures throughout the application.
library;

/// Base class for all encryption-related exceptions
abstract class EncryptionException implements Exception {
  const EncryptionException(this.message, {this.code, this.recoverySuggestion});

  final String message;
  final String? code;
  final String? recoverySuggestion;

  @override
  String toString() {
    final buffer = StringBuffer('EncryptionException: $message');
    if (code != null) buffer.write(' [Code: $code]');
    if (recoverySuggestion != null) {
      buffer.write('\nRecovery: $recoverySuggestion');
    }
    return buffer.toString();
  }
}

/// Thrown when encryption keys are unavailable or cannot be accessed
///
/// This typically occurs when:
/// - Secure storage (Keystore/Keychain) is not available
/// - Device security is not configured
/// - Secure storage is corrupted or inaccessible
///
/// **Security Note**: This replaces the insecure hardcoded fallback key.
/// The app will fail safely rather than use a predictable key.
class EncryptionKeyUnavailableException extends EncryptionException {
  const EncryptionKeyUnavailableException({
    String? message,
    String? code,
    String? recoverySuggestion,
    this.requiresDeviceSecurity = true,
  }) : super(
         message ?? 'Encryption keys are unavailable',
         code: code ?? 'ENCRYPTION_KEY_UNAVAILABLE',
         recoverySuggestion:
             recoverySuggestion ??
             'Please ensure your device has a screen lock (PIN, pattern, or biometric) '
                 'enabled. This is required for secure data storage.',
       );

  /// Whether this error requires device security to be enabled
  final bool requiresDeviceSecurity;

  /// Create exception for missing device security
  factory EncryptionKeyUnavailableException.deviceSecurityRequired() {
    return const EncryptionKeyUnavailableException(
      message: 'Device security is required for encryption',
      code: 'DEVICE_SECURITY_REQUIRED',
      recoverySuggestion:
          '1. Go to device Settings\n'
          '2. Enable screen lock (PIN, pattern, fingerprint, or face unlock)\n'
          '3. Restart the app\n\n'
          'Your data will remain secure and will be accessible once device security is enabled.',
      requiresDeviceSecurity: true,
    );
  }

  /// Create exception for corrupted secure storage
  factory EncryptionKeyUnavailableException.secureStorageCorrupted() {
    return const EncryptionKeyUnavailableException(
      message: 'Secure storage is corrupted or inaccessible',
      code: 'SECURE_STORAGE_CORRUPTED',
      recoverySuggestion:
          'The app\'s secure storage may be corrupted. You may need to:\n'
          '1. Clear app data (Settings > Apps > Duru Notes > Storage > Clear Data)\n'
          '2. Reinstall the app\n\n'
          'Note: This will reset the app. Please ensure your data is synced to the cloud first.',
      requiresDeviceSecurity: false,
    );
  }

  /// Create exception for secure storage access failure
  factory EncryptionKeyUnavailableException.secureStorageAccessFailed({
    required Object error,
  }) {
    return EncryptionKeyUnavailableException(
      message: 'Failed to access secure storage: ${error.toString()}',
      code: 'SECURE_STORAGE_ACCESS_FAILED',
      recoverySuggestion:
          'Temporary secure storage access failure. Please try:\n'
          '1. Restart the app\n'
          '2. Restart your device\n'
          '3. Check that device storage is not full\n\n'
          'If the issue persists, contact support.',
      requiresDeviceSecurity: true,
    );
  }
}

/// Thrown when database encryption operations fail
class DatabaseEncryptionException extends EncryptionException {
  const DatabaseEncryptionException({
    String? message,
    String? code,
    String? recoverySuggestion,
    this.operation,
    this.underlyingError,
  }) : super(
         message ?? 'Database encryption operation failed',
         code: code ?? 'DATABASE_ENCRYPTION_FAILED',
         recoverySuggestion:
             recoverySuggestion ??
             'A database encryption error occurred. '
                 'Your data is safe, but the operation could not be completed.',
       );

  /// The operation that failed (e.g., 'encrypt', 'decrypt', 'key_rotation')
  final String? operation;

  /// The underlying error that caused the failure
  final Object? underlyingError;

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    if (operation != null) buffer.write('\nOperation: $operation');
    if (underlyingError != null) {
      buffer.write('\nUnderlying error: $underlyingError');
    }
    return buffer.toString();
  }

  /// Create exception for key generation failure
  factory DatabaseEncryptionException.keyGenerationFailed({
    required Object error,
  }) {
    return DatabaseEncryptionException(
      message: 'Failed to generate database encryption key',
      code: 'KEY_GENERATION_FAILED',
      operation: 'key_generation',
      underlyingError: error,
      recoverySuggestion:
          'Could not generate a secure encryption key. This may indicate:\n'
          '1. Insufficient system entropy (rare)\n'
          '2. System cryptography issues\n\n'
          'Please restart your device and try again.',
    );
  }

  /// Create exception for key rotation failure
  factory DatabaseEncryptionException.keyRotationFailed({
    required Object error,
  }) {
    return DatabaseEncryptionException(
      message: 'Failed to rotate database encryption key',
      code: 'KEY_ROTATION_FAILED',
      operation: 'key_rotation',
      underlyingError: error,
      recoverySuggestion:
          'Key rotation failed. Your data remains encrypted with the existing key.\n'
          'You can continue using the app normally.',
    );
  }
}

/// Thrown when note data encryption/decryption fails
class NoteEncryptionException extends EncryptionException {
  const NoteEncryptionException({
    String? message,
    String? code,
    String? recoverySuggestion,
    this.noteId,
    this.operation,
  }) : super(
         message ?? 'Note encryption operation failed',
         code: code ?? 'NOTE_ENCRYPTION_FAILED',
         recoverySuggestion: recoverySuggestion,
       );

  /// The ID of the note that failed to encrypt/decrypt
  final String? noteId;

  /// The operation that failed ('encrypt' or 'decrypt')
  final String? operation;

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    if (noteId != null) buffer.write('\nNote ID: $noteId');
    if (operation != null) buffer.write('\nOperation: $operation');
    return buffer.toString();
  }
}

/// Thrown when encryption key derivation fails
class KeyDerivationException extends EncryptionException {
  const KeyDerivationException({
    String? message,
    String? code,
    String? recoverySuggestion,
    this.algorithm,
  }) : super(
         message ?? 'Key derivation failed',
         code: code ?? 'KEY_DERIVATION_FAILED',
         recoverySuggestion:
             recoverySuggestion ??
             'Failed to derive encryption key. This is a system-level error.',
       );

  /// The key derivation algorithm that failed (e.g., 'PBKDF2', 'HKDF')
  final String? algorithm;

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    if (algorithm != null) buffer.write('\nAlgorithm: $algorithm');
    return buffer.toString();
  }
}
