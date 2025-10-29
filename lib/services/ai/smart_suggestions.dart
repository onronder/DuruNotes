import 'dart:async';
import 'dart:collection';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderCoreRepositoryProvider;
import 'package:duru_notes/features/auth/providers/auth_providers.dart'
    show userIdProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Smart folder suggestions service using ML-like algorithms
///
/// Features:
/// - Content-based folder suggestions
/// - Usage pattern learning
/// - Time-based recommendations
/// - Similarity matching
/// - Auto-categorization
class SmartSuggestionsService {
  SmartSuggestionsService({
    required this.repository,
    required this.folderRepository,
    required this.userId,
  });

  final NotesCoreRepository repository;
  final IFolderRepository folderRepository;
  final String userId;
  final _logger = LoggerFactory.instance;

  // Learning data
  final _folderPatterns = <String, FolderPattern>{};
  final _userBehavior = UserBehavior();
  final _suggestionCache = <String, List<FolderSuggestion>>{};

  // Configuration
  static const int maxSuggestions = 5;
  static const double minConfidence = 0.3;
  static const int minPatternOccurrences = 3;

  /// Get smart folder suggestions for a note
  Future<List<FolderSuggestion>> getSuggestionsForNote(domain.Note note) async {
    // Check cache first
    final cacheKey = '${note.id}_${note.updatedAt.millisecondsSinceEpoch}';
    if (_suggestionCache.containsKey(cacheKey)) {
      return _suggestionCache[cacheKey]!;
    }

    final suggestions = <FolderSuggestion>[];

    try {
      // 1. Content-based suggestions
      final contentSuggestions = await _getContentBasedSuggestions(note);
      suggestions.addAll(contentSuggestions);

      // 2. Time-based suggestions
      final timeSuggestions = await _getTimeBasedSuggestions(note);
      suggestions.addAll(timeSuggestions);

      // 3. Pattern-based suggestions
      final patternSuggestions = await _getPatternBasedSuggestions(note);
      suggestions.addAll(patternSuggestions);

      // 4. Similar notes suggestions
      final similaritySuggestions = await _getSimilarityBasedSuggestions(note);
      suggestions.addAll(similaritySuggestions);

      // Merge and rank suggestions
      final rankedSuggestions = _rankSuggestions(suggestions);

      // Cache the result
      _suggestionCache[cacheKey] = rankedSuggestions;

      // Clean old cache entries
      _cleanCache();

      return rankedSuggestions;
    } catch (e, stack) {
      _logger.error('Failed to get suggestions', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Get content-based folder suggestions
  Future<List<FolderSuggestion>> _getContentBasedSuggestions(
    domain.Note note,
  ) async {
    final suggestions = <FolderSuggestion>[];
    final folders = await folderRepository.listFolders();

    // Extract keywords from note
    final keywords = _extractKeywords(note);

    for (final folder in folders) {
      // Repository already filters deleted folders, no need to check

      // Check folder name and description for keyword matches
      double score = 0;
      int matches = 0;

      for (final keyword in keywords) {
        if (folder.name.toLowerCase().contains(keyword.toLowerCase())) {
          score += 0.3;
          matches++;
        }
        final description = folder.description;
        if (description != null && description.toLowerCase().contains(keyword.toLowerCase())) {
          score += 0.2;
          matches++;
        }
      }

      // Check for pattern matches in existing notes
      final folderNoteCount = await repository.db.countNotesInFolder(folder.id);
      if (folderNoteCount > 0) {
        final similarityScore = await _calculateFolderContentSimilarity(
          note,
          folder.id,
        );
        score += similarityScore * 0.5;
      }

      if (score > minConfidence) {
        suggestions.add(
          FolderSuggestion(
            folder: folder,
            confidence: score.clamp(0, 1),
            reason: 'Content matches: $matches keywords',
            type: SuggestionType.content,
          ),
        );
      }
    }

    return suggestions;
  }

  /// Get time-based folder suggestions
  Future<List<FolderSuggestion>> _getTimeBasedSuggestions(
    domain.Note note,
  ) async {
    final suggestions = <FolderSuggestion>[];
    final now = DateTime.now();

    // Get user's time patterns
    final timeOfDay = now.hour;
    final dayOfWeek = now.weekday;

    // Find folders frequently used at this time
    final recentFolderUsage = await _getRecentFolderUsage(
      timeOfDay: timeOfDay,
      dayOfWeek: dayOfWeek,
    );

    for (final usage in recentFolderUsage) {
      if (usage.confidence > minConfidence) {
        final folder = await folderRepository.getFolder(usage.folderId);
        if (folder != null) {
          suggestions.add(
            FolderSuggestion(
              folder: folder,
              confidence: usage.confidence,
              reason: 'Frequently used at this time',
              type: SuggestionType.temporal,
            ),
          );
        }
      }
    }

    return suggestions;
  }

  /// Get pattern-based folder suggestions
  Future<List<FolderSuggestion>> _getPatternBasedSuggestions(
    domain.Note note,
  ) async {
    final suggestions = <FolderSuggestion>[];

    // Analyze note creation patterns
    await _updateFolderPatterns();

    // Find matching patterns
    for (final pattern in _folderPatterns.values) {
      if (pattern.occurrences >= minPatternOccurrences) {
        final matchScore = _matchesPattern(note, pattern);

        if (matchScore > minConfidence) {
          final folder = await folderRepository.getFolder(pattern.folderId);
          if (folder != null) {
            suggestions.add(
              FolderSuggestion(
                folder: folder,
                confidence: matchScore,
                reason: 'Matches filing pattern',
                type: SuggestionType.pattern,
              ),
            );
          }
        }
      }
    }

    return suggestions;
  }

  /// Get similarity-based folder suggestions
  Future<List<FolderSuggestion>> _getSimilarityBasedSuggestions(
    domain.Note note,
  ) async {
    final suggestions = <FolderSuggestion>[];

    // Find similar notes
    final similarNotes = await _findSimilarNotes(note, limit: 10);

    // Group by folder and calculate confidence
    final folderScores = <String, double>{};
    final folderCounts = <String, int>{};

    for (final similarNote in similarNotes) {
      // Use folderId from the similar note (notes now have folderId directly)
      final folderId = similarNote.folderId;
      if (folderId != null) {
        folderScores[folderId] =
            (folderScores[folderId] ?? 0.0) + similarNote.similarity;
        folderCounts[folderId] = (folderCounts[folderId] ?? 0) + 1;
      }
    }

    // Create suggestions from folder scores
    for (final entry in folderScores.entries) {
      final folderId = entry.key;
      final totalScore = entry.value;
      final count = folderCounts[folderId]!;

      final confidence = (totalScore / count).clamp(0.0, 1.0).toDouble();

      if (confidence > minConfidence) {
        final folder = await folderRepository.getFolder(folderId);
        if (folder != null) {
          suggestions.add(
            FolderSuggestion(
              folder: folder,
              confidence: confidence,
              reason: 'Similar to $count notes in this folder',
              type: SuggestionType.similarity,
            ),
          );
        }
      }
    }

    return suggestions;
  }

  /// Extract keywords from note
  List<String> _extractKeywords(domain.Note note) {
    final text = '${note.title} ${note.body}'.toLowerCase();

    // Simple keyword extraction (could be enhanced with NLP)
    final words = text.split(RegExp(r'\s+'));
    final stopWords = {
      'the',
      'a',
      'an',
      'and',
      'or',
      'but',
      'in',
      'on',
      'at',
      'to',
      'for',
      'of',
      'with',
      'by',
      'from',
      'as',
      'is',
      'was',
      'are',
      'were',
      'be',
    };

    final keywords = <String, int>{};

    for (final word in words) {
      final cleaned = word.replaceAll(RegExp(r'[^\w]'), '');
      if (cleaned.length > 3 && !stopWords.contains(cleaned)) {
        keywords[cleaned] = (keywords[cleaned] ?? 0) + 1;
      }
    }

    // Sort by frequency and return top keywords
    final sortedKeywords = keywords.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedKeywords.take(10).map((e) => e.key).toList();
  }

  /// Calculate content similarity between note and folder
  Future<double> _calculateFolderContentSimilarity(
    domain.Note note,
    String folderId,
  ) async {
    // Get sample notes from folder - use repository which returns decrypted notes
    final allNotes = await repository.localNotes();
    final folderNotes = allNotes
        .where((n) => n.folderId == folderId)
        .take(10)
        .toList();

    if (folderNotes.isEmpty) return 0;

    // Calculate average similarity
    double totalSimilarity = 0;
    for (final folderNote in folderNotes) {
      totalSimilarity += _calculateNoteSimilarity(note, folderNote);
    }

    return totalSimilarity / folderNotes.length;
  }

  /// Calculate similarity between two notes
  double _calculateNoteSimilarity(domain.Note note1, domain.Note note2) {
    // Simple cosine similarity based on keywords
    final keywords1 = _extractKeywords(note1).toSet();
    final keywords2 = _extractKeywords(note2).toSet();

    if (keywords1.isEmpty || keywords2.isEmpty) return 0;

    final intersection = keywords1.intersection(keywords2).length;
    final union = keywords1.union(keywords2).length;

    return intersection / union;
  }

  /// Find similar notes
  Future<List<SimilarNote>> _findSimilarNotes(
    domain.Note note, {
    int limit = 10,
  }) async {
    final similarNotes = <SimilarNote>[];

    // Get all notes (repository returns decrypted domain.Note entities)
    final allNotes = await repository.localNotes();
    final recentNotes = allNotes.take(100).toList();

    for (final otherNote in recentNotes) {
      if (otherNote.id == note.id) continue;

      final similarity = _calculateNoteSimilarity(note, otherNote);
      if (similarity > 0.2) {
        similarNotes.add(
          SimilarNote(
            noteId: otherNote.id,
            similarity: similarity,
            folderId: otherNote.folderId, // Include folderId to avoid extra lookups
          ),
        );
      }
    }

    // Sort by similarity and return top matches
    similarNotes.sort((a, b) => b.similarity.compareTo(a.similarity));
    return similarNotes.take(limit).toList();
  }

  /// Get recent folder usage patterns
  Future<List<FolderUsage>> _getRecentFolderUsage({
    required int timeOfDay,
    required int dayOfWeek,
  }) async {
    // This would typically query a usage tracking table
    // For now, return mock data based on patterns
    return [];
  }

  /// Update folder patterns from historical data
  Future<void> _updateFolderPatterns() async {
    // Analyze historical filing patterns
    // This would typically use a background job to analyze patterns
  }

  /// Check if note matches a pattern
  double _matchesPattern(domain.Note note, FolderPattern pattern) {
    double score = 0;
    int matches = 0;

    // Check title pattern
    if (pattern.titlePattern != null) {
      if (RegExp(pattern.titlePattern!).hasMatch(note.title)) {
        score += 0.4;
        matches++;
      }
    }

    // Check content pattern
    if (pattern.contentPattern != null) {
      if (RegExp(pattern.contentPattern!).hasMatch(note.body)) {
        score += 0.3;
        matches++;
      }
    }

    // Check time pattern
    if (pattern.timePattern != null) {
      final noteHour = note.updatedAt.hour;
      if ((pattern.timePattern! - noteHour).abs() < 2) {
        score += 0.2;
        matches++;
      }
    }

    // Check tag pattern
    if (pattern.tagPattern != null && pattern.tagPattern!.isNotEmpty) {
      // Would check note tags here
      score += 0.1;
    }

    return matches > 0 ? score / matches : 0;
  }

  /// Rank and merge suggestions
  List<FolderSuggestion> _rankSuggestions(List<FolderSuggestion> suggestions) {
    // Group by folder ID
    final grouped = <String, List<FolderSuggestion>>{};
    for (final suggestion in suggestions) {
      grouped.putIfAbsent(suggestion.folder.id, () => []).add(suggestion);
    }

    // Merge suggestions for same folder
    final merged = <FolderSuggestion>[];
    for (final group in grouped.values) {
      if (group.length == 1) {
        merged.add(group.first);
      } else {
        // Combine confidence scores
        double totalConfidence = 0;
        final reasons = <String>[];
        final types = <SuggestionType>{};

        for (final suggestion in group) {
          totalConfidence += suggestion.confidence;
          reasons.add(suggestion.reason);
          types.add(suggestion.type);
        }

        merged.add(
          FolderSuggestion(
            folder: group.first.folder,
            confidence: (totalConfidence / group.length).clamp(0, 1),
            reason: reasons.join(', '),
            type: types.length == 1 ? types.first : SuggestionType.combined,
          ),
        );
      }
    }

    // Sort by confidence
    merged.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Return top suggestions
    return merged.take(maxSuggestions).toList();
  }

  /// Clean old cache entries
  void _cleanCache() {
    if (_suggestionCache.length > 100) {
      // Keep only recent entries
      final keysToRemove =
          _suggestionCache.keys.take(_suggestionCache.length - 50).toList();
      for (final key in keysToRemove) {
        _suggestionCache.remove(key);
      }
    }
  }

  /// Record user action for learning
  Future<void> recordUserAction(UserAction action) async {
    _userBehavior.recordAction(action);

    // Update patterns if enough data
    if (_userBehavior.actionCount % 10 == 0) {
      await _learnFromUserBehavior();
    }
  }

  /// Learn from user behavior
  Future<void> _learnFromUserBehavior() async {
    // Analyze user actions to improve suggestions
    final patterns = _userBehavior.extractPatterns();

    for (final pattern in patterns) {
      _folderPatterns[pattern.id] = pattern;
    }

    _logger.info(
      'Updated folder patterns',
      data: {
        'pattern_count': _folderPatterns.length,
        'action_count': _userBehavior.actionCount,
      },
    );
  }
}

/// Folder suggestion model
class FolderSuggestion {
  const FolderSuggestion({
    required this.folder,
    required this.confidence,
    required this.reason,
    required this.type,
  });

  final domain.Folder folder; // Changed from LocalFolder to domain.Folder
  final double confidence;
  final String reason;
  final SuggestionType type;
}

/// Suggestion type
enum SuggestionType { content, temporal, pattern, similarity, combined }

/// Folder pattern model
class FolderPattern {
  const FolderPattern({
    required this.id,
    required this.folderId,
    this.titlePattern,
    this.contentPattern,
    this.timePattern,
    this.tagPattern,
    required this.occurrences,
    required this.confidence,
  });

  final String id;
  final String folderId;
  final String? titlePattern;
  final String? contentPattern;
  final int? timePattern; // Hour of day
  final Set<String>? tagPattern;
  final int occurrences;
  final double confidence;
}

/// Similar note model
class SimilarNote {
  const SimilarNote({
    required this.noteId,
    required this.similarity,
    this.folderId,
  });

  final String noteId;
  final double similarity;
  final String? folderId; // Added to avoid additional database lookups
}

/// Folder usage model
class FolderUsage {
  const FolderUsage({required this.folderId, required this.confidence});

  final String folderId;
  final double confidence;
}

/// User behavior tracking
class UserBehavior {
  final _actions = Queue<UserAction>(); // Keep last 100 actions

  int get actionCount => _actions.length;

  void recordAction(UserAction action) {
    _actions.add(action);

    // Keep queue size bounded
    while (_actions.length > 100) {
      _actions.removeFirst();
    }
  }

  List<FolderPattern> extractPatterns() {
    // Analyze actions to extract patterns
    final patterns = <FolderPattern>[];

    // Group actions by folder
    final folderActions = <String, List<UserAction>>{};
    for (final action in _actions) {
      if (action.folderId != null) {
        folderActions.putIfAbsent(action.folderId!, () => []).add(action);
      }
    }

    // Extract patterns for each folder
    for (final entry in folderActions.entries) {
      final folderId = entry.key;
      final actions = entry.value;

      if (actions.length >= 3) {
        // Extract common patterns
        final pattern = _extractPattern(folderId, actions);
        if (pattern != null) {
          patterns.add(pattern);
        }
      }
    }

    return patterns;
  }

  FolderPattern? _extractPattern(String folderId, List<UserAction> actions) {
    // Simple pattern extraction
    // Could be enhanced with more sophisticated ML algorithms

    return FolderPattern(
      id: 'pattern_$folderId',
      folderId: folderId,
      occurrences: actions.length,
      confidence: actions.length / 100.0,
    );
  }
}

/// User action model
class UserAction {
  const UserAction({
    required this.type,
    required this.noteId,
    this.folderId,
    required this.timestamp,
    this.accepted,
  });

  final ActionType type;
  final String noteId;
  final String? folderId;
  final DateTime timestamp;
  final bool? accepted; // For suggestion actions
}

/// Action type
enum ActionType {
  fileNote,
  acceptSuggestion,
  rejectSuggestion,
  moveNote,
  createFolder,
}

/// Smart suggestions provider
final smartSuggestionsProvider = Provider<SmartSuggestionsService>((ref) {
  final repository = ref.watch(notesCoreRepositoryProvider);
  final folderRepository = ref.watch(folderCoreRepositoryProvider);
  final userId = ref.watch(userIdProvider) ?? 'default';

  return SmartSuggestionsService(
    repository: repository,
    folderRepository: folderRepository,
    userId: userId,
  );
});

/// Suggestions for current note provider
final noteSuggestionsProvider =
    FutureProvider.family<List<FolderSuggestion>, String>((ref, noteId) async {
  final repository = ref.watch(notesCoreRepositoryProvider);
  final suggestionsService = ref.watch(smartSuggestionsProvider);

  // Get note using repository (returns domain.Note, already decrypted)
  final note = await repository.getNoteById(noteId);
  if (note == null) return [];

  return suggestionsService.getSuggestionsForNote(note);
});
