import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Production-grade Provider Error Recovery System
/// Provides automatic error recovery for Riverpod providers
/// Features:
/// - Automatic retry with exponential backoff
/// - Circuit breaker pattern
/// - Error state caching
/// - Fallback values
/// - Error aggregation and reporting
class ProviderErrorRecovery {
  static final ProviderErrorRecovery _instance = ProviderErrorRecovery._internal();
  factory ProviderErrorRecovery() => _instance;
  ProviderErrorRecovery._internal();

  // Error tracking
  final Map<String, ProviderErrorState> _errorStates = {};
  final Map<String, CircuitBreaker> _circuitBreakers = {};
  final Map<String, dynamic> _fallbackValues = {};
  final Map<String, RetryPolicy> _retryPolicies = {};

  // Global configuration
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Configure error recovery for a specific provider
  void configureProvider({
    required String providerId,
    dynamic fallbackValue,
    RetryPolicy? retryPolicy,
    CircuitBreakerConfig? circuitBreakerConfig,
  }) {
    if (fallbackValue != null) {
      _fallbackValues[providerId] = fallbackValue;
    }
    if (retryPolicy != null) {
      _retryPolicies[providerId] = retryPolicy;
    }
    if (circuitBreakerConfig != null) {
      _circuitBreakers[providerId] = CircuitBreaker(config: circuitBreakerConfig);
    }
  }

  /// Wrap provider logic with error recovery
  Future<T> executeWithRecovery<T>({
    required String providerId,
    required Future<T> Function() operation,
    T? fallbackValue,
    void Function(Object error, StackTrace stack)? onError,
  }) async {
    // Check circuit breaker
    final circuitBreaker = _circuitBreakers[providerId];
    if (circuitBreaker != null && !circuitBreaker.canExecute()) {
      if (kDebugMode) {
        debugPrint('Circuit breaker open for provider: $providerId');
      }
      return _getFallbackValue<T>(providerId, fallbackValue);
    }

    // Get retry policy
    final retryPolicy = _retryPolicies[providerId] ?? RetryPolicy.defaultPolicy();

    // Track error state
    final errorState = _getOrCreateErrorState(providerId);

    // Execute with retry logic
    int attempts = 0;
    Object? lastError;
    StackTrace? lastStack;

    while (attempts < retryPolicy.maxAttempts) {
      try {
        // Add timeout
        final result = await operation().timeout(
          retryPolicy.timeout ?? _defaultTimeout,
          onTimeout: () => throw TimeoutException('Provider operation timed out', _defaultTimeout),
        );

        // Success - reset error state
        errorState.reset();
        circuitBreaker?.onSuccess();

        return result;
      } catch (error, stack) {
        attempts++;
        lastError = error;
        lastStack = stack;

        // Update error state
        errorState.recordError(error, stack);

        // Update circuit breaker
        circuitBreaker?.onFailure();

        // Check if should retry
        if (!_shouldRetry(error, attempts, retryPolicy)) {
          break;
        }

        // Calculate delay with exponential backoff
        final delay = _calculateRetryDelay(attempts, retryPolicy);

        if (kDebugMode) {
          debugPrint('Provider $providerId failed (attempt $attempts). Retrying in ${delay.inSeconds}s...');
        }

        // Wait before retry
        await Future<void>.delayed(delay);
      }
    }

    // All retries failed
    if (onError != null && lastError != null) {
      onError(lastError, lastStack ?? StackTrace.current);
    }

    // Report to monitoring
    _reportProviderError(providerId, lastError!, lastStack);

    // Return fallback value
    return _getFallbackValue<T>(providerId, fallbackValue);
  }

