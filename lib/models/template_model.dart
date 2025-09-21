/// Template model for note templates (both system and user-defined)
///
/// Templates are blueprints for creating notes, not notes themselves.
/// They exist separately from notes and generate new notes when used.
library;

class Template {
  Template({
    required this.id,
    required this.title,
    required this.body,
    required this.tags,
    required this.isSystem,
    required this.category,
    required this.description,
    required this.icon,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  final String id;
  final String title;
  final String body;
  final List<String> tags;
  final bool isSystem; // true for built-in templates, false for user-created
  final String category; // 'work', 'personal', 'meeting', 'planning', etc.
  final String description; // Short description for the template picker
  final String icon; // Icon identifier for UI
  final int sortOrder; // Display order in template picker
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata; // Additional template settings

  /// Create a copy with optional updates
  Template copyWith({
    String? id,
    String? title,
    String? body,
    List<String>? tags,
    bool? isSystem,
    String? category,
    String? description,
    String? icon,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Template(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      tags: tags ?? this.tags,
      isSystem: isSystem ?? this.isSystem,
      category: category ?? this.category,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON for storage/sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'tags': tags,
      'is_system': isSystem,
      'category': category,
      'description': description,
      'icon': icon,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory Template.fromJson(Map<String, dynamic> json) {
    return Template(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      isSystem: json['is_system'] as bool,
      category: json['category'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      sortOrder: json['sort_order'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Template && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Template categories
class TemplateCategory {
  static const String work = 'work';
  static const String personal = 'personal';
  static const String meeting = 'meeting';
  static const String planning = 'planning';
  static const String education = 'education';
  static const String creative = 'creative';
  static const String review = 'review';
}

/// Template icons (using Material Icons identifiers)
class TemplateIcon {
  static const String meeting = 'meeting_room';
  static const String daily = 'today';
  static const String project = 'rocket_launch';
  static const String book = 'menu_book';
  static const String weekly = 'calendar_view_week';
  static const String idea = 'lightbulb';
  static const String checklist = 'checklist';
  static const String journal = 'book';
}
