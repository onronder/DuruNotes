import 'dart:convert';

import 'package:duru_notes/data/local/app_db.dart';
import 'package:flutter/material.dart';

/// Widget that displays an icon indicating the source of a note
class NoteSourceIcon extends StatelessWidget {
  const NoteSourceIcon({
    required this.note,
    super.key,
    this.size = 16,
    this.color,
  });
  final LocalNote note;
  final double size;
  final Color? color;

  /// Determines the source type of the note
  NoteSourceType _getNoteSourceType() {
    // Check encrypted metadata first (most reliable)
    if (note.encryptedMetadata != null) {
      try {
        final meta = jsonDecode(note.encryptedMetadata!);
        final source = meta['source'] as String?;

        if (source == 'email_in') {
          // Check if it has attachments
          final attachments = meta['attachments']?['files'] as List?;
          if (attachments != null && attachments.isNotEmpty) {
            return NoteSourceType.emailWithAttachment;
          }
          return NoteSourceType.email;
        } else if (source == 'web') {
          return NoteSourceType.web;
        }
      } catch (e) {
        // Fall through to tag-based detection
      }
    }

    // Fallback to tag-based detection
    final body = note.body.toLowerCase();
    if (body.contains('#email')) {
      // Check for attachments in metadata or body
      if (note.encryptedMetadata != null) {
        try {
          final meta = jsonDecode(note.encryptedMetadata!);
          final attachments = meta['attachments']?['files'] as List?;
          if (attachments != null && attachments.isNotEmpty) {
            return NoteSourceType.emailWithAttachment;
          }
        } catch (_) {}
      }
      // Check for attachment tag
      if (body.contains('#attachment')) {
        return NoteSourceType.emailWithAttachment;
      }
      return NoteSourceType.email;
    } else if (body.contains('#web')) {
      return NoteSourceType.web;
    }

    // Check for standalone attachments
    if (note.encryptedMetadata != null) {
      try {
        final meta = jsonDecode(note.encryptedMetadata!);
        final attachments = meta['attachments']?['files'] as List?;
        if (attachments != null && attachments.isNotEmpty) {
          return NoteSourceType.attachment;
        }
      } catch (_) {}
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
