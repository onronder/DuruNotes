import 'package:duru_notes/services/productivity_goals_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget for displaying a productivity goal with progress
class ProductivityGoalCard extends StatelessWidget {
  const ProductivityGoalCard({
    super.key,
    required this.goal,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final ProductivityGoal goal;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progressColor = _getProgressColor(goal.progressPercentage);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      goal.type.icon,
                      color: progressColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          goal.period.displayName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (goal.isOverdue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'OVERDUE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (onEdit != null || onDelete != null)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onSelected: (action) {
                        switch (action) {
                          case 'edit':
                            onEdit?.call();
                            break;
                          case 'delete':
                            onDelete?.call();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 16),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                goal.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 16),

              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(
                        '${goal.currentValue.toStringAsFixed(goal.type == GoalType.tasksCompleted ? 0 : 1)} / ${goal.targetValue.toStringAsFixed(goal.type == GoalType.tasksCompleted ? 0 : 1)} ${goal.type.unit}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: goal.progressPercentage,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(goal.progressPercentage * 100).round()}% complete',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: progressColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (goal.daysRemaining != null)
                        Text(
                          '${goal.daysRemaining} days left',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 1.0) return Colors.green;
    if (progress >= 0.8) return Colors.lightGreen;
    if (progress >= 0.5) return Colors.orange;
    return Colors.red;
  }
}

/// Widget for creating new productivity goals
class CreateGoalDialog extends StatefulWidget {
  const CreateGoalDialog({
    super.key,
    required this.onGoalCreated,
  });

  final void Function(ProductivityGoal) onGoalCreated;

  @override
  State<CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends State<CreateGoalDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetController = TextEditingController();

  GoalType _selectedType = GoalType.tasksCompleted;
  GoalPeriod _selectedPeriod = GoalPeriod.weekly;
  DateTime? _deadline;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _createGoal() {
    if (_titleController.text.trim().isEmpty ||
        _targetController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final targetValue = double.tryParse(_targetController.text);
    if (targetValue == null || targetValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid target value')),
      );
      return;
    }

    final goal = ProductivityGoal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _selectedType,
      period: _selectedPeriod,
      targetValue: targetValue,
      currentValue: 0.0,
      startDate: DateTime.now(),
      deadline: _deadline,
      isActive: true,
      isCompleted: false,
      metadata: {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    widget.onGoalCreated(goal);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.flag, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Create Goal',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Goal Title',
                        hintText: 'e.g., Complete 50 tasks this month',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Description
                    TextField(
                      controller: _descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'Additional details about this goal',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Goal type
                    DropdownButtonFormField<GoalType>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Goal Type',
                        border: OutlineInputBorder(),
                      ),
                      items: GoalType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Icon(type.icon, size: 16),
                              const SizedBox(width: 8),
                              Text(type.displayName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedType = value!),
                    ),

                    const SizedBox(height: 16),

                    // Target value
                    TextField(
                      controller: _targetController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Target Value',
                        hintText: 'e.g., 50',
                        suffixText: _selectedType.unit,
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Period
                    DropdownButtonFormField<GoalPeriod>(
                      initialValue: _selectedPeriod,
                      decoration: const InputDecoration(
                        labelText: 'Time Period',
                        border: OutlineInputBorder(),
                      ),
                      items: GoalPeriod.values.map((period) {
                        return DropdownMenuItem(
                          value: period,
                          child: Text(period.displayName),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedPeriod = value!),
                    ),

                    const SizedBox(height: 16),

                    // Optional deadline
                    ListTile(
                      title: const Text('Deadline (optional)'),
                      subtitle: Text(
                        _deadline != null
                            ? DateFormat.yMMMd().format(_deadline!)
                            : 'No deadline set',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _selectDeadline,
                            icon: const Icon(Icons.calendar_today),
                          ),
                          if (_deadline != null)
                            IconButton(
                              onPressed: () => setState(() => _deadline = null),
                              icon: const Icon(Icons.clear),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _createGoal,
                  child: const Text('Create Goal'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() => _deadline = date);
    }
  }

  // Helper method _getProgressColor removed - unused in CreateGoalDialog
  // ProductivityGoalCard and GoalProgressWidget have their own copies
}

/// Compact goal progress widget
class GoalProgressWidget extends StatelessWidget {
  const GoalProgressWidget({
    super.key,
    required this.goal,
    this.compact = false,
  });

  final ProductivityGoal goal;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progressColor = _getProgressColor(goal.progressPercentage);

    if (compact) {
      return Row(
        children: [
          Icon(goal.type.icon, size: 16, color: progressColor),
          const SizedBox(width: 6),
          Expanded(
            child: LinearProgressIndicator(
              value: goal.progressPercentage,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 4,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${(goal.progressPercentage * 100).round()}%',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: progressColor,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              goal.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(goal.progressPercentage * 100).round()}%',
              style: theme.textTheme.titleSmall?.copyWith(
                color: progressColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: goal.progressPercentage,
          backgroundColor: colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          minHeight: 8,
        ),
        const SizedBox(height: 4),
        Text(
          '${goal.currentValue.toStringAsFixed(goal.type == GoalType.tasksCompleted ? 0 : 1)} / ${goal.targetValue.toStringAsFixed(goal.type == GoalType.tasksCompleted ? 0 : 1)} ${goal.type.unit}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 1.0) return Colors.green;
    if (progress >= 0.8) return Colors.lightGreen;
    if (progress >= 0.5) return Colors.orange;
    return Colors.red;
  }
}

/// Achievement celebration widget
class AchievementCard extends StatelessWidget {
  const AchievementCard({
    super.key,
    required this.achievement,
  });

  final ProductivityAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.amber.withValues(alpha: 0.1),
              Colors.orange.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: Colors.amber.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Achieved ${DateFormat.yMMMd().format(achievement.achievedAt)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                achievement.goalType.icon,
                color: Colors.amber.shade700,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Goals overview widget for dashboard
class GoalsOverviewWidget extends StatelessWidget {
  const GoalsOverviewWidget({
    super.key,
    required this.goals,
    required this.onViewAll,
  });

  final List<ProductivityGoal> goals;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (goals.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.flag,
                size: 48,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'No active goals',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Set productivity goals to track your progress',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onViewAll,
                icon: const Icon(Icons.add),
                label: const Text('Create Goal'),
              ),
            ],
          ),
        ),
      );
    }

    final activeGoals = goals.take(3).toList(); // Show max 3 goals

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Active Goals',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...activeGoals.map((goal) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GoalProgressWidget(goal: goal),
                )),
            if (goals.length > 3)
              Text(
                '+${goals.length - 3} more goals',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Suggested goals widget
class SuggestedGoalsWidget extends StatelessWidget {
  const SuggestedGoalsWidget({
    super.key,
    required this.suggestedGoals,
    required this.onGoalSelected,
  });

  final List<ProductivityGoal> suggestedGoals;
  final void Function(ProductivityGoal) onGoalSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (suggestedGoals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Suggested Goals',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...suggestedGoals.map((goal) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Icon(goal.type.icon, color: colorScheme.primary),
                    title: Text(goal.title),
                    subtitle: Text(goal.description),
                    trailing: FilledButton(
                      onPressed: () => onGoalSelected(goal),
                      child: const Text('Add'),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
