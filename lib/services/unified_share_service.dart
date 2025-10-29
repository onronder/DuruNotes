import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

import 'package:duru_notes/core/io/app_directory_resolver.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/services/analytics/analytics_service.dart';

/// Share formats supported by the app
enum ShareFormat {
  plainText,
  markdown,
  html,
  json,
  pdf,
}

/// Share options for customizing the sharing experience
class ShareOptions {
  const ShareOptions({
    this.format = ShareFormat.markdown,
    this.includeTitle = true,
    this.includeMetadata = false,
    this.includeTasks = true,
    this.includeAttachments = false,
    this.customSubject,
  });

  final ShareFormat format;
  final bool includeTitle;
  final bool includeMetadata;
  final bool includeTasks;
  final bool includeAttachments;
  final String? customSubject;
}

/// Result of a share operation
class ShareResult {
  const ShareResult({
    required this.success,
    this.message,
    this.sharedFiles = const [],
  });

  final bool success;
  final String? message;
  final List<File> sharedFiles;
}

/// Unified share service that works with both domain and legacy models
class UnifiedShareService {
  static final UnifiedShareService _instance = UnifiedShareService._internal();
  factory UnifiedShareService() => _instance;
  UnifiedShareService._internal();

  final _logger = LoggerFactory.instance;

  late final AppDb _db;
  late final MigrationConfig _migrationConfig;
  late final AnalyticsService _analytics;

  Future<void> initialize({
    required AppDb database,
    required MigrationConfig migrationConfig,
    required AnalyticsService analytics,
  }) async {
    _db = database;
    _migrationConfig = migrationConfig;
    _analytics = analytics;
    _logger.info('UnifiedShareService initialized');
  }

  /// Share a single note
  Future<ShareResult> shareNote(
    dynamic note, {
    ShareOptions options = const ShareOptions(),
  }) async {
    try {
      _analytics.startTiming('share_note');

      final noteId = _getNoteId(note);
      final noteTitle = _getNoteTitle(note);
      // Note: noteContent not needed here as _formatContent extracts it directly from note
      // final noteContent = _getNoteContent(note);

      _logger.debug('Sharing note: $noteId with format: ${options.format}');

      // Format the content based on options
      String formattedContent = await _formatContent(
        note: note,
        options: options,
      );

      // Determine the subject
      final subject = options.customSubject ??
                      (noteTitle.isNotEmpty ? noteTitle : 'Shared Note');

      // Handle different share formats
      ShareResult result;
      switch (options.format) {
        case ShareFormat.pdf:
          result = await _sharePdf(note, formattedContent, subject);
          break;
        case ShareFormat.html:
          result = await _shareHtml(note, formattedContent, subject);
          break;
        default:
          result = await _shareText(formattedContent, subject);
      }

      // Track analytics
      _analytics.endTiming('share_note');
      _analytics.event('note_shared', properties: {
        'format': options.format.name,
        'include_metadata': options.includeMetadata,
        'include_tasks': options.includeTasks,
      });

      return result;

    } catch (e, stack) {
      _logger.error('Failed to share note', error: e, stackTrace: stack);
      _analytics.endTiming('share_note');
      return ShareResult(
        success: false,
        message: 'Failed to share: ${e.toString()}',
      );
    }
  }

  /// Share multiple notes
  Future<ShareResult> shareNotes(
    List<dynamic> notes, {
    ShareOptions options = const ShareOptions(),
  }) async {
    try {
      _analytics.startTiming('share_multiple_notes');

      _logger.debug('Sharing ${notes.length} notes with format: ${options.format}');

      // Combine all notes content
      final combinedContent = await _combineNotesContent(notes, options);
      final subject = options.customSubject ?? 'Shared Notes (${notes.length})';

      ShareResult result;
      switch (options.format) {
        case ShareFormat.pdf:
          result = await _shareMultiplePdf(notes, combinedContent, subject);
          break;
        case ShareFormat.html:
          result = await _shareHtml(null, combinedContent, subject);
          break;
        case ShareFormat.json:
          result = await _shareJson(notes, subject);
          break;
        default:
          result = await _shareText(combinedContent, subject);
      }

      _analytics.endTiming('share_multiple_notes');
      _analytics.event('multiple_notes_shared', properties: {
        'count': notes.length,
        'format': options.format.name,
      });

      return result;

    } catch (e, stack) {
      _logger.error('Failed to share multiple notes', error: e, stackTrace: stack);
      _analytics.endTiming('share_multiple_notes');
      return ShareResult(
        success: false,
        message: 'Failed to share: ${e.toString()}',
      );
    }
  }

