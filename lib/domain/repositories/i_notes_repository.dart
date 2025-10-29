import 'package:duru_notes/domain/entities/note.dart';

/// Domain interface for notes core operations
abstract class INotesRepository {
  /// Get a note by ID
  Future<Note?> getNoteById(String id);

  /// Create or update a note
  Future<Note?> createOrUpdate({
    required String title,
    required String body,
    String? id,
    String? folderId,
    List<String> tags = const [],
    List<Map<String, String?>> links = const [],
    Map<String, dynamic>? attachmentMeta,
    Map<String, dynamic>? metadataJson,
    bool? isPinned,
    DateTime? createdAt, // SYNC FIX: Allow sync to preserve remote timestamps
    DateTime? updatedAt, // SYNC FIX: Allow sync to preserve remote timestamps
  });

  /// Update an existing note
  Future<void> updateLocalNote(
    String id, {
    String? title,
    String? body,
    bool? deleted,
    String? folderId,
    bool updateFolder = false,
    Map<String, dynamic>? attachmentMeta,
    Map<String, dynamic>? metadata,
    List<Map<String, String?>>? links,
    bool? isPinned,
  });

  /// Delete a note
  Future<void> deleteNote(String id);

  /// Get all local notes for sync (includes system notes like standalone task container)
  Future<List<Note>> localNotesForSync();

  /// Get all local notes for UI display (filters out system notes)
  Future<List<Note>> localNotes();

  /// Get recently viewed notes
  Future<List<Note>> getRecentlyViewedNotes({int limit = 5});

  /// List notes with pagination
  Future<List<Note>> listAfter(DateTime? cursor, {int limit = 20});

  /// Toggle note pin status
  Future<void> toggleNotePin(String noteId);

  /// Set note pin status
  Future<void> setNotePin(String noteId, bool isPinned);

  /// Get all pinned notes
  Future<List<Note>> getPinnedNotes();

  /// Watch notes stream with filters
  Stream<List<Note>> watchNotes({
    String? folderId,
    List<String>? anyTags,
    List<String>? noneTags,
    bool pinnedFirst = true,
  });

  /// List all notes
  Future<List<Note>> list({int? limit});

  /// Get count of notes in a folder
  Future<int> getNotesCountInFolder(String folderId);

  /// Get note IDs in a folder
  Future<List<String>> getNoteIdsInFolder(String folderId);

  /// Sync operations
  Future<void> sync();
  Future<void> pushAllPending();
  Future<void> pullSince(DateTime? since);
  Future<DateTime?> getLastSyncTime();
}
