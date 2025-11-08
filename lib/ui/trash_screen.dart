import 'dart:async';
import 'package:duru_notes/domain/entities/folder.dart' as domain_folder;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' as domain_task;
import 'package:duru_notes/features/notes/providers/notes_state_providers.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:duru_notes/ui/components/modern_app_bar.dart';
import 'package:duru_notes/services/providers/services_providers.dart'
    show trashServiceProvider;
import 'package:duru_notes/services/trash_service.dart' show BulkDeleteResult;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Trash screen for viewing and managing soft-deleted items
/// Phase 1.1: Soft Delete & Trash System
class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen>
    with TickerProviderStateMixin {
  late AnimationController _listAnimationController;
  bool _isSelectionMode = false;
  final Set<String> _selectedItemIds = {};
  String _selectedTab = 'all'; // 'all', 'notes', 'folders', 'tasks'

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _listAnimationController.forward();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deletedNotesAsync = ref.watch(deletedNotesProvider);
    final deletedFoldersAsync = ref.watch(deletedFoldersProvider);
    final deletedTasksAsync = ref.watch(deletedTasksProvider);

    // Count total items
    final totalCount = (deletedNotesAsync.value?.length ?? 0) +
        (deletedFoldersAsync.value?.length ?? 0) +
        (deletedTasksAsync.value?.length ?? 0);

    return Scaffold(
      appBar: _buildAppBar(totalCount),
      body: Column(
        children: [
          _buildTabBar(
            deletedNotesAsync.value?.length ?? 0,
            deletedFoldersAsync.value?.length ?? 0,
            deletedTasksAsync.value?.length ?? 0,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _buildBody(
                deletedNotesAsync,
                deletedFoldersAsync,
                deletedTasksAsync,
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(int totalCount) {
    if (_isSelectionMode) {
      return ModernAppBar(
        title: '${_selectedItemIds.length} selected',
        subtitle: null,
        showGradient: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark),
          onPressed: _exitSelectionMode,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        actions: [
          ModernAppBarAction(
            icon: CupertinoIcons.arrow_counterclockwise,
            onPressed: _restoreSelected,
            tooltip: 'Restore',
          ),
          ModernAppBarAction(
            icon: CupertinoIcons.trash,
            onPressed: _deleteSelectedPermanently,
            tooltip: 'Delete Forever',
          ),
        ],
      );
    }

    return ModernAppBar(
      title: 'Trash',
      subtitle: totalCount == 0 ? 'Empty' : '$totalCount items',
      showGradient: true,
      actions: [
        if (totalCount > 0)
          ModernAppBarAction(
            icon: CupertinoIcons.ellipsis_circle,
            onPressed: () => _showTrashMenu(context),
            tooltip: 'More options',
          ),
      ],
    );
  }

  Widget _buildTabBar(int notesCount, int foldersCount, int tasksCount) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: DuruSpacing.md),
        child: Row(
          children: [
            _buildTabChip('All', notesCount + foldersCount + tasksCount, 'all'),
            SizedBox(width: DuruSpacing.sm),
            _buildTabChip('Notes', notesCount, 'notes'),
            SizedBox(width: DuruSpacing.sm),
            _buildTabChip('Folders', foldersCount, 'folders'),
            SizedBox(width: DuruSpacing.sm),
            _buildTabChip('Tasks', tasksCount, 'tasks'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(String label, int count, String value) {
    final isSelected = _selectedTab == value;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedTab = value;
            _listAnimationController.reset();
            _listAnimationController.forward();
          });
        }
      },
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: DuruColors.primary.withValues(alpha: 0.1),
      checkmarkColor: DuruColors.primary,
      side: BorderSide(
        color: isSelected
            ? DuruColors.primary
            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<List<domain.Note>> notesAsync,
    AsyncValue<List<domain_folder.Folder>> foldersAsync,
    AsyncValue<List<domain_task.Task>> tasksAsync,
  ) {
    // Handle loading/error states
    if (notesAsync.isLoading || foldersAsync.isLoading || tasksAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notesAsync.hasError || foldersAsync.hasError || tasksAsync.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            SizedBox(height: DuruSpacing.md),
            Text(
              'Failed to load trash items',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: DuruSpacing.sm),
            TextButton(
              onPressed: _refresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final notes = notesAsync.value ?? [];
    final folders = foldersAsync.value ?? [];
    final tasks = tasksAsync.value ?? [];

    // Filter by selected tab
    final List<_DeletedItem> items = [];
    if (_selectedTab == 'all' || _selectedTab == 'notes') {
      items.addAll(notes.map((n) => _DeletedItem(
        id: n.id,
        type: _ItemType.note,
        title: n.title.isEmpty ? 'Untitled Note' : n.title,
        subtitle: _getPreview(n.body),
        deletedAt: n.deletedAt ?? n.updatedAt,
        scheduledPurgeAt: n.scheduledPurgeAt,
        data: n,
      )));
    }
    if (_selectedTab == 'all' || _selectedTab == 'folders') {
      items.addAll(folders.map((f) => _DeletedItem(
        id: f.id,
        type: _ItemType.folder,
        title: f.name,
        subtitle: 'Folder',
        deletedAt: f.deletedAt ?? f.updatedAt,
        scheduledPurgeAt: f.scheduledPurgeAt,
        data: f,
      )));
    }
    if (_selectedTab == 'all' || _selectedTab == 'tasks') {
      items.addAll(tasks.map((t) => _DeletedItem(
        id: t.id,
        type: _ItemType.task,
        title: t.title,
        subtitle: 'Task',
        deletedAt: t.deletedAt ?? t.updatedAt,
        scheduledPurgeAt: t.scheduledPurgeAt,
        data: t,
      )));
    }

    // Sort by deletion time (most recent first)
    items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));

    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        top: DuruSpacing.sm,
        bottom: MediaQuery.of(context).padding.bottom + 100,
        left: DuruSpacing.md,
        right: DuruSpacing.md,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _listAnimationController,
            curve: Curves.easeIn,
          ),
          child: _buildItemCard(item),
        );
      },
    );
  }

  Widget _buildItemCard(_DeletedItem item) {
    final isSelected = _selectedItemIds.contains(item.id);

    return Card(
      margin: EdgeInsets.only(bottom: DuruSpacing.sm),
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            _toggleItemSelection(item.id);
          } else {
            _showItemActions(item);
          }
        },
        onLongPress: () {
          if (!_isSelectionMode) {
            _enterSelectionMode(item.id);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(DuruSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: DuruColors.primary, width: 2)
                : null,
          ),
          child: Row(
            children: [
              // Icon based on type
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getItemColor(item.type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getItemIcon(item.type),
                  color: _getItemColor(item.type),
                  size: 20,
                ),
              ),
              SizedBox(width: DuruSpacing.md),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: DuruSpacing.xs),
                    Text(
                      item.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: DuruSpacing.xs),
                    Text(
                      'Deleted ${_formatDate(item.deletedAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                    if (item.scheduledPurgeAt != null) ...[
                      SizedBox(height: DuruSpacing.xs / 2),
                      Text(
                        _formatPurgeCountdown(item.scheduledPurgeAt!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Selection checkbox or action button
              if (_isSelectionMode)
                Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: isSelected ? DuruColors.primary : null,
                )
              else
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.trash,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          SizedBox(height: DuruSpacing.lg),
          Text(
            'Trash is empty',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: DuruSpacing.sm),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: DuruSpacing.xl),
            child: Text(
              'Deleted items will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  IconData _getItemIcon(_ItemType type) {
    switch (type) {
      case _ItemType.note:
        return CupertinoIcons.doc_text;
      case _ItemType.folder:
        return CupertinoIcons.folder;
      case _ItemType.task:
        return CupertinoIcons.check_mark_circled;
    }
  }

  Color _getItemColor(_ItemType type) {
    switch (type) {
      case _ItemType.note:
        return DuruColors.primary;
      case _ItemType.folder:
        return DuruColors.accent;
      case _ItemType.task:
        return Colors.green;
    }
  }

  String _getPreview(String content) {
    final cleaned = content.replaceAll(RegExp(r'[\n\r\t]'), ' ').trim();
    return cleaned.length > 50 ? '${cleaned.substring(0, 50)}...' : cleaned;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  String _formatPurgeCountdown(DateTime purgeDate) {
    final now = DateTime.now();
    final difference = purgeDate.difference(now);

    if (difference.isNegative) {
      return 'Auto-purge overdue';
    } else if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Auto-purge in ${difference.inMinutes}m';
      }
      return 'Auto-purge in ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Auto-purge in 1 day';
    } else {
      return 'Auto-purge in ${difference.inDays} days';
    }
  }

  // Selection mode methods
  void _enterSelectionMode(String itemId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedItemIds.add(itemId);
    });
  }

  void _toggleItemSelection(String itemId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else {
        _selectedItemIds.add(itemId);
      }

      if (_selectedItemIds.isEmpty) {
        _exitSelectionMode();
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedItemIds.clear();
    });
  }

  // Action methods
  void _showItemActions(_DeletedItem item) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.arrow_counterclockwise),
              title: const Text('Restore'),
              onTap: () {
                Navigator.pop(sheetContext);
                _restoreItem(item);
              },
            ),
            ListTile(
              leading: Icon(
                CupertinoIcons.trash,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete Forever',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteItemPermanently(item);
              },
            ),
            SizedBox(height: DuruSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreItem(_DeletedItem item) async {
    try {
      final trashService = ref.read(trashServiceProvider);
      switch (item.type) {
        case _ItemType.note:
          await trashService.restoreNote(item.id);
          break;
        case _ItemType.folder:
          await trashService.restoreFolder(item.id, restoreContents: false);
          break;
        case _ItemType.task:
          await trashService.restoreTask(item.id);
          break;
      }

      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.title} restored'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteItemPermanently(_DeletedItem item) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Forever?'),
        content: Text(
          'This will permanently delete "${item.title}". This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final trashService = ref.read(trashServiceProvider);
      switch (item.type) {
        case _ItemType.note:
          await trashService.permanentlyDeleteNote(item.id);
          break;
        case _ItemType.folder:
          await trashService.permanentlyDeleteFolder(item.id);
          break;
        case _ItemType.task:
          await trashService.permanentlyDeleteTask(item.id);
          break;
      }

      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.title} permanently deleted'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _restoreSelected() async {
    // Get all selected items from current view
    final notesAsync = ref.read(deletedNotesProvider);
    final foldersAsync = ref.read(deletedFoldersProvider);
    final tasksAsync = ref.read(deletedTasksProvider);

    final items = <_DeletedItem>[];
    if (notesAsync.hasValue) {
      items.addAll(notesAsync.value!
          .where((n) => _selectedItemIds.contains(n.id))
          .map((n) => _DeletedItem(
                id: n.id,
                type: _ItemType.note,
                title: n.title,
                subtitle: '',
                deletedAt: n.deletedAt ?? n.updatedAt,
                scheduledPurgeAt: n.scheduledPurgeAt,
                data: n,
              )));
    }
    if (foldersAsync.hasValue) {
      items.addAll(foldersAsync.value!
          .where((f) => _selectedItemIds.contains(f.id))
          .map((f) => _DeletedItem(
                id: f.id,
                type: _ItemType.folder,
                title: f.name,
                subtitle: '',
                deletedAt: f.deletedAt ?? f.updatedAt,
                scheduledPurgeAt: f.scheduledPurgeAt,
                data: f,
              )));
    }
    if (tasksAsync.hasValue) {
      items.addAll(tasksAsync.value!
          .where((t) => _selectedItemIds.contains(t.id))
          .map((t) => _DeletedItem(
                id: t.id,
                type: _ItemType.task,
                title: t.title,
                subtitle: '',
                deletedAt: t.deletedAt ?? t.updatedAt,
                scheduledPurgeAt: t.scheduledPurgeAt,
                data: t,
              )));
    }

    for (final item in items) {
      await _restoreItem(item);
    }

    _exitSelectionMode();
  }

  Future<void> _deleteSelectedPermanently() async {
    final count = _selectedItemIds.length;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Forever?'),
        content: Text(
          'This will permanently delete $count ${count == 1 ? 'item' : 'items'}. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Get all selected items from current view
    final notesAsync = ref.read(deletedNotesProvider);
    final foldersAsync = ref.read(deletedFoldersProvider);
    final tasksAsync = ref.read(deletedTasksProvider);

    final items = <_DeletedItem>[];
    if (notesAsync.hasValue) {
      items.addAll(notesAsync.value!
          .where((n) => _selectedItemIds.contains(n.id))
          .map((n) => _DeletedItem(
                id: n.id,
                type: _ItemType.note,
                title: n.title,
                subtitle: '',
                deletedAt: n.deletedAt ?? n.updatedAt,
                scheduledPurgeAt: n.scheduledPurgeAt,
                data: n,
              )));
    }
    if (foldersAsync.hasValue) {
      items.addAll(foldersAsync.value!
          .where((f) => _selectedItemIds.contains(f.id))
          .map((f) => _DeletedItem(
                id: f.id,
                type: _ItemType.folder,
                title: f.name,
                subtitle: '',
                deletedAt: f.deletedAt ?? f.updatedAt,
                scheduledPurgeAt: f.scheduledPurgeAt,
                data: f,
              )));
    }
    if (tasksAsync.hasValue) {
      items.addAll(tasksAsync.value!
          .where((t) => _selectedItemIds.contains(t.id))
          .map((t) => _DeletedItem(
                id: t.id,
                type: _ItemType.task,
                title: t.title,
                subtitle: '',
                deletedAt: t.deletedAt ?? t.updatedAt,
                scheduledPurgeAt: t.scheduledPurgeAt,
                data: t,
              )));
    }

    // Delete all selected items
    int successCount = 0;
    int failureCount = 0;
    final trashService = ref.read(trashServiceProvider);

    for (final item in items) {
      try {
        switch (item.type) {
          case _ItemType.note:
            await trashService.permanentlyDeleteNote(item.id);
            break;
          case _ItemType.folder:
            await trashService.permanentlyDeleteFolder(item.id);
            break;
          case _ItemType.task:
            await trashService.permanentlyDeleteTask(item.id);
            break;
        }
        successCount++;
      } catch (e) {
        failureCount++;
      }
    }

    if (!mounted) return;
    _exitSelectionMode();

    if (mounted) {
      _refresh();

      if (failureCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount ${successCount == 1 ? 'item' : 'items'} permanently deleted'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount deleted, $failureCount failed'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(deletedNotesProvider);
    ref.invalidate(deletedFoldersProvider);
    ref.invalidate(deletedTasksProvider);
  }

  void _showTrashMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.trash),
              title: const Text('Empty Trash'),
              subtitle: const Text('Permanently delete all items'),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmEmptyTrash();
              },
            ),
            SizedBox(height: DuruSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmEmptyTrash() async {
    final notesAsync = ref.read(deletedNotesProvider);
    final foldersAsync = ref.read(deletedFoldersProvider);
    final tasksAsync = ref.read(deletedTasksProvider);

    // Check if providers are still loading
    if (!notesAsync.hasValue || !foldersAsync.hasValue || !tasksAsync.hasValue) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading trash items, please wait...')),
        );
      }
      return;
    }

    final totalCount = (notesAsync.value?.length ?? 0) +
        (foldersAsync.value?.length ?? 0) +
        (tasksAsync.value?.length ?? 0);

    if (totalCount == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trash is already empty')),
        );
      }
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: Text(
          'This will permanently delete all $totalCount items in the trash. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Empty Trash'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    BulkDeleteResult? result;
    try {
      result = await ref.read(trashServiceProvider).emptyTrash();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to empty trash: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    _refresh();

    if (result.failureCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trash emptied: ${result.successCount} items permanently deleted'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.successCount} deleted, ${result.failureCount} failed'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

// Helper classes
enum _ItemType { note, folder, task }

class _DeletedItem {
  final String id;
  final _ItemType type;
  final String title;
  final String subtitle;
  final DateTime deletedAt;
  final DateTime? scheduledPurgeAt;
  final Object data;

  _DeletedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.deletedAt,
    this.scheduledPurgeAt,
    required this.data,
  });
}
