import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_db.dart';
import '../../../providers.dart';
import '../folder_notifiers.dart';

/// A draggable and droppable folder tree widget
class DraggableFolderTree extends ConsumerStatefulWidget {
  const DraggableFolderTree({
    super.key,
    this.onFolderSelected,
    this.onFolderMoved,
    this.selectedFolderId,
    this.showSearch = true,
    this.allowReordering = true,
    this.showNoteCount = true,
  });

  final Function(LocalFolder folder)? onFolderSelected;
  final Function(String folderId, String? newParentId, int newPosition)? onFolderMoved;
  final String? selectedFolderId;
  final bool showSearch;
  final bool allowReordering;
  final bool showNoteCount;

  @override
  ConsumerState<DraggableFolderTree> createState() => _DraggableFolderTreeState();
}

class _DraggableFolderTreeState extends ConsumerState<DraggableFolderTree>
    with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  late AnimationController _dragAnimationController;
  late AnimationController _dropAnimationController;
  
  String? _draggedFolderId;
  String? _dropTargetId;
  Offset? _dragOffset;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _dragAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _dropAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _dragAnimationController.dispose();
    _dropAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hierarchyState = ref.watch(folderHierarchyProvider);
    final visibleNodes = ref.watch(visibleFolderNodesProvider);
    
    return Column(
      children: [
        if (widget.showSearch) _buildSearchBar(),
        
        Expanded(
          child: Stack(
            children: [
              // Main folder tree
              hierarchyState.isLoading && visibleNodes.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : hierarchyState.error != null
                      ? _buildErrorState(hierarchyState.error!)
                      : visibleNodes.isEmpty
                          ? _buildEmptyState()
                          : _buildFolderTree(visibleNodes),
              
              // Drag overlay
              if (_isDragging && _draggedFolderId != null && _dragOffset != null)
                _buildDragOverlay(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SearchBar(
        hintText: 'Search folders...',
        leading: const Icon(Icons.search),
        onChanged: (query) {
          ref.read(folderHierarchyProvider.notifier).updateSearchQuery(query);
        },
        trailing: [
          Consumer(
            builder: (context, ref, child) {
              final hierarchyState = ref.watch(folderHierarchyProvider);
              if (hierarchyState.searchQuery.isEmpty) return const SizedBox.shrink();
              
              return IconButton(
                onPressed: () {
                  ref.read(folderHierarchyProvider.notifier).clearSearch();
                },
                icon: const Icon(Icons.clear),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading folders',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ref.read(folderHierarchyProvider.notifier).loadFolders();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No folders yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first folder to get started',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderTree(List<FolderTreeNode> nodes) {
    return ReorderableListView.builder(
      scrollController: _scrollController,
      onReorder: (int oldIndex, int newIndex) {
        if (widget.allowReordering) {
          _onReorder(oldIndex, newIndex);
        }
      },
      buildDefaultDragHandles: false,
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        return _DraggableFolderItem(
          key: ValueKey(node.folder.id),
          node: node,
          index: index,
          isSelected: widget.selectedFolderId == node.folder.id,
          isDragTarget: _dropTargetId == node.folder.id,
          isDragging: _draggedFolderId == node.folder.id,
          showNoteCount: widget.showNoteCount,
          allowReordering: widget.allowReordering,
          onTap: () => widget.onFolderSelected?.call(node.folder),
          onExpansionToggle: () {
            ref.read(folderHierarchyProvider.notifier)
                .toggleExpansion(node.folder.id);
          },
          onDragStarted: (folderId) => _onDragStarted(folderId),
          onDragUpdate: (details) => _onDragUpdate(details),
          onDragEnd: () => _onDragEnd(),
          onAcceptDrop: (draggedFolderId, targetFolderId) =>
              _onAcceptDrop(draggedFolderId, targetFolderId),
          onHover: (folderId) => _onHover(folderId),
          onHoverEnd: () => _onHoverEnd(),
        );
      },
    );
  }

  Widget _buildDragOverlay() {
    final draggedFolder = ref.read(folderHierarchyProvider)
        .getFolderById(_draggedFolderId!);
    
    if (draggedFolder == null) return const SizedBox.shrink();

    return Positioned(
      left: _dragOffset!.dx - 100,
      top: _dragOffset!.dy - 30,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                draggedFolder.icon != null
                    ? IconData(int.parse(draggedFolder.icon!), fontFamily: 'MaterialIcons')
                    : Icons.folder,
                color: draggedFolder.color != null
                    ? Color(int.parse(draggedFolder.color!))
                    : Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  draggedFolder.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (!widget.allowReordering) return;
    
    final visibleNodes = ref.read(visibleFolderNodesProvider);
    if (oldIndex >= visibleNodes.length || newIndex >= visibleNodes.length) return;

    // Haptic feedback
    HapticFeedback.lightImpact();
    
    final folder = visibleNodes[oldIndex].folder;
    widget.onFolderMoved?.call(folder.id, folder.parentId, newIndex);
  }

  void _onDragStarted(String folderId) {
    setState(() {
      _draggedFolderId = folderId;
      _isDragging = true;
    });
    
    _dragAnimationController.forward();
    HapticFeedback.mediumImpact();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = details.globalPosition;
    });
  }

  void _onDragEnd() {
    setState(() {
      _draggedFolderId = null;
      _dropTargetId = null;
      _isDragging = false;
      _dragOffset = null;
    });
    
    _dragAnimationController.reverse();
    _dropAnimationController.forward().then((_) {
      _dropAnimationController.reset();
    });
  }

  void _onAcceptDrop(String draggedFolderId, String targetFolderId) {
    if (draggedFolderId == targetFolderId) return;
    
    // Prevent dropping a folder into its own descendant
    if (_isDescendant(draggedFolderId, targetFolderId)) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot move folder into its own subfolder'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    HapticFeedback.lightImpact();
    widget.onFolderMoved?.call(draggedFolderId, targetFolderId, 0);
  }

  void _onHover(String folderId) {
    setState(() {
      _dropTargetId = folderId;
    });
  }

  void _onHoverEnd() {
    setState(() {
      _dropTargetId = null;
    });
  }

  bool _isDescendant(String ancestorId, String descendantId) {
    final hierarchyState = ref.read(folderHierarchyProvider);
    String? currentId = descendantId;
    
    while (currentId != null) {
      if (currentId == ancestorId) return true;
      final folder = hierarchyState.getFolderById(currentId);
      currentId = folder?.parentId;
    }
    
    return false;
  }
}

class _DraggableFolderItem extends StatefulWidget {
  const _DraggableFolderItem({
    super.key,
    required this.node,
    required this.index,
    required this.isSelected,
    required this.isDragTarget,
    required this.isDragging,
    required this.showNoteCount,
    required this.allowReordering,
    this.onTap,
    this.onExpansionToggle,
    this.onDragStarted,
    this.onDragUpdate,
    this.onDragEnd,
    this.onAcceptDrop,
    this.onHover,
    this.onHoverEnd,
  });

  final FolderTreeNode node;
  final int index;
  final bool isSelected;
  final bool isDragTarget;
  final bool isDragging;
  final bool showNoteCount;
  final bool allowReordering;
  final VoidCallback? onTap;
  final VoidCallback? onExpansionToggle;
  final Function(String folderId)? onDragStarted;
  final Function(DragUpdateDetails details)? onDragUpdate;
  final VoidCallback? onDragEnd;
  final Function(String draggedId, String targetId)? onAcceptDrop;
  final Function(String folderId)? onHover;
  final VoidCallback? onHoverEnd;

  @override
  State<_DraggableFolderItem> createState() => _DraggableFolderItemState();
}

class _DraggableFolderItemState extends State<_DraggableFolderItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _elevationAnimation = Tween<double>(
      begin: 0.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_DraggableFolderItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isDragging && !oldWidget.isDragging) {
      _animationController.forward();
    } else if (!widget.isDragging && oldWidget.isDragging) {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folder = widget.node.folder;
    final indentWidth = widget.node.level * 24.0;

    Widget child = AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Material(
            elevation: _elevationAnimation.value,
            borderRadius: BorderRadius.circular(12),
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                    : widget.isDragTarget
                        ? theme.colorScheme.primaryContainer.withOpacity(0.1)
                        : null,
                borderRadius: BorderRadius.circular(12),
                border: widget.isDragTarget
                    ? Border.all(
                        color: theme.colorScheme.primary,
                        width: 2,
                      )
                    : null,
              ),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16 + indentWidth,
                    right: 16,
                    top: 12,
                    bottom: 12,
                  ),
                  child: Row(
                    children: [
                      // Expansion toggle
                      if (widget.node.hasChildren)
                        GestureDetector(
                          onTap: widget.onExpansionToggle,
                          child: AnimatedRotation(
                            turns: widget.node.isExpanded ? 0.25 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.chevron_right,
                              size: 20,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 20),

                      const SizedBox(width: 8),

                      // Folder icon
                      Icon(
                        folder.icon != null
                            ? IconData(int.parse(folder.icon!), fontFamily: 'MaterialIcons')
                            : Icons.folder,
                        color: folder.color != null
                            ? Color(int.parse(folder.color!))
                            : (widget.isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant),
                        size: 20,
                      ),

                      const SizedBox(width: 12),

                      // Folder name
                      Expanded(
                        child: Text(
                          folder.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: widget.isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                            fontWeight: widget.isSelected 
                                ? FontWeight.w600 
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Note count
                      if (widget.showNoteCount && widget.node.noteCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.node.noteCount.toString(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),

                      // Drag handle
                      if (widget.allowReordering) ...[
                        const SizedBox(width: 8),
                        ReorderableDragStartListener(
                          index: widget.index,
                          child: Icon(
                            Icons.drag_handle,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (widget.allowReordering) {
      child = LongPressDraggable<String>(
        data: folder.id,
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  folder.icon != null
                      ? IconData(int.parse(folder.icon!), fontFamily: 'MaterialIcons')
                      : Icons.folder,
                  color: folder.color != null
                      ? Color(int.parse(folder.color!))
                      : theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    folder.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: child,
        ),
        onDragStarted: () => widget.onDragStarted?.call(folder.id),
        onDragUpdate: widget.onDragUpdate,
        onDragEnd: (_) => widget.onDragEnd?.call(),
        child: child,
      );

      child = DragTarget<String>(
        onWillAccept: (data) => data != null && data != folder.id,
        onAccept: (draggedFolderId) {
          widget.onAcceptDrop?.call(draggedFolderId, folder.id);
        },
        onMove: (_) => widget.onHover?.call(folder.id),
        onLeave: (_) => widget.onHoverEnd?.call(),
        builder: (context, candidateData, rejectedData) => child,
      );
    }

    return child;
  }
}