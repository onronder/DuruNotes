import 'package:flutter/material.dart';

/// Configuration for metric card display
class MetricCardConfig {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final double? trend;
  final String? trendLabel;
  final String? subtitle;
  final VoidCallback? onTap;
  final double elevation;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool showTrendIcon;
  final Widget? customContent;

  const MetricCardConfig({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.trend,
    this.trendLabel,
    this.subtitle,
    this.onTap,
    this.elevation = 1,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.all(16),
    this.showTrendIcon = true,
    this.customContent,
  });

  factory MetricCardConfig.simple({
    required String title,
    required String value,
    required IconData icon,
    Color? color,
    String? subtitle,
  }) {
    return MetricCardConfig(
      title: title,
      value: value,
      icon: icon,
      color: color,
      subtitle: subtitle,
    );
  }

  factory MetricCardConfig.withTrend({
    required String title,
    required String value,
    required double trend,
    required IconData icon,
    String? trendLabel,
    Color? color,
  }) {
    return MetricCardConfig(
      title: title,
      value: value,
      icon: icon,
      trend: trend,
      trendLabel: trendLabel,
      color: color,
    );
  }
}

/// Unified metric card widget for analytics displays
class UnifiedMetricCard extends StatelessWidget {
  final MetricCardConfig config;

  const UnifiedMetricCard({
    super.key,
    required this.config,
  });

  factory UnifiedMetricCard.simple({
    required String title,
    required String value,
    required IconData icon,
    Color? color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return UnifiedMetricCard(
      config: MetricCardConfig.simple(
        title: title,
        value: value,
        icon: icon,
        color: color,
        subtitle: subtitle,
      ),
    );
  }

  factory UnifiedMetricCard.withTrend({
    required String title,
    required String value,
    required double trend,
    required IconData icon,
    String? trendLabel,
    Color? color,
    VoidCallback? onTap,
  }) {
    return UnifiedMetricCard(
      config: MetricCardConfig.withTrend(
        title: title,
        value: value,
        trend: trend,
        icon: icon,
        trendLabel: trendLabel,
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveColor = config.color ?? colorScheme.primary;

    return Card(
      elevation: config.elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(config.borderRadius),
      ),
      child: InkWell(
        onTap: config.onTap,
        borderRadius: BorderRadius.circular(config.borderRadius),
        child: Padding(
          padding: config.padding,
          child: config.customContent ??
              _buildDefaultContent(context, effectiveColor),
        ),
      ),
    );
  }

  Widget _buildDefaultContent(BuildContext context, Color effectiveColor) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with icon and title
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: effectiveColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                config.icon,
                color: effectiveColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                config.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Value
        Text(
          config.value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),

        // Subtitle or trend
        if (config.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            config.subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],

        if (config.trend != null) ...[
          const SizedBox(height: 8),
          _buildTrendIndicator(context, effectiveColor),
        ],
      ],
    );
  }

  Widget _buildTrendIndicator(BuildContext context, Color effectiveColor) {
    final theme = Theme.of(context);
    final isPositive = config.trend! > 0;
    final isNeutral = config.trend! == 0;

    final trendColor = isNeutral
        ? theme.colorScheme.onSurfaceVariant
        : isPositive
            ? Colors.green
            : Colors.red;

    final trendIcon = isNeutral
        ? Icons.remove
        : isPositive
            ? Icons.trending_up
            : Icons.trending_down;

    final trendText = isNeutral
        ? '0%'
        : '${isPositive ? '+' : ''}${config.trend!.toStringAsFixed(1)}%';

    return Row(
      children: [
        if (config.showTrendIcon)
          Icon(
            trendIcon,
            color: trendColor,
            size: 16,
          ),
        if (config.showTrendIcon) const SizedBox(width: 4),
        Text(
          trendText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: trendColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (config.trendLabel != null) ...[
          const SizedBox(width: 4),
          Text(
            config.trendLabel!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Quick stats widget using metric cards
class QuickStatsWidget extends StatelessWidget {
  final List<MetricCardConfig> metrics;
  final int crossAxisCount;
  final double spacing;
  final double childAspectRatio;

  const QuickStatsWidget({
    super.key,
    required this.metrics,
    this.crossAxisCount = 2,
    this.spacing = 12,
    this.childAspectRatio = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        return UnifiedMetricCard(config: metrics[index]);
      },
    );
  }
}

/// Streak card for habit tracking
class StreakCard extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;
  final String title;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const StreakCard({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
    required this.title,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return UnifiedMetricCard(
      config: MetricCardConfig(
        title: title,
        value: '$currentStreak days',
        icon: icon,
        color: effectiveColor,
        onTap: onTap,
        customContent: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: effectiveColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: effectiveColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Best: $bestStreak days',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currentStreak.toString(),
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: effectiveColor,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'days',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                if (currentStreak > 0)
                  Icon(
                    Icons.local_fire_department,
                    color: currentStreak >= 7
                        ? Colors.orange
                        : theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                    size: 32,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: bestStreak > 0 ? currentStreak / bestStreak : 0,
              backgroundColor: theme.colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
            ),
          ],
        ),
      ),
    );
  }
}
