import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duru_notes/services/security/encryption_service.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/security/fallback_note.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Service to handle encryption fallbacks when decryption fails
class EncryptionFallbackService {
  static final EncryptionFallbackService _instance =
      EncryptionFallbackService._internal();
  factory EncryptionFallbackService() => _instance;
  EncryptionFallbackService._internal();

  final AppLogger _logger = LoggerFactory.instance;
  final Map<String, FallbackNote> _fallbackCache = {};

  void _captureFallbackException({
    required String operation,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.warning,
  }) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.level = level;
          scope.setTag('service', 'EncryptionFallbackService');
          scope.setTag('operation', operation);
        },
      ),
    );
  }

  /// Attempt to decrypt note with fallback handling
  Future<Map<String, dynamic>> decryptNoteWithFallback({
    required String noteId,
    required dynamic titleEnc,
    required dynamic propsEnc,
    required EncryptionService encryptionService,
    required DateTime createdAt,
  }) async {
    String title = '';
    String body = '';
    String? folderId;
    bool isPinned = false;
    List<String> tags = [];
    bool decryptionFailed = false;

    // Try to decrypt title
    try {
      if (titleEnc != null) {
        title = await _decryptField(titleEnc, encryptionService, 'title');
      }
    } catch (error, stack) {
      _logger.warning(
        'Failed to decrypt title for note $noteId',
        data: {'error': error.toString()},
      );
      _captureFallbackException(
        operation: 'decryptNote.title',
        error: error,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
      title = await _createFallbackTitle(noteId, titleEnc);
      decryptionFailed = true;
    }

    // Try to decrypt props
    try {
      if (propsEnc != null) {
        final props = await _decryptProps(propsEnc, encryptionService);
        body = props['body'] as String? ?? '';
        folderId = props['folder_id'] as String?;
        isPinned = props['is_pinned'] as bool? ?? false;
        tags = (props['tags'] as List<dynamic>?)?.cast<String>() ?? [];
      }
    } catch (error, stack) {
      _logger.warning(
        'Failed to decrypt props for note $noteId',
        data: {'error': error.toString()},
      );
      _captureFallbackException(
        operation: 'decryptNote.props',
        error: error,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
      final fallbackProps = await _createFallbackProps(
        noteId,
        propsEnc,
        error.toString(),
      );
      body = fallbackProps['body'] as String;
      folderId = fallbackProps['folder_id'] as String?;
      isPinned = fallbackProps['is_pinned'] as bool;
      tags = (fallbackProps['tags'] as List<dynamic>).cast<String>();
      decryptionFailed = true;
    }

    // Store fallback data if decryption failed
    if (decryptionFailed) {
      await _storeFallbackNote(
        FallbackNote(
          id: noteId,
          fallbackTitle: title,
          fallbackBody: body,
          createdAt: createdAt,
          isRecoverable: await _checkIfRecoverable(titleEnc, propsEnc),
          rawData: await _extractRawData(titleEnc, propsEnc),
        ),
      );
    }

    return {
      'id': noteId,
      'title': title,
      'body': body,
      'folder_id': folderId,
      'is_pinned': isPinned,
      'tags': tags,
      'decryption_failed': decryptionFailed,
    };
  }

  /// Decrypt a single field with multiple fallback methods
  Future<String> _decryptField(
    dynamic encryptedField,
    EncryptionService encryptionService,
    String fieldName,
  ) async {
    // Try modern encryption format first
    try {
      final fieldBytes = _asBytes(encryptedField);
      final jsonData = utf8.decode(fieldBytes);
      final parsedData = jsonDecode(jsonData);

      if (parsedData is Map<String, dynamic>) {
        final encryptedData = EncryptedData.fromJson(parsedData);
        final decrypted = await encryptionService.decryptData(encryptedData);
        return decrypted as String;
      }
    } catch (e) {
      _logger.debug('Modern decryption failed for $fieldName: $e');
    }

    // Try legacy base64 format
    try {
      final fieldBytes = _asBytes(encryptedField);
      final base64String = String.fromCharCodes(fieldBytes);
      final decodedBytes = base64Decode(base64String);
      final recovered = utf8.decode(decodedBytes);

      if (recovered.isNotEmpty && recovered.length < 10000) {
        _logger.info('Recovered $fieldName using legacy base64 format');
        return recovered;
      }
    } catch (e) {
      _logger.debug('Legacy base64 decryption failed for $fieldName: $e');
    }

    // Try direct UTF-8 decoding
    try {
      final fieldBytes = _asBytes(encryptedField);
      final recovered = utf8.decode(fieldBytes);

      if (recovered.isNotEmpty && recovered.length < 10000) {
        _logger.info('Recovered $fieldName using direct UTF-8 decoding');
        return recovered;
      }
    } catch (e) {
      _logger.debug('Direct UTF-8 decryption failed for $fieldName: $e');
    }

    throw Exception('All decryption methods failed for $fieldName');
  }

  /// Decrypt props with multiple fallback methods
  Future<Map<String, dynamic>> _decryptProps(
    dynamic encryptedProps,
    EncryptionService encryptionService,
  ) async {
    // Try modern encryption format first
    try {
      final propsBytes = _asBytes(encryptedProps);
      final jsonData = utf8.decode(propsBytes);
      final parsedData = jsonDecode(jsonData);

      if (parsedData is Map<String, dynamic>) {
        final encryptedData = EncryptedData.fromJson(parsedData);
        final decrypted = await encryptionService.decryptData(encryptedData);
        return json.decode(decrypted as String) as Map<String, dynamic>;
      }
    } catch (e) {
      _logger.debug('Modern props decryption failed: $e');
    }

    // Try legacy base64 format
    try {
      final propsBytes = _asBytes(encryptedProps);
      final base64String = String.fromCharCodes(propsBytes);
      final decodedBytes = base64Decode(base64String);
      final propsJson = utf8.decode(decodedBytes);
      return json.decode(propsJson) as Map<String, dynamic>;
    } catch (e) {
      _logger.debug('Legacy base64 props decryption failed: $e');
    }

    // Try direct JSON parsing
    try {
      final propsBytes = _asBytes(encryptedProps);
      final propsJson = utf8.decode(propsBytes);
      return json.decode(propsJson) as Map<String, dynamic>;
    } catch (e) {
      _logger.debug('Direct JSON props decryption failed: $e');
    }

    throw Exception('All props decryption methods failed');
  }

  /// Create fallback title when decryption fails
  Future<String> _createFallbackTitle(String noteId, dynamic titleEnc) async {
    // Try to extract something meaningful
    try {
      final titleBytes = _asBytes(titleEnc);
      final rawString = utf8.decode(titleBytes, allowMalformed: true);

      // Look for any readable text in the first 50 characters
      final preview = rawString.substring(0, rawString.length.clamp(0, 50));
      final readableText = preview.replaceAll(RegExp(r'[^\w\s]'), '').trim();

      if (readableText.isNotEmpty && readableText.length > 3) {
        return 'Encrypted Note: $readableText...';
      }
    } catch (e) {
      _logger.debug('Failed to create meaningful fallback title: $e');
    }

    // Default fallback
    final shortId = noteId.length > 8 ? noteId.substring(0, 8) : noteId;
    return 'Encrypted Note ($shortId)';
  }

  /// Create fallback props when decryption fails
  Future<Map<String, dynamic>> _createFallbackProps(
    String noteId,
    dynamic propsEnc,
    String error,
  ) async {
    final fallbackBody =
        '''This note could not be decrypted automatically.

Possible causes:
• The note was encrypted with an older version of the app
• The encryption key was corrupted or lost
• The data was corrupted during sync

Technical details:
• Note ID: $noteId
• Error: $error
• Timestamp: ${DateTime.now().toIso8601String()}

The original encrypted data has been preserved and may be recoverable with a future update.''';

    return {
      'body': fallbackBody,
      'folder_id': null,
      'is_pinned': false,
      'tags': ['decryption-failed', 'needs-recovery'],
    };
  }

  /// Check if the encrypted data might be recoverable
  Future<bool> _checkIfRecoverable(dynamic titleEnc, dynamic propsEnc) async {
    // Check if the data has recognizable patterns
    try {
      if (titleEnc != null) {
        final titleBytes = _asBytes(titleEnc);
        final titleStr = utf8.decode(titleBytes, allowMalformed: true);
        // Look for JSON structure or base64 patterns
        if (titleStr.contains('{') ||
            titleStr.contains('eyJ') ||
            titleStr.contains('=')) {
          return true;
        }
      }

      if (propsEnc != null) {
        final propsBytes = _asBytes(propsEnc);
        final propsStr = utf8.decode(propsBytes, allowMalformed: true);
        // Look for JSON structure or base64 patterns
        if (propsStr.contains('{') ||
            propsStr.contains('eyJ') ||
            propsStr.contains('=')) {
          return true;
        }
      }
    } catch (e) {
      _logger.debug('Error checking recoverability: $e');
    }

    return false;
  }

  /// Extract raw data for potential future recovery
  Future<String?> _extractRawData(dynamic titleEnc, dynamic propsEnc) async {
    try {
      final rawData = <String, dynamic>{};

      if (titleEnc != null) {
        final titleBytes = _asBytes(titleEnc);
        rawData['titleRaw'] = base64Encode(titleBytes);
      }

      if (propsEnc != null) {
        final propsBytes = _asBytes(propsEnc);
        rawData['propsRaw'] = base64Encode(propsBytes);
      }

      return jsonEncode(rawData);
    } catch (e) {
      _logger.debug('Failed to extract raw data: $e');
      return null;
    }
  }

  /// Store fallback note data
  Future<void> _storeFallbackNote(FallbackNote note) async {
    _fallbackCache[note.id] = note;

    // Persist to SharedPreferences for recovery attempts
    try {
      final prefs = await SharedPreferences.getInstance();
      final fallbackData = prefs.getStringList('fallback_notes') ?? [];

      // Remove existing entry for this note
      fallbackData.removeWhere((entry) {
        try {
          final data = jsonDecode(entry) as Map<String, dynamic>;
          return data['id'] == note.id;
        } catch (e) {
          return false;
        }
      });

      // Add new entry
      fallbackData.add(jsonEncode(note.toJson()));

      // Keep only recent 100 fallback notes
      if (fallbackData.length > 100) {
        fallbackData.removeRange(0, fallbackData.length - 100);
      }

      await prefs.setStringList('fallback_notes', fallbackData);
    } catch (error, stack) {
      _logger.error(
        'Failed to store fallback note',
        error: error,
        stackTrace: stack,
      );
      _captureFallbackException(
        operation: 'storeFallbackNote',
        error: error,
        stackTrace: stack,
      );
    }
  }

  /// Get all fallback notes
  Future<List<FallbackNote>> getFallbackNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final fallbackData = prefs.getStringList('fallback_notes') ?? [];

    final notes = <FallbackNote>[];
    for (final entry in fallbackData) {
      try {
        final data = jsonDecode(entry) as Map<String, dynamic>;
        notes.add(FallbackNote.fromJson(data));
      } catch (e) {
        _logger.warning('Failed to parse fallback note: $e');
      }
    }

    return notes;
  }

  /// Attempt to recover a specific fallback note
  Future<bool> attemptNoteRecovery(String noteId) async {
    final fallbackNote = _fallbackCache[noteId];
    if (fallbackNote == null || !fallbackNote.isRecoverable) {
      return false;
    }

    // Attempt recovery with current encryption service
    try {
      final encryptionService = EncryptionService();
      await encryptionService.initialize();

      if (fallbackNote.rawData != null) {
        final rawData =
            jsonDecode(fallbackNote.rawData!) as Map<String, dynamic>;

        if (rawData['titleRaw'] != null) {
          final titleBytes = base64Decode(rawData['titleRaw'] as String);
          await _decryptField(titleBytes, encryptionService, 'title');
          _logger.info('Successfully recovered note $noteId');
          return true;
        }
      }
    } catch (e) {
      _logger.debug('Recovery attempt failed for note $noteId: $e');
    }

    return false;
  }

  /// Convert various data types to Uint8List
  Uint8List _asBytes(dynamic data) {
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    if (data is String) return utf8.encode(data);
    throw ArgumentError('Cannot convert to bytes: ${data.runtimeType}');
  }

  /// Clear fallback cache
  void clearCache() {
    _fallbackCache.clear();
  }

  /// Get fallback statistics
  Future<Map<String, int>> getStatistics() async {
    final notes = await getFallbackNotes();
    final total = notes.length;
    final recoverable = notes.where((n) => n.isRecoverable).length;

    return {
      'total': total,
      'recoverable': recoverable,
      'unrecoverable': total - recoverable,
    };
  }
}
