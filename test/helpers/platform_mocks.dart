/* COMMENTED OUT - errors
 * This file has errors. Needs rewrite.
 */

/*
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Platform-specific mock setup for Flutter plugins
///
/// This class sets up all necessary platform channel mocks required
/// for testing Flutter applications that use native platform features.
///
/// Usage:
/// ```dart
/// setUpAll(() async {
///   PlatformMocks.setup();
/// });
/// ```
class PlatformMocks {
  /// Setup all platform mocks
  static void setup() {
    TestWidgetsFlutterBinding.ensureInitialized();

    _setupSharedPreferences();
    _setupPathProvider();
    _setupFlutterSecureStorage();
    _setupMethodChannels();
    _setupPermissionHandler();
    _setupConnectivity();
    _setupDeviceInfo();
    _setupPackageInfo();
    _setupLocalNotifications();
    _setupInAppPurchase();
  }

  /// Setup SharedPreferences mock with initial values
  static void _setupSharedPreferences() {
    SharedPreferences.setMockInitialValues(<String, dynamic>{
      'user_id': null,
      'theme_mode': 'system',
      'locale': 'en',
      'first_launch': true,
      'onboarding_completed': false,
      'last_sync': null,
      'encryption_enabled': false,
      'biometric_enabled': false,
      'analytics_enabled': true,
      'notification_enabled': true,
      'auto_sync_enabled': true,
      'sync_interval': 30,
      'default_folder_id': null,
      'sort_order': 'created_desc',
      'view_mode': 'list',
      'show_completed_tasks': true,
      'show_archived_notes': false,
      'quick_capture_enabled': false,
      'tutorial_completed': false,
      'premium_user': false,
      'subscription_expiry': null,
    });
  }

  /// Setup Path Provider mock for file system paths
  static void _setupPathProvider() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getTemporaryDirectory':
          return '/tmp/test/temp';
        case 'getApplicationDocumentsDirectory':
          return '/tmp/test/documents';
        case 'getApplicationSupportDirectory':
          return '/tmp/test/support';
        case 'getApplicationCacheDirectory':
          return '/tmp/test/cache';
        case 'getExternalStorageDirectory':
          return '/tmp/test/external';
        case 'getDownloadsDirectory':
          return '/tmp/test/downloads';
        default:
          return null;
      }
    });
  }

  /// Setup Flutter Secure Storage mock
  static void _setupFlutterSecureStorage() {
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final storage = <String, String>{};

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      final arguments = methodCall.arguments as Map<String, dynamic>;

      switch (methodCall.method) {
        case 'write':
          final key = arguments['key'] as String;
          final value = arguments['value'] as String;
          storage[key] = value;
          return null;
        case 'read':
          final key = arguments['key'] as String;
          return storage[key];
        case 'readAll':
          return storage;
        case 'delete':
          final key = arguments['key'] as String;
          storage.remove(key);
          return null;
        case 'deleteAll':
          storage.clear();
          return null;
        case 'containsKey':
          final key = arguments['key'] as String;
          return storage.containsKey(key);
        default:
          return null;
      }
    });
  }

  /// Setup generic method channels used by various plugins
  static void _setupMethodChannels() {
    // URL Launcher
    const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'canLaunch') return true;
      if (methodCall.method == 'launch') return true;
      return null;
    });

    // Share Plus
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'share') return null;
      if (methodCall.method == 'shareFiles') return null;
      return null;
    });

    // Image Picker
    const imagePickerChannel = MethodChannel('plugins.flutter.io/image_picker');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(imagePickerChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'pickImage') {
        return <String, dynamic>{
          'path': '/tmp/test/image.jpg',
          'width': 1920.0,
          'height': 1080.0,
        };
      }
      return null;
    });

    // File Picker
    const filePickerChannel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(filePickerChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'any') {
        return <String, dynamic>{
          'files': [
            {
              'path': '/tmp/test/file.pdf',
              'name': 'file.pdf',
              'size': 1024,
            }
          ]
        };
      }
      return null;
    });
  }

  /// Setup permission handler mock
  static void _setupPermissionHandler() {
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'checkPermissionStatus':
          return 1; // PermissionStatus.granted
        case 'requestPermissions':
          final permissions = methodCall.arguments as List;
          return Map.fromIterable(
            permissions,
            value: (_) => 1, // All permissions granted
          );
        case 'shouldShowRequestPermissionRationale':
          return false;
        case 'openAppSettings':
          return true;
        default:
          return null;
      }
    });
  }

  /// Setup connectivity mock
  static void _setupConnectivity() {
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'check') {
        return 'wifi'; // ConnectivityResult.wifi
      }
      return null;
    });
  }

  /// Setup device info mock
  static void _setupDeviceInfo() {
    const channel = MethodChannel('dev.fluttercommunity.plus/device_info');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getDeviceInfo') {
        return <String, dynamic>{
          'version': <String, dynamic>{
            'release': '14',
            'sdkInt': 33,
          },
          'brand': 'TestBrand',
          'device': 'TestDevice',
          'manufacturer': 'TestManufacturer',
          'model': 'TestModel',
          'product': 'TestProduct',
          'isPhysicalDevice': true,
        };
      }
      return null;
    });
  }

  /// Setup package info mock
  static void _setupPackageInfo() {
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'Duru Notes Test',
          'packageName': 'com.fittechs.durunotes.test',
          'version': '1.0.0',
          'buildNumber': '1',
        };
      }
      return null;
    });
  }

  /// Setup local notifications mock
  static void _setupLocalNotifications() {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'initialize':
          return true;
        case 'show':
          return null;
        case 'cancel':
          return null;
        case 'cancelAll':
          return null;
        case 'schedule':
          return null;
        case 'periodicallyShow':
          return null;
        case 'getNotificationAppLaunchDetails':
          return <String, dynamic>{
            'notificationLaunchedApp': false,
          };
        case 'pendingNotificationRequests':
          return <Map<String, dynamic>>[];
        default:
          return null;
      }
    });
  }

  /// Setup in-app purchase mock
  static void _setupInAppPurchase() {
    const channel = MethodChannel('plugins.flutter.io/in_app_purchase');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'isAvailable':
          return true;
        case 'queryProductDetails':
          return <String, dynamic>{
            'productDetails': [],
            'notFoundIDs': [],
          };
        case 'queryPurchaseDetails':
          return <String, dynamic>{
            'purchases': [],
          };
        case 'buyConsumable':
          return true;
        case 'buyNonConsumable':
          return true;
        case 'completePurchase':
          return null;
        case 'restorePurchases':
          return null;
        default:
          return null;
      }
    });
  }

  /// Reset all mock channels
  ///
  /// Call this in tearDownAll() if needed to clean up
  static void reset() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/image_picker'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('miguelruivo.flutter.plugins.filepicker'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter.baseflow.com/permissions/methods'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/connectivity'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/device_info'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/package_info'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dexterous.com/flutter/local_notifications'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/in_app_purchase'), null);
  }
}
*/
