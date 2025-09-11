import 'package:duru_notes/services/clipper_inbox_service.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/data/local/app_db.dart';

class CaptureNotesAdapter implements NotesCapturePort {
  final NotesRepository _repository;
  final AppDb _db;
  
  CaptureNotesAdapter({
    required NotesRepository repository,
    required AppDb db,
  }) : _repository = repository,
       _db = db;

  @override
  Future<String> createEncryptedNote({
    required String title,
    required String body,
    required Map<String, dynamic> metadataJson,
    List<String> tags = const [],
  }) async {
    // Build the body with tags only (no metadata comments)
    final bodyWithTags = _buildBodyWithTags(body, tags);
    
    // Use the existing NotesRepository method to create the note
    // This will handle encryption, indexing, and sync queue
    // Now we pass metadata directly to the repository
    final note = await _repository.createOrUpdate(
      title: title,
      body: bodyWithTags,
      metadataJson: metadataJson.isNotEmpty ? metadataJson : null,
    );
    
    // The indexer will automatically extract and index the tags from the body
    return note?.id ?? '';
  }
  
  String _buildBodyWithTags(
    String body, 
    List<String> tags,
  ) {
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
