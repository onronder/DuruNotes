import 'dart:io';
import 'dart:convert';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show migrationConfigProvider, analyticsProvider;
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderCoreRepositoryProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:csv/csv.dart';
import 'package:xml/xml.dart' as xml;

/// Import formats supported by the service
enum ImportFormat {
  markdown('Markdown', ['md', 'markdown']),
  json('JSON', ['json']),
  csv('CSV', ['csv']),
  txt('Plain Text', ['txt']),
  evernote('Evernote', ['enex']),
  obsidian('Obsidian', ['md']),
  notion('Notion', ['md', 'csv']),
  bear('Bear', ['bearnote', 'md']),
  roam('Roam Research', ['json']),
  onenote('OneNote', ['one']);

  const ImportFormat(this.displayName, this.extensions);

  final String displayName;
  final List<String> extensions;

  static ImportFormat? fromExtension(String ext) {
    for (final format in ImportFormat.values) {
      if (format.extensions.contains(ext.toLowerCase())) {
        return format;
      }
    }
    return null;
  }
}

/// Import options for customizing the import process
class ImportOptions {
  const ImportOptions({
    this.targetFolderId,
    this.preserveFolders = true,
    this.preserveTags = true,
    this.preserveTimestamps = true,
    this.preserveAttachments = true,
    this.mergeStrategy = MergeStrategy.create,
    this.dateFormat = 'yyyy-MM-dd',
    this.tagPrefix,
    this.defaultTags = const [],
    this.skipDuplicates = false,
    this.maxBatchSize = 100,
  });

  final String? targetFolderId;
  final bool preserveFolders;
  final bool preserveTags;
  final bool preserveTimestamps;
  final bool preserveAttachments;
  final MergeStrategy mergeStrategy;
  final String dateFormat;
  final String? tagPrefix;
  final List<String> defaultTags;
  final bool skipDuplicates;
  final int maxBatchSize;
}

enum MergeStrategy {
  create, // Always create new notes
  update, // Update existing notes with same title
  skip,   // Skip if note exists
  merge,  // Merge content
}

/// Result of an import operation
class ImportResult {
  const ImportResult({
    required this.success,
    required this.totalNotes,
    required this.importedNotes,
    required this.skippedNotes,
    required this.failedNotes,
    this.errors = const [],
    this.importedFolders = 0,
    this.duration,
  });

  final bool success;
  final int totalNotes;
  final int importedNotes;
  final int skippedNotes;
  final int failedNotes;
  final List<String> errors;
  final int importedFolders;
  final Duration? duration;

  String get summary => 'Imported $importedNotes of $totalNotes notes'
      '${skippedNotes > 0 ? ', skipped $skippedNotes' : ''}'
      '${failedNotes > 0 ? ', failed $failedNotes' : ''}';
}

/// Unified import service that works with domain.Note
class UnifiedImportService {
  UnifiedImportService({
    required this.ref,
    required this.notesRepository,
    required this.folderRepository,
    required this.migrationConfig,
  })  : _logger = LoggerFactory.instance,
        _uuid = const Uuid();

  final Ref ref;
  final INotesRepository notesRepository;
  final IFolderRepository folderRepository;
  final MigrationConfig migrationConfig;
  final AppLogger _logger;
  final Uuid _uuid;

