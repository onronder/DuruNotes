import 'package:drift/native.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/productivity_goals_service.dart';
import 'package:duru_notes/services/task_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_goals_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<TaskAnalyticsService>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDb database;
  late MockTaskAnalyticsService mockAnalytics;
  late ProductivityGoalsService goalsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDb.forTesting(NativeDatabase.memory());
    mockAnalytics = MockTaskAnalyticsService();
    goalsService = ProductivityGoalsService(
      database: database,
      analyticsService: mockAnalytics,
    );
  });

  tearDown(() async {
    goalsService.dispose();
    await database.close();
  });

  group('ProductivityGoalsService', () {
    test('createGoal persists new active goal', () async {
      final goalId = await goalsService.createGoal(
        title: 'Complete 10 tasks',
        description: 'Wrap up weekly tasks',
        type: GoalType.tasksCompleted,
        period: GoalPeriod.weekly,
        targetValue: 10,
      );

      final goals = await goalsService.getActiveGoals();

      expect(goalId, isNotEmpty);
      expect(goals, hasLength(1));
      expect(goals.first.id, goalId);
      expect(goals.first.type, GoalType.tasksCompleted);
      expect(goals.first.targetValue, 10);
      expect(goals.first.currentValue, 0);
    });

    test('updateAllGoalProgress uses analytics stats', () async {
      final goalId = await goalsService.createGoal(
        title: 'Finish 10 tasks',
        description: 'Track task completions',
        type: GoalType.tasksCompleted,
        period: GoalPeriod.monthly,
        targetValue: 10,
      );

      when(mockAnalytics.getTaskCompletionStats(any, any)).thenAnswer(
        (_) async => const TaskCompletionStats(
          totalCompleted: 6,
          totalCreated: 12,
          completionRate: 0.5,
          averagePerDay: 2,
          completionsByDate: {},
          creationsByDate: {},
          currentStreak: 3,
        ),
      );

      await goalsService.updateAllGoalProgress();

      final progress = await goalsService.getGoalProgress(goalId);
      expect(progress, closeTo(0.6, 1e-3));
    });

    test('updateGoalProgress records achievement on completion', () async {
      final goalId = await goalsService.createGoal(
        title: 'Ship three features',
        description: 'Deliver feature set',
        type: GoalType.tasksCompleted,
        period: GoalPeriod.custom,
        targetValue: 3,
      );

      await goalsService.updateGoalProgress(goalId, 3);

      final activeGoals = await goalsService.getActiveGoals();
      final achievements = await goalsService.getAchievements();

      expect(activeGoals, isEmpty, reason: 'Completed goal is filtered out');
      expect(achievements, hasLength(1));
      expect(achievements.first.goalId, goalId);
      expect(achievements.first.title, 'Ship three features');
      expect(achievements.first.targetValue, 3);
      expect(achievements.first.achievedValue, 3);
    });
  });
}
