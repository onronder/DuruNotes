import 'package:duru_notes/domain/entities/note.dart';

/// Domain interface for template operations
abstract class ITemplateRepository {
  /// List all templates
  Future<List<Note>> listTemplates();

  /// Create a new template
  Future<Note?> createTemplate({
    required String title,
    required String body,
    List<String> tags = const [],
    Map<String, dynamic>? metadata,
  });

  /// Create a note from a template
  Future<Note?> createNoteFromTemplate(String templateId);

  /// Delete a template
  Future<bool> deleteTemplate(String templateId);
}