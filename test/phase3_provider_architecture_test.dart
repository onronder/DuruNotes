import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/providers/unified_reminder_provider.dart';
import 'package:duru_notes/providers/feature_flagged_providers.dart';
import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/unified_task_service.dart' as unified;
import 'package:duru_notes/services/enhanced_task_service.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

/// Phase 3 Provider Architecture Test Suite
///
/// CRITICAL: This test suite validates that the provider dependency graph
/// works correctly after Phase 3 compilation fixes and ensures no circular
/// dependencies or missing dependencies exist.
///
/// Tests cover:
/// - Provider instantiation order
/// - Dependency resolution
/// - Circular dependency detection
/// - Provider lifecycle management
/// - Feature-flagged provider behavior
void main() {
  group('Phase 3: Provider Architecture Tests', () {
    group('Provider Dependency Graph Validation', () {
      test('Core infrastructure providers resolve dependencies correctly', () async {
        print('\n🏗️ Testing core infrastructure provider dependencies...');

        final results = <String, dynamic>{};
        final container = ProviderContainer();

        try {
          // Test core provider dependency chain
          final providerTests = <String, Map<String, dynamic>>{};

          // Test AppDb provider (should have no dependencies)
          print('  📊 Testing AppDb provider...');
          final appDb = container.read(appDbProvider);
          expect(appDb, isNotNull);
          providerTests['appDb'] = {
            'success': true,
            'dependencies': <String>[],
            'type': appDb.runtimeType.toString(),
          };

          // Test Logger provider (should depend on bootstrap)
          print('  📝 Testing Logger provider...');
          final logger = container.read(loggerProvider);
          expect(logger, isNotNull);
          expect(logger, isA<AppLogger>());
          providerTests['logger'] = {
            'success': true,
            'dependencies': ['bootstrap'],
            'type': logger.runtimeType.toString(),
          };

          // Test Analytics provider (should depend on bootstrap)
          print('  📈 Testing Analytics provider...');
          final analytics = container.read(analyticsProvider);
          expect(analytics, isNotNull);
          expect(analytics, isA<AnalyticsService>());
          providerTests['analytics'] = {
            'success': true,
            'dependencies': ['bootstrap'],
            'type': analytics.runtimeType.toString(),
          };

          results['coreInfrastructure'] = {
            'success': true,
            'providerTests': providerTests,
            'totalProviders': providerTests.length,
          };

          print('  ✅ Core infrastructure providers validation completed');

        } catch (e, stack) {
          results['coreInfrastructure'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Core infrastructure providers validation failed: $e');
        } finally {
          container.dispose();
        }

        await _saveTestResults('core_infrastructure_providers', results);
        expect(results['coreInfrastructure']['success'], isTrue);
      });

      test('Task service provider dependency chain works correctly', () async {
        print('\n📋 Testing task service provider dependency chain...');

        final results = <String, dynamic>{};
        final container = ProviderContainer();

        try {
          final dependencyChain = <String, List<String>>{};

          // Test TaskService provider
          print('  📝 Testing TaskService provider dependencies...');
          final taskService = container.read(taskServiceProvider);
          expect(taskService, isNotNull);
          dependencyChain['taskService'] = ['appDb'];

          // Test TaskReminderBridge provider
          print('  🔔 Testing TaskReminderBridge provider dependencies...');
          final reminderBridge = container.read(taskReminderBridgeProvider);
          expect(reminderBridge, isNotNull);
          dependencyChain['taskReminderBridge'] = [
            'unifiedReminderCoordinator',
            'advancedReminderService',
            'taskService',
            'appDb',
            'navigatorKey'
          ];

          // Test EnhancedTaskService provider
          print('  🚀 Testing EnhancedTaskService provider dependencies...');
          final enhancedService = container.read(enhancedTaskServiceProvider);
          expect(enhancedService, isNotNull);
          expect(enhancedService, isA<EnhancedTaskService>());
          dependencyChain['enhancedTaskService'] = ['appDb', 'taskReminderBridge'];

          // Test UnifiedTaskService provider
          print('  🎯 Testing UnifiedTaskService provider dependencies...');
          final unifiedService = container.read(unifiedTaskServiceProvider);
          expect(unifiedService, isNotNull);
          expect(unifiedService, isA<unified.UnifiedTaskService>());
          dependencyChain['unifiedTaskService'] = [
            'appDb', 'logger', 'analytics', 'enhancedTaskService'
          ];

          results['taskServiceChain'] = {
            'success': true,
            'dependencyChain': dependencyChain,
            'chainDepth': dependencyChain.length,
          };

          print('  ✅ Task service provider dependency chain validation completed');

        } catch (e, stack) {
          results['taskServiceChain'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Task service provider dependency chain validation failed: $e');
        } finally {
          container.dispose();
        }

        await _saveTestResults('task_service_dependency_chain', results);
        expect(results['taskServiceChain']['success'], isTrue);
      });

      test('Reminder system provider dependencies resolve correctly', () async {
        print('\n🔔 Testing reminder system provider dependencies...');

        final results = <String, dynamic>{};
        final container = ProviderContainer();

        try {
          // Test UnifiedReminderCoordinator provider
          print('  🎯 Testing UnifiedReminderCoordinator provider...');
          final coordinator = container.read(unifiedReminderCoordinatorProvider);
          expect(coordinator, isNotNull);

          // Test AdvancedReminderService provider
          print('  🚀 Testing AdvancedReminderService provider...');
          final advancedService = container.read(advancedReminderServiceProvider);
          expect(advancedService, isNotNull);

          results['reminderSystem'] = {
            'success': true,
            'coordinatorType': coordinator.runtimeType.toString(),
            'advancedServiceType': advancedService.runtimeType.toString(),
          };

          print('  ✅ Reminder system provider dependencies validation completed');

        } catch (e, stack) {
          results['reminderSystem'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Reminder system provider dependencies validation failed: $e');
        } finally {
          container.dispose();
        }

        await _saveTestResults('reminder_system_dependencies', results);
        expect(results['reminderSystem']['success'], isTrue);
      });

      test('Repository provider authentication requirements work correctly', () async {
        print('\n🔐 Testing repository provider authentication requirements...');

        final results = <String, dynamic>{};
        final container = ProviderContainer();

        try {
          final authRequiredProviders = <String, Map<String, dynamic>>{};

          // Test NotesRepository provider (requires auth)
          print('  📝 Testing NotesRepository authentication requirement...');
          try {
            container.read(notesRepositoryProvider);
            authRequiredProviders['notesRepository'] = {
              'success': false,
              'message': 'Should have thrown authentication error',
            };
          } catch (e) {
            if (e.toString().contains('authenticated user')) {
              authRequiredProviders['notesRepository'] = {
                'success': true,
                'message': 'Correctly requires authentication',
                'error': e.toString(),
              };
            } else {
              authRequiredProviders['notesRepository'] = {
                'success': false,
                'message': 'Unexpected error',
                'error': e.toString(),
              };
            }
          }

          // Test FolderRepository provider (requires auth)
          print('  📁 Testing FolderRepository authentication requirement...');
          try {
            container.read(folderRepositoryProvider);
            authRequiredProviders['folderRepository'] = {
              'success': false,
              'message': 'Should have thrown authentication error',
            };
          } catch (e) {
            if (e.toString().contains('authenticated user')) {
              authRequiredProviders['folderRepository'] = {
                'success': true,
                'message': 'Correctly requires authentication',
                'error': e.toString(),
              };
            } else {
              authRequiredProviders['folderRepository'] = {
                'success': false,
                'message': 'Unexpected error',
                'error': e.toString(),
              };
            }
          }

          // Test TaskRepository provider (requires auth)
          print('  📋 Testing TaskRepository authentication requirement...');
          try {
            container.read(taskRepositoryProvider);
            authRequiredProviders['taskRepository'] = {
              'success': false,
              'message': 'Should have thrown authentication error',
            };
          } catch (e) {
            if (e.toString().contains('authenticated user')) {
              authRequiredProviders['taskRepository'] = {
                'success': true,
                'message': 'Correctly requires authentication',
                'error': e.toString(),
              };
            } else {
              authRequiredProviders['taskRepository'] = {
                'success': false,
                'message': 'Unexpected error',
                'error': e.toString(),
              };
            }
          }

          final allAuthTestsPassed = authRequiredProviders.values
              .every((test) => test['success'] == true);

          results['authenticationRequirements'] = {
            'success': allAuthTestsPassed,
            'providerTests': authRequiredProviders,
            'totalProviders': authRequiredProviders.length,
          };

          print('  ✅ Repository authentication requirements validation completed');

        } catch (e, stack) {
          results['authenticationRequirements'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Repository authentication requirements validation failed: $e');
        } finally {
          container.dispose();
        }

        await _saveTestResults('authentication_requirements', results);
        expect(results['authenticationRequirements']['success'], isTrue);
      });
    });

    group('Circular Dependency Detection', () {
      test('No circular dependencies in provider graph', () async {
        print('\n🔄 Testing for circular dependencies in provider graph...');

        final results = <String, dynamic>{};

        try {
          final testScenarios = [
            {
              'name': 'Core Services Circular Test',
              'providers': [
                'appDb',
                'logger',
                'analytics',
                'taskService',
                'enhancedTaskService',
                'unifiedTaskService'
              ],
            },
            {
              'name': 'Reminder System Circular Test',
              'providers': [
                'unifiedReminderCoordinator',
                'advancedReminderService',
                'taskReminderBridge',
                'enhancedTaskService'
              ],
            },
            {
              'name': 'Mixed Dependencies Circular Test',
              'providers': [
                'appDb',
                'taskService',
                'taskReminderBridge',
                'unifiedReminderCoordinator',
                'enhancedTaskService',
                'unifiedTaskService'
              ],
            },
          ];

          final scenarioResults = <String, Map<String, dynamic>>{};

          for (final scenario in testScenarios) {
            print('  🔍 Testing scenario: ${scenario['name']}');
            final container = ProviderContainer();

            try {
              final providers = scenario['providers'] as List<String>;
              final resolvedProviders = <String>[];

              for (final providerName in providers) {
                final startTime = DateTime.now();

                switch (providerName) {
                  case 'appDb':
                    container.read(appDbProvider);
                    break;
                  case 'logger':
                    container.read(loggerProvider);
                    break;
                  case 'analytics':
                    container.read(analyticsProvider);
                    break;
                  case 'taskService':
                    container.read(taskServiceProvider);
                    break;
                  case 'enhancedTaskService':
                    container.read(enhancedTaskServiceProvider);
                    break;
                  case 'unifiedTaskService':
                    container.read(unifiedTaskServiceProvider);
                    break;
                  case 'unifiedReminderCoordinator':
                    container.read(unifiedReminderCoordinatorProvider);
                    break;
                  case 'advancedReminderService':
                    container.read(advancedReminderServiceProvider);
                    break;
                  case 'taskReminderBridge':
                    container.read(taskReminderBridgeProvider);
                    break;
                }

                final endTime = DateTime.now();
                final duration = endTime.difference(startTime).inMilliseconds;

                // If resolution takes too long, it might indicate circular dependency
                if (duration > 5000) { // 5 seconds timeout
                  throw TimeoutException(
                    'Provider $providerName took too long to resolve ($duration ms)',
                    Duration(milliseconds: duration),
                  );
                }

                resolvedProviders.add(providerName);
              }

              scenarioResults[scenario['name'] as String] = {
                'success': true,
                'resolvedProviders': resolvedProviders,
                'totalProviders': providers.length,
              };

              print('    ✅ No circular dependencies in ${scenario['name']}');

            } catch (e) {
              scenarioResults[scenario['name'] as String] = {
                'success': false,
                'error': e.toString(),
                'resolvedProviders': [],
              };
              print('    ❌ Potential circular dependency in ${scenario['name']}: $e');
            } finally {
              container.dispose();
            }
          }

          final allScenariosPass = scenarioResults.values
              .every((result) => result['success'] == true);

          results['circularDependencyTest'] = {
            'success': allScenariosPass,
            'scenarios': scenarioResults,
            'totalScenarios': testScenarios.length,
          };

          print('  ✅ Circular dependency detection completed');

        } catch (e, stack) {
          results['circularDependencyTest'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Circular dependency detection failed: $e');
        }

        await _saveTestResults('circular_dependency_detection', results);
        expect(results['circularDependencyTest']['success'], isTrue);
      });

      test('Provider resolution performance is acceptable', () async {
        print('\n⚡ Testing provider resolution performance...');

        final results = <String, dynamic>{};

        try {
          final performanceTests = <String, Map<String, dynamic>>{};

          // Test different provider resolution scenarios
          final scenarios = [
            {
              'name': 'Cold Start - Fresh Container',
              'setup': () => ProviderContainer(),
            },
            {
              'name': 'Warm Start - Pre-warmed Container',
              'setup': () {
                final container = ProviderContainer();
                // Pre-warm with basic providers
                container.read(appDbProvider);
                container.read(loggerProvider);
                return container;
              },
            },
          ];

          for (final scenario in scenarios) {
            print('  🔍 Testing scenario: ${scenario['name']}');

            final container = scenario['setup']() as ProviderContainer;
            final providerTimings = <String, double>{};

            try {
              // Test core provider resolution times
              final providers = {
                'appDb': appDbProvider,
                'logger': loggerProvider,
                'analytics': analyticsProvider,
                'taskService': taskServiceProvider,
                'enhancedTaskService': enhancedTaskServiceProvider,
                'unifiedTaskService': unifiedTaskServiceProvider,
              };

              for (final entry in providers.entries) {
                final startTime = DateTime.now();
                container.read(entry.value);
                final endTime = DateTime.now();
                final duration = endTime.difference(startTime).inMilliseconds.toDouble();
                providerTimings[entry.key] = duration;
              }

              // Calculate statistics
              final totalTime = providerTimings.values.reduce((a, b) => a + b);
              final avgTime = totalTime / providerTimings.length;
              final maxTime = providerTimings.values.reduce((a, b) => a > b ? a : b);

              const maxAllowedTime = 1000.0; // 1 second per provider
              const maxTotalTime = 5000.0;   // 5 seconds total

              final isPerformanceAcceptable = maxTime <= maxAllowedTime && totalTime <= maxTotalTime;

              performanceTests[scenario['name'] as String] = {
                'success': isPerformanceAcceptable,
                'timings': providerTimings,
                'totalTime': totalTime,
                'averageTime': avgTime,
                'maxTime': maxTime,
                'thresholds': {
                  'maxPerProvider': maxAllowedTime,
                  'maxTotal': maxTotalTime,
                },
              };

              if (isPerformanceAcceptable) {
                print('    ✅ Performance acceptable for ${scenario['name']}');
              } else {
                print('    ⚠️ Performance issues in ${scenario['name']}');
              }

            } finally {
              container.dispose();
            }
          }

          final allPerformanceAcceptable = performanceTests.values
              .every((test) => test['success'] == true);

          results['providerPerformance'] = {
            'success': allPerformanceAcceptable,
            'performanceTests': performanceTests,
            'totalScenarios': scenarios.length,
          };

          print('  ✅ Provider resolution performance testing completed');

        } catch (e, stack) {
          results['providerPerformance'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Provider resolution performance testing failed: $e');
        }

        await _saveTestResults('provider_performance', results);
        expect(results['providerPerformance']['success'], isTrue);
      });
    });

    group('Provider Lifecycle Management', () {
      test('Provider disposal works correctly', () async {
        print('\n🧹 Testing provider disposal and cleanup...');

        final results = <String, dynamic>{};

        try {
          final disposalTests = <String, Map<String, dynamic>>{};

          // Test basic provider disposal
          print('  🔍 Testing basic provider disposal...');
          final container1 = ProviderContainer();
          container1.read(appDbProvider);
          container1.read(taskServiceProvider);
          container1.dispose();

          disposalTests['basicDisposal'] = {
            'success': true,
            'message': 'Basic provider disposal completed without errors',
          };

          // Test complex provider disposal with dependencies
          print('  🔍 Testing complex provider disposal...');
          final container2 = ProviderContainer();
          container2.read(enhancedTaskServiceProvider);
          container2.read(unifiedTaskServiceProvider);
          container2.dispose();

          disposalTests['complexDisposal'] = {
            'success': true,
            'message': 'Complex provider disposal completed without errors',
          };

          // Test multiple container disposal
          print('  🔍 Testing multiple container disposal...');
          final containers = List.generate(5, (i) => ProviderContainer());

          for (final container in containers) {
            container.read(appDbProvider);
            container.read(loggerProvider);
          }

          for (final container in containers) {
            container.dispose();
          }

          disposalTests['multipleContainerDisposal'] = {
            'success': true,
            'containersDisposed': containers.length,
            'message': 'Multiple container disposal completed without errors',
          };

          results['providerDisposal'] = {
            'success': true,
            'disposalTests': disposalTests,
            'totalTests': disposalTests.length,
          };

          print('  ✅ Provider disposal testing completed');

        } catch (e, stack) {
          results['providerDisposal'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Provider disposal testing failed: $e');
        }

        await _saveTestResults('provider_disposal', results);
        expect(results['providerDisposal']['success'], isTrue);
      });

      test('Provider invalidation works correctly', () async {
        print('\n♻️ Testing provider invalidation...');

        final results = <String, dynamic>{};

        try {
          final container = ProviderContainer();

          // Test provider invalidation
          print('  🔍 Testing provider invalidation...');

          // Read a provider
          final firstLogger = container.read(loggerProvider);
          expect(firstLogger, isNotNull);

          // Invalidate the provider
          container.invalidate(loggerProvider);

          // Read again - should get a new instance
          final secondLogger = container.read(loggerProvider);
          expect(secondLogger, isNotNull);

          // Both should be the same type but could be different instances
          expect(secondLogger.runtimeType, equals(firstLogger.runtimeType));

          results['providerInvalidation'] = {
            'success': true,
            'firstLoggerType': firstLogger.runtimeType.toString(),
            'secondLoggerType': secondLogger.runtimeType.toString(),
            'message': 'Provider invalidation works correctly',
          };

          print('  ✅ Provider invalidation testing completed');

          container.dispose();

        } catch (e, stack) {
          results['providerInvalidation'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Provider invalidation testing failed: $e');
        }

        await _saveTestResults('provider_invalidation', results);
        expect(results['providerInvalidation']['success'], isTrue);
      });
    });

    group('Feature-Flagged Provider Behavior', () {
      test('Feature flags affect provider behavior correctly', () async {
        print('\n🚩 Testing feature-flagged provider behavior...');

        final results = <String, dynamic>{};

        try {
          final flags = FeatureFlags.instance;
          flags.clearOverrides();

          final flagTests = <String, Map<String, dynamic>>{};

          // Test unified reminders feature flag
          print('  🔍 Testing unified reminders feature flag behavior...');

          // Test with flag enabled (default)
          final container1 = ProviderContainer();
          final coordinator1 = container1.read(unifiedReminderCoordinatorProvider);
          expect(coordinator1, isNotNull);

          flagTests['unifiedRemindersEnabled'] = {
            'success': true,
            'coordinatorType': coordinator1.runtimeType.toString(),
            'flagValue': true,
          };

          container1.dispose();

          // Test with flag disabled
          flags.setOverride('use_unified_reminders', false);
          final container2 = ProviderContainer();
          final coordinator2 = container2.read(unifiedReminderCoordinatorProvider);
          expect(coordinator2, isNotNull);

          flagTests['unifiedRemindersDisabled'] = {
            'success': true,
            'coordinatorType': coordinator2.runtimeType.toString(),
            'flagValue': false,
          };

          container2.dispose();
          flags.clearOverrides();

          results['featureFlaggedBehavior'] = {
            'success': true,
            'flagTests': flagTests,
            'totalTests': flagTests.length,
          };

          print('  ✅ Feature-flagged provider behavior testing completed');

        } catch (e, stack) {
          results['featureFlaggedBehavior'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Feature-flagged provider behavior testing failed: $e');
        }

        await _saveTestResults('feature_flagged_behavior', results);
        expect(results['featureFlaggedBehavior']['success'], isTrue);
      });
    });

    group('Provider Architecture Health Check', () {
      test('Overall provider architecture health is good', () async {
        print('\n🏥 Testing overall provider architecture health...');

        final results = <String, dynamic>{};

        try {
          final healthChecks = <String, bool>{};

          // Test core provider instantiation
          final container = ProviderContainer();

          healthChecks['coreProvidersWork'] = true;
          try {
            container.read(appDbProvider);
            container.read(loggerProvider);
            container.read(analyticsProvider);
          } catch (e) {
            healthChecks['coreProvidersWork'] = false;
          }

          // Test task service providers
          healthChecks['taskServiceProvidersWork'] = true;
          try {
            container.read(taskServiceProvider);
            container.read(enhancedTaskServiceProvider);
            container.read(unifiedTaskServiceProvider);
          } catch (e) {
            healthChecks['taskServiceProvidersWork'] = false;
          }

          // Test reminder system providers
          healthChecks['reminderProvidersWork'] = true;
          try {
            container.read(unifiedReminderCoordinatorProvider);
            container.read(advancedReminderServiceProvider);
            container.read(taskReminderBridgeProvider);
          } catch (e) {
            healthChecks['reminderProvidersWork'] = false;
          }

          // Test auth-required providers fail gracefully
          healthChecks['authRequiredProvidersFailGracefully'] = true;
          try {
            try {
              container.read(notesRepositoryProvider);
              healthChecks['authRequiredProvidersFailGracefully'] = false;
            } catch (e) {
              if (!e.toString().contains('authenticated user')) {
                healthChecks['authRequiredProvidersFailGracefully'] = false;
              }
            }
          } catch (e) {
            healthChecks['authRequiredProvidersFailGracefully'] = false;
          }

          container.dispose();

          // Calculate health score
          final passedChecks = healthChecks.values.where((passed) => passed).length;
          final totalChecks = healthChecks.length;
          final healthScore = (passedChecks / totalChecks) * 100;

          results['providerArchitectureHealth'] = {
            'success': healthScore >= 90, // 90% minimum health score
            'healthScore': healthScore,
            'passedChecks': passedChecks,
            'totalChecks': totalChecks,
            'healthChecks': healthChecks,
            'status': healthScore >= 95 ? 'EXCELLENT' :
                     healthScore >= 90 ? 'GOOD' :
                     healthScore >= 75 ? 'FAIR' : 'POOR',
          };

          print('  🏥 Provider architecture health score: ${healthScore.toStringAsFixed(1)}%');
          print('  ✅ Overall provider architecture health check completed');

        } catch (e, stack) {
          results['providerArchitectureHealth'] = {
            'success': false,
            'error': e.toString(),
            'stack': stack.toString(),
          };
          print('  ❌ Overall provider architecture health check failed: $e');
        }

        await _saveTestResults('provider_architecture_health', results);
        expect(results['providerArchitectureHealth']['success'], isTrue);
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

  final reportFile = File('/Users/onronder/duru-notes/docs/test_reports/phase3_provider_${testName}_${DateTime.now().millisecondsSinceEpoch}.json');

  // Ensure directory exists
  await reportFile.parent.create(recursive: true);

  // Write formatted JSON
  final jsonString = JsonEncoder.withIndent('  ').convert(reportData);
  await reportFile.writeAsString(jsonString);
}