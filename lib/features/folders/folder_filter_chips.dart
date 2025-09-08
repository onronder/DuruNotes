import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/folder_picker_sheet.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Material 3 filter chips for folder navigation
class FolderFilterChips extends ConsumerStatefulWidget {
  const FolderFilterChips({
    super.key,
    this.onFolderSelected,
    this.showCreateOption = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final ValueChanged<LocalFolder?>? onFolderSelected;
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
      duration: const Duration(milliseconds: 400),
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      )),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Consumer(
          builder: (context, ref, child) {
            final currentFolder = ref.watch(currentFolderProvider);
            final rootFoldersAsync = ref.watch(rootFoldersProvider);
            final unfiledCountAsync = ref.watch(unfiledNotesCountProvider);
            
            return ListView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: widget.padding,
              children: [
                // All Notes chip
                _FilterChip(
                  label: l10n.notesListTitle,
                  icon: Icons.notes,
                  isSelected: currentFolder == null,
                  onSelected: () {
                    // Clear folder filter by updating current folder to null
                    widget.onFolderSelected?.call(null);
                  },
                ),
                
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
                  error: (_, __) => const SizedBox.shrink(),
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
                  loading: () => const SizedBox(
                    width: 40,
                    height: 32,
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                
                // Browse all folders chip
                _FilterChip(
                  label: l10n.allFolders,
                  icon: Icons.folder_outlined,
                  isSelected: false,
                  onSelected: _showFolderPicker,
                ),
                
                // Create folder chip (optional)
                if (widget.showCreateOption) ...[
                  const SizedBox(width: 8),
                  _ActionChip(
                    label: l10n.createNewFolder,
                    icon: Icons.add,
                    onPressed: () => _showFolderPicker(showCreate: true),
                  ),
                ],
              ],
            );
          },
        ),
      ),
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
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(label),
          if (count != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected 
                    ? colorScheme.onSecondaryContainer.withOpacity(0.2)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.secondaryContainer,
      side: BorderSide(
        color: isSelected ? Colors.transparent : colorScheme.outline,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _FolderChip extends ConsumerWidget {
  const _FolderChip({
    required this.folder,
    required this.isSelected,
    required this.onSelected,
  });

  final LocalFolder folder;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Get note count for this folder
    return FutureBuilder<int>(
      future: ref.read(notesRepositoryProvider).db.countNotesInFolder(folder.id),
      builder: (context, snapshot) {
        final noteCount = snapshot.data ?? 0;
        
        return FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: folder.color != null
                      ? Color(int.parse(folder.color!, radix: 16))
                      : colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  folder.icon != null
                      ? IconData(int.parse(folder.icon!), fontFamily: 'MaterialIcons')
                      : Icons.folder,
                  size: 12,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Text(folder.name),
              if (noteCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? colorScheme.onSecondaryContainer.withOpacity(0.2)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    noteCount.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          selected: isSelected,
          onSelected: (_) => onSelected(),
          backgroundColor: colorScheme.surface,
          selectedColor: colorScheme.secondaryContainer,
          side: BorderSide(
            color: isSelected ? Colors.transparent : colorScheme.outline,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      },
    );
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
    
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: colorScheme.primary),
          ),
        ],
      ),
      onPressed: onPressed,
      backgroundColor: colorScheme.primaryContainer.withOpacity(0.3),
      side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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

  final LocalFolder? currentFolder;
  final ValueChanged<LocalFolder?>? onFolderTap;
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
      child: FutureBuilder<List<LocalFolder>>(
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isLast 
                                ? colorScheme.primaryContainer.withOpacity(0.5)
                                : colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: folder.color != null
                                      ? Color(int.parse(folder.color!, radix: 16))
                                      : colorScheme.primary,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Icon(
                                  folder.icon != null
                                      ? IconData(int.parse(folder.icon!), fontFamily: 'MaterialIcons')
                                      : Icons.folder,
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
                                  fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
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

  Future<List<LocalFolder>> _buildBreadcrumbPath(WidgetRef ref, LocalFolder folder) async {
    final repository = ref.read(notesRepositoryProvider);
    final path = <LocalFolder>[];
    
    LocalFolder? current = folder;
    while (current != null) {
      path.insert(0, current);
      if (current.parentId != null) {
        current = await repository.getFolder(current.parentId!);
      } else {
        break;
      }
    }
    
    return path;
  }
}
