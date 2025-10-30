import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/domain/entities/tag.dart';

/// Domain interface for tag operations
abstract class ITagRepository {
  /// List all tags with their counts
  Future<List<TagWithCount>> listTagsWithCounts();

  /// Add a tag to a note
  Future<void> addTag({required String noteId, required String tag});

  /// Remove a tag from a note
  Future<void> removeTag({required String noteId, required String tag});

  /// Rename a tag everywhere
  Future<int> renameTagEverywhere({
    required String oldTag,
    required String newTag,
  });

  /// Query notes by tags
  Future<List<Note>> queryNotesByTags({
    List<String> anyTags = const [],
    List<String> allTags = const [],
    List<String> noneTags = const [],
  });

  /// Search tags by prefix
  Future<List<String>> searchTags(String prefix);

  /// Get all tags for a specific note
  Future<List<String>> getTagsForNote(String noteId);
}
