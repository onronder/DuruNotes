import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/inbox_unread_service.dart';
import 'package:duru_notes/services/incoming_mail_folder_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Port interface for creating encrypted notes
abstract class NotesCapturePort {
  Future<String> createEncryptedNote({
    required String title,
    required String body,
    required Map<String, dynamic> metadataJson,
    List<String> tags,
  });
}

/// Service for monitoring the clipper_inbox table (manual workflow by default)
///
/// IMPORTANT: Auto-processing is DISABLED by default (kInboxAutoProcess = false)
/// - Email and web clip inbox items remain in inbox for user review
/// - User manually converts items via InboxManagementService
/// - Badge notifications show unread count
/// - Items persist until user action (convert or delete)
///
/// When kInboxAutoProcess = false (default - MANUAL MODE):
/// - Items remain in clipper_inbox until user manually converts them
/// - InboxRealtimeService provides realtime badge updates
/// - InboxUnreadService tracks unread count
/// - Manual conversion is handled by InboxManagementService via UI
/// - User has full control over which emails become notes
///
/// When kInboxAutoProcess = true (AUTO MODE - not recommended):
/// - Auto-converts inbox items to notes immediately upon arrival
/// - Monitors via both realtime subscriptions and polling (30s interval)
/// - Deletes items after successful conversion
/// - User never sees items in inbox UI
/// - No user review or control
class ClipperInboxService {
  ClipperInboxService({
    required SupabaseClient supabase,
    required NotesCapturePort notesPort,
    required IncomingMailFolderManager folderManager,
    InboxUnreadService? unreadService, // Kept in constructor for backward compatibility
  })  : _supabase = supabase,
        _notesPort = notesPort,
        _folderManager = folderManager;

  final SupabaseClient _supabase;
  final NotesCapturePort _notesPort;
  final IncomingMailFolderManager _folderManager;
  final AppLogger _logger = LoggerFactory.instance;

  Timer? _timer;
  RealtimeChannel? _realtimeChannel;

  // Track processed IDs to avoid duplicates between realtime and polling
  final Set<String> _processedIds = {};
  final int _maxProcessedIds = 1000; // Limit memory usage

  // Processing queue for realtime events
  final List<Map<String, dynamic>> _processingQueue = [];
  bool _isProcessingQueue = false;

  // Track realtime connection status
  bool _realtimeConnected = false;

  // Polling intervals
  static const Duration _normalPollingInterval = Duration(seconds: 30);
  static const Duration _realtimePollingInterval = Duration(minutes: 2);

  // Feature flag to control auto-processing (DISABLED - manual conversion via Inbox UI)
  // Set to true for automatic conversion (not recommended - bypasses user review)
  static const bool kInboxAutoProcess = false;

  void start() {
    // Check auto-processing feature flag
    if (!kInboxAutoProcess) {
      _logger.info(
        '🚫 [ClipperInbox] Auto-processing DISABLED - manual workflow active via InboxManagementService',
      );
      // Realtime is now handled by UnifiedRealtimeService
      // Badge counter handled by InboxUnreadService
      // Manual conversion handled by InboxManagementService
      return;
    }

    // Auto-processing ENABLED - start monitoring inbox
    _logger.info(
      '✅ [ClipperInbox] Auto-processing ENABLED - starting service',
    );
    stop();
    _startRealtimeSubscription();
    _startPolling();

    // Initial poll - process any pending items (including stuck items from previous sessions)
    unawaited(processOnce());
    _logger.info('[ClipperInbox] Service started successfully - monitoring inbox for auto-conversion');
  }

