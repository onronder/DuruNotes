import 'dart:convert';

import '../../data/local/app_db.dart';
import '../../domain/entities/template.dart';

class TemplateMapper {
  static Template toDomain(LocalTemplate local) {
    return Template(
      id: local.id,
      name: local.title, // Map title to name
      content: local.body, // Map body to content
      variables: _parseVariables(local.metadata), // Parse metadata as variables
      isSystem: local.isSystem,
      createdAt: local.createdAt,
      updatedAt: local.updatedAt,
    );
  }

  static LocalTemplate toInfrastructure(Template domain) {
    return LocalTemplate(
      id: domain.id,
      title: domain.name, // Map name to title
      body: domain.content, // Map content to body
      tags: '[]', // Empty tags array by default
      isSystem: domain.isSystem,
      category: 'general', // Default category
      description: _extractDescription(domain.content), // Extract description from content
      icon: 'description', // Default icon
      sortOrder: 0, // Default sort order
      metadata: _encodeVariables(domain.variables), // Encode variables as metadata
      createdAt: domain.createdAt,
      updatedAt: domain.updatedAt,
    );
  }

  static List<Template> toDomainList(List<LocalTemplate> locals) {
    return locals.map((local) => toDomain(local)).toList();
  }

  static List<LocalTemplate> toInfrastructureList(List<Template> domains) {
    return domains.map((domain) => toInfrastructure(domain)).toList();
  }

  /// Parse metadata JSON string to variables Map
  static Map<String, dynamic> _parseVariables(String? metadata) {
    if (metadata == null || metadata.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = json.decode(metadata);
      if (decoded is Map<String, dynamic>) {
        return decoded['variables'] as Map<String, dynamic>? ?? <String, dynamic>{};
      }
      return <String, dynamic>{};
    } catch (e) {
      return <String, dynamic>{};
    }
  }

  /// Encode variables Map to metadata JSON string
  static String? _encodeVariables(Map<String, dynamic> variables) {
    if (variables.isEmpty) return null;

    try {
      final metadata = {
        'variables': variables,
        'template_version': '1.0',
      };
      return json.encode(metadata);
    } catch (e) {
      return null;
    }
  }

  /// Extract description from template content (first line or first 100 chars)
  static String _extractDescription(String content) {
    if (content.isEmpty) return 'Template description';

    final firstLine = content.split('\n').first.trim();
    if (firstLine.length <= 100) {
      return firstLine.isNotEmpty ? firstLine : 'Template description';
    }

    return '${content.substring(0, 97).trim()}...';
  }
}