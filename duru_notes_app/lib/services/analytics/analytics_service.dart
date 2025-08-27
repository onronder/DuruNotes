import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/monitoring/app_logger.dart';

/// Analytics events constants
class AnalyticsEvents {
  // Note events
  static const String noteCreate = 'note_create';
  static const String noteEdit = 'note_edit';
  static const String noteView = 'note_view';
  static const String noteDelete = 'note_delete';
  static const String notesPageLoaded = 'notes_page_loaded';
  static const String notesLoadMore = 'notes_load_more';
  static const String notesRefreshed = 'notes_refreshed';
  
  // Search events
  static const String searchStarted = 'search_started';
  static const String searchCompleted = 'search_completed';
  
  // Reminder events
  static const String reminderSet = 'reminder_set';
  static const String reminderRemoved = 'reminder_removed';
  
  // Auth events
  static const String userSignIn = 'user_sign_in';
  static const String userSignOut = 'user_sign_out';
  static const String userSignUp = 'user_sign_up';
  
  // Feature usage
  static const String featureUsed = 'feature_used';
  static const String errorOccurred = 'error_occurred';
}

/// Analytics properties constants
class AnalyticsProperties {
  static const String userId = 'user_id';
  static const String noteId = 'note_id';
  static const String searchQuery = 'search_query';
  static const String searchResultCount = 'search_result_count';
  static const String featureName = 'feature_name';
  static const String errorType = 'error_type';
  static const String errorMessage = 'error_message';
  static const String contentLength = 'content_length';
  static const String hasTitle = 'has_title';
  static const String blockCount = 'block_count';
  static const String wordCount = 'word_count';
  static const String characterCount = 'character_count';
  static const String hasMarkdown = 'has_markdown';
  static const String hasTodos = 'has_todos';
  static const String hasCode = 'has_code';
  static const String hasLinks = 'has_links';
  static const String hasAttachments = 'has_attachments';
}

/// Analytics helper for extracting metadata
class AnalyticsHelper {
  /// Extract metadata from note content
  static Map<String, dynamic> getNoteMetadata(String content) {
    final hasMarkdown = _hasMarkdownFormatting(content);
    final todoCount = _countTodos(content);
    final codeBlockCount = _countCodeBlocks(content);
    final linkCount = _countLinks(content);
    final words = content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    
    return {
      AnalyticsProperties.wordCount: words,
      AnalyticsProperties.characterCount: content.length,
      AnalyticsProperties.hasMarkdown: hasMarkdown,
      AnalyticsProperties.hasTodos: todoCount > 0,
      AnalyticsProperties.hasCode: codeBlockCount > 0,
      AnalyticsProperties.hasLinks: linkCount > 0,
      'todo_count': todoCount,
      'code_block_count': codeBlockCount,
      'link_count': linkCount,
    };
  }
  
  static bool _hasMarkdownFormatting(String content) {
    return content.contains(RegExp(r'[#*`>]'));
  }
  
  static int _countTodos(String content) {
    return RegExp(r'- \[([ x])\]').allMatches(content).length;
  }
  
  static int _countCodeBlocks(String content) {
    return RegExp(r'```').allMatches(content).length ~/ 2;
  }
  
  static int _countLinks(String content) {
    return RegExp(r'\[.*?\]\(.*?\)').allMatches(content).length;
  }
}

/// Base analytics service interface
abstract class AnalyticsService {
  /// Track an event with optional properties
  void event(String name, {Map<String, dynamic>? properties});
  
  /// Track a screen view
  void screen(String name, {Map<String, dynamic>? properties});
  
  /// Start timing an operation
  void startTiming(String name);
  
  /// End timing an operation
  void endTiming(String name, {Map<String, dynamic>? properties});
  
  /// Track feature usage
  void featureUsed(String feature, {Map<String, dynamic>? properties});
  
  /// Track errors
  void trackError(String message, {String? context, Map<String, dynamic>? properties});
  
  /// Set user properties
  void setUserProperties(Map<String, dynamic> properties);
  
  /// Flush pending events
  Future<void> flush();
}

/// No-op analytics implementation for when analytics is disabled
class NoOpAnalytics implements AnalyticsService {
  @override
  void event(String name, {Map<String, dynamic>? properties}) {
    // No-op
  }
  
  @override
  void screen(String name, {Map<String, dynamic>? properties}) {
    // No-op
  }
  
  @override
  void startTiming(String name) {
    // No-op
  }
  
  @override
  void endTiming(String name, {Map<String, dynamic>? properties}) {
    // No-op
  }
  
  @override
  void featureUsed(String feature, {Map<String, dynamic>? properties}) {
    // No-op
  }
  
  @override
  void trackError(String message, {String? context, Map<String, dynamic>? properties}) {
    // No-op
  }
  
  @override
  void setUserProperties(Map<String, dynamic> properties) {
    // No-op
  }
  
  @override
  Future<void> flush() async {
    // No-op
  }
}

/// Debug analytics implementation that logs to console
class DebugAnalytics implements AnalyticsService {
  final Map<String, DateTime> _timings = {};
  
  @override
  void event(String name, {Map<String, dynamic>? properties}) {
    _log('EVENT: $name', properties);
  }
  
  @override
  void screen(String name, {Map<String, dynamic>? properties}) {
    _log('SCREEN: $name', properties);
  }
  
  @override
  void startTiming(String name) {
    _timings[name] = DateTime.now();
    _log('TIMING_START: $name');
  }
  
  @override
  void endTiming(String name, {Map<String, dynamic>? properties}) {
    final startTime = _timings.remove(name);
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      final props = {
        'duration_ms': duration.inMilliseconds,
        ...?properties,
      };
      _log('TIMING_END: $name', props);
    }
  }
  
  @override
  void featureUsed(String feature, {Map<String, dynamic>? properties}) {
    event(AnalyticsEvents.featureUsed, properties: {
      AnalyticsProperties.featureName: feature,
      ...?properties,
    });
  }
  
  @override
  void trackError(String message, {String? context, Map<String, dynamic>? properties}) {
    event(AnalyticsEvents.errorOccurred, properties: {
      AnalyticsProperties.errorMessage: message,
      if (context != null) 'context': context,
      ...?properties,
    });
  }
  
  @override
  void setUserProperties(Map<String, dynamic> properties) {
    _log('USER_PROPERTIES', properties);
  }
  
  @override
  Future<void> flush() async {
    _log('FLUSH');
  }
  
  void _log(String event, [Map<String, dynamic>? properties]) {
    if (kDebugMode) {
      final props = properties?.isNotEmpty == true 
          ? ' | ${properties!.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
          : '';
      print('📊 $event$props');
    }
  }
}

/// Analytics factory for creating analytics instances
class AnalyticsFactory {
  static AnalyticsService? _instance;
  
  static void initialize({bool analyticsEnabled = true}) {
    if (analyticsEnabled) {
      if (kDebugMode) {
        _instance = DebugAnalytics();
      } else {
        // In production, you could use a real analytics service here
        _instance = DebugAnalytics();
      }
    } else {
      _instance = NoOpAnalytics();
    }
  }
  
  static AnalyticsService get instance {
    return _instance ?? DebugAnalytics();
  }
}