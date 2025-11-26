import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// BLACK SCREEN FIX: Window diagnostics for iOS
class WindowDiagnostics {
  static const MethodChannel _channel = MethodChannel(
    'com.fittechs.durunotes/window_diagnostics',
  );

  /// Get and print iOS window state diagnostics
  static Future<void> printWindowState() async {
    if (!Platform.isIOS) {
      debugPrint('[WindowDiagnostics] Skipping - not iOS');
      return;
    }

    try {
      debugPrint('[WindowDiagnostics] ========== iOS WINDOW STATE ==========');

      final Map<dynamic, dynamic> state = await _channel.invokeMethod(
        'getWindowState',
      );

      // Window existence
      final windowExists = state['window_exists'] ?? false;
      debugPrint('[WindowDiagnostics] Window exists: $windowExists');

      if (!windowExists) {
        debugPrint('[WindowDiagnostics] ❌ CRITICAL: Window does not exist!');
        debugPrint(
          '[WindowDiagnostics] ========================================',
        );
        return;
      }

      // Window properties
      debugPrint(
        '[WindowDiagnostics] Window isKeyWindow: ${state['is_key_window']}',
      );
      debugPrint('[WindowDiagnostics] Window isHidden: ${state['is_hidden']}');
      debugPrint('[WindowDiagnostics] Window alpha: ${state['alpha']}');
      debugPrint(
        '[WindowDiagnostics] Window size: ${state['frame_width']} x ${state['frame_height']}',
      );
      debugPrint(
        '[WindowDiagnostics] Window backgroundColor: ${state['background_color']}',
      );

      // Root view controller
      final rootVcExists = state['root_vc_exists'] ?? true;
      if (!rootVcExists) {
        debugPrint(
          '[WindowDiagnostics] ❌ CRITICAL: Root view controller does not exist!',
        );
        debugPrint(
          '[WindowDiagnostics] ========================================',
        );
        return;
      }

      debugPrint('[WindowDiagnostics] RootVC type: ${state['root_vc_type']}');
      debugPrint(
        '[WindowDiagnostics] RootVC view alpha: ${state['root_vc_view_alpha']}',
      );
      debugPrint(
        '[WindowDiagnostics] RootVC view hidden: ${state['root_vc_view_hidden']}',
      );
      debugPrint(
        '[WindowDiagnostics] RootVC view size: ${state['root_vc_view_frame_width']} x ${state['root_vc_view_frame_height']}',
      );

      // Flutter view controller
      final isFlutterVC = state['is_flutter_vc'] ?? false;
      debugPrint('[WindowDiagnostics] Is FlutterViewController: $isFlutterVC');

      if (!isFlutterVC) {
        debugPrint(
          '[WindowDiagnostics] ❌ CRITICAL: Root VC is NOT FlutterViewController!',
        );
        debugPrint(
          '[WindowDiagnostics] ========================================',
        );
        return;
      }

      // Flutter subviews
      final subviewsCount = state['flutter_subviews_count'] ?? 0;
      debugPrint('[WindowDiagnostics] Flutter subviews count: $subviewsCount');

      if (subviewsCount == 0) {
        debugPrint(
          '[WindowDiagnostics] ⚠️  WARNING: No Flutter subviews - Flutter view not attached!',
        );
      }

      final subviews = state['flutter_subviews'] as List<dynamic>? ?? [];
      for (final subview in subviews) {
        final index = subview['index'];
        final type = subview['type'];
        final alpha = subview['alpha'];
        final hidden = subview['hidden'];
        final width = subview['width'];
        final height = subview['height'];
        debugPrint(
          '[WindowDiagnostics]   Subview[$index]: $type | alpha:$alpha hidden:$hidden size:${width}x$height',
        );
      }

      debugPrint(
        '[WindowDiagnostics] ========================================',
      );

      // Analyze for black screen causes
      _analyzeForBlackScreen(state);
    } catch (e, stack) {
      debugPrint('[WindowDiagnostics] ❌ Error getting window state: $e');
      debugPrint('[WindowDiagnostics] Stack: $stack');
    }
  }

  /// Log iOS platform state at a specific point in execution
  /// This helps identify where exactly the platform freezes
  static Future<void> logPlatformState(String context) async {
    if (!Platform.isIOS) {
      return;
    }

    try {
      debugPrint('📊 [PlatformState] $context - Calling native...');
      await _channel.invokeMethod('logPlatformState', {'context': context});
      debugPrint('📊 [PlatformState] $context - Native call completed');
    } catch (e) {
      debugPrint('📊 [PlatformState] $context - ERROR: $e');
    }
  }

  /// Analyze the window state for potential black screen causes
  static void _analyzeForBlackScreen(Map<dynamic, dynamic> state) {
    debugPrint(
      '[WindowDiagnostics] ========== BLACK SCREEN ANALYSIS ==========',
    );

    final issues = <String>[];

    // Check for common issues
    if (state['is_hidden'] == true) {
      issues.add('Window is HIDDEN');
    }

    if ((state['alpha'] as num?) == 0.0) {
      issues.add('Window alpha is 0.0 (transparent)');
    }

    if (state['root_vc_view_hidden'] == true) {
      issues.add('Root view controller view is HIDDEN');
    }

    if ((state['root_vc_view_alpha'] as num?) == 0.0) {
      issues.add('Root view controller view alpha is 0.0');
    }

    if (state['is_flutter_vc'] == false) {
      issues.add('Root VC is NOT FlutterViewController');
    }

    if ((state['flutter_subviews_count'] as num?) == 0) {
      issues.add('Flutter view has NO subviews (not attached)');
    }

    if (issues.isEmpty) {
      debugPrint(
        '[WindowDiagnostics] ✅ No obvious iOS window/view issues detected',
      );
      debugPrint(
        '[WindowDiagnostics] 💡 Black screen may be caused by Flutter rendering or widget issues',
      );
    } else {
      debugPrint(
        '[WindowDiagnostics] ❌ Found ${issues.length} potential issue(s):',
      );
      for (var i = 0; i < issues.length; i++) {
        debugPrint('[WindowDiagnostics]   ${i + 1}. ${issues[i]}');
      }
    }

    debugPrint(
      '[WindowDiagnostics] ================================================',
    );
  }
}
