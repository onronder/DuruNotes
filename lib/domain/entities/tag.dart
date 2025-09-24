/// Pure domain entity for Tag
/// This is infrastructure-agnostic and contains only business logic
class Tag {
  final String name;
  final int count;

  const Tag({
    required this.name,
    required this.count,
  });

  Tag copyWith({
    String? name,
    int? count,
  }) {
    return Tag(
      name: name ?? this.name,
      count: count ?? this.count,
    );
  }
}

/// Domain entity for tag with usage count
class TagWithCount {
  final String tag;
  final int noteCount;

  const TagWithCount({
    required this.tag,
    required this.noteCount,
  });
}