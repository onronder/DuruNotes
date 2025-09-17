/// Quick Capture Service for Home Screen Widgets
/// Production-grade implementation with comprehensive error handling,
/// offline support, caching, and monitoring
///
/// @author Senior Architect
/// @version 1.0.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/attachment_service.dart';
import 'package:duru_notes/services/incoming_mail_folder_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================
// CONSTANTS
// ============================================

/// Platform channel for widget communication
const String _kChannelName = 'com.fittechs.durunotes/quick_capture';

/// Cache keys for SharedPreferences
const String _kCacheKey = 'quick_capture_cache';
const String _kPendingCapturesKey = 'pending_quick_captures';
const String _kLastSyncKey = 'quick_capture_last_sync';
const String _kAuthStatusKey = 'quick_capture_auth_status';

/// Configuration constants
const int _kMaxCacheSize = 10;
const int _kMaxRetries = 3;
const int _kRetryDelayMs = 1000;
const int _kCacheExpirationHours = 24;
const int _kMaxPendingCaptures = 50;
const int _kMaxTextLength = 10000;

// ============================================
// DATA MODELS
// ============================================

/// Model for quick capture data
@immutable
class QuickCaptureData {
  final String text;
  final String? templateId;
  final List<String>? attachments;
  final String platform;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  const QuickCaptureData({
    required this.text,
    this.templateId,
    this.attachments,
    required this.platform,
    this.metadata,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        if (templateId != null) 'templateId': templateId,
        if (attachments != null) 'attachments': attachments,
        'platform': platform,
        if (metadata != null) 'metadata': metadata,
        'timestamp': timestamp.toIso8601String(),
      };

  factory QuickCaptureData.fromJson(Map<String, dynamic> json) {
    return QuickCaptureData(
      text: json['text'] as String,
      templateId: json['templateId'] as String?,
      attachments: (json['attachments'] as List?)?.cast<String>(),
      platform: json['platform'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Model for capture result
@immutable
class CaptureResult {
  final bool success;
  final String? noteId;
  final String message;
  final String? errorCode;

  const CaptureResult({
    required this.success,
    this.noteId,
    required this.message,
    this.errorCode,
  });
}

/// Model for cached capture display
@immutable
class CachedCapture {
  final String id;
  final String title;
  final String snippet;
  final DateTime createdAt;
  final bool isWidget;
  final bool isPinned;

  const CachedCapture({
    required this.id,
    required this.title,
    required this.snippet,
    required this.createdAt,
    required this.isWidget,
    required this.isPinned,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'snippet': snippet,
        'createdAt': createdAt.toIso8601String(),
        'isWidget': isWidget,
        'isPinned': isPinned,
      };

  factory CachedCapture.fromJson(Map<String, dynamic> json) {
    return CachedCapture(
      id: json['id'] as String,
      title: json['title'] as String,
      snippet: json['snippet'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isWidget: json['isWidget'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }
}

/// Template model
@immutable
class QuickCaptureTemplate {
  final String id;
  final String name;
  final String icon;
  final String content;
  final Map<String, dynamic>? metadata;

  const QuickCaptureTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.content,
    this.metadata,
  });

  Map<String, String> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'content': content,
      };
}

// ============================================
// EXCEPTIONS
// ============================================

/// Custom exception for quick capture errors
class QuickCaptureException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const QuickCaptureException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'QuickCaptureException: $message (code: $code)';
}

// ============================================
// SERVICE IMPLEMENTATION
// ============================================

/// Service for handling quick capture from home screen widgets
class QuickCaptureService {
  // Constants
  static const int _maxQueueSize = 50; // Maximum offline queue size
  static const int _maxRetries = 3; // Maximum sync retries
  
  // Dependencies
  final NotesRepository _notesRepository;
  final AttachmentService _attachmentService;
  final IncomingMailFolderManager _folderManager;
  final AnalyticsService _analytics;
  final AppLogger _logger;

  // Platform channel
  late final MethodChannel _channel;

  // State management
  final StreamController<List<CachedCapture>> _cacheUpdateController =
      StreamController<List<CachedCapture>>.broadcast();
  final StreamController<bool> _authStatusController =
      StreamController<bool>.broadcast();

  // Sync management
  Timer? _syncTimer;
  bool _isSyncing = false;
  int _retryCount = 0;

  // Cache
  List<CachedCapture>? _memoryCache;
  DateTime? _lastCacheUpdate;

  QuickCaptureService({
    required NotesRepository notesRepository,
    required AttachmentService attachmentService,
    required IncomingMailFolderManager folderManager,
    required AnalyticsService analytics,
    required AppLogger logger,
  })  : _notesRepository = notesRepository,
        _attachmentService = attachmentService,
        _folderManager = folderManager,
        _analytics = analytics,
        _logger = logger {
    _channel = const MethodChannel(_kChannelName);
  }

  // ============================================
  // PUBLIC API
  // ============================================

  /// Stream of cache updates for UI
  Stream<List<CachedCapture>> get cacheUpdates => _cacheUpdateController.stream;

  /// Stream of authentication status changes
  Stream<bool> get authStatusChanges => _authStatusController.stream;

  /// Initialize the service and set up platform channel handlers
  Future<void> initialize() async {
    try {
      _logger.info('Initializing QuickCaptureService');
      _analytics.startTiming('quick_capture.initialization');

      // Set up platform channel handler
      _channel.setMethodCallHandler(_handleMethodCall);

      // Check and update authentication status
      await _updateAuthenticationStatus();

      // Process any pending captures from offline mode
      await _processPendingCaptures();

      // Update widget cache with recent captures
      await updateWidgetCache();

      // Start periodic sync timer (every 5 minutes)
      _startSyncTimer();

      _analytics.endTiming('quick_capture.initialization', properties: {
        'success': true,
      });

      _analytics.event('quick_capture.service_initialized');

      _logger.info('QuickCaptureService initialized successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to initialize QuickCaptureService',
        error: e,
        stackTrace: stackTrace,
      );

      _analytics.endTiming('quick_capture.initialization', properties: {
        'success': false,
        'error': e.toString(),
      });

      _analytics.trackError(
        'quick_capture.initialization_error',
        context: 'initialize',
        properties: {'error': e.toString()},
      );

      rethrow;
    }
  }

  /// Create a note from widget capture
  Future<CaptureResult> captureNote({
    required String text,
    String? templateId,
    List<String>? attachments,
    required String platform,
    Map<String, dynamic>? metadata,
  }) async {
    // Validate input
    if (text.isEmpty) {
      return const CaptureResult(
        success: false,
        message: 'Text cannot be empty',
        errorCode: 'EMPTY_TEXT',
      );
    }

    if (text.length > _kMaxTextLength) {
      return CaptureResult(
        success: false,
        message: 'Text exceeds maximum length of $_kMaxTextLength characters',
        errorCode: 'TEXT_TOO_LONG',
      );
    }

    final captureData = QuickCaptureData(
      text: text,
      templateId: templateId,
      attachments: attachments,
      platform: platform,
      metadata: metadata,
      timestamp: DateTime.now(),
    );

    try {
      return await _createNote(captureData);
    } catch (e) {
      _logger.error('Failed to capture note', error: e);

      // Store for later sync if network error
      if (_isNetworkError(e)) {
        await _storePendingCapture(captureData);
        return const CaptureResult(
          success: false,
          message: 'Note saved offline and will sync when connected',
          errorCode: 'OFFLINE',
        );
      }

      return CaptureResult(
        success: false,
        message: 'Failed to create note: ${e.toString()}',
        errorCode: 'CREATION_FAILED',
      );
    }
  }

  /// Get recent captures for widget display
  Future<List<CachedCapture>> getRecentCaptures({int limit = 5}) async {
    try {
      // Try memory cache first
      if (_memoryCache != null &&
          _lastCacheUpdate != null &&
          DateTime.now().difference(_lastCacheUpdate!).inMinutes < 5) {
        return _memoryCache!.take(limit).toList();
      }

      // Try persistent cache
      final cached = await _getCachedCaptures();
      if (cached.isNotEmpty) {
        _memoryCache = cached;
        _lastCacheUpdate = DateTime.now();
        return cached.take(limit).toList();
      }

      // Fetch from database
      return await _fetchRecentCaptures(limit);
    } catch (e) {
      _logger.error('Failed to get recent captures', error: e);
      return [];
    }
  }

  /// Get available templates
  List<QuickCaptureTemplate> getTemplates() {
    return [
      QuickCaptureTemplate(
        id: 'meeting',
        name: 'Meeting Notes',
        icon: '📝',
        content: '''## Meeting Notes

Date: {{date}}
Time: {{time}}

### Attendees
- 

### Agenda
{{text}}

### Action Items
- [ ] 

### Notes
''',
      ),
      QuickCaptureTemplate(
        id: 'todo',
        name: 'Quick Todo',
        icon: '✅',
        content: '''## Todo

- [ ] {{text}}

Due: 
Priority: Medium
Status: Pending

### Notes
''',
      ),
      QuickCaptureTemplate(
        id: 'idea',
        name: 'Idea',
        icon: '💡',
        content: '''## Idea

{{text}}

### Next Steps
1. Research feasibility
2. Create prototype
3. Get feedback

### Resources Needed
- 

### Impact
''',
      ),
    ];
  }

  /// Update widget cache with recent captures
  Future<void> updateWidgetCache({bool force = false}) async {
    try {
      _logger.debug('Updating widget cache (force: $force)');

      // Skip if recently updated and not forced
      if (!force &&
          _lastCacheUpdate != null &&
          DateTime.now().difference(_lastCacheUpdate!).inMinutes < 1) {
        _logger.debug('Skipping cache update - recently updated');
        return;
      }

      final captures = await _fetchRecentCaptures(_kMaxCacheSize);

      // Update memory cache
      _memoryCache = captures;
      _lastCacheUpdate = DateTime.now();

      // Update persistent cache
      await _updateCache(captures);

      // Notify listeners
      _cacheUpdateController.add(captures);

      // Notify native widgets to refresh
      await _notifyWidgetRefresh();

      _logger.debug('Widget cache updated with ${captures.length} captures');
    } catch (e) {
      _logger.error('Failed to update widget cache', error: e);
      _analytics.trackError(
        'quick_capture.cache_update_error',
        context: 'updateWidgetCache',
        properties: {'error': e.toString()},
      );
    }
  }

  /// Process pending captures after reconnection
  Future<int> processPendingCaptures() async {
    return _processPendingCaptures();
  }

  /// Clear all caches
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCacheKey);
      await prefs.remove(_kLastSyncKey);
      _memoryCache = null;
      _lastCacheUpdate = null;
      _logger.info('Cache cleared');
    } catch (e) {
      _logger.error('Failed to clear cache', error: e);
    }
  }

  /// Dispose the service
  void dispose() {
    _channel.setMethodCallHandler(null);
    _syncTimer?.cancel();
    _cacheUpdateController.close();
    _authStatusController.close();
    _logger.info('QuickCaptureService disposed');
  }

  // ============================================
  // PLATFORM CHANNEL HANDLING
  // ============================================

  /// Handle method calls from native widgets
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    _logger.debug('Received method call: ${call.method}', data: {
      'method': call.method,
      'arguments': call.arguments,
    });

    try {
      switch (call.method) {
        case 'captureNote':
          return await _handleCaptureNote(call.arguments);

        case 'getRecentCaptures':
          return await _handleGetRecentCaptures(call.arguments);

        case 'getTemplates':
          return _handleGetTemplates();

        case 'checkAuthStatus':
          return await _handleCheckAuthStatus();

        case 'openQuickCapture':
          return await _handleOpenQuickCapture(call.arguments);

        case 'openNote':
          return await _handleOpenNote(call.arguments);

        case 'refreshCache':
          await updateWidgetCache(force: true);
          return true;

        default:
          throw PlatformException(
            code: 'UNKNOWN_METHOD',
            message: 'Unknown method: ${call.method}',
          );
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error handling method call: ${call.method}',
        error: e,
        stackTrace: stackTrace,
      );

      _analytics.trackError(
        'quick_capture.method_call_error',
        context: call.method,
        properties: {'error': e.toString()},
      );

      if (e is PlatformException) {
        rethrow;
      }

      throw PlatformException(
        code: 'HANDLER_ERROR',
        message: e.toString(),
        details: stackTrace.toString(),
      );
    }
  }

  /// Handle capture note request from widget
  Future<Map<String, dynamic>> _handleCaptureNote(
      Map<dynamic, dynamic> args) async {
    final text = args['text'] as String?;
    final templateId = args['templateId'] as String?;
    final attachments = (args['attachments'] as List?)?.cast<String>();
    final platform = args['platform'] as String? ?? 'unknown';

    if (text == null || text.isEmpty) {
      return {
        'success': false,
        'error': 'EMPTY_TEXT',
        'message': 'Text cannot be empty',
      };
    }

    final result = await captureNote(
      text: text,
      templateId: templateId,
      attachments: attachments,
      platform: platform,
    );

    return {
      'success': result.success,
      if (result.noteId != null) 'noteId': result.noteId,
      'message': result.message,
      if (result.errorCode != null) 'error': result.errorCode,
    };
  }

  /// Handle get recent captures request
  Future<List<Map<String, dynamic>>> _handleGetRecentCaptures(
      Map<dynamic, dynamic> args) async {
    final limit = args['limit'] as int? ?? 5;
    final captures = await getRecentCaptures(limit: limit);
    return captures.map((c) => c.toJson()).toList();
  }

  /// Handle get templates request
  List<Map<String, String>> _handleGetTemplates() {
    return getTemplates().map((t) => t.toMap()).toList();
  }

  /// Handle check auth status request
  Future<Map<String, dynamic>> _handleCheckAuthStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    return {
      'isAuthenticated': user != null,
      'userId': user?.id,
      'email': user?.email,
    };
  }

