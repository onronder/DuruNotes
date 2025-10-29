import 'dart:typed_data';
import 'package:duru_notes/data/local/app_db.dart';

/// DEPRECATED: This service is obsolete after encryption migration.
///
/// Post-encryption migration, all encryption/decryption is handled at the repository
/// layer using:
/// - infrastructure/helpers/note_decryption_helper.dart
/// - infrastructure/helpers/task_decryption_helper.dart
/// - infrastructure/mappers/note_mapper.dart
/// - infrastructure/mappers/task_mapper.dart
///
/// This service tried to work with LocalNote.title/.body fields which no longer exist.
/// All notes now have titleEncrypted/bodyEncrypted fields and are decrypted only when
/// converting to domain entities.
///
/// Use NotesCoreRepository and TaskCoreRepository instead - they handle encryption automatically.
@Deprecated('Use NotesCoreRepository and TaskCoreRepository instead - they handle encryption automatically')
class SecureDataService {
  static final SecureDataService _instance = SecureDataService._internal();
  factory SecureDataService() => _instance;
  SecureDataService._internal();

  /// Initialize the secure data service
  Future<void> initialize(AppDb database) async {
    // No-op: Service is deprecated
  }

  /// Encrypt sensitive note data before storage
  @Deprecated('Use NotesCoreRepository instead')
  Future<LocalNote> encryptNoteData(LocalNote note) async {
    throw UnsupportedError('SecureDataService is deprecated. Use NotesCoreRepository instead.');
  }

  /// Decrypt sensitive note data after retrieval
  @Deprecated('Use NotesCoreRepository instead')
  Future<LocalNote> decryptNoteData(LocalNote note) async {
    throw UnsupportedError('SecureDataService is deprecated. Use NotesCoreRepository instead.');
  }

  /// Store encrypted user preferences
  @Deprecated('Use secure storage from repository layer')
  Future<void> storeSecurePreference(String key, dynamic value) async {
    throw UnsupportedError('SecureDataService is deprecated.');
  }

  /// Retrieve and decrypt user preference
  @Deprecated('Use secure storage from repository layer')
  Future<T?> getSecurePreference<T>(String key) async {
    throw UnsupportedError('SecureDataService is deprecated.');
  }

  /// Store encrypted API credentials
  @Deprecated('Use secure storage from repository layer')
  Future<void> storeApiCredentials({
    required String service,
    required String apiKey,
    String? apiSecret,
    Map<String, dynamic>? additionalData,
  }) async {
    throw UnsupportedError('SecureDataService is deprecated.');
  }

  /// Retrieve and decrypt API credentials
  @Deprecated('Use secure storage from repository layer')
  Future<Map<String, dynamic>?> getApiCredentials(String service) async {
    throw UnsupportedError('SecureDataService is deprecated.');
  }

  /// Encrypt file attachment before storage
  @Deprecated('Use repository layer for attachment encryption')
  Future<Uint8List> encryptAttachment(Uint8List data, String attachmentId) async {
    throw UnsupportedError('SecureDataService is deprecated.');
  }

  /// Decrypt file attachment after retrieval
  @Deprecated('Use repository layer for attachment decryption')
  Future<Uint8List> decryptAttachment(Uint8List encryptedData, String attachmentId) async {
    throw UnsupportedError('SecureDataService is deprecated.');
  }

  /// Encrypt multiple notes in batch
  @Deprecated('Use NotesCoreRepository instead')
  Future<List<LocalNote>> encryptNotesBatch(List<LocalNote> notes) async {
    throw UnsupportedError('SecureDataService is deprecated. Use NotesCoreRepository instead.');
  }

  /// Decrypt multiple notes in batch
  @Deprecated('Use NotesCoreRepository instead')
  Future<List<LocalNote>> decryptNotesBatch(List<LocalNote> notes) async {
    throw UnsupportedError('SecureDataService is deprecated. Use NotesCoreRepository instead.');
  }

  /// Re-encrypt all data with new key during key rotation
  @Deprecated('Key rotation should be handled by crypto layer')
  Future<void> reencryptAllData() async {
    throw UnsupportedError('SecureDataService is deprecated.');
  }

  /// Securely wipe sensitive data from memory
  void secureWipe(dynamic data) {
    // No-op: deprecated
  }

  /// Get encryption statistics
  Map<String, dynamic> getEncryptionStats() {
    return {
      'deprecated': true,
      'message': 'Use NotesCoreRepository and TaskCoreRepository instead',
    };
  }
}
