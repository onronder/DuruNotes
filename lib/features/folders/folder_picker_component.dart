import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/create_folder_dialog.dart';
import 'package:duru_notes/features/folders/folder_icon_helpers.dart';
import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart' show folderHierarchyProvider, visibleFolderNodesProvider;
import 'package:duru_notes/features/folders/providers/folders_integration_providers.dart' show unfiledNotesCountProvider, rootFoldersProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Component for picking a folder from the hierarchy
class FolderPicker extends ConsumerStatefulWidget {
  const FolderPicker({
    super.key,
    this.selectedFolderId,
    this.onFolderSelected,
    this.showCreateOption = true,
    this.showUnfiledOption = true,
    this.title,
  });

  final String? selectedFolderId;
  final ValueChanged<String?>? onFolderSelected;
  final bool showCreateOption;
  final bool showUnfiledOption;
  final String? title;

  @override
  ConsumerState<FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends ConsumerState<FolderPicker> {
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.title ?? AppLocalizations.of(context).selectFolder,
                  style: theme.textTheme.titleLarge,
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).searchFolders,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  onChanged: (value) {
                    ref
                        .read(folderHierarchyProvider.notifier)
                        .updateSearchQuery(value);
                  },
                ),
              ),

              // Folder list
              Expanded(
                child: hierarchyState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : hierarchyState.error != null
                        ? _buildErrorState(theme, hierarchyState.error!)
                        : _buildFolderList(
                            theme,
                            visibleNodes,
                            unfiledCount,
                            scrollController,
                          ),
              ),

              // Actions
              if (widget.showCreateOption)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildCreateFolderButton(theme),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFolderList(
    ThemeData theme,
    List<FolderTreeNode> nodes,
    AsyncValue<int> unfiledCount,
    ScrollController scrollController,
  ) {
    if (nodes.isEmpty && !widget.showUnfiledOption) {
      return _buildEmptyState(theme);
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Unfiled option
        if (widget.showUnfiledOption)
          unfiledCount.when(
            data: (count) => _buildUnfiledOption(theme, count),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

        // Folder tree
        ...nodes.map((node) => _buildFolderItem(theme, node)),
      ],
    );
  }

  Widget _buildUnfiledOption(ThemeData theme, int count) {
    final isSelected = widget.selectedFolderId == null;

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface,
      child: ListTile(
        leading: Icon(
          Icons.folder_off_outlined,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          AppLocalizations.of(context).unfiled,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : null,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
        ),
        trailing: count > 0
            ? Chip(
                label: Text(count.toString()),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              )
            : null,
        selected: isSelected,
        selectedTileColor: theme.colorScheme.primaryContainer.withValues(
          alpha: 0.3,
        ),
        onTap: () {
          widget.onFolderSelected?.call(null);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).noFoldersFound,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).createYourFirstFolder,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).errorLoadingFolders,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
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
          FilledButton.tonal(
            onPressed: () {
              ref.read(folderHierarchyProvider.notifier).loadFolders();
            },
            child: Text(AppLocalizations.of(context).retry),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateFolderButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _showCreateFolderDialog,
        icon: const Icon(Icons.create_new_folder),
        label: Text(AppLocalizations.of(context).createNewFolder),
      ),
    );
  }

  Widget _buildFolderItem(ThemeData theme, FolderTreeNode node) {
    final isSelected = widget.selectedFolderId == node.folder.id;
    final indentWidth = node.level * 24.0;

    return ListTile(
      contentPadding: EdgeInsets.only(left: 16 + indentWidth, right: 16),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Icon(
            FolderIconHelpers.getFolderIcon(node.folder.icon),
            color: FolderIconHelpers.getFolderColor(node.folder.color) ??
                (isSelected
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
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.3,
      ),
      onTap: () {
        widget.onFolderSelected?.call(node.folder.id);
        Navigator.of(context).pop();
      },
    );
  }

  void _showCreateFolderDialog() async {
    final result = await showDialog<LocalFolder>(
      context: context,
      builder: (context) => const CreateFolderDialog(),
    );

    if (result != null && mounted) {
      // Select the newly created folder immediately
      widget.onFolderSelected?.call(result.id);

      // Refresh folder hierarchy
      ref.read(folderHierarchyProvider.notifier).refresh();
      ref.invalidate(rootFoldersProvider);
    }
  }
}
