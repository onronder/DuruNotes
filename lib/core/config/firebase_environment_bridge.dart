import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Bridge between environment configuration and Firebase options
/// Provides Firebase configuration from loaded environment variables
class FirebaseEnvironmentBridge {
  static Map<String, String> _environmentVariables = <String, String>{};

  /// Updates the environment variables from the loaded configuration
  static void updateEnvironment(Map<String, String> environment) {
    _environmentVariables = Map.from(environment);
  }

  /// Gets environment variable value with fallback to String.fromEnvironment
  static String getEnvironmentVariable(String key, {String defaultValue = ''}) {
    // First try from loaded environment variables (dotenv)
    final value = _environmentVariables[key];
    if (value != null && value.isNotEmpty) {
      return value;
    }

    // Fallback to compile-time defines - we need to handle each key separately
    // since String.fromEnvironment requires compile-time constants
    switch (key) {
      case 'FIREBASE_ANDROID_API_KEY':
        return const String.fromEnvironment(
          'FIREBASE_ANDROID_API_KEY',
          defaultValue: '',
        );
      case 'FIREBASE_IOS_API_KEY':
        return const String.fromEnvironment(
          'FIREBASE_IOS_API_KEY',
          defaultValue: '',
        );
      case 'FIREBASE_PROJECT_ID':
        return const String.fromEnvironment(
          'FIREBASE_PROJECT_ID',
          defaultValue: 'durunotes',
        );
      case 'FIREBASE_MESSAGING_SENDER_ID':
        return const String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
          defaultValue: '259019439896',
        );
      case 'FIREBASE_ANDROID_APP_ID':
        return const String.fromEnvironment(
          'FIREBASE_ANDROID_APP_ID',
          defaultValue: '1:259019439896:android:2ea0fc35a3cc360bbce86d',
        );
      case 'FIREBASE_IOS_APP_ID':
        return const String.fromEnvironment(
          'FIREBASE_IOS_APP_ID',
          defaultValue: '1:259019439896:ios:3ba3482d4245378dbce86d',
        );
      case 'FIREBASE_STORAGE_BUCKET':
        return const String.fromEnvironment(
          'FIREBASE_STORAGE_BUCKET',
          defaultValue: 'durunotes.firebasestorage.app',
        );
      case 'FIREBASE_IOS_BUNDLE_ID':
        return const String.fromEnvironment(
          'FIREBASE_IOS_BUNDLE_ID',
          defaultValue: 'com.fittechs.duruNotesApp',
        );
      default:
        return defaultValue;
    }
  }

  /// Gets Firebase options for the current platform using loaded environment
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase has not been configured for web');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _getAndroidOptions();
      case TargetPlatform.iOS:
        return _getIosOptions();
      case TargetPlatform.macOS:
        throw UnsupportedError('Firebase has not been configured for macOS');
      case TargetPlatform.windows:
        throw UnsupportedError('Firebase has not been configured for Windows');
      case TargetPlatform.linux:
        throw UnsupportedError('Firebase has not been configured for Linux');
      default:
        throw UnsupportedError('Platform not supported');
    }
  }

  static FirebaseOptions _getAndroidOptions() {
    final apiKey = getEnvironmentVariable('FIREBASE_ANDROID_API_KEY');
    final appId = getEnvironmentVariable(
      'FIREBASE_ANDROID_APP_ID',
      defaultValue: '1:259019439896:android:2ea0fc35a3cc360bbce86d',
    );
    final messagingSenderId = getEnvironmentVariable(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '259019439896',
    );
    final projectId = getEnvironmentVariable(
      'FIREBASE_PROJECT_ID',
      defaultValue: 'durunotes',
    );
    final storageBucket = getEnvironmentVariable(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: 'durunotes.firebasestorage.app',
    );

    if (apiKey.isEmpty) {
      throw StateError(
        'Firebase Android API key not configured. '
        'Please set FIREBASE_ANDROID_API_KEY in your environment file or as a dart-define.',
      );
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
    );
  }

  static FirebaseOptions _getIosOptions() {
    final apiKey = getEnvironmentVariable('FIREBASE_IOS_API_KEY');
    final appId = getEnvironmentVariable(
      'FIREBASE_IOS_APP_ID',
      defaultValue: '1:259019439896:ios:3ba3482d4245378dbce86d',
    );
    final messagingSenderId = getEnvironmentVariable(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '259019439896',
    );
    final projectId = getEnvironmentVariable(
      'FIREBASE_PROJECT_ID',
      defaultValue: 'durunotes',
    );
    final storageBucket = getEnvironmentVariable(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: 'durunotes.firebasestorage.app',
    );
    final iosBundleId = getEnvironmentVariable(
      'FIREBASE_IOS_BUNDLE_ID',
      defaultValue: 'com.fittechs.duruNotesApp',
    );

    if (apiKey.isEmpty) {
      throw StateError(
        'Firebase iOS API key not configured. '
        'Please set FIREBASE_IOS_API_KEY in your environment file or as a dart-define.',
      );
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
      iosBundleId: iosBundleId,
    );
  }
}
