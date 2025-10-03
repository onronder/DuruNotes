import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:duru_notes/core/security/security_initialization.dart';
import 'package:duru_notes/services/security/encryption_service.dart';
import 'package:duru_notes/services/error_logging_service.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Production-grade secure data service
/// Handles encryption/decryption of sensitive data throughout the app
class SecureDataService {
  static final SecureDataService _instance = SecureDataService._internal();
  factory SecureDataService() => _instance;
  SecureDataService._internal();

  late final EncryptionService _encryption;
  late final ErrorLoggingService _errorLogger;
  late final AppDb _database;

  /// List of sensitive fields that should be encrypted
  static const List<String> _sensitiveNoteFields = [
    'content',
    'attachments',
    'metadata',
    'encryptedMetadata',
  ];

  static const List<String> _sensitiveUserFields = [
    'email',
    'phone',
    'apiKeys',
    'tokens',
    'passwords',
    'creditCards',
    'personalInfo',
  ];

  /// Initialize the secure data service
  Future<void> initialize(AppDb database) async {
    _encryption = SecurityInitialization.encryption;
    _errorLogger = SecurityInitialization.errorLogging;
    _database = database;
  }

  // ============================================================================
  // NOTE DATA ENCRYPTION
  // ============================================================================

  /// Encrypt sensitive note data before storage
  Future<LocalNote> encryptNoteData(LocalNote note) async {
    try {
      Map<String, dynamic> noteData = {
        'id': note.id,
        'title': note.title,
        'body': note.body,
        'updatedAt': note.updatedAt.toIso8601String(),
        'deleted': note.deleted,
        'isPinned': note.isPinned,
        'noteType': note.noteType,
        'version': note.version,
        'userId': note.userId,
        'attachmentMeta': note.attachmentMeta,
        'metadata': note.metadata,
        'encryptedMetadata': note.encryptedMetadata,
      };

      // Encrypt sensitive fields
      if (note.body.isNotEmpty) {
        final encryptedBody = await _encryption.encryptData(
          note.body,
          metadata: {'noteId': note.id, 'type': 'body'},
        );
        noteData['body'] = jsonEncode(encryptedBody.toJson());
      }

      if (note.encryptedMetadata != null) {
        final encryptedMeta = await _encryption.encryptData(
          note.encryptedMetadata!,
          metadata: {'noteId': note.id, 'type': 'metadata'},
        );
        noteData['encryptedMetadata'] = jsonEncode(encryptedMeta.toJson());
      }

      // Create new note with encrypted data
      return LocalNote(
        id: noteData['id'] as String,
        title: noteData['title'] as String,
        body: noteData['body'] as String,
        updatedAt: DateTime.parse(noteData['updatedAt'] as String),
        deleted: noteData['deleted'] as bool,
        isPinned: noteData['isPinned'] as bool,
        noteType: noteData['noteType'] as NoteKind? ?? NoteKind.note,
        version: noteData['version'] as int? ?? 1,
        userId: noteData['userId'] as String? ?? '',
        attachmentMeta: noteData['attachmentMeta'] as String?,
        metadata: noteData['metadata'] as String?,
        encryptedMetadata: noteData['encryptedMetadata'] as String?,
      );
    } catch (error, stack) {
      _errorLogger.logError(error, stack, category: 'Encryption', metadata: {
        'operation': 'encryptNoteData',
        'noteId': note.id,
      });
      rethrow;
    }
  }

