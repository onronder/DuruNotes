import 'dart:async';
import 'dart:math' as math;

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/task_analytics_service.dart';

/// Type of insight being generated
enum InsightType {
  pattern,
  recommendation,
  prediction,
  achievement,
  warning,
}

/// Represents an AI-generated insight
class Insight {
  final String id;
  final InsightType type;
  final String title;
  final String description;
  final String? actionText;
  final VoidCallback? action;
  final DateTime generatedAt;
  final Map<String, dynamic>? metadata;
  
  Insight({
    required this.type,
    required this.title,
    required this.description,
    this.actionText,
    this.action,
    this.metadata,
  })  : id = DateTime.now().millisecondsSinceEpoch.toString(),
        generatedAt = DateTime.now();
}

/// Service for generating AI-powered insights from analytics
class AIInsightsService {
  AIInsightsService();
  
  final AppLogger _logger = LoggerFactory.instance;
  
  /// Generate insights from productivity analytics
  Future<List<Insight>> generateInsights(ProductivityAnalytics analytics) async {
    final insights = <Insight>[];
    
    try {
      // Pattern detection insights
      insights.addAll(await _detectPatterns(analytics));
      
      // Recommendation insights
      insights.addAll(await _generateRecommendations(analytics));
      
      // Prediction insights
      insights.addAll(await _generatePredictions(analytics));
      
      // Achievement insights
      insights.addAll(await _checkAchievements(analytics));
      
      // Warning insights
      insights.addAll(await _generateWarnings(analytics));
      
      _logger.info('Generated AI insights', data: {
        'insightCount': insights.length,
        'types': insights.map((i) => i.type.name).toSet().toList(),
      });
    } catch (e, stack) {
      _logger.error('Failed to generate AI insights', error: e, stackTrace: stack);
    }
    
    return insights;
  }
  
  /// Detect patterns in productivity data
  Future<List<Insight>> _detectPatterns(ProductivityAnalytics analytics) async {
    final insights = <Insight>[];
    
    // Peak productivity hour detection
    final hourlyDistribution = analytics.productivityTrends.hourlyDistribution;
    if (hourlyDistribution.isNotEmpty) {
      final peakHour = _findPeakHour(hourlyDistribution);
      if (peakHour != null) {
        insights.add(Insight(
          type: InsightType.pattern,
          title: 'Peak Productivity Time',
          description: 'You complete most tasks around ${peakHour}:00. '
              'Consider scheduling your most important work during this time for maximum efficiency.',
          metadata: {'peakHour': peakHour},
        ));
      }
    }
    
    // Weekly pattern detection
    final weeklyPattern = analytics.productivityTrends.weeklyPattern;
    if (weeklyPattern.isNotEmpty) {
      final bestDay = _findBestDayOfWeek(weeklyPattern);
      if (bestDay != null) {
        insights.add(Insight(
          type: InsightType.pattern,
          title: 'Most Productive Day',
          description: 'You tend to be most productive on ${bestDay}s. '
              'Plan challenging tasks for this day when your energy is highest.',
          metadata: {'bestDay': bestDay},
        ));
      }
    }
    
    // Task completion patterns
    if (analytics.completionStats.averagePerDay > 0) {
      final avgPerDay = analytics.completionStats.averagePerDay;
      insights.add(Insight(
        type: InsightType.pattern,
        title: 'Daily Task Average',
        description: 'You complete an average of ${avgPerDay.toStringAsFixed(1)} tasks per day. '
            '${_getAverageMessage(avgPerDay)}',
        metadata: {'averagePerDay': avgPerDay},
      ));
    }
    
    return insights;
  }
  
