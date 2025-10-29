import 'package:drift/drift.dart';
import 'package:duru_notes/data/local/app_db.dart';

/// Verification utility for performance optimization indexes
///
/// This utility verifies that all critical indexes from Migration 27
/// are properly created and provides detailed reporting.
class IndexVerifier {
  final AppDb db;

  IndexVerifier(this.db);

  /// All expected indexes from Migration 27
  static const expectedIndexes = [
    // Batch loading optimization
    'idx_note_tags_batch_load',
    'idx_note_links_batch_load',
    'idx_note_folders_batch_load',

    // Composite indexes for common queries
    'idx_notes_user_updated_composite',
    'idx_notes_pinned_updated',
    'idx_note_folders_folder_updated',

    // Task query optimization
    'idx_tasks_note_status_composite',
    'idx_tasks_status_due_composite',
    'idx_tasks_priority_due',

    // Search optimization
    'idx_notes_search_metadata',
    'idx_note_tags_tag_search',

    // Folder hierarchy optimization
    'idx_folders_hierarchy_path',
    'idx_folders_root',

    // Sync optimization
    'idx_pending_ops_entity',
    'idx_notes_version_updated',

    // Reminder optimization
    'idx_reminders_active',
    'idx_reminders_note_active',
  ];

  /// Verify all performance indexes exist
  Future<IndexVerificationResult> verifyAll() async {
    final result = IndexVerificationResult();

    try {
      // Get all indexes from database
      final indexQuery = await db.customSelect(
        "SELECT name, sql FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'",
      ).get();

      final existingIndexes = indexQuery.map((row) => row.read<String>('name')).toSet();

      // Check each expected index
      for (final expectedIndex in expectedIndexes) {
        if (existingIndexes.contains(expectedIndex)) {
          result.addSuccess(expectedIndex);
        } else {
          result.addMissing(expectedIndex);
        }
      }

      // Find any extra indexes (not in our expected list)
      for (final existingIndex in existingIndexes) {
        if (!expectedIndexes.contains(existingIndex)) {
          result.addExtra(existingIndex);
        }
      }

      result.totalExpected = expectedIndexes.length;
      result.totalFound = result.successIndexes.length;

    } catch (e) {
      result.error = e.toString();
    }

    return result;
  }

  /// Verify critical indexes (minimum set for performance)
  Future<bool> verifyCritical() async {
    final criticalIndexes = [
      'idx_note_tags_batch_load',
      'idx_note_links_batch_load',
      'idx_note_folders_batch_load',
      'idx_notes_user_updated_composite',
      'idx_tasks_note_status_composite',
    ];

    for (final indexName in criticalIndexes) {
      final exists = await db.customSelect(
        "SELECT 1 FROM sqlite_master WHERE type='index' AND name=?",
        variables: [Variable.withString(indexName)],
      ).getSingleOrNull();

      if (exists == null) {
        return false;
      }
    }

    return true;
  }

  /// Get detailed index information
  Future<Map<String, IndexInfo>> getIndexDetails() async {
    final details = <String, IndexInfo>{};

    try {
      final indexQuery = await db.customSelect(
        "SELECT name, tbl_name, sql FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'",
      ).get();

      for (final row in indexQuery) {
        final name = row.read<String>('name');
        final tableName = row.read<String>('tbl_name');
        final sql = row.readNullable<String>('sql') ?? 'AUTO INDEX';

        details[name] = IndexInfo(
          name: name,
          tableName: tableName,
          sql: sql,
          isExpected: expectedIndexes.contains(name),
        );
      }
    } catch (e) {
      // Handle error
    }

    return details;
  }

  /// Analyze index usage for a specific query
  Future<QueryAnalysis> analyzeQuery(String query) async {
    final analysis = QueryAnalysis(query: query);

    try {
      // Get query plan
      final plan = await db.customSelect(
        'EXPLAIN QUERY PLAN $query',
      ).get();

      analysis.queryPlan = plan.map((row) => row.data.toString()).toList();

      // Check if indexes are used
      final planText = plan.map((row) => row.data.toString()).join(' ');
      analysis.usesIndex = planText.contains('USING INDEX');
      analysis.scanType = planText.contains('SCAN TABLE') ? 'full_scan' : 'index_scan';

      // Extract index names used
      final indexMatches = RegExp(r'USING INDEX (\w+)').allMatches(planText);
      analysis.indexesUsed = indexMatches.map((m) => m.group(1)!).toList();

    } catch (e) {
      analysis.error = e.toString();
    }

    return analysis;
  }

