import 'dart:async';

/// Cached query result with expiration
class CachedResult<T> {
  CachedResult(this.value, this.ttl)
      : expiresAt = DateTime.now().add(ttl);

  final T value;
  final Duration ttl;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// High-performance query cache with LRU eviction and TTL support
///
/// Features:
/// - Automatic TTL-based expiration
/// - LRU eviction when cache exceeds max size
/// - Thread-safe operation
/// - Hit/miss statistics
class QueryCache {
  QueryCache({
    this.maxEntries = 1000,
    this.defaultTtl = const Duration(minutes: 5),
  });

  final int maxEntries;
  final Duration defaultTtl;
  final _cache = <String, CachedResult<dynamic>>{};
  final _stats = _CacheStats();

  /// Get or compute a cached value
  ///
  /// If the value exists in cache and hasn't expired, returns it.
  /// Otherwise, executes [query] and caches the result.
  Future<T> cached<T>(
    String key,
    Future<T> Function() query, {
    Duration? ttl,
  }) async {
    // Check if we have a valid cached value
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      _stats.recordHit();
      // Move to end (most recently used)
      _cache.remove(key);
      _cache[key] = cached;
      return cached.value as T;
    }

    // Cache miss - execute query
    _stats.recordMiss();
    final result = await query();

    // Store in cache
    _cache[key] = CachedResult(result, ttl ?? defaultTtl);

    // Evict oldest entries if we exceed max size
    _evictIfNeeded();

    return result;
  }

  /// Invalidate a specific cache key
  void invalidate(String key) {
    _cache.remove(key);
  }

  /// Invalidate all keys matching a pattern
  void invalidatePattern(bool Function(String key) predicate) {
    _cache.removeWhere((key, _) => predicate(key));
  }

  /// Clear all cached entries
  void clear() {
    _cache.clear();
    _stats.reset();
  }

  /// Clear expired entries
  int clearExpired() {
    final initialSize = _cache.length;
    _cache.removeWhere((_, value) => value.isExpired);
    return initialSize - _cache.length;
  }

  /// Get cache statistics
  CacheStatistics get statistics => CacheStatistics(
    hitCount: _stats.hits,
    missCount: _stats.misses,
    hitRate: _stats.hitRate,
    size: _cache.length,
    maxSize: maxEntries,
  );

  /// Evict oldest entries if cache exceeds max size
  void _evictIfNeeded() {
    if (_cache.length > maxEntries) {
      final toRemove = _cache.length - maxEntries;
      final keys = _cache.keys.take(toRemove).toList();
      for (final key in keys) {
        _cache.remove(key);
      }
    }
  }
}

/// Cache statistics tracker
class _CacheStats {
  int hits = 0;
  int misses = 0;

  void recordHit() => hits++;
  void recordMiss() => misses++;

  double get hitRate {
    final total = hits + misses;
    return total == 0 ? 0.0 : hits / total;
  }

  void reset() {
    hits = 0;
    misses = 0;
  }
}

/// Immutable cache statistics
class CacheStatistics {
  const CacheStatistics({
    required this.hitCount,
    required this.missCount,
    required this.hitRate,
    required this.size,
    required this.maxSize,
  });

  final int hitCount;
  final int missCount;
  final double hitRate;
  final int size;
  final int maxSize;

  @override
  String toString() {
    return 'CacheStatistics(hits: $hitCount, misses: $missCount, '
           'hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, '
           'size: $size/$maxSize)';
  }
}
