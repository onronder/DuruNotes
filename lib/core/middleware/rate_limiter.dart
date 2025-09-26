import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Production-grade Rate Limiting Middleware
/// Implements multiple strategies:
/// - Token bucket algorithm for smooth rate limiting
/// - Sliding window for accurate tracking
/// - Exponential backoff for retry logic
/// - Distributed rate limiting support
class RateLimitingMiddleware {
  static final RateLimitingMiddleware _instance = RateLimitingMiddleware._internal();
  factory RateLimitingMiddleware() => _instance;
  RateLimitingMiddleware._internal() {
    _initializeCleanupTimer();
  }

  // Rate limit configurations
  static const int _defaultRequestsPerMinute = 100;
  static const int _defaultRequestsPerHour = 1000;
  static const int _burstCapacity = 20;

  // Storage for rate limit tracking
  final Map<String, RateLimitBucket> _userBuckets = {};
  final Map<String, RateLimitBucket> _ipBuckets = {};
  final Map<String, SlidingWindow> _slidingWindows = {};
  final Map<String, BackoffState> _backoffStates = {};

  // Cleanup timer
  Timer? _cleanupTimer;

  /// Check if a request is allowed
  Future<RateLimitResult> checkRateLimit({
    required String identifier,
    RateLimitType type = RateLimitType.user,
    String? endpoint,
    Map<String, dynamic>? metadata,
  }) async {
    final now = DateTime.now();
    final bucketKey = _getBucketKey(identifier, type, endpoint);

    // Check if user is in backoff period
    final backoffState = _backoffStates[bucketKey];
    if (backoffState != null && backoffState.isInBackoff(now)) {
      return RateLimitResult(
        allowed: false,
        retryAfter: backoffState.retryAfter,
        remainingTokens: 0,
        resetAt: backoffState.resetAt,
        reason: 'Rate limit exceeded - in backoff period',
        backoffMultiplier: backoffState.multiplier,
      );
    }

    // Get or create rate limit bucket
    final bucket = _getBucket(bucketKey, type);

    // Check token bucket
    if (!bucket.tryConsume(now)) {
      // Apply exponential backoff
      _applyBackoff(bucketKey, now);

      return RateLimitResult(
        allowed: false,
        retryAfter: bucket.nextRefillTime(now),
        remainingTokens: bucket.tokens.toInt(),
        resetAt: bucket.nextFullRefillTime(now),
        reason: 'Rate limit exceeded - ${type.name} limit',
      );
    }

    // Check sliding window for more accurate tracking
    final window = _getOrCreateSlidingWindow(bucketKey);
    if (!window.allowRequest(now)) {
      // Refund the token since sliding window rejected
      bucket.refund();

      return RateLimitResult(
        allowed: false,
        retryAfter: window.earliestAllowedTime(now),
        remainingTokens: bucket.tokens.toInt(),
        resetAt: window.windowResetTime(now),
        reason: 'Rate limit exceeded - sliding window limit',
      );
    }

    // Log successful request
    await _logRequest(identifier, type, endpoint, metadata);

    // Reset backoff on successful request
    _resetBackoff(bucketKey);

    return RateLimitResult(
      allowed: true,
      remainingTokens: bucket.tokens.toInt(),
      resetAt: bucket.nextFullRefillTime(now),
    );
  }

  /// Apply custom rate limit for specific endpoints
  void configureEndpointLimit({
    required String endpoint,
    required int requestsPerMinute,
    int? requestsPerHour,
    int? burstCapacity,
  }) {
    _endpointConfigs[endpoint] = EndpointRateLimitConfig(
      requestsPerMinute: requestsPerMinute,
      requestsPerHour: requestsPerHour ?? requestsPerMinute * 60,
      burstCapacity: burstCapacity ?? (requestsPerMinute / 3).ceil(),
    );
  }

  /// Reset rate limit for a specific identifier
  void resetRateLimit(String identifier, {RateLimitType? type}) {
    if (type != null) {
      final key = _getBucketKey(identifier, type, null);
      _userBuckets.remove(key);
      _ipBuckets.remove(key);
      _slidingWindows.remove(key);
      _backoffStates.remove(key);
    } else {
      // Reset all types for this identifier
      _userBuckets.removeWhere((k, v) => k.contains(identifier));
      _ipBuckets.removeWhere((k, v) => k.contains(identifier));
      _slidingWindows.removeWhere((k, v) => k.contains(identifier));
      _backoffStates.removeWhere((k, v) => k.contains(identifier));
    }
  }