  /// Import notes from a file
  Future<ImportResult> importFromFile({
    required File file,
    ImportOptions options = const ImportOptions(),
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      _logger.info('[UnifiedImport] Starting import from: ${file.path}');

      // Detect format from extension
      final extension = path.extension(file.path).substring(1);
      final format = ImportFormat.fromExtension(extension);

      if (format == null) {
        return ImportResult(
          success: false,
          totalNotes: 0,
          importedNotes: 0,
          skippedNotes: 0,
          failedNotes: 0,
          errors: ['Unsupported file format: .$extension'],
        );
      }

      // Parse file based on format
      final List<Map<String, dynamic>> notesData = await _parseFile(file, format);

      if (notesData.isEmpty) {
        return ImportResult(
          success: true,
          totalNotes: 0,
          importedNotes: 0,
          skippedNotes: 0,
          failedNotes: 0,
        );
      }

      // Import notes
      final result = await _importNotes(notesData, options);

      // Track analytics
      await _trackImport(format, result);

      stopwatch.stop();
      return ImportResult(
        success: result.success,
        totalNotes: result.totalNotes,
        importedNotes: result.importedNotes,
        skippedNotes: result.skippedNotes,
        failedNotes: result.failedNotes,
        errors: result.errors,
        importedFolders: result.importedFolders,
        duration: stopwatch.elapsed,
      );
    } catch (e, stack) {
      _logger.error('[UnifiedImport] Import failed', error: e, stackTrace: stack);
      stopwatch.stop();
      return ImportResult(
        success: false,
        totalNotes: 0,
        importedNotes: 0,
        skippedNotes: 0,
        failedNotes: 0,
        errors: ['Import failed: $e'],
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Import notes from multiple files
  Future<ImportResult> importFromFiles({
    required List<File> files,
    ImportOptions options = const ImportOptions(),
  }) async {
    int totalImported = 0;
    int totalSkipped = 0;
    int totalFailed = 0;
    int totalNotes = 0;
    final errors = <String>[];

    for (final file in files) {
      final result = await importFromFile(file: file, options: options);
      totalImported += result.importedNotes;
      totalSkipped += result.skippedNotes;
      totalFailed += result.failedNotes;
      totalNotes += result.totalNotes;
      errors.addAll(result.errors);
    }

    return ImportResult(
      success: totalFailed == 0,
      totalNotes: totalNotes,
      importedNotes: totalImported,
      skippedNotes: totalSkipped,
      failedNotes: totalFailed,
      errors: errors,
    );
  }

  /// Pick and import files
  Future<ImportResult?> pickAndImport({
    ImportOptions options = const ImportOptions(),
    bool allowMultiple = true,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'md', 'markdown', 'json', 'csv', 'txt',
          'enex', 'bearnote', 'one', 'zip',
        ],
        allowMultiple: allowMultiple,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final files = result.paths
          .where((path) => path != null)
          .map((path) => File(path!))
          .toList();

      if (files.isEmpty) {
        return null;
      }

      if (files.length == 1) {
        return importFromFile(file: files.first, options: options);
      } else {
        return importFromFiles(files: files, options: options);
      }
    } catch (e, stack) {
      _logger.error('[UnifiedImport] Failed to pick files', error: e, stackTrace: stack);
      return null;
    }
  }

  // ========== PRIVATE HELPER METHODS ==========

  /// Parse file based on format
  Future<List<Map<String, dynamic>>> _parseFile(File file, ImportFormat format) async {
    switch (format) {
      case ImportFormat.markdown:
      case ImportFormat.obsidian:
        return _parseMarkdownFile(file);
      case ImportFormat.json:
      case ImportFormat.roam:
        return _parseJsonFile(file);
      case ImportFormat.csv:
      case ImportFormat.notion:
        return _parseCsvFile(file);
      case ImportFormat.txt:
        return _parsePlainTextFile(file);
      case ImportFormat.evernote:
        return _parseEvernoteFile(file);
      case ImportFormat.bear:
        return _parseBearFile(file);
      case ImportFormat.onenote:
        return _parseOneNoteFile(file);
    }
  }

  /// Parse Markdown file
  Future<List<Map<String, dynamic>>> _parseMarkdownFile(File file) async {
    try {
      final content = await file.readAsString();
      final notes = <Map<String, dynamic>>[];

      // Split by H1 headers (# Title)
      final sections = content.split(RegExp(r'^# ', multiLine: true));

      for (final section in sections) {
        if (section.trim().isEmpty) continue;

        final lines = section.split('\n');
        if (lines.isEmpty) continue;

        final title = lines.first.trim();
        final body = lines.skip(1).join('\n').trim();

        // Extract tags from content (#tag format)
        final tags = <String>[];
        final tagRegex = RegExp(r'#([a-zA-Z0-9_]+)');
        final matches = tagRegex.allMatches(body);
        for (final match in matches) {
          tags.add(match.group(1)!);
        }

        // Extract metadata from YAML frontmatter if present
        Map<String, dynamic> metadata = {};
        if (body.startsWith('---')) {
          final endIndex = body.indexOf('---', 3);
          if (endIndex > 0) {
            final yamlContent = body.substring(3, endIndex);
            metadata = _parseYamlMetadata(yamlContent);
          }
        }

        notes.add({
          'title': title.isEmpty ? 'Untitled' : title,
          'body': body,
          'tags': tags,
          'metadata': metadata,
          'format': 'markdown',
        });
      }

      // If no H1 headers, treat entire file as one note
      if (notes.isEmpty && content.isNotEmpty) {
        final fileName = path.basenameWithoutExtension(file.path);
        notes.add({
          'title': fileName,
          'body': content,
          'tags': <Map<String, dynamic>>[],
          'metadata': <String, dynamic>{},
          'format': 'markdown',
        });
      }

      return notes;
    } catch (e, stack) {
      _logger.error('[UnifiedImport] Failed to parse markdown file', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Parse JSON file
  Future<List<Map<String, dynamic>>> _parseJsonFile(File file) async {
    try {
      final content = await file.readAsString();
      final data = json.decode(content);

      final notes = <Map<String, dynamic>>[];

      // Handle array of notes
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            notes.add(_normalizeNoteData(item));
          }
        }
      }
      // Handle single note object
      else if (data is Map<String, dynamic>) {
        // Check if it's a Roam Research export
        if (data.containsKey('title') && data.containsKey('children')) {
          notes.addAll(_parseRoamData(data));
        }
        // Check if it's a wrapper object with notes array
        else if (data.containsKey('notes') && data['notes'] is List) {
          for (final note in data['notes'] as List) {
            notes.add(_normalizeNoteData(note as Map<String, dynamic>));
          }
        }
        // Treat as single note
        else {
          notes.add(_normalizeNoteData(data));
        }
      }

      return notes;
    } catch (e, stack) {
      _logger.error('[UnifiedImport] Failed to parse JSON file', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Parse CSV file
  Future<List<Map<String, dynamic>>> _parseCsvFile(File file) async {
    try {
      final content = await file.readAsString();
      final rows = const CsvToListConverter().convert(content);

      if (rows.isEmpty) return [];

      // First row should be headers
      final headers = rows.first.map((e) => e.toString().toLowerCase()).toList();
      final notes = <Map<String, dynamic>>[];

      // Process data rows
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final noteData = <String, dynamic>{};

        for (int j = 0; j < headers.length && j < row.length; j++) {
          final header = headers[j];
          final value = row[j];

          // Map common CSV headers to note properties
          if (header.contains('title') || header.contains('name')) {
            noteData['title'] = value.toString();
          } else if (header.contains('content') || header.contains('body') || header.contains('text')) {
            noteData['body'] = value.toString();
          } else if (header.contains('tag')) {
            final tags = value.toString().split(',').map((t) => t.trim()).toList();
            noteData['tags'] = tags;
          } else if (header.contains('folder') || header.contains('category')) {
            noteData['folder'] = value.toString();
          } else if (header.contains('created') || header.contains('date')) {
            noteData['createdAt'] = value.toString();
          } else {
            noteData[header] = value;
          }
        }

        // Ensure required fields
        noteData['title'] ??= 'Untitled';
        noteData['body'] ??= '';

        notes.add(noteData);
      }

      return notes;
    } catch (e, stack) {
      _logger.error('[UnifiedImport] Failed to parse CSV file', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Parse plain text file
  Future<List<Map<String, dynamic>>> _parsePlainTextFile(File file) async {
    try {
      final content = await file.readAsString();
      final fileName = path.basenameWithoutExtension(file.path);

      // Try to detect if it's multiple notes separated by markers
      if (content.contains('---\n') || content.contains('===\n')) {
        final separator = content.contains('---\n') ? '---\n' : '===\n';
        final sections = content.split(separator);
        final notes = <Map<String, dynamic>>[];

        for (int i = 0; i < sections.length; i++) {
          final section = sections[i].trim();
          if (section.isEmpty) continue;

          // Try to extract title from first line
          final lines = section.split('\n');
          String title = lines.first.trim();
          String body = section;

          if (lines.length > 1 && title.length < 100) {
            body = lines.skip(1).join('\n').trim();
          } else {
            title = '$fileName - Part ${i + 1}';
          }

          notes.add({
            'title': title,
            'body': body,
            'tags': <Map<String, dynamic>>[],
            'format': 'text',
          });
        }

        return notes;
      }

      // Single note
      return [{
        'title': fileName,
        'body': content,
        'tags': <String>[],
        'format': 'text',
      }];
    } catch (e, stack) {
      _logger.error('[UnifiedImport] Failed to parse text file', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Parse Evernote ENEX file
  Future<List<Map<String, dynamic>>> _parseEvernoteFile(File file) async {
    try {
      final content = await file.readAsString();
      final document = xml.XmlDocument.parse(content);
      final notes = <Map<String, dynamic>>[];

      final noteElements = document.findAllElements('note');

      for (final noteElement in noteElements) {
        final title = noteElement.findElements('title').firstOrNull?.innerText ?? 'Untitled';
        final content = noteElement.findElements('content').firstOrNull?.innerText ?? '';

        // Parse content from ENML to plain text/markdown
        final body = _convertEnmlToMarkdown(content);

        // Extract tags
        final tags = <String>[];
        final tagElements = noteElement.findElements('tag');
        for (final tag in tagElements) {
          tags.add(tag.innerText);
        }

        // Extract dates
        final created = noteElement.findElements('created').firstOrNull?.innerText;
        final updated = noteElement.findElements('updated').firstOrNull?.innerText;

        // Extract attributes
        final attributes = noteElement.findElements('note-attributes').firstOrNull;
        final source = attributes?.findElements('source').firstOrNull?.innerText;
        final sourceUrl = attributes?.findElements('source-url').firstOrNull?.innerText;

        notes.add({
          'title': title,
          'body': body,
          'tags': tags,
          'createdAt': created,
          'updatedAt': updated,
          'metadata': {
            if (source != null) 'source': source,
            if (sourceUrl != null) 'sourceUrl': sourceUrl,
          },
          'format': 'evernote',
        });
      }

      return notes;
    } catch (e, stack) {
      _logger.error('[UnifiedImport] Failed to parse Evernote file', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Parse Bear note file
  Future<List<Map<String, dynamic>>> _parseBearFile(File file) async {
    try {
      // Bear notes are typically markdown with special tags
      final notes = await _parseMarkdownFile(file);

      // Process Bear-specific features
      for (final note in notes) {
        // Bear uses #tag# format
        final body = note['body'] as String;
        final bearTags = <String>[];
        final bearTagRegex = RegExp(r'#([^#\s]+)#');
        final matches = bearTagRegex.allMatches(body);
        for (final match in matches) {
          bearTags.add(match.group(1)!);
        }

        if (bearTags.isNotEmpty) {
          final existingTags = note['tags'] as List? ?? [];
          note['tags'] = [...existingTags, ...bearTags];
        }

        note['format'] = 'bear';
      }

      return notes;
    } catch (e, stack) {
      _logger.error('[UnifiedImport] Failed to parse Bear file', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Parse OneNote file (placeholder - requires OneNote API)
  Future<List<Map<String, dynamic>>> _parseOneNoteFile(File file) async {
    _logger.warning('[UnifiedImport] OneNote import not yet implemented');
    return [];
  }

  /// Parse Roam Research data structure
  List<Map<String, dynamic>> _parseRoamData(Map<String, dynamic> data) {
    final notes = <Map<String, dynamic>>[];

    void parseNode(Map<String, dynamic> node, {String? parentTitle}) {
      final title = node['title'] as String? ??
                   node['string'] as String? ??
                   'Untitled';

      final children = node['children'] as List? ?? [];
      final body = StringBuffer();

      // Build body from children
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          final childText = child['string'] as String? ?? '';
          body.writeln('- $childText');

          // Recursively parse nested children as separate notes
          if (child['children'] != null) {
            parseNode(child, parentTitle: title);
          }
        }
      }

      notes.add({
        'title': title,
        'body': body.toString(),
        'tags': parentTitle != null ? [parentTitle] : <String>[],
        'format': 'roam',
      });
    }

    parseNode(data);
    return notes;
  }

  /// Convert ENML to Markdown
  String _convertEnmlToMarkdown(String enml) {
    // Basic ENML to Markdown conversion
    return enml
        .replaceAll(RegExp(r'<en-note[^>]*>'), '')
        .replaceAll('</en-note>', '')
        .replaceAll('<div>', '\n')
        .replaceAll('</div>', '')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br>', '\n')
        .replaceAll(RegExp(r'<b>([^<]+)</b>'), '**\$1**')
        .replaceAll(RegExp(r'<i>([^<]+)</i>'), '*\$1*')
        .replaceAll(RegExp(r'<u>([^<]+)</u>'), '__\$1__')
        .replaceAll(RegExp(r'<h1>([^<]+)</h1>'), '# \$1\n')
        .replaceAll(RegExp(r'<h2>([^<]+)</h2>'), '## \$1\n')
        .replaceAll(RegExp(r'<h3>([^<]+)</h3>'), '### \$1\n')
        .replaceAll(RegExp(r'<[^>]+>'), '') // Remove remaining HTML tags
        .trim();
  }

  /// Parse YAML metadata
  Map<String, dynamic> _parseYamlMetadata(String yaml) {
    final metadata = <String, dynamic>{};
    final lines = yaml.split('\n');

    for (final line in lines) {
      if (line.contains(':')) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.skip(1).join(':').trim();
          metadata[key] = value;
        }
      }
    }

    return metadata;
  }

  /// Normalize note data from various formats
  Map<String, dynamic> _normalizeNoteData(Map<String, dynamic> data) {
    return {
      'title': data['title'] ??
               data['name'] ??
               data['subject'] ??
               'Untitled',
      'body': data['body'] ??
              data['content'] ??
              data['text'] ??
              data['description'] ??
              '',
      'tags': _extractTags(data),
      'folder': data['folder'] ??
                data['category'] ??
                data['notebook'],
      'createdAt': data['createdAt'] ??
                   data['created'] ??
                   data['created_at'] ??
                   data['date'],
      'updatedAt': data['updatedAt'] ??
                   data['updated'] ??
                   data['updated_at'] ??
                   data['modified'],
      'metadata': data['metadata'] ?? <String, dynamic>{},
      'format': data['format'] ?? 'unknown',
    };
  }

  /// Extract tags from various data formats
  List<String> _extractTags(Map<String, dynamic> data) {
    final tags = <String>[];

    // Try different tag field names
    final tagFields = ['tags', 'tag', 'labels', 'categories'];

    for (final field in tagFields) {
      if (data.containsKey(field)) {
        final value = data[field];

        if (value is List) {
          tags.addAll(value.map((t) => t.toString()));
        } else if (value is String) {
          // Split by comma or semicolon
          tags.addAll(value.split(RegExp(r'[,;]')).map((t) => t.trim()));
        }
      }
    }

    return tags.where((t) => t.isNotEmpty).toSet().toList();
  }

  /// Import notes into the database
  Future<ImportResult> _importNotes(
    List<Map<String, dynamic>> notesData,
    ImportOptions options,
  ) async {
    int imported = 0;
    int skipped = 0;
    int failed = 0;
    final errors = <String>[];
    final folderMap = <String, String>{}; // folder name -> folder id

    try {
      // Process in batches
      for (int i = 0; i < notesData.length; i += options.maxBatchSize) {
        final batch = notesData.skip(i).take(options.maxBatchSize).toList();

        for (final noteData in batch) {
          try {
            // Check for duplicates if needed
            if (options.skipDuplicates) {
              final exists = await _checkDuplicate(noteData['title'] as String);
              if (exists) {
                skipped++;
                continue;
              }
            }

            // Create or get folder
            String? folderId = options.targetFolderId;
            if (options.preserveFolders && noteData['folder'] != null) {
              final folderName = noteData['folder'] as String;
              if (!folderMap.containsKey(folderName)) {
                folderId = await _createOrGetFolder(folderName, options.targetFolderId);
                folderMap[folderName] = folderId;
              } else {
                folderId = folderMap[folderName];
              }
            }

            // Process tags
            final tags = <String>[];
            if (options.preserveTags) {
              final noteTags = (noteData['tags'] as List?)?.cast<String>() ?? [];
              tags.addAll(noteTags);
            }
            if (options.tagPrefix != null) {
              tags.addAll(tags.map((t) => '${options.tagPrefix}$t'));
            }
            tags.addAll(options.defaultTags);

            // Create note
            await _createNote(
              title: noteData['title'] as String,
              body: noteData['body'] as String,
              tags: tags,
              folderId: folderId,
              metadata: noteData['metadata'] as Map<String, dynamic>? ?? {},
              createdAt: options.preserveTimestamps ? _parseDate(noteData['createdAt']) : null,
              updatedAt: options.preserveTimestamps ? _parseDate(noteData['updatedAt']) : null,
            );

            imported++;
          } catch (e) {
            failed++;
            errors.add('Failed to import "${noteData['title']}": $e');
            _logger.error('[UnifiedImport] Failed to import note', error: e);
          }
        }
      }

      return ImportResult(
        success: failed == 0,
        totalNotes: notesData.length,
        importedNotes: imported,
        skippedNotes: skipped,
        failedNotes: failed,
        errors: errors,
        importedFolders: folderMap.length,
      );
    } catch (e, stack) {
      _logger.error('[UnifiedImport] Import batch failed', error: e, stackTrace: stack);
      return ImportResult(
        success: false,
        totalNotes: notesData.length,
        importedNotes: imported,
        skippedNotes: skipped,
        failedNotes: failed + (notesData.length - imported - skipped),
        errors: [...errors, 'Batch import failed: $e'],
        importedFolders: folderMap.length,
      );
    }
  }

  /// Check if a note with the given title already exists
  Future<bool> _checkDuplicate(String title) async {
    try {
      final notes = await notesRepository.localNotes();
      return notes.any((n) => n.title == title);
    } catch (e) {
      _logger.warning('[UnifiedImport] Failed to check duplicate');
      return false;
    }
  }

  /// Create or get folder by name
  Future<String> _createOrGetFolder(String name, String? parentId) async {
    try {
      final folders = await folderRepository.listFolders();

      // Check if folder exists
      final existing = folders.firstWhere(
        (f) => f.name == name && f.parentId == parentId,
        orElse: () => domain.Folder(
          id: '',
          name: '',
          parentId: null,
          color: null,
          icon: null,
          sortOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          userId: '',
        ),
      );

      if (existing.id.isNotEmpty) {
        return existing.id;
      }

      // Create new folder
      final newFolder = await folderRepository.createFolder(
        name: name,
        description: name, // Use name as description for imported folders
        parentId: parentId,
        color: '#048ABF',
        icon: 'folder',
      );

      return newFolder.id;
    } catch (e, stack) {
      _logger.error('[UnifiedImport] Failed to create folder: $name', error: e, stackTrace: stack);
      return _uuid.v4(); // Return a new ID anyway
    }
  }

  /// Create a note
  Future<void> _createNote({
    required String title,
    required String body,
    required List<String> tags,
    String? folderId,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    try {
      await notesRepository.createOrUpdate(
        title: title,
        body: body,
        folderId: folderId,
        tags: tags,
        isPinned: false,
      );
    } catch (e, stack) {
      _logger.error('[UnifiedImport] Failed to create note: $title', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Parse date string
  DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;

    if (dateValue is DateTime) return dateValue;

    if (dateValue is String) {
      try {
        // Try ISO format
        return DateTime.parse(dateValue);
      } catch (_) {
        // Try other formats
        // Could add more date parsing logic here
        return null;
      }
    }

    if (dateValue is int) {
      // Assume milliseconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(dateValue);
    }

    return null;
  }

  /// Track import analytics
  Future<void> _trackImport(ImportFormat format, ImportResult result) async {
    try {
      final analytics = ref.read(analyticsProvider);
      analytics.event('notes_imported', properties: {
        'format': format.displayName,
        'total': result.totalNotes,
        'imported': result.importedNotes,
        'skipped': result.skippedNotes,
        'failed': result.failedNotes,
        'folders': result.importedFolders,
        'duration': result.duration?.inSeconds,
      });
    } catch (e) {
      _logger.warning('[UnifiedImport] Failed to track import analytics');
    }
  }
}

/// Provider for unified import service
final unifiedImportServiceProvider = Provider<UnifiedImportService>((ref) {
  final notesRepo = ref.watch(notesCoreRepositoryProvider);
  final folderRepo = ref.watch(folderCoreRepositoryProvider);
  final config = ref.watch(migrationConfigProvider);

  return UnifiedImportService(
    ref: ref,
    notesRepository: notesRepo,
    folderRepository: folderRepo,
    migrationConfig: config,
  );
});