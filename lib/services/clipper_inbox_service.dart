import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duru_notes/services/incoming_mail_folder_manager.dart';
import 'package:duru_notes/services/inbox_unread_service.dart';

/// Port interface for creating encrypted notes
abstract class NotesCapturePort {
  Future<String> createEncryptedNote({
    required String title,
    required String body,
    required Map<String, dynamic> metadataJson,
    List<String> tags,
  });
}

/// Service for monitoring the clipper_inbox table
/// 
/// IMPORTANT: Auto-processing is DISABLED by default (kInboxAutoProcess = false)
/// - Items remain in clipper_inbox until user manually converts them via the Inbox UI
/// - Service only provides realtime notifications for badge updates
/// - Manual conversion is handled by InboxManagementService
/// 
/// When kInboxAutoProcess = false (default):
/// - No automatic conversion of inbox items to notes
/// - Only realtime notifications for unread count updates
/// - Items persist until user action
/// 
/// When kInboxAutoProcess = true (legacy mode):
/// - Auto-converts inbox items to notes immediately
/// - Deletes items after conversion
/// - Used for backward compatibility only
class ClipperInboxService {
  ClipperInboxService({
    required SupabaseClient supabase, 
    required NotesCapturePort notesPort,
    required IncomingMailFolderManager folderManager,
    InboxUnreadService? unreadService,
  }) : _supabase = supabase,
       _notesPort = notesPort,
       _folderManager = folderManager,
       _unreadService = unreadService;  // Note: unreadService is no longer used here
  
  final SupabaseClient _supabase;
  final NotesCapturePort _notesPort;
  final IncomingMailFolderManager _folderManager;
  final InboxUnreadService? _unreadService;  // Deprecated - no longer used
  
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
  
  // Feature flag to control auto-processing (disabled by default)
  static const bool kInboxAutoProcess = false;

