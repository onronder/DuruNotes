import 'dart:async';
import 'dart:convert';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/analytics/analytics_factory.dart';
import 'package:duru_notes/services/task_analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing productivity goals and tracking progress
class ProductivityGoalsService {
  ProductivityGoalsService({
    required AppDb database,
    required TaskAnalyticsService analyticsService,
  })  : _db = database,
        _analyticsService = analyticsService;

  final AppDb _db;
  final TaskAnalyticsService _analyticsService;
  final AppLogger _logger = LoggerFactory.instance;

  static const String _goalsKey = 'productivity_goals';
  static const String _achievementsKey = 'productivity_achievements';

  /// Get all active productivity goals
  Future<List<ProductivityGoal>> getActiveGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final goalsJson = prefs.getString(_goalsKey);

      if (goalsJson == null) return [];

      final goalsList = jsonDecode(goalsJson) as List<dynamic>;
      return goalsList
          .map(
              (json) => ProductivityGoal.fromJson(json as Map<String, dynamic>))
          .where((goal) => goal.isActive && !goal.isCompleted)
          .toList();
    } catch (e, stack) {
      _logger.error('Failed to load productivity goals',
          error: e, stackTrace: stack);
      return [];
    }
  }

  /// Save productivity goals
  Future<void> saveGoals(List<ProductivityGoal> goals) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final goalsJson = jsonEncode(goals.map((g) => g.toJson()).toList());
      await prefs.setString(_goalsKey, goalsJson);
    } catch (e, stack) {
      _logger.error('Failed to save productivity goals',
          error: e, stackTrace: stack);
    }
  }

  /// Create a new productivity goal
  Future<String> createGoal({
    required String title,
    required String description,
    required GoalType type,
    required GoalPeriod period,
    required double targetValue,
    DateTime? deadline,
    Map<String, dynamic>? metadata,
  }) async {
    final goal = ProductivityGoal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      type: type,
      period: period,
      targetValue: targetValue,
      currentValue: 0.0,
      startDate: DateTime.now(),
      deadline: deadline,
      isActive: true,
      isCompleted: false,
      metadata: metadata ?? {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final goals = await getActiveGoals();
    goals.add(goal);
    await saveGoals(goals);

    _logger.info('Created productivity goal', data: {
      'goalId': goal.id,
      'type': goal.type.name,
      'target': goal.targetValue,
    });

    return goal.id;
  }

  /// Update goal progress
  Future<void> updateGoalProgress(String goalId, double newValue) async {
    try {
      final goals = await getActiveGoals();
      final goalIndex = goals.indexWhere((g) => g.id == goalId);

      if (goalIndex == -1) return;

      final goal = goals[goalIndex];
      final updatedGoal = goal.copyWith(
        currentValue: newValue,
        isCompleted: newValue >= goal.targetValue,
        updatedAt: DateTime.now(),
      );

      goals[goalIndex] = updatedGoal;
      await saveGoals(goals);

      // Check for achievement
      if (updatedGoal.isCompleted && !goal.isCompleted) {
        await _recordAchievement(updatedGoal);
      }
    } catch (e, stack) {
      _logger.error('Failed to update goal progress',
          error: e, stackTrace: stack);
    }
  }

  /// Check and update all goal progress based on current analytics
  Future<void> updateAllGoalProgress() async {
    try {
      final goals = await getActiveGoals();
      if (goals.isEmpty) return;

      final now = DateTime.now();

      for (final goal in goals) {
        final currentValue = await _calculateCurrentGoalValue(goal, now);
        await updateGoalProgress(goal.id, currentValue);
      }
    } catch (e, stack) {
      _logger.error('Failed to update all goal progress',
          error: e, stackTrace: stack);
    }
  }

  /// Calculate current value for a goal based on its type and period
  Future<double> _calculateCurrentGoalValue(
      ProductivityGoal goal, DateTime now) async {
    final startDate = _getGoalPeriodStart(goal, now);
    final endDate = now;

    switch (goal.type) {
      case GoalType.tasksCompleted:
        final stats =
            await _analyticsService.getTaskCompletionStats(startDate, endDate);
        return stats.totalCompleted.toDouble();

      case GoalType.completionRate:
        final stats =
            await _analyticsService.getTaskCompletionStats(startDate, endDate);
        return stats.completionRate * 100; // Convert to percentage

      case GoalType.timeAccuracy:
        final accuracy = await _analyticsService.getTimeEstimationAccuracy(
            startDate, endDate);
        return accuracy.overallAccuracy * 100; // Convert to percentage

      case GoalType.dailyStreak:
        final stats =
            await _analyticsService.getTaskCompletionStats(startDate, endDate);
        return stats.currentStreak.toDouble();

      case GoalType.deadlineAdherence:
        final metrics = await _analyticsService.getDeadlineAdherenceMetrics(
            startDate, endDate);
        return metrics.adherenceRate * 100; // Convert to percentage

      case GoalType.timeSpent:
        final trends =
            await _analyticsService.getProductivityTrends(startDate, endDate);
        return trends.dailyTrends
            .map((d) => d.totalMinutesSpent)
            .fold(0, (a, b) => a + b)
            .toDouble();

      case GoalType.averageTasksPerDay:
        final trends =
            await _analyticsService.getProductivityTrends(startDate, endDate);
        return trends.averageTasksPerDay;
    }
  }

  /// Get start date for goal period
  DateTime _getGoalPeriodStart(ProductivityGoal goal, DateTime now) {
    switch (goal.period) {
      case GoalPeriod.daily:
        return DateTime(now.year, now.month, now.day);
      case GoalPeriod.weekly:
        final daysFromMonday = now.weekday - 1;
        return now.subtract(Duration(days: daysFromMonday));
      case GoalPeriod.monthly:
        return DateTime(now.year, now.month, 1);
      case GoalPeriod.yearly:
        return DateTime(now.year, 1, 1);
      case GoalPeriod.custom:
        return goal.startDate;
    }
  }

  /// Record achievement when goal is completed
  Future<void> _recordAchievement(ProductivityGoal goal) async {
    try {
      final achievement = ProductivityAchievement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        goalId: goal.id,
        title: goal.title,
        description: 'Achieved: ${goal.description}',
        achievedAt: DateTime.now(),
        goalType: goal.type,
        targetValue: goal.targetValue,
        achievedValue: goal.currentValue,
        period: goal.period,
      );

      final prefs = await SharedPreferences.getInstance();
      final achievementsJson = prefs.getString(_achievementsKey) ?? '[]';
      final achievements = (jsonDecode(achievementsJson) as List<dynamic>)
          .map((json) =>
              ProductivityAchievement.fromJson(json as Map<String, dynamic>))
          .toList();

      achievements.add(achievement);

      // Send achievement notification
      await _sendAchievementNotification(goal);

      final updatedJson =
          jsonEncode(achievements.map((a) => a.toJson()).toList());
      await prefs.setString(_achievementsKey, updatedJson);

      _logger.info('Recorded productivity achievement', data: {
        'goalId': goal.id,
        'achievementId': achievement.id,
      });
    } catch (e, stack) {
      _logger.error('Failed to record achievement',
          error: e, stackTrace: stack);
    }
  }

  /// Get productivity achievements
  Future<List<ProductivityAchievement>> getAchievements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final achievementsJson = prefs.getString(_achievementsKey) ?? '[]';

      final achievementsList = jsonDecode(achievementsJson) as List<dynamic>;
      return achievementsList
          .map((json) =>
              ProductivityAchievement.fromJson(json as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
    } catch (e, stack) {
      _logger.error('Failed to load achievements', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Delete a goal
  Future<void> deleteGoal(String goalId) async {
    try {
      final goals = await getActiveGoals();
      goals.removeWhere((g) => g.id == goalId);
      await saveGoals(goals);
    } catch (e, stack) {
      _logger.error('Failed to delete goal', error: e, stackTrace: stack);
    }
  }

  /// Get suggested goals based on user's analytics
  Future<List<ProductivityGoal>> getSuggestedGoals() async {
    try {
      final now = DateTime.now();
      final analytics = await _analyticsService.getProductivityAnalytics(
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now,
      );

      final suggestions = <ProductivityGoal>[];

      // Suggest completion rate improvement
      if (analytics.completionStats.completionRate < 0.8) {
        suggestions.add(ProductivityGoal(
          id: 'suggested_completion_rate',
          title: 'Improve Completion Rate',
          description: 'Achieve 80% task completion rate',
          type: GoalType.completionRate,
          period: GoalPeriod.monthly,
          targetValue: 80.0,
          currentValue: analytics.completionStats.completionRate * 100,
          startDate: now,
          isActive: false,
          isCompleted: false,
          metadata: {'suggested': true},
          createdAt: now,
          updatedAt: now,
        ));
      }

      // Suggest daily task goal
      if (analytics.completionStats.averagePerDay < 3) {
        suggestions.add(ProductivityGoal(
          id: 'suggested_daily_tasks',
          title: 'Daily Task Goal',
          description: 'Complete 5 tasks per day',
          type: GoalType.averageTasksPerDay,
          period: GoalPeriod.daily,
          targetValue: 5.0,
          currentValue: analytics.completionStats.averagePerDay,
          startDate: now,
          isActive: false,
          isCompleted: false,
          metadata: {'suggested': true},
          createdAt: now,
          updatedAt: now,
        ));
      }

      // Suggest time accuracy improvement
      if (analytics.timeAccuracyStats.overallAccuracy < 0.9) {
        suggestions.add(ProductivityGoal(
          id: 'suggested_time_accuracy',
          title: 'Better Time Estimates',
          description: 'Achieve 90% time estimation accuracy',
          type: GoalType.timeAccuracy,
          period: GoalPeriod.monthly,
          targetValue: 90.0,
          currentValue: analytics.timeAccuracyStats.overallAccuracy * 100,
          startDate: now,
          isActive: false,
          isCompleted: false,
          metadata: {'suggested': true},
          createdAt: now,
          updatedAt: now,
        ));
      }

      return suggestions;
    } catch (e, stack) {
      _logger.error('Failed to generate suggested goals',
          error: e, stackTrace: stack);
      return [];
    }
  }

  /// Activate a suggested goal
  Future<void> activateSuggestedGoal(ProductivityGoal suggestedGoal) async {
    final activeGoal = suggestedGoal.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isActive: true,
      startDate: DateTime.now(),
      metadata: {},
    );

    final goals = await getActiveGoals();
    goals.add(activeGoal);
    await saveGoals(goals);
  }

  /// Send achievement notification
  Future<void> _sendAchievementNotification(ProductivityGoal goal) async {
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidDetails = AndroidNotificationDetails(
        'goals_achievements',
        'Goal Achievements',
        channelDescription: 'Notifications for productivity goal achievements',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF4CAF50), // Green for success
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        goal.id.hashCode,
        '🎉 Goal Achieved!',
        'You completed your goal: ${goal.title}',
        notificationDetails,
      );

      // Log analytics event
      AnalyticsFactory.instance.event('goal.achieved', properties: {
        'goal_type': goal.type.toString(),
        'target_value': goal.targetValue,
        'period': goal.period.toString(),
      });
    } catch (e, stack) {
      _logger.error('Failed to send achievement notification',
          error: e, stackTrace: stack);
    }
  }

  /// Check and notify achievements periodically
  Future<void> checkAndNotifyAchievements() async {
    try {
      await updateAllGoalProgress();
    } catch (e, stack) {
      _logger.error('Failed to check achievements',
          error: e, stackTrace: stack);
    }
  }

  /// Get goal progress
  Future<double> getGoalProgress(String goalId) async {
    try {
      final goals = await getActiveGoals();
      final goal = goals.firstWhere((g) => g.id == goalId);
      return goal.currentValue / goal.targetValue;
    } catch (e) {
      return 0.0;
    }
  }

  /// Watch active goals stream
  Stream<List<ProductivityGoal>> watchActiveGoals() {
    // Create a stream controller
    final controller = StreamController<List<ProductivityGoal>>.broadcast();

    // Initial load
    getActiveGoals().then((goals) {
      if (!controller.isClosed) {
        controller.add(goals);
      }
    });

    // Periodic updates
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }

      getActiveGoals().then((goals) {
        if (!controller.isClosed) {
          controller.add(goals);
        }
      });
    });

    return controller.stream;
  }
}

