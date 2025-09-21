import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supported runtime environments for the app.
enum Environment { development, staging, production }

/// Immutable configuration object describing the runtime environment.
class EnvironmentConfig {
  const EnvironmentConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.crashReportingEnabled,
    required this.analyticsEnabled,
    required this.analyticsSamplingRate,
    required this.sentryTracesSampleRate,
    required this.enableAutoSessionTracking,
    required this.sendDefaultPii,
    required this.debugMode,
    this.sentryDsn,
    this.adaptyPublicApiKey,
  });

  final Environment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool crashReportingEnabled;
  final bool analyticsEnabled;
  final double analyticsSamplingRate;
  final double sentryTracesSampleRate;
  final bool enableAutoSessionTracking;
  final bool sendDefaultPii;
  final bool debugMode;
  final String? sentryDsn;
  final String? adaptyPublicApiKey;

  /// Indicates whether the configuration contains a usable Supabase setup.
  bool get isValid => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Returns true if Sentry is configured with a DSN.
  bool get isSentryConfigured => sentryDsn != null && sentryDsn!.isNotEmpty;

  /// Provides a sanitized summary that avoids leaking secrets.
  String safeSummary() {
    final supabasePreview = _maskSecret(supabaseUrl);
    final anonKeyPreview = _maskSecret(supabaseAnonKey);

    return '''Environment: ${environment.name}
Debug Mode: $debugMode
Crash Reporting: $crashReportingEnabled
Analytics Enabled: $analyticsEnabled
Supabase URL: $supabasePreview
Supabase Anon Key: $anonKeyPreview
Sentry Configured: $isSentryConfigured
''';
  }

  EnvironmentConfig copyWith({
    Environment? environment,
    String? supabaseUrl,
    String? supabaseAnonKey,
    bool? crashReportingEnabled,
    bool? analyticsEnabled,
    double? analyticsSamplingRate,
    double? sentryTracesSampleRate,
    bool? enableAutoSessionTracking,
    bool? sendDefaultPii,
    bool? debugMode,
    String? sentryDsn,
    String? adaptyPublicApiKey,
  }) {
    return EnvironmentConfig(
      environment: environment ?? this.environment,
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
      crashReportingEnabled:
          crashReportingEnabled ?? this.crashReportingEnabled,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      analyticsSamplingRate:
          analyticsSamplingRate ?? this.analyticsSamplingRate,
      sentryTracesSampleRate:
          sentryTracesSampleRate ?? this.sentryTracesSampleRate,
      enableAutoSessionTracking:
          enableAutoSessionTracking ?? this.enableAutoSessionTracking,
      sendDefaultPii: sendDefaultPii ?? this.sendDefaultPii,
      debugMode: debugMode ?? this.debugMode,
      sentryDsn: sentryDsn ?? this.sentryDsn,
      adaptyPublicApiKey: adaptyPublicApiKey ?? this.adaptyPublicApiKey,
    );
  }

  /// Fallback configuration used when no env data can be loaded.
  static EnvironmentConfig fallback({
    Environment environment = Environment.development,
    bool debugMode = kDebugMode,
  }) {
    return EnvironmentConfig(
      environment: environment,
      supabaseUrl: '',
      supabaseAnonKey: '',
      crashReportingEnabled: false,
      analyticsEnabled: false,
      analyticsSamplingRate: 1,
      sentryTracesSampleRate: 0.1,
      enableAutoSessionTracking: true,
      sendDefaultPii: false,
      debugMode: debugMode,
      sentryDsn: null,
      adaptyPublicApiKey: null,
    );
  }

  static String _maskSecret(String value) {
    if (value.isEmpty) return '<unset>';
    if (value.length <= 4) {
      final visibleLength = value.length >= 2 ? 2 : 1;
      final prefix = value.substring(0, visibleLength);
      return '$prefix***';
    }
    final prefix = value.substring(0, 4);
    final suffix = value.substring(value.length - 4);
    return '$prefix***$suffix';
  }
}

/// Result of loading environment configuration, containing both the parsed
/// configuration and metadata about how it was obtained.
class EnvironmentLoadResult {
  const EnvironmentLoadResult({
    required this.config,
    required this.source,
    this.usedFallback = false,
    this.warnings = const <String>[],
  });

  final EnvironmentConfig config;
  final String source;
  final bool usedFallback;
  final List<String> warnings;
}

/// Responsible for loading [EnvironmentConfig] from dotenv files and/or
/// compile-time defines.
class EnvironmentConfigLoader {
  EnvironmentConfigLoader({DotEnv? dotenvInstance})
      : _dotenv = dotenvInstance ?? dotenv;

  final DotEnv _dotenv;

