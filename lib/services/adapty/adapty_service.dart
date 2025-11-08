import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:duru_notes/core/config/environment_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:flutter/foundation.dart';

/// Service to handle deferred Adapty initialization after first frame
/// CRITICAL: Adapty triggers StoreKit transaction enumeration which blocks main thread
/// Must be initialized AFTER first frame to prevent black screen freeze
class AdaptyService {
  AdaptyService({
    required EnvironmentConfig environment,
    required AppLogger logger,
    required AnalyticsService analytics,
  })  : _environment = environment,
        _logger = logger,
        _analytics = analytics;

  final EnvironmentConfig _environment;
  final AppLogger _logger;
  final AnalyticsService _analytics;

  static bool _adaptyActivated = false;
  bool _isInitializing = false;

  /// Initialize Adapty after first frame renders
  /// This prevents StoreKit from blocking the main thread during app startup
  Future<bool> initializeAdapty() async {
    // Skip if already activated or currently initializing
    if (_adaptyActivated) {
      debugPrint('🛒 [Adapty] Already activated - skipping');
      return true;
    }

    if (_isInitializing) {
      debugPrint('🛒 [Adapty] Already initializing - skipping duplicate call');
      return false;
    }

    final adaptyKey = _environment.adaptyPublicApiKey;
    if (adaptyKey == null || adaptyKey.isEmpty) {
      debugPrint('🛒 [Adapty] No API key - skipping initialization');
      return false;
    }

    _isInitializing = true;

    try {
      debugPrint('🛒 [Adapty] Setting log level');
      await Adapty().setLogLevel(
        _environment.debugMode ? AdaptyLogLevel.warn : AdaptyLogLevel.error,
      );

      debugPrint('🛒 [Adapty] Activating (post-first-frame)...');
      await Adapty()
          .activate(
            configuration: AdaptyConfiguration(apiKey: adaptyKey)
              ..withActivateUI(true)
              ..withAppleIdfaCollectionDisabled(true)
              ..withIpAddressCollectionDisabled(true),
          )
          .timeout(
            const Duration(seconds: 10), // Longer timeout for post-frame init
            onTimeout: () {
              throw TimeoutException(
                'Adapty activation timeout after 10 seconds',
              );
            },
          );

      _adaptyActivated = true;
      debugPrint('🛒 [Adapty] Initialized successfully (post-first-frame)');
      _logger.info('Adapty initialized successfully after first frame');

      // Track successful initialization
      _analytics.event(
        'adapty_initialized',
        properties: {
          'initialization_timing': 'post_first_frame',
          'environment': _environment.environment.name,
        },
      );

      return true;
    } catch (error, stack) {
      // Handle "activate once" error (error 3005)
      if (error.toString().contains('3005') ||
          error.toString().contains('activateOnceError') ||
          error.toString().contains('can only be activated once')) {
        _logger.warning(
          'Adapty already activated (error 3005) - continuing',
        );

        _analytics.event(
          'adapty_initialized',
          properties: {
            'adapty_already_activated': true,
            'error_code': '3005',
            'initialization_timing': 'post_first_frame',
          },
        );

        _adaptyActivated = true;
        return true;
      }

      // Log other errors but don't crash the app
      _logger.warning(
        'Adapty initialization failed (post-first-frame)',
        data: {
          'error': error.toString(),
          'is_timeout': error is TimeoutException,
          'stack_trace': stack.toString(),
        },
      );

      debugPrint('🛒 [Adapty] Initialization failed: $error');

      // Track failure
      _analytics.event(
        'adapty_initialization_failed',
        properties: {
          'error': error.toString(),
          'is_timeout': error is TimeoutException,
          'initialization_timing': 'post_first_frame',
        },
      );

      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Check if Adapty is activated
  bool get isActivated => _adaptyActivated;
}
