import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/create_folder_dialog.dart';
import 'package:duru_notes/features/folders/edit_folder_dialog.dart';
import 'package:duru_notes/features/folders/folder_hierarchy_view.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/features/folders/folder_icon_helpers.dart';

/// Comprehensive folder management screen with full CRUD operations
class FolderManagementScreen extends ConsumerStatefulWidget {
  const FolderManagementScreen({super.key});

  @override
  ConsumerState<FolderManagementScreen> createState() => _FolderManagementScreenState();
}

class _FolderManagementScreenState extends ConsumerState<FolderManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  LocalFolder? _selectedFolder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load folders when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(folderProvider.notifier).refresh();
      ref.read(folderHierarchyProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.folderManagement),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          // Bulk actions menu
          Consumer(
            builder: (context, ref, child) {
              final folderState = ref.watch(folderProvider);
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                enabled: !folderState.isLoading,
                onSelected: (value) async {
                  switch (value) {
                    case 'create_root_folder':
                      await _showCreateFolderDialog();
                    case 'expand_all':
                      ref.read(folderHierarchyProvider.notifier).expandAll();
                    case 'collapse_all':
                      ref.read(folderHierarchyProvider.notifier).collapseAll();
                    case 'health_check':
                      await _performHealthCheck();
                    case 'validate_structure':
                      await _validateFolderStructure();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'create_root_folder',
                    child: ListTile(
                      leading: const Icon(Icons.create_new_folder),
                      title: Text(l10n.createNewFolder),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'expand_all',
                    child: ListTile(
                      leading: const Icon(Icons.unfold_more),
                      title: Text(l10n.expandAll),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'collapse_all',
                    child: ListTile(
                      leading: const Icon(Icons.unfold_less),
                      title: Text(l10n.collapseAll),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'health_check',
                    child: ListTile(
                      leading: Icon(Icons.health_and_safety),
                      title: Text('Health Check'),
                      subtitle: Text('Validate folder system integrity'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'validate_structure',
                    child: ListTile(
                      leading: Icon(Icons.account_tree),
                      title: Text('Repair Structure'),
                      subtitle: Text('Fix orphaned folders and paths'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.account_tree),
              text: l10n.allFolders,
            ),
            const Tab(
              icon: Icon(Icons.info_outline),
              text: 'Details',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Folder hierarchy tab
          RefreshIndicator(
            onRefresh: () async {
              await ref.read(folderProvider.notifier).refresh();
              await ref.read(folderHierarchyProvider.notifier).refresh();
            },
            child: FolderHierarchyView(
              onFolderTap: (folder) {
                setState(() {
                  _selectedFolder = folder;
                });
                // Switch to details tab
                _tabController.animateTo(1);
              },
              onFolderLongPress: _showFolderActions,
              selectedFolderId: _selectedFolder?.id,
            ),
          ),
          
          // Folder details tab
          if (_selectedFolder != null) _FolderDetailsView(
                  folder: _selectedFolder!,
                  onFolderUpdated: () {
                    ref.read(folderProvider.notifier).refresh();
                    ref.read(folderHierarchyProvider.notifier).refresh();
                  },
                  onFolderDeleted: () {
                    setState(() {
                      _selectedFolder = null;
                    });
                    _tabController.animateTo(0);
                  },
                ) else _EmptyDetailsView(
                  onCreateFolder: _showCreateFolderDialog,
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateFolderDialog,
        icon: const Icon(Icons.create_new_folder),
        label: Text(l10n.createNewFolder),
      ),
    );
  }

  Future<void> _showCreateFolderDialog([LocalFolder? parent]) async {
    final result = await showDialog<LocalFolder>(
      context: context,
      builder: (context) => CreateFolderDialog(parentFolder: parent),
    );
    
    if (result != null && mounted) {
      ref.read(folderProvider.notifier).refresh();
      ref.read(folderHierarchyProvider.notifier).refresh();
      setState(() {
        _selectedFolder = result;
      });
      _tabController.animateTo(1);
    }
  }

  Future<void> _showFolderActions(LocalFolder folder) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _FolderActionsSheet(folder: folder),
    );
    
    switch (result) {
      case 'edit':
        await _editFolder(folder);
      case 'create_subfolder':
        await _showCreateFolderDialog(folder);
      case 'move':
        await _moveFolder(folder);
      case 'delete':
        await _confirmDeleteFolder(folder);
      case 'properties':
        setState(() {
          _selectedFolder = folder;
        });
        _tabController.animateTo(1);
    }
  }

  Future<void> _editFolder(LocalFolder folder) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditFolderDialog(folder: folder),
    );
    
    if (result ?? false && mounted) {
      ref.read(folderProvider.notifier).refresh();
      ref.read(folderHierarchyProvider.notifier).refresh();
      // Update selected folder if it was the one being edited
      if (_selectedFolder?.id == folder.id) {
        final updatedFolder = await ref.read(notesRepositoryProvider).getFolder(folder.id);
        setState(() {
          _selectedFolder = updatedFolder;
        });
      }
    }
  }

  Future<void> _moveFolder(LocalFolder folder) async {
    final l10n = AppLocalizations.of(context);
    
    // Show folder picker excluding the folder itself and its descendants
    final targetFolder = await showDialog<LocalFolder?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.moveFolder),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select where to move "${folder.name}":'),
            const SizedBox(height: 16),
            // We would need a custom folder picker here that excludes descendants
            const Text('Folder picker with exclusions would go here'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    
    if (targetFolder != null) {
      final success = await ref.read(folderProvider.notifier).moveFolder(
        folder.id,
        targetFolder.id,
      );
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved "${folder.name}" to "${targetFolder.name}"')),
        );
      }
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: FolderIconHelpers.getFolderColor(folder.color) ?? Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      FolderIconHelpers.getFolderIcon(folder.icon),
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      folder.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
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
        // Clear selection if deleted folder was selected
        if (_selectedFolder?.id == folder.id) {
          setState(() {
            _selectedFolder = null;
          });
          _tabController.animateTo(0);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted folder "${folder.name}"'),
              backgroundColor: Colors.red,
            ),
          );
        }
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

  Future<void> _performHealthCheck() async {
    final repo = ref.read(notesRepositoryProvider);
    
    try {
      final healthStats = await repo.performFolderHealthCheck();
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Folder Health Check'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHealthStatRow('Total Folders', healthStats['total_folders'].toString()),
                  _buildHealthStatRow('Active Folders', healthStats['active_folders'].toString()),
                  _buildHealthStatRow('Deleted Folders', healthStats['deleted_folders'].toString()),
                  _buildHealthStatRow('Root Folders', healthStats['root_folders'].toString()),
                  _buildHealthStatRow('Orphaned Folders', healthStats['orphaned_folders'].toString()),
                  _buildHealthStatRow('Total Relationships', healthStats['total_relationships'].toString()),
                  _buildHealthStatRow('Orphaned Relationships', healthStats['orphaned_relationships'].toString()),
                  _buildHealthStatRow('Notes with Folders', healthStats['notes_with_folders'].toString()),
                  _buildHealthStatRow('Unfiled Notes', healthStats['unfiled_notes'].toString()),
                  _buildHealthStatRow('Max Depth', healthStats['max_depth'].toString()),
                  
                  if (healthStats['issues_found'] != null && (healthStats['issues_found'] as List).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Issues Found:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...(healthStats['issues_found'] as List).map<Widget>((issue) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(child: Text(issue.toString())),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
            actions: [
              if (healthStats['issues_found'] != null && (healthStats['issues_found'] as List).isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _validateFolderStructure();
                  },
                  child: const Text('Repair Issues'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Health check failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildHealthStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _validateFolderStructure() async {
    final repo = ref.read(notesRepositoryProvider);
    
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator.adaptive(),
              SizedBox(width: 16),
              Text('Repairing folder structure...'),
            ],
          ),
        ),
      );
      
      await repo.validateAndRepairFolderStructure();
      await repo.cleanupOrphanedRelationships();
      await repo.resolveFolderConflicts();
      
      // Refresh our providers
      await ref.read(folderProvider.notifier).refresh();
      await ref.read(folderHierarchyProvider.notifier).refresh();
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Folder structure repaired successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Structure repair failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
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
            leading: const Icon(Icons.visibility),
            title: Text(l10n.folderProperties),
            subtitle: const Text('View folder details and statistics'),
            onTap: () => Navigator.of(context).pop('properties'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.editFolder),
            subtitle: const Text('Change name, color, or parent folder'),
            onTap: () => Navigator.of(context).pop('edit'),
          ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('Create Subfolder'),
            subtitle: Text('Add a new folder inside "${folder.name}"'),
            onTap: () => Navigator.of(context).pop('create_subfolder'),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_move_outlined),
            title: Text(l10n.moveFolder),
            subtitle: const Text('Move folder to a different location'),
            onTap: () => Navigator.of(context).pop('move'),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: colorScheme.error),
            title: Text(l10n.deleteFolder, style: TextStyle(color: colorScheme.error)),
            subtitle: const Text('Permanently delete this folder'),
            onTap: () => Navigator.of(context).pop('delete'),
          ),
        ],
      ),
    );
  }
}

