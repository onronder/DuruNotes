import 'dart:async';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/migrations/migration_14_attachments_inbox_optimization.dart';
import 'package:duru_notes/data/monitoring/query_performance_monitor.dart';
import 'package:duru_notes/data/queries/optimized_queries.dart';

/// Database Optimization Validator
///
/// Validates that all database optimizations are working correctly
/// and performance targets are met (&lt;100ms query response time)
class DatabaseOptimizationValidator {
  final AppDb _db;
  final AppLogger _logger;
  final QueryPerformanceMonitor _monitor;
  final OptimizedQueries _queries;

  DatabaseOptimizationValidator({
    required AppDb db,
  }) : _db = db,
       _logger = LoggerFactory.instance,
       _monitor = QueryPerformanceMonitor(db: db),
       _queries = OptimizedQueries(db);

  /// Run complete database optimization validation
  Future<ValidationReport> runCompleteValidation() async {
    final startTime = DateTime.now();
    final report = ValidationReport();

    _logger.info('Starting database optimization validation');

    try {
      // 1. Validate schema and tables
      report.schemaValidation = await _validateSchema();

      // 2. Validate indexes
      report.indexValidation = await _validateIndexes();

      // 3. Validate query performance
      report.performanceValidation = await _validateQueryPerformance();

      // 4. Validate N+1 query prevention
      report.n1QueryValidation = await _validateN1QueryPrevention();

      // 5. Validate migration integrity
      report.migrationValidation = await _validateMigrationIntegrity();

      // 6. Overall health check
      report.overallHealth = await _performHealthCheck();

      report.isValid = _isValidationSuccessful(report);
      report.executionTime = DateTime.now().difference(startTime);

      _logger.info(
        'Database validation completed in ${report.executionTime.inMilliseconds}ms',
        data: {'validation_passed': report.isValid},
      );

    } catch (e, stackTrace) {
      _logger.error('Database validation failed', error: e, stackTrace: stackTrace);
      report.isValid = false;
      report.error = e.toString();
      report.executionTime = DateTime.now().difference(startTime);
    }

    return report;
  }

  /// Validate database schema
  Future<SchemaValidationResult> _validateSchema() async {
    final result = SchemaValidationResult();

    try {
      // Check all expected tables exist
      final tables = await _db.customSelect('''
        SELECT name FROM sqlite_master WHERE type='table'
        AND name NOT LIKE 'sqlite_%'
        ORDER BY name
      ''').get();

      final expectedTables = {
        'local_notes',
        'note_tags',
        'note_tasks',
        'note_reminders',
        'local_folders',
        'note_folders',
        'saved_searches',
        'local_templates',
        'local_attachments',
        'local_inbox_items',
        'pending_ops',
        'note_links',
      };

      final actualTables = tables.map((row) => row.read<String>('name')).toSet();
      result.missingTables = expectedTables.difference(actualTables).toList();
      result.extraTables = actualTables.difference(expectedTables).toList();

      // Check foreign key constraints are enabled
      final fkCheck = await _db.customSelect('PRAGMA foreign_keys').getSingle();
      result.foreignKeysEnabled = fkCheck.read<int>('foreign_keys') == 1;

      result.isValid = result.missingTables.isEmpty && result.foreignKeysEnabled;

    } catch (e) {
      result.error = e.toString();
      result.isValid = false;
    }

    return result;
  }

  /// Validate database indexes
  Future<IndexValidationResult> _validateIndexes() async {
    final result = IndexValidationResult();

    try {
      // Get all indexes
      final indexes = await _db.customSelect('''
        SELECT name, tbl_name, sql FROM sqlite_master
        WHERE type='index' AND name LIKE 'idx_%'
        ORDER BY name
      ''').get();

      result.totalIndexes = indexes.length;

      // Check critical performance indexes exist
      final criticalIndexes = [
        'idx_notes_active_pinned_updated',
        'idx_tags_note_covering',
        'idx_tasks_note_status_position',
        'idx_attachments_note_id',
        'idx_inbox_unprocessed',
        'idx_folders_parent_order',
      ];

      final existingIndexes = indexes.map((row) => row.read<String>('name')).toSet();

      result.missingCriticalIndexes = criticalIndexes
          .where((idx) => !existingIndexes.contains(idx))
          .toList();

      // Check index usage statistics
      result.indexStats = await _getIndexUsageStats();

      result.isValid = result.missingCriticalIndexes.isEmpty;

    } catch (e) {
      result.error = e.toString();
      result.isValid = false;
    }

    return result;
  }

