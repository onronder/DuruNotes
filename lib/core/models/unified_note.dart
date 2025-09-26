// Unified Note type that bridges LocalNote and domain.Note
// This removes the need for conditional logic based on migration status

import 'dart:convert';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/data/local/app_db.dart';

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

  // Factory constructors to create from different sources
  factory UnifiedNote.fromLocal(LocalNote note) = _UnifiedNoteFromLocal;
  factory UnifiedNote.fromDomain(domain.Note note) = _UnifiedNoteFromDomain;
  
  // Smart factory that detects type
  factory UnifiedNote.from(dynamic note) {
    if (note is LocalNote) return UnifiedNote.fromLocal(note);
    if (note is domain.Note) return UnifiedNote.fromDomain(note);
    if (note is UnifiedNote) return note;
    throw ArgumentError('Unknown note type: ${note.runtimeType}');
  }

  // Convert to the required format
  LocalNote toLocal();
  domain.Note toDomain();
}

class _UnifiedNoteFromLocal implements UnifiedNote {
  final LocalNote _note;

  _UnifiedNoteFromLocal(this._note);

  @override
  String get id => _note.id;

  @override
  String get title => _note.title;

  @override
  String get body => _note.body;

  @override
  DateTime get createdAt => _note.updatedAt; // LocalNote doesn't have createdAt

  @override
  DateTime get updatedAt => _note.updatedAt;

  @override
  bool get deleted => _note.deleted;

  @override
  bool get isPinned => _note.isPinned;

  @override
  String get userId => _note.userId ?? ''; // LocalNote has nullable userId

  @override
  int get version => _note.version;

  @override
  String? get folderId => null; // LocalNote doesn't have folderId directly

  @override
  List<String> get tags => [];

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
  LocalNote toLocal() => _note;

  @override
  domain.Note toDomain() => domain.Note(
    id: _note.id,
    title: _note.title,
    body: _note.body,
    updatedAt: _note.updatedAt,
    deleted: _note.deleted,
    isPinned: _note.isPinned,
    noteType: _note.noteType,
    userId: _note.userId ?? '',
    folderId: null,
    tags: [],
    links: [],
    version: _note.version,
    metadata: _note.metadata,
    attachmentMeta: _note.attachmentMeta,
    encryptedMetadata: _note.encryptedMetadata,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UnifiedNoteFromLocal && _note.id == other._note.id;

  @override
  int get hashCode => _note.id.hashCode;
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
  LocalNote toLocal() => LocalNote(
    id: _note.id,
    title: _note.title,
    body: _note.body,
    updatedAt: _note.updatedAt,
    deleted: _note.deleted,
    isPinned: _note.isPinned,
    noteType: _note.noteType,
    userId: _note.userId,
    version: _note.version,
    metadata: _note.metadata,
    encryptedMetadata: _note.encryptedMetadata,
    attachmentMeta: _note.attachmentMeta,
  );

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