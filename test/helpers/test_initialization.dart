import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/security/security_initialization.dart';

/// Centralized test initialization
///
/// Call this in setUpAll() to properly initialize test environment:
/// - Flutter binding
/// - Supabase mock
/// - Feature flags
/// - Plugin channel handlers
class TestInitialization {
  static bool _baseInitialized = false;
  static bool _supabaseInitialized = false;
  static bool _securityInitialized = false;

  static const MethodChannel _sharedPreferencesChannel = MethodChannel(
    'plugins.flutter.io/shared_preferences',
  );
  static const MethodChannel _packageInfoChannel = MethodChannel(
    'dev.fluttercommunity.plus/package_info',
  );
  static const MethodChannel _secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  static final Map<String, String> _secureStorageData = {};

  /// Initialize test environment
  ///
  /// Safe to call multiple times - will only initialize once
  static Future<void> initialize({
    bool initializeSupabase = false,
    bool initializeSecurity = false,
    Map<String, bool>? featureFlags,
  }) async {
    // Initialize Flutter binding (fixes "Binding has not yet been initialized" errors)
    if (!_baseInitialized) {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Mock shared preferences channel
      _setupSharedPreferencesMock();

      // Configure feature flags for tests
      _setupFeatureFlags(featureFlags);

      _baseInitialized = true;
    } else if (featureFlags != null) {
      // Allow overriding flags even after base initialization
      _setupFeatureFlags(featureFlags);
    }

    if (initializeSupabase && !_supabaseInitialized) {
      await _initializeSupabaseMock();
    }

    if (initializeSecurity && !_securityInitialized) {
      await _initializeSecurityMocks();
      await SecurityInitialization.initialize(
        userId: 'test-security-user',
        sessionId: 'test-security-session',
        debugMode: true,
      );
      _securityInitialized = true;
    }
  }

  /// Reset initialization state (for testing)
  static void reset() {
    _baseInitialized = false;
    _supabaseInitialized = false;
    if (_securityInitialized) {
      SecurityInitialization.reset();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_packageInfoChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_secureStorageChannel, null);
      _secureStorageData.clear();
      _securityInitialized = false;
    }
  }

  /// Mock SharedPreferences plugin channel
  ///
  /// Returns empty values for all SharedPreferences operations
  static void _setupSharedPreferencesMock() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_sharedPreferencesChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'getAll') {
            return <String, dynamic>{}; // Empty preferences
          }
          return null;
        });
  }

  /// Initialize Supabase with mock/test configuration
  ///
  /// Uses fake URL and key that won't make real network requests
  static Future<void> _initializeSupabaseMock() async {
    try {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-anon-key-12345',
        // Disable automatic token refresh in tests
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
      _supabaseInitialized = true;
    } catch (e) {
      // Supabase already initialized, that's fine
      if (e.toString().contains('already initialized')) {
        _supabaseInitialized = true;
      } else {
        rethrow;
      }
    }
  }

  static Future<void> _initializeSecurityMocks() async {
    // Package info mock
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_packageInfoChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'getAll') {
            return {
              'appName': 'DuruNotes',
              'packageName': 'com.duru.notes.test',
              'version': '1.0.0-test',
              'buildNumber': '1',
              'buildSignature': 'test',
              'installerStore': 'test',
            };
          }
          return null;
        });

    // Secure storage mock
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (
          MethodCall methodCall,
        ) async {
          final arguments =
              (methodCall.arguments as Map?)?.cast<String, dynamic>() ?? {};
          switch (methodCall.method) {
            case 'write':
              _secureStorageData[arguments['key'] as String? ?? ''] =
                  arguments['value'] as String? ?? '';
              return null;
            case 'read':
              return _secureStorageData[arguments['key'] as String? ?? ''];
            case 'readAll':
              return _secureStorageData;
            case 'delete':
              _secureStorageData.remove(arguments['key'] as String? ?? '');
              return null;
            case 'deleteAll':
              _secureStorageData.clear();
              return null;
            case 'containsKey':
              return _secureStorageData.containsKey(
                arguments['key'] as String? ?? '',
              );
          }
          return null;
        });

    SecurityInitialization.reset();
  }

  /// Configure feature flags for tests
  ///
  /// Sets all Phase 1 flags to enabled by default
  static void _setupFeatureFlags(Map<String, bool>? customFlags) {
    final flags = FeatureFlags.instance;

    // Clear any existing overrides
    flags.clearOverrides();

    // Set default test flags (all Phase 1 features enabled)
    flags.setOverride('use_refactored_components', true);
    flags.setOverride('use_new_block_editor', true);
    flags.setOverride('use_unified_permission_manager', true);
    flags.setOverride('use_unified_reminders', true);

    // Apply custom flags if provided
    if (customFlags != null) {
      for (final entry in customFlags.entries) {
        flags.setOverride(entry.key, entry.value);
      }
    }
  }
}

/// Extension to make test initialization easier
extension TestSetup on Function {
  /// Wrap a test group with proper initialization
  ///
  /// Example:
  /// ```dart
  /// void main() {
  ///   TestInitialization.initialize();
  ///
  ///   group('My Tests', () {
  ///     test('my test', () {
  ///       // test code
  ///     });
  ///   });
  /// }
  /// ```
  static Future<void> withSetup(
    Future<void> Function() body, {
    bool initializeSupabase = false,
    bool initializeSecurity = false,
    Map<String, bool>? featureFlags,
  }) async {
    await TestInitialization.initialize(
      initializeSupabase: initializeSupabase,
      initializeSecurity: initializeSecurity,
      featureFlags: featureFlags,
    );
    await body();
  }
}
