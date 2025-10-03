import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/template.dart' as domain;
import 'dart:convert';

/// Converter utility for converting between LocalTemplate and domain.Template
class TemplateConverter {
  /// Convert LocalTemplate (infrastructure) to domain.Template
  static domain.Template fromLocal(LocalTemplate local) {
    // Parse variables from JSON metadata
    Map<String, String> variables = {};
    if (local.metadata != null && local.metadata!.isNotEmpty) {
      try {
        final meta = jsonDecode(local.metadata!) as Map<String, dynamic>;
        if (meta['variables'] != null) {
          variables = Map<String, String>.from(meta['variables'] as Map);
        }
      } catch (e) {
        // If parsing fails, use empty variables
      }
    }

    return domain.Template(
      id: local.id,
      name: local.title, // LocalTemplate uses 'title', domain uses 'name'
      content: local.body,
      variables: variables,
      isSystem: local.isSystem,
      createdAt: local.createdAt,
      updatedAt: local.updatedAt,
    );
  }

  /// Convert domain.Template to LocalTemplate
  static LocalTemplate toLocal(domain.Template template) {
    // Serialize variables to JSON metadata
    String? metadata;
    if (template.variables.isNotEmpty) {
      metadata = jsonEncode({
        'variables': template.variables,
      });
    }

    return LocalTemplate(
      id: template.id,
      title: template.name, // domain uses 'name', LocalTemplate uses 'title'
      body: template.content,
      tags: '[]', // Default empty tags JSON
      category: 'general', // Default category
      description: '', // Default empty description
      icon: 'note', // Default icon
      sortOrder: 0, // Default sort order
      metadata: metadata,
      isSystem: template.isSystem,
      createdAt: template.createdAt,
      updatedAt: template.updatedAt,
    );
  }

  /// Convert List<LocalTemplate> to List<domain.Template>
  static List<domain.Template> fromLocalList(List<LocalTemplate> localTemplates) {
    return localTemplates.map((local) => fromLocal(local)).toList();
  }

  /// Convert List<domain.Template> to List<LocalTemplate>
  static List<LocalTemplate> toLocalList(List<domain.Template> domainTemplates) {
    return domainTemplates.map((template) => toLocal(template)).toList();
  }

  /// Smart conversion that handles both types
  static domain.Template ensureDomainTemplate(dynamic template) {
    if (template is domain.Template) {
      return template;
    } else if (template is LocalTemplate) {
      return fromLocal(template);
    } else {
      throw ArgumentError('Unknown template type: ${template.runtimeType}');
    }
  }

  /// Smart conversion that handles both types to LocalTemplate
  static LocalTemplate ensureLocalTemplate(dynamic template) {
    if (template is LocalTemplate) {
      return template;
    } else if (template is domain.Template) {
      return toLocal(template);
    } else {
      throw ArgumentError('Unknown template type: ${template.runtimeType}');
    }
  }

  /// Get ID from any template type
  static String getTemplateId(dynamic template) {
    if (template is domain.Template) {
      return template.id;
    } else if (template is LocalTemplate) {
      return template.id;
    } else {
      throw ArgumentError('Unknown template type: ${template.runtimeType}');
    }
  }

  /// Get name from any template type
  static String getTemplateName(dynamic template) {
    if (template is domain.Template) {
      return template.name;
    } else if (template is LocalTemplate) {
      return template.title; // LocalTemplate uses 'title' field
    } else {
      throw ArgumentError('Unknown template type: ${template.runtimeType}');
    }
  }

  /// Get body from any template type
  static String getTemplateBody(dynamic template) {
    if (template is domain.Template) {
      return template.content;
    } else if (template is LocalTemplate) {
      return template.body;
    } else {
      throw ArgumentError('Unknown template type: ${template.runtimeType}');
    }
  }
}