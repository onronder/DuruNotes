import 'dart:async';
import 'dart:convert';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Production-grade helper functions for working with domain.Note in UI
///
/// This file provides utilities to work with domain.Note entities without
/// needing to convert them to LocalNote. This maintains clean architecture
/// while providing the functionality UI components need.
class DomainNoteHelpers {
  static final AppLogger _logger = LoggerFactory.instance;

  static void _logParsingFailure(
    String context,
    Note note,
    Object error,
    StackTrace stackTrace,
  ) {
    _logger.warning(
      'Failed to $context from note metadata',
      data: {'noteId': note.id, 'noteType': note.noteType.name},
    );
    unawaited(Sentry.captureException(error, stackTrace: stackTrace));
  }

  /// Check if a note has attachments
  static bool hasAttachments(Note note) {
    if (note.attachmentMeta == null) return false;
    try {
      if (note.attachmentMeta is Map) {
        final meta = note.attachmentMeta as Map<String, dynamic>;
        return meta.isNotEmpty &&
            meta.containsKey('count') &&
            (meta['count'] as int? ?? 0) > 0;
      }
      if (note.attachmentMeta is String) {
        final meta = jsonDecode(note.attachmentMeta as String);
        return meta is Map &&
            meta.isNotEmpty &&
            meta['count'] != null &&
            (meta['count'] as int? ?? 0) > 0;
      }
    } catch (error, stackTrace) {
      _logParsingFailure(
        'determine attachment presence',
        note,
        error,
        stackTrace,
      );
      return false;
    }
    return false;
  }

  /// Get attachment count from a note
  static int getAttachmentCount(Note note) {
    if (!hasAttachments(note)) return 0;

    try {
      if (note.attachmentMeta is Map) {
        final meta = note.attachmentMeta as Map<String, dynamic>;
        return meta['count'] as int? ?? 0;
      }
      if (note.attachmentMeta is String) {
        final meta = jsonDecode(note.attachmentMeta as String);
        if (meta is Map) {
          return meta['count'] as int? ?? 0;
        }
      }
    } catch (error, stackTrace) {
      _logParsingFailure('read attachment count', note, error, stackTrace);
      return 0;
    }
    return 0;
  }

  /// Check if note is from email
  static bool isFromEmail(Note note) {
    if (note.metadata == null) return false;

    try {
      if (note.metadata is Map) {
        final meta = note.metadata as Map<String, dynamic>;
        return meta['source'] == 'email' || meta['source_type'] == 'email';
      }
      if (note.metadata is String) {
        final meta = jsonDecode(note.metadata as String);
        if (meta is Map) {
          return meta['source'] == 'email' || meta['source_type'] == 'email';
        }
      }
    } catch (error, stackTrace) {
      _logParsingFailure('detect email source', note, error, stackTrace);
      return false;
    }
    return false;
  }

  /// Check if note is from web clipper
  static bool isFromWeb(Note note) {
    if (note.metadata == null) return false;

    try {
      if (note.metadata is Map) {
        final meta = note.metadata as Map<String, dynamic>;
        return meta['source'] == 'web' ||
            meta['source_type'] == 'web' ||
            meta['source'] == 'clipper';
      }
      if (note.metadata is String) {
        final meta = jsonDecode(note.metadata as String);
        if (meta is Map) {
          return meta['source'] == 'web' ||
              meta['source_type'] == 'web' ||
              meta['source'] == 'clipper';
        }
      }
    } catch (error, stackTrace) {
      _logParsingFailure('detect web source', note, error, stackTrace);
      return false;
    }
    return false;
  }

  /// Get list of attachments from note
  static List<Map<String, dynamic>> getAttachments(Note note) {
    if (!hasAttachments(note)) return [];

    try {
      Map<String, dynamic> meta;
      if (note.attachmentMeta is Map) {
        meta = note.attachmentMeta as Map<String, dynamic>;
      } else if (note.attachmentMeta is String) {
        meta =
            jsonDecode(note.attachmentMeta as String) as Map<String, dynamic>;
      } else {
        return [];
      }

      final files = meta['files'];
      if (files is List) {
        return files.cast<Map<String, dynamic>>();
      }
    } catch (error, stackTrace) {
      _logParsingFailure('extract attachments list', note, error, stackTrace);
      return [];
    }
    return [];
  }

