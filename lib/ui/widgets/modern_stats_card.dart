import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';

class ModernStatsCard extends StatelessWidget {
  const ModernStatsCard({
    required this.greeting,
    required this.email,
    required this.stats,
    required this.isCollapsed,
    required this.onToggleCollapse,
    super.key,
  });

  final String greeting;
  final String email;
  final List<StatItem> stats;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Compact header design with gradient accent
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: DuruSpacing.md,
        vertical: DuruSpacing.sm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggleCollapse,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  DuruColors.primary.withValues(alpha: 0.05),
                  DuruColors.accent.withValues(alpha: 0.03),
                ],
                stops: const [0.0, 1.0],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            padding: EdgeInsets.all(DuruSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Compact header row
                Row(
                  children: [
                    // User avatar with gradient border
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [DuruColors.primary, DuruColors.accent],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            email.substring(0, 2).toUpperCase(),
                            style: TextStyle(
                              color: DuruColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: DuruSpacing.sm),
                    // Greeting and stats summary
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            _getStatsummary(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Collapse/Expand button
                    Container(
                      padding: EdgeInsets.all(DuruSpacing.xs),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isCollapsed
                            ? CupertinoIcons.chevron_down
                            : CupertinoIcons.chevron_up,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                // Animated stats section
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    children: [
                      SizedBox(height: DuruSpacing.md),
                      Container(
                        padding: EdgeInsets.all(DuruSpacing.sm),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: stats
                              .map((stat) => _buildStatItem(context, stat))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  crossFadeState: isCollapsed
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, StatItem stat) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(DuruSpacing.sm),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                stat.color?.withValues(alpha: 0.1) ??
                    DuruColors.primary.withValues(alpha: 0.1),
                stat.color?.withValues(alpha: 0.05) ??
                    DuruColors.primary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            stat.icon,
            size: 20,
            color: stat.color ?? DuruColors.primary,
          ),
        ),
        SizedBox(height: DuruSpacing.xs),
        Text(
          stat.value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          stat.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  String _getStatsummary() {
    if (stats.isEmpty) return '';

    final noteCount = stats.firstWhere(
      (s) => s.label.toLowerCase().contains('note'),
      orElse: () => StatItem(icon: Icons.note, value: '0', label: 'Notes'),
    );

    final folderCount = stats.firstWhere(
      (s) => s.label.toLowerCase().contains('folder'),
      orElse: () => StatItem(icon: Icons.folder, value: '0', label: 'Folders'),
    );

    return '${noteCount.value} notes • ${folderCount.value} folders';
  }
}

class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: color ?? theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
