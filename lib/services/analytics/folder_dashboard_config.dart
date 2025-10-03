
/// Dashboard configuration for folder analytics
class FolderDashboardConfig {
  /// Main folder management dashboard
  static const Dashboard mainDashboard = Dashboard(
    id: 'folder_management_main',
    name: 'Folder Management Overview',
    description: 'High-level metrics for folder feature health',
    refreshInterval: Duration(minutes: 5),
    widgets: [
      // Row 1: Key Metrics
      DashboardWidget(
        type: WidgetType.metric,
        title: 'Active Folder Users',
        dataSource: 'folder_dau',
        format: MetricFormat.percentage,
        comparison: ComparisonPeriod.lastWeek,
      ),
      DashboardWidget(
        type: WidgetType.metric,
        title: 'Avg Folders/User',
        dataSource: 'avg_folders_per_user',
        format: MetricFormat.number,
        comparison: ComparisonPeriod.lastMonth,
      ),
      DashboardWidget(
        type: WidgetType.metric,
        title: 'Folder Creation Rate',
        dataSource: 'weekly_folder_creation',
        format: MetricFormat.rate,
        comparison: ComparisonPeriod.lastWeek,
      ),
      DashboardWidget(
        type: WidgetType.metric,
        title: 'Success Rate',
        dataSource: 'folder_operation_success',
        format: MetricFormat.percentage,
        targetLine: 99.5,
      ),

      // Row 2: Engagement Trends
      DashboardWidget(
        type: WidgetType.lineChart,
        title: 'Daily Active Folder Users',
        dataSource: 'folder_dau_trend',
        timeRange: TimeRange.last30Days,
        metrics: ['unique_users', 'folder_operations'],
      ),
      DashboardWidget(
        type: WidgetType.areaChart,
        title: 'Folder Creation Trend',
        dataSource: 'folder_creation_trend',
        timeRange: TimeRange.last30Days,
        metrics: ['new_folders', 'cumulative_folders'],
      ),

      // Row 3: Usage Patterns
      DashboardWidget(
        type: WidgetType.heatmap,
        title: 'Folder Usage Heatmap',
        dataSource: 'folder_usage_by_hour',
        dimensions: ['hour_of_day', 'day_of_week'],
      ),
      DashboardWidget(
        type: WidgetType.histogram,
        title: 'Folder Depth Distribution',
        dataSource: 'folder_depth_distribution',
        buckets: 10,
        showPercentiles: true,
      ),

      // Row 4: Feature Adoption
      DashboardWidget(
        type: WidgetType.funnel,
        title: 'Folder Feature Adoption Funnel',
        dataSource: 'folder_adoption_funnel',
        stages: [
          'Discovered Folders',
          'Created First Folder',
          'Created Multiple Folders',
          'Used Advanced Features',
          'Power User',
        ],
      ),
      DashboardWidget(
        type: WidgetType.barChart,
        title: 'Feature Usage Breakdown',
        dataSource: 'folder_features_usage',
        metrics: [
          'bulk_operations',
          'templates',
          'sharing',
          'search',
          'reorganization',
        ],
      ),
    ],
  );

  /// Performance monitoring dashboard
  static const Dashboard performanceDashboard = Dashboard(
    id: 'folder_performance',
    name: 'Folder Performance Monitoring',
    description: 'Technical performance metrics for folder operations',
    refreshInterval: Duration(minutes: 1),
    widgets: [
      // Performance metrics
      DashboardWidget(
        type: WidgetType.gauge,
        title: 'Avg Load Time',
        dataSource: 'avg_folder_load_time',
        format: MetricFormat.milliseconds,
        thresholds: [
          ThresholdConfig(value: 200, color: 'green', label: 'Good'),
          ThresholdConfig(value: 500, color: 'yellow', label: 'Warning'),
          ThresholdConfig(value: 1000, color: 'red', label: 'Critical'),
        ],
      ),
      DashboardWidget(
        type: WidgetType.lineChart,
        title: 'Response Time Percentiles',
        dataSource: 'folder_response_percentiles',
        metrics: ['p50', 'p75', 'p95', 'p99'],
        timeRange: TimeRange.last24Hours,
      ),
      DashboardWidget(
        type: WidgetType.table,
        title: 'Slow Operations',
        dataSource: 'slow_folder_operations',
        columns: ['operation', 'duration_ms', 'user_id', 'timestamp'],
        sortBy: 'duration_ms',
        limit: 20,
      ),
    ],
  );

