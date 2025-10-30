// DEPRECATED: Migration service and providers have been removed
// This dialog is kept for reference only. Encryption migration is now
// handled automatically during app bootstrap.
import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/services/data_encryption_migration_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Dialog for migrating plaintext data to encrypted format
///
/// DEPRECATED: This dialog is no longer used in the app flow.
/// Encryption migration is now handled automatically via database schema
/// during app bootstrap. All data is encrypted by default for new users,
/// and existing data is migrated seamlessly when the app detects plaintext.
///
/// Legacy Features (for reference):
/// - Real-time progress tracking
/// - Dry-run preview mode
/// - Automatic backup creation
/// - Detailed result reporting
class DataMigrationDialog extends ConsumerStatefulWidget {
  const DataMigrationDialog({super.key});

  @override
  ConsumerState<DataMigrationDialog> createState() =>
      _DataMigrationDialogState();
}

class _DataMigrationDialogState extends ConsumerState<DataMigrationDialog> {
  bool _isRunning = false;
  bool _isDryRun = true;
  MigrationResult? _result;
  String? _error;
  AppLogger get _logger => ref.read(loggerProvider);

  Future<void> _runMigration({required bool dryRun}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _error = 'No user logged in';
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _result = null;
      _error = null;
      _isDryRun = dryRun;
    });

    try {
      // DEPRECATED: DataEncryptionMigrationService and its provider have been removed
      // Encryption migration is now handled automatically via database schema
      // during app bootstrap. This dialog is kept for reference only.
      //
      // Migration is now handled by:
      // - Database schema (encryption_status column)
      // - AppBootstrap encryption initialization
      // - Automatic detection and migration on first launch

      _logger.warning(
        'Attempted to run deprecated data migration dialog',
        data: {'dryRun': dryRun},
      );

      if (mounted) {
        setState(() {
          _error =
              'Migration service is deprecated. Encryption is now handled automatically during app startup.';
          _isRunning = false;
        });
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Unexpected error while running deprecated migration dialog',
        error: error,
        stackTrace: stackTrace,
        data: {'dryRun': dryRun},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        setState(() {
          _error =
              'We could not process the migration request. Please try again later.';
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock, color: colorScheme.primary),
          const SizedBox(width: 12),
          const Expanded(child: Text('Encrypt Your Data')),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_result == null && !_isRunning) ...[
                _buildInfoSection(theme),
                const SizedBox(height: 24),
                _buildDryRunToggle(theme),
              ],

              if (_isRunning) ...[_buildProgressSection(theme)],

              if (_result != null) ...[_buildResultSection(theme)],

              if (_error != null) ...[_buildErrorSection(theme)],
            ],
          ),
        ),
      ),
      actions: [
        if (!_isRunning) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (_result == null)
            FilledButton.icon(
              onPressed: () => _runMigration(dryRun: _isDryRun),
              icon: Icon(_isDryRun ? Icons.preview : Icons.rocket_launch),
              label: Text(_isDryRun ? 'Preview' : 'Start Migration'),
            ),
          if (_result != null && _result!.isSuccess && _isDryRun)
            FilledButton.icon(
              onPressed: () => _runMigration(dryRun: false),
              icon: const Icon(Icons.rocket_launch),
              label: const Text('Run for Real'),
            ),
        ],
        if (_isRunning)
          TextButton(
            onPressed: null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Migrating...'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This will migrate your existing notes and tasks to encrypted format.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _buildInfoItem(
          icon: Icons.shield_outlined,
          title: 'What happens:',
          description:
              'All plaintext data will be encrypted using XChaCha20-Poly1305',
          color: Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildInfoItem(
          icon: Icons.backup_outlined,
          title: 'Safety:',
          description: 'Automatic backup created before migration',
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        _buildInfoItem(
          icon: Icons.speed_outlined,
          title: 'Duration:',
          description: 'Usually takes 10-60 seconds depending on data size',
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
              Text(description, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDryRunToggle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isDryRun ? Icons.preview : Icons.warning,
            color: _isDryRun ? Colors.blue : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isDryRun ? 'Preview Mode' : 'Production Mode',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  _isDryRun
                      ? 'Safe preview - no actual changes'
                      : 'Will modify your data',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: !_isDryRun,
            onChanged: (value) {
              setState(() {
                _isDryRun = !value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(ThemeData theme) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildResultSection(ThemeData theme) {
    final result = _result!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status header
        Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Migration Already Complete ✓',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Message
        if (result.message != null)
          Text(
            result.message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

        // Dry run notice
        if (_isDryRun) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This was a preview. No actual changes were made.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Error',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Text(_error!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
