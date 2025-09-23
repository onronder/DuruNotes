import 'package:duru_notes/core/bootstrap/bootstrap_error.dart';
import 'package:duru_notes/core/bootstrap/enhanced_app_bootstrap.dart';
import 'package:duru_notes/core/config/config_validator.dart';
import 'package:duru_notes/core/config/environment_config.dart';
import 'package:duru_notes/core/repository/base_repository.dart';
import 'package:duru_notes/core/repository/cache_manager.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 2: Bootstrap Error Handling Tests', () {
    test('Bootstrap error severity levels work correctly', () {
      final warningError = BootstrapError(
        stage: BootstrapStage.analytics,
        error: Exception('Analytics failed'),
        stackTrace: StackTrace.current,
        severity: BootstrapErrorSeverity.warning,
        retryable: true,
      );

      final criticalError = BootstrapError(
        stage: BootstrapStage.supabase,
        error: Exception('Database connection failed'),
        stackTrace: StackTrace.current,
        severity: BootstrapErrorSeverity.critical,
        retryable: false,
      );

      expect(warningError.isCritical, false);
      expect(criticalError.isCritical, true);
      expect(warningError.retryable, true);
      expect(warningError.userDescription, contains('Analytics'));
      expect(criticalError.userDescription, contains('Database'));
    });

    test('Bootstrap error manager tracks errors correctly', () {
      final errorManager = BootstrapErrorManager();

      final error1 = BootstrapError(
        stage: BootstrapStage.firebase,
        error: Exception('Firebase error'),
        stackTrace: StackTrace.current,
        severity: BootstrapErrorSeverity.important,
      );

      final error2 = BootstrapError(
        stage: BootstrapStage.supabase,
        error: Exception('Supabase error'),
        stackTrace: StackTrace.current,
        severity: BootstrapErrorSeverity.critical,
      );

      errorManager.addError(error1);
      errorManager.addError(error2);

      expect(errorManager.errors.length, 2);
      expect(errorManager.hasCriticalErrors, true);
      expect(errorManager.hasFatalErrors, false);
      expect(errorManager.errorsByStage(BootstrapStage.firebase).length, 1);
      expect(errorManager.errorsBySeverity(BootstrapErrorSeverity.critical).length, 1);

      final summary = errorManager.getSummary();
      expect(summary['total'], 2);
      expect(summary['critical'], 1);
    });

    test('Retry recovery strategy works with backoff', () async {
      final retryStrategy = RetryRecoveryStrategy(
        maxRetries: 3,
        delayMs: 100,
        backoffMultiplier: 2.0,
      );

      final error = BootstrapError(
        stage: BootstrapStage.firebase,
        error: Exception('Network error'),
        stackTrace: StackTrace.current,
        severity: BootstrapErrorSeverity.important,
        retryable: true,
      );

      // First retry should be allowed
      expect(retryStrategy.canHandle(error), true);

      final startTime = DateTime.now();
      await retryStrategy.recover(error);
      final elapsed = DateTime.now().difference(startTime);

      // Should have delayed ~100ms
      expect(elapsed.inMilliseconds, greaterThanOrEqualTo(90));

      // Second retry should have longer delay
      expect(retryStrategy.canHandle(error), true);
      await retryStrategy.recover(error);

      // Third retry
      expect(retryStrategy.canHandle(error), true);
      await retryStrategy.recover(error);

      // Fourth retry should not be allowed (max 3)
      expect(retryStrategy.canHandle(error), false);
    });
  });

  group('Phase 2: Configuration Validation Tests', () {
    test('Config validator detects invalid URLs', () {
      final validator = ConfigValidator(
        requireHttps: true,
        allowLocalhost: false,
      );

      final config = EnvironmentConfig(
        environment: Environment.production,
        supabaseUrl: 'http://insecure.supabase.co', // HTTP in production
        supabaseAnonKey: 'test_key_123',
        crashReportingEnabled: true,
        analyticsEnabled: true,
        analyticsSamplingRate: 0.5,
        sentryTracesSampleRate: 0.1,
        enableAutoSessionTracking: true,
        sendDefaultPii: false,
        debugMode: false,
      );

      final result = validator.validate(config);

      expect(result.isValid, false);
      expect(result.securityIssues, isNotEmpty);
      expect(result.securityIssues.first, contains('HTTPS'));
    });

    test('Config validator detects localhost in production', () {
      final validator = ConfigValidator(
        requireHttps: true,
        allowLocalhost: false,
      );

      final config = EnvironmentConfig(
        environment: Environment.production,
        supabaseUrl: 'https://localhost:3000',
        supabaseAnonKey: 'test_key_123',
        crashReportingEnabled: true,
        analyticsEnabled: true,
        analyticsSamplingRate: 0.5,
        sentryTracesSampleRate: 0.1,
        enableAutoSessionTracking: true,
        sendDefaultPii: false,
        debugMode: false,
      );

      final result = validator.validate(config);

      expect(result.isValid, false);
      expect(result.errors, isNotEmpty);
      expect(result.errors.first, contains('Localhost'));
    });

    test('Config validator checks analytics sampling rates', () {
      final validator = ConfigValidator();

      final config = EnvironmentConfig(
        environment: Environment.production,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'valid_key_123',
        crashReportingEnabled: true,
        analyticsEnabled: true,
        analyticsSamplingRate: 1.5, // Invalid: > 1
        sentryTracesSampleRate: -0.1, // Invalid: < 0
        enableAutoSessionTracking: true,
        sendDefaultPii: false,
        debugMode: false,
      );

      final result = validator.validate(config);

      expect(result.errors.length, greaterThanOrEqualTo(2));
      expect(result.errors.any((e) => e.contains('sampling rate')), true);
    });

    test('Config validator warns about production misconfigurations', () {
      final validator = ConfigValidator();

      final config = EnvironmentConfig(
        environment: Environment.production,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'valid_key_123',
        crashReportingEnabled: false, // Warning: disabled in production
        analyticsEnabled: true,
        analyticsSamplingRate: 0.5,
        sentryTracesSampleRate: 0.1,
        enableAutoSessionTracking: true,
        sendDefaultPii: true, // Warning: PII in production
        debugMode: true, // Warning: debug in production
      );

      final result = validator.validate(config);

      expect(result.warnings, isNotEmpty);
      expect(result.warnings.any((w) => w.contains('Debug mode')), true);
      expect(result.warnings.any((w) => w.contains('Crash reporting')), true);
      expect(result.warnings.any((w) => w.contains('PII')), true);
    });
  });

  group('Phase 2: Cache Manager Tests', () {
    test('Cache manager basic operations work', () {
      final cache = CacheManager<String, String>(
        config: const CacheConfig(
          maxSize: 3,
          defaultTtl: Duration(seconds: 5),
        ),
      );

      // Put and get
      cache.put('key1', 'value1');
      expect(cache.get('key1'), 'value1');
      expect(cache.containsKey('key1'), true);
      expect(cache.size, 1);

      // Multiple puts
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');
      expect(cache.size, 3);
      expect(cache.isFull, true);

      // Cache eviction when full
      cache.put('key4', 'value4');
      expect(cache.size, 3); // Still 3, one was evicted
      expect(cache.get('key4'), 'value4');

      // Remove
      cache.remove('key4');
      expect(cache.containsKey('key4'), false);
      expect(cache.size, 2);

      // Clear
      cache.clear();
      expect(cache.size, 0);
    });

    test('Cache TTL expiration works', () async {
      final cache = CacheManager<String, String>(
        config: const CacheConfig(
          defaultTtl: Duration(milliseconds: 100),
        ),
      );

      cache.put('key1', 'value1');
      expect(cache.get('key1'), 'value1');

      // Wait for expiration
      await Future.delayed(const Duration(milliseconds: 150));
      expect(cache.get('key1'), null);
      expect(cache.containsKey('key1'), false);
    });

    test('Cache statistics tracking works', () {
      final cache = CacheManager<String, String>();

      cache.put('key1', 'value1');
      cache.get('key1'); // Hit
      cache.get('key2'); // Miss
      cache.get('key1'); // Hit

      final stats = cache.getStats();
      expect(stats.hits, 2);
      expect(stats.misses, 1);
      expect(stats.hitRate, closeTo(0.666, 0.01));
      expect(stats.size, 1);
    });

    test('Cache eviction policies work correctly', () {
      // LRU eviction
      final lruCache = CacheManager<String, int>(
        config: const CacheConfig(
          maxSize: 2,
          evictionPolicy: CacheEvictionPolicy.lru,
        ),
      );

      lruCache.put('a', 1);
      lruCache.put('b', 2);
      lruCache.get('a'); // Access 'a' to make it more recent
      lruCache.put('c', 3); // Should evict 'b'

      expect(lruCache.get('a'), 1);
      expect(lruCache.get('b'), null); // Evicted
      expect(lruCache.get('c'), 3);

      // FIFO eviction
      final fifoCache = CacheManager<String, int>(
        config: const CacheConfig(
          maxSize: 2,
          evictionPolicy: CacheEvictionPolicy.fifo,
        ),
      );

      fifoCache.put('a', 1);
      fifoCache.put('b', 2);
      fifoCache.put('c', 3); // Should evict 'a' (first in)

      expect(fifoCache.get('a'), null); // Evicted
      expect(fifoCache.get('b'), 2);
      expect(fifoCache.get('c'), 3);
    });

    test('Cache getOrCompute works', () async {
      final cache = CacheManager<String, String>();
      int computeCount = 0;

      // First call computes
      final result1 = await cache.getOrCompute(
        'key1',
        () async {
          computeCount++;
          return 'computed_value';
        },
      );

      expect(result1, 'computed_value');
      expect(computeCount, 1);

      // Second call uses cache
      final result2 = await cache.getOrCompute(
        'key1',
        () async {
          computeCount++;
          return 'computed_value_2';
        },
      );

      expect(result2, 'computed_value'); // Cached value
      expect(computeCount, 1); // Not computed again

      // Force refresh
      final result3 = await cache.getOrCompute(
        'key1',
        () async {
          computeCount++;
          return 'new_value';
        },
        forceRefresh: true,
      );

      expect(result3, 'new_value');
      expect(computeCount, 2);
    });

    test('Cache invalidator tag-based invalidation works', () {
      final cache = CacheManager<String, String>();
      final invalidator = CacheInvalidator();

      cache.put('user:1', 'User 1');
      cache.put('user:2', 'User 2');
      cache.put('post:1', 'Post 1');

      invalidator.tag('user:1', 'users');
      invalidator.tag('user:2', 'users');
      invalidator.tag('post:1', 'posts');

      final invalidatedKeys = invalidator.invalidateByTag('users');
      expect(invalidatedKeys, {'user:1', 'user:2'});

      // In real implementation, you'd remove these from cache
      for (final key in invalidatedKeys) {
        cache.remove(key);
      }

      expect(cache.get('user:1'), null);
      expect(cache.get('user:2'), null);
      expect(cache.get('post:1'), 'Post 1'); // Not invalidated
    });
  });

  group('Phase 2: Repository Pattern Tests', () {
    test('Repository result wrapper works correctly', () {
      const successResult = RepositoryResult<String>.success('data');
      const failureResult = RepositoryResult<String>.failure(
        RepositoryError(message: 'Error occurred'),
      );

      expect(successResult.isSuccess, true);
      expect(successResult.isFailure, false);
      expect(successResult.getOrNull(), 'data');
      expect(successResult.getOrElse('default'), 'data');

      expect(failureResult.isSuccess, false);
      expect(failureResult.isFailure, true);
      expect(failureResult.getOrNull(), null);
      expect(failureResult.getOrElse('default'), 'default');

      // when pattern
      final successMessage = successResult.when(
        success: (data) => 'Success: $data',
        failure: (error) => 'Failed: ${error.message}',
      );
      expect(successMessage, 'Success: data');

      final failureMessage = failureResult.when(
        success: (data) => 'Success: $data',
        failure: (error) => 'Failed: ${error.message}',
      );
      expect(failureMessage, 'Failed: Error occurred');
    });

    test('Repository error includes metadata', () {
      const error = RepositoryError(
        message: 'Database connection failed',
        code: RepositoryErrorCodes.databaseError,
        retryable: true,
      );

      expect(error.message, 'Database connection failed');
      expect(error.code, RepositoryErrorCodes.databaseError);
      expect(error.retryable, true);
      expect(error.toString(), contains('DATABASE_ERROR'));
    });

    test('QuerySpec builds correct query parameters', () {
      const spec = QuerySpec(
        filters: {'status': 'active', 'type': 'user'},
        orderBy: 'createdAt',
        orderDescending: true,
        limit: 10,
        offset: 20,
      );

      expect(spec.filters['status'], 'active');
      expect(spec.filters['type'], 'user');
      expect(spec.orderBy, 'createdAt');
      expect(spec.orderDescending, true);
      expect(spec.limit, 10);
      expect(spec.offset, 20);

      final copied = spec.copyWith(limit: 50);
      expect(copied.limit, 50);
      expect(copied.offset, 20); // Unchanged
    });

    test('Cache statistics calculation', () {
      const stats = CacheStatistics(
        size: 75,
        maxSize: 100,
        hits: 150,
        misses: 50,
        evictionPolicy: 'lru',
      );

      expect(stats.hitRate, 0.75);
      expect(stats.fillRate, 0.75);

      final json = stats.toJson();
      expect(json['hits'], 150);
      expect(json['misses'], 50);
      expect(json['hitRate'], 0.75);
    });
  });

  group('Phase 2: Infrastructure Providers Tests', () {
    test('Infrastructure providers are properly configured', () {
      final container = ProviderContainer();

      // Test fallback values when bootstrap is null
      expect(container.read(bootstrapResultProvider), null);

      final logger = container.read(loggerProvider);
      expect(logger, isNotNull);

      final analytics = container.read(analyticsProvider);
      expect(analytics, isNotNull);

      final navKey = container.read(navigatorKeyProvider);
      expect(navKey, isNotNull);

      expect(container.read(degradedModeProvider), true); // True when no bootstrap
      expect(container.read(offlineModeProvider), true); // True when no bootstrap

      container.dispose();
    });

    test('Provider helper extensions work', () {
      final container = ProviderContainer();

      // Test providers directly
      final logger = container.read(loggerProvider);
      expect(logger, isNotNull);

      final analytics = container.read(analyticsProvider);
      expect(analytics, isNotNull);

      container.dispose();
    });
  });

  group('Phase 2: Integration Tests', () {
    test('Bootstrap error recovery flow works', () async {
      final errorManager = BootstrapErrorManager();

      final retryableError = BootstrapError(
        stage: BootstrapStage.firebase,
        error: Exception('Network timeout'),
        stackTrace: StackTrace.current,
        severity: BootstrapErrorSeverity.important,
        retryable: true,
      );

      errorManager.addError(retryableError);

      // Should be able to recover
      final canRecover = await errorManager.tryRecover(retryableError);
      expect(canRecover, true);

      // Fatal errors cannot be recovered
      final fatalError = BootstrapError(
        stage: BootstrapStage.environment,
        error: Exception('Invalid configuration'),
        stackTrace: StackTrace.current,
        severity: BootstrapErrorSeverity.fatal,
        retryable: false,
      );

      errorManager.addError(fatalError);
      expect(errorManager.hasFatalErrors, true);

      final canRecoverFatal = await errorManager.tryRecover(fatalError);
      expect(canRecoverFatal, false);
    });

    test('Complete cache lifecycle test', () async {
      final cache = CacheManager<String, Map<String, dynamic>>(
        config: const CacheConfig(
          maxSize: 5,
          defaultTtl: Duration(seconds: 1),
          evictionPolicy: CacheEvictionPolicy.lru,
        ),
      );

      // Add items
      for (int i = 0; i < 5; i++) {
        cache.put('item_$i', {'id': i, 'name': 'Item $i'});
      }

      expect(cache.size, 5);
      expect(cache.isFull, true);

      // Access some items to change LRU order
      cache.get('item_0');
      cache.get('item_2');

      // Add new item to trigger eviction
      cache.put('item_5', {'id': 5, 'name': 'Item 5'});

      // Item 1, 3, or 4 should be evicted (least recently used)
      expect(cache.size, 5);
      expect(cache.get('item_0'), isNotNull); // Recently accessed
      expect(cache.get('item_2'), isNotNull); // Recently accessed
      expect(cache.get('item_5'), isNotNull); // Just added

      // Wait for TTL expiration
      await Future.delayed(const Duration(milliseconds: 1100));
      cache.clearExpired();

      // All should be expired except item_5 which was added later
      expect(cache.size, lessThanOrEqualTo(1));

      cache.clear();
      expect(cache.size, 0);

      // Test statistics
      cache.resetStats();
      cache.put('test', {'data': 'value'});
      cache.get('test'); // Hit
      cache.get('missing'); // Miss

      final stats = cache.getStats();
      expect(stats.hits, 1);
      expect(stats.misses, 1);
      expect(stats.hitRate, 0.5);
    });
  });
}