  /// Business impact dashboard
  static const Dashboard businessDashboard = Dashboard(
    id: 'folder_business_impact',
    name: 'Folder Business Impact',
    description: 'Business metrics and conversion impact',
    refreshInterval: Duration(hours: 1),
    widgets: [
      // Retention impact
      DashboardWidget(
        type: WidgetType.cohortChart,
        title: 'Retention: Folder Users vs Non-Users',
        dataSource: 'folder_retention_cohorts',
        cohortType: CohortType.weekly,
        metric: 'retention_rate',
      ),

      // Productivity metrics
      DashboardWidget(
        type: WidgetType.scatterPlot,
        title: 'Folders vs Productivity',
        dataSource: 'folder_productivity_correlation',
        xAxis: 'folder_count',
        yAxis: 'notes_created_per_week',
        showTrendline: true,
      ),

      // Conversion impact
      DashboardWidget(
        type: WidgetType.conversionFunnel,
        title: 'Premium Conversion via Folders',
        dataSource: 'folder_premium_conversion',
        stages: [
          'Hit Folder Limit',
          'Viewed Upgrade Prompt',
          'Started Trial',
          'Converted to Premium',
        ],
      ),
    ],
  );

  /// Alert configurations
  static const List<AlertConfig> alerts = [
    // Performance alerts
    AlertConfig(
      id: 'folder_load_time_high',
      name: 'High Folder Load Time',
      condition: 'avg_folder_load_time > 500',
      severity: AlertSeverity.warning,
      notification: NotificationType.slack,
      cooldown: Duration(minutes: 30),
    ),
    AlertConfig(
      id: 'folder_error_rate_high',
      name: 'High Folder Error Rate',
      condition: 'folder_error_rate > 1.0',
      severity: AlertSeverity.critical,
      notification: NotificationType.pagerDuty,
      cooldown: Duration(minutes: 15),
    ),

    // Business alerts
    AlertConfig(
      id: 'folder_creation_drop',
      name: 'Folder Creation Rate Drop',
      condition: 'folder_creation_rate < 1.0',
      severity: AlertSeverity.warning,
      notification: NotificationType.email,
      cooldown: Duration(hours: 24),
    ),
    AlertConfig(
      id: 'new_user_adoption_low',
      name: 'Low New User Folder Adoption',
      condition: 'new_user_folder_creation < 40',
      severity: AlertSeverity.info,
      notification: NotificationType.slack,
      cooldown: Duration(days: 1),
    ),
  ];
}

/// Dashboard model
class Dashboard {
  final String id;
  final String name;
  final String description;
  final Duration refreshInterval;
  final List<DashboardWidget> widgets;

  const Dashboard({
    required this.id,
    required this.name,
    required this.description,
    required this.refreshInterval,
    required this.widgets,
  });
}

/// Dashboard widget configuration
class DashboardWidget {
  final WidgetType type;
  final String title;
  final String dataSource;
  final MetricFormat? format;
  final ComparisonPeriod? comparison;
  final TimeRange? timeRange;
  final List<String>? metrics;
  final List<String>? dimensions;
  final List<String>? columns;
  final List<String>? stages;
  final List<ThresholdConfig>? thresholds;
  final String? xAxis;
  final String? yAxis;
  final String? sortBy;
  final CohortType? cohortType;
  final String? metric;
  final int? buckets;
  final int? limit;
  final double? targetLine;
  final bool? showPercentiles;
  final bool? showTrendline;

  const DashboardWidget({
    required this.type,
    required this.title,
    required this.dataSource,
    this.format,
    this.comparison,
    this.timeRange,
    this.metrics,
    this.dimensions,
    this.columns,
    this.stages,
    this.thresholds,
    this.xAxis,
    this.yAxis,
    this.sortBy,
    this.cohortType,
    this.metric,
    this.buckets,
    this.limit,
    this.targetLine,
    this.showPercentiles,
    this.showTrendline,
  });
}

/// Alert configuration
class AlertConfig {
  final String id;
  final String name;
  final String condition;
  final AlertSeverity severity;
  final NotificationType notification;
  final Duration cooldown;

  const AlertConfig({
    required this.id,
    required this.name,
    required this.condition,
    required this.severity,
    required this.notification,
    required this.cooldown,
  });
}

/// Threshold configuration
class ThresholdConfig {
  final double value;
  final String color;
  final String label;

  const ThresholdConfig({
    required this.value,
    required this.color,
    required this.label,
  });
}

/// Enums for configuration
enum WidgetType {
  metric,
  lineChart,
  areaChart,
  barChart,
  pieChart,
  donutChart,
  heatmap,
  histogram,
  scatterPlot,
  table,
  funnel,
  conversionFunnel,
  cohortChart,
  gauge,
}

enum MetricFormat {
  number,
  percentage,
  currency,
  milliseconds,
  seconds,
  rate,
}

enum ComparisonPeriod {
  lastDay,
  lastWeek,
  lastMonth,
  lastQuarter,
  lastYear,
}

enum TimeRange {
  last24Hours,
  last7Days,
  last30Days,
  last90Days,
  lastYear,
  allTime,
}

enum CohortType {
  daily,
  weekly,
  monthly,
}

enum AlertSeverity {
  info,
  warning,
  critical,
}

enum NotificationType {
  email,
  slack,
  pagerDuty,
  webhook,
}