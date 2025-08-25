import 'dart:math';

/// Abstract interface for analytics services
abstract class AnalyticsService {
  /// Track an event with optional properties
  void event(String name, {Map<String, Object?> properties = const {}});
  
  /// Track a screen view
  void screen(String name, {Map<String, Object?> properties = const {}});
  
  /// Set user context for analytics
  void setUser(String? userId, {Map<String, Object?> properties = const {}});
  
  /// Clear user context
  void clearUser();
  
  /// Set user properties that persist across events
  void setUserProperty(String key, Object? value);
  
  /// Track timing events (start)
  void startTiming(String name);
  
  /// Track timing events (end)
  void endTiming(String name, {Map<String, Object?> properties = const {}});
  
  /// Track conversion funnel steps
  void funnelStep(String funnelName, String stepName, {Map<String, Object?> properties = const {}});
  
  /// Track feature usage
  void featureUsed(String featureName, {Map<String, Object?> properties = const {}});
  
  /// Track user engagement
  void engagement(String action, {String? category, Map<String, Object?> properties = const {}});
  
  /// Track errors for analytics (non-crash)
  void trackError(String error, {String? context, Map<String, Object?> properties = const {}});
}

/// Analytics event names as constants to avoid typos
class AnalyticsEvents {
  // Authentication
  static const String authLoginAttempt = 'auth.login.attempt';
  static const String authLoginSuccess = 'auth.login.success';
  static const String authLoginFailure = 'auth.login.failure';
  static const String authLogout = 'auth.logout';
  static const String authSignupAttempt = 'auth.signup.attempt';
  static const String authSignupSuccess = 'auth.signup.success';
  static const String authSignupFailure = 'auth.signup.failure';
  
  // Notes
  static const String noteCreate = 'note.create';
  static const String noteEdit = 'note.edit';
  static const String noteDelete = 'note.delete';
  static const String noteView = 'note.view';
  static const String noteShare = 'note.share';
  static const String noteExport = 'note.export';
  static const String noteImport = 'note.import';
  
  // Search
  static const String searchPerformed = 'search.performed';
  static const String searchResults = 'search.results';
  static const String searchResultClicked = 'search.result.clicked';
  
  // Pagination & Performance
  static const String notesPageLoaded = 'notes.page_loaded';
  static const String notesLoadMore = 'notes.load_more';
  static const String notesRefreshed = 'notes.refreshed';
  
  // Attachments
  static const String attachmentCacheMiss = 'attachment.cache_miss';
  static const String attachmentSizeLimitExceeded = 'attachment.size_limit_exceeded';
  static const String attachmentCacheCleared = 'attachment.cache_cleared';
  
  // Tags
  static const String tagCreate = 'tag.create';
  static const String tagEdit = 'tag.edit';
  static const String tagDelete = 'tag.delete';
  static const String tagApplied = 'tag.applied';
  static const String tagRemoved = 'tag.removed';
  
  // Navigation
  static const String screenView = 'screen.view';
  static const String navigationTab = 'navigation.tab';
  
  // Features
  static const String featureMarkdown = 'feature.markdown';
  static const String featureCrypto = 'feature.crypto';
  static const String featureSync = 'feature.sync';
  static const String featureSearch = 'feature.search';
  
  // Performance
  static const String appLaunch = 'app.launch';
  static const String appBackground = 'app.background';
  static const String appForeground = 'app.foreground';
  static const String syncCompleted = 'sync.completed';
  static const String syncFailed = 'sync.failed';
  
  // Voice & Audio
  static const String voiceStart = 'voice.start';
  static const String voicePartial = 'voice.partial';
  static const String voiceFinal = 'voice.final';
  static const String voiceCancel = 'voice.cancel';
  static const String voiceError = 'voice.error';
  static const String voiceSessionComplete = 'voice.session_complete';
  static const String voicePermissionRequested = 'voice.permission_requested';
  static const String voicePermissionDenied = 'voice.permission_denied';
  static const String audioRecordingStart = 'audio_recording.start';
  static const String audioRecordingStop = 'audio_recording.stop';
  static const String audioRecordingCancel = 'audio_recording.cancel';
  static const String audioRecordingSizeLimitExceeded = 'audio_recording.size_limit_exceeded';
  static const String audioRecordingFileDeleted = 'audio_recording.file_deleted';
  
  // Reminders
  static const String reminderSet = 'reminder.set';
  static const String reminderRemoved = 'reminder.removed';
  static const String reminderNotificationTapped = 'reminder.notification_tapped';
  static const String reminderPermissionRequested = 'reminder.permission_requested';
  static const String reminderPermissionGranted = 'reminder.permission_granted';
  static const String reminderPermissionDenied = 'reminder.permission_denied';
  static const String reminderScheduled = 'reminder.scheduled';
  static const String reminderCanceled = 'reminder.canceled';
  static const String reminderNotificationTapError = 'reminder.notification_tap_error';
  
