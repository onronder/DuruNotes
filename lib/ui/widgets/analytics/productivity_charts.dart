import 'dart:math';

import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/services/task_analytics_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Chart widget for task completion trends
class TaskCompletionChart extends StatelessWidget {
  const TaskCompletionChart({
    super.key,
    required this.completionStats,
    this.height = 200,
  });

  final TaskCompletionStats completionStats;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (completionStats.completionsByDate.isEmpty) {
      return _buildEmptyChart(context, 'No completion data available');
    }

    final sortedDates = completionStats.completionsByDate.keys.toList()..sort();
    final spots = <FlSpot>[];

    for (var i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final count = completionStats.completionsByDate[date] ?? 0;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.outline.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: max(1, sortedDates.length / 5).toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < sortedDates.length) {
                    return Text(
                      DateFormat.Md().format(sortedDates[index]),
                      style: theme.textTheme.labelSmall,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: colorScheme.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
          minY: 0,
          maxY: spots.map((s) => s.y).reduce(max) + 1,
        ),
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context, String message) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chart widget for time estimation accuracy
class TimeAccuracyChart extends StatelessWidget {
  const TimeAccuracyChart({
    super.key,
    required this.timeAccuracy,
    this.height = 200,
  });

  final TimeEstimationAccuracy timeAccuracy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (timeAccuracy.accuracyData.isEmpty) {
      return _buildEmptyChart(context, 'No time tracking data available');
    }

    final sortedData = timeAccuracy.accuracyData.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final spots = <FlSpot>[];
    final idealLine = <FlSpot>[];

    for (var i = 0; i < sortedData.length; i++) {
      final point = sortedData[i];
      spots.add(FlSpot(i.toDouble(), point.accuracy));
      idealLine.add(FlSpot(i.toDouble(), 1.0)); // Perfect accuracy line
    }

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 0.2,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.outline.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) => Text(
                  '${(value * 100).toInt()}%',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: max(1, sortedData.length / 4).toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < sortedData.length) {
                    return Text(
                      DateFormat.Md().format(sortedData[index].date),
                      style: theme.textTheme.labelSmall,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border:
                Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
          ),
          lineBarsData: [
            // Ideal accuracy line (100%)
            LineChartBarData(
              spots: idealLine,
              isCurved: false,
              color: Colors.green.withValues(alpha: 0.5),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              dashArray: [5, 5],
            ),
            // Actual accuracy
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: colorScheme.secondary,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final accuracy = spot.y;
                  Color dotColor;
                  if (accuracy >= 0.8 && accuracy <= 1.2) {
                    dotColor = Colors.green;
                  } else if (accuracy < 0.8) {
                    dotColor = Colors.red;
                  } else {
                    dotColor = Colors.orange;
                  }
                  return FlDotCirclePainter(
                    radius: 4,
                    color: dotColor,
                    strokeColor: Colors.white,
                    strokeWidth: 2,
                  );
                },
              ),
            ),
          ],
          minY: 0,
          maxY: spots.map((s) => s.y).reduce(max) + 0.2,
        ),
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context, String message) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timer,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chart widget for priority distribution
class PriorityDistributionChart extends StatelessWidget {
  const PriorityDistributionChart({
    super.key,
    required this.priorityDistribution,
    this.height = 200,
  });

  final PriorityDistribution priorityDistribution;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (priorityDistribution.distribution.isEmpty) {
      return _buildEmptyChart(context, 'No priority data available');
    }

    final sections = <PieChartSectionData>[];

