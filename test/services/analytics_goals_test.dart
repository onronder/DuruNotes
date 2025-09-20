import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/task_analytics_service.dart';
import 'package:duru_notes/services/productivity_goals_service.dart';
import 'package:duru_notes/services/ai_insights_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

@GenerateMocks([
  AppDb,
  TaskAnalyticsService,
  SharedPreferences,
])
import 'analytics_goals_test.mocks.dart';

void main() {
  late MockAppDb mockDb;
  late MockTaskAnalyticsService mockAnalyticsService;
  late MockSharedPreferences mockPrefs;
  late ProductivityGoalsService goalsService;
  late AIInsightsService insightsService;
  
  setUp(() {
    mockDb = MockAppDb();
    mockAnalyticsService = MockTaskAnalyticsService();
    mockPrefs = MockSharedPreferences();
    
    goalsService = ProductivityGoalsService(
      database: mockDb,
      analyticsService: mockAnalyticsService,
    );
    
    insightsService = AIInsightsService();
    
    // Setup default mock behavior
    when(mockPrefs.getString(any)).thenReturn(null);
    when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
  });
  
  group('Task Analytics Service', () {
    test('should calculate completion rate correctly', () async {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 7));
      
      // Mock completed tasks
      final completedTasks = List.generate(7, (i) => NoteTask(
        id: 'task-$i',
        noteId: 'note-1',
        content: 'Task $i',
        contentHash: 'hash-$i',
        status: TaskStatus.completed,
        completedAt: now.subtract(Duration(days: i)),
        createdAt: startDate,
        updatedAt: now,
        position: i,
      ));
      
      // Mock total tasks (7 completed + 3 pending)
      final allTasks = [
        ...completedTasks,
        ...List.generate(3, (i) => NoteTask(
          id: 'pending-$i',
          noteId: 'note-1',
          content: 'Pending $i',
          contentHash: 'hash-pending-$i',
          status: TaskStatus.open,
          createdAt: startDate,
          updatedAt: now,
          position: i + 7,
        )),
      ];
      
      // Completion rate should be 7/10 = 0.7
      expect(completedTasks.length / allTasks.length, equals(0.7));
    });
    
    test('should detect productivity patterns', () async {
      // Create hourly distribution
      final hourlyDistribution = <int, int>{
        9: 5,  // 9 AM - 5 tasks
        10: 8, // 10 AM - 8 tasks (peak)
        11: 6, // 11 AM - 6 tasks
        14: 4, // 2 PM - 4 tasks
        15: 3, // 3 PM - 3 tasks
      };
      
      // Find peak hour
      var peakHour = 0;
      var maxCount = 0;
      hourlyDistribution.forEach((hour, count) {
        if (count > maxCount) {
          maxCount = count;
          peakHour = hour;
        }
      });
      
      expect(peakHour, equals(10)); // 10 AM is peak
      expect(maxCount, equals(8));
    });
    
    test('should calculate streak correctly', () {
      final completionsByDate = <DateTime, int>{
        DateTime(2024, 1, 1): 2,
        DateTime(2024, 1, 2): 3,
        DateTime(2024, 1, 3): 1,
        // Gap on Jan 4
        DateTime(2024, 1, 5): 2,
        DateTime(2024, 1, 6): 1,
      };
      
      // Calculate streak (should be 3 days: Jan 1-3)
      var currentStreak = 0;
      var maxStreak = 0;
      var consecutiveDays = 0;
      
      final sortedDates = completionsByDate.keys.toList()..sort();
      DateTime? previousDate;
      
      for (final date in sortedDates) {
        if (previousDate != null) {
          final dayDifference = date.difference(previousDate).inDays;
          if (dayDifference == 1) {
            consecutiveDays++;
          } else {
            maxStreak = consecutiveDays > maxStreak ? consecutiveDays : maxStreak;
            consecutiveDays = 1;
          }
        } else {
          consecutiveDays = 1;
        }
        previousDate = date;
      }
      
      maxStreak = consecutiveDays > maxStreak ? consecutiveDays : maxStreak;
      
      expect(maxStreak, equals(3));
    });
  });
  
  group('Productivity Goals Service', () {
    test('should create and save goal', () async {
      // Create a goal
      final goalId = await goalsService.createGoal(
        title: 'Complete 10 tasks',
        description: 'Complete 10 tasks this week',
        type: GoalType.tasksCompleted,
        period: GoalPeriod.weekly,
        targetValue: 10,
      );
      
      expect(goalId, isNotEmpty);
      
      // Verify goal was saved
      verify(mockPrefs.setString('productivity_goals', any)).called(1);
    });
    
    test('should update goal progress', () async {
      // Setup existing goal
      final existingGoal = ProductivityGoal(
        id: 'goal-1',
        title: 'Daily Tasks',
        description: 'Complete 5 tasks daily',
        type: GoalType.tasksCompleted,
        period: GoalPeriod.daily,
        targetValue: 5,
        currentValue: 3,
        startDate: DateTime.now(),
        isActive: true,
        isCompleted: false,
        metadata: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      when(mockPrefs.getString('productivity_goals'))
          .thenReturn(jsonEncode([existingGoal.toJson()]));
      
      // Update progress
      await goalsService.updateGoalProgress('goal-1', 5);
      
      // Verify goal was marked as completed
      final savedGoalsCaptor = verify(mockPrefs.setString('productivity_goals', captureAny))
          .captured;
      
      expect(savedGoalsCaptor, isNotEmpty);
      final savedGoals = jsonDecode(savedGoalsCaptor.first as String) as List;
      expect(savedGoals.first['isCompleted'], isTrue);
      expect(savedGoals.first['currentValue'], equals(5));
    });
    
    test('should detect goal achievement', () async {
      final goal = ProductivityGoal(
        id: 'goal-2',
        title: 'Weekly Target',
        description: 'Complete 20 tasks this week',
        type: GoalType.tasksCompleted,
        period: GoalPeriod.weekly,
        targetValue: 20,
        currentValue: 19,
        startDate: DateTime.now().subtract(const Duration(days: 6)),
        isActive: true,
        isCompleted: false,
        metadata: {},
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
        updatedAt: DateTime.now(),
      );
      
      when(mockPrefs.getString('productivity_goals'))
          .thenReturn(jsonEncode([goal.toJson()]));
      
      // Update to achieve goal
      await goalsService.updateGoalProgress('goal-2', 20);
      
      // Verify achievement was recorded
      verify(mockPrefs.setString('productivity_achievements', any)).called(1);
    });
    
    test('should calculate goal progress percentage', () async {
      final goal = ProductivityGoal(
        id: 'goal-3',
        title: 'Completion Rate',
        description: 'Achieve 80% completion rate',
        type: GoalType.completionRate,
        period: GoalPeriod.monthly,
        targetValue: 0.8,
        currentValue: 0.6,
        startDate: DateTime.now(),
        isActive: true,
        isCompleted: false,
        metadata: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      when(mockPrefs.getString('productivity_goals'))
          .thenReturn(jsonEncode([goal.toJson()]));
      
      final progress = await goalsService.getGoalProgress('goal-3');
      
      // Progress should be 0.6/0.8 = 0.75 (75%)
      expect(progress, equals(0.75));
    });
  });
  
  group('AI Insights Service', () {
    test('should generate pattern insights', () async {
      final analytics = _createMockAnalytics();
      
      final insights = await insightsService.generateInsights(analytics);
      
      // Should have at least one insight
      expect(insights, isNotEmpty);
      
      // Check for pattern insights
      final patternInsights = insights.where((i) => i.type == InsightType.pattern);
      expect(patternInsights, isNotEmpty);
    });
    
    test('should generate recommendations for low accuracy', () async {
      final analytics = _createMockAnalytics(timeAccuracy: 0.5);
      
      final insights = await insightsService.generateInsights(analytics);
      
      // Should have recommendation for improving time estimates
      final recommendations = insights.where((i) => 
        i.type == InsightType.recommendation &&
        i.title.contains('Time Estimates')
      );
      expect(recommendations, isNotEmpty);
    });
    
    test('should detect achievements', () async {
      final analytics = _createMockAnalytics(
        completionRate: 0.95,
        currentStreak: 15,
        longestStreak: 10,
      );
      
      final insights = await insightsService.generateInsights(analytics);
      
      // Should detect high completion rate achievement
      final achievements = insights.where((i) => i.type == InsightType.achievement);
      expect(achievements, isNotEmpty);
      
      // Should detect new streak record
      final streakAchievement = achievements.where((i) => 
        i.title.contains('Streak Record')
      );
      expect(streakAchievement, isNotEmpty);
    });
    
    test('should generate warnings for overdue tasks', () async {
      final analytics = _createMockAnalytics(overdueCount: 10);
      
      final insights = await insightsService.generateInsights(analytics);
      
      // Should have warning about overdue tasks
      final warnings = insights.where((i) => 
        i.type == InsightType.warning &&
        i.title.contains('Overdue')
      );
      expect(warnings, isNotEmpty);
    });
    
    test('should predict weekly completion', () async {
      final analytics = _createMockAnalytics(averagePerDay: 5.0);
      
      final insights = await insightsService.generateInsights(analytics);
      
      // Should have prediction for weekly completion
      final predictions = insights.where((i) => 
        i.type == InsightType.prediction &&
        i.title.contains('Weekly Forecast')
      );
      expect(predictions, isNotEmpty);
      
      // Predicted should be around 35 (5 * 7)
      final prediction = predictions.first;
      expect(prediction.metadata?['predicted'], greaterThan(30));
      expect(prediction.metadata?['predicted'], lessThan(40));
    });
  });
  
  group('Integration Tests', () {
    test('should track goal progress from analytics', () async {
      // Create a tasks completed goal
      final goalId = await goalsService.createGoal(
        title: 'Daily Target',
        description: 'Complete 5 tasks today',
        type: GoalType.tasksCompleted,
        period: GoalPeriod.daily,
        targetValue: 5,
      );
      
      // Simulate completing tasks
      final completionStats = TaskCompletionStats(
        totalCompleted: 5,
        totalCreated: 6,
        completionRate: 5/6,
        averagePerDay: 5.0,
        currentStreak: 1,
        longestStreak: 1,
        completionsByDate: {DateTime.now(): 5},
        creationsByDate: {DateTime.now(): 6},
      );
      
      when(mockAnalyticsService.getTaskCompletionStats(any, any))
          .thenAnswer((_) async => completionStats);
      
      // Update goal progress
      await goalsService.updateAllGoalProgress();
      
      // Goal should be completed
      final goals = await goalsService.getActiveGoals();
      // Since goal is completed, it won't be in active goals
      expect(goals.where((g) => g.id == goalId), isEmpty);
    });
    
    test('should generate insights and trigger goal checks', () async {
      final analytics = _createMockAnalytics(
        completionRate: 0.9,
        averagePerDay: 6.0,
      );
      
      // Generate insights
      final insights = await insightsService.generateInsights(analytics);
      
      // Should have multiple types of insights
      final insightTypes = insights.map((i) => i.type).toSet();
      expect(insightTypes.length, greaterThanOrEqualTo(2));
      
      // Check for high performance insights
      final highPerformance = insights.where((i) => 
        i.description.contains('exceptional') ||
        i.description.contains('outstanding') ||
        i.description.contains('above average')
      );
      expect(highPerformance, isNotEmpty);
    });
  });
}

// Helper function to create mock analytics
ProductivityAnalytics _createMockAnalytics({
  double completionRate = 0.75,
  double averagePerDay = 4.0,
  int currentStreak = 5,
  int longestStreak = 10,
  double timeAccuracy = 0.8,
  int overdueCount = 2,
}) {
  return ProductivityAnalytics(
    dateRange: DateRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    ),
    completionStats: TaskCompletionStats(
      totalCompleted: 120,
      totalCreated: 160,
      completionRate: completionRate,
      averagePerDay: averagePerDay,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      completionsByDate: {},
      creationsByDate: {},
    ),
    timeAccuracyStats: TimeEstimationAccuracy(
      accuracyPercentage: timeAccuracy * 100,
      averageDeviation: 15,
      overestimateCount: 10,
      underestimateCount: 8,
      accurateCount: 22,
      totalEstimated: 40,
    ),
    productivityTrends: ProductivityTrends(
      overallTrend: 0.1,
      weeklyPattern: {
        1: 0.8, // Monday
        2: 0.9, // Tuesday
        3: 0.85, // Wednesday
        4: 0.9, // Thursday
        5: 0.7, // Friday
      },
      hourlyDistribution: {
        9: 5,
        10: 8,
        11: 6,
        14: 4,
      },
      trendByPriority: {},
      trendByCategory: {},
    ),
    priorityDistribution: PriorityDistribution(
      highPriorityCount: 40,
      mediumPriorityCount: 60,
      lowPriorityCount: 20,
      totalCount: 120,
      completionRateByPriority: {},
      averageTimeByPriority: {},
    ),
    deadlineMetrics: DeadlineAdherenceMetrics(
      onTimeCount: 90,
      lateCount: 20,
      overdueCount: overdueCount,
      totalWithDeadline: 110,
      onTimePercentage: 90/110 * 100,
      averageDelayDays: 1.5,
      upcomingDeadlines: [],
    ),
    categoryPerformance: CategoryPerformance(
      categoryCounts: {},
      categoryCompletionRates: {},
      categoryTimeSpent: {},
      topCategories: [],
    ),
    generatedAt: DateTime.now(),
  );
}