  /// Get performance statistics
  Future<PerformanceStats> getPerformanceStats() async {
    final stats = PerformanceStats();

    try {
      // Count custom indexes
      final indexCount = await db.customSelect(
        "SELECT COUNT(*) as count FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'",
      ).getSingle();
      stats.customIndexCount = indexCount.read<int>('count');

      // Get table row counts
      final tables = {
        'local_notes': 'notes',
        'note_tasks': 'tasks',
        'local_folders': 'folders',
        'note_tags': 'tags',
        'note_links': 'links',
      };

      for (final entry in tables.entries) {
        try {
          final count = await db.customSelect(
            'SELECT COUNT(*) as count FROM ${entry.key}',
          ).getSingle();
          stats.tableCounts[entry.value] = count.read<int>('count');
        } catch (_) {
          stats.tableCounts[entry.value] = 0;
        }
      }

      // Get database size
      final pageCount = await db.customSelect('PRAGMA page_count').getSingle();
      final pageSize = await db.customSelect('PRAGMA page_size').getSingle();
      stats.databaseSizeBytes = pageCount.read<int>('page_count') * pageSize.read<int>('page_size');

      stats.timestamp = DateTime.now();

    } catch (e) {
      stats.error = e.toString();
    }

    return stats;
  }

  /// Print verification report to console
  Future<void> printVerificationReport() async {
    print('\n=== DATABASE INDEX VERIFICATION REPORT ===\n');

    final result = await verifyAll();
    final stats = await getPerformanceStats();

    print('Schema Version: ${db.schemaVersion}');
    print('Expected Indexes: ${result.totalExpected}');
    print('Found Indexes: ${result.totalFound}');
    print('Status: ${result.isComplete ? "✅ COMPLETE" : "❌ INCOMPLETE"}\n');

    if (result.successIndexes.isNotEmpty) {
      print('✅ Successfully Verified (${result.successIndexes.length}):');
      for (final index in result.successIndexes) {
        print('   - $index');
      }
      print('');
    }

    if (result.missingIndexes.isNotEmpty) {
      print('❌ Missing Indexes (${result.missingIndexes.length}):');
      for (final index in result.missingIndexes) {
        print('   - $index');
      }
      print('');
    }

    if (result.extraIndexes.isNotEmpty) {
      print('ℹ️  Extra Indexes (${result.extraIndexes.length}):');
      for (final index in result.extraIndexes) {
        print('   - $index');
      }
      print('');
    }

    print('=== PERFORMANCE STATISTICS ===\n');
    print('Custom Indexes: ${stats.customIndexCount}');
    print('Database Size: ${(stats.databaseSizeBytes / 1024 / 1024).toStringAsFixed(2)} MB');
    print('Table Counts:');
    stats.tableCounts.forEach((table, count) {
      print('   - $table: $count');
    });

    if (result.error != null) {
      print('\n⚠️  Error: ${result.error}');
    }

    print('\n==========================================\n');
  }
}

/// Result of index verification
class IndexVerificationResult {
  List<String> successIndexes = [];
  List<String> missingIndexes = [];
  List<String> extraIndexes = [];
  int totalExpected = 0;
  int totalFound = 0;
  String? error;

  bool get isComplete => missingIndexes.isEmpty && error == null;

  void addSuccess(String index) => successIndexes.add(index);
  void addMissing(String index) => missingIndexes.add(index);
  void addExtra(String index) => extraIndexes.add(index);

  Map<String, dynamic> toJson() => {
    'success_indexes': successIndexes,
    'missing_indexes': missingIndexes,
    'extra_indexes': extraIndexes,
    'total_expected': totalExpected,
    'total_found': totalFound,
    'is_complete': isComplete,
    'error': error,
  };
}

/// Information about a specific index
class IndexInfo {
  final String name;
  final String tableName;
  final String sql;
  final bool isExpected;

  IndexInfo({
    required this.name,
    required this.tableName,
    required this.sql,
    required this.isExpected,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'table_name': tableName,
    'sql': sql,
    'is_expected': isExpected,
  };
}

/// Analysis of query execution plan
class QueryAnalysis {
  final String query;
  List<String> queryPlan = [];
  bool usesIndex = false;
  String scanType = 'unknown';
  List<String> indexesUsed = [];
  String? error;

  QueryAnalysis({required this.query});

  Map<String, dynamic> toJson() => {
    'query': query,
    'query_plan': queryPlan,
    'uses_index': usesIndex,
    'scan_type': scanType,
    'indexes_used': indexesUsed,
    'error': error,
  };
}

/// Performance statistics
class PerformanceStats {
  int customIndexCount = 0;
  int databaseSizeBytes = 0;
  Map<String, int> tableCounts = {};
  DateTime? timestamp;
  String? error;

  Map<String, dynamic> toJson() => {
    'custom_index_count': customIndexCount,
    'database_size_bytes': databaseSizeBytes,
    'database_size_mb': (databaseSizeBytes / 1024 / 1024).toStringAsFixed(2),
    'table_counts': tableCounts,
    'timestamp': timestamp?.toIso8601String(),
    'error': error,
  };
}
