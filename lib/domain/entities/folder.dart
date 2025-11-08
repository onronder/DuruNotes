/// Pure domain entity for Folder
/// This is infrastructure-agnostic and contains only business logic
class Folder {
  final String id;
  final String name;
  final String? parentId;
  final String? color;
  final String? icon;
  final String? description;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? scheduledPurgeAt;
  final String userId;

  const Folder({
    required this.id,
    required this.name,
    this.parentId,
    this.color,
    this.icon,
    this.description,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.scheduledPurgeAt,
    required this.userId,
  });

  Folder copyWith({
    String? id,
    String? name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? scheduledPurgeAt,
    String? userId,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      scheduledPurgeAt: scheduledPurgeAt ?? this.scheduledPurgeAt,
      userId: userId ?? this.userId,
    );
  }
}
