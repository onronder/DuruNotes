import 'dart:async';

/// Rate limiter for authentication attempts to prevent brute force attacks
///
/// Implements exponential backoff with progressive delays
class AuthRateLimiter {
  final Map<String, _RateLimitState> _attempts = <String, _RateLimitState>{};
  final Duration _cleanupInterval = const Duration(hours: 1);
  Timer? _cleanupTimer;

  AuthRateLimiter() {
    _startCleanupTimer();
  }

  /// Check if operation is allowed for the given identifier
  /// Returns delay duration if rate limited, null if allowed
  Duration? checkRateLimit(String identifier) {
    final now = DateTime.now();
    final state = _attempts[identifier];

    if (state == null) {
      // First attempt, allow
      _attempts[identifier] = _RateLimitState(
        attemptCount: 1,
        lastAttempt: now,
        lockoutUntil: null,
      );
      return null;
    }

    // Check if currently locked out
    if (state.lockoutUntil != null && now.isBefore(state.lockoutUntil!)) {
      return state.lockoutUntil!.difference(now);
    }

    // Calculate delay based on attempt count
    final delay = _calculateDelay(state.attemptCount);
    final requiredWaitTime = state.lastAttempt.add(delay);

    if (now.isBefore(requiredWaitTime)) {
      // Must wait longer
      return requiredWaitTime.difference(now);
    }

    // Update attempt count and allow
    state.attemptCount++;
    state.lastAttempt = now;

    // Apply lockout if too many attempts
    if (state.attemptCount >= 10) {
      state.lockoutUntil = now.add(const Duration(hours: 1));
    } else if (state.attemptCount >= 5) {
      state.lockoutUntil = now.add(const Duration(minutes: 15));
    }

    return null;
  }

  /// Record successful authentication (resets rate limit)
  void recordSuccess(String identifier) {
    _attempts.remove(identifier);
  }

  /// Calculate exponential backoff delay
  Duration _calculateDelay(int attemptCount) {
    if (attemptCount <= 1) return Duration.zero;
    if (attemptCount == 2) return const Duration(seconds: 2);
    if (attemptCount == 3) return const Duration(seconds: 5);
    if (attemptCount == 4) return const Duration(seconds: 10);
    if (attemptCount >= 5) return const Duration(seconds: 30);

    // Exponential backoff: 2^(attempts-1) seconds, capped at 60s
    final delaySeconds = (1 << (attemptCount - 1)).clamp(1, 60);
    return Duration(seconds: delaySeconds);
  }

  /// Start periodic cleanup of old entries
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) => _cleanup());
  }

  /// Remove entries older than 24 hours
  void _cleanup() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 24));

    _attempts.removeWhere((key, state) {
      // Remove if last attempt was over 24 hours ago and not locked out
      if (state.lockoutUntil == null || now.isAfter(state.lockoutUntil!)) {
        return state.lastAttempt.isBefore(cutoff);
      }
      return false;
    });
  }

  /// Get current lockout status for debugging
  RateLimitStatus getStatus(String identifier) {
    final state = _attempts[identifier];
    if (state == null) {
      return RateLimitStatus(
        attemptCount: 0,
        isLockedOut: false,
        nextAttemptAllowed: DateTime.now(),
      );
    }

    final now = DateTime.now();
    final isLockedOut =
        state.lockoutUntil != null && now.isBefore(state.lockoutUntil!);
    final delay = _calculateDelay(state.attemptCount);
    final nextAllowed = state.lastAttempt.add(delay);

    return RateLimitStatus(
      attemptCount: state.attemptCount,
      isLockedOut: isLockedOut,
      nextAttemptAllowed: isLockedOut ? state.lockoutUntil! : nextAllowed,
      lockoutUntil: state.lockoutUntil,
    );
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _attempts.clear();
  }
}

class _RateLimitState {
  int attemptCount;
  DateTime lastAttempt;
  DateTime? lockoutUntil;

  _RateLimitState({
    required this.attemptCount,
    required this.lastAttempt,
    this.lockoutUntil,
  });
}

class RateLimitStatus {
  final int attemptCount;
  final bool isLockedOut;
  final DateTime nextAttemptAllowed;
  final DateTime? lockoutUntil;

  RateLimitStatus({
    required this.attemptCount,
    required this.isLockedOut,
    required this.nextAttemptAllowed,
    this.lockoutUntil,
  });

  Duration? get remainingLockout {
    if (lockoutUntil == null) return null;
    final now = DateTime.now();
    if (now.isAfter(lockoutUntil!)) return null;
    return lockoutUntil!.difference(now);
  }
}