  void start() {
    // Auto-processing is disabled - inbox items must be manually converted by user
    if (!kInboxAutoProcess) {
      debugPrint('[clipper] Auto-processing disabled - items will remain in inbox for user review');
      // Realtime is now handled by InboxRealtimeService
      return;
    }
    
    // Legacy auto-processing code (disabled by default)
    stop();
    _startRealtimeSubscription();
    _startPolling();
    // Initial poll
    unawaited(processOnce());
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
    final interval = _realtimeConnected ? _realtimePollingInterval : _normalPollingInterval;
    _timer = Timer.periodic(interval, (_) => unawaited(processOnce()));
    debugPrint('[clipper] Polling started with interval: ${interval.inSeconds}s');
  }
  
  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }
  
  void _startRealtimeSubscription() {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('[clipper] Cannot start realtime: no authenticated user');
        return;
      }
      
      // Create channel for clipper_inbox inserts
      _realtimeChannel = _supabase
          .channel('clipper_inbox_changes')
          .onPostgresChanges(
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
          debugPrint('[clipper] Realtime subscription active');
          _realtimeConnected = true;
          // Restart polling with longer interval
          _startPolling();
        } else if (status == RealtimeSubscribeStatus.closed || 
                   status == RealtimeSubscribeStatus.channelError) {
          debugPrint('[clipper] Realtime subscription lost: $status, error: $error');
          _realtimeConnected = false;
          // Restart polling with normal interval
          _startPolling();
        }
      });
      
      debugPrint('[clipper] Realtime subscription initiated for user: $userId');
    } catch (e) {
      debugPrint('[clipper] Failed to setup realtime subscription: $e');
      _realtimeConnected = false;
    }
  }
  
  void _stopRealtimeSubscription() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _realtimeConnected = false;
    debugPrint('[clipper] Realtime subscription stopped');
  }
  
  void _handleRealtimeInsert(PostgresChangePayload payload) {
    try {
      final newRow = payload.newRecord;
      final id = newRow['id'] as String?;
      
      if (id == null) {
        debugPrint('[clipper] Realtime insert missing ID');
        return;
      }
      
      // Check if already processed
      if (_processedIds.contains(id)) {
        debugPrint('[clipper] Skipping duplicate realtime event for ID: $id');
        return;
      }
      
      debugPrint('[clipper] Realtime insert detected: $id');
      
      // Add to processing queue
      _processingQueue.add(newRow);
      
      // Process the queue
      unawaited(_processQueue());
    } catch (e) {
      debugPrint('[clipper] Error handling realtime insert: $e');
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
        debugPrint('[clipper] No authenticated user for processOnce');
        return;
      }
      
      // Fetch both email and web entries - strictly scoped to user
      final rows = await _supabase
          .from('clipper_inbox')
          .select()
          .eq('user_id', userId)  // Strict user scoping
          .or('source_type.eq.email_in,source_type.eq.web')
          .order('created_at', ascending: true);

      for (final row in rows) {
        await _handleRow(row);
      }
    } catch (e, st) {
      debugPrint('clipper inbox processing error: $e');
      debugPrint('$st');
    }
  }

  Future<void> _handleRow(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    
    // Skip if already processed
    if (_processedIds.contains(id)) {
      debugPrint('[clipper] Skipping already processed ID: $id');
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
        debugPrint('[clipper] Unknown source_type: $sourceType for row $id');
      }
      
      // Mark as processed
      _processedIds.add(id);
      
      // Limit the size of processed IDs set
      if (_processedIds.length > _maxProcessedIds) {
        // Remove oldest entries (convert to list, take last N, convert back)
        final recentIds = _processedIds.toList().skip(_processedIds.length - 500).toSet();
        _processedIds.clear();
        _processedIds.addAll(recentIds);
      }
    } catch (e, st) {
      debugPrint('[clipper] failed to process row $id: $e');
      debugPrint('$st');
      // keep row for retry
    }
  }

  /// LEGACY: Auto-conversion method - DO NOT USE
  /// All conversions should go through InboxManagementService.convertInboxItemToNote()
  /// This method is only called when kInboxAutoProcess = true (disabled by default)
  @Deprecated('Use InboxManagementService.convertInboxItemToNote instead')
  Future<void> _handleEmailRow(String id, Map<String, dynamic> payload) async {
    try {
      // Extract fields from payload
      final from = (payload['from'] as String?)?.trim() ?? 'Unknown';
      final subject = (payload['subject'] as String?)?.trim() ?? 'Email Note';
      final text = (payload['text'] as String?)?.trim() ?? '';
      final html = (payload['html'] as String?);
      final to = (payload['to'] as String?)?.trim();
      final receivedAt = (payload['received_at'] as String?)?.trim() 
          ?? DateTime.now().toIso8601String();

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
        if (payload['attachments'] != null) 'attachments': payload['attachments'],
      };

      // Check if the email has attachments
      final attachmentCount = payload['attachments']?['count'] as int? ?? 0;
      final hasAttachments = attachmentCount > 0;
      
      // Build tags list - always include 'Email', add 'Attachment' if needed
      final tags = <String>['Email'];
      if (hasAttachments) {
        tags.add('Attachment');
      }
      
      // Logging before processing
      debugPrint('[email_in] processing row=$id subject="$subject" from="$from"');
      debugPrint('[email_in] metadata keys: ${metadata.keys.join(', ')}');
      debugPrint('[email_in] attachments: $hasAttachments, tags: ${tags.join(', ')}');

      // Delegate to the same encryption + save path used by Editor V2
      final noteId = await _notesPort.createEncryptedNote(
        title: subject.isEmpty ? 'Email Note' : subject,
        body: body.toString().trimRight(),
        metadataJson: metadata,
        tags: tags,
      );

      // Add note to Incoming Mail folder
      try {
        await _folderManager.addNoteToIncomingMail(noteId);
      } catch (e) {
        debugPrint('[email_in] Failed to add note to folder: $e');
        // Continue even if folder assignment fails
      }

      // Logging after success
      debugPrint('[email_in] processed row=$id -> note=$noteId');

      // Only delete after successful save and folder assignment
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.from('clipper_inbox')
            .delete()
            .eq('user_id', userId)  // Strict user scoping
            .eq('id', id);
      }
    } catch (e, st) {
      debugPrint('[email_in] failed to process row $id: $e');
      debugPrint('$st');
      // keep row for retry
    }
  }

  /// LEGACY: Auto-conversion method - DO NOT USE
  /// All conversions should go through InboxManagementService.convertInboxItemToNote()
  /// This method is only called when kInboxAutoProcess = true (disabled by default)
  @Deprecated('Use InboxManagementService.convertInboxItemToNote instead')
  Future<void> _handleWebRow(String id, Map<String, dynamic> payload) async {
    try {
      // Extract fields from web clip payload
      final title = (payload['title'] as String?)?.trim() ?? 'Web Clip';
      final text = (payload['text'] as String?)?.trim() ?? '';
      final url = (payload['url'] as String?)?.trim() ?? '';
      final html = (payload['html'] as String?);
      final clippedAt = (payload['clipped_at'] as String?)?.trim() 
          ?? DateTime.now().toIso8601String();

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
      
      // Logging before processing
      debugPrint('[web] processing row=$id title="$title" url="$url"');
      debugPrint('[web] metadata keys: ${metadata.keys.join(', ')}');
      debugPrint('[web] tags: ${tags.join(', ')}');

      // Create encrypted note
      final noteId = await _notesPort.createEncryptedNote(
        title: title,
        body: body.toString().trimRight(),
        metadataJson: metadata,
        tags: tags,
      );

      // Add note to Incoming Mail folder (serves as unified inbox)
      try {
        await _folderManager.addNoteToIncomingMail(noteId);
      } catch (e) {
        debugPrint('[web] Failed to add note to folder: $e');
        // Continue even if folder assignment fails
      }

      // Logging after success
      debugPrint('[web] processed row=$id -> note=$noteId');

      // Only delete after successful save and folder assignment
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.from('clipper_inbox')
            .delete()
            .eq('user_id', userId)  // Strict user scoping
            .eq('id', id);
      }
    } catch (e, st) {
      debugPrint('[web] failed to process row $id: $e');
      debugPrint('$st');
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
