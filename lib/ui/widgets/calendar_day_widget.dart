import 'package:duru_notes/data/local/app_db.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Calendar day widget with visual indicators for tasks
class CalendarDayWidget extends StatelessWidget {
  const CalendarDayWidget({
    super.key,
    required this.date,
    required this.tasks,
    required this.isSelected,
    required this.onTap,
    this.isToday = false,
    this.isCurrentMonth = true,
  });

  final DateTime date;
  final List<NoteTask> tasks;
  final bool isSelected;
  final bool isToday;
  final bool isCurrentMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine task priority levels
    final hasUrgent = tasks.any((t) => t.priority == TaskPriority.urgent);
    final hasHigh = tasks.any((t) => t.priority == TaskPriority.high);
    final hasMedium = tasks.any((t) => t.priority == TaskPriority.medium);
    final hasOverdue = tasks.any((t) =>
        t.dueDate != null &&
        t.dueDate!.isBefore(DateTime.now()) &&
        t.status != TaskStatus.completed);

    // Determine indicator color based on highest priority
    Color? indicatorColor;
    if (hasOverdue) {
      indicatorColor = Colors.red.shade700;
    } else if (hasUrgent) {
      indicatorColor = Colors.purple;
    } else if (hasHigh) {
      indicatorColor = Colors.red;
    } else if (hasMedium) {
      indicatorColor = Colors.orange;
    } else if (tasks.isNotEmpty) {
      indicatorColor = Colors.green;
    }

    // Filter incomplete tasks for count
    final incompleteTasks =
        tasks.where((t) => t.status != TaskStatus.completed).toList();
    final completedTasks =
        tasks.where((t) => t.status == TaskStatus.completed).toList();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: _getBackgroundColor(colorScheme),
            borderRadius: BorderRadius.circular(8),
            border: _getBorder(colorScheme),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Date number
              Text(
                date.day.toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _getTextColor(colorScheme),
                  fontWeight: isToday || isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),

              const SizedBox(height: 2),

              // Task indicators
              if (tasks.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Main indicator dot
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: indicatorColor,
                      ),
                    ),

                    // Additional dots for multiple tasks
                    if (incompleteTasks.length > 1) ...[
                      const SizedBox(width: 2),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: indicatorColor?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],

                    if (incompleteTasks.length > 2) ...[
                      const SizedBox(width: 1),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: indicatorColor?.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 1),

                // Task count (only show if more than 1 incomplete task)
                if (incompleteTasks.length > 1)
                  Text(
                    incompleteTasks.length.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: _getTextColor(colorScheme).withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                // Completed indicator (small check if all tasks completed)
                if (incompleteTasks.isEmpty && completedTasks.isNotEmpty)
                  Icon(
                    Icons.check_circle,
                    size: 10,
                    color: Colors.green.withValues(alpha: 0.7),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color? _getBackgroundColor(ColorScheme colorScheme) {
    if (isSelected) {
      return colorScheme.primary;
    } else if (isToday) {
      return colorScheme.primaryContainer;
    } else if (!isCurrentMonth) {
      return colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
    }
    return null;
  }

  Border? _getBorder(ColorScheme colorScheme) {
    if (isToday && !isSelected) {
      return Border.all(
        color: colorScheme.primary,
        width: 2,
      );
    }
    return null;
  }

  Color _getTextColor(ColorScheme colorScheme) {
    if (isSelected) {
      return colorScheme.onPrimary;
    } else if (isToday) {
      return colorScheme.onPrimaryContainer;
    } else if (!isCurrentMonth) {
      return colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    }
    return colorScheme.onSurface;
  }
}

/// Compact calendar month widget
class CalendarMonthWidget extends StatelessWidget {
  const CalendarMonthWidget({
    super.key,
    required this.month,
    required this.tasksByDate,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime month;
  final Map<DateTime, List<NoteTask>> tasksByDate;
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get first day of month and calculate calendar grid
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final firstDayOfCalendar = firstDayOfMonth.subtract(
      Duration(days: firstDayOfMonth.weekday % 7),
    );
    final lastDayOfCalendar = lastDayOfMonth.add(
      Duration(days: 6 - lastDayOfMonth.weekday % 7),
    );

    final days = <DateTime>[];
    var currentDay = firstDayOfCalendar;
    while (currentDay.isBefore(lastDayOfCalendar) ||
        currentDay.isAtSameMomentAs(lastDayOfCalendar)) {
      days.add(currentDay);
      currentDay = currentDay.add(const Duration(days: 1));
    }

    return Column(
      children: [
        // Weekday headers
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),

        // Calendar grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.0,
          ),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final date = days[index];
            final dateKey = DateTime(date.year, date.month, date.day);
            final tasks = tasksByDate[dateKey] ?? [];
            final isSelected = selectedDate != null &&
                selectedDate!.year == date.year &&
                selectedDate!.month == date.month &&
                selectedDate!.day == date.day;
            final isToday = dateKey.isAtSameMomentAs(today);
            final isCurrentMonth = date.month == month.month;

            return CalendarDayWidget(
              date: date,
              tasks: tasks,
              isSelected: isSelected,
              isToday: isToday,
              isCurrentMonth: isCurrentMonth,
              onTap: () => onDateSelected(dateKey),
            );
          },
        ),
      ],
    );
  }
}

/// Calendar header with month navigation
class CalendarHeader extends StatelessWidget {
  const CalendarHeader({
    super.key,
    required this.currentMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.onTodayTapped,
  });

  final DateTime currentMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback? onTodayTapped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isCurrentMonth =
        currentMonth.year == now.year && currentMonth.month == now.month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Previous month
          IconButton(
            onPressed: onPreviousMonth,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
          ),

          // Current month/year
          Expanded(
            child: GestureDetector(
              onTap: onTodayTapped,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat.yMMMM().format(currentMonth),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!isCurrentMonth && onTodayTapped != null)
                      Text(
                        'Tap to go to today',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Next month
          IconButton(
            onPressed: onNextMonth,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
          ),
        ],
      ),
    );
  }
}
