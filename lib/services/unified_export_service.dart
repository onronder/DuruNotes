import 'dart:io';

import 'package:duru_notes/core/io/app_directory_resolver.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/services/export_service.dart';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show migrationConfigProvider, analyticsProvider;
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Unified export service that works with domain.Note
class UnifiedExportService {
  UnifiedExportService({
    required this.ref,
    required this.notesRepository,
    required this.migrationConfig,
  }) : _logger = LoggerFactory.instance;

  final Ref ref;
  final INotesRepository notesRepository;
  final MigrationConfig migrationConfig;
  final AppLogger _logger;

  /// Export a note to the specified format
  Future<File?> exportNote({
    required domain.Note note,
    required ExportFormat format,
    ExportOptions options = const ExportOptions(),
  }) async {
    try {
      _logger.info('[UnifiedExport] Exporting note as ${format.displayName}');

      // Extract note data based on type
      final noteData = _extractNoteData(note);

      // Get export content based on format
      String content;
      switch (format) {
        case ExportFormat.markdown:
          content = await _generateMarkdown(noteData, options);
          break;
        case ExportFormat.html:
          content = await _generateHtml(noteData, options);
          break;
        case ExportFormat.txt:
          content = await _generatePlainText(noteData, options);
          break;
        case ExportFormat.pdf:
          return await _generatePdf(noteData, options);
        case ExportFormat.docx:
          // For now, export as HTML which can be opened in Word
          content = await _generateHtml(noteData, options);
          break;
      }

      // Save to file
      final directory = await resolveTemporaryDirectory();
      final fileName = _sanitizeFileName(noteData['title'] as String);
      final file = File(
        path.join(directory.path, '$fileName.${format.extension}'),
      );

      await file.writeAsString(content);

      // Track export
      await _trackExport(format, 1);

      _logger.info('[UnifiedExport] Export completed: ${file.path}');
      return file;
    } catch (e, stack) {
      _logger.error(
        '[UnifiedExport] Export failed',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Export multiple notes
  Future<File?> exportNotes({
    required List<domain.Note> notes,
    required ExportFormat format,
    ExportOptions options = const ExportOptions(),
    String? customFileName,
  }) async {
    try {
      _logger.info(
        '[UnifiedExport] Exporting ${notes.length} notes as ${format.displayName}',
      );

      if (notes.isEmpty) return null;

      // Extract data for all notes
      final notesData = notes.map(_extractNoteData).toList();

      // Get export content based on format
      String content;
      switch (format) {
        case ExportFormat.markdown:
          content = await _generateMultipleMarkdown(notesData, options);
          break;
        case ExportFormat.html:
          content = await _generateMultipleHtml(notesData, options);
          break;
        case ExportFormat.txt:
          content = await _generateMultiplePlainText(notesData, options);
          break;
        case ExportFormat.pdf:
          return await _generateMultiplePdf(notesData, options, customFileName);
        case ExportFormat.docx:
          content = await _generateMultipleHtml(notesData, options);
          break;
      }

      // Save to file
      final directory = await resolveTemporaryDirectory();
      final fileName =
          customFileName ??
          'duru_notes_export_${DateTime.now().millisecondsSinceEpoch}';
      final file = File(
        path.join(directory.path, '$fileName.${format.extension}'),
      );

      await file.writeAsString(content);

      // Track export
      await _trackExport(format, notes.length);

      _logger.info('[UnifiedExport] Batch export completed: ${file.path}');
      return file;
    } catch (e, stack) {
      _logger.error(
        '[UnifiedExport] Batch export failed',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Share exported file
  Future<void> shareExport(File file) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'Duru Notes Export'),
      );
      _logger.info('[UnifiedExport] Shared file: ${file.path}');
    } catch (e, stack) {
      _logger.error(
        '[UnifiedExport] Share failed',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Open exported file
  Future<void> openExport(File file) async {
    try {
      await OpenFile.open(file.path);
      _logger.info('[UnifiedExport] Opened file: ${file.path}');
    } catch (e, stack) {
      _logger.error('[UnifiedExport] Open failed', error: e, stackTrace: stack);
    }
  }

  // ========== PRIVATE HELPER METHODS ==========

  /// Extract note data from domain.Note
  Map<String, dynamic> _extractNoteData(domain.Note note) {
    return {
      'id': note.id,
      'title': note.title,
      'body': note.body,
      'isPinned': note.isPinned,
      'tags': note.tags,
      'folderId': note.folderId,
      'updatedAt': note.updatedAt,
      'version': note.version,
    };
  }

  /// Generate markdown content
  Future<String> _generateMarkdown(
    Map<String, dynamic> noteData,
    ExportOptions options,
  ) async {
    final buffer = StringBuffer();

    // Title
    buffer.writeln('# ${noteData['title']}');
    buffer.writeln();

    // Metadata
    if (options.includeMetadata) {
      if (options.includeTimestamps) {
        final updatedAt = noteData['updatedAt'] as DateTime;
        buffer.writeln('*Last updated: ${_formatDate(updatedAt)}*');
        buffer.writeln();
      }

      if (options.includeTags && (noteData['tags'] as List).isNotEmpty) {
        final tags = (noteData['tags'] as List).join(', ');
        buffer.writeln('**Tags:** $tags');
        buffer.writeln();
      }
    }

    // Body
    buffer.writeln(noteData['body']);

    return buffer.toString();
  }

  /// Generate HTML content
  Future<String> _generateHtml(
    Map<String, dynamic> noteData,
    ExportOptions options,
  ) async {
    final buffer = StringBuffer();

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html>');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln('<title>${noteData['title']}</title>');
    buffer.writeln(_getHtmlStyles());
    buffer.writeln('</head>');
    buffer.writeln('<body>');

    buffer.writeln('<h1>${noteData['title']}</h1>');

    if (options.includeMetadata && options.includeTimestamps) {
      final updatedAt = noteData['updatedAt'] as DateTime;
      buffer.writeln(
        '<p class="metadata">Last updated: ${_formatDate(updatedAt)}</p>',
      );
    }

    if (options.includeTags && (noteData['tags'] as List).isNotEmpty) {
      buffer.writeln('<p class="tags">');
      for (final tag in noteData['tags'] as List) {
        buffer.writeln('<span class="tag">$tag</span>');
      }
      buffer.writeln('</p>');
    }

    // Convert markdown to HTML (basic conversion)
    final htmlBody = _markdownToHtml(noteData['body'] as String);
    buffer.writeln(htmlBody);

    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  /// Generate plain text content
  Future<String> _generatePlainText(
    Map<String, dynamic> noteData,
    ExportOptions options,
  ) async {
    final buffer = StringBuffer();

    buffer.writeln(noteData['title']);
    buffer.writeln('=' * (noteData['title'] as String).length);
    buffer.writeln();

    if (options.includeMetadata && options.includeTimestamps) {
      final updatedAt = noteData['updatedAt'] as DateTime;
      buffer.writeln('Last updated: ${_formatDate(updatedAt)}');
      buffer.writeln();
    }

    buffer.writeln(noteData['body']);

    return buffer.toString();
  }

  /// Generate PDF content
  Future<File?> _generatePdf(
    Map<String, dynamic> noteData,
    ExportOptions options,
  ) async {
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.nunitoRegular();
      final boldFont = await PdfGoogleFonts.nunitoBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: options.pageSize,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                noteData['title'] as String,
                style: pw.TextStyle(font: boldFont, fontSize: 24),
              ),
            ),
            if (options.includeMetadata && options.includeTimestamps)
              pw.Text(
                'Last updated: ${_formatDate(noteData['updatedAt'] as DateTime)}',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: PdfColors.grey,
                ),
              ),
            pw.SizedBox(height: 20),
            pw.Text(
              noteData['body'] as String,
              style: pw.TextStyle(font: font, fontSize: 12),
            ),
          ],
        ),
      );

      final directory = await resolveTemporaryDirectory();
      final fileName = _sanitizeFileName(noteData['title'] as String);
      final file = File(path.join(directory.path, '$fileName.pdf'));

      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e, stack) {
      _logger.error(
        '[UnifiedExport] PDF generation failed',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Generate markdown for multiple notes
  Future<String> _generateMultipleMarkdown(
    List<Map<String, dynamic>> notesData,
    ExportOptions options,
  ) async {
    final buffer = StringBuffer();

    for (int i = 0; i < notesData.length; i++) {
      if (i > 0) buffer.writeln('\n---\n');
      buffer.writeln(await _generateMarkdown(notesData[i], options));
    }

    return buffer.toString();
  }

  /// Generate HTML for multiple notes
  Future<String> _generateMultipleHtml(
    List<Map<String, dynamic>> notesData,
    ExportOptions options,
  ) async {
    final buffer = StringBuffer();

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html>');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln('<title>Duru Notes Export</title>');
    buffer.writeln(_getHtmlStyles());
    buffer.writeln('</head>');
    buffer.writeln('<body>');

    for (int i = 0; i < notesData.length; i++) {
      if (i > 0) buffer.writeln('<hr>');

      final noteData = notesData[i];
      buffer.writeln('<div class="note">');
      buffer.writeln('<h1>${noteData['title']}</h1>');

      if (options.includeMetadata && options.includeTimestamps) {
        final updatedAt = noteData['updatedAt'] as DateTime;
        buffer.writeln(
          '<p class="metadata">Last updated: ${_formatDate(updatedAt)}</p>',
        );
      }

      final htmlBody = _markdownToHtml(noteData['body'] as String);
      buffer.writeln(htmlBody);
      buffer.writeln('</div>');
    }

    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  /// Generate plain text for multiple notes
  Future<String> _generateMultiplePlainText(
    List<Map<String, dynamic>> notesData,
    ExportOptions options,
  ) async {
    final buffer = StringBuffer();

    for (int i = 0; i < notesData.length; i++) {
      if (i > 0) buffer.writeln('\n${'=' * 50}\n');
      buffer.writeln(await _generatePlainText(notesData[i], options));
    }

    return buffer.toString();
  }

  /// Generate PDF for multiple notes
  Future<File?> _generateMultiplePdf(
    List<Map<String, dynamic>> notesData,
    ExportOptions options,
    String? customFileName,
  ) async {
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.nunitoRegular();
      final boldFont = await PdfGoogleFonts.nunitoBold();

      for (final noteData in notesData) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: options.pageSize,
            build: (context) => [
              pw.Header(
                level: 0,
                child: pw.Text(
                  noteData['title'] as String,
                  style: pw.TextStyle(font: boldFont, fontSize: 24),
                ),
              ),
              if (options.includeMetadata && options.includeTimestamps)
                pw.Text(
                  'Last updated: ${_formatDate(noteData['updatedAt'] as DateTime)}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
              pw.SizedBox(height: 20),
              pw.Text(
                noteData['body'] as String,
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
            ],
          ),
        );
      }

      final directory = await resolveTemporaryDirectory();
      final fileName =
          customFileName ??
          'duru_notes_export_${DateTime.now().millisecondsSinceEpoch}';
      final file = File(path.join(directory.path, '$fileName.pdf'));

      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e, stack) {
      _logger.error(
        '[UnifiedExport] Multi-PDF generation failed',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Basic markdown to HTML conversion
  String _markdownToHtml(String markdown) {
    // Very basic conversion - in production use a proper markdown parser
    return markdown
        .replaceAll('\n\n', '</p><p>')
        .replaceAll('\n', '<br>')
        .replaceAll('**', '<strong>')
        .replaceAll('*', '<em>')
        .replaceAll('# ', '<h1>')
        .replaceAll('## ', '<h2>')
        .replaceAll('### ', '<h3>');
  }

  /// Get HTML styles
  String _getHtmlStyles() {
    return '''
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 40px; line-height: 1.6; }
      h1 { color: #333; border-bottom: 2px solid #e0e0e0; padding-bottom: 10px; }
      .metadata { color: #666; font-size: 0.9em; font-style: italic; }
      .tags { margin: 10px 0; }
      .tag { display: inline-block; background: #f0f0f0; padding: 4px 8px; margin-right: 8px; border-radius: 4px; font-size: 0.85em; }
      .note { margin-bottom: 40px; }
      hr { border: none; border-top: 1px solid #e0e0e0; margin: 40px 0; }
    </style>
    ''';
  }

  /// Sanitize filename
  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .substring(0, name.length > 50 ? 50 : name.length);
  }

  /// Format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Track export analytics
  Future<void> _trackExport(ExportFormat format, int count) async {
    try {
      final analytics = ref.read(analyticsProvider);
      analytics.event(
        'note_exported',
        properties: {
          'format': format.displayName,
          'count': count,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      _logger.warning('[UnifiedExport] Failed to track export analytics');
    }
  }
}

/// Provider for unified export service
final unifiedExportServiceProvider = Provider<UnifiedExportService>((ref) {
  final notesRepo = ref.watch(notesCoreRepositoryProvider);
  final config = ref.watch(migrationConfigProvider);

  return UnifiedExportService(
    ref: ref,
    notesRepository: notesRepo,
    migrationConfig: config,
  );
});