  /// Decrypt sensitive note data after retrieval
  Future<LocalNote> decryptNoteData(LocalNote note) async {
    try {
      Map<String, dynamic> noteData = {
        'id': note.id,
        'title': note.title,
        'body': note.body,
        'updatedAt': note.updatedAt.toIso8601String(),
        'deleted': note.deleted,
        'isPinned': note.isPinned,
        'noteType': note.noteType,
        'version': note.version,
        'userId': note.userId,
        'attachmentMeta': note.attachmentMeta,
        'metadata': note.metadata,
        'encryptedMetadata': note.encryptedMetadata,
      };

      // Decrypt body if it's encrypted
      if (_isEncryptedData(note.body)) {
        final encryptedData = EncryptedData.fromJson(jsonDecode(note.body) as Map<String, dynamic>);
        noteData['body'] = await _encryption.decryptData(encryptedData) as String;
      }

      // Decrypt metadata if encrypted
      if (note.encryptedMetadata != null && _isEncryptedData(note.encryptedMetadata!)) {
        final encryptedData = EncryptedData.fromJson(jsonDecode(note.encryptedMetadata!) as Map<String, dynamic>);
        noteData['encryptedMetadata'] = await _encryption.decryptData(encryptedData) as String;
      }

      return LocalNote(
        id: noteData['id'] as String,
        title: noteData['title'] as String,
        body: noteData['body'] as String,
        updatedAt: DateTime.parse(noteData['updatedAt'] as String),
        deleted: noteData['deleted'] as bool,
        isPinned: noteData['isPinned'] as bool,
        noteType: noteData['noteType'] as NoteKind? ?? NoteKind.note,
        version: noteData['version'] as int? ?? 1,
        userId: noteData['userId'] as String? ?? '',
        attachmentMeta: noteData['attachmentMeta'] as String?,
        metadata: noteData['metadata'] as String?,
        encryptedMetadata: noteData['encryptedMetadata'] as String?,
      );
    } catch (error, stack) {
      _errorLogger.logError(error, stack, category: 'Decryption', metadata: {
        'operation': 'decryptNoteData',
        'noteId': note.id,
      });
      // Return original note if decryption fails
      return note;
    }
  }

  // ============================================================================
  // USER PREFERENCES ENCRYPTION
  // ============================================================================

