import 'dart:convert';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/models/template_model.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Repository for managing note templates (system and user-defined)
/// 
/// Templates are blueprints for creating notes, stored separately from notes.
/// System templates are immutable and bundled with the app.
/// User templates can be created, edited, and deleted.
class TemplateRepository {
  TemplateRepository({
    required this.db,
  }) : _uuid = const Uuid();

  final AppDb db;
  final Uuid _uuid;
  final _logger = LoggerFactory.instance;

  // ----------------------
  // Template Retrieval
  // ----------------------

  /// Get all templates (system and user)
  Future<List<LocalTemplate>> getAllTemplates() async {
    try {
      return await db.getAllTemplates();
    } catch (e, stackTrace) {
      _logger.error('Failed to get all templates',
          error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get system templates only
  Future<List<LocalTemplate>> getSystemTemplates() async {
    try {
      return await db.getSystemTemplates();
    } catch (e, stackTrace) {
      _logger.error('Failed to get system templates',
          error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get user templates only
  Future<List<LocalTemplate>> getUserTemplates() async {
    try {
      return await db.getUserTemplates();
    } catch (e, stackTrace) {
      _logger.error('Failed to get user templates',
          error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get a specific template by ID
  Future<LocalTemplate?> getTemplate(String id) async {
    try {
      return await db.getTemplate(id);
    } catch (e, stackTrace) {
      _logger.error('Failed to get template',
          error: e, stackTrace: stackTrace, data: {'templateId': id});
      return null;
    }
  }

  /// Get templates by category
  Future<List<LocalTemplate>> getTemplatesByCategory(String category) async {
    try {
      final templates = await getAllTemplates();
      return templates.where((t) => t.category == category).toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to get templates by category',
          error: e, stackTrace: stackTrace, data: {'category': category});
      return [];
    }
  }

  // ----------------------
  // User Template Management
  // ----------------------

  /// Create a new user template
  Future<LocalTemplate?> createUserTemplate({
    required String title,
    required String body,
    List<String> tags = const [],
    String category = 'personal',
    String description = '',
    String icon = 'description',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final id = 'user_${_uuid.v4()}';
      final now = DateTime.now();

      final template = LocalTemplate(
        id: id,
        title: title,
        body: body,
        tags: jsonEncode(tags),
        isSystem: false, // User template
        category: category,
        description: description.isEmpty ? 'User-created template' : description,
        icon: icon,
        sortOrder: 1000, // User templates have higher sort order
        metadata: metadata != null ? jsonEncode(metadata) : null,
        createdAt: now,
        updatedAt: now,
      );

      await db.upsertTemplate(template);

      debugPrint('✅ User template created: $id');
      _logger.info('User template created', data: {
        'templateId': id,
        'title': title,
        'category': category,
      });

      return template;
    } catch (e, stackTrace) {
      _logger.error('Failed to create user template',
          error: e,
          stackTrace: stackTrace,
          data: {
            'title': title,
            'category': category,
          });
      debugPrint('❌ Failed to create user template: $e');
      return null;
    }
  }

  /// Update an existing user template
  Future<bool> updateUserTemplate({
    required String id,
    String? title,
    String? body,
    List<String>? tags,
    String? category,
    String? description,
    String? icon,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final existing = await getTemplate(id);
      if (existing == null) {
        throw StateError('Template not found: $id');
      }

      if (existing.isSystem) {
        throw StateError('Cannot modify system template: $id');
      }

      final updated = LocalTemplate(
        id: id,
        title: title ?? existing.title,
        body: body ?? existing.body,
        tags: tags != null ? jsonEncode(tags) : existing.tags,
        isSystem: false,
        category: category ?? existing.category,
        description: description ?? existing.description,
        icon: icon ?? existing.icon,
        sortOrder: existing.sortOrder,
        metadata: metadata != null ? jsonEncode(metadata) : existing.metadata,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );

      await db.upsertTemplate(updated);

      debugPrint('✅ User template updated: $id');
      _logger.info('User template updated', data: {'templateId': id});

      return true;
    } catch (e, stackTrace) {
      _logger.error('Failed to update user template',
          error: e, stackTrace: stackTrace, data: {'templateId': id});
      debugPrint('❌ Failed to update user template: $e');
      return false;
    }
  }

  /// Delete a user template (system templates cannot be deleted)
  Future<bool> deleteUserTemplate(String id) async {
    try {
      final success = await db.deleteTemplate(id);
      
      if (success) {
        debugPrint('✅ User template deleted: $id');
        _logger.info('User template deleted', data: {'templateId': id});
      } else {
        debugPrint('⚠️ Could not delete template (may be system): $id');
      }
      
      return success;
    } catch (e, stackTrace) {
      _logger.error('Failed to delete user template',
          error: e, stackTrace: stackTrace, data: {'templateId': id});
      debugPrint('❌ Failed to delete user template: $e');
      return false;
    }
  }

  // ----------------------
  // Template to Note Conversion
  // ----------------------

  /// Create a new note from a template
  /// Returns the note data that can be used to create an actual note
  Map<String, dynamic> createNoteFromTemplate(LocalTemplate template) {
    try {
      // Parse tags from JSON
      final tags = List<String>.from(jsonDecode(template.tags));

      // Create note data from template
      final noteData = {
        'title': template.title.replaceAll(RegExp(r'^[^\w\s]+\s*'), ''), // Remove emoji prefix if any
        'body': template.body,
        'tags': tags,
        'metadata': {
          'createdFromTemplate': true,
          'templateId': template.id,
          'templateTitle': template.title,
          'templateCategory': template.category,
        },
      };

      debugPrint('✅ Note data created from template: ${template.id}');
      return noteData;
    } catch (e, stackTrace) {
      _logger.error('Failed to create note from template',
          error: e,
          stackTrace: stackTrace,
          data: {'templateId': template.id});
      
      // Return basic note data as fallback
      return {
        'title': template.title,
        'body': template.body,
        'tags': [],
        'metadata': {},
      };
    }
  }

  // ----------------------
  // Template Import/Export
  // ----------------------

  /// Export a template to JSON format for sharing
  Map<String, dynamic> exportTemplate(LocalTemplate template) {
    return {
      'title': template.title,
      'body': template.body,
      'tags': jsonDecode(template.tags),
      'category': template.category,
      'description': template.description,
      'icon': template.icon,
      'metadata': template.metadata != null 
          ? jsonDecode(template.metadata!) 
          : null,
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  /// Import a template from JSON
  Future<LocalTemplate?> importTemplate(Map<String, dynamic> json) async {
    try {
      final title = json['title'] as String;
      final body = json['body'] as String;
      final tags = List<String>.from(json['tags'] ?? []);
      final category = json['category'] as String? ?? 'personal';
      final description = json['description'] as String? ?? 'Imported template';
      final icon = json['icon'] as String? ?? 'description';
      final metadata = json['metadata'] as Map<String, dynamic>?;

      return await createUserTemplate(
        title: title,
        body: body,
        tags: tags,
        category: category,
        description: description,
        icon: icon,
        metadata: metadata,
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to import template',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  // ----------------------
  // Template Analytics
  // ----------------------

  /// Track template usage
  void trackTemplateUsage(String templateId) {
    try {
      _logger.info('Template used', data: {
        'templateId': templateId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Non-critical, don't throw
      debugPrint('Failed to track template usage: $e');
    }
  }

  /// Get template statistics
  Future<Map<String, dynamic>> getTemplateStatistics() async {
    try {
      final allTemplates = await getAllTemplates();
      final systemTemplates = allTemplates.where((t) => t.isSystem).toList();
      final userTemplates = allTemplates.where((t) => !t.isSystem).toList();

      final categoryCounts = <String, int>{};
      for (final template in allTemplates) {
        categoryCounts[template.category] = 
            (categoryCounts[template.category] ?? 0) + 1;
      }

      return {
        'totalTemplates': allTemplates.length,
        'systemTemplates': systemTemplates.length,
        'userTemplates': userTemplates.length,
        'categoryCounts': categoryCounts,
      };
    } catch (e, stackTrace) {
      _logger.error('Failed to get template statistics',
          error: e, stackTrace: stackTrace);
      return {
        'totalTemplates': 0,
        'systemTemplates': 0,
        'userTemplates': 0,
        'categoryCounts': {},
      };
    }
  }
}
