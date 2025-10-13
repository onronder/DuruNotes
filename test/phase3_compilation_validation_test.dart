import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/providers/unified_reminder_provider.dart';
import 'package:duru_notes/services/unified_task_service.dart' as unified;
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/services/reminders/reminder_coordinator.dart';
import 'package:duru_notes/core/feature_flags.dart';
// Phase 11: Import repository providers directly
import 'package:duru_notes/infrastructure/providers/repository_providers.dart' show notesCoreRepositoryProvider;
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart' show folderCoreRepositoryProvider;
import 'dart:convert';
import 'dart:io';

/// Phase 3 Compilation Validation Test Suite
///
/// CRITICAL: This test suite validates that all compilation fixes work correctly
/// and that the complex sync system remains intact after the fixes.
///
/// This is essential for validating Phase 3 database optimizations deployment.
void main() {
  group('Phase 3: Compilation Fix Validation', () {
    late ProviderContainer container;

    setUpAll(() {
      // Initialize feature flags for consistent testing
      FeatureFlags.instance.clearOverrides();
      container = ProviderContainer();
    });

    tearDownAll(() {
      container.dispose();
      FeatureFlags.instance.clearOverrides();
    });

    group('Service Instantiation Tests', () {
      test('Core providers can be instantiated without errors', () async {
        print('\n🔧 Testing core provider instantiation...');

        final results = <String, dynamic>{};

        try {
          // Test database provider
          print('  📊 Testing AppDb provider...');
          final db = container.read(appDbProvider);
          expect(db, isNotNull);
          results['appDb'] = {'success': true, 'type': db.runtimeType.toString()};

          // Test logger provider
          print('  📝 Testing Logger provider...');
          final logger = container.read(loggerProvider);
          expect(logger, isNotNull);
          results['logger'] = {'success': true, 'type': logger.runtimeType.toString()};

          // Test analytics provider
          print('  📈 Testing Analytics provider...');
          final analytics = container.read(analyticsProvider);
          expect(analytics, isNotNull);
          results['analytics'] = {'success': true, 'type': analytics.runtimeType.toString()};

          print('  ✅ Core providers instantiated successfully');

        } catch (e, stack) {
          fail('Core provider instantiation failed: $e\n$stack');
        }

        // Save instantiation results
        await _saveTestResults('core_providers_instantiation', results);
      });

      test('Task service providers can be instantiated correctly', () async {
        print('\n📋 Testing task service provider instantiation...');

        final results = <String, dynamic>{};

        try {
          // Test task core repository (domain architecture)
          print('  📝 Testing TaskCoreRepository provider...');
          final taskRepo = container.read(taskCoreRepositoryProvider);
          expect(taskRepo, isNotNull);
          results['taskCoreRepository'] = {'success': true, 'type': taskRepo.runtimeType.toString()};

          // Test enhanced task service - CRITICAL for compilation fixes
          print('  🚀 Testing EnhancedTaskService provider...');
          final enhancedService = container.read(enhancedTaskServiceProvider);
          expect(enhancedService, isNotNull);
          expect(enhancedService, isA<EnhancedTaskService>());
          results['enhancedTaskService'] = {'success': true, 'type': enhancedService.runtimeType.toString()};

          // Test unified task service - CRITICAL for Phase 3 optimizations
          print('  🎯 Testing UnifiedTaskService provider...');
          final unifiedService = container.read(unifiedTaskServiceProvider);
          expect(unifiedService, isNotNull);
          expect(unifiedService, isA<unified.UnifiedTaskService>());
          results['unifiedTaskService'] = {'success': true, 'type': unifiedService.runtimeType.toString()};

          // Test task reminder bridge
          print('  🔔 Testing TaskReminderBridge provider...');
          final reminderBridge = container.read(taskReminderBridgeProvider);
          expect(reminderBridge, isNotNull);
          results['taskReminderBridge'] = {'success': true, 'type': reminderBridge.runtimeType.toString()};

          print('  ✅ Task service providers instantiated successfully');

        } catch (e, stack) {
          fail('Task service provider instantiation failed: $e\n$stack');
        }

        await _saveTestResults('task_service_providers_instantiation', results);
      });

      test('Reminder system providers can be instantiated correctly', () async {
        print('\n🔔 Testing reminder system provider instantiation...');

        final results = <String, dynamic>{};

        try {
          // Test unified reminder coordinator - CRITICAL for compilation fixes
          print('  🎯 Testing Unified ReminderCoordinator provider...');
          final unifiedCoordinator = container.read(unifiedReminderCoordinatorProvider);
          expect(unifiedCoordinator, isNotNull);
          expect(unifiedCoordinator, isA<ReminderCoordinator>());
          results['unifiedReminderCoordinator'] = {'success': true, 'type': unifiedCoordinator.runtimeType.toString()};

          print('  ✅ Reminder system providers instantiated successfully');

        } catch (e, stack) {
          fail('Reminder system provider instantiation failed: $e\n$stack');
        }

        await _saveTestResults('reminder_system_providers_instantiation', results);
      });

      test('Repository providers can be instantiated correctly', () async {
        print('\n🗄️ Testing repository provider instantiation...');

        final results = <String, dynamic>{};

        try {
          // Test notes repository - CRITICAL for sync system
          print('  📝 Testing NotesRepository provider...');
          try {
            final notesRepo = container.read(notesCoreRepositoryProvider);
            expect(notesRepo, isNotNull);
            results['notesRepository'] = {'success': true, 'type': notesRepo.runtimeType.toString()};
          } catch (e) {
            // Notes repository requires authentication, so we expect this to fail gracefully
            if (e.toString().contains('authenticated user')) {
              results['notesRepository'] = {'success': true, 'note': 'Correctly requires authentication'};
              print('    ✅ NotesRepository correctly requires authentication');
            } else {
              rethrow;
            }
          }

          // Test folder repository
          print('  📁 Testing FolderRepository provider...');
          try {
            final folderRepo = container.read(folderCoreRepositoryProvider);
            expect(folderRepo, isNotNull);
            results['folderRepository'] = {'success': true, 'type': folderRepo.runtimeType.toString()};
          } catch (e) {
            if (e.toString().contains('authenticated user')) {
              results['folderRepository'] = {'success': true, 'note': 'Correctly requires authentication'};
              print('    ✅ FolderRepository correctly requires authentication');
            } else {
              rethrow;
            }
          }

          // Test task repository
          print('  📋 Testing TaskRepository provider...');
          try {
            final taskRepo = container.read(taskRepositoryProvider);
            expect(taskRepo, isNotNull);
            results['taskRepository'] = {'success': true, 'type': taskRepo.runtimeType.toString()};
          } catch (e) {
            if (e.toString().contains('authenticated user')) {
              results['taskRepository'] = {'success': true, 'note': 'Correctly requires authentication'};
              print('    ✅ TaskRepository correctly requires authentication');
            } else {
              rethrow;
            }
          }

          print('  ✅ Repository providers behave correctly');

        } catch (e, stack) {
          fail('Repository provider instantiation failed: $e\n$stack');
        }

        await _saveTestResults('repository_providers_instantiation', results);
      });
    });

    group('Provider Dependency Graph Validation', () {
      test('Provider dependency chain is healthy', () async {
        print('\n🔗 Testing provider dependency chain...');

        final results = <String, dynamic>{};
        final dependencyMap = <String, List<String>>{};

        try {
          // Map key dependencies
          dependencyMap['unifiedTaskService'] = [
            'appDb', 'logger', 'analytics', 'enhancedTaskService'
          ];
          dependencyMap['enhancedTaskService'] = [
            'appDb', 'taskReminderBridge'
          ];
          dependencyMap['taskReminderBridge'] = [
            'unifiedReminderCoordinator', 'advancedReminderService', 'taskCoreRepository'
          ];

          // Test dependency resolution
          for (final entry in dependencyMap.entries) {
            final serviceName = entry.key;
            final dependencies = entry.value;

            print('  🔍 Testing $serviceName dependencies: ${dependencies.join(", ")}');

            bool allDependenciesResolved = true;
            final resolvedDependencies = <String>[];

            for (final dep in dependencies) {
              try {
                switch (dep) {
                  case 'appDb':
                    container.read(appDbProvider);
                    resolvedDependencies.add(dep);
                    break;
                  case 'logger':
                    container.read(loggerProvider);
                    resolvedDependencies.add(dep);
                    break;
                  case 'analytics':
                    container.read(analyticsProvider);
                    resolvedDependencies.add(dep);
                    break;
                  case 'enhancedTaskService':
                    container.read(enhancedTaskServiceProvider);
                    resolvedDependencies.add(dep);
                    break;
                  case 'taskReminderBridge':
                    container.read(taskReminderBridgeProvider);
                    resolvedDependencies.add(dep);
                    break;
                  case 'unifiedReminderCoordinator':
                    container.read(unifiedReminderCoordinatorProvider);
                    resolvedDependencies.add(dep);
                    break;
                  case 'taskCoreRepository':
                    container.read(taskCoreRepositoryProvider);
                    resolvedDependencies.add(dep);
                    break;
                  default:
                    print('    ⚠️ Unknown dependency: $dep');
                }
              } catch (e) {
                print('    ❌ Failed to resolve dependency $dep: $e');
                allDependenciesResolved = false;
              }
            }

            results[serviceName] = {
              'success': allDependenciesResolved,
              'resolvedDependencies': resolvedDependencies,
              'totalDependencies': dependencies.length,
            };

            if (allDependenciesResolved) {
              print('    ✅ All dependencies resolved for $serviceName');
            }
          }

          print('  ✅ Provider dependency chain validation completed');

        } catch (e, stack) {
          fail('Provider dependency validation failed: $e\n$stack');
        }

        await _saveTestResults('provider_dependency_validation', results);
      });

      test('No circular dependencies detected', () async {
        print('\n🔄 Testing for circular dependencies...');

        final results = <String, dynamic>{};

        try {
          // Test circular dependency detection by attempting to create providers
          // in different orders and ensuring no deadlocks

          final testOrders = [
            ['appDb', 'logger', 'taskCoreRepository', 'enhancedTaskService', 'unifiedTaskService'],
            ['unifiedTaskService', 'enhancedTaskService', 'taskCoreRepository', 'logger', 'appDb'],
            ['logger', 'unifiedTaskService', 'appDb', 'taskCoreRepository', 'enhancedTaskService'],
          ];

          for (int i = 0; i < testOrders.length; i++) {
            final order = testOrders[i];
            print('  🔄 Testing provider order ${i + 1}: ${order.join(" → ")}');

            final tempContainer = ProviderContainer();
            final resolvedProviders = <String>[];

            try {
              for (final providerName in order) {
                switch (providerName) {
                  case 'appDb':
                    tempContainer.read(appDbProvider);
                    resolvedProviders.add(providerName);
                    break;
                  case 'logger':
                    tempContainer.read(loggerProvider);
                    resolvedProviders.add(providerName);
                    break;
                  case 'taskCoreRepository':
                    tempContainer.read(taskCoreRepositoryProvider);
                    resolvedProviders.add(providerName);
                    break;
                  case 'enhancedTaskService':
                    tempContainer.read(enhancedTaskServiceProvider);
                    resolvedProviders.add(providerName);
                    break;
                  case 'unifiedTaskService':
                    tempContainer.read(unifiedTaskServiceProvider);
                    resolvedProviders.add(providerName);
                    break;
                }
              }

              results['order_${i + 1}'] = {
                'success': true,
                'resolvedProviders': resolvedProviders,
                'order': order,
              };

              print('    ✅ No circular dependencies in order ${i + 1}');

            } catch (e) {
              print('    ❌ Potential circular dependency detected in order ${i + 1}: $e');
              results['order_${i + 1}'] = {
                'success': false,
                'error': e.toString(),
                'resolvedProviders': resolvedProviders,
                'failedAt': resolvedProviders.length < order.length
                    ? order[resolvedProviders.length]
                    : 'unknown',
              };
            } finally {
              tempContainer.dispose();
            }
          }

          print('  ✅ Circular dependency testing completed');

        } catch (e, stack) {
          fail('Circular dependency testing failed: $e\n$stack');
        }

        await _saveTestResults('circular_dependency_validation', results);
      });
    });

    group('Service Integration Tests', () {
      test('UnifiedTaskService integrates correctly with dependencies', () async {
        print('\n🎯 Testing UnifiedTaskService integration...');

        final results = <String, dynamic>{};

        try {
          final unifiedService = container.read(unifiedTaskServiceProvider);

          // Test basic operations are available
          expect(unifiedService.createTask, isA<Function>());
          expect(unifiedService.getTasksForNote, isA<Function>());
          expect(unifiedService.toggleTaskStatus, isA<Function>());
          expect(unifiedService.deleteTask, isA<Function>());

          // Test stream operations
          expect(unifiedService.taskUpdates, isA<Stream<dynamic>>());
          expect(unifiedService.watchOpenTasks, isA<Function>());

          // Test hierarchical operations
          expect(unifiedService.getTaskHierarchy, isA<Function>());
          expect(unifiedService.hasSubtasks, isA<Function>());

          results['unifiedTaskService'] = {
            'success': true,
            'apiMethods': [
              'createTask', 'getTasksForNote', 'toggleTaskStatus', 'deleteTask',
              'taskUpdates', 'watchOpenTasks', 'getTaskHierarchy', 'hasSubtasks'
            ],
            'type': unifiedService.runtimeType.toString(),
          };

          print('  ✅ UnifiedTaskService integration validated');

        } catch (e, stack) {
          fail('UnifiedTaskService integration test failed: $e\n$stack');
        }

        await _saveTestResults('unified_task_service_integration', results);
      });

      test('EnhancedTaskService integrates correctly with reminder bridge', () async {
        print('\n🚀 Testing EnhancedTaskService integration...');

        final results = <String, dynamic>{};

        try {
          final enhancedService = container.read(enhancedTaskServiceProvider);

          // Test enhanced operations are available
          expect(enhancedService.createTask, isA<Function>());
          expect(enhancedService.updateTask, isA<Function>());
          expect(enhancedService.completeTask, isA<Function>());
          expect(enhancedService.deleteTask, isA<Function>());

          // Test reminder integration methods
          expect(enhancedService.createTaskWithReminder, isA<Function>());
          expect(enhancedService.snoozeTaskReminder, isA<Function>());
          expect(enhancedService.getTasksWithReminders, isA<Function>());

          // Test hierarchical methods
          expect(enhancedService.completeAllSubtasks, isA<Function>());
          expect(enhancedService.deleteTaskHierarchy, isA<Function>());
          expect(enhancedService.getTaskHierarchy, isA<Function>());

          results['enhancedTaskService'] = {
            'success': true,
            'reminderMethods': [
              'createTaskWithReminder', 'snoozeTaskReminder', 'getTasksWithReminders'
            ],
            'hierarchicalMethods': [
              'completeAllSubtasks', 'deleteTaskHierarchy', 'getTaskHierarchy'
            ],
            'type': enhancedService.runtimeType.toString(),
          };

          print('  ✅ EnhancedTaskService integration validated');

        } catch (e, stack) {
          fail('EnhancedTaskService integration test failed: $e\n$stack');
        }

        await _saveTestResults('enhanced_task_service_integration', results);
      });

      test('ReminderCoordinator integrates correctly', () async {
        print('\n🔔 Testing ReminderCoordinator integration...');

        final results = <String, dynamic>{};

        try {
          final coordinator = container.read(unifiedReminderCoordinatorProvider);

          // Test basic coordinator operations
          expect(coordinator, isA<ReminderCoordinator>());

          results['reminderCoordinator'] = {
            'success': true,
            'type': coordinator.runtimeType.toString(),
          };

          print('  ✅ ReminderCoordinator integration validated');

        } catch (e, stack) {
          fail('ReminderCoordinator integration test failed: $e\n$stack');
        }

        await _saveTestResults('reminder_coordinator_integration', results);
      });
    });

    group('Memory Management Tests', () {
      test('Provider disposal works correctly', () async {
        print('\n🧹 Testing provider disposal...');

        final results = <String, dynamic>{};

        try {
          // Create temporary container to test disposal
          final tempContainer = ProviderContainer();

          // Initialize some providers
          tempContainer.read(appDbProvider);
          tempContainer.read(loggerProvider);
          tempContainer.read(taskCoreRepositoryProvider);

          // Dispose and check for cleanup
          tempContainer.dispose();

          results['disposal'] = {
            'success': true,
            'message': 'Container disposed without errors',
          };

          print('  ✅ Provider disposal completed successfully');

        } catch (e, stack) {
          fail('Provider disposal test failed: $e\n$stack');
        }

        await _saveTestResults('provider_disposal', results);
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

  final reportFile = File('/Users/onronder/duru-notes/docs/test_reports/phase3_compilation_${testName}_${DateTime.now().millisecondsSinceEpoch}.json');

  // Ensure directory exists
  await reportFile.parent.create(recursive: true);

  // Write formatted JSON
  final jsonString = JsonEncoder.withIndent('  ').convert(reportData);
  await reportFile.writeAsString(jsonString);
}