import 'dart:convert';
import 'dart:io';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/domain/entities/quick_capture_widget_cache.dart';
import 'package:duru_notes/domain/entities/template.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_quick_capture_repository.dart';
import 'package:duru_notes/domain/repositories/i_template_repository.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/attachment_service.dart';
import 'package:duru_notes/services/quick_capture_widget_syncer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception class for quick capture operations
class QuickCaptureException implements Exception {
  QuickCaptureException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => 'QuickCaptureException: $message';
}

/// Result object for capture operations
class QuickCaptureResult {
  QuickCaptureResult({
    required this.success,
    this.noteId,
    this.error,
    this.metadata,
  });

  final bool success;
  final String? noteId;
  final String? error;
  final Map<String, dynamic>? metadata;
}

/// Quick capture data object
class QuickCaptureData {
  QuickCaptureData({
    required this.text,
    this.platform,
    this.templateId,
    this.tags,
    this.metadata,
  });

  final String text;
  final String? platform;
  final String? templateId;
  final List<String>? tags;
  final Map<String, dynamic>? metadata;
}

/// Quick capture service for handling rapid note creation
/// Production-grade implementation aligned with encrypted architecture
class QuickCaptureService {
  QuickCaptureService({
    required INotesRepository notesRepository,
    required ITemplateRepository templateRepository,
    required IQuickCaptureRepository quickCaptureRepository,
    required AnalyticsService analyticsService,
    required AppLogger logger,
    required SupabaseClient supabaseClient,
    AttachmentService? attachmentService,
    QuickCaptureWidgetSyncer? widgetSyncer,
  }) : _notesRepository = notesRepository,
       _templateRepository = templateRepository,
       _quickCaptureRepository = quickCaptureRepository,
       _analyticsService = analyticsService,
       _logger = logger,
       _supabaseClient = supabaseClient,
       _attachmentService = attachmentService,
       _widgetSyncer =
           widgetSyncer ??
           (Platform.isIOS
               ? IosQuickCaptureWidgetSyncer(logger: logger)
               : const NoopQuickCaptureWidgetSyncer());

  final INotesRepository _notesRepository;
  final ITemplateRepository _templateRepository;
  final IQuickCaptureRepository _quickCaptureRepository;
  final AnalyticsService _analyticsService;
  final AppLogger _logger;
  final SupabaseClient _supabaseClient;
  final AttachmentService? _attachmentService;
  final QuickCaptureWidgetSyncer _widgetSyncer;

  final List<Note> _recentCaptures = <Note>[];
  bool _initialized = false;

