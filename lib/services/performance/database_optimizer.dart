import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/providers.dart'; // Import appDbProvider from here
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Database optimization service for query performance
class DatabaseOptimizer {
  DatabaseOptimizer(this._db);

  final AppDb _db;
  final _logger = LoggerFactory.instance;

  /// Analyze and optimize database
  Future<DatabaseOptimizationResult> optimize() async {
    final startTime = DateTime.now();
    final results = <String, dynamic>{};

    try {
      // 1. Run ANALYZE to update SQLite statistics
      await _runAnalyze();
      results['analyze'] = true;

      // 2. Create missing indexes
      final indexesCreated = await _createOptimizedIndexes();
      results['indexes_created'] = indexesCreated;

      // 3. Run VACUUM to reclaim space
      final vacuumResult = await _runVacuum();
      results['vacuum'] = vacuumResult;

      // 4. Optimize query planner
      await _optimizeQueryPlanner();
      results['query_planner'] = true;

      // 5. Update statistics
      final stats = await _gatherStatistics();
      results['statistics'] = stats;

      final duration = DateTime.now().difference(startTime);

      _logger.info(
        'Database optimization completed',
        data: {'duration_ms': duration.inMilliseconds, 'results': results},
      );

      return DatabaseOptimizationResult(
        success: true,
        duration: duration,
        indexesCreated: indexesCreated,
        statistics: stats,
      );
    } catch (e, stack) {
      _logger.error(
        'Database optimization failed',
        error: e,
        stackTrace: stack,
      );
      return DatabaseOptimizationResult(
        success: false,
        duration: DateTime.now().difference(startTime),
        error: e.toString(),
      );
    }
  }

  /// Run ANALYZE command to update database statistics
  Future<void> _runAnalyze() async {
    await _db.customStatement('ANALYZE');
  }

  /// Run VACUUM to reclaim space and defragment
  Future<bool> _runVacuum() async {
    try {
      // VACUUM cannot be run in a transaction
      await _db.customStatement('VACUUM');
      return true;
    } catch (e) {
      _logger.warning(
        'VACUUM failed (may be in transaction)',
        data: {'error': e.toString()},
      );
      return false;
    }
  }

  /// Create optimized indexes for common queries
  Future<List<String>> _createOptimizedIndexes() async {
    final indexesCreated = <String>[];

    // Define optimal indexes for performance
    final indexes = [
      // Notes table indexes
      IndexDefinition(
        'idx_notes_updated_pinned',
        'local_notes(is_pinned DESC, updated_at DESC)',
        'WHERE deleted = 0',
      ),
      IndexDefinition(
        'idx_notes_deleted_updated',
        'local_notes(deleted, updated_at DESC)',
        null,
      ),

      // Note-folder relationship indexes
      IndexDefinition(
        'idx_note_folders_folder',
        'note_folders(folder_id, note_id)',
        null,
      ),
      IndexDefinition(
        'idx_note_folders_note',
        'note_folders(note_id, folder_id)',
        null,
      ),
      IndexDefinition(
        'idx_note_folders_added',
        'note_folders(added_at DESC)',
        null,
      ),

      // Folder hierarchy indexes
      IndexDefinition(
        'idx_folders_parent',
        'local_folders(parent_id, sort_order)',
        'WHERE deleted = 0',
      ),
      IndexDefinition(
        'idx_folders_path',
        'local_folders(path)',
        'WHERE deleted = 0',
      ),
      IndexDefinition(
        'idx_folders_updated',
        'local_folders(updated_at DESC)',
        'WHERE deleted = 0',
      ),
      IndexDefinition(
        'idx_folders_name',
        'local_folders(name COLLATE NOCASE)',
        'WHERE deleted = 0',
      ),

      // Tags indexes
      IndexDefinition('idx_note_tags_note', 'note_tags(note_id, tag)', null),
      IndexDefinition(
        'idx_note_tags_tag_note',
        'note_tags(tag, note_id)',
        null,
      ),

      // Saved searches indexes
      IndexDefinition(
        'idx_saved_searches_pinned',
        'saved_searches(is_pinned DESC, sort_order, usage_count DESC)',
        null,
      ),
      IndexDefinition(
        'idx_saved_searches_usage',
        'saved_searches(usage_count DESC, last_used_at DESC)',
        null,
      ),

      // Tasks indexes
      IndexDefinition('idx_tasks_note', 'note_tasks(note_id, position)', null),
      IndexDefinition(
        'idx_tasks_completed',
        'note_tasks(is_completed, note_id)',
        null,
      ),
      IndexDefinition(
        'idx_tasks_due',
        'note_tasks(due_date)',
        'WHERE due_date IS NOT NULL',
      ),

      // Reminders indexes
      IndexDefinition(
        'idx_reminders_active',
        'note_reminders(is_active, remind_at)',
        'WHERE is_active = 1',
      ),
      IndexDefinition(
        'idx_reminders_note_active',
        'note_reminders(note_id, is_active)',
        null,
      ),

      // Pending operations indexes
      IndexDefinition(
        'idx_pending_ops_created',
        'pending_ops(created_at)',
        null,
      ),
      IndexDefinition(
        'idx_pending_ops_entity_kind',
        'pending_ops(entity_id, kind)',
        null,
      ),
    ];

    // Create each index if it doesn't exist
    for (final index in indexes) {
      try {
        final whereClause =
            index.whereClause != null ? ' ${index.whereClause}' : '';
        await _db.customStatement(
          'CREATE INDEX IF NOT EXISTS ${index.name} ON ${index.definition}$whereClause',
        );
        indexesCreated.add(index.name);
      } catch (e) {
        _logger.warning(
          'Failed to create index ${index.name}',
          data: {'error': e.toString()},
        );
      }
    }

    return indexesCreated;
  }

