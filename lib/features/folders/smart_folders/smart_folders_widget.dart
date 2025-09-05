import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_db.dart';
import 'smart_folder_creator.dart';
import 'smart_folder_engine.dart';
import 'smart_folder_provider.dart';
import 'smart_folder_types.dart';

class SmartFoldersWidget extends ConsumerWidget {
  const SmartFoldersWidget({
    super.key,
    this.onFolderTap,
    this.onNoteTap,
    this.showExpandedView = false,
  });

  final Function(SmartFolderConfig folder)? onFolderTap;
  final Function(LocalNote note)? onNoteTap;
  final bool showExpandedView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smartFoldersState = ref.watch(smartFoldersProvider);
    final enabled = ref.watch(smartFoldersEnabledProvider);

    if (!enabled) {
      return const SizedBox.shrink();
    }

    if (smartFoldersState.isLoading && smartFoldersState.folders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (smartFoldersState.error != null) {
      return _buildErrorWidget(context, ref, smartFoldersState.error!);
    }

    if (smartFoldersState.folders.isEmpty) {
      return _buildEmptyWidget(context, ref);
    }

    return showExpandedView
        ? _buildExpandedView(context, ref, smartFoldersState)
        : _buildCompactView(context, ref, smartFoldersState);
  }

  Widget _buildErrorWidget(BuildContext context, WidgetRef ref, String error) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Smart Folders Error',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ref.read(smartFoldersProvider.notifier).clearError();
                ref.read(smartFoldersProvider.notifier).refreshAllFolders();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Smart Folders',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Automatically organize your notes with intelligent filters',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _showCreateSmartFolder(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Create Smart Folder'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactView(
    BuildContext context,
    WidgetRef ref,
    SmartFoldersState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome),
              const SizedBox(width: 8),
              Text(
                'Smart Folders',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _showCreateSmartFolder(context, ref),
                icon: const Icon(Icons.add),
                tooltip: 'Create Smart Folder',
              ),
            ],
          ),
        ),
        
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.folders.length,
            itemBuilder: (context, index) {
              final folder = state.folders[index];
              final notes = state.folderContents[folder.id] ?? [];
              final stats = state.folderStats[folder.id];
              
              return _SmartFolderCard(
                folder: folder,
                noteCount: notes.length,
                stats: stats,
                onTap: () => onFolderTap?.call(folder),
                onLongPress: () => _showFolderActions(context, ref, folder),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedView(
    BuildContext context,
    WidgetRef ref,
    SmartFoldersState state,
  ) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome),
              const SizedBox(width: 8),
              Text(
                'Smart Folders',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => ref.read(smartFoldersProvider.notifier).refreshAllFolders(),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showCreateSmartFolder(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
            ],
          ),
        ),
        
        // Loading indicator
        if (state.isLoading)
          const LinearProgressIndicator(),
        
        // Folder list
        Expanded(
          child: ListView.builder(
            itemCount: state.folders.length,
            itemBuilder: (context, index) {
              final folder = state.folders[index];
              final notes = state.folderContents[folder.id] ?? [];
              final stats = state.folderStats[folder.id];
              
              return _SmartFolderTile(
                folder: folder,
                notes: notes,
                stats: stats,
                onTap: () => onFolderTap?.call(folder),
                onLongPress: () => _showFolderActions(context, ref, folder),
                onNoteTap: onNoteTap,
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCreateSmartFolder(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SmartFolderCreator(),
      ),
    ).then((config) {
      if (config != null && config is SmartFolderConfig) {
        ref.read(smartFoldersProvider.notifier).saveSmartFolder(config);
      }
    });
  }

  void _showFolderActions(
    BuildContext context,
    WidgetRef ref,
    SmartFolderConfig folder,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _SmartFolderActionsSheet(
        folder: folder,
        onEdit: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SmartFolderCreator(initialConfig: folder),
            ),
          ).then((config) {
            if (config != null && config is SmartFolderConfig) {
              ref.read(smartFoldersProvider.notifier).saveSmartFolder(config);
            }
          });
        },
        onDuplicate: () {
          _showDuplicateDialog(context, ref, folder);
        },
        onExport: () {
          final exported = ref.read(smartFoldersProvider.notifier).exportSmartFolder(folder.id);
          // TODO: Show share sheet or copy to clipboard
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export feature coming soon!')),
          );
        },
        onDelete: () {
          _showDeleteDialog(context, ref, folder);
        },
      ),
    );
  }

  void _showDuplicateDialog(
    BuildContext context,
    WidgetRef ref,
    SmartFolderConfig folder,
  ) {
    final controller = TextEditingController(text: '${folder.name} Copy');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Smart Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New folder name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(smartFoldersProvider.notifier)
                  .duplicateSmartFolder(folder.id, controller.text.trim());
            },
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    SmartFolderConfig folder,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Smart Folder'),
        content: Text('Are you sure you want to delete "${folder.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(smartFoldersProvider.notifier).deleteSmartFolder(folder.id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SmartFolderCard extends StatelessWidget {
  const _SmartFolderCard({
    required this.folder,
    required this.noteCount,
    this.stats,
    this.onTap,
    this.onLongPress,
  });

  final SmartFolderConfig folder;
  final int noteCount;
  final SmartFolderStats? stats;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = folder.customColor ?? folder.type.color;
    final icon = folder.customIcon ?? folder.type.icon;

    return Card(
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withOpacity(0.2),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const Spacer(),
                  if (stats?.lastRefresh != null)
                    Icon(
                      Icons.refresh,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Text(
                folder.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const Spacer(),
              
              Row(
                children: [
                  Text(
                    '$noteCount notes',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (stats != null && stats!.totalNotes > 0)
                    Text(
                      '${stats!.matchPercentage.toStringAsFixed(0)}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmartFolderTile extends StatelessWidget {
  const _SmartFolderTile({
    required this.folder,
    required this.notes,
    this.stats,
    this.onTap,
    this.onLongPress,
    this.onNoteTap,
  });

  final SmartFolderConfig folder;
  final List<LocalNote> notes;
  final SmartFolderStats? stats;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Function(LocalNote note)? onNoteTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = folder.customColor ?? folder.type.color;
    final icon = folder.customIcon ?? folder.type.icon;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color.withOpacity(0.2),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folder.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${notes.length} notes • ${folder.rules.length} rules',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (stats != null && stats!.totalNotes > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${stats!.matchPercentage.toStringAsFixed(0)}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              // Recent notes preview
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...notes.take(3).map((note) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: InkWell(
                      onTap: () => onNoteTap?.call(note),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.note,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                note.title.isEmpty ? 'Untitled' : note.title,
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatDate(note.updatedAt),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
                
                if (notes.length > 3) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'View ${notes.length - 3} more notes...',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return 'Now';
    }
  }
}

class _SmartFolderActionsSheet extends StatelessWidget {
  const _SmartFolderActionsSheet({
    required this.folder,
    this.onEdit,
    this.onDuplicate,
    this.onExport,
    this.onDelete,
  });

  final SmartFolderConfig folder;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = folder.customColor ?? folder.type.color;
    final icon = folder.customIcon ?? folder.type.icon;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withOpacity(0.2),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      folder.type.displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Actions
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit'),
            onTap: () {
              Navigator.of(context).pop();
              onEdit?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Duplicate'),
            onTap: () {
              Navigator.of(context).pop();
              onDuplicate?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Export'),
            onTap: () {
              Navigator.of(context).pop();
              onExport?.call();
            },
          ),
          ListTile(
            leading: Icon(Icons.delete, color: theme.colorScheme.error),
            title: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
            onTap: () {
              Navigator.of(context).pop();
              onDelete?.call();
            },
          ),
        ],
      ),
    );
  }
}