import 'dart:io';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter/services.dart';

/// Contract for pushing quick capture payloads to platform widgets.
abstract class QuickCaptureWidgetSyncer {
  const QuickCaptureWidgetSyncer();

  /// Push the latest payload to the native widget layer.
  Future<void> sync({
    required String userId,
    required Map<String, dynamic> payload,
  });

  /// Clear any cached payloads on the native side.
  Future<void> clear();
}

/// No-op implementation used on unsupported platforms (Android, Web, tests).
class NoopQuickCaptureWidgetSyncer extends QuickCaptureWidgetSyncer {
  const NoopQuickCaptureWidgetSyncer();

  @override
  Future<void> clear() async {}

  @override
  Future<void> sync({
    required String userId,
    required Map<String, dynamic> payload,
  }) async {}
}

/// iOS implementation that talks to the WidgetKit extension via MethodChannel.
class IosQuickCaptureWidgetSyncer extends QuickCaptureWidgetSyncer {
  IosQuickCaptureWidgetSyncer({
    MethodChannel? channel,
    AppLogger? logger,
  })  : _channel = channel ?? const MethodChannel(_channelName),
        _logger = logger;

  static const String _channelName =
      'com.fittechs.durunotes/quick_capture_widget';
  final MethodChannel _channel;
  final AppLogger? _logger;

  @override
  Future<void> sync({
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod<void>('syncWidgetCache', {
        'userId': userId,
        'payload': payload,
      });
    } on PlatformException catch (error, stackTrace) {
      _logger?.error(
        'Failed to push quick capture payload to WidgetKit',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> clear() async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod<void>('clearWidgetCache');
    } on PlatformException catch (error, stackTrace) {
      _logger?.error(
        'Failed to clear quick capture widget cache',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
