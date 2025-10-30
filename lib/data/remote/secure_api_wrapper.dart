import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/core/middleware/rate_limiter.dart';
import 'package:duru_notes/core/security/security_initialization.dart';
import 'package:duru_notes/services/error_logging_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Secure wrapper for API calls with rate limiting, error handling, and monitoring
class SecureApiWrapper {
  final SupabaseNoteApi _api;
  final RateLimitingMiddleware _rateLimiter;
  final ErrorLoggingService _errorLogger;
  final String Function()? _userIdResolver;

  SecureApiWrapper(
    SupabaseClient client, {
    SupabaseNoteApi? api,
    String Function()? userIdResolver,
  }) : _api = api ?? SupabaseNoteApi(client),
       _rateLimiter = SecurityInitialization.isInitialized
           ? SecurityInitialization.rateLimiter
           : (() {
               if (kDebugMode) {
                 debugPrint(
                   '⚠️ [SecureApiWrapper] FALLBACK: Creating local RateLimitingMiddleware',
                 );
                 debugPrint(
                   '⚠️ [SecureApiWrapper] SecurityInitialization.isInitialized = false',
                 );
                 debugPrint(
                   '⚠️ [SecureApiWrapper] This indicates a race condition bug',
                 );
                 debugPrint('⚠️ [SecureApiWrapper] Stack trace:');
                 debugPrint(StackTrace.current.toString());
               }
               return RateLimitingMiddleware();
             })(),
       _errorLogger = SecurityInitialization.isInitialized
           ? SecurityInitialization.errorLogging
           : (() {
               if (kDebugMode) {
                 debugPrint(
                   '⚠️ [SecureApiWrapper] FALLBACK: Creating local ErrorLoggingService',
                 );
                 debugPrint(
                   '⚠️ [SecureApiWrapper] SecurityInitialization.isInitialized = false',
                 );
               }
               return ErrorLoggingService();
             })(),
       _userIdResolver = userIdResolver;
  // Note: SecurityInitialization must complete before SecureApiWrapper is created (app.dart:504-580)
  // If SecurityInitialization.isInitialized is false, this indicates a race condition bug
  // Diagnostic logging added to capture stack trace and timing information

  /// Testing constructor that bypasses security initialization.
  SecureApiWrapper.testing({
    required SupabaseNoteApi api,
    String Function()? userIdResolver,
  }) : _api = api,
       _rateLimiter = RateLimitingMiddleware(),
       _errorLogger = ErrorLoggingService(),
       _userIdResolver = userIdResolver;

