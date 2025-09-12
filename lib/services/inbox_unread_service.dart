import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Badge display modes for the inbox
enum InboxBadgeMode { 
  /// Show count of new items since last inbox open (default)
  newSinceLastOpen,
  /// Show total count of all items in inbox
  total 
}

/// Service to track unread items in the inbox
class InboxUnreadService extends ChangeNotifier {
  static const String _lastViewedKey = 'inbox_last_viewed_timestamp';
  static const String _unreadCountKey = 'inbox_unread_count';
  static const String _badgeModeKey = 'inbox_badge_mode';
  
  /// Default badge mode (can be made configurable via settings)
  static const InboxBadgeMode kDefaultBadgeMode = InboxBadgeMode.newSinceLastOpen;
  
  final SupabaseClient _supabase;
  DateTime? _lastViewedTimestamp;
  int _unreadCount = 0;
  InboxBadgeMode _badgeMode = kDefaultBadgeMode;
  bool _disposed = false;
  
  InboxUnreadService({required SupabaseClient supabase}) : _supabase = supabase {
    _loadSettings();
  }
  
  int get unreadCount => _unreadCount;
  DateTime? get lastViewedTimestamp => _lastViewedTimestamp;
  InboxBadgeMode get badgeMode => _badgeMode;
  
  /// Update badge mode and recompute count
  Future<void> setBadgeMode(InboxBadgeMode mode) async {
    if (_badgeMode == mode) return;
    
    _badgeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_badgeModeKey, mode.index);
    
    // Recompute badge with new mode
    await computeBadgeCount();
  }
  
  /// Load settings from local storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load last viewed timestamp
      final timestamp = prefs.getInt(_lastViewedKey);
      if (timestamp != null) {
        _lastViewedTimestamp = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      
      // Load badge mode
      final modeIndex = prefs.getInt(_badgeModeKey);
      if (modeIndex != null && modeIndex < InboxBadgeMode.values.length) {
        _badgeMode = InboxBadgeMode.values[modeIndex];
      }
      
      // Load cached count
      _unreadCount = prefs.getInt(_unreadCountKey) ?? 0;
      
      if (!_disposed) {
        notifyListeners();
      }
      
      // Compute fresh count after loading
      await computeBadgeCount();
    } catch (e) {
      debugPrint('[InboxUnread] Error loading settings: $e');
    }
  }
  
  /// Mark inbox as viewed (reset badge count in newSinceLastOpen mode)
  Future<void> markInboxViewed() async {
    try {
      _lastViewedTimestamp = DateTime.now();
      
      // In newSinceLastOpen mode, reset the count immediately
      if (_badgeMode == InboxBadgeMode.newSinceLastOpen) {
        _unreadCount = 0;
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastViewedKey, _lastViewedTimestamp!.millisecondsSinceEpoch);
      
      // Only reset stored count in newSinceLastOpen mode
      if (_badgeMode == InboxBadgeMode.newSinceLastOpen) {
        await prefs.setInt(_unreadCountKey, 0);
      }
      
      if (!_disposed) {
        notifyListeners();
      }
      debugPrint('[InboxUnread] Marked inbox as viewed at $_lastViewedTimestamp (mode: $_badgeMode)');
      
      // In total mode, recompute to get current total
      if (_badgeMode == InboxBadgeMode.total) {
        await computeBadgeCount();
      }
    } catch (e) {
      debugPrint('[InboxUnread] Error marking inbox as viewed: $e');
    }
  }
  
  /// Compute badge count based on current mode
  Future<void> computeBadgeCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _unreadCount = 0;
        if (!_disposed) {
        notifyListeners();
      }
        return;
      }
      
      // Build query - strictly scoped to user
      var query = _supabase
          .from('clipper_inbox')
          .select('id')
          .eq('user_id', userId)  // Strict user scoping
          .or('source_type.eq.email_in,source_type.eq.web');
      
      // Apply mode-specific filtering
      if (_badgeMode == InboxBadgeMode.newSinceLastOpen && _lastViewedTimestamp != null) {
        // Only count items newer than last viewed
        query = query.gt('created_at', _lastViewedTimestamp!.toIso8601String());
      }
      // For total mode, no additional filtering needed
      
      final response = await query;
      final count = (response as List).length;
      
      if (_unreadCount != count) {
        _unreadCount = count;
        
        // Save to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_unreadCountKey, _unreadCount);
        
        if (!_disposed) {
        notifyListeners();
      }
        debugPrint('[InboxUnread] Badge count updated: $_unreadCount (mode: $_badgeMode)');
      }
    } catch (e) {
      debugPrint('[InboxUnread] Error computing badge count: $e');
    }
  }
  
  /// Legacy method - forwards to computeBadgeCount
  @Deprecated('Use computeBadgeCount instead')
  Future<void> updateUnreadCount() async {
    await computeBadgeCount();
  }
  
  /// Legacy method - forwards to markInboxViewed
  @Deprecated('Use markInboxViewed instead')
  Future<void> markAsViewed() async {
    await markInboxViewed();
  }
  
  /// Clear all stored data (useful on logout)
  Future<void> clear() async {
    if (_disposed) {
      debugPrint('[InboxUnread] Cannot clear: service is disposed');
      return;
    }
    
    try {
      _lastViewedTimestamp = null;
      _unreadCount = 0;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastViewedKey);
      await prefs.remove(_unreadCountKey);
      
      if (!_disposed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[InboxUnread] Error clearing data: $e');
    }
  }
  
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