  /// Stream wrapper with error recovery
  Stream<T> streamWithRecovery<T>({
    required String providerId,
    required Stream<T> Function() streamFactory,
    T? fallbackValue,
  }) {
    final controller = StreamController<T>.broadcast();
    final errorState = _getOrCreateErrorState(providerId);
    final retryPolicy = _retryPolicies[providerId] ?? RetryPolicy.defaultPolicy();

    StreamSubscription<T>? subscription;
    int reconnectAttempts = 0;

    void connect() {
      try {
        final stream = streamFactory();
        subscription = stream.listen(
          (data) {
            // Reset error state on successful data
            errorState.reset();
            reconnectAttempts = 0;
            controller.add(data);
          },
          onError: (Object error, StackTrace? stack) async {
            errorState.recordError(error, stack ?? StackTrace.current);
            reconnectAttempts++;

            if (reconnectAttempts < retryPolicy.maxAttempts) {
              // Emit fallback value while reconnecting
              if (fallbackValue != null) {
                controller.add(fallbackValue);
              }

              // Schedule reconnection
              final delay = _calculateRetryDelay(reconnectAttempts, retryPolicy);
              await Future<void>.delayed(delay);

              // Reconnect
              subscription?.cancel();
              connect();
            } else {
              // Max retries reached
              controller.addError(error, stack ?? StackTrace.current);
              _reportProviderError(providerId, error, stack ?? StackTrace.current);
            }
          },
          onDone: () {
            if (!controller.isClosed) {
              controller.close();
            }
          },
          cancelOnError: false,
        );
      } catch (error, stack) {
        controller.addError(error, stack);
        _reportProviderError(providerId, error, stack);
      }
    }

    // Start connection
    connect();

    // Handle controller lifecycle
    controller.onCancel = () {
      subscription?.cancel();
    };

    return controller.stream;
  }

  /// Get error state for a provider
  ProviderErrorState? getErrorState(String providerId) {
    return _errorStates[providerId];
  }

  /// Clear error state for a provider
  void clearErrorState(String providerId) {
    _errorStates[providerId]?.reset();
    _circuitBreakers[providerId]?.reset();
  }

  /// Get all providers in error state
  Map<String, ProviderErrorInfo> getProvidersInError() {
    final result = <String, ProviderErrorInfo>{};

    _errorStates.forEach((id, state) {
      if (state.hasError) {
        result[id] = ProviderErrorInfo(
          providerId: id,
          errorCount: state.errorCount,
          lastError: state.lastError,
          lastErrorTime: state.lastErrorTime,
          isCircuitBreakerOpen: _circuitBreakers[id]?.isOpen ?? false,
        );
      }
    });

    return result;
  }

  // Private helper methods

  ProviderErrorState _getOrCreateErrorState(String providerId) {
    return _errorStates.putIfAbsent(
      providerId,
      () => ProviderErrorState(providerId: providerId),
    );
  }

  T _getFallbackValue<T>(String providerId, T? specificFallback) {
    final fallback = specificFallback ?? _fallbackValues[providerId];
    if (fallback == null) {
      throw ProviderErrorException(
        'No fallback value configured for provider: $providerId',
      );
    }
    return fallback as T;
  }

  bool _shouldRetry(Object error, int attempts, RetryPolicy policy) {
    // Don't retry on certain errors
    if (error is ProviderErrorException && !error.isRetryable) {
      return false;
    }

    // Check max attempts
    if (attempts >= policy.maxAttempts) {
      return false;
    }

    // Check retryable errors
    if (policy.retryableErrors != null) {
      return policy.retryableErrors!.any((type) => error.runtimeType == type);
    }

    // Default: retry on all errors except programming errors
    return error is! TypeError && error is! NoSuchMethodError;
  }

  Duration _calculateRetryDelay(int attempt, RetryPolicy policy) {
    if (policy.backoffStrategy == BackoffStrategy.fixed) {
      return policy.retryDelay;
    }

    // Exponential backoff with jitter
    final exponentialDelay = policy.retryDelay * (1 << (attempt - 1));
    final maxDelay = policy.maxRetryDelay ?? const Duration(seconds: 60);
    final clampedDelay = exponentialDelay > maxDelay ? maxDelay : exponentialDelay;

    // Add jitter to prevent thundering herd
    final jitter = Duration(
      milliseconds: (clampedDelay.inMilliseconds * 0.2 *
                     (DateTime.now().millisecondsSinceEpoch % 100) / 100).round(),
    );

    return clampedDelay + jitter;
  }

  void _reportProviderError(String providerId, Object error, StackTrace? stack) {
    if (kDebugMode) {
      debugPrint('Provider error [$providerId]: $error');
      if (stack != null) {
        debugPrint('Stack trace:\n$stack');
      }
    }

    // In production, report to monitoring service
    // Sentry.captureException(error, stackTrace: stack);
  }
}

