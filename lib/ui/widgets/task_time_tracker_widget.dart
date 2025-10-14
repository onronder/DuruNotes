import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/data/local/app_db.dart';
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/features/tasks/providers/tasks_services_providers.dart' show enhancedTaskServiceProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Widget for tracking actual time spent on a task
class TaskTimeTrackerWidget extends ConsumerStatefulWidget {
  const TaskTimeTrackerWidget({
    super.key,
    required this.task,
    this.onTimeUpdated,
  });

  final NoteTask task;
  final VoidCallback? onTimeUpdated;

  @override
  ConsumerState<TaskTimeTrackerWidget> createState() =>
      _TaskTimeTrackerWidgetState();
}

class _TaskTimeTrackerWidgetState extends ConsumerState<TaskTimeTrackerWidget> {
  Timer? _timer;
  bool _isTracking = false;
  int _elapsedSeconds = 0;
  DateTime? _startTime;

  AppLogger get _logger => ref.read(loggerProvider);

  static const String _activeTaskKey = 'active_task_tracking';
  static const String _startTimeKey = 'task_tracking_start_time';

  @override
  void initState() {
    super.initState();
    _loadTrackingState();
    _elapsedSeconds = (widget.task.actualMinutes ?? 0) * 60;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTrackingState() async {
    final prefs = await SharedPreferences.getInstance();
    final activeTaskId = prefs.getString(_activeTaskKey);

    if (activeTaskId == widget.task.id) {
      final startTimeMillis = prefs.getInt(_startTimeKey);
      if (startTimeMillis != null) {
        _startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMillis);
        final elapsed = DateTime.now().difference(_startTime!);
        setState(() {
          _isTracking = true;
          _elapsedSeconds =
              ((widget.task.actualMinutes ?? 0) * 60) + elapsed.inSeconds;
        });
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSeconds++;
      });

      // Auto-save every minute
      if (_elapsedSeconds % 60 == 0) {
        _saveTimeToDatabase();
      }
    });
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await _stopTracking();
    } else {
      await _startTracking();
    }
  }

  Future<void> _startTracking() async {
    final prefs = await SharedPreferences.getInstance();

    // Stop any other active tracking
    final activeTaskId = prefs.getString(_activeTaskKey);
    if (activeTaskId != null && activeTaskId != widget.task.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stopped tracking other task'),
          duration: const Duration(seconds: 2),
        ),
      );
      _logger.info(
        'Stopping tracking on another task before starting new session',
        data: {'previousTaskId': activeTaskId, 'newTaskId': widget.task.id},
      );
    }

    // Start tracking this task
    _startTime = DateTime.now();
    await prefs.setString(_activeTaskKey, widget.task.id);
    await prefs.setInt(_startTimeKey, _startTime!.millisecondsSinceEpoch);

    setState(() {
      _isTracking = true;
    });

    _startTimer();
  }

  Future<void> _stopTracking() async {
    _timer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeTaskKey);
    await prefs.remove(_startTimeKey);

    setState(() {
      _isTracking = false;
    });

    await _saveTimeToDatabase();
    widget.onTimeUpdated?.call();
  }

  Future<void> _saveTimeToDatabase() async {
    final actualMinutes = (_elapsedSeconds / 60).round();

    try {
      final taskService = ref.read(enhancedTaskServiceProvider);
      await taskService.updateTask(
        taskId: widget.task.id,
        actualMinutes: actualMinutes,
      );
      _logger.debug(
        'Task time tracking saved',
        data: {'taskId': widget.task.id, 'actualMinutes': actualMinutes},
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to save time tracking',
        error: error,
        stackTrace: stackTrace,
        data: {'taskId': widget.task.id, 'elapsedSeconds': _elapsedSeconds},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Could not save tracked time. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_saveTimeToDatabase()),
            ),
          ),
        );
      }
    }
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final estimatedMinutes = widget.task.estimatedMinutes ?? 0;
    final actualMinutes = (_elapsedSeconds / 60).round();
    final progress = estimatedMinutes > 0
        ? (actualMinutes / estimatedMinutes).clamp(0.0, 2.0)
        : 0.0;

    Color progressColor;
    if (progress <= 0.8) {
      progressColor = Colors.green;
    } else if (progress <= 1.2) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }

    return Card(
      elevation: _isTracking ? 2 : 0,
      color: _isTracking ? colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 20,
                  color: _isTracking
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Time Tracking',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _isTracking ? colorScheme.onPrimaryContainer : null,
                  ),
                ),
                const Spacer(),
                // Timer display
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isTracking
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatTime(_elapsedSeconds),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: _isTracking
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            if (estimatedMinutes > 0) ...[
              const SizedBox(height: 12),

              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _isTracking
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '$actualMinutes / $estimatedMinutes min',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _isTracking
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progress > 1.0
                        ? 'Over by ${((progress - 1) * 100).round()}%'
                        : '${(progress * 100).round()}% complete',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: progressColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Control buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _toggleTracking,
                    icon: Icon(_isTracking ? Icons.pause : Icons.play_arrow),
                    label: Text(_isTracking ? 'Pause' : 'Start'),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          _isTracking ? colorScheme.error : colorScheme.primary,
                    ),
                  ),
                ),
                if (_elapsedSeconds > 0 && !_isTracking) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.restart_alt),
                    tooltip: 'Reset timer',
                  ),
                ],
              ],
            ),

            // Quick time buttons
            if (!_isTracking && estimatedMinutes == 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('+5m'),
                    onPressed: () => _addMinutes(5),
                  ),
                  ActionChip(
                    label: const Text('+15m'),
                    onPressed: () => _addMinutes(15),
                  ),
                  ActionChip(
                    label: const Text('+30m'),
                    onPressed: () => _addMinutes(30),
                  ),
                  ActionChip(
                    label: const Text('+1h'),
                    onPressed: () => _addMinutes(60),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _resetTimer() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Timer?'),
        content:
            const Text('This will reset the tracked time to 0. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              setState(() {
                _elapsedSeconds = 0;
              });
              await _saveTimeToDatabase();
              widget.onTimeUpdated?.call();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _addMinutes(int minutes) async {
    setState(() {
      _elapsedSeconds += minutes * 60;
    });
    await _saveTimeToDatabase();
    widget.onTimeUpdated?.call();
  }
}

/// Compact time tracker for task list items
class CompactTimeTracker extends StatelessWidget {
  const CompactTimeTracker({
    super.key,
    required this.task,
  });

  final NoteTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final estimated = task.estimatedMinutes ?? 0;
    final actual = task.actualMinutes ?? 0;

    if (estimated == 0 && actual == 0) {
      return const SizedBox.shrink();
    }

    final progress = estimated > 0 ? (actual / estimated).clamp(0.0, 2.0) : 0.0;

    Color progressColor;
    if (progress <= 0.8) {
      progressColor = Colors.green;
    } else if (progress <= 1.2) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            size: 14,
            color: actual > 0 ? progressColor : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            actual > 0 ? '${actual}m' : '${estimated}m est',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: actual > 0 ? progressColor : colorScheme.onSurfaceVariant,
            ),
          ),
          if (estimated > 0 && actual > 0) ...[
            const SizedBox(width: 4),
            Text(
              '/ ${estimated}m',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
