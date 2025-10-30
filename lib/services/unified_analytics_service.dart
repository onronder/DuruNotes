import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as path;

import 'package:duru_notes/core/monitoring/app_logger.dart';
import '../core/migration/migration_config.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/repositories/i_template_repository.dart';
import 'package:duru_notes/domain/repositories/i_tag_repository.dart';
import 'package:duru_notes/domain/repositories/i_search_repository.dart';
// Legacy repository imports removed - using domain repositories only

// Analytics models
class AnalyticsOverview {
  final int totalNotes;
  final int totalTasks;
  final int totalFolders;
  final int totalTemplates;
  final int totalTags;
  final int activeNotes;
  final int completedTasks;
  final int pendingTasks;
  final int overdueTasks;
  final double taskCompletionRate;
  final double averageNoteLength;
  final DateTime? lastActivity;
  final int notesCreatedToday;
  final int notesCreatedThisWeek;
  final int notesCreatedThisMonth;
  final Map<String, int> notesByFolder;
  final Map<String, int> notesByTag;
  final Map<String, double> productivityScore;

  AnalyticsOverview({
    required this.totalNotes,
    required this.totalTasks,
    required this.totalFolders,
    required this.totalTemplates,
    required this.totalTags,
    required this.activeNotes,
    required this.completedTasks,
    required this.pendingTasks,
    required this.overdueTasks,
    required this.taskCompletionRate,
    required this.averageNoteLength,
    this.lastActivity,
    required this.notesCreatedToday,
    required this.notesCreatedThisWeek,
    required this.notesCreatedThisMonth,
    required this.notesByFolder,
    required this.notesByTag,
    required this.productivityScore,
  });

  Map<String, dynamic> toJson() => {
    'totalNotes': totalNotes,
    'totalTasks': totalTasks,
    'totalFolders': totalFolders,
    'totalTemplates': totalTemplates,
    'totalTags': totalTags,
    'activeNotes': activeNotes,
    'completedTasks': completedTasks,
    'pendingTasks': pendingTasks,
    'overdueTasks': overdueTasks,
    'taskCompletionRate': taskCompletionRate,
    'averageNoteLength': averageNoteLength,
    'lastActivity': lastActivity?.toIso8601String(),
    'notesCreatedToday': notesCreatedToday,
    'notesCreatedThisWeek': notesCreatedThisWeek,
    'notesCreatedThisMonth': notesCreatedThisMonth,
    'notesByFolder': notesByFolder,
    'notesByTag': notesByTag,
    'productivityScore': productivityScore,
  };
}

class TimeSeriesData {
  final DateTime date;
  final double value;
  final String? label;

  TimeSeriesData({required this.date, required this.value, this.label});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'value': value,
    'label': label,
  };
}

class ProductivityMetrics {
  final double dailyAverage;
  final double weeklyAverage;
  final double monthlyAverage;
  final int currentStreak;
  final int longestStreak;
  final List<TimeSeriesData> dailyActivity;
  final List<TimeSeriesData> weeklyActivity;
  final Map<int, double> hourlyDistribution;
  final Map<int, double> weekdayDistribution;
  final double focusScore;
  final double consistencyScore;

  ProductivityMetrics({
    required this.dailyAverage,
    required this.weeklyAverage,
    required this.monthlyAverage,
    required this.currentStreak,
    required this.longestStreak,
    required this.dailyActivity,
    required this.weeklyActivity,
    required this.hourlyDistribution,
    required this.weekdayDistribution,
    required this.focusScore,
    required this.consistencyScore,
  });

  Map<String, dynamic> toJson() => {
    'dailyAverage': dailyAverage,
    'weeklyAverage': weeklyAverage,
    'monthlyAverage': monthlyAverage,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'dailyActivity': dailyActivity.map((e) => e.toJson()).toList(),
    'weeklyActivity': weeklyActivity.map((e) => e.toJson()).toList(),
    'hourlyDistribution': hourlyDistribution,
    'weekdayDistribution': weekdayDistribution,
    'focusScore': focusScore,
    'consistencyScore': consistencyScore,
  };
}

class ContentAnalytics {
  final int totalWords;
  final int totalCharacters;
  final double averageWordsPerNote;
  final Map<String, int> topKeywords;
  final Map<String, int> topTags;
  final Map<String, int> contentTypes;
  final List<WordFrequency> wordFrequencies;
  final double readabilityScore;
  final Map<String, int> linkStatistics;

  ContentAnalytics({
    required this.totalWords,
    required this.totalCharacters,
    required this.averageWordsPerNote,
    required this.topKeywords,
    required this.topTags,
    required this.contentTypes,
    required this.wordFrequencies,
    required this.readabilityScore,
    required this.linkStatistics,
  });

