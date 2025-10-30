import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/task_analytics_service.dart';

/// Type of insight being generated
enum InsightType { pattern, recommendation, prediction, achievement, warning }

/// Represents an AI-generated insight
class Insight {
  Insight({
    required this.type,
    required this.title,
    required this.description,
    this.actionText,
    this.action,
    this.metadata,
  }) : id = DateTime.now().millisecondsSinceEpoch.toString(),
       generatedAt = DateTime.now();

  final String id;
  final InsightType type;
  final String title;
  final String description;
  final String? actionText;
  final void Function()? action;
  final DateTime generatedAt;
  final Map<String, dynamic>? metadata;
}

/// Service for generating AI-powered insights from analytics
class AIInsightsService {
  AIInsightsService();

  final AppLogger _logger = LoggerFactory.instance;

  /// Generate high level insights from productivity analytics
  Future<List<Insight>> generateInsights(
    ProductivityAnalytics analytics,
  ) async {
    final insights = <Insight>[];

    try {
      _addPeakHourInsight(analytics, insights);
      _addBestDayInsight(analytics, insights);
      _addAveragePerDayInsight(analytics, insights);
      _addTimeAccuracyInsight(analytics, insights);
      _addPriorityBalanceInsight(analytics, insights);
      _addDeadlineInsight(analytics, insights);
      _addStreakInsight(analytics, insights);

      _logger.info(
        'Generated AI insights',
        data: {
          'insightCount': insights.length,
          'types': insights.map((i) => i.type.name).toSet().toList(),
        },
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to generate AI insights',
        error: e,
        stackTrace: stack,
      );
    }

    return insights;
  }

  void _addPeakHourInsight(
    ProductivityAnalytics analytics,
    List<Insight> insights,
  ) {
    final peakHour = _findPeakHour(
      analytics.productivityTrends.hourlyDistribution,
    );
    if (peakHour == null) {
      return;
    }

    insights.add(
      Insight(
        type: InsightType.pattern,
        title: 'Peak Productivity Time',
        description:
            'You complete most tasks around ${peakHour.toString().padLeft(2, '0')}:00. '
            'Schedule important work for this window to take advantage of your focus.',
        metadata: {'peakHour': peakHour},
      ),
    );
  }

  void _addBestDayInsight(
    ProductivityAnalytics analytics,
    List<Insight> insights,
  ) {
    final weekdayTotals = <int, int>{};
    for (final daily in analytics.productivityTrends.dailyTrends) {
      final weekday = daily.date.weekday;
      weekdayTotals[weekday] =
          (weekdayTotals[weekday] ?? 0) + daily.tasksCompleted;
    }

    if (weekdayTotals.isEmpty) {
      return;
    }

    final bestEntry = weekdayTotals.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    if (bestEntry.value == 0) {
      return;
    }

    insights.add(
      Insight(
        type: InsightType.pattern,
        title: 'Most Productive Day',
        description:
            'You usually complete the most tasks on ${_weekdayLabel(bestEntry.key)}. '
            'Plan challenging work for this day when your momentum is strongest.',
        metadata: {'weekday': bestEntry.key, 'completedTasks': bestEntry.value},
      ),
    );
  }

  void _addAveragePerDayInsight(
    ProductivityAnalytics analytics,
    List<Insight> insights,
  ) {
    final avgPerDay = analytics.completionStats.averagePerDay;
    if (avgPerDay <= 0) {
      return;
    }

    insights.add(
      Insight(
        type: InsightType.pattern,
        title: 'Daily Task Average',
        description:
            'You complete an average of ${avgPerDay.toStringAsFixed(1)} tasks per day. '
            '${_getAverageMessage(avgPerDay)}',
        metadata: {'averagePerDay': avgPerDay},
      ),
    );
  }

