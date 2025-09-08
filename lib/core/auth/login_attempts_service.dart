import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of account lockout check
class AccountLockoutStatus {

  const AccountLockoutStatus({
    required this.isLocked,
    required this.attemptsRemaining, this.remainingLockoutTime,
  });
  final bool isLocked;
  final Duration? remainingLockoutTime;
  final int attemptsRemaining;
}

/// Service for tracking and limiting login attempts to prevent brute force attacks
class LoginAttemptsService {
  static const String _attemptsKey = 'login_attempts';
  static const String _lastAttemptKey = 'last_login_attempt';
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 15);

  /// Check if login attempts are currently locked out
  Future<bool> isLockedOut() async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getInt(_attemptsKey) ?? 0;
    
    if (attempts >= _maxAttempts) {
      final lastAttemptMs = prefs.getInt(_lastAttemptKey) ?? 0;
      final lastAttempt = DateTime.fromMillisecondsSinceEpoch(lastAttemptMs);
      final timeSinceLastAttempt = DateTime.now().difference(lastAttempt);
      
      if (timeSinceLastAttempt < _lockoutDuration) {
        return true;
      } else {
        // Reset attempts after lockout period
        await _resetAttempts();
        return false;
      }
    }
    
    return false;
  }

  /// Get remaining time until lockout expires
  Future<Duration?> getRemainingLockoutTime() async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getInt(_attemptsKey) ?? 0;
    
    if (attempts >= _maxAttempts) {
      final lastAttemptMs = prefs.getInt(_lastAttemptKey) ?? 0;
      final lastAttempt = DateTime.fromMillisecondsSinceEpoch(lastAttemptMs);
      final timeSinceLastAttempt = DateTime.now().difference(lastAttempt);
      
      if (timeSinceLastAttempt < _lockoutDuration) {
        return _lockoutDuration - timeSinceLastAttempt;
      }
    }
    
    return null;
  }

  /// Record a failed login attempt
  Future<void> recordFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final currentAttempts = prefs.getInt(_attemptsKey) ?? 0;
    
    await prefs.setInt(_attemptsKey, currentAttempts + 1);
    await prefs.setInt(_lastAttemptKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Record a successful login (resets attempts)
  Future<void> recordSuccessfulLogin() async {
    await _resetAttempts();
  }

  /// Get current number of failed attempts
  Future<int> getCurrentAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_attemptsKey) ?? 0;
  }

  /// Get remaining attempts before lockout
  Future<int> getRemainingAttempts() async {
    final current = await getCurrentAttempts();
    return (_maxAttempts - current).clamp(0, _maxAttempts);
  }

  /// Reset all login attempt data
  Future<void> _resetAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_attemptsKey);
    await prefs.remove(_lastAttemptKey);
  }

  /// Clear all login attempt data (admin function)
  Future<void> clearAttempts() async {
    await _resetAttempts();
  }

  /// Check account lockout status (alias for isLockedOut)
  Future<AccountLockoutStatus> checkAccountLockout() async {
    final isLocked = await isLockedOut();
    final remaining = await getRemainingLockoutTime();
    final attempts = await getRemainingAttempts();
    
    return AccountLockoutStatus(
      isLocked: isLocked,
      remainingLockoutTime: remaining,
      attemptsRemaining: attempts,
    );
  }

  /// Check if user can attempt login (alias for !isLockedOut)
  Future<bool> canAttemptLogin() async {
    return !(await isLockedOut());
  }

  /// Record failed login (alias for recordFailedAttempt)
  Future<void> recordFailedLogin() async {
    return recordFailedAttempt();
  }
}
