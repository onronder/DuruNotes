import 'dart:async';
import 'dart:convert';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final AppLogger _logger = LoggerFactory.instance;

/// Widget that displays an icon indicating the source of a note
class NoteSourceIcon extends StatelessWidget {
  const NoteSourceIcon({
    required this.note,
    super.key,
    this.size = 16,
    this.color,
  });
  final domain.Note note;
  final double size;
  final Color? color;

  Map<String, dynamic>? _decodeJsonMap(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to decode note metadata JSON for source icon',
        data: {'noteId': note.id, 'error': error.toString()},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
    }
    return null;
  }

  bool _hasAttachments(dynamic attachments) {
    if (attachments is List) {
      return attachments.isNotEmpty;
    }
    if (attachments is Map<String, dynamic>) {
      final files = attachments['files'];
      if (files is List && files.isNotEmpty) return true;
    }
    return false;
  }

  bool _hasAttachmentMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return false;
    final attachments = metadata['attachments'];
    if (_hasAttachments(attachments)) return true;
    return false;
  }

  bool _hasAttachmentFromNote(
    domain.Note note,
    Map<String, dynamic>? metadata,
  ) {
    if (_hasAttachmentMetadata(metadata)) return true;

    final attachmentMeta = _decodeJsonMap(note.attachmentMeta);
    return _hasAttachmentMetadata(attachmentMeta);
  }

  /// Determines the source type of the note
  NoteSourceType _getNoteSourceType() {
    // Prefer decrypted metadata when available, fall back to legacy field.
    final metadata =
        _decodeJsonMap(note.metadata) ?? _decodeJsonMap(note.encryptedMetadata);
    final source = (metadata?['source'] as String?)?.toLowerCase().trim();
    final tags = note.tags.map((tag) => tag.toLowerCase()).toSet();
    final hasAttachments = _hasAttachmentFromNote(note, metadata);

    bool looksLikeEmail() =>
        source == 'email_in' ||
        source == 'email_inbox' ||
        source == 'email' ||
        tags.contains('email') ||
        metadata?.containsKey('original_id') == true ||
        metadata?.containsKey('message_id') == true ||
        metadata?.containsKey('from') == true;
    bool looksLikeWeb() =>
        source == 'web' ||
        source == 'webclipper' ||
        tags.contains('web') ||
        tags.contains('webclipper') ||
        metadata?.containsKey('web_url') == true ||
        metadata?.containsKey('url') == true;

    if (looksLikeEmail()) {
      return hasAttachments
          ? NoteSourceType.emailWithAttachment
          : NoteSourceType.email;
    }

    if (looksLikeWeb()) {
      return NoteSourceType.web;
    }

    if (hasAttachments || tags.contains('attachment')) {
      return NoteSourceType.attachment;
    }

    // Default to regular note
    return NoteSourceType.regular;
  }

  @override
  Widget build(BuildContext context) {
    final sourceType = _getNoteSourceType();
    final theme = Theme.of(context);
    final iconColor =
        color ?? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    Widget icon;
    String tooltip;

    switch (sourceType) {
      case NoteSourceType.email:
        icon = Icon(Icons.email_outlined, size: size, color: iconColor);
        tooltip = 'From Email';
        break;
      case NoteSourceType.emailWithAttachment:
        icon = Stack(
          children: [
            Icon(Icons.email_outlined, size: size, color: iconColor),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.attach_file,
                  size: size * 0.6,
                  color: iconColor,
                ),
              ),
            ),
          ],
        );
        tooltip = 'From Email with Attachments';
        break;
      case NoteSourceType.web:
        icon = Icon(Icons.language, size: size, color: iconColor);
        tooltip = 'From Web Clipper';
        break;
      case NoteSourceType.attachment:
        icon = Icon(Icons.attach_file, size: size, color: iconColor);
        tooltip = 'Has Attachments';
        break;
      case NoteSourceType.regular:
        // Don't show an icon for regular notes to reduce clutter
        return const SizedBox.shrink();
    }

    return Tooltip(
      message: tooltip,
      child: Padding(padding: const EdgeInsets.only(left: 4), child: icon),
    );
  }
}

/// Enum representing different note source types
enum NoteSourceType { regular, email, emailWithAttachment, web, attachment }
