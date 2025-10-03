import 'package:duru_notes/services/data_encryption_migration_service.dart';
import 'package:duru_notes/services/providers/migration_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dialog for migrating plaintext data to encrypted format
///
/// Features:
/// - Real-time progress tracking
/// - Dry-run preview mode
/// - Automatic backup creation
/// - Detailed result reporting
class DataMigrationDialog extends ConsumerStatefulWidget {
  const DataMigrationDialog({super.key});

  @override
  ConsumerState<DataMigrationDialog> createState() => _DataMigrationDialogState();
}

class _DataMigrationDialogState extends ConsumerState<DataMigrationDialog> {
  bool _isRunning = false;
  bool _isDryRun = true;
  MigrationProgress? _progress;
  MigrationResult? _result;
  String? _error;

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
      _progress = null;
      _result = null;
      _error = null;
      _isDryRun = dryRun;
    });

    try {
      final migrationService = ref.read(dataEncryptionMigrationServiceProvider);

      final result = await migrationService.executeMigration(
        userId: user.id,
        dryRun: dryRun,
        skipBackup: false,
        skipValidation: false,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _result = result;
          _isRunning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
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
          const Expanded(
            child: Text('Encrypt Your Data'),
          ),
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

              if (_isRunning) ...[
                _buildProgressSection(theme),
              ],

              if (_result != null) ...[
                _buildResultSection(theme),
              ],

              if (_error != null) ...[
                _buildErrorSection(theme),
              ],
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
          description: 'All plaintext data will be encrypted using XChaCha20-Poly1305',
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
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                description,
                style: const TextStyle(fontSize: 12),
              ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
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
    if (_progress == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phase: ${_progress!.phase}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // Progress bar
        LinearProgressIndicator(
          value: _progress!.progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),

        // Progress text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_progress!.processed} / ${_progress!.total}',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              '${_progress!.percentComplete}%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        if (_progress!.estimatedTimeRemaining != null) ...[
          const SizedBox(height: 8),
          Text(
            'ETA: ${_formatDuration(_progress!.estimatedTimeRemaining!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Stats
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatChip(
              icon: Icons.check_circle_outline,
              label: 'Success',
              value: '${_progress!.successCount}',
              color: Colors.green,
            ),
            _buildStatChip(
              icon: Icons.error_outline,
              label: 'Failed',
              value: '${_progress!.failureCount}',
              color: Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultSection(ThemeData theme) {
    final result = _result!;
    final isSuccess = result.isSuccess;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status header
        Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isSuccess
                    ? (_isDryRun ? 'Preview Complete ✓' : 'Migration Complete ✓')
                    : 'Migration Failed',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

        // Statistics
        if (result.notesResult != null) ...[
          _buildResultItem(
            'Notes',
            result.notesResult!.successCount,
            result.notesResult!.totalCount,
            result.notesResult!.successRate,
          ),
          const SizedBox(height: 8),
        ],

        if (result.tasksResult != null) ...[
          _buildResultItem(
            'Tasks',
            result.tasksResult!.successCount,
            result.tasksResult!.totalCount,
            result.tasksResult!.successRate,
          ),
          const SizedBox(height: 8),
        ],

        if (result.ftsResult != null) ...[
          const Divider(),
          const SizedBox(height: 8),
          _buildResultItem(
            'Search Index',
            result.ftsResult!.notesReindexed,
            result.ftsResult!.notesReindexed + result.ftsResult!.notesFailed,
            result.ftsResult!.notesFailed == 0 ? 1.0 : 0.8,
          ),
        ],

        const SizedBox(height: 16),

        // Duration
        Text(
          'Duration: ${_formatDuration(result.duration)}',
          style: theme.textTheme.bodySmall?.copyWith(
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

  Widget _buildResultItem(String label, int success, int total, double rate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Text(
          '$success / $total (${(rate * 100).toStringAsFixed(1)}%)',
          style: TextStyle(
            color: rate >= 0.9 ? Colors.green : Colors.orange,
            fontWeight: FontWeight.w600,
          ),
        ),
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
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
