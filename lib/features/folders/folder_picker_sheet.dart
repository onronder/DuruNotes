import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_db.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import 'folder_notifiers.dart';
import 'create_folder_dialog.dart';

/// Material 3 bottom sheet for folder selection with hierarchical tree view
class FolderPickerSheet extends ConsumerStatefulWidget {
  const FolderPickerSheet({
    super.key,
    this.selectedFolderId,
    this.noteId,
    this.title,
    this.showCreateOption = true,
    this.showUnfiledOption = true,
  });

  final String? selectedFolderId;
  final String? noteId;
  final String? title;
  final bool showCreateOption;
  final bool showUnfiledOption;

  @override
  ConsumerState<FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends ConsumerState<FolderPickerSheet>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _slideController;
  late AnimationController _fadeController;
  String _searchQuery = '';
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    // Start animation
    _slideController.forward();
    _fadeController.forward();
    
    // Load folder hierarchy
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(folderHierarchyProvider.notifier).loadFolders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
    });
    
    if (_showSearch) {
      _searchFocusNode.requestFocus();
    } else {
      _searchController.clear();
      _searchQuery = '';
      _searchFocusNode.unfocus();
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
           folder.path.toLowerCase().contains(_searchQuery);
  }

  List<FolderTreeNode> _filterNodes(List<FolderTreeNode> nodes) {
    if (_searchQuery.isEmpty) return nodes;
    
    final filtered = <FolderTreeNode>[];
    for (final node in nodes) {
      final nodeMatches = _matchesSearch(node.folder);
      
      if (nodeMatches) {
        filtered.add(node.copyWith(
          isExpanded: _searchQuery.isNotEmpty, // Auto-expand when searching
        ));
      }
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      )),
      child: FadeTransition(
        opacity: _fadeController,
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 8, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title ?? l10n.folderPickerTitle,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (widget.noteId != null)
                                Text(
                                  l10n.folderPickerSubtitle,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        // Search toggle button
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
                        
                        // Close button
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: l10n.close,
                        ),
                      ],
                    ),
                  ),
                  
                  // Search bar (when visible)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _showSearch ? 56 : 0,
                    curve: Curves.easeOutCubic,
                    child: _showSearch
                        ? Container(
                            margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
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
                  
                  // Folder list
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
                            onRetry: () => ref.read(folderHierarchyProvider.notifier).loadFolders(),
                          );
                        }
                        
                        final visibleNodes = ref.read(folderHierarchyProvider.notifier).getVisibleNodes();
                        final filteredNodes = _filterNodes(visibleNodes);
                        
                        return ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          children: [
                            // Unfiled option
                            if (widget.showUnfiledOption)
                              _UnfiledOption(
                                isSelected: widget.selectedFolderId == null,
                                onTap: () => Navigator.of(context).pop(null),
                              ),
                            
                            // Create new folder option
                            if (widget.showCreateOption)
                              _CreateFolderOption(
                                onTap: _showCreateFolderDialog,
                              ),
                            
                            // Divider
                            if (widget.showUnfiledOption || widget.showCreateOption)
                              const Divider(height: 1),
                            
                            // Folder tree
                            ...filteredNodes.map((node) => _buildFolderTreeItem(node)),
                            
                            // Empty state
                            if (filteredNodes.isEmpty && _searchQuery.isNotEmpty)
                              _EmptySearchState(query: _searchQuery),
                            
                            // Bottom padding for better scrolling
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFolderTreeItem(FolderTreeNode node) {
    return _FolderTreeTile(
      node: node,
      isSelected: node.folder.id == widget.selectedFolderId,
      onTap: () => Navigator.of(context).pop(node.folder),
      onExpandToggle: () {
        ref.read(folderHierarchyProvider.notifier).toggleExpansion(node.folder.id);
      },
      children: node.children.map(_buildFolderTreeItem).toList(),
    );
  }

  Future<void> _showCreateFolderDialog() async {
    final result = await showDialog<LocalFolder>(
      context: context,
      builder: (context) => const CreateFolderDialog(),
    );
    
    if (result != null && mounted) {
      // Refresh folder hierarchy
      ref.read(folderHierarchyProvider.notifier).loadFolders();
      // Return the newly created folder
      Navigator.of(context).pop(result);
    }
  }
}

class _UnfiledOption extends StatelessWidget {
  const _UnfiledOption({
    required this.isSelected,
    required this.onTap,
  });

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    
    return Consumer(
      builder: (context, ref, child) {
        final unfiledCountAsync = ref.watch(unfiledNotesCountProvider);
        
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.folder_off_outlined,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          title: Text(l10n.unfiledNotes),
          subtitle: unfiledCountAsync.when(
            data: (count) => Text(l10n.noteCount(count)),
            loading: () => const SizedBox(
              height: 16,
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => Text(l10n.loadError),
          ),
          trailing: isSelected
              ? Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                )
              : null,
          selected: isSelected,
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }
}

class _CreateFolderOption extends StatelessWidget {
  const _CreateFolderOption({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.create_new_folder_outlined,
          color: colorScheme.onPrimaryContainer,
          size: 20,
        ),
      ),
      title: Text(
        l10n.createNewFolder,
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(l10n.createNewFolderSubtitle),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _FolderTreeTile extends StatelessWidget {
  const _FolderTreeTile({
    required this.node,
    required this.isSelected,
    required this.onTap,
    required this.onExpandToggle,
    this.children = const [],
  });

  final FolderTreeNode node;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onExpandToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final folder = node.folder;
    
    return Column(
      children: [
        ListTile(
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indentation for hierarchy
              SizedBox(width: node.level * 16.0),
              
              // Expand/collapse button
              if (node.hasChildren)
                IconButton(
                  icon: AnimatedRotation(
                    turns: node.isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right),
                  ),
                  onPressed: onExpandToggle,
                  iconSize: 20,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                )
              else
                const SizedBox(width: 32),
              
              // Folder icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: folder.color != null
                      ? Color(int.parse(folder.color!, radix: 16))
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  folder.icon != null
                      ? IconData(int.parse(folder.icon!), fontFamily: 'MaterialIcons')
                      : Icons.folder,
                  color: folder.color != null
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
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          subtitle: Row(
            children: [
              if (folder.path.isNotEmpty)
                Flexible(
                  child: Text(
                    folder.path,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(width: 8),
              // Note count badge
              if (node.noteCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${node.noteCount}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          trailing: isSelected
              ? Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                )
              : null,
          selected: isSelected,
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        
        // Child folders (when expanded)
        if (node.isExpanded && children.isNotEmpty)
          ...children,
      ],
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

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noFoldersFound,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noFoldersFoundSubtitle(query),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Show folder picker bottom sheet
Future<LocalFolder?> showFolderPicker(
  BuildContext context, {
  String? selectedFolderId,
  String? noteId,
  String? title,
  bool showCreateOption = true,
  bool showUnfiledOption = true,
}) {
  return showModalBottomSheet<LocalFolder>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FolderPickerSheet(
      selectedFolderId: selectedFolderId,
      noteId: noteId,
      title: title,
      showCreateOption: showCreateOption,
      showUnfiledOption: showUnfiledOption,
    ),
  );
}