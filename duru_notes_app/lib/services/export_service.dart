import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/monitoring/app_logger.dart';
import '../core/parser/note_block_parser.dart';
import '../data/local/app_db.dart';
import '../models/note_block.dart';
import '../services/analytics/analytics_service.dart';
import '../services/attachment_service.dart';

/// Export formats supported by the service
enum ExportFormat {
  markdown('Markdown', 'md', 'text/markdown'),
  pdf('PDF', 'pdf', 'application/pdf'),
  html('HTML', 'html', 'text/html'),
  docx('Word Document', 'docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
  txt('Plain Text', 'txt', 'text/plain');

  const ExportFormat(this.displayName, this.extension, this.mimeType);
  
  final String displayName;
  final String extension;
  final String mimeType;
}

/// Export options for customizing output
class ExportOptions {
  final bool includeMetadata;
  final bool includeTimestamps;
  final bool includeAttachments;
  final bool includeTags;
  final bool includeBacklinks;
  final String? customTitle;
  final String? authorName;
  final PdfPageFormat? pageSize;
  final bool embedImages;
  final int? maxImageWidth;
  final String? watermarkText;

  const ExportOptions({
    this.includeMetadata = true,
    this.includeTimestamps = true,
    this.includeAttachments = true,
    this.includeTags = false,
    this.includeBacklinks = false,
    this.customTitle,
    this.authorName,
    this.pageSize = PdfPageFormat.a4,
    this.embedImages = true,
    this.maxImageWidth = 400,
    this.watermarkText,
  });
}

/// Progress callback for export operations
typedef ExportProgressCallback = void Function(ExportProgress progress);

/// Export progress information
class ExportProgress {
  final ExportPhase phase;
  final int current;
  final int total;
  final double percentage;
  final String? currentOperation;
  final String? estimatedTimeRemaining;

  const ExportProgress({
    required this.phase,
    required this.current,
    required this.total,
    this.currentOperation,
    this.estimatedTimeRemaining,
  }) : percentage = total > 0 ? (current / total) * 100 : 0;
}

/// Export phases
enum ExportPhase {
  preparing('Preparing export...'),
  parsing('Parsing content...'),
  processing('Processing blocks...'),
  rendering('Rendering document...'),
  embedding('Embedding attachments...'),
  finalizing('Finalizing export...'),
  saving('Saving file...'),
  completed('Export completed');

  const ExportPhase(this.description);
  final String description;
}

/// Export result with comprehensive information
class ExportResult {
  final bool success;
  final File? file;
  final String? error;
  final String? errorCode;
  final Duration processingTime;
  final int fileSize;
  final ExportFormat format;
  final Map<String, dynamic> metadata;

  const ExportResult({
    required this.success,
    this.file,
    this.error,
    this.errorCode,
    required this.processingTime,
    this.fileSize = 0,
    required this.format,
    this.metadata = const {},
  });

  factory ExportResult.success({
    required File file,
    required Duration processingTime,
    required ExportFormat format,
    Map<String, dynamic> metadata = const {},
  }) {
    return ExportResult(
      success: true,
      file: file,
      processingTime: processingTime,
      fileSize: file.existsSync() ? file.lengthSync() : 0,
      format: format,
      metadata: metadata,
    );
  }

  factory ExportResult.failure({
    required String error,
    String? errorCode,
    required Duration processingTime,
    required ExportFormat format,
  }) {
    return ExportResult(
      success: false,
      error: error,
      errorCode: errorCode,
      processingTime: processingTime,
      format: format,
    );
  }
}

/// World-class export service with comprehensive format support
class ExportService {
  final AppLogger _logger;
  final AnalyticsService _analytics;
  final AttachmentService _attachmentService;

  // Configuration constants
  static const int _maxFileSize = 500 * 1024 * 1024; // 500MB limit
  static const Duration _operationTimeout = Duration(minutes: 15);
  static const int _maxImageSize = 10 * 1024 * 1024; // 10MB per image
  static const double _defaultFontSize = 12;
  static const double _titleFontSize = 24;
  static const double _headingFontSize = 18;

  ExportService({
    AppLogger? logger,
    AnalyticsService? analytics,
    AttachmentService? attachmentService,
  })  : _logger = logger ?? LoggerFactory.instance,
        _analytics = analytics ?? AnalyticsFactory.instance,
        _attachmentService = attachmentService ?? AttachmentService();

