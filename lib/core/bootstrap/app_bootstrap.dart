import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:duru_notes/core/android_optimizations.dart';
import 'package:duru_notes/core/config/environment_config.dart';
import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/monitoring/sentry_config.dart';
import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/firebase_options.dart';
import 'package:duru_notes/services/analytics/analytics_factory.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/data/migrations/migration_tables_setup.dart';
import 'package:duru_notes/services/template_initialization_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Steps performed during application bootstrap.
enum BootstrapStage {
  environment,
  logging,
  platform,
  monitoring,
  firebase,
  supabase,
  migrations,
  featureFlags,
  analytics,
  adapty,
}

/// Error captured during bootstrap.
class BootstrapFailure {
  BootstrapFailure({
    required this.stage,
    required this.error,
    required this.stackTrace,
    this.critical = false,
    this.duration,
    this.timedOut = false,
  });

  final BootstrapStage stage;
  final Object error;
  final StackTrace stackTrace;
  final bool critical;
  final Duration? duration;
  final bool timedOut;
}

/// Result of running the application bootstrap sequence.
class BootstrapResult {
  BootstrapResult({
    required this.environment,
    required this.logger,
    required this.analytics,
    required this.supabaseClient,
    required this.firebaseApp,
    required this.sentryEnabled,
    required this.failures,
    required this.adaptyEnabled,
    this.warnings = const <String>[],
    this.environmentSource = 'unknown',
    this.stageDurations = const <BootstrapStage, Duration>{},
  });

  final EnvironmentConfig environment;
  final AppLogger logger;
  final AnalyticsService analytics;
  final SupabaseClient? supabaseClient;
  final FirebaseApp? firebaseApp;
  final bool sentryEnabled;
  final bool adaptyEnabled;
  final List<BootstrapFailure> failures;
  final List<String> warnings;
  final String environmentSource;
  final Map<BootstrapStage, Duration> stageDurations;

  bool get hasFailures => failures.isNotEmpty;
  bool get hasCriticalFailures => failures.any((failure) => failure.critical);
}

/// Coordinates initialization of environment, logging, and backend SDKs.
class AppBootstrap {
  AppBootstrap({EnvironmentConfigLoader? environmentLoader})
    : _environmentLoader = environmentLoader ?? EnvironmentConfigLoader();

  final EnvironmentConfigLoader _environmentLoader;
  static const Duration _stageTimeout = Duration(seconds: 8);

  // Track Adapty activation to prevent multiple activation attempts
  static bool _adaptyActivated = false;

