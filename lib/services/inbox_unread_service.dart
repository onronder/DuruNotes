import 'dart:convert';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Badge display modes for the inbox
enum InboxBadgeMode {
  /// Show count of new items since last inbox open (default)
  newSinceLastOpen,

  /// Show total count of all items in inbox
  total,
}

/// Service to track unread items in the inbox
class InboxUnreadService extends ChangeNotifier {
  InboxUnreadService({required SupabaseClient supabase})
    : _supabase = supabase {
    _loadSettings();
  }
  static const List<String> _defaultSourceTypes = <String>[
    'email_in',
    'web',
    'web_clip',
    'mobile_clip',
    'extension',
    'share_sheet',
    'api',
  ];
  static const String _lastViewedKey = 'inbox_last_viewed_timestamp';
  static const String _unreadCountKey = 'inbox_unread_count';
  static const String _badgeModeKey = 'inbox_badge_mode';
  static const String _readItemsKey = 'inbox_read_item_ids';

  /// Default badge mode (can be made configurable via settings)
  static const InboxBadgeMode kDefaultBadgeMode =
      InboxBadgeMode.newSinceLastOpen;

  final SupabaseClient _supabase;
  final AppLogger _logger = LoggerFactory.instance;
  DateTime? _lastViewedTimestamp;
  int _unreadCount = 0;
  InboxBadgeMode _badgeMode = kDefaultBadgeMode;
  final Set<String> _readItemIds = <String>{};
  bool _disposed = false;

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

      // Load read item IDs
      final readItems = prefs.getStringList(_readItemsKey);
      if (readItems != null) {
        _readItemIds
          ..clear()
          ..addAll(readItems);
      }

      if (!_disposed) {
        notifyListeners();
      }

      // Compute fresh count after loading
      await computeBadgeCount();
    } catch (e) {
      _logger.debug(' Error loading settings: $e');
    }
  }

  /// Mark inbox as viewed (reset badge count in newSinceLastOpen mode)
  Future<void> markInboxViewed() async {
    try {
      _lastViewedTimestamp = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastViewedKey,
        _lastViewedTimestamp!.millisecondsSinceEpoch,
      );

      _logger.debug(
        ' Marked inbox as viewed at $_lastViewedTimestamp (mode: $_badgeMode)',
      );

      await computeBadgeCount();
    } catch (e) {
      _logger.debug(' Error marking inbox as viewed: $e');
    }
  }

  Future<void> markItemViewed(String id) async {
    if (id.isEmpty) return;
    final added = _readItemIds.add(id);
    if (!added) return;
    await _persistReadItems();
    await computeBadgeCount();
  }

  Future<void> markItemsViewed(Iterable<String> ids) async {
    var changed = false;
    for (final id in ids) {
      if (id.isEmpty) continue;
      changed = _readItemIds.add(id) || changed;
    }
    if (!changed) return;
    await _persistReadItems();
    await computeBadgeCount();
  }

  Future<void> _persistReadItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readItemsKey, _readItemIds.toList());
  }

  Map<String, dynamic> _parseMetadata(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        // Ignore invalid JSON payloads
      }
    }
    return const <String, dynamic>{};
  }

  bool _truthy(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  bool _shouldIgnoreMetadata(Map<String, dynamic> metadata) {
    if (metadata.isEmpty) {
      return false;
    }

    if (_truthy(metadata['archived']) || _truthy(metadata['deleted'])) {
      return true;
    }

    if (_truthy(metadata['processed']) || _truthy(metadata['dismissed'])) {
      return true;
    }

    final status = (metadata['status'] as String?)?.toLowerCase();
    if (status == 'archived' || status == 'deleted' || status == 'dismissed') {
      return true;
    }

    return false;
  }

  /// Compute badge count based on current mode
  Future<void> computeBadgeCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _unreadCount = 0;
        _readItemIds.clear();
        if (!_disposed) {
          notifyListeners();
        }
        return;
      }

      // Build query - strictly scoped to user and unprocessed items only
      final sourceFilter = _defaultSourceTypes
          .map((source) => 'source_type.eq.$source')
          .join(',');

      var query = _supabase
          .from('clipper_inbox')
          .select('id,created_at,metadata')
          .eq('user_id', userId) // Strict user scoping
          .filter('converted_to_note_id', 'is', 'null')
          .or(sourceFilter);

      final response = await query;
      final rows = (response as List)
          .cast<Map<String, dynamic>>()
          .where((row) => row['id'] != null)
          .toList();

      final idsInResponse = <String>{};
      final candidateIds = <String>[];

      for (final row in rows) {
        final id = row['id'] as String;
        idsInResponse.add(id);

        final metadata = _parseMetadata(row['metadata']);
        if (_shouldIgnoreMetadata(metadata)) {
          _logger.debug(
            'Skipping inbox item due to metadata flags',
            data: {'id': id, 'metadata': metadata},
          );
          continue;
        }

        if (_badgeMode == InboxBadgeMode.newSinceLastOpen &&
            _lastViewedTimestamp != null) {
          final createdAtStr = row['created_at'] as String?;
          final createdAt = createdAtStr != null
              ? DateTime.tryParse(createdAtStr)
              : null;
          if (createdAt == null || !createdAt.isAfter(_lastViewedTimestamp!)) {
            continue;
          }
        }

        candidateIds.add(id);
      }

      final beforeSize = _readItemIds.length;
      _readItemIds.removeWhere((id) => !idsInResponse.contains(id));
      if (_readItemIds.length != beforeSize) {
        await _persistReadItems();
      }

      final unreadIds = candidateIds
          .where((id) => !_readItemIds.contains(id))
          .toList();
      final count = unreadIds.length;

      if (_unreadCount != count) {
        _unreadCount = count;

        // Save to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_unreadCountKey, _unreadCount);

        if (!_disposed) {
          notifyListeners();
        }
        _logger.debug(
          ' Badge count updated: $_unreadCount (mode: $_badgeMode)',
        );
      }
    } catch (e) {
      _logger.debug(' Error computing badge count: $e');
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
      _logger.debug(' Cannot clear: service is disposed');
      return;
    }

    try {
      _lastViewedTimestamp = null;
      _unreadCount = 0;
      _readItemIds.clear();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastViewedKey);
      await prefs.remove(_unreadCountKey);
      await prefs.remove(_readItemsKey);

      if (!_disposed) {
        notifyListeners();
      }
    } catch (e) {
      _logger.debug(' Error clearing data: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
