import 'dart:typed_data';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/reminders/encryption_result.dart';
import 'package:duru_notes/services/reminders/encryption_retry_queue.dart';
import 'package:duru_notes/services/reminders/encryption_verification_helper.dart';

/// Callback type for retrieving reminders during retry processing
typedef ReminderRetriever = Future<NoteReminder?> Function(String reminderId);

/// Helper for encrypting reminders during sync with explicit error handling
///
/// **Purpose:**
/// Provides encryption with explicit success/failure results, retry queue
/// management, and validation before upload to prevent data corruption.
///
/// **Key Differences from base_reminder_service.dart:**
/// - Returns explicit ReminderEncryptionResult instead of silently failing
/// - Integrates with retry queue for failed encryptions
/// - Validates encryption consistency before allowing upload
/// - Designed specifically for sync operations (strict requirements)
///
/// **Production Usage:**
/// ```dart
/// final helper = SyncEncryptionHelper(cryptoBox);
/// final result = await helper.encryptForSync(reminder, userId);
///
/// if (!result.success) {
///   if (result.isRetryable) {
///     // Queue for retry
///     retryQueue.enqueue(...);
///   }
///   // Don't upload - would create inconsistent state
///   return;
/// }
///
/// // Safe to upload - fully encrypted
/// await uploadToServer(result);
/// ```
class SyncEncryptionHelper {
  final CryptoBox? _cryptoBox;
  final _logger = LoggerFactory.instance;
  final EncryptionRetryQueue _retryQueue;

  SyncEncryptionHelper(this._cryptoBox, [ReminderServiceConfig? config])
      : _retryQueue = EncryptionRetryQueue(config ?? ReminderServiceConfig.defaultConfig());

  /// Encrypt a reminder for sync upload with explicit error handling
  ///
  /// Returns:
  /// - Success: Fully encrypted data ready for upload
  /// - Failure: Error details and retry recommendation
  ///
  /// **IMPORTANT:** Only upload if result.success == true
  /// Uploading on failure creates inconsistent database state.
  Future<ReminderEncryptionResult> encryptForSync({
    required NoteReminder reminder,
    required String userId,
  }) async {
    // Check if CryptoBox available
    if (_cryptoBox == null) {
      _logger.warning(
        '[SyncEncryption] CryptoBox not available',
        data: {'reminderId': reminder.id},
      );
      return ReminderEncryptionResult.cryptoBoxUnavailable();
    }

    // Check if reminder already encrypted
    if (_isReminderEncrypted(reminder)) {
      // Already encrypted - validate consistency
      final isConsistent = await _validateEncryptionConsistency(
        reminder: reminder,
        userId: userId,
      );

      if (isConsistent) {
        _logger.debug(
          '[SyncEncryption] Using existing encryption',
          data: {'reminderId': reminder.id},
        );
        return ReminderEncryptionResult.success(
          titleEncrypted: reminder.titleEncrypted!,
          bodyEncrypted: reminder.bodyEncrypted!,
          locationNameEncrypted: reminder.locationNameEncrypted,
        );
      } else {
        // Inconsistent - need to re-encrypt
        _logger.warning(
          '[SyncEncryption] Existing encryption inconsistent, re-encrypting',
          data: {'reminderId': reminder.id},
        );
      }
    }

    // Perform encryption
    try {
      final titleEnc = await _cryptoBox!.encryptStringForNote(
        userId: userId,
        noteId: reminder.noteId,
        text: reminder.title,
      );

      final bodyEnc = await _cryptoBox!.encryptStringForNote(
        userId: userId,
        noteId: reminder.noteId,
        text: reminder.body,
      );

      Uint8List? locationNameEnc;
      if (reminder.locationName != null && reminder.locationName!.isNotEmpty) {
        locationNameEnc = await _cryptoBox!.encryptStringForNote(
          userId: userId,
          noteId: reminder.noteId,
          text: reminder.locationName!,
        );
      }

      // CRITICAL #7: Verify encryption roundtrip
      // Decrypt the encrypted data and compare with original to ensure integrity
      _logger.debug(
        '[SyncEncryption] Verifying encryption roundtrip',
        data: {'reminderId': reminder.id},
      );

      final titleVerification = await EncryptionVerificationHelper.verifyField(
        cryptoBox: _cryptoBox!,
        userId: userId,
        noteId: reminder.noteId,
        originalValue: reminder.title,
        encryptedValue: titleEnc,
        fieldName: 'title',
      );

      if (!titleVerification.success) {
        return _handleVerificationFailure(
          titleVerification,
          reminder,
          userId,
          'Title',
        );
      }

      final bodyVerification = await EncryptionVerificationHelper.verifyField(
        cryptoBox: _cryptoBox!,
        userId: userId,
        noteId: reminder.noteId,
        originalValue: reminder.body,
        encryptedValue: bodyEnc,
        fieldName: 'body',
      );

      if (!bodyVerification.success) {
        return _handleVerificationFailure(
          bodyVerification,
          reminder,
          userId,
          'Body',
        );
      }

      // Verify location name if present
      if (locationNameEnc != null && reminder.locationName != null) {
        final locationVerification = await EncryptionVerificationHelper.verifyField(
          cryptoBox: _cryptoBox!,
          userId: userId,
          noteId: reminder.noteId,
          originalValue: reminder.locationName!,
          encryptedValue: locationNameEnc,
          fieldName: 'locationName',
        );

        if (!locationVerification.success) {
          return _handleVerificationFailure(
            locationVerification,
            reminder,
            userId,
            'Location name',
          );
        }
      }

      _logger.info(
        '[SyncEncryption] Encryption and verification successful',
        data: {'reminderId': reminder.id},
      );

      // Remove from retry queue if present
      if (_retryQueue.isQueued(reminder.id)) {
        _retryQueue.dequeue(reminder.id);
      }

      return ReminderEncryptionResult.success(
        titleEncrypted: titleEnc,
        bodyEncrypted: bodyEnc,
        locationNameEncrypted: locationNameEnc,
      );
    } catch (error, stack) {
      _logger.error(
        '[SyncEncryption] Encryption failed',
        error: error,
        stackTrace: stack,
        data: {'reminderId': reminder.id},
      );

      // Determine if retryable
      final isRetryable = _isRetryableError(error);

      // Add to retry queue if retryable
      if (isRetryable) {
        _retryQueue.enqueue(
          reminderId: reminder.id,
          noteId: reminder.noteId,
          userId: userId,
        );
      }

      return ReminderEncryptionResult.failure(
        error: error,
        stackTrace: stack,
        reason: _getErrorReason(error),
        isRetryable: isRetryable,
      );
    }
  }

