import 'package:duru_notes/features/folders/batch_operations/batch_selection_provider.dart';
import 'package:duru_notes/features/folders/folder_picker_component.dart';
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/features/notes/providers/notes_state_providers.dart'
    show currentNotesProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A floating action bar that appears during batch selection mode
class BatchOperationsBar extends ConsumerStatefulWidget {
  const BatchOperationsBar({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  ConsumerState<BatchOperationsBar> createState() => _BatchOperationsBarState();
}

class _BatchOperationsBarState extends ConsumerState<BatchOperationsBar>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _expandController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _expandAnimation;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _expandController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _expandAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _expandController, curve: Curves.easeInOut),
    );

    // Start animations
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() => _isExpanded = !_isExpanded);

    if (_isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }

    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectionState = ref.watch(batchSelectionProvider);
    final capabilities = ref.watch(batchOperationCapabilitiesProvider);
    final operationsState = ref.watch(batchOperationsProvider);

    if (!selectionState.isSelectionMode || selectionState.selectedCount == 0) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main action bar
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Selection count and expand button
                  GestureDetector(
                    onTap: _toggleExpansion,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${capabilities.noteCount}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            capabilities.noteCount == 1 ? 'note' : 'notes',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.expand_more,
                              color: theme.colorScheme.onPrimaryContainer,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Quick actions
                  Expanded(
                    child: Row(
                      children: [
                        // Move to folder
                        _BatchActionButton(
                          icon: Icons.folder_outlined,
                          tooltip: 'Move to folder',
                          onPressed: capabilities.canMove
                              ? _showFolderPicker
                              : null,
                          isLoading: operationsState.isLoading,
                        ),

                        const SizedBox(width: 8),

                        // Delete
                        _BatchActionButton(
                          icon: Icons.delete_outline,
                          tooltip: 'Delete notes',
                          onPressed: capabilities.canDelete
                              ? _confirmDelete
                              : null,
                          isLoading: operationsState.isLoading,
                          isDestructive: true,
                        ),

                        const SizedBox(width: 8),

                        // More actions
                        _BatchActionButton(
                          icon: Icons.more_horiz,
                          tooltip: 'More actions',
                          onPressed: _showMoreActions,
                          isLoading: operationsState.isLoading,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Close button
                  _BatchActionButton(
                    icon: Icons.close,
                    tooltip: 'Exit selection',
                    onPressed: _closeSelection,
                  ),
                ],
              ),
            ),

            // Expanded actions
            AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                return ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: _expandAnimation.value,
                    child: child,
                  ),
                );
              },
              child: _buildExpandedActions(theme, capabilities),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedActions(
    ThemeData theme,
    BatchOperationCapabilities capabilities,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Selection tools
          Row(
            children: [
              Text(
                'Selection',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    _SelectionChip(
                      label: 'All',
                      icon: Icons.select_all,
                      onPressed: _selectAll,
                    ),
                    _SelectionChip(
                      label: 'Clear',
                      icon: Icons.clear_all,
                      onPressed: _clearSelection,
                    ),
                    _SelectionChip(
                      label: 'Invert',
                      icon: Icons.flip_to_back,
                      onPressed: _invertSelection,
                    ),
                    _SelectionChip(
                      label: 'Recent',
                      icon: Icons.history,
                      onPressed: _selectRecent,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Batch actions grid
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            childAspectRatio: 1.2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _BatchActionTile(
                icon: Icons.archive_outlined,
                label: 'Archive',
                enabled: capabilities.canArchive,
                onPressed: () => _toggleArchive(true),
              ),
              _BatchActionTile(
                icon: Icons.unarchive_outlined,
                label: 'Unarchive',
                enabled: capabilities.canUnarchive,
                onPressed: () => _toggleArchive(false),
              ),
              _BatchActionTile(
                icon: Icons.favorite_outline,
                label: 'Favorite',
                enabled: capabilities.canFavorite,
                onPressed: () => _toggleFavorite(true),
              ),
              _BatchActionTile(
                icon: Icons.favorite,
                label: 'Unfavorite',
                enabled: capabilities.canUnfavorite,
                onPressed: () => _toggleFavorite(false),
              ),
              _BatchActionTile(
                icon: Icons.lock_outline,
                label: 'Encrypt',
                enabled: capabilities.canEncrypt,
                onPressed: _encryptNotes,
              ),
              _BatchActionTile(
                icon: Icons.lock_open,
                label: 'Decrypt',
                enabled: capabilities.canDecrypt,
                onPressed: _decryptNotes,
              ),
              _BatchActionTile(
                icon: Icons.share,
                label: 'Share',
                enabled: capabilities.canShare,
                onPressed: _shareNotes,
              ),
              _BatchActionTile(
                icon: Icons.download,
                label: 'Export',
                enabled: capabilities.canExport,
                onPressed: _exportNotes,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _closeSelection() {
    _slideController.reverse().then((_) {
      ref.read(batchSelectionProvider.notifier).exitSelectionMode();
      widget.onClose?.call();
    });
  }

  void _selectAll() {
    final allNotes = ref.read(currentNotesProvider);
    final allIds = allNotes.map((note) => note.id).toList();
    ref.read(batchSelectionProvider.notifier).selectAll(allIds);
  }

  void _clearSelection() {
    ref.read(batchSelectionProvider.notifier).clearSelection();
  }

  void _invertSelection() {
    final allNotes = ref.read(currentNotesProvider);
    final allIds = allNotes.map((note) => note.id).toList();
    ref.read(batchSelectionProvider.notifier).invertSelection(allIds);
  }

  void _selectRecent() {
    final allNotes = ref.read(currentNotesProvider);
    ref.read(batchSelectionProvider.notifier).selectRecentlyModified(allNotes);
  }

  void _showFolderPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FolderPicker(
        title:
            'Move ${ref.read(batchSelectionProvider).selectedCount} notes to...',
        onFolderSelected: (folderId) {
          ref
              .read(batchOperationsProvider.notifier)
              .moveNotesToFolder(folderId);
        },
      ),
    );
  }

  void _confirmDelete() {
    final count = ref.read(batchSelectionProvider).selectedCount;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notes'),
        content: Text(
          'Are you sure you want to delete $count note${count > 1 ? 's' : ''}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(batchOperationsProvider.notifier).deleteSelectedNotes();
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

  void _showMoreActions() {
    // Toggle expansion instead of showing a separate sheet
    _toggleExpansion();
  }

  void _toggleArchive(bool archive) {
    ref
        .read(batchOperationsProvider.notifier)
        .toggleArchiveSelectedNotes(archive);
  }

  void _toggleFavorite(bool favorite) {
    ref
        .read(batchOperationsProvider.notifier)
        .toggleFavoriteSelectedNotes(favorite);
  }

  void _encryptNotes() {
    // TODO: Implement encryption
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Encryption feature coming soon!')),
    );
  }

  void _decryptNotes() {
    // TODO: Implement decryption
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Decryption feature coming soon!')),
    );
  }

  void _shareNotes() {
    ref.read(batchOperationsProvider.notifier).shareSelectedNotes();
  }

  void _exportNotes() {
    // Show export format options
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('Markdown'),
              onTap: () {
                Navigator.of(context).pop();
                ref
                    .read(batchOperationsProvider.notifier)
                    .exportSelectedNotes('markdown');
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('PDF'),
              onTap: () {
                Navigator.of(context).pop();
                ref
                    .read(batchOperationsProvider.notifier)
                    .exportSelectedNotes('pdf');
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('JSON'),
              onTap: () {
                Navigator.of(context).pop();
                ref
                    .read(batchOperationsProvider.notifier)
                    .exportSelectedNotes('json');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchActionButton extends StatelessWidget {
  const _BatchActionButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.isLoading = false,
    this.isDestructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDestructive
              ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Icon(
                    icon,
                    color: isDestructive
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.5,
      ),
      side: BorderSide.none,
      labelStyle: theme.textTheme.labelSmall,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

class _BatchActionTile extends StatelessWidget {
  const _BatchActionTile({
    required this.icon,
    required this.label,
    required this.enabled,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: enabled
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: enabled
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: enabled
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
