import 'dart:async';

import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/smart_folders/smart_folder_types.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:flutter/foundation.dart';

/// Engine for evaluating smart folder rules and filtering notes
class SmartFolderEngine {

  SmartFolderEngine(this._repository);
  final NotesRepository _repository;
  final Map<String, StreamController<List<LocalNote>>> _controllers = {};
  final Map<String, Timer> _refreshTimers = {};

  /// Get all notes from the repository
  Future<List<LocalNote>> getAllNotes() async {
    return _repository.list();
  }

  /// Get notes matching a smart folder configuration
  Future<List<LocalNote>> getNotesForSmartFolder(SmartFolderConfig config) async {
    try {
      // Get all notes first
      final allNotes = await _repository.list();
      
      // Filter based on rules
      final filteredNotes = _filterNotes(allNotes, config);
      
      // Sort by modified date (most recent first)
      filteredNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      // Apply max results limit
      if (filteredNotes.length > config.maxResults) {
        return filteredNotes.take(config.maxResults).toList();
      }
      
      return filteredNotes;
    } catch (e) {
      if (kDebugMode) print('Error getting smart folder notes: $e');
      return [];
    }
  }

  /// Stream of notes for a smart folder with auto-refresh
  Stream<List<LocalNote>> watchSmartFolder(SmartFolderConfig config) {
    // Cancel existing controller if any
    _controllers[config.id]?.close();
    _refreshTimers[config.id]?.cancel();
    
    // Create new controller
    final controller = StreamController<List<LocalNote>>.broadcast();
    _controllers[config.id] = controller;
    
    // Initial load
    _refreshSmartFolder(config);
    
    // Setup auto-refresh if enabled
    if (config.autoRefresh) {
      final interval = config.refreshInterval ?? const Duration(minutes: 1);
      _refreshTimers[config.id] = Timer.periodic(interval, (_) {
        _refreshSmartFolder(config);
      });
    }
    
    return controller.stream;
  }

  /// Stop watching a smart folder
  void stopWatching(String smartFolderId) {
    _controllers[smartFolderId]?.close();
    _controllers.remove(smartFolderId);
    _refreshTimers[smartFolderId]?.cancel();
    _refreshTimers.remove(smartFolderId);
  }

  /// Manually refresh a smart folder
  Future<void> refreshSmartFolder(SmartFolderConfig config) async {
    await _refreshSmartFolder(config);
  }

  Future<void> _refreshSmartFolder(SmartFolderConfig config) async {
    final notes = await getNotesForSmartFolder(config);
    _controllers[config.id]?.add(notes);
  }

  /// Filter notes based on smart folder rules
  List<LocalNote> _filterNotes(List<LocalNote> notes, SmartFolderConfig config) {
    if (config.rules.isEmpty) return notes;
    
    return notes.where((note) {
      if (config.combineWithAnd) {
        // All rules must match (AND)
        return config.rules.every((rule) => _evaluateRule(note, rule));
      } else {
        // At least one rule must match (OR)
        return config.rules.any((rule) => _evaluateRule(note, rule));
      }
    }).toList();
  }

  /// Evaluate a single rule against a note
  bool _evaluateRule(LocalNote note, SmartFolderRule rule) {
    final fieldValue = _getFieldValue(note, rule.field);
    
    switch (rule.operator) {
      case RuleOperator.equals:
        return fieldValue == rule.value;
        
      case RuleOperator.notEquals:
        return fieldValue != rule.value;
        
      case RuleOperator.contains:
        if (fieldValue is String && rule.value is String) {
          return fieldValue.toLowerCase().contains((rule.value as String).toLowerCase());
        }
        return false;
        
      case RuleOperator.notContains:
        if (fieldValue is String && rule.value is String) {
          return !fieldValue.toLowerCase().contains((rule.value as String).toLowerCase());
        }
        return true;
        
      case RuleOperator.startsWith:
        if (fieldValue is String && rule.value is String) {
          return fieldValue.toLowerCase().startsWith((rule.value as String).toLowerCase());
        }
        return false;
        
      case RuleOperator.endsWith:
        if (fieldValue is String && rule.value is String) {
          return fieldValue.toLowerCase().endsWith((rule.value as String).toLowerCase());
        }
        return false;
        
      case RuleOperator.greaterThan:
        if (fieldValue is num && rule.value is num) {
          return fieldValue > (rule.value as num);
        }
        if (fieldValue is DateTime && rule.value is DateTime) {
          return fieldValue.isAfter(rule.value as DateTime);
        }
        return false;
        
      case RuleOperator.lessThan:
        if (fieldValue is num && rule.value is num) {
          return fieldValue < (rule.value as num);
        }
        if (fieldValue is DateTime && rule.value is DateTime) {
          return fieldValue.isBefore(rule.value as DateTime);
        }
        return false;
        
      case RuleOperator.between:
        if (fieldValue is num && rule.value is num && rule.secondValue is num) {
          return fieldValue >= (rule.value as num) && fieldValue <= (rule.secondValue as num);
        }
        if (fieldValue is DateTime && rule.value is DateTime && rule.secondValue is DateTime) {
          return fieldValue.isAfter(rule.value as DateTime) && fieldValue.isBefore(rule.secondValue as DateTime);
        }
        return false;
        
      case RuleOperator.inList:
        if (rule.value is List) {
          return (rule.value as List).contains(fieldValue);
        }
        return false;
        
      case RuleOperator.notInList:
        if (rule.value is List) {
          return !(rule.value as List).contains(fieldValue);
        }
        return true;
        
      case RuleOperator.isEmpty:
        if (fieldValue is String) {
          return fieldValue.isEmpty;
        }
        if (fieldValue is List) {
          return fieldValue.isEmpty;
        }
        return fieldValue == null;
        
      case RuleOperator.isNotEmpty:
        if (fieldValue is String) {
          return fieldValue.isNotEmpty;
        }
        if (fieldValue is List) {
          return fieldValue.isNotEmpty;
        }
        return fieldValue != null;
    }
  }

