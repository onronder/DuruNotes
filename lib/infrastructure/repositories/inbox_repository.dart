import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/inbox_item.dart' as domain;
import 'package:duru_notes/domain/repositories/i_inbox_repository.dart';
import 'package:duru_notes/infrastructure/mappers/inbox_item_mapper.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:drift/drift.dart';

/// Implementation of IInboxRepository using the local database
class InboxRepository implements IInboxRepository {
  InboxRepository({
    required AppDb db,
  })  : _db = db,
        _logger = LoggerFactory.instance;

  final AppDb _db;
  final AppLogger _logger;

  @override
  Future<domain.InboxItem?> getById(String id) async {
    try {
      final query = _db.select<$InboxItemsTable, InboxItem>(_db.inboxItems)
        ..where((i) => i.id.equals(id));
      final result = await query.getSingleOrNull();
      return result != null ? InboxItemMapper.toDomain(result) : null;
    } catch (e, stack) {
      _logger.error('Failed to get inbox item by id: $id', error: e, stackTrace: stack);
      return null;
    }
  }

  @override
  Future<List<domain.InboxItem>> getUnprocessed() async {
    try {
      final query = _db.select<$InboxItemsTable, InboxItem>(_db.inboxItems)
        ..where((i) => i.isProcessed.equals(false))
        ..orderBy([(i) => OrderingTerm.desc(i.createdAt)]);
      final results = await query.get();
      return results.map<domain.InboxItem>(InboxItemMapper.toDomain).toList();
    } catch (e, stack) {
      _logger.error('Failed to get unprocessed inbox items', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<List<domain.InboxItem>> getBySourceType(String sourceType) async {
    try {
      final query = _db.select<$InboxItemsTable, InboxItem>(_db.inboxItems)
        ..where((i) => i.sourceType.equals(sourceType))
        ..orderBy([(i) => OrderingTerm.desc(i.createdAt)]);
      final results = await query.get();
      return results.map<domain.InboxItem>(InboxItemMapper.toDomain).toList();
    } catch (e, stack) {
      _logger.error('Failed to get inbox items by source type: $sourceType', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<List<domain.InboxItem>> getByDateRange(DateTime start, DateTime end) async {
    try {
      final query = _db.select<$InboxItemsTable, InboxItem>(_db.inboxItems)
        ..where((i) => i.createdAt.isBetweenValues(start, end))
        ..orderBy([(i) => OrderingTerm.desc(i.createdAt)]);

      final results = await query.get();
      return results.map<domain.InboxItem>(InboxItemMapper.toDomain).toList();
    } catch (e, stack) {
      _logger.error('Failed to get inbox items by date range', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<domain.InboxItem> create(domain.InboxItem item) async {
    try {
      final companion = InboxItemMapper.toCompanion(item);
      await _db.into<$InboxItemsTable, InboxItem>(_db.inboxItems).insert(companion);
      _logger.info('Created inbox item: ${item.id}');
      return item;
    } catch (e, stack) {
      _logger.error('Failed to create inbox item', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<domain.InboxItem> update(domain.InboxItem item) async {
    try {
      final companion = InboxItemMapper.toUpdateCompanion(item);

      final rows = await (_db.update<$InboxItemsTable, InboxItem>(_db.inboxItems)
        ..where((i) => i.id.equals(item.id)))
        .write(companion);

      if (rows > 0) {
        _logger.info('Updated inbox item: ${item.id}');
        return item;
      } else {
        throw Exception('Inbox item not found: ${item.id}');
      }
    } catch (e, stack) {
      _logger.error('Failed to update inbox item: ${item.id}', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> markAsProcessed(String id, {String? noteId}) async {
    try {
      final companion = InboxItemsCompanion(
        isProcessed: const Value(true),
        noteId: Value(noteId),
      );

      final rows = await (_db.update<$InboxItemsTable, InboxItem>(_db.inboxItems)
        ..where((i) => i.id.equals(id)))
        .write(companion);

      if (rows > 0) {
        _logger.info('Marked inbox item as processed: $id');
      } else {
        _logger.warning('Inbox item not found for marking as processed: $id');
      }
    } catch (e, stack) {
      _logger.error('Failed to mark inbox item as processed: $id', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      final rows = await (_db.delete<$InboxItemsTable, InboxItem>(_db.inboxItems)
        ..where((i) => i.id.equals(id)))
        .go();

      if (rows > 0) {
        _logger.info('Deleted inbox item: $id');
      } else {
        _logger.warning('Inbox item not found for deletion: $id');
      }
    } catch (e, stack) {
      _logger.error('Failed to delete inbox item: $id', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> deleteProcessed({int? olderThanDays}) async {
    try {
      var query = _db.delete<$InboxItemsTable, InboxItem>(_db.inboxItems)
        ..where((i) => i.isProcessed.equals(true));

      if (olderThanDays != null) {
        final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));
        query = query..where((i) => i.createdAt.isSmallerThanValue(cutoff));
      }

      final rows = await query.go();
      _logger.info('Deleted $rows processed inbox items');
    } catch (e, stack) {
      _logger.error('Failed to delete processed inbox items', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<int> getUnprocessedCount() async {
    try {
      final countExp = _db.inboxItems.id.count();
      final query = _db.selectOnly<$InboxItemsTable, InboxItem>(_db.inboxItems)
        ..addColumns([countExp])
        ..where(_db.inboxItems.isProcessed.equals(false));

      final result = await query.getSingleOrNull();
      return result?.read(countExp) ?? 0;
    } catch (e, stack) {
      _logger.error('Failed to get unprocessed count', error: e, stackTrace: stack);
      return 0;
    }
  }

  @override
  Stream<List<domain.InboxItem>> watchUnprocessed() {
    try {
      final query = _db.select<$InboxItemsTable, InboxItem>(_db.inboxItems)
        ..where((i) => i.isProcessed.equals(false))
        ..orderBy([(i) => OrderingTerm.desc(i.createdAt)]);

      return query.watch().map((items) =>
          items.map<domain.InboxItem>(InboxItemMapper.toDomain).toList());
    } catch (e, stack) {
      _logger.error('Failed to watch unprocessed inbox items', error: e, stackTrace: stack);
      return Stream.value([]);
    }
  }

  @override
  Stream<int> watchUnprocessedCount() {
    try {
      final countExp = _db.inboxItems.id.count();
      final query = _db.selectOnly<$InboxItemsTable, InboxItem>(_db.inboxItems)
        ..addColumns([countExp])
        ..where(_db.inboxItems.isProcessed.equals(false));

      return query.watchSingleOrNull().map((result) =>
          result?.read(countExp) ?? 0);
    } catch (e, stack) {
      _logger.error('Failed to watch unprocessed count', error: e, stackTrace: stack);
      return Stream.value(0);
    }
  }

  @override
  Future<void> processItem(String id, String noteId) async {
    try {
      await markAsProcessed(id, noteId: noteId);
    } catch (e, stack) {
      _logger.error('Failed to process inbox item: $id', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<Map<String, int>> getStatsBySourceType() async {
    try {
      final results = await _db.customSelect(
        '''SELECT source_type, COUNT(*) as count
           FROM inbox_items
           GROUP BY source_type''',
        readsFrom: {_db.inboxItems},
      ).get();

      final stats = <String, int>{};
      for (final row in results) {
        stats[row.read<String>('source_type')] = row.read<int>('count');
      }

      return stats;
    } catch (e, stack) {
      _logger.error('Failed to get inbox stats by source type', error: e, stackTrace: stack);
      return {};
    }
  }

  @override
  Future<void> cleanupOldItems({required int daysToKeep}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));
      final rows = await (_db.delete<$InboxItemsTable, InboxItem>(_db.inboxItems)
        ..where((i) => i.createdAt.isSmallerThanValue(cutoff)))
        .go();

      _logger.info('Cleaned up $rows old inbox items');
    } catch (e, stack) {
      _logger.error('Failed to cleanup old inbox items', error: e, stackTrace: stack);
    }
  }
}