/* COMMENTED OUT - 42 errors - uses old providers and APIs
 * This tool uses old providers and API methods that no longer exist.
 * Needs rewrite to use new architecture.
 *
 * TODO: Rewrite deployment validation tool
 */

/*
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:duru_notes/providers/pre_deployment_providers.dart';
import 'package:duru_notes/providers/sync_verification_providers.dart';
import 'package:duru_notes/tools/pre_deployment_validator.dart';
import 'package:duru_notes/core/sync/sync_integrity_validator.dart';
import 'dart:convert';
import 'dart:io';

/// Comprehensive deployment validation test
///
/// This script runs the complete pre-deployment validation suite
/// to establish baseline measurements before Phase 3 deployment
class DeploymentValidationTest {
  final ProviderContainer container;

  DeploymentValidationTest(this.container);

  /// Execute comprehensive pre-deployment validation
  Future<Map<String, dynamic>> runCompleteValidation() async {
    final results = <String, dynamic>{};
    final timestamp = DateTime.now();

    print('🔍 Starting Pre-Deployment Validation at ${timestamp.toIso8601String()}');
    print('=' * 80);

    try {
      // 1. Basic connectivity validation
      print('📡 Step 1: Testing database connectivity...');
      final connectivityResult = await _testConnectivity();
      results['connectivity'] = connectivityResult;
      _printStepResult('Connectivity Test', connectivityResult['success']);

      // 2. Sync integrity validation
      print('\n🔄 Step 2: Validating sync integrity...');
      final syncResult = await _validateSyncIntegrity();
      results['sync_integrity'] = syncResult;
      _printStepResult('Sync Integrity', syncResult['is_valid']);

      // 3. Data consistency check
      print('\n📊 Step 3: Checking data consistency...');
      final consistencyResult = await _checkDataConsistency();
      results['data_consistency'] = consistencyResult;
      _printStepResult('Data Consistency', consistencyResult['is_consistent']);

      // 4. Conflict detection
      print('\n⚡ Step 4: Detecting conflicts...');
      final conflictResult = await _detectConflicts();
      results['conflict_detection'] = conflictResult;
      _printStepResult('Conflict Detection', conflictResult['conflicts_found'] == 0);

      // 5. Performance baseline
      print('\n⚡ Step 5: Establishing performance baseline...');
      final performanceResult = await _measurePerformanceBaseline();
      results['performance_baseline'] = performanceResult;
      _printStepResult('Performance Baseline', performanceResult['success']);

      // 6. Full pre-deployment validation
      print('\n🛡️ Step 6: Running comprehensive pre-deployment validation...');
      final preDeployResult = await _runPreDeploymentValidation();
      results['pre_deployment'] = preDeployResult;
      _printStepResult('Pre-deployment Validation', preDeployResult['is_deployment_ready']);

      // 7. Generate summary
      final summary = _generateValidationSummary(results, timestamp);
      results['summary'] = summary;

      // 8. Save baseline report
      await _saveBaselineReport(results);

      print('\n' + '=' * 80);
      print('✅ Pre-deployment validation completed successfully!');
      print('📄 Baseline report saved to docs/deployment_baseline_report.json');

      return results;

    } catch (error, stackTrace) {
      print('\n❌ Validation failed with error: $error');
      print('Stack trace: $stackTrace');

      results['error'] = {
        'message': error.toString(),
        'stack_trace': stackTrace.toString(),
        'timestamp': timestamp.toIso8601String(),
      };

      return results;
    }
  }

  /// Test basic database connectivity
  Future<Map<String, dynamic>> _testConnectivity() async {
    try {
      final validator = container.read(syncIntegrityValidatorProvider);

      // Test local database
      final localTest = await _testLocalDatabase();

      // Test remote database
      final remoteTest = await _testRemoteDatabase();

      return {
        'success': localTest['success'] && remoteTest['success'],
        'local_db': localTest,
        'remote_db': remoteTest,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Test local SQLite database
  Future<Map<String, dynamic>> _testLocalDatabase() async {
    try {
      final appDb = container.read(appDbProvider);

      // Test basic query
      final noteCount = await appDb.customSelect('SELECT COUNT(*) as count FROM local_notes').getSingle();
      final folderCount = await appDb.customSelect('SELECT COUNT(*) as count FROM local_folders').getSingle();
      final taskCount = await appDb.customSelect('SELECT COUNT(*) as count FROM note_tasks').getSingle();

      return {
        'success': true,
        'note_count': noteCount.read<int>('count'),
        'folder_count': folderCount.read<int>('count'),
        'task_count': taskCount.read<int>('count'),
        'database_path': appDb.executor.databaseName ?? 'in_memory',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Test remote PostgreSQL database
  Future<Map<String, dynamic>> _testRemoteDatabase() async {
    try {
      final remoteApi = container.read(supabaseNoteApiProvider);

      // Test basic connectivity by fetching a small amount of data
      final recentNotes = await remoteApi.fetchRecentNotes(limit: 1);

      return {
        'success': true,
        'connection_test': 'passed',
        'recent_notes_accessible': recentNotes.isNotEmpty,
        'api_responsive': true,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'connection_test': 'failed',
      };
    }
  }

  /// Validate sync integrity between databases
  Future<Map<String, dynamic>> _validateSyncIntegrity() async {
    try {
      final validator = container.read(syncIntegrityValidatorProvider);

      final result = await validator.validateSyncIntegrity(
        deepValidation: true,
        validationWindow: DateTime.now().subtract(Duration(days: 7)),
      );

      return {
        'is_valid': result.isValid,
        'issues_found': result.issues.length,
        'critical_issues': result.criticalIssues.length,
        'warning_issues': result.warningIssues.length,
        'validation_duration_ms': result.metrics.duration?.inMilliseconds ?? 0,
        'records_validated': result.metrics.recordsChecked,
        'details': result.issues.map((issue) => {
          'type': issue.type.toString(),
          'severity': issue.severity.toString(),
          'message': issue.message,
        }).toList(),
      };
    } catch (e) {
      return {
        'is_valid': false,
        'error': e.toString(),
        'issues_found': -1,
      };
    }
  }

  /// Check data consistency across databases
  Future<Map<String, dynamic>> _checkDataConsistency() async {
    try {
      final checker = container.read(dataConsistencyCheckerProvider);

      final result = await checker.performConsistencyCheck(
        deepCheck: true,
        specificTables: {'notes', 'folders', 'note_tasks'},
      );

      return {
        'is_consistent': result.isConsistent,
        'tables_checked': result.tablesChecked.length,
        'inconsistencies_found': result.inconsistencies.length,
        'critical_issues': result.criticalIssues.length,
        'consistency_rate': result.consistencyRate,
        'check_duration_ms': result.checkDuration.inMilliseconds,
        'details': result.inconsistencies.map((Map<String, dynamic> inconsistency) => {
          'table': inconsistency.tableName,
          'type': inconsistency.type.toString(),
          'severity': inconsistency.severity.toString(),
          'description': inconsistency.description,
        }).toList(),
      };
    } catch (e) {
      return {
        'is_consistent': false,
        'error': e.toString(),
        'inconsistencies_found': -1,
      };
    }
  }

  /// Detect existing conflicts
  Future<Map<String, dynamic>> _detectConflicts() async {
    try {
      final conflictEngine = container.read(conflictResolutionEngineProvider);

      final result = await conflictEngine.detectAndResolveNoteConflicts(
        strategy: ConflictResolutionStrategy.manual, // Just detect, don't resolve
      );

      return {
        'conflicts_found': result.conflictsFound,
        'conflicts_resolved': result.conflictsResolved,
        'resolution_rate': result.resolutionRate,
        'has_unresolved_conflicts': result.hasUnresolvedConflicts,
        'processing_duration_ms': result.processingDuration.inMilliseconds,
        'conflict_details': result.conflicts.map((conflict) => {
          'note_id': conflict.noteId,
          'conflict_type': conflict.conflictType.toString(),
          'resolution_strategy': conflict.appliedStrategy?.toString(),
          'local_timestamp': conflict.localVersion.updatedAt.toIso8601String(),
          'remote_timestamp': conflict.remoteVersion.updatedAt.toIso8601String(),
        }).toList(),
      };
    } catch (e) {
      return {
        'conflicts_found': -1,
        'error': e.toString(),
        'has_unresolved_conflicts': true,
      };
    }
  }

  /// Measure performance baseline
  Future<Map<String, dynamic>> _measurePerformanceBaseline() async {
    try {
      final measurements = <String, dynamic>{};

      // Test local database query performance
      final localPerf = await _measureLocalQueryPerformance();
      measurements['local_db_performance'] = localPerf;

      // Test remote API performance
      final remotePerf = await _measureRemoteApiPerformance();
      measurements['remote_api_performance'] = remotePerf;

      // Test sync operation performance
      final syncPerf = await _measureSyncPerformance();
      measurements['sync_performance'] = syncPerf;

      return {
        'success': true,
        'measurements': measurements,
        'baseline_timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Measure local database query performance
  Future<Map<String, dynamic>> _measureLocalQueryPerformance() async {
    final appDb = container.read(appDbProvider);
    final measurements = <String, int>{};

    // Note query performance
    final noteQueryStart = DateTime.now();
    await appDb.customSelect('SELECT * FROM local_notes LIMIT 100').get();
    measurements['notes_query_ms'] = DateTime.now().difference(noteQueryStart).inMilliseconds;

    // Folder query performance
    final folderQueryStart = DateTime.now();
    await appDb.customSelect('SELECT * FROM local_folders LIMIT 50').get();
    measurements['folders_query_ms'] = DateTime.now().difference(folderQueryStart).inMilliseconds;

    // Task query performance
    final taskQueryStart = DateTime.now();
    await appDb.customSelect('SELECT * FROM note_tasks LIMIT 100').get();
    measurements['tasks_query_ms'] = DateTime.now().difference(taskQueryStart).inMilliseconds;

    return measurements;
  }

  /// Measure remote API performance
  Future<Map<String, dynamic>> _measureRemoteApiPerformance() async {
    final remoteApi = container.read(supabaseNoteApiProvider);
    final measurements = <String, int>{};

    try {
      // Notes fetch performance
      final notesStart = DateTime.now();
      await remoteApi.fetchRecentNotes(limit: 50);
      measurements['notes_fetch_ms'] = DateTime.now().difference(notesStart).inMilliseconds;

      // Folders fetch performance
      final foldersStart = DateTime.now();
      await remoteApi.fetchAllFolders();
      measurements['folders_fetch_ms'] = DateTime.now().difference(foldersStart).inMilliseconds;

    } catch (e) {
      measurements['error'] = e.toString();
    }

    return measurements;
  }

  /// Measure sync operation performance
  Future<Map<String, dynamic>> _measureSyncPerformance() async {
    final validator = container.read(syncIntegrityValidatorProvider);

    // Quick sync validation performance
    final syncStart = DateTime.now();
    try {
      await validator.validateSyncIntegrity(deepValidation: false);
      final syncDuration = DateTime.now().difference(syncStart).inMilliseconds;

      return {
        'quick_sync_validation_ms': syncDuration,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'quick_sync_validation_ms': -1,
      };
    }
  }

  /// Run comprehensive pre-deployment validation
  Future<Map<String, dynamic>> _runPreDeploymentValidation() async {
    try {
      final preDeployValidator = container.read(preDeploymentValidatorProvider);

      final report = await preDeployValidator.performPreDeploymentValidation(
        createBackupDocumentation: true,
        resolveExistingIssues: false, // Don't resolve issues yet, just report
      );

      return {
        'is_deployment_ready': report.isDeploymentReady,
        'overall_health_score': report.syncHealthCheck?.healthScore ?? 0.0,
        'critical_issues_count': report.criticalIssuesCount,
        'warning_issues_count': report.warningIssuesCount,
        'backup_documentation_created': report.backupDocumentationPath != null,
        'validation_steps_completed': report.validationSteps.length,
        'validation_steps': report.validationSteps.map((Map<String, dynamic> step) => {
          'step_name': step.stepName,
          'is_successful': step.isSuccessful,
          'duration_ms': step.duration.inMilliseconds,
          'details': step.details,
        }).toList(),
        'recommendations': report.recommendations,
      };
    } catch (e) {
      return {
        'is_deployment_ready': false,
        'error': e.toString(),
        'critical_issues_count': -1,
      };
    }
  }

  /// Generate validation summary
  Map<String, dynamic> _generateValidationSummary(Map<String, dynamic> results, DateTime timestamp) {
    final connectivity = results['connectivity'] as Map<String, dynamic>? ?? {};
    final syncIntegrity = results['sync_integrity'] as Map<String, dynamic>? ?? {};
    final dataConsistency = results['data_consistency'] as Map<String, dynamic>? ?? {};
    final conflictDetection = results['conflict_detection'] as Map<String, dynamic>? ?? {};
    final preDeployment = results['pre_deployment'] as Map<String, dynamic>? ?? {};

    final isHealthy = (connectivity['success'] == true) &&
                     (syncIntegrity['is_valid'] == true) &&
                     (dataConsistency['is_consistent'] == true) &&
                     (conflictDetection['conflicts_found'] == 0) &&
                     (preDeployment['is_deployment_ready'] == true);

    return {
      'validation_timestamp': timestamp.toIso8601String(),
      'overall_health_status': isHealthy ? 'HEALTHY' : 'ISSUES_FOUND',
      'deployment_readiness': preDeployment['is_deployment_ready'] ?? false,
      'health_score': preDeployment['overall_health_score'] ?? 0.0,
      'total_critical_issues': (syncIntegrity['critical_issues'] ?? 0) +
                              (dataConsistency['critical_issues'] ?? 0) +
                              (preDeployment['critical_issues_count'] ?? 0),
      'database_connectivity': connectivity['success'] ?? false,
      'sync_integrity_valid': syncIntegrity['is_valid'] ?? false,
      'data_consistency_valid': dataConsistency['is_consistent'] ?? false,
      'conflicts_detected': conflictDetection['conflicts_found'] ?? -1,
      'recommendations': preDeployment['recommendations'] ?? <String>[],
      'next_steps': _generateNextSteps(isHealthy, results),
    };
  }

  /// Generate next steps based on validation results
  List<String> _generateNextSteps(bool isHealthy, Map<String, dynamic> results) {
    final steps = <String>[];

    if (isHealthy) {
      steps.addAll([
        'All validation checks passed - system is ready for Phase 3 deployment',
        'Proceed with Step 2: Deploy sync verification system to production',
        'Monitor system health during each deployment step',
        'Maintain backup documentation for rollback if needed',
      ]);
    } else {
      final connectivity = results['connectivity'] as Map<String, dynamic>? ?? {};
      final syncIntegrity = results['sync_integrity'] as Map<String, dynamic>? ?? {};
      final dataConsistency = results['data_consistency'] as Map<String, dynamic>? ?? {};
      final conflictDetection = results['conflict_detection'] as Map<String, dynamic>? ?? {};

      if (connectivity['success'] != true) {
        steps.add('🔴 Fix database connectivity issues before proceeding');
      }

      if (syncIntegrity['is_valid'] != true) {
        steps.add('🔴 Resolve sync integrity issues - run sync recovery if needed');
      }

      if (dataConsistency['is_consistent'] != true) {
        steps.add('🔴 Fix data consistency issues between local and remote databases');
      }

      if ((conflictDetection['conflicts_found'] ?? 0) > 0) {
        steps.add('🟡 Resolve existing conflicts before deployment');
      }

      steps.addAll([
        'Re-run validation after fixing issues',
        'Only proceed with deployment after achieving HEALTHY status',
      ]);
    }

    return steps;
  }

  /// Save baseline report to file
  Future<void> _saveBaselineReport(Map<String, dynamic> results) async {
    final reportFile = File('/Users/onronder/duru-notes/docs/deployment_baseline_report.json');

    // Ensure directory exists
    await reportFile.parent.create(recursive: true);

    // Write formatted JSON
    final jsonString = JsonEncoder.withIndent('  ').convert(results);
    await reportFile.writeAsString(jsonString);
  }

  /// Print step result with formatting
  void _printStepResult(String stepName, bool success) {
    final status = success ? '✅ PASSED' : '❌ FAILED';
    final padding = ' ' * (30 - stepName.length);
    print('   $stepName$padding$status');
  }
}

/// Helper function to run validation test
Future<Map<String, dynamic>> runDeploymentValidationTest(ProviderContainer container) async {
  final test = DeploymentValidationTest(container);
  return await test.runCompleteValidation();
}
*/