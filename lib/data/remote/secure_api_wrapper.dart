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

  SecureApiWrapper(SupabaseClient client)
      : _api = SupabaseNoteApi(client),
        _rateLimiter = SecurityInitialization.rateLimiter,
        _errorLogger = SecurityInitialization.errorLogging;

  /// Execute API call with rate limiting and error handling
  Future<T> _executeWithProtection<T>({
    required String endpoint,
    required Future<T> Function() operation,
    Map<String, dynamic>? metadata,
  }) async {
    // Get user ID for rate limiting
    final userId = _api._uid;

    // Check rate limit
    final rateLimitResult = await _rateLimiter.checkRateLimit(
      identifier: userId,
      type: RateLimitType.user,
      endpoint: endpoint,
      metadata: metadata,
    );

    if (!rateLimitResult.allowed) {
      // Log rate limit violation
      _errorLogger.logWarning(
        'Rate limit exceeded for $endpoint',
        {
          'userId': userId,
          'endpoint': endpoint,
          'retryAfter': rateLimitResult.retryAfter?.toIso8601String(),
          'reason': rateLimitResult.reason,
        },
      );

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
        debugPrint('API call to $endpoint completed in ${stopwatch.elapsedMilliseconds}ms');
      }

      return result;
    } catch (error, stack) {
      // Log error
      _errorLogger.logError(
        error,
        stack,
        category: 'API',
        metadata: {
          'endpoint': endpoint,
          'userId': userId,
          ...?metadata,
        },
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
  Future<void> upsertEncryptedNote({
    required String id,
    required Uint8List titleEnc,
    required Uint8List propsEnc,
    required bool deleted,
  }) async {
    return _executeWithProtection(
      endpoint: '/api/notes/upsert',
      operation: () => _api.upsertEncryptedNote(
        id: id,
        titleEnc: titleEnc,
        propsEnc: propsEnc,
        deleted: deleted,
      ),
      metadata: {
        'noteId': id,
        'deleted': deleted,
      },
    );
  }

  /// Fetch encrypted notes with rate limiting
  Future<List<Map<String, dynamic>>> fetchEncryptedNotes({
    DateTime? since,
  }) async {
    return _executeWithProtection(
      endpoint: '/api/notes/fetch',
      operation: () => _api.fetchEncryptedNotes(since: since),
      metadata: {
        'since': since?.toIso8601String(),
      },
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
      metadata: {
        'folderId': id,
        'deleted': deleted,
      },
    );
  }

  /// Fetch encrypted folders with rate limiting
  Future<List<Map<String, dynamic>>> fetchEncryptedFolders({
    DateTime? since,
  }) async {
    return _executeWithProtection(
      endpoint: '/api/folders/fetch',
      operation: () => _api.fetchEncryptedFolders(since: since),
      metadata: {
        'since': since?.toIso8601String(),
      },
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
      operation: () => _api.upsertNoteFolderRelation(
        noteId: noteId,
        folderId: folderId,
      ),
      metadata: {
        'noteId': noteId,
        'folderId': folderId,
      },
    );
  }

  /// Delete note-folder relationship with rate limiting
  Future<void> deleteNoteFolderRelation({
    required String noteId,
    required String folderId,
  }) async {
    return _executeWithProtection(
      endpoint: '/api/note-folders/delete',
      operation: () => _api.deleteNoteFolderRelation(
        noteId: noteId,
        folderId: folderId,
      ),
      metadata: {
        'noteId': noteId,
        'folderId': folderId,
      },
    );
  }

  /// Fetch note-folder relations with rate limiting
  Future<List<Map<String, dynamic>>> fetchNoteFolderRelations({
    DateTime? since,
  }) async {
    return _executeWithProtection(
      endpoint: '/api/note-folders/fetch',
      operation: () => _api.fetchNoteFolderRelations(since: since),
      metadata: {
        'since': since?.toIso8601String(),
      },
    );
  }

  /// Fetch all active relations with rate limiting
  Future<List<Map<String, dynamic>>> fetchAllActiveRelations() async {
    return _executeWithProtection(
      endpoint: '/api/note-folders/active-relations',
      operation: () => _api.fetchAllActiveRelations(),
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
            );
          }
        },
        metadata: {
          'batchSize': batch.length,
          'totalNotes': notes.length,
        },
      );

      // Add delay between batches to prevent rate limiting
      if (i + batchSize < notes.length) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }
}

/// Custom exception for rate limit violations
class RateLimitException implements Exception {
  final String message;
  final DateTime? retryAfter;

  RateLimitException({
    required this.message,
    this.retryAfter,
  });

  @override
  String toString() => 'RateLimitException: $message${retryAfter != null ? ' (Retry after: $retryAfter)' : ''}';
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
  String toString() => 'ApiException [$endpoint]: $message${code != null ? ' (Code: $code)' : ''}';
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