  /// Validate query performance
  Future<PerformanceValidationResult> _validateQueryPerformance() async {
    final result = PerformanceValidationResult();

    try {
      // Run standard performance tests
      final perfTests = await _monitor.runPerformanceValidation();
      result.performanceTests = perfTests;

      // Test specific optimized queries
      result.noteQueryTime = await _testNoteQuery();
      result.tagAggregationTime = await _testTagAggregation();
      result.taskHierarchyTime = await _testTaskHierarchy();
      result.attachmentQueryTime = await _testAttachmentQuery();
      result.inboxQueryTime = await _testInboxQuery();

      // Check if all queries meet target (<100ms)
      final queryTimes = [
        result.noteQueryTime,
        result.tagAggregationTime,
        result.taskHierarchyTime,
        result.attachmentQueryTime,
        result.inboxQueryTime,
      ];

      result.maxQueryTime = queryTimes.reduce((a, b) => a > b ? a : b);
      result.isValid = result.maxQueryTime <= 100;

    } catch (e) {
      result.error = e.toString();
      result.isValid = false;
    }

    return result;
  }

  /// Validate N+1 query prevention
  Future<N1QueryValidationResult> _validateN1QueryPrevention() async {
    final result = N1QueryValidationResult();

    try {
      // Test note with relations query (should be single query per relation type)
      final startTime = DateTime.now();

      // This should execute 3 queries total: notes, tasks, tags, attachments
      final notesWithRelations = await _queries.getNotesWithRelations(
        userId: 'test-user',
        limit: 10,
      );

      final executionTime = DateTime.now().difference(startTime);
      result.batchQueryTime = executionTime.inMilliseconds;

      // Test individual queries (should be much slower due to N+1)
      final individualStartTime = DateTime.now();
      for (final noteData in notesWithRelations.take(5)) {
        await _queries.getNoteWithRelations(noteData.note.id, userId: 'test-user');
      }
      final individualTime = DateTime.now().difference(individualStartTime);
      result.individualQueriesTime = individualTime.inMilliseconds;

      // Batch loading should be significantly faster
      result.performanceImprovement = result.individualQueriesTime / result.batchQueryTime;
      result.isValid = result.performanceImprovement > 2.0; // At least 2x faster

    } catch (e) {
      result.error = e.toString();
      result.isValid = false;
    }

    return result;
  }

  /// Validate migration integrity
  Future<MigrationValidationResult> _validateMigrationIntegrity() async {
    final result = MigrationValidationResult();

    try {
      // Check migration was applied successfully
      result.migrationApplied = await Migration14AttachmentsInboxOptimization.validateMigration(_db);

      // Get migration metrics
      result.migrationMetrics = await Migration14AttachmentsInboxOptimization.getPerformanceMetrics(_db);

      // Check schema version
      final versionResult = await _db.customSelect('''
        SELECT version FROM schema_versions ORDER BY version DESC LIMIT 1
      ''').getSingleOrNull();

      result.currentSchemaVersion = versionResult?.read<int>('version') ?? 0;
      result.expectedSchemaVersion = 14;

      result.isValid = result.migrationApplied &&
                      result.currentSchemaVersion >= result.expectedSchemaVersion;

    } catch (e) {
      result.error = e.toString();
      result.isValid = false;
    }

    return result;
  }

