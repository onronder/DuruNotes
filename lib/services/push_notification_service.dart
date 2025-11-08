import 'dart:async';
import 'dart:io';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a push token registration attempt
class PushTokenResult {
  const PushTokenResult({
    required this.success,
    this.token,
    this.error,
    this.permissionStatus,
  });

  final bool success;
  final String? token;
  final String? error;
  final AuthorizationStatus? permissionStatus;
}

/// Service for managing push notifications and FCM tokens
class PushNotificationService {
  PushNotificationService({
    required AppLogger logger,
    SupabaseClient? client,
    PushMessagingClient? messagingClient,
    PushTokenApi? tokenApi,
    AuthAdapter? authAdapter,
    Future<SharedPreferences> Function()? sharedPreferencesLoader,
    Future<bool?> Function()? physicalDeviceResolver,
  }) : _logger = logger,
       _tokenApi =
           tokenApi ?? SupabasePushTokenApi(client ?? Supabase.instance.client),
       _auth =
           authAdapter ??
           SupabaseAuthAdapter(client ?? Supabase.instance.client),
       _sharedPreferencesLoader =
           sharedPreferencesLoader ?? SharedPreferences.getInstance,
       _physicalDeviceResolver = physicalDeviceResolver,
       _messaging = messagingClient;

  final AppLogger _logger;
  final PushTokenApi _tokenApi;
  final AuthAdapter _auth;
  final Future<SharedPreferences> Function() _sharedPreferencesLoader;
  final Future<bool?> Function()? _physicalDeviceResolver;

  // Messaging client
  PushMessagingClient? _messaging;

  // Stream subscription for token refresh
  StreamSubscription<String>? _tokenRefreshSubscription;

  // Store device ID to ensure consistency
  String? _deviceId;
  bool? _isPhysicalDevice;

  /// Initialize the push notification service
  Future<void> initialize() async {
    try {
      _messaging ??= FirebasePushMessagingClient(FirebaseMessaging.instance);

      try {
        final resolver = _physicalDeviceResolver;
        final resolvedPhysical = resolver != null ? await resolver() : null;

        if (resolvedPhysical != null) {
          _isPhysicalDevice = resolvedPhysical;
        } else {
          final deviceInfo = DeviceInfoPlugin();
          if (!kIsWeb && Platform.isIOS) {
            final ios = await deviceInfo.iosInfo;
            _isPhysicalDevice = ios.isPhysicalDevice;
          } else if (!kIsWeb && Platform.isAndroid) {
            final android = await deviceInfo.androidInfo;
            _isPhysicalDevice = android.isPhysicalDevice;
          } else {
            _isPhysicalDevice = true;
          }
        }
        _logger.debug(
          'Push notification device details',
          data: {
            'platform': Platform.isIOS
                ? 'ios'
                : Platform.isAndroid
                ? 'android'
                : Platform.operatingSystem,
            'isPhysicalDevice': _isPhysicalDevice,
          },
        );
      } catch (deviceError, stack) {
        _logger.warning(
          'Unable to determine physical device status for push notifications',
          data: {
            'error': deviceError.toString(),
            'stackTrace': stack.toString(),
          },
        );
        _isPhysicalDevice ??= true;
      }

      // Generate or retrieve device ID
      _deviceId = await _getOrCreateDeviceId();

      _logger.info(
        'Push notification service initialized with device ID: $_deviceId',
      );
    } catch (e) {
      _logger.error('Failed to initialize push notification service: $e');
    }
  }

  /// Request notification permissions from the user
  Future<NotificationSettings> requestPermission() async {
    final messaging = _messaging;
    if (messaging == null) {
      throw StateError('Push notification service not initialized');
    }

    final settings = await messaging.requestPermission();

    _logger.info(
      'Notification permission status: ${settings.authorizationStatus}',
    );

    return settings;
  }

  /// Check current notification permission status
  Future<NotificationSettings> checkPermissionStatus() async {
    final messaging = _messaging;
    if (messaging == null) {
      throw StateError('Push notification service not initialized');
    }

    return messaging.getNotificationSettings();
  }