/// Productivity goal model
class ProductivityGoal {
  const ProductivityGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.period,
    required this.targetValue,
    required this.currentValue,
    required this.startDate,
    required this.isActive,
    required this.isCompleted,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.deadline,
  });

  final String id;
  final String title;
  final String description;
  final GoalType type;
  final GoalPeriod period;
  final double targetValue;
  final double currentValue;
  final DateTime startDate;
  final DateTime? deadline;
  final bool isActive;
  final bool isCompleted;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Calculate progress percentage
  double get progressPercentage {
    if (targetValue <= 0) return 0.0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  /// Check if goal is overdue
  bool get isOverdue {
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline!) && !isCompleted;
  }

  /// Get days remaining (if deadline is set)
  int? get daysRemaining {
    if (deadline == null) return null;
    final remaining = deadline!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  ProductivityGoal copyWith({
    String? id,
    String? title,
    String? description,
    GoalType? type,
    GoalPeriod? period,
    double? targetValue,
    double? currentValue,
    DateTime? startDate,
    DateTime? deadline,
    bool? isActive,
    bool? isCompleted,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductivityGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      period: period ?? this.period,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      startDate: startDate ?? this.startDate,
      deadline: deadline ?? this.deadline,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'period': period.name,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'startDate': startDate.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'isActive': isActive,
      'isCompleted': isCompleted,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ProductivityGoal.fromJson(Map<String, dynamic> json) {
    return ProductivityGoal(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      type: GoalType.values.firstWhere((e) => e.name == json['type']),
      period: GoalPeriod.values.firstWhere((e) => e.name == json['period']),
      targetValue: (json['targetValue'] as num).toDouble(),
      currentValue: (json['currentValue'] as num).toDouble(),
      startDate: DateTime.parse(json['startDate'] as String),
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      isActive: json['isActive'] as bool,
      isCompleted: json['isCompleted'] as bool,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// Productivity achievement model
class ProductivityAchievement {
  const ProductivityAchievement({
    required this.id,
    required this.goalId,
    required this.title,
    required this.description,
    required this.achievedAt,
    required this.goalType,
    required this.targetValue,
    required this.achievedValue,
    required this.period,
  });

  final String id;
  final String goalId;
  final String title;
  final String description;
  final DateTime achievedAt;
  final GoalType goalType;
  final double targetValue;
  final double achievedValue;
  final GoalPeriod period;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'goalId': goalId,
      'title': title,
      'description': description,
      'achievedAt': achievedAt.toIso8601String(),
      'goalType': goalType.name,
      'targetValue': targetValue,
      'achievedValue': achievedValue,
      'period': period.name,
    };
  }

  factory ProductivityAchievement.fromJson(Map<String, dynamic> json) {
    return ProductivityAchievement(
      id: json['id'] as String,
      goalId: json['goalId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      achievedAt: DateTime.parse(json['achievedAt'] as String),
      goalType: GoalType.values.firstWhere((e) => e.name == json['goalType']),
      targetValue: (json['targetValue'] as num).toDouble(),
      achievedValue: (json['achievedValue'] as num).toDouble(),
      period: GoalPeriod.values.firstWhere((e) => e.name == json['period']),
    );
  }
}

/// Types of productivity goals
enum GoalType {
  tasksCompleted,
  completionRate,
  timeAccuracy,
  dailyStreak,
  deadlineAdherence,
  timeSpent,
  averageTasksPerDay,
}

/// Goal time periods
enum GoalPeriod {
  daily,
  weekly,
  monthly,
  yearly,
  custom,
}

/// Goal progress tracking data
class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.progressHistory,
    required this.projectedCompletion,
    required this.isOnTrack,
  });

  final ProductivityGoal goal;
  final List<GoalProgressPoint> progressHistory;
  final DateTime? projectedCompletion;
  final bool isOnTrack;
}

/// Individual progress data point
class GoalProgressPoint {
  const GoalProgressPoint({
    required this.date,
    required this.value,
    required this.percentage,
  });

  final DateTime date;
  final double value;
  final double percentage;
}

/// Extension methods for goal types
extension GoalTypeExtension on GoalType {
  String get displayName {
    switch (this) {
      case GoalType.tasksCompleted:
        return 'Tasks Completed';
      case GoalType.completionRate:
        return 'Completion Rate';
      case GoalType.timeAccuracy:
        return 'Time Accuracy';
      case GoalType.dailyStreak:
        return 'Daily Streak';
      case GoalType.deadlineAdherence:
        return 'Deadline Adherence';
      case GoalType.timeSpent:
        return 'Time Spent';
      case GoalType.averageTasksPerDay:
        return 'Tasks per Day';
    }
  }

  String get unit {
    switch (this) {
      case GoalType.tasksCompleted:
        return 'tasks';
      case GoalType.completionRate:
        return '%';
      case GoalType.timeAccuracy:
        return '%';
      case GoalType.dailyStreak:
        return 'days';
      case GoalType.deadlineAdherence:
        return '%';
      case GoalType.timeSpent:
        return 'minutes';
      case GoalType.averageTasksPerDay:
        return 'tasks/day';
    }
  }

  IconData get icon {
    switch (this) {
      case GoalType.tasksCompleted:
        return Icons.check_circle;
      case GoalType.completionRate:
        return Icons.pie_chart;
      case GoalType.timeAccuracy:
        return Icons.timer;
      case GoalType.dailyStreak:
        return Icons.local_fire_department;
      case GoalType.deadlineAdherence:
        return Icons.schedule;
      case GoalType.timeSpent:
        return Icons.access_time;
      case GoalType.averageTasksPerDay:
        return Icons.today;
    }
  }
}

/// Extension methods for goal periods
extension GoalPeriodExtension on GoalPeriod {
  String get displayName {
    switch (this) {
      case GoalPeriod.daily:
        return 'Daily';
      case GoalPeriod.weekly:
        return 'Weekly';
      case GoalPeriod.monthly:
        return 'Monthly';
      case GoalPeriod.yearly:
        return 'Yearly';
      case GoalPeriod.custom:
        return 'Custom';
    }
  }
}
