import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';

/// Reminder types
enum ReminderType {
  task,
  note,
  recurring,
  location,
  smart,
}

/// Reminder frequency for recurring reminders
enum ReminderFrequency {
  once,
  daily,
  weekly,
  monthly,
  yearly,
  custom,
}

/// Unified reminder model
class UnifiedReminder {
  const UnifiedReminder({
    required this.id,
    required this.type,
    required this.entityId,
    required this.title,
    required this.message,
    required this.scheduledAt,
    this.frequency = ReminderFrequency.once,
    this.metadata = const {},
    this.isActive = true,
    this.isSnoozed = false,
    this.completedAt,
  });

  final String id;
  final ReminderType type;
  final String entityId;
  final String title;
  final String message;
  final DateTime scheduledAt;
  final ReminderFrequency frequency;
  final Map<String, dynamic> metadata;
  final bool isActive;
  final bool isSnoozed;
  final DateTime? completedAt;

  UnifiedReminder copyWith({
    String? id,
    ReminderType? type,
    String? entityId,
    String? title,
    String? message,
    DateTime? scheduledAt,
    ReminderFrequency? frequency,
    Map<String, dynamic>? metadata,
    bool? isActive,
    bool? isSnoozed,
    DateTime? completedAt,
  }) {
    return UnifiedReminder(
      id: id ?? this.id,
      type: type ?? this.type,
      entityId: entityId ?? this.entityId,
      title: title ?? this.title,
      message: message ?? this.message,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      frequency: frequency ?? this.frequency,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      isSnoozed: isSnoozed ?? this.isSnoozed,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'entityId': entityId,
    'title': title,
    'message': message,
    'scheduledAt': scheduledAt.toIso8601String(),
    'frequency': frequency.name,
    'metadata': metadata,
    'isActive': isActive,
    'isSnoozed': isSnoozed,
    'completedAt': completedAt?.toIso8601String(),
  };
}

/// Unified reminder service supporting both domain and legacy models
class UnifiedReminderService {
  static final UnifiedReminderService _instance = UnifiedReminderService._internal();
  factory UnifiedReminderService() => _instance;
  UnifiedReminderService._internal();

  final _logger = LoggerFactory.instance;
  final _uuid = const Uuid();

  late final AppDb _db;
  late final MigrationConfig _migrationConfig;
  late final FlutterLocalNotificationsPlugin _notifications;

  // Domain repositories
  INotesRepository? _domainNotesRepo;
  ITaskRepository? _domainTasksRepo;

  // Reminder storage (in-memory for now, should be persisted)
  final Map<String, UnifiedReminder> _reminders = {};
  final Map<String, Timer> _activeTimers = {};

  // Stream controllers
  final _reminderStreamController = StreamController<List<UnifiedReminder>>.broadcast();

  Stream<List<UnifiedReminder>> get remindersStream => _reminderStreamController.stream;

  Future<void> initialize({
    required AppDb database,
    required MigrationConfig migrationConfig,
    required FlutterLocalNotificationsPlugin notifications,
    INotesRepository? domainNotesRepo,
    ITaskRepository? domainTasksRepo,
  }) async {
    _db = database;
    _migrationConfig = migrationConfig;
    _notifications = notifications;
    _domainNotesRepo = domainNotesRepo;
    _domainTasksRepo = domainTasksRepo;

    // Initialize notifications
    await _initializeNotifications();

    // Load existing reminders
    await _loadReminders();

    // Start reminder scheduler
    _startReminderScheduler();

    _logger.info('UnifiedReminderService initialized');
  }