  /// Generate recommendations based on analytics
  Future<List<Insight>> _generateRecommendations(ProductivityAnalytics analytics) async {
    final insights = <Insight>[];
    
    // Time estimation accuracy recommendation
    if (analytics.timeAccuracyStats.accuracyPercentage < 70) {
      final accuracy = analytics.timeAccuracyStats.accuracyPercentage;
      final tendency = analytics.timeAccuracyStats.averageDeviation > 0 
          ? 'overestimate' : 'underestimate';
      
      insights.add(Insight(
        type: InsightType.recommendation,
        title: 'Improve Time Estimates',
        description: 'Your time estimates are off by ${(100 - accuracy).toStringAsFixed(0)}%. '
            'You tend to $tendency task duration. Try breaking tasks into smaller chunks '
            'for better accuracy.',
        actionText: 'View Tips',
        metadata: {
          'accuracy': accuracy,
          'tendency': tendency,
        },
      ));
    }
    
    // Priority balance recommendation
    final priorityDist = analytics.priorityDistribution;
    final highPriorityRatio = priorityDist.highPriorityCount / 
        (priorityDist.totalCount > 0 ? priorityDist.totalCount : 1);
    
    if (highPriorityRatio > 0.5) {
      insights.add(Insight(
        type: InsightType.recommendation,
        title: 'Priority Balance',
        description: 'Over ${(highPriorityRatio * 100).toStringAsFixed(0)}% of your tasks are marked as high priority. '
            'Consider re-evaluating task priorities to focus on what truly matters.',
        actionText: 'Review Priorities',
        metadata: {'highPriorityRatio': highPriorityRatio},
      ));
    }
    
    // Deadline adherence recommendation
    if (analytics.deadlineMetrics.onTimePercentage < 80) {
      final onTimeRate = analytics.deadlineMetrics.onTimePercentage;
      insights.add(Insight(
        type: InsightType.recommendation,
        title: 'Improve Deadline Management',
        description: 'You meet deadlines ${onTimeRate.toStringAsFixed(0)}% of the time. '
            'Try setting earlier personal deadlines to create buffer time.',
        metadata: {'onTimeRate': onTimeRate},
      ));
    }
    
    return insights;
  }
  
  /// Generate predictions based on trends
  Future<List<Insight>> _generatePredictions(ProductivityAnalytics analytics) async {
    final insights = <Insight>[];
    
    // Weekly completion prediction
    final weeklyAverage = analytics.completionStats.averagePerDay * 7;
    final predictedWeekly = _predictWeeklyCompletion(analytics);
    
    insights.add(Insight(
      type: InsightType.prediction,
      title: 'Weekly Forecast',
      description: 'Based on your current patterns, you\'re likely to complete '
          '${predictedWeekly.toStringAsFixed(0)} tasks this week. '
          '${_getWeeklyPredictionMessage(predictedWeekly, weeklyAverage)}',
      metadata: {
        'predicted': predictedWeekly,
        'average': weeklyAverage,
      },
    ));
    
    // Streak prediction
    if (analytics.completionStats.currentStreak > 0) {
      final streakPrediction = _predictStreakContinuation(analytics);
      insights.add(Insight(
        type: InsightType.prediction,
        title: 'Streak Outlook',
        description: 'You have a ${(streakPrediction * 100).toStringAsFixed(0)}% chance '
            'of maintaining your ${analytics.completionStats.currentStreak}-day streak. '
            '${_getStreakMessage(streakPrediction)}',
        metadata: {
          'currentStreak': analytics.completionStats.currentStreak,
          'probability': streakPrediction,
        },
      ));
    }
    
    return insights;
  }
  
  /// Check for notable achievements
  Future<List<Insight>> _checkAchievements(ProductivityAnalytics analytics) async {
    final insights = <Insight>[];
    
    // Streak achievement
    if (analytics.completionStats.currentStreak >= analytics.completionStats.longestStreak &&
        analytics.completionStats.currentStreak > 7) {
      insights.add(Insight(
        type: InsightType.achievement,
        title: '🎉 New Streak Record!',
        description: 'You\'ve maintained a ${analytics.completionStats.currentStreak}-day streak! '
            'This is your longest streak ever. Keep up the amazing work!',
        metadata: {'streak': analytics.completionStats.currentStreak},
      ));
    }
    
    // Completion rate achievement
    if (analytics.completionStats.completionRate > 0.9) {
      insights.add(Insight(
        type: InsightType.achievement,
        title: '⭐ Outstanding Completion Rate',
        description: 'You\'ve completed ${(analytics.completionStats.completionRate * 100).toStringAsFixed(0)}% '
            'of your tasks! This is an exceptional achievement.',
        metadata: {'completionRate': analytics.completionStats.completionRate},
      ));
    }
    
    // Perfect day achievement
    final todayCompleted = analytics.completionStats.totalCompleted;
    if (todayCompleted >= 10) {
      insights.add(Insight(
        type: InsightType.achievement,
        title: '💪 Productivity Champion',
        description: 'You\'ve completed $todayCompleted tasks recently! '
            'You\'re in the top tier of productive users.',
        metadata: {'tasksCompleted': todayCompleted},
      ));
    }
    
    return insights;
  }
  
