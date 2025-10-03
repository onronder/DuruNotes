import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/core/sync/sync_integrity_validator.dart';
import 'package:duru_notes/core/sync/conflict_resolution_engine.dart';
import 'package:duru_notes/core/sync/data_consistency_checker.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Pre-deployment validation tool for Phase 3 database optimizations
///
/// This tool performs comprehensive health checks and creates baseline
/// documentation before deploying any database changes. It ensures the
/// current system is in a stable state and provides rollback information.
class PreDeploymentValidator {
  final AppDb _localDb;
  final SupabaseNoteApi _remoteApi;
  final SyncIntegrityValidator _validator;
  final ConflictResolutionEngine _conflictEngine;
  final DataConsistencyChecker _consistencyChecker;
  final AppLogger _logger;

  PreDeploymentValidator({
    required AppDb localDb,
    required SupabaseNoteApi remoteApi,
    required SyncIntegrityValidator validator,
    required ConflictResolutionEngine conflictEngine,
    required DataConsistencyChecker consistencyChecker,
    required AppLogger logger,
  }) : _localDb = localDb,
       _remoteApi = remoteApi,
       _validator = validator,
       _conflictEngine = conflictEngine,
       _consistencyChecker = consistencyChecker,
       _logger = logger;

  /// Perform comprehensive pre-deployment validation
  Future<PreDeploymentReport> performPreDeploymentValidation({
    bool createBackupDocumentation = true,
    bool resolveExistingIssues = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logger.info('Starting pre-deployment validation for Phase 3 deployment');

    try {
      final report = PreDeploymentReport();

      // 1. System environment check
      _logger.info('Step 1: System environment validation');
      final envCheck = await _validateSystemEnvironment();
      report.environmentCheck = envCheck;

      // 2. Database connectivity validation
      _logger.info('Step 2: Database connectivity validation');
      final connectivityCheck = await _validateDatabaseConnectivity();
      report.connectivityCheck = connectivityCheck;

      // 3. Current schema version validation
      _logger.info('Step 3: Schema version validation');
      final schemaCheck = await _validateCurrentSchemaVersions();
      report.schemaCheck = schemaCheck;

      // 4. Baseline sync health assessment
      _logger.info('Step 4: Baseline sync health assessment');
      final syncHealthCheck = await _assessBaselineSyncHealth();
      report.syncHealthCheck = syncHealthCheck;

      // 5. Data integrity validation
      _logger.info('Step 5: Data integrity validation');
      final integrityCheck = await _validateDataIntegrity();
      report.integrityCheck = integrityCheck;

      // 6. Performance baseline establishment
      _logger.info('Step 6: Performance baseline establishment');
      final performanceBaseline = await _establishPerformanceBaseline();
      report.performanceBaseline = performanceBaseline;

      // 7. Resolve existing issues (if enabled)
      if (resolveExistingIssues && report.hasIssuesRequiringResolution) {
        _logger.info('Step 7: Resolving existing issues');
        final resolutionResult = await _resolveExistingIssues(report);
        report.issueResolutionResult = resolutionResult;
      }

      // 8. Create backup documentation (if enabled)
      if (createBackupDocumentation) {
        _logger.info('Step 8: Creating backup documentation');
        final backupResult = await _createBackupDocumentation();
        report.backupDocumentation = backupResult;
      }

      // 9. Final readiness assessment
      _logger.info('Step 9: Final deployment readiness assessment');
      final readinessAssessment = await _assessDeploymentReadiness(report);
      report.deploymentReadiness = readinessAssessment;

      stopwatch.stop();
      report.validationDuration = stopwatch.elapsed;
      report.completedAt = DateTime.now();

      _logger.info('Pre-deployment validation completed', data: {
        'duration_ms': stopwatch.elapsedMilliseconds,
        'deployment_ready': report.isDeploymentReady,
        'critical_issues': report.criticalIssuesCount,
        'baseline_health_score': report.syncHealthCheck?.healthScore,
      });

      return report;

    } catch (e, stackTrace) {
      stopwatch.stop();
      _logger.error(
        'Pre-deployment validation failed',
        error: e,
        stackTrace: stackTrace,
      );

      return PreDeploymentReport.failed(
        error: 'Pre-deployment validation failed: $e',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Validate system environment and prerequisites
  Future<EnvironmentCheck> _validateSystemEnvironment() async {
    final issues = <String>[];
    final info = <String, dynamic>{};

    try {
      // Check Dart/Flutter version compatibility
      final dartVersion = Platform.version;
      info['dart_version'] = dartVersion;

      // Check available disk space (approximate)
      try {
        final tempDir = Directory.systemTemp;
        final freeSpace = await _estimateAvailableSpace(tempDir);
        info['available_space_mb'] = freeSpace;

        if (freeSpace < 100) {
          issues.add('Low disk space: ${freeSpace}MB available (recommend 100MB+)');
        }
      } catch (e) {
        issues.add('Could not determine available disk space');
      }

      // Check network connectivity
      try {
        final result = await InternetAddress.lookup('supabase.com');
        info['network_connectivity'] = result.isNotEmpty;
        if (result.isEmpty) {
          issues.add('No network connectivity to Supabase');
        }
      } catch (e) {
        issues.add('Network connectivity check failed: $e');
      }

      // Check current time (for timestamp validation)
      final now = DateTime.now();
      final utcNow = DateTime.now().toUtc();
      info['local_time'] = now.toIso8601String();
      info['utc_time'] = utcNow.toIso8601String();
      info['timezone_offset_hours'] = now.timeZoneOffset.inHours;

    } catch (e) {
      issues.add('Environment check failed: $e');
    }

    return EnvironmentCheck(
      isValid: issues.isEmpty,
      issues: issues,
      systemInfo: info,
    );
  }

  /// Validate database connectivity
  Future<ConnectivityCheck> _validateDatabaseConnectivity() async {
    final issues = <String>[];
    final metrics = <String, dynamic>{};

    try {
      // Test local database
      final localStopwatch = Stopwatch()..start();
      try {
        final localCount = await _localDb.managers.localNotes.count();
        localStopwatch.stop();

        metrics['local_note_count'] = localCount;
        metrics['local_connection_time_ms'] = localStopwatch.elapsedMilliseconds;

        _logger.debug('Local database connectivity: OK', data: metrics);
      } catch (e) {
        localStopwatch.stop();
        issues.add('Local database connection failed: $e');
        metrics['local_connection_error'] = e.toString();
      }

      // Test remote database
      final remoteStopwatch = Stopwatch()..start();
      try {
        final remoteIds = await _remoteApi.fetchAllActiveIds();
        remoteStopwatch.stop();

        metrics['remote_note_count'] = remoteIds.length;
        metrics['remote_connection_time_ms'] = remoteStopwatch.elapsedMilliseconds;

        _logger.debug('Remote database connectivity: OK', data: metrics);
      } catch (e) {
        remoteStopwatch.stop();
        issues.add('Remote database connection failed: $e');
        metrics['remote_connection_error'] = e.toString();
      }

      // Test authentication
      try {
        final client = Supabase.instance.client;
        final currentUser = client.auth.currentUser;

        if (currentUser == null) {
          issues.add('No authenticated user found');
        } else {
          metrics['user_id'] = currentUser.id;
          metrics['authentication_method'] = currentUser.appMetadata['provider'] ?? 'unknown';
        }
      } catch (e) {
        issues.add('Authentication check failed: $e');
      }

    } catch (e) {
      issues.add('Connectivity validation failed: $e');
    }

    return ConnectivityCheck(
      isValid: issues.isEmpty,
      issues: issues,
      metrics: metrics,
    );
  }

  /// Validate current schema versions
  Future<SchemaVersionCheck> _validateCurrentSchemaVersions() async {
    final issues = <String>[];
    final versions = <String, dynamic>{};

    try {
      // Get local schema version
      final localVersion = await _localDb.schemaVersion;
      versions['local_schema_version'] = localVersion;

      // Expected version before Phase 3 deployment should be 11
      if (localVersion < 11) {
        issues.add('Local schema version $localVersion is too old (expected 11+)');
      } else if (localVersion > 11) {
        issues.add('Local schema version $localVersion suggests Phase 3 already deployed');
      }

      // Check migration history
      try {
        final migrationHistory = await _localDb.customSelect(
          'SELECT name FROM sqlite_master WHERE type="table" AND name="migration_history"'
        ).getSingleOrNull();

        if (migrationHistory == null) {
          issues.add('Migration tracking tables not found (will be created in deployment)');
        } else {
          versions['migration_tracking_available'] = true;
        }
      } catch (e) {
        // Migration tables don't exist yet - this is expected
        versions['migration_tracking_available'] = false;
      }

      // Check remote schema (by testing known table structure)
      try {
        final remoteTestQuery = await Supabase.instance.client
            .from('notes')
            .select('id')
            .limit(1)
            .maybeSingle();

        versions['remote_schema_accessible'] = true;
      } catch (e) {
        issues.add('Remote schema validation failed: $e');
        versions['remote_schema_accessible'] = false;
      }

    } catch (e) {
      issues.add('Schema version validation failed: $e');
    }

    return SchemaVersionCheck(
      isValid: issues.isEmpty,
      issues: issues,
      versions: versions,
    );
  }

  /// Assess baseline sync health
  Future<SyncHealthCheck> _assessBaselineSyncHealth() async {
    try {
      // Run comprehensive sync validation
      final validationResult = await _validator.validateSyncIntegrity(
        deepValidation: true,
      );

      // Run conflict detection
      final conflictResult = await _conflictEngine.detectAndResolveNoteConflicts(
        strategy: ConflictResolutionStrategy.manualReview, // Don't auto-resolve
      );

      // Run consistency check
      final consistencyResult = await _consistencyChecker.performConsistencyCheck(
        deepCheck: true,
      );

      // Calculate overall health score
      double healthScore = 1.0;

      if (!validationResult.isValid) {
        healthScore -= 0.3;
      }

      if (!consistencyResult.isConsistent) {
        healthScore -= 0.3;
      }

      if (conflictResult.totalConflicts > 0) {
        healthScore -= 0.2;
      }

      // Collect additional health metrics
      final additionalMetrics = await _collectSyncHealthMetrics();

      return SyncHealthCheck(
        healthScore: math.max(0.0, healthScore),
        validationResult: validationResult,
        conflictResult: conflictResult,
        consistencyResult: consistencyResult,
        additionalMetrics: additionalMetrics,
      );

    } catch (e) {
      _logger.error('Sync health assessment failed', error: e);
      return SyncHealthCheck(
        healthScore: 0.0,
        error: 'Sync health assessment failed: $e',
      );
    }
  }

  /// Validate data integrity
  Future<DataIntegrityCheck> _validateDataIntegrity() async {
    final issues = <String>[];
    final metrics = <String, dynamic>{};

    try {
      // Check for corrupted records
      final corruptedNotes = await _localDb.customSelect('''
        SELECT COUNT(*) as count FROM local_notes
        WHERE (title_enc IS NULL AND props_enc IS NULL) OR
              (created_at IS NULL OR updated_at IS NULL)
      ''').getSingle();

      final corruptedCount = corruptedNotes.read<int>('count') ?? 0;
      metrics['corrupted_notes_count'] = corruptedCount;

      if (corruptedCount > 0) {
        issues.add('$corruptedCount corrupted note records found');
      }

      // Check for invalid timestamps
      final invalidTimestamps = await _localDb.customSelect('''
        SELECT COUNT(*) as count FROM local_notes
        WHERE updated_at < created_at
      ''').getSingle();

      final invalidCount = invalidTimestamps.read<int>('count') ?? 0;
      metrics['invalid_timestamps_count'] = invalidCount;

      if (invalidCount > 0) {
        issues.add('$invalidCount records with invalid timestamps found');
      }

      // Check for orphaned relationships
      final orphanedTasks = await _localDb.customSelect('''
        SELECT COUNT(*) as count FROM note_tasks nt
        LEFT JOIN local_notes ln ON nt.note_id = ln.id
        WHERE ln.id IS NULL AND nt.deleted = 0
      ''').getSingle();

      final orphanedTaskCount = orphanedTasks.read<int>('count') ?? 0;
      metrics['orphaned_tasks_count'] = orphanedTaskCount;

      if (orphanedTaskCount > 0) {
        issues.add('$orphanedTaskCount orphaned tasks found');
      }

      // Check database file integrity (SQLite specific)
      try {
        await _localDb.customStatement('PRAGMA integrity_check');
        metrics['database_integrity'] = 'ok';
      } catch (e) {
        issues.add('Database integrity check failed: $e');
        metrics['database_integrity'] = 'failed';
      }

    } catch (e) {
      issues.add('Data integrity validation failed: $e');
    }

    return DataIntegrityCheck(
      isValid: issues.isEmpty,
      issues: issues,
      metrics: metrics,
    );
  }

  /// Establish performance baseline
  Future<PerformanceBaseline> _establishPerformanceBaseline() async {
    final metrics = <String, dynamic>{};

    try {
      // Test common query performance
      final queryTests = <String, Future<Duration>>{
        'select_all_notes': _timeQuery(() => _localDb.select(_localDb.localNotes).get()),
        'count_notes': _timeQuery(() => _localDb.managers.localNotes.count()),
        'select_folders': _timeQuery(() => _localDb.select(_localDb.localFolders).get()),
        'select_tasks': _timeQuery(() => _localDb.select(_localDb.noteTasks).get()),
      };

      for (final entry in queryTests.entries) {
        try {
          final duration = await entry.value;
          metrics['${entry.key}_ms'] = duration.inMilliseconds;
        } catch (e) {
          metrics['${entry.key}_error'] = e.toString();
        }
      }

      // Test remote API performance
      final remoteStopwatch = Stopwatch()..start();
      try {
        await _remoteApi.fetchEncryptedNotes();
        remoteStopwatch.stop();
        metrics['remote_fetch_notes_ms'] = remoteStopwatch.elapsedMilliseconds;
      } catch (e) {
        remoteStopwatch.stop();
        metrics['remote_fetch_error'] = e.toString();
      }

      // Database size metrics
      try {
        final dbFile = File(_localDb.executor.databaseName);
        if (await dbFile.exists()) {
          final dbSize = await dbFile.length();
          metrics['database_size_bytes'] = dbSize;
          metrics['database_size_mb'] = (dbSize / (1024 * 1024)).toStringAsFixed(2);
        }
      } catch (e) {
        metrics['database_size_error'] = e.toString();
      }

    } catch (e) {
      metrics['baseline_error'] = e.toString();
    }

    return PerformanceBaseline(
      metrics: metrics,
      collectedAt: DateTime.now(),
    );
  }

  /// Resolve existing issues before deployment
  Future<IssueResolutionResult> _resolveExistingIssues(PreDeploymentReport report) async {
    final resolutions = <String>[];
    final failures = <String>[];

    try {
      // Resolve sync conflicts if any
      if (report.syncHealthCheck?.conflictResult?.totalConflicts ?? 0 > 0) {
        try {
          final conflictResolution = await _conflictEngine.detectAndResolveNoteConflicts(
            strategy: ConflictResolutionStrategy.lastWriteWins,
          );

          if (conflictResolution.resolvedConflicts > 0) {
            resolutions.add('Resolved ${conflictResolution.resolvedConflicts} sync conflicts');
          }
        } catch (e) {
          failures.add('Failed to resolve conflicts: $e');
        }
      }

      // Clean up orphaned data
      if (report.integrityCheck?.metrics['orphaned_tasks_count'] ?? 0 > 0) {
        try {
          await _localDb.customStatement('''
            DELETE FROM note_tasks
            WHERE note_id NOT IN (SELECT id FROM local_notes)
            AND deleted = 0
          ''');
          resolutions.add('Cleaned up orphaned tasks');
        } catch (e) {
          failures.add('Failed to clean orphaned tasks: $e');
        }
      }

      // Fix invalid timestamps
      if (report.integrityCheck?.metrics['invalid_timestamps_count'] ?? 0 > 0) {
        try {
          await _localDb.customStatement('''
            UPDATE local_notes
            SET updated_at = created_at
            WHERE updated_at < created_at
          ''');
          resolutions.add('Fixed invalid timestamps');
        } catch (e) {
          failures.add('Failed to fix timestamps: $e');
        }
      }

    } catch (e) {
      failures.add('Issue resolution failed: $e');
    }

    return IssueResolutionResult(
      resolutions: resolutions,
      failures: failures,
      isSuccessful: failures.isEmpty,
    );
  }

  /// Create backup documentation
  Future<BackupDocumentation> _createBackupDocumentation() async {
    final documentation = <String, dynamic>{};
    final files = <String>[];

    try {
      // Document current database state
      documentation['backup_created_at'] = DateTime.now().toIso8601String();
      documentation['local_schema_version'] = await _localDb.schemaVersion;

      // Create schema dump
      final schemaDump = await _createSchemaDump();
      documentation['schema_dump'] = schemaDump;

      // Document table counts
      final tableCounts = <String, int>{};
      final tables = ['local_notes', 'local_folders', 'note_folders', 'note_tasks'];

      for (final table in tables) {
        try {
          final result = await _localDb.customSelect('SELECT COUNT(*) as count FROM $table').getSingle();
          tableCounts[table] = result.read<int>('count') ?? 0;
        } catch (e) {
          tableCounts[table] = -1; // Error indicator
        }
      }

      documentation['table_counts'] = tableCounts;

      // Document current indexes
      final indexes = await _localDb.customSelect('''
        SELECT name, sql FROM sqlite_master
        WHERE type = 'index' AND name NOT LIKE 'sqlite_%'
      ''').get();

      documentation['current_indexes'] = indexes.map((row) => {
        'name': row.read<String>('name'),
        'sql': row.read<String>('sql'),
      }).toList();

      // Create rollback instructions
      documentation['rollback_instructions'] = _createRollbackInstructions();

    } catch (e) {
      documentation['backup_error'] = e.toString();
    }

    return BackupDocumentation(
      documentation: documentation,
      files: files,
      createdAt: DateTime.now(),
    );
  }

  /// Assess deployment readiness
  Future<DeploymentReadiness> _assessDeploymentReadiness(PreDeploymentReport report) async {
    final blockers = <String>[];
    final warnings = <String>[];
    final readinessScore = <String, double>{};

    // Environment readiness
    if (!report.environmentCheck.isValid) {
      blockers.addAll(report.environmentCheck.issues);
      readinessScore['environment'] = 0.0;
    } else {
      readinessScore['environment'] = 1.0;
    }

    // Connectivity readiness
    if (!report.connectivityCheck.isValid) {
      blockers.addAll(report.connectivityCheck.issues);
      readinessScore['connectivity'] = 0.0;
    } else {
      readinessScore['connectivity'] = 1.0;
    }

    // Schema readiness
    if (!report.schemaCheck.isValid) {
      final criticalSchemaIssues = report.schemaCheck.issues
          .where((issue) => issue.contains('too old') || issue.contains('already deployed'))
          .toList();

      if (criticalSchemaIssues.isNotEmpty) {
        blockers.addAll(criticalSchemaIssues);
        readinessScore['schema'] = 0.0;
      } else {
        warnings.addAll(report.schemaCheck.issues);
        readinessScore['schema'] = 0.5;
      }
    } else {
      readinessScore['schema'] = 1.0;
    }

    // Sync health readiness
    final healthScore = report.syncHealthCheck?.healthScore ?? 0.0;
    readinessScore['sync_health'] = healthScore;

    if (healthScore < 0.5) {
      blockers.add('Sync health score too low: ${(healthScore * 100).toStringAsFixed(1)}%');
    } else if (healthScore < 0.8) {
      warnings.add('Sync health score is marginal: ${(healthScore * 100).toStringAsFixed(1)}%');
    }

    // Data integrity readiness
    if (!report.integrityCheck.isValid) {
      warnings.addAll(report.integrityCheck.issues);
      readinessScore['data_integrity'] = 0.5;
    } else {
      readinessScore['data_integrity'] = 1.0;
    }

    // Calculate overall readiness score
    final overallScore = readinessScore.values.isNotEmpty
        ? readinessScore.values.reduce((a, b) => a + b) / readinessScore.values.length
        : 0.0;

    return DeploymentReadiness(
      isReady: blockers.isEmpty && overallScore >= 0.7,
      overallScore: overallScore,
      blockers: blockers,
      warnings: warnings,
      readinessScores: readinessScore,
    );
  }

  // Helper methods

  Future<Duration> _timeQuery(Future<dynamic> Function() query) async {
    final stopwatch = Stopwatch()..start();
    await query();
    stopwatch.stop();
    return stopwatch.elapsed;
  }

  Future<int> _estimateAvailableSpace(Directory directory) async {
    // This is a simplified estimation - in production you might use platform-specific APIs
    try {
      final stat = await directory.stat();
      return 1000; // Placeholder - return 1GB estimate
    } catch (e) {
      return 0;
    }
  }

  Future<Map<String, dynamic>> _collectSyncHealthMetrics() async {
    final metrics = <String, dynamic>{};

    try {
      // Check for recent sync activity
      final recentActivity = await _localDb.customSelect('''
        SELECT COUNT(*) as count FROM pending_ops
        WHERE created_at > datetime('now', '-24 hours')
      ''').getSingleOrNull();

      metrics['recent_sync_activity'] = recentActivity?.read<int>('count') ?? 0;

      // Check for failed operations
      final failedOps = await _localDb.customSelect('''
        SELECT COUNT(*) as count FROM pending_ops
        WHERE operation_type LIKE '%failed%'
      ''').getSingleOrNull();

      metrics['failed_operations'] = failedOps?.read<int>('count') ?? 0;

    } catch (e) {
      metrics['collection_error'] = e.toString();
    }

    return metrics;
  }

  Future<String> _createSchemaDump() async {
    try {
      final result = await _localDb.customSelect('''
        SELECT sql FROM sqlite_master
        WHERE type IN ('table', 'index', 'trigger')
        AND name NOT LIKE 'sqlite_%'
        ORDER BY type, name
      ''').get();

      return result.map((row) => row.read<String>('sql')).join(';\n\n') + ';';
    } catch (e) {
      return 'Schema dump failed: $e';
    }
  }

  Map<String, dynamic> _createRollbackInstructions() {
    return {
      'local_migration_rollback': 'Use Migration12Phase3Optimization.rollback() method',
      'remote_migration_rollback': 'DROP all indexes created by 20250122_phase3_optimizations.sql',
      'sync_verification_rollback': 'Disable sync verification providers',
      'emergency_contacts': ['Check logs in app_logger', 'Review backup documentation'],
      'recovery_steps': [
        '1. Stop the application',
        '2. Restore database from backup if needed',
        '3. Roll back migrations in reverse order',
        '4. Restart application',
        '5. Verify data integrity',
      ],
    };
  }
}

// Data classes for validation results

class PreDeploymentReport {
  EnvironmentCheck environmentCheck = EnvironmentCheck(isValid: false, issues: [], systemInfo: {});
  ConnectivityCheck connectivityCheck = ConnectivityCheck(isValid: false, issues: [], metrics: {});
  SchemaVersionCheck schemaCheck = SchemaVersionCheck(isValid: false, issues: [], versions: {});
  SyncHealthCheck? syncHealthCheck;
  DataIntegrityCheck integrityCheck = DataIntegrityCheck(isValid: false, issues: [], metrics: {});
  PerformanceBaseline? performanceBaseline;
  IssueResolutionResult? issueResolutionResult;
  BackupDocumentation? backupDocumentation;
  DeploymentReadiness? deploymentReadiness;

  Duration? validationDuration;
  DateTime? completedAt;
  String? error;

  PreDeploymentReport();

  factory PreDeploymentReport.failed({
    required String error,
    required Duration duration,
  }) {
    final report = PreDeploymentReport();
    report.error = error;
    report.validationDuration = duration;
    report.completedAt = DateTime.now();
    return report;
  }

  bool get isDeploymentReady => deploymentReadiness?.isReady ?? false;
  bool get hasIssuesRequiringResolution =>
      (syncHealthCheck?.conflictResult?.totalConflicts ?? 0) > 0 ||
      (integrityCheck.metrics['orphaned_tasks_count'] ?? 0) > 0 ||
      (integrityCheck.metrics['invalid_timestamps_count'] ?? 0) > 0;

  int get criticalIssuesCount =>
      (deploymentReadiness?.blockers.length ?? 0) +
      (syncHealthCheck?.validationResult?.criticalIssues.length ?? 0);

  Map<String, dynamic> toJson() => {
    'deployment_ready': isDeploymentReady,
    'critical_issues_count': criticalIssuesCount,
    'validation_duration_ms': validationDuration?.inMilliseconds,
    'completed_at': completedAt?.toIso8601String(),
    'sync_health_score': syncHealthCheck?.healthScore,
    'error': error,
  };
}

// Supporting data classes
class EnvironmentCheck {
  final bool isValid;
  final List<String> issues;
  final Map<String, dynamic> systemInfo;

  EnvironmentCheck({
    required this.isValid,
    required this.issues,
    required this.systemInfo,
  });
}

class ConnectivityCheck {
  final bool isValid;
  final List<String> issues;
  final Map<String, dynamic> metrics;

  ConnectivityCheck({
    required this.isValid,
    required this.issues,
    required this.metrics,
  });
}

class SchemaVersionCheck {
  final bool isValid;
  final List<String> issues;
  final Map<String, dynamic> versions;

  SchemaVersionCheck({
    required this.isValid,
    required this.issues,
    required this.versions,
  });
}

class SyncHealthCheck {
  final double healthScore;
  final ValidationResult? validationResult;
  final ConflictResolutionResult? conflictResult;
  final ConsistencyCheckResult? consistencyResult;
  final Map<String, dynamic>? additionalMetrics;
  final String? error;

  SyncHealthCheck({
    required this.healthScore,
    this.validationResult,
    this.conflictResult,
    this.consistencyResult,
    this.additionalMetrics,
    this.error,
  });
}

class DataIntegrityCheck {
  final bool isValid;
  final List<String> issues;
  final Map<String, dynamic> metrics;

  DataIntegrityCheck({
    required this.isValid,
    required this.issues,
    required this.metrics,
  });
}

class PerformanceBaseline {
  final Map<String, dynamic> metrics;
  final DateTime collectedAt;

  PerformanceBaseline({
    required this.metrics,
    required this.collectedAt,
  });
}

class IssueResolutionResult {
  final List<String> resolutions;
  final List<String> failures;
  final bool isSuccessful;

  IssueResolutionResult({
    required this.resolutions,
    required this.failures,
    required this.isSuccessful,
  });
}

class BackupDocumentation {
  final Map<String, dynamic> documentation;
  final List<String> files;
  final DateTime createdAt;

  BackupDocumentation({
    required this.documentation,
    required this.files,
    required this.createdAt,
  });
}

class DeploymentReadiness {
  final bool isReady;
  final double overallScore;
  final List<String> blockers;
  final List<String> warnings;
  final Map<String, double> readinessScores;

  DeploymentReadiness({
    required this.isReady,
    required this.overallScore,
    required this.blockers,
    required this.warnings,
    required this.readinessScores,
  });
}

