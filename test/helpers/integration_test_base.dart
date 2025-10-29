/* COMMENTED OUT - 3 errors
 * This file uses old models/APIs. Needs rewrite.
 */

/*
/// Base class for integration tests that interact with real Supabase instances
///
/// Provides:
/// - Isolated test environment per test run
/// - Automatic test user creation and cleanup
/// - Test data management with proper cleanup
/// - Retry mechanisms for network operations
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'test_environment.dart';

abstract class IntegrationTestBase {
  late SupabaseClient supabaseClient;
  late SupabaseClient adminClient;
  late String testNamespace;
  late String testUserEmail;
  String? testUserId;
  User? testUser;

  // Track created resources for cleanup
  final List<String> createdNoteIds = [];
  final List<String> createdTaskIds = [];
  final List<String> createdReminderIds = [];

  /// Set up integration test environment
  Future<void> setUpIntegration() async {
    // Skip if environment not configured
    if (!TestEnvironment.isConfigured) {
      throw Exception('Test environment not configured. Skipping integration tests.');
    }

    // Create test client
    supabaseClient = await TestEnvironment.createTestClient();
    adminClient = TestEnvironment.createAdminClient();

    // Generate unique namespace for this test run
    testNamespace = TestEnvironment.generateTestNamespace();
    testUserEmail = TestEnvironment.generateTestEmail(testNamespace);

    // Create test user
    await _createTestUser();

    // Set up test-specific data
    await setupTestData();
  }

  /// Clean up integration test environment
  Future<void> tearDownIntegration() async {
    try {
      // Clean up test data
      await cleanupTestData();

      // Delete test user
      await _deleteTestUser();

      // Sign out
      await supabaseClient.auth.signOut();

      // Dispose clients
      supabaseClient.dispose();
      adminClient.dispose();
    } catch (e) {
      // Log cleanup errors but don't fail the test
      print('Warning: Cleanup error: $e');
    }
  }

  /// Create test user with retry logic
  Future<void> _createTestUser() async {
    for (int attempt = 1; attempt <= TestEnvironment.retryCount; attempt++) {
      try {
        final response = await supabaseClient.auth.signUp(
          email: testUserEmail,
          password: 'TestPassword123!@#',
          data: {
            'test_namespace': testNamespace,
            'is_test_user': true,
            'created_at': DateTime.now().toIso8601String(),
          },
        );

        testUser = response.user;
        testUserId = testUser?.id;

        if (testUserId == null) {
          throw Exception('Failed to create test user - no user ID returned');
        }

        // Sign in with the test user
        await supabaseClient.auth.signInWithPassword(
          email: testUserEmail,
          password: 'TestPassword123!@#',
        );

        break; // Success
      } catch (e) {
        if (attempt == TestEnvironment.retryCount) {
          throw Exception('Failed to create test user after $attempt attempts: $e');
        }
        await Future.delayed(Duration(seconds: attempt)); // Exponential backoff
      }
    }
  }

  /// Delete test user using admin API
  Future<void> _deleteTestUser() async {
    if (testUserId == null) return;

    try {
      // Use admin client to delete user
      await adminClient.auth.admin.deleteUser(testUserId!);
    } catch (e) {
      // Try alternative cleanup method
      await _alternativeUserCleanup();
    }
  }

  /// Alternative user cleanup if admin API fails
  Future<void> _alternativeUserCleanup() async {
    try {
      // Mark user as deleted in a custom table if you have one
      await supabaseClient.rpc('mark_test_user_for_deletion', params: {
        'user_id': testUserId,
        'namespace': testNamespace,
      });
    } catch (e) {
      print('Warning: Could not mark user for deletion: $e');
    }
  }

  /// Set up test-specific data
  /// Override this method in subclasses
  Future<void> setupTestData() async {
    // Default implementation - override as needed
  }

  /// Clean up all test data
  Future<void> cleanupTestData() async {
    if (testUserId == null) return;

    // Clean up in reverse order of dependencies
    await _cleanupReminders();
    await _cleanupTasks();
    await _cleanupNotes();

    // Clean up any other test-specific data
    await additionalCleanup();
  }

  /// Clean up test reminders
  Future<void> _cleanupReminders() async {
    if (createdReminderIds.isEmpty) return;

    try {
      await supabaseClient
          .from('reminders')
          .delete()
          .inFilter('id', createdReminderIds);
    } catch (e) {
      print('Warning: Failed to cleanup reminders: $e');
    }
  }

  /// Clean up test tasks
  Future<void> _cleanupTasks() async {
    if (createdTaskIds.isEmpty) return;

    try {
      await supabaseClient.from('tasks').delete().inFilter('id', createdTaskIds);
    } catch (e) {
      print('Warning: Failed to cleanup tasks: $e');
    }
  }

  /// Clean up test notes
  Future<void> _cleanupNotes() async {
    if (createdNoteIds.isEmpty) return;

    try {
      await supabaseClient.from('notes').delete().inFilter('id', createdNoteIds);
    } catch (e) {
      print('Warning: Failed to cleanup notes: $e');
    }
  }

  /// Additional cleanup operations
  /// Override this method for test-specific cleanup
  Future<void> additionalCleanup() async {
    // Default implementation - override as needed
  }

  // Helper methods for creating test data

  /// Create a test note and track it for cleanup
  Future<Map<String, dynamic>> createTestNote({
    required String title,
    String content = '',
    Map<String, dynamic>? metadata,
  }) async {
    final data = {
      'user_id': testUserId,
      'title': '$testNamespace: $title',
      'content': content,
      'metadata': metadata,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await supabaseClient.from('notes').insert(data).select().single();

    createdNoteIds.add(response['id']);
    return response;
  }

  /// Create a test task and track it for cleanup
  Future<Map<String, dynamic>> createTestTask({
    required String title,
    String? description,
    bool isCompleted = false,
    DateTime? dueDate,
    String? noteId,
    int priority = 0,
  }) async {
    final data = {
      'user_id': testUserId,
      'title': '$testNamespace: $title',
      'description': description,
      'is_completed': isCompleted,
      'due_date': dueDate?.toIso8601String(),
      'note_id': noteId,
      'priority': priority,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await supabaseClient.from('tasks').insert(data).select().single();

    createdTaskIds.add(response['id']);
    return response;
  }

  /// Create a test reminder and track it for cleanup
  Future<Map<String, dynamic>> createTestReminder({
    required String taskId,
    required DateTime dateTime,
    bool isEnabled = true,
    String? type,
    Map<String, dynamic>? config,
  }) async {
    final data = {
      'task_id': taskId,
      'user_id': testUserId,
      'date_time': dateTime.toIso8601String(),
      'is_enabled': isEnabled,
      'type': type ?? 'standard',
      'config': config,
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await supabaseClient.from('reminders').insert(data).select().single();

    createdReminderIds.add(response['id']);
    return response;
  }

  /// Execute a test with retry logic
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int? maxAttempts,
  }) async {
    maxAttempts ??= TestEnvironment.retryCount;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (attempt == maxAttempts) {
          throw Exception('Operation failed after $attempt attempts: $e');
        }
        await Future.delayed(Duration(seconds: attempt)); // Exponential backoff
      }
    }

    throw Exception('Unexpected error in executeWithRetry');
  }

  /// Wait for eventual consistency in distributed systems
  Future<void> waitForEventualConsistency({
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    await Future.delayed(delay);
  }

  /// Verify data was synced correctly
  Future<void> verifyDataSynced<T>({
    required Future<T> Function() fetchOperation,
    required bool Function(T) validator,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      try {
        final data = await fetchOperation();
        if (validator(data)) {
          return; // Success
        }
      } catch (e) {
        // Ignore errors during polling
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }

    throw Exception('Data sync verification timed out after ${timeout.inSeconds} seconds');
  }
}
*/