/// Provider error state tracking
class ProviderErrorState {
  final String providerId;
  int errorCount = 0;
  Object? lastError;
  StackTrace? lastStack;
  DateTime? lastErrorTime;
  DateTime? firstErrorTime;

  ProviderErrorState({required this.providerId});

  bool get hasError => lastError != null;

  void recordError(Object error, StackTrace? stack) {
    errorCount++;
    lastError = error;
    lastStack = stack;
    lastErrorTime = DateTime.now();
    firstErrorTime ??= lastErrorTime;
  }

  void reset() {
    errorCount = 0;
    lastError = null;
    lastStack = null;
    lastErrorTime = null;
    firstErrorTime = null;
  }

  Duration? get errorDuration {
    if (firstErrorTime == null || lastErrorTime == null) return null;
    return lastErrorTime!.difference(firstErrorTime!);
  }
}

/// Retry policy configuration
class RetryPolicy {
  final int maxAttempts;
  final Duration retryDelay;
  final Duration? maxRetryDelay;
  final BackoffStrategy backoffStrategy;
  final Duration? timeout;
  final List<Type>? retryableErrors;

  const RetryPolicy({
    required this.maxAttempts,
    required this.retryDelay,
    this.maxRetryDelay,
    this.backoffStrategy = BackoffStrategy.exponential,
    this.timeout,
    this.retryableErrors,
  });

  factory RetryPolicy.defaultPolicy() {
    return const RetryPolicy(
      maxAttempts: 3,
      retryDelay: Duration(seconds: 1),
      maxRetryDelay: Duration(seconds: 30),
      backoffStrategy: BackoffStrategy.exponential,
    );
  }

  factory RetryPolicy.aggressive() {
    return const RetryPolicy(
      maxAttempts: 5,
      retryDelay: Duration(milliseconds: 500),
      maxRetryDelay: Duration(seconds: 10),
      backoffStrategy: BackoffStrategy.exponential,
    );
  }

  factory RetryPolicy.conservative() {
    return const RetryPolicy(
      maxAttempts: 2,
      retryDelay: Duration(seconds: 5),
      backoffStrategy: BackoffStrategy.fixed,
    );
  }
}

/// Backoff strategies for retry delays
enum BackoffStrategy {
  fixed,
  exponential,
}

/// Circuit breaker implementation
class CircuitBreaker {
  final CircuitBreakerConfig config;
  CircuitBreakerState _state = CircuitBreakerState.closed;
  int _failureCount = 0;
  DateTime? _openedAt;

  CircuitBreaker({required this.config});

  bool canExecute() {
    switch (_state) {
      case CircuitBreakerState.closed:
        return true;
      case CircuitBreakerState.open:
        // Check if should transition to half-open
        if (_openedAt != null) {
          final elapsed = DateTime.now().difference(_openedAt!);
          if (elapsed >= config.resetTimeout) {
            _state = CircuitBreakerState.halfOpen;
            return true;
          }
        }
        return false;
      case CircuitBreakerState.halfOpen:
        return true;
    }
  }

  void onSuccess() {
    switch (_state) {
      case CircuitBreakerState.closed:
        _failureCount = 0;
        break;
      case CircuitBreakerState.halfOpen:
        // Successful call in half-open state closes the circuit
        _state = CircuitBreakerState.closed;
        _failureCount = 0;
        _openedAt = null;
        break;
      case CircuitBreakerState.open:
        // Shouldn't happen
        break;
    }
  }

  void onFailure() {
    _failureCount++;

    switch (_state) {
      case CircuitBreakerState.closed:
        if (_failureCount >= config.failureThreshold) {
          _open();
        }
        break;
      case CircuitBreakerState.halfOpen:
        // Failed in half-open state reopens the circuit
        _open();
        break;
      case CircuitBreakerState.open:
        // Already open
        break;
    }
  }

  void _open() {
    _state = CircuitBreakerState.open;
    _openedAt = DateTime.now();

    if (kDebugMode) {
      debugPrint('Circuit breaker opened after $_failureCount failures');
    }
  }

