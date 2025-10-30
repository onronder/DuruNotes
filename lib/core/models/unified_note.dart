// Unified Note type that wraps domain.Note
// Post-encryption migration: All data flows through domain entities (already decrypted)
// LocalNote is now only used at the infrastructure layer with encrypted fields

import 'dart:convert';
import 'package:duru_notes/domain/entities/note.dart' as domain;

abstract class UnifiedNote {
  String get id;
  String get title;
  String get body;
  DateTime get createdAt;
  DateTime get updatedAt;
  bool get deleted;
  bool get isPinned;
  String get userId;
  int get version;
  String? get folderId;
  List<String> get tags;
  Map<String, dynamic>? get metadata;

  // Factory constructor - only works with domain entities now
  factory UnifiedNote.fromDomain(domain.Note note) = _UnifiedNoteFromDomain;

  // Smart factory that detects type
  factory UnifiedNote.from(dynamic note) {
    if (note is domain.Note) return UnifiedNote.fromDomain(note);
    if (note is UnifiedNote) return note;
    throw ArgumentError(
      'Unknown note type: ${note.runtimeType}. Only domain.Note is supported post-migration.',
    );
  }

  // Convert to domain format
  domain.Note toDomain();
}

class _UnifiedNoteFromDomain implements UnifiedNote {
  final domain.Note _note;

  _UnifiedNoteFromDomain(this._note);

  @override
  String get id => _note.id;

  @override
  String get title => _note.title;

  @override
  String get body => _note.body;

  @override
  DateTime get createdAt => _note.updatedAt; // domain.Note doesn't have createdAt

  @override
  DateTime get updatedAt => _note.updatedAt;

  @override
  bool get deleted => _note.deleted;

  @override
  bool get isPinned => _note.isPinned;

  @override
  String get userId => _note.userId;

  @override
  int get version => _note.version;

  @override
  String? get folderId => _note.folderId;

  @override
  List<String> get tags => _note.tags;

  @override
  Map<String, dynamic>? get metadata {
    // Parse metadata string to Map if it exists
    if (_note.metadata != null && _note.metadata!.isNotEmpty) {
      try {
        return Map<String, dynamic>.from(jsonDecode(_note.metadata!) as Map);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  domain.Note toDomain() => _note;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UnifiedNoteFromDomain && _note.id == other._note.id;

  @override
  int get hashCode => _note.id.hashCode;
}

// Unified pagination that works with a single type
class UnifiedNotesPage {
  final List<UnifiedNote> notes;
  final bool hasMore;
  final int currentPage;
  final int totalCount;

  UnifiedNotesPage({
    required this.notes,
    required this.hasMore,
    required this.currentPage,
    this.totalCount = 0,
  });

  UnifiedNotesPage copyWith({
    List<UnifiedNote>? notes,
    bool? hasMore,
    int? currentPage,
    int? totalCount,
  }) {
    return UnifiedNotesPage(
      notes: notes ?? this.notes,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}
