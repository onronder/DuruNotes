import 'package:drift/drift.dart' show Value;
import 'package:duru_notes/data/local/app_db.dart'
    show NoteReminder, NoteRemindersCompanion, RecurrencePattern, ReminderType;
import 'package:duru_notes/main.dart'; // for global `ref.read(loggerProvider)`
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/providers/feature_flagged_providers.dart';
import 'package:duru_notes/services/reminders/reminder_coordinator.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:duru_notes/ui/components/modern_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

/// Screen for managing all reminders for a specific note
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({
    required this.noteId,
    required this.noteTitle,
    required this.noteBody,
    super.key,
  });

  final String noteId;
  final String noteTitle;
  final String noteBody;

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  List<NoteReminder> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
    // Log screen view ref.read(analyticsProvider)
    ref.read(analyticsProvider).event(
      'screen_view',
      properties: {
        'screen': 'RemindersScreen',
        'note_id': widget.noteId,
        'has_note_title': widget.noteTitle.isNotEmpty,
      },
    );
  }

  Future<void> _loadReminders() async {
    try {
      // Load reminders from the coordinator service
      final coordinator = ref.read(featureFlaggedReminderCoordinatorProvider);
      final reminders = await coordinator.getRemindersForNote(widget.noteId);
      if (mounted) {
        setState(() {
          _reminders = reminders != null ? List<NoteReminder>.from(reminders as List) : [];
          _loading = false;
        });
      }
    } catch (e, stack) {
      ref.read(loggerProvider).error('Failed to load reminders', error: e, stackTrace: stack);
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF8FAFB),
      appBar: ModernAppBar(
        title: 'Reminders',
        subtitle: widget.noteTitle.isNotEmpty ? widget.noteTitle : 'Manage notifications',
        showGradient: true,
        actions: [
          ModernAppBarAction(
            icon: CupertinoIcons.bell,
            onPressed: _showAddReminderDialog,
            tooltip: 'Add reminder',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats header
          _buildStatsHeader(context),
          // Reminders list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildRemindersList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddReminderDialog,
        backgroundColor: DuruColors.primary,
        icon: const Icon(CupertinoIcons.bell_fill, color: Colors.white),
        label: const Text('Add Reminder', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildStatsHeader(BuildContext context) {
    final theme = Theme.of(context);
    final activeReminders = _reminders.where((r) => r.isActive).length;
    final recurringReminders = _reminders.where((r) =>
        r.recurrencePattern != RecurrencePattern.none).length;
    final locationReminders = _reminders.where((r) =>
        r.type == ReminderType.location).length;

    return Container(
      margin: EdgeInsets.all(DuruSpacing.md),
      padding: EdgeInsets.all(DuruSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DuruColors.primary.withOpacity(0.1),
            DuruColors.accent.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            icon: CupertinoIcons.bell_fill,
            value: activeReminders.toString(),
            label: 'Active',
            color: DuruColors.primary,
          ),
          _buildStatItem(
            context,
            icon: CupertinoIcons.repeat,
            value: recurringReminders.toString(),
            label: 'Recurring',
            color: DuruColors.accent,
          ),
          _buildStatItem(
            context,
            icon: CupertinoIcons.location_fill,
            value: locationReminders.toString(),
            label: 'Location',
            color: DuruColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(DuruSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: DuruSpacing.xs),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildRemindersList() {
    if (_reminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(DuruSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    DuruColors.primary.withOpacity(0.1),
                    DuruColors.accent.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.bell_slash,
                size: 64,
                color: DuruColors.primary.withOpacity(0.5),
              ),
            ),
            SizedBox(height: DuruSpacing.lg),
            Text(
              'No reminders set',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            SizedBox(height: DuruSpacing.sm),
            Text(
              'Add time-based or location-based reminders for this note',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: DuruSpacing.xl),
            ElevatedButton.icon(
              onPressed: _showAddReminderDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: DuruColors.primary,
                padding: EdgeInsets.symmetric(
                  horizontal: DuruSpacing.lg,
                  vertical: DuruSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(CupertinoIcons.bell_fill, color: Colors.white),
              label: const Text('Add Reminder', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reminders.length,
      itemBuilder: (context, index) {
        final reminder = _reminders[index];
        return _buildReminderCard(reminder);
      },
    );
  }

  Widget _buildReminderCard(NoteReminder reminder) {
    final theme = Theme.of(context);
    final isSnoozed = reminder.snoozedUntil != null &&
        reminder.snoozedUntil!.isAfter(DateTime.now());

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: DuruSpacing.md,
        vertical: DuruSpacing.xs,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEditReminderSheet(reminder),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isSnoozed
                      ? DuruColors.warning.withOpacity(0.05)
                      : reminder.isActive
                          ? DuruColors.accent.withOpacity(0.03)
                          : theme.colorScheme.surface,
                  theme.colorScheme.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSnoozed
                    ? DuruColors.warning.withOpacity(0.2)
                    : reminder.isActive
                        ? DuruColors.accent.withOpacity(0.2)
                        : theme.colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: EdgeInsets.all(DuruSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Reminder type icon with modern styling
                    Container(
                      padding: EdgeInsets.all(DuruSpacing.sm),
                      decoration: BoxDecoration(
                        color: _getReminderColor(reminder).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _getReminderIcon(reminder.type),
                    ),
                    SizedBox(width: DuruSpacing.md),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reminder.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (reminder.body.isNotEmpty) ...[
                            SizedBox(height: DuruSpacing.xs),
                            Text(
                              reminder.body,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Status chip
                    _buildReminderStatusChip(reminder),
                    // Action menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        CupertinoIcons.ellipsis_vertical,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) => _handleReminderAction(value, reminder),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(CupertinoIcons.pencil, color: DuruColors.primary),
                            title: const Text('Edit'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        if (reminder.snoozedUntil != null)
                          PopupMenuItem(
                            value: 'unsnooze',
                            child: ListTile(
                              leading: Icon(CupertinoIcons.bell, color: DuruColors.primary),
                              title: const Text('Un-snooze'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        if (reminder.isActive)
                          PopupMenuItem(
                            value: 'deactivate',
                            child: ListTile(
                              leading: Icon(CupertinoIcons.pause_fill, color: DuruColors.warning),
                              title: const Text('Deactivate'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          )
                        else
                          PopupMenuItem(
                            value: 'activate',
                            child: ListTile(
                              leading: Icon(CupertinoIcons.play_arrow_solid, color: DuruColors.accent),
                              title: const Text('Activate'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(CupertinoIcons.trash, color: DuruColors.error),
                            title: Text(
                              'Delete',
                              style: TextStyle(color: DuruColors.error),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Additional info section
                if (reminder.snoozedUntil != null ||
                    reminder.remindAt != null ||
                    reminder.recurrencePattern != RecurrencePattern.none) ...[
                  SizedBox(height: DuruSpacing.sm),
                  Wrap(
                    spacing: DuruSpacing.sm,
                    runSpacing: DuruSpacing.xs,
                    children: [
                      if (reminder.snoozedUntil != null)
                        _buildInfoBadge(
                          icon: CupertinoIcons.moon_zzz_fill,
                          label: 'Snoozed until ${_formatDateTime(reminder.snoozedUntil!)}',
                          color: DuruColors.warning,
                        ),
                      if (reminder.remindAt != null)
                        _buildInfoBadge(
                          icon: CupertinoIcons.clock_fill,
                          label: _formatDateTime(reminder.remindAt!),
                          color: DuruColors.primary,
                        ),
                      if (reminder.recurrencePattern != RecurrencePattern.none)
                        _buildInfoBadge(
                          icon: CupertinoIcons.repeat,
                          label: _getRecurrenceLabel(reminder.recurrencePattern),
                          color: DuruColors.accent,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Icon _getReminderIcon(ReminderType type) {
    final color = _getReminderColorByType(type);
    switch (type) {
      case ReminderType.time:
        return Icon(CupertinoIcons.clock_fill, color: color, size: 20);
      case ReminderType.location:
        return Icon(CupertinoIcons.location_fill, color: color, size: 20);
      case ReminderType.recurring:
        return Icon(CupertinoIcons.repeat, color: color, size: 20);
    }
  }

  Color _getReminderColor(NoteReminder reminder) {
    if (reminder.snoozedUntil != null &&
        reminder.snoozedUntil!.isAfter(DateTime.now())) {
      return DuruColors.warning;
    }
    return _getReminderColorByType(reminder.type);
  }

  Color _getReminderColorByType(ReminderType type) {
    switch (type) {
      case ReminderType.time:
        return DuruColors.primary;
      case ReminderType.location:
        return DuruColors.accent;
      case ReminderType.recurring:
        return DuruColors.warning;
    }
  }

  Widget _buildReminderStatusChip(NoteReminder reminder) {
    late String label;
    late Color color;
    late IconData icon;

    if (!reminder.isActive) {
      label = 'Inactive';
      color = DuruColors.surfaceVariant;
      icon = CupertinoIcons.pause_circle_fill;
    } else if (reminder.snoozedUntil != null &&
        reminder.snoozedUntil!.isAfter(DateTime.now())) {
      label = 'Snoozed';
      color = DuruColors.warning;
      icon = CupertinoIcons.moon_zzz_fill;
    } else {
      label = 'Active';
      color = DuruColors.accent;
      icon = CupertinoIcons.checkmark_circle_fill;
    }

    return Container(
      margin: EdgeInsets.only(right: DuruSpacing.xs),
      padding: EdgeInsets.symmetric(
        horizontal: DuruSpacing.sm,
        vertical: DuruSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: DuruSpacing.xs),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DuruSpacing.sm,
        vertical: DuruSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: DuruSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (date == today) {
      return 'Today ${DateFormat.jm().format(dateTime)}';
    } else if (date == today.add(const Duration(days: 1))) {
      return 'Tomorrow ${DateFormat.jm().format(dateTime)}';
    } else if (date == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat.jm().format(dateTime)}';
    } else {
      return DateFormat.MMMd().add_jm().format(dateTime);
    }
  }

  String _getRecurrenceLabel(RecurrencePattern pattern) {
    switch (pattern) {
      case RecurrencePattern.none:
        return 'One-time';
      case RecurrencePattern.daily:
        return 'Daily';
      case RecurrencePattern.weekly:
        return 'Weekly';
      case RecurrencePattern.monthly:
        return 'Monthly';
      case RecurrencePattern.yearly:
        return 'Yearly';
    }
  }

  void _handleReminderAction(String action, NoteReminder reminder) {
    switch (action) {
      case 'edit':
        _showEditReminderSheet(reminder);
      case 'unsnooze':
        _unsnoozeReminder(reminder);
      case 'deactivate':
        _deactivateReminder(reminder);
      case 'activate':
        _activateReminder(reminder);
      case 'delete':
        _deleteReminder(reminder);
    }
  }

  Future<void> _unsnoozeReminder(NoteReminder reminder) async {
    try {
      await ref.read(appDbProvider).clearSnooze(reminder.id);
      await _loadReminders();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reminder un-snoozed')));
      }
    } catch (e, stack) {
      ref.read(loggerProvider).error('Failed to unsnooze reminder', error: e, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unsnooze reminder')),
        );
      }
    }
  }

  Future<void> _deactivateReminder(NoteReminder reminder) async {
    try {
      await ref.read(appDbProvider).deactivateReminder(reminder.id);
      await _loadReminders();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reminder deactivated')));
      }
    } catch (e, stack) {
      ref.read(loggerProvider).error(
        'Failed to deactivate reminder',
        error: e,
        stackTrace: stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to deactivate reminder')),
        );
      }
    }
  }

  Future<void> _activateReminder(NoteReminder reminder) async {
    try {
      // Mark isActive = true in database
      await ref.read(appDbProvider).updateReminder(
            reminder.id,
            const NoteRemindersCompanion(isActive: Value(true)),
          );
      await _loadReminders();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reminder activated')));
      }
    } catch (e, stack) {
      ref.read(loggerProvider).error('Failed to activate reminder', error: e, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to activate reminder')),
        );
      }
    }
  }

  Future<void> _deleteReminder(NoteReminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: const Text('Are you sure you want to delete this reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      try {
        await ref.read(appDbProvider).deleteReminderById(reminder.id);
        await _loadReminders();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Reminder deleted')));
        }
      } catch (e, stack) {
        ref.read(loggerProvider).error('Failed to delete reminder', error: e, stackTrace: stack);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete reminder')),
          );
        }
      }
    }
  }

  void _showEditReminderSheet(NoteReminder reminder) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditReminderSheet(
        reminder: reminder,
        noteTitle: widget.noteTitle,
        noteBody: widget.noteBody,
        onReminderUpdated: _loadReminders,
      ),
    );
  }

  Future<void> _showAddReminderDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddReminderSheet(
        noteId: widget.noteId,
        noteTitle: widget.noteTitle,
        noteBody: widget.noteBody,
        onReminderAdded: _loadReminders,
      ),
    );
  }
}

/// Bottom sheet for adding new reminders (time-based or location-based)
class AddReminderSheet extends ConsumerStatefulWidget {
  const AddReminderSheet({
    required this.noteId,
    required this.noteTitle,
    required this.noteBody,
    required this.onReminderAdded,
    super.key,
  });

  final String noteId;
  final String noteTitle;
  final String noteBody;
  final VoidCallback onReminderAdded;

  @override
  ConsumerState<AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<AddReminderSheet> {
  ReminderType _selectedType = ReminderType.time;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add Reminder',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // Type selector (Time or Location)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<ReminderType>(
                        segments: const [
                          ButtonSegment(
                            value: ReminderType.time,
                            label: Text('Time'),
                            icon: Icon(Icons.access_time),
                          ),
                          ButtonSegment(
                            value: ReminderType.location,
                            label: Text('Location'),
                            icon: Icon(Icons.location_on),
                          ),
                        ],
                        selected: {_selectedType},
                        onSelectionChanged: (selected) {
                          setState(() {
                            _selectedType = selected.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Form content based on selected type
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _selectedType == ReminderType.time
                      ? TimeReminderForm(
                          noteId: widget.noteId,
                          noteTitle: widget.noteTitle,
                          noteBody: widget.noteBody,
                          onReminderAdded: () {
                            Navigator.of(context).pop();
                            widget.onReminderAdded();
                          },
                        )
                      : LocationReminderForm(
                          noteId: widget.noteId,
                          noteTitle: widget.noteTitle,
                          noteBody: widget.noteBody,
                          onReminderAdded: () {
                            Navigator.of(context).pop();
                            widget.onReminderAdded();
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Form for creating time-based reminders
class TimeReminderForm extends ConsumerStatefulWidget {
  const TimeReminderForm({
    required this.noteId,
    required this.noteTitle,
    required this.noteBody,
    required this.onReminderAdded,
    super.key,
  });

  final String noteId;
  final String noteTitle;
  final String noteBody;
  final VoidCallback onReminderAdded;

  @override
  ConsumerState<TimeReminderForm> createState() => _TimeReminderFormState();
}

class _TimeReminderFormState extends ConsumerState<TimeReminderForm> {
  // Recurrence options
  static const List<String> _recurrenceOptions = [
    'none',
    'daily',
    'weekly',
    'monthly',
    'yearly',
  ];

  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  String _recurrence = 'none';
  int _recurrenceInterval = 1;
  DateTime? _recurrenceEndDate;
  bool _loading = false;

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _notificationTitleController = TextEditingController();
  final _notificationBodyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.noteTitle;
    _bodyController.text = widget.noteBody;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _notificationTitleController.dispose();
    _notificationBodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and description fields
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Reminder Title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _bodyController,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        // Date and time picker
        const Text(
          'When',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(_formatDateTime(_selectedDateTime)),
            subtitle: const Text('Tap to change'),
            onTap: _selectDateTime,
          ),
        ),
        const SizedBox(height: 24),
        // Recurrence pattern
        const Text(
          'Repeat',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _recurrence,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: _recurrenceOptions.map((pattern) {
            final display = pattern[0].toUpperCase() + pattern.substring(1);
            return DropdownMenuItem(value: pattern, child: Text(display));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _recurrence = value ?? 'none';
            });
          },
        ),
        if (_recurrence != 'none') ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Every',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(
                    text: _recurrenceInterval.toString(),
                  ),
                  onChanged: (value) {
                    _recurrenceInterval = int.tryParse(value) ?? 1;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Text(
                  _getIntervalLabel(_recurrence),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        // Custom notification content
        ExpansionTile(
          title: const Text('Notification Options'),
          children: [
            TextField(
              controller: _notificationTitleController,
              decoration: const InputDecoration(
                labelText: 'Custom notification title (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notificationBodyController,
              decoration: const InputDecoration(
                labelText: 'Custom notification message (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Create button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _createReminder,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('Create Reminder'),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    if (dateOnly == today) {
      return 'Today at $timeStr';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow at $timeStr';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at $timeStr';
    }
  }

  String _getIntervalLabel(String pattern) {
    switch (pattern) {
      case 'daily':
        return _recurrenceInterval == 1 ? 'day' : 'days';
      case 'weekly':
        return _recurrenceInterval == 1 ? 'week' : 'weeks';
      case 'monthly':
        return _recurrenceInterval == 1 ? 'month' : 'months';
      case 'yearly':
        return _recurrenceInterval == 1 ? 'year' : 'years';
      case 'none':
      default:
        return '';
    }
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );
      if (time != null && mounted) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _createReminder() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }
    if (_selectedDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a future time')),
      );
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      // Determine recurrence pattern enum from string
      final recPattern = RecurrencePattern.values.firstWhere(
        (p) => p.name == _recurrence,
        orElse: () => RecurrencePattern.none,
      );
      final coord = ref.read(featureFlaggedReminderCoordinatorProvider);
      final reminderId = await coord.createTimeReminder(
        noteId: widget.noteId,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        remindAtUtc: _selectedDateTime.toUtc(),
        recurrence: recPattern,
        recurrenceInterval: _recurrenceInterval,
        recurrenceEndDate: _recurrenceEndDate,
        customNotificationTitle:
            _notificationTitleController.text.trim().isEmpty
                ? null
                : _notificationTitleController.text.trim(),
        customNotificationBody: _notificationBodyController.text.trim().isEmpty
            ? null
            : _notificationBodyController.text.trim(),
      );
      if (reminderId != null) {
        widget.onReminderAdded();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder created successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create reminder')),
          );
        }
      }
    } catch (e, stack) {
      ref.read(loggerProvider).error(
        'Failed to create time reminder',
        error: e,
        stackTrace: stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create reminder')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}

/// Form for creating location-based reminders
class LocationReminderForm extends ConsumerStatefulWidget {
  const LocationReminderForm({
    required this.noteId,
    required this.noteTitle,
    required this.noteBody,
    required this.onReminderAdded,
    super.key,
  });

  final String noteId;
  final String noteTitle;
  final String noteBody;
  final VoidCallback onReminderAdded;

  @override
  ConsumerState<LocationReminderForm> createState() =>
      _LocationReminderFormState();
}

class _LocationReminderFormState extends ConsumerState<LocationReminderForm> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _notificationTitleController = TextEditingController();
  final _notificationBodyController = TextEditingController();

  double _latitude = 0;
  double _longitude = 0;
  double _radius = 100; // default radius in meters
  bool _hasLocation = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.noteTitle;
    _bodyController.text = widget.noteBody;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _locationNameController.dispose();
    _notificationTitleController.dispose();
    _notificationBodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and description fields
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Reminder Title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _bodyController,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        // Location selection
        const Text(
          'Location',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text('Use current location'),
                subtitle: _hasLocation
                    ? Text(
                        '${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}',
                      )
                    : const Text('Tap to get current location'),
                onTap: _getCurrentLocation,
              ),
              if (_hasLocation)
                ListTile(
                  leading: const Icon(Icons.edit_location),
                  title: const Text('Set custom location'),
                  subtitle: const Text('Enter coordinates manually'),
                  onTap: _showLocationDialog,
                ),
            ],
          ),
        ),
        if (_hasLocation) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _locationNameController,
            decoration: const InputDecoration(
              labelText: 'Location name (optional)',
              border: OutlineInputBorder(),
              hintText: 'e.g., Home, Office, Grocery Store',
            ),
          ),
          const SizedBox(height: 16),
          const Text('Radius (meters)'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _radius,
                  min: 50,
                  max: 1000,
                  divisions: 19,
                  label: '${_radius.round()}m',
                  onChanged: (value) {
                    setState(() {
                      _radius = value;
                    });
                  },
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  '${_radius.round()}m',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        // Custom notification content
        ExpansionTile(
          title: const Text('Notification Options'),
          children: [
            TextField(
              controller: _notificationTitleController,
              decoration: const InputDecoration(
                labelText: 'Custom notification title (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notificationBodyController,
              decoration: const InputDecoration(
                labelText: 'Custom notification message (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Create button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_loading || !_hasLocation) ? null : _createReminder,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('Create Location Reminder'),
          ),
        ),
        if (!_hasLocation)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Please set a location first',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _loading = true;
      });
      final coord = ref.read(featureFlaggedReminderCoordinatorProvider);
      // Ensure permissions for location
      var havePerms = (await coord.hasRequiredPermissions(includeLocation: true)) as bool;
      if (!havePerms) {
        await coord.requestNotificationPermissions();
        await coord.requestLocationPermissions();
        havePerms = (await coord.hasRequiredPermissions(includeLocation: true)) as bool;
      }
      if (!havePerms) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required for location reminders',
              ),
            ),
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _hasLocation = true;
      });
    } catch (e, stack) {
      ref.read(loggerProvider).error(
        'Failed to get current location',
        error: e,
        stackTrace: stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get current location')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showLocationDialog() {
    final latController = TextEditingController(text: _latitude.toString());
    final lngController = TextEditingController(text: _longitude.toString());
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lngController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final lat = double.tryParse(latController.text);
              final lng = double.tryParse(lngController.text);
              if (lat != null && lng != null) {
                setState(() {
                  _latitude = lat;
                  _longitude = lng;
                  _hasLocation = true;
                });
                Navigator.of(context).pop();
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Future<void> _createReminder() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }
    if (!_hasLocation) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please set a location')));
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final coord = ref.read(featureFlaggedReminderCoordinatorProvider);
      final reminderId = await coord.createLocationReminder(
        noteId: widget.noteId,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        radius: _radius,
        locationName: _locationNameController.text.trim().isEmpty
            ? null
            : _locationNameController.text.trim(),
        customNotificationTitle:
            _notificationTitleController.text.trim().isEmpty
                ? null
                : _notificationTitleController.text.trim(),
        customNotificationBody: _notificationBodyController.text.trim().isEmpty
            ? null
            : _notificationBodyController.text.trim(),
      );
      if (reminderId != null) {
        widget.onReminderAdded();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location reminder created successfully'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create location reminder')),
          );
        }
      }
    } catch (e, stack) {
      ref.read(loggerProvider).error(
        'Failed to create location reminder',
        error: e,
        stackTrace: stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create location reminder')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}

/// Bottom sheet for editing an existing reminder (simplified placeholder)
class EditReminderSheet extends ConsumerWidget {
  const EditReminderSheet({
    required this.reminder,
    required this.noteTitle,
    required this.noteBody,
    required this.onReminderUpdated,
    super.key,
  });

  final NoteReminder reminder;
  final String noteTitle;
  final String noteBody;
  final VoidCallback onReminderUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Edit Reminder',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          const Text('Edit functionality coming soon...'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onReminderUpdated();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
