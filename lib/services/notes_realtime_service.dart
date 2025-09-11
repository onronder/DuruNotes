import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duru_notes/providers.dart';

/// Events emitted by the notes realtime service
enum NotesRealtimeEvent {
  noteInserted,
  noteUpdated,
  noteDeleted,
  folderChanged,
  listChanged,
}

/// Realtime service for notes and folders updates
/// Provides instant updates for main notes list
class NotesRealtimeService extends ChangeNotifier {
  final SupabaseClient _supabase;
  final Ref _ref;
  RealtimeChannel? _channel;
  bool _isSubscribed = false;
  
  // Event deduplication
  final Set<String> _processedEventIds = {};
  static const int _maxProcessedIds = 100;
  
  // Debounce timer for provider invalidation
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 500);
  
  // Stream controller for list refresh events
  final _listRefreshController = StreamController<NotesRealtimeEvent>.broadcast();
  Stream<NotesRealtimeEvent> get listRefreshStream => _listRefreshController.stream;
  
  // Exponential backoff for reconnection
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const List<int> _backoffDelays = [1, 2, 4, 8, 16, 30]; // Exponential backoff
  
  NotesRealtimeService({
    required SupabaseClient supabase,
    required Ref ref,
  }) : _supabase = supabase, _ref = ref;
  
  bool get isSubscribed => _isSubscribed;
  
  /// Start realtime subscription for notes changes
  Future<void> start() async {
    await stop(); // Clean up any existing subscription
    
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[NotesRealtime] Cannot start: no authenticated user');
      return;
    }
    
    debugPrint('[NotesRealtime] Starting realtime subscription for user: $userId');
    
    try {
      // Create channel for notes and note_folders changes
      _channel = _supabase
          .channel('notes_realtime_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all, // INSERT, UPDATE, DELETE
            schema: 'public',
            table: 'notes',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: _handleNotesChange,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all, // INSERT, UPDATE, DELETE
            schema: 'public',
            table: 'note_folders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: _handleFolderChange,
          );
      
      // Subscribe to the channel
      _channel!.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _isSubscribed = true;
          _reconnectAttempts = 0; // Reset on successful connection
          _cancelReconnectTimer();
          notifyListeners();
          debugPrint('[NotesRealtime] Subscription active');
        } else if (status == RealtimeSubscribeStatus.closed || 
                   status == RealtimeSubscribeStatus.channelError) {
          _isSubscribed = false;
          notifyListeners();
          debugPrint('[NotesRealtime] Subscription lost: $status, error: $error');
          
          // Schedule reconnect with exponential backoff
          _scheduleReconnect();
        }
      });
    } catch (e) {
      debugPrint('[NotesRealtime] Failed to setup subscription: $e');
      _isSubscribed = false;
      notifyListeners();
    }
  }
  
  /// Stop realtime subscription
  Future<void> stop() async {
    _cancelReconnectTimer();
    _cancelDebounceTimer();
    if (_channel != null) {
      await _channel!.unsubscribe();
      _channel = null;
    }
    _isSubscribed = false;
    _processedEventIds.clear();
    _reconnectAttempts = 0;
    notifyListeners();
    debugPrint('[NotesRealtime] Subscription stopped');
  }
  
  /// Handle notes table changes
  void _handleNotesChange(PostgresChangePayload payload) {
    try {
      final eventType = payload.eventType;
      final record = eventType == PostgresChangeEvent.delete 
          ? payload.oldRecord 
          : payload.newRecord;
      final id = record['id'] as String?;
      
      if (id == null) {
        debugPrint('[NotesRealtime] Change missing ID');
        return;
      }
      
      // Create unique event key for deduplication
      final eventKey = '${eventType.name}_$id';
      
      // Deduplicate events
      if (_processedEventIds.contains(eventKey)) {
        debugPrint('[NotesRealtime] Duplicate event: $eventKey');
        return;
      }
      
      _processedEventIds.add(eventKey);
      _pruneProcessedIds();
      
      debugPrint('[NotesRealtime] Note ${eventType.name}: $id');
      
      // Emit specific event type
      NotesRealtimeEvent event;
      switch (eventType) {
        case PostgresChangeEvent.insert:
          event = NotesRealtimeEvent.noteInserted;
          break;
        case PostgresChangeEvent.update:
          event = NotesRealtimeEvent.noteUpdated;
          break;
        case PostgresChangeEvent.delete:
          event = NotesRealtimeEvent.noteDeleted;
          break;
        default:
          event = NotesRealtimeEvent.listChanged;
      }
      
      _listRefreshController.add(event);
      _listRefreshController.add(NotesRealtimeEvent.listChanged);
      
      // Debounce provider invalidation
      _scheduleProviderInvalidation();
      
      // Notify listeners
      notifyListeners();
    } catch (e) {
      debugPrint('[NotesRealtime] Error handling notes change: $e');
    }
  }
  
  /// Handle note_folders table changes
  void _handleFolderChange(PostgresChangePayload payload) {
    try {
      final eventType = payload.eventType;
      final record = eventType == PostgresChangeEvent.delete 
          ? payload.oldRecord 
          : payload.newRecord;
      final noteId = record['note_id'] as String?;
      
      if (noteId == null) {
        debugPrint('[NotesRealtime] Folder change missing note_id');
        return;
      }
      
      // Create unique event key for deduplication
      final eventKey = 'folder_${eventType.name}_$noteId';
      
      // Deduplicate events
      if (_processedEventIds.contains(eventKey)) {
        debugPrint('[NotesRealtime] Duplicate folder event: $eventKey');
        return;
      }
      
      _processedEventIds.add(eventKey);
      _pruneProcessedIds();
      
      debugPrint('[NotesRealtime] Folder ${eventType.name} for note: $noteId');
      
      // Emit folder changed event
      _listRefreshController.add(NotesRealtimeEvent.folderChanged);
      _listRefreshController.add(NotesRealtimeEvent.listChanged);
      
      // Debounce provider invalidation
      _scheduleProviderInvalidation();
      
      // Notify listeners
      notifyListeners();
    } catch (e) {
      debugPrint('[NotesRealtime] Error handling folder change: $e');
    }
  }
  
  /// Schedule provider invalidation with debouncing
  void _scheduleProviderInvalidation() {
    _cancelDebounceTimer();
    
    _debounceTimer = Timer(_debounceDuration, () {
      try {
        // Invalidate notes providers to trigger refresh
        debugPrint('[NotesRealtime] Invalidating notes providers');
        
        // Invalidate the filtered notes provider to refresh the list
        _ref.invalidate(filteredNotesProvider);
        
        // Also refresh the notes page
        _ref.read(notesPageProvider.notifier).refresh();
      } catch (e) {
        debugPrint('[NotesRealtime] Error invalidating providers: $e');
      }
    });
  }
  
  /// Cancel debounce timer
  void _cancelDebounceTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
  
  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) {
      return; // Already scheduled
    }
    
    final delayIndex = _reconnectAttempts < _backoffDelays.length 
        ? _reconnectAttempts 
        : _backoffDelays.length - 1;
    final delaySeconds = _backoffDelays[delayIndex];
    
    debugPrint('[NotesRealtime] Scheduling reconnect in ${delaySeconds}s (attempt ${_reconnectAttempts + 1})');
    
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isSubscribed && _supabase.auth.currentUser != null) {
        _reconnectAttempts++;
        debugPrint('[NotesRealtime] Attempting to reconnect...');
        start();
      }
    });
  }
  
  /// Cancel any pending reconnect timer
  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
  
  /// Prune processed IDs to prevent memory growth
  void _pruneProcessedIds() {
    if (_processedEventIds.length > _maxProcessedIds) {
      // Keep only the most recent IDs
      final toKeep = _processedEventIds.toList()
          .skip(_processedEventIds.length - (_maxProcessedIds ~/ 2))
          .toSet();
      _processedEventIds.clear();
      _processedEventIds.addAll(toKeep);
    }
  }
  
  @override
  void dispose() {
    stop();
    _cancelReconnectTimer();
    _cancelDebounceTimer();
    _listRefreshController.close();
    super.dispose();
  }
}
