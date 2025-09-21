import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Theme configuration for charts
class ChartTheme {
  final Color gridColor;
  final Color borderColor;
  final Color lineColor;
  final Color dotColor;
  final Color tooltipBackground;
  final Color tooltipText;
  final TextStyle? titleStyle;
  final TextStyle? labelStyle;

  const ChartTheme({
    required this.gridColor,
    required this.borderColor,
    required this.lineColor,
    required this.dotColor,
    required this.tooltipBackground,
    required this.tooltipText,
    this.titleStyle,
    this.labelStyle,
  });

  factory ChartTheme.fromContext(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ChartTheme(
      gridColor: colorScheme.surfaceContainerHighest
          .withValues(alpha: isDark ? 0.3 : 0.5),
      borderColor: colorScheme.outline.withValues(alpha: 0.3),
      lineColor: colorScheme.primary,
      dotColor: colorScheme.primary,
      tooltipBackground: colorScheme.surface,
      tooltipText: colorScheme.onSurface,
      titleStyle: theme.textTheme.titleSmall,
      labelStyle: theme.textTheme.bodySmall,
    );
  }
}

/// Configuration for chart display
class ChartConfig {
  final bool showGrid;
  final bool drawVerticalLines;
  final bool drawHorizontalLines;
  final double? minY;
  final double? maxY;
  final double? minX;
  final double? maxX;
  final double horizontalInterval;
  final double verticalInterval;
  final double gridOpacity;
  final double gridStrokeWidth;
  final bool showTooltips;
  final bool showDots;
  final double dotRadius;
  final double lineWidth;
  final bool isCurved;
  final double curveSmoothness;

  const ChartConfig({
    this.showGrid = true,
    this.drawVerticalLines = true,
    this.drawHorizontalLines = true,
    this.minY,
    this.maxY,
    this.minX,
    this.maxX,
    this.horizontalInterval = 1,
    this.verticalInterval = 1,
    this.gridOpacity = 0.3,
    this.gridStrokeWidth = 1,
    this.showTooltips = true,
    this.showDots = true,
    this.dotRadius = 4,
    this.lineWidth = 2,
    this.isCurved = true,
    this.curveSmoothness = 0.35,
  });

  static const ChartConfig defaults = ChartConfig();

  factory ChartConfig.minimal() {
    return const ChartConfig(
      showGrid: false,
      showDots: false,
      showTooltips: false,
    );
  }

  factory ChartConfig.detailed() {
    return const ChartConfig(
      showGrid: true,
      showDots: true,
      showTooltips: true,
      dotRadius: 5,
      lineWidth: 3,
    );
  }
}

/// Unified chart builders for consistent chart creation
class ChartBuilders {
  /// Build a line chart with the given data and configuration
  static LineChartData buildLineChart({
    required List<FlSpot> spots,
    required ChartTheme theme,
    ChartConfig config = ChartConfig.defaults,
    String? title,
    List<String>? bottomTitles,
    List<String>? leftTitles,
  }) {
    return LineChartData(
      gridData: _buildGridData(theme, config),
      titlesData: _buildTitlesData(theme, config, bottomTitles, leftTitles),
      borderData: _buildBorderData(theme, config),
      lineBarsData: [_buildLineBarData(spots, theme, config)],
      minY: config.minY ?? _calculateMinY(spots),
      maxY: config.maxY ?? _calculateMaxY(spots),
      minX: config.minX ?? _calculateMinX(spots),
      maxX: config.maxX ?? _calculateMaxX(spots),
      lineTouchData: _buildLineTouchData(theme, config),
    );
  }

  /// Build a bar chart with the given data
  static BarChartData buildBarChart({
    required List<BarChartGroupData> barGroups,
    required ChartTheme theme,
    ChartConfig config = ChartConfig.defaults,
    List<String>? bottomTitles,
    List<String>? leftTitles,
  }) {
    return BarChartData(
      gridData: _buildGridData(theme, config),
      titlesData: _buildTitlesData(theme, config, bottomTitles, leftTitles),
      borderData: _buildBorderData(theme, config),
      barGroups: barGroups,
      minY: config.minY ?? 0,
      maxY: config.maxY,
      barTouchData: _buildBarTouchData(theme, config),
    );
  }

  /// Build a pie chart with the given data
  static PieChartData buildPieChart({
    required List<PieChartSectionData> sections,
    required ChartTheme theme,
    bool showSectionValues = true,
    double centerSpaceRadius = 40,
    double sectionsSpace = 2,
  }) {
    return PieChartData(
      sections: sections,
      centerSpaceRadius: centerSpaceRadius,
      sectionsSpace: sectionsSpace,
      pieTouchData: PieTouchData(
        enabled: true,
      ),
    );
  }

