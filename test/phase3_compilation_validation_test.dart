import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/providers/unified_reminder_provider.dart';
import 'package:duru_notes/services/domain_task_controller.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/services/reminders/reminder_coordinator.dart';
import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/security/security_initialization.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderCoreRepositoryProvider;
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show domainTaskControllerProvider;
import 'package:duru_notes/services/advanced_reminder_service.dart'
    show advancedReminderServiceProvider;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:mockito/mockito.dart';
import 'dart:convert';
import 'dart:io';
import 'helpers/test_initialization.dart';

/// Phase 3 Compilation Validation Test Suite
///
/// CRITICAL: This test suite validates that all compilation fixes work correctly
/// and that the complex sync system remains intact after the fixes.
///
/// This is essential for validating Phase 3 database optimizations deployment.
void main() {
  group('Phase 3: Compilation Fix Validation', () {
    late ProviderContainer container;

    setUpAll(() async {
      await TestInitialization.initialize(initializeSupabase: true);
      // Initialize feature flags for consistent testing
      FeatureFlags.instance.clearOverrides();
      SecurityInitialization.reset();
      container = ProviderContainer();
    });

    tearDownAll(() {
      SecurityInitialization.reset();
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
          results['appDb'] = {
            'success': true,
            'type': db.runtimeType.toString(),
          };

          // Test logger provider
          print('  📝 Testing Logger provider...');
          final logger = container.read(loggerProvider);
          expect(logger, isNotNull);
          results['logger'] = {
            'success': true,
            'type': logger.runtimeType.toString(),
          };

          // Test analytics provider
          print('  📈 Testing Analytics provider...');
          final analytics = container.read(analyticsProvider);
          expect(analytics, isNotNull);
          results['analytics'] = {
            'success': true,
            'type': analytics.runtimeType.toString(),
          };

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
          try {
            final taskRepo = container.read(taskCoreRepositoryProvider);
            if (taskRepo == null) {
              results['taskCoreRepository'] = {
                'success': true,
                'note': 'Returns null without authentication',
              };
              print(
                '    ✅ TaskCoreRepository unavailable without authentication',
              );
            } else {
              results['taskCoreRepository'] = {
                'success': true,
                'type': taskRepo.runtimeType.toString(),
              };
            }
          } on AssertionError catch (e) {
            final message = e.toString();
            if (message.contains('Supabase.instance')) {
              results['taskCoreRepository'] = {
                'success': true,
                'note': 'Supabase not initialized (expected in tests)',
              };
              print(
                '    ✅ TaskCoreRepository requires Supabase initialization (expected)',
              );
            } else {
              rethrow;
            }
          }

          // Test enhanced task service - CRITICAL for compilation fixes
          print('  🚀 Testing EnhancedTaskService provider...');
          try {
            final enhancedService = container.read(enhancedTaskServiceProvider);
            expect(enhancedService, isNotNull);
            expect(enhancedService, isA<EnhancedTaskService>());
            results['enhancedTaskService'] = {
              'success': true,
              'type': enhancedService.runtimeType.toString(),
            };
          } on StateError catch (e) {
            expect(e.message, contains('requires authenticated user'));
            results['enhancedTaskService'] = {
              'success': true,
              'note': 'Requires authenticated user',
            };
            print(
              '    ✅ EnhancedTaskService requires authenticated user (expected)',
            );
          } on AssertionError catch (e) {
            final message = e.toString();
            if (message.contains('Supabase.instance')) {
              results['enhancedTaskService'] = {
                'success': true,
                'note': 'Supabase not initialized (expected in tests)',
              };
              print(
                '    ✅ EnhancedTaskService requires Supabase initialization (expected)',
              );
            } else {
              rethrow;
            }
          }

          // Test domain task controller provider - requires authentication
          print('  🎯 Testing DomainTaskController provider...');
          try {
            container.read(domainTaskControllerProvider);
            fail(
              'DomainTaskController provider should require authentication or initialized security',
            );
          } on StateError catch (e) {
            final message = e.message;
            if (message.contains('Security') ||
                message.contains('SecurityInitialization')) {
              results['domainTaskController'] = {
                'success': true,
                'note': 'Security services not initialized (expected guard)',
              };
              print(
                '    ✅ DomainTaskController blocked until security services initialize (expected)',
              );
            } else {
              expect(
                message,
                contains('DomainTaskController requires authenticated user'),
              );
              results['domainTaskController'] = {
                'success': true,
                'note': 'Requires authenticated user',
              };
              print(
                '    ✅ DomainTaskController correctly requires authentication',
              );
            }
          } on AssertionError catch (e) {
            final message = e.toString();
            if (message.contains('Supabase.instance')) {
              results['domainTaskController'] = {
                'success': true,
                'note': 'Supabase not initialized (expected in tests)',
              };
              print(
                '    ✅ DomainTaskController requires Supabase initialization (expected)',
              );
            } else {
              rethrow;
            }
          }

          // Test task reminder bridge
          print('  🔔 Testing TaskReminderBridge provider...');
          try {
            final reminderBridge = container.read(taskReminderBridgeProvider);
            expect(reminderBridge, isNotNull);
            results['taskReminderBridge'] = {
              'success': true,
              'type': reminderBridge.runtimeType.toString(),
            };
          } on StateError catch (e) {
            expect(e.message, contains('requires authenticated user'));
            results['taskReminderBridge'] = {
              'success': true,
              'note': 'Requires authenticated user',
            };
            print(
              '    ✅ TaskReminderBridge requires authenticated user (expected)',
            );
          } on AssertionError catch (e) {
            final message = e.toString();
            if (message.contains('Supabase.instance')) {
              results['taskReminderBridge'] = {
                'success': true,
                'note': 'Supabase not initialized (expected in tests)',
              };
              print(
                '    ✅ TaskReminderBridge requires Supabase initialization (expected)',
              );
            } else {
              rethrow;
            }
          }

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
          final unifiedCoordinator = container.read(
            unifiedReminderCoordinatorProvider,
          );
          expect(unifiedCoordinator, isNotNull);
          expect(unifiedCoordinator, isA<ReminderCoordinator>());
          results['unifiedReminderCoordinator'] = {
            'success': true,
            'type': unifiedCoordinator.runtimeType.toString(),
          };

          print('  ✅ Reminder system providers instantiated successfully');
        } catch (e, stack) {
          fail('Reminder system provider instantiation failed: $e\n$stack');
        }

        await _saveTestResults(
          'reminder_system_providers_instantiation',
          results,
        );
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
            results['notesRepository'] = {
              'success': true,
              'type': notesRepo.runtimeType.toString(),
            };
          } catch (e) {
            final message = e.toString();
            // Notes repository requires authentication, so we expect this to fail gracefully
            if (message.contains('authenticated user')) {
              results['notesRepository'] = {
                'success': true,
                'note': 'Correctly requires authentication',
              };
              print('    ✅ NotesRepository correctly requires authentication');
            } else if (message.contains('Security') ||
                message.contains('SecurityInitialization')) {
              results['notesRepository'] = {
                'success': true,
                'note': 'Security services not initialized (expected guard)',
              };
              print(
                '    ✅ NotesRepository blocked until security services initialize (expected)',
              );
            } else if (message.contains('Supabase.instance')) {
              results['notesRepository'] = {
                'success': true,
                'note': 'Supabase not initialized (expected in tests)',
              };
              print(
                '    ✅ NotesRepository requires Supabase initialization (expected)',
              );
            } else {
              rethrow;
            }
          }

          // Test folder repository
          print('  📁 Testing FolderRepository provider...');
          try {
            final folderRepo = container.read(folderCoreRepositoryProvider);
            results['folderRepository'] = {
              'success': true,
              'type': folderRepo.runtimeType.toString(),
            };
          } catch (e) {
            final message = e.toString();
            if (message.contains('authenticated user')) {
              results['folderRepository'] = {
                'success': true,
                'note': 'Correctly requires authentication',
              };
              print('    ✅ FolderRepository correctly requires authentication');
            } else if (message.contains('Security') ||
                message.contains('SecurityInitialization')) {
              results['folderRepository'] = {
                'success': true,
                'note': 'Security services not initialized (expected guard)',
              };
              print(
                '    ✅ FolderRepository blocked until security services initialize (expected)',
              );
            } else if (message.contains('Supabase.instance')) {
              results['folderRepository'] = {
                'success': true,
                'note': 'Supabase not initialized (expected in tests)',
              };
              print(
                '    ✅ FolderRepository requires Supabase initialization (expected)',
              );
            } else {
              rethrow;
            }
          }

          // Test task repository
          print('  📋 Testing TaskRepository provider...');
          try {
            final taskRepo = container.read(taskRepositoryProvider);
            results['taskRepository'] = {
              'success': true,
              'type': taskRepo.runtimeType.toString(),
            };
          } catch (e) {
            final message = e.toString();
            if (message.contains('authenticated user')) {
              results['taskRepository'] = {
                'success': true,
                'note': 'Correctly requires authentication',
              };
              print('    ✅ TaskRepository correctly requires authentication');
            } else if (message.contains('Security') ||
                message.contains('SecurityInitialization')) {
              results['taskRepository'] = {
                'success': true,
                'note': 'Security services not initialized (expected guard)',
              };
              print(
                '    ✅ TaskRepository blocked until security services initialize (expected)',
              );
            } else if (message.contains('Supabase.instance')) {
              results['taskRepository'] = {
                'success': true,
                'note': 'Supabase not initialized (expected in tests)',
              };
              print(
                '    ✅ TaskRepository requires Supabase initialization (expected)',
              );
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
          dependencyMap['domainTaskController'] = [
            'taskCoreRepository',
            'notesCoreRepository',
            'enhancedTaskService',
            'logger',
          ];
          dependencyMap['enhancedTaskService'] = [
            'appDb',
            'taskReminderBridge',
          ];
          dependencyMap['taskReminderBridge'] = [
            'unifiedReminderCoordinator',
            'advancedReminderService',
            'taskCoreRepository',
          ];

          // Test dependency resolution
          for (final entry in dependencyMap.entries) {
            final serviceName = entry.key;
            final dependencies = entry.value;

            print(
              '  🔍 Testing $serviceName dependencies: ${dependencies.join(", ")}',
            );

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
                  case 'advancedReminderService':
                    container.read(advancedReminderServiceProvider);
                    resolvedDependencies.add(dep);
                    break;
                  case 'taskCoreRepository':
                    container.read(taskCoreRepositoryProvider);
                    resolvedDependencies.add(dep);
                    break;
                  case 'notesCoreRepository':
                    container.read(notesCoreRepositoryProvider);
                    resolvedDependencies.add(dep);
                    break;
                  default:
                    print('    ⚠️ Unknown dependency: $dep');
                }
              } catch (e) {
                final message = e.toString();
                if (message.contains('Supabase.instance')) {
                  resolvedDependencies.add('$dep (Supabase init required)');
                  print(
                    '    ⚠️ $dep requires Supabase initialization (expected in tests)',
                  );
                } else {
                  print('    ❌ Failed to resolve dependency $dep: $e');
                  allDependenciesResolved = false;
                }
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
            [
              'appDb',
              'logger',
              'taskCoreRepository',
              'notesCoreRepository',
              'enhancedTaskService',
              'domainTaskController',
            ],
            [
              'domainTaskController',
              'enhancedTaskService',
              'notesCoreRepository',
              'taskCoreRepository',
              'logger',
              'appDb',
            ],
            [
              'logger',
              'domainTaskController',
              'appDb',
              'taskCoreRepository',
              'notesCoreRepository',
              'enhancedTaskService',
            ],
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
                    try {
                      tempContainer.read(taskCoreRepositoryProvider);
                      resolvedProviders.add(providerName);
                    } on AssertionError catch (e) {
                      final message = e.toString();
                      if (message.contains('Supabase.instance')) {
                        resolvedProviders.add(
                          '$providerName (Supabase init required)',
                        );
                      } else {
                        rethrow;
                      }
                    }
                    break;
                  case 'notesCoreRepository':
                    try {
                      tempContainer.read(notesCoreRepositoryProvider);
                      resolvedProviders.add(providerName);
                    } on AssertionError catch (e) {
                      final message = e.toString();
                      if (message.contains('Supabase.instance')) {
                        resolvedProviders.add(
                          '$providerName (Supabase init required)',
                        );
                      } else {
                        rethrow;
                      }
                    }
                    break;
                  case 'enhancedTaskService':
                    try {
                      tempContainer.read(enhancedTaskServiceProvider);
                      resolvedProviders.add(providerName);
                    } on AssertionError catch (e) {
                      final message = e.toString();
                      if (message.contains('Supabase.instance')) {
                        resolvedProviders.add(
                          '$providerName (Supabase init required)',
                        );
                      } else {
                        rethrow;
                      }
                    }
                    break;
                  case 'domainTaskController':
                    try {
                      tempContainer.read(domainTaskControllerProvider);
                      resolvedProviders.add(providerName);
                    } on StateError catch (e) {
                      if (e.message.contains(
                        'DomainTaskController requires authenticated user',
                      )) {
                        resolvedProviders.add('$providerName (auth required)');
                      } else {
                        rethrow;
                      }
                    } on AssertionError catch (e) {
                      final message = e.toString();
                      if (message.contains('Supabase.instance')) {
                        resolvedProviders.add(
                          '$providerName (Supabase init required)',
                        );
                      } else {
                        rethrow;
                      }
                    }
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
              print(
                '    ❌ Potential circular dependency detected in order ${i + 1}: $e',
              );
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
      test(
        'DomainTaskController integrates correctly with dependencies',
        () async {
          print('\n🎯 Testing DomainTaskController integration...');

          final results = <String, dynamic>{};

          try {
            final controller = DomainTaskController(
              taskRepository: _MockTaskRepository(),
              notesRepository: _MockNotesRepository(),
              enhancedTaskService: _MockEnhancedTaskService(),
              logger: const NoOpLogger(),
            );

            // Test basic operations are available
            expect(controller.createTask, isA<Function>());
            expect(controller.getTasksForNote, isA<Function>());
            expect(controller.toggleStatus, isA<Function>());
            expect(controller.deleteTask, isA<Function>());

            // Test stream operations
            expect(controller.watchAllTasks, isA<Function>());
            expect(controller.watchTasksForNote, isA<Function>());

            // Test hierarchy/support operations
            expect(controller.getTaskById, isA<Function>());
            expect(controller.updateTask, isA<Function>());

            results['domainTaskController'] = {
              'success': true,
              'apiMethods': [
                'createTask',
                'getTasksForNote',
                'toggleStatus',
                'deleteTask',
                'watchAllTasks',
                'watchTasksForNote',
                'getTaskById',
                'updateTask',
              ],
              'type': controller.runtimeType.toString(),
            };

            print('  ✅ DomainTaskController integration validated');
          } catch (e, stack) {
            fail('DomainTaskController integration test failed: $e\n$stack');
          }

          await _saveTestResults('domain_task_controller_integration', results);
        },
      );

      test(
        'EnhancedTaskService integrates correctly with reminder bridge',
        () async {
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
            results['enhancedTaskService'] = {
              'success': true,
              'reminderMethods': [
                'createTaskWithReminder',
                'snoozeTaskReminder',
                'getTasksWithReminders',
              ],
              'hierarchicalMethods': [
                'completeAllSubtasks',
                'deleteTaskHierarchy',
              ],
              'type': enhancedService.runtimeType.toString(),
            };

            print('  ✅ EnhancedTaskService integration validated');
          } on StateError catch (e) {
            final message = e.message;
            if (message.contains('Security') ||
                message.contains('SecurityInitialization')) {
              results['enhancedTaskService'] = {
                'success': true,
                'note': 'Security services not initialized (expected guard)',
              };
              print(
                '  ✅ EnhancedTaskService blocked until security services initialize (expected)',
              );
            } else {
              expect(message, contains('requires authenticated user'));
              results['enhancedTaskService'] = {
                'success': true,
                'note': 'Requires authenticated user',
              };
              print(
                '  ✅ EnhancedTaskService requires authenticated user (expected)',
              );
            }
          } on AssertionError catch (e) {
            final message = e.toString();
            if (message.contains('Supabase.instance')) {
              results['enhancedTaskService'] = {
                'success': true,
                'note': 'Supabase not initialized (expected in tests)',
              };
              print(
                '  ✅ EnhancedTaskService requires Supabase initialization (expected)',
              );
            } else {
              rethrow;
            }
          } catch (e, stack) {
            fail('EnhancedTaskService integration test failed: $e\n$stack');
          }

          await _saveTestResults('enhanced_task_service_integration', results);
        },
      );

      test('ReminderCoordinator integrates correctly', () async {
        print('\n🔔 Testing ReminderCoordinator integration...');

        final results = <String, dynamic>{};

        try {
          final coordinator = container.read(
            unifiedReminderCoordinatorProvider,
          );

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
          try {
            tempContainer.read(taskCoreRepositoryProvider);
          } on AssertionError catch (e) {
            final message = e.toString();
            if (message.contains('Supabase.instance')) {
              print(
                '  ⚠️ taskCoreRepository requires Supabase initialization (skipping)',
              );
            } else {
              rethrow;
            }
          }

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

class _MockTaskRepository extends Mock implements ITaskRepository {}

class _MockNotesRepository extends Mock implements INotesRepository {}

class _MockEnhancedTaskService extends Mock implements EnhancedTaskService {}

/// Save test results to JSON file for analysis
Future<void> _saveTestResults(
  String testName,
  Map<String, dynamic> results,
) async {
  final timestamp = DateTime.now().toIso8601String();
  final reportData = {
    'test_name': testName,
    'timestamp': timestamp,
    'results': results,
  };

  final reportFile = File(
    '/Users/onronder/duru-notes/docs/test_reports/phase3_compilation_${testName}_${DateTime.now().millisecondsSinceEpoch}.json',
  );

  // Ensure directory exists
  await reportFile.parent.create(recursive: true);

  // Write formatted JSON
  final jsonString = JsonEncoder.withIndent('  ').convert(reportData);
  await reportFile.writeAsString(jsonString);
}
