import 'dart:convert';
import 'dart:io';
import 'package:duru_notes/models/template_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:duru_notes/core/io/app_directory_resolver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

/// Service for exporting and importing templates
class TemplateSharingService {
  static final TemplateSharingService _instance =
      TemplateSharingService._internal();
  factory TemplateSharingService() => _instance;
  TemplateSharingService._internal();

  static const String templateFileExtension = 'dntemplate';
  static const String templatePackExtension = 'dntpack';
  static const int currentVersion = 1;

  /// Export a single template to JSON file
  Future<bool> exportTemplate(Template template) async {
    try {
      final exportData = _prepareTemplateExport(template);
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Create temporary file
      final tempDir = await resolveTemporaryDirectory();
      final fileName =
          '${template.title.replaceAll(RegExp(r'[^\w\s-]'), '')}_template.$templateFileExtension';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      // Share file
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Duru Notes Template: ${template.title}',
          text: 'Template exported from Duru Notes',
        ),
      );

      // Clean up temp file after sharing
      await file.delete();

      return result.status == ShareResultStatus.success;
    } catch (e) {
      throw Exception('Failed to export template: $e');
    }
  }

  /// Export multiple templates as a template pack
  Future<bool> exportTemplatePack(
    List<Template> templates,
    String packName,
  ) async {
    try {
      final exportData = {
        'version': currentVersion,
        'type': 'template_pack',
        'name': packName,
        'created_at': DateTime.now().toIso8601String(),
        'template_count': templates.length,
        'templates': templates.map(_prepareTemplateExport).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Create temporary file
      final tempDir = await resolveTemporaryDirectory();
      final fileName =
          '${packName.replaceAll(RegExp(r'[^\w\s-]'), '')}_pack.$templatePackExtension';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      // Share file
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Duru Notes Template Pack: $packName',
          text:
              'Template pack with ${templates.length} templates exported from Duru Notes',
        ),
      );

      // Clean up temp file
      await file.delete();

      return result.status == ShareResultStatus.success;
    } catch (e) {
      throw Exception('Failed to export template pack: $e');
    }
  }

  /// Import template from file
  Future<Template?> importTemplate() async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [templateFileExtension, 'json'],
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate template format
      if (!_validateTemplateData(data)) {
        throw FormatException('Invalid template format');
      }

      // Convert to Template model with new ID
      return _importTemplateFromData(data);
    } catch (e) {
      throw Exception('Failed to import template: $e');
    }
  }

  /// Import template pack from file
  Future<List<Template>> importTemplatePack() async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [templatePackExtension, 'json'],
      );

      if (result == null || result.files.isEmpty) {
        return [];
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate pack format
      if (data['type'] != 'template_pack') {
        throw FormatException('Invalid template pack format');
      }

      final templates = <Template>[];
      final templatesList = data['templates'] as List<dynamic>;

      for (final templateData in templatesList) {
        if (_validateTemplateData(templateData as Map<String, dynamic>)) {
          templates.add(_importTemplateFromData(templateData));
        }
      }

      return templates;
    } catch (e) {
      throw Exception('Failed to import template pack: $e');
    }
  }

  /// Prepare template data for export
  Map<String, dynamic> _prepareTemplateExport(Template template) {
    return {
      'version': currentVersion,
      'type': 'template',
      'exported_at': DateTime.now().toIso8601String(),
      'template': {
        'title': template.title,
        'body': template.body,
        'tags': template.tags,
        'category': template.category,
        'description': template.description,
        'icon': template.icon,
        'metadata': template.metadata,
        // Don't export ID or timestamps - will be regenerated on import
      },
    };
  }

  /// Validate imported template data
  bool _validateTemplateData(Map<String, dynamic> data) {
    if (data['type'] != 'template' && !data.containsKey('template')) {
      return false;
    }

    final templateData = data['type'] == 'template'
        ? data['template'] as Map<String, dynamic>
        : data;

    return templateData.containsKey('title') &&
        templateData.containsKey('body') &&
        templateData['title'] != null &&
        templateData['body'] != null;
  }

  /// Convert imported data to Template model
  Template _importTemplateFromData(Map<String, dynamic> data) {
    final templateData = data['type'] == 'template'
        ? data['template'] as Map<String, dynamic>
        : data;

    final now = DateTime.now();

    return Template(
      id: const Uuid().v4(), // Generate new ID
      title: templateData['title'] as String,
      body: templateData['body'] as String,
      tags: (templateData['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isSystem: false, // Imported templates are user templates
      category: templateData['category'] as String? ?? 'imported',
      description:
          templateData['description'] as String? ?? 'Imported template',
      icon: templateData['icon'] as String? ?? 'note',
      sortOrder: 999, // Put at end
      createdAt: now,
      updatedAt: now,
      metadata: (templateData['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Export templates to a specific directory (for backup)
  Future<String> exportTemplatesToDirectory(
    List<Template> templates,
    String directoryPath,
  ) async {
    try {
      final exportDir = Directory(directoryPath);
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupDir = Directory(
        '${exportDir.path}/templates_backup_$timestamp',
      );
      await backupDir.create();

      for (final template in templates) {
        final exportData = _prepareTemplateExport(template);
        final jsonString = const JsonEncoder.withIndent(
          '  ',
        ).convert(exportData);

        final fileName =
            '${template.title.replaceAll(RegExp(r'[^\w\s-]'), '')}.json';
        final file = File('${backupDir.path}/$fileName');
        await file.writeAsString(jsonString);
      }

      return backupDir.path;
    } catch (e) {
      throw Exception('Failed to export templates to directory: $e');
    }
  }

  /// Import templates from a directory
  Future<List<Template>> importTemplatesFromDirectory(
    String directoryPath,
  ) async {
    try {
      final dir = Directory(directoryPath);
      if (!await dir.exists()) {
        throw Exception('Directory does not exist');
      }

      final templates = <Template>[];
      final files = dir.listSync().whereType<File>();

      for (final file in files) {
        if (file.path.endsWith('.json') ||
            file.path.endsWith('.$templateFileExtension')) {
          try {
            final jsonString = await file.readAsString();
            final data = jsonDecode(jsonString) as Map<String, dynamic>;

            if (_validateTemplateData(data)) {
              templates.add(_importTemplateFromData(data));
            }
          } catch (e) {
            // Skip invalid files
            continue;
          }
        }
      }

      return templates;
    } catch (e) {
      throw Exception('Failed to import templates from directory: $e');
    }
  }
}
