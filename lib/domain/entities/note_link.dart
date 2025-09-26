/// Domain entity representing a link between notes
class NoteLink {
  final String id;
  final String fromNoteId; // Source note ID
  final String toNoteId; // Target note ID
  final String linkType; // 'reference', 'related', 'parent', 'child'
  final String? linkText; // Display text for the link
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const NoteLink({
    required this.id,
    required this.fromNoteId,
    required this.toNoteId,
    required this.linkType,
    this.linkText,
    required this.createdAt,
    this.metadata,
  });

  // Helper getters
  bool get isReference => linkType == 'reference';
  bool get isRelated => linkType == 'related';
  bool get isHierarchical => linkType == 'parent' || linkType == 'child';
  bool get isParent => linkType == 'parent';
  bool get isChild => linkType == 'child';

  NoteLink copyWith({
    String? id,
    String? fromNoteId,
    String? toNoteId,
    String? linkType,
    String? linkText,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return NoteLink(
      id: id ?? this.id,
      fromNoteId: fromNoteId ?? this.fromNoteId,
      toNoteId: toNoteId ?? this.toNoteId,
      linkType: linkType ?? this.linkType,
      linkText: linkText ?? this.linkText,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteLink &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'NoteLink(from: $fromNoteId, to: $toNoteId, type: $linkType)';
}