  Map<String, dynamic> toJson() => {
    'totalWords': totalWords,
    'totalCharacters': totalCharacters,
    'averageWordsPerNote': averageWordsPerNote,
    'topKeywords': topKeywords,
    'topTags': topTags,
    'contentTypes': contentTypes,
    'wordFrequencies': wordFrequencies.map((e) => e.toJson()).toList(),
    'readabilityScore': readabilityScore,
    'linkStatistics': linkStatistics,
  };
}

class WordFrequency {
  final String word;
  final int count;
  final double percentage;

  WordFrequency({
    required this.word,
    required this.count,
    required this.percentage,
  });

  Map<String, dynamic> toJson() => {
    'word': word,
    'count': count,
    'percentage': percentage,
  };
}

class PerformanceAnalytics {
  final double averageSyncTime;
  final double averageSearchTime;
  final double averageLoadTime;
  final int syncFailures;
  final int searchQueries;
  final Map<String, double> featureUsage;
  final Map<String, int> errorFrequency;
  final double systemHealth;

  PerformanceAnalytics({
    required this.averageSyncTime,
    required this.averageSearchTime,
    required this.averageLoadTime,
    required this.syncFailures,
    required this.searchQueries,
    required this.featureUsage,
    required this.errorFrequency,
    required this.systemHealth,
  });

  Map<String, dynamic> toJson() => {
    'averageSyncTime': averageSyncTime,
    'averageSearchTime': averageSearchTime,
    'averageLoadTime': averageLoadTime,
    'syncFailures': syncFailures,
    'searchQueries': searchQueries,
    'featureUsage': featureUsage,
    'errorFrequency': errorFrequency,
    'systemHealth': systemHealth,
  };
}

enum ReportFormat { json, csv, html, markdown }

enum TimeRange {
  today,
  thisWeek,
  thisMonth,
  thisYear,
  last7Days,
  last30Days,
  last90Days,
  allTime,
  custom,
}

class AnalyticsFilter {
  final TimeRange timeRange;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String>? folderIds;
  final List<String>? tagIds;
  final bool includeDeleted;
  final bool includeArchived;

  const AnalyticsFilter({
    this.timeRange = TimeRange.allTime,
    this.startDate,
    this.endDate,
    this.folderIds,
    this.tagIds,
    this.includeDeleted = false,
    this.includeArchived = true,
  });
}

class UnifiedAnalyticsService {
  static final UnifiedAnalyticsService _instance =
      UnifiedAnalyticsService._internal();
  factory UnifiedAnalyticsService() => _instance;
  UnifiedAnalyticsService._internal();

  final _logger = LoggerFactory.instance;

  // Domain repositories
  INotesRepository? _domainNotesRepo;
  ITaskRepository? _domainTasksRepo;
  IFolderRepository? _domainFoldersRepo;
  ITemplateRepository? _domainTemplatesRepo;
  ITagRepository? _domainTagsRepo;

  // Legacy repositories - not implemented yet
  // LocalNotesRepository? _legacyNotesRepo;
  // NoteTasksRepository? _legacyTasksRepo;
  // LocalFoldersRepository? _legacyFoldersRepo;
  // LocalTemplateRepository? _legacyTemplatesRepo;
  // SavedSearchesRepository? _legacySearchesRepo;

  // Analytics cache
  final Map<String, dynamic> _analyticsCache = {};
  Timer? _cacheTimer;

