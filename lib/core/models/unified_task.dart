// Unified Task type that bridges LocalTask and domain.Task
// This removes the need for conditional logic based on migration status

import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/data/local/app_db.dart';

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

  // Factory constructors to create from different sources
  factory UnifiedTask.fromLocal(NoteTask task) = _UnifiedTaskFromLocal;
  factory UnifiedTask.fromDomain(domain.Task task) = _UnifiedTaskFromDomain;

  // Smart factory that detects type
  factory UnifiedTask.from(dynamic task) {
    if (task is NoteTask) return UnifiedTask.fromLocal(task);
    if (task is domain.Task) return UnifiedTask.fromDomain(task);
    if (task is UnifiedTask) return task;
    throw ArgumentError('Unknown task type: ${task.runtimeType}');
  }

  // Convert to the required format
  NoteTask toLocal();
  domain.Task toDomain();

  // Helper methods
  bool get isCompleted => status == '1' || status == domain.TaskStatus.completed.toString();
  bool get isPending => status == '0' || status == domain.TaskStatus.pending.toString();
  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now()) && !isCompleted;
}

class _UnifiedTaskFromLocal implements UnifiedTask {
  final NoteTask _task;

  _UnifiedTaskFromLocal(this._task);

  @override
  String get id => _task.id;

  @override
  String get content => _task.content;

  @override
  String? get noteId => _task.noteId;

  @override
  String? get description => null; // LocalTask doesn't have description

  @override
  DateTime? get dueDate => _task.dueDate;

  @override
  DateTime get createdAt => _task.createdAt;

  @override
  DateTime get updatedAt => _task.updatedAt;

  @override
  String get status => _task.status == TaskStatus.completed ? '1' : '0';

  @override
  int get priority => _task.priority?.index ?? 0;

  @override
  bool get deleted => _task.deleted;

  @override
  String get userId => ''; // NoteTask doesn't have userId

  @override
  int get version => 1; // NoteTask doesn't have version

  @override
  List<String> get tags => [];

  @override
  Map<String, dynamic>? get metadata => null; // NoteTask doesn't have metadata

  @override
  bool get isCompleted => status == '1' || status == domain.TaskStatus.completed.toString();

  @override
  bool get isPending => status == '0' || status == domain.TaskStatus.pending.toString();

  @override
  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now()) && !isCompleted;

  @override
  NoteTask toLocal() => _task;

  @override
  domain.Task toDomain() => domain.Task(
    id: _task.id,
    noteId: _task.noteId ?? '',
    title: _task.content,
    content: null,
    status: _task.status == '1'
        ? domain.TaskStatus.completed
        : domain.TaskStatus.pending,
    priority: domain.TaskPriority.values.firstWhere(
      (p) => p.index == (_task.priority ?? 0),
      orElse: () => domain.TaskPriority.medium,
    ),
    dueDate: _task.dueDate,
    completedAt: isCompleted ? DateTime.now() : null,
    tags: [],
    metadata: {},
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UnifiedTaskFromLocal && _task.id == other._task.id;

  @override
  int get hashCode => _task.id.hashCode;
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
  String? get description => _task.content;

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
  Map<String, dynamic>? get metadata => _task.metadata.isNotEmpty ? _task.metadata : null;

  @override
  bool get isCompleted => _task.status == domain.TaskStatus.completed;

  @override
  bool get isPending => _task.status == domain.TaskStatus.pending;

  @override
  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now()) && !isCompleted;

  @override
  NoteTask toLocal() => NoteTask(
    id: _task.id,
    content: _task.title,
    noteId: _task.noteId,
    status: _task.status == domain.TaskStatus.completed
        ? TaskStatus.completed
        : TaskStatus.open,
    priority: TaskPriority.values[_task.priority.index],
    dueDate: _task.dueDate,
    completedAt: _task.completedAt,
    completedBy: null,
    position: 0,
    contentHash: _task.title.hashCode.toString(),
    reminderId: null,
    labels: _task.tags.join(','),
    notes: _task.content,
    estimatedMinutes: null,
    actualMinutes: null,
    parentTaskId: null,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    deleted: false,
  );

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