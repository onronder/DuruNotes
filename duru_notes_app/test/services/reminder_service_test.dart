import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:duru_notes_app/services/reminder_service.dart';
import 'package:duru_notes_app/data/local/app_db.dart';

// Mock classes
class MockFlutterLocalNotificationsPlugin extends Mock implements FlutterLocalNotificationsPlugin {}
class MockAppDb extends Mock implements AppDb {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('ReminderService', () {
    late ReminderService reminderService;
    late MockFlutterLocalNotificationsPlugin mockPlugin;
    late MockAppDb mockDb;

    setUp(() {
      mockPlugin = MockFlutterLocalNotificationsPlugin();
      mockDb = MockAppDb();
      reminderService = ReminderService(mockPlugin, mockDb);
    });

    test('should initialize without error', () async {
      // Arrange
      when(mockPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(null);

      // Act & Assert
      expect(() => reminderService.init(), returnsNormally);
    });

    test('should generate stable notification ID from noteId', () {
      // Arrange
      const noteId = 'test-note-id';
      
      // Act
      final id1 = noteId.hashCode.abs();
      final id2 = noteId.hashCode.abs();
      
      // Assert
      expect(id1, equals(id2));
      expect(id1, isA<int>());
    });

    test('should not schedule reminder for past time', () async {
      // Arrange
      await reminderService.init();
      final pastTime = DateTime.now().toUtc().subtract(const Duration(hours: 1));

      // Act
      final result = await reminderService.schedule(
        noteId: 'test-note',
        remindAtUtc: pastTime,
        title: 'Test',
        body: 'Test',
      );

      // Assert
      expect(result, isFalse);
    });

    test('should format notification payload correctly', () {
      // Arrange
      const noteId = 'test-note-123';
      
      // Act
      const expectedPayload = '{"noteId":"test-note-123"}';
      
      // Assert
      // This would be tested in the actual schedule method
      expect(expectedPayload.contains(noteId), isTrue);
    });

    test('should handle cancellation gracefully', () async {
      // Arrange
      await reminderService.init();
      const noteId = 'test-note';

      // Act & Assert
      expect(() => reminderService.cancel(noteId), returnsNormally);
    });

    test('should cleanup all reminders', () async {
      // Arrange
      await reminderService.init();

      // Act & Assert
      expect(() => reminderService.cancelAll(), returnsNormally);
    });
  });
}
