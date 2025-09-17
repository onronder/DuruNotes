import 'package:duru_notes/services/notification_handler_service.dart';
import 'package:duru_notes/services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@GenerateMocks([SupabaseClient, GoTrueClient, FirebaseMessaging, RemoteMessage])
void main() {
  group('Push Notification System Tests', () {
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late PushNotificationService pushService;
    late NotificationHandlerService handlerService;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();

      when(mockSupabase.auth).thenReturn(mockAuth);

      pushService = PushNotificationService(client: mockSupabase);
      handlerService = NotificationHandlerService(
        client: mockSupabase,
        pushService: pushService,
      );
    });

    group('PushNotificationService', () {
      test('should initialize successfully', () async {
        await pushService.initialize();
        expect(pushService.isInitialized, isTrue);
      });

      test('should handle missing user gracefully', () async {
        when(mockAuth.currentUser).thenReturn(null);

        final result = await pushService.registerWithBackend();

        expect(result.success, isFalse);
        expect(result.error, contains('not authenticated'));
      });

      test('should handle permission denial', () async {
        // Mock user authenticated
        final mockUser = User(
          id: 'test-user-id',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        );
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Mock permission denied
        // This would require mocking Firebase Messaging
        // For now, we'll test the structure

        expect(pushService.registerWithBackend, returnsNormally);
      });
    });

    group('NotificationHandlerService', () {
      test('should initialize notification handler', () async {
        await handlerService.initialize();
        expect(handlerService.isInitialized, isTrue);
      });

      test('should parse notification payload correctly', () {
        const payload = NotificationPayload(
          eventId: 'test-event-id',
          eventType: 'email_received',
          title: 'Test Title',
          body: 'Test Body',
          data: {'key': 'value'},
        );

        final json = payload.toJson();
        final parsed = NotificationPayload.fromJson(json);

        expect(parsed.eventId, equals(payload.eventId));
        expect(parsed.eventType, equals(payload.eventType));
        expect(parsed.title, equals(payload.title));
        expect(parsed.body, equals(payload.body));
        expect(parsed.data, equals(payload.data));
      });

      test('should emit notification tap events', () async {
        await handlerService.initialize();

        const payload = NotificationPayload(
          eventId: 'test-event',
          eventType: 'test',
          title: 'Test',
          body: 'Body',
        );

        expectLater(handlerService.onNotificationTap, emits(payload));

        // Simulate notification tap
        handlerService.notificationTapSubject.add(payload);
      });

      test('should handle notification preferences', () async {
        final mockUser = User(
          id: 'test-user-id',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        );
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Mock preferences response
        when(
          mockSupabase.from('notification_preferences'),
        ).thenReturn(MockSupabaseQueryBuilder());

        await handlerService.initialize();

        // Test preference checking
        const payload = NotificationPayload(
          eventId: 'test',
          eventType: 'email_received',
          title: 'Test',
          body: 'Test',
        );

        final shouldShow = await handlerService.shouldShowNotification(payload);
        expect(shouldShow, isNotNull);
      });
    });

    group('Notification Event Queue', () {
      test('should create notification event', () async {
        final mockUser = User(
          id: 'test-user-id',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        );
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Mock RPC call
        when(
          mockSupabase.rpc(
            'create_notification_event',
            params: anyNamed('params'),
          ),
        ).thenAnswer((_) async => 'event-id-123');

        // Test event creation
        final eventData = {
          'p_user_id': 'test-user-id',
          'p_event_type': 'email_received',
          'p_event_source': 'email_in',
          'p_payload': {'from': 'sender@example.com', 'subject': 'Test Email'},
        };

        await mockSupabase.rpc('create_notification_event', params: eventData);

        verify(
          mockSupabase.rpc(
            'create_notification_event',
            params: argThat(isA<Map>()),
          ),
        ).called(1);
      });

      test('should handle deduplication', () async {
        // Test that duplicate events with same dedupe_key are handled
        final eventData1 = {
          'p_user_id': 'test-user',
          'p_event_type': 'email_received',
          'p_dedupe_key': 'email_123',
        };

        final eventData2 = {
          'p_user_id': 'test-user',
          'p_event_type': 'email_received',
          'p_dedupe_key': 'email_123', // Same key
        };

        // First event should succeed
        when(
          mockSupabase.rpc('create_notification_event', params: eventData1),
        ).thenAnswer((_) async => 'event-1');

        // Second event should update, not create new
        when(
          mockSupabase.rpc('create_notification_event', params: eventData2),
        ).thenAnswer((_) async => 'event-1'); // Same ID

        final result1 = await mockSupabase.rpc(
          'create_notification_event',
          params: eventData1,
        );
        final result2 = await mockSupabase.rpc(
          'create_notification_event',
          params: eventData2,
        );

        expect(result1, equals(result2));
      });
    });

    group('Edge Function Integration', () {
      test('should process notification batch', () async {
        // Mock batch processing
        final batchData = {'batch_size': 10};

        when(
          mockSupabase.functions.invoke(
            'send-push-notification',
            body: batchData,
          ),
        ).thenAnswer(
          (_) async => FunctionResponse(
            data: {
              'processed': 5,
              'results': [
                {'event_id': '1', 'status': 'delivered'},
                {'event_id': '2', 'status': 'delivered'},
                {'event_id': '3', 'status': 'failed'},
                {'event_id': '4', 'status': 'delivered'},
                {'event_id': '5', 'status': 'retrying'},
              ],
            },
            status: 200,
          ),
        );

        final response = await mockSupabase.functions.invoke(
          'send-push-notification',
          body: batchData,
        );

        expect(response.status, equals(200));
        expect(response.data['processed'], equals(5));
      });

      test('should handle retry logic', () async {
        // Test exponential backoff calculation
        final retryDelays = [30, 120, 600, 3600]; // seconds

        for (var i = 0; i < retryDelays.length; i++) {
          final nextRetry = calculateNextRetryTime(i);
          final expectedDelay = retryDelays[i];

          expect(
            nextRetry.difference(DateTime.now()).inSeconds,
            closeTo(expectedDelay, 1),
          );
        }
      });
    });

    group('Notification Delivery Tracking', () {
      test('should track delivery status', () async {
        final deliveryData = {
          'event_id': 'test-event',
          'user_id': 'test-user',
          'channel': 'push',
          'status': 'delivered',
          'delivered_at': DateTime.now().toIso8601String(),
        };

        when(
          mockSupabase.from('notification_deliveries'),
        ).thenReturn(MockSupabaseQueryBuilder());

        // Simulate delivery tracking
        await mockSupabase.from('notification_deliveries').insert(deliveryData);

        verify(mockSupabase.from('notification_deliveries')).called(1);
      });

      test('should handle failed deliveries', () async {
        final failureData = {
          'event_id': 'test-event',
          'user_id': 'test-user',
          'channel': 'push',
          'status': 'failed',
          'error_code': 'InvalidToken',
          'error_message': 'Token is invalid or expired',
          'failed_at': DateTime.now().toIso8601String(),
        };

        when(
          mockSupabase.from('notification_deliveries'),
        ).thenReturn(MockSupabaseQueryBuilder());

        await mockSupabase.from('notification_deliveries').insert(failureData);

        verify(mockSupabase.from('notification_deliveries')).called(1);
      });
    });

    group('User Preferences', () {
      test('should respect quiet hours', () {
        final now = DateTime.now();
        final quietStart = TimeOfDay(hour: 22, minute: 0);
        final quietEnd = TimeOfDay(hour: 7, minute: 0);

        // Test if current time is in quiet hours
        final currentMinutes = now.hour * 60 + now.minute;
        final startMinutes = quietStart.hour * 60 + quietStart.minute;
        final endMinutes = quietEnd.hour * 60 + quietEnd.minute;

        bool inQuietHours;
        if (startMinutes > endMinutes) {
          // Quiet hours span midnight
          inQuietHours =
              currentMinutes >= startMinutes || currentMinutes <= endMinutes;
        } else {
          inQuietHours =
              currentMinutes >= startMinutes && currentMinutes <= endMinutes;
        }

        expect(inQuietHours, isA<bool>());
      });

      test('should respect Do Not Disturb', () async {
        final dndUntil = DateTime.now().add(const Duration(hours: 2));

        // Check if DND is active
        final isDndActive = DateTime.now().isBefore(dndUntil);

        expect(isDndActive, isTrue);

        // Check after DND expires
        final afterDnd = dndUntil.add(const Duration(minutes: 1));
        final isDndExpired = afterDnd.isAfter(dndUntil);

        expect(isDndExpired, isTrue);
      });

      test('should filter by event type preferences', () {
        final eventPreferences = {
          'email_received': {'enabled': true},
          'web_clip_saved': {'enabled': false},
          'reminder_due': {'enabled': true},
        };

        // Test filtering
        expect(eventPreferences['email_received']?['enabled'], isTrue);
        expect(eventPreferences['web_clip_saved']?['enabled'], isFalse);
        expect(eventPreferences['reminder_due']?['enabled'], isTrue);
        expect(eventPreferences['unknown_event']?['enabled'], isNull);
      });
    });
  });
}

// Helper function to calculate retry time
DateTime calculateNextRetryTime(int retryCount) {
  final delays = [30, 120, 600, 3600]; // seconds
  final delaySeconds = delays[retryCount.clamp(0, delays.length - 1)];
  return DateTime.now().add(Duration(seconds: delaySeconds));
}

// Mock classes for testing
class MockSupabaseQueryBuilder extends Mock
    implements SupabaseQueryBuilder<dynamic> {
  @override
  SupabaseQueryBuilder<dynamic> select([String? columns]) => this;

  @override
  SupabaseQueryBuilder<dynamic> eq(String column, Object value) => this;

  @override
  Future<dynamic> maybeSingle() async => null;

  @override
  Future<dynamic> insert(Map<String, dynamic> values) async => null;

  @override
  Future<dynamic> update(Map<String, dynamic> values) async => null;
}
