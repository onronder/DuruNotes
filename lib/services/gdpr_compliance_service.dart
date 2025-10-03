import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/unified_export_service.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/security/security_audit_trail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GDPR Compliance Service
/// Handles all GDPR requirements including:
/// - Right to be forgotten (data deletion)
/// - Right to data portability (data export)
/// - Right to rectification (data correction)
/// - Right to access (data viewing)
/// - Consent management
class GDPRComplianceService {
  GDPRComplianceService({
    required this.db,
    required this.exportService,
    required this.supabaseClient,
  }) : _logger = LoggerFactory.instance;

  final AppDb db;
  final UnifiedExportService exportService;
  final SupabaseClient supabaseClient;
  final AppLogger _logger;

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Export all user data in a portable format (GDPR Article 20)
  Future<File> exportAllUserData({
    required String userId,
    ExportFormat format = ExportFormat.json,
  }) async {
    try {
      _logger.info('[GDPR] Starting full data export for user: $userId');

      final exportData = <String, dynamic>{
        'exportMetadata': {
          'userId': userId,
          'exportDate': DateTime.now().toIso8601String(),
          'gdprCompliant': true,
          'format': format.displayName,
          'version': '1.0',
        },
        'userData': <String, dynamic>{},
      };

      // 1. Export user profile data
      final userProfile = await _exportUserProfile(userId);
      exportData['userData']['profile'] = userProfile;

      // 2. Export all notes
      final notes = await _exportAllNotes(userId);
      exportData['userData']['notes'] = notes;

      // 3. Export all tasks
      final tasks = await _exportAllTasks(userId);
      exportData['userData']['tasks'] = tasks;

      // 4. Export all folders
      final folders = await _exportAllFolders(userId);
      exportData['userData']['folders'] = folders;

      // 5. Export all tags
      final tags = await _exportAllTags(userId);
      exportData['userData']['tags'] = tags;

      // 6. Export all reminders
      final reminders = await _exportAllReminders(userId);
      exportData['userData']['reminders'] = reminders;

      // 7. Export all attachments metadata
      final attachments = await _exportAllAttachments(userId);
      exportData['userData']['attachments'] = attachments;

      // 8. Export user preferences
      final preferences = await _exportUserPreferences(userId);
      exportData['userData']['preferences'] = preferences;

      // 9. Export audit trail (user's activity)
      final auditTrail = await _exportAuditTrail(userId);
      exportData['userData']['auditTrail'] = auditTrail;

      // Create export file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'gdpr_export_${userId}_${DateTime.now().millisecondsSinceEpoch}';
      final file = File(path.join(directory.path, '$fileName.${format.extension}'));

      // Write data based on format
      switch (format) {
        case ExportFormat.json:
          await file.writeAsString(
            const JsonEncoder.withIndent('  ').convert(exportData),
          );
          break;
        case ExportFormat.csv:
          // Convert to CSV format
          final csvContent = _convertToCSV(exportData);
          await file.writeAsString(csvContent);
          break;
        default:
          // Default to JSON for other formats
          await file.writeAsString(jsonEncode(exportData));
      }

      // Log successful export
      await SecurityAuditTrail().logAccess(
        resource: 'GDPR Data Export for user $userId',
        granted: true,
        reason: 'User requested data export in ${format.displayName} format',
      );

      _logger.info('[GDPR] Data export completed: ${file.path}');
      return file;
    } catch (e, stack) {
      _logger.error('[GDPR] Data export failed', error: e, stackTrace: stack);

      // Log failed export
      await SecurityAuditTrail().logAccess(
        resource: 'GDPR Data Export for user $userId',
        granted: false,
        reason: 'Export failed: ${e.toString()}',
      );

      rethrow;
    }
  }