  static const int _recentCapturesCacheSize = 20;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _initialized = true;
      _analyticsService.event(
        'quick_capture.service_initialized',
        properties: {'timestamp': DateTime.now().toIso8601String()},
      );
      if (_attachmentService != null) {
        _logger.debug(
          'QuickCaptureService attachment support enabled',
          data: {'service': _attachmentService.runtimeType.toString()},
        );
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to initialize QuickCaptureService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<QuickCaptureResult> captureNote({
    required String text,
    String? platform,
    String? templateId,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) async {
    await initialize();

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return QuickCaptureResult(success: false, error: 'Text cannot be empty');
    }
    if (trimmed.length > 10000) {
      return QuickCaptureResult(
        success: false,
        error: 'Text exceeds maximum length',
      );
    }

    final userId = _currentUserId();
    if (userId == null) {
      _logger.warning(
        '[QuickCapture] capture request denied – unauthenticated',
      );
      return QuickCaptureResult(
        success: false,
        error: 'User not authenticated',
      );
    }

    final captureMetadata = _buildCaptureMetadata(
      platform: platform,
      templateId: templateId,
      extra: metadata,
    );
    final title = _deriveTitle(trimmed);

    try {
      final note = await _notesRepository.createOrUpdate(
        title: title,
        body: trimmed,
        tags: tags ?? const <String>[],
        metadataJson: captureMetadata,
      );
      if (note == null) {
        throw QuickCaptureException('Note repository returned null');
      }

      _addToRecentCaptures(
        Note(
          id: note.id,
          title: note.title,
          body: note.body,
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
          deleted: note.deleted,
          isPinned: note.isPinned,
          noteType: note.noteType,
          version: note.version,
          userId: note.userId,
        ),
      );

      await _refreshWidgetCache(userId: userId);

      _analyticsService.event(
        'quick_capture.note_created',
        properties: {
          'platform': platform ?? 'unknown',
          'hasTemplate': templateId != null,
          'hasTags': tags?.isNotEmpty ?? false,
          'textLength': trimmed.length,
        },
      );

      return QuickCaptureResult(
        success: true,
        noteId: note.id,
        metadata: captureMetadata,
      );
    } on SocketException catch (error, stackTrace) {
      _logger.error(
        'Quick capture offline – enqueueing capture',
        error: error,
        stackTrace: stackTrace,
      );
      await _enqueueForLater(
        userId: userId,
        text: trimmed,
        platform: platform,
        templateId: templateId,
        tags: tags,
        metadata: captureMetadata,
      );
      _analyticsService.event(
        'quick_capture.note_queued',
        properties: {
          'platform': platform ?? 'unknown',
          'reason': 'socket_exception',
        },
      );
      return QuickCaptureResult(
        success: false,
        error: 'queued',
        metadata: {...captureMetadata, 'queued': true},
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to capture note – queued for retry',
        error: error,
        stackTrace: stackTrace,
      );
      await _enqueueForLater(
        userId: userId,
        text: trimmed,
        platform: platform,
        templateId: templateId,
        tags: tags,
        metadata: captureMetadata,
      );
      _analyticsService.event(
        'quick_capture.note_queued',
        properties: {
          'platform': platform ?? 'unknown',
          'reason': error.runtimeType.toString(),
        },
      );
      return QuickCaptureResult(
        success: false,
        error: error.toString(),
        metadata: {...captureMetadata, 'queued': true},
      );
    }
  }

  Future<QuickCaptureResult> captureNote2(QuickCaptureData data) async {
    return captureNote(
      text: data.text,
      platform: data.platform,
      templateId: data.templateId,
      tags: data.tags,
      metadata: data.metadata,
    );
  }

  Future<List<Note>> getRecentCaptures({int limit = 10}) async {
    if (_recentCaptures.isNotEmpty) {
      return _recentCaptures.take(limit).toList(growable: false);
    }
    final notes = await _notesRepository.list(limit: limit);
    if (notes.isEmpty) return const <Note>[];
    _recentCaptures
      ..clear()
      ..addAll(notes.take(_recentCapturesCacheSize));
    return notes;
  }

  void clearCache() {
    _recentCaptures.clear();
  }

  Future<void> updateWidgetCache() async {
    final userId = _currentUserId();
    if (userId == null) return;
    await _refreshWidgetCache(userId: userId);
    _analyticsService.event('quick_capture.widget_cache_updated');
  }

  Future<void> refreshWidget() async {
    _analyticsService.event('quick_capture.widget_refreshed');
  }

  Future<List<Template>> getTemplates() async {
    try {
      return await _templateRepository.getAllTemplates();
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load templates for quick capture',
        error: error,
        stackTrace: stackTrace,
      );
      return const <Template>[];
    }
  }

  Future<int> processPendingCaptures() async {
    final userId = _currentUserId();
    if (userId == null) return 0;

    final pending = await _quickCaptureRepository.getPendingCaptures(
      userId: userId,
      limit: 20,
    );

    var processed = 0;
    for (final item in pending) {
      final payload = item.payload;
      final text = (payload['text'] as String?)?.trim();
      if (text == null || text.isEmpty) {
        await _quickCaptureRepository.markCaptureProcessed(
          id: item.id,
          processed: true,
          processedAt: DateTime.now().toUtc(),
        );
        continue;
      }

      final templateId = payload['templateId'] as String?;
      final tags = _parseStringList(payload['tags']);
      final metadata = Map<String, dynamic>.from(
        _parseMap(payload['metadata']) ?? const <String, dynamic>{},
      );
      metadata['queued'] = false;

      try {
        final note = await _notesRepository.createOrUpdate(
          title: _deriveTitle(text),
          body: text,
          tags: tags,
          metadataJson: metadata,
        );

        if (note != null) {
          processed += 1;
          await _quickCaptureRepository.markCaptureProcessed(
            id: item.id,
            processed: true,
            processedAt: DateTime.now().toUtc(),
          );
        } else {
          await _quickCaptureRepository.incrementRetryCount(item.id);
        }
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to process queued quick capture',
          error: error,
          stackTrace: stackTrace,
          data: {'queueId': item.id, 'templateId': templateId},
        );
        await _quickCaptureRepository.incrementRetryCount(item.id);
      }
    }

