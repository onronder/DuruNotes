import 'dart:async';

import 'package:duru_notes/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to handle realtime updates for folders
class FolderRealtimeService {
  FolderRealtimeService({
    required this.supabase,
    required this.ref,
  });

  final SupabaseClient supabase;
  final Ref ref;
  
  RealtimeChannel? _subscription;
  Timer? _debounceTimer;
  
  /// Start listening for folder changes
  Future<void> start() async {
    // Clean up any existing subscription
    await stop();
    
    final user = supabase.auth.currentUser;
    if (user == null) {
      debugPrint('[FolderRealtime] No authenticated user, skipping start');
      return;
    }
    
    try {
      debugPrint('[FolderRealtime] Starting realtime subscription for user ${user.id}');
      
      // Subscribe to folder changes for the current user
      _subscription = supabase
          .channel('realtime:folders:${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all, // INSERT, UPDATE, DELETE
            schema: 'public',
            table: 'folders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user.id,
            ),
            callback: (payload) => _onFolderChanged(payload),
          )
          .subscribe();
          
      debugPrint('[FolderRealtime] Subscription created successfully');
    } catch (e) {
      debugPrint('[FolderRealtime] Error starting subscription: $e');
    }
  }
  
  /// Handle folder change events with debouncing
  void _onFolderChanged(PostgresChangePayload payload) {
    debugPrint('[FolderRealtime] Folder change detected: ${payload.eventType}');
    
    // Cancel any existing debounce timer
    _debounceTimer?.cancel();
    
    // Debounce folder refresh (300ms to coalesce rapid changes)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        debugPrint('[FolderRealtime] Refreshing folders after change');
        
        // Refresh folder hierarchy (updates tree used by picker)
        // This also triggers rootFoldersProvider rebuild automatically
        await ref.read(folderHierarchyProvider.notifier).loadFolders();
        
        debugPrint('[FolderRealtime] Folder refresh completed');
      } catch (e) {
        debugPrint('[FolderRealtime] Error refreshing folders: $e');
      }
    });
  }
  
  /// Stop listening for folder changes
  Future<void> stop() async {
    debugPrint('[FolderRealtime] Stopping realtime subscription');
    
    _debounceTimer?.cancel();
    _debounceTimer = null;
    
    if (_subscription != null) {
      await supabase.removeChannel(_subscription!);
      _subscription = null;
    }
    
    debugPrint('[FolderRealtime] Realtime subscription stopped');
  }
  
  /// Dispose of resources
  void dispose() {
    stop();
  }
}
