import 'dart:async';
import 'dart:math';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Service for analyzing task productivity and generating insights
class TaskAnalyticsService {
  TaskAnalyticsService(this._ref, {required AppDb database}) : _db = database;

  final Ref _ref;
  final AppDb _db;
  AppLogger get _logger => _ref.read(loggerProvider);

  /// Get comprehensive productivity analytics
  Future<ProductivityAnalytics> getProductivityAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final results = await Future.wait([
        getTaskCompletionStats(start, end),
        getTimeEstimationAccuracy(start, end),
        getProductivityTrends(start, end),
        getPriorityDistribution(start, end),
        getDeadlineAdherenceMetrics(start, end),
        getCategoryPerformance(start, end),
      ]);

      final completionStats = results[0] as TaskCompletionStats;
      final timeAccuracyStats = results[1] as TimeEstimationAccuracy;
      final productivityTrends = results[2] as ProductivityTrends;
      final priorityDistribution = results[3] as PriorityDistribution;
      final deadlineMetrics = results[4] as DeadlineAdherenceMetrics;
      final categoryPerformance = results[5] as CategoryPerformance;

      return ProductivityAnalytics(
        dateRange: DateRange(start: start, end: end),
        completionStats: completionStats,
        timeAccuracyStats: timeAccuracyStats,
        productivityTrends: productivityTrends,
        priorityDistribution: priorityDistribution,
        deadlineMetrics: deadlineMetrics,
        categoryPerformance: categoryPerformance,
        generatedAt: DateTime.now(),
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to generate productivity analytics',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Get task completion statistics
  Future<TaskCompletionStats> getTaskCompletionStats(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final completedTasks = await _getCompletedTasksInRange(startDate, endDate);
    final totalTasks = await _getAllTasksInRange(startDate, endDate);

    // Group by date
    final completionsByDate = <DateTime, int>{};
    final creationsByDate = <DateTime, int>{};

    for (final task in completedTasks) {
      if (task.completedAt != null) {
        final date = DateTime(
          task.completedAt!.year,
          task.completedAt!.month,
          task.completedAt!.day,
        );
        completionsByDate[date] = (completionsByDate[date] ?? 0) + 1;
      }
    }

    for (final task in totalTasks) {
      final date = DateTime(
        task.createdAt.year,
        task.createdAt.month,
        task.createdAt.day,
      );
      creationsByDate[date] = (creationsByDate[date] ?? 0) + 1;
    }

    // Calculate streaks
    final completionStreak = _calculateCompletionStreak(completionsByDate);
    final averagePerDay =
        completedTasks.length / _daysBetween(startDate, endDate);

    return TaskCompletionStats(
      totalCompleted: completedTasks.length,
      totalCreated: totalTasks.length,
      completionRate: totalTasks.isNotEmpty
          ? completedTasks.length / totalTasks.length
          : 0.0,
      averagePerDay: averagePerDay,
      completionsByDate: completionsByDate,
      creationsByDate: creationsByDate,
      currentStreak: completionStreak,
      bestDay: _getBestCompletionDay(completionsByDate),
    );
  }

  /// Get time estimation accuracy statistics
  Future<TimeEstimationAccuracy> getTimeEstimationAccuracy(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final tasksWithTime = await _getTasksWithTimeTracking(startDate, endDate);

    if (tasksWithTime.isEmpty) {
      return TimeEstimationAccuracy.empty();
    }

    final accuracyData = <TimeAccuracyPoint>[];
    var totalEstimated = 0;
    var totalActual = 0;
    var accurateEstimates = 0;
    var underEstimates = 0;
    var overEstimates = 0;

    for (final task in tasksWithTime) {
      final estimated = task.estimatedMinutes!;
      final actual = task.actualMinutes!;

      totalEstimated += estimated;
      totalActual += actual;

      final accuracy = estimated > 0 ? actual / estimated : 0.0;
      final accuracyPercentage = (accuracy * 100).round();

      accuracyData.add(TimeAccuracyPoint(
        taskId: task.id,
        estimated: estimated,
        actual: actual,
        accuracy: accuracy,
        date: task.completedAt ?? task.updatedAt,
        priority: task.priority,
      ));

      // Categorize accuracy (within 20% is considered accurate)
      if (accuracy >= 0.8 && accuracy <= 1.2) {
        accurateEstimates++;
      } else if (accuracy > 1.2) {
        underEstimates++;
      } else {
        overEstimates++;
      }
    }

    final overallAccuracy =
        totalEstimated > 0 ? totalActual / totalEstimated : 0.0;
    final averageEstimationError =
        _calculateAverageEstimationError(accuracyData);

    return TimeEstimationAccuracy(
      totalTasksWithTime: tasksWithTime.length,
      overallAccuracy: overallAccuracy,
      averageEstimationError: averageEstimationError,
      accurateEstimates: accurateEstimates,
      underEstimates: underEstimates,
      overEstimates: overEstimates,
      totalEstimatedMinutes: totalEstimated,
      totalActualMinutes: totalActual,
      accuracyData: accuracyData,
      improvementTrend: _calculateImprovementTrend(accuracyData),
    );
  }

  /// Get productivity trends over time
  Future<ProductivityTrends> getProductivityTrends(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final completedTasks = await _getCompletedTasksInRange(startDate, endDate);

    // Group by time periods
    final dailyTrends = <DateTime, DailyProductivity>{};
    final weeklyTrends = <DateTime, WeeklyProductivity>{};
    final hourlyDistribution = <int, int>{};

    for (final task in completedTasks) {
      if (task.completedAt != null) {
        final completedAt = task.completedAt!;
        final date =
            DateTime(completedAt.year, completedAt.month, completedAt.day);
        final hour = completedAt.hour;

        // Daily trends
        final daily = dailyTrends[date] ??
            DailyProductivity(
              date: date,
              tasksCompleted: 0,
              totalMinutesSpent: 0,
              averageTaskTime: 0,
              priorityBreakdown: {},
            );

        dailyTrends[date] = DailyProductivity(
          date: date,
          tasksCompleted: daily.tasksCompleted + 1,
          totalMinutesSpent:
              daily.totalMinutesSpent + (task.actualMinutes ?? 0),
          averageTaskTime: 0, // Will be calculated later
          priorityBreakdown: {
            ...daily.priorityBreakdown,
            task.priority: (daily.priorityBreakdown[task.priority] ?? 0) + 1,
          },
        );

        // Hourly distribution
        hourlyDistribution[hour] = (hourlyDistribution[hour] ?? 0) + 1;
      }
    }

    // Calculate average task times for daily trends
    for (final entry in dailyTrends.entries) {
      final daily = entry.value;
      dailyTrends[entry.key] = DailyProductivity(
        date: daily.date,
        tasksCompleted: daily.tasksCompleted,
        totalMinutesSpent: daily.totalMinutesSpent,
        averageTaskTime: daily.tasksCompleted > 0
            ? daily.totalMinutesSpent / daily.tasksCompleted
            : 0,
        priorityBreakdown: daily.priorityBreakdown,
      );
    }

    // Calculate weekly trends
    final weekStartDates = <DateTime>{};
    for (final date in dailyTrends.keys) {
      final weekStart = _getWeekStart(date);
      weekStartDates.add(weekStart);
    }

    for (final weekStart in weekStartDates) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final weekTasks = completedTasks.where((task) {
        if (task.completedAt == null) return false;
        final date = DateTime(
          task.completedAt!.year,
          task.completedAt!.month,
          task.completedAt!.day,
        );
        return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            date.isBefore(weekEnd.add(const Duration(days: 1)));
      }).toList();

      weeklyTrends[weekStart] = WeeklyProductivity(
        weekStart: weekStart,
        tasksCompleted: weekTasks.length,
        totalMinutesSpent:
            weekTasks.fold(0, (sum, task) => sum + (task.actualMinutes ?? 0)),
        averageTasksPerDay: weekTasks.length / 7.0,
        mostProductiveDay: _getMostProductiveDay(weekTasks),
      );
    }

    return ProductivityTrends(
      dailyTrends: dailyTrends.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date)),
      weeklyTrends: weeklyTrends.values.toList()
        ..sort((a, b) => a.weekStart.compareTo(b.weekStart)),
      hourlyDistribution: hourlyDistribution,
      mostProductiveHour: _getMostProductiveHour(hourlyDistribution),
      averageTasksPerDay: _calculateAverageTasksPerDay(dailyTrends),
      productivityScore: _calculateProductivityScore(dailyTrends, weeklyTrends),
    );
  }

  /// Get priority distribution statistics
  Future<PriorityDistribution> getPriorityDistribution(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final allTasks = await _getAllTasksInRange(startDate, endDate);
    final completedTasks = await _getCompletedTasksInRange(startDate, endDate);

    final distribution = <TaskPriority, PriorityStats>{};

    for (final priority in TaskPriority.values) {
      final totalCount = allTasks.where((t) => t.priority == priority).length;
      final completedCount =
          completedTasks.where((t) => t.priority == priority).length;
      final averageTimeToComplete = _calculateAverageCompletionTime(
        completedTasks.where((t) => t.priority == priority).toList(),
      );

      distribution[priority] = PriorityStats(
        priority: priority,
        totalTasks: totalCount,
        completedTasks: completedCount,
        completionRate: totalCount > 0 ? completedCount / totalCount : 0.0,
        averageTimeToComplete: averageTimeToComplete,
        averageEstimatedTime: _calculateAverageEstimatedTime(
          allTasks.where((t) => t.priority == priority).toList(),
        ),
        averageActualTime: _calculateAverageActualTime(
          completedTasks.where((t) => t.priority == priority).toList(),
        ),
      );
    }

    return PriorityDistribution(
      distribution: distribution,
      mostCompletedPriority: _getMostCompletedPriority(distribution),
      fastestCompletingPriority: _getFastestCompletingPriority(distribution),
    );
  }

  /// Get deadline adherence metrics
  Future<DeadlineAdherenceMetrics> getDeadlineAdherenceMetrics(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final tasksWithDueDates =
        await _getTasksWithDueDatesInRange(startDate, endDate);
    final completedTasksWithDueDates = tasksWithDueDates
        .where((t) => t.status == TaskStatus.completed)
        .toList();

    var onTimeCompletions = 0;
    var earlyCompletions = 0;
    var lateCompletions = 0;
    var totalDeadlineDrift = Duration.zero;

    final adherenceData = <DeadlineAdherencePoint>[];

    for (final task in completedTasksWithDueDates) {
      if (task.completedAt != null && task.dueDate != null) {
        final drift = task.completedAt!.difference(task.dueDate!);
        totalDeadlineDrift += drift.abs();

        final adherencePoint = DeadlineAdherencePoint(
          taskId: task.id,
          dueDate: task.dueDate!,
          completedAt: task.completedAt!,
          drift: drift,
          priority: task.priority,
          wasOnTime: drift.inHours.abs() <= 2, // Within 2 hours is "on time"
        );

        adherenceData.add(adherencePoint);

        if (drift.inHours.abs() <= 2) {
          onTimeCompletions++;
        } else if (drift.isNegative) {
          earlyCompletions++;
        } else {
          lateCompletions++;
        }
      }
    }

    final averageDeadlineDrift = completedTasksWithDueDates.isNotEmpty
        ? totalDeadlineDrift ~/ completedTasksWithDueDates.length
        : Duration.zero;

    return DeadlineAdherenceMetrics(
      totalTasksWithDeadlines: tasksWithDueDates.length,
      completedWithDeadlines: completedTasksWithDueDates.length,
      onTimeCompletions: onTimeCompletions,
      earlyCompletions: earlyCompletions,
      lateCompletions: lateCompletions,
      averageDeadlineDrift: averageDeadlineDrift,
      adherenceRate: completedTasksWithDueDates.isNotEmpty
          ? onTimeCompletions / completedTasksWithDueDates.length
          : 0.0,
      adherenceData: adherenceData,
      worstDeadlineMiss: _getWorstDeadlineMiss(adherenceData),
    );
  }

  /// Get category performance (based on labels/tags)
  Future<CategoryPerformance> getCategoryPerformance(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final tasksWithLabels =
        await _getTasksWithLabelsInRange(startDate, endDate);
    final categoryStats = <String, CategoryStats>{};

    for (final task in tasksWithLabels) {
      if (task.labels?.isNotEmpty == true) {
        final labels = task.labels!.split(',').map((l) => l.trim()).toList();

        for (final label in labels) {
          if (label.isNotEmpty) {
            final existing = categoryStats[label] ??
                CategoryStats(
                  category: label,
                  totalTasks: 0,
                  completedTasks: 0,
                  totalEstimatedMinutes: 0,
                  totalActualMinutes: 0,
                  averageCompletionTime: Duration.zero,
                );

            categoryStats[label] = CategoryStats(
              category: label,
              totalTasks: existing.totalTasks + 1,
              completedTasks: existing.completedTasks +
                  (task.status == TaskStatus.completed ? 1 : 0),
              totalEstimatedMinutes:
                  existing.totalEstimatedMinutes + (task.estimatedMinutes ?? 0),
              totalActualMinutes:
                  existing.totalActualMinutes + (task.actualMinutes ?? 0),
              averageCompletionTime:
                  existing.averageCompletionTime, // Will calculate later
            );
          }
        }
      }
    }

    // Calculate average completion times
    for (final entry in categoryStats.entries) {
      final stats = entry.value;
      final categoryTasks = tasksWithLabels
          .where((t) => t.labels?.contains(entry.key) == true)
          .toList();

      final avgCompletionTime = _calculateAverageCompletionTime(categoryTasks);

      categoryStats[entry.key] = CategoryStats(
        category: stats.category,
        totalTasks: stats.totalTasks,
        completedTasks: stats.completedTasks,
        totalEstimatedMinutes: stats.totalEstimatedMinutes,
        totalActualMinutes: stats.totalActualMinutes,
        averageCompletionTime: avgCompletionTime,
      );
    }

    return CategoryPerformance(
      categoryStats: categoryStats,
      mostProductiveCategory: _getMostProductiveCategory(categoryStats),
      slowestCategory: _getSlowestCategory(categoryStats),
    );
  }

  /// Get productivity insights and recommendations
  Future<ProductivityInsights> getProductivityInsights(
    ProductivityAnalytics analytics,
  ) async {
    final insights = <ProductivityInsight>[];

    // Time estimation insights
    if (analytics.timeAccuracyStats.totalTasksWithTime > 5) {
      if (analytics.timeAccuracyStats.overallAccuracy < 0.8) {
        insights.add(ProductivityInsight(
          type: InsightType.timeEstimation,
          title: 'Improve Time Estimation',
          description:
              'You tend to underestimate task duration. Try adding 25% buffer time.',
          impact: InsightImpact.medium,
          actionable: true,
        ));
      } else if (analytics.timeAccuracyStats.overallAccuracy > 1.3) {
        insights.add(ProductivityInsight(
          type: InsightType.timeEstimation,
          title: 'More Ambitious Estimates',
          description:
              'You consistently overestimate. Try reducing estimates by 20%.',
          impact: InsightImpact.low,
          actionable: true,
        ));
      }
    }

    // Completion rate insights
    if (analytics.completionStats.completionRate < 0.6) {
      insights.add(ProductivityInsight(
        type: InsightType.completion,
        title: 'Focus on Task Completion',
        description:
            'Only ${(analytics.completionStats.completionRate * 100).round()}% of tasks are completed. Try smaller, more achievable tasks.',
        impact: InsightImpact.high,
        actionable: true,
      ));
    }

    // Deadline adherence insights
    if (analytics.deadlineMetrics.adherenceRate < 0.7) {
      insights.add(ProductivityInsight(
        type: InsightType.deadlines,
        title: 'Improve Deadline Planning',
        description:
            'Consider setting more realistic deadlines or breaking large tasks into smaller ones.',
        impact: InsightImpact.high,
        actionable: true,
      ));
    }

    // Productivity pattern insights
    final mostProductiveHour = analytics.productivityTrends.mostProductiveHour;
    if (mostProductiveHour != null) {
      insights.add(ProductivityInsight(
        type: InsightType.timing,
        title: 'Optimize Your Schedule',
        description:
            'You\'re most productive at ${_formatHour(mostProductiveHour)}. Schedule important tasks then.',
        impact: InsightImpact.medium,
        actionable: true,
      ));
    }

    return ProductivityInsights(
      insights: insights,
      overallScore: _calculateOverallProductivityScore(analytics),
      recommendations: _generateRecommendations(analytics),
    );
  }

  /// Export analytics data as CSV
  Future<String> exportAnalyticsAsCSV(ProductivityAnalytics analytics) async {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
        'Date,Tasks Completed,Tasks Created,Completion Rate,Time Spent (min)');

    // Daily data
    final allDates = <DateTime>{
      ...analytics.completionStats.completionsByDate.keys,
      ...analytics.completionStats.creationsByDate.keys,
    }.toList()
      ..sort();

    for (final date in allDates) {
      final completed = analytics.completionStats.completionsByDate[date] ?? 0;
      final created = analytics.completionStats.creationsByDate[date] ?? 0;
      final rate =
          created > 0 ? (completed / created * 100).toStringAsFixed(1) : '0.0';

      // Find total time spent on this date
      final dayTrend = analytics.productivityTrends.dailyTrends
          .where((t) => _isSameDay(t.date, date))
          .firstOrNull;
      final timeSpent = dayTrend?.totalMinutesSpent ?? 0;

      buffer.writeln(
          '${DateFormat('yyyy-MM-dd').format(date)},$completed,$created,$rate%,$timeSpent');
    }

    return buffer.toString();
  }

  // Helper methods

  Future<List<NoteTask>> _getCompletedTasksInRange(
      DateTime start, DateTime end) async {
    try {
      final tasks = await _db.getCompletedTasks();
      return tasks
          .where((t) =>
              t.completedAt != null &&
              t.completedAt!.isAfter(start.subtract(const Duration(days: 1))) &&
              t.completedAt!.isBefore(end.add(const Duration(days: 1))))
          .toList();
    } catch (e) {
      _logger.error('Error getting completed tasks: $e');
      return [];
    }
  }

  Future<List<NoteTask>> _getAllTasksInRange(
      DateTime start, DateTime end) async {
    try {
      // Use getAllTasks and filter by date range since getTasksByDateRange might not exist
      final allTasks = await _db.getAllTasks();
      return allTasks
          .where((t) =>
              t.createdAt.isAfter(start.subtract(const Duration(days: 1))) &&
              t.createdAt.isBefore(end.add(const Duration(days: 1))))
          .toList();
    } catch (e) {
      _logger.error('Error getting tasks in range: $e');
      return [];
    }
  }

  Future<List<NoteTask>> _getTasksWithTimeTracking(
      DateTime start, DateTime end) async {
    final tasks = await _getCompletedTasksInRange(start, end);
    return tasks
        .where((t) =>
            t.estimatedMinutes != null &&
            t.actualMinutes != null &&
            t.estimatedMinutes! > 0 &&
            t.actualMinutes! > 0)
        .toList();
  }

  Future<List<NoteTask>> _getTasksWithDueDatesInRange(
      DateTime start, DateTime end) async {
    final tasks = await _getAllTasksInRange(start, end);
    return tasks.where((t) => t.dueDate != null).toList();
  }

  Future<List<NoteTask>> _getTasksWithLabelsInRange(
      DateTime start, DateTime end) async {
    final tasks = await _getAllTasksInRange(start, end);
    return tasks.where((t) => t.labels?.isNotEmpty == true).toList();
  }

  int _calculateCompletionStreak(Map<DateTime, int> completionsByDate) {
    final sortedDates = completionsByDate.keys.toList()..sort();
    if (sortedDates.isEmpty) return 0;

    var streak = 0;
    final today = DateTime.now();
    var currentDate = DateTime(today.year, today.month, today.day);

    while (completionsByDate.containsKey(currentDate) &&
        completionsByDate[currentDate]! > 0) {
      streak++;
      currentDate = currentDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  DateTime? _getBestCompletionDay(Map<DateTime, int> completionsByDate) {
    if (completionsByDate.isEmpty) return null;

    return completionsByDate.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  double _calculateAverageEstimationError(List<TimeAccuracyPoint> data) {
    if (data.isEmpty) return 0.0;

    final errors = data.map((d) => (d.accuracy - 1.0).abs()).toList();
    return errors.reduce((a, b) => a + b) / errors.length;
  }

  double _calculateImprovementTrend(List<TimeAccuracyPoint> data) {
    if (data.length < 2) return 0.0;

    // Sort by date
    data.sort((a, b) => a.date.compareTo(b.date));

    // Calculate trend using simple linear regression
    final firstHalf = data.take(data.length ~/ 2).toList();
    final secondHalf = data.skip(data.length ~/ 2).toList();

    final firstAvg = firstHalf.map((d) => d.accuracy).reduce((a, b) => a + b) /
        firstHalf.length;
    final secondAvg =
        secondHalf.map((d) => d.accuracy).reduce((a, b) => a + b) /
            secondHalf.length;

    return secondAvg - firstAvg; // Positive = improving, negative = declining
  }

  int _daysBetween(DateTime start, DateTime end) {
    return end.difference(start).inDays + 1;
  }

  DateTime _getWeekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return date.subtract(Duration(days: daysFromMonday));
  }

  int? _getMostProductiveHour(Map<int, int> hourlyDistribution) {
    if (hourlyDistribution.isEmpty) return null;

    return hourlyDistribution.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  DateTime? _getMostProductiveDay(List<NoteTask> weekTasks) {
    if (weekTasks.isEmpty) return null;

    final dayCount = <DateTime, int>{};
    for (final task in weekTasks) {
      if (task.completedAt != null) {
        final date = DateTime(
          task.completedAt!.year,
          task.completedAt!.month,
          task.completedAt!.day,
        );
        dayCount[date] = (dayCount[date] ?? 0) + 1;
      }
    }

    return dayCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double _calculateAverageTasksPerDay(
      Map<DateTime, DailyProductivity> dailyTrends) {
    if (dailyTrends.isEmpty) return 0.0;

    final totalTasks =
        dailyTrends.values.map((d) => d.tasksCompleted).reduce((a, b) => a + b);

    return totalTasks / dailyTrends.length;
  }

  double _calculateProductivityScore(
    Map<DateTime, DailyProductivity> dailyTrends,
    Map<DateTime, WeeklyProductivity> weeklyTrends,
  ) {
    // Complex scoring algorithm considering multiple factors
    var score = 0.0;

    // Consistency factor (30%)
    if (dailyTrends.isNotEmpty) {
      final taskCounts =
          dailyTrends.values.map((d) => d.tasksCompleted.toDouble()).toList();
      final avg = taskCounts.reduce((a, b) => a + b) / taskCounts.length;
      final variance =
          taskCounts.map((c) => pow(c - avg, 2)).reduce((a, b) => a + b) /
              taskCounts.length;
      final consistency =
          1.0 / (1.0 + variance); // Lower variance = higher consistency
      score += consistency * 0.3;
    }

    // Volume factor (40%)
    final avgTasksPerDay = _calculateAverageTasksPerDay(dailyTrends);
    final volumeScore =
        min(avgTasksPerDay / 10.0, 1.0); // Normalize to max 10 tasks/day
    score += volumeScore * 0.4;

    // Trend factor (30%)
    if (weeklyTrends.length >= 2) {
      final weeks = weeklyTrends.values.toList()
        ..sort((a, b) => a.weekStart.compareTo(b.weekStart));
      final firstWeek = weeks.first.tasksCompleted;
      final lastWeek = weeks.last.tasksCompleted;
      final trendScore = lastWeek > firstWeek ? 0.3 : 0.1;
      score += trendScore;
    }

    return (score * 100).clamp(0.0, 100.0);
  }

  Duration _calculateAverageCompletionTime(List<NoteTask> tasks) {
    final tasksWithCompletionTime =
        tasks.where((t) => t.completedAt != null).toList();

    if (tasksWithCompletionTime.isEmpty) return Duration.zero;

    final totalDuration = tasksWithCompletionTime
        .map((t) => t.completedAt!.difference(t.createdAt))
        .reduce((a, b) => a + b);

    return Duration(
      milliseconds:
          totalDuration.inMilliseconds ~/ tasksWithCompletionTime.length,
    );
  }

  double _calculateAverageEstimatedTime(List<NoteTask> tasks) {
    final tasksWithEstimates =
        tasks.where((t) => t.estimatedMinutes != null).toList();
    if (tasksWithEstimates.isEmpty) return 0.0;

    final total = tasksWithEstimates
        .map((t) => t.estimatedMinutes!)
        .reduce((a, b) => a + b);

    return total / tasksWithEstimates.length;
  }

  double _calculateAverageActualTime(List<NoteTask> tasks) {
    final tasksWithActual =
        tasks.where((t) => t.actualMinutes != null).toList();
    if (tasksWithActual.isEmpty) return 0.0;

    final total =
        tasksWithActual.map((t) => t.actualMinutes!).reduce((a, b) => a + b);

    return total / tasksWithActual.length;
  }

  TaskPriority? _getMostCompletedPriority(
      Map<TaskPriority, PriorityStats> distribution) {
    if (distribution.isEmpty) return null;

    return distribution.entries
        .reduce(
            (a, b) => a.value.completedTasks > b.value.completedTasks ? a : b)
        .key;
  }

  TaskPriority? _getFastestCompletingPriority(
      Map<TaskPriority, PriorityStats> distribution) {
    final withCompletionTimes = distribution.entries
        .where((e) => e.value.averageTimeToComplete != Duration.zero)
        .toList();

    if (withCompletionTimes.isEmpty) return null;

    return withCompletionTimes
        .reduce((a, b) =>
            a.value.averageTimeToComplete < b.value.averageTimeToComplete
                ? a
                : b)
        .key;
  }

  DeadlineAdherencePoint? _getWorstDeadlineMiss(
      List<DeadlineAdherencePoint> data) {
    final lateTasks = data.where((d) => d.drift.isNegative == false).toList();
    if (lateTasks.isEmpty) return null;

    return lateTasks.reduce((a, b) => a.drift > b.drift ? a : b);
  }

  String? _getMostProductiveCategory(Map<String, CategoryStats> categoryStats) {
    if (categoryStats.isEmpty) return null;

    return categoryStats.entries
        .reduce(
            (a, b) => a.value.completedTasks > b.value.completedTasks ? a : b)
        .key;
  }

  String? _getSlowestCategory(Map<String, CategoryStats> categoryStats) {
    final withCompletionTimes = categoryStats.entries
        .where((e) => e.value.averageCompletionTime != Duration.zero)
        .toList();

    if (withCompletionTimes.isEmpty) return null;

    return withCompletionTimes
        .reduce((a, b) =>
            a.value.averageCompletionTime > b.value.averageCompletionTime
                ? a
                : b)
        .key;
  }

  double _calculateOverallProductivityScore(ProductivityAnalytics analytics) {
    var score = 0.0;
    var factors = 0;

    // Completion rate (25%)
    score += analytics.completionStats.completionRate * 25;
    factors++;

    // Time accuracy (25%)
    if (analytics.timeAccuracyStats.totalTasksWithTime > 0) {
      final accuracy = 1.0 - analytics.timeAccuracyStats.averageEstimationError;
      score += accuracy.clamp(0.0, 1.0) * 25;
      factors++;
    }

    // Deadline adherence (25%)
    score += analytics.deadlineMetrics.adherenceRate * 25;
    factors++;

    // Consistency (25%)
    final trends = analytics.productivityTrends;
    if (trends.dailyTrends.isNotEmpty) {
      score += (trends.productivityScore / 100) * 25;
      factors++;
    }

    return factors > 0 ? score / factors : 0.0;
  }

  List<String> _generateRecommendations(ProductivityAnalytics analytics) {
    final recommendations = <String>[];

    if (analytics.completionStats.completionRate < 0.7) {
      recommendations
          .add('Break large tasks into smaller, more manageable pieces');
    }

    if (analytics.timeAccuracyStats.overallAccuracy < 0.8) {
      recommendations.add('Add buffer time to your estimates (try 25% extra)');
    }

    if (analytics.deadlineMetrics.adherenceRate < 0.8) {
      recommendations
          .add('Set more realistic deadlines or use earlier reminder times');
    }

    final mostProductiveHour = analytics.productivityTrends.mostProductiveHour;
    if (mostProductiveHour != null) {
      recommendations.add(
          'Schedule important tasks around ${_formatHour(mostProductiveHour)} when you\'re most productive');
    }

    return recommendations;
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour < 12) return '$hour:00 AM';
    if (hour == 12) return '12:00 PM';
    return '${hour - 12}:00 PM';
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}

/// Main analytics data container
class ProductivityAnalytics {
  const ProductivityAnalytics({
    required this.dateRange,
    required this.completionStats,
    required this.timeAccuracyStats,
    required this.productivityTrends,
    required this.priorityDistribution,
    required this.deadlineMetrics,
    required this.categoryPerformance,
    required this.generatedAt,
  });

  final DateRange dateRange;
  final TaskCompletionStats completionStats;
  final TimeEstimationAccuracy timeAccuracyStats;
  final ProductivityTrends productivityTrends;
  final PriorityDistribution priorityDistribution;
  final DeadlineAdherenceMetrics deadlineMetrics;
  final CategoryPerformance categoryPerformance;
  final DateTime generatedAt;
}

/// Date range for analytics
class DateRange {
  const DateRange({required this.start, required this.end});
  final DateTime start;
  final DateTime end;

  int get days => end.difference(start).inDays + 1;
}

/// Task completion statistics
class TaskCompletionStats {
  const TaskCompletionStats({
    required this.totalCompleted,
    required this.totalCreated,
    required this.completionRate,
    required this.averagePerDay,
    required this.completionsByDate,
    required this.creationsByDate,
    required this.currentStreak,
    this.bestDay,
  });

  final int totalCompleted;
  final int totalCreated;
  final double completionRate;
  final double averagePerDay;
  final Map<DateTime, int> completionsByDate;
  final Map<DateTime, int> creationsByDate;
  final int currentStreak;
  final DateTime? bestDay;
}

/// Time estimation accuracy data
class TimeEstimationAccuracy {
  const TimeEstimationAccuracy({
    required this.totalTasksWithTime,
    required this.overallAccuracy,
    required this.averageEstimationError,
    required this.accurateEstimates,
    required this.underEstimates,
    required this.overEstimates,
    required this.totalEstimatedMinutes,
    required this.totalActualMinutes,
    required this.accuracyData,
    required this.improvementTrend,
  });

  final int totalTasksWithTime;
  final double overallAccuracy;
  final double averageEstimationError;
  final int accurateEstimates;
  final int underEstimates;
  final int overEstimates;
  final int totalEstimatedMinutes;
  final int totalActualMinutes;
  final List<TimeAccuracyPoint> accuracyData;
  final double improvementTrend;

  factory TimeEstimationAccuracy.empty() {
    return const TimeEstimationAccuracy(
      totalTasksWithTime: 0,
      overallAccuracy: 0.0,
      averageEstimationError: 0.0,
      accurateEstimates: 0,
      underEstimates: 0,
      overEstimates: 0,
      totalEstimatedMinutes: 0,
      totalActualMinutes: 0,
      accuracyData: [],
      improvementTrend: 0.0,
    );
  }
}

/// Individual time accuracy data point
class TimeAccuracyPoint {
  const TimeAccuracyPoint({
    required this.taskId,
    required this.estimated,
    required this.actual,
    required this.accuracy,
    required this.date,
    required this.priority,
  });

  final String taskId;
  final int estimated;
  final int actual;
  final double accuracy;
  final DateTime date;
  final TaskPriority priority;
}

/// Productivity trends over time
class ProductivityTrends {
  const ProductivityTrends({
    required this.dailyTrends,
    required this.weeklyTrends,
    required this.hourlyDistribution,
    required this.averageTasksPerDay,
    required this.productivityScore,
    this.mostProductiveHour,
  });

  final List<DailyProductivity> dailyTrends;
  final List<WeeklyProductivity> weeklyTrends;
  final Map<int, int> hourlyDistribution;
  final double averageTasksPerDay;
  final double productivityScore;
  final int? mostProductiveHour;
}

/// Daily productivity data
class DailyProductivity {
  const DailyProductivity({
    required this.date,
    required this.tasksCompleted,
    required this.totalMinutesSpent,
    required this.averageTaskTime,
    required this.priorityBreakdown,
  });

  final DateTime date;
  final int tasksCompleted;
  final int totalMinutesSpent;
  final double averageTaskTime;
  final Map<TaskPriority, int> priorityBreakdown;
}

/// Weekly productivity data
class WeeklyProductivity {
  const WeeklyProductivity({
    required this.weekStart,
    required this.tasksCompleted,
    required this.totalMinutesSpent,
    required this.averageTasksPerDay,
    this.mostProductiveDay,
  });

  final DateTime weekStart;
  final int tasksCompleted;
  final int totalMinutesSpent;
  final double averageTasksPerDay;
  final DateTime? mostProductiveDay;
}

/// Priority distribution statistics
class PriorityDistribution {
  const PriorityDistribution({
    required this.distribution,
    this.mostCompletedPriority,
    this.fastestCompletingPriority,
  });

  final Map<TaskPriority, PriorityStats> distribution;
  final TaskPriority? mostCompletedPriority;
  final TaskPriority? fastestCompletingPriority;
}

/// Statistics for a specific priority level
class PriorityStats {
  const PriorityStats({
    required this.priority,
    required this.totalTasks,
    required this.completedTasks,
    required this.completionRate,
    required this.averageTimeToComplete,
    required this.averageEstimatedTime,
    required this.averageActualTime,
  });

  final TaskPriority priority;
  final int totalTasks;
  final int completedTasks;
  final double completionRate;
  final Duration averageTimeToComplete;
  final double averageEstimatedTime;
  final double averageActualTime;
}

/// Deadline adherence metrics
class DeadlineAdherenceMetrics {
  const DeadlineAdherenceMetrics({
    required this.totalTasksWithDeadlines,
    required this.completedWithDeadlines,
    required this.onTimeCompletions,
    required this.earlyCompletions,
    required this.lateCompletions,
    required this.averageDeadlineDrift,
    required this.adherenceRate,
    required this.adherenceData,
    this.worstDeadlineMiss,
  });

  final int totalTasksWithDeadlines;
  final int completedWithDeadlines;
  final int onTimeCompletions;
  final int earlyCompletions;
  final int lateCompletions;
  final Duration averageDeadlineDrift;
  final double adherenceRate;
  final List<DeadlineAdherencePoint> adherenceData;
  final DeadlineAdherencePoint? worstDeadlineMiss;
}

/// Individual deadline adherence data point
class DeadlineAdherencePoint {
  const DeadlineAdherencePoint({
    required this.taskId,
    required this.dueDate,
    required this.completedAt,
    required this.drift,
    required this.priority,
    required this.wasOnTime,
  });

  final String taskId;
  final DateTime dueDate;
  final DateTime completedAt;
  final Duration drift;
  final TaskPriority priority;
  final bool wasOnTime;
}

/// Category performance data
class CategoryPerformance {
  const CategoryPerformance({
    required this.categoryStats,
    this.mostProductiveCategory,
    this.slowestCategory,
  });

  final Map<String, CategoryStats> categoryStats;
  final String? mostProductiveCategory;
  final String? slowestCategory;
}

/// Statistics for a specific category/label
class CategoryStats {
  const CategoryStats({
    required this.category,
    required this.totalTasks,
    required this.completedTasks,
    required this.totalEstimatedMinutes,
    required this.totalActualMinutes,
    required this.averageCompletionTime,
  });

  final String category;
  final int totalTasks;
  final int completedTasks;
  final int totalEstimatedMinutes;
  final int totalActualMinutes;
  final Duration averageCompletionTime;

  double get completionRate =>
      totalTasks > 0 ? completedTasks / totalTasks : 0.0;
  double get timeAccuracy => totalEstimatedMinutes > 0
      ? totalActualMinutes / totalEstimatedMinutes
      : 0.0;
}

/// Productivity insights and recommendations
class ProductivityInsights {
  const ProductivityInsights({
    required this.insights,
    required this.overallScore,
    required this.recommendations,
  });

  final List<ProductivityInsight> insights;
  final double overallScore;
  final List<String> recommendations;
}

/// Individual productivity insight
class ProductivityInsight {
  const ProductivityInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.impact,
    required this.actionable,
  });

  final InsightType type;
  final String title;
  final String description;
  final InsightImpact impact;
  final bool actionable;
}

/// Types of insights
enum InsightType {
  timeEstimation,
  completion,
  deadlines,
  timing,
  priority,
  category,
}

/// Impact levels for insights
enum InsightImpact { low, medium, high }
