import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FolderPicker extends ConsumerStatefulWidget {
  const FolderPicker({
    super.key,
    this.selectedFolderId,
    this.onFolderSelected,
    this.showCreateOption = true,
    this.showUnfiledOption = true,
    this.title = 'Select Folder',
  });

  final String? selectedFolderId;
  final Function(String? folderId)? onFolderSelected;
  final bool showCreateOption;
  final bool showUnfiledOption;
  final String title;

  @override
  ConsumerState<FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends ConsumerState<FolderPicker> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Ensure folders are loaded when picker opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(folderHierarchyProvider.notifier).loadFolders();
    });
  }

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
    final unfiledCount = ref.watch(unfiledNotesCountProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
              ),

              const SizedBox(height: 16),

              // Folder list
              Expanded(
                child: hierarchyState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : hierarchyState.error != null
                        ? _buildErrorState(theme, hierarchyState.error!)
                        : _buildFolderList(theme, visibleNodes, unfiledCount),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: theme.colorScheme.error,
          ),
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
    );
  }

  Widget _buildFolderList(ThemeData theme, List<FolderTreeNode> visibleNodes, AsyncValue<int> unfiledCount) {
    // Debug: Print the number of visible nodes
    print('FolderPicker: Building folder list with ${visibleNodes.length} visible nodes');
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _getItemCount(visibleNodes, unfiledCount),
      itemBuilder: (context, index) {
        // Unfiled option
        if (widget.showUnfiledOption && index == 0) {
          return _buildUnfiledOption(theme, unfiledCount);
        }

        // Create new folder option
        final createOptionIndex = widget.showUnfiledOption ? 1 : 0;
        if (widget.showCreateOption && index == createOptionIndex) {
          return _buildCreateFolderOption(theme);
        }

        // Divider after special options
        final dividerIndex = (widget.showUnfiledOption ? 1 : 0) + (widget.showCreateOption ? 1 : 0);
        if (index == dividerIndex && visibleNodes.isNotEmpty) {
          return const Divider(height: 1);
        }

        // Folder items
        final nodeIndex = index - dividerIndex - (visibleNodes.isNotEmpty ? 1 : 0);
        if (nodeIndex >= 0 && nodeIndex < visibleNodes.length) {
          return _buildFolderItem(theme, visibleNodes[nodeIndex]);
        }

        return const SizedBox.shrink();
      },
    );
  }

  int _getItemCount(List<FolderTreeNode> visibleNodes, AsyncValue<int> unfiledCount) {
    var count = visibleNodes.length;
    if (widget.showUnfiledOption) count++;
    if (widget.showCreateOption) count++;
    if (visibleNodes.isNotEmpty && (widget.showUnfiledOption || widget.showCreateOption)) {
      count++; // divider
    }
    return count;
  }

  Widget _buildUnfiledOption(ThemeData theme, AsyncValue<int> unfiledCount) {
    final isSelected = widget.selectedFolderId == null;
    
    return ListTile(
      leading: Icon(
        Icons.note_outlined,
        color: isSelected 
            ? theme.colorScheme.primary 
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        'Unfiled Notes',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: isSelected 
              ? theme.colorScheme.primary 
              : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : null,
        ),
      ),
      trailing: unfiledCount.when(
        data: (count) => count > 0 
            ? Chip(
                label: Text(count.toString()),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                labelStyle: theme.textTheme.labelSmall,
              )
            : null,
        loading: () => const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (_, __) => null,
      ),
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
      onTap: () {
        widget.onFolderSelected?.call(null);
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildCreateFolderOption(ThemeData theme) {
    return ListTile(
      leading: Icon(
        Icons.create_new_folder_outlined,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        'Create New Folder',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        _showCreateFolderDialog();
      },
    );
  }

  Widget _buildFolderItem(ThemeData theme, FolderTreeNode node) {
    final isSelected = widget.selectedFolderId == node.folder.id;
    final indentWidth = node.level * 24.0;
    
    return ListTile(
      contentPadding: EdgeInsets.only(
        left: 16 + indentWidth,
        right: 16,
      ),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (node.hasChildren)
            IconButton(
              onPressed: () {
                ref.read(folderHierarchyProvider.notifier)
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
          Icon(
            node.folder.icon != null 
                ? IconData(
                    int.parse(node.folder.icon!),
                    fontFamily: 'MaterialIcons',
                  )
                : Icons.folder,
            color: node.folder.color != null
                ? Color(int.parse(node.folder.color!))
                : (isSelected 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.onSurfaceVariant),
            size: 20,
          ),
        ],
      ),
      title: Text(
        node.folder.name,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: isSelected 
              ? theme.colorScheme.primary 
              : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : null,
        ),
      ),
      trailing: node.noteCount > 0
          ? Chip(
              label: Text(node.noteCount.toString()),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              labelStyle: theme.textTheme.labelSmall,
            )
          : null,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
      onTap: () {
        widget.onFolderSelected?.call(node.folder.id);
        Navigator.of(context).pop();
      },
    );
  }

  void _showCreateFolderDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateFolderDialog(),
    );
  }
}

class CreateFolderDialog extends ConsumerStatefulWidget {
  const CreateFolderDialog({super.key});

  @override
  ConsumerState<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends ConsumerState<CreateFolderDialog> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Folder'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'Enter folder name',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Folder name is required';
            }
            return null;
          },
          autofocus: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _createFolder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isCreating ? null : _createFolder,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createFolder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final folderId = await ref.read(folderProvider.notifier).createFolder(
        name: _nameController.text.trim(),
      );

      if (folderId != null) {
        // Refresh all folder-related providers
        ref.read(folderHierarchyProvider.notifier).loadFolders();
        ref.invalidate(rootFoldersProvider);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Folder "${_nameController.text.trim()}" created'),
              behavior: SnackBarBehavior.fixed,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create folder'),
              behavior: SnackBarBehavior.fixed,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }
}
