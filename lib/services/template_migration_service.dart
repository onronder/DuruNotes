import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';

/// Service to migrate templates from local_notes to local_templates table
class TemplateMigrationService {
  final AppDb _db;
  final AppLogger _logger = LoggerFactory.instance;

  TemplateMigrationService(this._db);

  /// Migrate all templates from local_notes to local_templates
  Future<void> migrateTemplates() async {
    try {
      _logger.info('Starting template migration...');

      // Get all notes with noteType = template (value 1)
      final templateNotes = await (_db.select(_db.localNotes)
            ..where((n) => n.noteType.equals(1))) // 1 = template type
          .get();

      if (templateNotes.isEmpty) {
        _logger.info('No templates to migrate');
        return;
      }

      _logger.info('Found ${templateNotes.length} templates to migrate');

      for (final templateNote in templateNotes) {
        try {
          // Check if template already exists in local_templates
          final existingTemplate = await (_db.select(_db.localTemplates)
                ..where((t) => t.id.equals(templateNote.id)))
              .getSingleOrNull();

          if (existingTemplate != null) {
            _logger.debug('Template ${templateNote.id} already migrated');
            continue;
          }

          // Templates from notes don't have tags in the same format
          List<String> tags = [];

          // Determine category and icon based on title
          String category = 'general';
          String icon = 'description';
          String description = templateNote.title;

          if (templateNote.title.contains('Meeting')) {
            category = 'meeting';
            icon = 'groups';
          } else if (templateNote.title.contains('Daily')) {
            category = 'daily';
            icon = 'today';
          } else if (templateNote.title.contains('Project')) {
            category = 'project';
            icon = 'work';
          } else if (templateNote.title.contains('Book')) {
            category = 'personal';
            icon = 'book';
          } else if (templateNote.title.contains('Weekly')) {
            category = 'review';
            icon = 'calendar_view_week';
          }

          // Create template in local_templates table
          final template = LocalTemplate(
            id: templateNote.id,
            title: templateNote.title,
            body: templateNote.body,
            tags: tags.toString(),
            isSystem: true, // Mark as system since they came from sync
            category: category,
            description: description,
            icon: icon,
            sortOrder: 0,
            metadata: null,
            createdAt: DateTime.now(),
            updatedAt: templateNote.updatedAt,
          );

          await _db.into(_db.localTemplates).insertOnConflictUpdate(template);
          _logger.info('Migrated template: ${templateNote.title}');
        } catch (e, stack) {
          _logger.error('Failed to migrate template ${templateNote.id}',
              error: e, stackTrace: stack);
        }
      }

      _logger.info('Template migration completed successfully');
    } catch (e, stack) {
      _logger.error('Template migration failed', error: e, stackTrace: stack);
    }
  }

  /// Check if templates need migration
  Future<bool> needsMigration() async {
    try {
      // Check if there are templates in local_notes
      final templateNotesCount = await (_db.select(_db.localNotes)
            ..where((n) => n.noteType.equals(1))) // 1 = template type
          .get()
          .then((notes) => notes.length);

      // Check how many templates are in local_templates
      final localTemplatesCount = await _db
          .select(_db.localTemplates)
          .get()
          .then((templates) => templates.length);

      return templateNotesCount > localTemplatesCount;
    } catch (e, stack) {
      _logger.error('Failed to check migration status',
          error: e, stackTrace: stack);
      return false;
    }
  }
}
