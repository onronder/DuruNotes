import 'dart:typed_data';

/// Result of a reminder encryption operation
///
/// This class wraps the outcome of encryption attempts to enable:
/// - Explicit success/failure handling
/// - Error propagation to callers
/// - Retry queue management
/// - Metrics tracking
///
/// **Production Context:**
/// Encryption can fail for various reasons in offline scenarios:
/// - CryptoBox not initialized (user not authenticated)
/// - Master key not unlocked (biometric/PIN required)
/// - Memory pressure (large batch encryption)
/// - Cryptographic errors (corrupted key material)
///
/// Silent failures lead to data corruption where plaintext and encrypted
/// fields become inconsistent. This wrapper makes failures explicit.
class ReminderEncryptionResult {
  /// Whether encryption succeeded
  final bool success;

  /// Encrypted title (null if encryption failed)
  final Uint8List? titleEncrypted;

  /// Encrypted body (null if encryption failed)
  final Uint8List? bodyEncrypted;

  /// Encrypted location name (null if encryption failed or field was null)
  final Uint8List? locationNameEncrypted;

  /// Encryption version (1 for current XChaCha20-Poly1305, null if failed)
  final int? encryptionVersion;

  /// Error that caused encryption failure (null if succeeded)
  final Object? error;

  /// Stack trace for debugging (null if succeeded)
  final StackTrace? stackTrace;

  /// Reason for failure in human-readable form
  final String? failureReason;

  /// Whether this failure is retryable
  ///
  /// Retryable failures:
  /// - CryptoBox temporarily unavailable
  /// - Memory pressure (transient)
  /// - Network timeout during key fetching
  ///
  /// Non-retryable failures:
  /// - Corrupted key material
  /// - Invalid input data
  /// - Cryptographic errors
  final bool isRetryable;

  const ReminderEncryptionResult._({
    required this.success,
    this.titleEncrypted,
    this.bodyEncrypted,
    this.locationNameEncrypted,
    this.encryptionVersion,
    this.error,
    this.stackTrace,
    this.failureReason,
    required this.isRetryable,
  });

  /// Create a successful encryption result
  factory ReminderEncryptionResult.success({
    required Uint8List titleEncrypted,
    required Uint8List bodyEncrypted,
    Uint8List? locationNameEncrypted,
  }) {
    return ReminderEncryptionResult._(
      success: true,
      titleEncrypted: titleEncrypted,
      bodyEncrypted: bodyEncrypted,
      locationNameEncrypted: locationNameEncrypted,
      encryptionVersion: 1,
      isRetryable: false,
    );
  }

  /// Create a failed encryption result
  factory ReminderEncryptionResult.failure({
    required Object error,
    StackTrace? stackTrace,
    required String reason,
    required bool isRetryable,
  }) {
    return ReminderEncryptionResult._(
      success: false,
      failureReason: reason,
      error: error,
      stackTrace: stackTrace,
      isRetryable: isRetryable,
    );
  }

  /// Create a failure result for missing CryptoBox
  factory ReminderEncryptionResult.cryptoBoxUnavailable() {
    return ReminderEncryptionResult._(
      success: false,
      failureReason: 'CryptoBox not available - user may not be authenticated',
      isRetryable: true, // Retryable - user can authenticate later
    );
  }

  /// Create a failure result for master key not unlocked
  factory ReminderEncryptionResult.keyNotUnlocked() {
    return ReminderEncryptionResult._(
      success: false,
      failureReason: 'Master key not unlocked - biometric/PIN required',
      isRetryable: true, // Retryable - user can unlock later
    );
  }

  @override
  String toString() {
    if (success) {
      return 'ReminderEncryptionResult.success(version=$encryptionVersion)';
    }
    return 'ReminderEncryptionResult.failure(reason=$failureReason, retryable=$isRetryable)';
  }
}

/// Metadata about a failed encryption attempt for retry queue
class EncryptionRetryMetadata {
  /// Reminder ID that failed encryption
  final String reminderId;

  /// Note ID (needed for encryption context)
  final String noteId;

  /// User ID (needed for encryption context)
  final String userId;

  /// When the encryption first failed
  final DateTime firstFailureTime;

  /// How many retry attempts have been made
  final int retryCount;

  /// When the last retry was attempted
  final DateTime? lastRetryTime;

  /// Exponential backoff delay (milliseconds)
  ///
  /// Uses exponential backoff: 1s, 2s, 4s, 8s, 16s, ...
  /// Capped at 5 minutes
  int get nextRetryDelayMs {
    final baseDelay = 1000; // 1 second
    final maxDelay = 300000; // 5 minutes
    final delay = baseDelay * (1 << retryCount); // 2^retryCount
    return delay.clamp(baseDelay, maxDelay);
  }

  /// Whether this retry should be attempted now
  bool get shouldRetryNow {
    if (lastRetryTime == null) return true;
    final elapsed = DateTime.now().difference(lastRetryTime!);
    return elapsed.inMilliseconds >= nextRetryDelayMs;
  }

  const EncryptionRetryMetadata({
    required this.reminderId,
    required this.noteId,
    required this.userId,
    required this.firstFailureTime,
    required this.retryCount,
    this.lastRetryTime,
  });

  /// Create new metadata for first failure
  factory EncryptionRetryMetadata.firstFailure({
    required String reminderId,
    required String noteId,
    required String userId,
  }) {
    return EncryptionRetryMetadata(
      reminderId: reminderId,
      noteId: noteId,
      userId: userId,
      firstFailureTime: DateTime.now(),
      retryCount: 0,
    );
  }

  /// Create new metadata for retry attempt
  EncryptionRetryMetadata incrementRetry() {
    return EncryptionRetryMetadata(
      reminderId: reminderId,
      noteId: noteId,
      userId: userId,
      firstFailureTime: firstFailureTime,
      retryCount: retryCount + 1,
      lastRetryTime: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'EncryptionRetryMetadata(id=$reminderId, attempts=$retryCount, '
        'nextRetry=${nextRetryDelayMs}ms)';
  }
}