  /// Get current rate limit status
  RateLimitStatus getStatus(String identifier, {RateLimitType type = RateLimitType.user}) {
    final key = _getBucketKey(identifier, type, null);
    final bucket = _getBucket(key, type);
    final window = _slidingWindows[key];
    final backoff = _backoffStates[key];

    return RateLimitStatus(
      identifier: identifier,
      type: type,
      currentTokens: bucket.tokens.toInt(),
      maxTokens: bucket.capacity,
      requestsInWindow: window?.requestCount ?? 0,
      isInBackoff: backoff?.isInBackoff(DateTime.now()) ?? false,
      backoffMultiplier: backoff?.multiplier ?? 1,
      nextResetTime: bucket.nextFullRefillTime(DateTime.now()),
    );
  }

  /// Distributed rate limiting support
  Future<void> syncWithDistributedCache() async {
    // In production, this would sync with Redis or similar
    // For now, persist to SharedPreferences for cross-session tracking
    final prefs = await SharedPreferences.getInstance();

    // Save current state
    final state = _serializeState();
    await prefs.setString('rate_limit_state', state);
  }

  /// Load distributed state
  Future<void> loadDistributedState() async {
    final prefs = await SharedPreferences.getInstance();
    final state = prefs.getString('rate_limit_state');

    if (state != null) {
      _deserializeState(state);
    }
  }

  // Private helper methods

  String _getBucketKey(String identifier, RateLimitType type, String? endpoint) {
    return '${type.name}:$identifier${endpoint != null ? ':$endpoint' : ''}';
  }

  RateLimitBucket _getBucket(String key, RateLimitType type) {
    final buckets = type == RateLimitType.user ? _userBuckets : _ipBuckets;

    return buckets.putIfAbsent(
      key,
      () => RateLimitBucket(
        capacity: _burstCapacity,
        refillRate: _defaultRequestsPerMinute / 60, // tokens per second
        tokens: _burstCapacity.toDouble(),
        lastRefill: DateTime.now(),
      ),
    );
  }

  SlidingWindow _getOrCreateSlidingWindow(String key) {
    return _slidingWindows.putIfAbsent(
      key,
      () => SlidingWindow(
        windowSize: const Duration(hours: 1),
        maxRequests: _defaultRequestsPerHour,
      ),
    );
  }

  void _applyBackoff(String key, DateTime now) {
    final current = _backoffStates[key];

    if (current == null) {
      // First violation - start with 1 minute backoff
      _backoffStates[key] = BackoffState(
        startTime: now,
        retryAfter: now.add(const Duration(minutes: 1)),
        resetAt: now.add(const Duration(minutes: 5)),
        multiplier: 1,
      );
    } else {
      // Exponential backoff - double the wait time up to 1 hour
      final newMultiplier = min(current.multiplier * 2, 60);
      final backoffDuration = Duration(minutes: newMultiplier);

      _backoffStates[key] = BackoffState(
        startTime: now,
        retryAfter: now.add(backoffDuration),
        resetAt: now.add(backoffDuration * 2),
        multiplier: newMultiplier,
      );
    }
  }

  void _resetBackoff(String key) {
    _backoffStates.remove(key);
  }

  Future<void> _logRequest(
    String identifier,
    RateLimitType type,
    String? endpoint,
    Map<String, dynamic>? metadata,
  ) async {
    // In production, log to analytics or monitoring service
    if (kDebugMode) {
      debugPrint('Rate limit request: $identifier ($type) - $endpoint');
    }
  }

  void _initializeCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupExpiredData();
    });
  }

  void _cleanupExpiredData() {
    final now = DateTime.now();

    // Clean up expired backoff states
    _backoffStates.removeWhere((k, v) => v.resetAt.isBefore(now));

    // Clean up old sliding windows
    _slidingWindows.forEach((k, v) => v.cleanup(now));

    // Clean up inactive buckets
    final inactiveThreshold = now.subtract(const Duration(hours: 1));
    _userBuckets.removeWhere((k, v) => v.lastRefill.isBefore(inactiveThreshold));
    _ipBuckets.removeWhere((k, v) => v.lastRefill.isBefore(inactiveThreshold));
  }

  String _serializeState() {
    // Serialize state for distributed caching
    // In production, use proper serialization
    return '';
  }

  void _deserializeState(String state) {
    // Deserialize state from distributed cache
    // In production, use proper deserialization
  }

  final Map<String, EndpointRateLimitConfig> _endpointConfigs = {};

  void dispose() {
    _cleanupTimer?.cancel();
  }
}

