import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/ui/widgets/folder_breadcrumbs_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hierarchical folder tree widget with expand/collapse functionality
class FolderTreeWidget extends ConsumerStatefulWidget {
  const FolderTreeWidget({
    required this.onFolderSelected,
    super.key,
    this.selectedFolderId,
    this.showActions = true,
    this.showBreadcrumbs = true,
  });
  final String? selectedFolderId;
  final Function(LocalFolder?) onFolderSelected;
  final bool showActions;
  final bool showBreadcrumbs;

  @override
  ConsumerState<FolderTreeWidget> createState() => _FolderTreeWidgetState();
}

class _FolderTreeWidgetState extends ConsumerState<FolderTreeWidget> {
  final Set<String> _expandedFolders = {};
  String? _editingFolderId;
  final Map<String, TextEditingController> _editControllers = {};

  Future<List<LocalFolder>> _getFolderBreadcrumbs(
    NotesRepository repo,
    String folderId,
  ) async {
    final breadcrumbs = <LocalFolder>[];
    String? currentId = folderId;

    while (currentId != null) {
      final folder = await repo.getFolder(currentId);
      if (folder == null) break;
      breadcrumbs.insert(0, folder);
      currentId = folder.parentId;
    }

    return breadcrumbs;
  }

  @override
  void dispose() {
    for (final controller in _editControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesRepo = ref.watch(notesRepositoryProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumbs
        if (widget.showBreadcrumbs && widget.selectedFolderId != null)
          FutureBuilder<List<LocalFolder>>(
            future: _getFolderBreadcrumbs(notesRepo, widget.selectedFolderId!),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: FolderBreadcrumbsWidget(
                    breadcrumbs: snapshot.data!,
                    onFolderTap: widget.onFolderSelected,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

        // Folder tree
        Expanded(
          child: FutureBuilder<List<LocalFolder>>(
            future: notesRepo.listFolders(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState(context);
              }

              final folders = snapshot.data!;
              final rootFolders =
                  folders
                      .where((f) => f.parentId == null && !f.deleted)
                      .toList()
                    ..sort((a, b) {
                      final orderCompare = a.sortOrder.compareTo(b.sortOrder);
                      return orderCompare != 0
                          ? orderCompare
                          : a.name.compareTo(b.name);
                    });

              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Inbox (unfiled notes)
                  _buildInboxItem(context),
                  const Divider(height: 1),
                  // Root folders
                  ...rootFolders.map(
                    (folder) => _buildFolderItem(context, folder, folders, 0),
                  ),
                  // Add folder button
                  if (widget.showActions) _buildAddFolderButton(context, null),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No folders yet',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create folders to organize your notes',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          if (widget.showActions)
            FilledButton.icon(
              onPressed: () => _createFolder(context, null),
              icon: const Icon(Icons.create_new_folder),
              label: const Text('Create Folder'),
            ),
        ],
      ),
    );
  }

  Widget _buildInboxItem(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected =
        widget.selectedFolderId == null || widget.selectedFolderId == '';

    return ListTile(
      leading: Icon(
        Icons.inbox,
        color: isSelected ? theme.colorScheme.primary : null,
      ),
      title: Text(
        'Inbox',
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
      ),
      subtitle: const Text('Unfiled notes'),
      selected: isSelected,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onFolderSelected(null);
      },
    );
  }

  Widget _buildFolderItem(
    BuildContext context,
    LocalFolder folder,
    List<LocalFolder> allFolders,
    int depth,
  ) {
    final theme = Theme.of(context);
    final isSelected = widget.selectedFolderId == folder.id;
    final isExpanded = _expandedFolders.contains(folder.id);
    final isEditing = _editingFolderId == folder.id;

    // Get child folders
    final children =
        allFolders.where((f) => f.parentId == folder.id && !f.deleted).toList()
          ..sort((a, b) {
            final orderCompare = a.sortOrder.compareTo(b.sortOrder);
            return orderCompare != 0 ? orderCompare : a.name.compareTo(b.name);
          });

    final hasChildren = children.isNotEmpty;

    // Get folder color
    Color? folderColor;
    if (folder.color != null) {
      try {
        folderColor = Color(int.parse(folder.color!.replaceFirst('#', '0xff')));
      } catch (_) {}
    }

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(
            left: 16.0 + (depth * 16.0),
            right: 8,
          ),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasChildren)
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedFolders.remove(folder.id);
                      } else {
                        _expandedFolders.add(folder.id);
                      }
                    });
                  },
                )
              else
                const SizedBox(width: 24),
              Icon(
                _getFolderIcon(folder),
                color:
                    folderColor ??
                    (isSelected ? theme.colorScheme.primary : null),
                size: 20,
              ),
            ],
          ),
          title: isEditing
              ? TextField(
                  controller: _editControllers[folder.id],
                  autofocus: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (value) => _saveRename(folder, value),
                  onTapOutside: (_) => _cancelEdit(),
                )
              : Text(
                  folder.name,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                ),
          trailing: widget.showActions
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isEditing) ...[
                      IconButton(
                        icon: const Icon(Icons.check, size: 20),
                        onPressed: () => _saveRename(
                          folder,
                          _editControllers[folder.id]?.text ?? folder.name,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: _cancelEdit,
                      ),
                    ] else ...[
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (value) {
                          switch (value) {
                            case 'rename':
                              _startEdit(folder);
                              break;
                            case 'move':
                              _moveFolder(context, folder, allFolders);
                              break;
                            case 'delete':
                              _deleteFolder(context, folder);
                              break;
                            case 'add_subfolder':
                              _createFolder(context, folder.id);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'add_subfolder',
                            child: Text('Add Subfolder'),
                          ),
                          const PopupMenuItem(
                            value: 'rename',
                            child: Text('Rename'),
                          ),
                          const PopupMenuItem(
                            value: 'move',
                            child: Text('Move'),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ],
                )
              : null,
          selected: isSelected,
          onTap: isEditing
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onFolderSelected(folder);
                },
        ),
        // Child folders
        if (hasChildren && isExpanded)
          ...children.map(
            (child) => _buildFolderItem(context, child, allFolders, depth + 1),
          ),
        // Add subfolder button
        if (hasChildren && isExpanded && widget.showActions)
          _buildAddFolderButton(context, folder.id, depth: depth + 1),
      ],
    );
  }

  Widget _buildAddFolderButton(
    BuildContext context,
    String? parentId, {
    int depth = 0,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.only(
        left: 16.0 + (depth * 16.0) + 24.0,
        right: 16,
      ),
      leading: const Icon(Icons.add, size: 20),
      title: const Text('New folder'),
      onTap: () => _createFolder(context, parentId),
    );
  }

  IconData _getFolderIcon(LocalFolder folder) {
    if (folder.icon != null) {
      switch (folder.icon) {
        case 'work':
          return Icons.work;
        case 'personal':
          return Icons.person;
        case 'archive':
          return Icons.archive;
        case 'star':
          return Icons.star;
        default:
          return Icons.folder;
      }
    }
    return Icons.folder;
  }

  void _startEdit(LocalFolder folder) {
    setState(() {
      _editingFolderId = folder.id;
      _editControllers[folder.id] = TextEditingController(text: folder.name);
    });
  }

  void _cancelEdit() {
    setState(() {
      if (_editingFolderId != null) {
        _editControllers[_editingFolderId]?.dispose();
        _editControllers.remove(_editingFolderId);
      }
      _editingFolderId = null;
    });
  }

  Future<void> _saveRename(LocalFolder folder, String newName) async {
    if (newName.trim().isEmpty || newName == folder.name) {
      _cancelEdit();
      return;
    }

    try {
      final notesRepo = ref.read(notesRepositoryProvider);
      await notesRepo.renameFolder(folder.id, newName.trim());
      _cancelEdit();
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Renamed to "$newName"')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to rename: $e')));
      }
    }
  }

  Future<void> _createFolder(BuildContext context, String? parentId) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(parentId == null ? 'Create Folder' : 'Create Subfolder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'Enter folder name',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        final notesRepo = ref.read(notesRepositoryProvider);
        final folder = await notesRepo.createFolder(
          name: result.trim(),
          parentId: parentId,
        );
        HapticFeedback.mediumImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Created folder "${folder.name}"')),
          );
          // Auto-expand parent if creating subfolder
          if (parentId != null) {
            setState(() {
              _expandedFolders.add(parentId);
            });
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create folder: $e')),
          );
        }
      }
    }
  }

  Future<void> _moveFolder(
    BuildContext context,
    LocalFolder folder,
    List<LocalFolder> allFolders,
  ) async {
    // Filter out the folder itself and its descendants
    final availableParents = <LocalFolder?>[null]; // null = root
    for (final f in allFolders) {
      if (f.id != folder.id && !f.path.startsWith('${folder.path}/')) {
        availableParents.add(f);
      }
    }

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move "${folder.name}"'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Root'),
                onTap: () => Navigator.pop(context, ''),
              ),
              ...availableParents
                  .skip(1)
                  .map(
                    (parent) => ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(parent!.name),
                      subtitle: Text(parent.path),
                      onTap: () => Navigator.pop(context, parent.id),
                    ),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final notesRepo = ref.read(notesRepositoryProvider);
        await notesRepo.moveFolder(folder.id, result.isEmpty ? null : result);
        HapticFeedback.mediumImpact();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Folder moved')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to move folder: $e')));
        }
      }
    }
  }

  Future<void> _deleteFolder(BuildContext context, LocalFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
          'Delete "${folder.name}"?\n\n'
          'Notes in this folder will be moved to Inbox.\n'
          'Subfolders will also be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        final notesRepo = ref.read(notesRepositoryProvider);
        await notesRepo.deleteFolder(folder.id);
        HapticFeedback.mediumImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted folder "${folder.name}"')),
          );
          // If deleted folder was selected, switch to inbox
          if (widget.selectedFolderId == folder.id) {
            widget.onFolderSelected(null);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete folder: $e')),
          );
        }
      }
    }
  }
}