    if (processed > 0) {
      await _refreshWidgetCache(userId: userId);
      await _quickCaptureRepository.clearProcessedCaptures(
        userId: userId,
        olderThan: DateTime.now().toUtc().subtract(const Duration(days: 7)),
      );
    }

    _analyticsService.event(
      'quick_capture.pending_captures_processed',
      properties: {
        'processed': processed,
        'remaining': pending.length - processed,
      },
    );
    return processed;
  }

  Future<void> dispose() async {
    clearCache();
    _initialized = false;
  }

  Future<void> _enqueueForLater({
    required String userId,
    required String text,
    String? platform,
    String? templateId,
    List<String>? tags,
    required Map<String, dynamic> metadata,
  }) async {
    final payload = <String, dynamic>{
      'text': text,
      'templateId': templateId,
      'tags': tags ?? const <String>[],
      'metadata': metadata,
      'capturedAt': DateTime.now().toIso8601String(),
    };
    await _quickCaptureRepository.enqueueCapture(
      userId: userId,
      payload: payload,
      platform: platform,
    );
  }

  /// Format DateTime to ISO8601 without fractional seconds for widget compatibility
  /// Swift's ISO8601DateFormatter expects either 3 digits (milliseconds) or 0 digits,
  /// but Dart's toIso8601String() produces 6 digits (microseconds), causing parsing to fail.
  String _formatDateWithoutMicroseconds(DateTime date) {
    // Remove microseconds: "2025-10-28T13:09:37.123456Z" -> "2025-10-28T13:09:37Z"
    return '${date.toUtc().toIso8601String().split('.').first}Z';
  }

  Future<void> _refreshWidgetCache({required String userId}) async {
    try {
      final recent = await _notesRepository.list(limit: 10);
      final payload = <String, dynamic>{
        'userId': userId,
        'updatedAt': _formatDateWithoutMicroseconds(DateTime.now()),
        'recentCaptures': recent
            .map(
              (note) => {
                'id': note.id,
                'title': note.title,
                'snippet': note.body.length > 140
                    ? '${note.body.substring(0, 137)}...'
                    : note.body,
                'createdAt': _formatDateWithoutMicroseconds(note.createdAt),
                'updatedAt': _formatDateWithoutMicroseconds(note.updatedAt),
              },
            )
            .toList(),
      };

      await _quickCaptureRepository.upsertWidgetCache(
        QuickCaptureWidgetCache(
          userId: userId,
          payload: payload,
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      await _widgetSyncer.sync(userId: userId, payload: payload);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to refresh widget cache',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _addToRecentCaptures(Note note) {
    _recentCaptures.insert(0, note);
    if (_recentCaptures.length > _recentCapturesCacheSize) {
      _recentCaptures.removeRange(
        _recentCapturesCacheSize,
        _recentCaptures.length,
      );
    }
  }

  String _deriveTitle(String text) {
    final firstLine = text.split('\n').first.trim();
    if (firstLine.isEmpty) return 'Quick Capture';
    return firstLine.length > 64
        ? '${firstLine.substring(0, 61)}...'
        : firstLine;
  }

  Map<String, dynamic> _buildCaptureMetadata({
    required String? platform,
    required String? templateId,
    required Map<String, dynamic>? extra,
  }) {
    return <String, dynamic>{
      'source': 'quick_capture',
      'platform': platform ?? 'unknown',
      if (templateId != null) 'templateId': templateId,
      'capturedAt': DateTime.now().toIso8601String(),
      ...?extra,
    };
  }

  String? _currentUserId() => _supabaseClient.auth.currentUser?.id;

  List<String> _parseStringList(dynamic value) {
    if (value == null) return const <String>[];
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((item) => item.toString()).toList();
        }
      } catch (_) {
        return value
            .split(',')
            .map((element) => element.trim())
            .where((element) => element.isNotEmpty)
            .toList();
      }
    }
    return const <String>[];
  }

  Map<String, dynamic>? _parseMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic val) => MapEntry(key.toString(), val));
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map(
            (key, dynamic val) => MapEntry(key.toString(), val),
          );
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
