// lib/config/secure_env_config.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Secure environment configuration that loads from environment variables
/// or a local .env file (for development only)
class SecureEnvConfig {
  static final SecureEnvConfig _instance = SecureEnvConfig._internal();
  factory SecureEnvConfig() => _instance;
  SecureEnvConfig._internal();

  late final Map<String, String> _config;
  bool _initialized = false;

  /// Initialize the configuration
  /// In production, uses environment variables
  /// In development, can load from .env.local file
  Future<void> initialize() async {
    if (_initialized) return;

    _config = {};

    if (kReleaseMode) {
      // Production: Load from environment variables only
      _loadFromEnvironment();
    } else {
      // Development: Try to load from .env.local file first
      await _loadFromLocalEnvFile();
      // Override with environment variables if set
      _loadFromEnvironment();
    }

    _validateConfiguration();
    _initialized = true;
  }

  /// Load configuration from environment variables
  void _loadFromEnvironment() {
    // Platform environment variables
    final env = Platform.environment;

    // Supabase
    _config['SUPABASE_URL'] = env['SUPABASE_URL'] ?? _config['SUPABASE_URL'] ?? '';
    _config['SUPABASE_ANON_KEY'] = env['SUPABASE_ANON_KEY'] ?? _config['SUPABASE_ANON_KEY'] ?? '';
    _config['SUPABASE_SERVICE_ROLE_KEY'] = env['SUPABASE_SERVICE_ROLE_KEY'] ?? _config['SUPABASE_SERVICE_ROLE_KEY'] ?? '';

    // Push Notifications
    _config['FCM_SERVER_KEY'] = env['FCM_SERVER_KEY'] ?? _config['FCM_SERVER_KEY'] ?? '';
    _config['APNS_KEY_ID'] = env['APNS_KEY_ID'] ?? _config['APNS_KEY_ID'] ?? '';
    _config['APNS_TEAM_ID'] = env['APNS_TEAM_ID'] ?? _config['APNS_TEAM_ID'] ?? '';

    // Analytics
    _config['SENTRY_DSN'] = env['SENTRY_DSN'] ?? _config['SENTRY_DSN'] ?? '';
    _config['MIXPANEL_TOKEN'] = env['MIXPANEL_TOKEN'] ?? _config['MIXPANEL_TOKEN'] ?? '';
    _config['ADAPTY_PUBLIC_KEY'] = env['ADAPTY_PUBLIC_KEY'] ?? _config['ADAPTY_PUBLIC_KEY'] ?? '';

    // Security
    _config['ENCRYPTION_KEY'] = env['ENCRYPTION_KEY'] ?? _config['ENCRYPTION_KEY'] ?? '';
    _config['INBOUND_HMAC_SECRET'] = env['INBOUND_HMAC_SECRET'] ?? _config['INBOUND_HMAC_SECRET'] ?? '';

    // API Keys
    _config['OPENAI_API_KEY'] = env['OPENAI_API_KEY'] ?? _config['OPENAI_API_KEY'] ?? '';
  }

  /// Load from local .env.local file (development only)
  Future<void> _loadFromLocalEnvFile() async {
    try {
      final file = File('.env.local');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        for (final line in lines) {
          if (line.isEmpty || line.startsWith('#')) continue;

          final parts = line.split('=');
          if (parts.length >= 2) {
            final key = parts[0].trim();
            final value = parts.sublist(1).join('=').trim();
            _config[key] = value;
          }
        }

        if (kDebugMode) {
          print('✅ Loaded configuration from .env.local');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ No .env.local file found. Using environment variables only.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading .env.local: $e');
      }
    }
  }

  /// Validate that required configuration is present
  void _validateConfiguration() {
    final requiredKeys = [
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
    ];

    final missingKeys = <String>[];
    for (final key in requiredKeys) {
      if (_config[key]?.isEmpty ?? true) {
        missingKeys.add(key);
      }
    }

    if (missingKeys.isNotEmpty) {
      if (kDebugMode) {
        print('⚠️ Missing required configuration: ${missingKeys.join(', ')}');
        print('Please set these environment variables or add them to .env.local');
      }

      if (kReleaseMode) {
        // In production, missing config is critical
        throw Exception('Missing required configuration: ${missingKeys.join(', ')}');
      }
    }
  }

  /// Get a configuration value
  String get(String key) {
    if (!_initialized) {
      throw StateError('SecureEnvConfig not initialized. Call initialize() first.');
    }
    return _config[key] ?? '';
  }

  /// Check if a configuration value exists and is not empty
  bool has(String key) {
    if (!_initialized) {
      throw StateError('SecureEnvConfig not initialized. Call initialize() first.');
    }
    return _config[key]?.isNotEmpty ?? false;
  }

  // Convenience getters for common values
  String get supabaseUrl => get('SUPABASE_URL');
  String get supabaseAnonKey => get('SUPABASE_ANON_KEY');
  String get supabaseServiceRoleKey => get('SUPABASE_SERVICE_ROLE_KEY');
  String get sentryDsn => get('SENTRY_DSN');
  String get encryptionKey => get('ENCRYPTION_KEY');
  String get openAiApiKey => get('OPENAI_API_KEY');

  /// Clear sensitive data from memory (call on app termination)
  void dispose() {
    _config.clear();
    _initialized = false;
  }
}