import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/ui/widgets/tasks/task_widget_adapter.dart';
import 'package:duru_notes/ui/widgets/tasks/task_model_converter.dart';
import 'package:duru_notes/models/note_task.dart' show UiNoteTask, UiTaskStatus, UiTaskPriority;
import 'package:flutter/material.dart';

/// Fully migrated hierarchical task tree node widget
/// Works with both database NoteTask and legacy UiNoteTask models
class TaskTreeNode extends StatefulWidget {
  final NoteTask? dbTask;
  final UiNoteTask? uiTask;
  final List<NoteTask> dbSubtasks;
  final List<UiNoteTask> uiSubtasks;
  final UnifiedTaskCallbacks callbacks;
  final bool isExpanded;
  final int depth;
  
  const TaskTreeNode({
    super.key,
    this.dbTask,
    this.uiTask,
    this.dbSubtasks = const [],
    this.uiSubtasks = const [],
    required this.callbacks,
    this.isExpanded = false,
    this.depth = 0,
  }) : assert(dbTask != null || uiTask != null, 'Either dbTask or uiTask must be provided');
  
  @override
  State<TaskTreeNode> createState() => _TaskTreeNodeState();
}

class _TaskTreeNodeState extends State<TaskTreeNode> {
  late bool _isExpanded;
  
  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.dbTask != null) {
      return TaskWidgetAdapter(
        dbTask: widget.dbTask,
        builder: (uiTask) => _buildNode(context, uiTask, widget.dbSubtasks.map((t) => 
          TaskModelConverter.dbTaskToUiTask(t)).toList()),
      );
    } else {
      return _buildNode(context, widget.uiTask!, widget.uiSubtasks);
    }
  }
  
  Widget _buildNode(BuildContext context, UiNoteTask task, List<UiNoteTask> subtasks) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasSubtasks = subtasks.isNotEmpty;
    final taskId = task.id;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main task node
        Container(
          margin: EdgeInsets.only(
            left: widget.depth * 24.0,
            bottom: 4,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.callbacks.onEdit(taskId),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Expand/Collapse button
                    if (hasSubtasks) ...[
                      IconButton(
                        icon: AnimatedRotation(
                          turns: _isExpanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.chevron_right, size: 20),
                        ),
                        onPressed: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 24),
                    ],
                    
                    // Checkbox
                    Checkbox(
                      value: task.status == UiTaskStatus.completed,
                      onChanged: (value) async {
                        final newStatus = value! ? TaskStatus.completed : TaskStatus.open;
                        await widget.callbacks.onStatusChanged(taskId, newStatus);
                        
                        // Also update subtasks if completing parent
                        if (value && hasSubtasks) {
                          for (final subtask in subtasks) {
                            if (subtask.status != UiTaskStatus.completed) {
                              await widget.callbacks.onStatusChanged(
                                subtask.id, 
                                TaskStatus.completed,
                              );
                            }
                          }
                        }
                      },
                      activeColor: _getPriorityColor(task.priority),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Task content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.content,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              decoration: task.status == UiTaskStatus.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.status == UiTaskStatus.completed
                                  ? colorScheme.onSurface.withOpacity(0.5)
                                  : null,
                            ),
                          ),
                          
                          // Metadata row
                          if (task.priority != UiTaskPriority.none ||
                              task.dueDate != null ||
                              hasSubtasks) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (task.priority != UiTaskPriority.none)
                                  _buildPriorityBadge(context, task.priority),
                                if (task.dueDate != null)
                                  _buildDueDateBadge(context, task.dueDate!),
                                if (hasSubtasks)
                                  _buildSubtaskCount(context, subtasks),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Actions menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            widget.callbacks.onEdit(taskId);
                            break;
                          case 'add_subtask':
                            _showAddSubtaskDialog(context, taskId);
                            break;
                          case 'priority':
                            _showPriorityDialog(context, task);
                            break;
                          case 'delete':
                            _confirmDelete(context, taskId, hasSubtasks);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        const PopupMenuItem(
                          value: 'add_subtask',
                          child: Text('Add Subtask'),
                        ),
                        const PopupMenuItem(
                          value: 'priority',
                          child: Text('Set Priority'),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            hasSubtasks ? 'Delete with Subtasks' : 'Delete',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Subtasks (if expanded)
        if (hasSubtasks && _isExpanded)
          ...subtasks.map((subtask) => TaskTreeNode(
            uiTask: subtask,
            uiSubtasks: subtask.subtasks,
            callbacks: widget.callbacks,
            depth: widget.depth + 1,
          )),
      ],
    );
  }
  
  Widget _buildPriorityBadge(BuildContext context, UiTaskPriority priority) {
    final color = _getPriorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            _getPriorityLabel(priority),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDueDateBadge(BuildContext context, DateTime dueDate) {
    final now = DateTime.now();
    final isOverdue = dueDate.isBefore(now);
    final color = isOverdue ? Colors.red : Theme.of(context).colorScheme.primary;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '${dueDate.month}/${dueDate.day}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSubtaskCount(BuildContext context, List<UiNoteTask> subtasks) {
    final completed = subtasks.where((t) => t.status == UiTaskStatus.completed).length;
    final total = subtasks.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$completed/$total',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
  
  void _showAddSubtaskDialog(BuildContext context, String parentId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Subtask'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Subtask description...',
            prefixIcon: Icon(Icons.subdirectory_arrow_right),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                // This would create a subtask via the service
                // For now, just close the dialog
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
  
  void _showPriorityDialog(BuildContext context, UiNoteTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Priority'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TaskPriority.values.map((priority) {
            final uiPriority = TaskModelConverter.dbPriorityToUiPriority(priority);
            return ListTile(
              leading: Icon(
                Icons.flag,
                color: _getPriorityColor(uiPriority),
              ),
              title: Text(priority.name),
              onTap: () async {
                await widget.callbacks.onPriorityChanged(task.id, priority);
                if (context.mounted) Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }
  
  void _confirmDelete(BuildContext context, String taskId, bool hasSubtasks) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(hasSubtasks ? 'Delete Task and Subtasks' : 'Delete Task'),
        content: Text(
          hasSubtasks 
              ? 'This will delete the task and all its subtasks. Are you sure?'
              : 'Are you sure you want to delete this task?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await widget.callbacks.onDeleted(taskId);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  Color _getPriorityColor(UiTaskPriority priority) {
    switch (priority) {
      case UiTaskPriority.urgent:
        return Colors.red;
      case UiTaskPriority.high:
        return Colors.orange;
      case UiTaskPriority.medium:
        return Colors.blue;
      case UiTaskPriority.low:
        return Colors.grey;
      case UiTaskPriority.none:
        return Colors.grey.withOpacity(0.5);
    }
  }
  
  String _getPriorityLabel(UiTaskPriority priority) {
    switch (priority) {
      case UiTaskPriority.urgent:
        return 'Urgent';
      case UiTaskPriority.high:
        return 'High';
      case UiTaskPriority.medium:
        return 'Medium';
      case UiTaskPriority.low:
        return 'Low';
      case UiTaskPriority.none:
        return '';
    }
  }
}