  /// Validate that encrypted and plaintext fields are consistent
  ///
  /// Checks:
  /// - Encrypted fields exist
  /// - Decrypted values match plaintext values
  /// - encryption_version is correct
  ///
  /// Returns false if inconsistent, requiring re-encryption
  Future<bool> _validateEncryptionConsistency({
    required NoteReminder reminder,
    required String userId,
  }) async {
    // Check encryption version
    if (reminder.encryptionVersion != 1) {
      return false;
    }

    // Check encrypted fields exist
    if (reminder.titleEncrypted == null || reminder.bodyEncrypted == null) {
      return false;
    }

    // Validate by decrypting and comparing
    try {
      final decryptedTitle = await _cryptoBox!.decryptStringForNote(
        userId: userId,
        noteId: reminder.noteId,
        data: reminder.titleEncrypted!,
      );

      final decryptedBody = await _cryptoBox!.decryptStringForNote(
        userId: userId,
        noteId: reminder.noteId,
        data: reminder.bodyEncrypted!,
      );

      // Compare decrypted with plaintext
      if (decryptedTitle != reminder.title) {
        _logger.warning(
          '[SyncEncryption] Title mismatch: encrypted != plaintext',
          data: {'reminderId': reminder.id},
        );
        return false;
      }

      if (decryptedBody != reminder.body) {
        _logger.warning(
          '[SyncEncryption] Body mismatch: encrypted != plaintext',
          data: {'reminderId': reminder.id},
        );
        return false;
      }

      // Validate location if present
      if (reminder.locationNameEncrypted != null) {
        final decryptedLocation = await _cryptoBox!.decryptStringForNote(
          userId: userId,
          noteId: reminder.noteId,
          data: reminder.locationNameEncrypted!,
        );

        if (decryptedLocation != reminder.locationName) {
          _logger.warning(
            '[SyncEncryption] Location mismatch: encrypted != plaintext',
            data: {'reminderId': reminder.id},
          );
          return false;
        }
      }

      return true;
    } catch (error) {
      _logger.warning(
        '[SyncEncryption] Validation failed - decryption error',
        data: {
          'reminderId': reminder.id,
          'error': error.toString(),
        },
      );
      return false;
    }
  }