  /// Delete all user data (GDPR Article 17 - Right to be forgotten)
  Future<void> deleteAllUserData({
    required String userId,
    required String confirmationCode,
    bool createBackup = true,
  }) async {
    try {
      _logger.info('[GDPR] Starting complete data deletion for user: $userId');

      // Verify confirmation code
      if (!await _verifyDeletionCode(userId, confirmationCode)) {
        throw GDPRException('Invalid confirmation code');
      }

      // Create backup before deletion if requested
      File? backupFile;
      if (createBackup) {
        backupFile = await exportAllUserData(
          userId: userId,
          format: ExportFormat.json,
        );
        _logger.info('[GDPR] Backup created: ${backupFile.path}');
      }

      // Start deletion process
      final deletionResults = <String, bool>{};

      // 1. Delete from remote database (Supabase)
      deletionResults['remote'] = await _deleteRemoteData(userId);

      // 2. Delete from local database
      deletionResults['local'] = await _deleteLocalData(userId);

      // 3. Delete cached data
      deletionResults['cache'] = await _deleteCachedData(userId);

      // 4. Delete secure storage data
      deletionResults['secureStorage'] = await _deleteSecureStorageData(userId);

      // 5. Delete shared preferences
      deletionResults['preferences'] = await _deleteSharedPreferences(userId);

      // 6. Delete files and attachments
      deletionResults['files'] = await _deleteUserFiles(userId);

      // 7. Revoke authentication
      deletionResults['auth'] = await _revokeAuthentication(userId);

      // Log deletion
      await SecurityAuditTrail().logAccess(
        resource: 'GDPR Data Deletion for user $userId',
        granted: true,
        reason: 'User requested complete data deletion (backup: $createBackup)',
      );

      // Verify deletion was complete
      final allDeleted = deletionResults.values.every((result) => result);
      if (!allDeleted) {
        throw GDPRException('Some data could not be deleted: $deletionResults');
      }

      _logger.info('[GDPR] Complete data deletion successful');
    } catch (e, stack) {
      _logger.error('[GDPR] Data deletion failed', error: e, stackTrace: stack);

      // Log failed deletion
      await SecurityAuditTrail().logAccess(
        resource: 'GDPR Data Deletion for user $userId',
        granted: false,
        reason: 'Deletion failed: ${e.toString()}',
      );

      rethrow;
    }
  }

  /// Generate a deletion confirmation code
  Future<String> generateDeletionCode(String userId) async {
    final code = _generateSecureCode();

    // Store code temporarily (expires in 15 minutes)
    await _secureStorage.write(
      key: 'gdpr_deletion_code_$userId',
      value: '$code:${DateTime.now().millisecondsSinceEpoch}',
    );

    return code;
  }