  void reset() {
    _state = CircuitBreakerState.closed;
    _failureCount = 0;
    _openedAt = null;
  }

  bool get isOpen => _state == CircuitBreakerState.open;
}

/// Circuit breaker states
enum CircuitBreakerState {
  closed, // Normal operation
  open, // Failing, reject calls
  halfOpen, // Testing if service recovered
}

/// Circuit breaker configuration
class CircuitBreakerConfig {
  final int failureThreshold;
  final Duration resetTimeout;
  final Duration? monitoringWindow;

  const CircuitBreakerConfig({
    required this.failureThreshold,
    required this.resetTimeout,
    this.monitoringWindow,
  });

  factory CircuitBreakerConfig.defaultConfig() {
    return const CircuitBreakerConfig(
      failureThreshold: 5,
      resetTimeout: Duration(seconds: 30),
      monitoringWindow: Duration(minutes: 1),
    );
  }
}

/// Provider error information
class ProviderErrorInfo {
  final String providerId;
  final int errorCount;
  final Object? lastError;
  final DateTime? lastErrorTime;
  final bool isCircuitBreakerOpen;

  ProviderErrorInfo({
    required this.providerId,
    required this.errorCount,
    this.lastError,
    this.lastErrorTime,
    required this.isCircuitBreakerOpen,
  });
}

/// Provider error exception
class ProviderErrorException implements Exception {
  final String message;
  final bool isRetryable;
  final String? code;

  ProviderErrorException(
    this.message, {
    this.isRetryable = true,
    this.code,
  });

  @override
  String toString() => 'ProviderErrorException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Extension for easy provider error recovery integration
extension ProviderErrorRecoveryExtension<T> on AutoDisposeFutureProvider<T> {
  AutoDisposeFutureProvider<T> withErrorRecovery({
    T? fallbackValue,
    RetryPolicy? retryPolicy,
  }) {
    return AutoDisposeFutureProvider<T>((ref) async {
      final recovery = ProviderErrorRecovery();
      final providerId = toString(); // Use provider toString as ID

      recovery.configureProvider(
        providerId: providerId,
        fallbackValue: fallbackValue,
        retryPolicy: retryPolicy,
      );

      return recovery.executeWithRecovery(
        providerId: providerId,
        operation: () => ref.watch(future),
        fallbackValue: fallbackValue,
      );
    });
  }
}

/// Extension for stream providers
///
/// DEPRECATED: This extension uses the deprecated .stream accessor
/// Instead, manually create StreamProviders with async* generators:
///
/// ```dart
/// final myProvider = StreamProvider.autoDispose<T>((ref) async* {
///   final recovery = ProviderErrorRecovery();
///   yield* recovery.streamWithRecovery(
///     providerId: 'my_provider',
///     streamFactory: () async* {
///       final initialData = await ref.watch(sourceProvider.future);
///       yield initialData;
///       ref.listen(sourceProvider, (previous, next) {});
///     },
///     fallbackValue: defaultValue,
///   );
/// });
/// ```
@Deprecated('Use manual async* generator pattern instead - see documentation')
extension StreamProviderErrorRecoveryExtension<T> on AutoDisposeStreamProvider<T> {
  @Deprecated('Use manual async* generator pattern instead')
  AutoDisposeStreamProvider<T> withErrorRecovery({
    T? fallbackValue,
    RetryPolicy? retryPolicy,
  }) {
    return AutoDisposeStreamProvider<T>((ref) {
      final recovery = ProviderErrorRecovery();
      final providerId = toString();

      recovery.configureProvider(
        providerId: providerId,
        fallbackValue: fallbackValue,
        retryPolicy: retryPolicy,
      );

      // NOTE: This uses deprecated .stream accessor
      // ignore: deprecated_member_use
      return recovery.streamWithRecovery(
        providerId: providerId,
        streamFactory: () async* {
          // Workaround: Create async generator from future
          // This is a migration path until this extension is removed
          try {
            final initialValue = await ref.watch(future);
            yield initialValue;
            ref.listen(this, (previous, next) {});
          } catch (e) {
            if (fallbackValue != null) {
              yield fallbackValue;
            }
            rethrow;
          }
        },
        fallbackValue: fallbackValue,
      );
    });
  }
}