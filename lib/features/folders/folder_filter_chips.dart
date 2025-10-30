import 'package:duru_notes/core/accessibility_utils.dart';
import 'package:duru_notes/core/animation_config.dart';
import 'package:duru_notes/core/debounce_utils.dart';
import 'package:duru_notes/core/haptic_utils.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/features/folders/folder_icon_helpers.dart';
import 'package:duru_notes/features/folders/folder_picker_sheet.dart';
import 'package:duru_notes/features/folders/providers/folders_integration_providers.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart';
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart';
import 'package:duru_notes/features/notes/providers/notes_providers.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/services/providers/services_providers.dart'
    show undoRedoServiceProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Material 3 filter chips for folder navigation
class FolderFilterChips extends ConsumerStatefulWidget {
  const FolderFilterChips({
    super.key,
    this.onFolderSelected,
    this.showCreateOption = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final ValueChanged<domain.Folder?>? onFolderSelected;
  final bool showCreateOption;
  final EdgeInsets padding;

  @override
  ConsumerState<FolderFilterChips> createState() => _FolderFilterChipsState();
}

class _FolderFilterChipsState extends ConsumerState<FolderFilterChips>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: AnimationConfig.standard,
      vsync: this,
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Auto-scroll to selected chip when selection changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedChip();
    });

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _slideController,
              curve: Curves.easeOutCubic,
            ),
          ),
      child: Container(
        height: AccessibilityUtils.minTouchTarget + 12, // 44dp + padding
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Consumer(
          builder: (context, ref, child) {
            final currentFolder = ref.watch(currentFolderProvider);
            final rootFoldersAsync = ref.watch(rootFoldersProvider);
            final unfiledCountAsync = ref.watch(unfiledNotesCountProvider);

            // Debounce UI updates to animation frame
            DebounceUtils.debounceFrame('folder_chips_update', () {
              if (mounted) setState(() {});
            });

            return ListView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: widget.padding,
              physics: const ClampingScrollPhysics(),
              children: [
                // All Notes chip - Now a drop target for unfiling notes
                _AllNotesDropTarget(
                  label: l10n.notesListTitle,
                  icon: Icons.notes,
                  isSelected:
                      currentFolder == null &&
                      !ref.watch(isInboxFilterActiveProvider),
                  onSelected: () {
                    HapticUtils.selection();
                    // Clear folder filter by updating current folder to null
                    widget.onFolderSelected?.call(null);
                    ref.read(isInboxFilterActiveProvider.notifier).state =
                        false;
                  },
                ),

                const SizedBox(width: 8),

                // Inbox preset chip - Shows incoming mail folder with live count
                _InboxPresetChip(),

                const SizedBox(width: 8),

                // Unfiled Notes chip
                unfiledCountAsync.when(
                  data: (count) => count > 0
                      ? _FilterChip(
                          label: l10n.unfiledNotes,
                          icon: Icons.folder_off_outlined,
                          count: count,
                          isSelected: false, // Special case for unfiled
                          onSelected: () async {
                            // Show only unfiled notes
                            widget.onFolderSelected?.call(null);
                          },
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox(width: 8),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                const SizedBox(width: 8),

                // Root folders
                rootFoldersAsync.when(
                  data: (folders) => Row(
                    children: folders.map((folder) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FolderChip(
                          folder: folder,
                          isSelected: currentFolder?.id == folder.id,
                          onSelected: () async {
                            widget.onFolderSelected?.call(folder);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  loading: _SkeletonChips.new,
                  error: (_, _) => const SizedBox.shrink(),
                ),

                // Browse all folders chip
                _FilterChip(
                  label: l10n.allFolders,
                  icon: Icons.folder_outlined,
                  isSelected: false,
                  onSelected: _showFolderPicker,
                ),

                // New Folder chip (trailing)
                if (widget.showCreateOption) ...[
                  const SizedBox(width: 8),
                  _ActionChip(
                    label: l10n.newFolder,
                    icon: Icons.create_new_folder_outlined,
                    onPressed: () => _showCreateFolderSheet(context),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _scrollToSelectedChip() {
    // Calculate approximate position of selected chip
    // This is a simple implementation - could be enhanced with actual measurements
    if (_scrollController.hasClients) {
      // Don't auto-scroll for now to avoid jarring UX
      // Could implement smooth scrolling to selected chip in future
    }
  }

  Future<void> _showCreateFolderSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
          ),
          child: const _CreateFolderSheet(),
        );
      },
    );
  }

  Future<void> _showFolderPicker({bool showCreate = false}) async {
    final selectedFolder = await showFolderPicker(
      context,
      selectedFolderId: ref.read(currentFolderProvider)?.id,
    );

    if (selectedFolder != null && mounted) {
      widget.onFolderSelected?.call(selectedFolder);
    } else if (selectedFolder == null && mounted) {
      // User selected "Unfiled" option
      widget.onFolderSelected?.call(null);
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onSelected,
    this.count,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onSelected;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semanticLabel = count != null
        ? '$label, $count items, ${isSelected ? "Selected" : "Not selected"}'
        : '$label, ${isSelected ? "Selected" : "Not selected"}';

    return AccessibilityUtils.semanticChip(
      label: semanticLabel,
      selected: isSelected,
      onTap: onSelected,
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(label),
            if (count != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.onSecondaryContainer.withValues(alpha: 0.2)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        selected: isSelected,
        onSelected: (_) {
          HapticUtils.selection();
          onSelected();
          AccessibilityUtils.announce(context, '$label selected');
        },
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.secondaryContainer,
        side: BorderSide(
          color: isSelected ? Colors.transparent : colorScheme.outline,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _FolderChip extends ConsumerStatefulWidget {
  const _FolderChip({
    required this.folder,
    required this.isSelected,
    required this.onSelected,
  });

  final domain.Folder folder;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  ConsumerState<_FolderChip> createState() => _FolderChipState();
}

class _FolderChipState extends ConsumerState<_FolderChip> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    // Get note count for this folder
    return FutureBuilder<int>(
      future: ref
          .read(notesCoreRepositoryProvider)
          .getNotesCountInFolder(widget.folder.id),
      builder: (context, snapshot) {
        final noteCount = snapshot.data ?? 0;
        final semanticLabel = noteCount > 0
            ? '${widget.folder.name} folder, $noteCount notes, ${widget.isSelected ? "Selected" : "Not selected"}'
            : '${widget.folder.name} folder, ${widget.isSelected ? "Selected" : "Not selected"}';

        return AccessibilityUtils.semanticChip(
          label: semanticLabel,
          selected: widget.isSelected,
          onTap: widget.onSelected,
          child: GestureDetector(
            onLongPress: () => _showFolderActions(context, l10n),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color:
                          FolderIconHelpers.getFolderColor(
                            widget.folder.color,
                          ) ??
                          colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      FolderIconHelpers.getFolderIcon(widget.folder.icon),
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(widget.folder.name),
                  if (noteCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? colorScheme.onSecondaryContainer.withValues(
                                alpha: 0.2,
                              )
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        noteCount.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: widget.isSelected
                              ? colorScheme.onSecondaryContainer
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: widget.isSelected,
              onSelected: (_) {
                HapticUtils.selection();
                widget.onSelected();
                AccessibilityUtils.announce(
                  context,
                  '${widget.folder.name} folder selected',
                );
              },
              backgroundColor: colorScheme.surface,
              selectedColor: colorScheme.secondaryContainer,
              side: BorderSide(
                color: widget.isSelected
                    ? Colors.transparent
                    : colorScheme.outline,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              tooltip: widget.folder.name,
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFolderActions(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    // Haptic feedback
    await HapticUtils.selection();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Folder name header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  widget.folder.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1),
              // Action items
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.rename),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _renameFolder(context, l10n);
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: Text(l10n.move),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _moveFolder(context, l10n);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  l10n.delete,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: Text(l10n.folderDeleteDescription),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _deleteFolder(context, l10n);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _renameFolder(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final controller = TextEditingController(text: widget.folder.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.renameFolder),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.folderName,
                  errorText: errorText,
                ),
                onChanged: (value) {
                  if (errorText != null) {
                    setState(() => errorText = null);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) {
                      setState(() => errorText = l10n.folderNameEmpty);
                      return;
                    }

                    // Check for duplicate name among siblings
                    final siblings = widget.folder.parentId != null
                        ? await ref
                              .read(folderCoreRepositoryProvider)
                              .getChildFolders(widget.folder.parentId!)
                        : await ref
                              .read(folderCoreRepositoryProvider)
                              .getRootFolders();
                    final isDuplicate = siblings.any(
                      (f) => f.id != widget.folder.id && f.name == name,
                    );

                    if (isDuplicate) {
                      setState(() => errorText = l10n.folderNameDuplicate);
                      return;
                    }

                    Navigator.pop(dialogContext, name);
                  },
                  child: Text(l10n.rename),
                ),
              ],
            );
          },
        );
      },
    );

    if (newName != null && newName != widget.folder.name) {
      try {
        await ref
            .read(folderCoreRepositoryProvider)
            .renameFolder(widget.folder.id, newName);

        await HapticUtils.success();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.folderRenamed),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorRenamingFolder),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    controller.dispose();
  }

  Future<void> _moveFolder(BuildContext context, AppLocalizations l10n) async {
    final selectedParentId = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return _ParentFolderPicker(
              currentFolder: widget.folder,
              scrollController: scrollController,
            );
          },
        );
      },
    );

    if (selectedParentId != null &&
        selectedParentId != widget.folder.parentId) {
      try {
        await ref
            .read(folderCoreRepositoryProvider)
            .moveFolder(
              widget.folder.id,
              selectedParentId == 'root' ? null : selectedParentId,
            );

        await HapticUtils.success();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.folderMoved),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().contains('descendant')
                    ? l10n.cannotMoveToDescendant
                    : l10n.errorMovingFolder,
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteFolder(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.deleteFolder),
          content: Text(l10n.deleteFolderConfirmation(widget.folder.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );

    if (confirmed ?? false) {
      try {
        final currentFolder = ref.read(currentFolderProvider);
        final wasSelected = currentFolder?.id == widget.folder.id;

        await ref
            .read(folderCoreRepositoryProvider)
            .deleteFolder(widget.folder.id);

        await HapticUtils.success();

        if (wasSelected) {
          // Auto-select "All Notes" if deleted folder was selected
          ref.read(currentFolderProvider.notifier).clearCurrentFolder();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.folderDeletedNotesMovedToInbox),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorDeletingFolder),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AccessibilityUtils.semanticButton(
      label: label,
      hint: 'Double tap to $label',
      onTap: onPressed,
      child: ActionChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: colorScheme.primary)),
          ],
        ),
        onPressed: () {
          HapticUtils.tap();
          onPressed();
        },
        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

/// Breadcrumb navigation for folder hierarchy
class FolderBreadcrumb extends ConsumerWidget {
  const FolderBreadcrumb({
    super.key,
    this.currentFolder,
    this.onFolderTap,
    this.maxWidth = 300,
    this.showHomeIcon = true,
  });

  final domain.Folder? currentFolder;
  final ValueChanged<domain.Folder?>? onFolderTap;
  final double maxWidth;
  final bool showHomeIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (currentFolder == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FutureBuilder<List<domain.Folder>>(
        future: _buildBreadcrumbPath(ref, currentFolder!),
        builder: (context, snapshot) {
          final path = snapshot.data ?? [currentFolder!];

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Home icon (optional)
                if (showHomeIcon)
                  GestureDetector(
                    onTap: () => onFolderTap?.call(null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.home,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.notesListTitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Path separator
                if (showHomeIcon && path.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                ],

                // Folder path
                ...path.asMap().entries.map((entry) {
                  final index = entry.key;
                  final folder = entry.value;
                  final isLast = index == path.length - 1;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => onFolderTap?.call(folder),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isLast
                                ? colorScheme.primaryContainer.withValues(
                                    alpha: 0.5,
                                  )
                                : colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color:
                                      FolderIconHelpers.getFolderColor(
                                        folder.color,
                                      ) ??
                                      colorScheme.primary,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Icon(
                                  FolderIconHelpers.getFolderIcon(folder.icon),
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                folder.name,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isLast
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: isLast
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Separator (if not last)
                      if (!isLast) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                      ],
                    ],
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<List<domain.Folder>> _buildBreadcrumbPath(
    WidgetRef ref,
    domain.Folder folder,
  ) async {
    final repository = ref.read(folderCoreRepositoryProvider);
    final path = <domain.Folder>[];

    // Build path from current folder to root
    var currentFolder = folder;
    path.insert(0, currentFolder);

    while (currentFolder.parentId != null) {
      final parent = await repository.getFolder(currentFolder.parentId!);
      if (parent == null) break;

      path.insert(0, parent);
      currentFolder = parent;
    }

    return path;
  }
}

/// Create folder sheet widget
class _CreateFolderSheet extends ConsumerStatefulWidget {
  const _CreateFolderSheet();

  @override
  ConsumerState<_CreateFolderSheet> createState() => _CreateFolderSheetState();
}

class _CreateFolderSheetState extends ConsumerState<_CreateFolderSheet> {
  final _nameController = TextEditingController();
  String? _selectedParentId;
  String? _errorText;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Text(l10n.createNewFolder, style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            // Name field
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.folderName,
                prefixIcon: const Icon(Icons.folder_outlined),
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
            ),
            const SizedBox(height: 16),
            // Parent folder selector
            Consumer(
              builder: (context, ref, child) {
                final rootFoldersAsync = ref.watch(rootFoldersProvider);

                return rootFoldersAsync.when(
                  data: (folders) {
                    final allFolders = <domain.Folder?>[
                      null, // Root option
                      ...folders,
                    ];

                    return DropdownButtonFormField<String?>(
                      initialValue: _selectedParentId,
                      decoration: InputDecoration(
                        labelText: l10n.parentFolder,
                        prefixIcon: const Icon(Icons.folder_open),
                        border: const OutlineInputBorder(),
                      ),
                      items: allFolders.map((folder) {
                        return DropdownMenuItem(
                          value: folder?.id,
                          child: Row(
                            children: [
                              if (folder != null) ...[
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color:
                                        FolderIconHelpers.getFolderColor(
                                          folder.color,
                                        ) ??
                                        theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    FolderIconHelpers.getFolderIcon(
                                      folder.icon,
                                    ),
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(folder?.name ?? l10n.rootFolder),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedParentId = value);
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
                );
              },
            ),
            const SizedBox(height: 24),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isCreating ? null : () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isCreating ? null : _createFolder,
                  icon: _isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(l10n.create),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createFolder() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorText = l10n.folderNameEmpty);
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Check for duplicate name among siblings
      final siblings = _selectedParentId != null
          ? await ref
                .read(folderCoreRepositoryProvider)
                .getChildFolders(_selectedParentId!)
          : await ref.read(folderCoreRepositoryProvider).getRootFolders();

      final isDuplicate = siblings.any((f) => f.name == name);

      if (isDuplicate) {
        setState(() {
          _errorText = l10n.folderNameDuplicate;
          _isCreating = false;
        });
        return;
      }

      // Create the folder
      await ref
          .read(folderCoreRepositoryProvider)
          .createFolder(name: name, parentId: _selectedParentId);

      await HapticFeedback.mediumImpact();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.folderCreated(name)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorText = l10n.errorCreatingFolder;
        _isCreating = false;
      });
    }
  }
}

/// Parent folder picker widget
class _ParentFolderPicker extends ConsumerWidget {
  const _ParentFolderPicker({
    required this.currentFolder,
    required this.scrollController,
  });

  final domain.Folder currentFolder;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        // Handle bar
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.selectParentFolder,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Divider(height: 1),
        // Folder list
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              final foldersAsync = ref.watch(rootFoldersProvider);

              return foldersAsync.when(
                data: (folders) {
                  // Filter out current folder and its descendants
                  final availableFolders = _filterAvailableFolders(folders);

                  return ListView(
                    controller: scrollController,
                    children: [
                      // Root option
                      ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(l10n.rootFolder),
                        selected: currentFolder.parentId == null,
                        onTap: () => Navigator.pop(context, 'root'),
                      ),
                      const Divider(height: 1),
                      // Other folders
                      ...availableFolders.map((folder) {
                        return ListTile(
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color:
                                  FolderIconHelpers.getFolderColor(
                                    folder.color,
                                  ) ??
                                  theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              FolderIconHelpers.getFolderIcon(folder.icon),
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(folder.name),
                          selected: currentFolder.parentId == folder.id,
                          onTap: () => Navigator.pop(context, folder.id),
                        );
                      }),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(child: Text(l10n.errorLoadingFolders)),
              );
            },
          ),
        ),
      ],
    );
  }

  List<domain.Folder> _filterAvailableFolders(List<domain.Folder> allFolders) {
    // TODO: Implement proper filtering to exclude current folder and its descendants
    // For now, just exclude the current folder
    return allFolders.where((f) => f.id != currentFolder.id).toList();
  }
}

/// Skeleton loader for folder chips
class _SkeletonChips extends StatefulWidget {
  const _SkeletonChips();

  @override
  State<_SkeletonChips> createState() => _SkeletonChipsState();
}

class _SkeletonChipsState extends State<_SkeletonChips>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: List.generate(4, (index) {
        final widths = [80.0, 90.0, 75.0, 85.0];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, child) {
              return Container(
                width: widths[index % widths.length],
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                      colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    begin: Alignment(-1.0 + _shimmerAnimation.value * 2, 0),
                    end: Alignment(1.0 + _shimmerAnimation.value * 2, 0),
                  ),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}

/// All Notes chip that accepts drag and drop to unfile notes
class _AllNotesDropTarget extends ConsumerStatefulWidget {
  const _AllNotesDropTarget({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  ConsumerState<_AllNotesDropTarget> createState() =>
      _AllNotesDropTargetState();
}

class _AllNotesDropTargetState extends ConsumerState<_AllNotesDropTarget>
    with SingleTickerProviderStateMixin {
  late AnimationController _highlightController;
  late Animation<double> _highlightAnimation;
  bool _isDragOver = false;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _highlightAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _highlightController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  Future<void> _handleNoteDrop(LocalNote note) async {
    final folderRepository = ref.read(folderCoreRepositoryProvider);
    final undoService = ref.read(undoRedoServiceProvider);
    final l10n = AppLocalizations.of(context);

    // Get current folder info before unfiling
    final currentFolder = await folderRepository.getFolderForNote(note.id);

    // Remove note from folder (unfile it)
    await folderRepository.removeNoteFromFolder(note.id);

    // Record the operation for undo
    undoService.recordNoteFolderChange(
      noteId: note.id,
      noteTitle: note.titleEncrypted.isEmpty ? 'Untitled' : note.titleEncrypted,
      previousFolderId: currentFolder?.id,
      previousFolderName: currentFolder?.name,
      newFolderId: null,
      newFolderName: null,
    );

    // Show snackbar with undo action
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.unfiledNotes),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await undoService.undo();
              // Refresh the UI
              ref.invalidate(folderProvider);
              ref.invalidate(unfiledNotesCountProvider);
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Refresh counts
    ref.invalidate(unfiledNotesCountProvider);
    ref.invalidate(folderProvider);
  }

  Future<void> _handleBatchDrop(List<LocalNote> notes) async {
    final folderRepository = ref.read(folderCoreRepositoryProvider);
    final undoService = ref.read(undoRedoServiceProvider);

    // Collect previous folder info for all notes
    final previousFolderIds = <String, String?>{};
    for (final note in notes) {
      final folder = await folderRepository.getFolderForNote(note.id);
      previousFolderIds[note.id] = folder?.id;
    }

    // Unfile all notes
    for (final note in notes) {
      await folderRepository.removeNoteFromFolder(note.id);
    }

    // Record batch operation for undo
    undoService.recordBatchFolderChange(
      noteIds: notes.map((n) => n.id).toList(),
      previousFolderIds: previousFolderIds,
      newFolderId: null,
      newFolderName: null,
    );

    // Show snackbar with undo action
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${notes.length} notes unfiled'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await undoService.undo();
              // Refresh the UI
              ref.invalidate(folderProvider);
              ref.invalidate(unfiledNotesCountProvider);
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Refresh counts
    ref.invalidate(unfiledNotesCountProvider);
    ref.invalidate(folderProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        // Accept both single notes and batch selections
        return details.data is LocalNote || details.data is List<LocalNote>;
      },
      onAcceptWithDetails: (details) async {
        HapticFeedback.mediumImpact();

        if (details.data is LocalNote) {
          await _handleNoteDrop(details.data as LocalNote);
        } else if (details.data is List<LocalNote>) {
          await _handleBatchDrop(details.data as List<LocalNote>);
        }

        setState(() => _isDragOver = false);
        _highlightController.reverse();
      },
      onMove: (_) {
        if (!_isDragOver) {
          setState(() => _isDragOver = true);
          _highlightController.forward();
          HapticFeedback.selectionClick();
        }
      },
      onLeave: (_) {
        setState(() => _isDragOver = false);
        _highlightController.reverse();
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedBuilder(
          animation: _highlightAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_highlightAnimation.value * 0.05),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _isDragOver
                      ? [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.icon,
                        size: 16,
                        color: widget.isSelected || _isDragOver
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(widget.label),
                      if (_isDragOver) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.file_download_outlined,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  selected: widget.isSelected || _isDragOver,
                  onSelected: (_) => widget.onSelected(),
                  backgroundColor: _isDragOver
                      ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : colorScheme.surface,
                  selectedColor: _isDragOver
                      ? colorScheme.primaryContainer
                      : colorScheme.secondaryContainer,
                  side: BorderSide(
                    color: _isDragOver
                        ? colorScheme.primary
                        : widget.isSelected
                        ? Colors.transparent
                        : colorScheme.outline,
                    width: _isDragOver ? 2 : 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Inbox preset chip showing incoming mail folder
class _InboxPresetChip extends ConsumerWidget {
  const _InboxPresetChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(isInboxFilterActiveProvider);

    return FutureBuilder<String?>(
      future: _getIncomingMailFolderId(ref),
      builder: (context, folderSnapshot) {
        if (!folderSnapshot.hasData || folderSnapshot.data == null) {
          return const SizedBox.shrink();
        }

        final folderId = folderSnapshot.data!;

        return FutureBuilder<int>(
          future: ref
              .read(notesCoreRepositoryProvider)
              .getNotesCountInFolder(folderId),
          builder: (context, countSnapshot) {
            final count = countSnapshot.data ?? 0;

            // Only show if there are notes in inbox
            if (count == 0 && !isActive) {
              return const SizedBox.shrink();
            }

            return _FilterChip(
              label: 'Inbox',
              icon: Icons.inbox,
              count: count > 0 ? count : null,
              isSelected: isActive,
              onSelected: () async {
                HapticUtils.selection();

                // Toggle inbox filter
                final newActiveState = !isActive;
                ref
                    .read(isInboxFilterActiveProvider.notifier)
                    .update((_) => newActiveState);

                if (newActiveState) {
                  // Activate inbox filter - show only notes in incoming mail folder
                  final folder = await ref
                      .read(folderCoreRepositoryProvider)
                      .getFolder(folderId);
                  if (folder != null) {
                    ref
                        .read(currentFolderProvider.notifier)
                        .setCurrentFolder(folder);
                  }
                } else {
                  // Deactivate inbox filter
                  ref.read(currentFolderProvider.notifier).clearCurrentFolder();
                }
              },
            );
          },
        );
      },
    );
  }

  Future<String?> _getIncomingMailFolderId(WidgetRef ref) async {
    try {
      final repository = ref.read(folderCoreRepositoryProvider);
      final folders = await repository.listFolders();

      // Look for "Incoming Mail" folder (domain folders don't have deleted field)
      final incomingMailFolder = folders.firstWhere(
        (f) => f.name.toLowerCase() == 'incoming mail',
        orElse: () => throw Exception('Not found'),
      );

      return incomingMailFolder.id;
    } catch (e) {
      return null;
    }
  }
}

/// Provider to track if inbox filter is active
final isInboxFilterActiveProvider = StateProvider<bool>((ref) => false);
