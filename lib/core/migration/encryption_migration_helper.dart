import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duru_notes/services/security/encryption_service.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/migration/migration_result.dart';

/// Migration helper for handling old encrypted notes that can't be decrypted
class EncryptionMigrationHelper {
  static final EncryptionMigrationHelper _instance =
      EncryptionMigrationHelper._internal();
  factory EncryptionMigrationHelper() => _instance;
  EncryptionMigrationHelper._internal();

  final AppLogger _logger = LoggerFactory.instance;

  /// Run migration for encrypted notes
  Future<MigrationResult> migrateEncryptedNotes({
    required SupabaseClient client,
    bool dryRun = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final migrationKey = 'encryption_migration_completed_v2';

    // Check if migration already completed
    if (prefs.getBool(migrationKey) == true) {
      _logger.info('Encryption migration already completed');
      return MigrationResult(
        totalNotes: 0,
        successfulDecryptions: 0,
        failedDecryptions: 0,
        recoveredNotes: 0,
        errors: [],
      );
    }

    _logger.info('Starting encryption migration${dryRun ? ' (dry run)' : ''}');

    final encryptionService = EncryptionService();
    await encryptionService.initialize();

    final api = SupabaseNoteApi(client);
    final errors = <String>[];
    int totalNotes = 0;
    int successfulDecryptions = 0;
    int failedDecryptions = 0;
    int recoveredNotes = 0;

    try {
      // Fetch all encrypted notes
      final encryptedNotes = await api.fetchEncryptedNotes();
      totalNotes = encryptedNotes.length;

      _logger.info('Found $totalNotes encrypted notes to migrate');

      for (final note in encryptedNotes) {
        final noteId = note['id'] as String;
        bool needsUpdate = false;
        String? newTitle;
        Map<String, dynamic>? newProps;

        // Try to decrypt title
        if (note['title_enc'] != null) {
          final titleResult = await _attemptTitleDecryption(
            note['title_enc'],
            noteId,
            encryptionService,
          );

          if (titleResult.success) {
            newTitle = titleResult.value;
            successfulDecryptions++;
          } else {
            // Try recovery methods
            final recoveredTitle = await _attemptTitleRecovery(
              note['title_enc'],
              noteId,
            );

            if (recoveredTitle != null) {
              newTitle = recoveredTitle;
              recoveredNotes++;
              needsUpdate = true;
            } else {
              newTitle =
                  'Recovered Note (${DateTime.now().toIso8601String().split('T')[0]})';
              failedDecryptions++;
              needsUpdate = true;
              errors.add(
                'Failed to decrypt title for note $noteId: ${titleResult.error}',
              );
            }
          }
        }

        // Try to decrypt props
        if (note['props_enc'] != null) {
          final propsResult = await _attemptPropsDecryption(
            note['props_enc'],
            noteId,
            encryptionService,
          );

          if (propsResult.success) {
            newProps = propsResult.value;
            // Don't increment successfulDecryptions again if title was already successful
            if (note['title_enc'] == null) {
              successfulDecryptions++;
            }
          } else {
            // Try recovery methods
            final recoveredProps = await _attemptPropsRecovery(
              note['props_enc'],
              noteId,
            );

            if (recoveredProps != null) {
              newProps = recoveredProps;
              if (note['title_enc'] == null) {
                recoveredNotes++;
              }
              needsUpdate = true;
            } else {
              newProps = {
                'body':
                    'This note could not be decrypted. It may have been corrupted during a previous migration.\n\nOriginal note ID: $noteId\nMigration date: ${DateTime.now().toIso8601String()}',
                'folder_id': null,
                'is_pinned': false,
                'tags': ['migration-recovery'],
              };
              if (note['title_enc'] == null) {
                failedDecryptions++;
              }
              needsUpdate = true;
              errors.add(
                'Failed to decrypt props for note $noteId: ${propsResult.error}',
              );
            }
          }
        }

        // Re-encrypt with current encryption service if recovery was needed
        if (needsUpdate && !dryRun) {
          try {
            await _reencryptNote(
              api: api,
              noteId: noteId,
              title: newTitle ?? 'Untitled Note',
              props:
                  newProps ??
                  {
                    'body': '',
                    'folder_id': null,
                    'is_pinned': false,
                    'tags': <String>[],
                  },
              encryptionService: encryptionService,
            );
            _logger.debug('Re-encrypted note $noteId with current encryption');
          } catch (reencryptError) {
            errors.add(
              'Failed to re-encrypt recovered note $noteId: $reencryptError',
            );
          }
        }
      }

      // Mark migration as completed
      if (!dryRun) {
        await prefs.setBool(migrationKey, true);
        _logger.info('Encryption migration completed successfully');
      }
    } catch (e, stack) {
      _logger.error('Migration failed', error: e, stackTrace: stack);
      errors.add('Migration failed: $e');
    }

    final result = MigrationResult(
      totalNotes: totalNotes,
      successfulDecryptions: successfulDecryptions,
      failedDecryptions: failedDecryptions,
      recoveredNotes: recoveredNotes,
      errors: errors,
    );

    _logger.info(
      'Migration ${dryRun ? 'dry run ' : ''}completed: '
      '$totalNotes total, $successfulDecryptions successful, '
      '$failedDecryptions failed, $recoveredNotes recovered, '
      '${errors.length} errors',
    );

    return result;
  }

  /// Attempt to decrypt title with current encryption service
  Future<DecryptionResult<String>> _attemptTitleDecryption(
    dynamic titleEnc,
    String noteId,
    EncryptionService encryptionService,
  ) async {
    try {
      final titleBytes = SupabaseNoteApi.asBytes(titleEnc);
      final jsonData = utf8.decode(titleBytes);
      final parsedData = jsonDecode(jsonData);

      if (parsedData is Map<String, dynamic>) {
        final encryptedData = EncryptedData.fromJson(parsedData);
        final decrypted = await encryptionService.decryptData(encryptedData);
        return DecryptionResult.success(decrypted as String);
      }

      return DecryptionResult.failure('Invalid data format');
    } catch (e) {
      return DecryptionResult.failure(e.toString());
    }
  }

  /// Attempt to decrypt props with current encryption service
  Future<DecryptionResult<Map<String, dynamic>>> _attemptPropsDecryption(
    dynamic propsEnc,
    String noteId,
    EncryptionService encryptionService,
  ) async {
    try {
      final propsBytes = SupabaseNoteApi.asBytes(propsEnc);
      final jsonData = utf8.decode(propsBytes);
      final parsedData = jsonDecode(jsonData);

      if (parsedData is Map<String, dynamic>) {
        final encryptedData = EncryptedData.fromJson(parsedData);
        final decrypted = await encryptionService.decryptData(encryptedData);
        final props = json.decode(decrypted as String) as Map<String, dynamic>;
        return DecryptionResult.success(props);
      }

      return DecryptionResult.failure('Invalid data format');
    } catch (e) {
      return DecryptionResult.failure(e.toString());
    }
  }

  /// Attempt to recover title using legacy methods
  Future<String?> _attemptTitleRecovery(dynamic titleEnc, String noteId) async {
    try {
      // Try base64 decoding (legacy format)
      final titleBytes = SupabaseNoteApi.asBytes(titleEnc);
      final base64String = String.fromCharCodes(titleBytes);
      final decodedBytes = base64Decode(base64String);
      final recovered = utf8.decode(decodedBytes);

      // Validate that it's a reasonable title
      if (recovered.isNotEmpty && recovered.length < 1000) {
        _logger.info('Recovered title for note $noteId using base64 method');
        return recovered;
      }
    } catch (e) {
      _logger.debug('Base64 recovery failed for title $noteId: $e');
    }

    try {
      // Try direct UTF-8 decoding
      final titleBytes = SupabaseNoteApi.asBytes(titleEnc);
      final recovered = utf8.decode(titleBytes);

      if (recovered.isNotEmpty && recovered.length < 1000) {
        _logger.info(
          'Recovered title for note $noteId using direct UTF-8 method',
        );
        return recovered;
      }
    } catch (e) {
      _logger.debug('Direct UTF-8 recovery failed for title $noteId: $e');
    }

    return null;
  }

  /// Attempt to recover props using legacy methods
  Future<Map<String, dynamic>?> _attemptPropsRecovery(
    dynamic propsEnc,
    String noteId,
  ) async {
    try {
      // Try base64 decoding (legacy format)
      final propsBytes = SupabaseNoteApi.asBytes(propsEnc);
      final base64String = String.fromCharCodes(propsBytes);
      final decodedBytes = base64Decode(base64String);
      final propsJson = utf8.decode(decodedBytes);
      final props = json.decode(propsJson) as Map<String, dynamic>;

      _logger.info('Recovered props for note $noteId using base64 method');
      return props;
    } catch (e) {
      _logger.debug('Base64 recovery failed for props $noteId: $e');
    }

    try {
      // Try direct JSON parsing
      final propsBytes = SupabaseNoteApi.asBytes(propsEnc);
      final propsJson = utf8.decode(propsBytes);
      final props = json.decode(propsJson) as Map<String, dynamic>;

      _logger.info('Recovered props for note $noteId using direct JSON method');
      return props;
    } catch (e) {
      _logger.debug('Direct JSON recovery failed for props $noteId: $e');
    }

    return null;
  }

  /// Re-encrypt note with current encryption service
  Future<void> _reencryptNote({
    required SupabaseNoteApi api,
    required String noteId,
    required String title,
    required Map<String, dynamic> props,
    required EncryptionService encryptionService,
  }) async {
    // Encrypt title
    final titleEncrypted = await encryptionService.encryptData(title);
    final titleBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(titleEncrypted.toJson())),
    );

    // Encrypt props
    final propsEncrypted = await encryptionService.encryptData(
      jsonEncode(props),
    );
    final propsBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(propsEncrypted.toJson())),
    );

    // Update the note
    await api.upsertEncryptedNote(
      id: noteId,
      titleEnc: titleBytes,
      propsEnc: propsBytes,
      deleted: false,
    );
  }

  /// Reset migration status (for testing)
  Future<void> resetMigrationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('encryption_migration_completed_v2');
    _logger.info('Reset encryption migration status');
  }
}
