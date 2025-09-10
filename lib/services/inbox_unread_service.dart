import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to track unread items in the inbox
class InboxUnreadService extends ChangeNotifier {
  static const String _lastViewedKey = 'inbox_last_viewed_timestamp';
  static const String _unreadCountKey = 'inbox_unread_count';
  
  final SupabaseClient _supabase;
  DateTime? _lastViewedTimestamp;
  int _unreadCount = 0;
  
  InboxUnreadService({required SupabaseClient supabase}) : _supabase = supabase {
    _loadLastViewed();
  }
  
  int get unreadCount => _unreadCount;
  DateTime? get lastViewedTimestamp => _lastViewedTimestamp;
  
  /// Load last viewed timestamp from local storage
  Future<void> _loadLastViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastViewedKey);
      if (timestamp != null) {
        _lastViewedTimestamp = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      _unreadCount = prefs.getInt(_unreadCountKey) ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint('[InboxUnread] Error loading last viewed: $e');
    }
  }
  
  /// Mark inbox as viewed (reset unread count)
  Future<void> markAsViewed() async {
    try {
      _lastViewedTimestamp = DateTime.now();
      _unreadCount = 0;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastViewedKey, _lastViewedTimestamp!.millisecondsSinceEpoch);
      await prefs.setInt(_unreadCountKey, 0);
      
      notifyListeners();
      debugPrint('[InboxUnread] Marked as viewed at $_lastViewedTimestamp');
    } catch (e) {
      debugPrint('[InboxUnread] Error marking as viewed: $e');
    }
  }
  
  /// Update unread count based on clipper_inbox items
  Future<void> updateUnreadCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _unreadCount = 0;
        notifyListeners();
        return;
      }
      
      // Get count of items newer than last viewed
      var query = _supabase
          .from('clipper_inbox')
          .select('id')
          .or('source_type.eq.email_in,source_type.eq.web');
      
      // Add timestamp filter if we have a last viewed timestamp
      if (_lastViewedTimestamp != null) {
        query = query.gt('created_at', _lastViewedTimestamp!.toIso8601String());
      }
      
      final response = await query;
      final count = (response as List).length;
      
      if (_unreadCount != count) {
        _unreadCount = count;
        
        // Save to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_unreadCountKey, _unreadCount);
        
        notifyListeners();
        debugPrint('[InboxUnread] Updated unread count: $_unreadCount');
      }
    } catch (e) {
      debugPrint('[InboxUnread] Error updating unread count: $e');
    }
  }
  
  /// Clear all stored data (useful on logout)
  Future<void> clear() async {
    try {
      _lastViewedTimestamp = null;
      _unreadCount = 0;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastViewedKey);
      await prefs.remove(_unreadCountKey);
      
      notifyListeners();
    } catch (e) {
      debugPrint('[InboxUnread] Error clearing data: $e');
    }
  }
}
