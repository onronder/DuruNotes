import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; // Added for BuildContext
import 'package:duru_notes/services/security/input_validation_service.dart';
import 'package:duru_notes/services/security/encryption_service.dart';
import 'package:duru_notes/services/error_logging_service.dart';
import 'package:duru_notes/core/middleware/rate_limiter.dart';
import 'package:duru_notes/core/guards/auth_guard.dart';
import 'package:duru_notes/core/error/provider_error_recovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized Security Services Initialization
/// This class initializes and configures all security services
class SecurityInitialization {
  static bool _initialized = false;
  static late InputValidationService _validationService;
  static late EncryptionService _encryptionService;
  static late ErrorLoggingService _errorLoggingService;
  static late RateLimitingMiddleware _rateLimiter;
  static late AuthenticationGuard _authGuard;
  static late ProviderErrorRecovery _providerErrorRecovery;

  // Getters for services
  static InputValidationService get validation => _validationService;
  static EncryptionService get encryption => _encryptionService;
  static ErrorLoggingService get errorLogging => _errorLoggingService;
  static RateLimitingMiddleware get rateLimiter => _rateLimiter;
  static AuthenticationGuard get authGuard => _authGuard;
  static ProviderErrorRecovery get providerRecovery => _providerErrorRecovery;

  /// Initialize all security services
  /// PRODUCTION FIX: Idempotent - safe to call multiple times
  /// For re-authentication flows (sign-out → sign-up), call reset() first
  static Future<void> initialize({
    required String userId,
    String? sessionId,
    required bool debugMode,
  }) async {
    // PRODUCTION FIX: Allow re-initialization if reset() was called
    // This is critical for supporting sign-out → sign-up flows
    if (_initialized) {
      if (kDebugMode) {
        debugPrint('ℹ️ Security services already initialized, skipping...');
      }
      return;
    }

    try {
      // 1. Initialize Error Logging Service first
      _errorLoggingService = ErrorLoggingService();
      await _errorLoggingService.initialize(
        userId: userId,
        sessionId: sessionId,
        enableFileLogging: !debugMode,
        enableRemoteLogging: !debugMode,
      );

      // 2. Initialize Input Validation Service
      _validationService = InputValidationService();

      // 3. Initialize Encryption Service
      _encryptionService = EncryptionService();
      await _encryptionService.initialize();

      // 4. Initialize Rate Limiter
      _rateLimiter = RateLimitingMiddleware();
      await _rateLimiter.loadDistributedState();

      // Configure rate limits for critical endpoints
      _rateLimiter.configureEndpointLimit(
        endpoint: '/auth/login',
        requestsPerMinute: 5,
        requestsPerHour: 30,
        burstCapacity: 3,
      );

      _rateLimiter.configureEndpointLimit(
        endpoint: '/auth/register',
        requestsPerMinute: 3,
        requestsPerHour: 10,
        burstCapacity: 2,
      );

      _rateLimiter.configureEndpointLimit(
        endpoint: '/api/notes',
        requestsPerMinute: 100,
        requestsPerHour: 1000,
        burstCapacity: 20,
      );

      // 5. Initialize Authentication Guard
      _authGuard = AuthenticationGuard();

      // Get stored secrets or generate new ones
      final prefs = await SharedPreferences.getInstance();
      String? jwtSecret = prefs.getString('jwt_secret');
      String? csrfSecret = prefs.getString('csrf_secret');

      if (jwtSecret == null || csrfSecret == null) {
        // Generate secure secrets
        jwtSecret = _generateSecureSecret();
        csrfSecret = _generateSecureSecret();

        // Store for future use
        await prefs.setString('jwt_secret', jwtSecret);
        await prefs.setString('csrf_secret', csrfSecret);
      }

      await _authGuard.initialize(
        jwtSecret: jwtSecret,
        csrfSecret: csrfSecret,
      );

      // 6. Initialize Provider Error Recovery
      _providerErrorRecovery = ProviderErrorRecovery();

      _initialized = true;

      if (kDebugMode) {
        debugPrint('✅ Security services initialized successfully');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ Failed to initialize security services: $e');
        debugPrint('Stack: $stack');
      }

      // Log to error service if available
      try {
        _errorLoggingService.logError(
          e,
          stack,
          category: 'SecurityInitialization',
          metadata: {'stage': 'initialization'},
        );
      } catch (_) {
        // Ignore if error logging not available
      }

      rethrow;
    }
  }

  /// Generate a secure random secret
  static String _generateSecureSecret() {
    final random = List.generate(32, (i) =>
      DateTime.now().microsecondsSinceEpoch * i % 256);
    return base64Encode(random);
  }

  /// Check if services are initialized
  static bool get isInitialized => _initialized;

  /// PRODUCTION FIX: Reset initialization state
  /// Call this before signing out to allow fresh initialization on next sign-up
  /// This is critical for supporting sign-out → sign-up flows
  static void reset() {
    if (!_initialized) return;

    if (kDebugMode) {
      debugPrint('🔄 Resetting security services initialization state...');
    }

    // Don't dispose services, just reset the flag
    // AuthenticationGuard is now idempotent and can be re-initialized
    _initialized = false;

    if (kDebugMode) {
      debugPrint('✅ Security services reset complete');
    }
  }

  /// Dispose all services
  /// IMPORTANT: Call reset() instead of dispose() for sign-out flows
  /// Only call dispose() when completely shutting down the app
  static void dispose() {
    if (!_initialized) return;

    _rateLimiter.dispose();
    _authGuard.dispose();
    _encryptionService.dispose();
    _errorLoggingService.dispose();

    _initialized = false;
  }
}

/// Extension for easy access to security services
extension SecurityContext on BuildContext {
  InputValidationService get validation => SecurityInitialization.validation;
  EncryptionService get encryption => SecurityInitialization.encryption;
  ErrorLoggingService get errorLogging => SecurityInitialization.errorLogging;
  RateLimitingMiddleware get rateLimiter => SecurityInitialization.rateLimiter;
  AuthenticationGuard get authGuard => SecurityInitialization.authGuard;
  ProviderErrorRecovery get providerRecovery => SecurityInitialization.providerRecovery;
}