/// Folder model for Phase 2 UI components
/// 
/// This is a simplified folder model for demonstrating the
/// refactored UI components. In production, this would integrate
/// with the existing folder system.

class LocalFolder {
  final String id;
  final String name;
  final String? parentId;
  final bool isSpecial;
  final String? specialType;
  final bool hasChildren;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? color;
  final String? icon;
  final int sortOrder;
  
  const LocalFolder({
    required this.id,
    required this.name,
    this.parentId,
    this.isSpecial = false,
    this.specialType,
    this.hasChildren = false,
    required this.createdAt,
    required this.updatedAt,
    this.color,
    this.icon,
    this.sortOrder = 0,
  });
  
  LocalFolder copyWith({
    String? id,
    String? name,
    String? parentId,
    bool? isSpecial,
    String? specialType,
    bool? hasChildren,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? color,
    String? icon,
    int? sortOrder,
  }) {
    return LocalFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      isSpecial: isSpecial ?? this.isSpecial,
      specialType: specialType ?? this.specialType,
      hasChildren: hasChildren ?? this.hasChildren,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
