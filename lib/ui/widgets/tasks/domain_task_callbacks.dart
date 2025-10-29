import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/services/domain_task_controller.dart';

/// Unified task callbacks that work with domain entities
/// Replaces the old UnifiedTaskCallbacks that used drift models
abstract class DomainTaskCallbacks {
  /// Called when task status changes
  Future<void> onStatusChanged(String taskId, domain.TaskStatus newStatus);

  /// Called when task priority changes
  Future<void> onPriorityChanged(
    String taskId,
    domain.TaskPriority newPriority,
  );

  /// Called when task content is edited
  Future<void> onContentChanged(String taskId, String newContent);

  /// Called when task is deleted
  Future<void> onDeleted(String taskId);

  /// Called to edit task details
  void onEdit(String taskId);

  /// Called when due date changes
  Future<void> onDueDateChanged(String taskId, DateTime? newDate);
}

/// Implementation of DomainTaskCallbacks that delegates to a service
class ServiceTaskCallbacks implements DomainTaskCallbacks {
  final Future<void> Function(String taskId, domain.TaskStatus status)
  _onStatusChanged;
  final Future<void> Function(String taskId, domain.TaskPriority priority)
  _onPriorityChanged;
  final Future<void> Function(String taskId, String content) _onContentChanged;
  final Future<void> Function(String taskId) _onDeleted;
  final void Function(String taskId) _onEdit;
  final Future<void> Function(String taskId, DateTime? date) _onDueDateChanged;

  const ServiceTaskCallbacks({
    required Future<void> Function(String taskId, domain.TaskStatus status)
    onStatusChanged,
    required Future<void> Function(String taskId, domain.TaskPriority priority)
    onPriorityChanged,
    required Future<void> Function(String taskId, String content)
    onContentChanged,
    required Future<void> Function(String taskId) onDeleted,
    required void Function(String taskId) onEdit,
    required Future<void> Function(String taskId, DateTime? date)
    onDueDateChanged,
  }) : _onStatusChanged = onStatusChanged,
       _onPriorityChanged = onPriorityChanged,
       _onContentChanged = onContentChanged,
       _onDeleted = onDeleted,
       _onEdit = onEdit,
       _onDueDateChanged = onDueDateChanged;

  factory ServiceTaskCallbacks.fromController({
    required DomainTaskController controller,
    required void Function(String taskId) onEdit,
  }) {
    return ServiceTaskCallbacks(
      onStatusChanged: (taskId, status) => controller.setStatus(taskId, status),
      onPriorityChanged: (taskId, priority) =>
          controller.setPriority(taskId, priority),
      onContentChanged: (taskId, content) =>
          controller.updateTaskContents(taskId: taskId, title: content),
      onDeleted: controller.deleteTask,
      onEdit: onEdit,
      onDueDateChanged: (taskId, date) => controller.setDueDate(taskId, date),
    );
  }

  @override
  Future<void> onStatusChanged(String taskId, domain.TaskStatus newStatus) =>
      _onStatusChanged(taskId, newStatus);

  @override
  Future<void> onPriorityChanged(
    String taskId,
    domain.TaskPriority newPriority,
  ) => _onPriorityChanged(taskId, newPriority);

  @override
  Future<void> onContentChanged(String taskId, String newContent) =>
      _onContentChanged(taskId, newContent);

  @override
  Future<void> onDeleted(String taskId) => _onDeleted(taskId);

  @override
  void onEdit(String taskId) => _onEdit(taskId);

  @override
  Future<void> onDueDateChanged(String taskId, DateTime? newDate) =>
      _onDueDateChanged(taskId, newDate);
}