  /// Generate warnings for potential issues
  Future<List<Insight>> _generateWarnings(ProductivityAnalytics analytics) async {
    final insights = <Insight>[];
    
    // Overdue tasks warning
    if (analytics.deadlineMetrics.overdueCount > 5) {
      insights.add(Insight(
        type: InsightType.warning,
        title: '⚠️ Overdue Tasks',
        description: 'You have ${analytics.deadlineMetrics.overdueCount} overdue tasks. '
            'Consider reviewing and updating their deadlines or priorities.',
        actionText: 'Review Overdue',
        metadata: {'overdueCount': analytics.deadlineMetrics.overdueCount},
      ));
    }
    
    // Declining productivity warning
    final trend = analytics.productivityTrends.overallTrend;
    if (trend < -0.2) {
      insights.add(Insight(
        type: InsightType.warning,
        title: 'Productivity Decline',
        description: 'Your task completion has decreased by ${(trend.abs() * 100).toStringAsFixed(0)}% '
            'compared to last period. Consider reviewing your workload and priorities.',
        metadata: {'trend': trend},
      ));
    }
    
    // Streak at risk warning
    if (analytics.completionStats.currentStreak > 0 && 
        analytics.completionStats.todayCompleted == 0) {
      insights.add(Insight(
        type: InsightType.warning,
        title: '🔥 Streak at Risk',
        description: 'Complete at least one task today to maintain your '
            '${analytics.completionStats.currentStreak}-day streak!',
        actionText: 'View Tasks',
        metadata: {'currentStreak': analytics.completionStats.currentStreak},
      ));
    }
    
    return insights;
  }
  
  // Helper methods
  
  int? _findPeakHour(Map<int, int> hourlyDistribution) {
    if (hourlyDistribution.isEmpty) return null;
    
    var maxHour = 0;
    var maxCount = 0;
    
    hourlyDistribution.forEach((hour, count) {
      if (count > maxCount) {
        maxCount = count;
        maxHour = hour;
      }
    });
    
    return maxCount > 0 ? maxHour : null;
  }
  
  String? _findBestDayOfWeek(Map<int, double> weeklyPattern) {
    if (weeklyPattern.isEmpty) return null;
    
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    var maxDay = 0;
    var maxValue = 0.0;
    
    weeklyPattern.forEach((day, value) {
      if (value > maxValue) {
        maxValue = value;
        maxDay = day;
      }
    });
    
    return maxValue > 0 ? days[maxDay % 7] : null;
  }
  
  String _getAverageMessage(double avgPerDay) {
    if (avgPerDay < 3) {
      return 'Focus on completing a few key tasks each day to build momentum.';
    } else if (avgPerDay < 7) {
      return 'You\'re maintaining a good pace. Keep it consistent!';
    } else {
      return 'You\'re highly productive! Make sure to maintain work-life balance.';
    }
  }
  
  double _predictWeeklyCompletion(ProductivityAnalytics analytics) {
    final baseAverage = analytics.completionStats.averagePerDay * 7;
    final trend = analytics.productivityTrends.overallTrend;
    
    // Apply trend adjustment
    return baseAverage * (1 + trend);
  }
  
  double _predictStreakContinuation(ProductivityAnalytics analytics) {
    final currentStreak = analytics.completionStats.currentStreak;
    final longestStreak = analytics.completionStats.longestStreak;
    final completionRate = analytics.completionStats.completionRate;
    
    // Simple probability model
    var probability = completionRate;
    
    // Adjust based on current vs longest streak
    if (currentStreak >= longestStreak) {
      probability *= 0.9; // Harder to maintain record streaks
    } else {
      probability *= 1.1; // Easier to maintain shorter streaks
    }
    
    return probability.clamp(0.0, 1.0);
  }
  
  String _getWeeklyPredictionMessage(double predicted, double average) {
    final difference = predicted - average;
    if (difference.abs() < 1) {
      return 'This is on par with your usual performance.';
    } else if (difference > 0) {
      return 'You\'re trending ${difference.toStringAsFixed(0)} tasks above average!';
    } else {
      return 'This is ${difference.abs().toStringAsFixed(0)} tasks below average. Consider what might be affecting your productivity.';
    }
  }
  
  String _getStreakMessage(double probability) {
    if (probability > 0.8) {
      return 'Keep doing what you\'re doing!';
    } else if (probability > 0.5) {
      return 'Stay focused to maintain your streak.';
    } else {
      return 'Your streak might be at risk. Make sure to complete at least one task today.';
    }
  }
}

typedef VoidCallback = void Function();
