import 'dart:io';

import 'package:duru_notes/core/config/environment_config.dart';

/// Validation result for configuration
class ConfigValidationResult {
  ConfigValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.securityIssues = const [],
  });

  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final List<String> securityIssues;

  bool get hasSecurityIssues => securityIssues.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'isValid': isValid,
    'errors': errors,
    'warnings': warnings,
    'securityIssues': securityIssues,
  };
}

/// Validator for environment configuration
class ConfigValidator {
  ConfigValidator({
    this.allowLocalhost = false,
    this.requireHttps = true,
    this.allowEmptyKeys = false,
  });

  final bool allowLocalhost;
  final bool requireHttps;
  final bool allowEmptyKeys;

  // Common patterns for detecting hardcoded secrets
  static final _secretPatterns = [
    RegExp(r'sk_live_[a-zA-Z0-9]+'), // Stripe secret key
    RegExp(r'pk_live_[a-zA-Z0-9]+'), // Stripe publishable key
    RegExp(r'AIza[0-9A-Za-z-_]+'), // Google API key
    RegExp(r'[0-9a-f]{40}'), // Generic hex key (e.g., GitHub token)
    RegExp(r'eyJ[a-zA-Z0-9]+\.eyJ[a-zA-Z0-9]+'), // JWT token
    RegExp(r'xox[baprs]-[a-zA-Z0-9]+'), // Slack token
    RegExp(r'ghp_[a-zA-Z0-9]+'), // GitHub personal access token
  ];

  /// Validate the environment configuration
  ConfigValidationResult validate(EnvironmentConfig config) {
    final errors = <String>[];
    final warnings = <String>[];
    final securityIssues = <String>[];

    // Check Supabase configuration
    _validateSupabase(
      config.supabaseUrl,
      config.supabaseAnonKey,
      errors,
      warnings,
      securityIssues,
    );

    // Check Sentry configuration if enabled
    if (config.isSentryConfigured) {
      _validateSentry(config.sentryDsn!, errors, warnings, securityIssues);
    }

    // Check analytics configuration
    _validateAnalytics(config, errors, warnings);

    // Check for hardcoded secrets
    _checkForHardcodedSecrets(config, securityIssues);

    // Check environment consistency
    _validateEnvironmentConsistency(config, warnings);

    // Check for common misconfigurations
    _checkCommonMisconfigurations(config, warnings);

    return ConfigValidationResult(
      isValid: errors.isEmpty && securityIssues.isEmpty,
      errors: errors,
      warnings: warnings,
      securityIssues: securityIssues,
    );
  }

  void _validateSupabase(
    String url,
    String anonKey,
    List<String> errors,
    List<String> warnings,
    List<String> securityIssues,
  ) {
    // Check URL format
    if (url.isEmpty) {
      if (!allowEmptyKeys) {
        errors.add('Supabase URL is empty');
      }
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      errors.add('Invalid Supabase URL format: $url');
      return;
    }

    // Check for HTTPS
    if (requireHttps && uri.scheme != 'https') {
      securityIssues.add('Supabase URL must use HTTPS in production: $url');
    }

    // Check for localhost
    if (!allowLocalhost && _isLocalhost(uri.host)) {
      errors.add('Localhost URLs not allowed in production: $url');
    }

    // Validate Supabase URL format
    if (!url.contains('.supabase.co') && !_isLocalhost(uri.host)) {
      warnings.add('Supabase URL does not match expected format');
    }

    // Check anon key
    if (anonKey.isEmpty) {
      if (!allowEmptyKeys) {
        errors.add('Supabase anon key is empty');
      }
      return;
    }

    // Check if anon key looks like a service role key (security issue)
    if (anonKey.contains('service_role') ||
        anonKey.startsWith('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')) {
      securityIssues.add('Service role key detected - use anon key instead');
    }

    // Check key length
    if (anonKey.length < 100) {
      warnings.add('Supabase anon key seems too short');
    }
  }

  void _validateSentry(
    String dsn,
    List<String> errors,
    List<String> warnings,
    List<String> securityIssues,
  ) {
    if (dsn.isEmpty) return;

    final uri = Uri.tryParse(dsn);
    if (uri == null) {
      errors.add('Invalid Sentry DSN format: $dsn');
      return;
    }

    // Check for HTTPS
    if (requireHttps && uri.scheme != 'https') {
      securityIssues.add('Sentry DSN must use HTTPS');
    }

    // Validate Sentry DSN format
    if (!dsn.contains('@') || !dsn.contains('/')) {
      errors.add('Sentry DSN does not match expected format');
    }

    // Check if DSN contains sensitive info in path
    if (dsn.contains('secret') || dsn.contains('password')) {
      securityIssues.add('Sentry DSN may contain sensitive information');
    }
  }

  void _validateAnalytics(
    EnvironmentConfig config,
    List<String> errors,
    List<String> warnings,
  ) {
    if (config.analyticsEnabled) {
      // Check sampling rate
      if (config.analyticsSamplingRate < 0 ||
          config.analyticsSamplingRate > 1) {
        errors.add('Analytics sampling rate must be between 0 and 1');
      }

      // Check Sentry traces sample rate
      if (config.sentryTracesSampleRate < 0 ||
          config.sentryTracesSampleRate > 1) {
        errors.add('Sentry traces sample rate must be between 0 and 1');
      }

      // Warn about high sampling rates in production
      if (config.environment == Environment.production) {
        if (config.analyticsSamplingRate > 0.5) {
          warnings.add(
            'High analytics sampling rate in production: ${config.analyticsSamplingRate}',
          );
        }
        if (config.sentryTracesSampleRate > 0.1) {
          warnings.add(
            'High Sentry traces rate in production: ${config.sentryTracesSampleRate}',
          );
        }
      }
    }
  }

