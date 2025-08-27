import 'package:flutter/material.dart';

import '../../../models/note_block.dart';

/// Widget for rendering and editing todo/checklist blocks.
/// 
/// This widget handles:
/// - Checkbox state management (checked/unchecked)
/// - Text input for todo item description
/// - Visual styling for completed vs pending todos
/// - Block deletion functionality
class TodoBlockWidget extends StatelessWidget {
  const TodoBlockWidget({
    super.key,
    required this.block,
    required this.controller,
    required this.onChanged,
    required this.onDelete,
    this.hintText = 'Todo',
  });

  /// The todo block being edited
  final NoteBlock block;
  
  /// Text controller for the todo text
  final TextEditingController controller;
  
  /// Callback when the block content or state changes
  final ValueChanged<NoteBlock> onChanged;
  
  /// Callback when the block should be deleted
  final VoidCallback onDelete;
  
  /// Hint text to display when empty
  final String hintText;

  TodoBlockData get _todoData => block.data as TodoBlockData;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Checkbox for todo completion state
        Checkbox(
          value: _todoData.checked,
          onChanged: (checked) {
            final updatedData = _todoData.copyWith(checked: checked ?? false);
            final updatedBlock = block.copyWith(data: updatedData);
            onChanged(updatedBlock);
          },
        ),
        
        // Todo text input
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              decoration: _todoData.checked 
                  ? TextDecoration.lineThrough 
                  : TextDecoration.none,
              color: _todoData.checked
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                  : null,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 0.0,
              ),
            ),
            onChanged: (value) {
              final updatedData = _todoData.copyWith(text: value);
              final updatedBlock = block.copyWith(data: updatedData);
              onChanged(updatedBlock);
            },
          ),
        ),
        
        // Delete button
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: onDelete,
          tooltip: 'Delete todo',
        ),
      ],
    );
  }
}

/// Widget for rendering a todo checklist summary.
/// 
/// This provides a compact view of todo completion status.
class TodoSummaryWidget extends StatelessWidget {
  const TodoSummaryWidget({
    super.key,
    required this.todos,
    this.showProgress = true,
  });

  /// List of todo blocks to summarize
  final List<NoteBlock> todos;
  
  /// Whether to show progress indicator
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) {
      return const SizedBox.shrink();
    }

    final todoItems = todos
        .where((block) => block.type == NoteBlockType.todo)
        .map((block) => block.data as TodoBlockData)
        .toList();

    final completedCount = todoItems.where((todo) => todo.checked).length;
    final totalCount = todoItems.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checklist,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Todo List',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '$completedCount of $totalCount',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            
            if (showProgress) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress == 1.0 
                      ? Colors.green 
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
