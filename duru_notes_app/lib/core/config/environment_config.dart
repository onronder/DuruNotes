import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Enumeration of available environments
enum Environment {
  development('dev'),
  staging('staging'),
  production('prod');

  const Environment(this.fileName);
  final String fileName;
}

/// Environment configuration class that loads and manages environment-specific settings
class EnvironmentConfig {
  static Environment _currentEnvironment = Environment.development;
  static bool _isInitialized = false;

  /// Current environment
  static Environment get currentEnvironment => _currentEnvironment;

  /// Check if the config has been initialized
  static bool get isInitialized => _isInitialized;

  /// Initialize the environment configuration
  /// Must be called before using any configuration values
  static Future<void> initialize({Environment? environment}) async {
    // Determine environment from build flavor or default
    _currentEnvironment = environment ?? _getEnvironmentFromFlavor();
    
    try {
      // Load the appropriate .env file
      await dotenv.load(fileName: 'assets/env/${_currentEnvironment.fileName}.env');
      _isInitialized = true;
      
      if (kDebugMode) {
        print('🌍 Environment initialized: ${_currentEnvironment.name}');
        print('📍 Supabase URL: ${supabaseUrl}');
        print('🔧 Debug Mode: $debugMode');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to load environment config: $e');
        print('📁 Attempted to load: assets/env/${_currentEnvironment.fileName}.env');
      }
      
      // Fall back to development environment
      if (_currentEnvironment != Environment.development) {
        await initialize(environment: Environment.development);
      } else {
        throw Exception('Failed to load environment configuration: $e');
      }
    }
  }

  /// Get environment from build flavor or default to development
  static Environment _getEnvironmentFromFlavor() {
    // This will be set by build flavors
    const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    
    switch (flavor.toLowerCase()) {
      case 'staging':
        return Environment.staging;
      case 'production':
      case 'prod':
        return Environment.production;
      case 'development':
      case 'dev':
      default:
        return Environment.development;
    }
  }

