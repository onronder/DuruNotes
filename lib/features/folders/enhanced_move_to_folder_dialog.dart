import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/create_folder_dialog.dart';
import 'package:duru_notes/features/folders/folder_icon_helpers.dart';
import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/features/folders/note_folder_integration_service.dart';
import 'package:duru_notes/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Enhanced dialog for moving notes to folders with progress tracking
class EnhancedMoveToFolderDialog extends ConsumerStatefulWidget {
  const EnhancedMoveToFolderDialog({
    super.key,
    required this.noteIds,
    required this.onMoveCompleted,
    this.currentFolderId,
  });

  final List<String> noteIds;
  final Function(BatchMoveResult result) onMoveCompleted;
  final String? currentFolderId;

  @override
  ConsumerState<EnhancedMoveToFolderDialog> createState() =>
      _EnhancedMoveToFolderDialogState();
}

class _EnhancedMoveToFolderDialogState
    extends ConsumerState<EnhancedMoveToFolderDialog>
    with TickerProviderStateMixin {
  final _logger = LoggerFactory.instance;
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _selectedFolderId;
  bool _isMoving = false;
  double _moveProgress = 0.0;
  List<String> _recentFolders = [];
  bool _showCreateFolderSection = false;

  late AnimationController _progressAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeIn),
    );

    _fadeAnimationController.forward();

    _loadRecentFolders();

    // Ensure folders are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(folderHierarchyProvider.notifier).loadFolders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _progressAnimationController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentFolders() async {
    try {
      final service = ref.read(noteFolderIntegrationServiceProvider);
      final recentFolders = await service.getRecentFolders();

      if (mounted) {
        setState(() {
          _recentFolders = recentFolders;
        });
      }

      _logger.debug('Loaded recent folders for move dialog', data: {
        'count': recentFolders.length,
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to load recent folders for move dialog',
        error: e,
        stackTrace: stackTrace,
      );

      await Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hierarchyState = ref.watch(folderHierarchyProvider);
    final visibleNodes = ref.watch(visibleFolderNodesProvider);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.folder_copy_rounded,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Move ${widget.noteIds.length} note${widget.noteIds.length == 1 ? '' : 's'}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: _isMoving ? _buildProgressContent(theme) : _buildSelectionContent(theme, hierarchyState, visibleNodes),
        actions: _isMoving ? null : _buildActions(theme),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      ),
    );
  }

  Widget _buildProgressContent(ThemeData theme) {
    return SizedBox(
      width: 300,
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: _moveProgress,
            strokeWidth: 3,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 16),
          Text(
            'Moving notes...',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_moveProgress * 100).toInt()}% complete',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionContent(
    ThemeData theme,
    FolderHierarchyState hierarchyState,
    List<FolderTreeNode> visibleNodes,
  ) {
    return SizedBox(
      width: 400,
      height: 500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Semantics(
            label: 'Search folders',
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search folders...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(folderHierarchyProvider.notifier)
                              .clearSearch();
                        },
                        tooltip: 'Clear search',
                      )
                    : null,
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

          const SizedBox(height: 16),

          // Recent folders section
          if (_recentFolders.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.history,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent folders',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildRecentFoldersSection(theme),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
          ],

          // All folders section
          Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'All folders',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showCreateFolderSection = !_showCreateFolderSection;
                  });
                },
                icon: Icon(
                  _showCreateFolderSection ? Icons.expand_less : Icons.add,
                  size: 18,
                ),
                label: Text(_showCreateFolderSection ? 'Hide' : 'New'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(60, 32),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Create folder section
          if (_showCreateFolderSection) ...[
            _buildCreateFolderSection(theme),
            const SizedBox(height: 16),
          ],

          // Folder list
          Expanded(
            child: hierarchyState.isLoading
                ? _buildLoadingState(theme)
                : hierarchyState.error != null
                    ? _buildErrorState(theme, hierarchyState.error!)
                    : _buildFoldersList(theme, visibleNodes),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentFoldersSection(ThemeData theme) {
    final foldersAsync = ref.watch(rootFoldersProvider);

    return foldersAsync.when(
      data: (allFolders) {
        final recentFolderObjects = _recentFolders
            .map((id) => allFolders.where((f) => f.id == id).firstOrNull)
            .where((f) => f != null)
            .cast<LocalFolder>()
            .toList();

        if (recentFolderObjects.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recentFolderObjects.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final folder = recentFolderObjects[index];
              final isSelected = _selectedFolderId == folder.id;

              return Semantics(
                label: 'Recent folder ${folder.name}, ${isSelected ? 'selected' : 'not selected'}',
                selected: isSelected,
                button: true,
                child: FilterChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        FolderIconHelpers.getFolderIcon(folder.icon),
                        size: 16,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : FolderIconHelpers.getFolderColor(folder.color),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        folder.name,
                        style: TextStyle(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                  onSelected: (selected) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedFolderId = selected ? folder.id : null;
                    });
                  },
                  backgroundColor: isSelected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  side: BorderSide(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCreateFolderSection(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.create_new_folder,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Create a new folder',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            FilledButton.tonal(
              onPressed: _showCreateFolderDialog,
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return const Center(
      child: CircularProgressIndicator(),
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
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildFoldersList(ThemeData theme, List<FolderTreeNode> nodes) {
    if (nodes.isEmpty) {
      return _buildEmptyState(theme);
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: nodes.length + 1, // +1 for "Unfiled" option
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildUnfiledOption(theme);
        }

        final node = nodes[index - 1];
        return _buildFolderItem(theme, node);
      },
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
            'No folders found',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first folder to organize notes',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUnfiledOption(ThemeData theme) {
    final isSelected = _selectedFolderId == null;

    return Semantics(
      label: 'Unfiled option, ${isSelected ? 'selected' : 'not selected'}. Remove notes from any folder.',
      selected: isSelected,
      button: true,
      child: Card(
        elevation: isSelected ? 2 : 0,
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : null,
        child: ListTile(
          leading: Icon(
            Icons.folder_off_outlined,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(
            'Unfiled',
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : null,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
          subtitle: const Text('Remove from any folder'),
          selected: isSelected,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedFolderId = null;
            });
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildFolderItem(ThemeData theme, FolderTreeNode node) {
    final isSelected = _selectedFolderId == node.folder.id;
    final isCurrent = widget.currentFolderId == node.folder.id;
    final indentWidth = node.level * 24.0;

    return Semantics(
      label: 'Folder ${node.folder.name}${isCurrent ? ', current folder' : ''}${isSelected ? ', selected' : ''}${node.noteCount > 0 ? ', ${node.noteCount} notes' : ''}',
      selected: isSelected,
      button: !isCurrent,
      excludeSemantics: true,
      child: Card(
        elevation: isSelected ? 2 : 0,
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : null,
        child: ListTile(
          contentPadding: EdgeInsets.only(left: 16 + indentWidth, right: 16),
          enabled: !isCurrent,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (node.hasChildren)
                Semantics(
                  label: '${node.isExpanded ? 'Collapse' : 'Expand'} ${node.folder.name} folder',
                  button: true,
                  child: IconButton(
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
                  ),
                )
              else
                const SizedBox(width: 24),
              Icon(
                FolderIconHelpers.getFolderIcon(node.folder.icon),
                color: isCurrent
                    ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                    : FolderIconHelpers.getFolderColor(node.folder.color) ??
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
              color: isCurrent
                  ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                  : isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : null,
            ),
          ),
          subtitle: isCurrent ? const Text('Current folder') : null,
          trailing: node.noteCount > 0
              ? Chip(
                  label: Text(node.noteCount.toString()),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  labelStyle: theme.textTheme.labelSmall,
                )
              : null,
          selected: isSelected,
          onTap: isCurrent
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedFolderId = node.folder.id;
                  });
                },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(ThemeData theme) {
    final isDisabled = _selectedFolderId == widget.currentFolderId;
    final actionText = _selectedFolderId == null ? 'Remove from folder' : 'Move to folder';

    return [
      Semantics(
        label: 'Cancel move operation',
        button: true,
        child: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
      Semantics(
        label: isDisabled ? 'Cannot move to current folder' : '$actionText for ${widget.noteIds.length} note${widget.noteIds.length == 1 ? '' : 's'}',
        button: !isDisabled,
        excludeSemantics: true,
        child: FilledButton(
          onPressed: isDisabled ? null : () => _moveNotes(),
          child: Text(actionText),
        ),
      ),
    ];
  }

  Future<void> _showCreateFolderDialog() async {
    try {
      final result = await showDialog<LocalFolder>(
        context: context,
        builder: (context) => const CreateFolderDialog(),
      );

      if (result != null && mounted) {
        // Select the newly created folder immediately
        setState(() {
          _selectedFolderId = result.id;
        });

        // Refresh folder hierarchy
        ref.read(folderHierarchyProvider.notifier).refresh();
        ref.invalidate(rootFoldersProvider);

        _logger.info('Created new folder in move dialog', data: {
          'folderId': result.id,
          'folderName': result.name,
        });
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to create folder in move dialog',
        error: e,
        stackTrace: stackTrace,
      );

      await Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  Future<void> _moveNotes() async {
    if (_isMoving) return;

    setState(() {
      _isMoving = true;
      _moveProgress = 0.0;
    });

    try {
      final service = ref.read(noteFolderIntegrationServiceProvider);

      final result = await service.moveNotesToFolder(
        noteIds: widget.noteIds,
        folderId: _selectedFolderId,
        onProgress: (progress) {
          setState(() {
            _moveProgress = progress;
          });
        },
      );

      if (mounted) {
        widget.onMoveCompleted(result);
        Navigator.of(context).pop();
      }

      _logger.info('Completed move operation in dialog', data: {
        'noteCount': widget.noteIds.length,
        'targetFolderId': _selectedFolderId,
        'successCount': result.successCount,
        'errorCount': result.errorCount,
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to move notes in dialog',
        error: e,
        stackTrace: stackTrace,
        data: {
          'noteIds': widget.noteIds,
          'targetFolderId': _selectedFolderId,
        },
      );

      await Sentry.captureException(e, stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          _isMoving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to move notes: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}