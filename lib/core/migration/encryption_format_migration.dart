import 'dart:convert';
import 'dart:typed_data';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/crypto/key_manager.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/services/security/encryption_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Migrates encrypted data from AES-256-GCM format to XChaCha20-Poly1305
class EncryptionFormatMigration {
  EncryptionFormatMigration({
    required this.db,
    required this.supabase,
    required this.cryptoBox,
    required this.keyManager,
    EncryptionService? encryptionService,
  })  : _encryptionService = encryptionService,
        _logger = LoggerFactory.instance;

  final AppDb db;
  final SupabaseClient supabase;
  final CryptoBox cryptoBox;
  final KeyManager keyManager;
  // API can be provided through constructor if needed
  final EncryptionService? _encryptionService;
  final AppLogger _logger;

  static const _migrationKey = 'encryption_format_migration_v1';
  static const _batchSize = 50;

  /// Check if migration is needed
  Future<bool> isMigrationNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrationCompleted = prefs.getBool(_migrationKey) ?? false;

      if (migrationCompleted) {
        _logger.info('Encryption format migration already completed');
        return false;
      }

      // Check if there are any AES-encrypted notes
      final hasAesData = await _checkForAesEncryptedData();

      if (hasAesData) {
        _logger.info('AES-encrypted data detected, migration needed');
        return true;
      }

