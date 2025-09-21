import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/productivity_goals_service.dart';
import 'package:duru_notes/services/task_analytics_service.dart';
import 'package:duru_notes/ui/dialogs/goals_dialog.dart';
import 'package:duru_notes/ui/widgets/analytics/productivity_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// Comprehensive productivity analytics dashboard
class ProductivityAnalyticsScreen extends ConsumerStatefulWidget {
  const ProductivityAnalyticsScreen({super.key});

  @override
  ConsumerState<ProductivityAnalyticsScreen> createState() =>
      _ProductivityAnalyticsScreenState();
}

class _ProductivityAnalyticsScreenState
    extends ConsumerState<ProductivityAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _selectedDateRange;
  ProductivityAnalytics? _analytics;
  ProductivityInsights? _insights;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Default to last 30 days
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );

    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    if (_selectedDateRange == null) return;

    setState(() => _isLoading = true);

    try {
      final analyticsService = ref.read(taskAnalyticsServiceProvider);

      final analytics = await analyticsService.getProductivityAnalytics(
        startDate: _selectedDateRange!.start,
        endDate: _selectedDateRange!.end,
      );

      final insights =
          await analyticsService.getProductivityInsights(analytics);

      if (mounted) {
        setState(() {
          _analytics = analytics;
          _insights = insights;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (range != null) {
      setState(() => _selectedDateRange = range);
      await _loadAnalytics();
    }
  }

  Future<void> _showGoalsDialog() async {
    final result = await showDialog<ProductivityGoal>(
      context: context,
      builder: (context) => const GoalsDialog(),
    );

    if (result != null && mounted) {
      // Refresh analytics to show progress toward new goal
      await _loadAnalytics();
    }
  }

  Future<void> _exportData() async {
    if (_analytics == null) return;

    try {
      final analyticsService = ref.read(taskAnalyticsServiceProvider);
      final csvData = await analyticsService.exportAnalyticsAsCSV(_analytics!);

      await Share.share(
        csvData,
        subject:
            'Productivity Analytics - ${DateFormat.yMMMd().format(_selectedDateRange!.start)} to ${DateFormat.yMMMd().format(_selectedDateRange!.end)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productivity Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Time', icon: Icon(Icons.timer)),
            Tab(text: 'Trends', icon: Icon(Icons.trending_up)),
            Tab(text: 'Insights', icon: Icon(Icons.lightbulb)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag),
            onPressed: _showGoalsDialog,
            tooltip: 'Set Goals',
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select date range',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _analytics != null ? _exportData : null,
            tooltip: 'Export data',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date range indicator
          if (_selectedDateRange != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(Icons.date_range, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${DateFormat.yMMMd().format(_selectedDateRange!.start)} - ${DateFormat.yMMMd().format(_selectedDateRange!.end)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_analytics != null)
                    Text(
                      '${_analytics!.dateRange.days} days',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _analytics == null
                    ? _buildErrorState()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildTimeAnalysisTab(),
                          _buildTrendsTab(),
                          _buildInsightsTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No analytics data available',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Complete some tasks to see your productivity insights',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final analytics = _analytics!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              AnalyticsSummaryCard(
                title: 'Tasks Completed',
                value: analytics.completionStats.totalCompleted.toString(),
                subtitle:
                    '${(analytics.completionStats.completionRate * 100).round()}% completion rate',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              AnalyticsSummaryCard(
                title: 'Average per Day',
                value:
                    analytics.completionStats.averagePerDay.toStringAsFixed(1),
                subtitle: 'tasks completed daily',
                icon: Icons.today,
                color: Colors.blue,
              ),
              AnalyticsSummaryCard(
                title: 'Current Streak',
                value: analytics.completionStats.currentStreak.toString(),
                subtitle: 'days with completed tasks',
                icon: Icons.local_fire_department,
                color: Colors.orange,
              ),
              AnalyticsSummaryCard(
                title: 'Time Accuracy',
                value:
                    '${(analytics.timeAccuracyStats.overallAccuracy * 100).round()}%',
                subtitle: 'estimation accuracy',
                icon: Icons.timer,
                color: Colors.purple,
                trend: analytics.timeAccuracyStats.improvementTrend,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Completion chart
          _buildChartSection(
            'Task Completion Trends',
            TaskCompletionChart(completionStats: analytics.completionStats),
          ),

          const SizedBox(height: 24),

          // Priority distribution
          _buildChartSection(
            'Priority Distribution',
            PriorityDistributionChart(
                priorityDistribution: analytics.priorityDistribution),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeAnalysisTab() {
    final analytics = _analytics!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time accuracy summary
          Row(
            children: [
              Expanded(
                child: AnalyticsSummaryCard(
                  title: 'Accurate Estimates',
                  value:
                      analytics.timeAccuracyStats.accurateEstimates.toString(),
                  subtitle: 'within 20% of actual',
                  icon: Icons.check,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnalyticsSummaryCard(
                  title: 'Under Estimates',
                  value: analytics.timeAccuracyStats.underEstimates.toString(),
                  subtitle: 'took longer than expected',
                  icon: Icons.trending_up,
                  color: Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Time accuracy chart
          _buildChartSection(
            'Estimation Accuracy Over Time',
            TimeAccuracyChart(timeAccuracy: analytics.timeAccuracyStats),
          ),

          const SizedBox(height: 24),

          // Time breakdown by priority
          _buildTimeBreakdownSection(analytics),
        ],
      ),
    );
  }

  Widget _buildTrendsTab() {
    final analytics = _analytics!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Productivity score
          Center(
            child: Column(
              children: [
                ProductivityScoreGauge(
                  score: analytics.productivityTrends.productivityScore,
                ),
                const SizedBox(height: 8),
                Text(
                  'Productivity Score',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  _getScoreDescription(
                      analytics.productivityTrends.productivityScore),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Weekly trends
          _buildChartSection(
            'Weekly Productivity',
            WeeklyTrendsChart(
                weeklyTrends: analytics.productivityTrends.weeklyTrends),
          ),

          const SizedBox(height: 24),

          // Hourly distribution
          _buildChartSection(
            'Most Productive Hours',
            HourlyProductivityChart(
                hourlyDistribution:
                    analytics.productivityTrends.hourlyDistribution),
          ),

          const SizedBox(height: 24),

          // Deadline adherence
          _buildChartSection(
            'Deadline Adherence',
            DeadlineAdherenceChart(deadlineMetrics: analytics.deadlineMetrics),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsTab() {
    final insights = _insights!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall score card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  ProductivityScoreGauge(
                    score: insights.overallScore,
                    size: 80,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall Productivity',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getScoreDescription(insights.overallScore),
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Insights
          if (insights.insights.isNotEmpty) ...[
            Text(
              'Key Insights',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...insights.insights.map((insight) => _buildInsightCard(insight)),
          ],

          const SizedBox(height: 24),

          // Recommendations
          if (insights.recommendations.isNotEmpty) ...[
            Text(
              'Recommendations',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...insights.recommendations.map(
                (recommendation) => _buildRecommendationCard(recommendation)),
          ],
        ],
      ),
    );
  }

  Widget _buildChartSection(String title, Widget chart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: chart,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeBreakdownSection(ProductivityAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time Breakdown by Priority',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: analytics.priorityDistribution.distribution.entries
                  .map((entry) {
                final priority = entry.key;
                final stats = entry.value;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getPriorityColor(priority),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getPriorityLabel(priority),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              'Avg: ${stats.averageActualTime.toStringAsFixed(0)}m per task',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${stats.completedTasks} tasks',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(ProductivityInsight insight) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final impactColor = _getImpactColor(insight.impact);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: impactColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getInsightIcon(insight.type),
                color: impactColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          insight.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: impactColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          insight.impact.name.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: impactColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    insight.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(String recommendation) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lightbulb,
              color: Colors.amber,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                recommendation,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getScoreDescription(double score) {
    if (score >= 80) return 'Excellent productivity! Keep it up!';
    if (score >= 60) return 'Good productivity with room for improvement';
    if (score >= 40) return 'Moderate productivity - focus on consistency';
    return 'Lots of room for improvement';
  }

  Color _getImpactColor(InsightImpact impact) {
    switch (impact) {
      case InsightImpact.low:
        return Colors.blue;
      case InsightImpact.medium:
        return Colors.orange;
      case InsightImpact.high:
        return Colors.red;
    }
  }

  IconData _getInsightIcon(InsightType type) {
    switch (type) {
      case InsightType.timeEstimation:
        return Icons.timer;
      case InsightType.completion:
        return Icons.check_circle;
      case InsightType.deadlines:
        return Icons.schedule;
      case InsightType.timing:
        return Icons.access_time;
      case InsightType.priority:
        return Icons.flag;
      case InsightType.category:
        return Icons.category;
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.urgent:
        return Colors.purple;
    }
  }

  String _getPriorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Low Priority';
      case TaskPriority.medium:
        return 'Medium Priority';
      case TaskPriority.high:
        return 'High Priority';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }
}

/// Quick analytics widget for dashboard inclusion
class QuickAnalyticsWidget extends ConsumerWidget {
  const QuickAnalyticsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<ProductivityAnalytics>(
      future: _getQuickAnalytics(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final analytics = snapshot.data!;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Today\'s Productivity',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              const ProductivityAnalyticsScreen(),
                        ),
                      ),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickStat(
                      'Completed',
                      analytics.completionStats.totalCompleted.toString(),
                      Icons.check_circle,
                      Colors.green,
                      theme,
                    ),
                    _buildQuickStat(
                      'Streak',
                      '${analytics.completionStats.currentStreak} days',
                      Icons.local_fire_department,
                      Colors.orange,
                      theme,
                    ),
                    _buildQuickStat(
                      'Accuracy',
                      '${(analytics.timeAccuracyStats.overallAccuracy * 100).round()}%',
                      Icons.timer,
                      Colors.blue,
                      theme,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickStat(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<ProductivityAnalytics> _getQuickAnalytics(WidgetRef ref) async {
    final analyticsService = ref.read(taskAnalyticsServiceProvider);
    final now = DateTime.now();

    return analyticsService.getProductivityAnalytics(
      startDate: now.subtract(const Duration(days: 7)),
      endDate: now,
    );
  }
}
