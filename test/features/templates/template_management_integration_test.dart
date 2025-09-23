import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/repository/template_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

/// Integration test for template management system
void main() {
  group('Template Management Integration Tests', () {
    late AppDb database;
    late TemplateRepository repository;

    setUp(() async {
      // Create in-memory database for testing
      database = AppDb.forTesting(NativeDatabase.memory());
      repository = TemplateRepository(db: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('should create and retrieve user template', () async {
      // Create a user template
      final template = await repository.createUserTemplate(
        title: 'Test Template',
        body: 'This is a test template with {{placeholder}}',
        category: 'work',
        description: 'A test template for integration testing',
        tags: ['test', 'integration'],
      );

      expect(template, isNotNull);
      expect(template!.title, equals('Test Template'));
      expect(template.isSystem, isFalse);
      expect(template.category, equals('work'));

      // Retrieve the template
      final retrieved = await repository.getTemplate(template.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Test Template'));
      expect(retrieved.body, contains('{{placeholder}}'));
    });

    test('should update user template', () async {
      // Create a template
      final original = await repository.createUserTemplate(
        title: 'Original Template',
        body: 'Original content',
        category: 'personal',
      );

      expect(original, isNotNull);

      // Update the template
      final updated = await repository.updateUserTemplate(
        id: original!.id,
        title: 'Updated Template',
        body: 'Updated content with {{variable}}',
        category: 'work',
        description: 'Updated description',
      );

      expect(updated, isTrue);

      // Verify the update
      final retrieved = await repository.getTemplate(original.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Updated Template'));
      expect(retrieved.body, equals('Updated content with {{variable}}'));
      expect(retrieved.category, equals('work'));
      expect(retrieved.description, equals('Updated description'));
    });

    test('should delete user template', () async {
      // Create a template
      final template = await repository.createUserTemplate(
        title: 'Template to Delete',
        body: 'This will be deleted',
        category: 'test',
      );

      expect(template, isNotNull);

      // Delete the template
      final deleted = await repository.deleteUserTemplate(template!.id);
      expect(deleted, isTrue);

      // Verify it's deleted
      final retrieved = await repository.getTemplate(template.id);
      expect(retrieved, isNull);
    });

    test('should not delete system templates', () async {
      // Initialize system templates
      await database._initializeSystemTemplates();

      // Get a system template
      final systemTemplates = await repository.getSystemTemplates();
      expect(systemTemplates, isNotEmpty);

      final systemTemplate = systemTemplates.first;
      expect(systemTemplate.isSystem, isTrue);

      // Try to delete it
      final deleted = await repository.deleteUserTemplate(systemTemplate.id);
      expect(deleted, isFalse);

      // Verify it still exists
      final retrieved = await repository.getTemplate(systemTemplate.id);
      expect(retrieved, isNotNull);
    });

    test('should filter templates by category', () async {
      // Create templates in different categories
      await repository.createUserTemplate(
        title: 'Work Template 1',
        body: 'Work content 1',
        category: 'work',
      );

      await repository.createUserTemplate(
        title: 'Work Template 2',
        body: 'Work content 2',
        category: 'work',
      );

      await repository.createUserTemplate(
        title: 'Personal Template',
        body: 'Personal content',
        category: 'personal',
      );

      // Filter by work category
      final workTemplates = await repository.getTemplatesByCategory('work');
      expect(workTemplates, hasLength(2));
      expect(workTemplates.every((t) => t.category == 'work'), isTrue);

      // Filter by personal category
      final personalTemplates = await repository.getTemplatesByCategory('personal');
      expect(personalTemplates, hasLength(1));
      expect(personalTemplates.first.category, equals('personal'));
    });

    test('should create note data from template', () async {
      // Create a template with variables
      final template = await repository.createUserTemplate(
        title: 'Meeting Notes Template',
        body: '''# Meeting Notes
Date: {{date}}
Attendees: {{attendees}}

## Agenda
{{agenda}}

## Action Items
- [ ] {{action1}}
- [ ] {{action2}}
''',
        category: 'meeting',
        tags: ['meeting', 'notes'],
      );

      expect(template, isNotNull);

      // Create note data from template
      final noteData = repository.createNoteFromTemplate(template!);

      expect(noteData, isNotNull);
      expect(noteData['title'], equals('Meeting Notes Template'));
      expect(noteData['body'], contains('{{date}}'));
      expect(noteData['body'], contains('{{attendees}}'));
      expect(noteData['tags'], isA<List>());
      expect(noteData['metadata'], isA<Map>());

      final metadata = noteData['metadata'] as Map;
      expect(metadata['createdFromTemplate'], isTrue);
      expect(metadata['templateId'], equals(template.id));
      expect(metadata['templateCategory'], equals('meeting'));
    });

    test('should export and import templates', () async {
      // Create a template
      final original = await repository.createUserTemplate(
        title: 'Export Test Template',
        body: 'Content for export test',
        category: 'test',
        description: 'Template for testing export/import',
        tags: ['export', 'test'],
      );

      expect(original, isNotNull);

      // Export the template
      final exported = repository.exportTemplate(original!);

      expect(exported, isNotNull);
      expect(exported['title'], equals('Export Test Template'));
      expect(exported['body'], equals('Content for export test'));
      expect(exported['category'], equals('test'));
      expect(exported['tags'], isA<List>());
      expect(exported['version'], equals('1.0'));

      // Import the template (this creates a new template)
      final imported = await repository.importTemplate(exported);

      expect(imported, isNotNull);
      expect(imported!.title, equals('Export Test Template'));
      expect(imported.body, equals('Content for export test'));
      expect(imported.category, equals('test'));
      expect(imported.isSystem, isFalse);
    });

    test('should get template statistics', () async {
      // Create templates
      await repository.createUserTemplate(
        title: 'Work Template',
        body: 'Work content',
        category: 'work',
      );

      await repository.createUserTemplate(
        title: 'Personal Template',
        body: 'Personal content',
        category: 'personal',
      );

      // Initialize system templates
      await database._initializeSystemTemplates();

      // Get statistics
      final stats = await repository.getTemplateStatistics();

      expect(stats, isNotNull);
      expect(stats['totalTemplates'], greaterThan(0));
      expect(stats['systemTemplates'], greaterThan(0));
      expect(stats['userTemplates'], equals(2));
      expect(stats['categoryCounts'], isA<Map>());

      final categoryCounts = stats['categoryCounts'] as Map<String, int>;
      expect(categoryCounts['work'], greaterThan(0));
      expect(categoryCounts['personal'], greaterThan(0));
    });

    test('should handle template errors gracefully', () async {
      // Test creating template with empty title
      final emptyTemplate = await repository.createUserTemplate(
        title: '',
        body: 'Content',
        category: 'test',
      );
      expect(emptyTemplate, isNull);

      // Test updating non-existent template
      final updateResult = await repository.updateUserTemplate(
        id: 'non-existent-id',
        title: 'Updated Title',
      );
      expect(updateResult, isFalse);

      // Test deleting non-existent template
      final deleteResult = await repository.deleteUserTemplate('non-existent-id');
      expect(deleteResult, isFalse);
    });
  });
}