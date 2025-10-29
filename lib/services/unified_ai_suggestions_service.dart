import 'dart:async';
import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/repositories/i_template_repository.dart';
import 'package:duru_notes/domain/repositories/i_tag_repository.dart';

/// Types of AI suggestions
enum SuggestionType {
  noteTitle,
  noteTags,
  noteFolder,
  noteTemplate,
  taskPriority,
  taskDueDate,
  relatedNotes,
  smartFolders,
  contentImprovement,
  duplicateDetection,
}

/// AI suggestion model
class AISuggestion {
  const AISuggestion({
    required this.type,
    required this.value,
    required this.confidence,
    required this.reasoning,
    this.metadata = const {},
  });

  final SuggestionType type;
  final dynamic value;
  final double confidence;
  final String reasoning;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'value': value,
    'confidence': confidence,
    'reasoning': reasoning,
    'metadata': metadata,
  };
}

/// Smart folder suggestion
class SmartFolderSuggestion {
  const SmartFolderSuggestion({
    required this.name,
    required this.description,
    required this.criteria,
    required this.estimatedCount,
  });

  final String name;
  final String description;
  final Map<String, dynamic> criteria;
  final int estimatedCount;
}

/// Content improvement suggestion
class ContentImprovementSuggestion {
  const ContentImprovementSuggestion({
    required this.type,
    required this.original,
    required this.improved,
    required this.reason,
  });

  final String type; // 'grammar', 'clarity', 'structure', 'formatting'
  final String original;
  final String improved;
  final String reason;
}

/// Unified AI suggestions service supporting both domain and legacy models
class UnifiedAISuggestionsService {
  static final UnifiedAISuggestionsService _instance = UnifiedAISuggestionsService._internal();
  factory UnifiedAISuggestionsService() => _instance;
  UnifiedAISuggestionsService._internal();

  final _logger = LoggerFactory.instance;

  late final AppDb _db;

  // Domain repositories
  INotesRepository? _domainNotesRepo;
  IFolderRepository? _domainFoldersRepo;

  // Caches for performance
  final Map<String, List<AISuggestion>> _suggestionCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Duration _cacheExpiration = const Duration(minutes: 10);

  // Pattern analysis
  final Map<String, int> _tagFrequency = {};
  final Map<String, int> _folderUsage = {};

  Future<void> initialize({
    required AppDb database,
    required MigrationConfig migrationConfig,
    INotesRepository? domainNotesRepo,
    ITaskRepository? domainTasksRepo,
    IFolderRepository? domainFoldersRepo,
    ITemplateRepository? domainTemplatesRepo,
    ITagRepository? domainTagsRepo,
  }) async {
    _db = database;
    _domainNotesRepo = domainNotesRepo;
    _domainFoldersRepo = domainFoldersRepo;

    // Build initial patterns
    await _buildUsagePatterns();

    _logger.info('UnifiedAISuggestionsService initialized');
  }

  /// Get suggestions for a note
  Future<List<AISuggestion>> getSuggestionsForNote(dynamic note) async {
    try {
      final noteId = _getNoteId(note);

      // Check cache
      if (_isCacheValid(noteId)) {
        return _suggestionCache[noteId]!;
      }

      final suggestions = <AISuggestion>[];

      // Generate various suggestions
      suggestions.addAll(await _suggestNoteTitle(note));
      suggestions.addAll(await _suggestNoteTags(note));
      suggestions.addAll(await _suggestNoteFolder(note));
      suggestions.addAll(await _suggestRelatedNotes(note));
      suggestions.addAll(await _detectDuplicates(note));

      // Sort by confidence
      suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));

      // Cache results
      _suggestionCache[noteId] = suggestions;
      _cacheTimestamps[noteId] = DateTime.now();

