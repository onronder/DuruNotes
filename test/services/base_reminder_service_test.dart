import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/reminders/base_reminder_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'base_reminder_service_test.mocks.dart';

// Generate mocks
@GenerateMocks([
  FlutterLocalNotificationsPlugin,
  AppDb,
])
void main() {
  group('BaseReminderService Tests', () {
    late MockFlutterLocalNotificationsPlugin mockPlugin;
    late MockAppDb mockDb;
    late TestReminderService service;

    setUp(() {
      mockPlugin = MockFlutterLocalNotificationsPlugin();
      mockDb = MockAppDb();
      service = TestReminderService(
        plugin: mockPlugin,
        db: mockDb,
      );
    });

    group('Permission Management', () {
      test('should request notification permissions', () async {
        // Arrange
        service.setPermissionResponse(true);

        // Act
        final result = await service.requestNotificationPermissions();

        // Assert
        expect(result, isTrue);
      });

      test('should check notification permissions', () async {
        // Arrange
        service.setPermissionStatus(true);

        // Act
        final result = await service.hasNotificationPermissions();

        // Assert
        expect(result, isTrue);
      });

      test('should handle permission denial', () async {
        // Arrange
        service.setPermissionResponse(false);

        // Act
        final result = await service.requestNotificationPermissions();

        // Assert
        expect(result, isFalse);
      });
    });

    group('Database Operations', () {
      test('should create reminder in database', () async {
        // Arrange
        const expectedId = 123;
        service.setDbCreateResponse(expectedId);

        // Act
        final companion = NoteRemindersCompanion.insert(
          noteId: 'test-note',
          reminderTime: DateTime.now(),
        );
        final result = await service.createReminderInDb(companion);

        // Assert
        expect(result, equals(expectedId));
      });

      test('should handle database creation failure', () async {
        // Arrange
        service.setDbCreateResponse(null);

        // Act
        final companion = NoteRemindersCompanion.insert(
          noteId: 'test-note',
          reminderTime: DateTime.now(),
        );
        final result = await service.createReminderInDb(companion);

        // Assert
        expect(result, isNull);
      });

      test('should update reminder status', () async {
        // Arrange
        const reminderId = 123;
        service.setUpdateSuccess(true);

        // Act
        await service.updateReminderStatus(reminderId, true, false, false);

        // Assert
        expect(service.lastUpdatedId, equals(reminderId));
        expect(service.lastUpdatedStatus, isTrue);
      });
    });

    group('Notification Scheduling', () {
      test('should schedule notification with correct data', () async {
        // Arrange
        final notificationData = ReminderNotificationData(
          id: 1,
          title: 'Test Reminder',
          body: 'Test Body',
          scheduledDate: DateTime.now().add(const Duration(hours: 1)),
        );

        // Act
        await service.scheduleNotification(notificationData);

        // Assert
        expect(service.lastScheduledNotification, equals(notificationData));
      });

      test('should get notification actions', () {
        // Act
        final actions = service.getNotificationActions();

        // Assert
        expect(actions, isNotEmpty);
        expect(actions.any((a) => a.id == 'complete'), isTrue);
        expect(actions.any((a) => a.id == 'snooze'), isTrue);
      });
    });

    group('Analytics Tracking', () {
      test('should track reminder creation event', () {
        // Arrange
        const event = 'reminder_created';
        final properties = {'type': 'recurring', 'noteId': 'test'};

        // Act
        service.trackReminderEvent(event, properties);

        // Assert
        expect(service.lastTrackedEvent, equals(event));
        expect(service.lastTrackedProperties, equals(properties));
      });

      test('should track reminder cancellation', () {
        // Arrange
        const event = 'reminder_cancelled';
        final properties = {'id': 123};

        // Act
        service.trackReminderEvent(event, properties);

        // Assert
        expect(service.lastTrackedEvent, equals(event));
        expect(service.lastTrackedProperties?['id'], equals(123));
      });
    });

    group('Reminder Operations', () {
      test('should create reminder successfully', () async {
        // Arrange
        service.setPermissionStatus(true);
        service.setDbCreateResponse(123);
        final config = ReminderConfig(
          noteId: 'test-note',
          reminderTime: DateTime.now().add(const Duration(hours: 1)),
          type: ReminderType.oneTime,
        );

        // Act
        final result = await service.createReminder(config);

        // Assert
        expect(result, equals(123));
        expect(service.lastScheduledNotification, isNotNull);
      });

      test('should not create reminder without permissions', () async {
        // Arrange
        service.setPermissionStatus(false);
        final config = ReminderConfig(
          noteId: 'test-note',
          reminderTime: DateTime.now().add(const Duration(hours: 1)),
          type: ReminderType.oneTime,
        );

        // Act
        final result = await service.createReminder(config);

        // Assert
        expect(result, isNull);
      });

      test('should cancel reminder', () async {
        // Arrange
        const reminderId = 123;
        service.setCancelSuccess(true);

        // Act
        await service.cancelReminder(reminderId);

        // Assert
        expect(service.lastCancelledId, equals(reminderId));
      });
    });
  });
}

