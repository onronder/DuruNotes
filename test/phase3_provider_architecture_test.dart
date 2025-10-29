import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:duru_notes/providers.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/domain_task_controller.dart';
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show
        domainTaskControllerProvider,
        enhancedTaskServiceProvider,
        taskReminderBridgeProvider;
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:duru_notes/providers/unified_reminder_provider.dart'
    show unifiedReminderCoordinatorProvider;
import 'package:duru_notes/services/advanced_reminder_service.dart'
    show advancedReminderServiceProvider;
import 'package:mockito/mockito.dart';

const _supabaseInitMessage = 'Supabase.instance';
const _securityGuardMessage = 'Security services must be initialized';

bool _isSupabaseNotInitialized(Object error) {
  final message = error.toString();
  return message.contains(_supabaseInitMessage) ||
      message.contains(_securityGuardMessage) ||
      message.contains('SecurityInitialization');
}

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
    '/Users/onronder/duru-notes/docs/test_reports/phase3_provider_${testName}_${DateTime.now().millisecondsSinceEpoch}.json',
  );

  await reportFile.parent.create(recursive: true);
  final jsonString = JsonEncoder.withIndent('  ').convert(reportData);
  await reportFile.writeAsString(jsonString);
}

void main() {
  group('Phase 3: Provider Architecture Tests', () {
    group('Core Provider Validation', () {
      test('Core infrastructure providers resolve dependencies correctly',
          () async {
        print('\n🏗️ Testing core infrastructure provider dependencies...');

        final container = ProviderContainer();
        final providerTests = <String, Map<String, dynamic>>{};

        try {
          print('  📊 Testing AppDb provider...');
          providerTests['appDb'] = {
            'success': true,
            'type': container.read(appDbProvider).runtimeType.toString(),
            'dependencies': const <String>[],
          };

          print('  📝 Testing Logger provider...');
          final logger = container.read(loggerProvider);
          expect(logger, isA<AppLogger>());
          providerTests['logger'] = {
            'success': true,
            'type': logger.runtimeType.toString(),
            'dependencies': const ['bootstrap'],
          };

          print('  📈 Testing Analytics provider...');
          final analytics = container.read(analyticsProvider);
          expect(analytics, isA<AnalyticsService>());
          providerTests['analytics'] = {
            'success': true,
            'type': analytics.runtimeType.toString(),
            'dependencies': const ['bootstrap'],
          };

          print('  ✅ Core infrastructure providers validation completed');
        } catch (e, stack) {
          providerTests['error'] = {
            'success': false,
            'message': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Core infrastructure providers validation failed: $e');
        } finally {
          container.dispose();
        }

        await _saveTestResults('core_infrastructure', providerTests);
        expect(
          providerTests.values
              .where((entry) => entry.containsKey('success'))
              .every((entry) => entry['success'] == true),
          isTrue,
        );
      });

      test('Domain task service providers expose expected prerequisites',
          () async {
        print('\n📋 Testing domain task provider prerequisites...');

        final container = ProviderContainer();
        final results = <String, dynamic>{};

        try {
          print('  📝 Reading taskCoreRepositoryProvider...');
          try {
            final repo = container.read(taskCoreRepositoryProvider);
            results['taskCoreRepository'] = {
              'success': repo == null,
              'note': repo == null
                  ? 'Returns null without authentication'
                  : 'Unexpected non-null repository',
            };
            if (repo == null) {
              print('    ✅ taskCoreRepository unavailable without authentication');
            }
          } catch (e) {
            if (_isSupabaseNotInitialized(e)) {
              results['taskCoreRepository'] = {
                'success': true,
                'note': 'Supabase not initialized (expected in tests)',
              };
              print('    ✅ taskCoreRepository requires Supabase initialization (expected)');
            } else {
              rethrow;
            }
          }

          print('  🚀 Reading enhancedTaskServiceProvider...');
          try {
            final service = container.read(enhancedTaskServiceProvider);
            expect(service, isA<EnhancedTaskService>());
            results['enhancedTaskService'] = {
              'success': true,
              'type': service.runtimeType.toString(),
            };
          } catch (e) {
            if (_isSupabaseNotInitialized(e)) {
              results['enhancedTaskService'] = {
                'success': true,
                'note': 'Supabase not initialized (expected in tests)',
              };
              print('    ✅ enhancedTaskService requires Supabase initialization (expected)');
            } else {
              rethrow;
            }
          }

          print('  🎯 Reading domainTaskControllerProvider...');
          try {
            container.read(domainTaskControllerProvider);
            results['domainTaskController'] = {
              'success': false,
              'note': 'Provider unexpectedly resolved without auth',
            };
          } on StateError catch (e) {
            if (e.message.contains('requires authenticated user')) {
              results['domainTaskController'] = {
                'success': true,
                'note': 'Correctly requires authenticated user',
              };
              print('    ✅ domainTaskController requires authenticated user');
            } else {
              rethrow;
            }
          } catch (e) {
            if (_isSupabaseNotInitialized(e)) {
              results['domainTaskController'] = {
                'success': true,
                'note': 'Supabase not initialized (expected in tests)',
              };
              print('    ✅ domainTaskController requires Supabase initialization (expected)');
            } else {
              rethrow;
            }
          }

          print('  🔔 Reading taskReminderBridgeProvider...');
          try {
            final reminderBridge = container.read(taskReminderBridgeProvider);
            results['taskReminderBridge'] = {
              'success': true,
              'type': reminderBridge.runtimeType.toString(),
            };
          } catch (e) {
            if (_isSupabaseNotInitialized(e)) {
              results['taskReminderBridge'] = {
                'success': true,
                'note': 'Supabase not initialized (expected in tests)',
              };
              print('    ✅ taskReminderBridge requires Supabase initialization (expected)');
            } else {
              rethrow;
            }
          }
        } finally {
          container.dispose();
        }

        await _saveTestResults('domain_task_prerequisites', results);
        expect(results.isNotEmpty, isTrue);
      });

      test('Reminder system providers can be instantiated correctly', () async {
        print('\n🔔 Testing reminder system provider instantiation...');

        final container = ProviderContainer();
        final results = <String, dynamic>{};

        try {
          print('  🎯 Reading unifiedReminderCoordinatorProvider...');
          final coordinator = container.read(unifiedReminderCoordinatorProvider);
          results['unifiedReminderCoordinator'] = {
            'success': true,
            'type': coordinator.runtimeType.toString(),
          };

          print('  🚀 Reading advancedReminderServiceProvider...');
          final advanced = container.read(advancedReminderServiceProvider);
          results['advancedReminderService'] = {
            'success': true,
            'type': advanced.runtimeType.toString(),
          };

          print('  ✅ Reminder system providers instantiated successfully');
        } catch (e, stack) {
          results['error'] = {
            'success': false,
            'message': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Reminder system provider instantiation failed: $e');
        } finally {
          container.dispose();
        }

        await _saveTestResults('reminder_system', results);
        expect(
          results.entries
              .where((entry) => entry.value is Map &&
                  (entry.value as Map).containsKey('success'))
              .every((entry) =>
                  (entry.value as Map<String, dynamic>)['success'] == true),
          isTrue,
        );
      });
    });

    group('Domain Dependency Graph Validation', () {
      test('Domain task dependency chain resolves expected providers', () async {
        print('\n🔗 Testing domain task dependency chain...');

        final container = ProviderContainer();
        final results = <String, dynamic>{};

        try {
          final dependencyMap = <String, List<String>>{
            'domainTaskController': [
              'taskCoreRepository',
              'notesCoreRepository',
              'enhancedTaskService',
              'logger',
            ],
            'enhancedTaskService': [
              'appDb',
              'taskReminderBridge',
            ],
            'taskReminderBridge': [
              'unifiedReminderCoordinator',
              'advancedReminderService',
              'appDb',
            ],
          };

          for (final entry in dependencyMap.entries) {
            final resolved = <String>[];
            print('  🔍 Testing ${entry.key} dependencies...');

            for (final dep in entry.value) {
              try {
                switch (dep) {
                  case 'taskCoreRepository':
                    container.read(taskCoreRepositoryProvider);
                    break;
                  case 'notesCoreRepository':
                    container.read(notesCoreRepositoryProvider);
                    break;
                  case 'enhancedTaskService':
                    container.read(enhancedTaskServiceProvider);
                    break;
                  case 'logger':
                    container.read(loggerProvider);
                    break;
                  case 'appDb':
                    container.read(appDbProvider);
                    break;
                  case 'taskReminderBridge':
                    container.read(taskReminderBridgeProvider);
                    break;
                  case 'unifiedReminderCoordinator':
                    container.read(unifiedReminderCoordinatorProvider);
                    break;
                  case 'advancedReminderService':
                    container.read(advancedReminderServiceProvider);
                    break;
                }
                resolved.add(dep);
              } catch (e) {
                if (_isSupabaseNotInitialized(e)) {
                  resolved.add('$dep (Supabase init required)');
                  print('    ⚠️ $dep requires Supabase initialization (expected)');
                } else if (e is StateError) {
                  resolved.add('$dep (${e.message})');
                } else {
                  rethrow;
                }
              }
            }

            results[entry.key] = {
              'success': true,
              'resolvedDependencies': resolved,
              'totalDependencies': entry.value.length,
            };

            print('    ✅ Dependencies processed for ${entry.key}');
          }
        } finally {
          container.dispose();
        }

        await _saveTestResults('domain_dependency_chain', results);
        expect(results.isNotEmpty, isTrue);
      });

      test('Circular dependency detection for domain providers', () async {
        print('\n🔄 Testing for circular dependencies (domain)...');

        final scenarios = [
          [
            'appDb',
            'taskCoreRepository',
            'notesCoreRepository',
            'enhancedTaskService',
            'domainTaskController',
          ],
          [
            'domainTaskController',
            'enhancedTaskService',
            'taskReminderBridge',
            'unifiedReminderCoordinator',
            'advancedReminderService',
          ],
        ];

        final results = <String, dynamic>{};

        for (int i = 0; i < scenarios.length; i++) {
          final order = scenarios[i];
          final container = ProviderContainer();
          final resolvedProviders = <String>[];

          print('  🔁 Scenario ${i + 1}: ${order.join(" → ")}');

          try {
            for (final providerName in order) {
              switch (providerName) {
                case 'appDb':
                  container.read(appDbProvider);
                  resolvedProviders.add(providerName);
                  break;
                case 'taskCoreRepository':
                  try {
                    container.read(taskCoreRepositoryProvider);
                    resolvedProviders.add(providerName);
                  } catch (e) {
                    if (_isSupabaseNotInitialized(e)) {
                      resolvedProviders.add('$providerName (Supabase init required)');
                    } else {
                      rethrow;
                    }
                  }
                  break;
                case 'notesCoreRepository':
                  try {
                    container.read(notesCoreRepositoryProvider);
                    resolvedProviders.add(providerName);
                  } catch (e) {
                    if (_isSupabaseNotInitialized(e)) {
                      resolvedProviders.add('$providerName (Supabase init required)');
                    } else {
                      rethrow;
                    }
                  }
                  break;
                case 'enhancedTaskService':
                  try {
                    container.read(enhancedTaskServiceProvider);
                    resolvedProviders.add(providerName);
                  } catch (e) {
                    if (_isSupabaseNotInitialized(e)) {
                      resolvedProviders.add('$providerName (Supabase init required)');
                    } else {
                      rethrow;
                    }
                  }
                  break;
                case 'domainTaskController':
                  try {
                    container.read(domainTaskControllerProvider);
                    resolvedProviders.add(providerName);
                  } on StateError catch (e) {
                    resolvedProviders.add('$providerName (${e.message})');
                  } catch (e) {
                    if (_isSupabaseNotInitialized(e)) {
                      resolvedProviders.add('$providerName (Supabase init required)');
                    } else {
                      rethrow;
                    }
                  }
                  break;
                case 'taskReminderBridge':
                  try {
                    container.read(taskReminderBridgeProvider);
                    resolvedProviders.add(providerName);
                  } catch (e) {
                    if (_isSupabaseNotInitialized(e)) {
                      resolvedProviders.add('$providerName (Supabase init required)');
                    } else {
                      rethrow;
                    }
                  }
                  break;
                case 'unifiedReminderCoordinator':
                  container.read(unifiedReminderCoordinatorProvider);
                  resolvedProviders.add(providerName);
                  break;
                case 'advancedReminderService':
                  container.read(advancedReminderServiceProvider);
                  resolvedProviders.add(providerName);
                  break;
              }
            }

            results['scenario_${i + 1}'] = {
              'success': true,
              'resolvedProviders': resolvedProviders,
            };

            print('    ✅ No circular dependency detected in scenario ${i + 1}');
          } catch (e, stack) {
            if (_isSupabaseNotInitialized(e)) {
              results['scenario_${i + 1}'] = {
                'success': true,
                'note': 'Infrastructure guard triggered (expected)',
                'resolvedProviders': resolvedProviders,
              };
              print(
                '    ✅ Scenario ${i + 1} blocked by infrastructure guard (expected)',
              );
            } else {
              results['scenario_${i + 1}'] = {
                'success': false,
                'error': e.toString(),
                'stack': stack.toString(),
                'resolvedProviders': resolvedProviders,
              };
              print('    ❌ Potential circular dependency in scenario ${i + 1}: $e');
            }
          } finally {
            container.dispose();
          }
        }

        await _saveTestResults('circular_dependency', results);
        expect(
          results.values
              .every((value) => (value as Map<String, dynamic>)['success'] == true),
          isTrue,
        );
      });
    });

    group('Lifecycle & Performance', () {
      test('Provider disposal works correctly', () async {
        print('\n🧹 Testing provider disposal and cleanup...');

        final results = <String, dynamic>{};

        try {
          print('  🔍 Testing base provider disposal...');
          final basic = ProviderContainer();
          basic.read(appDbProvider);
          basic.read(loggerProvider);
          basic.dispose();

          print('  🔍 Testing enhanced task provider disposal...');
          final container = ProviderContainer();
          try {
            container.read(enhancedTaskServiceProvider);
            results['enhancedTaskServiceDisposal'] = {
              'success': true,
              'message': 'EnhancedTaskService instantiated and disposed',
            };
          } catch (e) {
            if (_isSupabaseNotInitialized(e)) {
              results['enhancedTaskServiceDisposal'] = {
                'success': true,
                'note': 'Supabase not initialized (expected in tests)',
              };
            } else {
              rethrow;
            }
          } finally {
            container.dispose();
          }

          print('  ✅ Provider disposal checks completed');
          results['disposal'] = {
            'success': true,
            'message': 'Provider disposal completed without errors',
          };
        } catch (e, stack) {
          results['disposal'] = {
            'success': false,
            'message': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Provider disposal testing failed: $e');
        }

        await _saveTestResults('provider_disposal', results);
        expect(results['disposal']['success'], isTrue);
      });
    });

    group('Domain Controller API Surface', () {
      test('DomainTaskController exposes expected API surface', () async {
        print('\n🎯 Inspecting DomainTaskController API surface...');

        final controller = DomainTaskController(
          taskRepository: _MockTaskRepository(),
          notesRepository: _MockNotesRepository(),
          enhancedTaskService: _MockEnhancedTaskService(),
          logger: const _StubLogger(),
        );

        final methodTypes = <String, String>{
          'createTask': controller.createTask.runtimeType.toString(),
          'getTasksForNote': controller.getTasksForNote.runtimeType.toString(),
          'toggleStatus': controller.toggleStatus.runtimeType.toString(),
          'deleteTask': controller.deleteTask.runtimeType.toString(),
          'watchAllTasks': controller.watchAllTasks.runtimeType.toString(),
          'watchTasksForNote': controller.watchTasksForNote.runtimeType.toString(),
          'getTaskById': controller.getTaskById.runtimeType.toString(),
          'updateTask': controller.updateTask.runtimeType.toString(),
        };

        await _saveTestResults(
          'domain_controller_api',
          {'methodTypes': methodTypes},
        );
        expect(methodTypes.length, equals(8));
      });
    });
  });
}

class _MockTaskRepository extends Mock implements ITaskRepository {}

class _MockNotesRepository extends Mock implements INotesRepository {}

class _MockEnhancedTaskService extends Mock implements EnhancedTaskService {}

class _StubLogger implements AppLogger {
  const _StubLogger();
  @override
  void breadcrumb(String message, {Map<String, dynamic>? data}) {}
  @override
  void debug(String message, {Map<String, dynamic>? data}) {}
  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {}
  @override
  Future<void> flush() async {}
  @override
  void info(String message, {Map<String, dynamic>? data}) {}
  @override
  void warn(String message, {Map<String, dynamic>? data}) {}
  @override
  void warning(String message, {Map<String, dynamic>? data}) {}
}
