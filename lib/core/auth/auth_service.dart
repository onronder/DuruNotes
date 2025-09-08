import 'dart:async';
import 'dart:math';

import 'package:duru_notes/core/auth/login_attempts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of an authentication attempt
class AuthResult {
  const AuthResult({
    required this.success,
    this.user,
    this.session,
    this.error,
    this.isAccountLocked = false,
    this.lockoutDuration,
    this.attemptsRemaining,
  });

  final bool success;
  final User? user;
  final Session? session;
  final String? error;
  final bool isAccountLocked;
  final Duration? lockoutDuration;
  final int? attemptsRemaining;

  bool get isRetryable => !success && !isAccountLocked;
}

/// Enhanced authentication service with rate limiting and brute force protection
class AuthService {
  AuthService({
    SupabaseClient? client,
    LoginAttemptsService? loginAttemptsService,
  }) : _client = client ?? Supabase.instance.client,
       _loginAttemptsService = loginAttemptsService ?? LoginAttemptsService();

  final SupabaseClient _client;
  final LoginAttemptsService _loginAttemptsService;

  // Rate limiting constants
  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(seconds: 1);
  static const Duration _maxDelay = Duration(seconds: 30);
  
  // Backoff tracking per email
  final Map<String, _BackoffState> _backoffStates = {};

