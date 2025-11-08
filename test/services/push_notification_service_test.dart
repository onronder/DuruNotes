import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart' as app_logger;
import 'package:duru_notes/services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    app_logger.LoggerFactory.initialize();
    PackageInfo.setMockInitialValues(
      appName: 'Duru Notes',
      packageName: 'com.fittechs.duruNotesApp',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'test',
      installerStore: 'mock',
    );
  });

  group('PushNotificationService.registerWithBackend', () {
    late FakeMessagingClient messaging;
    late FakeAuthAdapter auth;
    late FakePushTokenApi tokenApi;
    late PushNotificationService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      messaging = FakeMessagingClient();
      auth = FakeAuthAdapter();
      tokenApi = FakePushTokenApi();

      auth.currentUser = User.fromJson({
        'id': 'user-123',
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'test@example.com',
        'email_confirmed_at': DateTime.now().toIso8601String(),
        'app_metadata': const <String, dynamic>{},
        'user_metadata': const <String, dynamic>{},
        'created_at': DateTime.now().toIso8601String(),
      });
      auth.currentSession = Session.fromJson({
        'access_token': 'token',
        'token_type': 'bearer',
        'refresh_token': 'refresh',
        'expires_in': 3600,
        'expires_at':
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
        'user': auth.currentUser!.toJson(),
      });

      service = PushNotificationService(
        logger: app_logger.LoggerFactory.instance,
        messagingClient: messaging,
        tokenApi: tokenApi,
        authAdapter: auth,
        sharedPreferencesLoader: () => SharedPreferences.getInstance(),
        physicalDeviceResolver: () async => true,
      );
    });

    test(
      'requests permission, obtains token, and syncs with backend',
      () async {
        messaging
          ..permissionSequence = [_settings(AuthorizationStatus.notDetermined)]
          ..requestResponse = _settings(AuthorizationStatus.authorized)
          ..tokenToReturn = 'fcm-token-12345678901234567890';

        await service.initialize();
        service.debugSetOverrides(messagingClient: messaging);

        final result = await service.registerWithBackend();

        expect(result.success, isTrue);
        expect(tokenApi.upsertCalls, 1);
        expect(tokenApi.lastDeviceId, isNotEmpty);
        expect(tokenApi.lastToken, 'fcm-token-12345678901234567890');
        expect(messaging.permissionRequested, isTrue);
        expect(messaging.getTokenCalls, greaterThan(0));
      },
    );
  });
}

NotificationSettings _settings(AuthorizationStatus status) {
  return NotificationSettings(
    alert: AppleNotificationSetting.enabled,
    announcement: AppleNotificationSetting.notSupported,
    authorizationStatus: status,
    badge: AppleNotificationSetting.enabled,
    carPlay: AppleNotificationSetting.notSupported,
    criticalAlert: AppleNotificationSetting.notSupported,
    lockScreen: AppleNotificationSetting.enabled,
    notificationCenter: AppleNotificationSetting.enabled,
    showPreviews: AppleShowPreviewSetting.notSupported,
    sound: AppleNotificationSetting.enabled,
    timeSensitive: AppleNotificationSetting.notSupported,
    providesAppNotificationSettings: AppleNotificationSetting.notSupported,
  );
}

class FakeMessagingClient implements PushMessagingClient {
  final _refreshController = StreamController<String>.broadcast();
  List<NotificationSettings> permissionSequence = const [];
  NotificationSettings? requestResponse;
  String? tokenToReturn;
  bool permissionRequested = false;
  int getTokenCalls = 0;

  @override
  Future<String?> getAPNSToken() async => null;

  @override
  Future<NotificationSettings> getNotificationSettings() async {
    if (permissionSequence.isEmpty) {
      return _settings(AuthorizationStatus.authorized);
    }
    return permissionSequence.removeAt(0);
  }

  @override
  Stream<String> get onTokenRefresh => _refreshController.stream;

  @override
  Future<String?> getToken() async {
    getTokenCalls += 1;
    return tokenToReturn;
  }

  @override
  Future<NotificationSettings> requestPermission() async {
    permissionRequested = true;
    return requestResponse ?? _settings(AuthorizationStatus.denied);
  }
}

class FakePushTokenApi implements PushTokenApi {
  int upsertCalls = 0;
  String? lastDeviceId;
  String? lastToken;
  String? lastPlatform;
  String? lastAppVersion;

  @override
  Future<Map<String, dynamic>?> fetchDevice(String deviceId) async {
    return lastDeviceId == deviceId
        ? {
            'device_id': deviceId,
            'platform': lastPlatform,
            'push_token': lastToken,
          }
        : null;
  }

  @override
  Future<void> removeDevice(String deviceId, {required String? userId}) async {
    lastDeviceId = deviceId;
  }

  @override
  Future<void> upsertToken({
    required String deviceId,
    required String token,
    required String platform,
    required String appVersion,
  }) async {
    upsertCalls += 1;
    lastDeviceId = deviceId;
    lastToken = token;
    lastPlatform = platform;
    lastAppVersion = appVersion;
  }
}

class FakeAuthAdapter implements AuthAdapter {
  @override
  Session? currentSession;

  @override
  User? currentUser;
}