      // Mark migration as complete if no AES data exists
      await prefs.setBool(_migrationKey, true);
      return false;
    } catch (e) {
      _logger.error('Failed to check migration status', error: e);
      return false;
    }
  }

  /// Perform the migration from AES to CryptoBox format
  Future<MigrationResult> performMigration({
    void Function(MigrationProgress)? onProgress,
  }) async {
    final result = MigrationResult();
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      result.errors.add('User not authenticated');
      return result;
    }

    try {
      _logger.info('Starting encryption format migration');

      // Initialize encryption service if not provided
      final encryptionService = _encryptionService ?? EncryptionService();
      if (_encryptionService == null) {
        await encryptionService.initialize();
      }

      // Get all encrypted notes from remote
      final remoteNotes = await _fetchAllEncryptedNotes();
      result.totalItems = remoteNotes.length;

      _logger.info('Found ${remoteNotes.length} notes to migrate');

      // Process notes in batches
      for (int i = 0; i < remoteNotes.length; i += _batchSize) {
        final batch = remoteNotes.skip(i).take(_batchSize).toList();

        final progress = MigrationProgress(
          current: i,
          total: remoteNotes.length,
          phase: 'Migrating batch ${(i ~/ _batchSize) + 1}',
        );
        onProgress?.call(progress);

        await _migrateBatch(
          batch,
          userId,
          encryptionService,
          result,
        );
      }

      // Mark migration as complete
      if (result.errors.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_migrationKey, true);
        _logger.info('Encryption migration completed successfully');
      }

      result.success = result.errors.isEmpty;
      return result;
    } catch (e) {
      _logger.error('Encryption migration failed', error: e);
      result.errors.add('Migration failed: $e');
      result.success = false;
      return result;
    }
  }

  /// Check if there are any AES-encrypted notes
  Future<bool> _checkForAesEncryptedData() async {
    try {
      final response = await supabase
          .from('notes')
          .select('title_enc, props_enc')
          .limit(1);

      if (response.isEmpty) {
        return false;
      }

      final note = response.first;

      // Try to detect AES format
      if (note['title_enc'] != null) {
        final titleBytes = SupabaseNoteApi.asBytes(note['title_enc']);
        return _isAesFormat(titleBytes);
      }

      return false;
    } catch (e) {
      _logger.error('Failed to check for AES data', error: e);
      return false;
    }
  }

  /// Detect if data is in AES format
  bool _isAesFormat(Uint8List data) {
    try {
      final decoded = utf8.decode(data);
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      // AES format has these keys: data, iv, mac, keyId, algorithm
      return json.containsKey('data') &&
          json.containsKey('iv') &&
          json.containsKey('mac') &&
          json.containsKey('keyId');
    } catch (e) {
      // If it's not valid JSON or doesn't have the expected structure,
      // it might be CryptoBox format or corrupted
      return false;
    }
  }

  /// Fetch all encrypted notes from remote
  Future<List<Map<String, dynamic>>> _fetchAllEncryptedNotes() async {
    try {
      final response = await supabase
          .from('notes')
          .select('id, title_enc, props_enc, deleted, updated_at')
          .order('updated_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logger.error('Failed to fetch encrypted notes', error: e);
      return [];
    }
  }

  /// Migrate a batch of notes
  Future<void> _migrateBatch(
    List<Map<String, dynamic>> batch,
    String userId,
    EncryptionService encryptionService,
    MigrationResult result,
  ) async {
    for (final note in batch) {
      try {
        final noteId = note['id'] as String;
        final deleted = note['deleted'] as bool? ?? false;

        // Skip deleted notes
        if (deleted) {
          result.skippedItems++;
          continue;
        }

        bool needsMigration = false;
        Uint8List? newTitleEnc;
        Uint8List? newPropsEnc;

        // Check and migrate title
        if (note['title_enc'] != null) {
          final titleBytes = SupabaseNoteApi.asBytes(note['title_enc']);

          if (_isAesFormat(titleBytes)) {
            needsMigration = true;

            // Decrypt with AES
            final decryptedTitle = await _decryptAesData(
              titleBytes,
              encryptionService,
            );

            if (decryptedTitle != null) {
              // Re-encrypt with CryptoBox
              newTitleEnc = await cryptoBox.encryptJsonForNote(
                userId: userId,
                noteId: noteId,
                json: decryptedTitle,
              );
            }
          }
        }

        // Check and migrate props
        if (note['props_enc'] != null) {
          final propsBytes = SupabaseNoteApi.asBytes(note['props_enc']);

          if (_isAesFormat(propsBytes)) {
            needsMigration = true;

            // Decrypt with AES
            final decryptedProps = await _decryptAesData(
              propsBytes,
              encryptionService,
            );

            if (decryptedProps != null) {
              // Re-encrypt with CryptoBox
              newPropsEnc = await cryptoBox.encryptJsonForNote(
                userId: userId,
                noteId: noteId,
                json: decryptedProps,
              );
            }
          }
        }

        // Update remote if migration was needed
        if (needsMigration) {
          await _updateRemoteNote(
            noteId,
            newTitleEnc,
            newPropsEnc,
          );

          result.migratedItems++;
          _logger.debug('Migrated note: $noteId');
        } else {
          result.skippedItems++;
        }
      } catch (e) {
        _logger.error('Failed to migrate note ${note['id']}', error: e);
        result.errors.add('Note ${note['id']}: $e');
        result.failedItems++;
      }
    }
  }

  /// Decrypt AES-encrypted data
  Future<Map<String, dynamic>?> _decryptAesData(
    Uint8List encryptedBytes,
    EncryptionService encryptionService,
  ) async {
    try {
      final encryptedStr = utf8.decode(encryptedBytes);
      final encryptedData = EncryptedData.fromJson(
        jsonDecode(encryptedStr) as Map<String, dynamic>,
      );

      final decryptedData = await encryptionService.decryptData(encryptedData);
      // decryptData returns dynamic, we need to handle it properly
      final decryptedBytes = decryptedData is List<int>
          ? decryptedData
          : decryptedData is String
              ? utf8.encode(decryptedData)
              : throw Exception('Unexpected decryption result type');
      final decryptedStr = utf8.decode(decryptedBytes);

      // Try to parse as JSON
      try {
        return jsonDecode(decryptedStr) as Map<String, dynamic>;
      } catch (_) {
        // If not JSON, wrap in a simple structure
        return {'value': decryptedStr};
      }
    } catch (e) {
      _logger.error('Failed to decrypt AES data', error: e);
      return null;
    }
  }

  /// Update remote note with new encryption format
  Future<void> _updateRemoteNote(
    String noteId,
    Uint8List? titleEnc,
    Uint8List? propsEnc,
  ) async {
    final updates = <String, dynamic>{};

    if (titleEnc != null) {
      updates['title_enc'] = titleEnc;
    }

    if (propsEnc != null) {
      updates['props_enc'] = propsEnc;
    }

    if (updates.isNotEmpty) {
      updates['updated_at'] = DateTime.now().toUtc().toIso8601String();

      await supabase
          .from('notes')
          .update(updates)
          .eq('id', noteId);
    }
  }

  /// Rollback migration if needed
  Future<void> rollbackMigration() async {
    try {
      _logger.info('Rolling back encryption migration');

      // Clear migration flag
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_migrationKey);

      _logger.info('Migration rollback completed');
    } catch (e) {
      _logger.error('Failed to rollback migration', error: e);
    }
  }
}

/// Result of the migration process
class MigrationResult {
  bool success = false;
  int totalItems = 0;
  int migratedItems = 0;
  int skippedItems = 0;
  int failedItems = 0;
  List<String> errors = [];

  Map<String, dynamic> toJson() => {
        'success': success,
        'totalItems': totalItems,
        'migratedItems': migratedItems,
        'skippedItems': skippedItems,
        'failedItems': failedItems,
        'errors': errors,
      };
}

/// Progress indicator for migration
class MigrationProgress {
  MigrationProgress({
    required this.current,
    required this.total,
    required this.phase,
  });

  final int current;
  final int total;
  final String phase;

  double get percentage => total > 0 ? (current / total) * 100 : 0;
}