  Future<BootstrapResult> initialize() async {
    final failures = <BootstrapFailure>[];
    final warnings = <String>[];
    final stageDurations = <BootstrapStage, Duration>{};
    EnvironmentConfig environment;
    String environmentSource = 'unknown';
    AppLogger logger = LoggerFactory.instance;

    // 1. Environment configuration
    final envResult = await _runStage<EnvironmentLoadResult>(
      stage: BootstrapStage.environment,
      logger: logger,
      failures: failures,
      stageDurations: stageDurations,
      action: () => _environmentLoader.load(),
    );
    if (envResult != null) {
      environment = envResult.config;
      warnings.addAll(envResult.warnings);
      environmentSource = envResult.source;
      if (envResult.usedFallback) {
        warnings.add(
          'Using fallback configuration - Supabase configuration missing',
        );
      }
    } else {
      environment = EnvironmentConfig.fallback();
      environmentSource = 'fallback';
      warnings.add('Using fallback configuration due to initialization error');
    }

    // 2. Logging
    await _runStage<void>(
      stage: BootstrapStage.logging,
      logger: logger,
      failures: failures,
      stageDurations: stageDurations,
      critical: true,
      action: () async {
        LoggerFactory.initialize(
          minLevel: environment.debugMode ? LogLevel.debug : LogLevel.info,
        );
      },
    );
    logger = LoggerFactory.instance;

    logger.info(
      'Environment loaded',
      data: {'source': environmentSource, 'summary': environment.safeSummary()},
    );

    logger.debug(
      'Bootstrap Supabase configuration',
      data: {
        'supabaseUrl': environment.supabaseUrl,
        'supabaseAnonKeyPreview': environment.supabaseAnonKey.isNotEmpty
            ? environment.supabaseAnonKey.substring(
                0,
                environment.supabaseAnonKey.length >= 6
                    ? 6
                    : environment.supabaseAnonKey.length,
              )
            : '<unset>',
      },
    );

    if (warnings.isNotEmpty) {
      logger.warning('Bootstrap warnings', data: {'warnings': warnings});
    }

    // 3. Platform-specific optimizations
    await _runStage<void>(
      stage: BootstrapStage.platform,
      logger: logger,
      failures: failures,
      stageDurations: stageDurations,
      action: AndroidOptimizations.initialize,
    );

    // 4. Monitoring (Sentry)
    bool sentryEnabled = false;
    await _runStage<void>(
      stage: BootstrapStage.monitoring,
      logger: logger,
      failures: failures,
      stageDurations: stageDurations,
      action: () async {
        SentryConfig.configure(environment: environment, logger: logger);
        await SentryConfig.initialize();
        sentryEnabled = SentryConfig.isInitialized;
      },
    );

    // 5. Firebase
    FirebaseApp? firebaseApp;
    await _runStage<void>(
      stage: BootstrapStage.firebase,
      logger: logger,
      failures: failures,
      stageDurations: stageDurations,
      action: () async {
        debugPrint('[Firebase] BEFORE Firebase.initializeApp()');
        firebaseApp = await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('[Firebase] AFTER Firebase.initializeApp()');
      },
    );
    if (firebaseApp == null) {
      logger.warning(
        'Firebase initialization failed - some features may be unavailable',
      );
    }

    // 6. Supabase
    SupabaseClient? supabaseClient;
    if (environment.isValid) {
      await _runStage<void>(
        stage: BootstrapStage.supabase,
        logger: logger,
        failures: failures,
        stageDurations: stageDurations,
        action: () async {
          await Supabase.initialize(
            url: environment.supabaseUrl,
            anonKey: environment.supabaseAnonKey,
            debug: environment.debugMode,
          );
          supabaseClient = Supabase.instance.client;
        },
      );
      if (supabaseClient == null) {
        logger.warning(
          'Supabase initialization failed - running in local-only mode',
        );
      }
    } else {
      warnings.add(
        'Supabase credentials not configured - using local-only mode',
      );
      logger.warning('Running in local-only mode without Supabase sync');
    }

    // 7. Migration System
    await _runStage<void>(
      stage: BootstrapStage.migrations,
      logger: logger,
      failures: failures,
      stageDurations: stageDurations,
      action: () async {
        if (supabaseClient != null) {
          final appDb = getAppDb();
          await MigrationTablesSetup.ensureMigrationTables(appDb);
          await MigrationTablesSetup.seedInitialMigrationData(appDb);
          await TemplateInitializationService.initializeDefaultTemplates(appDb);
          logger.info('Migration system initialized successfully');
        } else {
          logger.warning(
            'Skipping migration system initialization - Supabase not available',
          );
        }
      },
    );

    // 8. Feature flags
    await _runStage<void>(
      stage: BootstrapStage.featureFlags,
      logger: logger,
      failures: failures,
      stageDurations: stageDurations,
      action: () async {
        await FeatureFlags.instance.updateFromRemoteConfig();
        if (environment.debugMode) {
          logger.info(
            'Feature flags loaded',
            data: {
              'useNewBlockEditor': FeatureFlags.instance.useNewBlockEditor,
              'useRefactoredComponents':
                  FeatureFlags.instance.useRefactoredComponents,
              'useUnifiedPermissionManager':
                  FeatureFlags.instance.useUnifiedPermissionManager,
            },
          );
        }
      },
    );

    // 9. Analytics
    AnalyticsFactory.reset();
    AnalyticsFactory.configure(config: environment, logger: logger);
    AnalyticsService analytics;
    analytics = AnalyticsFactory.instance;
    await _runStage<void>(
      stage: BootstrapStage.analytics,
      logger: logger,
      failures: failures,
      stageDurations: stageDurations,
      action: () async {
        analytics = await AnalyticsFactory.initialize();
        if (environment.analyticsEnabled) {
          analytics.event(
            AnalyticsEvents.appLaunched,
            properties: {
              'environment': environment.environment.name,
              'debug_mode': environment.debugMode,
            },
          );
        }
      },
    );

    // 10. Adapty (optional)
    bool adaptyEnabled = false;
    final adaptyKey = environment.adaptyPublicApiKey;
    if (adaptyKey != null && adaptyKey.isNotEmpty) {
      if (_adaptyActivated) {
        logger.info('Adapty already activated - skipping reinitialization');
        adaptyEnabled = true;
      } else {
        await _runStage<void>(
          stage: BootstrapStage.adapty,
          logger: logger,
          failures: failures,
          stageDurations: stageDurations,
          action: () async {
            try {
              await Adapty().setLogLevel(
                environment.debugMode
                    ? AdaptyLogLevel.warn
                    : AdaptyLogLevel.error,
              );
              await Adapty()
                  .activate(
                    configuration: AdaptyConfiguration(apiKey: adaptyKey)
                      ..withActivateUI(true)
                      ..withAppleIdfaCollectionDisabled(true)
                      ..withIpAddressCollectionDisabled(true),
                  )
                  .timeout(
                    const Duration(seconds: 5),
                    onTimeout: () {
                      throw TimeoutException(
                        'Adapty activation timeout after 5 seconds',
                      );
                    },
                  );
              _adaptyActivated = true;
              adaptyEnabled = true;
              logger.info('Adapty initialized successfully');
            } catch (error) {
              if (_isAdaptyAlreadyActivatedError(error)) {
                logger.warning(
                  'Adapty already activated (error 3005) - continuing',
                );
                analytics.event(
                  AnalyticsEvents.appLaunched,
                  properties: {
                    'adapty_already_activated': true,
                    'error_code': '3005',
                    'bootstrap_stage': 'adapty',
                  },
                );
                _adaptyActivated = true;
                adaptyEnabled = true;
                return;
              }
              rethrow;
            }
          },
        );
      }
    }

    // 11. Preload SharedPreferences (CRITICAL iOS FIX)
    // This prevents main thread blocking when SharedPreferences is first accessed
    // The first getInstance() call makes a platform channel call that can block for 100-500ms
    await _runStage<void>(
      stage: BootstrapStage.platform,
      logger: logger,
      failures: failures,
      stageDurations: stageDurations,
      action: () async {
        try {
          debugPrint('[Bootstrap] Preloading SharedPreferences...');
          await SharedPreferences.getInstance();
          debugPrint('[Bootstrap] ✅ SharedPreferences preloaded');
        } catch (e, stack) {
          logger.warning(
            'SharedPreferences preload failed (non-critical)',
            data: {'error': e.toString()},
          );
          // Non-critical - app can continue
        }
      },
    );

    debugPrint(
      '[AppBootstrap] completed: failures=${failures.length} '
      'warnings=${warnings.length} sentry=$sentryEnabled',
    );
    return BootstrapResult(
      environment: environment,
      logger: logger,
      analytics: analytics,
      supabaseClient: supabaseClient,
      firebaseApp: firebaseApp,
      sentryEnabled: sentryEnabled,
      failures: failures,
      adaptyEnabled: adaptyEnabled,
      warnings: warnings,
      environmentSource: environmentSource,
      stageDurations: Map.unmodifiable(stageDurations),
    );
  }

