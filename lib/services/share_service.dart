// lib/services/share_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../data/local/app_db.dart';
import '../core/monitoring/app_logger.dart';
import 'analytics/analytics_service.dart';

/// Share formats supported by the app
enum ShareFormat { plainText, markdown, html, json }

/// Share options for customizing the sharing experience
class ShareOptions {
  final ShareFormat format;
  final bool includeTitle;
  final bool includeMetadata;
  final String? customSubject;

  const ShareOptions({
    this.format = ShareFormat.markdown,
    this.includeTitle = true,
    this.includeMetadata = false,
    this.customSubject,
  });
}

/// Service for sharing notes via various methods
class ShareService {
  ShareService({
    AppLogger? logger,
    AnalyticsService? analytics,
  })  : _logger = logger ?? LoggerFactory.instance,
        _analytics = analytics ?? AnalyticsFactory.instance;

  final AppLogger _logger;
  final AnalyticsService _analytics;

  /// Share a single note
  Future<bool> shareNote(
    LocalNote note, {
    ShareOptions options = const ShareOptions(),
  }) async {
    try {
      _analytics.startTiming('share_note');

      final content = _formatNoteContent(note, options);
      final subject = options.customSubject ??
          (note.title.isNotEmpty ? note.title : 'Shared Note');

      if (await _canUseNativeShare()) {
        await _shareViaNativeShare(content, subject);
      } else {
        await _shareViaClipboard(content);
      }

      _analytics.endTiming('share_note', properties: {
        'success': true,
        'format': options.format.name,
        'include_title': options.includeTitle,
        'include_metadata': options.includeMetadata,
      });

      _analytics.featureUsed('note_shared', properties: {
        'format': options.format.name,
        'method': await _canUseNativeShare() ? 'native' : 'clipboard',
      });

      _logger.info('Note shared successfully', data: {
        'note_id': note.id,
        'format': options.format.name,
      });

      return true;
    } catch (e) {
      _logger.error('Failed to share note', error: e, data: {'note_id': note.id});
      _analytics.endTiming('share_note',
          properties: {'success': false, 'error': e.toString()});
      return false;
    }
  }

  /// Share multiple notes
  Future<bool> shareNotes(
    List<LocalNote> notes, {
    ShareOptions options = const ShareOptions(),
    String? collectionTitle,
  }) async {
    try {
      _analytics.startTiming('share_multiple_notes');

      final content =
          _formatMultipleNotesContent(notes, options, collectionTitle);
      final subject = collectionTitle ?? 'Shared Notes (${notes.length})';

      if (await _canUseNativeShare()) {
        await _shareViaNativeShare(content, subject);
      } else {
        await _shareViaClipboard(content);
      }

      _analytics.endTiming('share_multiple_notes', properties: {
        'success': true,
        'note_count': notes.length,
        'format': options.format.name,
      });

      _analytics.featureUsed('multiple_notes_shared', properties: {
        'count': notes.length,
        'format': options.format.name,
      });

      _logger.info('Multiple notes shared successfully',
          data: {'note_count': notes.length, 'format': options.format.name});

      return true;
    } catch (e) {
      _logger.error('Failed to share multiple notes',
          error: e, data: {'note_count': notes.length});
      _analytics.endTiming('share_multiple_notes',
          properties: {'success': false, 'error': e.toString()});
      return false;
    }
  }

  /// Export note as file
  Future<String?> exportNoteAsFile(
    LocalNote note, {
    ShareFormat format = ShareFormat.markdown,
    String? directory,
  }) async {
    try {
      _analytics.startTiming('export_note_file');

      final content = _formatNoteContent(note, ShareOptions(format: format));
      final fileName = _generateFileName(note, format);

      final dir = directory != null
          ? Directory(directory)
          : await getApplicationDocumentsDirectory();

      final file = File(path.join(dir.path, fileName));
      await file.writeAsString(content);

      _analytics.endTiming('export_note_file', properties: {
        'success': true,
        'format': format.name,
        'file_size': content.length,
      });

      _analytics.featureUsed('note_exported_as_file',
          properties: {'format': format.name});

      _logger.info('Note exported as file',
          data: {'note_id': note.id, 'file_path': file.path, 'format': format.name});

      return file.path;
    } catch (e) {
      _logger.error('Failed to export note as file',
          error: e, data: {'note_id': note.id});
      _analytics.endTiming('export_note_file',
          properties: {'success': false, 'error': e.toString()});
      return null;
    }
  }

  /// Copy note to clipboard
  Future<bool> copyToClipboard(
    LocalNote note, {
    ShareOptions options = const ShareOptions(),
  }) async {
    try {
      final content = _formatNoteContent(note, options);
      await _shareViaClipboard(content);

      _analytics.featureUsed('note_copied_to_clipboard',
          properties: {'format': options.format.name});
      return true;
    } catch (e) {
      _logger.error('Failed to copy note to clipboard', error: e);
      return false;
    }
  }

  // ---------- Formatting helpers ----------

  String _formatNoteContent(LocalNote note, ShareOptions options) {
    switch (options.format) {
      case ShareFormat.plainText:
        return _formatAsPlainText(note, options);
      case ShareFormat.markdown:
        return _formatAsMarkdown(note, options);
      case ShareFormat.html:
        return _formatAsHtml(note, options);
      case ShareFormat.json:
        return _formatAsJson(note, options);
    }
  }

  String _formatAsPlainText(LocalNote note, ShareOptions options) {
    final buffer = StringBuffer();
    if (options.includeTitle && note.title.isNotEmpty) {
      buffer.writeln(note.title);
      buffer.writeln('=' * note.title.length);
      buffer.writeln();
    }
    buffer.writeln(note.body);
    if (options.includeMetadata) {
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln('Created: ${_formatDate(note.updatedAt)}');
      buffer.writeln('Updated: ${_formatDate(note.updatedAt)}');
    }
    return buffer.toString().trim();
  }

