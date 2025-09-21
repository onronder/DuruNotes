import 'dart:async';
import 'dart:io';

import 'package:duru_notes/core/monitoring/app_logger.dart';
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
  PushNotificationService({SupabaseClient? client, AppLogger? logger})
      : _client = client ?? Supabase.instance.client,
        _logger = logger ?? LoggerFactory.instance;

  final SupabaseClient _client;
  final AppLogger _logger;

  // Firebase Messaging instance
  FirebaseMessaging? _messaging;

  // Stream subscription for token refresh
  StreamSubscription<String>? _tokenRefreshSubscription;

  // Store device ID to ensure consistency
  String? _deviceId;

  /// Initialize the push notification service
  Future<void> initialize() async {
    try {
      _messaging = FirebaseMessaging.instance;

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
    if (_messaging == null) {
      throw StateError('Push notification service not initialized');
    }

    final settings = await _messaging!.requestPermission();

    _logger.info(
      'Notification permission status: ${settings.authorizationStatus}',
    );

    return settings;
  }

  /// Check current notification permission status
  Future<NotificationSettings> checkPermissionStatus() async {
    if (_messaging == null) {
      throw StateError('Push notification service not initialized');
    }

    return _messaging!.getNotificationSettings();
  }

  /// Register device for push notifications and sync with backend
  Future<PushTokenResult> registerWithBackend() async {
    try {
      // Check if user is authenticated
      final user = _client.auth.currentUser;
      if (user == null) {
        return const PushTokenResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      // Check permission status
      final settings = await checkPermissionStatus();

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        // Request permission if not authorized
        final newSettings = await requestPermission();

        if (newSettings.authorizationStatus != AuthorizationStatus.authorized) {
          return PushTokenResult(
            success: false,
            error: 'Notification permission denied',
            permissionStatus: newSettings.authorizationStatus,
          );
        }
      }

      // Get FCM token
      final token = await _getToken();

      if (token == null) {
        return const PushTokenResult(
          success: false,
          error: 'Failed to get FCM token',
        );
      }

      // Get device metadata
      final metadata = await _getDeviceMetadata();

      // Send token to backend
      await _syncTokenWithBackend(
        token: token,
        platform: metadata['platform']!,
        appVersion: metadata['app_version']!,
      );

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
    if (_messaging == null) return null;

    try {
      // On iOS, we need to get APNs token first for physical devices
      if (Platform.isIOS && !kIsWeb) {
        // Try to get APNs token with retries
        String? apnsToken;
        int retries = 0;
        const maxRetries = 5;
        const retryDelay = Duration(seconds: 2);

        while (apnsToken == null && retries < maxRetries) {
          apnsToken = await _messaging!.getAPNSToken();
          if (apnsToken == null) {
            _logger.warning(
                'APNs token not available yet, attempt ${retries + 1}/$maxRetries');
            if (retries < maxRetries - 1) {
              await Future.delayed(retryDelay);
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

      final token = await _messaging!.getToken();
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

    if (_messaging == null) return;

    _tokenRefreshSubscription = _messaging!.onTokenRefresh.listen(
      (newToken) async {
        _logger.info('FCM token refreshed');

        // Check if user is still authenticated
        final user = _client.auth.currentUser;
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
      onError: (error) {
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
    if (_deviceId == null) {
      throw StateError('Device ID not available');
    }

    try {
      // Call Supabase RPC function to upsert device token
      await _client.rpc(
        'user_devices_upsert',
        params: {
          '_device_id': _deviceId,
          '_push_token': token,
          '_platform': platform,
          '_app_version': appVersion,
        },
      );

      _logger.info('Token synced with backend successfully');
    } catch (e) {
      _logger.error('Failed to sync token with backend: $e');
      rethrow;
    }
  }

  /// Get or create a unique device ID
  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
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

    final hex =
        random.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

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
      // Delete the device record for this user
      await _client
          .from('user_devices')
          .delete()
          .eq('device_id', _deviceId!)
          .eq('user_id', _client.auth.currentUser?.id ?? '');

      _logger.info('Token removed from backend');
    } catch (e) {
      _logger.error('Failed to remove token from backend: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    _tokenRefreshSubscription?.cancel();
  }
}
