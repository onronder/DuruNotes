// Unified Task type that wraps domain.Task
// Post-encryption migration: All data flows through domain entities (already decrypted)
// NoteTask is now only used at the infrastructure layer with encrypted fields

import 'package:duru_notes/domain/entities/task.dart' as domain;

abstract class UnifiedTask {
  String get id;
  String get content;
  String? get noteId;
  String? get description;
  DateTime? get dueDate;
  DateTime get createdAt;
  DateTime get updatedAt;
  String get status;
  int get priority;
  bool get deleted;
  String get userId;
  int get version;
  List<String> get tags;
  Map<String, dynamic>? get metadata;

  // Factory constructor - only works with domain entities now
  factory UnifiedTask.fromDomain(domain.Task task) = _UnifiedTaskFromDomain;

  // Smart factory that detects type
  factory UnifiedTask.from(dynamic task) {
    if (task is domain.Task) return UnifiedTask.fromDomain(task);
    if (task is UnifiedTask) return task;
    throw ArgumentError(
      'Unknown task type: ${task.runtimeType}. Only domain.Task is supported post-migration.',
    );
  }

  // Convert to domain format
  domain.Task toDomain();

  // Helper methods
  bool get isCompleted => status == domain.TaskStatus.completed.toString();
  bool get isPending => status == domain.TaskStatus.pending.toString();
  bool get isOverdue =>
      dueDate != null && dueDate!.isBefore(DateTime.now()) && !isCompleted;
}

class _UnifiedTaskFromDomain implements UnifiedTask {
  final domain.Task _task;

  _UnifiedTaskFromDomain(this._task);

  @override
  String get id => _task.id;

  @override
  String get content => _task.title;

  @override
  String? get noteId => _task.noteId;

  @override
  String? get description => _task.description;

  @override
  DateTime? get dueDate => _task.dueDate;

  @override
  DateTime get createdAt => DateTime.now(); // domain.Task doesn't have createdAt

  @override
  DateTime get updatedAt => DateTime.now(); // domain.Task doesn't have updatedAt

  @override
  String get status => _task.status == domain.TaskStatus.completed ? '1' : '0';

  @override
  int get priority => _task.priority.index;

  @override
  bool get deleted => false; // domain.Task doesn't have deleted flag

  @override
  String get userId => ''; // domain.Task doesn't have userId

  @override
  int get version => 1; // domain.Task doesn't have version

  @override
  List<String> get tags => _task.tags;

  @override
  Map<String, dynamic>? get metadata =>
      _task.metadata.isNotEmpty ? _task.metadata : null;

  @override
  bool get isCompleted => _task.status == domain.TaskStatus.completed;

  @override
  bool get isPending => _task.status == domain.TaskStatus.pending;

  @override
  bool get isOverdue =>
      dueDate != null && dueDate!.isBefore(DateTime.now()) && !isCompleted;

  @override
  domain.Task toDomain() => _task;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UnifiedTaskFromDomain && _task.id == other._task.id;

  @override
  int get hashCode => _task.id.hashCode;
}

// Unified task list that works with a single type
class UnifiedTaskList {
  final List<UnifiedTask> tasks;
  final bool hasMore;
  final int currentPage;
  final int totalCount;

  UnifiedTaskList({
    required this.tasks,
    this.hasMore = false,
    this.currentPage = 0,
    this.totalCount = 0,
  });

  UnifiedTaskList copyWith({
    List<UnifiedTask>? tasks,
    bool? hasMore,
    int? currentPage,
    int? totalCount,
  }) {
    return UnifiedTaskList(
      tasks: tasks ?? this.tasks,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}