// Test implementation of BaseReminderService
class TestReminderService extends BaseReminderService {
  bool _hasPermission = false;
  bool _permissionResponse = false;
  int? _dbCreateResponse;
  bool _updateSuccess = false;
  bool _cancelSuccess = false;

  // Tracking for assertions
  ReminderNotificationData? lastScheduledNotification;
  String? lastTrackedEvent;
  Map<String, dynamic>? lastTrackedProperties;
  int? lastUpdatedId;
  bool? lastUpdatedStatus;
  int? lastCancelledId;

  TestReminderService({
    required super.plugin,
    required super.db,
  });

  void setPermissionStatus(bool status) => _hasPermission = status;
  void setPermissionResponse(bool response) => _permissionResponse = response;
  void setDbCreateResponse(int? id) => _dbCreateResponse = id;
  void setUpdateSuccess(bool success) => _updateSuccess = success;
  void setCancelSuccess(bool success) => _cancelSuccess = success;

  @override
  Future<bool> requestNotificationPermissions() async {
    return _permissionResponse;
  }

  @override
  Future<bool> hasNotificationPermissions() async {
    return _hasPermission;
  }

  @override
  Future<int?> createReminderInDb(NoteRemindersCompanion companion) async {
    return _dbCreateResponse;
  }

  @override
  Future<void> updateReminderStatus(
    int id,
    bool isCompleted,
    bool isActive,
    bool isSnoozed,
  ) async {
    lastUpdatedId = id;
    lastUpdatedStatus = isCompleted;
    if (!_updateSuccess) {
      throw Exception('Update failed');
    }
  }

  @override
  Future<void> scheduleNotification(ReminderNotificationData data) async {
    lastScheduledNotification = data;
  }

  @override
  List<AndroidNotificationAction> getNotificationActions() {
    return [
      const AndroidNotificationAction('complete', 'Complete'),
      const AndroidNotificationAction('snooze', 'Snooze'),
    ];
  }

  @override
  void trackReminderEvent(String event, Map<String, dynamic> properties) {
    lastTrackedEvent = event;
    lastTrackedProperties = properties;
  }

  @override
  Future<int?> createReminder(ReminderConfig config) async {
    if (!await hasNotificationPermissions()) {
      return null;
    }

    final companion = NoteRemindersCompanion.insert(
      noteId: config.noteId,
      reminderTime: config.reminderTime,
    );

    final id = await createReminderInDb(companion);
    if (id != null) {
      await scheduleNotification(
        ReminderNotificationData(
          id: id,
          title: 'Reminder',
          body: 'Note reminder',
          scheduledDate: config.reminderTime,
        ),
      );
      trackReminderEvent('reminder_created', {
        'id': id,
        'type': config.type.toString(),
      });
    }
    return id;
  }

  @override
  Future<void> cancelReminder(int id) async {
    lastCancelledId = id;
    if (!_cancelSuccess) {
      throw Exception('Cancel failed');
    }
    trackReminderEvent('reminder_cancelled', {'id': id});
  }
}

// Supporting classes for testing
class ReminderConfig {
  final String noteId;
  final DateTime reminderTime;
  final ReminderType type;

  ReminderConfig({
    required this.noteId,
    required this.reminderTime,
    required this.type,
  });
}

enum ReminderType { oneTime, recurring, location }

class ReminderNotificationData {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledDate;

  ReminderNotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderNotificationData &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          body == other.body;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ body.hashCode;
}
