import 'package:flutter/material.dart';

/// Header widget for task groups with title, count, and optional accent color
class TaskGroupHeader extends StatelessWidget {
  const TaskGroupHeader({
    super.key,
    required this.title,
    required this.taskCount,
    this.accentColor,
    this.onTap,
    this.isExpanded = true,
    this.showExpandIcon = false,
  });

  final String title;
  final int taskCount;
  final Color? accentColor;
  final VoidCallback? onTap;
  final bool isExpanded;
  final bool showExpandIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine urgency color based on title
    Color effectiveAccentColor =
        accentColor ?? _getUrgencyColor(title, colorScheme);

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Accent color indicator
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: effectiveAccentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const SizedBox(width: 12),

                // Title and count
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: effectiveAccentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: effectiveAccentColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _formatTaskCount(taskCount),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: effectiveAccentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Expand/collapse icon
                if (showExpandIcon)
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getUrgencyColor(String title, ColorScheme colorScheme) {
    switch (title.toLowerCase()) {
      case 'overdue':
        return Colors.red;
      case 'today':
        return Colors.orange;
      case 'tomorrow':
        return Colors.blue;
      case 'this week':
        return colorScheme.primary;
      case 'later':
        return colorScheme.secondary;
      case 'no due date':
        return Colors.grey;
      default:
        return colorScheme.primary;
    }
  }

  String _formatTaskCount(int count) {
    if (count == 0) return '0 tasks';
    if (count == 1) return '1 task';
    return '$count tasks';
  }
}

/// Expandable task group with header and content
class ExpandableTaskGroup extends StatefulWidget {
  const ExpandableTaskGroup({
    super.key,
    required this.header,
    required this.children,
    this.initiallyExpanded = true,
    this.maintainState = true,
  });

  final TaskGroupHeader header;
  final List<Widget> children;
  final bool initiallyExpanded;
  final bool maintainState;

  @override
  State<ExpandableTaskGroup> createState() => _ExpandableTaskGroupState();
}

class _ExpandableTaskGroupState extends State<ExpandableTaskGroup>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskGroupHeader(
          title: widget.header.title,
          taskCount: widget.header.taskCount,
          accentColor: widget.header.accentColor,
          isExpanded: _isExpanded,
          showExpandIcon: true,
          onTap: _toggleExpanded,
        ),
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: widget.maintainState
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.children,
                )
              : _isExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.children,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Empty state widget for task groups
class EmptyTaskGroup extends StatelessWidget {
  const EmptyTaskGroup({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.task_alt,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}
