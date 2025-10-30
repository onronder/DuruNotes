import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:duru_notes/core/android_optimizations.dart';
import 'package:duru_notes/core/bootstrap/bootstrap_error.dart';
import 'package:duru_notes/core/config/environment_config.dart';
import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/monitoring/sentry_config.dart';
import 'package:duru_notes/firebase_options.dart';
import 'package:duru_notes/services/analytics/analytics_factory.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Enhanced result of running the application bootstrap sequence
class EnhancedBootstrapResult {
  EnhancedBootstrapResult({
    required this.environment,
    required this.logger,
    required this.analytics,
    required this.errorManager,
    required this.duration,
    this.supabaseClient,
    this.firebaseApp,
    this.sentryEnabled = false,
    this.adaptyEnabled = false,
    this.warnings = const <String>[],
    this.environmentSource = 'unknown',
    this.degradedMode = false,
    this.offlineMode = false,
  });

  final EnvironmentConfig environment;
  final AppLogger logger;
  final AnalyticsService analytics;
  final SupabaseClient? supabaseClient;
  final FirebaseApp? firebaseApp;
  final bool sentryEnabled;
  final bool adaptyEnabled;
  final BootstrapErrorManager errorManager;
  final List<String> warnings;
  final String environmentSource;
  final Duration duration;
  final bool degradedMode;
  final bool offlineMode;

  bool get hasErrors => errorManager.errors.isNotEmpty;
  bool get hasCriticalErrors => errorManager.hasCriticalErrors;
  bool get isFullyFunctional => !hasErrors && !degradedMode && !offlineMode;
}

/// Progress callback for bootstrap process
typedef BootstrapProgressCallback =
    void Function(BootstrapStage stage, double progress, String? message);

/// Enhanced application bootstrap with retry logic and timeout handling
class EnhancedAppBootstrap {
  EnhancedAppBootstrap({
    EnvironmentConfigLoader? environmentLoader,
    this.maxBootstrapDuration = const Duration(seconds: 30),
    this.progressCallback,
  }) : _environmentLoader = environmentLoader ?? EnvironmentConfigLoader();

  final EnvironmentConfigLoader _environmentLoader;
  final Duration maxBootstrapDuration;
  final BootstrapProgressCallback? progressCallback;

  late final BootstrapErrorManager _errorManager;
  late final RetryRecoveryStrategy _retryStrategy;

  /// Initialize the application with enhanced error handling
  Future<EnhancedBootstrapResult> initialize() async {
    final startTime = DateTime.now();
    _errorManager = BootstrapErrorManager();
    _retryStrategy = RetryRecoveryStrategy(
      maxRetries: 3,
      delayMs: 1000,
      backoffMultiplier: 2.0,
    );

    // Wrap the entire bootstrap in a timeout
    try {
      return await _performBootstrap(startTime).timeout(maxBootstrapDuration);
    } on TimeoutException {
      _errorManager.addError(
        BootstrapError(
          stage: BootstrapStage.environment,
          error: TimeoutException('Bootstrap timeout exceeded'),
          stackTrace: StackTrace.current,
          severity: BootstrapErrorSeverity.fatal,
          message: 'Application initialization took too long',
          retryable: false,
        ),
      );

      // Return a fallback result
      return _createFallbackResult(startTime);
    }
  }