  /// Create reminder for a task
  Future<UnifiedReminder> createTaskReminder({
    required dynamic task,
    required DateTime scheduledAt,
    String? customMessage,
    ReminderFrequency frequency = ReminderFrequency.once,
  }) async {
    try {
      final taskId = _getTaskId(task);
      final taskTitle = _getTaskTitle(task);

      final reminder = UnifiedReminder(
        id: _uuid.v4(),
        type: ReminderType.task,
        entityId: taskId,
        title: 'Task Reminder',
        message: customMessage ?? 'Task due: $taskTitle',
        scheduledAt: scheduledAt,
        frequency: frequency,
        metadata: {
          'taskTitle': taskTitle,
          'noteId': _getTaskNoteId(task),
        },
      );

      await _saveReminder(reminder);
      await _scheduleNotification(reminder);

      _logger.info('Created task reminder: ${reminder.id}');
      return reminder;

    } catch (e, stack) {
      _logger.error('Failed to create task reminder', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Create reminder for a note
  Future<UnifiedReminder> createNoteReminder({
    required dynamic note,
    required DateTime scheduledAt,
    String? customTitle,
    String? customMessage,
    ReminderFrequency frequency = ReminderFrequency.once,
  }) async {
    try {
      final noteId = _getNoteId(note);
      final noteTitle = _getNoteTitle(note);

      final reminder = UnifiedReminder(
        id: _uuid.v4(),
        type: ReminderType.note,
        entityId: noteId,
        title: customTitle ?? 'Note Reminder',
        message: customMessage ?? 'Review note: $noteTitle',
        scheduledAt: scheduledAt,
        frequency: frequency,
        metadata: {
          'noteTitle': noteTitle,
        },
      );

      await _saveReminder(reminder);
      await _scheduleNotification(reminder);

      _logger.info('Created note reminder: ${reminder.id}');
      return reminder;

    } catch (e, stack) {
      _logger.error('Failed to create note reminder', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Create smart reminder based on content analysis
  Future<List<UnifiedReminder>> createSmartReminders(dynamic note) async {
    try {
      final noteId = _getNoteId(note);
      final noteContent = _getNoteContent(note);
      final reminders = <UnifiedReminder>[];

      // Parse for dates and times in content
      final datePattern = RegExp(r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b');
      final timePattern = RegExp(r'\b(\d{1,2}:\d{2}\s*(?:AM|PM)?)\b', caseSensitive: false);

      final dateMatches = datePattern.allMatches(noteContent);
      final timeMatches = timePattern.allMatches(noteContent);

      // Create reminders for found dates
      for (final match in dateMatches) {
        try {
          final dateStr = match.group(0)!;
          // Parse date (simplified - would need better date parsing)
          final parts = dateStr.split(RegExp(r'[/-]'));
          if (parts.length == 3) {
            final month = int.tryParse(parts[0]) ?? 1;
            final day = int.tryParse(parts[1]) ?? 1;
            final year = int.tryParse(parts[2]) ?? DateTime.now().year;

            final scheduledDate = DateTime(year, month, day, 9, 0); // Default to 9 AM

            if (scheduledDate.isAfter(DateTime.now())) {
              final reminder = UnifiedReminder(
                id: _uuid.v4(),
                type: ReminderType.smart,
                entityId: noteId,
                title: 'Smart Reminder',
                message: 'Date mentioned in note: $dateStr',
                scheduledAt: scheduledDate,
                metadata: {
                  'extractedDate': dateStr,
                  'noteId': noteId,
                },
              );

              reminders.add(reminder);
            }
          }
        } catch (e) {
          _logger.debug('Failed to parse date: ${match.group(0)}');
        }
      }

      // Save all smart reminders
      for (final reminder in reminders) {
        await _saveReminder(reminder);
        await _scheduleNotification(reminder);
      }

      _logger.info('Created ${reminders.length} smart reminders for note: $noteId');
      return reminders;

    } catch (e, stack) {
      _logger.error('Failed to create smart reminders', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Get reminders for an entity
  Future<List<UnifiedReminder>> getRemindersForEntity(String entityId) async {
    return _reminders.values
        .where((r) => r.entityId == entityId && r.isActive)
        .toList();
  }

  /// Get all active reminders
  Future<List<UnifiedReminder>> getActiveReminders() async {
    return _reminders.values
        .where((r) => r.isActive && r.completedAt == null)
        .toList();
  }

  /// Get upcoming reminders
  Future<List<UnifiedReminder>> getUpcomingReminders({
    Duration within = const Duration(days: 7),
  }) async {
    final now = DateTime.now();
    final cutoff = now.add(within);

    return _reminders.values
        .where((r) =>
            r.isActive &&
            r.completedAt == null &&
            r.scheduledAt.isAfter(now) &&
            r.scheduledAt.isBefore(cutoff))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  /// Snooze a reminder
  Future<void> snoozeReminder(
    String reminderId, {
    Duration snoozeDuration = const Duration(minutes: 10),
  }) async {
    try {
      final reminder = _reminders[reminderId];
      if (reminder == null) {
        throw ArgumentError('Reminder not found: $reminderId');
      }

      final snoozedReminder = reminder.copyWith(
        scheduledAt: DateTime.now().add(snoozeDuration),
        isSnoozed: true,
      );

      await _saveReminder(snoozedReminder);
      await _cancelNotification(reminder);
      await _scheduleNotification(snoozedReminder);

      _logger.info('Snoozed reminder: $reminderId for ${snoozeDuration.inMinutes} minutes');

    } catch (e, stack) {
      _logger.error('Failed to snooze reminder', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Complete a reminder
  Future<void> completeReminder(String reminderId) async {
    try {
      final reminder = _reminders[reminderId];
      if (reminder == null) {
        throw ArgumentError('Reminder not found: $reminderId');
      }

      final completedReminder = reminder.copyWith(
        isActive: false,
        completedAt: DateTime.now(),
      );

      await _saveReminder(completedReminder);
      await _cancelNotification(reminder);

      // If it's a recurring reminder, schedule the next occurrence
      if (reminder.frequency != ReminderFrequency.once) {
        await _scheduleNextOccurrence(reminder);
      }

      _logger.info('Completed reminder: $reminderId');

    } catch (e, stack) {
      _logger.error('Failed to complete reminder', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Delete a reminder
  Future<void> deleteReminder(String reminderId) async {
    try {
      final reminder = _reminders[reminderId];
      if (reminder != null) {
        await _cancelNotification(reminder);
        _reminders.remove(reminderId);
        _notifyListeners();
      }

      _logger.info('Deleted reminder: $reminderId');

    } catch (e, stack) {
      _logger.error('Failed to delete reminder', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Sync task reminders with task due dates
  Future<void> syncTaskReminders() async {
    try {
      _logger.debug('Syncing task reminders');

      // Get all tasks with due dates
      final tasks = await _getAllTasks();

      for (final task in tasks) {
        final taskId = _getTaskId(task);
        final dueDate = _getTaskDueDate(task);

        if (dueDate != null && dueDate.isAfter(DateTime.now())) {
          // Check if reminder already exists
          final existingReminders = await getRemindersForEntity(taskId);
          final hasReminder = existingReminders.any((r) =>
              r.type == ReminderType.task &&
              r.scheduledAt.difference(dueDate).abs() < const Duration(minutes: 1));

          if (!hasReminder && !_isTaskCompleted(task)) {
            // Create reminder 1 hour before due date
            final reminderTime = dueDate.subtract(const Duration(hours: 1));
            if (reminderTime.isAfter(DateTime.now())) {
              await createTaskReminder(
                task: task,
                scheduledAt: reminderTime,
              );
            }
          }
        }
      }

      _logger.info('Task reminder sync completed');

    } catch (e, stack) {
      _logger.error('Failed to sync task reminders', error: e, stackTrace: stack);
    }
  }

  // Private helper methods
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
  }

  void _handleNotificationResponse(NotificationResponse response) {
    _logger.debug('Notification response: ${response.payload}');

    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        final reminderId = data['reminderId'] as String?;

        if (reminderId != null) {
          // Handle reminder action
          final reminder = _reminders[reminderId];
          if (reminder != null) {
            // Navigate to the related entity
            _logger.info('User tapped reminder notification: $reminderId');
          }
        }
      } catch (e) {
        _logger.error('Failed to handle notification response', error: e);
      }
    }
  }

  Future<void> _scheduleNotification(UnifiedReminder reminder) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'reminders',
        'Reminders',
        channelDescription: 'Notifications for reminders',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = jsonEncode({
        'reminderId': reminder.id,
        'type': reminder.type.name,
        'entityId': reminder.entityId,
      });

      if (reminder.scheduledAt.isAfter(DateTime.now())) {
        await _notifications.zonedSchedule(
          reminder.id.hashCode,
          reminder.title,
          reminder.message,
          tz.TZDateTime.from(reminder.scheduledAt, tz.local),
          details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );

        _logger.debug('Scheduled notification for reminder: ${reminder.id}');
      }
    } catch (e, stack) {
      _logger.error('Failed to schedule notification', error: e, stackTrace: stack);
    }
  }

  Future<void> _cancelNotification(UnifiedReminder reminder) async {
    try {
      await _notifications.cancel(reminder.id.hashCode);
      _logger.debug('Cancelled notification for reminder: ${reminder.id}');
    } catch (e) {
      _logger.error('Failed to cancel notification', error: e);
    }
  }

  Future<void> _scheduleNextOccurrence(UnifiedReminder reminder) async {
    DateTime? nextDate;

    switch (reminder.frequency) {
      case ReminderFrequency.daily:
        nextDate = reminder.scheduledAt.add(const Duration(days: 1));
        break;
      case ReminderFrequency.weekly:
        nextDate = reminder.scheduledAt.add(const Duration(days: 7));
        break;
      case ReminderFrequency.monthly:
        nextDate = DateTime(
          reminder.scheduledAt.year,
          reminder.scheduledAt.month + 1,
          reminder.scheduledAt.day,
          reminder.scheduledAt.hour,
          reminder.scheduledAt.minute,
        );
        break;
      case ReminderFrequency.yearly:
        nextDate = DateTime(
          reminder.scheduledAt.year + 1,
          reminder.scheduledAt.month,
          reminder.scheduledAt.day,
          reminder.scheduledAt.hour,
          reminder.scheduledAt.minute,
        );
        break;
      default:
        return; // No recurrence
    }

    final nextReminder = reminder.copyWith(
      id: _uuid.v4(),
      scheduledAt: nextDate,
      isActive: true,
      isSnoozed: false,
      completedAt: null,
    );

    await _saveReminder(nextReminder);
    await _scheduleNotification(nextReminder);

    _logger.info('Scheduled next occurrence for recurring reminder');
    }

  Future<void> _saveReminder(UnifiedReminder reminder) async {
    _reminders[reminder.id] = reminder;
    _notifyListeners();
    // Should persist to database
  }

  Future<void> _loadReminders() async {
    // Should load from database
    _notifyListeners();
  }

  void _startReminderScheduler() {
    // Check for due reminders every minute
    Timer.periodic(const Duration(minutes: 1), (_) {
      _checkDueReminders();
    });
  }

  void _checkDueReminders() {
    final now = DateTime.now();
    for (final reminder in _reminders.values) {
      if (reminder.isActive &&
          reminder.completedAt == null &&
          reminder.scheduledAt.isBefore(now)) {
        // Reminder is due
        _logger.debug('Reminder due: ${reminder.id}');
      }
    }
  }

  void _notifyListeners() {
    _reminderStreamController.add(
      _reminders.values.toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt)),
    );
  }

  // Data access methods
  Future<List<dynamic>> _getAllTasks() async {
    if (_migrationConfig.isFeatureEnabled('tasks') && _domainTasksRepo != null) {
      return await _domainTasksRepo!.getAllTasks();
    } else {
      return await _db.select(_db.noteTasks).get();
    }
  }

  // Type-agnostic property accessors
  String _getNoteId(dynamic note) {
    if (note is domain.Note) return note.id;
    if (note is LocalNote) return note.id;
    throw ArgumentError('Unknown note type');
  }

  String _getNoteTitle(dynamic note) {
    if (note is domain.Note) return note.title;
    if (note is LocalNote) return note.title;
    throw ArgumentError('Unknown note type');
  }

  String _getNoteContent(dynamic note) {
    if (note is domain.Note) return note.body;
    if (note is LocalNote) return note.body;
    throw ArgumentError('Unknown note type');
  }

  String _getTaskId(dynamic task) {
    if (task is domain.Task) return task.id;
    if (task is NoteTask) return task.id;
    throw ArgumentError('Unknown task type');
  }

  String _getTaskTitle(dynamic task) {
    if (task is domain.Task) return task.title;
    if (task is NoteTask) return task.content;
    throw ArgumentError('Unknown task type');
  }

  String? _getTaskNoteId(dynamic task) {
    if (task is domain.Task) return task.noteId;
    if (task is NoteTask) return task.noteId;
    throw ArgumentError('Unknown task type');
  }

  DateTime? _getTaskDueDate(dynamic task) {
    if (task is domain.Task) return task.dueDate;
    if (task is NoteTask) return task.dueDate;
    throw ArgumentError('Unknown task type');
  }

  bool _isTaskCompleted(dynamic task) {
    if (task is domain.Task) return task.status == domain.TaskStatus.completed;
    if (task is NoteTask) return task.status == TaskStatus.completed;
    throw ArgumentError('Unknown task type');
  }

  void dispose() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    _reminderStreamController.close();
  }
}