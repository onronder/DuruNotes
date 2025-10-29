import 'package:flutter/material.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Service for notifying users about sync and encryption errors
///
/// Provides non-intrusive notifications for:
/// - Decryption failures
/// - Sync conflicts
/// - Connection issues
/// - Data validation errors
class SyncErrorNotificationService {
  static final SyncErrorNotificationService _instance = SyncErrorNotificationService._internal();
  factory SyncErrorNotificationService() => _instance;
  SyncErrorNotificationService._internal();

  final _logger = LoggerFactory.instance;

  // Error tracking
  final List<SyncError> _errors = [];
  final int _maxErrorsTracked = 50;

  /// Notify about decryption failures
  void notifyDecryptionFailure({
    required String noteId,
    required String field,
    String? error,
    BuildContext? context,
  }) {
    _addError(SyncError(
      type: SyncErrorType.decryption,
      message: 'Failed to decrypt $field for note',
      details: error,
      noteId: noteId,
      timestamp: DateTime.now(),
    ));

    _logger.error('Decryption failure for note $noteId field $field: $error');

    // Show snackbar if context available
    if (context != null && context.mounted) {
      _showSnackBar(
        context,
        'Some content could not be decrypted',
        action: SnackBarAction(
          label: 'Details',
          onPressed: () => _showErrorDetails(context, _errors.last),
        ),
      );
    }
  }

  /// Notify about sync conflicts
  void notifySyncConflict({
    required String entityType,
    required String entityId,
    required String resolution,
    BuildContext? context,
  }) {
    _addError(SyncError(
      type: SyncErrorType.conflict,
      message: 'Sync conflict in $entityType',
      details: 'Resolved using: $resolution',
      noteId: entityId,
      timestamp: DateTime.now(),
    ));

    _logger.warning('Sync conflict for $entityType $entityId - resolved: $resolution');

    if (context != null && context.mounted) {
      _showSnackBar(
        context,
        'Sync conflict resolved ($resolution)',
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// Notify about connection issues
  void notifyConnectionError({
    required String operation,
    String? error,
    BuildContext? context,
  }) {
    _addError(SyncError(
      type: SyncErrorType.connection,
      message: 'Connection failed during $operation',
      details: error,
      timestamp: DateTime.now(),
    ));

    _logger.error('Connection error during $operation: $error');

    if (context != null && context.mounted) {
      _showSnackBar(
        context,
        'Connection failed - will retry automatically',
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Notify about validation errors
  void notifyValidationError({
    required String field,
    required String message,
    BuildContext? context,
  }) {
    _addError(SyncError(
      type: SyncErrorType.validation,
      message: 'Validation failed for $field',
      details: message,
      timestamp: DateTime.now(),
    ));

    _logger.warning('Validation error for $field: $message');

    if (context != null && context.mounted) {
      _showSnackBar(
        context,
        'Data validation failed: $message',
        isError: true,
      );
    }
  }

  /// Notify about multiple failures
  void notifyBatchErrors({
    required int count,
    required SyncErrorType type,
    BuildContext? context,
  }) {
    _logger.error('Batch error: $count ${type.name} failures');

    if (context != null && context.mounted) {
      _showSnackBar(
        context,
        '$count items failed to sync',
        isError: true,
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _showAllErrors(context),
        ),
      );
    }
  }

  /// Get all tracked errors
  List<SyncError> get errors => List.unmodifiable(_errors);

  /// Get errors of specific type
  List<SyncError> getErrorsByType(SyncErrorType type) {
    return _errors.where((e) => e.type == type).toList();
  }

  /// Clear all errors
  void clearErrors() {
    _errors.clear();
    _logger.debug('Cleared all sync errors');
  }

  /// Clear errors older than duration
  void clearOldErrors(Duration age) {
    final cutoff = DateTime.now().subtract(age);
    _errors.removeWhere((e) => e.timestamp.isBefore(cutoff));
  }

  // Internal methods
  void _addError(SyncError error) {
    _errors.add(error);

    // Limit number of tracked errors
    if (_errors.length > _maxErrorsTracked) {
      _errors.removeAt(0);
    }
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    bool isError = false,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : null,
        action: action,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorDetails(BuildContext context, SyncError error) {
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${error.type.name.toUpperCase()} Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error.message,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (error.details != null) ...[
              const Text('Details:', style: TextStyle(fontSize: 12)),
              Text(
                error.details!,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Time: ${error.timestamp.toLocal()}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAllErrors(BuildContext context) {
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Errors'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _errors.length,
            itemBuilder: (context, index) {
              final error = _errors[index];
              return ListTile(
                leading: Icon(_getIconForType(error.type)),
                title: Text(error.message),
                subtitle: Text(error.timestamp.toLocal().toString()),
                onTap: () {
                  Navigator.of(context).pop();
                  _showErrorDetails(context, error);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              clearErrors();
              Navigator.of(context).pop();
            },
            child: const Text('Clear All'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(SyncErrorType type) {
    switch (type) {
      case SyncErrorType.decryption:
        return Icons.lock_outline;
      case SyncErrorType.conflict:
        return Icons.sync_problem;
      case SyncErrorType.connection:
        return Icons.cloud_off;
      case SyncErrorType.validation:
        return Icons.error_outline;
    }
  }
}

/// Types of sync errors
enum SyncErrorType {
  decryption,
  conflict,
  connection,
  validation,
}

/// Represents a sync error
class SyncError {
  const SyncError({
    required this.type,
    required this.message,
    required this.timestamp,
    this.details,
    this.noteId,
  });

  final SyncErrorType type;
  final String message;
  final String? details;
  final String? noteId;
  final DateTime timestamp;

  @override
  String toString() => '[$type] $message ${details != null ? "($details)" : ""} @ $timestamp';
}
