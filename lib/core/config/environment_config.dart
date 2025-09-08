import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Production-grade environment configuration management
class EnvironmentConfig {

  const EnvironmentConfig._({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.crashReportingEnabled, required this.analyticsEnabled, required this.analyticsSamplingRate, required this.sentryTracesSampleRate, required this.enableAutoSessionTracking, required this.sendDefaultPii, required this.debugMode, required this.currentEnvironment, this.sentryDsn,
  });
  static EnvironmentConfig? _instance;
  
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String? sentryDsn;
  final bool crashReportingEnabled;
  final bool analyticsEnabled;
  final double analyticsSamplingRate;
  final double sentryTracesSampleRate;
  final bool enableAutoSessionTracking;
  final bool sendDefaultPii;
  final bool debugMode;
  final Environment currentEnvironment;

  static EnvironmentConfig get current {
    if (_instance == null) {
      throw StateError('EnvironmentConfig not initialized. Call initialize() first.');
    }
    return _instance!;
  }

  /// Initialize environment configuration
  static Future<void> initialize() async {
    try {
      // Try to load environment variables (optional)
      // Priority:
      // 1) Load env file based on build flavor (dev/staging/prod) if provided via DART_DEFINES
      // 2) Fallback to a generic .env if present
      // 3) If none found, continue with sane defaults
      try {
        const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
        const flavoredEnvPath = 'assets/env/$flavor.env';

        var loaded = false;
        try {
          await dotenv.load(fileName: flavoredEnvPath);
          loaded = true;
        } catch (_) {
          // Will try generic .env next
        }

        if (!loaded) {
          try {
            await dotenv.load(fileName: 'assets/env/.env');
            loaded = true;
          } catch (_) {
            // No env files found - proceed with defaults
          }
        }
      } catch (e) {
        // Ignore env file errors - use defaults
      }
      
      _instance = EnvironmentConfig._(
        supabaseUrl: dotenv.env['SUPABASE_URL'] ?? const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: 'https://jtaedgpxesshdrnbgvjr.supabase.co',
        ),
        supabaseAnonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? const String.fromEnvironment(
          'SUPABASE_ANON_KEY',
          defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyNDQ5ODMsImV4cCI6MjA3MDgyMDk4M30.a0O-FD0LwqZ-ikRCNnLqBZ0AoeKQKznwJjj8yPYrM-U',
        ),
        sentryDsn: dotenv.env['SENTRY_DSN'],
        crashReportingEnabled: dotenv.env['CRASH_REPORTING_ENABLED'] == 'true',
        analyticsEnabled: dotenv.env['ANALYTICS_ENABLED'] == 'true',
        analyticsSamplingRate: double.tryParse(dotenv.env['ANALYTICS_SAMPLING_RATE'] ?? '1.0') ?? 1.0,
        sentryTracesSampleRate: double.tryParse(dotenv.env['SENTRY_TRACES_SAMPLE_RATE'] ?? '0.1') ?? 0.1,
        enableAutoSessionTracking: dotenv.env['ENABLE_AUTO_SESSION_TRACKING'] != 'false',
        sendDefaultPii: dotenv.env['SEND_DEFAULT_PII'] == 'true',
        debugMode: kDebugMode,
        currentEnvironment: _detectEnvironment(),
      );
    } catch (e) {
      // Fallback configuration for development
      _instance = EnvironmentConfig._(
        supabaseUrl: dotenv.env['SUPABASE_URL'] ?? const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: 'https://jtaedgpxesshdrnbgvjr.supabase.co',
        ),
        supabaseAnonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? const String.fromEnvironment(
          'SUPABASE_ANON_KEY', 
          defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyNDQ5ODMsImV4cCI6MjA3MDgyMDk4M30.a0O-FD0LwqZ-ikRCNnLqBZ0AoeKQKznwJjj8yPYrM-U',
        ),
        crashReportingEnabled: false,
        analyticsEnabled: false,
        analyticsSamplingRate: 1,
        sentryTracesSampleRate: 0.1,
        enableAutoSessionTracking: true,
        sendDefaultPii: false,
        debugMode: kDebugMode,
        currentEnvironment: Environment.development,
      );
    }
  }

  static Environment _detectEnvironment() {
    // Prefer explicit build flavor if provided (via iOS xcconfig DART_DEFINES or CLI --dart-define)
    const flavor = String.fromEnvironment('FLAVOR');
    if (flavor.isNotEmpty) {
      switch (flavor.toLowerCase()) {
        case 'production':
        case 'prod':
          return Environment.production;
        case 'staging':
        case 'stage':
          return Environment.staging;
        default:
          return Environment.development;
      }
    }

    if (kDebugMode) return Environment.development;

    const env = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
    switch (env.toLowerCase()) {
      case 'production':
      case 'prod':
        return Environment.production;
      case 'staging':
      case 'stage':
        return Environment.staging;
      default:
        return Environment.development;
    }
  }

  /// Validate configuration
  static bool validateConfig() {
    try {
      final config = current;
      return config.supabaseUrl.isNotEmpty && 
             config.supabaseAnonKey.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get safe configuration summary (no secrets)
  static String getSafeConfigSummary() {
    try {
      final config = current;
      return '''
Environment: ${config.currentEnvironment.name}
Debug Mode: ${config.debugMode}
Sentry Configured: ${config.isSentryConfigured}
Analytics Enabled: ${config.analyticsEnabled}
Supabase URL: ${config.supabaseUrl.substring(0, 20)}...
''';
    } catch (e) {
      return 'Configuration not initialized';
    }
  }

  /// Check if Sentry is properly configured
  bool get isSentryConfigured => sentryDsn != null && sentryDsn!.isNotEmpty;

  /// Check if performance monitoring is enabled
  bool get isPerformanceMonitoringEnabled => analyticsEnabled && debugMode;
}

/// Environment types
enum Environment {
  development('development'),
  staging('staging'),
  production('production');

  const Environment(this.name);
  final String name;
}