  /// Execute API call with rate limiting and error handling
  Future<T> _executeWithProtection<T>({
    required String endpoint,
    required Future<T> Function() operation,
    Map<String, dynamic>? metadata,
  }) async {
    // Get user ID for rate limiting
    final userId = _userIdResolver?.call() ?? _api._uid;

    // Check rate limit
    final rateLimitResult = await _rateLimiter.checkRateLimit(
      identifier: userId,
      type: RateLimitType.user,
      endpoint: endpoint,
      metadata: metadata,
    );

    if (!rateLimitResult.allowed) {
      // Log rate limit violation
      _errorLogger.logWarning('Rate limit exceeded for $endpoint', {
        'userId': userId,
        'endpoint': endpoint,
        'retryAfter': rateLimitResult.retryAfter?.toIso8601String(),
        'reason': rateLimitResult.reason,
      });

      throw RateLimitException(
        message: rateLimitResult.reason ?? 'Rate limit exceeded',
        retryAfter: rateLimitResult.retryAfter,
      );
    }

    // Execute operation with error handling
    try {
      final stopwatch = Stopwatch()..start();
      final result = await operation();
      stopwatch.stop();

      // Log successful operation
      if (kDebugMode) {
        debugPrint(
          'API call to $endpoint completed in ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      return result;
    } catch (error, stack) {
      // Log error
      _errorLogger.logError(
        error,
        stack,
        category: 'API',
        metadata: {'endpoint': endpoint, 'userId': userId, ...?metadata},
      );

      // Rethrow with additional context
      if (error is PostgrestException) {
        throw ApiException(
          message: error.message,
          code: error.code,
          endpoint: endpoint,
          originalError: error,
        );
      }

      rethrow;
    }
  }

  /// Generate a new UUID string for use as an ID
  static String generateId() => SupabaseNoteApi.generateId();

  /// Upsert encrypted note with rate limiting
  ///
  /// [createdAt] should be provided for new notes to ensure timestamp consistency
  /// across all devices. For existing notes being updated, this can be null.
  Future<void> upsertEncryptedNote({
    required String id,
    required Uint8List titleEnc,
    required Uint8List propsEnc,
    required bool deleted,
    DateTime? createdAt,
  }) async {
    return _executeWithProtection(
      endpoint: '/api/notes/upsert',
      operation: () => _api.upsertEncryptedNote(
        id: id,
        titleEnc: titleEnc,
        propsEnc: propsEnc,
        deleted: deleted,
        createdAt: createdAt,
      ),
      metadata: {'noteId': id, 'deleted': deleted},
    );
  }

  /// Fetch encrypted notes with rate limiting
  Future<List<Map<String, dynamic>>> fetchEncryptedNotes({
    DateTime? since,
  }) async {
    return _executeWithProtection(
      endpoint: '/api/notes/fetch',
      operation: () => _api.fetchEncryptedNotes(since: since),
      metadata: {'since': since?.toIso8601String()},
    );
  }

  /// Fetch all active note IDs with rate limiting
  Future<Set<String>> fetchAllActiveIds() async {
    return _executeWithProtection(
      endpoint: '/api/notes/active-ids',
      operation: () => _api.fetchAllActiveIds(),
    );
  }

  /// Upsert encrypted folder with rate limiting
  Future<void> upsertEncryptedFolder({
    required String id,
    required Uint8List nameEnc,
    required Uint8List propsEnc,
    required bool deleted,
  }) async {
    return _executeWithProtection(
      endpoint: '/api/folders/upsert',
      operation: () => _api.upsertEncryptedFolder(
        id: id,
        nameEnc: nameEnc,
        propsEnc: propsEnc,
        deleted: deleted,
      ),
      metadata: {'folderId': id, 'deleted': deleted},
    );
  }

  /// Fetch encrypted folders with rate limiting
  Future<List<Map<String, dynamic>>> fetchEncryptedFolders({
    DateTime? since,
  }) async {
    return _executeWithProtection(
      endpoint: '/api/folders/fetch',
      operation: () => _api.fetchEncryptedFolders(since: since),
      metadata: {'since': since?.toIso8601String()},
    );
  }

  /// Fetch all active folder IDs with rate limiting
  Future<Set<String>> fetchAllActiveFolderIds() async {
    return _executeWithProtection(
      endpoint: '/api/folders/active-ids',
      operation: () => _api.fetchAllActiveFolderIds(),
    );
  }

  /// Upsert note-folder relationship with rate limiting
  Future<void> upsertNoteFolderRelation({
    required String noteId,
    required String folderId,
  }) async {
    return _executeWithProtection(
      endpoint: '/api/note-folders/upsert',
      operation: () =>
          _api.upsertNoteFolderRelation(noteId: noteId, folderId: folderId),
      metadata: {'noteId': noteId, 'folderId': folderId},
    );
  }

  /// Delete note-folder relationship with rate limiting
  Future<void> deleteNoteFolderRelation({
    required String noteId,
    String? folderId,
  }) async {
    return _executeWithProtection(
      endpoint: '/api/note-folders/delete',
      operation: () => _api.removeNoteFolderRelation(noteId: noteId),
      metadata: {'noteId': noteId, 'folderId': folderId},
    );
  }

  /// Fetch note-folder relations with rate limiting
  Future<List<Map<String, dynamic>>> fetchNoteFolderRelations({
    DateTime? since,
  }) async {
    return _executeWithProtection(
      endpoint: '/api/note-folders/fetch',
      operation: () => _api.fetchNoteFolderRelations(since: since),
      metadata: {'since': since?.toIso8601String()},
    );
  }

  /// Fetch all active relations with rate limiting
  Future<List<Map<String, dynamic>>> fetchAllActiveRelations() async {
    return _executeWithProtection(
      endpoint: '/api/note-folders/active-relations',
      operation: () => _api.fetchNoteFolderRelations(),
    );
  }

  /// Batch operations with rate limiting
  Future<void> batchUpsertNotes(List<Map<String, dynamic>> notes) async {
    // Apply rate limiting for batch operations
    const batchSize = 50;
    for (int i = 0; i < notes.length; i += batchSize) {
      final batch = notes.skip(i).take(batchSize).toList();

      await _executeWithProtection(
        endpoint: '/api/notes/batch-upsert',
        operation: () async {
          // Execute batch operations
          for (final note in batch) {
            await _api.upsertEncryptedNote(
              id: note['id'] as String,
              titleEnc: note['titleEnc'] as Uint8List,
              propsEnc: note['propsEnc'] as Uint8List,
              deleted: (note['deleted'] ?? false) as bool,
              createdAt: note['createdAt'] as DateTime?,
            );
          }
        },
        metadata: {'batchSize': batch.length, 'totalNotes': notes.length},
      );

      // Add delay between batches to prevent rate limiting
      if (i + batchSize < notes.length) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  /// Upsert task with rate limiting
  Future<void> upsertNoteTask({
    required String id,
    required String noteId,
    required String content,
    required String status,
    required int priority,
    required int position,
    DateTime? dueDate,
    DateTime? completedAt,
    String? parentId,
    Map<String, dynamic>? labels,
    Map<String, dynamic>? metadata,
    required bool deleted,
  }) async {
    return _executeWithProtection(
      endpoint: '/api/tasks/upsert',
      operation: () => _api.upsertNoteTask(
        id: id,
        noteId: noteId,
        content: content,
        status: status,
        priority: priority,
        position: position,
        dueDate: dueDate,
        completedAt: completedAt,
        parentId: parentId,
        labels: labels,
        metadata: metadata,
        deleted: deleted,
      ),
      metadata: {'taskId': id, 'noteId': noteId, 'deleted': deleted},
    );
  }

  /// Soft delete task with rate limiting
  Future<void> deleteNoteTask({required String id}) async {
    return _executeWithProtection(
      endpoint: '/api/tasks/delete',
      operation: () => _api.deleteNoteTask(id: id),
      metadata: {'taskId': id},
    );
  }

  /// Fetch tasks with rate limiting
  Future<List<Map<String, dynamic>>> fetchNoteTasks({DateTime? since}) async {
    return _executeWithProtection(
      endpoint: '/api/tasks/fetch',
      operation: () => _api.fetchNoteTasks(since: since),
      metadata: {'since': since?.toIso8601String()},
    );
  }

  /// Fetch active task IDs with rate limiting
  Future<Set<String>> fetchAllActiveTaskIds() async {
    return _executeWithProtection(
      endpoint: '/api/tasks/active-ids',
      operation: () => _api.fetchAllActiveTaskIds(),
    );
  }

  /// Upsert reminder with rate limiting
  Future<void> upsertReminder(Map<String, dynamic> reminderData) async {
    return _executeWithProtection(
      endpoint: '/api/reminders/upsert',
      operation: () => _api.upsertReminder(reminderData),
      metadata: {
        'reminderId': reminderData['id'],
        'noteId': reminderData['note_id'],
        'isActive': reminderData['is_active'],
      },
    );
  }

  /// Delete reminder with rate limiting
  Future<void> deleteReminder(String reminderId) async {
    return _executeWithProtection(
      endpoint: '/api/reminders/delete',
      operation: () => _api.deleteReminder(reminderId),
      metadata: {'reminderId': reminderId},
    );
  }

  /// Fetch reminders with rate limiting
  Future<List<Map<String, dynamic>>> fetchReminders() async {
    return _executeWithProtection(
      endpoint: '/api/reminders/fetch',
      operation: () => _api.getReminders(),
    );
  }

  /// Upsert template with rate limiting
  Future<void> upsertTemplate({
    required String id,
    required String userId,
    required String titleEnc,
    required String bodyEnc,
    String? tagsEnc,
    required bool isSystem,
    required String category,
    String? descriptionEnc,
    String? icon,
    int sortOrder = 0,
    String? propsEnc,
    required bool deleted,
  }) async {
    return _executeWithProtection(
      endpoint: '/api/templates/upsert',
      operation: () => _api.upsertTemplate(
        id: id,
        userId: userId,
        titleEnc: titleEnc,
        bodyEnc: bodyEnc,
        tagsEnc: tagsEnc,
        isSystem: isSystem,
        category: category,
        descriptionEnc: descriptionEnc,
        icon: icon,
        sortOrder: sortOrder,
        propsEnc: propsEnc,
        deleted: deleted,
      ),
      metadata: {
        'templateId': id,
        'userId': userId,
        'deleted': deleted,
        'isSystem': isSystem,
      },
    );
  }

  /// Soft delete template with rate limiting
  Future<void> deleteTemplate({required String id}) async {
    return _executeWithProtection(
      endpoint: '/api/templates/delete',
      operation: () => _api.deleteTemplate(id: id),
      metadata: {'templateId': id},
    );
  }

  /// Fetch templates with rate limiting
  Future<List<Map<String, dynamic>>> fetchTemplates({DateTime? since}) async {
    return _executeWithProtection(
      endpoint: '/api/templates/fetch',
      operation: () => _api.fetchTemplates(since: since),
      metadata: {'since': since?.toIso8601String()},
    );
  }
}

/// Custom exception for rate limit violations
class RateLimitException implements Exception {
  final String message;
  final DateTime? retryAfter;

  RateLimitException({required this.message, this.retryAfter});

  @override
  String toString() =>
      'RateLimitException: $message${retryAfter != null ? ' (Retry after: $retryAfter)' : ''}';
}

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final String? code;
  final String endpoint;
  final dynamic originalError;

  ApiException({
    required this.message,
    this.code,
    required this.endpoint,
    this.originalError,
  });

  @override
  String toString() =>
      'ApiException [$endpoint]: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Extension to make SupabaseNoteApi private members accessible
extension SupabaseNoteApiAccess on SupabaseNoteApi {
  String get _uid {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw StateError('Not authenticated');
    }
    return uid;
  }
}