  /// Get preview text from note body (first N characters)
  static String getPreviewText(Note note, {int maxLength = 200}) {
    if (note.body.isEmpty) return '';

    // Remove markdown formatting for preview
    var preview = note.body
        .replaceAll(RegExp(r'#+ '), '') // Remove headers
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1') // Remove bold
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1') // Remove italic
        .replaceAll(RegExp(r'`(.+?)`'), r'$1') // Remove code
        .replaceAll(RegExp(r'\[(.+?)\]\(.+?\)'), r'$1') // Remove links
        .trim();

    if (preview.length <= maxLength) return preview;

    // Find last space before maxLength
    final cutoff = preview.lastIndexOf(' ', maxLength);
    if (cutoff > 0) {
      return '${preview.substring(0, cutoff)}...';
    }

    return '${preview.substring(0, maxLength)}...';
  }

  /// Check if note matches search query
  static bool matchesSearch(Note note, String query) {
    if (query.isEmpty) return true;

    final lowerQuery = query.toLowerCase();
    return note.title.toLowerCase().contains(lowerQuery) ||
        note.body.toLowerCase().contains(lowerQuery);
  }

  /// Get note source icon name
  static String getSourceIcon(Note note) {
    if (isFromEmail(note)) return 'email';
    if (isFromWeb(note)) return 'web';
    // Note: NoteKind.journal and NoteKind.draft don't exist in current enum
    return 'note';
  }

  /// Get note type display name
  static String getNoteTypeDisplayName(Note note) {
    switch (note.noteType) {
      case NoteKind.note:
        return 'Note';
      case NoteKind.template:
        return 'Template';
      default:
        return 'Note';
    }
  }

  /// Filter notes by criteria
  static List<Note> filterNotes(
    List<Note> notes, {
    bool? isPinned,
    bool? hasAttachments,
    bool? isFromEmail,
    bool? isFromWeb,
    String? searchQuery,
    NoteKind? noteType,
  }) {
    var filtered = notes;

    if (isPinned != null) {
      filtered = filtered.where((n) => n.isPinned == isPinned).toList();
    }

    if (hasAttachments == true) {
      filtered = filtered.where(DomainNoteHelpers.hasAttachments).toList();
    }

    if (isFromEmail == true) {
      filtered = filtered.where(DomainNoteHelpers.isFromEmail).toList();
    }

    if (isFromWeb == true) {
      filtered = filtered.where(DomainNoteHelpers.isFromWeb).toList();
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      filtered = filtered.where((n) => matchesSearch(n, searchQuery)).toList();
    }

    if (noteType != null) {
      filtered = filtered.where((n) => n.noteType == noteType).toList();
    }

    return filtered;
  }

  /// Sort notes by various criteria
  static List<Note> sortNotes(
    List<Note> notes, {
    String sortBy = 'updatedAt',
    bool ascending = false,
  }) {
    final sorted = List<Note>.from(notes);

    switch (sortBy) {
      case 'title':
        sorted.sort((a, b) {
          final comparison = a.title.toLowerCase().compareTo(
            b.title.toLowerCase(),
          );
          return ascending ? comparison : -comparison;
        });
        break;
      case 'createdAt':
      // Fall through to updatedAt (LocalNotes doesn't have createdAt)
      case 'updatedAt':
      default:
        sorted.sort((a, b) {
          final comparison = a.updatedAt.compareTo(b.updatedAt);
          return ascending ? comparison : -comparison;
        });
        break;
    }

    return sorted;
  }

  /// Group notes by date (for timeline view)
  static Map<String, List<Note>> groupByDate(List<Note> notes) {
    final grouped = <String, List<Note>>{};

    for (final note in notes) {
      final date = DateTime(
        note.updatedAt.year,
        note.updatedAt.month,
        note.updatedAt.day,
      );
      final dateKey = _formatDateKey(date);

      grouped.putIfAbsent(dateKey, () => []).add(note);
    }

    return grouped;
  }

  static String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';

    // Return formatted date
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
