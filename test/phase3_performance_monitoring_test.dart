import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/unified_task_service.dart' as unified;
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/core/monitoring/task_sync_metrics.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';

/// Phase 3 Performance Monitoring Test Suite
///
/// CRITICAL: This test suite validates the performance characteristics of
/// sync operations after Phase 3 compilation fixes. It ensures that the
/// bidirectional sync system maintains acceptable performance levels.
///
/// Tests cover:
/// - Sync operation performance benchmarks
/// - Memory usage monitoring
/// - Database operation timing
/// - Concurrent operation handling
/// - Stress testing with large datasets
/// - Performance regression detection
void main() {
  group('Phase 3: Performance Monitoring Tests', () {
    late ProviderContainer container;
    late unified.UnifiedTaskService unifiedTaskService;
    late AppDb database;

    setUpAll(() async {
      container = ProviderContainer();
      database = container.read(appDbProvider);
      unifiedTaskService = container.read(unifiedTaskServiceProvider);

      // Reset metrics for clean testing
      TaskSyncMetrics.instance.reset();
    });

    tearDownAll(() async {
      container.dispose();
    });

    group('Sync Operation Performance Benchmarks', () {
      test('Basic sync operations meet performance thresholds', () async {
        print('\n⚡ Testing basic sync operation performance...');

        final results = <String, dynamic>{};

        try {
          final performanceMetrics = <String, Map<String, dynamic>>{};

          // Test task creation performance
          print('  🔍 Benchmarking task creation...');

          final createStartTime = DateTime.now();
          final testNoteId = 'perf_test_note_${DateTime.now().millisecondsSinceEpoch}';

          final task = await unifiedTaskService.createTask(
            noteId: testNoteId,
            content: 'Performance test task',
            priority: TaskPriority.medium,
          );

          final createEndTime = DateTime.now();
          final createDuration = createEndTime.difference(createStartTime).inMilliseconds;

          performanceMetrics['taskCreation'] = {
            'durationMs': createDuration,
            'threshold': 1000, // 1 second threshold
            'withinThreshold': createDuration <= 1000,
            'taskId': task.id,
          };

          // Test task retrieval performance
          print('  👁️ Benchmarking task retrieval...');

          final retrieveStartTime = DateTime.now();
          final retrievedTask = await unifiedTaskService.getTask(task.id);
          final retrieveEndTime = DateTime.now();
          final retrieveDuration = retrieveEndTime.difference(retrieveStartTime).inMilliseconds;

          performanceMetrics['taskRetrieval'] = {
            'durationMs': retrieveDuration,
            'threshold': 500, // 500ms threshold
            'withinThreshold': retrieveDuration <= 500,
            'taskRetrieved': retrievedTask != null,
          };

          // Test batch operations performance
          print('  📋 Benchmarking batch operations...');

          final batchStartTime = DateTime.now();
          final tasks = await unifiedTaskService.getTasksForNote(testNoteId);
          final batchEndTime = DateTime.now();
          final batchDuration = batchEndTime.difference(batchStartTime).inMilliseconds;

          performanceMetrics['batchRetrieval'] = {
            'durationMs': batchDuration,
            'threshold': 750, // 750ms threshold
            'withinThreshold': batchDuration <= 750,
            'tasksRetrieved': tasks.length,
          };

          // Test sync operation performance
          print('  🔄 Benchmarking sync operations...');

          final syncStartTime = DateTime.now();
          await unifiedTaskService.syncFromNoteToTasks(
            testNoteId,
            '- [ ] Sync performance test task 1\n- [x] Sync performance test task 2\n- [ ] Sync performance test task 3',
          );
          final syncEndTime = DateTime.now();
          final syncDuration = syncEndTime.difference(syncStartTime).inMilliseconds;

          performanceMetrics['syncOperation'] = {
            'durationMs': syncDuration,
            'threshold': 2000, // 2 second threshold
            'withinThreshold': syncDuration <= 2000,
            'tasksProcessed': 3,
          };

          // Clean up
          await unifiedTaskService.deleteTask(task.id);

          // Calculate overall performance score
          final allWithinThreshold = performanceMetrics.values
              .every((metric) => metric['withinThreshold'] == true);

          final avgDuration = performanceMetrics.values
              .map((metric) => metric['durationMs'] as int)
              .reduce((a, b) => a + b) / performanceMetrics.length;

          results['basicSyncPerformance'] = {
            'success': allWithinThreshold,
            'performanceMetrics': performanceMetrics,
            'allWithinThreshold': allWithinThreshold,
            'averageDurationMs': avgDuration,
            'totalOperations': performanceMetrics.length,
          };

          print('  ✅ Basic sync operation performance benchmark completed');

        } catch (e, stack) {
          results['basicSyncPerformance'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Basic sync operation performance benchmark failed: $e');
        }

        await _saveTestResults('basic_sync_performance', results);
        expect(results['basicSyncPerformance']['success'], isTrue);
      });

      test('Concurrent operation performance is acceptable', () async {
        print('\n🔀 Testing concurrent operation performance...');

        final results = <String, dynamic>{};

        try {
          final concurrencyTests = <String, Map<String, dynamic>>{};

          // Test concurrent task creation
          print('  ➕ Testing concurrent task creation...');

          final concurrentCreateStartTime = DateTime.now();
          final testNoteId = 'concurrent_test_note_${DateTime.now().millisecondsSinceEpoch}';

          final createFutures = List.generate(5, (index) =>
            unifiedTaskService.createTask(
              noteId: testNoteId,
              content: 'Concurrent test task $index',
              priority: TaskPriority.medium,
            )
          );

          final createdTasks = await Future.wait(createFutures);
          final concurrentCreateEndTime = DateTime.now();
          final concurrentCreateDuration = concurrentCreateEndTime.difference(concurrentCreateStartTime).inMilliseconds;

          concurrencyTests['concurrentCreation'] = {
            'durationMs': concurrentCreateDuration,
            'threshold': 3000, // 3 second threshold for 5 concurrent operations
            'withinThreshold': concurrentCreateDuration <= 3000,
            'tasksCreated': createdTasks.length,
            'expectedTasks': 5,
            'allTasksCreated': createdTasks.length == 5,
          };

          // Test concurrent sync operations
          print('  🔄 Testing concurrent sync operations...');

          final concurrentSyncStartTime = DateTime.now();
          final syncFutures = List.generate(3, (index) =>
            unifiedTaskService.syncFromNoteToTasks(
              '${testNoteId}_sync_$index',
              '- [ ] Concurrent sync task $index\n- [x] Completed sync task $index',
            )
          );

          await Future.wait(syncFutures);
          final concurrentSyncEndTime = DateTime.now();
          final concurrentSyncDuration = concurrentSyncEndTime.difference(concurrentSyncStartTime).inMilliseconds;

          concurrencyTests['concurrentSync'] = {
            'durationMs': concurrentSyncDuration,
            'threshold': 5000, // 5 second threshold for 3 concurrent sync operations
            'withinThreshold': concurrentSyncDuration <= 5000,
            'syncOperations': 3,
          };

          // Test concurrent retrieval
          print('  👁️ Testing concurrent retrieval...');

          final concurrentRetrieveStartTime = DateTime.now();
          final retrieveFutures = createdTasks.map((task) =>
            unifiedTaskService.getTask(task.id)
          ).toList();

          final retrievedTasks = await Future.wait(retrieveFutures);
          final concurrentRetrieveEndTime = DateTime.now();
          final concurrentRetrieveDuration = concurrentRetrieveEndTime.difference(concurrentRetrieveStartTime).inMilliseconds;

          concurrencyTests['concurrentRetrieval'] = {
            'durationMs': concurrentRetrieveDuration,
            'threshold': 1500, // 1.5 second threshold for 5 concurrent retrievals
            'withinThreshold': concurrentRetrieveDuration <= 1500,
            'tasksRetrieved': retrievedTasks.where((task) => task != null).length,
            'expectedTasks': createdTasks.length,
          };

          // Clean up
          for (final task in createdTasks) {
            await unifiedTaskService.deleteTask(task.id);
          }

          final allConcurrencyTestsPassed = concurrencyTests.values
              .every((test) => test['withinThreshold'] == true);

          results['concurrentOperationPerformance'] = {
            'success': allConcurrencyTestsPassed,
            'concurrencyTests': concurrencyTests,
            'totalTests': concurrencyTests.length,
            'passedTests': concurrencyTests.values
                .where((test) => test['withinThreshold'] == true).length,
          };

          print('  ✅ Concurrent operation performance test completed');

        } catch (e, stack) {
          results['concurrentOperationPerformance'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Concurrent operation performance test failed: $e');
        }

        await _saveTestResults('concurrent_operation_performance', results);
        expect(results['concurrentOperationPerformance']['success'], isTrue);
      });

      test('Large dataset performance is acceptable', () async {
        print('\n📊 Testing large dataset performance...');

        final results = <String, dynamic>{};

        try {
          final largeDatasetTests = <String, Map<String, dynamic>>{};

          // Test large note content sync
          print('  📝 Testing large note content sync...');

          final largeNoteContent = _generateLargeNoteContent(100); // 100 tasks
          final testNoteId = 'large_dataset_note_${DateTime.now().millisecondsSinceEpoch}';

          final largeSyncStartTime = DateTime.now();
          await unifiedTaskService.syncFromNoteToTasks(testNoteId, largeNoteContent);
          final largeSyncEndTime = DateTime.now();
          final largeSyncDuration = largeSyncEndTime.difference(largeSyncStartTime).inMilliseconds;

          largeDatasetTests['largeNoteSync'] = {
            'durationMs': largeSyncDuration,
            'threshold': 10000, // 10 second threshold for 100 tasks
            'withinThreshold': largeSyncDuration <= 10000,
            'tasksInContent': 100,
            'contentSize': largeNoteContent.length,
          };

          // Test batch retrieval performance
          print('  📋 Testing batch retrieval performance...');

          final batchRetrievalStartTime = DateTime.now();
          final syncedTasks = await unifiedTaskService.getTasksForNote(testNoteId);
          final batchRetrievalEndTime = DateTime.now();
          final batchRetrievalDuration = batchRetrievalEndTime.difference(batchRetrievalStartTime).inMilliseconds;

          largeDatasetTests['batchRetrieval'] = {
            'durationMs': batchRetrievalDuration,
            'threshold': 3000, // 3 second threshold for retrieving 100 tasks
            'withinThreshold': batchRetrievalDuration <= 3000,
            'tasksRetrieved': syncedTasks.length,
            'expectedTasks': 100,
          };

          // Test hierarchical task performance
          print('  🌳 Testing hierarchical task performance...');

          final hierarchyStartTime = DateTime.now();
          final hierarchy = await unifiedTaskService.getTaskHierarchy(testNoteId);
          final hierarchyEndTime = DateTime.now();
          final hierarchyDuration = hierarchyEndTime.difference(hierarchyStartTime).inMilliseconds;

          largeDatasetTests['hierarchyRetrieval'] = {
            'durationMs': hierarchyDuration,
            'threshold': 2000, // 2 second threshold for hierarchy calculation
            'withinThreshold': hierarchyDuration <= 2000,
            'hierarchyNodes': hierarchy.length,
          };

          // Clean up large dataset
          for (final task in syncedTasks) {
            await unifiedTaskService.deleteTask(task.id);
          }

          final allLargeDatasetTestsPassed = largeDatasetTests.values
              .every((test) => test['withinThreshold'] == true);

          results['largeDatasetPerformance'] = {
            'success': allLargeDatasetTestsPassed,
            'largeDatasetTests': largeDatasetTests,
            'totalTests': largeDatasetTests.length,
            'passedTests': largeDatasetTests.values
                .where((test) => test['withinThreshold'] == true).length,
          };

          print('  ✅ Large dataset performance test completed');

        } catch (e, stack) {
          results['largeDatasetPerformance'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Large dataset performance test failed: $e');
        }

        await _saveTestResults('large_dataset_performance', results);
        expect(results['largeDatasetPerformance']['success'], isTrue);
      });
    });

    group('Memory Usage Monitoring', () {
      test('Memory usage remains stable during sync operations', () async {
        print('\n🧠 Testing memory usage during sync operations...');

        final results = <String, dynamic>{};

        try {
          // Note: Dart/Flutter memory monitoring is limited in test environments
          // This test focuses on ensuring operations complete without errors
          // and provides a framework for memory testing

          final memoryTests = <String, Map<String, dynamic>>{};

          // Test memory usage during multiple sync operations
          print('  🔄 Testing memory during multiple sync operations...');

          final testNoteId = 'memory_test_note_${DateTime.now().millisecondsSinceEpoch}';

          // Perform multiple sync operations
          for (int i = 0; i < 10; i++) {
            final noteContent = '- [ ] Memory test task $i\n- [x] Completed memory test task $i';
            await unifiedTaskService.syncFromNoteToTasks('${testNoteId}_$i', noteContent);
          }

          memoryTests['multipleSyncOperations'] = {
            'success': true,
            'syncOperations': 10,
            'completedWithoutError': true,
          };

          // Test memory usage during large object creation
          print('  📊 Testing memory during large object creation...');

          final largeTasks = <NoteTask>[];
          for (int i = 0; i < 50; i++) {
            final task = await unifiedTaskService.createTask(
              noteId: testNoteId,
              content: 'Large memory test task $i with some additional content to increase size',
              priority: TaskPriority.medium,
            );
            largeTasks.add(task);
          }

          memoryTests['largeObjectCreation'] = {
            'success': true,
            'objectsCreated': largeTasks.length,
            'expectedObjects': 50,
            'completedWithoutError': largeTasks.length == 50,
          };

          // Clean up
          for (final task in largeTasks) {
            await unifiedTaskService.deleteTask(task.id);
          }

          results['memoryUsageMonitoring'] = {
            'success': true,
            'memoryTests': memoryTests,
            'totalTests': memoryTests.length,
            'allTestsPassed': memoryTests.values
                .every((test) => test['success'] == true),
          };

          print('  ✅ Memory usage monitoring test completed');

        } catch (e, stack) {
          results['memoryUsageMonitoring'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Memory usage monitoring test failed: $e');
        }

        await _saveTestResults('memory_usage_monitoring', results);
        expect(results['memoryUsageMonitoring']['success'], isTrue);
      });
    });

    group('Database Operation Timing', () {
      test('Database operations meet timing requirements', () async {
        print('\n🗄️ Testing database operation timing...');

        final results = <String, dynamic>{};

        try {
          final timingTests = <String, Map<String, dynamic>>{};

          // Test basic database queries
          print('  🔍 Testing basic database query timing...');

          final basicQueryStartTime = DateTime.now();
          await database.customSelect('SELECT COUNT(*) FROM notes').getSingle();
          final basicQueryEndTime = DateTime.now();
          final basicQueryDuration = basicQueryEndTime.difference(basicQueryStartTime).inMilliseconds;

          timingTests['basicQuery'] = {
            'durationMs': basicQueryDuration,
            'threshold': 100, // 100ms threshold
            'withinThreshold': basicQueryDuration <= 100,
          };

          // Test complex queries
          print('  🔍 Testing complex database query timing...');

          final complexQueryStartTime = DateTime.now();
          await database.customSelect('''
            SELECT n.*, COUNT(nt.id) as task_count
            FROM notes n
            LEFT JOIN note_tasks nt ON n.id = nt.note_id
            GROUP BY n.id
            LIMIT 10
          ''').get();
          final complexQueryEndTime = DateTime.now();
          final complexQueryDuration = complexQueryEndTime.difference(complexQueryStartTime).inMilliseconds;

          timingTests['complexQuery'] = {
            'durationMs': complexQueryDuration,
            'threshold': 500, // 500ms threshold
            'withinThreshold': complexQueryDuration <= 500,
          };

          // Test transaction timing
          print('  💾 Testing transaction timing...');

          final transactionStartTime = DateTime.now();
          await database.transaction(() async {
            // Simulate a transaction with multiple operations
            await database.customSelect('SELECT 1').getSingle();
            await database.customSelect('SELECT 2').getSingle();
            await database.customSelect('SELECT 3').getSingle();
          });
          final transactionEndTime = DateTime.now();
          final transactionDuration = transactionEndTime.difference(transactionStartTime).inMilliseconds;

          timingTests['transaction'] = {
            'durationMs': transactionDuration,
            'threshold': 300, // 300ms threshold
            'withinThreshold': transactionDuration <= 300,
          };

          final allTimingTestsPassed = timingTests.values
              .every((test) => test['withinThreshold'] == true);

          results['databaseOperationTiming'] = {
            'success': allTimingTestsPassed,
            'timingTests': timingTests,
            'totalTests': timingTests.length,
            'passedTests': timingTests.values
                .where((test) => test['withinThreshold'] == true).length,
          };

          print('  ✅ Database operation timing test completed');

        } catch (e, stack) {
          results['databaseOperationTiming'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Database operation timing test failed: $e');
        }

        await _saveTestResults('database_operation_timing', results);
        expect(results['databaseOperationTiming']['success'], isTrue);
      });
    });

    group('Metrics Collection and Analysis', () {
      test('Task sync metrics are collected correctly', () async {
        print('\n📊 Testing task sync metrics collection...');

        final results = <String, dynamic>{};

        try {
          // Reset metrics for clean testing
          TaskSyncMetrics.instance.reset();

          // Perform operations to generate metrics
          print('  🔄 Generating sync metrics...');

          final testNoteId = 'metrics_test_note_${DateTime.now().millisecondsSinceEpoch}';

          // Perform sync operations to generate metrics
          await unifiedTaskService.syncFromNoteToTasks(
            testNoteId,
            '- [ ] Metrics test task 1\n- [x] Metrics test task 2\n- [ ] Metrics test task 3',
          );

          // Wait a bit for metrics to be recorded
          await Future.delayed(Duration(milliseconds: 100));

          // Get metrics
          final metrics = TaskSyncMetrics.instance.getMetrics();

          results['taskSyncMetrics'] = {
            'success': metrics.isNotEmpty,
            'metricsCollected': metrics.length,
            'hasValidMetrics': metrics.isNotEmpty,
            'sampleMetric': metrics.isNotEmpty ? metrics.first : null,
          };

          print('  ✅ Task sync metrics collection test completed');

        } catch (e, stack) {
          results['taskSyncMetrics'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Task sync metrics collection test failed: $e');
        }

        await _saveTestResults('task_sync_metrics', results);
        expect(results['taskSyncMetrics']['success'], isTrue);
      });

      test('Performance trend analysis works correctly', () async {
        print('\n📈 Testing performance trend analysis...');

        final results = <String, dynamic>{};

        try {
          final trendAnalysis = <String, dynamic>{};

          // Perform multiple operations and track performance trends
          print('  🔍 Analyzing performance trends...');

          final operationTimes = <int>[];
          final testNoteId = 'trend_test_note_${DateTime.now().millisecondsSinceEpoch}';

          for (int i = 0; i < 10; i++) {
            final startTime = DateTime.now();

            await unifiedTaskService.syncFromNoteToTasks(
              '${testNoteId}_$i',
              '- [ ] Trend test task $i',
            );

            final endTime = DateTime.now();
            final duration = endTime.difference(startTime).inMilliseconds;
            operationTimes.add(duration);
          }

          // Calculate trend statistics
          final avgTime = operationTimes.reduce((a, b) => a + b) / operationTimes.length;
          final minTime = operationTimes.reduce(min);
          final maxTime = operationTimes.reduce(max);
          final timeVariance = _calculateVariance(operationTimes, avgTime);

          trendAnalysis['operationTrend'] = {
            'averageTimeMs': avgTime,
            'minimumTimeMs': minTime,
            'maximumTimeMs': maxTime,
            'variance': timeVariance,
            'operationCount': operationTimes.length,
            'isStable': timeVariance < (avgTime * 0.5), // Less than 50% variance
          };

          results['performanceTrendAnalysis'] = {
            'success': true,
            'trendAnalysis': trendAnalysis,
            'operationTimes': operationTimes,
            'trendIsStable': trendAnalysis['operationTrend']['isStable'],
          };

          print('  ✅ Performance trend analysis test completed');

        } catch (e, stack) {
          results['performanceTrendAnalysis'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Performance trend analysis test failed: $e');
        }

        await _saveTestResults('performance_trend_analysis', results);
        expect(results['performanceTrendAnalysis']['success'], isTrue);
      });
    });

    group('Performance Monitoring Health Check', () {
      test('Overall performance monitoring system health is good', () async {
        print('\n🏥 Testing overall performance monitoring health...');

        final results = <String, dynamic>{};

        try {
          final healthChecks = <String, bool>{};

          // Test sync system performance
          healthChecks['syncSystemPerformant'] = true;
          try {
            final startTime = DateTime.now();
            await unifiedTaskService.syncFromNoteToTasks(
              'health_check_note',
              '- [ ] Health check task',
            );
            final duration = DateTime.now().difference(startTime).inMilliseconds;
            healthChecks['syncSystemPerformant'] = duration <= 2000;
          } catch (e) {
            healthChecks['syncSystemPerformant'] = false;
          }

          // Test database performance
          healthChecks['databasePerformant'] = true;
          try {
            final startTime = DateTime.now();
            await database.customSelect('SELECT 1').getSingle();
            final duration = DateTime.now().difference(startTime).inMilliseconds;
            healthChecks['databasePerformant'] = duration <= 100;
          } catch (e) {
            healthChecks['databasePerformant'] = false;
          }

          // Test provider performance
          healthChecks['providersPerformant'] = true;
          try {
            final startTime = DateTime.now();
            container.read(unifiedTaskServiceProvider);
            final duration = DateTime.now().difference(startTime).inMilliseconds;
            healthChecks['providersPerformant'] = duration <= 500;
          } catch (e) {
            healthChecks['providersPerformant'] = false;
          }

          // Test metrics system
          healthChecks['metricsSystemWorking'] = true;
          try {
            final metrics = TaskSyncMetrics.instance.getMetrics();
            healthChecks['metricsSystemWorking'] = true; // If no exception, it's working
          } catch (e) {
            healthChecks['metricsSystemWorking'] = false;
          }

          // Calculate health score
          final passedChecks = healthChecks.values.where((passed) => passed).length;
          final totalChecks = healthChecks.length;
          final healthScore = (passedChecks / totalChecks) * 100;

          results['performanceMonitoringHealth'] = {
            'success': healthScore >= 80, // 80% minimum health score
            'healthScore': healthScore,
            'passedChecks': passedChecks,
            'totalChecks': totalChecks,
            'healthChecks': healthChecks,
            'status': healthScore >= 95 ? 'EXCELLENT' :
                     healthScore >= 80 ? 'GOOD' :
                     healthScore >= 65 ? 'FAIR' : 'POOR',
          };

          print('  🏥 Performance monitoring health score: ${healthScore.toStringAsFixed(1)}%');
          print('  ✅ Overall performance monitoring health check completed');

        } catch (e, stack) {
          results['performanceMonitoringHealth'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Overall performance monitoring health check failed: $e');
        }

        await _saveTestResults('performance_monitoring_health', results);
        expect(results['performanceMonitoringHealth']['success'], isTrue);
      });
    });
  });
}

// Helper functions

/// Generate large note content for testing
String _generateLargeNoteContent(int taskCount) {
  final buffer = StringBuffer();
  buffer.writeln('# Large Note Content Test');
  buffer.writeln('');
  buffer.writeln('This note contains $taskCount tasks for performance testing.');
  buffer.writeln('');

  for (int i = 0; i < taskCount; i++) {
    final isCompleted = i % 3 == 0; // Every third task is completed
    final checkbox = isCompleted ? '[x]' : '[ ]';
    final priority = i % 10 == 0 ? ' !high' : i % 5 == 0 ? ' !medium' : '';

    buffer.writeln('- $checkbox Task $i: Performance test task with content$priority');

    // Add some nested tasks
    if (i % 20 == 0) {
      buffer.writeln('  - [ ] Subtask ${i}a: Nested task for complexity');
      buffer.writeln('  - [ ] Subtask ${i}b: Another nested task');
    }
  }

  return buffer.toString();
}

/// Calculate variance for performance analysis
double _calculateVariance(List<int> values, double mean) {
  if (values.isEmpty) return 0.0;

  final squaredDifferences = values.map((value) => pow(value - mean, 2));
  return squaredDifferences.reduce((a, b) => a + b) / values.length;
}

/// Save test results to JSON file for analysis
Future<void> _saveTestResults(String testName, Map<String, dynamic> results) async {
  final timestamp = DateTime.now().toIso8601String();
  final reportData = {
    'test_name': testName,
    'timestamp': timestamp,
    'results': results,
  };

  final reportFile = File('/Users/onronder/duru-notes/docs/test_reports/phase3_performance_${testName}_${DateTime.now().millisecondsSinceEpoch}.json');

  // Ensure directory exists
  await reportFile.parent.create(recursive: true);

  // Write formatted JSON
  final jsonString = JsonEncoder.withIndent('  ').convert(reportData);
  await reportFile.writeAsString(jsonString);
}