  bool _isAdaptyAlreadyActivatedError(Object error) {
    final message = error.toString();
    return message.contains('3005') ||
        message.contains('activateOnceError') ||
        message.contains('can only be activated once');
  }

  Future<T?> _runStage<T>({
    required BootstrapStage stage,
    required AppLogger logger,
    required List<BootstrapFailure> failures,
    required Map<BootstrapStage, Duration> stageDurations,
    required Future<T> Function() action,
    bool critical = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    debugPrint('[AppBootstrap] Stage ${stage.name} started');
    try {
      final result = await action().timeout(_stageTimeout);
      debugPrint(
        '[AppBootstrap] Stage ${stage.name} completed in '
        '${stopwatch.elapsedMilliseconds}ms',
      );
      return result;
    } on TimeoutException catch (error) {
      debugPrint(
        '[AppBootstrap] Stage ${stage.name} timed out after '
        '${_stageTimeout.inSeconds}s',
      );
      final failure = BootstrapFailure(
        stage: stage,
        error: TimeoutException(
          'Stage timed out after ${_stageTimeout.inSeconds}s',
          error.duration ?? _stageTimeout,
        ),
        stackTrace: StackTrace.current,
        critical: critical,
        duration: stopwatch.elapsed,
        timedOut: true,
      );
      failures.add(failure);
      logger.warning(
        'Bootstrap stage timed out',
        data: {
          'stage': stage.name,
          'timeout_seconds': _stageTimeout.inSeconds,
        },
      );
      return null;
    } catch (error, stack) {
      debugPrint(
        '[AppBootstrap] Stage ${stage.name} failed: $error',
      );
      failures.add(
        BootstrapFailure(
          stage: stage,
          error: error,
          stackTrace: stack,
          critical: critical,
          duration: stopwatch.elapsed,
        ),
      );
      logger.error(
        'Bootstrap stage failed',
        error: error,
        stackTrace: stack,
        data: {'stage': stage.name},
      );
      return null;
    } finally {
      stopwatch.stop();
      stageDurations[stage] = stopwatch.elapsed;
      logger.debug(
        'Bootstrap stage finished',
        data: {
          'stage': stage.name,
          'duration_ms': stopwatch.elapsedMilliseconds,
        },
      );
    }
  }
}
