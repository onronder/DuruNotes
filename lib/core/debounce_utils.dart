import 'dart:async';
import 'package:flutter/scheduler.dart';

/// Debounce utilities for optimizing frequent updates
class DebounceUtils {
  DebounceUtils._();

  static final Map<String, Timer> _timers = {};
  static final Map<String, int> _frameCallbacks = {};

  /// Debounce a function call by specified duration
  static void debounce(
    String tag,
    Duration duration,
    void Function() callback,
  ) {
    _timers[tag]?.cancel();
    _timers[tag] = Timer(duration, () {
      callback();
      _timers.remove(tag);
    });
  }

  /// Throttle a function to run at most once per duration
  static void throttle(
    String tag,
    Duration duration,
    void Function() callback,
  ) {
    if (_timers.containsKey(tag)) return;

    callback();
    _timers[tag] = Timer(duration, () {
      _timers.remove(tag);
    });
  }

  /// Debounce to next animation frame for smooth UI updates
  static void debounceFrame(String tag, VoidCallback callback) {
    // Cancel existing frame callback if any
    final existingCallback = _frameCallbacks[tag];
    if (existingCallback != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(existingCallback);
    }

    // Schedule new frame callback
    _frameCallbacks[tag] = SchedulerBinding.instance.scheduleFrameCallback((_) {
      callback();
      _frameCallbacks.remove(tag);
    });
  }

  /// Cancel a debounced call
  static void cancel(String tag) {
    _timers[tag]?.cancel();
    _timers.remove(tag);

    final frameCallback = _frameCallbacks[tag];
    if (frameCallback != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(frameCallback);
      _frameCallbacks.remove(tag);
    }
  }

  /// Cancel all pending debounced calls
  static void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();

    for (final callback in _frameCallbacks.values) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(callback);
    }
    _frameCallbacks.clear();
  }
}

/// A debounced notifier that delays state updates
class DebouncedStateNotifier<T> {
  DebouncedStateNotifier({required this.delay, required this.onUpdate});
  final Duration delay;
  final void Function(T value) onUpdate;
  Timer? _timer;
  T? _pendingValue;

  void update(T value) {
    _pendingValue = value;
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (_pendingValue != null) {
        onUpdate(_pendingValue as T);
        _pendingValue = null;
      }
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}