  Future<EnvironmentLoadResult> load({String? flavorOverride}) async {
    final warnings = <String>[];
    final mutableEnv = <String, String>{};

    void capture(String key, String value) {
      if (value.isNotEmpty) {
        mutableEnv[key] = value;
      }
    }

    // Load compile-time defines first so dotenv can override selectively.
    capture('SUPABASE_URL',
        const String.fromEnvironment('SUPABASE_URL', defaultValue: ''));
    capture('SUPABASE_ANON_KEY',
        const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''));
    capture('SENTRY_DSN',
        const String.fromEnvironment('SENTRY_DSN', defaultValue: ''));
    capture(
      'CRASH_REPORTING_ENABLED',
      const String.fromEnvironment('CRASH_REPORTING_ENABLED', defaultValue: ''),
    );
    capture('ANALYTICS_ENABLED',
        const String.fromEnvironment('ANALYTICS_ENABLED', defaultValue: ''));
    capture(
        'ANALYTICS_SAMPLING_RATE',
        const String.fromEnvironment(
          'ANALYTICS_SAMPLING_RATE',
          defaultValue: '',
        ));
    capture(
        'SENTRY_TRACES_SAMPLE_RATE',
        const String.fromEnvironment(
          'SENTRY_TRACES_SAMPLE_RATE',
          defaultValue: '',
        ));
    capture(
      'ENABLE_AUTO_SESSION_TRACKING',
      const String.fromEnvironment(
        'ENABLE_AUTO_SESSION_TRACKING',
        defaultValue: '',
      ),
    );
    capture('SEND_DEFAULT_PII',
        const String.fromEnvironment('SEND_DEFAULT_PII', defaultValue: ''));
    capture(
      'ADAPTY_PUBLIC_API_KEY',
      const String.fromEnvironment('ADAPTY_PUBLIC_API_KEY', defaultValue: ''),
    );
    capture('FLAVOR', const String.fromEnvironment('FLAVOR', defaultValue: ''));
    capture(
      'ENVIRONMENT',
      const String.fromEnvironment('ENVIRONMENT', defaultValue: ''),
    );

    final envFile = _resolveEnvFile(flavorOverride: flavorOverride);
    String source = 'dart-define';
    if (envFile != null) {
      source = envFile;
      try {
        await _dotenv.load(fileName: envFile);
        mutableEnv.addAll(_dotenv.env);
      } catch (error) {
        warnings.add('Failed to load $envFile: $error');
      }
    }

    final environment = _detectEnvironment(mutableEnv, flavorOverride);

    final config = EnvironmentConfig(
      environment: environment,
      supabaseUrl: mutableEnv['SUPABASE_URL'] ?? '',
      supabaseAnonKey: mutableEnv['SUPABASE_ANON_KEY'] ?? '',
      crashReportingEnabled:
          _boolFromEnv(mutableEnv, 'CRASH_REPORTING_ENABLED', false),
      analyticsEnabled: _boolFromEnv(mutableEnv, 'ANALYTICS_ENABLED', false),
      analyticsSamplingRate:
          _doubleFromEnv(mutableEnv, 'ANALYTICS_SAMPLING_RATE', 1.0),
      sentryTracesSampleRate:
          _doubleFromEnv(mutableEnv, 'SENTRY_TRACES_SAMPLE_RATE', 0.1),
      enableAutoSessionTracking:
          _boolFromEnv(mutableEnv, 'ENABLE_AUTO_SESSION_TRACKING', true),
      sendDefaultPii: _boolFromEnv(mutableEnv, 'SEND_DEFAULT_PII', false),
      debugMode: kDebugMode,
      sentryDsn: _sanitizeOptional(mutableEnv['SENTRY_DSN']),
      adaptyPublicApiKey:
          _sanitizeOptional(mutableEnv['ADAPTY_PUBLIC_API_KEY']),
    );

    final usedFallback = !config.isValid;
    final resolvedConfig = usedFallback
        ? EnvironmentConfig.fallback(environment: environment)
        : config;

    if (usedFallback) {
      warnings
          .add('Supabase credentials missing; falling back to empty config');
    }

    return EnvironmentLoadResult(
      config: resolvedConfig,
      source: source,
      usedFallback: usedFallback,
      warnings: warnings,
    );
  }

  static Environment _detectEnvironment(
    Map<String, String> env,
    String? flavorOverride,
  ) {
    final flavor =
        flavorOverride?.toLowerCase() ?? env['FLAVOR']?.toLowerCase();
    if (flavor != null && flavor.isNotEmpty) {
      switch (flavor) {
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

    final envOverride = env['ENVIRONMENT']?.toLowerCase();
    if (envOverride != null && envOverride.isNotEmpty) {
      switch (envOverride) {
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

    if (kReleaseMode) return Environment.production;
    if (kProfileMode) return Environment.staging;
    return Environment.development;
  }

  static String? _resolveEnvFile({String? flavorOverride}) {
    if (flavorOverride != null && flavorOverride.isNotEmpty) {
      return _envForFlavor(flavorOverride);
    }

    const flavor = String.fromEnvironment('FLAVOR');
    if (flavor.isNotEmpty) {
      final resolved = _envForFlavor(flavor);
      if (resolved != null) return resolved;
    }

    if (kReleaseMode) return 'assets/env/prod.env';
    if (kProfileMode) return 'assets/env/staging.env';
    return 'assets/env/dev.env';
  }

  static String? _envForFlavor(String flavor) {
    switch (flavor.toLowerCase()) {
      case 'production':
      case 'prod':
        return 'assets/env/prod.env';
      case 'staging':
      case 'stage':
        return 'assets/env/staging.env';
      case 'development':
      case 'dev':
        return 'assets/env/dev.env';
    }
    return null;
  }

  static bool _boolFromEnv(
    Map<String, String> env,
    String key,
    bool defaultValue,
  ) {
    final value = env[key];
    if (value == null || value.isEmpty) return defaultValue;
    return value.toLowerCase() == 'true' || value == '1';
  }

  static double _doubleFromEnv(
    Map<String, String> env,
    String key,
    double defaultValue,
  ) {
    final value = env[key];
    if (value == null || value.isEmpty) return defaultValue;
    return double.tryParse(value) ?? defaultValue;
  }

  static String? _sanitizeOptional(String? value) {
    if (value == null) return null;
    return value.isEmpty ? null : value;
  }
}