  /// Handle open quick capture request
  Future<void> _handleOpenQuickCapture(Map<dynamic, dynamic> args) async {
    final templateId = args['templateId'] as String?;
    _logger.info('Opening quick capture editor', data: {
      'templateId': templateId,
    });
    // This would be handled by the app's navigation
    // The implementation depends on your app's navigation setup
  }

  /// Handle open note request
  Future<void> _handleOpenNote(Map<dynamic, dynamic> args) async {
    final noteId = args['noteId'] as String?;
    if (noteId != null) {
      _logger.info('Opening note', data: {'noteId': noteId});
      // This would be handled by the app's navigation
      // The implementation depends on your app's navigation setup
    }
  }

  // ============================================
  // NOTE CREATION
  // ============================================

  /// Create a note from capture data
  Future<CaptureResult> _createNote(QuickCaptureData capture) async {
    _analytics.startTiming('quick_capture.create_note');

    try {
      // Check authentication
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        // Store for later when user logs in
        await _storePendingCapture(capture);
        return const CaptureResult(
          success: false,
          message: 'Please sign in to capture notes',
          errorCode: 'NOT_AUTHENTICATED',
        );
      }

      // Apply template if specified
      String finalText = capture.text;
      String? title;
      if (capture.templateId != null) {
        final template = _getTemplate(capture.templateId!);
        if (template != null) {
          finalText = _applyTemplate(capture.text, template);
          title = _generateTitle(capture.text, template);
        }
      }

      // Generate title if not set
      title ??= _generateDefaultTitle(capture.text);

      // Create note with metadata
      final metadata = <String, dynamic>{
        'source': 'widget',
        'entry_point': capture.platform,
        'widget_version': '1.0.0',
        'capture_timestamp': capture.timestamp.toIso8601String(),
        if (capture.templateId != null) 'template_id': capture.templateId,
        if (capture.metadata != null) ...capture.metadata!,
      };

      // Create the note
      // Note: NotesRepository handles encryption internally using CryptoBox
      // The title and body will be encrypted as title_enc and props_enc
      final note = await _notesRepository.createOrUpdate(
        title: title,
        body: finalText,
        tags: {'widget', 'quick-capture'},
        metadataJson: metadata,
      );

      if (note == null) {
        throw const QuickCaptureException('Failed to create note');
      }

      // Add to Inbox folder (non-blocking)
      _addToInboxFolder(note.id);

      // Handle attachments if present (non-blocking)
      if (capture.attachments != null && capture.attachments!.isNotEmpty) {
        _processAttachments(note.id, capture.attachments!);
      }

      // Update widget cache (non-blocking)
      updateWidgetCache();

      _analytics.endTiming('quick_capture.create_note', properties: {
        'success': true,
        'platform': capture.platform,
        'has_template': capture.templateId != null,
        'has_attachments': capture.attachments?.isNotEmpty ?? false,
        'text_length': capture.text.length,
      });

      _analytics.event('quick_capture.widget_note_created', properties: {
        'platform': capture.platform,
        'note_id': note.id,
        'has_template': capture.templateId != null,
        'text_length': capture.text.length,
        'capture_type': 'widget_offline',
        'offline': true,
      });

      return CaptureResult(
        success: true,
        noteId: note.id,
        message: 'Note created successfully',
      );
    } catch (e) {
      _analytics.endTiming('quick_capture.create_note', properties: {
        'success': false,
        'error': e.toString(),
      });

      _analytics.trackError(
        'quick_capture.note_creation_error',
        context: '_createNote',
        properties: {
          'platform': capture.platform,
          'error': e.toString(),
        },
      );

      rethrow;
    }
  }

  // ============================================
  // TEMPLATE HANDLING
  // ============================================

  /// Get template by ID
  QuickCaptureTemplate? _getTemplate(String templateId) {
    final templates = getTemplates();
    try {
      return templates.firstWhere((t) => t.id == templateId);
    } catch (_) {
      return null;
    }
  }

  /// Apply template to text
  String _applyTemplate(String text, QuickCaptureTemplate template) {
    final now = DateTime.now();
    return template.content
        .replaceAll('{{text}}', text)
        .replaceAll('{{date}}', '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}')
        .replaceAll('{{time}}', '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
  }

  /// Generate title from template
  String _generateTitle(String text, QuickCaptureTemplate template) {
    final now = DateTime.now();
    final timestamp = '${now.month}/${now.day} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    switch (template.id) {
      case 'meeting':
        return 'Meeting Notes - $timestamp';
      case 'todo':
        return 'Quick Todo - $timestamp';
      case 'idea':
        return 'Idea - $timestamp';
      default:
        return _generateDefaultTitle(text);
    }
  }

  /// Generate default title from text
  String _generateDefaultTitle(String text) {
    final now = DateTime.now();
    final timestamp = '${now.month}/${now.day} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    // Try to extract first line as title
    final firstLine = text.split('\n').first.trim();
    if (firstLine.isNotEmpty && firstLine.length <= 50) {
      return firstLine;
    } else if (firstLine.length > 50) {
      return '${firstLine.substring(0, 47)}...';
    }
    
    return 'Quick Capture - $timestamp';
  }

  // ============================================
  // OFFLINE SUPPORT
  // ============================================

  /// Store a pending capture for later sync
  Future<void> _storePendingCapture(QuickCaptureData capture) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_kPendingCapturesKey) ?? [];

      // Limit pending captures
      if (pending.length >= _kMaxPendingCaptures) {
        _logger.warning('Maximum pending captures reached, removing oldest');
        pending.removeAt(0);
      }

      pending.add(jsonEncode(capture.toJson()));
      await prefs.setStringList(_kPendingCapturesKey, pending);

      _logger.info('Stored pending capture for later sync');
      _analytics.event('quick_capture.offline_capture_stored');
    } catch (e) {
      _logger.error('Failed to store pending capture', error: e);
    }
  }

  /// Process pending captures after reconnection
  Future<int> _processPendingCaptures() async {
    if (_isSyncing) {
      _logger.debug('Already syncing, skipping pending captures processing');
      return 0;
    }

    _isSyncing = true;
    int processedCount = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_kPendingCapturesKey) ?? [];

      if (pending.isEmpty) {
        return 0;
      }

      _logger.info('Processing ${pending.length} pending captures');

      final failed = <String>[];

      for (final captureJson in pending) {
        try {
          final capture = QuickCaptureData.fromJson(
            jsonDecode(captureJson) as Map<String, dynamic>,
          );

          // Skip if too old (> 7 days)
          if (DateTime.now().difference(capture.timestamp).inDays > 7) {
            _logger.debug('Skipping old pending capture');
            continue;
          }

          final result = await _createNote(capture);
          if (result.success) {
            processedCount++;
          } else {
            failed.add(captureJson);
          }
        } catch (e) {
          _logger.error('Failed to process pending capture', error: e);
          failed.add(captureJson);
        }
      }

      // Keep failed captures for next retry
      await prefs.setStringList(_kPendingCapturesKey, failed);

      if (processedCount > 0) {
        _analytics.event('quick_capture.pending_captures_processed', properties: {
          'count': processedCount,
          'remaining': failed.length,
        });
      }

      return processedCount;
    } catch (e) {
      _logger.error('Error processing pending captures', error: e);
      return processedCount;
    } finally {
      _isSyncing = false;
    }
  }

  // ============================================
  // CACHE MANAGEMENT
  // ============================================

  /// Fetch recent captures from database
  Future<List<CachedCapture>> _fetchRecentCaptures(int limit) async {
    try {
      final notes = await _notesRepository.getRecentlyViewedNotes(limit: limit);

      return notes.map((note) {
        final metadata = note.encryptedMetadata != null
            ? jsonDecode(note.encryptedMetadata!) as Map<String, dynamic>
            : <String, dynamic>{};

        return CachedCapture(
          id: note.id,
          title: note.title,
          snippet: note.body.length > 100
              ? '${note.body.substring(0, 100)}...'
              : note.body,
          createdAt: note.updatedAt,
          isWidget: metadata['source'] == 'widget',
          isPinned: note.isPinned,
        );
      }).toList();
    } catch (e) {
      _logger.error('Failed to fetch recent captures', error: e);
      return [];
    }
  }

  /// Get cached captures from persistent storage
  Future<List<CachedCapture>> _getCachedCaptures() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kCacheKey);

      if (cached == null) return [];

      final list = jsonDecode(cached) as List;
      return list
          .map((item) => CachedCapture.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.error('Failed to decode cache', error: e);
      return [];
    }
  }

  /// Update persistent cache
  Future<void> _updateCache(List<CachedCapture> captures) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = captures.map((c) => c.toJson()).toList();
      await prefs.setString(_kCacheKey, jsonEncode(json));
      await prefs.setString(_kLastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      _logger.error('Failed to update cache', error: e);
    }
  }

  // ============================================
  // WIDGET COMMUNICATION
  // ============================================

  /// Notify native widgets to refresh
  Future<void> _notifyWidgetRefresh() async {
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        await _channel.invokeMethod('refreshWidget');
        _logger.debug('Widget refresh notification sent');
      }
    } catch (e) {
      _logger.debug('Widget refresh notification failed', data: {
        'error': e.toString(),
      });
    }
  }

  /// Update authentication status in widget
  Future<void> _updateAuthenticationStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final isAuthenticated = user != null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAuthStatusKey, isAuthenticated);

      if (Platform.isIOS || Platform.isAndroid) {
        await _channel.invokeMethod('setAuthStatus', {
          'isAuthenticated': isAuthenticated,
          'userId': user?.id,
          'email': user?.email,
        });
      }

      _authStatusController.add(isAuthenticated);
    } catch (e) {
      _logger.error('Failed to update authentication status', error: e);
    }
  }

  // ============================================
  // BACKGROUND OPERATIONS
  // ============================================

  /// Add note to inbox folder (non-blocking)
  Future<void> _addToInboxFolder(String noteId) async {
    try {
      await _folderManager.addNoteToIncomingMail(noteId);
      _logger.debug('Note added to inbox folder');
    } catch (e) {
      _logger.warning('Failed to add note to inbox folder', data: {
        'noteId': noteId,
        'error': e.toString(),
      });
    }
  }

  /// Process attachments (non-blocking)
  Future<void> _processAttachments(
      String noteId, List<String> attachmentPaths) async {
    try {
      _logger.info('Processing ${attachmentPaths.length} attachments for note $noteId');
      // TODO: Implement attachment processing
      // This would involve:
      // 1. Downloading attachments from temporary storage
      // 2. Uploading to permanent storage
      // 3. Updating note with attachment metadata
    } catch (e) {
      _logger.error('Failed to process attachments', error: e);
    }
  }

  /// Start periodic sync timer
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _processPendingCaptures();
      updateWidgetCache();
    });
  }

  /// Check if error is network-related
  bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('offline') ||
        errorString.contains('socketexception') ||
        errorString.contains('timeout');
  }
}
