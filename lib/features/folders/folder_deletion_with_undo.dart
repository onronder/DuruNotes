import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderCoreRepositoryProvider;
import 'package:duru_notes/l10n/app_localizations.dart';
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart'
    show folderProvider, folderHierarchyProvider;
import 'package:duru_notes/services/folder_undo_service.dart'
    show
        FolderUndoType,
        FolderUndoOperation,
        folderUndoServiceProvider,
        folderUndoHistoryProvider;
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Mixin for folder management screens to handle deletion with undo support
mixin FolderDeletionWithUndo {
  // Logger instance
  final AppLogger _folderDeletionLogger = LoggerFactory.instance;

  /// Show confirmation dialog and delete folder with undo support
  Future<bool> confirmAndDeleteFolder(
    BuildContext context,
    WidgetRef ref,
    domain.Folder folder, {
    VoidCallback? onDeleted,
    VoidCallback? onUndone,
  }) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDeleteFolder),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.confirmDeleteFolderMessage),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder, color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folder.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.error,
                          ),
                        ),
                        if (folder.parentId != null &&
                            folder.parentId!.isNotEmpty)
                          Text(
                            'Subfolder',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          )
                        else
                          Text(
                            'Root folder',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can undo this action within 5 minutes',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: Text(l10n.confirmDeleteFolderAction),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false)) {
      _folderDeletionLogger.info(
        'Folder deletion cancelled by user',
        data: {'folderId': folder.id, 'folderName': folder.name},
      );
      return false;
    }

    // Log deletion attempt
    _folderDeletionLogger.info(
      'Starting folder deletion',
      data: {
        'folderId': folder.id,
        'folderName': folder.name,
        'parentId': folder.parentId,
      },
    );

    // Track in Sentry
    await Sentry.addBreadcrumb(
      Breadcrumb(
        message: 'Folder deletion started',
        category: 'folder.delete',
        data: {'folderId': folder.id, 'folderName': folder.name},
      ),
    );

    // Gather data for undo operation before deletion
    final folderRepo = ref.read(folderCoreRepositoryProvider);
    final undoService = ref.read(folderUndoServiceProvider);
    // final analytics = ref.read(analyticsProvider); // Not currently used

    try {
      // Get affected notes and child folders before deletion
      final affectedNotes = await folderRepo.getNoteIdsInFolder(folder.id);
      final affectedChildFolders = await folderRepo.getChildFoldersRecursive(
        folder.id,
      );

      _folderDeletionLogger.debug(
        'Folder deletion metadata',
        data: {
          'affectedNotes': affectedNotes.length,
          'childFolders': affectedChildFolders.length,
        },
      );

      // Perform the deletion
      final success = await ref
          .read(folderProvider.notifier)
          .deleteFolder(folder.id);

      if (!success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete folder: ${ref.read(folderProvider).error}',
              ),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
        return false;
      }

      // Add to undo history
      final operationId = await undoService.addDeleteOperation(
        folder: folder,
        affectedNotes: affectedNotes,
        affectedChildFolders: affectedChildFolders,
      );

      // Call onDeleted callback
      onDeleted?.call();

      // Show success snackbar with undo option
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted folder "${folder.name}"'),
            backgroundColor: DuruColors.accent,
            duration: const Duration(seconds: 8), // Longer duration for undo
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () async {
                await _performUndo(context, ref, operationId, onUndone);
              },
            ),
          ),
        );
      }

      return true;
    } catch (e, stackTrace) {
      _folderDeletionLogger.error(
        'Failed to delete folder',
        error: e,
        stackTrace: stackTrace,
        data: {'folderId': folder.id, 'folderName': folder.name},
      );

      await Sentry.captureException(
        e,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.setTag('operation', 'folder_deletion');
          scope.setContexts('folder', {
            'id': folder.id,
            'name': folder.name,
            'parentId': folder.parentId,
          });
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting folder: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
      return false;
    }
  }

  /// Perform undo operation
  Future<void> _performUndo(
    BuildContext context,
    WidgetRef ref,
    String operationId,
    VoidCallback? onUndone,
  ) async {
    final undoService = ref.read(folderUndoServiceProvider);

    _folderDeletionLogger.info(
      'Starting undo operation',
      data: {'operationId': operationId},
    );

    try {
      final success = await undoService.undoOperation(operationId);

      if (success) {
        _folderDeletionLogger.info(
          'Undo operation succeeded',
          data: {'operationId': operationId},
        );
        // Refresh folder providers
        ref.read(folderProvider.notifier).refresh();
        ref.read(folderHierarchyProvider.notifier).refresh();

        // Call onUndone callback
        onUndone?.call();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Folder deletion undone'),
              backgroundColor: DuruColors.primary,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        _folderDeletionLogger.warning(
          'Undo operation failed',
          data: {'operationId': operationId},
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to undo deletion'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      _folderDeletionLogger.error(
        'Undo operation failed with exception',
        error: e,
        stackTrace: stackTrace,
        data: {'operationId': operationId},
      );

      await Sentry.captureException(
        e,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.setTag('operation', 'folder_undo');
          scope.setContexts('undo', {'operationId': operationId});
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Undo failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Show undo history dialog
  Future<void> showUndoHistory(BuildContext context, WidgetRef ref) async {
    final undoService = ref.read(folderUndoServiceProvider);
    final history = undoService.currentHistory;

    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No recent folder operations to undo'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recent Folder Operations'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: history.length,
            itemBuilder: (context, index) {
              final operation = history[index];
              final timeAgo = _getTimeAgo(operation.timestamp);

              return ListTile(
                leading: Icon(_getOperationIcon(operation.type)),
                title: Text(operation.description),
                subtitle: Text('$timeAgo ago'),
                trailing: TextButton(
                  onPressed: operation.isExpired
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          await _performUndo(context, ref, operation.id, null);
                        },
                  child: Text(operation.isExpired ? 'Expired' : 'Undo'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              undoService.clearHistory();
              Navigator.of(context).pop();
            },
            child: const Text('Clear History'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getOperationIcon(FolderUndoType type) {
    switch (type) {
      case FolderUndoType.delete:
        return Icons.delete_outline;
      case FolderUndoType.move:
        return Icons.drive_file_move_outline;
      case FolderUndoType.rename:
        return Icons.edit_outlined;
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'}';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'}';
    } else {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
    }
  }
}

/// Widget to display undo history as a floating action button
class UndoHistoryFAB extends ConsumerWidget {
  const UndoHistoryFAB({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsyncValue = ref.watch(folderUndoHistoryProvider);

    return historyAsyncValue.when(
      data: (history) {
        final hasOperations = history.isNotEmpty;

        if (!hasOperations) return const SizedBox.shrink();

        return FloatingActionButton(
          mini: true,
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          onPressed: () => _showUndoHistory(context, ref, history),
          tooltip: 'Recent Operations',
          child: Badge(
            label: Text(history.length.toString()),
            child: const Icon(Icons.undo),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _showUndoHistory(
    BuildContext context,
    WidgetRef ref,
    List<FolderUndoOperation> history,
  ) async {
    final undoService = ref.read(folderUndoServiceProvider);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recent Operations'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: history.length,
            itemBuilder: (context, index) {
              final operation = history[index];
              final timeAgo = DateTime.now().difference(operation.timestamp);

              return ListTile(
                leading: Icon(_getOperationIcon(operation.type)),
                title: Text(operation.description),
                subtitle: Text('${timeAgo.inMinutes}m ago'),
                trailing: TextButton(
                  onPressed: operation.isExpired
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          final success = await undoService.undoOperation(
                            operation.id,
                          );
                          if (success && context.mounted) {
                            ref.read(folderProvider.notifier).refresh();
                            ref
                                .read(folderHierarchyProvider.notifier)
                                .refresh();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Operation undone')),
                            );
                          }
                        },
                  child: Text(operation.isExpired ? 'Expired' : 'Undo'),
                ),
              );
            },
          ),
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

  IconData _getOperationIcon(FolderUndoType type) {
    switch (type) {
      case FolderUndoType.delete:
        return Icons.delete_outline;
      case FolderUndoType.move:
        return Icons.drive_file_move_outline;
      case FolderUndoType.rename:
        return Icons.edit_outlined;
    }
  }
}