  Future<EnhancedBootstrapResult> _performBootstrap(DateTime startTime) async {
    final warnings = <String>[];
    bool degradedMode = false;
    bool offlineMode = false;

    // Progress tracking
    const totalStages = 9;
    var currentStage = 0;

    void reportProgress(BootstrapStage stage, String? message) {
      currentStage++;
      progressCallback?.call(stage, currentStage / totalStages, message);
    }

    // 1. Environment configuration
    reportProgress(BootstrapStage.environment, 'Loading configuration');
    final envResult = await _initializeEnvironment();
    final environment = envResult.environment;
    warnings.addAll(envResult.warnings);

    // 2. Logging
    reportProgress(BootstrapStage.logging, 'Initializing logging');
    final logger = await _initializeLogging(environment);

    // Log bootstrap start
    logger.info(
      'Bootstrap started',
      data: {
        'environment': environment.environment.name,
        'debugMode': environment.debugMode,
      },
    );

    // 3. Platform-specific optimizations
    reportProgress(BootstrapStage.platform, 'Platform optimization');
    await _initializePlatform(logger);

    // 4. Monitoring (Sentry)
    reportProgress(BootstrapStage.monitoring, 'Setting up monitoring');
    final sentryEnabled = await _initializeMonitoring(environment, logger);

    // 5. Firebase
    reportProgress(BootstrapStage.firebase, 'Connecting to Firebase');
    final firebaseApp = await _initializeFirebase(logger);
    if (firebaseApp == null) degradedMode = true;

    // 6. Supabase
    reportProgress(BootstrapStage.supabase, 'Connecting to database');
    final supabaseClient = await _initializeSupabase(environment, logger);
    if (supabaseClient == null) {
      degradedMode = true;
      offlineMode = true;
    }

    // 7. Feature flags
    reportProgress(BootstrapStage.featureFlags, 'Loading features');
    await _initializeFeatureFlags(logger);

    // 8. Analytics
    reportProgress(BootstrapStage.analytics, 'Setting up analytics');
    final analytics = await _initializeAnalytics(environment, logger);

    // 9. Adapty (optional)
    reportProgress(BootstrapStage.adapty, 'Premium features');
    final adaptyEnabled = await _initializeAdapty(environment, logger);

    // Calculate duration
    final duration = DateTime.now().difference(startTime);

    // Log bootstrap completion
    logger.info(
      'Bootstrap completed',
      data: {
        'duration': duration.inMilliseconds,
        'errors': _errorManager.errors.length,
        'degradedMode': degradedMode,
        'offlineMode': offlineMode,
      },
    );

    return EnhancedBootstrapResult(
      environment: environment,
      logger: logger,
      analytics: analytics,
      supabaseClient: supabaseClient,
      firebaseApp: firebaseApp,
      sentryEnabled: sentryEnabled,
      adaptyEnabled: adaptyEnabled,
      errorManager: _errorManager,
      warnings: warnings,
      environmentSource: envResult.source,
      duration: duration,
      degradedMode: degradedMode,
      offlineMode: offlineMode,
    );
  }

  /// Initialize environment with error handling
  Future<
    ({EnvironmentConfig environment, String source, List<String> warnings})
  >
  _initializeEnvironment() async {
    return await _executeWithRetry(
      stage: BootstrapStage.environment,
      operation: () async {
        final result = await _environmentLoader.load();
        if (result.usedFallback) {
          throw StateError('Supabase configuration missing');
        }
        return (
          environment: result.config,
          source: result.source,
          warnings: result.warnings,
        );
      },
      fallback: () async => (
        environment: EnvironmentConfig.fallback(),
        source: 'fallback',
        warnings: ['Using fallback configuration'],
      ),
      severity: BootstrapErrorSeverity.critical,
    );
  }

  /// Initialize logging with error handling
  Future<AppLogger> _initializeLogging(EnvironmentConfig environment) async {
    return await _executeWithRetry(
      stage: BootstrapStage.logging,
      operation: () async {
        LoggerFactory.initialize(
          minLevel: environment.debugMode ? LogLevel.debug : LogLevel.info,
        );
        return LoggerFactory.instance;
      },
      fallback: () async => const ConsoleLogger(),
      severity: BootstrapErrorSeverity.critical,
    );
  }

  /// Initialize platform optimizations
  Future<void> _initializePlatform(AppLogger logger) async {
    await _executeWithRetry(
      stage: BootstrapStage.platform,
      operation: () => AndroidOptimizations.initialize(),
      fallback: () async {
        logger.warning('Platform optimizations skipped');
      },
      severity: BootstrapErrorSeverity.warning,
    );
  }

  /// Initialize monitoring (Sentry)
  Future<bool> _initializeMonitoring(
    EnvironmentConfig environment,
    AppLogger logger,
  ) async {
    return await _executeWithRetry(
      stage: BootstrapStage.monitoring,
      operation: () async {
        SentryConfig.configure(environment: environment, logger: logger);
        await SentryConfig.initialize();
        return SentryConfig.isInitialized;
      },
      fallback: () async {
        logger.warning('Monitoring disabled');
        return false;
      },
      severity: BootstrapErrorSeverity.important,
    );
  }

  /// Initialize Firebase with retry
  Future<FirebaseApp?> _initializeFirebase(AppLogger logger) async {
    return await _executeWithRetry(
      stage: BootstrapStage.firebase,
      operation: () => Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
      fallback: () async {
        logger.warning('Firebase unavailable - running in offline mode');
        return null;
      },
      severity: BootstrapErrorSeverity.important,
      maxRetries: 2, // Fewer retries for Firebase
    );
  }

  /// Initialize Supabase with connection check
  Future<SupabaseClient?> _initializeSupabase(
    EnvironmentConfig environment,
    AppLogger logger,
  ) async {
    if (!environment.isValid) {
      _errorManager.addError(
        BootstrapError(
          stage: BootstrapStage.supabase,
          error: StateError('Invalid Supabase configuration'),
          stackTrace: StackTrace.current,
          severity: BootstrapErrorSeverity.critical,
          fallbackAvailable: true,
        ),
      );
      return null;
    }

    return await _executeWithRetry(
      stage: BootstrapStage.supabase,
      operation: () async {
        await Supabase.initialize(
          url: environment.supabaseUrl,
          anonKey: environment.supabaseAnonKey,
          debug: environment.debugMode,
        );

        // Test connection with timeout
        final client = Supabase.instance.client;
        await client.auth.signInAnonymously().timeout(
          const Duration(seconds: 5),
        );

        return client;
      },
      fallback: () async {
        logger.warning('Supabase offline - local mode only');
        return null;
      },
      severity: BootstrapErrorSeverity.critical,
    );
  }

