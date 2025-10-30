// ============================================================================
// USER PREFERENCES REPOSITORY INTERFACE
// ============================================================================

import 'package:duru_notes/domain/entities/user_preferences.dart';

/// Repository interface for user preferences operations
///
/// Provides CRUD operations for user preferences with proper error handling,
/// caching, and conflict resolution.
abstract class IUserPreferencesRepository {
  /// Get user preferences for the current authenticated user
  ///
  /// Returns cached preferences if available and not stale.
  /// Throws [PreferencesNotFoundException] if preferences don't exist.
  /// Throws [PreferencesException] on other errors.
  Future<UserPreferences> getUserPreferences();

  /// Get notification preferences for the current authenticated user
  ///
  /// Returns cached preferences if available and not stale.
  /// Throws [PreferencesNotFoundException] if preferences don't exist.
  /// Throws [PreferencesException] on other errors.
  Future<NotificationPreferences> getNotificationPreferences();

  /// Update user preferences
  ///
  /// Implements optimistic locking using version field.
  /// Throws [PreferencesConflictException] if version mismatch detected.
  /// Throws [PreferencesException] on other errors.
  Future<UserPreferences> updateUserPreferences(UserPreferences preferences);

  /// Update notification preferences
  ///
  /// Implements optimistic locking using version field.
  /// Throws [PreferencesConflictException] if version mismatch detected.
  /// Throws [PreferencesException] on other errors.
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences,
  );

  /// Partially update user preferences (only specified fields)
  ///
  /// More efficient than full update when changing single fields.
  Future<UserPreferences> patchUserPreferences(Map<String, dynamic> updates);

  /// Partially update notification preferences (only specified fields)
  ///
  /// More efficient than full update when changing single fields.
  Future<NotificationPreferences> patchNotificationPreferences(
    Map<String, dynamic> updates,
  );

  /// Initialize default preferences for a new user
  ///
  /// Called automatically on first login or can be called explicitly.
  /// Returns existing preferences if they already exist.
  Future<void> initializePreferences(String userId);

  /// Check if notification should be sent based on preferences
  ///
  /// This is a convenience method that encapsulates all notification rules.
  /// Can be called from server-side functions or client-side.
  Future<bool> shouldSendNotification({
    required String userId,
    required String eventType,
    required NotificationChannel channel,
    required NotificationPriority priority,
  });

  /// Record that a notification was sent
  ///
  /// Updates notification count and last sent timestamp.
  /// Called by notification sending service.
  Future<void> recordNotificationSent(String userId);

  /// Clear local cache
  ///
  /// Forces next read to fetch fresh data from server.
  void clearCache();

  /// Watch for changes to user preferences
  ///
  /// Returns a stream that emits updates when preferences change.
  /// Useful for reactive UI updates.
  Stream<UserPreferences> watchUserPreferences();

  /// Watch for changes to notification preferences
  ///
  /// Returns a stream that emits updates when preferences change.
  /// Useful for reactive UI updates.
  Stream<NotificationPreferences> watchNotificationPreferences();

  /// Export preferences as JSON (for backup/debugging)
  Future<Map<String, dynamic>> exportPreferences();

  /// Import preferences from JSON (for restore)
  ///
  /// Validates data before import and throws [ValidationException] if invalid.
  Future<void> importPreferences(Map<String, dynamic> data);

  /// Reset preferences to defaults
  ///
  /// Dangerous operation - requires confirmation in UI.
  Future<void> resetToDefaults();
}

// ============================================================================
// EXCEPTIONS
// ============================================================================

/// Base exception for preferences operations
class PreferencesException implements Exception {
  PreferencesException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'PreferencesException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Thrown when preferences are not found
class PreferencesNotFoundException extends PreferencesException {
  PreferencesNotFoundException([String? userId])
    : super(
        'Preferences not found${userId != null ? ' for user $userId' : ''}',
      );
}

/// Thrown when a conflict is detected during update (optimistic locking)
class PreferencesConflictException extends PreferencesException {
  PreferencesConflictException({
    required this.currentVersion,
    required this.attemptedVersion,
  }) : super(
         'Preferences conflict: expected version $attemptedVersion, but current version is $currentVersion',
       );

  final int currentVersion;
  final int attemptedVersion;
}

/// Thrown when validation fails
class ValidationException extends PreferencesException {
  ValidationException(super.message, [super.cause]);
}

/// Thrown when user is not authenticated
class NotAuthenticatedException extends PreferencesException {
  NotAuthenticatedException() : super('User not authenticated');
}
