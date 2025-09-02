/// Standard analytics events used throughout the app
class AnalyticsEvents {
  // User actions
  static const String userSignUp = 'user_sign_up';
  static const String userLogin = 'user_login';
  static const String userLogout = 'user_logout';
  
  // Note actions
  static const String noteCreate = 'note_create';
  static const String noteCreated = 'note_created';
  static const String noteUpdated = 'note_updated';
  static const String noteDeleted = 'note_deleted';
  static const String noteShared = 'note_shared';
  static const String noteExported = 'note_exported';
  static const String noteImported = 'note_imported';
  static const String notesPageLoaded = 'notes_page_loaded';
  static const String notesRefreshed = 'notes_refreshed';
  static const String notesLoadMore = 'notes_load_more';
  
  // Search and navigation
  static const String searchPerformed = 'search_performed';
  static const String searchResults = 'search_results';
  static const String searchResultClicked = 'search_result_clicked';
  static const String screenView = 'screen_view';
  
  // Reminders
  static const String reminderCreated = 'reminder_created';
  static const String reminderSet = 'reminder_set';
  static const String reminderRemoved = 'reminder_removed';
  static const String reminderTriggered = 'reminder_triggered';
  static const String reminderSnoozed = 'reminder_snoozed';
  static const String reminderCompleted = 'reminder_completed';
  static const String reminderPermissionGranted = 'reminder_permission_granted';
  static const String reminderPermissionDenied = 'reminder_permission_denied';
  static const String reminderSetupCompleted = 'reminder_setup_completed';
  static const String reminderLocationPermissionGranted = 'reminder_location_permission_granted';
  
  // App events
  static const String appLaunched = 'app_launched';
  static const String featureUsed = 'feature_used';
  static const String errorOccurred = 'error_occurred';
  static const String performanceIssue = 'performance_issue';
}

/// Standard analytics properties used throughout the app
class AnalyticsProperties {
  // User properties
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';
  static const String userType = 'user_type';
  
  // Session properties
  static const String sessionId = 'session_id';
  static const String appVersion = 'app_version';
  static const String environment = 'environment';
  static const String platform = 'platform';
  
  // Content properties
  static const String noteId = 'note_id';
  static const String noteTitle = 'note_title';
  static const String contentLength = 'content_length';
  static const String contentType = 'content_type';
  
  // UI properties
  static const String screenName = 'screen_name';
  static const String buttonName = 'button_name';
  static const String action = 'action';
  static const String category = 'category';
  
  // Performance properties
  static const String duration = 'duration';
  static const String loadTime = 'load_time';
  static const String errorType = 'error_type';
  static const String errorMessage = 'error_message';
  
  // Search properties
  static const String searchQuery = 'search_query';
  static const String searchQueryLength = 'search_query_length';
  static const String resultsCount = 'results_count';
  static const String searchResultCount = 'search_result_count';
  static const String featureContext = 'feature_context';
  static const String featureName = 'feature_name';
  
  // Reminder properties
  static const String reminderType = 'reminder_type';
  static const String reminderTime = 'reminder_time';
  static const String snoozeReason = 'snooze_reason';
}

/// Analytics service interface and default implementation
class AnalyticsService {
  bool _enabled = true;
  
  void startTiming(String eventName) {
    // Start timing an event (no-op default)
  }
  void endTiming(String eventName, {Map<String, dynamic>? properties}) {
    // End timing an event (no-op default)
  }
  void featureUsed(String featureName, {Map<String, dynamic>? properties}) {
    // Record a feature usage event (no-op default)
  }
  void trackError(String message, {String? context, Map<String, dynamic>? properties}) {
    // Track an error event (no-op default)
  }
  void event(String name, {Map<String, dynamic>? properties}) {
    // Track a generic event (no-op default)
  }
  
  /// Enable analytics tracking
  void enable() {
    _enabled = true;
  }
  
  /// Disable analytics tracking
  void disable() {
    _enabled = false;
  }
  
  /// Check if analytics is enabled
  bool get isEnabled => _enabled;
}

/// Analytics factory to manage a singleton AnalyticsService
class AnalyticsFactory {
  static AnalyticsService? _instance;
  static void initialize() {
    _instance = AnalyticsService();
  }
  static AnalyticsService get instance => _instance ?? AnalyticsService();
}