  /// Register device for push notifications and sync with backend
  Future<PushTokenResult> registerWithBackend() async {
    try {
      // Check if user is authenticated
      final user = _auth.currentUser;
      if (user == null) {
        return const PushTokenResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      // Check permission status
      final settings = await checkPermissionStatus();

      debugPrint(
        '🔔 Initial permission status: ${settings.authorizationStatus}',
      );
      debugPrint('🔔 Alert setting: ${settings.alert}');
      debugPrint('🔔 Badge setting: ${settings.badge}');
      debugPrint('🔔 Sound setting: ${settings.sound}');

      // Check if we need to request permission
      // Accept both 'authorized' and 'provisional' as valid states
      final isPermissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!isPermissionGranted) {
        debugPrint('🔔 Permission not granted yet. Requesting permission...');

        // Request permission if not authorized
        final newSettings = await requestPermission();

        debugPrint(
          '🔔 Permission after request: ${newSettings.authorizationStatus}',
        );
        debugPrint(
          '🔔 Alert: ${newSettings.alert}, Badge: ${newSettings.badge}, Sound: ${newSettings.sound}',
        );

        // Accept both 'authorized' and 'provisional' as success
        // Only fail if explicitly denied or permanently denied
        final isGranted =
            newSettings.authorizationStatus == AuthorizationStatus.authorized ||
            newSettings.authorizationStatus == AuthorizationStatus.provisional;

        final isDenied =
            newSettings.authorizationStatus == AuthorizationStatus.denied;

        if (isDenied) {
          // Hard fail only on explicit denial
          debugPrint(
            '❌ Permission explicitly denied. Status: ${newSettings.authorizationStatus}',
          );
          _logger.error(
            '❌ Permission explicitly denied. Status: ${newSettings.authorizationStatus}',
          );
          return PushTokenResult(
            success: false,
            error:
                'Notification permission denied (status: ${newSettings.authorizationStatus})',
            permissionStatus: newSettings.authorizationStatus,
          );
        }

        if (!isGranted) {
          // notDetermined or other states - log but continue to try getting token
          debugPrint(
            '⚠️  Permission not yet determined. Status: ${newSettings.authorizationStatus}',
          );
          debugPrint(
            '🔔 Attempting to get token anyway (may work on some platforms)...',
          );
          _logger.warning(
            'Notification permission not determined, attempting token retrieval',
            data: {'status': newSettings.authorizationStatus.toString()},
          );
        } else {
          debugPrint(
            '✅ Permission granted! Status: ${newSettings.authorizationStatus}',
          );
        }
      } else {
        debugPrint(
          '✅ Permission already granted: ${settings.authorizationStatus}',
        );
      }

      final runningOnUnsupportedSimulator =
          !kIsWeb && Platform.isIOS && (_isPhysicalDevice == false);

      if (runningOnUnsupportedSimulator) {
        const simMessage =
            'FCM tokens are not available on the iOS simulator. Please test on a physical device.';
        debugPrint('ℹ️ $simMessage');
        _logger.warning(simMessage);
        return PushTokenResult(
          success: false,
          error: simMessage,
          permissionStatus: settings.authorizationStatus,
        );
      }

      // Get FCM token
      debugPrint('🔔 Attempting to get FCM token...');
      final token = await _getToken();

      if (token == null) {
        const genericError = 'Failed to get FCM token';
        debugPrint('❌ $genericError');
        _logger.error(genericError);
        return const PushTokenResult(
          success: false,
          error: 'Failed to get FCM token',
        );
      }

      debugPrint('✅ Got FCM token: ${token.substring(0, 30)}...');

      // Get device metadata
      debugPrint('📱 Getting device metadata...');
      final metadata = await _getDeviceMetadata();
      debugPrint(
        '📱 Platform: ${metadata['platform']}, App version: ${metadata['app_version']}',
      );

      // Send token to backend
      debugPrint('💾 Syncing token with backend...');
      await _syncTokenWithBackend(
        token: token,
        platform: metadata['platform']!,
        appVersion: metadata['app_version']!,
      );
      debugPrint('✅ Token sync completed');

      // Set up token refresh listener
      _setupTokenRefreshListener();

      _logger.info('Successfully registered push token with backend');

      return PushTokenResult(
        success: true,
        token: token,
        permissionStatus: settings.authorizationStatus,
      );
    } catch (e) {
      _logger.error('Failed to register push token: $e');
      return PushTokenResult(success: false, error: e.toString());
    }
  }

  /// Get FCM token
  Future<String?> _getToken() async {
    final messaging = _messaging;
    if (messaging == null) return null;

    try {
      // On iOS, we need to get APNs token first for physical devices
      if (Platform.isIOS && !kIsWeb) {
        // Try to get APNs token with retries
        String? apnsToken;
        int retries = 0;
        const maxRetries = 5;
        const retryDelay = Duration(seconds: 2);

        while (apnsToken == null && retries < maxRetries) {
          apnsToken = await messaging.getAPNSToken();
          if (apnsToken == null) {
            _logger.warning(
              'APNs token not available yet, attempt ${retries + 1}/$maxRetries',
            );
            if (retries < maxRetries - 1) {
              await Future<void>.delayed(retryDelay);
            }
            retries++;
          }
        }

        if (apnsToken == null) {
          _logger.error('Failed to get APNs token after $maxRetries attempts');
          // On simulator or if APNs is not configured, we can still try to get FCM token
          // but it might fail
        } else {
          _logger.info('APNs token retrieved successfully');
        }
      }

      final token = await messaging.getToken();
      if (token != null) {
        _logger.info('Retrieved FCM token: ${token.substring(0, 20)}...');
      }
      return token;
    } catch (e) {
      _logger.error('Failed to get FCM token: $e');
      return null;
    }
  }