  Future<void> initialize({
    required AppDb database,
    required MigrationConfig migrationConfig,
    INotesRepository? domainNotesRepo,
    ITaskRepository? domainTasksRepo,
    IFolderRepository? domainFoldersRepo,
    ITemplateRepository? domainTemplatesRepo,
    ITagRepository? domainTagsRepo,
    ISearchRepository? domainSearchesRepo,
    // LocalNotesRepository? legacyNotesRepo,
    // NoteTasksRepository? legacyTasksRepo,
    // LocalFoldersRepository? legacyFoldersRepo,
    // LocalTemplateRepository? legacyTemplatesRepo,
    // SavedSearchesRepository? legacySearchesRepo,
  }) async {
    _domainNotesRepo = domainNotesRepo;
    _domainTasksRepo = domainTasksRepo;
    _domainFoldersRepo = domainFoldersRepo;
    _domainTemplatesRepo = domainTemplatesRepo;
    _domainTagsRepo = domainTagsRepo;

    // Legacy repositories removed - using domain repositories only

    // Start cache refresh timer
    _cacheTimer?.cancel();
    _cacheTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _refreshCache();
    });

    _logger.info('UnifiedAnalyticsService initialized');
  }

  // Main analytics methods
  Future<AnalyticsOverview> getOverview({
    AnalyticsFilter filter = const AnalyticsFilter(),
  }) async {
    try {
      final cacheKey =
          'overview_${filter.timeRange}_${filter.startDate}_${filter.endDate}';
      if (_analyticsCache.containsKey(cacheKey)) {
        return _analyticsCache[cacheKey] as AnalyticsOverview;
      }

      // Get all data based on migration config
      final notes = await _getAllNotes(filter);
      final tasks = await _getAllTasks(filter);
      final folders = await _getAllFolders();
      final templates = await _getAllTemplates();
      final tags = await _getAllTags();

      // Calculate metrics
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      int notesCreatedToday = 0;
      int notesCreatedThisWeek = 0;
      int notesCreatedThisMonth = 0;
      int activeNotes = 0;
      int totalWords = 0;
      DateTime? lastActivity;
      final notesByFolder = <String, int>{};
      final notesByTag = <String, int>{};

      for (final note in notes) {
        final createdAt = _getNoteCreatedAt(note);
        final updatedAt = _getNoteUpdatedAt(note);

        if (createdAt.isAfter(todayStart)) notesCreatedToday++;
        if (createdAt.isAfter(weekStart)) notesCreatedThisWeek++;
        if (createdAt.isAfter(monthStart)) notesCreatedThisMonth++;

        if (!_isNoteDeleted(note)) activeNotes++;

        totalWords += _getNoteContent(note).split(' ').length;

        if (lastActivity == null || updatedAt.isAfter(lastActivity)) {
          lastActivity = updatedAt;
        }

        // Count by folder
        final folderId = _getNoteFolderId(note);
        if (folderId != null) {
          notesByFolder[folderId] = (notesByFolder[folderId] ?? 0) + 1;
        }

        // Count by tags
        for (final tag in await _getNoteTagIds(note)) {
          notesByTag[tag] = (notesByTag[tag] ?? 0) + 1;
        }
      }

      // Task metrics
      int completedTasks = 0;
      int pendingTasks = 0;
      int overdueTasks = 0;

      for (final task in tasks) {
        if (_isTaskCompleted(task)) {
          completedTasks++;
        } else {
          pendingTasks++;
          final dueDate = _getTaskDueDate(task);
          if (dueDate != null && dueDate.isBefore(now)) {
            overdueTasks++;
          }
        }
      }

      final taskCompletionRate = tasks.isEmpty
          ? 0.0
          : completedTasks / tasks.length;
      final averageNoteLength = notes.isEmpty ? 0.0 : totalWords / notes.length;

      // Calculate productivity score
      final productivityScore = _calculateProductivityScore(
        notesCreatedToday: notesCreatedToday,
        notesCreatedThisWeek: notesCreatedThisWeek,
        taskCompletionRate: taskCompletionRate,
        overdueTasks: overdueTasks,
      );

      final overview = AnalyticsOverview(
        totalNotes: notes.length,
        totalTasks: tasks.length,
        totalFolders: folders.length,
        totalTemplates: templates.length,
        totalTags: tags.length,
        activeNotes: activeNotes,
        completedTasks: completedTasks,
        pendingTasks: pendingTasks,
        overdueTasks: overdueTasks,
        taskCompletionRate: taskCompletionRate,
        averageNoteLength: averageNoteLength,
        lastActivity: lastActivity,
        notesCreatedToday: notesCreatedToday,
        notesCreatedThisWeek: notesCreatedThisWeek,
        notesCreatedThisMonth: notesCreatedThisMonth,
        notesByFolder: notesByFolder,
        notesByTag: notesByTag,
        productivityScore: productivityScore,
      );

      _analyticsCache[cacheKey] = overview;
      return overview;
    } catch (e, stack) {
      _logger.error(
        'Failed to get analytics overview',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<ProductivityMetrics> getProductivityMetrics({
    AnalyticsFilter filter = const AnalyticsFilter(),
  }) async {
    try {
      final notes = await _getAllNotes(filter);
      final tasks = await _getAllTasks(filter);

      // Calculate daily, weekly, monthly averages
      final dateRange = _getDateRange(filter);
      final daysDiff = dateRange.end.difference(dateRange.start).inDays + 1;

      final notesByDate = <DateTime, int>{};
      final tasksByDate = <DateTime, int>{};

      for (final note in notes) {
        final date = _dateOnly(_getNoteCreatedAt(note));
        notesByDate[date] = (notesByDate[date] ?? 0) + 1;
      }

      for (final task in tasks) {
        if (_isTaskCompleted(task)) {
          final date = _dateOnly(_getTaskCompletedAt(task) ?? DateTime.now());
          tasksByDate[date] = (tasksByDate[date] ?? 0) + 1;
        }
      }

      // Calculate averages
      final dailyAverage = notes.length / daysDiff;
      final weeklyAverage = dailyAverage * 7;
      final monthlyAverage = dailyAverage * 30;

      // Calculate streaks
      final streaks = _calculateStreaks(notesByDate);

      // Build time series
      final dailyActivity = <TimeSeriesData>[];
      final weeklyActivity = <TimeSeriesData>[];

      var currentDate = dateRange.start;
      while (currentDate.isBefore(dateRange.end) ||
          currentDate.isAtSameMomentAs(dateRange.end)) {
        final notesCount = notesByDate[_dateOnly(currentDate)] ?? 0;
        final tasksCount = tasksByDate[_dateOnly(currentDate)] ?? 0;

        dailyActivity.add(
          TimeSeriesData(
            date: currentDate,
            value: notesCount + tasksCount * 0.5, // Weight tasks less
            label: 'Notes: $notesCount, Tasks: $tasksCount',
          ),
        );

        currentDate = currentDate.add(const Duration(days: 1));
      }

      // Weekly aggregation
      for (int i = 0; i < dailyActivity.length; i += 7) {
        final weekData = dailyActivity.skip(i).take(7);
        if (weekData.isNotEmpty) {
          final weekTotal = weekData.fold<double>(
            0,
            (sum, data) => sum + data.value,
          );
          weeklyActivity.add(
            TimeSeriesData(
              date: weekData.first.date,
              value: weekTotal,
              label: 'Week total: ${weekTotal.round()}',
            ),
          );
        }
      }

      // Hourly and weekday distribution
      final hourlyDistribution = <int, double>{};
      final weekdayDistribution = <int, double>{};

      for (final note in notes) {
        final createdAt = _getNoteCreatedAt(note);
        hourlyDistribution[createdAt.hour] =
            (hourlyDistribution[createdAt.hour] ?? 0) + 1;
        weekdayDistribution[createdAt.weekday] =
            (weekdayDistribution[createdAt.weekday] ?? 0) + 1;
      }

      // Normalize distributions
      _normalizeDistribution(hourlyDistribution);
      _normalizeDistribution(weekdayDistribution);

      // Calculate scores
      final focusScore = _calculateFocusScore(hourlyDistribution);
      final consistencyScore = _calculateConsistencyScore(
        notesByDate,
        daysDiff,
      );

      return ProductivityMetrics(
        dailyAverage: dailyAverage,
        weeklyAverage: weeklyAverage,
        monthlyAverage: monthlyAverage,
        currentStreak: streaks.current,
        longestStreak: streaks.longest,
        dailyActivity: dailyActivity,
        weeklyActivity: weeklyActivity,
        hourlyDistribution: hourlyDistribution,
        weekdayDistribution: weekdayDistribution,
        focusScore: focusScore,
        consistencyScore: consistencyScore,
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to get productivity metrics',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<ContentAnalytics> getContentAnalytics({
    AnalyticsFilter filter = const AnalyticsFilter(),
  }) async {
    try {
      final notes = await _getAllNotes(filter);

      int totalWords = 0;
      int totalCharacters = 0;
      final wordCounts = <String, int>{};
      final tagCounts = <String, int>{};
      final contentTypes = <String, int>{};
      final linkStats = <String, int>{
        'internal': 0,
        'external': 0,
        'broken': 0,
      };

      for (final note in notes) {
        final content = _getNoteContent(note);

        // Basic counts
        totalCharacters += content.length;
        final words = content.split(RegExp(r'\s+'));
        totalWords += words.length;

        // Word frequency
        for (final word in words) {
          final cleaned = word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
          if (cleaned.length > 3) {
            // Skip short words
            wordCounts[cleaned] = (wordCounts[cleaned] ?? 0) + 1;
          }
        }

        // Tag counts
        for (final tagId in await _getNoteTagIds(note)) {
          tagCounts[tagId] = (tagCounts[tagId] ?? 0) + 1;
        }

        // Content type detection
        if (content.contains('- [ ]') || content.contains('- [x]')) {
          contentTypes['task'] = (contentTypes['task'] ?? 0) + 1;
        }
        if (content.contains('```')) {
          contentTypes['code'] = (contentTypes['code'] ?? 0) + 1;
        }
        if (content.contains('![') || content.contains('<img')) {
          contentTypes['image'] = (contentTypes['image'] ?? 0) + 1;
        }
        if (content.contains('http://') || content.contains('https://')) {
          contentTypes['links'] = (contentTypes['links'] ?? 0) + 1;
        }

        // Link analysis
        final linkPattern = RegExp(r'https?://[^\s\)]+');
        final links = linkPattern.allMatches(content);
        for (final link in links) {
          final url = link.group(0)!;
          if (url.contains('localhost') || url.contains('127.0.0.1')) {
            linkStats['internal'] = linkStats['internal']! + 1;
          } else {
            linkStats['external'] = linkStats['external']! + 1;
          }
        }
      }

      // Get top keywords
      final sortedWords = wordCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topKeywords = Map.fromEntries(sortedWords.take(20));

      // Get top tags
      final sortedTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topTags = Map.fromEntries(sortedTags.take(10));

      // Word frequencies with percentages
      final totalWordCount = wordCounts.values.fold(0, (a, b) => a + b);
      final wordFrequencies = sortedWords.take(50).map((entry) {
        return WordFrequency(
          word: entry.key,
          count: entry.value,
          percentage: (entry.value / totalWordCount) * 100,
        );
      }).toList();

      // Calculate readability (simplified Flesch Reading Ease)
      final averageWordsPerNote = notes.isEmpty
          ? 0.0
          : totalWords / notes.length;
      final readabilityScore = _calculateReadabilityScore(
        averageWordsPerNote: averageWordsPerNote,
        totalWords: totalWords,
        totalSentences: notes.length * 10, // Estimate
      );

      return ContentAnalytics(
        totalWords: totalWords,
        totalCharacters: totalCharacters,
        averageWordsPerNote: averageWordsPerNote,
        topKeywords: topKeywords,
        topTags: topTags,
        contentTypes: contentTypes,
        wordFrequencies: wordFrequencies,
        readabilityScore: readabilityScore,
        linkStatistics: linkStats,
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to get content analytics',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<PerformanceAnalytics> getPerformanceAnalytics() async {
    try {
      // Note: These would typically come from actual performance monitoring
      // For now, returning mock data that would be replaced with real metrics

      return PerformanceAnalytics(
        averageSyncTime: 1.5, // seconds
        averageSearchTime: 0.3, // seconds
        averageLoadTime: 0.8, // seconds
        syncFailures: 2,
        searchQueries: 150,
        featureUsage: {
          'notes': 85.0,
          'tasks': 65.0,
          'folders': 45.0,
          'templates': 30.0,
          'search': 70.0,
        },
        errorFrequency: {
          'sync_error': 2,
          'network_error': 5,
          'validation_error': 1,
        },
        systemHealth: 92.5, // percentage
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to get performance analytics',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  // Export methods
  Future<File?> exportAnalyticsReport({
    required ReportFormat format,
    AnalyticsFilter filter = const AnalyticsFilter(),
    String? outputPath,
  }) async {
    try {
      // Gather all analytics data
      final overview = await getOverview(filter: filter);
      final productivity = await getProductivityMetrics(filter: filter);
      final content = await getContentAnalytics(filter: filter);
      final performance = await getPerformanceAnalytics();

      final reportData = {
        'generated': DateTime.now().toIso8601String(),
        'filter': {
          'timeRange': filter.timeRange.toString(),
          'startDate': filter.startDate?.toIso8601String(),
          'endDate': filter.endDate?.toIso8601String(),
        },
        'overview': overview.toJson(),
        'productivity': productivity.toJson(),
        'content': content.toJson(),
        'performance': performance.toJson(),
      };

      // Generate report content
      String reportContent;
      String fileExtension;

      switch (format) {
        case ReportFormat.json:
          reportContent = const JsonEncoder.withIndent(
            '  ',
          ).convert(reportData);
          fileExtension = 'json';
          break;
        case ReportFormat.csv:
          reportContent = _generateCsvReport(reportData);
          fileExtension = 'csv';
          break;
        case ReportFormat.html:
          reportContent = _generateHtmlReport(reportData);
          fileExtension = 'html';
          break;
        case ReportFormat.markdown:
          reportContent = _generateMarkdownReport(reportData);
          fileExtension = 'md';
          break;
      }

      // Save to file
      final fileName =
          'analytics_report_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final file = File(
        outputPath ?? path.join(Directory.systemTemp.path, fileName),
      );
      await file.writeAsString(reportContent);

      _logger.info('Analytics report exported to ${file.path}');
      return file;
    } catch (e, stack) {
      _logger.error(
        'Failed to export analytics report',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  // Helper methods
  Future<List<dynamic>> _getAllNotes(AnalyticsFilter filter) async {
    // Always use domain repository
    final notes = await _domainNotesRepo?.localNotes() ?? [];
    return _filterNotesByDate(notes, filter);
  }

  Future<List<dynamic>> _getAllTasks(AnalyticsFilter filter) async {
    // Always use domain repository
    final tasks = await _domainTasksRepo?.getAllTasks() ?? [];
    return _filterTasksByDate(tasks, filter);
  }

  Future<List<dynamic>> _getAllFolders() async {
    // Always use domain repository
    // Use listFolders() method for folders
    return await _domainFoldersRepo?.listFolders() ?? [];
  }

  Future<List<dynamic>> _getAllTemplates() async {
    // Always use domain repository
    // Use getAllTemplates() method for templates
    return await _domainTemplatesRepo?.getAllTemplates() ?? [];
  }

  Future<List<dynamic>> _getAllTags() async {
    // Always use domain repository
    final tagCounts = await _domainTagsRepo?.listTagsWithCounts() ?? [];
    return tagCounts.map((tc) => tc.tag).toList();
  }

  List<dynamic> _filterNotesByDate(
    List<dynamic> notes,
    AnalyticsFilter filter,
  ) {
    final dateRange = _getDateRange(filter);
    return notes.where((note) {
      final createdAt = _getNoteCreatedAt(note);
      return createdAt.isAfter(dateRange.start) &&
          createdAt.isBefore(dateRange.end);
    }).toList();
  }

  List<dynamic> _filterTasksByDate(
    List<dynamic> tasks,
    AnalyticsFilter filter,
  ) {
    final dateRange = _getDateRange(filter);
    return tasks.where((task) {
      final createdAt = _getTaskCreatedAt(task);
      return createdAt.isAfter(dateRange.start) &&
          createdAt.isBefore(dateRange.end);
    }).toList();
  }

  ({DateTime start, DateTime end}) _getDateRange(AnalyticsFilter filter) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (filter.timeRange) {
      case TimeRange.today:
        return (start: todayStart, end: now);
      case TimeRange.thisWeek:
        final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
        return (start: weekStart, end: now);
      case TimeRange.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        return (start: monthStart, end: now);
      case TimeRange.thisYear:
        final yearStart = DateTime(now.year, 1, 1);
        return (start: yearStart, end: now);
      case TimeRange.last7Days:
        return (start: now.subtract(const Duration(days: 7)), end: now);
      case TimeRange.last30Days:
        return (start: now.subtract(const Duration(days: 30)), end: now);
      case TimeRange.last90Days:
        return (start: now.subtract(const Duration(days: 90)), end: now);
      case TimeRange.custom:
        return (
          start: filter.startDate ?? DateTime(2020),
          end: filter.endDate ?? now,
        );
      case TimeRange.allTime:
      default:
        return (start: DateTime(2020), end: now);
    }
  }

  // Type-agnostic property accessors
  DateTime _getNoteCreatedAt(dynamic note) {
    if (note is domain.Note)
      return note.updatedAt; // Note doesn't have createdAt
    if (note is LocalNote)
      return note.updatedAt; // LocalNote doesn't have createdAt
    throw ArgumentError('Unknown note type');
  }

  DateTime _getNoteUpdatedAt(dynamic note) {
    if (note is domain.Note) return note.updatedAt;
    if (note is LocalNote) return note.updatedAt;
    throw ArgumentError('Unknown note type');
  }

  String _getNoteContent(dynamic note) {
    if (note is domain.Note) return note.body;
    throw UnsupportedError(
      'LocalNote content access deprecated. Use domain.Note from repository instead.',
    );
  }

  bool _isNoteDeleted(dynamic note) {
    if (note is domain.Note) return note.deleted;
    if (note is LocalNote) return note.deleted;
    throw ArgumentError('Unknown note type');
  }

  String? _getNoteFolderId(dynamic note) {
    if (note is domain.Note) return note.folderId;
    if (note is LocalNote) {
      // Legacy notes use join table, would need separate query
      return null; // Simplified for now
    }
    throw ArgumentError('Unknown note type');
  }

  Future<List<String>> _getNoteTagIds(dynamic note) async {
    if (note is domain.Note) return note.tags;
    // LocalNote tag access deprecated post-encryption
    throw UnsupportedError(
      'LocalNote tag access deprecated. Use domain.Note from repository instead.',
    );
  }

  DateTime _getTaskCreatedAt(dynamic task) {
    if (task is domain.Task)
      return DateTime.now(); // Task doesn't have createdAt
    if (task is NoteTask) return task.createdAt;
    throw ArgumentError('Unknown task type');
  }

  bool _isTaskCompleted(dynamic task) {
    if (task is domain.Task) return task.status == domain.TaskStatus.completed;
    if (task is NoteTask) return task.status == TaskStatus.completed;
    throw ArgumentError('Unknown task type');
  }

  DateTime? _getTaskCompletedAt(dynamic task) {
    if (task is domain.Task) return task.completedAt;
    if (task is NoteTask) return task.completedAt;
    throw ArgumentError('Unknown task type');
  }

  DateTime? _getTaskDueDate(dynamic task) {
    if (task is domain.Task) return task.dueDate;
    if (task is NoteTask) return task.dueDate;
    throw ArgumentError('Unknown task type');
  }

  // Calculation helpers
  Map<String, double> _calculateProductivityScore({
    required int notesCreatedToday,
    required int notesCreatedThisWeek,
    required double taskCompletionRate,
    required int overdueTasks,
  }) {
    // Daily score (0-100)
    final dailyScore = math.min(100, notesCreatedToday * 20.0);

    // Weekly score (0-100)
    final weeklyScore = math.min(100, notesCreatedThisWeek * 5.0);

    // Task score (0-100)
    final taskScore = (taskCompletionRate * 100) - (overdueTasks * 5.0);

    // Overall score (weighted average)
    final overallScore =
        (dailyScore * 0.3 + weeklyScore * 0.3 + taskScore * 0.4);

    return {
      'daily': dailyScore.toDouble(),
      'weekly': weeklyScore.toDouble(),
      'tasks': math.max(0, taskScore),
      'overall': math.max(0, overallScore),
    };
  }

  ({int current, int longest}) _calculateStreaks(
    Map<DateTime, int> notesByDate,
  ) {
    if (notesByDate.isEmpty) return (current: 0, longest: 0);

    final sortedDates = notesByDate.keys.toList()..sort();

    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 1;

    for (int i = 1; i < sortedDates.length; i++) {
      final prevDate = sortedDates[i - 1];
      final currDate = sortedDates[i];

      if (currDate.difference(prevDate).inDays == 1) {
        tempStreak++;
      } else {
        longestStreak = math.max(longestStreak, tempStreak);
        tempStreak = 1;
      }
    }

    longestStreak = math.max(longestStreak, tempStreak);

    // Check if current streak is ongoing
    final today = _dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    if (notesByDate.containsKey(today) || notesByDate.containsKey(yesterday)) {
      currentStreak = tempStreak;
    }

    return (current: currentStreak, longest: longestStreak);
  }

  void _normalizeDistribution(Map<int, double> distribution) {
    if (distribution.isEmpty) return;

    final total = distribution.values.fold<double>(0, (sum, val) => sum + val);
    if (total > 0) {
      distribution.updateAll((key, value) => (value / total) * 100);
    }
  }

  double _calculateFocusScore(Map<int, double> hourlyDistribution) {
    // Higher score for work concentrated in fewer hours
    if (hourlyDistribution.isEmpty) return 0;

    final hoursActive = hourlyDistribution.keys.length;
    final concentrationScore = (24 - hoursActive) / 24.0 * 100;

    // Bonus for work during productive hours (9-17)
    double productiveHoursScore = 0;
    for (int hour = 9; hour <= 17; hour++) {
      productiveHoursScore += hourlyDistribution[hour] ?? 0;
    }

    return (concentrationScore * 0.5 + productiveHoursScore * 0.5);
  }

  double _calculateConsistencyScore(
    Map<DateTime, int> notesByDate,
    int totalDays,
  ) {
    if (totalDays == 0) return 0;

    final daysWithNotes = notesByDate.length;
    return (daysWithNotes / totalDays) * 100;
  }

  double _calculateReadabilityScore({
    required double averageWordsPerNote,
    required int totalWords,
    required int totalSentences,
  }) {
    if (totalSentences == 0 || totalWords == 0) return 50.0;

    // Simplified Flesch Reading Ease formula
    final avgWordsPerSentence = totalWords / totalSentences;
    final avgSyllablesPerWord = 1.5; // Estimate

    final score =
        206.835 - 1.015 * avgWordsPerSentence - 84.6 * avgSyllablesPerWord;

    return math.max(0, math.min(100, score));
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // Report generation helpers
  String _generateCsvReport(Map<String, dynamic> data) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('Analytics Report - ${data['generated']}');
    buffer.writeln();

    // Overview section
    final overview = data['overview'] as Map<String, dynamic>;
    buffer.writeln('Overview');
    buffer.writeln('Metric,Value');
    buffer.writeln('Total Notes,${overview['totalNotes']}');
    buffer.writeln('Total Tasks,${overview['totalTasks']}');
    buffer.writeln('Total Folders,${overview['totalFolders']}');
    buffer.writeln('Task Completion Rate,${overview['taskCompletionRate']}');
    buffer.writeln('Average Note Length,${overview['averageNoteLength']}');
    buffer.writeln();

    // Productivity section
    final productivity = data['productivity'] as Map<String, dynamic>;
    buffer.writeln('Productivity Metrics');
    buffer.writeln('Metric,Value');
    buffer.writeln('Daily Average,${productivity['dailyAverage']}');
    buffer.writeln('Weekly Average,${productivity['weeklyAverage']}');
    buffer.writeln('Current Streak,${productivity['currentStreak']}');
    buffer.writeln('Longest Streak,${productivity['longestStreak']}');
    buffer.writeln();

    // Content section
    final content = data['content'] as Map<String, dynamic>;
    buffer.writeln('Content Analytics');
    buffer.writeln('Metric,Value');
    buffer.writeln('Total Words,${content['totalWords']}');
    buffer.writeln('Total Characters,${content['totalCharacters']}');
    buffer.writeln('Readability Score,${content['readabilityScore']}');

    return buffer.toString();
  }

  String _generateHtmlReport(Map<String, dynamic> data) {
    final overview = data['overview'] as Map<String, dynamic>;
    final productivity = data['productivity'] as Map<String, dynamic>;
    final content = data['content'] as Map<String, dynamic>;
    final performance = data['performance'] as Map<String, dynamic>;

    return '''
<!DOCTYPE html>
<html>
<head>
    <title>Analytics Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #333; }
        h2 { color: #666; margin-top: 30px; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #f2f2f2; }
        .metric { font-size: 24px; font-weight: bold; color: #4CAF50; }
        .section { margin-bottom: 40px; }
    </style>
</head>
<body>
    <h1>Analytics Report</h1>
    <p>Generated: ${data['generated']}</p>

    <div class="section">
        <h2>Overview</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Total Notes</td><td class="metric">${overview['totalNotes']}</td></tr>
            <tr><td>Total Tasks</td><td class="metric">${overview['totalTasks']}</td></tr>
            <tr><td>Task Completion Rate</td><td>${(overview['taskCompletionRate'] * 100).toStringAsFixed(1)}%</td></tr>
            <tr><td>Average Note Length</td><td>${overview['averageNoteLength'].toStringAsFixed(0)} words</td></tr>
        </table>
    </div>

    <div class="section">
        <h2>Productivity</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Daily Average</td><td>${productivity['dailyAverage'].toStringAsFixed(1)}</td></tr>
            <tr><td>Current Streak</td><td>${productivity['currentStreak']} days</td></tr>
            <tr><td>Focus Score</td><td>${productivity['focusScore'].toStringAsFixed(1)}%</td></tr>
            <tr><td>Consistency Score</td><td>${productivity['consistencyScore'].toStringAsFixed(1)}%</td></tr>
        </table>
    </div>

    <div class="section">
        <h2>Content</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Total Words</td><td>${content['totalWords']}</td></tr>
            <tr><td>Readability Score</td><td>${content['readabilityScore'].toStringAsFixed(1)}</td></tr>
        </table>
    </div>

    <div class="section">
        <h2>System Performance</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>System Health</td><td>${performance['systemHealth']}%</td></tr>
            <tr><td>Average Sync Time</td><td>${performance['averageSyncTime']}s</td></tr>
            <tr><td>Search Queries</td><td>${performance['searchQueries']}</td></tr>
        </table>
    </div>
</body>
</html>
''';
  }

  String _generateMarkdownReport(Map<String, dynamic> data) {
    final overview = data['overview'] as Map<String, dynamic>;
    final productivity = data['productivity'] as Map<String, dynamic>;
    final content = data['content'] as Map<String, dynamic>;
    final performance = data['performance'] as Map<String, dynamic>;

    final buffer = StringBuffer();

    buffer.writeln('# Analytics Report');
    buffer.writeln();
    buffer.writeln('Generated: ${data['generated']}');
    buffer.writeln();

    buffer.writeln('## Overview');
    buffer.writeln();
    buffer.writeln('| Metric | Value |');
    buffer.writeln('|--------|-------|');
    buffer.writeln('| Total Notes | **${overview['totalNotes']}** |');
    buffer.writeln('| Total Tasks | **${overview['totalTasks']}** |');
    buffer.writeln(
      '| Task Completion Rate | ${(overview['taskCompletionRate'] * 100).toStringAsFixed(1)}% |',
    );
    buffer.writeln(
      '| Average Note Length | ${overview['averageNoteLength'].toStringAsFixed(0)} words |',
    );
    buffer.writeln();

    buffer.writeln('## Productivity Metrics');
    buffer.writeln();
    buffer.writeln(
      '- **Daily Average**: ${productivity['dailyAverage'].toStringAsFixed(1)} items',
    );
    buffer.writeln(
      '- **Current Streak**: ${productivity['currentStreak']} days',
    );
    buffer.writeln(
      '- **Longest Streak**: ${productivity['longestStreak']} days',
    );
    buffer.writeln(
      '- **Focus Score**: ${productivity['focusScore'].toStringAsFixed(1)}%',
    );
    buffer.writeln(
      '- **Consistency Score**: ${productivity['consistencyScore'].toStringAsFixed(1)}%',
    );
    buffer.writeln();

    buffer.writeln('## Content Analytics');
    buffer.writeln();
    buffer.writeln('- **Total Words**: ${content['totalWords']}');
    buffer.writeln('- **Total Characters**: ${content['totalCharacters']}');
    buffer.writeln(
      '- **Readability Score**: ${content['readabilityScore'].toStringAsFixed(1)}',
    );

    // Top keywords
    final topKeywords = content['topKeywords'] as Map<String, dynamic>;
    if (topKeywords.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('### Top Keywords');
      buffer.writeln();
      topKeywords.entries.take(10).forEach((entry) {
        buffer.writeln('- ${entry.key}: ${entry.value}');
      });
    }

    buffer.writeln();
    buffer.writeln('## Performance');
    buffer.writeln();
    buffer.writeln('- **System Health**: ${performance['systemHealth']}%');
    buffer.writeln(
      '- **Average Sync Time**: ${performance['averageSyncTime']}s',
    );
    buffer.writeln(
      '- **Average Search Time**: ${performance['averageSearchTime']}s',
    );
    buffer.writeln('- **Search Queries**: ${performance['searchQueries']}');

    return buffer.toString();
  }

  void _refreshCache() {
    // Clear old cache entries
    _analyticsCache.clear();
    _logger.debug('Analytics cache refreshed');
  }

  void dispose() {
    _cacheTimer?.cancel();
    _analyticsCache.clear();
  }
}
