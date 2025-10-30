import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';

/// Production-grade service for parsing and managing note links
///
/// Supports multiple link formats:
/// - @[note-title] - @ sign mentions
/// - [[note-title]] - Wiki-style links
/// - @note-id - Direct note ID references
///
/// Features:
/// - Case-insensitive matching
/// - Fuzzy search for note titles
/// - Bidirectional link support
/// - Link validation
/// - Automatic link extraction
class NoteLinkParser {
  NoteLinkParser({required AppLogger logger, NoteIndexer? noteIndexer})
    : _logger = logger,
      _noteIndexer = noteIndexer;

  final AppLogger _logger;
  final NoteIndexer? _noteIndexer;

  // Regular expressions for different link formats
  static final _atMentionRegex = RegExp(r'@\[([^\]]+)\]', multiLine: true);

  static final _wikiLinkRegex = RegExp(r'\[\[([^\]]+)\]\]', multiLine: true);

  static final _atNoteIdRegex = RegExp(
    r'@([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})',
    multiLine: true,
    caseSensitive: false,
  );

  /// Extract all note links from text content
  ///
  /// Returns list of maps with format:
  /// ```dart
  /// {
  ///   'id': 'note-id' or null,
  ///   'title': 'note-title',
  ///   'type': 'at_mention' | 'wiki_link' | 'at_id'
  /// }
  /// ```
  Future<List<Map<String, String?>>> extractLinks(
    String content,
    INotesRepository notesRepository,
  ) async {
    try {
      final links = <Map<String, String?>>[];
      final processedTitles = <String>{};

      _logger.debug(
        '[NoteLinkParser] Extracting links from content',
        data: {'content_length': content.length},
      );

      // Extract @ mentions: @[note title]
      final atMentions = _atMentionRegex.allMatches(content);
      for (final match in atMentions) {
        final title = match.group(1)?.trim();
        if (title != null &&
            title.isNotEmpty &&
            !processedTitles.contains(title.toLowerCase())) {
          processedTitles.add(title.toLowerCase());
          final noteId = await _findNoteIdByTitle(title, notesRepository);
          links.add({'id': noteId, 'title': title, 'type': 'at_mention'});
        }
      }

      // Extract wiki links: [[note title]]
      final wikiLinks = _wikiLinkRegex.allMatches(content);
      for (final match in wikiLinks) {
        final title = match.group(1)?.trim();
        if (title != null &&
            title.isNotEmpty &&
            !processedTitles.contains(title.toLowerCase())) {
          processedTitles.add(title.toLowerCase());
          final noteId = await _findNoteIdByTitle(title, notesRepository);
          links.add({'id': noteId, 'title': title, 'type': 'wiki_link'});
        }
      }

      // Extract direct note ID references: @note-id
      final noteIdRefs = _atNoteIdRegex.allMatches(content);
      for (final match in noteIdRefs) {
        final noteId = match.group(1);
        if (noteId != null && !processedTitles.contains(noteId.toLowerCase())) {
          processedTitles.add(noteId.toLowerCase());
          final note = await notesRepository.getNoteById(noteId);
          links.add({
            'id': noteId,
            'title': note?.title ?? 'Unknown Note',
            'type': 'at_id',
          });
        }
      }

      _logger.info(
        '[NoteLinkParser] Extracted links',
        data: {
          'total_links': links.length,
          'at_mentions': links.where((l) => l['type'] == 'at_mention').length,
          'wiki_links': links.where((l) => l['type'] == 'wiki_link').length,
          'at_id_refs': links.where((l) => l['type'] == 'at_id').length,
        },
      );

      return links;
    } catch (e, stack) {
      _logger.error(
        '[NoteLinkParser] Failed to extract links',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Find note ID by title (case-insensitive, fuzzy match)
  Future<String?> _findNoteIdByTitle(
    String title,
    INotesRepository notesRepository,
  ) async {
    try {
      final allNotes = await notesRepository.localNotes();
      final titleLower = title.toLowerCase().trim();

      // Try exact match first
      for (final note in allNotes) {
        if (note.title.toLowerCase().trim() == titleLower) {
          _logger.debug(
            '[NoteLinkParser] Found exact match',
            data: {'title': title, 'note_id': note.id},
          );
          return note.id;
        }
      }

      // Try fuzzy match (contains)
      for (final note in allNotes) {
        if (note.title.toLowerCase().contains(titleLower)) {
          _logger.debug(
            '[NoteLinkParser] Found fuzzy match',
            data: {
              'title': title,
              'note_title': note.title,
              'note_id': note.id,
            },
          );
          return note.id;
        }
      }

      _logger.warning(
        '[NoteLinkParser] No note found for title',
        data: {'title': title},
      );
      return null;
    } catch (e, stack) {
      _logger.error(
        '[NoteLinkParser] Error finding note by title',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Search notes by partial title for autocomplete
  ///
  /// Returns up to [limit] notes matching the partial title
  Future<List<domain.Note>> searchNotesByTitle(
    String partialTitle,
    INotesRepository notesRepository, {
    int limit = 10,
  }) async {
    try {
      if (partialTitle.trim().isEmpty) return [];

      final allNotes = await notesRepository.localNotes();
      final titleLower = partialTitle.toLowerCase().trim();

      final matches = <domain.Note>[];

      // Exact matches first
      for (final note in allNotes) {
        if (note.title.toLowerCase().startsWith(titleLower)) {
          matches.add(note);
        }
      }

      // Then fuzzy matches
      for (final note in allNotes) {
        if (!matches.contains(note) &&
            note.title.toLowerCase().contains(titleLower)) {
          matches.add(note);
        }
      }

      final results = matches.take(limit).toList();

      _logger.debug(
        '[NoteLinkParser] Search results',
        data: {'query': partialTitle, 'results': results.length},
      );

      return results;
    } catch (e, stack) {
      _logger.error(
        '[NoteLinkParser] Error searching notes',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Validate if a note exists by title
  Future<bool> noteExistsByTitle(
    String title,
    INotesRepository notesRepository,
  ) async {
    final noteId = await _findNoteIdByTitle(title, notesRepository);
    return noteId != null;
  }

  /// Get backlinks for a note (notes that link to this note)
  Future<List<domain.Note>> getBacklinks(
    String noteId,
    INotesRepository notesRepository,
  ) async {
    try {
      if (_noteIndexer != null) {
        final backlinkIds = _noteIndexer.findNotesLinkingTo(noteId);
        if (backlinkIds.isNotEmpty) {
          final noteFutures = backlinkIds.map(notesRepository.getNoteById);
          final fetched = await Future.wait(noteFutures);
          final backlinks = fetched.whereType<domain.Note>().toList();

          if (backlinks.isNotEmpty) {
            _logger.info(
              '[NoteLinkParser] Backlinks (index)',
              data: {'note_id': noteId, 'backlink_count': backlinks.length},
            );
            return backlinks;
          }
        }
      }

      final targetNote = await notesRepository.getNoteById(noteId);
      if (targetNote == null) return [];

      final allNotes = await notesRepository.localNotes();
      final backlinks = <domain.Note>[];

      for (final note in allNotes) {
        if (note.id == noteId) continue;

        // Check if this note links to target note
        final links = await extractLinks(note.body, notesRepository);
        final hasLink = links.any(
          (link) =>
              link['id'] == noteId ||
              link['title']?.toLowerCase() == targetNote.title.toLowerCase(),
        );

        if (hasLink) {
          backlinks.add(note);
        }
      }

      _logger.info(
        '[NoteLinkParser] Found backlinks',
        data: {'note_id': noteId, 'backlink_count': backlinks.length},
      );

      return backlinks;
    } catch (e, stack) {
      _logger.error(
        '[NoteLinkParser] Error getting backlinks',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Replace note links with clickable markdown links
  ///
  /// Converts:
  /// - @[note title] → [note title](note://note-id)
  /// - [[note title]] → [note title](note://note-id)
  Future<String> replaceLinksWithMarkdown(
    String content,
    INotesRepository notesRepository,
  ) async {
    try {
      var result = content;

      // Replace @ mentions
      final atMentions = _atMentionRegex.allMatches(content);
      for (final match in atMentions) {
        final title = match.group(1)?.trim();
        if (title != null) {
          final noteId = await _findNoteIdByTitle(title, notesRepository);
          if (noteId != null) {
            result = result.replaceAll(
              match.group(0)!,
              '[$title](note://$noteId)',
            );
          }
        }
      }

      // Replace wiki links
      final wikiLinks = _wikiLinkRegex.allMatches(result);
      for (final match in wikiLinks) {
        final title = match.group(1)?.trim();
        if (title != null) {
          final noteId = await _findNoteIdByTitle(title, notesRepository);
          if (noteId != null) {
            result = result.replaceAll(
              match.group(0)!,
              '[$title](note://$noteId)',
            );
          }
        }
      }

      return result;
    } catch (e, stack) {
      _logger.error(
        '[NoteLinkParser] Error replacing links',
        error: e,
        stackTrace: stack,
      );
      return content;
    }
  }

  /// Check if content contains any note links
  bool hasLinks(String content) {
    return _atMentionRegex.hasMatch(content) ||
        _wikiLinkRegex.hasMatch(content) ||
        _atNoteIdRegex.hasMatch(content);
  }

  /// Get link statistics for a note
  Future<Map<String, dynamic>> getLinkStats(
    String content,
    INotesRepository notesRepository,
  ) async {
    final links = await extractLinks(content, notesRepository);

    return {
      'total_links': links.length,
      'resolved_links': links.where((l) => l['id'] != null).length,
      'unresolved_links': links.where((l) => l['id'] == null).length,
      'at_mentions': links.where((l) => l['type'] == 'at_mention').length,
      'wiki_links': links.where((l) => l['type'] == 'wiki_link').length,
      'at_id_refs': links.where((l) => l['type'] == 'at_id').length,
    };
  }
}