  // Errors
  static const String errorOccurred = 'error.occurred';
  static const String errorRecovered = 'error.recovered';
}

/// Common analytics properties
class AnalyticsProperties {
  static const String userId = 'user_id';
  static const String timestamp = 'timestamp';
  static const String sessionId = 'session_id';
  static const String appVersion = 'app_version';
  static const String platform = 'platform';
  static const String environment = 'environment';
  
  // Note properties
  static const String noteId = 'note_id';
  static const String noteLength = 'note_length';
  static const String hasAttachments = 'has_attachments';
  static const String wordCount = 'word_count';
  static const String characterCount = 'character_count';
  static const String isEncrypted = 'is_encrypted';
  
  // Search properties
  static const String searchQuery = 'search_query';
  static const String searchQueryLength = 'search_query_length';
  static const String searchResultCount = 'search_result_count';
  static const String searchDuration = 'search_duration_ms';
  
  // Tag properties
  static const String tagName = 'tag_name';
  static const String tagCount = 'tag_count';
  
  // Performance properties
  static const String duration = 'duration_ms';
  static const String success = 'success';
  static const String errorType = 'error_type';
  static const String errorMessage = 'error_message';
  
  // Feature properties
  static const String featureName = 'feature_name';
  static const String featureContext = 'feature_context';
  
  // UI properties
  static const String screenName = 'screen_name';
  static const String action = 'action';
  static const String category = 'category';
  
  // Voice & Audio properties  
  static const String voiceSessionId = 'voice_session_id';
  static const String locale = 'locale';
  static const String hasPermission = 'has_permission';
  static const String hasConfidence = 'has_confidence';
  static const String confidence = 'confidence';
  static const String fileSizeBytes = 'file_size_bytes';
  static const String maxSizeBytes = 'max_size_bytes';
  static const String encoder = 'encoder';
  static const String sampleRate = 'sample_rate';
}

/// Analytics funnel definitions
class AnalyticsFunnels {
  static const String userOnboarding = 'user_onboarding';
  static const String noteCreation = 'note_creation';
  static const String searchFlow = 'search_flow';
  static const String syncSetup = 'sync_setup';
}

/// Helper class for common analytics operations
class AnalyticsHelper {
  static final Random _random = Random();
  
  /// Check if event should be sampled based on sampling rate
  static bool shouldSample(double samplingRate) {
    if (samplingRate <= 0.0) return false;
    if (samplingRate >= 1.0) return true;
    return _random.nextDouble() <= samplingRate;
  }
  
  /// Sanitize properties to remove PII
  static Map<String, Object?> sanitizeProperties(Map<String, Object?> properties) {
    final sanitized = <String, Object?>{};
    
    for (final entry in properties.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;
      
      // Skip potential PII fields
      if (_isPotentialPii(key)) {
        continue;
      }
      
      // Sanitize string values
      if (value is String) {
        sanitized[entry.key] = _sanitizeStringValue(key, value);
      } else {
        sanitized[entry.key] = value;
      }
    }
    
    return sanitized;
  }
  
  /// Check if a key might contain PII
  static bool _isPotentialPii(String key) {
    const piiKeys = [
      'email',
      'name',
      'phone',
      'address',
      'ip',
      'password',
      'token',
      'secret',
      'key',
    ];
    
    return piiKeys.any((piiKey) => key.contains(piiKey));
  }
  
  /// Sanitize string values
  static String _sanitizeStringValue(String key, String value) {
    // For search queries, only track length for privacy
    if (key.contains('search') && key.contains('query')) {
      return '${value.length} characters';
    }
    
    // For content fields, only track metadata
    if (key.contains('content') || key.contains('text')) {
      return '${value.length} characters, ${value.split(' ').length} words';
    }
    
    // Truncate very long strings
    if (value.length > 100) {
      return '${value.substring(0, 97)}...';
    }
    
    return value;
  }
  
  /// Get standard event properties
  static Map<String, Object?> getStandardProperties() {
    return {
      AnalyticsProperties.timestamp: DateTime.now().toIso8601String(),
      AnalyticsProperties.platform: 'flutter',
      // Note: Environment will be added by the service implementation
    };
  }
  
  /// Calculate note metadata for analytics
  static Map<String, Object?> getNoteMetadata(String content) {
    final words = content.trim().split(RegExp(r'\s+'));
    return {
      AnalyticsProperties.characterCount: content.length,
      AnalyticsProperties.wordCount: words.where((w) => w.isNotEmpty).length,
      AnalyticsProperties.noteLength: _getNoteLength(content.length),
    };
  }
  
  /// Categorize note length
  static String _getNoteLength(int characterCount) {
    if (characterCount == 0) return 'empty';
    if (characterCount < 100) return 'short';
    if (characterCount < 500) return 'medium';
    if (characterCount < 2000) return 'long';
    return 'very_long';
  }
}