  /// Get a configuration value with optional default
  static String _getValue(String key, {String? defaultValue}) {
    if (!_isInitialized) {
      throw StateError('EnvironmentConfig not initialized. Call initialize() first.');
    }
    
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      if (defaultValue != null) {
        return defaultValue;
      }
      throw ArgumentError('Environment variable $key not found and no default provided');
    }
    return value;
  }

  /// Get a boolean configuration value
  static bool _getBoolValue(String key, {bool defaultValue = false}) {
    final value = _getValue(key, defaultValue: defaultValue.toString());
    return value.toLowerCase() == 'true';
  }

  /// Get an integer configuration value
  static int _getIntValue(String key, {int? defaultValue}) {
    final value = _getValue(key, defaultValue: defaultValue?.toString());
    return int.tryParse(value) ?? (defaultValue ?? 0);
  }

  /// Get a double configuration value
  static double _getDoubleValue(String key, {double? defaultValue}) {
    final value = _getValue(key, defaultValue: defaultValue?.toString());
    return double.tryParse(value) ?? (defaultValue ?? 0.0);
  }

  /// Get an optional string value (can be null)
  static String? _getOptionalValue(String key) {
    if (!_isInitialized) {
      throw StateError('EnvironmentConfig not initialized. Call initialize() first.');
    }
    
    final value = dotenv.env[key];
    return (value == null || value.isEmpty) ? null : value;
  }

  // Supabase Configuration
  static String get supabaseUrl => _getValue('SUPABASE_URL');
  static String get supabaseAnonKey => _getValue('SUPABASE_ANON_KEY');

  // Environment Settings
  static String get environment => _getValue('ENVIRONMENT', defaultValue: 'development');
  static bool get debugMode => _getBoolValue('DEBUG_MODE', defaultValue: kDebugMode);
  static String get logLevel => _getValue('LOG_LEVEL', defaultValue: 'info');

  // Monitoring & Analytics Configuration
  static String? get sentryDsn => _getOptionalValue('SENTRY_DSN');
  static bool get crashReportingEnabled => _getBoolValue('CRASH_REPORTING_ENABLED');
  static bool get analyticsEnabled => _getBoolValue('ANALYTICS_ENABLED');
  static double get analyticsSamplingRate => _getDoubleValue('ANALYTICS_SAMPLING_RATE', defaultValue: 1.0);
  static double get sentryTracesSampleRate => _getDoubleValue('SENTRY_TRACES_SAMPLE_RATE', defaultValue: 0.15);
  static bool get sendDefaultPii => _getBoolValue('SENTRY_SEND_DEFAULT_PII');
  static bool get enableAutoSessionTracking => _getBoolValue('SENTRY_AUTO_SESSION_TRACKING', defaultValue: true);

  // Legacy Feature Flags (kept for backward compatibility)
  static bool get enableAnalytics => analyticsEnabled;
  static bool get enableCrashReporting => crashReportingEnabled;
  static bool get enablePerformanceMonitoring => _getBoolValue('ENABLE_PERFORMANCE_MONITORING');

  // API Settings
  static int get apiTimeout => _getIntValue('API_TIMEOUT', defaultValue: 15000);
  static int get maxRetryAttempts => _getIntValue('MAX_RETRY_ATTEMPTS', defaultValue: 3);

  // Storage Settings
  static bool get enableLocalStorageEncryption => _getBoolValue('ENABLE_LOCAL_STORAGE_ENCRYPTION', defaultValue: true);
  static String get localDbName => _getValue('LOCAL_DB_NAME', defaultValue: 'duru_notes.db');

  // Security Settings
  static bool get enableBiometricAuth => _getBoolValue('ENABLE_BIOMETRIC_AUTH', defaultValue: true);
  static int get sessionTimeoutMinutes => _getIntValue('SESSION_TIMEOUT_MINUTES', defaultValue: 30);

  // Development Specific
  static bool get enableDebugTools => _getBoolValue('ENABLE_DEBUG_TOOLS');
  static bool get mockExternalServices => _getBoolValue('MOCK_EXTERNAL_SERVICES');
  static bool get bypassRateLimiting => _getBoolValue('BYPASS_RATE_LIMITING');

  // Testing Features (Staging)
  static bool get enableTestData => _getBoolValue('ENABLE_TEST_DATA');
  static bool get resetDataOnLaunch => _getBoolValue('RESET_DATA_ON_LAUNCH');

  // Performance (Production)
  static bool get enableCaching => _getBoolValue('ENABLE_CACHING');
  static int get cacheDurationMinutes => _getIntValue('CACHE_DURATION_MINUTES', defaultValue: 30);
  static int get backgroundSyncIntervalMinutes => _getIntValue('BACKGROUND_SYNC_INTERVAL_MINUTES', defaultValue: 15);

  // Security Hardening (Production)
  static bool get forceHttps => _getBoolValue('FORCE_HTTPS');
  static bool get enableCertificatePinning => _getBoolValue('ENABLE_CERTIFICATE_PINNING');
  static String get minimumPasswordStrength => _getValue('MINIMUM_PASSWORD_STRENGTH', defaultValue: 'medium');

  /// Get all configuration as a map (useful for debugging)
  static Map<String, dynamic> getAllConfig() {
    if (!_isInitialized) {
      return {'error': 'Configuration not initialized'};
    }

    return {
      'environment': _currentEnvironment.name,
      'supabaseUrl': supabaseUrl,
      'debugMode': debugMode,
      'logLevel': logLevel,
      'enableAnalytics': enableAnalytics,
      'enableCrashReporting': enableCrashReporting,
      'apiTimeout': apiTimeout,
      'maxRetryAttempts': maxRetryAttempts,
      'localDbName': localDbName,
      'sessionTimeoutMinutes': sessionTimeoutMinutes,
      // Note: Sensitive values like API keys are excluded for security
    };
  }

  /// Check if Sentry crash reporting is properly configured
  static bool get isSentryConfigured => 
      crashReportingEnabled && 
      sentryDsn != null && 
      sentryDsn!.isNotEmpty;

  /// Validate that all required configuration values are present
  static bool validateConfig() {
    try {
      // Check required values
      supabaseUrl;
      supabaseAnonKey;
      
      // Validate analytics sampling rate
      if (analyticsSamplingRate < 0.0 || analyticsSamplingRate > 1.0) {
        if (kDebugMode) {
          print('❌ Invalid analytics sampling rate: $analyticsSamplingRate (must be 0.0-1.0)');
        }
        return false;
      }
      
      // Validate Sentry traces sampling rate
      if (sentryTracesSampleRate < 0.0 || sentryTracesSampleRate > 1.0) {
        if (kDebugMode) {
          print('❌ Invalid Sentry traces sampling rate: $sentryTracesSampleRate (must be 0.0-1.0)');
        }
        return false;
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Configuration validation failed: $e');
      }
      return false;
    }
  }

  /// Get a safe configuration summary for logging
  static Map<String, dynamic> getSafeConfigSummary() {
    if (!_isInitialized) {
      return {
        'environment': _currentEnvironment.name,
        'initialized': false,
        'message': 'Configuration not yet initialized'
      };
    }

    return {
      'environment': _currentEnvironment.name,
      'debugMode': debugMode,
      'logLevel': logLevel,
      'analyticsEnabled': analyticsEnabled,
      'crashReportingEnabled': crashReportingEnabled,
      'isSentryConfigured': isSentryConfigured,
      'analyticsSamplingRate': analyticsSamplingRate,
      'sentryTracesSampleRate': sentryTracesSampleRate,
      'apiTimeout': apiTimeout,
      'localDbName': localDbName,
      'initialized': true,
      // Exclude sensitive information like DSN
    };
  }
}