      return suggestions;

    } catch (e, stack) {
      _logger.error('Failed to get suggestions for note', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Get suggestions for a task
  Future<List<AISuggestion>> getSuggestionsForTask(dynamic task) async {
    try {
      final suggestions = <AISuggestion>[];

      // Suggest priority based on content
      suggestions.addAll(await _suggestTaskPriority(task));

      // Suggest due date based on patterns
      suggestions.addAll(await _suggestTaskDueDate(task));

      return suggestions;

    } catch (e, stack) {
      _logger.error('Failed to get suggestions for task', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Suggest smart folders based on content patterns
  Future<List<SmartFolderSuggestion>> suggestSmartFolders() async {
    try {
      final suggestions = <SmartFolderSuggestion>[];
      final notes = await _getAllNotes();

      // Analyze content patterns
      final patterns = <String, List<dynamic>>{};

      for (final note in notes) {
        final content = _getNoteContent(note).toLowerCase();

        // Meeting notes pattern
        if (content.contains('meeting') || content.contains('agenda') || content.contains('minutes')) {
          patterns.putIfAbsent('meetings', () => []).add(note);
        }

        // Project notes pattern
        if (content.contains('project') || content.contains('milestone') || content.contains('deadline')) {
          patterns.putIfAbsent('projects', () => []).add(note);
        }

        // Ideas pattern
        if (content.contains('idea') || content.contains('brainstorm') || content.contains('concept')) {
          patterns.putIfAbsent('ideas', () => []).add(note);
        }

        // Research pattern
        if (content.contains('research') || content.contains('study') || content.contains('analysis')) {
          patterns.putIfAbsent('research', () => []).add(note);
        }

        // Daily notes pattern
        if (content.contains('today') || content.contains('daily') || content.contains('journal')) {
          patterns.putIfAbsent('daily', () => []).add(note);
        }
      }

      // Create suggestions for significant patterns
      if ((patterns['meetings']?.length ?? 0) > 5) {
        suggestions.add(SmartFolderSuggestion(
          name: 'Meeting Notes',
          description: 'All notes related to meetings and discussions',
          criteria: {'contentContains': ['meeting', 'agenda', 'minutes']},
          estimatedCount: patterns['meetings']!.length,
        ));
      }

      if ((patterns['projects']?.length ?? 0) > 5) {
        suggestions.add(SmartFolderSuggestion(
          name: 'Project Documentation',
          description: 'Notes related to projects and milestones',
          criteria: {'contentContains': ['project', 'milestone', 'deadline']},
          estimatedCount: patterns['projects']!.length,
        ));
      }

      if ((patterns['ideas']?.length ?? 0) > 3) {
        suggestions.add(SmartFolderSuggestion(
          name: 'Ideas & Brainstorming',
          description: 'Creative ideas and brainstorming sessions',
          criteria: {'contentContains': ['idea', 'brainstorm', 'concept']},
          estimatedCount: patterns['ideas']!.length,
        ));
      }

      return suggestions;

    } catch (e, stack) {
      _logger.error('Failed to suggest smart folders', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Get content improvement suggestions
  Future<List<ContentImprovementSuggestion>> suggestContentImprovements(dynamic note) async {
    try {
      final suggestions = <ContentImprovementSuggestion>[];
      final content = _getNoteContent(note);

      // Check for formatting improvements
      if (!content.contains('#') && content.length > 500) {
        suggestions.add(ContentImprovementSuggestion(
          type: 'structure',
          original: content.substring(0, math.min(100, content.length)),
          improved: '# Main Topic\n\n## Section 1\n${content.substring(0, math.min(100, content.length))}',
          reason: 'Add headers to improve document structure',
        ));
      }

      // Check for list formatting
      final bulletPattern = RegExp(r'^[*\-•]\s+(.+)$', multiLine: true);
      final matches = bulletPattern.allMatches(content);
      if (matches.length > 3) {
        // Suggest numbered list for sequential items
        final hasSequentialWords = content.contains('first') ||
                                   content.contains('second') ||
                                   content.contains('then') ||
                                   content.contains('finally');
        if (hasSequentialWords) {
          suggestions.add(ContentImprovementSuggestion(
            type: 'formatting',
            original: '• Item one\n• Item two\n• Item three',
            improved: '1. Item one\n2. Item two\n3. Item three',
            reason: 'Use numbered lists for sequential items',
          ));
        }
      }

      // Check for task list opportunities
      final actionWords = ['todo', 'need to', 'must', 'should', 'will'];
      for (final word in actionWords) {
        if (content.toLowerCase().contains(word)) {
          suggestions.add(ContentImprovementSuggestion(
            type: 'formatting',
            original: 'Need to complete the report',
            improved: '- [ ] Complete the report',
            reason: 'Convert action items to task checkboxes',
          ));
          break;
        }
      }

      // Check for link opportunities
      final urlPattern = RegExp(r'(https?://[^\s]+)');
      final urlMatches = urlPattern.allMatches(content);
      for (final match in urlMatches) {
        final url = match.group(0)!;
        if (!content.contains('[$url]') && !content.contains('](url)')) {
          suggestions.add(ContentImprovementSuggestion(
            type: 'formatting',
            original: url,
            improved: '[Link]($url)',
            reason: 'Format URLs as markdown links',
          ));
        }
      }

      return suggestions;

    } catch (e, stack) {
      _logger.error('Failed to suggest content improvements', error: e, stackTrace: stack);
      return [];
    }
  }

  // Private suggestion methods
  Future<List<AISuggestion>> _suggestNoteTitle(dynamic note) async {
    final suggestions = <AISuggestion>[];
    final currentTitle = _getNoteTitle(note);
    final content = _getNoteContent(note);

    // If title is empty or generic, suggest based on content
    if (currentTitle.isEmpty || currentTitle == 'Untitled' || currentTitle == 'New Note') {
      // Extract first line or header
      final lines = content.split('\n');
      for (final line in lines) {
        if (line.trim().isNotEmpty) {
          String suggestedTitle = line.trim();

          // Remove markdown headers
          suggestedTitle = suggestedTitle.replaceAll(RegExp(r'^#+\s*'), '');

          // Limit length
          if (suggestedTitle.length > 50) {
            suggestedTitle = '${suggestedTitle.substring(0, 47)}...';
          }

          suggestions.add(AISuggestion(
            type: SuggestionType.noteTitle,
            value: suggestedTitle,
            confidence: 0.8,
            reasoning: 'Based on the first line of your note',
          ));
          break;
        }
      }

      // Suggest based on content patterns
      if (content.toLowerCase().contains('meeting')) {
        final dateStr = DateTime.now().toString().split(' ')[0];
        suggestions.add(AISuggestion(
          type: SuggestionType.noteTitle,
          value: 'Meeting Notes - $dateStr',
          confidence: 0.7,
          reasoning: 'Detected meeting-related content',
        ));
      }
    }

    return suggestions;
  }

  Future<List<AISuggestion>> _suggestNoteTags(dynamic note) async {
    final suggestions = <AISuggestion>[];
    final content = _getNoteContent(note).toLowerCase();
    final currentTags = await _getNoteTags(note);

    // Suggest based on content keywords
    final keywordTags = {
      'meeting': ['meeting', 'discussion'],
      'project': ['project', 'work'],
      'idea': ['idea', 'brainstorm'],
      'todo': ['task', 'todo'],
      'bug': ['bug', 'issue'],
      'feature': ['feature', 'enhancement'],
      'research': ['research', 'study'],
      'personal': ['personal', 'private'],
    };

    for (final entry in keywordTags.entries) {
      if (content.contains(entry.key)) {
        for (final tag in entry.value) {
          if (!currentTags.contains(tag)) {
            suggestions.add(AISuggestion(
              type: SuggestionType.noteTags,
              value: tag,
              confidence: 0.6 + (_tagFrequency[tag] ?? 0) / 100,
              reasoning: 'Based on content analysis',
              metadata: {'keyword': entry.key},
            ));
          }
        }
      }
    }

    // Suggest frequently used tags
    final frequentTags = _tagFrequency.entries
        .sorted((a, b) => b.value.compareTo(a.value))
        .take(5);

    for (final entry in frequentTags) {
      if (!currentTags.contains(entry.key)) {
        suggestions.add(AISuggestion(
          type: SuggestionType.noteTags,
          value: entry.key,
          confidence: 0.5,
          reasoning: 'Frequently used tag',
          metadata: {'frequency': entry.value},
        ));
      }
    }

    return suggestions;
  }

  Future<List<AISuggestion>> _suggestNoteFolder(dynamic note) async {
    final suggestions = <AISuggestion>[];
    final content = _getNoteContent(note).toLowerCase();
    final currentFolderId = _getNoteFolderId(note);

    if (currentFolderId == null) {
      // Analyze content to suggest folder
      final folders = await _getAllFolders();

      for (final folder in folders) {
        final folderName = _getFolderName(folder).toLowerCase();
        final score = _calculateFolderRelevance(content, folderName);

        if (score > 0.5) {
          suggestions.add(AISuggestion(
            type: SuggestionType.noteFolder,
            value: _getFolderId(folder),
            confidence: score,
            reasoning: 'Content matches folder theme',
            metadata: {'folderName': _getFolderName(folder)},
          ));
        }
      }
    }

    return suggestions;
  }

  Future<List<AISuggestion>> _suggestRelatedNotes(dynamic note) async {
    final suggestions = <AISuggestion>[];
    final noteId = _getNoteId(note);
    final content = _getNoteContent(note).toLowerCase();
    final words = _extractKeywords(content);

    if (words.isEmpty) return suggestions;

    final allNotes = await _getAllNotes();
    final relatedNotes = <dynamic, double>{};

    for (final otherNote in allNotes) {
      if (_getNoteId(otherNote) == noteId) continue;

      final otherContent = _getNoteContent(otherNote).toLowerCase();
      final otherWords = _extractKeywords(otherContent);

      // Calculate similarity
      final similarity = _calculateSimilarity(words, otherWords);

      if (similarity > 0.3) {
        relatedNotes[otherNote] = similarity;
      }
    }

    // Get top 5 related notes
    final topRelated = relatedNotes.entries
        .sorted((a, b) => b.value.compareTo(a.value))
        .take(5);

    for (final entry in topRelated) {
      suggestions.add(AISuggestion(
        type: SuggestionType.relatedNotes,
        value: _getNoteId(entry.key),
        confidence: entry.value,
        reasoning: 'Similar content detected',
        metadata: {
          'title': _getNoteTitle(entry.key),
          'similarity': entry.value,
        },
      ));
    }

    return suggestions;
  }

  Future<List<AISuggestion>> _detectDuplicates(dynamic note) async {
    final suggestions = <AISuggestion>[];
    final noteId = _getNoteId(note);
    final content = _getNoteContent(note);
    final contentHash = _hashContent(content);

    final allNotes = await _getAllNotes();

    for (final otherNote in allNotes) {
      if (_getNoteId(otherNote) == noteId) continue;

      final otherContent = _getNoteContent(otherNote);
      final otherHash = _hashContent(otherContent);

      // Check for exact duplicates
      if (contentHash == otherHash) {
        suggestions.add(AISuggestion(
          type: SuggestionType.duplicateDetection,
          value: _getNoteId(otherNote),
          confidence: 1.0,
          reasoning: 'Exact duplicate content found',
          metadata: {
            'title': _getNoteTitle(otherNote),
            'type': 'exact',
          },
        ));
      } else {
        // Check for near duplicates
        final similarity = _calculateSimilarity(
          _extractKeywords(content),
          _extractKeywords(otherContent),
        );

        if (similarity > 0.8) {
          suggestions.add(AISuggestion(
            type: SuggestionType.duplicateDetection,
            value: _getNoteId(otherNote),
            confidence: similarity,
            reasoning: 'Very similar content found',
            metadata: {
              'title': _getNoteTitle(otherNote),
              'type': 'similar',
              'similarity': similarity,
            },
          ));
        }
      }
    }

    return suggestions;
  }

  Future<List<AISuggestion>> _suggestTaskPriority(dynamic task) async {
    final suggestions = <AISuggestion>[];
    final taskTitle = _getTaskTitle(task).toLowerCase();

    // Keywords for priority detection
    final urgentKeywords = ['urgent', 'asap', 'immediately', 'critical', 'emergency'];
    final highKeywords = ['important', 'priority', 'deadline', 'must'];
    final lowKeywords = ['maybe', 'someday', 'eventually', 'optional'];

    String suggestedPriority = 'medium';
    double confidence = 0.5;

    for (final keyword in urgentKeywords) {
      if (taskTitle.contains(keyword)) {
        suggestedPriority = 'urgent';
        confidence = 0.9;
        break;
      }
    }

    if (suggestedPriority == 'medium') {
      for (final keyword in highKeywords) {
        if (taskTitle.contains(keyword)) {
          suggestedPriority = 'high';
          confidence = 0.8;
          break;
        }
      }
    }

    if (suggestedPriority == 'medium') {
      for (final keyword in lowKeywords) {
        if (taskTitle.contains(keyword)) {
          suggestedPriority = 'low';
          confidence = 0.7;
          break;
        }
      }
    }

    suggestions.add(AISuggestion(
      type: SuggestionType.taskPriority,
      value: suggestedPriority,
      confidence: confidence,
      reasoning: 'Based on task description keywords',
    ));

    return suggestions;
  }

  Future<List<AISuggestion>> _suggestTaskDueDate(dynamic task) async {
    final suggestions = <AISuggestion>[];
    final taskTitle = _getTaskTitle(task).toLowerCase();

    // Pattern for date detection
    final patterns = {
      'today': DateTime.now(),
      'tomorrow': DateTime.now().add(const Duration(days: 1)),
      'next week': DateTime.now().add(const Duration(days: 7)),
      'next month': DateTime.now().add(const Duration(days: 30)),
      'end of week': _getEndOfWeek(),
      'end of month': _getEndOfMonth(),
    };

    for (final entry in patterns.entries) {
      if (taskTitle.contains(entry.key)) {
        suggestions.add(AISuggestion(
          type: SuggestionType.taskDueDate,
          value: entry.value.toIso8601String(),
          confidence: 0.7,
          reasoning: 'Detected time reference: ${entry.key}',
        ));
      }
    }

    return suggestions;
  }

  // Helper methods
  Future<void> _buildUsagePatterns() async {
    try {
      // Build tag frequency map
      final notes = await _getAllNotes();
      for (final note in notes) {
        final tags = await _getNoteTags(note);
        for (final tag in tags) {
          _tagFrequency[tag] = (_tagFrequency[tag] ?? 0) + 1;
        }
      }

      // Build folder usage map
      final folders = await _getAllFolders();
      for (final folder in folders) {
        final folderId = _getFolderId(folder);
        _folderUsage[folderId] = 0; // Would count notes in folder
      }

      _logger.debug('Built usage patterns: ${_tagFrequency.length} tags, ${_folderUsage.length} folders');

    } catch (e, stack) {
      _logger.error('Failed to build usage patterns', error: e, stackTrace: stack);
    }
  }

  bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheExpiration;
  }

  List<String> _extractKeywords(String content) {
    // Simple keyword extraction - would use NLP in production
    final words = content
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toList();

    // Remove common words
    final stopWords = {'the', 'and', 'for', 'with', 'this', 'that', 'from', 'have', 'will'};
    return words.where((w) => !stopWords.contains(w)).toList();
  }

  double _calculateSimilarity(List<String> words1, List<String> words2) {
    if (words1.isEmpty || words2.isEmpty) return 0;

    final set1 = words1.toSet();
    final set2 = words2.toSet();

    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;

    return union > 0 ? intersection / union : 0;
  }

  double _calculateFolderRelevance(String content, String folderName) {
    final folderWords = folderName.split(RegExp(r'[\s_-]+')).map((w) => w.toLowerCase());
    int matches = 0;

    for (final word in folderWords) {
      if (content.contains(word)) {
        matches++;
      }
    }

    return matches / folderWords.length;
  }

  String _hashContent(String content) {
    // Simple hash for duplicate detection
    return '${content.length}_${content.hashCode}';
  }

  DateTime _getEndOfWeek() {
    final now = DateTime.now();
    final daysUntilFriday = 5 - now.weekday;
    return now.add(Duration(days: daysUntilFriday));
  }

  DateTime _getEndOfMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0);
  }

  // Data access methods
  Future<List<dynamic>> _getAllNotes() async {
    // SECURITY FIX: Always use domain repository to avoid crashes and ensure user isolation
    if (_domainNotesRepo != null) {
      return await _domainNotesRepo!.localNotes();
    } else {
      // Legacy fallback - DEPRECATED: Should not be used as it causes crashes with encrypted fields
      _logger.warning('[AISuggestions] Domain repository not available. AI suggestions disabled for encrypted notes.');

      // Get current user ID for filtering
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _logger.warning('[AISuggestions] No authenticated user');
        return [];
      }

      // SECURITY FIX: Filter by userId
      // Note: Fetching notes but not using them due to encryption incompatibility
      // TODO: Remove this query once domain repository is always available
      // final notes = await (_db.select(_db.localNotes)
      //   ..where((n) => n.userId.equals(userId))).get();

      // Return empty to prevent crashes - LocalNote can't be used with encrypted fields
      _logger.warning('[AISuggestions] Returning empty list - LocalNote incompatible with encryption');
      return [];
    }
  }

  Future<List<dynamic>> _getAllFolders() async {
    // Always prefer domain repository when available
    if (_domainFoldersRepo != null) {
      return await _domainFoldersRepo!.listFolders();
    } else {
      // Legacy fallback with user isolation
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _logger.warning('[AISuggestions] No authenticated user for folders');
        return [];
      }

      // SECURITY FIX: Filter by userId
      return await (_db.select(_db.localFolders)
        ..where((f) => f.userId.equals(userId))).get();
    }
  }

  Future<List<String>> _getNoteTags(dynamic note) async {
    // Note: noteId would be used for legacy tag lookup, but that's deprecated
    // final noteId = _getNoteId(note);
    if (note is domain.Note) {
      return note.tags;
    } else {
      // Post-migration: LocalNote doesn't have tags accessible, use domain.Note from repository
      throw UnsupportedError('LocalNote tag access deprecated. Use domain.Note from repository instead.');
    }
  }

  // Type-agnostic property accessors
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

  String? _getNoteFolderId(dynamic note) {
    if (note is domain.Note) return note.folderId;
    if (note is LocalNote) return null; // Legacy uses join table
    throw ArgumentError('Unknown note type');
  }

  String _getTaskTitle(dynamic task) {
    if (task is domain.Task) return task.title;
    // NoteTask.content doesn't exist post-encryption
    throw UnsupportedError('NoteTask title access deprecated. Use domain.Task from repository instead.');
  }

  String _getFolderId(dynamic folder) {
    if (folder is domain.Folder) return folder.id;
    if (folder is LocalFolder) return folder.id;
    throw ArgumentError('Unknown folder type');
  }

  String _getFolderName(dynamic folder) {
    if (folder is domain.Folder) return folder.name;
    if (folder is LocalFolder) return folder.name;
    throw ArgumentError('Unknown folder type');
  }

  void clearCache() {
    _suggestionCache.clear();
    _cacheTimestamps.clear();
  }
}