  /// Share note to clipboard
  Future<bool> copyToClipboard(
    dynamic note, {
    ShareFormat format = ShareFormat.markdown,
  }) async {
    try {
      final formattedContent = await _formatContent(
        note: note,
        options: ShareOptions(format: format),
      );

      await Clipboard.setData(ClipboardData(text: formattedContent));

      _analytics.event('note_copied_to_clipboard', properties: {
        'format': format.name,
      });

      return true;
    } catch (e, stack) {
      _logger.error('Failed to copy to clipboard', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Export note as file
  Future<File?> exportAsFile(
    dynamic note, {
    ShareFormat format = ShareFormat.markdown,
    String? outputPath,
  }) async {
    try {
      // Note: noteId used only for task lookup which is temporarily disabled
      // final noteId = _getNoteId(note);
      final noteTitle = _getNoteTitle(note);

      // Determine file extension
      String extension;
      switch (format) {
        case ShareFormat.markdown:
          extension = 'md';
          break;
        case ShareFormat.html:
          extension = 'html';
          break;
        case ShareFormat.json:
          extension = 'json';
          break;
        case ShareFormat.pdf:
          extension = 'pdf';
          break;
        default:
          extension = 'txt';
      }

      // Generate file path
      final tempDir = await resolveTemporaryDirectory();
      final fileName = '${noteTitle.replaceAll(RegExp(r'[^\w\s-]'), '')}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = outputPath ?? path.join(tempDir.path, fileName);
      final file = File(filePath);

      // Format content
      final formattedContent = await _formatContent(
        note: note,
        options: ShareOptions(format: format, includeMetadata: true),
      );

      // Write to file
      if (format == ShareFormat.pdf) {
        // PDF generation would require additional implementation
        _logger.warning('PDF export not yet implemented in unified service');
        return null;
      } else {
        await file.writeAsString(formattedContent);
      }

      _analytics.event('note_exported', properties: {
        'format': format.name,
        'file_size': file.lengthSync(),
      });

      return file;

    } catch (e, stack) {
      _logger.error('Failed to export as file', error: e, stackTrace: stack);
      return null;
    }
  }

  // Private helper methods
  Future<String> _formatContent({
    required dynamic note,
    required ShareOptions options,
  }) async {
    final noteTitle = _getNoteTitle(note);
    final noteContent = _getNoteContent(note);
    final noteCreatedAt = _getNoteCreatedAt(note);
    final noteUpdatedAt = _getNoteUpdatedAt(note);

    final buffer = StringBuffer();

    switch (options.format) {
      case ShareFormat.markdown:
        if (options.includeTitle && noteTitle.isNotEmpty) {
          buffer.writeln('# $noteTitle');
          buffer.writeln();
        }
        if (options.includeMetadata) {
          buffer.writeln('---');
          buffer.writeln('Created: ${noteCreatedAt.toIso8601String()}');
          buffer.writeln('Updated: ${noteUpdatedAt.toIso8601String()}');
          buffer.writeln('---');
          buffer.writeln();
        }
        buffer.write(noteContent);

        if (options.includeTasks) {
          final tasks = await _getNoteTasks(note);
          if (tasks.isNotEmpty) {
            buffer.writeln('\n\n## Tasks');
            for (final task in tasks) {
              final completed = _isTaskCompleted(task);
              final taskTitle = _getTaskTitle(task);
              buffer.writeln('- [${completed ? 'x' : ' '}] $taskTitle');
            }
          }
        }
        break;

      case ShareFormat.html:
        buffer.writeln('<!DOCTYPE html>');
        buffer.writeln('<html><head>');
        buffer.writeln('<meta charset="UTF-8">');
        buffer.writeln('<title>${_escapeHtml(noteTitle)}</title>');
        buffer.writeln('<style>');
        buffer.writeln('body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }');
        buffer.writeln('pre { background: #f5f5f5; padding: 10px; overflow-x: auto; }');
        buffer.writeln('</style>');
        buffer.writeln('</head><body>');

        if (options.includeTitle && noteTitle.isNotEmpty) {
          buffer.writeln('<h1>${_escapeHtml(noteTitle)}</h1>');
        }

        if (options.includeMetadata) {
          buffer.writeln('<div class="metadata">');
          buffer.writeln('<p><small>Created: ${noteCreatedAt.toLocal()}</small></p>');
          buffer.writeln('<p><small>Updated: ${noteUpdatedAt.toLocal()}</small></p>');
          buffer.writeln('</div><hr>');
        }

        // Convert markdown to HTML (simplified)
        final htmlContent = _markdownToHtml(noteContent);
        buffer.writeln(htmlContent);

        buffer.writeln('</body></html>');
        break;

      case ShareFormat.json:
        final jsonData = <String, dynamic>{
          'id': _getNoteId(note),
          'title': noteTitle,
          'content': noteContent,
          'created_at': noteCreatedAt.toIso8601String(),
          'updated_at': noteUpdatedAt.toIso8601String(),
        };

        if (options.includeTasks) {
          final tasks = await _getNoteTasks(note);
          jsonData['tasks'] = tasks.map((task) => {
            'id': _getTaskId(task),
            'title': _getTaskTitle(task),
            'completed': _isTaskCompleted(task),
          }).toList();
        }

        buffer.write(const JsonEncoder.withIndent('  ').convert(jsonData));
        break;

      case ShareFormat.plainText:
      default:
        if (options.includeTitle && noteTitle.isNotEmpty) {
          buffer.writeln(noteTitle);
          buffer.writeln('=' * noteTitle.length);
          buffer.writeln();
        }
        if (options.includeMetadata) {
          buffer.writeln('Created: ${noteCreatedAt.toLocal()}');
          buffer.writeln('Updated: ${noteUpdatedAt.toLocal()}');
          buffer.writeln('-' * 40);
          buffer.writeln();
        }
        buffer.write(noteContent);
        break;
    }

    return buffer.toString();
  }

  Future<String> _combineNotesContent(
    List<dynamic> notes,
    ShareOptions options,
  ) async {
    final buffer = StringBuffer();

    for (int i = 0; i < notes.length; i++) {
      if (i > 0) {
        buffer.writeln('\n---\n');
      }

      final content = await _formatContent(
        note: notes[i],
        options: options,
      );
      buffer.write(content);
    }

    return buffer.toString();
  }

  Future<ShareResult> _shareText(String content, String subject) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: content,
          subject: subject,
        ),
      );
      return const ShareResult(success: true);
    } catch (e) {
      _logger.error('Failed to share text', error: e);
      return ShareResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  Future<ShareResult> _shareHtml(dynamic note, String htmlContent, String subject) async {
    try {
      // Save HTML to temporary file
      final tempDir = await resolveTemporaryDirectory();
      final htmlFile = File(path.join(tempDir.path, 'share_${DateTime.now().millisecondsSinceEpoch}.html'));
      await htmlFile.writeAsString(htmlContent);

      // Share the file
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(htmlFile.path)],
          subject: subject,
        ),
      );

