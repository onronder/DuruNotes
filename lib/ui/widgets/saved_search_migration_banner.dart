import 'package:flutter/material.dart';
import 'package:duru_notes/services/data_migration/saved_search_migration_service.dart';

/// Banner widget to display SavedSearch migration status to users
///
/// This widget appears at the top of the app when:
/// - Migration is deferred (user needs to log in)
/// - Migration failed (manual intervention needed)
///
/// It provides actionable information and buttons for users to complete migration.
class SavedSearchMigrationBanner extends StatelessWidget {
  final SavedSearchMigrationResult migrationResult;
  final VoidCallback? onLoginPressed;
  final VoidCallback? onDismiss;

  const SavedSearchMigrationBanner({
    super.key,
    required this.migrationResult,
    this.onLoginPressed,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show banner if migration is complete or not needed
    if (migrationResult.isSuccess ||
        migrationResult.isComplete ||
        migrationResult.status == MigrationStatus.notNeeded) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final color = _getColor(theme);
    final icon = _getIcon();
    final title = _getTitle();
    final message = _getMessage();

    return Material(
      color: color.withValues(alpha: 0.1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: color.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (migrationResult.needsUserAction && onLoginPressed != null)
              TextButton(
                onPressed: onLoginPressed,
                child: const Text('Log In'),
              ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: onDismiss,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }

  Color _getColor(ThemeData theme) {
    switch (migrationResult.status) {
      case MigrationStatus.deferred:
        return Colors.orange;
      case MigrationStatus.failed:
        return Colors.red;
      default:
        return theme.colorScheme.primary;
    }
  }

  IconData _getIcon() {
    switch (migrationResult.status) {
      case MigrationStatus.deferred:
        return Icons.login;
      case MigrationStatus.failed:
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }

  String _getTitle() {
    switch (migrationResult.status) {
      case MigrationStatus.deferred:
        return 'Login Required';
      case MigrationStatus.failed:
        return 'Migration Failed';
      default:
        return 'Migration Status';
    }
  }

  String _getMessage() {
    final count = migrationResult.searchesNeedingMigration;

    switch (migrationResult.status) {
      case MigrationStatus.deferred:
        return 'Please log in to access your ${count ?? 0} saved searches';
      case MigrationStatus.failed:
        return migrationResult.message;
      default:
        return migrationResult.message;
    }
  }
}

/// Snackbar helper for showing migration success messages
class SavedSearchMigrationSnackbar {
  static void show(BuildContext context, SavedSearchMigrationResult result) {
    if (!result.isSuccess) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                result.message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