  void _checkForHardcodedSecrets(
    EnvironmentConfig config,
    List<String> securityIssues,
  ) {
    // Convert config to string representation for checking
    final configString =
        '''
      ${config.supabaseUrl}
      ${config.supabaseAnonKey}
      ${config.sentryDsn ?? ''}
      ${config.adaptyPublicApiKey ?? ''}
    ''';

    // Check against known secret patterns
    for (final pattern in _secretPatterns) {
      if (pattern.hasMatch(configString)) {
        // Check if it's actually a problematic key
        final match = pattern.firstMatch(configString)?.group(0) ?? '';
        if (_looksLikeRealSecret(match)) {
          securityIssues.add(
            'Possible hardcoded secret detected: ${_maskSecret(match)}',
          );
        }
      }
    }

    // Check for common test/development keys
    if (_containsTestKeys(configString)) {
      securityIssues.add('Test or development keys detected in configuration');
    }
  }

  void _validateEnvironmentConsistency(
    EnvironmentConfig config,
    List<String> warnings,
  ) {
    // Production environment checks
    if (config.environment == Environment.production) {
      if (config.debugMode) {
        warnings.add('Debug mode is enabled in production');
      }
      if (!config.crashReportingEnabled) {
        warnings.add('Crash reporting disabled in production');
      }
      if (config.sendDefaultPii) {
        warnings.add('Sending PII is enabled in production');
      }
    }

    // Development environment checks
    if (config.environment == Environment.development) {
      if (config.crashReportingEnabled) {
        warnings.add('Crash reporting enabled in development');
      }
    }
  }

  void _checkCommonMisconfigurations(
    EnvironmentConfig config,
    List<String> warnings,
  ) {
    // Check for mixed environments
    if (config.supabaseUrl.contains('prod') &&
        config.environment != Environment.production) {
      warnings.add(
        'Production Supabase URL used in non-production environment',
      );
    }

    if (config.supabaseUrl.contains('dev') &&
        config.environment == Environment.production) {
      warnings.add('Development Supabase URL used in production environment');
    }

    // Check for missing optional features
    if (config.adaptyPublicApiKey == null &&
        config.environment == Environment.production) {
      warnings.add('Premium features (Adapty) not configured for production');
    }
  }

  bool _isLocalhost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host.endsWith('.local');
  }

  bool _looksLikeRealSecret(String value) {
    // Skip if it's obviously a placeholder
    if (value.contains('xxx') ||
        value.contains('YOUR_') ||
        value.contains('REPLACE_') ||
        value == '0000000000000000000000000000000000000000') {
      return false;
    }

    return true;
  }

  bool _containsTestKeys(String value) {
    final testKeyPatterns = [
      'test_',
      'demo_',
      'example_',
      'sample_',
      'pk_test_',
      'sk_test_',
    ];

    return testKeyPatterns.any((pattern) => value.contains(pattern));
  }

  String _maskSecret(String secret) {
    if (secret.length <= 8) {
      return '***';
    }
    return '${secret.substring(0, 4)}...${secret.substring(secret.length - 4)}';
  }
}

/// Extension to scan source files for hardcoded secrets
class SourceCodeSecurityScanner {
  static Future<List<String>> scanForSecrets(String directoryPath) async {
    final issues = <String>[];
    final directory = Directory(directoryPath);

    if (!directory.existsSync()) {
      return issues;
    }

    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final content = await entity.readAsString();
        final fileIssues = _scanFileContent(content, entity.path);
        issues.addAll(fileIssues);
      }
    }

    return issues;
  }

  static List<String> _scanFileContent(String content, String filePath) {
    final issues = <String>[];

    // Check for hardcoded URLs
    final urlPattern = RegExp(r'https?://[^\s"]+\.(supabase\.co|sentry\.io)');
    if (urlPattern.hasMatch(content)) {
      issues.add('Hardcoded URL found in $filePath');
    }

    // Check for API keys
    final apiKeyPatterns = [
      RegExp(r'"[A-Za-z0-9]{20,}"'), // Generic long string
      RegExp(r"'[A-Za-z0-9]{20,}'"), // Generic long string in single quotes
    ];

    for (final pattern in apiKeyPatterns) {
      if (pattern.hasMatch(content)) {
        // Additional checks to reduce false positives
        final matches = pattern.allMatches(content);
        for (final match in matches) {
          final value = match.group(0) ?? '';
          if (_looksLikeApiKey(value) && !_isTestFile(filePath)) {
            issues.add('Possible hardcoded API key in $filePath');
            break;
          }
        }
      }
    }

    return issues;
  }

  static bool _looksLikeApiKey(String value) {
    // Remove quotes
    final cleanValue = value.replaceAll('"', '').replaceAll("'", '');

    // Skip if it's a common non-secret string
    if (cleanValue.contains(' ') || // Has spaces
        cleanValue.contains('.dart') || // File path
        cleanValue.contains('/') || // Path separator
        RegExp(r'^[a-z_]+$').hasMatch(cleanValue)) {
      // All lowercase snake_case
      return false;
    }

    // Check if it has characteristics of an API key
    return cleanValue.length > 30 &&
        RegExp(r'[A-Z]').hasMatch(cleanValue) &&
        RegExp(r'[a-z]').hasMatch(cleanValue) &&
        RegExp(r'[0-9]').hasMatch(cleanValue);
  }

  static bool _isTestFile(String filePath) {
    return filePath.contains('test/') ||
        filePath.contains('test.dart') ||
        filePath.contains('mock') ||
        filePath.contains('example');
  }
}