    for (final entry in priorityDistribution.distribution.entries) {
      final priority = entry.key;
      final stats = entry.value;

      if (stats.totalTasks > 0) {
        sections.add(
          PieChartSectionData(
            value: stats.totalTasks.toDouble(),
            title: '${stats.totalTasks}',
            color: _getPriorityColor(priority),
            radius: 60,
            titleStyle: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
    }

    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: priorityDistribution.distribution.entries.map((entry) {
                final priority = entry.key;
                final stats = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_getPriorityLabel(priority)}: ${stats.totalTasks}',
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context, String message) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(domain.TaskPriority priority) {
    switch (priority) {
      case domain.TaskPriority.low:
        return Colors.green;
      case domain.TaskPriority.medium:
        return Colors.orange;
      case domain.TaskPriority.high:
        return Colors.red;
      case domain.TaskPriority.urgent:
        return Colors.purple;
    }
  }

  String _getPriorityLabel(domain.TaskPriority priority) {
    switch (priority) {
      case domain.TaskPriority.low:
        return 'Low';
      case domain.TaskPriority.medium:
        return 'Medium';
      case domain.TaskPriority.high:
        return 'High';
      case domain.TaskPriority.urgent:
        return 'Urgent';
    }
  }
}

/// Chart widget for hourly productivity distribution
class HourlyProductivityChart extends StatelessWidget {
  const HourlyProductivityChart({
    super.key,
    required this.hourlyDistribution,
    this.height = 200,
  });

  final Map<int, int> hourlyDistribution;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (hourlyDistribution.isEmpty) {
      return _buildEmptyChart(context, 'No hourly data available');
    }

    final barGroups = <BarChartGroupData>[];
    final maxCount = hourlyDistribution.values.reduce(max);

    for (var hour = 0; hour < 24; hour++) {
      final count = hourlyDistribution[hour] ?? 0;
      final intensity = count / maxCount;

      barGroups.add(
        BarChartGroupData(
          x: hour,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: Color.lerp(
                colorScheme.primary.withValues(alpha: 0.3),
                colorScheme.primary,
                intensity,
              ),
              width: 12,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          barGroups: barGroups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: max(1, maxCount / 5).toDouble(),
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.outline.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 4,
                getTitlesWidget: (value, meta) {
                  final hour = value.toInt();
                  if (hour % 4 == 0) {
                    return Text(
                      _formatHour(hour),
                      style: theme.textTheme.labelSmall,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border:
                Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
          ),
          maxY: maxCount.toDouble() + 1,
        ),
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context, String message) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12AM';
    if (hour < 12) return '${hour}AM';
    if (hour == 12) return '12PM';
    return '${hour - 12}PM';
  }
}

/// Chart widget for deadline adherence
class DeadlineAdherenceChart extends StatelessWidget {
  const DeadlineAdherenceChart({
    super.key,
    required this.deadlineMetrics,
    this.height = 200,
  });

  final DeadlineAdherenceMetrics deadlineMetrics;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (deadlineMetrics.adherenceData.isEmpty) {
      return _buildEmptyChart(context, 'No deadline data available');
    }

    final sections = [
      PieChartSectionData(
        value: deadlineMetrics.onTimeCompletions.toDouble(),
        title: '${deadlineMetrics.onTimeCompletions}',
        color: Colors.green,
        radius: 60,
        titleStyle: theme.textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      PieChartSectionData(
        value: deadlineMetrics.earlyCompletions.toDouble(),
        title: '${deadlineMetrics.earlyCompletions}',
        color: Colors.blue,
        radius: 60,
        titleStyle: theme.textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      PieChartSectionData(
        value: deadlineMetrics.lateCompletions.toDouble(),
        title: '${deadlineMetrics.lateCompletions}',
        color: Colors.red,
        radius: 60,
        titleStyle: theme.textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ].where((section) => section.value > 0).toList();

    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegendItem(
                  'On Time',
                  deadlineMetrics.onTimeCompletions,
                  Colors.green,
                  theme,
                ),
                _buildLegendItem(
                  'Early',
                  deadlineMetrics.earlyCompletions,
                  Colors.blue,
                  theme,
                ),
                _buildLegendItem(
                  'Late',
                  deadlineMetrics.lateCompletions,
                  Colors.red,
                  theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
      String label, int count, Color color, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $count',
              style: theme.textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context, String message) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chart widget for weekly productivity trends
class WeeklyTrendsChart extends StatelessWidget {
  const WeeklyTrendsChart({
    super.key,
    required this.weeklyTrends,
    this.height = 200,
  });

  final List<WeeklyProductivity> weeklyTrends;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (weeklyTrends.isEmpty) {
      return _buildEmptyChart(context, 'No weekly data available');
    }

    final sortedWeeks = weeklyTrends.toList()
      ..sort((a, b) => a.weekStart.compareTo(b.weekStart));

    final barGroups = <BarChartGroupData>[];

    for (var i = 0; i < sortedWeeks.length; i++) {
      final week = sortedWeeks[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: week.tasksCompleted.toDouble(),
              color: colorScheme.primary,
              width: 20,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    final maxTasks = sortedWeeks.map((w) => w.tasksCompleted).reduce(max);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          barGroups: barGroups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: max(1, maxTasks / 5).toDouble(),
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.outline.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < sortedWeeks.length) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat.Md().format(sortedWeeks[index].weekStart),
                          style: theme.textTheme.labelSmall,
                        ),
                        Text(
                          'Week',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border:
                Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
          ),
          maxY: maxTasks.toDouble() + 2,
        ),
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context, String message) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Productivity score gauge widget
class ProductivityScoreGauge extends StatelessWidget {
  const ProductivityScoreGauge({
    super.key,
    required this.score,
    this.size = 120,
  });

  final double score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final normalizedScore = score / 100.0;
    final scoreColor = _getScoreColor(score);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          // Score circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: normalizedScore,
              strokeWidth: 8,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            ),
          ),
          // Score text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${score.round()}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
              Text(
                'Score',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.red;
    return Colors.grey;
  }
}

/// Compact analytics summary card
class AnalyticsSummaryCard extends StatelessWidget {
  const AnalyticsSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.color,
    this.trend,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? color;
  final double? trend; // Positive = up, negative = down

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveColor = color ?? colorScheme.primary;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: effectiveColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trend != null)
                  Icon(
                    trend! > 0 ? Icons.trending_up : Icons.trending_down,
                    color: trend! > 0 ? Colors.green : Colors.red,
                    size: 14,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: effectiveColor,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
