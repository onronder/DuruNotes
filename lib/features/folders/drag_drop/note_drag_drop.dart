import 'package:duru_notes/data/local/app_db.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A draggable note item that can be dropped on folders
class DraggableNoteItem extends ConsumerStatefulWidget {
  const DraggableNoteItem({
    required this.note,
    required this.child,
    super.key,
    this.onDragStarted,
    this.onDragEnd,
    this.onDroppedOnFolder,
    this.enabled = true,
  });

  final LocalNote note;
  final Widget child;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;
  final Function(String folderId)? onDroppedOnFolder;
  final bool enabled;

  @override
  ConsumerState<DraggableNoteItem> createState() => _DraggableNoteItemState();
}

class _DraggableNoteItemState extends ConsumerState<DraggableNoteItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return LongPressDraggable<LocalNote>(
      data: widget.note,
      feedback: _buildFeedback(context),
      childWhenDragging: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.95,
            child: Opacity(opacity: 0.7, child: widget.child),
          );
        },
      ),
      onDragStarted: () {
        setState(() => _isDragging = true);
        _animationController.forward();
        HapticFeedback.mediumImpact();
        widget.onDragStarted?.call();
      },
      onDragEnd: (_) {
        setState(() => _isDragging = false);
        _animationController.reverse();
        widget.onDragEnd?.call();
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _isDragging ? _scaleAnimation.value : 1.0,
            child: widget.child,
          );
        },
      ),
    );
  }

  Widget _buildFeedback(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.note.title.isEmpty
                        ? 'Untitled Note'
                        : widget.note.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (widget.note.body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.note.body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Drop on folder to organize',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A folder drop target that accepts note drops
class FolderDropTarget extends ConsumerStatefulWidget {
  const FolderDropTarget({
    required this.folder,
    required this.child,
    super.key,
    this.onNoteDropped,
    this.enabled = true,
  });

  final LocalFolder? folder; // null for "Unfiled" option
  final Widget child;
  final Function(LocalNote note, LocalFolder? folder)? onNoteDropped;
  final bool enabled;

  @override
  ConsumerState<FolderDropTarget> createState() => _FolderDropTargetState();
}

class _FolderDropTargetState extends ConsumerState<FolderDropTarget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _highlightAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _highlightAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final theme = Theme.of(context);

    return DragTarget<LocalNote>(
      onWillAcceptWithDetails: (note) => note != null,
      onAcceptWithDetails: (details) {
        HapticFeedback.lightImpact();
        widget.onNoteDropped?.call(details.data, widget.folder);
        _animationController.reverse();
      },
      onMove: (_) {
        if (!_isHovered) {
          setState(() => _isHovered = true);
          _animationController.forward();
          HapticFeedback.selectionClick();
        }
      },
      onLeave: (_) {
        if (_isHovered) {
          setState(() => _isHovered = false);
          _animationController.reverse();
        }
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: _isHovered
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  widget.child,
                  if (_isHovered)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1 * _highlightAnimation.value,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  if (_isHovered)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Drop here',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// A batch drag and drop component for multiple notes
class BatchNoteDragDrop extends ConsumerStatefulWidget {
  const BatchNoteDragDrop({
    required this.selectedNotes,
    required this.child,
    super.key,
    this.onNotesDropped,
    this.enabled = true,
  });

  final List<LocalNote> selectedNotes;
  final Widget child;
  final Function(List<LocalNote> notes, LocalFolder? folder)? onNotesDropped;
  final bool enabled;

  @override
  ConsumerState<BatchNoteDragDrop> createState() => _BatchNoteDragDropState();
}

class _BatchNoteDragDropState extends ConsumerState<BatchNoteDragDrop>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1, end: 1.03).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.selectedNotes.isEmpty) {
      return widget.child;
    }

    return LongPressDraggable<List<LocalNote>>(
      data: widget.selectedNotes,
      feedback: _buildBatchFeedback(context),
      childWhenDragging: Opacity(opacity: 0.7, child: widget.child),
      onDragStarted: () {
        _animationController.forward();
        HapticFeedback.mediumImpact();
      },
      onDragEnd: (_) {
        _animationController.reverse();
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          );
        },
      ),
    );
  }

  Widget _buildBatchFeedback(BuildContext context) {
    final theme = Theme.of(context);
    final noteCount = widget.selectedNotes.length;

    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary, width: 2),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.library_books,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$noteCount Selected Notes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Moving multiple items',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Note previews
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.selectedNotes.take(3).length,
                itemBuilder: (context, index) {
                  final note = widget.selectedNotes[index];
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title.isEmpty ? 'Untitled' : note.title,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          note.body,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            if (widget.selectedNotes.length > 3) ...[
              const SizedBox(height: 8),
              Text(
                '+${widget.selectedNotes.length - 3} more notes',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Drop on any folder to move all selected notes',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Enhanced folder drop target for batch operations
class BatchFolderDropTarget extends FolderDropTarget {
  const BatchFolderDropTarget({
    required super.folder,
    required super.child,
    super.key,
    this.onBatchNotesDropped,
    super.enabled = true,
  }) : super(onNoteDropped: null);

  final Function(List<LocalNote> notes, LocalFolder? folder)?
      onBatchNotesDropped;

  @override
  ConsumerState<FolderDropTarget> createState() =>
      _BatchFolderDropTargetState();
}

class _BatchFolderDropTargetState extends _FolderDropTargetState {
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Stack(
      children: [
        // Single note drop target
        super.build(context),

        // Batch notes drop target
        DragTarget<List<LocalNote>>(
          onWillAcceptWithDetails: (details) => details.data.isNotEmpty,
          onAcceptWithDetails: (details) {
            HapticFeedback.lightImpact();
            (widget as BatchFolderDropTarget).onBatchNotesDropped?.call(
                  details.data,
                  widget.folder,
                );
            _animationController.reverse();
          },
          onMove: (_) {
            if (!_isHovered) {
              setState(() => _isHovered = true);
              _animationController.forward();
              HapticFeedback.selectionClick();
            }
          },
          onLeave: (_) {
            if (_isHovered) {
              setState(() => _isHovered = false);
              _animationController.reverse();
            }
          },
          builder: (context, candidateData, rejectedData) {
            return const SizedBox.expand();
          },
        ),
      ],
    );
  }
}
