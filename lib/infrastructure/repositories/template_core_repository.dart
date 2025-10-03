import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_template_repository.dart';
import 'package:duru_notes/domain/entities/template.dart';
import 'package:duru_notes/infrastructure/mappers/template_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Core template repository implementation
class TemplateCoreRepository implements ITemplateRepository {
  TemplateCoreRepository({
    required this.db,
    required this.client,
  })  : _logger = LoggerFactory.instance;

  final AppDb db;
  final SupabaseClient client;
  final AppLogger _logger;
  final _uuid = const Uuid();

  @override
  Future<List<Template>> getAllTemplates() async {
    try {
      final localTemplates = await db.getAllTemplates();
      return TemplateMapper.toDomainList(localTemplates);
    } catch (e, stack) {
      _logger.error('Failed to get all templates', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<List<Template>> getSystemTemplates() async {
    try {
      final localTemplates = await db.getSystemTemplates();
      return TemplateMapper.toDomainList(localTemplates);
    } catch (e, stack) {
      _logger.error('Failed to get system templates', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<List<Template>> getUserTemplates() async {
    try {
      final localTemplates = await db.getUserTemplates();
      return TemplateMapper.toDomainList(localTemplates);
    } catch (e, stack) {
      _logger.error('Failed to get user templates', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<Template?> getTemplateById(String id) async {
    try {
      final localTemplate = await db.getTemplate(id);
      if (localTemplate == null) return null;

      return TemplateMapper.toDomain(localTemplate);
    } catch (e, stack) {
      _logger.error('Failed to get template by id: $id', error: e, stackTrace: stack);
      return null;
    }
  }

  @override
  Future<Template> createTemplate(Template template) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        throw Exception('Cannot create template without authenticated user');
      }

      // Create template with new ID if not provided
      final templateToCreate = template.id.isEmpty
          ? template.copyWith(id: _uuid.v4())
          : template;

      // Map to infrastructure model
      final localTemplate = TemplateMapper.toInfrastructure(templateToCreate);

      // Insert into database
      await db.upsertTemplate(localTemplate);

      // Enqueue for sync if it's a user template
      if (!templateToCreate.isSystem) {
        await db.enqueue(templateToCreate.id, 'upsert_template');
      }

      return templateToCreate;
    } catch (e, stack) {
      _logger.error('Failed to create template: ${template.name}', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<Template> updateTemplate(Template template) async {
    try {
      // Verify template exists
      final existing = await db.getTemplate(template.id);
      if (existing == null) {
        throw Exception('Template not found: ${template.id}');
      }

      // Don't allow updating system templates
      if (existing.isSystem && !template.isSystem) {
        throw Exception('Cannot modify system template');
      }

      // Create updated template with new timestamp
      final updatedTemplate = template.copyWith(
        updatedAt: DateTime.now().toUtc(),
      );

      // Map to infrastructure model
      final localTemplate = TemplateMapper.toInfrastructure(updatedTemplate);

      // Update in database
      await db.upsertTemplate(localTemplate);

      // Enqueue for sync if it's a user template
      if (!updatedTemplate.isSystem) {
        await db.enqueue(updatedTemplate.id, 'upsert_template');
      }

      return updatedTemplate;
    } catch (e, stack) {
      _logger.error('Failed to update template: ${template.id}', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> deleteTemplate(String id) async {
    try {
      // Verify template exists
      final existing = await db.getTemplate(id);
      if (existing == null) {
        _logger.warning('Attempted to delete non-existent template: $id');
        return;
      }

      // Don't allow deleting system templates
      if (existing.isSystem) {
        throw Exception('Cannot delete system template');
      }

      // Delete from database
      final deleted = await db.deleteTemplate(id);
      if (!deleted) {
        throw Exception('Failed to delete template from database');
      }

      // Enqueue for sync deletion
      await db.enqueue(id, 'delete_template');

      _logger.info('Deleted template: $id');
    } catch (e, stack) {
      _logger.error('Failed to delete template: $id', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Stream<List<Template>> watchTemplates() {
    try {
      // Create a StreamController to emit template changes
      late StreamController<List<Template>> controller;
      Timer? timer;

      void emitTemplates() async {
        try {
          final templates = await getAllTemplates();
          if (!controller.isClosed) {
            controller.add(templates);
          }
        } catch (e) {
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }
      }

      controller = StreamController<List<Template>>(
        onListen: () {
          // Emit initial data
          emitTemplates();

          // Set up periodic refresh (since Drift doesn't provide stream for custom queries)
          timer = Timer.periodic(const Duration(seconds: 5), (_) => emitTemplates());
        },
        onCancel: () {
          timer?.cancel();
        },
      );

      return controller.stream;
    } catch (e, stack) {
      _logger.error('Failed to create template watch stream', error: e, stackTrace: stack);
      return Stream.error(e, stack);
    }
  }

  /// Create a template from a note
  Future<Template> createTemplateFromNote({
    required String noteTitle,
    required String noteContent,
    required String templateName,
    String? templateDescription,
    Map<String, dynamic> variables = const {},
  }) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        throw Exception('Cannot create template without authenticated user');
      }

      // Extract variables from note content (simple implementation)
      final extractedVariables = _extractVariablesFromContent(noteContent);
      final mergedVariables = {...extractedVariables, ...variables};

      final template = Template(
        id: _uuid.v4(),
        name: templateName,
        content: noteContent,
        variables: mergedVariables,
        isSystem: false,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      return await createTemplate(template);
    } catch (e, stack) {
      _logger.error('Failed to create template from note', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Apply template variables to content
  Future<String> applyTemplate({
    required String templateId,
    required Map<String, String> variableValues,
  }) async {
    try {
      final template = await getTemplateById(templateId);
      if (template == null) {
        throw Exception('Template not found: $templateId');
      }

      String processedContent = template.content;

      // Replace variables in format {{variableName}}
      for (final entry in variableValues.entries) {
        final placeholder = '{{${entry.key}}}';
        processedContent = processedContent.replaceAll(placeholder, entry.value);
      }

      // Replace any remaining placeholders with empty strings or defaults
      for (final entry in template.variables.entries) {
        final placeholder = '{{${entry.key}}}';
        if (processedContent.contains(placeholder)) {
          final defaultValue = entry.value.toString();
          processedContent = processedContent.replaceAll(placeholder, defaultValue);
        }
      }

      return processedContent;
    } catch (e, stack) {
      _logger.error('Failed to apply template: $templateId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Get template usage statistics
  Future<Map<String, int>> getTemplateUsageStats() async {
    try {
      final templates = await getAllTemplates();
      final stats = <String, int>{};

      // This is a simplified implementation
      // In a real system, you'd track usage in a separate table
      for (final template in templates) {
        stats[template.id] = 0; // Placeholder for actual usage count
      }

      return stats;
    } catch (e, stack) {
      _logger.error('Failed to get template usage stats', error: e, stackTrace: stack);
      return {};
    }
  }

  /// Search templates by name or content
  Future<List<Template>> searchTemplates(String query) async {
    try {
      if (query.isEmpty) {
        return await getAllTemplates();
      }

      final allTemplates = await getAllTemplates();
      final normalizedQuery = query.toLowerCase();

      return allTemplates.where((template) {
        final matchesName = template.name.toLowerCase().contains(normalizedQuery);
        final matchesContent = template.content.toLowerCase().contains(normalizedQuery);
        return matchesName || matchesContent;
      }).toList();
    } catch (e, stack) {
      _logger.error('Failed to search templates with query: $query', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Duplicate an existing template
  Future<Template> duplicateTemplate({
    required String templateId,
    String? newName,
  }) async {
    try {
      final original = await getTemplateById(templateId);
      if (original == null) {
        throw Exception('Template not found: $templateId');
      }

      final duplicatedTemplate = Template(
        id: _uuid.v4(),
        name: newName ?? '${original.name} (Copy)',
        content: original.content,
        variables: Map<String, dynamic>.from(original.variables),
        isSystem: false, // Duplicates are always user templates
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      return await createTemplate(duplicatedTemplate);
    } catch (e, stack) {
      _logger.error('Failed to duplicate template: $templateId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Validate template content for variables
  bool validateTemplate(Template template) {
    try {
      final content = template.content;
      final variables = template.variables;

      // Find all variable placeholders in content
      final placeholderRegex = RegExp(r'\{\{([^}]+)\}\}');
      final matches = placeholderRegex.allMatches(content);

      // Check if all placeholders have corresponding variables
      for (final match in matches) {
        final variableName = match.group(1)?.trim();
        if (variableName != null && !variables.containsKey(variableName)) {
          _logger.warning('Template ${template.id} has undefined variable: $variableName');
          return false;
        }
      }

      // Check if all variables are used in content
      for (final variableName in variables.keys) {
        final placeholder = '{{$variableName}}';
        if (!content.contains(placeholder)) {
          _logger.warning('Template ${template.id} has unused variable: $variableName');
          // This is just a warning, not an error
        }
      }

      return true;
    } catch (e, stack) {
      _logger.error('Failed to validate template: ${template.id}', error: e, stackTrace: stack);
      return false;
    }
  }

  // Private helper methods

  /// Extract variables from content (simple implementation)
  Map<String, dynamic> _extractVariablesFromContent(String content) {
    final variables = <String, dynamic>{};
    final placeholderRegex = RegExp(r'\{\{([^}]+)\}\}');
    final matches = placeholderRegex.allMatches(content);

    for (final match in matches) {
      final variableName = match.group(1)?.trim();
      if (variableName != null) {
        // Set default value as empty string
        variables[variableName] = '';
      }
    }

    return variables;
  }

  /// Initialize system templates if they don't exist
  Future<void> ensureSystemTemplatesExist() async {
    try {
      final existingSystemTemplates = await getSystemTemplates();

      if (existingSystemTemplates.isEmpty) {
        await _createDefaultSystemTemplates();
      }
    } catch (e, stack) {
      _logger.error('Failed to ensure system templates exist', error: e, stackTrace: stack);
    }
  }

  /// Create default system templates
  Future<void> _createDefaultSystemTemplates() async {
    final systemTemplates = [
      Template(
        id: 'sys_meeting_notes',
        name: 'Meeting Notes',
        content: '''# Meeting Notes - {{meeting_title}}

**Date:** {{date}}
**Attendees:** {{attendees}}
**Duration:** {{duration}}

## Agenda
{{agenda}}

## Discussion Points
{{discussion}}

## Action Items
{{action_items}}

## Next Steps
{{next_steps}}''',
        variables: {
          'meeting_title': 'Weekly Team Meeting',
          'date': DateTime.now().toString().split(' ')[0],
          'attendees': 'Team members',
          'duration': '1 hour',
          'agenda': '- Topic 1\n- Topic 2',
          'discussion': 'Key discussion points',
          'action_items': '- [ ] Action 1\n- [ ] Action 2',
          'next_steps': 'Schedule follow-up meeting',
        },
        isSystem: true,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
      Template(
        id: 'sys_project_plan',
        name: 'Project Plan',
        content: '''# {{project_name}} - Project Plan

**Project Manager:** {{project_manager}}
**Start Date:** {{start_date}}
**End Date:** {{end_date}}
**Status:** {{status}}

## Project Overview
{{overview}}

## Objectives
{{objectives}}

## Deliverables
{{deliverables}}

## Timeline
{{timeline}}

## Resources
{{resources}}

## Risk Assessment
{{risks}}''',
        variables: {
          'project_name': 'New Project',
          'project_manager': 'Project Manager Name',
          'start_date': DateTime.now().toString().split(' ')[0],
          'end_date': 'TBD',
          'status': 'Planning',
          'overview': 'Project description and goals',
          'objectives': '- Objective 1\n- Objective 2',
          'deliverables': '- Deliverable 1\n- Deliverable 2',
          'timeline': 'Phase 1: Weeks 1-4\nPhase 2: Weeks 5-8',
          'resources': 'Team members, budget, tools',
          'risks': 'Potential risks and mitigation strategies',
        },
        isSystem: true,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
      Template(
        id: 'sys_daily_journal',
        name: 'Daily Journal',
        content: '''# Daily Journal - {{date}}

## Mood: {{mood}}

## Today's Goals
{{goals}}

## Accomplishments
{{accomplishments}}

## Challenges
{{challenges}}

## Grateful For
{{gratitude}}

## Tomorrow's Priority
{{tomorrow_priority}}

## Notes
{{notes}}''',
        variables: {
          'date': DateTime.now().toString().split(' ')[0],
          'mood': '😊',
          'goals': '- Goal 1\n- Goal 2',
          'accomplishments': 'What went well today',
          'challenges': 'Obstacles faced',
          'gratitude': 'Three things I\'m grateful for',
          'tomorrow_priority': 'Most important task for tomorrow',
          'notes': 'Additional thoughts and reflections',
        },
        isSystem: true,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    ];

    for (final template in systemTemplates) {
      try {
        final localTemplate = TemplateMapper.toInfrastructure(template);
        await db.upsertTemplate(localTemplate);
      } catch (e) {
        _logger.error('Failed to create system template: ${template.name}', error: e);
      }
    }

    _logger.info('Created ${systemTemplates.length} system templates');
  }
}