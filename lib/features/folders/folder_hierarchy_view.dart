import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/create_folder_dialog.dart';
import 'package:duru_notes/features/folders/edit_folder_dialog.dart';
import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/features/folders/folder_icon_helpers.dart';

/// Material 3 expandable folder hierarchy with drag & drop support
class FolderHierarchyView extends ConsumerStatefulWidget {
  const FolderHierarchyView({
    super.key,
    this.onFolderTap,
    this.onFolderLongPress,
    this.selectedFolderId,
    this.showActions = true,
    this.showSearch = true,
    this.padding = const EdgeInsets.all(16),
  });

  final ValueChanged<LocalFolder>? onFolderTap;
  final ValueChanged<LocalFolder>? onFolderLongPress;
  final String? selectedFolderId;
  final bool showActions;
  final bool showSearch;
  final EdgeInsets padding;

  @override
  ConsumerState<FolderHierarchyView> createState() => _FolderHierarchyViewState();
}

class _FolderHierarchyViewState extends ConsumerState<FolderHierarchyView>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _fadeController;
  late AnimationController _expansionController;
  
  String _searchQuery = '';
  bool _showSearch = false;
  String? _draggedFolderId;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expansionController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _fadeController.forward();
    
    // Load folder hierarchy
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(folderHierarchyProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _fadeController.dispose();
    _expansionController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
    });
    
    if (_showSearch) {
      _searchFocusNode.requestFocus();
      _expansionController.forward();
    } else {
      _searchController.clear();
      _searchQuery = '';
      _searchFocusNode.unfocus();
      _expansionController.reverse();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  bool _matchesSearch(LocalFolder folder) {
    if (_searchQuery.isEmpty) return true;
    return folder.name.toLowerCase().contains(_searchQuery) ||
           folder.path.toLowerCase().contains(_searchQuery) ||
           (folder.description.toLowerCase().contains(_searchQuery) ?? false);
  }

  List<FolderTreeNode> _filterNodes(List<FolderTreeNode> nodes) {
    if (_searchQuery.isEmpty) return nodes;
    
    final filtered = <FolderTreeNode>[];
    for (final node in nodes) {
      final childrenFiltered = _filterNodes(node.children);
      final nodeMatches = _matchesSearch(node.folder);
      
      if (nodeMatches || childrenFiltered.isNotEmpty) {
        filtered.add(node.copyWith(
          children: childrenFiltered,
          isExpanded: _searchQuery.isNotEmpty, // Auto-expand when searching
        ));
      }
    }
    return filtered;
  }

  Future<void> _showCreateFolderDialog([LocalFolder? parent]) async {
    final result = await showDialog<LocalFolder>(
      context: context,
      builder: (context) => CreateFolderDialog(parentFolder: parent),
    );
    
    if (result != null && mounted) {
      ref.read(folderHierarchyProvider.notifier).refresh();
      ref.read(folderProvider.notifier).refresh();
    }
  }

  Future<void> _showEditFolderDialog(LocalFolder folder) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditFolderDialog(folder: folder),
    );
    
    if (result ?? false && mounted) {
      ref.read(folderHierarchyProvider.notifier).refresh();
      ref.read(folderProvider.notifier).refresh();
    }
  }

  Future<void> _showFolderActions(LocalFolder folder) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _FolderActionsSheet(folder: folder),
    );
    
    switch (result) {
      case 'edit':
        await _showEditFolderDialog(folder);
      case 'create_subfolder':
        await _showCreateFolderDialog(folder);
      case 'delete':
        await _confirmDeleteFolder(folder);
    }
  }

  Future<void> _confirmDeleteFolder(LocalFolder folder) async {
    final l10n = AppLocalizations.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDeleteFolder),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.confirmDeleteFolderMessage),
            const SizedBox(height: 8),
            Text(
              '"${folder.name}"',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
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
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.confirmDeleteFolderAction),
          ),
        ],
      ),
    );
    
    if (confirmed ?? false && mounted) {
      final success = await ref.read(folderProvider.notifier).deleteFolder(folder.id);
      if (success) {
        ref.read(folderHierarchyProvider.notifier).refresh();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete folder: ${ref.read(folderProvider).error}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    
    return FadeTransition(
      opacity: _fadeController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with actions
          if (widget.showActions)
            Padding(
              padding: widget.padding.copyWith(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.folders,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  
                  // Search toggle
                  if (widget.showSearch)
                    IconButton.filledTonal(
                      onPressed: _toggleSearch,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _showSearch ? Icons.search_off : Icons.search,
                          key: ValueKey(_showSearch),
                        ),
                      ),
                      tooltip: _showSearch ? l10n.hideSearch : l10n.showSearch,
                    ),
                  
                  const SizedBox(width: 8),
                  
                  // Expand/Collapse all
                  IconButton.filledTonal(
                    onPressed: () {
                      final hierarchyNotifier = ref.read(folderHierarchyProvider.notifier);
                      final hasExpandedFolders = ref.read(folderHierarchyProvider).expandedIds.isNotEmpty;
                      
                      if (hasExpandedFolders) {
                        hierarchyNotifier.collapseAll();
                      } else {
                        hierarchyNotifier.expandAll();
                      }
                    },
                    icon: Consumer(
                      builder: (context, ref, child) {
                        final hasExpandedFolders = ref.watch(folderHierarchyProvider).expandedIds.isNotEmpty;
                        return Icon(hasExpandedFolders ? Icons.unfold_less : Icons.unfold_more);
                      },
                    ),
                    tooltip: ref.watch(folderHierarchyProvider).expandedFolders.isNotEmpty ? l10n.collapseAll : l10n.expandAll,
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Create folder
                  IconButton.filled(
                    onPressed: _showCreateFolderDialog,
                    icon: const Icon(Icons.create_new_folder),
                    tooltip: l10n.createNewFolder,
                  ),
                ],
              ),
            ),
          
          // Search bar (animated)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: _showSearch
                ? Container(
                    margin: widget.padding.copyWith(top: 0, bottom: 16),
                    child: SearchBar(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      hintText: l10n.searchFolders,
                      onChanged: _onSearchChanged,
                      leading: const Icon(Icons.search),
                      trailing: _searchQuery.isNotEmpty
                          ? [
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                                tooltip: l10n.clearSearch,
                              ),
                            ]
                          : null,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          
          // Folder hierarchy
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final hierarchyState = ref.watch(folderHierarchyProvider);
                
                if (hierarchyState.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }
                
                if (hierarchyState.error != null) {
                  return _ErrorDisplay(
                    error: hierarchyState.error!,
                    onRetry: () => ref.read(folderHierarchyProvider.notifier).refresh(),
                  );
                }
                
                final filteredNodes = _filterNodes(hierarchyState.rootNodes);
                
                if (filteredNodes.isEmpty) {
                  return _EmptyState(
                    searchQuery: _searchQuery,
                    onCreateFolder: widget.showActions ? _showCreateFolderDialog : null,
                  );
                }
                
                return DragTarget<String>(
                  onWillAcceptWithDetails: (details) => details.data != null,
                  onAcceptWithDetails: (details) => _moveToRoot(details.data),
                  builder: (context, candidateData, rejectedData) {
                    return Container(
                      decoration: candidateData.isNotEmpty
                          ? BoxDecoration(
                              border: Border.all(
                                color: colorScheme.primary,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            )
                          : null,
                      child: ListView.builder(
                        padding: widget.padding.copyWith(top: 0),
                        itemCount: filteredNodes.length,
                        itemBuilder: (context, index) {
                          return _buildFolderTreeItem(filteredNodes[index]);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderTreeItem(FolderTreeNode node) {
    return _FolderTreeTile(
      key: ValueKey(node.folder.id),
      node: node,
      isSelected: node.folder.id == widget.selectedFolderId,
      onTap: () => widget.onFolderTap?.call(node.folder),
      onLongPress: () {
        if (widget.onFolderLongPress != null) {
          widget.onFolderLongPress!(node.folder);
        } else {
          _showFolderActions(node.folder);
        }
      },
      onExpandToggle: () {
        ref.read(folderHierarchyProvider.notifier).toggleExpansion(node.folder.id);
      },
      onDragStarted: (folderId) => setState(() => _draggedFolderId = folderId),
      onDragCompleted: () => setState(() => _draggedFolderId = null),
      onAcceptDrop: _moveFolderToFolder,
      isDragging: _draggedFolderId == node.folder.id,
      children: node.children.map(_buildFolderTreeItem).toList(),
    );
  }

  Future<void> _moveToRoot(String folderId) async {
    if (folderId == _draggedFolderId) {
      final success = await ref.read(folderProvider.notifier).moveFolder(folderId, null);
      if (success) {
        ref.read(folderHierarchyProvider.notifier).refresh();
      }
    }
  }

  Future<void> _moveFolderToFolder(String draggedId, String targetId) async {
    if (draggedId != targetId) {
      final success = await ref.read(folderProvider.notifier).moveFolder(draggedId, targetId);
      if (success) {
        ref.read(folderHierarchyProvider.notifier).refresh();
      }
    }
  }
}

class _FolderTreeTile extends StatefulWidget {
  const _FolderTreeTile({
    required this.node, required this.isSelected, required this.onTap, required this.onLongPress, required this.onExpandToggle, required this.onDragStarted, required this.onDragCompleted, required this.onAcceptDrop, required this.isDragging, super.key,
    this.children = const [],
  });

  final FolderTreeNode node;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onExpandToggle;
  final ValueChanged<String> onDragStarted;
  final VoidCallback onDragCompleted;
  final Function(String, String) onAcceptDrop;
  final bool isDragging;
  final List<Widget> children;

  @override
  State<_FolderTreeTile> createState() => _FolderTreeTileState();
}

class _FolderTreeTileState extends State<_FolderTreeTile> 
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  bool _isDragOver = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: 1,
    );
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    if (widget.node.isExpanded) {
      _rotationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_FolderTreeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.node.isExpanded != oldWidget.node.isExpanded) {
      if (widget.node.isExpanded) {
        _rotationController.forward();
      } else {
        _rotationController.reverse();
      }
    }
    
    if (widget.isDragging != oldWidget.isDragging) {
      if (widget.isDragging) {
        _scaleController.animateTo(1.1);
      } else {
        _scaleController.animateTo(1);
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final folder = widget.node.folder;
    
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != folder.id,
      onAcceptWithDetails: (details) => widget.onAcceptDrop(details.data, folder.id),
      onMove: (details) => setState(() => _isDragOver = true),
      onLeave: (data) => setState(() => _isDragOver = false),
      builder: (context, candidateData, rejectedData) {
        return AnimatedScale(
          scale: widget.isDragging ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Column(
            children: [
              Draggable<String>(
                data: folder.id,
                feedback: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: FolderIconHelpers.getFolderColor(folder.color) ?? colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            FolderIconHelpers.getFolderIcon(folder.icon),
                            color: FolderIconHelpers.getFolderColor(folder.color) != null
                                ? Colors.white
                                : colorScheme.onPrimaryContainer,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          folder.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.5,
                  child: _buildTileContent(context, theme, colorScheme, folder),
                ),
                onDragStarted: () => widget.onDragStarted(folder.id),
                onDragCompleted: widget.onDragCompleted,
                child: _buildTileContent(context, theme, colorScheme, folder),
              ),
              
              // Child folders (when expanded)
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: widget.node.isExpanded && widget.children.isNotEmpty
                    ? Column(children: widget.children)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTileContent(BuildContext context, ThemeData theme, ColorScheme colorScheme, LocalFolder folder) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: widget.isSelected
            ? colorScheme.primaryContainer.withOpacity(0.5)
            : _isDragOver
                ? colorScheme.surfaceContainerHighest
                : null,
        borderRadius: BorderRadius.circular(12),
        border: _isDragOver
            ? Border.all(color: colorScheme.primary, width: 2)
            : null,
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indentation
            SizedBox(width: widget.node.level * 20.0),
            
            // Expand/collapse button
            if (widget.node.children.isNotEmpty)
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 1.5708, // 90 degrees
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: widget.onExpandToggle,
                      iconSize: 20,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  );
                },
              )
            else
              const SizedBox(width: 32),
            
            // Folder icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: FolderIconHelpers.getFolderColor(folder.color) ?? colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                FolderIconHelpers.getFolderIcon(folder.icon),
                color: FolderIconHelpers.getFolderColor(folder.color) != null
                    ? Colors.white
                    : colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
          ],
        ),
        title: Text(
          folder.name,
          style: TextStyle(
            fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        subtitle: Row(
          children: [
            if (folder.description.isNotEmpty ?? false)
              Flexible(
                child: Text(
                  folder.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (folder.description.isNotEmpty ?? false) const SizedBox(width: 8),
            
            // Note count badge
            if (widget.node.noteCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.node.noteCount}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        trailing: widget.isSelected
            ? Icon(
                Icons.folder_open,
                color: colorScheme.primary,
              )
            : null,
        selected: widget.isSelected,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _FolderActionsSheet extends StatelessWidget {
  const _FolderActionsSheet({required this.folder});

  final LocalFolder folder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: FolderIconHelpers.getFolderColor(folder.color) ?? colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  FolderIconHelpers.getFolderIcon(folder.icon),
                  color: FolderIconHelpers.getFolderColor(folder.color) != null
                      ? Colors.white
                      : colorScheme.onPrimaryContainer,
                ),
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
                      folder.path,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Actions
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.editFolder),
            onTap: () => Navigator.of(context).pop('edit'),
          ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(l10n.createNewFolder),
            subtitle: Text('Create subfolder in "${folder.name}"'),
            onTap: () => Navigator.of(context).pop('create_subfolder'),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: colorScheme.error),
            title: Text(l10n.deleteFolder, style: TextStyle(color: colorScheme.error)),
            onTap: () => Navigator.of(context).pop('delete'),
          ),
        ],
      ),
    );
  }
}

class _ErrorDisplay extends StatelessWidget {
  const _ErrorDisplay({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.loadFoldersError,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.searchQuery,
    this.onCreateFolder,
  });

  final String searchQuery;
  final VoidCallback? onCreateFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searchQuery.isNotEmpty ? Icons.search_off : Icons.folder_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty ? l10n.noFoldersFound : 'No folders yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty 
                  ? l10n.noFoldersFoundSubtitle(searchQuery)
                  : 'Create folders to organize your notes',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            
            if (onCreateFolder != null && searchQuery.isEmpty) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onCreateFolder,
                icon: const Icon(Icons.create_new_folder),
                label: Text(l10n.createNewFolder),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