  String _formatAsMarkdown(LocalNote note, ShareOptions options) {
    final buffer = StringBuffer();
    if (options.includeTitle && note.title.isNotEmpty) {
      buffer.writeln('# ${note.title}');
      buffer.writeln();
    }
    buffer.writeln(note.body);
    if (options.includeMetadata) {
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln('**Created:** ${_formatDate(note.updatedAt)}');
      buffer.writeln('**Updated:** ${_formatDate(note.updatedAt)}');
    }
    return buffer.toString().trim();
  }

  String _formatAsHtml(LocalNote note, ShareOptions options) {
    final buffer = StringBuffer();
    buffer
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html>')
      ..writeln('<head>')
      ..writeln('<meta charset="UTF-8">');
    if (note.title.isNotEmpty) {
      buffer.writeln('<title>${_escapeHtml(note.title)}</title>');
    }
    buffer
      ..writeln('<style>')
      ..writeln(
          'body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 40px; }')
      ..writeln('pre { background: #f5f5f5; padding: 16px; border-radius: 8px; }')
      ..writeln('</style>')
      ..writeln('</head>')
      ..writeln('<body>');
    if (options.includeTitle && note.title.isNotEmpty) {
      buffer.writeln('<h1>${_escapeHtml(note.title)}</h1>');
    }
    final htmlBody = _simpleMarkdownToHtml(note.body);
    buffer.writeln(htmlBody);
    if (options.includeMetadata) {
      buffer
        ..writeln('<hr>')
        ..writeln('<p><small>')
        ..writeln('<strong>Created:</strong> ${_formatDate(note.updatedAt)}<br>')
        ..writeln('<strong>Updated:</strong> ${_formatDate(note.updatedAt)}')
        ..writeln('</small></p>');
    }
    buffer
      ..writeln('</body>')
      ..writeln('</html>');
    return buffer.toString();
  }

  String _formatAsJson(LocalNote note, ShareOptions options) {
    final data = <String, dynamic>{
      'title': note.title,
      'body': note.body,
    };
    if (options.includeMetadata) {
      data['created_at'] = note.updatedAt.toIso8601String();
      data['updated_at'] = note.updatedAt.toIso8601String();
      data['id'] = note.id;
    }
    return data.entries
        .map((e) => '"${e.key}": "${_escapeJson(e.value.toString())}"')
        .join(',\n  ');
  }

  String _formatMultipleNotesContent(
    List<LocalNote> notes,
    ShareOptions options,
    String? collectionTitle,
  ) {
    final buffer = StringBuffer();
    if (collectionTitle != null && collectionTitle.isNotEmpty) {
      switch (options.format) {
        case ShareFormat.markdown:
          buffer.writeln('# $collectionTitle\n');
          break;
        case ShareFormat.html:
          buffer.writeln('<h1>${_escapeHtml(collectionTitle)}</h1>');
          break;
        default:
          buffer
            ..writeln(collectionTitle)
            ..writeln('=' * collectionTitle.length)
            ..writeln();
      }
    }
    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      if (i > 0) {
        buffer.writeln();
        buffer.writeln(options.format == ShareFormat.html ? '<hr>' : '---');
        buffer.writeln();
      }
      buffer.writeln(_formatNoteContent(note, options));
    }
    return buffer.toString();
  }

  // ---------- Sharing helpers ----------

  Future<bool> _canUseNativeShare() async =>
      Platform.isAndroid || Platform.isIOS;

  Future<void> _shareViaNativeShare(String content, String subject) async {
    // In production, integrate share_plus here
    await _shareViaClipboard(content);
  }

  Future<void> _shareViaClipboard(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
  }

  String _generateFileName(LocalNote note, ShareFormat format) {
    final title = note.title.isNotEmpty
        ? note.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim()
        : 'Note_${note.id}';
    final ext = _getFileExtension(format);
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${title}_$ts.$ext';
  }

  String _getFileExtension(ShareFormat format) {
    switch (format) {
      case ShareFormat.plainText:
        return 'txt';
      case ShareFormat.markdown:
        return 'md';
      case ShareFormat.html:
        return 'html';
      case ShareFormat.json:
        return 'json';
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  String _escapeHtml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String _escapeJson(String text) => text
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t');

  String _simpleMarkdownToHtml(String markdown) {
    var html = _escapeHtml(markdown);
    html = html.replaceAllMapped(RegExp(r'^### (.+)$', multiLine: true),
        (m) => '<h3>${m.group(1)}</h3>');
    html = html.replaceAllMapped(RegExp(r'^## (.+)$', multiLine: true),
        (m) => '<h2>${m.group(1)}</h2>');
    html = html.replaceAllMapped(RegExp(r'^# (.+)$', multiLine: true),
        (m) => '<h1>${m.group(1)}</h1>');
    html = html.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'),
        (m) => '<strong>${m.group(1)}</strong>');
    html = html.replaceAllMapped(RegExp(r'\*(.+?)\*'),
        (m) => '<em>${m.group(1)}</em>');
    html = html.replaceAllMapped(RegExp(r'`(.+?)`'),
        (m) => '<code>${m.group(1)}</code>');
    html = html.replaceAll('\n', '<br>\n');
    return html;
  }

  static String getShareFormatDisplayName(ShareFormat format) {
    switch (format) {
      case ShareFormat.plainText:
        return 'Plain Text';
      case ShareFormat.markdown:
        return 'Markdown';
      case ShareFormat.html:
        return 'HTML';
      case ShareFormat.json:
        return 'JSON';
    }
  }
}
