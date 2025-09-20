import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/productivity_goals_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dialog for creating and managing productivity goals
class GoalsDialog extends ConsumerStatefulWidget {
  const GoalsDialog({super.key});
  
  @override
  ConsumerState<GoalsDialog> createState() => _GoalsDialogState();
}

class _GoalsDialogState extends ConsumerState<GoalsDialog> {
  final _formKey = GlobalKey<FormState>();
  
  GoalType _selectedType = GoalType.tasksCompleted;
  GoalPeriod _selectedPeriod = GoalPeriod.daily;
  int _targetValue = 5;
  String _customDescription = '';
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.flag,
                    color: colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Set Productivity Goal',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Goal Type Selection
              Text(
                'Goal Type',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<GoalType>(
                value: _selectedType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: GoalType.values.map((type) => DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(_getIconForGoalType(type), size: 20),
                      const SizedBox(width: 8),
                      Text(_getDisplayNameForGoalType(type)),
                    ],
                  ),
                )).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                      _updateDefaultTarget();
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Period Selection
              Text(
                'Time Period',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<GoalPeriod>(
                selected: {_selectedPeriod},
                onSelectionChanged: (selected) {
                  setState(() {
                    _selectedPeriod = selected.first;
                    _updateDefaultTarget();
                  });
                },
                segments: const [
                  ButtonSegment(
                    value: GoalPeriod.daily,
                    label: Text('Daily'),
                    icon: Icon(Icons.today),
                  ),
                  ButtonSegment(
                    value: GoalPeriod.weekly,
                    label: Text('Weekly'),
                    icon: Icon(Icons.date_range),
                  ),
                  ButtonSegment(
                    value: GoalPeriod.monthly,
                    label: Text('Monthly'),
                    icon: Icon(Icons.calendar_month),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Target Value
              Text(
                'Target',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _targetValue.toDouble(),
                      min: _getMinTarget(),
                      max: _getMaxTarget(),
                      divisions: (_getMaxTarget() - _getMinTarget()).toInt(),
                      label: _targetValue.toString(),
                      onChanged: (value) {
                        setState(() {
                          _targetValue = value.toInt();
                        });
                      },
                    ),
                  ),
                  Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatTargetValue(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _getGoalDescription(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              
              // Custom Description (Optional)
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add any additional notes about this goal',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                maxLines: 2,
                onChanged: (value) {
                  _customDescription = value;
                },
              ),
              const SizedBox(height: 24),
              
              // Current Goals List
              FutureBuilder<List<ProductivityGoal>>(
                future: ref.read(productivityGoalsServiceProvider).getActiveGoals(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Goals',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: snapshot.data!.length,
                            itemBuilder: (context, index) {
                              final goal = snapshot.data![index];
                              return ListTile(
                                leading: Icon(
                                  _getIconForGoalType(goal.type),
                                  color: goal.isCompleted 
                                    ? Colors.green 
                                    : colorScheme.primary,
                                ),
                                title: Text(goal.description),
                                subtitle: LinearProgressIndicator(
                                  value: goal.currentValue / goal.targetValue,
                                  backgroundColor: colorScheme.surfaceVariant,
                                  valueColor: AlwaysStoppedAnimation(
                                    goal.isCompleted 
                                      ? Colors.green 
                                      : colorScheme.primary,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    await ref.read(productivityGoalsServiceProvider)
                                      .deleteGoal(goal.id);
                                    setState(() {});
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _createGoal,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Goal'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _updateDefaultTarget() {
    setState(() {
      switch (_selectedType) {
        case GoalType.tasksCompleted:
          _targetValue = _selectedPeriod == GoalPeriod.daily ? 5 
            : _selectedPeriod == GoalPeriod.weekly ? 30 : 100;
          break;
        case GoalType.completionRate:
          _targetValue = 80;
          break;
        case GoalType.timeAccuracy:
          _targetValue = 80;
          break;
        case GoalType.dailyStreak:
          _targetValue = 7;
          break;
        case GoalType.deadlineAdherence:
          _targetValue = 90;
          break;
        case GoalType.timeSpent:
          _targetValue = _selectedPeriod == GoalPeriod.daily ? 120 
            : _selectedPeriod == GoalPeriod.weekly ? 600 : 2400;
          break;
        case GoalType.averageTasksPerDay:
          _targetValue = 5;
          break;
      }
    });
  }
  
  double _getMinTarget() {
    switch (_selectedType) {
      case GoalType.tasksCompleted:
        return 1;
      case GoalType.completionRate:
        return 10;
      case GoalType.timeAccuracy:
        return 10;
      case GoalType.dailyStreak:
        return 1;
      case GoalType.deadlineAdherence:
        return 10;
      case GoalType.timeSpent:
        return 15;
      case GoalType.averageTasksPerDay:
        return 1;
    }
  }
  
  double _getMaxTarget() {
    switch (_selectedType) {
      case GoalType.tasksCompleted:
        return _selectedPeriod == GoalPeriod.daily ? 20 
          : _selectedPeriod == GoalPeriod.weekly ? 100 : 500;
      case GoalType.completionRate:
        return 100;
      case GoalType.timeAccuracy:
        return 100;
      case GoalType.dailyStreak:
        return 365;
      case GoalType.deadlineAdherence:
        return 100;
      case GoalType.timeSpent:
        return _selectedPeriod == GoalPeriod.daily ? 480 
          : _selectedPeriod == GoalPeriod.weekly ? 2400 : 10000;
      case GoalType.averageTasksPerDay:
        return 50;
    }
  }
  
  String _formatTargetValue() {
    switch (_selectedType) {
      case GoalType.completionRate:
        return '$_targetValue%';
      case GoalType.tasksCompleted:
        return _targetValue.toString();
      case GoalType.timeAccuracy:
        return '$_targetValue%';
      case GoalType.dailyStreak:
        return '$_targetValue days';
      case GoalType.deadlineAdherence:
        return '$_targetValue%';
      case GoalType.timeSpent:
        return '${_targetValue}m';
      case GoalType.averageTasksPerDay:
        return _targetValue.toString();
    }
  }
  
  String _getGoalDescription() {
    final period = _selectedPeriod.name;
    switch (_selectedType) {
      case GoalType.tasksCompleted:
        return 'Complete $_targetValue tasks $period';
      case GoalType.completionRate:
        return 'Achieve $_targetValue% completion rate $period';
      case GoalType.timeAccuracy:
        return 'Achieve $_targetValue% time estimation accuracy $period';
      case GoalType.dailyStreak:
        return 'Maintain a $_targetValue day completion streak';
      case GoalType.deadlineAdherence:
        return 'Meet $_targetValue% of deadlines $period';
      case GoalType.timeSpent:
        return 'Spend ${_formatTargetValue()} on tasks $period';
      case GoalType.averageTasksPerDay:
        return 'Average $_targetValue tasks per day';
    }
  }
  
  IconData _getIconForGoalType(GoalType type) {
    switch (type) {
      case GoalType.tasksCompleted:
        return Icons.check_box;
      case GoalType.completionRate:
        return Icons.pie_chart;
      case GoalType.timeAccuracy:
        return Icons.access_time;
      case GoalType.dailyStreak:
        return Icons.local_fire_department;
      case GoalType.deadlineAdherence:
        return Icons.schedule;
      case GoalType.timeSpent:
        return Icons.timer;
      case GoalType.averageTasksPerDay:
        return Icons.trending_up;
    }
  }
  
  String _getDisplayNameForGoalType(GoalType type) {
    switch (type) {
      case GoalType.tasksCompleted:
        return 'Task Completion';
      case GoalType.completionRate:
        return 'Completion Rate';
      case GoalType.timeAccuracy:
        return 'Time Accuracy';
      case GoalType.dailyStreak:
        return 'Daily Streak';
      case GoalType.deadlineAdherence:
        return 'Deadline Adherence';
      case GoalType.timeSpent:
        return 'Time Spent';
      case GoalType.averageTasksPerDay:
        return 'Average Tasks/Day';
    }
  }
  
  Future<void> _createGoal() async {
    if (_formKey.currentState!.validate()) {
      final goalsService = ref.read(productivityGoalsServiceProvider);
      
      final goal = ProductivityGoal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _getDisplayNameForGoalType(_selectedType),
        type: _selectedType,
        period: _selectedPeriod,
        targetValue: _targetValue.toDouble(),
        currentValue: 0,
        description: _customDescription.isNotEmpty 
          ? _customDescription 
          : _getGoalDescription(),
        startDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
        isCompleted: false,
        metadata: {},
      );
      
      await goalsService.createGoal(
        title: goal.title,
        description: goal.description,
        type: goal.type,
        period: goal.period,
        targetValue: goal.targetValue,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Goal created: ${goal.description}'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(goal);
      }
    }
  }
}