  /// Authenticate user with exponential backoff and rate limiting
  Future<AuthResult> signInWithRetry({
    required String email,
    required String password,
    bool enableRetry = true,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    
    // Check if account is locked
    final lockStatus = await _loginAttemptsService.checkAccountLockout();
    if (lockStatus.isLocked) {
      return AuthResult(
        success: false,
        isAccountLocked: true,
        lockoutDuration: lockStatus.remainingLockoutTime,
        error: 'Account temporarily locked due to multiple failed login attempts. '
               'Please try again in ${_formatDuration(lockStatus.remainingLockoutTime!)}.',
      );
    }

    if (!enableRetry) {
      return _performSingleSignIn(normalizedEmail, password);
    }

    // Get or create backoff state for this email
    final backoffState = _backoffStates[normalizedEmail] ??= _BackoffState();
    
    // Check if we're in a backoff period
    if (backoffState.isInBackoff) {
      return AuthResult(
        success: false,
        error: 'Too many recent attempts. Please wait ${_formatDuration(backoffState.remainingBackoffTime)} before trying again.',
      );
    }

    AuthResult? result;
    Exception? lastException;

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          final delay = _calculateDelay(attempt - 1);
          if (kDebugMode) {
            print('Auth retry attempt $attempt after ${delay.inSeconds}s delay');
          }
          await Future<void>.delayed(delay);
        }

        result = await _performSingleSignIn(normalizedEmail, password);
        
        if (result.success) {
          // Reset backoff on success
          backoffState.reset();
          return result;
        }

        // If account is locked, don't retry
        if (result.isAccountLocked) {
          backoffState.activateBackoff();
          return result;
        }

        // Don't retry on credential errors (wrong password)
        if (_isCredentialError(result.error)) {
          backoffState.activateBackoff();
          return result;
        }

      } on AuthException catch (e) {
        lastException = e;
        if (_isCredentialError(e.message)) {
          // Don't retry credential errors
          break;
        }
      } on Exception catch (e) {
        lastException = e;
      } catch (e) {
        lastException = Exception(e.toString());
      }
    }

    // All retries failed - activate backoff
    backoffState.activateBackoff();
    
    return AuthResult(
      success: false,
      error: result?.error ?? lastException?.toString() ?? 'Authentication failed after multiple attempts',
    );
  }

  /// Perform a single sign-in attempt without retries
  Future<AuthResult> _performSingleSignIn(String email, String password) async {
    try {
      // Check rate limiting before attempting
      final canAttempt = await _loginAttemptsService.canAttemptLogin();
      if (!canAttempt) {
        final lockStatus = await _loginAttemptsService.checkAccountLockout();
        return AuthResult(
          success: false,
          isAccountLocked: lockStatus.isLocked,
          lockoutDuration: lockStatus.remainingLockoutTime,
          attemptsRemaining: lockStatus.attemptsRemaining,
          error: lockStatus.isLocked
              ? 'Account locked. Try again in ${_formatDuration(lockStatus.remainingLockoutTime!)}'
              : 'Too many attempts. ${lockStatus.attemptsRemaining} attempts remaining.',
        );
      }

      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null && response.session != null) {
        // Record successful login
        await _loginAttemptsService.recordSuccessfulLogin();
        
        return AuthResult(
          success: true,
          user: response.user,
          session: response.session,
        );
      }

      // This shouldn't happen but handle edge case
      await _loginAttemptsService.recordFailedLogin();
      return const AuthResult(
        success: false,
        error: 'Authentication failed - no session created',
      );

    } on AuthException catch (e) {
      // Record failed login attempt
      await _loginAttemptsService.recordFailedLogin();

      // Check if account is now locked after this attempt
      final lockStatus = await _loginAttemptsService.checkAccountLockout();
      
      return AuthResult(
        success: false,
        error: e.message,
        isAccountLocked: lockStatus.isLocked,
        lockoutDuration: lockStatus.remainingLockoutTime,
        attemptsRemaining: lockStatus.attemptsRemaining,
      );
    } on Exception catch (e) {
      // Record generic failed attempt
      await _loginAttemptsService.recordFailedLogin();
      
      if (kDebugMode) {
        print('Auth error: $e');
      }
      
      return const AuthResult(
        success: false,
        error: 'Authentication failed. Please try again.',
      );
    }
  }

  /// Sign up with basic retry logic
  Future<AuthResult> signUpWithRetry({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    
    try {
      final response = await _client.auth.signUp(
        email: normalizedEmail,
        password: password,
      );

      if (response.user != null) {
        return AuthResult(
          success: true,
          user: response.user,
          session: response.session,
        );
      }

      return const AuthResult(
        success: false,
        error: 'Account creation failed',
      );

    } on AuthException catch (e) {
      return AuthResult(
        success: false,
        error: e.message,
      );
    } on Exception catch (e) {
      if (kDebugMode) {
        print('Signup error: $e');
      }
      
      return const AuthResult(
        success: false,
        error: 'Account creation failed. Please try again.',
      );
    }
  }

  /// Calculate exponential backoff delay
  Duration _calculateDelay(int attemptNumber) {
    final exponentialDelay = Duration(
      milliseconds: _baseDelay.inMilliseconds * pow(2, attemptNumber).toInt()
    );
    
    // Add jitter to prevent thundering herd
    final jitter = Duration(
      milliseconds: Random().nextInt(1000)
    );
    
    final totalDelay = exponentialDelay + jitter;
    return totalDelay > _maxDelay ? _maxDelay : totalDelay;
  }

  /// Check if error is a credential error (shouldn't retry)
  bool _isCredentialError(String? errorMessage) {
    if (errorMessage == null) return false;
    
    final lowerError = errorMessage.toLowerCase();
    return lowerError.contains('invalid login credentials') ||
           lowerError.contains('wrong password') ||
           lowerError.contains('invalid email') ||
           lowerError.contains('user not found') ||
           lowerError.contains('invalid credentials');
  }

  /// Format duration for user display
  String _formatDuration(Duration duration) {
    if (duration.inMinutes >= 1) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      return seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
    }
    return '${duration.inSeconds}s';
  }

  /// Clear all backoff states (useful for testing)
  void clearBackoffStates() {
    _backoffStates.clear();
  }

  /// Get current backoff status for email (useful for UI)
  Duration? getBackoffTimeRemaining(String email) {
    final state = _backoffStates[email.trim().toLowerCase()];
    return state?.isInBackoff ?? false ? state?.remainingBackoffTime : null;
  }
}

/// Internal backoff state for tracking retry delays per email
class _BackoffState {
  _BackoffState();

  DateTime? _backoffUntil;
  static const Duration _backoffDuration = Duration(minutes: 2);

  bool get isInBackoff => 
      _backoffUntil != null && DateTime.now().isBefore(_backoffUntil!);

  Duration get remainingBackoffTime {
    if (!isInBackoff) return Duration.zero;
    return _backoffUntil!.difference(DateTime.now());
  }

  void activateBackoff() {
    _backoffUntil = DateTime.now().add(_backoffDuration);
  }

  void reset() {
    _backoffUntil = null;
  }
}
