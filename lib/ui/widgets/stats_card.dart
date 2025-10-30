import 'package:duru_notes/core/ui/responsive.dart';
import 'package:flutter/material.dart';

class StatsCard extends StatelessWidget {
  const StatsCard({
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
    final compact = AppBreakpoints.isCompact(context);
    return Card(
      margin: EdgeInsets.all(compact ? 12 : 16),
      child: InkWell(
        onTap: onToggleCollapse,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: AppBreakpoints.clampControlsTextScale(
            context: context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: Theme.of(context).textTheme.headlineSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isCollapsed ? 'Expand' : 'Collapse',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isCollapsed ? Icons.expand_more : Icons.expand_less,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
                if (!isCollapsed) ...[
                  SizedBox(height: compact ? 12 : 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: stats,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatItem extends StatelessWidget {
  const StatItem({
    required this.icon,
    required this.value,
    required this.label,
    super.key,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
