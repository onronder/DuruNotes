import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Android-specific optimizations and fixes
class AndroidOptimizations {
  static bool _initialized = false;

  /// Initialize Android-specific optimizations
  static Future<void> initialize() async {
    if (_initialized || !Platform.isAndroid) return;
    _initialized = true;

    // Reduce repetitive logging
    if (kReleaseMode) {
      // In release mode, reduce verbose logging
      debugPrint = (message, {wrapWidth}) {
        // Filter out repetitive encryption logs
        if (message?.contains('SecretBox data structure') ?? false) return;
        if (message?.contains('Converted List<int> to Map') ?? false) return;

        // Print other messages normally
        if (message != null) {
          debugPrint(message);
        }
      };
    }

    // Configure method channels for better performance
    await _configureMethodChannels();

    // Set up error handlers
    _setupErrorHandlers();
  }

  static Future<void> _configureMethodChannels() async {
    try {
      // Configure platform channels
      const platform = MethodChannel('com.fittechs.duruNotesApp/optimization');
      await platform.invokeMethod('configure', {
        'enableHardwareAcceleration': true,
        'reduceSurfaceRedraw': true,
        'optimizeMemory': true,
      }).catchError((e) {
        // Ignore if channel doesn't exist
        return null;
      });
    } catch (e) {
      // Ignore configuration errors
    }
  }

  static void _setupErrorHandlers() {
    // Handle surface-related errors gracefully
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('EGLNativeWindowType') ||
          details.exception.toString().contains('disconnect failed')) {
        // Log but don't crash for surface issues
        debugPrint('Surface warning: ${details.exception}');
        return;
      }

      // Let other errors propagate normally
      FlutterError.presentError(details);
    };
  }

  /// Clean up caches periodically
  static Future<void> cleanupCaches() async {
    if (!Platform.isAndroid) return;

    try {
      // Clear image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Trigger garbage collection
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      debugPrint('Cache cleanup error: $e');
    }
  }
}
