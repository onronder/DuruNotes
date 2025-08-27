import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../providers.dart';
import '../services/reminder_service.dart';
import '../services/reminders/reminder_coordinator.dart';
import '../services/analytics/analytics_service.dart';
import '../main.dart';
import '../models/note_reminder.dart';
import '../data/local/app_db.dart' show ReminderType, RecurrencePattern, NoteRemindersCompanion, Value;
// RecurrencePattern is now imported from app_db.dart via NoteReminder model

/// Screen for managing all reminders for a specific note
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({
    super.key,
    required this.noteId,
    required this.noteTitle,
    required this.noteBody,
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
    
    analytics.screen('RemindersScreen', properties: {
      'note_id': widget.noteId,
      'has_note_title': widget.noteTitle.isNotEmpty,
    });
  }

  Future<void> _loadReminders() async {
    try {
      // Load reminders from the reminder service
      final reminderService = ref.read(reminderCoordinatorProvider);
      final reminders = await reminderService.getRemindersForNote(widget.noteId);
      
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
        child: const Icon(Icons.add),
        tooltip: 'Add reminder',
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
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No reminders set',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add time-based or location-based reminders for this note',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
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

  Widget _buildReminderCard(NoteReminder reminder) { // TODO: Define NoteReminder model
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
                      if (reminder.body?.isNotEmpty == true)
                        Text(
                          reminder.body!,
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
                        title: Text('Delete', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildReminderDetails(reminder),
          ],
        ),
      ),
    );
  }

  Widget _getReminderIcon(ReminderType type) {
    switch (type) {
      case ReminderType.time:
        return Icon(
          Icons.access_time,
          color: Colors.blue[600],
          size: 28,
        );
      case ReminderType.location:
        return Icon(
          Icons.location_on,
          color: Colors.green[600],
          size: 28,
        );
      case ReminderType.recurring:
        return Icon(
          Icons.repeat,
          color: Colors.orange[600],
          size: 28,
        );
    }
  }

  Widget _buildReminderStatusChip(NoteReminder reminder) {
    if (!reminder.isActive) {
      return Chip(
        label: const Text('Inactive', style: TextStyle(fontSize: 12)),
        backgroundColor: Colors.grey[300],
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }
    
    if (reminder.snoozedUntil != null && 
        reminder.snoozedUntil!.isAfter(DateTime.now().toUtc())) {
      return Chip(
        label: const Text('Snoozed', style: TextStyle(fontSize: 12)),
        backgroundColor: Colors.orange[100],
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }
    
    return Chip(
      label: const Text('Active', style: TextStyle(fontSize: 12)),
      backgroundColor: Colors.green[100],
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildReminderDetails(NoteReminder reminder) {
    final details = <Widget>[];

    // Time details
    if (reminder.remindAt != null) {
      final localTime = reminder.remindAt!.toLocal();
      final timeStr = _formatDateTime(localTime);
      details.add(
        Row(
          children: [
            const Icon(Icons.schedule, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(timeStr, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    // Location details
    if (reminder.latitude != null && reminder.longitude != null) {
      final locationText = reminder.locationName ?? 
          '${reminder.latitude!.toStringAsFixed(4)}, ${reminder.longitude!.toStringAsFixed(4)}';
      details.add(
        Row(
          children: [
            const Icon(Icons.place, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                locationText,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
      
      if (reminder.radius != null) {
        details.add(
          Row(
            children: [
              const Icon(Icons.radio_button_unchecked, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Radius: ${reminder.radius!.round()}m',
                style: Theme.of(context).textTheme.bodySmall,
                        ),
        ],
      ),
    );
  }

  /// Get display name for recurrence pattern
  String _getRecurrenceDisplayName(RecurrencePattern? pattern) {
    if (pattern == null) return 'None';
    
    switch (pattern) {
      case RecurrencePattern.none:
        return 'None';
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

  String _getIntervalLabel(String interval) {
            const SizedBox(width: 8),
            Text(
              'Snoozed until $snoozeTimeStr',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Column(
      children: details
          .map((detail) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: detail,
              ))
          .toList(),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';

    if (date == today) {
      return 'Today $timeStr';
    } else if (date == tomorrow) {
      return 'Tomorrow $timeStr';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} $timeStr';
    }
  }

  void _showAddReminderDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddReminderSheet(
        noteId: widget.noteId,
        noteTitle: widget.noteTitle,
        noteBody: widget.noteBody,
        onReminderAdded: _loadReminders,
      ),
    );
  }

  void _handleReminderAction(String action, NoteReminder reminder) async {
    switch (action) {
      case 'edit':
        _showEditReminderDialog(reminder);
        break;
      case 'unsnooze':
        await _unsnoozeReminder(reminder);
        break;
      case 'deactivate':
        await _deactivateReminder(reminder);
        break;
      case 'activate':
        await _activateReminder(reminder);
        break;
      case 'delete':
        await _deleteReminder(reminder);
        break;
    }
  }

  void _showEditReminderDialog(NoteReminder reminder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditReminderSheet(
        reminder: reminder,
        noteTitle: widget.noteTitle,
        noteBody: widget.noteBody,
        onReminderUpdated: _loadReminders,
      ),
    );
  }

  Future<void> _unsnoozeReminder(NoteReminder reminder) async {
    try {
      final reminderService = null; // ref.read(advancedReminderServiceProvider) // TODO: Fix provider;
      final db = ref.read(appDbProvider);
      
      await db.clearSnooze(reminder.id);
      await _loadReminders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder un-snoozed')),
        );
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
      final db = ref.read(appDbProvider);
      
      await db.deactivateReminder(reminder.id);
      await _loadReminders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder deactivated')),
        );
      }
    } catch (e, stack) {
      logger.error('Failed to deactivate reminder', error: e, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to deactivate reminder')),
        );
      }
    }
  }

  Future<void> _activateReminder(NoteReminder reminder) async {
    try {
      final db = ref.read(appDbProvider);
      
      await db.updateReminder(reminder.id, const NoteRemindersCompanion(
        isActive: Value(true),
      ));
      await _loadReminders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder activated')),
        );
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

    if (confirmed == true) {
      try {
        final reminderService = null; // ref.read(advancedReminderServiceProvider) // TODO: Fix provider;
        
        await reminderService.deleteReminder(reminder.id);
        await _loadReminders();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder deleted')),
          );
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
}

/// Bottom sheet for adding new reminders
class AddReminderSheet extends ConsumerStatefulWidget {
  const AddReminderSheet({
    super.key,
    required this.noteId,
    required this.noteTitle,
    required this.noteBody,
    required this.onReminderAdded,
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
        return Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
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
              
              // Type selector
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
                            value: ReminderType.time,
                            label: Text('Location'),
                            icon: Icon(Icons.location_on),
                          ),
                        ],
                        selected: {_selectedType},
                        onSelectionChanged: (Set<ReminderType> selected) {
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
              
              // Content based on type
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
    super.key,
    required this.noteId,
    required this.noteTitle,
    required this.noteBody,
    required this.onReminderAdded,
  });

  final String noteId;
  final String noteTitle;
  final String noteBody;
  final VoidCallback onReminderAdded;

  @override
  ConsumerState<TimeReminderForm> createState() => _TimeReminderFormState();
}

class _TimeReminderFormState extends ConsumerState<TimeReminderForm> {
  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  String _recurrence = 'none';
  int _recurrenceInterval = 1;
  DateTime? _recurrenceEndDate;
  
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _notificationTitleController = TextEditingController();
  final _notificationBodyController = TextEditingController();
  
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
    _notificationTitleController.dispose();
    _notificationBodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic fields
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Reminder Title',
            border: OutlineInputBorder(),
          ),
          maxLines: 1,
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
        
        // Recurrence
        const Text(
          'Repeat',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        
        DropdownButtonFormField<String>(
          value: _recurrence,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          items: String.values.map((pattern) {
            return DropdownMenuItem(
              value: pattern,
              child: Text(pattern.displayName),
            );
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
                  controller: TextEditingController(text: _recurrenceInterval.toString()),
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
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';

    if (date == today) {
      return 'Today at $timeStr';
    } else if (date == tomorrow) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
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
      final reminderService = null; // ref.read(advancedReminderServiceProvider) // TODO: Fix provider;
      
      final reminderId = await reminderService.createTimeReminder(
        noteId: widget.noteId,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        remindAtUtc: _selectedDateTime.toUtc(),
        recurrence: _recurrence,
        recurrenceInterval: _recurrenceInterval,
        recurrenceEndDate: _recurrenceEndDate,
        customNotificationTitle: _notificationTitleController.text.trim().isEmpty
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
      logger.error('Failed to create time reminder', error: e, stackTrace: stack);
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
    super.key,
    required this.noteId,
    required this.noteTitle,
    required this.noteBody,
    required this.onReminderAdded,
  });

  final String noteId;
  final String noteTitle;
  final String noteBody;
  final VoidCallback onReminderAdded;

  @override
  ConsumerState<LocationReminderForm> createState() => _LocationReminderFormState();
}

class _LocationReminderFormState extends ConsumerState<LocationReminderForm> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _notificationTitleController = TextEditingController();
  final _notificationBodyController = TextEditingController();
  
  double _latitude = 0.0;
  double _longitude = 0.0;
  double _radius = 100.0; // Default 100 meters
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
        // Basic fields
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Reminder Title',
            border: OutlineInputBorder(),
          ),
          maxLines: 1,
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
                    ? Text('${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}')
                    : const Text('Tap to get current location'),
                onTap: _getCurrentLocation,
              ),
              if (_hasLocation) ...[
                ListTile(
                  leading: const Icon(Icons.edit_location),
                  title: const Text('Set custom location'),
                  subtitle: const Text('Enter coordinates manually'),
                  onTap: _showLocationDialog,
                ),
              ],
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

      final reminderService = null; // ref.read(advancedReminderServiceProvider) // TODO: Fix provider;
      
      // Check permissions
      if (!await reminderService.hasLocationPermissions()) {
        final granted = await reminderService.requestLocationPermissions();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission is required for location reminders'),
              ),
            );
          }
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _hasLocation = true;
      });

    } catch (e, stack) {
      logger.error('Failed to get current location', error: e, stackTrace: stack);
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

    showDialog(
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lngController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    if (!_hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a location')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final reminderService = null; // ref.read(advancedReminderServiceProvider) // TODO: Fix provider;
      
      final reminderId = await reminderService.createLocationReminder(
        noteId: widget.noteId,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        radius: _radius,
        locationName: _locationNameController.text.trim().isEmpty
            ? null
            : _locationNameController.text.trim(),
        customNotificationTitle: _notificationTitleController.text.trim().isEmpty
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
            const SnackBar(content: Text('Location reminder created successfully')),
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
      logger.error('Failed to create location reminder', error: e, stackTrace: stack);
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

/// Edit reminder sheet - simplified for brevity
class EditReminderSheet extends ConsumerWidget {
  const EditReminderSheet({
    super.key,
    required this.reminder,
    required this.noteTitle,
    required this.noteBody,
    required this.onReminderUpdated,
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
          
          // For now, show basic edit options
          // In a full implementation, this would have forms similar to AddReminderSheet
          
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

  /// Get display name for recurrence pattern
  String _getRecurrenceDisplayName(RecurrencePattern? pattern) {
    if (pattern == null) return 'None';
    
    switch (pattern) {
      case RecurrencePattern.none:
        return 'None';
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
}