class _FolderDetailsView extends ConsumerWidget {
  const _FolderDetailsView({
    required this.folder,
    required this.onFolderUpdated,
    required this.onFolderDeleted,
  });

  final LocalFolder folder;
  final VoidCallback onFolderUpdated;
  final VoidCallback onFolderDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Folder header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: FolderIconHelpers.getFolderColor(folder.color) ?? colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          FolderIconHelpers.getFolderIcon(folder.icon),
                          color: FolderIconHelpers.getFolderColor(folder.color) != null
                              ? Colors.white
                              : colorScheme.onPrimaryContainer,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              folder.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              folder.path,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  if (folder.description.isNotEmpty ?? false) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        folder.description,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statistics',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<Map<String, int>>(
                    future: _getFolderStats(ref, folder),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator.adaptive());
                      }
                      
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }
                      
                      final stats = snapshot.data ?? {};
                      return Column(
                        children: [
                          _buildStatRow(context, 'Notes in Folder', stats['notes'] ?? 0),
                          _buildStatRow(context, 'Subfolders', stats['subfolders'] ?? 0),
                          _buildStatRow(context, 'Total Descendants', stats['totalDescendants'] ?? 0),
                          _buildStatRow(context, 'Depth Level', stats['depth'] ?? 0),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Properties
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Properties',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPropertyRow(context, 'ID', folder.id),
                  _buildPropertyRow(context, 'Parent ID', folder.parentId ?? 'None (Root Level)'),
                  _buildPropertyRow(context, 'Sort Order', folder.sortOrder.toString()),
                  _buildPropertyRow(context, 'Created', _formatDateTime(folder.createdAt)),
                  _buildPropertyRow(context, 'Modified', _formatDateTime(folder.updatedAt)),
                  _buildPropertyRow(context, 'Status', folder.deleted ? 'Deleted' : 'Active'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editFolder(context, ref),
                  icon: const Icon(Icons.edit),
                  label: Text(l10n.editFolder),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _deleteFolder(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete),
                  label: Text(l10n.deleteFolder),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value.toString(),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, int>> _getFolderStats(WidgetRef ref, LocalFolder folder) async {
    final repo = ref.read(notesRepositoryProvider);
    
    // Get notes count
    final noteIds = await repo.db.getNoteIdsInFolder(folder.id);
    final notesCount = noteIds.length;
    
    // Get subfolders count
    final subfolders = await repo.getChildFolders(folder.id);
    final subfoldersCount = subfolders.length;
    
    // Get total descendants (recursive)
    final subtree = await repo.db.getFolderSubtree(folder.id);
    final totalDescendants = subtree.length - 1; // Subtract the folder itself
    
    // Get depth
    final depth = await repo.db.getFolderDepth(folder.id);
    
    return {
      'notes': notesCount,
      'subfolders': subfoldersCount,
      'totalDescendants': totalDescendants,
      'depth': depth,
    };
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _editFolder(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditFolderDialog(folder: folder),
    );
    
    if (result ?? false) {
      onFolderUpdated();
    }
  }

  Future<void> _deleteFolder(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDeleteFolder),
        content: Text(l10n.confirmDeleteFolderMessage),
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
    
    if (confirmed ?? false) {
      final success = await ref.read(folderProvider.notifier).deleteFolder(folder.id);
      
      if (success) {
        onFolderDeleted();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted folder "${folder.name}"')),
          );
        }
      }
    }
  }
}

class _EmptyDetailsView extends StatelessWidget {
  const _EmptyDetailsView({required this.onCreateFolder});

  final VoidCallback onCreateFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 80,
              color: colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'Select a Folder',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a folder from the hierarchy to view its details and manage its properties.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateFolder,
              icon: const Icon(Icons.create_new_folder),
              label: const Text('Create First Folder'),
            ),
          ],
        ),
      ),
    );
  }
}