  /// One-time cleanup to process any stuck inbox items (useful after re-enabling auto-process)
  Future<void> processAllPendingItems() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _logger.debug('🔒 [ClipperInbox] No authenticated user for cleanup');
        return;
      }

      _logger.info('🧹 [ClipperInbox] Starting cleanup of pending inbox items...');

      // Fetch ALL pending items without filtering by processed IDs
      final rows = await _supabase
          .from('clipper_inbox')
          .select()
          .eq('user_id', userId) // Strict user scoping
          .or('source_type.eq.email_in,source_type.eq.web')
          .order('created_at', ascending: true);

      if (rows.isEmpty) {
        _logger.info('[ClipperInbox] No pending items to clean up');
        return;
      }

      _logger.info('📥 [ClipperInbox] Found ${rows.length} pending items to process');

      // Clear processed IDs to allow reprocessing
      final originalProcessedIds = Set<String>.from(_processedIds);
      _processedIds.clear();

      int successCount = 0;
      int failCount = 0;

      for (final row in rows) {
        try {
          await _handleRow(row);
          successCount++;
        } catch (e) {
          failCount++;
          _logger.error('❌ [ClipperInbox] Failed to process item ${row['id']}: $e');
        }
      }

      _logger.info(
        '✅ [ClipperInbox] Cleanup complete: $successCount succeeded, $failCount failed',
      );

      // Restore processed IDs for normal operation
      _processedIds.addAll(originalProcessedIds);
    } catch (e, st) {
      _logger.error('❌ [ClipperInbox] Cleanup error: $e', error: e, stackTrace: st);
    }
  }

  void stop() {
    _stopPolling();
    _stopRealtimeSubscription();
    _processedIds.clear();
    _processingQueue.clear();
  }

  void _startPolling() {
    _stopPolling();
    // Use longer interval when realtime is connected
    final interval =
        _realtimeConnected ? _realtimePollingInterval : _normalPollingInterval;
    _timer = Timer.periodic(interval, (_) => unawaited(processOnce()));
    _logger.debug(' Polling started with interval: ${interval.inSeconds}s');
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  void _startRealtimeSubscription() {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _logger.debug(' Cannot start realtime: no authenticated user');
        return;
      }

      // Create channel for clipper_inbox inserts
      _realtimeChannel =
          _supabase.channel('clipper_inbox_changes').onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'clipper_inbox',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'user_id',
                  value: userId,
                ),
                callback: _handleRealtimeInsert,
              );

      // Subscribe to the channel
      _realtimeChannel!.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _logger.debug(' Realtime subscription active');
          _realtimeConnected = true;
          // Restart polling with longer interval
          _startPolling();
        } else if (status == RealtimeSubscribeStatus.closed ||
            status == RealtimeSubscribeStatus.channelError) {
          _logger.debug(' Realtime subscription lost: $status, error: $error');
          _realtimeConnected = false;
          // Restart polling with normal interval
          _startPolling();
        }
      });

      _logger.debug(' Realtime subscription initiated for user: $userId');
    } catch (e) {
      _logger.debug(' Failed to setup realtime subscription: $e');
      _realtimeConnected = false;
    }
  }

  void _stopRealtimeSubscription() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _realtimeConnected = false;
    _logger.debug(' Realtime subscription stopped');
  }

  void _handleRealtimeInsert(PostgresChangePayload payload) {
    try {
      final newRow = payload.newRecord;
      final id = newRow['id'] as String?;

      if (id == null) {
        _logger.debug(' Realtime insert missing ID');
        return;
      }

      // Check if already processed
      if (_processedIds.contains(id)) {
        _logger.debug(' Skipping duplicate realtime event for ID: $id');
        return;
      }

      _logger.debug(' Realtime insert detected: $id');

      // Add to processing queue
      _processingQueue.add(newRow);

      // Process the queue
      unawaited(_processQueue());
    } catch (e) {
      _logger.debug(' Error handling realtime insert: $e');
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue) {
      return; // Already processing
    }

    _isProcessingQueue = true;
    try {
      while (_processingQueue.isNotEmpty) {
        final row = _processingQueue.removeAt(0);
        await _handleRow(row);
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<void> processOnce() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _logger.debug('🔒 [ClipperInbox] No authenticated user for processOnce');
        return;
      }

      _logger.debug('🔄 [ClipperInbox] Polling inbox for user: ${userId.substring(0, 8)}...');

      // Fetch both email and web entries - strictly scoped to user
      final rows = await _supabase
          .from('clipper_inbox')
          .select()
          .eq('user_id', userId) // Strict user scoping
          .or('source_type.eq.email_in,source_type.eq.web')
          .order('created_at', ascending: true);

      if (rows.isEmpty) {
        // Silent return - no spam in logs for normal empty state
        return;
      }

      _logger.info('📥 [ClipperInbox] Found ${rows.length} items to process');

      int processed = 0;
      int failed = 0;
      for (final row in rows) {
        try {
          await _handleRow(row);
          processed++;
        } catch (e) {
          failed++;
          _logger.error('❌ [ClipperInbox] Failed to process row ${row['id']}: $e');
        }
      }

      _logger.info('✅ [ClipperInbox] Batch complete: $processed processed, $failed failed');
    } catch (e, st) {
      _logger.error('❌ [ClipperInbox] Processing error: $e', error: e, stackTrace: st);
    }
  }

  Future<void> _handleRow(Map<String, dynamic> row) async {
    final id = row['id'] as String;

    // Skip if already processed
    if (_processedIds.contains(id)) {
      _logger.debug(' Skipping already processed ID: $id');
      return;
    }

    final sourceType = row['source_type'] as String;
    final payload = Map<String, dynamic>.from(row['payload_json'] as Map);

    try {
      // Branch based on source type
      if (sourceType == 'email_in') {
        await _handleEmailRow(id, payload);
      } else if (sourceType == 'web') {
        await _handleWebRow(id, payload);
      } else {
        _logger.debug(' Unknown source_type: $sourceType for row $id');
      }

      // Mark as processed
      _processedIds.add(id);

      // Limit the size of processed IDs set
      if (_processedIds.length > _maxProcessedIds) {
        // Remove oldest entries (convert to list, take last N, convert back)
        final recentIds =
            _processedIds.toList().skip(_processedIds.length - 500).toSet();
        _processedIds.clear();
        _processedIds.addAll(recentIds);
      }
    } catch (e, st) {
      _logger.debug(' failed to process row $id: $e');
      _logger.debug('$st');
      // keep row for retry
    }
  }

  /// ACTIVE: Auto-conversion method for email inbox items
  /// This method is called when kInboxAutoProcess = true (enabled by default)
  /// For manual conversion workflow, use InboxManagementService.convertInboxItemToNote()
  Future<void> _handleEmailRow(String id, Map<String, dynamic> payload) async {
    try {
      // Extract fields from payload
      final from = (payload['from'] as String?)?.trim() ?? 'Unknown';
      final subject = (payload['subject'] as String?)?.trim() ?? 'Email Note';
      final text = (payload['text'] as String?)?.trim() ?? '';
      final html = payload['html'] as String?;
      final to = (payload['to'] as String?)?.trim();
      final receivedAt = (payload['received_at'] as String?)?.trim() ??
          DateTime.now().toIso8601String();

      // Build note body (plain text + footer)
      final body = StringBuffer();
      if (text.isNotEmpty) {
        body.write(text);
      }
      body.writeln('\n\n---');
      body.writeln('From: $from');
      body.writeln('Received: $receivedAt');

      // Build metadata map for encrypted properties
      final metadata = <String, dynamic>{
        'source': 'email_in',
        'from_email': from,
        'received_at': receivedAt,
        if (to != null) 'to': to,
        if (payload['message_id'] != null) 'message_id': payload['message_id'],
        if (html != null) 'original_html': html,
        if (payload['attachments'] != null)
          'attachments': payload['attachments'],
      };

      // Check if the email has attachments
      final attachmentCount = payload['attachments']?['count'] as int? ?? 0;
      final hasAttachments = attachmentCount > 0;

      // Build tags list - always include 'Email', add 'Attachment' if needed
      final tags = <String>['Email'];
      if (hasAttachments) {
        tags.add('Attachment');
      }

      // Production logging - info level for tracking
      _logger.info('📧 [ClipperInbox/Email] Processing: "$subject" from $from (inbox_id: $id)');
      if (hasAttachments) {
        _logger.info('[ClipperInbox/Email] Has $attachmentCount attachment(s)');
      }

      // Delegate to the same encryption + save path used by Editor V2
      final noteId = await _notesPort.createEncryptedNote(
        title: subject.isEmpty ? 'Email Note' : subject,
        body: body.toString().trimRight(),
        metadataJson: metadata,
        tags: tags,
      );

      _logger.info('✅ [ClipperInbox/Email] Created note: $noteId with tags: ${tags.join(', ')} (from inbox_id: $id)');

      // Add note to Incoming Mail folder
      try {
        await _folderManager.addNoteToIncomingMail(noteId);
      } catch (e) {
        _logger.debug('[email_in] Failed to add note to folder: $e');
        // Continue even if folder assignment fails
      }

      // Logging after success
      _logger.debug('[email_in] processed row=$id -> note=$noteId');

      // Only delete after successful save and folder assignment
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase
            .from('clipper_inbox')
            .delete()
            .eq('user_id', userId) // Strict user scoping
            .eq('id', id);
      }
    } catch (e, st) {
      _logger.debug('[email_in] failed to process row $id: $e');
      _logger.debug('$st');
      // keep row for retry
    }
  }

  /// ACTIVE: Auto-conversion method for web clip inbox items
  /// This method is called when kInboxAutoProcess = true (enabled by default)
  /// For manual conversion workflow, use InboxManagementService.convertInboxItemToNote()
  Future<void> _handleWebRow(String id, Map<String, dynamic> payload) async {
    try {
      // Extract fields from web clip payload
      final title = (payload['title'] as String?)?.trim() ?? 'Web Clip';
      final text = (payload['text'] as String?)?.trim() ?? '';
      final url = (payload['url'] as String?)?.trim() ?? '';
      final html = payload['html'] as String?;
      final clippedAt = (payload['clipped_at'] as String?)?.trim() ??
          DateTime.now().toIso8601String();

      // Build note body with clipped content and source reference
      final body = StringBuffer();
      if (text.isNotEmpty) {
        body.write(text);
      }
      body.writeln('\n\n---');
      body.writeln('Source: $url');
      body.writeln('Clipped: $clippedAt');

      // Build metadata map for encrypted properties
      final metadata = <String, dynamic>{
        'source': 'web',
        'url': url,
        'clipped_at': clippedAt,
        if (title != 'Web Clip') 'title': title,
        if (html != null) 'html': html,
      };

      // Build tags list - include 'Web' tag
      final tags = <String>['Web'];

      // Production logging - info level for tracking
      _logger.info('🌐 [ClipperInbox/Web] Processing: "$title" from $url (inbox_id: $id)');

      // Create encrypted note
      final noteId = await _notesPort.createEncryptedNote(
        title: title,
        body: body.toString().trimRight(),
        metadataJson: metadata,
        tags: tags,
      );

      _logger.info('✅ [ClipperInbox/Web] Created note: $noteId (from inbox_id: $id)');

      // Add note to Incoming Mail folder (serves as unified inbox)
      try {
        await _folderManager.addNoteToIncomingMail(noteId);
      } catch (e) {
        _logger.debug('[web] Failed to add note to folder: $e');
        // Continue even if folder assignment fails
      }

      // Logging after success
      _logger.debug('[web] processed row=$id -> note=$noteId');

      // Only delete after successful save and folder assignment
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase
            .from('clipper_inbox')
            .delete()
            .eq('user_id', userId) // Strict user scoping
            .eq('id', id);
      }
    } catch (e, st) {
      _logger.debug('[web] failed to process row $id: $e');
      _logger.debug('$st');
      // keep row for retry
    }
  }

  // Lifecycle management
  void dispose() {
    stop();
  }

  // Allow external trigger for immediate processing (useful for testing)
  Future<void> processNow() async {
    await processOnce();
  }

  // Status getters
  bool get isRealtimeConnected => _realtimeConnected;
  int get queueLength => _processingQueue.length;
  int get processedCount => _processedIds.length;
}
