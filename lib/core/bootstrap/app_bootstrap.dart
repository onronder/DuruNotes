import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:duru_notes/core/android_optimizations.dart';
import 'package:duru_notes/core/config/environment_config.dart';
import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/monitoring/sentry_config.dart';
import 'package:duru_notes/firebase_options.dart';
import 'package:duru_notes/services/analytics/analytics_factory.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/data/migrations/migration_tables_setup.dart';
import 'package:duru_notes/data/local/app_db.dart';
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
        failures.add(
          BootstrapFailure(
            stage: BootstrapStage.environment,
            error: StateError('Supabase configuration missing'),
            stackTrace: StackTrace.current,
            critical: true,
          ),
        );
      }
    } catch (error, stack) {
      failures.add(
        BootstrapFailure(
          stage: BootstrapStage.environment,
          error: error,
          stackTrace: stack,
          critical: true,
        ),
      );
      environment = EnvironmentConfig.fallback();
      environmentSource = 'fallback';
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
      data: {
        'source': environmentSource,
        'summary': environment.safeSummary(),
      },
    );

    if (warnings.isNotEmpty) {
      logger.warning(
        'Bootstrap warnings',
        data: {'warnings': warnings},
      );
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
          critical: true,
        ),
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
            critical: true,
          ),
        );
      }
    } else {
      failures.add(
        BootstrapFailure(
          stage: BootstrapStage.supabase,
          error: StateError('Supabase credentials are not configured'),
          stackTrace: StackTrace.current,
          critical: true,
        ),
      );
    }

    // 7. Migration System
    try {
      if (supabaseClient != null) {
        // Initialize the app database instance for migration tables
        final appDb = AppDb();
        await MigrationTablesSetup.ensureMigrationTables(appDb);
        await MigrationTablesSetup.seedInitialMigrationData(appDb);

        logger.info('Migration system initialized successfully');
      } else {
        logger.warning('Skipping migration system initialization - Supabase not available');
      }
    } catch (error, stack) {
      failures.add(
        BootstrapFailure(
          stage: BootstrapStage.migrations,
          error: error,
          stackTrace: stack,
        ),
      );
      logger.warning('Migration system initialization failed', data: {
        'error': error.toString(),
      });
    }

    // 8. Feature flags
    try {
      await FeatureFlags.instance.updateFromRemoteConfig();
      if (environment.debugMode) {
        logger.info('Feature flags loaded', data: {
          'useNewBlockEditor': FeatureFlags.instance.useNewBlockEditor,
          'useRefactoredComponents':
              FeatureFlags.instance.useRefactoredComponents,
          'useUnifiedPermissionManager':
              FeatureFlags.instance.useUnifiedPermissionManager,
        });
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
      try {
        await Adapty().setLogLevel(
          environment.debugMode ? AdaptyLogLevel.warn : AdaptyLogLevel.error,
        );
        await Adapty().activate(
          configuration: AdaptyConfiguration(apiKey: adaptyKey)
            ..withActivateUI(true)
            ..withAppleIdfaCollectionDisabled(true)
            ..withIpAddressCollectionDisabled(true),
        );
        adaptyEnabled = true;
      } catch (error, stack) {
        failures.add(
          BootstrapFailure(
            stage: BootstrapStage.adapty,
            error: error,
            stackTrace: stack,
          ),
        );
        logger.warning('Adapty initialization failed', data: {
          'error': error.toString(),
        });
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
