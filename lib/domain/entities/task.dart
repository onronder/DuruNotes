class Task {
  final String id;
  final String noteId;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  const Task({
    required this.id,
    required this.noteId,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.dueDate,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    required this.metadata,
  });

  Task copyWith({
    String? id,
    String? noteId,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return Task(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Task &&
        other.id == id &&
        other.noteId == noteId &&
        other.title == title &&
        other.status == status &&
        other.priority == priority;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        noteId.hashCode ^
        title.hashCode ^
        status.hashCode ^
        priority.hashCode;
  }

  @override
  String toString() {
    return 'Task(id: $id, title: $title, status: $status, priority: $priority)';
  }
}

enum TaskStatus { pending, inProgress, completed, cancelled }

enum TaskPriority { low, medium, high, urgent }