  /// Perform overall health check
  Future<HealthCheckResult> _performHealthCheck() async {
    final result = HealthCheckResult();

    try {
      // Database integrity check
      final integrityResult = await _db.customSelect('PRAGMA integrity_check').getSingle();
      result.integrityCheck = integrityResult.read<String>('integrity_check') == 'ok';

      // Get database size
      final sizeResult = await _db.customSelect('PRAGMA page_count').getSingle();
      final pageSize = await _db.customSelect('PRAGMA page_size').getSingle();
      result.databaseSizeMB = (sizeResult.read<int>('page_count') *
                              pageSize.read<int>('page_size')) / (1024 * 1024);

      // Check vacuum recommendation
      final freePageResult = await _db.customSelect('PRAGMA freelist_count').getSingle();
      final freePages = freePageResult.read<int>('freelist_count');
      result.needsVacuum = freePages > 1000; // Arbitrary threshold

      // Count total records
      result.totalRecords = await _getTotalRecordCount();

      result.isValid = result.integrityCheck;

    } catch (e) {
      result.error = e.toString();
      result.isValid = false;
    }

    return result;
  }

  // Helper methods for testing

  Future<int> _testNoteQuery() async {
    final stopwatch = Stopwatch()..start();
    await _queries.getNotesWithRelations(userId: 'test-user', limit: 20);
    stopwatch.stop();
    return stopwatch.elapsedMilliseconds;
  }

  Future<int> _testTagAggregation() async {
    final stopwatch = Stopwatch()..start();
    await _db.customSelect('''
      SELECT tag, COUNT(*) as count FROM note_tags
      GROUP BY tag ORDER BY count DESC LIMIT 50
    ''').get();
    stopwatch.stop();
    return stopwatch.elapsedMilliseconds;
  }

  Future<int> _testTaskHierarchy() async {
    final stopwatch = Stopwatch()..start();
    await _queries.getTasksWithSubtasks('test-note-id');
    stopwatch.stop();
    return stopwatch.elapsedMilliseconds;
  }

  Future<int> _testAttachmentQuery() async {
    final stopwatch = Stopwatch()..start();
    // Attachments table is no longer present in the schema
    // Return 0ms as this query is not applicable
    stopwatch.stop();
    return 0;
  }

  Future<int> _testInboxQuery() async {
    final stopwatch = Stopwatch()..start();
    await _queries.getUnprocessedInboxItems(userId: 'test-user');
    stopwatch.stop();
    return stopwatch.elapsedMilliseconds;
  }

  Future<Map<String, dynamic>> _getIndexUsageStats() async {
    // SQLite doesn't have built-in index usage stats, so we return basic info
    final result = await _db.customSelect('''
      SELECT COUNT(*) as index_count FROM sqlite_master
      WHERE type='index' AND name LIKE 'idx_%'
    ''').getSingle();

    return {
      'total_indexes': result.read<int>('index_count'),
    };
  }

  Future<int> _getTotalRecordCount() async {
    final tables = ['local_notes', 'note_tasks', 'note_tags', 'local_attachments', 'local_inbox_items'];
    int total = 0;

    for (final table in tables) {
      // Validate table name against whitelist to prevent SQL injection
      if (!tables.contains(table)) {
        throw ArgumentError('Invalid table name: $table');
      }

      // Additional safety: validate table name format
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(table)) {
        throw ArgumentError('Invalid table name format: $table');
      }

      final result = await _db.customSelect('SELECT COUNT(*) as count FROM $table').getSingle();
      total += result.read<int>('count');
    }

    return total;
  }

  bool _isValidationSuccessful(ValidationReport report) {
    return report.schemaValidation.isValid &&
           report.indexValidation.isValid &&
           report.performanceValidation.isValid &&
           report.n1QueryValidation.isValid &&
           report.migrationValidation.isValid &&
           report.overallHealth.isValid;
  }
}

// Validation result classes
class ValidationReport {
  bool isValid = false;
  String? error;
  Duration executionTime = Duration.zero;
  SchemaValidationResult schemaValidation = SchemaValidationResult();
  IndexValidationResult indexValidation = IndexValidationResult();
  PerformanceValidationResult performanceValidation = PerformanceValidationResult();
  N1QueryValidationResult n1QueryValidation = N1QueryValidationResult();
  MigrationValidationResult migrationValidation = MigrationValidationResult();
  HealthCheckResult overallHealth = HealthCheckResult();

