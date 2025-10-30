import 'dart:math' as math;

import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart'
    show taskCoreRepositoryProvider;
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TimeTrackingDashboardScreen extends ConsumerStatefulWidget {
  const TimeTrackingDashboardScreen({super.key});

  @override
  ConsumerState<TimeTrackingDashboardScreen> createState() =>
      _TimeTrackingDashboardScreenState();
}

class _TimeTrackingDashboardScreenState
    extends ConsumerState<TimeTrackingDashboardScreen> {
  int _refreshSeed = 0;

  Future<_TrackingOverview> _loadOverview(ITaskRepository repository) {
    return _TrackingOverview.load(repository);
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(taskCoreRepositoryProvider);
    if (repository == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(title: const Text('Tracking Preview')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Sign in to view time tracking previews.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return FutureBuilder<_TrackingOverview>(
      key: ValueKey(_refreshSeed),
      future: _loadOverview(repository),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(title: const Text('Tracking Preview')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(title: const Text('Tracking Preview')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load tracking data.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final overview = snapshot.data ?? const _TrackingOverview.empty();
        return Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0A0A0A)
              : const Color(0xFFF8FAFB),
          appBar: AppBar(
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tracking Preview'),
                Text(
                  'Monitor focused work and time budgets',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            flexibleSpace: const _GradientHeader(),
          ),
          body: overview.hasData
              ? RefreshIndicator(
                  onRefresh: () => _handleRefresh(repository, context),
                  child: ListView(
                    padding: EdgeInsets.all(DuruSpacing.lg),
                    children: [
                      _SummaryRow(overview: overview),
                      const SizedBox(height: 24),
                      _WeekTrend(overview: overview),
                      const SizedBox(height: 24),
                      _TopTrackedTasks(overview: overview),
                    ],
                  ),
                )
              : const _NoTrackingEmptyState(),
        );
      },
    );
  }

  Future<void> _handleRefresh(
    ITaskRepository repository,
    BuildContext context,
  ) async {
    await _TrackingOverview.load(repository);
    if (!mounted) return;
    setState(() => _refreshSeed++);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Tracking data refreshed')));
  }
}

class _GradientHeader extends StatelessWidget {
  const _GradientHeader();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [DuruColors.primary, DuruColors.accent],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.overview});

  final _TrackingOverview overview;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DuruSpacing.md,
      runSpacing: DuruSpacing.md,
      children: [
        _SummaryCard(
          icon: Icons.timer_outlined,
          label: 'Tracked',
          value: _formatMinutes(overview.totalTrackedMinutes),
          chipLabel: '${overview.trackedTaskCount} tasks',
        ),
        _SummaryCard(
          icon: Icons.schedule,
          label: 'Estimated',
          value: _formatMinutes(overview.totalEstimatedMinutes),
          chipLabel: overview.totalTrackedMinutes > 0
              ? _formatVariance(
                  overview.totalTrackedMinutes,
                  overview.totalEstimatedMinutes,
                )
              : 'No estimates',
        ),
        _SummaryCard(
          icon: Icons.bolt_outlined,
          label: 'Focus Average',
          value: overview.trackedTaskCount > 0
              ? _formatMinutes(
                  (overview.totalTrackedMinutes / overview.trackedTaskCount)
                      .round(),
                )
              : '0m',
          chipLabel: 'Per tracked task',
        ),
      ],
    );
  }

  String _formatVariance(int actualMinutes, int estimatedMinutes) {
    if (estimatedMinutes == 0) return 'No estimates';
    final delta = actualMinutes - estimatedMinutes;
    if (delta == 0) return 'On budget';
    final minutes = delta.abs();
    return '${minutes}m ${delta.isNegative ? 'under' : 'over'}';
  }

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final hours = minutes / 60;
      return '${hours.toStringAsFixed(hours >= 10 ? 0 : 1)}h';
    }
    return '${minutes}m';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.chipLabel,
  });

  final IconData icon;
  final String label;
  final String value;
  final String chipLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 220,
      padding: EdgeInsets.all(DuruSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: DuruColors.primary),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: DuruColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              chipLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: DuruColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekTrend extends StatelessWidget {
  const _WeekTrend({required this.overview});

  final _TrackingOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chartData = overview.dailySummaries;
    final int maxMinutes = chartData.isEmpty
        ? 0
        : chartData.map((e) => e.minutes).reduce(math.max);

    return Container(
      padding: EdgeInsets.all(DuruSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Weekly focus trend',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                overview.totalTrackedMinutes > 0
                    ? '${_formatMinutes(overview.totalTrackedMinutes)} tracked this week'
                    : 'No tracking yet',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: chartData.map((day) {
                final value = day.minutes;
                final double normalized = maxMinutes == 0
                    ? 0
                    : value.toDouble() / maxMinutes;
                final double height = 20 + (140 * normalized);
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: height,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [DuruColors.primary, DuruColors.accent],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        day.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final hours = minutes / 60;
      return '${hours.toStringAsFixed(hours >= 10 ? 0 : 1)}h';
    }
    return '${minutes}m';
  }
}

class _TopTrackedTasks extends StatelessWidget {
  const _TopTrackedTasks({required this.overview});

  final _TrackingOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (overview.topTrackedTasks.isEmpty) {
      return Container(
        padding: EdgeInsets.all(DuruSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.access_time, color: DuruColors.primary, size: 32),
            SizedBox(height: 12),
            Text(
              'No tracked tasks yet',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'Start the timer on a task to build focus insights.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(DuruSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top tracked work',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...overview.topTrackedTasks.map((task) {
            final variance = task.estimatedMinutes > 0
                ? task.actualMinutes - task.estimatedMinutes
                : null;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: DuruColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: DuruColors.primary),
              ),
              title: Text(task.title.isEmpty ? '(Untitled task)' : task.title),
              subtitle: Text(
                variance == null
                    ? _formatMinutes(task.actualMinutes)
                    : '${_formatMinutes(task.actualMinutes)} • ${variance.abs()}m ${variance.isNegative ? 'under' : 'over'} estimate',
              ),
              trailing: Text(
                task.lastUpdatedLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final hours = minutes / 60;
      return '${hours.toStringAsFixed(hours >= 10 ? 0 : 1)}h';
    }
    return '${minutes}m';
  }
}

class _NoTrackingEmptyState extends StatelessWidget {
  const _NoTrackingEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(DuruSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timelapse, size: 56, color: DuruColors.primary),
            const SizedBox(height: 24),
            Text(
              'Start a focus timer to preview tracking insights.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Once you log time on tasks, this space will curate highlights, overages, and your weekly focus trend.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingOverview {
  const _TrackingOverview({
    required this.totalTrackedMinutes,
    required this.totalEstimatedMinutes,
    required this.trackedTaskCount,
    required this.topTrackedTasks,
    required this.dailySummaries,
    required this.hasData,
  });

  const _TrackingOverview.empty()
    : totalTrackedMinutes = 0,
      totalEstimatedMinutes = 0,
      trackedTaskCount = 0,
      topTrackedTasks = const <_TrackedTask>[],
      dailySummaries = const <_DailySummary>[],
      hasData = false;

  final int totalTrackedMinutes;
  final int totalEstimatedMinutes;
  final int trackedTaskCount;
  final List<_TrackedTask> topTrackedTasks;
  final List<_DailySummary> dailySummaries;
  final bool hasData;

  static Future<_TrackingOverview> load(ITaskRepository repository) async {
    final tasks = await repository.getAllTasks();
    if (tasks.isEmpty) {
      return const _TrackingOverview.empty();
    }

    final trackedTasks = tasks
        .map<_TrackedTask>(_TrackedTask.fromTask)
        .where((task) => task.actualMinutes > 0)
        .toList();

    if (trackedTasks.isEmpty) {
      return const _TrackingOverview.empty();
    }

    final totalTracked = trackedTasks.fold<int>(
      0,
      (int sum, _TrackedTask task) => sum + task.actualMinutes,
    );
    final totalEstimated = trackedTasks.fold<int>(
      0,
      (int sum, _TrackedTask task) => sum + task.estimatedMinutes,
    );

    trackedTasks.sort((a, b) => b.actualMinutes.compareTo(a.actualMinutes));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastSevenDays = List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );

    final Map<DateTime, int> dailyTotals = {};
    for (final task in trackedTasks) {
      final date = DateTime(
        task.lastUpdated.year,
        task.lastUpdated.month,
        task.lastUpdated.day,
      );
      dailyTotals[date] = (dailyTotals[date] ?? 0) + task.actualMinutes;
    }

    final dailySummaries = lastSevenDays
        .map(
          (date) => _DailySummary(date: date, minutes: dailyTotals[date] ?? 0),
        )
        .toList();

    return _TrackingOverview(
      totalTrackedMinutes: totalTracked,
      totalEstimatedMinutes: totalEstimated,
      trackedTaskCount: trackedTasks.length,
      topTrackedTasks: trackedTasks.take(5).toList(),
      dailySummaries: dailySummaries,
      hasData: trackedTasks.isNotEmpty,
    );
  }
}

class _TrackedTask {
  _TrackedTask({
    required this.id,
    required this.title,
    required this.actualMinutes,
    required this.estimatedMinutes,
    required this.lastUpdated,
  });

  factory _TrackedTask.fromTask(domain.Task task) {
    final metadata = task.metadata;
    final actual = (metadata['actualMinutes'] as num?)?.toInt() ?? 0;
    final estimated = (metadata['estimatedMinutes'] as num?)?.toInt() ?? 0;
    return _TrackedTask(
      id: task.id,
      title: task.title,
      actualMinutes: actual,
      estimatedMinutes: estimated,
      lastUpdated: task.updatedAt,
    );
  }

  final String id;
  final String title;
  final int actualMinutes;
  final int estimatedMinutes;
  final DateTime lastUpdated;

  String get lastUpdatedLabel {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }
}

class _DailySummary {
  const _DailySummary({required this.date, required this.minutes});

  final DateTime date;
  final int minutes;

  String get label => '${_weekday(date.weekday)}\n${date.month}/${date.day}';

  String _weekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
    }
    return '';
  }
}
