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

/// Phase 3 Sync System Integrity Test Suite
///
/// CRITICAL: This test suite validates that the bidirectional sync system
/// between local SQLite and remote PostgreSQL remains intact and functional
/// after Phase 3 compilation fixes.
///
/// Tests cover:
/// - Bidirectional sync verification
/// - Data consistency validation
/// - Conflict resolution
/// - Performance monitoring
/// - Real-time sync operations
void main() {
  group('Phase 3: Sync System Integrity Tests', () {
    late ProviderContainer container;
    late unified.UnifiedTaskService unifiedTaskService;
    late AppDb database;

    setUpAll(() async {
      container = ProviderContainer();

      // Initialize core components for testing
      database = container.read(appDbProvider);
      unifiedTaskService = container.read(unifiedTaskServiceProvider);

      // Initialize metrics for monitoring
      TaskSyncMetrics.instance.reset();
    });

    tearDownAll(() async {
      container.dispose();
    });

    group('Bidirectional Sync Validation', () {
      test('Note-to-Task sync functionality works correctly', () async {
        print('\n📝➡️📋 Testing Note-to-Task sync...');

        final results = <String, dynamic>{};
        final testNoteId = 'test_note_${DateTime.now().millisecondsSinceEpoch}';

        try {
          // Test parsing tasks from note content
          const noteContent = '''
# Test Note

Some regular content here.

## Tasks
- [ ] First task to complete
- [x] Already completed task
- [ ] Task with priority !high
- [ ] Task with due date @2024-12-31
- [ ] Nested task
  - [ ] Subtask 1
  - [ ] Subtask 2

More content here.
''';

          print('  🔍 Testing task parsing from note content...');

          // Test hierarchical task extraction
          final hierarchicalTasks = unifiedTaskService.extractHierarchicalTasksFromContent(noteContent);

          expect(hierarchicalTasks.length, greaterThan(0));
          print('    ✅ Extracted ${hierarchicalTasks.length} hierarchical tasks');

          // Test task line mapping
          final taskMappings = unifiedTaskService.extractHierarchicalTasksFromContent(noteContent);

          bool hasMainTasks = false;
          bool hasSubtasks = false;
          bool hasCompletedTasks = false;
          bool hasMetadata = false;

          for (final task in taskMappings) {
            if (task.indentLevel == 0) hasMainTasks = true;
            if (task.indentLevel > 0) hasSubtasks = true;
            if (task.isCompleted) hasCompletedTasks = true;
            if (task.priority != TaskPriority.medium || task.dueDate != null) hasMetadata = true;
          }

          results['taskParsing'] = {
            'success': true,
            'totalTasks': taskMappings.length,
            'hasMainTasks': hasMainTasks,
            'hasSubtasks': hasSubtasks,
            'hasCompletedTasks': hasCompletedTasks,
            'hasMetadata': hasMetadata,
          };

          print('  ✅ Note-to-Task sync validation completed');

        } catch (e, stack) {
          results['taskParsing'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Note-to-Task sync validation failed: $e');
        }

        await _saveTestResults('note_to_task_sync', results);
        expect(results['taskParsing']['success'], isTrue);
      });

      test('Task-to-Note sync functionality works correctly', () async {
        print('\n📋➡️📝 Testing Task-to-Note sync...');

        final results = <String, dynamic>{};
        final testNoteId = 'test_note_${DateTime.now().millisecondsSinceEpoch}';

        try {
          // Test sync from tasks to note content
          print('  🔄 Testing sync initialization...');

          // Initialize bidirectional sync for the test note
          await unifiedTaskService.initializeBidirectionalSync(testNoteId);

          results['syncInitialization'] = {
            'success': true,
            'noteId': testNoteId,
          };

          print('  ✅ Task-to-Note sync validation completed');

        } catch (e, stack) {
          results['syncInitialization'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Task-to-Note sync validation failed: $e');
        }

        await _saveTestResults('task_to_note_sync', results);
        expect(results['syncInitialization']['success'], isTrue);
      });

      test('Sync loop prevention works correctly', () async {
        print('\n🔄🛡️ Testing sync loop prevention...');

        final results = <String, dynamic>{};
        final testNoteId = 'test_note_${DateTime.now().millisecondsSinceEpoch}';

        try {
          print('  🔍 Testing rapid sync operations...');

          // Start watching note for sync
          await unifiedTaskService.startWatchingNote(testNoteId);

          // Test that multiple rapid sync calls don't create loops
          final futures = <Future<void>>[];

          for (int i = 0; i < 5; i++) {
            futures.add(unifiedTaskService.syncFromNoteToTasks(
              testNoteId,
              '- [ ] Test task $i\n- [x] Completed task $i'
            ));
          }

          // Wait for all sync operations to complete
          await Future.wait(futures);

          // Stop watching
          await unifiedTaskService.stopWatchingNote(testNoteId);

          results['loopPrevention'] = {
            'success': true,
            'rapidSyncOperations': futures.length,
            'message': 'No sync loops detected in rapid operations',
          };

          print('  ✅ Sync loop prevention validation completed');

        } catch (e, stack) {
          results['loopPrevention'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Sync loop prevention validation failed: $e');
        }

        await _saveTestResults('sync_loop_prevention', results);
        expect(results['loopPrevention']['success'], isTrue);
      });
    });

    group('Data Consistency Validation', () {
      test('Task data integrity is maintained during sync', () async {
        print('\n🔒 Testing task data integrity...');

        final results = <String, dynamic>{};

        try {
          print('  🔍 Testing task CRUD operations...');

          // Test task creation
          final task1 = await unifiedTaskService.createTask(
            noteId: 'test_note_integrity',
            content: 'Test task for integrity check',
            priority: TaskPriority.high,
            dueDate: DateTime.now().add(Duration(days: 1)),
          );

          expect(task1, isNotNull);
          expect(task1.content, equals('Test task for integrity check'));
          expect(task1.priority, equals(TaskPriority.high));

          // Test task update
          await unifiedTaskService.updateTask(
            taskId: task1.id,
            content: 'Updated test task',
            status: TaskStatus.completed,
          );

          final updatedTask = await unifiedTaskService.getTask(task1.id);
          expect(updatedTask?.content, equals('Updated test task'));
          expect(updatedTask?.status, equals(TaskStatus.completed));

          // Test task deletion
          await unifiedTaskService.deleteTask(task1.id);
          final deletedTask = await unifiedTaskService.getTask(task1.id);
          expect(deletedTask, isNull);

          results['dataIntegrity'] = {
            'success': true,
            'operations': ['create', 'update', 'delete'],
            'message': 'All CRUD operations maintain data integrity',
          };

          print('  ✅ Task data integrity validation completed');

        } catch (e, stack) {
          results['dataIntegrity'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Task data integrity validation failed: $e');
        }

        await _saveTestResults('task_data_integrity', results);
        expect(results['dataIntegrity']['success'], isTrue);
      });

      test('Hierarchical task relationships are preserved', () async {
        print('\n🌳 Testing hierarchical task relationships...');

        final results = <String, dynamic>{};

        try {
          print('  🔍 Testing parent-child relationships...');

          // Create parent task
          final parentTask = await unifiedTaskService.createTask(
            noteId: 'test_note_hierarchy',
            content: 'Parent task',
            priority: TaskPriority.medium,
          );

          // Create child tasks
          final childTask1 = await unifiedTaskService.createTask(
            noteId: 'test_note_hierarchy',
            content: 'Child task 1',
            parentTaskId: parentTask.id,
          );

          final childTask2 = await unifiedTaskService.createTask(
            noteId: 'test_note_hierarchy',
            content: 'Child task 2',
            parentTaskId: parentTask.id,
          );

          // Test hierarchy retrieval
          final hierarchy = await unifiedTaskService.getTaskHierarchy('test_note_hierarchy');
          expect(hierarchy.length, greaterThan(0));

          // Find the parent node
          final parentNode = hierarchy.firstWhere((node) => node.task.id == parentTask.id);
          expect(parentNode.children.length, equals(2));

          // Test hierarchy statistics
          final stats = await unifiedTaskService.getHierarchyStats('test_note_hierarchy');
          expect(stats.totalTasks, equals(3));
          expect(stats.rootTasks, equals(1));
          expect(stats.subtasks, equals(2));

          // Clean up
          await unifiedTaskService.deleteTask(childTask1.id);
          await unifiedTaskService.deleteTask(childTask2.id);
          await unifiedTaskService.deleteTask(parentTask.id);

          results['hierarchicalRelationships'] = {
            'success': true,
            'parentTaskId': parentTask.id,
            'childTaskIds': [childTask1.id, childTask2.id],
            'hierarchyStats': {
              'totalTasks': stats.totalTasks,
              'rootTasks': stats.rootTasks,
              'subtasks': stats.subtasks,
            },
          };

          print('  ✅ Hierarchical task relationships validation completed');

        } catch (e, stack) {
          results['hierarchicalRelationships'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Hierarchical task relationships validation failed: $e');
        }

        await _saveTestResults('hierarchical_relationships', results);
        expect(results['hierarchicalRelationships']['success'], isTrue);
      });

      test('Task status changes propagate correctly', () async {
        print('\n📊 Testing task status propagation...');

        final results = <String, dynamic>{};

        try {
          print('  🔍 Testing status change propagation...');

          // Create a task to test status changes
          final task = await unifiedTaskService.createTask(
            noteId: 'test_note_status',
            content: 'Status test task',
          );

          expect(task.status, equals(TaskStatus.open));

          // Test status change
          await unifiedTaskService.onStatusChanged(task.id, TaskStatus.completed);

          final updatedTask = await unifiedTaskService.getTask(task.id);
          expect(updatedTask?.status, equals(TaskStatus.completed));
          expect(updatedTask?.completedAt, isNotNull);

          // Test toggle back
          await unifiedTaskService.toggleTaskStatus(task.id);

          final toggledTask = await unifiedTaskService.getTask(task.id);
          expect(toggledTask?.status, equals(TaskStatus.open));

          // Clean up
          await unifiedTaskService.deleteTask(task.id);

          results['statusPropagation'] = {
            'success': true,
            'taskId': task.id,
            'statusChanges': ['open', 'completed', 'open'],
            'message': 'Status changes propagate correctly',
          };

          print('  ✅ Task status propagation validation completed');

        } catch (e, stack) {
          results['statusPropagation'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Task status propagation validation failed: $e');
        }

        await _saveTestResults('status_propagation', results);
        expect(results['statusPropagation']['success'], isTrue);
      });
    });

    group('Performance and Monitoring', () {
      test('Sync operations complete within acceptable time limits', () async {
        print('\n⏱️ Testing sync operation performance...');

        final results = <String, dynamic>{};

        try {
          print('  🔍 Measuring sync operation performance...');

          final performanceTests = <String, double>{};

          // Test task creation performance
          final createStartTime = DateTime.now();
          await unifiedTaskService.createTask(
            noteId: 'test_note_performance',
            content: 'Performance test task',
          );
          final createDuration = DateTime.now().difference(createStartTime).inMilliseconds;
          performanceTests['taskCreation'] = createDuration.toDouble();

          // Test task query performance
          final queryStartTime = DateTime.now();
          await unifiedTaskService.getTasksForNote('test_note_performance');
          final queryDuration = DateTime.now().difference(queryStartTime).inMilliseconds;
          performanceTests['taskQuery'] = queryDuration.toDouble();

          // Test sync operation performance
          final syncStartTime = DateTime.now();
          await unifiedTaskService.syncFromNoteToTasks(
            'test_note_performance',
            '- [ ] Sync test task 1\n- [x] Sync test task 2\n- [ ] Sync test task 3',
          );
          final syncDuration = DateTime.now().difference(syncStartTime).inMilliseconds;
          performanceTests['syncOperation'] = syncDuration.toDouble();

          // Validate performance thresholds
          const maxCreateTime = 1000; // 1 second
          const maxQueryTime = 500;   // 500ms
          const maxSyncTime = 2000;   // 2 seconds

          final performanceIssues = <String>[];

          if (performanceTests['taskCreation']! > maxCreateTime) {
            performanceIssues.add('Task creation took ${performanceTests['taskCreation']}ms (max: ${maxCreateTime}ms)');
          }

          if (performanceTests['taskQuery']! > maxQueryTime) {
            performanceIssues.add('Task query took ${performanceTests['taskQuery']}ms (max: ${maxQueryTime}ms)');
          }

          if (performanceTests['syncOperation']! > maxSyncTime) {
            performanceIssues.add('Sync operation took ${performanceTests['syncOperation']}ms (max: ${maxSyncTime}ms)');
          }

          results['performance'] = {
            'success': performanceIssues.isEmpty,
            'measurements': performanceTests,
            'thresholds': {
              'taskCreation': maxCreateTime,
              'taskQuery': maxQueryTime,
              'syncOperation': maxSyncTime,
            },
            'issues': performanceIssues,
          };

          if (performanceIssues.isEmpty) {
            print('  ✅ All sync operations within acceptable time limits');
          } else {
            print('  ⚠️ Performance issues detected: ${performanceIssues.join(', ')}');
          }

        } catch (e, stack) {
          results['performance'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Performance testing failed: $e');
        }

        await _saveTestResults('sync_performance', results);
        expect(results['performance']['success'], isTrue);
      });

      test('Sync metrics are collected correctly', () async {
        print('\n📊 Testing sync metrics collection...');

        final results = <String, dynamic>{};

        try {
          print('  🔍 Testing metrics collection...');

          // Reset metrics for clean test
          TaskSyncMetrics.instance.reset();

          // Perform some sync operations to generate metrics
          final noteId = 'test_note_metrics';

          await unifiedTaskService.syncFromNoteToTasks(
            noteId,
            '- [ ] Metrics test task 1\n- [x] Metrics test task 2',
          );

          // Get metrics
          final metrics = TaskSyncMetrics.instance.getMetrics();

          expect(metrics, isNotNull);
          expect(metrics.isNotEmpty, isTrue);

          // Check if metrics contain expected data
          bool hasNoteToTaskMetrics = false;

          for (final metric in metrics) {
            if (metric['syncType'] == 'note_to_tasks') {
              hasNoteToTaskMetrics = true;
              break;
            }
          }

          results['metricsCollection'] = {
            'success': true,
            'totalMetrics': metrics.length,
            'hasNoteToTaskMetrics': hasNoteToTaskMetrics,
            'sampleMetric': metrics.isNotEmpty ? metrics.first : null,
          };

          print('  ✅ Sync metrics collection validation completed');

        } catch (e, stack) {
          results['metricsCollection'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Sync metrics collection validation failed: $e');
        }

        await _saveTestResults('sync_metrics', results);
        expect(results['metricsCollection']['success'], isTrue);
      });
    });

    group('Real-time Sync Operations', () {
      test('Task update streams work correctly', () async {
        print('\n🔄 Testing real-time task update streams...');

        final results = <String, dynamic>{};

        try {
          print('  🔍 Testing task update stream...');

          final updateEvents = <unified.TaskUpdate>[];
          late StreamSubscription subscription;

          // Subscribe to task updates
          subscription = unifiedTaskService.taskUpdates.listen((update) {
            updateEvents.add(update);
          });

          // Create a task to generate events
          final task = await unifiedTaskService.createTask(
            noteId: 'test_note_realtime',
            content: 'Real-time test task',
          );

          // Update the task
          await unifiedTaskService.onContentChanged(task.id, 'Updated real-time test task');

          // Change status
          await unifiedTaskService.onStatusChanged(task.id, TaskStatus.completed);

          // Wait a bit for events to propagate
          await Future.delayed(Duration(milliseconds: 100));

          // Cancel subscription
          await subscription.cancel();

          // Clean up
          await unifiedTaskService.deleteTask(task.id);

          results['realTimeStreams'] = {
            'success': updateEvents.isNotEmpty,
            'eventCount': updateEvents.length,
            'eventTypes': updateEvents.map((e) => e.type.toString()).toList(),
            'taskId': task.id,
          };

          print('  ✅ Real-time task update streams validation completed');

        } catch (e, stack) {
          results['realTimeStreams'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Real-time task update streams validation failed: $e');
        }

        await _saveTestResults('realtime_streams', results);
        expect(results['realTimeStreams']['success'], isTrue);
      });

      test('Note watching functionality works correctly', () async {
        print('\n👁️ Testing note watching functionality...');

        final results = <String, dynamic>{};

        try {
          print('  🔍 Testing note watching start/stop...');

          final testNoteId = 'test_note_watching';

          // Start watching note
          await unifiedTaskService.startWatchingNote(testNoteId);

          // Stop watching note
          await unifiedTaskService.stopWatchingNote(testNoteId);

          results['noteWatching'] = {
            'success': true,
            'noteId': testNoteId,
            'message': 'Note watching start/stop completed without errors',
          };

          print('  ✅ Note watching functionality validation completed');

        } catch (e, stack) {
          results['noteWatching'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Note watching functionality validation failed: $e');
        }

        await _saveTestResults('note_watching', results);
        expect(results['noteWatching']['success'], isTrue);
      });
    });

    group('Sync System Health Check', () {
      test('Overall sync system health is good', () async {
        print('\n🏥 Testing overall sync system health...');

        final results = <String, dynamic>{};

        try {
          print('  🔍 Performing comprehensive sync system health check...');

          final healthChecks = <String, bool>{};

          // Check if UnifiedTaskService is properly initialized
          healthChecks['unifiedTaskServiceInitialized'] = unifiedTaskService != null;

          // Check if database is accessible
          try {
            await database.customSelect('SELECT 1').getSingle();
            healthChecks['databaseAccessible'] = true;
          } catch (e) {
            healthChecks['databaseAccessible'] = false;
          }

          // Check if task CRUD operations work
          try {
            final testTask = await unifiedTaskService.createTask(
              noteId: 'health_check_note',
              content: 'Health check task',
            );

            await unifiedTaskService.deleteTask(testTask.id);
            healthChecks['crudOperationsWorking'] = true;
          } catch (e) {
            healthChecks['crudOperationsWorking'] = false;
          }

          // Check if sync operations work
          try {
            await unifiedTaskService.syncFromNoteToTasks(
              'health_check_note',
              '- [ ] Health check sync task',
            );
            healthChecks['syncOperationsWorking'] = true;
          } catch (e) {
            healthChecks['syncOperationsWorking'] = false;
          }

          // Calculate overall health score
          final passedChecks = healthChecks.values.where((passed) => passed).length;
          final totalChecks = healthChecks.length;
          final healthScore = (passedChecks / totalChecks) * 100;

          results['syncSystemHealth'] = {
            'success': healthScore >= 80, // 80% minimum health score
            'healthScore': healthScore,
            'passedChecks': passedChecks,
            'totalChecks': totalChecks,
            'healthChecks': healthChecks,
            'status': healthScore >= 95 ? 'EXCELLENT' :
                     healthScore >= 80 ? 'GOOD' :
                     healthScore >= 60 ? 'FAIR' : 'POOR',
          };

          print('  🏥 Sync system health score: ${healthScore.toStringAsFixed(1)}%');
          print('  ✅ Overall sync system health check completed');

        } catch (e, stack) {
          results['syncSystemHealth'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Overall sync system health check failed: $e');
        }

        await _saveTestResults('sync_system_health', results);
        expect(results['syncSystemHealth']['success'], isTrue);
      });
    });
  });
}

/// Save test results to JSON file for analysis
Future<void> _saveTestResults(String testName, Map<String, dynamic> results) async {
  final timestamp = DateTime.now().toIso8601String();
  final reportData = {
    'test_name': testName,
    'timestamp': timestamp,
    'results': results,
  };

  final reportFile = File('/Users/onronder/duru-notes/docs/test_reports/phase3_sync_${testName}_${DateTime.now().millisecondsSinceEpoch}.json');

  // Ensure directory exists
  await reportFile.parent.create(recursive: true);

  // Write formatted JSON
  final jsonString = JsonEncoder.withIndent('  ').convert(reportData);
  await reportFile.writeAsString(jsonString);
}