  /// Create bar groups for a simple bar chart
  static List<BarChartGroupData> createBarGroups({
    required List<double> values,
    Color? color,
    double width = 22,
    double borderRadius = 8,
  }) {
    return values.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: color ?? Colors.blue,
            width: width,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ],
      );
    }).toList();
  }

  /// Create pie chart sections
  static List<PieChartSectionData> createPieSections({
    required List<double> values,
    required List<String> labels,
    required List<Color> colors,
    double radius = 50,
    bool showTitle = true,
    TextStyle? titleStyle,
  }) {
    assert(values.length == labels.length && values.length == colors.length);

    final total = values.reduce((a, b) => a + b);

    return List.generate(values.length, (index) {
      final percentage = (values[index] / total * 100).toStringAsFixed(1);

      return PieChartSectionData(
        value: values[index],
        title: showTitle ? '$percentage%' : '',
        color: colors[index],
        radius: radius,
        titleStyle: titleStyle ??
            const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
      );
    });
  }

  // Private helper methods

  static FlGridData _buildGridData(ChartTheme theme, ChartConfig config) {
    return FlGridData(
      show: config.showGrid,
      drawVerticalLine: config.drawVerticalLines,
      drawHorizontalLine: config.drawHorizontalLines,
      horizontalInterval: config.horizontalInterval,
      verticalInterval: config.verticalInterval,
      getDrawingHorizontalLine: (value) => FlLine(
        color: theme.gridColor.withValues(alpha: config.gridOpacity),
        strokeWidth: config.gridStrokeWidth,
      ),
      getDrawingVerticalLine: (value) => FlLine(
        color: theme.gridColor.withValues(alpha: config.gridOpacity),
        strokeWidth: config.gridStrokeWidth,
      ),
    );
  }

  static FlTitlesData _buildTitlesData(
    ChartTheme theme,
    ChartConfig config,
    List<String>? bottomTitles,
    List<String>? leftTitles,
  ) {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: bottomTitles != null,
          getTitlesWidget: bottomTitles != null
              ? (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < bottomTitles.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        bottomTitles[index],
                        style: theme.labelStyle,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }
              : (value, meta) => const SizedBox.shrink(),
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: leftTitles != null,
          getTitlesWidget: leftTitles != null
              ? (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < leftTitles.length) {
                    return Text(
                      leftTitles[index],
                      style: theme.labelStyle,
                    );
                  }
                  return const SizedBox.shrink();
                }
              : (value, meta) => Text(
                    value.toInt().toString(),
                    style: theme.labelStyle,
                  ),
        ),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
    );
  }

  static FlBorderData _buildBorderData(ChartTheme theme, ChartConfig config) {
    return FlBorderData(
      show: true,
      border: Border.all(
        color: theme.borderColor,
        width: 1,
      ),
    );
  }

  static LineChartBarData _buildLineBarData(
    List<FlSpot> spots,
    ChartTheme theme,
    ChartConfig config,
  ) {
    return LineChartBarData(
      spots: spots,
      isCurved: config.isCurved,
      curveSmoothness: config.curveSmoothness,
      color: theme.lineColor,
      barWidth: config.lineWidth,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: config.showDots,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: config.dotRadius,
            color: theme.dotColor,
            strokeWidth: 2,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: theme.lineColor.withValues(alpha: 0.1),
      ),
    );
  }

  static LineTouchData _buildLineTouchData(
      ChartTheme theme, ChartConfig config) {
    if (!config.showTooltips) {
      return const LineTouchData(enabled: false);
    }

    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            return LineTooltipItem(
              spot.y.toStringAsFixed(1),
              TextStyle(
                color: theme.tooltipText,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList();
        },
      ),
    );
  }

  static BarTouchData _buildBarTouchData(ChartTheme theme, ChartConfig config) {
    if (!config.showTooltips) {
      return BarTouchData(enabled: false);
    }

    return BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          return BarTooltipItem(
            rod.toY.toStringAsFixed(1),
            TextStyle(
              color: theme.tooltipText,
              fontWeight: FontWeight.bold,
            ),
          );
        },
      ),
    );
  }

  static double _calculateMinY(List<FlSpot> spots) {
    if (spots.isEmpty) return 0;
    return spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
  }

  static double _calculateMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) return 10;
    return spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
  }

  static double _calculateMinX(List<FlSpot> spots) {
    if (spots.isEmpty) return 0;
    return spots.map((s) => s.x).reduce((a, b) => a < b ? a : b);
  }

  static double _calculateMaxX(List<FlSpot> spots) {
    if (spots.isEmpty) return 10;
    return spots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
  }
}