  void _addTimeAccuracyInsight(
    ProductivityAnalytics analytics,
    List<Insight> insights,
  ) {
    final stats = analytics.timeAccuracyStats;
    if (stats.totalTasksWithTime == 0) {
      return;
    }

    final accuracyPercent = (stats.overallAccuracy * 100).clamp(0.0, 100.0);
    final tendency = stats.underEstimates > stats.overEstimates
        ? 'underestimate'
        : stats.overEstimates > stats.underEstimates
        ? 'overestimate'
        : 'vary';

    insights.add(
      Insight(
        type: InsightType.recommendation,
        title: 'Improve Time Estimates',
        description:
            'Your time estimates are accurate about ${accuracyPercent.toStringAsFixed(0)}% of the time. '
            'You tend to $tendency task durations. Review past estimates to refine your planning.',
        metadata: {
          'accuracyPercent': accuracyPercent,
          'underEstimates': stats.underEstimates,
          'overEstimates': stats.overEstimates,
        },
      ),
    );
  }

  void _addPriorityBalanceInsight(
    ProductivityAnalytics analytics,
    List<Insight> insights,
  ) {
    final distribution = analytics.priorityDistribution.distribution;
    if (distribution.isEmpty) {
      return;
    }

    final totalTasks = distribution.values.fold<int>(
      0,
      (sum, stats) => sum + stats.totalTasks,
    );
    if (totalTasks == 0) {
      return;
    }

    // ignore: collection_methods_unrelated_type
    final highPriorityCount = distribution[TaskPriority.high]?.totalTasks ?? 0;
    final ratio = highPriorityCount / totalTasks;

    if (ratio <= 0.5) {
      return;
    }

    insights.add(
      Insight(
        type: InsightType.recommendation,
        title: 'Priority Balance',
        description:
            'About ${(ratio * 100).toStringAsFixed(0)}% of your tasks are marked as high priority. '
            'Consider re-evaluating priorities so the most critical work stands out.',
        metadata: {'highPriorityRatio': ratio, 'totalTasks': totalTasks},
      ),
    );
  }

  void _addDeadlineInsight(
    ProductivityAnalytics analytics,
    List<Insight> insights,
  ) {
    final metrics = analytics.deadlineMetrics;
    if (metrics.totalTasksWithDeadlines == 0) {
      return;
    }

    final onTimeRate = (metrics.adherenceRate * 100).clamp(0.0, 100.0);
    if (onTimeRate >= 80) {
      return;
    }

    insights.add(
      Insight(
        type: InsightType.warning,
        title: 'Deadline Management',
        description:
            'You meet deadlines ${onTimeRate.toStringAsFixed(0)}% of the time. '
            'Try scheduling earlier reminders or breaking work into smaller checkpoints.',
        metadata: {
          'onTimeRate': onTimeRate,
          'totalWithDeadlines': metrics.totalTasksWithDeadlines,
        },
      ),
    );
  }

  void _addStreakInsight(
    ProductivityAnalytics analytics,
    List<Insight> insights,
  ) {
    final streak = analytics.completionStats.currentStreak;
    if (streak <= 0) {
      return;
    }

    insights.add(
      Insight(
        type: InsightType.achievement,
        title: 'Completion Streak',
        description:
            'Great job! You are on a $streak day completion streak. '
            'Complete at least one task today to keep it going.',
        metadata: {'streak': streak},
      ),
    );
  }

  int? _findPeakHour(Map<int, int> hourlyDistribution) {
    if (hourlyDistribution.isEmpty) {
      return null;
    }

    return hourlyDistribution.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  String _weekdayLabel(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    if (weekday < 1 || weekday > 7) {
      return 'Unknown';
    }
    return names[weekday - 1];
  }

  String _getAverageMessage(double avgPerDay) {
    if (avgPerDay < 3) {
      return 'Focus on finishing a few key tasks each day to build momentum.';
    }
    if (avgPerDay < 7) {
      return 'You\'re maintaining a strong pace. Keep it consistent!';
    }
    return 'Your productivity is very high—remember to balance rest and focused work.';
  }
}
