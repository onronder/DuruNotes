/// Task model for Phase 2 UI components
///
/// This is a simplified task model for demonstrating the
/// refactored UI components. In production, this would integrate
/// with the existing task system.
///
/// NOTE: This is renamed from NoteTask to UiNoteTask to avoid conflicts
/// with the Drift-generated NoteTask model. UI components using this
/// should be updated to use the actual database model.
///
/// @deprecated Use the Drift-generated NoteTask model from 'package:duru_notes/data/local/app_db.dart' instead.
/// For conversion between models, use TaskModelConverter from 'package:duru_notes/ui/widgets/tasks/task_model_converter.dart'.

@Deprecated(
    'Use TaskStatus from app_db.dart instead. See TaskModelConverter for migration.')
enum UiTaskStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

@Deprecated(
    'Use TaskPriority from app_db.dart instead. See TaskModelConverter for migration.')
enum UiTaskPriority {
  none,
  low,
  medium,
  high,
  urgent,
}

@Deprecated(
    'Use NoteTask from app_db.dart instead. See TaskModelConverter for migration.')
class UiNoteTask {
  final String id;
  final String content;
  final UiTaskStatus status;
  final UiTaskPriority priority;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final List<UiNoteTask> subtasks;
  final String? noteId;
  final String? parentTaskId;

  const UiNoteTask({
    required this.id,
    required this.content,
    this.status = UiTaskStatus.pending,
    this.priority = UiTaskPriority.none,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.subtasks = const [],
    this.noteId,
    this.parentTaskId,
  });

  UiNoteTask copyWith({
    String? id,
    String? content,
    UiTaskStatus? status,
    UiTaskPriority? priority,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    List<UiNoteTask>? subtasks,
    String? noteId,
    String? parentTaskId,
  }) {
    return UiNoteTask(
      id: id ?? this.id,
      content: content ?? this.content,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      subtasks: subtasks ?? this.subtasks,
      noteId: noteId ?? this.noteId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
    );
  }
}