  /// Export a note to Markdown format
  Future<ExportResult> exportToMarkdown(
    LocalNote note, {
    ExportOptions options = const ExportOptions(),
    ExportProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      _logger.info('Starting Markdown export', data: {
        'note_id': note.id,
        'note_title': note.title,
      });

      _analytics.startTiming('export_markdown');
      
      onProgress?.call(const ExportProgress(
        phase: ExportPhase.preparing,
        current: 0,
        total: 100,
        currentOperation: 'Preparing markdown export...',
      ));

      // Parse note content to blocks
      onProgress?.call(const ExportProgress(
        phase: ExportPhase.parsing,
        current: 20,
        total: 100,
        currentOperation: 'Parsing note content...',
      ));
      
      final blocks = parseMarkdownToBlocks(note.body);
      
      // Build markdown content
      onProgress?.call(const ExportProgress(
        phase: ExportPhase.processing,
        current: 40,
        total: 100,
        currentOperation: 'Processing blocks...',
      ));
      
      final markdownContent = await _buildMarkdownContent(note, blocks, options);
      
      // Save to file
      onProgress?.call(const ExportProgress(
        phase: ExportPhase.saving,
        current: 80,
        total: 100,
        currentOperation: 'Saving file...',
      ));
      
      final file = await _saveToFile(
        content: markdownContent,
        filename: _generateFilename(note.title, ExportFormat.markdown),
        format: ExportFormat.markdown,
      );

      onProgress?.call(const ExportProgress(
        phase: ExportPhase.completed,
        current: 100,
        total: 100,
        currentOperation: 'Export completed',
      ));

      final result = ExportResult.success(
        file: file,
        processingTime: stopwatch.elapsed,
        format: ExportFormat.markdown,
        metadata: {
          'blocks_count': blocks.length,
          'content_length': markdownContent.length,
          'include_metadata': options.includeMetadata,
        },
      );

      _analytics.endTiming('export_markdown', properties: {
        'success': true,
        'file_size': result.fileSize,
        'processing_time_ms': stopwatch.elapsedMilliseconds,
      });

      _analytics.featureUsed('note_exported', properties: {
        'format': 'markdown',
        'blocks_count': blocks.length,
      });

      return result;
    } catch (e, stackTrace) {
      _logger.error('Markdown export failed', error: e, stackTrace: stackTrace, data: {
        'note_id': note.id,
      });

      _analytics.endTiming('export_markdown', properties: {
        'success': false,
        'error': e.toString(),
      });

      return ExportResult.failure(
        error: 'Failed to export to Markdown: ${e.toString()}',
        errorCode: 'MARKDOWN_EXPORT_FAILED',
        processingTime: stopwatch.elapsed,
        format: ExportFormat.markdown,
      );
    }
  }

  /// Export a note to PDF format with rich formatting
  Future<ExportResult> exportToPdf(
    LocalNote note, {
    ExportOptions options = const ExportOptions(),
    ExportProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      _logger.info('Starting PDF export', data: {
        'note_id': note.id,
        'note_title': note.title,
      });

      _analytics.startTiming('export_pdf');
      
      onProgress?.call(const ExportProgress(
        phase: ExportPhase.preparing,
        current: 0,
        total: 100,
        currentOperation: 'Preparing PDF export...',
      ));

      // Parse note content to blocks
      onProgress?.call(const ExportProgress(
        phase: ExportPhase.parsing,
        current: 10,
        total: 100,
        currentOperation: 'Parsing note content...',
      ));
      
      final blocks = parseMarkdownToBlocks(note.body);
      
      // Create PDF document
      onProgress?.call(const ExportProgress(
        phase: ExportPhase.rendering,
        current: 30,
        total: 100,
        currentOperation: 'Creating PDF document...',
      ));
      
      final pdf = pw.Document();
      
      // Load fonts
      final fontRegular = await PdfGoogleFonts.openSansRegular();
      final fontBold = await PdfGoogleFonts.openSansBold();
      final fontItalic = await PdfGoogleFonts.openSansItalic();
      final fontMono = await PdfGoogleFonts.robotoMonoRegular();

      // Build PDF content
      onProgress?.call(const ExportProgress(
        phase: ExportPhase.processing,
        current: 50,
        total: 100,
        currentOperation: 'Processing blocks...',
      ));
      
      final pdfWidgets = await _buildPdfContent(
        note, 
        blocks, 
        options,
        fontRegular: fontRegular,
        fontBold: fontBold,
        fontItalic: fontItalic,
        fontMono: fontMono,
        onProgress: (progress) {
          onProgress?.call(ExportProgress(
            phase: ExportPhase.processing,
            current: 50 + (progress * 20).round(),
            total: 100,
            currentOperation: 'Processing block ${progress * blocks.length}/${blocks.length}...',
          ));
        },
      );

      // Add pages to PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: options.pageSize ?? PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => pdfWidgets,
          header: options.includeMetadata ? (context) => _buildPdfHeader(note, options) : null,
          footer: options.includeMetadata ? (context) => _buildPdfFooter(context) : null,
        ),
      );