  /// Set up listener for token refresh
  void _setupTokenRefreshListener() {
    // Cancel existing subscription if any
    _tokenRefreshSubscription?.cancel();

    final messaging = _messaging;
    if (messaging == null) return;

    _tokenRefreshSubscription = messaging.onTokenRefresh.listen(
      (newToken) async {
        _logger.info('FCM token refreshed');

        // Check if user is still authenticated
        final user = _auth.currentUser;
        if (user == null) {
          _logger.warning(
            'Token refreshed but user not authenticated, skipping sync',
          );
          return;
        }

        try {
          final metadata = await _getDeviceMetadata();
          await _syncTokenWithBackend(
            token: newToken,
            platform: metadata['platform']!,
            appVersion: metadata['app_version']!,
          );
          _logger.info('Successfully synced refreshed token with backend');
        } catch (e) {
          _logger.error('Failed to sync refreshed token: $e');
        }
      },
      onError: (Object error) {
        _logger.error('Token refresh stream error: $error');
      },
    );
  }

  /// Sync token with Supabase backend
  Future<void> _syncTokenWithBackend({
    required String token,
    required String platform,
    required String appVersion,
  }) async {
    debugPrint('🔐 _syncTokenWithBackend called');

    if (_deviceId == null) {
      debugPrint('❌ Device ID is null!');
      throw StateError('Device ID not available');
    }

    debugPrint('📱 Device ID: $_deviceId');

    try {
      // CRITICAL: Verify auth status before calling RPC
      final session = _auth.currentSession;
      final user = _auth.currentUser;

      debugPrint('🔐 Auth Status Check:');
      debugPrint('  User ID: ${user?.id}');
      debugPrint('  User Email: ${user?.email}');
      debugPrint('  Session exists: ${session != null}');
      debugPrint('  Access token exists: ${session?.accessToken != null}');

      if (session != null && session.expiresAt != null) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final secondsUntilExpiry = session.expiresAt! - now;
        debugPrint('  Token expires in: ${secondsUntilExpiry}s');

        if (secondsUntilExpiry < 0) {
          debugPrint('  ❌ TOKEN EXPIRED!');
          throw StateError('JWT token expired. Please re-authenticate.');
        }
      }

      if (user == null) {
        debugPrint('  ❌ NO USER FOUND!');
        throw StateError('User not authenticated');
      }

      // Log what we're about to send (for debugging)
      debugPrint('📤 Calling user_devices_upsert RPC with:');
      debugPrint('  device_id: $_deviceId');
      debugPrint('  push_token: ${token.substring(0, 20)}...');
      debugPrint('  platform: $platform');
      debugPrint('  app_version: $appVersion');
      debugPrint('  user_id (from auth): ${user.id}');

      // Call Supabase RPC function to upsert device token
      debugPrint('🚀 Making RPC call...');
      await _tokenApi.upsertToken(
        deviceId: _deviceId!,
        token: token,
        platform: platform,
        appVersion: appVersion,
      );

      debugPrint('✅ RPC call succeeded');
      _logger.info('Token synced with backend successfully');

      // Verify the insert worked by querying the database
      debugPrint('🔍 Verifying token in database...');
      try {
        final checkResult = await _tokenApi.fetchDevice(_deviceId!);

        debugPrint('🔍 Query result: $checkResult');

        if (checkResult != null) {
          debugPrint('✅ Verified: Token exists in database');
          debugPrint('   Device ID: ${checkResult['device_id']}');
          debugPrint('   Platform: ${checkResult['platform']}');
          _logger.info('✅ Verified: Token exists in database');
        } else {
          debugPrint('⚠️  RPC succeeded but token not found in database!');
          _logger.error('⚠️  RPC succeeded but token not found in database!');
        }
      } catch (e) {
        debugPrint('⚠️  Could not verify token in database: $e');
        _logger.warning('Could not verify token in database: $e');
      }
    } catch (e, stack) {
      debugPrint('❌ Failed to sync token with backend: $e');
      debugPrint('Stack trace: $stack');
      _logger.error('❌ Failed to sync token with backend: $e');
      _logger.error('Stack trace: $stack');
      rethrow;
    }
  }

  /// Get or create a unique device ID
  Future<String> _getOrCreateDeviceId() async {
    final prefs = await _sharedPreferencesLoader();
    const key = 'device_id';

    var deviceId = prefs.getString(key);

    if (deviceId == null) {
      // Generate a new UUID for this device
      deviceId = _generateUuid();
      await prefs.setString(key, deviceId);
      _logger.info('Generated new device ID: $deviceId');
    }

    return deviceId;
  }

  /// Generate a UUID v4
  String _generateUuid() {
    // Simple UUID v4 generator
    final random = List<int>.generate(
      16,
      (i) => DateTime.now().millisecondsSinceEpoch + i,
    );

    // Set version (4) and variant bits
    random[6] = (random[6] & 0x0f) | 0x40;
    random[8] = (random[8] & 0x3f) | 0x80;

    final hex = random
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Get device metadata
  Future<Map<String, String>> _getDeviceMetadata() async {
    var platform = 'unknown';
    var appVersion = '1.0.0';

    if (Platform.isAndroid) {
      platform = 'android';
    } else if (Platform.isIOS) {
      platform = 'ios';
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      _logger.warning('Failed to get package info: $e');
    }

    return {'platform': platform, 'app_version': appVersion};
  }

  /// Remove token from backend (e.g., on logout)
  Future<void> removeTokenFromBackend() async {
    if (_deviceId == null) {
      _logger.warning('No device ID available, cannot remove token');
      return;
    }

    try {
      await _tokenApi.removeDevice(_deviceId!, userId: _auth.currentUser?.id);

      _logger.info('Token removed from backend');
    } catch (e) {
      _logger.error('Failed to remove token from backend: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    _tokenRefreshSubscription?.cancel();
  }

  @visibleForTesting
  void debugSetOverrides({
    String? deviceId,
    bool? isPhysicalDevice,
    PushMessagingClient? messagingClient,
  }) {
    _deviceId = deviceId ?? _deviceId;
    _isPhysicalDevice = isPhysicalDevice ?? _isPhysicalDevice;
    if (messagingClient != null) {
      _messaging = messagingClient;
    }
  }
}

/// Lightweight adapter so we can mock FirebaseMessaging in tests.
abstract class PushMessagingClient {
  Future<NotificationSettings> requestPermission();
  Future<NotificationSettings> getNotificationSettings();
  Future<String?> getToken();
  Future<String?> getAPNSToken();
  Stream<String> get onTokenRefresh;
}

class FirebasePushMessagingClient implements PushMessagingClient {
  FirebasePushMessagingClient(this._delegate);
  final FirebaseMessaging _delegate;

  @override
  Future<String?> getAPNSToken() => _delegate.getAPNSToken();

  @override
  Future<NotificationSettings> getNotificationSettings() =>
      _delegate.getNotificationSettings();

  @override
  Future<String?> getToken() => _delegate.getToken();

  @override
  Stream<String> get onTokenRefresh => _delegate.onTokenRefresh;

  @override
  Future<NotificationSettings> requestPermission() =>
      _delegate.requestPermission();
}

abstract class PushTokenApi {
  Future<void> upsertToken({
    required String deviceId,
    required String token,
    required String platform,
    required String appVersion,
  });

  Future<Map<String, dynamic>?> fetchDevice(String deviceId);

  Future<void> removeDevice(String deviceId, {required String? userId});
}

class SupabasePushTokenApi implements PushTokenApi {
  SupabasePushTokenApi(this._client);
  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>?> fetchDevice(String deviceId) {
    return _client
        .from('user_devices')
        .select('device_id, platform, push_token')
        .eq('device_id', deviceId)
        .maybeSingle();
  }

  @override
  Future<void> removeDevice(String deviceId, {required String? userId}) {
    return _client
        .from('user_devices')
        .delete()
        .eq('device_id', deviceId)
        .eq('user_id', userId ?? '');
  }

  @override
  Future<void> upsertToken({
    required String deviceId,
    required String token,
    required String platform,
    required String appVersion,
  }) {
    return _client.rpc<void>(
      'user_devices_upsert',
      params: {
        '_device_id': deviceId,
        '_push_token': token,
        '_platform': platform,
        '_app_version': appVersion,
      },
    );
  }
}

abstract class AuthAdapter {
  User? get currentUser;
  Session? get currentSession;
}

class SupabaseAuthAdapter implements AuthAdapter {
  SupabaseAuthAdapter(this._client);
  final SupabaseClient _client;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Session? get currentSession => _client.auth.currentSession;
}
