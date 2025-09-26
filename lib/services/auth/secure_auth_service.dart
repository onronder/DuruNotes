import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duru_notes/core/security/security_initialization.dart';
import 'package:duru_notes/core/guards/auth_guard.dart';
import 'package:duru_notes/services/security/input_validation_service.dart';
import 'package:duru_notes/services/security/encryption_service.dart';
import 'package:duru_notes/core/middleware/rate_limiter.dart';
import 'package:duru_notes/services/error_logging_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Production-grade secure authentication service
/// Integrates all security services for comprehensive protection
class SecureAuthService {
  static final SecureAuthService _instance = SecureAuthService._internal();
  factory SecureAuthService() => _instance;
  SecureAuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  late final AuthenticationGuard _authGuard;
  late final InputValidationService _validator;
  late final EncryptionService _encryption;
  late final RateLimitingMiddleware _rateLimiter;
  late final ErrorLoggingService _errorLogger;

  String? _currentSessionId;
  String? _csrfToken;

  /// Initialize the secure auth service
  Future<void> initialize() async {
    _authGuard = SecurityInitialization.authGuard;
    _validator = SecurityInitialization.validation;
    _encryption = SecurityInitialization.encryption;
    _rateLimiter = SecurityInitialization.rateLimiter;
    _errorLogger = SecurityInitialization.errorLogging;

    // Listen to auth state changes
    _supabase.auth.onAuthStateChange.listen(_handleAuthStateChange);
  }

  /// Secure sign up with comprehensive validation and protection
  Future<SecureAuthResult> signUp({
    required String email,
    required String password,
    String? username,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // 1. Input validation
      final validatedEmail = _validator.validateEmail(email, required: true);
      if (validatedEmail == null) {
        throw AuthException('Invalid email address');
      }

      // Validate password strength
      _validatePasswordStrength(password);

      // 2. Check rate limiting
      await _checkRateLimit('signup', email);

      // 3. Get device info for fingerprinting
      final deviceInfo = await _getDeviceInfo();

      // 4. Encrypt sensitive metadata
      final encryptedMetadata = metadata != null
          ? await _encryptMetadata(metadata)
          : null;

      // 5. Perform Supabase sign up
      final response = await _supabase.auth.signUp(
        email: validatedEmail,
        password: password,
        data: {
          if (username != null) 'username': username,
          'encrypted_metadata': encryptedMetadata,
          'device_info': deviceInfo,
        },
      );

      if (response.user == null) {
        throw AuthException('Sign up failed');
      }

      // 6. Create secure session with our AuthenticationGuard
      final authResult = await _authGuard.authenticate(
        username: response.user!.id,
        password: password, // This would be validated server-side
        deviceId: (deviceInfo['deviceId'] ?? 'unknown') as String,
        deviceInfo: deviceInfo,
      );

      if (!authResult.success) {
        throw AuthException(authResult.error ?? 'Authentication failed');
      }

      _currentSessionId = authResult.sessionId;
      _csrfToken = authResult.csrfToken;

      // 7. Store encrypted credentials locally if remember me
      await _storeSecureCredentials(validatedEmail, authResult.accessToken!);

      // 8. Log successful signup
      _errorLogger.logInfo('User signed up successfully', {
        'userId': response.user!.id,
        'email': validatedEmail,
        'sessionId': _currentSessionId,
      });

      return SecureAuthResult(
        success: true,
        user: response.user!,
        sessionId: _currentSessionId,
        csrfToken: _csrfToken,
        accessToken: authResult.accessToken,
        refreshToken: authResult.refreshToken,
      );
    } catch (error, stack) {
      _errorLogger.logError(error, stack, category: 'Auth', metadata: {
        'operation': 'signup',
        'email': email,
      });

      if (error is AuthException) rethrow;
      throw AuthException('Sign up failed: ${error.toString()}');
    }
  }

