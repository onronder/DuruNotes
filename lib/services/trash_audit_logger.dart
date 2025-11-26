import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Describes the type of item being logged for trash analytics.
enum TrashAuditItemType { note, folder, task }

/// Supported trash actions for compliance logging.
enum TrashAuditAction { softDelete, restore, permanentDelete }

/// Helper responsible for writing trash audit events to Supabase via
/// the `log_trash_event` function defined in the migration.
class TrashAuditLogger {
  TrashAuditLogger({required SupabaseClient client, AppLogger? logger})
    : _client = client,
      _logger = logger ?? LoggerFactory.instance;

  final SupabaseClient _client;
  final AppLogger _logger;

  /// Log a soft delete (move to trash) event.
  Future<void> logSoftDelete({
    required TrashAuditItemType itemType,
    required String itemId,
    String? itemTitle,
    DateTime? scheduledPurgeAt,
    Map<String, dynamic>? metadata,
  }) {
    return _logEvent(
      action: TrashAuditAction.softDelete,
      itemType: itemType,
      itemId: itemId,
      itemTitle: itemTitle,
      scheduledPurgeAt: scheduledPurgeAt,
      metadata: metadata,
    );
  }

  /// Log a restore event.
  Future<void> logRestore({
    required TrashAuditItemType itemType,
    required String itemId,
    String? itemTitle,
    Map<String, dynamic>? metadata,
  }) {
    return _logEvent(
      action: TrashAuditAction.restore,
      itemType: itemType,
      itemId: itemId,
      itemTitle: itemTitle,
      metadata: metadata,
    );
  }

  /// Log a permanent delete event.
  Future<void> logPermanentDelete({
    required TrashAuditItemType itemType,
    required String itemId,
    String? itemTitle,
    Map<String, dynamic>? metadata,
  }) {
    return _logEvent(
      action: TrashAuditAction.permanentDelete,
      itemType: itemType,
      itemId: itemId,
      itemTitle: itemTitle,
      metadata: metadata,
    );
  }

  Future<void> _logEvent({
    required TrashAuditAction action,
    required TrashAuditItemType itemType,
    required String itemId,
    String? itemTitle,
    DateTime? scheduledPurgeAt,
    Map<String, dynamic>? metadata,
  }) async {
    // Best-effort logging; never block user actions.
    try {
      await _client.rpc<dynamic>(
        'log_trash_event',
        params: {
          'p_item_type': _mapItemType(itemType),
          'p_item_id': itemId,
          'p_item_title': _normalizeTitle(itemTitle),
          'p_action': _mapAction(action),
          if (scheduledPurgeAt != null)
            'p_scheduled_purge_at': scheduledPurgeAt.toUtc().toIso8601String(),
          if (metadata != null && metadata.isNotEmpty) 'p_metadata': metadata,
        },
      );
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to log trash event',
        data: {
          'action': _mapAction(action),
          'itemType': _mapItemType(itemType),
          'itemId': itemId,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  String _mapItemType(TrashAuditItemType type) {
    switch (type) {
      case TrashAuditItemType.note:
        return 'note';
      case TrashAuditItemType.folder:
        return 'folder';
      case TrashAuditItemType.task:
        return 'task';
    }
  }

  String _mapAction(TrashAuditAction action) {
    switch (action) {
      case TrashAuditAction.softDelete:
        return 'soft_delete';
      case TrashAuditAction.restore:
        return 'restore';
      case TrashAuditAction.permanentDelete:
        return 'permanent_delete';
    }
  }

  String _normalizeTitle(String? rawTitle) {
    final trimmed = rawTitle?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Untitled';
    }
    if (trimmed.length > 200) {
      return '${trimmed.substring(0, 197)}...';
    }
    return trimmed;
  }
}
