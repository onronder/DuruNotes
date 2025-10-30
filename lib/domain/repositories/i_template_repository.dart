import '../entities/template.dart';

/// Domain interface for template operations
abstract class ITemplateRepository {
  /// Get all templates
  Future<List<Template>> getAllTemplates();

  /// Get system templates
  Future<List<Template>> getSystemTemplates();

  /// Get user-created templates
  Future<List<Template>> getUserTemplates();

  /// Get template by ID
  Future<Template?> getTemplateById(String id);

  /// Create a new template
  Future<Template> createTemplate(Template template);

  /// Update an existing template
  Future<Template> updateTemplate(Template template);

  /// Delete a template
  Future<void> deleteTemplate(String id);

  /// Watch templates stream
  Stream<List<Template>> watchTemplates();

  /// Apply a template to create a note
  /// Returns the created note ID
  Future<String> applyTemplate({
    required String templateId,
    required Map<String, dynamic> variableValues,
  });

  /// Duplicate an existing template
  Future<Template> duplicateTemplate({
    required String templateId,
    required String newName,
  });
}