  /// Optimize SQLite query planner settings
  Future<void> _optimizeQueryPlanner() async {
    // Set optimal PRAGMA settings for performance
    final pragmas = [
      'PRAGMA cache_size = -64000', // 64MB cache
      'PRAGMA temp_store = MEMORY', // Use memory for temp tables
      'PRAGMA mmap_size = 268435456', // 256MB memory-mapped I/O
      'PRAGMA synchronous = NORMAL', // Balance safety and speed
      'PRAGMA journal_mode = WAL', // Write-Ahead Logging
      'PRAGMA wal_autocheckpoint = 1000', // Checkpoint every 1000 pages
      'PRAGMA optimize', // Run query optimizer
    ];

    for (final pragma in pragmas) {
      try {
        await _db.customStatement(pragma);
      } catch (e) {
        _logger.warning(
          'Failed to set pragma: $pragma',
          data: {'error': e.toString()},
        );
      }
    }
  }

  /// Gather database statistics
  Future<DatabaseStatistics> _gatherStatistics() async {
    final stats = DatabaseStatistics();

    // Count records in each table
    stats.noteCount = await _countRows('local_notes', 'deleted = 0');
    stats.folderCount = await _countRows('local_folders', 'deleted = 0');
    stats.tagCount = await _countDistinct('note_tags', 'tag');
    stats.reminderCount = await _countRows('note_reminders', 'is_active = 1');
    stats.taskCount = await _countRows('note_tasks', null);
    stats.pendingOpsCount = await _countRows('pending_ops', null);

    // Get database size
    final dbInfo = await _db.customSelect('PRAGMA page_count').getSingle();
    final pageCount = dbInfo.data['page_count'] as int;
    final pageSize = await _getPageSize();
    stats.databaseSizeBytes = pageCount * pageSize;

    // Get cache statistics
    final cacheStats =
        await _db.customSelect('PRAGMA cache_stats').getSingleOrNull();
    if (cacheStats != null) {
      stats.cacheHitRate = cacheStats.data['hit_rate'] as double?;
    }

    return stats;
  }

  Future<int> _countRows(String table, String? whereClause) async {
    final where = whereClause != null ? ' WHERE $whereClause' : '';
    final result = await _db
        .customSelect('SELECT COUNT(*) as count FROM $table$where')
        .getSingle();
    return result.data['count'] as int;
  }

  Future<int> _countDistinct(String table, String column) async {
    final result = await _db
        .customSelect('SELECT COUNT(DISTINCT $column) as count FROM $table')
        .getSingle();
    return result.data['count'] as int;
  }

  Future<int> _getPageSize() async {
    final result = await _db.customSelect('PRAGMA page_size').getSingle();
    return result.data['page_size'] as int;
  }
}

/// Index definition for creating optimized indexes
class IndexDefinition {
  const IndexDefinition(this.name, this.definition, this.whereClause);

  final String name;
  final String definition;
  final String? whereClause;
}

/// Result of database optimization
class DatabaseOptimizationResult {
  const DatabaseOptimizationResult({
    required this.success,
    required this.duration,
    this.indexesCreated = const [],
    this.statistics,
    this.error,
  });

  final bool success;
  final Duration duration;
  final List<String> indexesCreated;
  final DatabaseStatistics? statistics;
  final String? error;
}

/// Database statistics
class DatabaseStatistics {
  int noteCount = 0;
  int folderCount = 0;
  int tagCount = 0;
  int reminderCount = 0;
  int taskCount = 0;
  int pendingOpsCount = 0;
  int databaseSizeBytes = 0;
  double? cacheHitRate;

  Map<String, dynamic> toJson() => {
        'note_count': noteCount,
        'folder_count': folderCount,
        'tag_count': tagCount,
        'reminder_count': reminderCount,
        'task_count': taskCount,
        'pending_ops_count': pendingOpsCount,
        'database_size_bytes': databaseSizeBytes,
        'database_size_mb':
            (databaseSizeBytes / (1024 * 1024)).toStringAsFixed(2),
        'cache_hit_rate': cacheHitRate,
      };
}

/// Provider for database optimizer
final databaseOptimizerProvider = Provider<DatabaseOptimizer>((ref) {
  final db = ref.watch(appDbProvider);
  return DatabaseOptimizer(db);
});

/// Provider for database statistics
final databaseStatisticsProvider = FutureProvider<DatabaseStatistics>((
  ref,
) async {
  final optimizer = ref.watch(databaseOptimizerProvider);
  return optimizer._gatherStatistics();
});
