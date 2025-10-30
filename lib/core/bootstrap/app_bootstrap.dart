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
  });

  final BootstrapStage stage;
  final Object error;
  final StackTrace stackTrace;
  final bool critical;
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

  bool get hasFailures => failures.isNotEmpty;
  bool get hasCriticalFailures => failures.any((failure) => failure.critical);
}

/// Coordinates initialization of environment, logging, and backend SDKs.
class AppBootstrap {
  AppBootstrap({EnvironmentConfigLoader? environmentLoader})
    : _environmentLoader = environmentLoader ?? EnvironmentConfigLoader();

  final EnvironmentConfigLoader _environmentLoader;

  // Track Adapty activation to prevent multiple activation attempts
  static bool _adaptyActivated = false;

  Future<BootstrapResult> initialize() async {
    final failures = <BootstrapFailure>[];
    final warnings = <String>[];
    EnvironmentConfig environment;
    String environmentSource = 'unknown';

    // 1. Environment configuration
    try {
      final loadResult = await _environmentLoader.load();
      environment = loadResult.config;
      warnings.addAll(loadResult.warnings);
      environmentSource = loadResult.source;
      if (loadResult.usedFallback) {
        warnings.add(
          'Using fallback configuration - Supabase configuration missing',
        );
      }
    } catch (error, stack) {
      failures.add(
        BootstrapFailure(
          stage: BootstrapStage.environment,
          error: error,
          stackTrace: stack,
          critical: false,
        ),
      );
      environment = EnvironmentConfig.fallback();
      environmentSource = 'fallback';
      warnings.add('Using fallback configuration due to initialization error');
    }

    // 2. Logging
    try {
      LoggerFactory.initialize(
        minLevel: environment.debugMode ? LogLevel.debug : LogLevel.info,
      );
    } catch (error, stack) {
      failures.add(
        BootstrapFailure(
          stage: BootstrapStage.logging,
          error: error,
          stackTrace: stack,
          critical: true,
        ),
      );
    }
    final logger = LoggerFactory.instance;

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
    try {
      await AndroidOptimizations.initialize();
    } catch (error, stack) {
      failures.add(
        BootstrapFailure(
          stage: BootstrapStage.platform,
          error: error,
          stackTrace: stack,
        ),
      );
    }

    // 4. Monitoring (Sentry)
    bool sentryEnabled = false;
    try {
      SentryConfig.configure(environment: environment, logger: logger);
      await SentryConfig.initialize();
      sentryEnabled = SentryConfig.isInitialized;
    } catch (error, stack) {
      failures.add(
        BootstrapFailure(
          stage: BootstrapStage.monitoring,
          error: error,
          stackTrace: stack,
        ),
      );
    }

    // 5. Firebase
    FirebaseApp? firebaseApp;
    try {
      firebaseApp = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (error, stack) {
      failures.add(
        BootstrapFailure(
          stage: BootstrapStage.firebase,
          error: error,
          stackTrace: stack,
          critical: false,
        ),
      );
      logger.warning(
        'Firebase initialization failed - some features may be unavailable',
      );
    }

    // 6. Supabase
    SupabaseClient? supabaseClient;
    if (environment.isValid) {
      try {
        await Supabase.initialize(
          url: environment.supabaseUrl,
          anonKey: environment.supabaseAnonKey,
          debug: environment.debugMode,
        );
        supabaseClient = Supabase.instance.client;
      } catch (error, stack) {
        failures.add(
          BootstrapFailure(
            stage: BootstrapStage.supabase,
            error: error,
            stackTrace: stack,
            critical: false,
          ),
        );
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
    try {
      if (supabaseClient != null) {
        // Use the singleton AppDb instance (prevents multiple instances)
        final appDb = getAppDb();
        await MigrationTablesSetup.ensureMigrationTables(appDb);
        await MigrationTablesSetup.seedInitialMigrationData(appDb);

        // Initialize default templates
        await TemplateInitializationService.initializeDefaultTemplates(appDb);

        logger.info('Migration system initialized successfully');
      } else {
        logger.warning(
          'Skipping migration system initialization - Supabase not available',
        );
      }
    } catch (error, stack) {
      failures.add(
        BootstrapFailure(
          stage: BootstrapStage.migrations,
          error: error,
          stackTrace: stack,
        ),
      );
      logger.warning(
        'Migration system initialization failed',
        data: {'error': error.toString()},
      );
    }

    // 8. Feature flags
    try {
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
    } catch (error, stack) {
      failures.add(
        BootstrapFailure(
          stage: BootstrapStage.featureFlags,
          error: error,
          stackTrace: stack,
        ),
      );
    }

    // 9. Analytics
    AnalyticsFactory.reset();
    AnalyticsFactory.configure(config: environment, logger: logger);
    AnalyticsService analytics;
    try {
      analytics = await AnalyticsFactory.initialize();
    } catch (error, stack) {
      failures.add(
        BootstrapFailure(
          stage: BootstrapStage.analytics,
          error: error,
          stackTrace: stack,
        ),
      );
      analytics = AnalyticsFactory.instance;
    }

    if (environment.analyticsEnabled) {
      try {
        analytics.event(
          AnalyticsEvents.appLaunched,
          properties: {
            'environment': environment.environment.name,
            'debug_mode': environment.debugMode,
          },
        );
      } catch (error, stack) {
        logger.warning(
          'Failed to record appLaunched analytics event',
          data: {'error': error.toString()},
        );
        failures.add(
          BootstrapFailure(
            stage: BootstrapStage.analytics,
            error: error,
            stackTrace: stack,
          ),
        );
      }
    }

    // 10. Adapty (optional)
    bool adaptyEnabled = false;
    final adaptyKey = environment.adaptyPublicApiKey;
    if (adaptyKey != null && adaptyKey.isNotEmpty) {
      // Skip if already activated (prevents multiple activation error)
      if (_adaptyActivated) {
        logger.info('Adapty already activated - skipping reinitialization');
        adaptyEnabled = true;
      } else {
        try {
          await Adapty().setLogLevel(
            environment.debugMode ? AdaptyLogLevel.warn : AdaptyLogLevel.error,
          );

          // Add timeout to prevent hanging on activation
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
        } catch (error, stack) {
          // If error is "activate once" error, treat as already activated
          if (error.toString().contains('3005') ||
              error.toString().contains('activateOnceError') ||
              error.toString().contains('can only be activated once')) {
            logger.warning(
              'Adapty already activated (error 3005) - continuing',
            );

            // Track error 3005 frequency for monitoring
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
          } else {
            failures.add(
              BootstrapFailure(
                stage: BootstrapStage.adapty,
                error: error,
                stackTrace: stack,
              ),
            );
            logger.warning(
              'Adapty initialization failed',
              data: {
                'error': error.toString(),
                'is_timeout': error is TimeoutException,
              },
            );
          }
        }
      }
    }

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
    );
  }
}