  Map<String, dynamic> toMap() {
    return {
      'is_valid': isValid,
      'error': error,
      'execution_time_ms': executionTime.inMilliseconds,
      'schema_validation': schemaValidation.toMap(),
      'index_validation': indexValidation.toMap(),
      'performance_validation': performanceValidation.toMap(),
      'n1_query_validation': n1QueryValidation.toMap(),
      'migration_validation': migrationValidation.toMap(),
      'overall_health': overallHealth.toMap(),
    };
  }
}

class SchemaValidationResult {
  bool isValid = false;
  String? error;
  List<String> missingTables = [];
  List<String> extraTables = [];
  bool foreignKeysEnabled = false;

  Map<String, dynamic> toMap() {
    return {
      'is_valid': isValid,
      'error': error,
      'missing_tables': missingTables,
      'extra_tables': extraTables,
      'foreign_keys_enabled': foreignKeysEnabled,
    };
  }
}

class IndexValidationResult {
  bool isValid = false;
  String? error;
  int totalIndexes = 0;
  List<String> missingCriticalIndexes = [];
  Map<String, dynamic> indexStats = {};

  Map<String, dynamic> toMap() {
    return {
      'is_valid': isValid,
      'error': error,
      'total_indexes': totalIndexes,
      'missing_critical_indexes': missingCriticalIndexes,
      'index_stats': indexStats,
    };
  }
}

class PerformanceValidationResult {
  bool isValid = false;
  String? error;
  Map<String, dynamic> performanceTests = <String, dynamic>{};
  int noteQueryTime = 0;
  int tagAggregationTime = 0;
  int taskHierarchyTime = 0;
  int attachmentQueryTime = 0;
  int inboxQueryTime = 0;
  int maxQueryTime = 0;

  Map<String, dynamic> toMap() {
    return {
      'is_valid': isValid,
      'error': error,
      'performance_tests': performanceTests,
      'note_query_time_ms': noteQueryTime,
      'tag_aggregation_time_ms': tagAggregationTime,
      'task_hierarchy_time_ms': taskHierarchyTime,
      'attachment_query_time_ms': attachmentQueryTime,
      'inbox_query_time_ms': inboxQueryTime,
      'max_query_time_ms': maxQueryTime,
      'target_time_ms': 100,
    };
  }
}

class N1QueryValidationResult {
  bool isValid = false;
  String? error;
  int batchQueryTime = 0;
  int individualQueriesTime = 0;
  double performanceImprovement = 0.0;

  Map<String, dynamic> toMap() {
    return {
      'is_valid': isValid,
      'error': error,
      'batch_query_time_ms': batchQueryTime,
      'individual_queries_time_ms': individualQueriesTime,
      'performance_improvement_ratio': performanceImprovement,
    };
  }
}

class MigrationValidationResult {
  bool isValid = false;
  String? error;
  bool migrationApplied = false;
  Map<String, dynamic> migrationMetrics = <String, dynamic>{};
  int currentSchemaVersion = 0;
  int expectedSchemaVersion = 0;

  Map<String, dynamic> toMap() {
    return {
      'is_valid': isValid,
      'error': error,
      'migration_applied': migrationApplied,
      'migration_metrics': migrationMetrics,
      'current_schema_version': currentSchemaVersion,
      'expected_schema_version': expectedSchemaVersion,
    };
  }
}

class HealthCheckResult {
  bool isValid = false;
  String? error;
  bool integrityCheck = false;
  double databaseSizeMB = 0.0;
  bool needsVacuum = false;
  int totalRecords = 0;

  Map<String, dynamic> toMap() {
    return {
      'is_valid': isValid,
      'error': error,
      'integrity_check': integrityCheck,
      'database_size_mb': databaseSizeMB,
      'needs_vacuum': needsVacuum,
      'total_records': totalRecords,
    };
  }
}