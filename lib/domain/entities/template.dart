class Template {
  final String id;
  final String name;
  final String content;
  final Map<String, dynamic> variables;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Template({
    required this.id,
    required this.name,
    required this.content,
    required this.variables,
    required this.isSystem,
    required this.createdAt,
    required this.updatedAt,
  });

  Template copyWith({
    String? id,
    String? name,
    String? content,
    Map<String, dynamic>? variables,
    bool? isSystem,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Template(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      variables: variables ?? this.variables,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Template &&
        other.id == id &&
        other.name == name &&
        other.content == content &&
        other.isSystem == isSystem;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ content.hashCode ^ isSystem.hashCode;
  }

  @override
  String toString() {
    return 'Template(id: $id, name: $name, isSystem: $isSystem)';
  }
}
