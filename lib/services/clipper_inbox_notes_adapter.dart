import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/services/clipper_inbox_service.dart';

class CaptureNotesAdapter implements NotesCapturePort {
  CaptureNotesAdapter({required NotesRepository repository, required AppDb db})
    : _repository = repository,
      _db = db;
  final NotesRepository _repository;
  final AppDb _db;

  @override
  Future<String> createEncryptedNote({
    required String title,
    required String body,
    required Map<String, dynamic> metadataJson,
    List<String> tags = const [],
  }) async {
    // Build the body with tags only (no metadata comments)
    final bodyWithTags = _buildBodyWithTags(body, tags);

    // PRODUCTION FIX: Convert tags to normalized set for database storage
    final tagSet = <String>{};
    for (final tag in tags) {
      // Remove # if present and normalize to lowercase
      final normalizedTag = tag.startsWith('#')
          ? tag.substring(1).toLowerCase()
          : tag.toLowerCase();
      if (normalizedTag.isNotEmpty) {
        tagSet.add(normalizedTag);
      }
    }

    // PRODUCTION FIX: Also extract hashtags from body
    final hashtagRegex = RegExp(r'#(\w+)');
    final matches = hashtagRegex.allMatches(body);
    for (final match in matches) {
      final tag = match.group(1);
      if (tag != null) {
        tagSet.add(tag.toLowerCase());
      }
    }

    // Use the existing NotesRepository method to create the note
    // This will handle encryption, indexing, and sync queue
    // Now we pass metadata directly to the repository
    final note = await _repository.createOrUpdate(
      title: title,
      body: bodyWithTags,
      tags:
          tagSet, // PRODUCTION FIX: Pass normalized tags to be stored in note_tags table
      metadataJson: metadataJson.isNotEmpty ? metadataJson : null,
    );

    // The indexer will automatically extract and index the tags from the body
    return note?.id ?? '';
  }

  String _buildBodyWithTags(String body, List<String> tags) {
    final buffer = StringBuffer();

    // Add the main body content
    buffer.write(body);

    // Add tags as hashtags at the end if not already present
    if (tags.isNotEmpty) {
      buffer.writeln('\n');
      for (final tag in tags) {
        final tagFormatted = tag.startsWith('#') ? tag : '#$tag';
        if (!body.contains(tagFormatted)) {
          buffer.write('$tagFormatted ');
        }
      }
    }

    return buffer.toString().trimRight();
  }
}
