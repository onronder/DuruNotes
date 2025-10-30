import 'dart:convert';
import 'dart:io';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/parser/note_block_parser.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/models/note_block.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

// Legacy type alias for backward compatibility
typedef NotesRepository = NotesCoreRepository;

/// Progress callback for import operations
typedef ProgressCallback = void Function(ImportProgress progress);

/// Production-grade import service with comprehensive error handling and validation
class ImportService {
  // 1MB per note content
  // static const Duration _operationTimeout = Duration(minutes: 10);  // Reserved for timeout implementation

  ImportService({
    required NotesRepository notesRepository,
    required NoteIndexer noteIndexer, // Kept for backward compatibility
    required AppLogger logger,
    required AnalyticsService analytics,
  }) : _notesRepository = notesRepository,
       _noteIndexer = noteIndexer,
       _logger = logger,
       _analytics = analytics;
  final NotesRepository _notesRepository;
  final NoteIndexer _noteIndexer;
  final AppLogger _logger;
  final AnalyticsService _analytics;

  // Configuration constants
  static const int _maxFileSize = 100 * 1024 * 1024; // 100MB limit
  static const int _maxNotesPerImport = 10000; // Prevent memory issues
  static const int _maxContentLength = 1000000;

  // No need to declare typedef inside class

  /// Import a single Markdown file with comprehensive validation
  Future<ImportResult> importMarkdown(
    File file, {
    ProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      _logger.info(
        'Starting Markdown import',
        data: {
          'file': file.path,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Validate file
      await _validateFile(
        file,
        allowedExtensions: ['.md', '.markdown', '.txt'],
      );

      onProgress?.call(
        ImportProgress(
          phase: ImportPhase.reading,
          current: 0,
          total: 1,
          currentFile: path.basename(file.path),
        ),
      );

      // Read and validate content
      final content = await _readFileWithValidation(file);

      onProgress?.call(
        ImportProgress(
          phase: ImportPhase.parsing,
          current: 0,
          total: 1,
          currentFile: path.basename(file.path),
        ),
      );

      // Parse note
      final parsedNote = await _parseMarkdownFile(
        content,
        path.basename(file.path),
      );

      onProgress?.call(
        ImportProgress(
          phase: ImportPhase.converting,
          current: 0,
          total: 1,
          currentFile: path.basename(file.path),
        ),
      );

      // Convert to blocks with validation
      final blocks = await _parseMarkdownToBlocks(parsedNote.content);

      onProgress?.call(
        ImportProgress(
          phase: ImportPhase.saving,
          current: 0,
          total: 1,
          currentFile: path.basename(file.path),
        ),
      );

      // Create note with full validation
      await _createNoteWithValidation(
        title: parsedNote.title,
        blocks: blocks,
        originalPath: file.path,
        createdAt: parsedNote.createdAt,
        updatedAt: parsedNote.updatedAt,
        tags: parsedNote.tags,
      );

      onProgress?.call(
        ImportProgress(
          phase: ImportPhase.completed,
          current: 1,
          total: 1,
          currentFile: path.basename(file.path),
        ),
      );

      stopwatch.stop();
      final result = ImportResult.success(
        successCount: 1,
        duration: stopwatch.elapsed,
        importedFiles: [file.path],
      );

      _analytics.event(
        'import.success',
        properties: {
          'type': 'markdown',
          'count': 1,
          'duration_ms': stopwatch.elapsedMilliseconds,
          'file_size': await file.length(),
        },
      );

      _logger.info(
        'Markdown import completed successfully',
        data: {
          'duration_ms': stopwatch.elapsedMilliseconds,
          'file_size': await file.length(),
        },
      );

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      return _handleImportError(e, stackTrace, 'markdown', stopwatch.elapsed);
    }
  }

  /// Import ENEX file with robust XML parsing and validation
  Future<ImportResult> importEnex(
    File file, {
    ProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    var successCount = 0;
    final errors = <ImportError>[];
    final importedFiles = <String>[];

    try {
      _logger.info(
        'Starting ENEX import',
        data: {
          'file': file.path,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Validate file
      await _validateFile(file, allowedExtensions: ['.enex']);

      onProgress?.call(
        ImportProgress(
          phase: ImportPhase.reading,
          current: 0,
          total: 1,
          currentFile: path.basename(file.path),
        ),
      );

      // Read and parse XML with error handling
      final content = await _readFileWithValidation(file);
      late XmlDocument document;

      try {
        document = XmlDocument.parse(content);
      } catch (e) {
        throw ImportException('Invalid XML format: $e');
      }

      // Find notes with validation
      final noteElements = document.findAllElements('note');
      final totalNotes = noteElements.length;

      if (totalNotes == 0) {
        throw ImportException('No notes found in ENEX file');
      }

      if (totalNotes > _maxNotesPerImport) {
        throw ImportException(
          'Too many notes in file: $totalNotes. Maximum allowed: $_maxNotesPerImport',
        );
      }

      _logger.info('Found $totalNotes notes in ENEX file');

      onProgress?.call(
        ImportProgress(
          phase: ImportPhase.parsing,
          current: 0,
          total: totalNotes,
          currentFile: path.basename(file.path),
        ),
      );

      // Process each note with individual error handling
      final notesList = noteElements.toList();
      for (var i = 0; i < notesList.length; i++) {
        final noteElement = notesList[i];

        try {
          onProgress?.call(
            ImportProgress(
              phase: ImportPhase.parsing,
              current: i,
              total: totalNotes,
              currentFile: 'Note ${i + 1}',
            ),
          );

          final parsedNote = await _parseEnexNote(noteElement);
          final blocks = await _parseMarkdownToBlocks(parsedNote.content);

          onProgress?.call(
            ImportProgress(
              phase: ImportPhase.saving,
              current: i,
              total: totalNotes,
              currentFile: 'Note ${i + 1}',
            ),
          );

          await _createNoteWithValidation(
            title: parsedNote.title,
            blocks: blocks,
            originalPath: file.path,
            createdAt: parsedNote.createdAt,
            updatedAt: parsedNote.updatedAt,
            tags: parsedNote.tags,
          );

          successCount++;
          importedFiles.add('Note ${i + 1}: ${parsedNote.title}');
        } catch (e, stackTrace) {
          final error = ImportError(
            message: 'Failed to import note ${i + 1}: $e',
            source: 'Note ${i + 1}',
            exception: e,
            stackTrace: stackTrace,
          );
          errors.add(error);

          _logger.error(
            'Failed to import ENEX note ${i + 1}',
            error: e,
            stackTrace: stackTrace,
            data: {'note_index': i + 1},
          );
        }
      }

      onProgress?.call(
        ImportProgress(
          phase: ImportPhase.completed,
          current: totalNotes,
          total: totalNotes,
          currentFile: path.basename(file.path),
        ),
      );

      stopwatch.stop();
      final result = ImportResult(
        successCount: successCount,
        errorCount: errors.length,
        errors: errors,
        duration: stopwatch.elapsed,
        importedFiles: importedFiles,
      );

      _analytics.event(
        'import.success',
        properties: {
          'type': 'enex',
          'total': totalNotes,
          'success': successCount,
          'errors': errors.length,
          'duration_ms': stopwatch.elapsedMilliseconds,
          'file_size': await file.length(),
        },
      );

      _logger.info(
        'ENEX import completed',
        data: {
          'success': successCount,
          'errors': errors.length,
          'total': totalNotes,
          'duration_ms': stopwatch.elapsedMilliseconds,
        },
      );

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      return _handleImportError(
        e,
        stackTrace,
        'enex',
        stopwatch.elapsed,
        partialSuccessCount: successCount,
        partialErrors: errors,
        partialImportedFiles: importedFiles,
      );
    }
  }

  /// Import Obsidian vault with recursive file processing
  Future<ImportResult> importObsidian(
    Directory directory, {
    ProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    var successCount = 0;
    final errors = <ImportError>[];
    final importedFiles = <String>[];

    try {
      _logger.info(
        'Starting Obsidian vault import',
        data: {
          'directory': directory.path,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Validate directory
      if (!await directory.exists()) {
        throw ImportException('Directory does not exist: ${directory.path}');
      }

      onProgress?.call(
        const ImportProgress(
          phase: ImportPhase.scanning,
          current: 0,
          total: 1,
          currentFile: 'Scanning files...',
        ),
      );

      // Find all Markdown files with validation
      final markdownFiles = await _findMarkdownFiles(directory);
      final totalFiles = markdownFiles.length;

      if (totalFiles == 0) {
        throw ImportException('No Markdown files found in directory');
      }

      if (totalFiles > _maxNotesPerImport) {
        throw ImportException(
          'Too many files: $totalFiles. Maximum allowed: $_maxNotesPerImport',
        );
      }

      _logger.info('Found $totalFiles Markdown files in Obsidian vault');

      // Process each file with comprehensive error handling
      for (var i = 0; i < totalFiles; i++) {
        final file = markdownFiles[i];

        try {
          final relativePath = path.relative(file.path, from: directory.path);

          onProgress?.call(
            ImportProgress(
              phase: ImportPhase.processing,
              current: i,
              total: totalFiles,
              currentFile: relativePath,
            ),
          );

          // Validate individual file
          await _validateFile(file, allowedExtensions: ['.md', '.markdown']);

          final content = await _readFileWithValidation(file);
          final parsedNote = await _parseMarkdownFile(content, relativePath);
          final blocks = await _parseMarkdownToBlocks(parsedNote.content);

          await _createNoteWithValidation(
            title: parsedNote.title,
            blocks: blocks,
            originalPath: file.path,
            tags: _extractObsidianTags(content),
          );

          successCount++;
          importedFiles.add(relativePath);
        } catch (e, stackTrace) {
          final relativePath = path.relative(file.path, from: directory.path);
          final error = ImportError(
            message: 'Failed to import $relativePath: $e',
            source: relativePath,
            exception: e,
            stackTrace: stackTrace,
          );
          errors.add(error);

          _logger.error(
            'Failed to import Obsidian file',
            error: e,
            stackTrace: stackTrace,
            data: {'file': file.path, 'relative_path': relativePath},
          );
        }
      }

      onProgress?.call(
        ImportProgress(
          phase: ImportPhase.completed,
          current: totalFiles,
          total: totalFiles,
          currentFile: 'Import completed',
        ),
      );

      stopwatch.stop();
      final result = ImportResult(
        successCount: successCount,
        errorCount: errors.length,
        errors: errors,
        duration: stopwatch.elapsed,
        importedFiles: importedFiles,
      );

      _analytics.event(
        'import.success',
        properties: {
          'type': 'obsidian',
          'total': totalFiles,
          'success': successCount,
          'errors': errors.length,
          'duration_ms': stopwatch.elapsedMilliseconds,
        },
      );

      _logger.info(
        'Obsidian vault import completed',
        data: {
          'success': successCount,
          'errors': errors.length,
          'total': totalFiles,
          'duration_ms': stopwatch.elapsedMilliseconds,
        },
      );

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      return _handleImportError(
        e,
        stackTrace,
        'obsidian',
        stopwatch.elapsed,
        partialSuccessCount: successCount,
        partialErrors: errors,
        partialImportedFiles: importedFiles,
      );
    }
  }

  /// Pick and import files with user-friendly interface
  Future<ImportResult?> pickAndImport({ProgressCallback? onProgress}) async {
    try {
      onProgress?.call(
        const ImportProgress(
          phase: ImportPhase.selecting,
          current: 0,
          total: 1,
          currentFile: 'Opening file picker...',
        ),
      );

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'markdown', 'enex'],
      );

      if (result == null || result.files.isEmpty) {
        _logger.info('Import cancelled by user');
        _analytics.event('import.cancelled');
        return null;
      }

      final file = result.files.first;
      final filePath = file.path;

      if (filePath == null) {
        throw ImportException('Unable to access selected file');
      }

      return await importFromPath(filePath, onProgress: onProgress);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to pick and import file',
        error: e,
        stackTrace: stackTrace,
      );
      _analytics.event(
        'import.error',
        properties: {'phase': 'file_picking', 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Import from a specific file or directory path
  Future<ImportResult> importFromPath(
    String filePath, {
    ProgressCallback? onProgress,
  }) async {
    final fileSystemEntity = await FileSystemEntity.type(filePath);

    if (fileSystemEntity == FileSystemEntityType.file) {
      final file = File(filePath);
      final extension = path.extension(filePath).toLowerCase();

      switch (extension) {
        case '.md':
        case '.markdown':
          return importMarkdown(file, onProgress: onProgress);
        case '.enex':
          return importEnex(file, onProgress: onProgress);
        default:
          throw ImportException('Unsupported file type: $extension');
      }
    } else if (fileSystemEntity == FileSystemEntityType.directory) {
      final directory = Directory(filePath);
      return importObsidian(directory, onProgress: onProgress);
    } else {
      throw ImportException('Invalid file or directory path: $filePath');
    }
  }

  // Private helper methods with comprehensive validation

  /// Validate file size, existence, and type
  Future<void> _validateFile(
    File file, {
    required List<String> allowedExtensions,
  }) async {
    if (!await file.exists()) {
      throw ImportException('File does not exist: ${file.path}');
    }

    final fileSize = await file.length();
    if (fileSize > _maxFileSize) {
      throw ImportException(
        'File too large: ${_formatBytes(fileSize)}. '
        'Maximum allowed: ${_formatBytes(_maxFileSize)}',
      );
    }

    if (fileSize == 0) {
      throw ImportException('File is empty: ${file.path}');
    }

    final extension = path.extension(file.path).toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      throw ImportException(
        'Unsupported file type: $extension. '
        'Allowed types: ${allowedExtensions.join(', ')}',
      );
    }
  }

  /// Read file with encoding detection and validation
  Future<String> _readFileWithValidation(File file) async {
    try {
      final bytes = await file.readAsBytes();

      // Try UTF-8 first
      try {
        final content = utf8.decode(bytes, allowMalformed: false);

        if (content.length > _maxContentLength) {
          throw ImportException(
            'File content too large: ${content.length} characters. '
            'Maximum allowed: $_maxContentLength characters.',
          );
        }

        return content;
      } catch (e) {
        // Fallback to Latin-1 if UTF-8 fails
        final content = latin1.decode(bytes);

        if (content.length > _maxContentLength) {
          throw ImportException(
            'File content too large: ${content.length} characters. '
            'Maximum allowed: $_maxContentLength characters.',
          );
        }

        return content;
      }
    } catch (e) {
      throw ImportException('Failed to read file: $e');
    }
  }

  /// Parse Markdown file with enhanced title detection
  Future<ParsedNote> _parseMarkdownFile(String content, String filename) async {
    final lines = content.split('\n');
    var title = '';
    var bodyContent = content;
    final tags = <String>[];

    // Enhanced title extraction
    if (lines.isNotEmpty) {
      final firstLine = lines.first.trim();

      // Try H1 heading
      if (firstLine.startsWith('# ')) {
        title = firstLine.substring(2).trim();
        bodyContent = lines.skip(1).join('\n').trim();
      }
      // Try H2 heading as fallback
      else if (firstLine.startsWith('## ')) {
        title = firstLine.substring(3).trim();
        bodyContent = lines.skip(1).join('\n').trim();
      }
      // Look for title in frontmatter
      else if (firstLine == '---') {
        final frontmatterEnd = lines.skip(1).toList().indexOf('---');
        if (frontmatterEnd != -1) {
          final frontmatter = lines.skip(1).take(frontmatterEnd).join('\n');
          title = _extractTitleFromFrontmatter(frontmatter);
          bodyContent = lines.skip(frontmatterEnd + 2).join('\n').trim();
        }
      }
    }

    // Generate title from filename if none found
    if (title.isEmpty) {
      title = _generateTitleFromFilename(filename);
    }

    // Extract tags from content
    tags.addAll(_extractMarkdownTags(content));

    return ParsedNote(
      title: title.isEmpty ? 'Untitled Note' : title,
      content: bodyContent,
      tags: tags,
    );
  }

  /// Parse ENEX note with comprehensive error handling
  Future<ParsedNote> _parseEnexNote(XmlElement noteElement) async {
    var title = 'Untitled Note';
    var content = '';
    DateTime? createdAt;
    DateTime? updatedAt;
    final tags = <String>[];

    try {
      // Extract title with validation
      final titleElement = noteElement.findElements('title').firstOrNull;
      if (titleElement != null && titleElement.innerText.trim().isNotEmpty) {
        title = titleElement.innerText.trim();

        // Validate title length
        if (title.length > 1000) {
          title = '${title.substring(0, 997)}...';
        }
      }

      // Extract content with ENML conversion
      final contentElement = noteElement.findElements('content').firstOrNull;
      if (contentElement != null) {
        content = await _convertEnmlToMarkdown(contentElement.innerText);
      }

      // Extract dates with validation
      final createdElement = noteElement.findElements('created').firstOrNull;
      if (createdElement != null) {
        createdAt = _parseEnexDate(createdElement.innerText);
      }

      final updatedElement = noteElement.findElements('updated').firstOrNull;
      if (updatedElement != null) {
        updatedAt = _parseEnexDate(updatedElement.innerText);
      }

      // Extract tags
      for (final tagElement in noteElement.findElements('tag')) {
        final tag = tagElement.innerText.trim();
        if (tag.isNotEmpty && tag.length <= 50) {
          tags.add(tag);
        }
      }
    } catch (e) {
      _logger.error('Error parsing ENEX note element', error: e);
    }

    return ParsedNote(
      title: title,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
      tags: tags,
    );
  }

  /// Convert ENML to Markdown with robust parsing
  Future<String> _convertEnmlToMarkdown(String enml) async {
    if (enml.trim().isEmpty) return '';

    try {
      var markdown = enml;

      // Remove ENML envelope
      markdown = markdown.replaceAll(RegExp(r'<\?xml[^>]*>'), '');
      markdown = markdown.replaceAll(RegExp('<!DOCTYPE[^>]*>'), '');
      markdown = markdown.replaceAll(RegExp('<en-note[^>]*>'), '');
      markdown = markdown.replaceAll('</en-note>', '');

      // Convert block elements
      markdown = markdown.replaceAll(RegExp('<div[^>]*>'), '\n');
      markdown = markdown.replaceAll('</div>', '\n');
      markdown = markdown.replaceAll(
        RegExp('<br[^>]*/?>', multiLine: true),
        '\n',
      );
      markdown = markdown.replaceAll(RegExp('<p[^>]*>'), '\n');
      markdown = markdown.replaceAll('</p>', '\n');

      // Convert formatting with proper escaping
      markdown = markdown.replaceAllMapped(
        RegExp('<b[^>]*>(.*?)</b>', dotAll: true),
        (match) => '**${match.group(1)?.trim() ?? ''}**',
      );
      markdown = markdown.replaceAllMapped(
        RegExp('<strong[^>]*>(.*?)</strong>', dotAll: true),
        (match) => '**${match.group(1)?.trim() ?? ''}**',
      );
      markdown = markdown.replaceAllMapped(
        RegExp('<i[^>]*>(.*?)</i>', dotAll: true),
        (match) => '*${match.group(1)?.trim() ?? ''}*',
      );
      markdown = markdown.replaceAllMapped(
        RegExp('<em[^>]*>(.*?)</em>', dotAll: true),
        (match) => '*${match.group(1)?.trim() ?? ''}*',
      );

      // Convert lists
      markdown = markdown.replaceAll(RegExp('<ul[^>]*>'), '');
      markdown = markdown.replaceAll('</ul>', '');
      markdown = markdown.replaceAll(RegExp('<ol[^>]*>'), '');
      markdown = markdown.replaceAll('</ol>', '');
      markdown = markdown.replaceAll(RegExp('<li[^>]*>'), '- ');
      markdown = markdown.replaceAll('</li>', '\n');

      // Clean up excessive whitespace
      markdown = markdown.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
      markdown = markdown.replaceAll(RegExp(r'^\s+|\s+$'), '');

      return markdown;
    } catch (e) {
      _logger.error('Error converting ENML to Markdown', error: e);
      return enml; // Return original if conversion fails
    }
  }

  /// Parse Evernote date with comprehensive validation
  DateTime? _parseEnexDate(String dateStr) {
    if (dateStr.trim().isEmpty) return null;

    try {
      // Handle various Evernote date formats
      final cleaned = dateStr.trim().replaceAll(RegExp('[TZ]'), '');

      if (cleaned.length >= 8) {
        final year = int.parse(cleaned.substring(0, 4));
        final month = int.parse(cleaned.substring(4, 6));
        final day = int.parse(cleaned.substring(6, 8));

        // Validate date components
        if (year < 1900 ||
            year > 2100 ||
            month < 1 ||
            month > 12 ||
            day < 1 ||
            day > 31) {
          return null;
        }

        if (cleaned.length >= 14) {
          final hour = int.parse(cleaned.substring(8, 10));
          final minute = int.parse(cleaned.substring(10, 12));
          final second = int.parse(cleaned.substring(12, 14));

          if (hour < 0 ||
              hour > 23 ||
              minute < 0 ||
              minute > 59 ||
              second < 0 ||
              second > 59) {
            return DateTime.utc(year, month, day);
          }

          return DateTime.utc(year, month, day, hour, minute, second);
        } else {
          return DateTime.utc(year, month, day);
        }
      }
    } catch (e) {
      _logger.error(
        'Failed to parse ENEX date',
        error: e,
        data: {'date': dateStr},
      );
    }

    return null;
  }

  /// Find Markdown files with comprehensive filtering
  Future<List<File>> _findMarkdownFiles(Directory directory) async {
    final files = <File>[];
    final validExtensions = {'.md', '.markdown'};

    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();
          final filename = path.basename(entity.path);

          // Check extension
          if (!validExtensions.contains(extension)) continue;

          // Skip hidden files, system files, and common non-content files
          if (filename.startsWith('.') ||
              filename.startsWith('_') ||
              filename.toLowerCase() == 'readme.md' ||
              filename.toLowerCase().contains('license') ||
              filename.toLowerCase().contains('changelog')) {
            continue;
          }

          // Validate file size
          try {
            final fileSize = await entity.length();
            if (fileSize > _maxFileSize || fileSize == 0) continue;
          } catch (e) {
            _logger.error(
              'Cannot check file size',
              error: e,
              data: {'file': entity.path},
            );
            continue;
          }

          files.add(entity);
        }
      }
    } catch (e) {
      throw ImportException('Failed to scan directory: $e');
    }

    return files;
  }

  /// Extract tags from content with validation
  List<String> _extractObsidianTags(String content) {
    final tags = <String>{};

    // Find hashtag-style tags
    final hashtagPattern = RegExp(r'#([a-zA-Z0-9_-]+)(?:\s|$)');
    final matches = hashtagPattern.allMatches(content);

    for (final match in matches) {
      final tag = match.group(1);
      if (tag != null && tag.length <= 50 && tag.length >= 2) {
        tags.add(tag.toLowerCase());
      }
    }

    return tags.toList();
  }

  /// Extract tags from Markdown content
  List<String> _extractMarkdownTags(String content) {
    final tags = <String>{};

    // Look for tags in various formats
    final patterns = [
      RegExp(r'tags:\s*\[(.*?)\]', multiLine: true), // YAML array
      RegExp(r'tags:\s*(.*?)(?:\n|$)', multiLine: true), // YAML list
      RegExp(r'#([a-zA-Z0-9_-]+)(?:\s|$)'), // Hashtags
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(content);
      for (final match in matches) {
        final tagText = match.group(1)?.trim();
        if (tagText != null && tagText.isNotEmpty) {
          // Parse comma-separated or space-separated tags
          final individualTags = tagText
              .split(RegExp(r'[,\s]+'))
              .where((tag) => tag.isNotEmpty && tag.length <= 50)
              .map(
                (tag) => tag.toLowerCase().replaceAll(RegExp(r'[^\w-]'), ''),
              );

          tags.addAll(individualTags);
        }
      }
    }

    return tags.toList();
  }

  /// Convert Markdown to blocks with enhanced error handling
  Future<List<NoteBlock>> _parseMarkdownToBlocks(String content) async {
    try {
      if (content.trim().isEmpty) {
        return [const NoteBlock(type: NoteBlockType.paragraph, data: '')];
      }

      // Use the parser from the helper function
      return await compute(_parseMarkdownInIsolate, {
        'content': content,
        'maxLength': _maxContentLength,
      });
    } catch (e) {
      _logger.error('Failed to parse markdown to blocks', error: e);
      // Fallback: create a single paragraph block
      return [NoteBlock(type: NoteBlockType.paragraph, data: content)];
    }
  }

  /// Create note with comprehensive validation and error handling
  Future<void> _createNoteWithValidation({
    required String title,
    required List<NoteBlock> blocks,
    required String originalPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
  }) async {
    // Validate title
    if (title.trim().isEmpty) {
      throw ImportException('Note title cannot be empty');
    }

    if (title.length > 1000) {
      throw ImportException('Note title too long: ${title.length} characters');
    }

    // Validate blocks
    if (blocks.isEmpty) {
      throw ImportException('Note must have at least one block');
    }

    if (blocks.length > 1000) {
      throw ImportException('Too many blocks: ${blocks.length}. Maximum: 1000');
    }

    // Validate each block
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.data.trim().isEmpty) {
        throw ImportException('Invalid block at position $i');
      }
    }

    // Validate tags
    final validTags =
        tags
            ?.where(
              (tag) =>
                  tag.trim().isNotEmpty && tag.length <= 50 && tag.length >= 2,
            )
            .take(20)
            .toList() ??
        [];

    try {
      // Create the note with timeout
      final createdNote = await _notesRepository.createOrUpdate(
        title: title.trim(),
        body: blocksToMarkdown(blocks),
      );

      if (createdNote == null) {
        _logger.error('Failed to create note');
        return;
      }

      // Index the newly created note so search/backlinks remain up to date
      await _noteIndexer.indexNote(createdNote);

      _logger.info(
        'Successfully imported note',
        data: {
          'noteId': createdNote.id,
          'title': title,
          'originalPath': originalPath,
          'blockCount': blocks.length,
          'tagCount': validTags.length,
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create imported note',
        error: e,
        stackTrace: stackTrace,
        data: {
          'title': title,
          'originalPath': originalPath,
          'blockCount': blocks.length,
        },
      );
      rethrow;
    }
  }

  /// Handle import errors with comprehensive logging
  ImportResult _handleImportError(
    Object error,
    StackTrace stackTrace,
    String importType,
    Duration elapsed, {
    int partialSuccessCount = 0,
    List<ImportError> partialErrors = const [],
    List<String> partialImportedFiles = const [],
  }) {
    final errorMessage = error.toString();

    _logger.error(
      'Import failed',
      error: error,
      stackTrace: stackTrace,
      data: {
        'import_type': importType,
        'duration_ms': elapsed.inMilliseconds,
        'partial_success': partialSuccessCount,
      },
    );

    _analytics.event(
      'import.error',
      properties: {
        'type': importType,
        'error': errorMessage,
        'duration_ms': elapsed.inMilliseconds,
        'partial_success': partialSuccessCount,
      },
    );

    final importError = ImportError(
      message: errorMessage,
      source: 'Import Service',
      exception: error,
      stackTrace: stackTrace,
    );

    return ImportResult(
      successCount: partialSuccessCount,
      errorCount: partialErrors.length + 1,
      errors: [...partialErrors, importError],
      duration: elapsed,
      importedFiles: partialImportedFiles,
    );
  }

  // Helper methods

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _extractTitleFromFrontmatter(String frontmatter) {
    final titleMatch = RegExp(
      r'^title:\s*(.+)$',
      multiLine: true,
    ).firstMatch(frontmatter);
    final title = titleMatch?.group(1)?.trim() ?? '';
    // Remove quotes from beginning and end
    var result = title;
    if (result.startsWith('"') && result.endsWith('"')) {
      result = result.substring(1, result.length - 1);
    }
    if (result.startsWith("'") && result.endsWith("'")) {
      result = result.substring(1, result.length - 1);
    }
    return result;
  }

  String _generateTitleFromFilename(String filename) {
    var title = path.basenameWithoutExtension(filename);
    title = title.replaceAll(RegExp('[_-]'), ' ');
    title = title.replaceAll(RegExp(r'\s+'), ' ');

    // Capitalize words
    return title
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ')
        .trim();
  }
}

// Supporting classes and types

/// Represents a parsed note with metadata
class ParsedNote {
  const ParsedNote({
    required this.title,
    required this.content,
    this.createdAt,
    this.updatedAt,
    this.tags = const [],
  });
  final String title;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> tags;
}

/// Import result with comprehensive error information
class ImportResult {
  const ImportResult({
    required this.successCount,
    required this.errorCount,
    required this.errors,
    required this.duration,
    required this.importedFiles,
  });

  factory ImportResult.success({
    required int successCount,
    required Duration duration,
    required List<String> importedFiles,
  }) {
    return ImportResult(
      successCount: successCount,
      errorCount: 0,
      errors: const [],
      duration: duration,
      importedFiles: importedFiles,
    );
  }
  final int successCount;
  final int errorCount;
  final List<ImportError> errors;
  final Duration duration;
  final List<String> importedFiles;

  bool get hasErrors => errorCount > 0;
  int get totalProcessed => successCount + errorCount;
  bool get isSuccess => errorCount == 0 && successCount > 0;

  double get successRate =>
      totalProcessed > 0 ? successCount / totalProcessed : 0.0;
}

/// Detailed import error information
class ImportError {
  const ImportError({
    required this.message,
    required this.source,
    this.exception,
    this.stackTrace,
  });
  final String message;
  final String source;
  final Object? exception;
  final StackTrace? stackTrace;

  @override
  String toString() => '$source: $message';
}

/// Import progress information for UI updates
class ImportProgress {
  const ImportProgress({
    required this.phase,
    required this.current,
    required this.total,
    required this.currentFile,
  });
  final ImportPhase phase;
  final int current;
  final int total;
  final String currentFile;

  double get progress => total > 0 ? current / total : 0.0;
  String get phaseDescription => phase.description;
}

/// Import phases for progress tracking
enum ImportPhase {
  selecting('Selecting files'),
  scanning('Scanning directory'),
  reading('Reading file'),
  parsing('Parsing content'),
  converting('Converting to blocks'),
  processing('Processing files'),
  saving('Saving notes'),
  completed('Import completed');

  const ImportPhase(this.description);
  final String description;
}

/// Import-specific exception with user-friendly messages
class ImportException implements Exception {
  ImportException(this.message);
  final String message;

  @override
  String toString() => 'ImportException: $message';
}

/// Extension for safe XML element access
extension XmlElementExtension on Iterable<XmlElement> {
  XmlElement? get firstOrNull => isEmpty ? null : first;
}

/// Isolate function for parsing Markdown (for compute)
List<NoteBlock> _parseMarkdownInIsolate(Map<String, dynamic> params) {
  final content = params['content'] as String;
  final maxLength = params['maxLength'] as int;

  if (content.length > maxLength) {
    throw ImportException('Content too long: ${content.length} characters');
  }

  return parseMarkdownToBlocks(content);
}
