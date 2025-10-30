import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/core/providers/database_providers.dart'
    show appDbProvider;
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart'
    show taskAnalyticsServiceProvider;
import 'package:duru_notes/features/auth/providers/auth_providers.dart'
    show supabaseClientProvider;
import 'package:duru_notes/services/task_analytics_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Today's task statistics
class TodayStats {
  final int completed;
  final int pending;
  final int overdue;
  final int streak;

  TodayStats({
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.streak,
  });
}

/// Provider for today's task statistics
final todayStatsProvider = FutureProvider<TodayStats>((ref) async {
  final db = ref.watch(appDbProvider);
  final analyticsService = ref.watch(taskAnalyticsServiceProvider);
  final supabase = ref.watch(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;

  if (userId == null || userId.isEmpty) {
    return TodayStats(completed: 0, pending: 0, overdue: 0, streak: 0);
  }

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));

  // Get all tasks for today
  final allTasks = await db.getTasksByDateRange(
    userId: userId,
    start: todayStart,
    end: todayEnd,
  );

  // Count by status
  int completed = 0;
  int pending = 0;
  int overdue = 0;

  for (final task in allTasks) {
    if (task.status == TaskStatus.completed) {
      completed++;
    } else if (task.dueDate != null && task.dueDate!.isBefore(now)) {
      overdue++;
    } else {
      pending++;
    }
  }

  // Get streak
  final analytics = await analyticsService.getProductivityAnalytics(
    startDate: now.subtract(const Duration(days: 30)),
    endDate: now,
  );

  final streak = analytics.completionStats.currentStreak;

  return TodayStats(
    completed: completed,
    pending: pending,
    overdue: overdue,
    streak: streak,
  );
});

/// Provider for weekly statistics
final weeklyStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final analyticsService = ref.watch(taskAnalyticsServiceProvider);

  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 7));

  final analytics = await analyticsService.getProductivityAnalytics(
    startDate: weekStart,
    endDate: weekEnd,
  );

  return {
    'completionRate': analytics.completionStats.completionRate,
    'averagePerDay': analytics.completionStats.averagePerDay,
    'totalCompleted': analytics.completionStats.totalCompleted,
    'totalCreated': analytics.completionStats.totalCreated,
    'timeAccuracy': analytics.timeAccuracyStats.overallAccuracy,
  };
});

/// Provider for productivity insights
final productivityInsightsProvider = FutureProvider<ProductivityInsights?>((
  ref,
) async {
  final analyticsService = ref.watch(taskAnalyticsServiceProvider);

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);

  final analytics = await analyticsService.getProductivityAnalytics(
    startDate: monthStart,
    endDate: now,
  );

  return await analyticsService.getProductivityInsights(analytics);
});
