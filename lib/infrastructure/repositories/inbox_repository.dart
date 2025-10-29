import 'dart:async';

import 'package:duru_notes/domain/entities/inbox_item.dart' as domain;
import 'package:duru_notes/domain/repositories/i_inbox_repository.dart';
import 'package:duru_notes/infrastructure/mappers/inbox_item_mapper.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Repository for managing inbox items from Supabase clipper_inbox table.
///
/// Inbox items are temporary content from various sources (email, web clips)
/// that need to be processed into notes. They are stored in Supabase's
/// clipper_inbox table, not in the local database.
///
/// NOTE: This repository does NOT use encryption because:
/// 1. Inbox items are temporary (deleted after conversion to notes)
/// 2. The notes created from inbox items ARE encrypted
/// 3. Supabase provides secure storage via RLS policies
class InboxRepository implements IInboxRepository {
  InboxRepository({required SupabaseClient client})
    : _client = client,
      _logger = LoggerFactory.instance;

  final SupabaseClient _client;
  final AppLogger _logger;

  void _captureRepositoryException({
    required String method,
    required Object error,
    required StackTrace stackTrace,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.error,
  }) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.level = level;
          scope.setTag('layer', 'repository');
          scope.setTag('repository', 'InboxRepository');
          scope.setTag('method', method);
          if (data != null && data.isNotEmpty) {
            scope.setContexts('payload', data);
          }
        },
      ),
    );
  }

  /// Name of the Supabase table
  static const String _tableName = 'clipper_inbox';

  @override
  Future<domain.InboxItem?> getById(String id) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _logger.warning('Cannot get inbox item without authenticated user');
        return null;
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('id', id)
          .eq('user_id', userId) // Security: enforce user isolation
          .maybeSingle();

      if (response == null) return null;

      return InboxItemMapper.fromJson(response);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get inbox item by id',
        error: e,
        stackTrace: stackTrace,
        data: {'id': id},
      );
      _captureRepositoryException(
        method: 'getById',
        error: e,
        stackTrace: stackTrace,
        data: {'id': id},
      );
      return null;
    }
  }

  @override
  Future<List<domain.InboxItem>> getUnprocessed() async {
    try {
      final userId = _client.auth.currentUser?.id;

      if (userId == null || userId.isEmpty) {
        _logger.warning(
          'Cannot get unprocessed items without authenticated user',
        );
        return const <domain.InboxItem>[];
      }

      _logger.debug(
        'Fetching unprocessed inbox items',
        data: {'userId': userId},
      );

      final response = await _client
          .from(_tableName)
          .select()
          .eq('user_id', userId) // Security: enforce user isolation
          .filter('converted_to_note_id', 'is', 'null')
          .order('created_at', ascending: false);

      final results = (response as List)
          .map((json) => InboxItemMapper.fromJson(json as Map<String, dynamic>))
          .toList();

      _logger.debug(
        'Fetched unprocessed inbox items',
        data: {'count': results.length},
      );

      return results;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get unprocessed inbox items',
        error: e,
        stackTrace: stackTrace,
      );
      _captureRepositoryException(
        method: 'getUnprocessed',
        error: e,
        stackTrace: stackTrace,
      );
      return const <domain.InboxItem>[];
    }
  }

  @override
  Future<List<domain.InboxItem>> getBySourceType(String sourceType) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _logger.warning(
          'Cannot get items by source type without authenticated user',
        );
        return const <domain.InboxItem>[];
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('user_id', userId) // Security: enforce user isolation
          .eq('source_type', sourceType)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => InboxItemMapper.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get inbox items by source type',
        error: e,
        stackTrace: stackTrace,
        data: {'sourceType': sourceType},
      );
      _captureRepositoryException(
        method: 'getBySourceType',
        error: e,
        stackTrace: stackTrace,
        data: {'sourceType': sourceType},
      );
      return const <domain.InboxItem>[];
    }
  }

  @override
  Future<List<domain.InboxItem>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _logger.warning(
          'Cannot get items by date range without authenticated user',
        );
        return const <domain.InboxItem>[];
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('user_id', userId) // Security: enforce user isolation
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => InboxItemMapper.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get inbox items by date range',
        error: e,
        stackTrace: stackTrace,
        data: {'start': start.toIso8601String(), 'end': end.toIso8601String()},
      );
      _captureRepositoryException(
        method: 'getByDateRange',
        error: e,
        stackTrace: stackTrace,
        data: {'start': start.toIso8601String(), 'end': end.toIso8601String()},
      );
      return const <domain.InboxItem>[];
    }
  }

  @override
  Future<domain.InboxItem> create(domain.InboxItem item) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        final authorizationError = StateError(
          'Cannot create inbox item without authenticated user',
        );
        _logger.warning('Cannot create inbox item without authenticated user');
        _captureRepositoryException(
          method: 'create',
          error: authorizationError,
          stackTrace: StackTrace.current,
          level: SentryLevel.warning,
        );
        throw authorizationError;
      }

      // Ensure user_id matches current user (security)
      final itemToCreate = item.userId != userId
          ? item.copyWith(userId: userId)
          : item;

      final json = InboxItemMapper.toJson(itemToCreate);

      await _client.from(_tableName).insert(json);

      _logger.info(
        'Created inbox item',
        data: {'id': item.id, 'sourceType': item.sourceType},
      );

      return itemToCreate;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create inbox item',
        error: e,
        stackTrace: stackTrace,
        data: {'id': item.id, 'sourceType': item.sourceType},
      );
      _captureRepositoryException(
        method: 'create',
        error: e,
        stackTrace: stackTrace,
        data: {'id': item.id, 'sourceType': item.sourceType},
      );
      rethrow;
    }
  }

  @override
  Future<domain.InboxItem> update(domain.InboxItem item) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        final authorizationError = StateError(
          'Cannot update inbox item without authenticated user',
        );
        _logger.warning('Cannot update inbox item without authenticated user');
        _captureRepositoryException(
          method: 'update',
          error: authorizationError,
          stackTrace: StackTrace.current,
          level: SentryLevel.warning,
        );
        throw authorizationError;
      }

      final json = InboxItemMapper.toJson(item);

      await _client
          .from(_tableName)
          .update(json)
          .eq('id', item.id)
          .eq('user_id', userId); // Security: enforce user isolation

      _logger.info('Updated inbox item', data: {'id': item.id});

      return item;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update inbox item',
        error: e,
        stackTrace: stackTrace,
        data: {'id': item.id},
      );
      _captureRepositoryException(
        method: 'update',
        error: e,
        stackTrace: stackTrace,
        data: {'id': item.id},
      );
      rethrow;
    }
  }

  @override
  Future<void> markAsProcessed(String id, {String? noteId}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _logger.warning(
          'Cannot mark item as processed without authenticated user',
        );
        return;
      }

      await _client
          .from(_tableName)
          .update({
            'converted_to_note_id': noteId,
            'converted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .eq('user_id', userId); // Security: enforce user isolation

      _logger.info(
        'Marked inbox item as processed',
        data: {'id': id, 'noteId': noteId},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to mark inbox item as processed',
        error: e,
        stackTrace: stackTrace,
        data: {'id': id, 'noteId': noteId},
      );
      _captureRepositoryException(
        method: 'markAsProcessed',
        error: e,
        stackTrace: stackTrace,
        data: {'id': id, 'noteId': noteId},
      );
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _logger.warning('Cannot delete inbox item without authenticated user');
        return;
      }

      await _client
          .from(_tableName)
          .delete()
          .eq('id', id)
          .eq('user_id', userId); // Security: enforce user isolation

      _logger.info('Deleted inbox item', data: {'id': id});
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete inbox item',
        error: e,
        stackTrace: stackTrace,
        data: {'id': id},
      );
      _captureRepositoryException(
        method: 'delete',
        error: e,
        stackTrace: stackTrace,
        data: {'id': id},
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteProcessed({int? olderThanDays}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _logger.warning(
          'Cannot delete processed items without authenticated user',
        );
        return;
      }

      var query = _client
          .from(_tableName)
          .delete()
          .eq('user_id', userId) // Security: enforce user isolation
          .not('converted_to_note_id', 'is', 'null');

      if (olderThanDays != null) {
        final cutoffDate = DateTime.now().subtract(
          Duration(days: olderThanDays),
        );
        query = query.lt('converted_at', cutoffDate.toIso8601String());
      }

      await query;

      _logger.info(
        'Deleted processed inbox items',
        data: {'olderThanDays': olderThanDays},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete processed inbox items',
        error: e,
        stackTrace: stackTrace,
        data: {'olderThanDays': olderThanDays},
      );
      _captureRepositoryException(
        method: 'deleteProcessed',
        error: e,
        stackTrace: stackTrace,
        data: {'olderThanDays': olderThanDays},
      );
      rethrow;
    }
  }

  @override
  Future<int> getUnprocessedCount() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _logger.warning(
          'Cannot get unprocessed count without authenticated user',
        );
        return 0;
      }

      final response = await _client
          .from(_tableName)
          .select('id')
          .eq('user_id', userId) // Security: enforce user isolation
          .filter('converted_to_note_id', 'is', 'null');

      return (response as List).length;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get unprocessed count',
        error: e,
        stackTrace: stackTrace,
      );
      _captureRepositoryException(
        method: 'getUnprocessedCount',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  @override
  Stream<List<domain.InboxItem>> watchUnprocessed() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _logger.warning(
        'Cannot watch unprocessed items without authenticated user',
      );
      return Stream.value([]);
    }

    try {
      return _client
          .from(_tableName)
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .map((data) {
            try {
              final items = (data as List)
                  .map(
                    (json) =>
                        InboxItemMapper.fromJson(json as Map<String, dynamic>),
                  )
                  .toList();
              return items.where((item) => !item.isProcessed).toList();
            } catch (error, stackTrace) {
              _logger.error(
                'Failed to map unprocessed inbox items stream',
                error: error,
                stackTrace: stackTrace,
                data: {'userId': userId},
              );
              _captureRepositoryException(
                method: 'watchUnprocessed.map',
                error: error,
                stackTrace: stackTrace,
                data: {'userId': userId},
              );
              return const <domain.InboxItem>[];
            }
          });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create watch stream for unprocessed items',
        error: e,
        stackTrace: stackTrace,
      );
      _captureRepositoryException(
        method: 'watchUnprocessed',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return Stream<List<domain.InboxItem>>.error(e, stackTrace);
    }
  }

  @override
  Stream<int> watchUnprocessedCount() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _logger.warning(
        'Cannot watch unprocessed count without authenticated user',
      );
      return Stream.value(0);
    }

    try {
      // Note: Supabase stream doesn't support .or() filters
      // We filter in-memory after receiving the data
      return _client
          .from(_tableName)
          .stream(primaryKey: ['id'])
          .eq('user_id', userId) // Security: enforce user isolation
          .map((data) {
            try {
              final items = (data as List)
                  .map(
                    (json) =>
                        InboxItemMapper.fromJson(json as Map<String, dynamic>),
                  )
                  .toList();
              return items.where((item) => !item.isProcessed).length;
            } catch (error, stackTrace) {
              _logger.error(
                'Failed to map unprocessed count stream',
                error: error,
                stackTrace: stackTrace,
                data: {'userId': userId},
              );
              _captureRepositoryException(
                method: 'watchUnprocessedCount.map',
                error: error,
                stackTrace: stackTrace,
                data: {'userId': userId},
              );
              return 0;
            }
          });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create watch stream for unprocessed count',
        error: e,
        stackTrace: stackTrace,
      );
      _captureRepositoryException(
        method: 'watchUnprocessedCount',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return Stream<int>.error(e, stackTrace);
    }
  }

  @override
  Future<void> processItem(String id, String noteId) async {
    await markAsProcessed(id, noteId: noteId);
  }

  @override
  Future<Map<String, int>> getStatsBySourceType() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _logger.warning('Cannot get stats without authenticated user');
        return {};
      }

      // Get all items for current user
      final response = await _client
          .from(_tableName)
          .select('source_type')
          .eq('user_id', userId); // Security: enforce user isolation

      // Count by source type
      final stats = <String, int>{};
      for (final item in response as List) {
        final sourceType = item['source_type'] as String;
        stats[sourceType] = (stats[sourceType] ?? 0) + 1;
      }

      return stats;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get stats by source type',
        error: e,
        stackTrace: stackTrace,
      );
      _captureRepositoryException(
        method: 'getStatsBySourceType',
        error: e,
        stackTrace: stackTrace,
      );
      return const <String, int>{};
    }
  }

  @override
  Future<void> cleanupOldItems({required int daysToKeep}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _logger.warning('Cannot cleanup old items without authenticated user');
        return;
      }

      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      await _client
          .from(_tableName)
          .delete()
          .eq('user_id', userId) // Security: enforce user isolation
          .lt('created_at', cutoffDate.toIso8601String());

      _logger.info(
        'Cleaned up old inbox items',
        data: {'daysToKeep': daysToKeep},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to cleanup old items',
        error: e,
        stackTrace: stackTrace,
        data: {'daysToKeep': daysToKeep},
      );
      _captureRepositoryException(
        method: 'cleanupOldItems',
        error: e,
        stackTrace: stackTrace,
        data: {'daysToKeep': daysToKeep},
      );
      rethrow;
    }
  }
}
