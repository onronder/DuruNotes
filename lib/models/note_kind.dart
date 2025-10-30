/// Note type enumeration to distinguish between regular notes and templates
enum NoteKind {
  note, // Regular note (default)
  template, // Note template
}

/// Extension methods for NoteKind enum
extension NoteKindX on NoteKind {
  /// Get integer representation for database storage
  int get index => this == NoteKind.note ? 0 : 1;

  /// Get string representation for database/API
  String get db => this == NoteKind.note ? 'note' : 'template';

  /// Parse from integer value (defaults to note for null/invalid)
  static NoteKind parse(int? v) => v == 1 ? NoteKind.template : NoteKind.note;
}