  /// Secure sign in with all protections
  Future<SecureAuthResult> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
    String? totpCode,
  }) async {
    try {
      // 1. Input validation
      final validatedEmail = _validator.validateEmail(email, required: true);
      if (validatedEmail == null) {
        throw AuthException('Invalid email address');
      }

      // 2. Check rate limiting
      await _checkRateLimit('signin', email);

      // 3. Get device info
      final deviceInfo = await _getDeviceInfo();

      // 4. Perform Supabase sign in
      final response = await _supabase.auth.signInWithPassword(
        email: validatedEmail,
        password: password,
      );

      if (response.user == null) {
        throw AuthException('Sign in failed');
      }

      // 5. Create secure session with AuthenticationGuard
      final authResult = await _authGuard.authenticate(
        username: response.user!.id,
        password: password,
        deviceId: (deviceInfo['deviceId'] ?? 'unknown') as String,
        totpCode: totpCode,
        deviceInfo: deviceInfo,
      );

      if (!authResult.success) {
        // Handle specific auth failures
        if (authResult.requiresMfa) {
          throw AuthException('2FA required', requiresMfa: true);
        }
        if (authResult.requiresDeviceVerification) {
          throw AuthException('Device verification required',
            requiresDeviceVerification: true);
        }
        throw AuthException(authResult.error ?? 'Authentication failed');
      }

      _currentSessionId = authResult.sessionId;
      _csrfToken = authResult.csrfToken;

      // 6. Store credentials if remember me
      if (rememberMe) {
        await _storeSecureCredentials(validatedEmail, authResult.accessToken!);
      }

      // 7. Update security context with actual user ID
      await SecurityInitialization.initialize(
        userId: response.user!.id,
        sessionId: _currentSessionId,
        debugMode: kDebugMode,
      );

      // 8. Log successful signin
      _errorLogger.logInfo('User signed in successfully', {
        'userId': response.user!.id,
        'sessionId': _currentSessionId,
      });

      return SecureAuthResult(
        success: true,
        user: response.user!,
        sessionId: _currentSessionId,
        csrfToken: _csrfToken,
        accessToken: authResult.accessToken,
        refreshToken: authResult.refreshToken,
      );
    } catch (error, stack) {
      _errorLogger.logError(error, stack, category: 'Auth', metadata: {
        'operation': 'signin',
        'email': email,
      });

      if (error is AuthException) rethrow;
      throw AuthException('Sign in failed: ${error.toString()}');
    }
  }

  /// Validate access token for protected routes
  Future<bool> validateSession() async {
    if (_currentSessionId == null) return false;

    // Get current Supabase session
    final supabaseSession = _supabase.auth.currentSession;
    if (supabaseSession == null) return false;

    // Validate with AuthenticationGuard
    final validationResult = await _authGuard.validateAccessToken(
      supabaseSession.accessToken,
    );

    if (!validationResult.valid) {
      // Try to refresh if needed
      if (validationResult.needsRefresh) {
        return await refreshSession();
      }
      return false;
    }

    return true;
  }

  /// Refresh session tokens
  Future<bool> refreshSession() async {
    try {
      if (_currentSessionId == null || _csrfToken == null) return false;

      final supabaseSession = _supabase.auth.currentSession;
      if (supabaseSession == null) return false;

      // Refresh with AuthenticationGuard
      final refreshResult = await _authGuard.refreshAccessToken(
        refreshToken: supabaseSession.refreshToken!,
        csrfToken: _csrfToken!,
      );

      if (!refreshResult.success) {
        _errorLogger.logWarning('Token refresh failed', {
          'sessionId': _currentSessionId,
          'error': refreshResult.error,
        });
        return false;
      }

      // Update CSRF token
      _csrfToken = refreshResult.csrfToken;

      // Also refresh Supabase session
      await _supabase.auth.refreshSession();

      return true;
    } catch (error, stack) {
      _errorLogger.logError(error, stack, category: 'Auth', metadata: {
        'operation': 'refresh',
        'sessionId': _currentSessionId,
      });
      return false;
    }
  }

  /// Secure sign out
  Future<void> signOut() async {
    try {
      // 1. Logout from AuthenticationGuard
      if (_currentSessionId != null) {
        await _authGuard.logout(_currentSessionId!);
      }

      // 2. Clear stored credentials
      await _clearStoredCredentials();

      // 3. Sign out from Supabase
      await _supabase.auth.signOut();

      // 4. Clear session data
      _currentSessionId = null;
      _csrfToken = null;

      _errorLogger.logInfo('User signed out successfully');
    } catch (error, stack) {
      _errorLogger.logError(error, stack, category: 'Auth', metadata: {
        'operation': 'signout',
      });
    }
  }

  /// Check if user has permission for an action
  bool hasPermission(String permission) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    return _authGuard.hasPermission(userId, permission);
  }

  /// Check if user can access a route
  bool canAccessRoute(String route) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    return _authGuard.canAccessRoute(userId, route);
  }

  /// Get CSRF token for requests
  String? getCsrfToken() => _csrfToken;

  // Private helper methods

  void _handleAuthStateChange(AuthState state) {
    if (state.event == AuthChangeEvent.signedOut) {
      _currentSessionId = null;
      _csrfToken = null;
    }
  }

  Future<void> _checkRateLimit(String operation, String identifier) async {
    final result = await _rateLimiter.checkRateLimit(
      identifier: identifier,
      type: RateLimitType.user,
      endpoint: '/auth/$operation',
    );

    if (!result.allowed) {
      throw AuthException(
        'Too many attempts. Please try again later.',
        retryAfter: result.retryAfter,
      );
    }
  }

  void _validatePasswordStrength(String password) {
    if (password.length < 8) {
      throw AuthException('Password must be at least 8 characters');
    }

    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    int strength = 0;
    if (hasUpper) strength++;
    if (hasLower) strength++;
    if (hasDigit) strength++;
    if (hasSpecial) strength++;

    if (strength < 3) {
      throw AuthException(
        'Password must contain at least 3 of: uppercase, lowercase, digit, special character'
      );
    }
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final prefs = await SharedPreferences.getInstance();

    String? deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('device_id', deviceId);
    }

    Map<String, dynamic> info = {'deviceId': deviceId};

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      info.addAll({
        'platform': 'Android',
        'model': androidInfo.model,
        'version': androidInfo.version.release,
      });
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      info.addAll({
        'platform': 'iOS',
        'model': iosInfo.model,
        'version': iosInfo.systemVersion,
      });
    }

    return info;
  }

  Future<String> _encryptMetadata(Map<String, dynamic> metadata) async {
    final encrypted = await _encryption.encryptData(
      metadata,
      compressBeforeEncrypt: true,
    );
    return jsonEncode(encrypted.toJson());
  }

  Future<void> _storeSecureCredentials(String email, String token) async {
    final prefs = await SharedPreferences.getInstance();

    // Encrypt credentials before storing
    final encryptedEmail = await _encryption.encryptData(email);
    final encryptedToken = await _encryption.encryptData(token);

    await prefs.setString('secure_email', jsonEncode(encryptedEmail.toJson()));
    await prefs.setString('secure_token', jsonEncode(encryptedToken.toJson()));
  }

  Future<void> _clearStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('secure_email');
    await prefs.remove('secure_token');
  }

  Future<Map<String, String>?> getStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final emailJson = prefs.getString('secure_email');
      final tokenJson = prefs.getString('secure_token');

      if (emailJson == null || tokenJson == null) return null;

      final emailData = EncryptedData.fromJson(jsonDecode(emailJson) as Map<String, dynamic>);
      final tokenData = EncryptedData.fromJson(jsonDecode(tokenJson) as Map<String, dynamic>);

      final email = await _encryption.decryptData(emailData) as String;
      final token = await _encryption.decryptData(tokenData) as String;

      return {'email': email, 'token': token};
    } catch (e) {
      return null;
    }
  }
}

/// Secure authentication result
class SecureAuthResult {
  final bool success;
  final User? user;
  final String? sessionId;
  final String? csrfToken;
  final String? accessToken;
  final String? refreshToken;
  final String? error;

  SecureAuthResult({
    required this.success,
    this.user,
    this.sessionId,
    this.csrfToken,
    this.accessToken,
    this.refreshToken,
    this.error,
  });
}

/// Custom auth exception
class AuthException implements Exception {
  final String message;
  final DateTime? retryAfter;
  final bool requiresMfa;
  final bool requiresDeviceVerification;

  AuthException(
    this.message, {
    this.retryAfter,
    this.requiresMfa = false,
    this.requiresDeviceVerification = false,
  });

  @override
  String toString() => message;
}