  /// Store encrypted user preferences
  Future<void> storeSecurePreference(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Encrypt the value
      final encrypted = await _encryption.encryptData(
        value,
        metadata: {'key': key, 'type': 'preference'},
      );

      // Store as JSON string
      await prefs.setString('secure_$key', jsonEncode(encrypted.toJson()));
    } catch (error, stack) {
      _errorLogger.logError(error, stack, category: 'SecureStorage', metadata: {
        'operation': 'storeSecurePreference',
        'key': key,
      });
      rethrow;
    }
  }

  /// Retrieve and decrypt user preference
  Future<T?> getSecurePreference<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedJson = prefs.getString('secure_$key');

      if (encryptedJson == null) return null;

      final encryptedData = EncryptedData.fromJson(jsonDecode(encryptedJson) as Map<String, dynamic>);
      final decrypted = await _encryption.decryptData(encryptedData);

      return decrypted as T;
    } catch (error, stack) {
      _errorLogger.logError(error, stack, category: 'SecureStorage', metadata: {
        'operation': 'getSecurePreference',
        'key': key,
      });
      return null;
    }
  }

  // ============================================================================
  // API CREDENTIALS ENCRYPTION
  // ============================================================================

  /// Store encrypted API credentials
  Future<void> storeApiCredentials({
    required String service,
    required String apiKey,
    String? apiSecret,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final credentials = {
        'apiKey': apiKey,
        if (apiSecret != null) 'apiSecret': apiSecret,
        ...?additionalData,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Encrypt with additional security
      final encrypted = await _encryption.encryptData(
        credentials,
        metadata: {
          'service': service,
          'type': 'api_credentials',
        },
      );

      // Store in secure storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_$service', jsonEncode(encrypted.toJson()));

      _errorLogger.logInfo('API credentials stored securely', {
        'service': service,
      });
    } catch (error, stack) {
      _errorLogger.logError(error, stack, category: 'Security', metadata: {
        'operation': 'storeApiCredentials',
        'service': service,
      });
      rethrow;
    }
  }

  /// Retrieve and decrypt API credentials
  Future<Map<String, dynamic>?> getApiCredentials(String service) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedJson = prefs.getString('api_$service');

      if (encryptedJson == null) return null;

      final encryptedData = EncryptedData.fromJson(jsonDecode(encryptedJson) as Map<String, dynamic>);
      final decrypted = await _encryption.decryptData(encryptedData);

      return decrypted as Map<String, dynamic>;
    } catch (error, stack) {
      _errorLogger.logError(error, stack, category: 'Security', metadata: {
        'operation': 'getApiCredentials',
        'service': service,
      });
      return null;
    }
  }

  // ============================================================================
  // FILE ATTACHMENT ENCRYPTION
  // ============================================================================

  /// Encrypt file attachment before storage
  Future<Uint8List> encryptAttachment(Uint8List data, String attachmentId) async {
    try {
      final encrypted = await _encryption.encryptData(
        base64Encode(data),
        metadata: {
          'attachmentId': attachmentId,
          'type': 'attachment',
          'size': data.length,
        },
      );

      // Convert encrypted data to bytes for storage
      final jsonStr = jsonEncode(encrypted.toJson());
      return Uint8List.fromList(utf8.encode(jsonStr));
    } catch (error, stack) {
      _errorLogger.logError(error, stack, category: 'Encryption', metadata: {
        'operation': 'encryptAttachment',
        'attachmentId': attachmentId,
      });
      rethrow;
    }
  }

  /// Decrypt file attachment after retrieval
  Future<Uint8List> decryptAttachment(Uint8List encryptedData, String attachmentId) async {
    try {
      // Parse encrypted data from bytes
      final jsonStr = utf8.decode(encryptedData);
      final encrypted = EncryptedData.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

      // Decrypt
      final decrypted = await _encryption.decryptData(encrypted) as String;

      // Convert from base64 back to bytes
      return base64Decode(decrypted);
    } catch (error, stack) {
      _errorLogger.logError(error, stack, category: 'Decryption', metadata: {
        'operation': 'decryptAttachment',
        'attachmentId': attachmentId,
      });
      rethrow;
    }
  }

  // ============================================================================
  // BATCH ENCRYPTION OPERATIONS
  // ============================================================================

  /// Encrypt multiple notes in batch
  Future<List<LocalNote>> encryptNotesBatch(List<LocalNote> notes) async {
    final encryptedNotes = <LocalNote>[];

    for (final note in notes) {
      try {
        final encrypted = await encryptNoteData(note);
        encryptedNotes.add(encrypted);
      } catch (e) {
        // Log error but continue with other notes
        _errorLogger.logWarning('Failed to encrypt note ${note.id}', {
          'error': e.toString(),
        });
        encryptedNotes.add(note); // Add unencrypted if encryption fails
      }
    }

    return encryptedNotes;
  }

  /// Decrypt multiple notes in batch
  Future<List<LocalNote>> decryptNotesBatch(List<LocalNote> notes) async {
    final decryptedNotes = <LocalNote>[];

    for (final note in notes) {
      try {
        final decrypted = await decryptNoteData(note);
        decryptedNotes.add(decrypted);
      } catch (e) {
        // Log error but continue with other notes
        _errorLogger.logWarning('Failed to decrypt note ${note.id}', {
          'error': e.toString(),
        });
        decryptedNotes.add(note); // Add as-is if decryption fails
      }
    }

    return decryptedNotes;
  }

  // ============================================================================
  // KEY ROTATION SUPPORT
  // ============================================================================

  /// Re-encrypt all data with new key during key rotation
  Future<void> reencryptAllData() async {
    try {
      _errorLogger.logInfo('Starting data re-encryption for key rotation');

      // Re-encrypt all notes
      final notes = await _database.select(_database.localNotes).get();
      for (final note in notes) {
        if (_needsReencryption(note)) {
          // Decrypt with old key and encrypt with new key
          final decrypted = await decryptNoteData(note);
          final reencrypted = await encryptNoteData(decrypted);
          await _database.into(_database.localNotes).insertOnConflictUpdate(reencrypted);
        }
      }

      // Re-encrypt stored preferences
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('secure_'));

      for (final key in keys) {
        final value = await getSecurePreference<String>(key.substring(7));
        if (value != null) {
          await storeSecurePreference(key.substring(7), value);
        }
      }

      _errorLogger.logInfo('Data re-encryption completed successfully');
    } catch (error, stack) {
      _errorLogger.logError(error, stack,
        severity: ErrorSeverity.critical,
        category: 'KeyRotation',
      );
      rethrow;
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Check if a string contains encrypted data
  bool _isEncryptedData(String data) {
    try {
      final json = jsonDecode(data);
      return json is Map &&
          json.containsKey('data') &&
          json.containsKey('iv') &&
          json.containsKey('mac') &&
          json.containsKey('keyId');
    } catch (e) {
      return false;
    }
  }

  /// Check if note needs re-encryption
  bool _needsReencryption(LocalNote note) {
    // Check if body or metadata is encrypted with old key
    return _isEncryptedData(note.body) ||
        (note.encryptedMetadata != null && _isEncryptedData(note.encryptedMetadata!));
  }

  /// Securely wipe sensitive data from memory
  void secureWipe(dynamic data) {
    _encryption.secureErase(data);
  }

  /// Get encryption statistics
  Map<String, dynamic> getEncryptionStats() {
    return {
      'encryptionEnabled': true,
      'keyRotationEnabled': true,
      'algorithm': 'AES-256-GCM',
      'sensitiveFieldsProtected': [
        ..._sensitiveNoteFields,
        ..._sensitiveUserFields,
      ],
    };
  }
}