  /// Initialize feature flags
  Future<void> _initializeFeatureFlags(AppLogger logger) async {
    await _executeWithRetry(
      stage: BootstrapStage.featureFlags,
      operation: () => FeatureFlags.instance.updateFromRemoteConfig(),
      fallback: () async {
        logger.info('Using default feature flags');
      },
      severity: BootstrapErrorSeverity.warning,
    );
  }

  /// Initialize analytics
  Future<AnalyticsService> _initializeAnalytics(
    EnvironmentConfig environment,
    AppLogger logger,
  ) async {
    return await _executeWithRetry(
      stage: BootstrapStage.analytics,
      operation: () async {
        AnalyticsFactory.reset();
        AnalyticsFactory.configure(config: environment, logger: logger);
        return await AnalyticsFactory.initialize();
      },
      fallback: () async {
        logger.warning('Analytics disabled');
        return AnalyticsFactory.instance; // NoOp analytics
      },
      severity: BootstrapErrorSeverity.warning,
    );
  }

  /// Initialize Adapty
  Future<bool> _initializeAdapty(
    EnvironmentConfig environment,
    AppLogger logger,
  ) async {
    final adaptyKey = environment.adaptyPublicApiKey;
    if (adaptyKey == null || adaptyKey.isEmpty) {
      return false;
    }

    return await _executeWithRetry(
      stage: BootstrapStage.adapty,
      operation: () async {
        await Adapty().setLogLevel(
          environment.debugMode ? AdaptyLogLevel.warn : AdaptyLogLevel.error,
        );
        await Adapty().activate(
          configuration: AdaptyConfiguration(apiKey: adaptyKey)
            ..withActivateUI(true)
            ..withAppleIdfaCollectionDisabled(true)
            ..withIpAddressCollectionDisabled(true),
        );
        return true;
      },
      fallback: () async {
        logger.warning('Premium features disabled');
        return false;
      },
      severity: BootstrapErrorSeverity.warning,
    );
  }

  /// Execute an operation with retry logic
  Future<T> _executeWithRetry<T>({
    required BootstrapStage stage,
    required Future<T> Function() operation,
    required Future<T> Function() fallback,
    required BootstrapErrorSeverity severity,
    int? maxRetries,
  }) async {
    // Override retry strategy if needed
    if (maxRetries != null) {
      _retryStrategy.resetStage(stage);
    }

    int attempts = 0;
    Object? lastError;
    StackTrace? lastStackTrace;

    while (attempts < (maxRetries ?? _retryStrategy.maxRetries)) {
      attempts++;

      try {
        return await operation();
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;

        final bootstrapError = BootstrapError(
          stage: stage,
          error: error,
          stackTrace: stackTrace,
          severity: severity,
          retryable: attempts < (maxRetries ?? _retryStrategy.maxRetries),
          fallbackAvailable: true,
        );

        _errorManager.addError(bootstrapError);

        // Check if we should retry
        if (bootstrapError.retryable) {
          final shouldRetry = await _errorManager.tryRecover(bootstrapError);
          if (shouldRetry) {
            continue; // Retry the operation
          }
        }

        break; // No more retries
      }
    }

    // All retries exhausted, use fallback
    try {
      return await fallback();
    } catch (fallbackError, fallbackStackTrace) {
      // Fallback also failed
      _errorManager.addError(
        BootstrapError(
          stage: stage,
          error: fallbackError,
          stackTrace: fallbackStackTrace,
          severity: BootstrapErrorSeverity.fatal,
          message: 'Both operation and fallback failed',
        ),
      );

      // Re-throw the original error
      Error.throwWithStackTrace(lastError!, lastStackTrace!);
    }
  }

  /// Create a fallback result when bootstrap completely fails
  EnhancedBootstrapResult _createFallbackResult(DateTime startTime) {
    return EnhancedBootstrapResult(
      environment: EnvironmentConfig.fallback(),
      logger: const ConsoleLogger(),
      analytics: AnalyticsFactory.instance, // NoOp
      errorManager: _errorManager,
      duration: DateTime.now().difference(startTime),
      degradedMode: true,
      offlineMode: true,
      warnings: ['Application running in emergency fallback mode'],
    );
  }
}