      // Save PDF
      onProgress?.call(const ExportProgress(
        phase: ExportPhase.saving,
        current: 90,
        total: 100,
        currentOperation: 'Saving PDF file...',
      ));
      
      final pdfBytes = await pdf.save();
      final file = await _saveBytesToFile(
        bytes: pdfBytes,
        filename: _generateFilename(note.title, ExportFormat.pdf),
        format: ExportFormat.pdf,
      );

      onProgress?.call(const ExportProgress(
        phase: ExportPhase.completed,
        current: 100,
        total: 100,
        currentOperation: 'PDF export completed',
      ));

      final result = ExportResult.success(
        file: file,
        processingTime: stopwatch.elapsed,
        format: ExportFormat.pdf,
        metadata: {
          'blocks_count': blocks.length,
          'pages_count': 1, // Estimate
          'file_size': pdfBytes.length,
        },
      );

      _analytics.endTiming('export_pdf', properties: {
        'success': true,
        'file_size': result.fileSize,
        'processing_time_ms': stopwatch.elapsedMilliseconds,
        'pages_count': 1, // Estimate
      });

      _analytics.featureUsed('note_exported', properties: {
        'format': 'pdf',
        'blocks_count': blocks.length,
      });

      return result;
    } catch (e, stackTrace) {
      _logger.error('PDF export failed', error: e, stackTrace: stackTrace, data: {
        'note_id': note.id,
      });

      _analytics.endTiming('export_pdf', properties: {
        'success': false,
        'error': e.toString(),
      });

      return ExportResult.failure(
        error: 'Failed to export to PDF: ${e.toString()}',
        errorCode: 'PDF_EXPORT_FAILED',
        processingTime: stopwatch.elapsed,
        format: ExportFormat.pdf,
      );
    }
  }

  /// Export a note to HTML format
  Future<ExportResult> exportToHtml(
    LocalNote note, {
    ExportOptions options = const ExportOptions(),
    ExportProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      _analytics.startTiming('export_html');
      
      onProgress?.call(const ExportProgress(
        phase: ExportPhase.preparing,
        current: 0,
        total: 100,
        currentOperation: 'Preparing HTML export...',
      ));

      final blocks = parseMarkdownToBlocks(note.body);
      
      onProgress?.call(const ExportProgress(
        phase: ExportPhase.processing,
        current: 50,
        total: 100,
        currentOperation: 'Building HTML content...',
      ));
      
      final htmlContent = await _buildHtmlContent(note, blocks, options);
      
      onProgress?.call(const ExportProgress(
        phase: ExportPhase.saving,
        current: 90,
        total: 100,
        currentOperation: 'Saving HTML file...',
      ));
      
      final file = await _saveToFile(
        content: htmlContent,
        filename: _generateFilename(note.title, ExportFormat.html),
        format: ExportFormat.html,
      );

      final result = ExportResult.success(
        file: file,
        processingTime: stopwatch.elapsed,
        format: ExportFormat.html,
      );

      _analytics.endTiming('export_html', properties: {
        'success': true,
        'file_size': result.fileSize,
      });

      return result;
    } catch (e) {
      _analytics.endTiming('export_html', properties: {
        'success': false,
        'error': e.toString(),
      });

      return ExportResult.failure(
        error: 'Failed to export to HTML: ${e.toString()}',
        errorCode: 'HTML_EXPORT_FAILED',
        processingTime: stopwatch.elapsed,
        format: ExportFormat.html,
      );
    }
  }

  /// Share exported file using platform sharing
  Future<bool> shareExportedFile(File file, ExportFormat format) async {
    try {
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Shared from Duru Notes',
        subject: 'Note Export - ${path.basenameWithoutExtension(file.path)}',
      );
      
      _analytics.featureUsed('export_shared', properties: {
        'format': format.name,
        'file_size': file.lengthSync(),
      });
      
      return result.status == ShareResultStatus.success;
    } catch (e) {
      _logger.error('Failed to share exported file', error: e);
      return false;
    }
  }

  /// Open exported file with system default app
  Future<bool> openExportedFile(File file) async {
    try {
      final result = await OpenFile.open(file.path);
      
      _analytics.featureUsed('export_opened', properties: {
        'file_size': file.lengthSync(),
      });
      
      return result.type == ResultType.done;
    } catch (e) {
      _logger.error('Failed to open exported file', error: e);
      return false;
    }
  }

  /// Get estimated export time based on content size
  Duration getEstimatedExportTime(LocalNote note, ExportFormat format) {
    final contentLength = note.body.length;
    final blocks = parseMarkdownToBlocks(note.body);
    
    // Base time calculations
    int baseSeconds = 1;
    
    switch (format) {
      case ExportFormat.markdown:
      case ExportFormat.txt:
        baseSeconds = 1;
        break;
      case ExportFormat.html:
        baseSeconds = 2;
        break;
      case ExportFormat.pdf:
        baseSeconds = 5;
        break;
      case ExportFormat.docx:
        baseSeconds = 8;
        break;
    }
    
    // Add time based on content size
    final sizeMultiplier = (contentLength / 1000).ceil();
    final blockMultiplier = (blocks.length / 10).ceil();
    
    final totalSeconds = baseSeconds + sizeMultiplier + blockMultiplier;
    return Duration(seconds: totalSeconds.clamp(1, 60));
  }

  // Private helper methods

  String _generateFilename(String title, ExportFormat format) {
    // Sanitize title for filename
    final sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final filename = sanitizedTitle.isNotEmpty ? sanitizedTitle : 'note';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    return '${filename}_$timestamp.${format.extension}';
  }

  Future<String> _buildMarkdownContent(
    LocalNote note, 
    List<NoteBlock> blocks, 
    ExportOptions options,
  ) async {
    final buffer = StringBuffer();
    
    // Add title
    if (note.title.isNotEmpty) {
      buffer.writeln('# ${note.title}');
      buffer.writeln();
    }
    
    // Add metadata if requested
    if (options.includeMetadata) {
      buffer.writeln('---');
      if (options.includeTimestamps) {
        buffer.writeln('Created: ${_formatDate(note.updatedAt)}');
        buffer.writeln('Updated: ${_formatDate(note.updatedAt)}');
      }
      if (options.authorName != null) {
        buffer.writeln('Author: ${options.authorName}');
      }
      buffer.writeln('Exported: ${_formatDate(DateTime.now())}');
      buffer.writeln('---');
      buffer.writeln();
    }
    
    // Convert blocks back to markdown
    final markdownBody = blocksToMarkdown(blocks);
    buffer.write(markdownBody);
    
    return buffer.toString();
  }

  Future<List<pw.Widget>> _buildPdfContent(
    LocalNote note,
    List<NoteBlock> blocks,
    ExportOptions options, {
    required pw.Font fontRegular,
    required pw.Font fontBold,
    required pw.Font fontItalic,
    required pw.Font fontMono,
    Function(double)? onProgress,
  }) async {
    final widgets = <pw.Widget>[];
    
    // Add title
    if (note.title.isNotEmpty) {
      widgets.add(
        pw.Text(
          note.title,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: _titleFontSize,
            color: PdfColors.black,
          ),
        ),
      );
      widgets.add(pw.SizedBox(height: 20));
    }
    
    // Add metadata if requested
    if (options.includeMetadata) {
      widgets.add(_buildPdfMetadata(note, options, fontRegular));
      widgets.add(pw.SizedBox(height: 20));
    }
    
    // Process blocks
    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      onProgress?.call(i / blocks.length);
      
      final widget = await _buildPdfBlock(
        block,
        fontRegular: fontRegular,
        fontBold: fontBold,
        fontItalic: fontItalic,
        fontMono: fontMono,
      );
      
      if (widget != null) {
        widgets.add(widget);
        widgets.add(pw.SizedBox(height: 8));
      }
    }
    
    return widgets;
  }

  pw.Widget _buildPdfMetadata(LocalNote note, ExportOptions options, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (options.includeTimestamps) ...[
            pw.Text('Created: ${_formatDate(note.updatedAt ?? DateTime.now())}', style: pw.TextStyle(font: font, fontSize: 10)),
            pw.Text('Updated: ${_formatDate(note.updatedAt)}', style: pw.TextStyle(font: font, fontSize: 10)),
          ],
          if (options.authorName != null)
            pw.Text('Author: ${options.authorName}', style: pw.TextStyle(font: font, fontSize: 10)),
          pw.Text('Exported: ${_formatDate(DateTime.now())}', style: pw.TextStyle(font: font, fontSize: 10)),
        ],
      ),
    );
  }

  pw.Widget _buildPdfHeader(LocalNote note, ExportOptions options) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Text(
        'Duru Notes',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
      ),
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
      ),
    );
  }

  Future<pw.Widget?> _buildPdfBlock(
    NoteBlock block, {
    required pw.Font fontRegular,
    required pw.Font fontBold,
    required pw.Font fontItalic,
    required pw.Font fontMono,
  }) async {
    switch (block.type) {
      case NoteBlockType.paragraph:
        return pw.Text(
          block.data,
          style: pw.TextStyle(font: fontRegular, fontSize: _defaultFontSize),
        );
        
      case NoteBlockType.heading1:
        return pw.Text(
          block.data,
          style: pw.TextStyle(font: fontBold, fontSize: _headingFontSize),
        );
        
      case NoteBlockType.heading2:
        return pw.Text(
          block.data,
          style: pw.TextStyle(font: fontBold, fontSize: _headingFontSize - 2),
        );
        
      case NoteBlockType.heading3:
        return pw.Text(
          block.data,
          style: pw.TextStyle(font: fontBold, fontSize: _headingFontSize - 4),
        );
        
      case NoteBlockType.code:
        return pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Text(
            block.data,
            style: pw.TextStyle(font: fontMono, fontSize: _defaultFontSize - 1),
          ),
        );
        
      case NoteBlockType.quote:
        return pw.Container(
          padding: const pw.EdgeInsets.only(left: 16, top: 8, bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: PdfColors.blue, width: 4),
            ),
          ),
          child: pw.Text(
            block.data,
            style: pw.TextStyle(font: fontItalic, fontSize: _defaultFontSize),
          ),
        );
        
      case NoteBlockType.bulletList:
        return pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('• ', style: pw.TextStyle(font: fontRegular)),
            pw.Expanded(
              child: pw.Text(
                block.data,
                style: pw.TextStyle(font: fontRegular, fontSize: _defaultFontSize),
              ),
            ),
          ],
        );
        
      case NoteBlockType.numberedList:
        return pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('1. ', style: pw.TextStyle(font: fontRegular)),
            pw.Expanded(
              child: pw.Text(
                block.data,
                style: pw.TextStyle(font: fontRegular, fontSize: _defaultFontSize),
              ),
            ),
          ],
        );
        
      case NoteBlockType.todo:
        final parts = block.data.split(':');
        final isCompleted = parts.length > 1 && parts[0] == 'completed';
        final text = parts.length > 1 ? parts.skip(1).join(':') : block.data;
        
        return pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 12,
              height: 12,
              margin: const pw.EdgeInsets.only(right: 8, top: 2),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                color: isCompleted ? PdfColors.green : null,
              ),
              child: isCompleted
                  ? pw.Center(
                      child: pw.Text(
                        '✓',
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.white),
                      ),
                    )
                  : null,
            ),
            pw.Expanded(
              child: pw.Text(
                text,
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: _defaultFontSize,
                  decoration: isCompleted ? pw.TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        );
        
      default:
        return pw.Text(
          block.data,
          style: pw.TextStyle(font: fontRegular, fontSize: _defaultFontSize),
        );
    }
  }

  Future<String> _buildHtmlContent(
    LocalNote note, 
    List<NoteBlock> blocks, 
    ExportOptions options,
  ) async {
    final buffer = StringBuffer();
    
    // HTML header
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en">');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer.writeln('<title>${_escapeHtml(note.title.isNotEmpty ? note.title : 'Note')}</title>');
    buffer.writeln('<style>');
    buffer.writeln(_getHtmlStyles());
    buffer.writeln('</style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    
    // Content
    if (note.title.isNotEmpty) {
      buffer.writeln('<h1>${_escapeHtml(note.title)}</h1>');
    }
    
    if (options.includeMetadata) {
      buffer.writeln('<div class="metadata">');
      if (options.includeTimestamps) {
        buffer.writeln('<p><strong>Created:</strong> ${_formatDate(note.updatedAt ?? DateTime.now())}</p>');
        buffer.writeln('<p><strong>Updated:</strong> ${_formatDate(note.updatedAt)}</p>');
      }
      buffer.writeln('<p><strong>Exported:</strong> ${_formatDate(DateTime.now())}</p>');
      buffer.writeln('</div>');
    }
    
    // Convert blocks to HTML
    for (final block in blocks) {
      buffer.writeln(_blockToHtml(block));
    }
    
    buffer.writeln('</body>');
    buffer.writeln('</html>');
    
    return buffer.toString();
  }

  String _blockToHtml(NoteBlock block) {
    final escapedData = _escapeHtml(block.data);
    
    switch (block.type) {
      case NoteBlockType.paragraph:
        return '<p>$escapedData</p>';
      case NoteBlockType.heading1:
        return '<h1>$escapedData</h1>';
      case NoteBlockType.heading2:
        return '<h2>$escapedData</h2>';
      case NoteBlockType.heading3:
        return '<h3>$escapedData</h3>';
      case NoteBlockType.code:
        return '<pre><code>$escapedData</code></pre>';
      case NoteBlockType.quote:
        return '<blockquote>$escapedData</blockquote>';
      case NoteBlockType.bulletList:
        return '<ul><li>$escapedData</li></ul>';
      case NoteBlockType.numberedList:
        return '<ol><li>$escapedData</li></ol>';
      case NoteBlockType.todo:
        final parts = block.data.split(':');
        final isCompleted = parts.length > 1 && parts[0] == 'completed';
        final text = parts.length > 1 ? parts.skip(1).join(':') : block.data;
        final checked = isCompleted ? 'checked' : '';
        return '<div class="todo"><input type="checkbox" $checked disabled> ${_escapeHtml(text)}</div>';
      default:
        return '<p>$escapedData</p>';
    }
  }

  String _getHtmlStyles() {
    return '''
      body { 
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        line-height: 1.6;
        max-width: 800px;
        margin: 0 auto;
        padding: 40px 20px;
        color: #333;
      }
      .metadata {
        background: #f5f5f5;
        padding: 15px;
        border-radius: 5px;
        margin: 20px 0;
        font-size: 0.9em;
      }
      .metadata p { margin: 5px 0; }
      h1, h2, h3 { color: #2c3e50; }
      code { 
        background: #f8f9fa;
        padding: 2px 4px;
        border-radius: 3px;
        font-family: 'Monaco', 'Consolas', monospace;
      }
      pre {
        background: #f8f9fa;
        padding: 15px;
        border-radius: 5px;
        overflow-x: auto;
      }
      blockquote {
        border-left: 4px solid #3498db;
        margin: 0;
        padding-left: 20px;
        font-style: italic;
        color: #666;
      }
      .todo {
        margin: 5px 0;
      }
      .todo input {
        margin-right: 8px;
      }
    ''';
  }

  Future<File> _saveToFile({
    required String content,
    required String filename,
    required ExportFormat format,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(path.join(directory.path, 'exports', filename));
    
    // Ensure exports directory exists
    await file.parent.create(recursive: true);
    
    await file.writeAsString(content, encoding: utf8);
    return file;
  }

  Future<File> _saveBytesToFile({
    required Uint8List bytes,
    required String filename,
    required ExportFormat format,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(path.join(directory.path, 'exports', filename));
    
    // Ensure exports directory exists
    await file.parent.create(recursive: true);
    
    await file.writeAsBytes(bytes);
    return file;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }
}
