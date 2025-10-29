import 'package:mockito/mockito.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';

/// Centralized mock configuration for tests
///
/// Provides dummy values for complex types that Mockito can't auto-generate.
/// Use this at the beginning of test files to prevent MissingDummyValueError.
///
/// Usage:
/// ```dart
/// @GenerateNiceMocks([
///   MockSpec<Ref>(),
///   // ... other mocks
/// ])
/// void main() {
///   setUpAll(() {
///     TestMockConfig.configureDummies();
///   });
///
///   // ... tests
/// }
/// ```
class TestMockConfig {
  static bool _configured = false;

  /// Configure dummy values for all common test types
  ///
  /// Call this once in setUpAll() at the start of your test file.
  /// Safe to call multiple times - will only configure once.
  static void configureDummies() {
    if (_configured) return;

    // AppLogger dummy
    provideDummy<AppLogger>(_DummyAppLogger());

    // AnalyticsService dummy
    provideDummy<AnalyticsService>(_DummyAnalyticsService());

    _configured = true;
  }

  /// Reset configuration state
  ///
  /// Only needed if you want to reconfigure dummies with different implementations.
  /// Normally you don't need to call this.
  static void reset() {
    _configured = false;
  }
}

/// Dummy AppLogger that does nothing
///
/// Used as a fallback when Mockito needs a dummy value but no mock is configured.
class _DummyAppLogger implements AppLogger {
  @override
  void debug(String message, {Map<String, dynamic>? data}) {}

  @override
  void info(String message, {Map<String, dynamic>? data}) {}

  @override
  void warning(String message, {Map<String, dynamic>? data}) {}

  @override
  void warn(String message, {Map<String, dynamic>? data}) {}

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {}

  void fatal(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {}

  @override
  void breadcrumb(String message, {Map<String, dynamic>? data}) {}

  @override
  Future<void> flush() async {}
}

/// Dummy AnalyticsService that does nothing
///
/// Used as a fallback when Mockito needs a dummy value but no mock is configured.
class _DummyAnalyticsService implements AnalyticsService {
  @override
  void startTiming(String eventName) {}

  @override
  void endTiming(String eventName, {Map<String, dynamic>? properties}) {}

  @override
  void featureUsed(String featureName, {Map<String, dynamic>? properties}) {}

  @override
  void trackError(
    String message, {
    String? context,
    Map<String, dynamic>? properties,
  }) {}

  @override
  void event(String name, {Map<String, dynamic>? properties}) {}

  @override
  void enable() {}

  @override
  void disable() {}

  @override
  bool get isEnabled => false;
}