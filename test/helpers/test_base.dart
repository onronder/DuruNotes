/* COMMENTED OUT - 13 errors - uses old APIs
 * This class uses old models/APIs that no longer exist.
 * Needs rewrite to use new architecture.
 */

/*
/// Base class for all unit tests in Duru Notes
///
/// Provides common test setup and teardown functionality including:
/// - In-memory database initialization
/// - Feature flag management
/// - Test data setup
/// - Proper cleanup
library;

import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

abstract class TestBase {
  late AppDb testDb;
  late FeatureFlags featureFlags;

  /// Set up test environment
  Future<void> setUp() async {
    // Create in-memory database for testing
    testDb = AppDb(NativeDatabase.memory());

    // Reset feature flags to defaults
    featureFlags = FeatureFlags.instance;
    featureFlags.clearOverrides();

    // Initialize test-specific data
    await initializeTestData();
  }

  /// Clean up test environment
  Future<void> tearDown() async {
    // Close database connection
    await testDb.close();

    // Clear feature flag overrides
    featureFlags.clearOverrides();

    // Additional cleanup if needed
    await additionalCleanup();
  }

  /// Initialize test-specific data
  /// Override this method in subclasses to add specific test data
  Future<void> initializeTestData() async {
    // Default implementation - override as needed
  }

  /// Additional cleanup operations
  /// Override this method for test-specific cleanup
  Future<void> additionalCleanup() async {
    // Default implementation - override as needed
  }

  /// Helper method to create test notes
  Future<int> createTestNote({
    required String title,
    String content = '',
    DateTime? createdAt,
  }) async {
    final note = NotesCompanion.insert(
      title: title,
      content: content,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await testDb.into(testDb.notes).insert(note);
  }

  /// Helper method to create test tasks
  Future<int> createTestTask({
    required String title,
    String? description,
    bool isCompleted = false,
    DateTime? dueDate,
    int? noteId,
  }) async {
    final task = TasksCompanion.insert(
      title: title,
      description: Value(description),
      isCompleted: isCompleted,
      dueDate: Value(dueDate),
      noteId: Value(noteId),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await testDb.into(testDb.tasks).insert(task);
  }

  /// Helper method to create test reminders
  Future<int> createTestReminder({
    required int taskId,
    required DateTime dateTime,
    bool isEnabled = true,
  }) async {
    final reminder = RemindersCompanion.insert(
      taskId: taskId,
      dateTime: dateTime,
      isEnabled: isEnabled,
      createdAt: DateTime.now(),
    );
    return await testDb.into(testDb.reminders).insert(reminder);
  }

  /// Enable a feature flag for testing
  void enableFeature(String flagName) {
    featureFlags.setOverride(flagName, true);
  }

  /// Disable a feature flag for testing
  void disableFeature(String flagName) {
    featureFlags.setOverride(flagName, false);
  }

  /// Verify database is empty
  Future<void> verifyEmptyDatabase() async {
    final noteCount = await testDb.select(testDb.notes).get();
    final taskCount = await testDb.select(testDb.tasks).get();
    final reminderCount = await testDb.select(testDb.reminders).get();

    expect(noteCount, isEmpty, reason: 'Database should have no notes');
    expect(taskCount, isEmpty, reason: 'Database should have no tasks');
    expect(reminderCount, isEmpty, reason: 'Database should have no reminders');
  }
}*/