  /// Determine if an encryption error is retryable
  ///
  /// Retryable errors:
  /// - Temporary key unavailability
  /// - Transient system errors
  /// - Network issues (for cloud-based keys)
  ///
  /// Non-retryable errors:
  /// - Corrupted key material
  /// - Invalid encryption algorithm
  /// - Programming errors
  bool _isRetryableError(Object error) {
    final errorStr = error.toString().toLowerCase();

    // Non-retryable: Programming errors
    if (errorStr.contains('assertion') ||
        errorStr.contains('invalid argument') ||
        errorStr.contains('null check')) {
      return false;
    }

    // Non-retryable: Cryptographic errors
    if (errorStr.contains('invalid key') ||
        errorStr.contains('corrupted') ||
        errorStr.contains('bad decrypt')) {
      return false;
    }

    // Retryable: Temporary issues
    if (errorStr.contains('timeout') ||
        errorStr.contains('unavailable') ||
        errorStr.contains('not initialized') ||
        errorStr.contains('locked')) {
      return true;
    }

    // Default to retryable (conservative approach)
    return true;
  }

  /// Get human-readable reason for encryption failure
  String _getErrorReason(Object error) {
    final errorStr = error.toString();

    if (errorStr.contains('key') && errorStr.contains('lock')) {
      return 'Master key locked - user authentication required';
    }

    if (errorStr.contains('timeout')) {
      return 'Encryption timeout - system may be under load';
    }

    if (errorStr.contains('not initialized')) {
      return 'CryptoBox not initialized - authentication pending';
    }

    if (errorStr.contains('invalid')) {
      return 'Invalid encryption parameters - data may be corrupted';
    }

    return 'Encryption failed: ${errorStr.length > 100 ? errorStr.substring(0, 100) : errorStr}';
  }

  /// Check if a reminder is already encrypted
  ///
  /// A reminder is considered encrypted if it has both title and body encrypted
  /// and the encryption version is set to 1.
  bool _isReminderEncrypted(NoteReminder reminder) {
    return reminder.titleEncrypted != null &&
        reminder.bodyEncrypted != null &&
        reminder.encryptionVersion == 1;
  }

  /// Handle verification failure by logging error, queuing for retry, and returning failure result
  ///
  /// This consolidates the error handling logic for encryption verification failures.
  /// Logs the error with relevant context, queues for retry, and returns a failure result.
  ReminderEncryptionResult _handleVerificationFailure(
    VerificationResult verification,
    NoteReminder reminder,
    String userId,
    String fieldName,
  ) {
    final error = verification.isError
        ? verification.error!
        : StateError(
            'Encryption verification failed: $fieldName roundtrip mismatch',
          );

    _logger.error(
      '[SyncEncryption] $fieldName verification failed',
      error: error,
      data: {
        'reminderId': reminder.id,
        'originalLength': verification.originalLength,
        'decryptedLength': verification.decryptedLength,
      },
    );

    // Queue for retry - this is a retryable encryption error
    _retryQueue.enqueue(
      reminderId: reminder.id,
      noteId: reminder.noteId,
      userId: userId,
    );

    return ReminderEncryptionResult.failure(
      error: error is Exception ? error : Exception(error.toString()),
      reason: 'Encryption verification failed for $fieldName',
      isRetryable: true,
    );
  }

  /// Get retry queue statistics
  Map<String, dynamic> getRetryStats() => _retryQueue.getStats();

  /// Process pending retries
  ///
  /// Call this when:
  /// - CryptoBox becomes available
  /// - User authenticates
  /// - App returns from background
  /// - Periodic background job
  ///
  /// The [retriever] callback is used to fetch reminders from the database
  /// Returns the number of reminders still pending retry
  Future<int> processRetries({
    required String userId,
    required ReminderRetriever retriever,
  }) async {
    return await _retryQueue.processRetries((metadata) async {
      final reminder = await retriever(metadata.reminderId);
      if (reminder == null) {
        // Reminder deleted - remove from queue
        return ReminderEncryptionResult.failure(
          error: Exception('Reminder not found'),
          reason: 'Reminder deleted',
          isRetryable: false,
        );
      }

      return await encryptForSync(reminder: reminder, userId: userId);
    });
  }
}