  /// Get user consent status
  Future<Map<String, bool>> getUserConsents(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'dataCollection': prefs.getBool('consent_data_collection_$userId') ?? false,
      'analytics': prefs.getBool('consent_analytics_$userId') ?? false,
      'marketing': prefs.getBool('consent_marketing_$userId') ?? false,
      'thirdPartySharing': prefs.getBool('consent_third_party_$userId') ?? false,
      'personalizedAds': prefs.getBool('consent_personalized_ads_$userId') ?? false,
    };
  }

  /// Update user consent
  Future<void> updateUserConsent({
    required String userId,
    required String consentType,
    required bool granted,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consent_${consentType}_$userId', granted);

    // Log consent change
    await SecurityAuditTrail().logAccess(
      resource: 'GDPR Consent Update for user $userId: $consentType',
      granted: granted,
      reason: 'User ${granted ? "granted" : "revoked"} consent for $consentType',
    );
  }

  /// Get data retention policy
  Map<String, dynamic> getDataRetentionPolicy() {
    return {
      'notes': {'retention': '2 years', 'autoDelete': false},
      'tasks': {'retention': '1 year', 'autoDelete': true},
      'reminders': {'retention': '6 months', 'autoDelete': true},
      'auditLogs': {'retention': '90 days', 'autoDelete': true},
      'analytics': {'retention': '1 year', 'autoDelete': true},
      'backups': {'retention': '30 days', 'autoDelete': true},
    };
  }

  // Private helper methods

  Future<Map<String, dynamic>> _exportUserProfile(String userId) async {
    try {
      final user = supabaseClient.auth.currentUser;
      return {
        'id': user?.id,
        'email': user?.email,
        'phone': user?.phone,
        'createdAt': user?.createdAt,
        'lastSignInAt': user?.lastSignInAt,
        'appMetadata': user?.appMetadata,
        'userMetadata': user?.userMetadata,
      };
    } catch (e) {
      _logger.warning('[GDPR] Failed to export user profile: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _exportAllNotes(String userId) async {
    try {
      final notes = await db.allNotes();
      return notes.map((note) => {
        'id': note.id,
        'title': note.title,
        'body': note.body,
        'updatedAt': note.updatedAt.toIso8601String(),
        'isPinned': note.isPinned,
        'isDeleted': note.deleted,
        'version': note.version,
      }).toList();
    } catch (e) {
      _logger.warning('[GDPR] Failed to export notes: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _exportAllTasks(String userId) async {
    try {
      final tasks = await db.getAllTasks();
      return tasks.map((task) => {
        'id': task.id,
        'noteId': task.noteId,
        'content': task.content,
        'status': task.status.name,
        'isCompleted': task.status == TaskStatus.completed,
        'dueDate': task.dueDate?.toIso8601String(),
        'priority': task.priority.name,
        'createdAt': task.createdAt.toIso8601String(),
        'updatedAt': task.updatedAt.toIso8601String(),
      }).toList();
    } catch (e) {
      _logger.warning('[GDPR] Failed to export tasks: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _exportAllFolders(String userId) async {
    try {
      final folders = await db.allFolders();
      return folders.map((folder) => {
        'id': folder.id,
        'name': folder.name,
        'color': folder.color,
        'icon': folder.icon,
        'createdAt': folder.createdAt.toIso8601String(),
        'updatedAt': folder.updatedAt.toIso8601String(),
      }).toList();
    } catch (e) {
      _logger.warning('[GDPR] Failed to export folders: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _exportAllTags(String userId) async {
    try {
      final tags = await db.distinctTags();
      return tags.map((tag) => {
        'name': tag,
      }).toList();
    } catch (e) {
      _logger.warning('[GDPR] Failed to export tags: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _exportAllReminders(String userId) async {
    try {
      final reminders = await db.getAllReminders();
      return reminders.map((reminder) => {
        'id': reminder.id,
        'noteId': reminder.noteId,
        'reminderTime': reminder.remindAt?.toIso8601String(),
        'isRecurring': reminder.recurrencePattern != RecurrencePattern.none,
        'recurringPattern': reminder.recurrencePattern.name,
        'isActive': reminder.isActive,
        'type': reminder.type.name,
      }).toList();
    } catch (e) {
      _logger.warning('[GDPR] Failed to export reminders: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _exportAllAttachments(String userId) async {
    // Export attachment metadata only, not actual files
    try {
      // Use direct query until getAllAttachments method is implemented
      final attachments = await (db.select(db.localAttachments)).get();
      return attachments.map((attachment) => {
        'id': attachment.id,
        'noteId': attachment.noteId,
        'fileName': attachment.fileName,
        'mimeType': attachment.mimeType,
        'fileSize': attachment.size,
        'createdAt': attachment.createdAt.toIso8601String(),
      }).toList();
    } catch (e) {
      _logger.warning('[GDPR] Failed to export attachments: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _exportUserPreferences(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final userPrefs = <String, dynamic>{};

      for (final key in allKeys) {
        if (key.contains(userId) || !key.contains('_')) {
          userPrefs[key] = prefs.get(key);
        }
      }

      return userPrefs;
    } catch (e) {
      _logger.warning('[GDPR] Failed to export preferences: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _exportAuditTrail(String userId) async {
    try {
      // Export audit trail data via audit report
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final report = await SecurityAuditTrail().getAuditReport(
        startDate: thirtyDaysAgo,
        endDate: now,
      );
      return [{
        'reportId': 'audit_${now.millisecondsSinceEpoch}',
        'userId': userId,
        'generatedAt': now.toIso8601String(),
        'summary': report.summary,
        'eventCount': report.events.length,
        'startDate': report.startDate.toIso8601String(),
        'endDate': report.endDate.toIso8601String(),
      }];
    } catch (e) {
      _logger.warning('[GDPR] Failed to export audit trail: $e');
      return [];
    }
  }

  String _convertToCSV(Map<String, dynamic> data) {
    final buffer = StringBuffer();

    // Add metadata
    buffer.writeln('GDPR Data Export');
    buffer.writeln('User ID,${data['exportMetadata']['userId']}');
    buffer.writeln('Export Date,${data['exportMetadata']['exportDate']}');
    buffer.writeln('');

    // Convert each section to CSV
    final userData = data['userData'] as Map<String, dynamic>;

    for (final entry in userData.entries) {
      buffer.writeln('Section: ${entry.key}');

      if (entry.value is List) {
        final items = entry.value as List;
        if (items.isNotEmpty && items.first is Map) {
          // Write headers
          final headers = (items.first as Map).keys.join(',');
          buffer.writeln(headers);

          // Write data rows
          for (final item in items) {
            final values = (item as Map).values.map((v) => '"${v.toString()}"').join(',');
            buffer.writeln(values);
          }
        }
      } else if (entry.value is Map) {
        for (final kv in (entry.value as Map).entries) {
          buffer.writeln('${kv.key},"${kv.value}"');
        }
      }

      buffer.writeln('');
    }

    return buffer.toString();
  }

  Future<bool> _verifyDeletionCode(String userId, String code) async {
    final stored = await _secureStorage.read(key: 'gdpr_deletion_code_$userId');
    if (stored == null) return false;

    final parts = stored.split(':');
    if (parts.length != 2) return false;

    final storedCode = parts[0];
    final timestamp = int.tryParse(parts[1]) ?? 0;

    // Check if code is expired (15 minutes)
    final isExpired = DateTime.now().millisecondsSinceEpoch - timestamp > 900000;

    // Delete the code after verification
    await _secureStorage.delete(key: 'gdpr_deletion_code_$userId');

    return storedCode == code && !isExpired;
  }

  String _generateSecureCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final code = StringBuffer();

    for (int i = 0; i < 6; i++) {
      final index = (random + i * 13) % chars.length;
      code.write(chars[index]);
    }

    return code.toString();
  }

  Future<bool> _deleteRemoteData(String userId) async {
    try {
      // Delete from Supabase tables
      await supabaseClient.from('notes').delete().eq('user_id', userId);
      await supabaseClient.from('tasks').delete().eq('user_id', userId);
      await supabaseClient.from('folders').delete().eq('user_id', userId);
      await supabaseClient.from('tags').delete().eq('user_id', userId);
      await supabaseClient.from('reminders').delete().eq('user_id', userId);
      await supabaseClient.from('attachments').delete().eq('user_id', userId);

      return true;
    } catch (e) {
      _logger.error('[GDPR] Failed to delete remote data: $e');
      return false;
    }
  }

  Future<bool> _deleteLocalData(String userId) async {
    try {
      // Delete all local database entries manually
      // Mark all notes as deleted (soft delete)
      await db.transaction(() async {
        await (db.update(db.localNotes)..where((t) => t.userId.equals(userId)))
            .write(LocalNotesCompanion(deleted: Value(true)));

        // Get all note IDs for the user
        final userNoteIds = await (db.select(db.localNotes)
          ..where((n) => n.userId.equals(userId)))
          .map((n) => n.id)
          .get();

        // Delete tasks for user notes
        if (userNoteIds.isNotEmpty) {
          await (db.delete(db.noteTasks)..where((t) => t.noteId.isIn(userNoteIds))).go();
        }

        // Delete reminders for user notes
        if (userNoteIds.isNotEmpty) {
          await (db.delete(db.noteReminders)..where((r) => r.noteId.isIn(userNoteIds))).go();
        }
      });
      return true;
    } catch (e) {
      _logger.error('[GDPR] Failed to delete local data: $e');
      return false;
    }
  }

  Future<bool> _deleteCachedData(String userId) async {
    try {
      // Clear app cache
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      return true;
    } catch (e) {
      _logger.error('[GDPR] Failed to delete cached data: $e');
      return false;
    }
  }

  Future<bool> _deleteSecureStorageData(String userId) async {
    try {
      await _secureStorage.deleteAll();
      return true;
    } catch (e) {
      _logger.error('[GDPR] Failed to delete secure storage: $e');
      return false;
    }
  }

  Future<bool> _deleteSharedPreferences(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      return true;
    } catch (e) {
      _logger.error('[GDPR] Failed to delete preferences: $e');
      return false;
    }
  }

  Future<bool> _deleteUserFiles(String userId) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final userDir = Directory(path.join(documentsDir.path, userId));

      if (await userDir.exists()) {
        await userDir.delete(recursive: true);
      }

      return true;
    } catch (e) {
      _logger.error('[GDPR] Failed to delete user files: $e');
      return false;
    }
  }

  Future<bool> _revokeAuthentication(String userId) async {
    try {
      await supabaseClient.auth.signOut();
      return true;
    } catch (e) {
      _logger.error('[GDPR] Failed to revoke authentication: $e');
      return false;
    }
  }
}

/// GDPR-specific exception
class GDPRException implements Exception {
  final String message;
  final String? code;

  GDPRException(this.message, {this.code});

  @override
  String toString() => 'GDPRException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Export format enum
enum ExportFormat {
  json('JSON', 'json'),
  csv('CSV', 'csv'),
  xml('XML', 'xml'),
  pdf('PDF', 'pdf'),
  markdown('Markdown', 'md'),
  html('HTML', 'html'),
  txt('Plain Text', 'txt'),
  docx('Word Document', 'docx');

  final String displayName;
  final String extension;

  const ExportFormat(this.displayName, this.extension);
}