import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderCoreRepositoryProvider;
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/ui/widgets/folder_breadcrumbs_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
  final void Function(domain.Folder?) onFolderSelected;
  final bool showActions;
  final bool showBreadcrumbs;

  @override
  ConsumerState<FolderTreeWidget> createState() => _FolderTreeWidgetState();
}

class _FolderTreeWidgetState extends ConsumerState<FolderTreeWidget> {
  AppLogger get _logger => ref.read(loggerProvider);

  final Set<String> _expandedFolders = {};
  String? _editingFolderId;
  final Map<String, TextEditingController> _editControllers = {};

  Future<List<domain.Folder>> _getFolderBreadcrumbs(
    IFolderRepository repo,
    String folderId,
  ) async {
    final breadcrumbs = <domain.Folder>[];
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
    final folderRepo = ref.watch(folderCoreRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumbs
        if (widget.showBreadcrumbs && widget.selectedFolderId != null)
          FutureBuilder<List<domain.Folder>>(
            future: _getFolderBreadcrumbs(folderRepo, widget.selectedFolderId!),
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
          child: FutureBuilder<List<domain.Folder>>(
            future: folderRepo.listFolders(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState(context);
              }

              final folders = snapshot.data!;
              final rootFolders =
                  folders.where((f) => f.parentId == null).toList()
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
    domain.Folder folder,
    List<domain.Folder> allFolders,
    int depth,
  ) {
    final theme = Theme.of(context);
    final isSelected = widget.selectedFolderId == folder.id;
    final isExpanded = _expandedFolders.contains(folder.id);
    final isEditing = _editingFolderId == folder.id;

    // Get child folders
    final children = allFolders.where((f) => f.parentId == folder.id).toList()
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
      } catch (error, stack) {
        if (kDebugMode) {
          debugPrint(
            'Invalid folder color ${folder.color} for ${folder.name}: $error\n$stack',
          );
        }
        folderColor = null;
      }
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

  IconData _getFolderIcon(domain.Folder folder) {
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

  void _startEdit(domain.Folder folder) {
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

  Future<void> _saveRename(domain.Folder folder, String newName) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty || trimmedName == folder.name) {
      _cancelEdit();
      return;
    }

    try {
      final folderRepo = ref.read(folderCoreRepositoryProvider);
      await folderRepo.renameFolder(folder.id, trimmedName);
      _logger.info(
        'Folder renamed',
        data: {
          'folderId': folder.id,
          'newName': trimmedName,
          'previousName': folder.name,
        },
      );
      _cancelEdit();
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Renamed to "$trimmedName"')));
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to rename folder',
        error: error,
        stackTrace: stackTrace,
        data: {
          'folderId': folder.id,
          'attemptedName': trimmedName,
        },
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      _showErrorSnackBar(
        'Failed to rename folder. Please try again.',
        onRetry: () => unawaited(_saveRename(folder, trimmedName)),
      );
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
      final trimmed = result.trim();
      try {
        final folderRepo = ref.read(folderCoreRepositoryProvider);
        final folder = await folderRepo.createFolder(
          name: trimmed,
          parentId: parentId,
        );
        _logger.info(
          'Folder created',
          data: {'folderId': folder.id, 'parentId': parentId, 'name': folder.name},
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
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to create folder',
          error: error,
          stackTrace: stackTrace,
          data: {'parentId': parentId, 'requestedName': trimmed},
        );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
        _showErrorSnackBar(
          'Failed to create folder. Please try again.',
          onRetry: () => unawaited(_createFolder(context, parentId)),
        );
      }
    }
  }

  Future<void> _moveFolder(
    BuildContext context,
    domain.Folder folder,
    List<domain.Folder> allFolders,
  ) async {
    // Filter out the folder itself and its descendants
    // Find available parent folders (excluding self and descendants)
    bool isDescendant(domain.Folder potential, domain.Folder target) {
      var current = potential;
      while (current.parentId != null) {
        if (current.parentId == target.id) return true;
        final parent = allFolders
            .where((f) => f.id == current.parentId)
            .firstOrNull;
        if (parent == null) break;
        current = parent;
      }
      return false;
    }

    final availableParents = <domain.Folder?>[null]; // null = root
    for (final f in allFolders) {
      if (f.id != folder.id && !isDescendant(f, folder)) {
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
              ...availableParents.skip(1).map((parent) {
                // Build path from parent chain
                String buildPath(domain.Folder folder) {
                  final parts = <String>[];
                  var current = folder;
                  while (true) {
                    parts.insert(0, current.name);
                    if (current.parentId == null) break;
                    final parentFolder = allFolders
                        .where((f) => f.id == current.parentId)
                        .firstOrNull;
                    if (parentFolder == null) break;
                    current = parentFolder;
                  }
                  return parts.join(' / ');
                }

                return ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(parent!.name),
                  subtitle: Text(buildPath(parent)),
                  onTap: () => Navigator.pop(context, parent.id),
                );
              }),
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
        final folderRepo = ref.read(folderCoreRepositoryProvider);
        await folderRepo.moveFolder(folder.id, result.isEmpty ? null : result);
        _logger.info(
          'Folder moved',
          data: {
            'folderId': folder.id,
            'newParentId': result.isEmpty ? null : result,
          },
        );
        HapticFeedback.mediumImpact();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Folder moved')));
        }
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to move folder',
          error: error,
          stackTrace: stackTrace,
          data: {
            'folderId': folder.id,
            'targetParentId': result.isEmpty ? null : result,
          },
        );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
        _showErrorSnackBar(
          'Failed to move folder. Please try again.',
          onRetry: () => unawaited(_moveFolder(context, folder, allFolders)),
        );
      }
    }
  }

  Future<void> _deleteFolder(BuildContext context, domain.Folder folder) async {
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
        final folderRepo = ref.read(folderCoreRepositoryProvider);
        await folderRepo.deleteFolder(folder.id);
        _logger.info(
          'Folder deleted',
          data: {'folderId': folder.id, 'folderName': folder.name},
        );
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
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to delete folder',
          error: error,
          stackTrace: stackTrace,
          data: {'folderId': folder.id, 'folderName': folder.name},
        );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
        _showErrorSnackBar(
          'Failed to delete folder. Please try again.',
          onRetry: () => unawaited(_deleteFolder(context, folder)),
        );
      }
    }
  }

  void _showErrorSnackBar(String message, {VoidCallback? onRetry}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}
