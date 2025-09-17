import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/create_folder_dialog.dart';
import 'package:duru_notes/features/folders/folder_icon_helpers.dart';
import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FolderHierarchyWidget extends ConsumerStatefulWidget {
  const FolderHierarchyWidget({
    super.key,
    this.onFolderSelected,
    this.selectedFolderId,
    this.showSearchBar = true,
    this.showActions = true,
    this.maxHeight,
  });

  final Function(LocalFolder folder)? onFolderSelected;
  final String? selectedFolderId;
  final bool showSearchBar;
  final bool showActions;
  final double? maxHeight;

  @override
  ConsumerState<FolderHierarchyWidget> createState() =>
      _FolderHierarchyWidgetState();
}

class _FolderHierarchyWidgetState extends ConsumerState<FolderHierarchyWidget> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hierarchyState = ref.watch(folderHierarchyProvider);
    final visibleNodes = ref.watch(visibleFolderNodesProvider);
    final folderOperationState = ref.watch(folderProvider);

    return Container(
      constraints: widget.maxHeight != null
          ? BoxConstraints(maxHeight: widget.maxHeight!)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showSearchBar) _buildSearchBar(theme),
          if (widget.showActions) _buildActionBar(theme),

          Expanded(
            child: hierarchyState.isLoading && visibleNodes.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : hierarchyState.error != null
                ? _buildErrorState(theme, hierarchyState.error!)
                : visibleNodes.isEmpty
                ? _buildEmptyState(theme)
                : _buildHierarchyList(theme, visibleNodes),
          ),

          if (folderOperationState.isLoading) _buildLoadingIndicator(theme),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SearchBar(
        controller: _searchController,
        hintText: 'Search folders...',
        leading: const Icon(Icons.search),
        trailing: _searchController.text.isNotEmpty
            ? [
                IconButton(
                  onPressed: () {
                    _searchController.clear();
                    ref.read(folderHierarchyProvider.notifier).clearSearch();
                  },
                  icon: const Icon(Icons.clear),
                ),
              ]
            : null,
        onChanged: (query) {
          ref.read(folderHierarchyProvider.notifier).updateSearchQuery(query);
        },
      ),
    );
  }

  Widget _buildActionBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Folders',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              ref.read(folderHierarchyProvider.notifier).expandAll();
            },
            icon: const Icon(Icons.unfold_more),
            tooltip: 'Expand All',
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            onPressed: () {
              ref.read(folderHierarchyProvider.notifier).collapseAll();
            },
            icon: const Icon(Icons.unfold_less),
            tooltip: 'Collapse All',
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            onPressed: _showCreateFolderDialog,
            icon: const Icon(Icons.create_new_folder),
            tooltip: 'Create Folder',
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error loading folders',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ref.read(folderHierarchyProvider.notifier).loadFolders();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No folders yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first folder to organize your notes',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _showCreateFolderDialog,
              icon: const Icon(Icons.create_new_folder),
              label: const Text('Create Folder'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchyList(
    ThemeData theme,
    List<FolderTreeNode> visibleNodes,
  ) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: visibleNodes.length,
      itemBuilder: (context, index) {
        final node = visibleNodes[index];
        return _buildFolderItem(theme, node);
      },
    );
  }

  Widget _buildFolderItem(ThemeData theme, FolderTreeNode node) {
    final isSelected = widget.selectedFolderId == node.folder.id;
    final indentWidth = node.level * 24.0;

    return InkWell(
      onTap: () => widget.onFolderSelected?.call(node.folder),
      onLongPress: () => _showFolderContextMenu(node.folder),
      child: Container(
        padding: EdgeInsets.only(
          left: 16 + indentWidth,
          right: 16,
          top: 8,
          bottom: 8,
        ),
        decoration: isSelected
            ? BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Row(
          children: [
            // Expansion toggle
            if (node.hasChildren)
              IconButton(
                onPressed: () {
                  ref
                      .read(folderHierarchyProvider.notifier)
                      .toggleExpansion(node.folder.id);
                },
                icon: Icon(
                  node.isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(24, 24),
                ),
              )
            else
              const SizedBox(width: 24),

            // Folder icon
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: Icon(
                FolderIconHelpers.getFolderIcon(node.folder.icon),
                color:
                    FolderIconHelpers.getFolderColor(node.folder.color) ??
                    (isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant),
                size: 20,
              ),
            ),

            // Folder name
            Expanded(
              child: Text(
                node.folder.name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Note count
            if (node.noteCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  node.noteCount.toString(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            // More actions button
            IconButton(
              onPressed: () => _showFolderContextMenu(node.folder),
              icon: const Icon(Icons.more_vert, size: 18),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(24, 24),
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(ThemeData theme) {
    return const SizedBox(height: 4, child: LinearProgressIndicator());
  }

  void _showCreateFolderDialog([String? parentId]) async {
    final result = await showDialog<LocalFolder>(
      context: context,
      builder: (context) => CreateFolderDialog(parentId: parentId),
    );
    
    if (result != null && mounted) {
      // Refresh folder hierarchy
      ref.read(folderHierarchyProvider.notifier).refresh();
    }
  }

  void _showFolderContextMenu(LocalFolder folder) {
    showModalBottomSheet(
      context: context,
      builder: (context) => FolderContextMenu(folder: folder),
    );
  }
}

class FolderContextMenu extends ConsumerWidget {
  const FolderContextMenu({required this.folder, super.key});

  final LocalFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  FolderIconHelpers.getFolderIcon(folder.icon),
                  color:
                      FolderIconHelpers.getFolderColor(folder.color) ??
                      theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    folder.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Actions
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('Create Subfolder'),
            onTap: () {
              Navigator.of(context).pop();
              _showCreateSubfolderDialog(context, ref, folder.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit Folder'),
            onTap: () {
              Navigator.of(context).pop();
              _showEditFolderDialog(context, ref, folder);
            },
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_move_outlined),
            title: const Text('Move Folder'),
            onTap: () {
              Navigator.of(context).pop();
              _showMoveFolderDialog(context, ref, folder);
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(
              'Delete Folder',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () {
              Navigator.of(context).pop();
              _showDeleteConfirmDialog(context, ref, folder);
            },
          ),
        ],
      ),
    );
  }

  void _showCreateSubfolderDialog(
    BuildContext context,
    WidgetRef ref,
    String parentId,
  ) {
    showDialog(
      context: context,
      builder: (context) => CreateFolderDialog(parentId: parentId),
    );
  }

  void _showEditFolderDialog(
    BuildContext context,
    WidgetRef ref,
    LocalFolder folder,
  ) {
    // TODO: Implement edit folder dialog
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Edit folder coming soon')));
  }

  void _showMoveFolderDialog(
    BuildContext context,
    WidgetRef ref,
    LocalFolder folder,
  ) {
    // TODO: Implement move folder dialog
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Move folder coming soon')));
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    LocalFolder folder,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
          'Are you sure you want to delete "${folder.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await ref
                  .read(folderProvider.notifier)
                  .deleteFolder(folder.id);
              if (success) {
                ref
                    .read(folderHierarchyProvider.notifier)
                    .removeFolder(folder.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Folder "${folder.name}" deleted'),
                      behavior: SnackBarBehavior.fixed,
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete folder'),
                      behavior: SnackBarBehavior.fixed,
                    ),
                  );
                }
              }
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
