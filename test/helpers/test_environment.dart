/// Test environment configuration for integration testing
///
/// Provides configuration and utilities for testing against real Supabase instances
/// with proper data isolation and cleanup
library;

import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class TestEnvironment {
  // Environment variables for test Supabase instance
  static const String TEST_SUPABASE_URL = String.fromEnvironment(
    'TEST_SUPABASE_URL',
    defaultValue: '', // Set via CI/CD or local env
  );

  static const String TEST_SUPABASE_ANON_KEY = String.fromEnvironment(
    'TEST_SUPABASE_ANON_KEY',
    defaultValue: '', // Set via CI/CD or local env
  );

  static const String TEST_SUPABASE_SERVICE_KEY = String.fromEnvironment(
    'TEST_SUPABASE_SERVICE_KEY',
    defaultValue: '', // For admin operations in tests
  );

  // Test namespace prefix to isolate test data
  static const String TEST_NAMESPACE_PREFIX = 'test_';

  // Check if test environment is configured
  static bool get isConfigured =>
      TEST_SUPABASE_URL.isNotEmpty && TEST_SUPABASE_ANON_KEY.isNotEmpty;

  /// Generate unique namespace for test isolation
  static String generateTestNamespace() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return '${TEST_NAMESPACE_PREFIX}${timestamp}_$random';
  }

  /// Generate unique test email
  static String generateTestEmail(String namespace) {
    return '$namespace@test.durunotes.local';
  }

  /// Create test Supabase client
  static Future<SupabaseClient> createTestClient() async {
    if (!isConfigured) {
      throw Exception(
        'Test environment not configured. '
        'Please set TEST_SUPABASE_URL and TEST_SUPABASE_ANON_KEY environment variables.',
      );
    }

    // Initialize Supabase if not already initialized
    if (!Supabase.instance.initialized) {
      await Supabase.initialize(
        url: TEST_SUPABASE_URL,
        anonKey: TEST_SUPABASE_ANON_KEY,
      );
    }

    return Supabase.instance.client;
  }

  /// Create admin client for test management operations
  static SupabaseClient createAdminClient() {
    if (!isConfigured || TEST_SUPABASE_SERVICE_KEY.isEmpty) {
      throw Exception(
        'Admin client requires TEST_SUPABASE_SERVICE_KEY environment variable.',
      );
    }

    return SupabaseClient(
      TEST_SUPABASE_URL,
      TEST_SUPABASE_SERVICE_KEY,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
      ),
    );
  }

  /// Check if running in CI/CD environment
  static bool get isCI => const bool.fromEnvironment('CI', defaultValue: false);

  /// Get test timeout duration based on environment
  static Duration get testTimeout => isCI
      ? const Duration(minutes: 5) // Longer timeout for CI
      : const Duration(minutes: 2); // Shorter timeout for local

  /// Get retry count for flaky operations
  static int get retryCount => isCI ? 3 : 1;

  /// Validate test environment setup
  static Future<bool> validateEnvironment() async {
    if (!isConfigured) {
      print('❌ Test environment not configured');
      return false;
    }

    try {
      final client = await createTestClient();

      // Try a simple health check
      final response = await client.from('notes').select().limit(1);

      print('✅ Test environment validated successfully');
      return true;
    } catch (e) {
      print('❌ Test environment validation failed: $e');
      return false;
    }
  }

  /// Get test data retention period
  /// In CI, clean up immediately. Locally, keep for debugging.
  static Duration get dataRetentionPeriod =>
      isCI ? Duration.zero : const Duration(hours: 1);
}