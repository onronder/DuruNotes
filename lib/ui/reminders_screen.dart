import 'package:drift/drift.dart' show Value;
import 'package:duru_notes/data/local/app_db.dart'
    show NoteReminder, NoteRemindersCompanion, RecurrencePattern, ReminderType;
import 'package:duru_notes/main.dart'; // for global `logger`
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/reminders/reminder_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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
    // Log screen view analytics
    analytics.event(
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
      final coordinator = ref.read(reminderCoordinatorProvider);
      final reminders = await coordinator.getRemindersForNote(widget.noteId);
      if (mounted) {
        setState(() {
          _reminders = reminders;
          _loading = false;
        });
      }
    } catch (e, stack) {
      logger.error('Failed to load reminders', error: e, stackTrace: stack);
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddReminderDialog,
            tooltip: 'Add reminder',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildRemindersList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddReminderDialog,
        tooltip: 'Add reminder',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRemindersList() {
    if (_reminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No reminders set',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add time-based or location-based reminders for this note',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddReminderDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Reminder'),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getReminderIcon(reminder.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (reminder.body.isNotEmpty)
                        Text(
                          reminder.body,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                _buildReminderStatusChip(reminder),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleReminderAction(value, reminder),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (reminder.snoozedUntil != null)
                      const PopupMenuItem(
                        value: 'unsnooze',
                        child: ListTile(
                          leading: Icon(Icons.notifications_active),
                          title: Text('Un-snooze'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (reminder.isActive)
                      const PopupMenuItem(
                        value: 'deactivate',
                        child: ListTile(
                          leading: Icon(Icons.pause),
                          title: Text('Deactivate'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'activate',
                        child: ListTile(
                          leading: Icon(Icons.play_arrow),
                          title: Text('Activate'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (reminder.snoozedUntil != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Snoozed until ${reminder.snoozedUntil}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Icon _getReminderIcon(ReminderType type) {
    switch (type) {
      case ReminderType.time:
        return const Icon(Icons.access_time);
      case ReminderType.location:
        return const Icon(Icons.location_on);
      case ReminderType.recurring:
        return const Icon(Icons.refresh);
    }
  }

  Widget _buildReminderStatusChip(NoteReminder reminder) {
    late String label;
    late Color color;
    if (!reminder.isActive) {
      label = 'Inactive';
      color = Colors.grey;
    } else if (reminder.snoozedUntil != null &&
        reminder.snoozedUntil!.isAfter(DateTime.now())) {
      label = 'Snoozed';
      color = Colors.orange;
    } else {
      label = 'Active';
      color = Colors.green;
    }
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
    );
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
      logger.error('Failed to unsnooze reminder', error: e, stackTrace: stack);
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
      logger.error(
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
      logger.error('Failed to activate reminder', error: e, stackTrace: stack);
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
        logger.error('Failed to delete reminder', error: e, stackTrace: stack);
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
      final coord = ref.read(reminderCoordinatorProvider);
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
      logger.error(
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
      final coord = ref.read(reminderCoordinatorProvider);
      // Ensure permissions for location
      var havePerms = await coord.hasRequiredPermissions(includeLocation: true);
      if (!havePerms) {
        await coord.requestNotificationPermissions();
        await coord.requestLocationPermissions();
        havePerms = await coord.hasRequiredPermissions(includeLocation: true);
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
      logger.error(
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
      final coord = ref.read(reminderCoordinatorProvider);
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
      logger.error(
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