  /// Get field value from a note
  dynamic _getFieldValue(LocalNote note, RuleField field) {
    switch (field) {
      case RuleField.title:
        return note.title;
        
      case RuleField.content:
        return note.body;
        
      case RuleField.tags:
        // Extract tags from content (assuming #tag format)
        final tagPattern = RegExp(r'#\w+');
        final matches = tagPattern.allMatches(note.body);
        return matches.map((m) => m.group(0)).toList();
        
      case RuleField.createdDate:
        // Use updatedAt since createdAt is not available in LocalNote
        return note.updatedAt;
        
      case RuleField.modifiedDate:
        return note.updatedAt;
        
      case RuleField.attachmentCount:
        // Count attachment blocks in content
        final attachmentPattern = RegExp(r'!\[.*?\]\(.*?\)');
        return attachmentPattern.allMatches(note.body).length;
        
      case RuleField.wordCount:
        return note.body.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        
      case RuleField.hasImages:
        return note.body.contains(RegExp(r'!\[.*?\]\(.*?\)'));
        
      case RuleField.hasLinks:
        return note.body.contains(RegExp(r'\[.*?\]\(.*?\)')) ||
               note.body.contains(RegExp('https?://'));
        
      case RuleField.hasCode:
        return note.body.contains('```');
        
      case RuleField.hasTasks:
        return note.body.contains('- [ ]') || note.body.contains('- [x]');
        
      case RuleField.isEncrypted:
        // TODO: Add encryption support when available
        return false; // note.encryptedDataKey != null;
        
      case RuleField.isFavorite:
        // TODO: Add favorite field to LocalNote
        return false;
        
      case RuleField.isArchived:
        // TODO: Add archived field to LocalNote
        return false;
    }
  }

  /// Dispose of all resources
  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    
    for (final timer in _refreshTimers.values) {
      timer.cancel();
    }
    _refreshTimers.clear();
  }
}

/// Statistics for a smart folder
class SmartFolderStats {

  const SmartFolderStats({
    required this.totalNotes,
    required this.matchingNotes,
    this.lastRefresh,
    this.averageAge,
    this.totalWords = 0,
    this.totalAttachments = 0,
    this.tagCounts = const {},
  });

  factory SmartFolderStats.fromNotes(List<LocalNote> notes, int totalNotes) {
    if (notes.isEmpty) {
      return SmartFolderStats(
        totalNotes: totalNotes,
        matchingNotes: 0,
      );
    }

    // Calculate average age
    final now = DateTime.now();
    var totalAgeSeconds = 0;
    for (final note in notes) {
      totalAgeSeconds += now.difference(note.updatedAt).inSeconds;
    }
    final averageAge = Duration(seconds: totalAgeSeconds ~/ notes.length);

    // Calculate total words
    var totalWords = 0;
    for (final note in notes) {
      totalWords += note.body.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    }

    // Count attachments
    var totalAttachments = 0;
    final attachmentPattern = RegExp(r'!\[.*?\]\(.*?\)');
    for (final note in notes) {
      totalAttachments += attachmentPattern.allMatches(note.body).length;
    }

    // Count tags
    final tagCounts = <String, int>{};
    final tagPattern = RegExp(r'#(\w+)');
    for (final note in notes) {
      final matches = tagPattern.allMatches(note.body);
      for (final match in matches) {
        final tag = match.group(1)!;
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }

    return SmartFolderStats(
      totalNotes: totalNotes,
      matchingNotes: notes.length,
      lastRefresh: DateTime.now(),
      averageAge: averageAge,
      totalWords: totalWords,
      totalAttachments: totalAttachments,
      tagCounts: tagCounts,
    );
  }
  final int totalNotes;
  final int matchingNotes;
  final DateTime? lastRefresh;
  final Duration? averageAge;
  final int totalWords;
  final int totalAttachments;
  final Map<String, int> tagCounts;

  double get matchPercentage => 
      totalNotes > 0 ? (matchingNotes / totalNotes) * 100 : 0;
}
