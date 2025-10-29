import 'dart:async';

/// Provides lightweight scoped tracing using Dart zones.
///
/// The tracing helper is intentionally minimal so it can be used across
/// repositories and UI flows without introducing heavier dependencies.
class TraceContext {
  TraceContext._();

  static const String _noteSaveKey = 'trace.note.save';

  /// Runs [action] inside a zone that carries the provided note save [traceId].
  static Future<T> runWithNoteSaveTrace<T>(
    String traceId,
    Future<T> Function() action,
  ) {
    return runZoned(action, zoneValues: {_noteSaveKey: traceId});
  }

  /// Returns the current note save trace identifier, if one is set.
  static String? get currentNoteSaveTrace {
    final value = Zone.current[_noteSaveKey];
    return value is String && value.isNotEmpty ? value : null;
  }
}
