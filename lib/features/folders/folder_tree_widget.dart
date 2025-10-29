import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderCoreRepositoryProvider;
import 'package:duru_notes/infrastructure/mappers/folder_mapper.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Example widget showing folder hierarchy with navigation
class FolderTreeWidget extends ConsumerStatefulWidget {
  const FolderTreeWidget({
    super.key,
    this.onFolderSelected,
    this.selectedFolderId,
  });

  final void Function(String? folderId)? onFolderSelected;
  final String? selectedFolderId;

  @override
  ConsumerState<FolderTreeWidget> createState() => _FolderTreeWidgetState();
}

class _FolderTreeWidgetState extends ConsumerState<FolderTreeWidget> {
  final Set<String> _expandedFolders = {};

  @override
  Widget build(BuildContext context) {
    final folderRepo = ref.watch(folderCoreRepositoryProvider);

    return Column(
      children: [
        // Header with create button
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Folders',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.create_new_folder, size: 20),
                onPressed: () => _showCreateFolderDialog(null),
                tooltip: 'Create folder',
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Inbox (unfiled notes)
        ListTile(
          leading: const Icon(Icons.inbox, size: 20),
          title: const Text('Inbox'),
          selected: widget.selectedFolderId == null,
          onTap: () => widget.onFolderSelected?.call(null),
          trailing: FutureBuilder<List<domain.Note>>(
            future: folderRepo.getUnfiledNotes(),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          ),
        ),

        // Folder tree
        Expanded(
          child: FutureBuilder<List<domain.Folder>>(
            future: folderRepo.getRootFolders(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final domainFolders = snapshot.data!;
              if (domainFolders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_off,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No folders yet',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Convert to local folders for UI display
              final rootFolders = domainFolders
                  .map((df) => FolderMapper.toInfrastructure(df))
                  .toList();

              return ListView.builder(
                itemCount: rootFolders.length,
                itemBuilder: (context, index) {
                  return _buildFolderTile(rootFolders[index], 0);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFolderTile(LocalFolder folder, int depth) {
    final folderRepo = ref.watch(folderCoreRepositoryProvider);
    final isExpanded = _expandedFolders.contains(folder.id);
    final isSelected = widget.selectedFolderId == folder.id;

    return Column(
      children: [
        ListTile(
          leading: Padding(
            padding: EdgeInsets.only(left: depth * DuruSpacing.md),
            child: Icon(
              isExpanded ? Icons.folder_open : Icons.folder,
              size: 20,
              color: folder.color != null
                  ? Color(int.parse(folder.color!.replaceFirst('#', '0xff')))
                  : null,
            ),
          ),
          title: Text(folder.name),
          subtitle: folder.description.isNotEmpty
              ? Text(
                  folder.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          selected: isSelected,
          onTap: () => widget.onFolderSelected?.call(folder.id),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Note count
              FutureBuilder<List<domain.Note>>(
                future: folderRepo.getNotesInFolder(folder.id),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      count.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              ),
              // Expand/collapse chevron
              FutureBuilder<List<domain.Folder>>(
                future: folderRepo.getChildFolders(folder.id),
                builder: (context, snapshot) {
                  final hasChildren = snapshot.data?.isNotEmpty ?? false;
                  if (!hasChildren) return const SizedBox(width: 24);

                  return IconButton(
                    icon: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 20,
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
                  );
                },
              ),
              // More menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'create_subfolder',
                    child: Row(
                      children: [
                        Icon(Icons.create_new_folder, size: 18),
                        SizedBox(width: 8),
                        Text('Create subfolder'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'move',
                    child: Row(
                      children: [
                        Icon(Icons.drive_file_move, size: 18),
                        SizedBox(width: 8),
                        Text('Move'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) => _handleFolderAction(value, folder),
              ),
            ],
          ),
        ),
        // Show child folders if expanded
        if (isExpanded)
          FutureBuilder<List<domain.Folder>>(
            future: folderRepo.getChildFolders(folder.id),
            builder: (context, snapshot) {
              final domainChildren = snapshot.data ?? [];
              final children = domainChildren
                  .map((df) => FolderMapper.toInfrastructure(df))
                  .toList();
              return Column(
                children: children
                    .map((child) => _buildFolderTile(child, depth + 1))
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  void _handleFolderAction(String action, LocalFolder folder) {
    switch (action) {
      case 'create_subfolder':
        _showCreateFolderDialog(folder.id);
        break;
      case 'rename':
        _showRenameFolderDialog(folder);
        break;
      case 'move':
        _showMoveFolderDialog(folder);
        break;
      case 'delete':
        _showDeleteConfirmation(folder);
        break;
    }
  }

  void _showCreateFolderDialog(String? parentId) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(parentId == null ? 'Create Folder' : 'Create Subfolder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Folder name',
                hintText: 'Enter folder name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Enter description',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final folderRepo = ref.read(folderCoreRepositoryProvider);
                await folderRepo.createFolder(
                  name: nameController.text,
                  parentId: parentId,
                  description: descriptionController.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameFolderDialog(LocalFolder folder) {
    final controller = TextEditingController(text: folder.name);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Folder name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.isNotEmpty &&
                  controller.text != folder.name) {
                final folderRepo = ref.read(folderCoreRepositoryProvider);
                await folderRepo.renameFolder(folder.id, controller.text);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showMoveFolderDialog(LocalFolder folder) {
    // This would show a dialog with folder picker
    // For now, just show a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Move folder feature coming soon')),
    );
  }

  void _showDeleteConfirmation(LocalFolder folder) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
          'Are you sure you want to delete "${folder.name}"?\n\n'
          'Notes in this folder will be moved to the Inbox.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final folderRepo = ref.read(folderCoreRepositoryProvider);
              await folderRepo.deleteFolder(folder.id);
              if (context.mounted) {
                Navigator.of(context).pop();
                // If deleted folder was selected, go back to inbox
                if (widget.selectedFolderId == folder.id) {
                  widget.onFolderSelected?.call(null);
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