      return ShareResult(
        success: result.status == ShareResultStatus.success,
        sharedFiles: [htmlFile],
      );
    } catch (e) {
      _logger.error('Failed to share HTML', error: e);
      return ShareResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  Future<ShareResult> _sharePdf(dynamic note, String content, String subject) async {
    // PDF generation would require additional implementation
    _logger.warning('PDF sharing not yet implemented');
    return const ShareResult(
      success: false,
      message: 'PDF sharing not yet implemented',
    );
  }

  Future<ShareResult> _shareMultiplePdf(List<dynamic> notes, String content, String subject) async {
    // PDF generation would require additional implementation
    _logger.warning('Multi-PDF sharing not yet implemented');
    return const ShareResult(
      success: false,
      message: 'Multi-PDF sharing not yet implemented',
    );
  }

  Future<ShareResult> _shareJson(List<dynamic> notes, String subject) async {
    try {
      final jsonData = {
        'notes': await Future.wait(notes.map((note) async {
          final tasks = await _getNoteTasks(note);
          return {
            'id': _getNoteId(note),
            'title': _getNoteTitle(note),
            'content': _getNoteContent(note),
            'created_at': _getNoteCreatedAt(note).toIso8601String(),
            'updated_at': _getNoteUpdatedAt(note).toIso8601String(),
            'tasks': tasks.map((task) => {
              'id': _getTaskId(task),
              'title': _getTaskTitle(task),
              'completed': _isTaskCompleted(task),
            }).toList(),
          };
        })),
        'exported_at': DateTime.now().toIso8601String(),
        'count': notes.length,
      };

      final jsonContent = const JsonEncoder.withIndent('  ').convert(jsonData);

      // Save to file and share
      final tempDir = await resolveTemporaryDirectory();
      final jsonFile = File(path.join(tempDir.path, 'notes_export_${DateTime.now().millisecondsSinceEpoch}.json'));
      await jsonFile.writeAsString(jsonContent);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(jsonFile.path)],
          subject: subject,
        ),
      );

      return ShareResult(
        success: result.status == ShareResultStatus.success,
        sharedFiles: [jsonFile],
      );
    } catch (e) {
      _logger.error('Failed to share JSON', error: e);
      return ShareResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  // Type-agnostic helper methods
  String _getNoteId(dynamic note) {
    if (note is domain.Note) return note.id;
    if (note is LocalNote) return note.id;
    throw ArgumentError('Unknown note type');
  }

  String _getNoteTitle(dynamic note) {
    if (note is domain.Note) return note.title;
    // LocalNote.title doesn't exist post-encryption
    throw UnsupportedError('LocalNote title access deprecated. Use domain.Note from repository instead.');
  }

  String _getNoteContent(dynamic note) {
    if (note is domain.Note) return note.body;
    // LocalNote.body doesn't exist post-encryption
    throw UnsupportedError('LocalNote content access deprecated. Use domain.Note from repository instead.');
  }

  DateTime _getNoteCreatedAt(dynamic note) {
    if (note is domain.Note) return note.updatedAt;
    if (note is LocalNote) return note.updatedAt;
    throw ArgumentError('Unknown note type');
  }

  DateTime _getNoteUpdatedAt(dynamic note) {
    if (note is domain.Note) return note.updatedAt;
    if (note is LocalNote) return note.updatedAt;
    throw ArgumentError('Unknown note type');
  }

  Future<List<dynamic>> _getNoteTasks(dynamic note) async {
    final noteId = _getNoteId(note);

    if (_migrationConfig.isFeatureEnabled('tasks')) {
      // Use domain tasks - would need task repository
      return [];
    } else {
      // Use legacy tasks
      final localNote = await (_db.select(_db.localNotes)
            ..where((n) => n.id.equals(noteId)))
          .getSingleOrNull();
      final userId = localNote?.userId;
      if (userId == null || userId.isEmpty) {
        return [];
      }
      return await _db.getTasksForNote(noteId, userId: userId);
    }
  }

  String _getTaskId(dynamic task) {
    if (task is domain.Task) return task.id;
    if (task is NoteTask) return task.id;
    throw ArgumentError('Unknown task type');
  }

  String _getTaskTitle(dynamic task) {
    if (task is domain.Task) return task.title;
    // NoteTask.content doesn't exist post-encryption
    throw UnsupportedError('NoteTask title access deprecated. Use domain.Task from repository instead.');
  }

  bool _isTaskCompleted(dynamic task) {
    if (task is domain.Task) return task.status == domain.TaskStatus.completed;
    if (task is NoteTask) return task.status == TaskStatus.completed;
    throw ArgumentError('Unknown task type');
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _markdownToHtml(String markdown) {
    // Simplified markdown to HTML conversion
    // A full implementation would use a markdown parser
    return markdown
        .replaceAll(RegExp(r'^# (.+)$', multiLine: true), '<h1>\$1</h1>')
        .replaceAll(RegExp(r'^## (.+)$', multiLine: true), '<h2>\$1</h2>')
        .replaceAll(RegExp(r'^### (.+)$', multiLine: true), '<h3>\$1</h3>')
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), '<strong>\$1</strong>')
        .replaceAll(RegExp(r'\*(.+?)\*'), '<em>\$1</em>')
        .replaceAll(RegExp(r'^- (.+)$', multiLine: true), '<li>\$1</li>')
        .replaceAll(RegExp(r'\[(.+?)\]\((.+?)\)'), '<a href="\$2">\$1</a>')
        .replaceAll('\n\n', '</p><p>')
        .replaceAll('\n', '<br>')
        .replaceAll('<li>', '<ul><li>')
        .replaceAll('</li>\n', '</li></ul>\n');
  }
}