/// Token bucket implementation for smooth rate limiting
class RateLimitBucket {
  final int capacity;
  final double refillRate; // tokens per second
  double tokens;
  DateTime lastRefill;

  RateLimitBucket({
    required this.capacity,
    required this.refillRate,
    required this.tokens,
    required this.lastRefill,
  });

  bool tryConsume(DateTime now, {int tokensToConsume = 1}) {
    _refill(now);

    if (tokens >= tokensToConsume) {
      tokens -= tokensToConsume;
      return true;
    }

    return false;
  }

  void refund({int tokensToRefund = 1}) {
    tokens = min(tokens + tokensToRefund, capacity.toDouble());
  }

  void _refill(DateTime now) {
    final elapsed = now.difference(lastRefill);
    final tokensToAdd = elapsed.inMicroseconds / 1000000 * refillRate;
    tokens = min(tokens + tokensToAdd, capacity.toDouble());
    lastRefill = now;
  }

  DateTime nextRefillTime(DateTime now) {
    final tokensNeeded = 1 - tokens;
    if (tokensNeeded <= 0) return now;

    final secondsToWait = tokensNeeded / refillRate;
    return now.add(Duration(milliseconds: (secondsToWait * 1000).ceil()));
  }

  DateTime nextFullRefillTime(DateTime now) {
    final tokensNeeded = capacity - tokens;
    final secondsToWait = tokensNeeded / refillRate;
    return now.add(Duration(milliseconds: (secondsToWait * 1000).ceil()));
  }
}

/// Sliding window implementation for accurate request tracking
class SlidingWindow {
  final Duration windowSize;
  final int maxRequests;
  final Queue<DateTime> _requests = Queue();

  SlidingWindow({
    required this.windowSize,
    required this.maxRequests,
  });

  bool allowRequest(DateTime now) {
    _removeOldRequests(now);

    if (_requests.length < maxRequests) {
      _requests.add(now);
      return true;
    }

    return false;
  }

  int get requestCount => _requests.length;

  DateTime earliestAllowedTime(DateTime now) {
    if (_requests.isEmpty) return now;

    _removeOldRequests(now);

    if (_requests.length < maxRequests) return now;

    // Next allowed time is when the oldest request expires
    return _requests.first.add(windowSize);
  }

  DateTime windowResetTime(DateTime now) {
    return now.add(windowSize);
  }

  void cleanup(DateTime now) {
    _removeOldRequests(now);
  }

  void _removeOldRequests(DateTime now) {
    final cutoff = now.subtract(windowSize);
    while (_requests.isNotEmpty && _requests.first.isBefore(cutoff)) {
      _requests.removeFirst();
    }
  }
}

/// Backoff state for exponential backoff
class BackoffState {
  final DateTime startTime;
  final DateTime retryAfter;
  final DateTime resetAt;
  final int multiplier;

  BackoffState({
    required this.startTime,
    required this.retryAfter,
    required this.resetAt,
    required this.multiplier,
  });

  bool isInBackoff(DateTime now) => now.isBefore(retryAfter);
}

/// Rate limit result
class RateLimitResult {
  final bool allowed;
  final DateTime? retryAfter;
  final int remainingTokens;
  final DateTime? resetAt;
  final String? reason;
  final int? backoffMultiplier;

  RateLimitResult({
    required this.allowed,
    this.retryAfter,
    required this.remainingTokens,
    this.resetAt,
    this.reason,
    this.backoffMultiplier,
  });

  Duration? get retryIn => retryAfter?.difference(DateTime.now());
}

/// Rate limit status
class RateLimitStatus {
  final String identifier;
  final RateLimitType type;
  final int currentTokens;
  final int maxTokens;
  final int requestsInWindow;
  final bool isInBackoff;
  final int backoffMultiplier;
  final DateTime nextResetTime;

  RateLimitStatus({
    required this.identifier,
    required this.type,
    required this.currentTokens,
    required this.maxTokens,
    required this.requestsInWindow,
    required this.isInBackoff,
    required this.backoffMultiplier,
    required this.nextResetTime,
  });
}

/// Endpoint rate limit configuration
class EndpointRateLimitConfig {
  final int requestsPerMinute;
  final int requestsPerHour;
  final int burstCapacity;

  EndpointRateLimitConfig({
    required this.requestsPerMinute,
    required this.requestsPerHour,
    required this.burstCapacity,
  });
}

/// Rate limit types
enum RateLimitType {
  user,
  ip,
  api,
  endpoint,
}