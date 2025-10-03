import 'dart:async';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Simple in-memory cache for query results
class QueryCache<K, V> {
  QueryCache({
    required this.name,
    this.maxSize = 100,
    this.ttl = const Duration(minutes: 5),
    AppLogger? logger,
  }) : _logger = logger ?? LoggerFactory.instance;

  final String name;
  final int maxSize;
  final Duration ttl;
  final AppLogger _logger;

  final Map<K, _CacheEntry<V>> _cache = <String, dynamic>{};
  final List<K> _accessOrder = <dynamic>[];

  /// Get a value from cache
  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) {
      _logger.debug('[QueryCache:$name] Cache miss', data: {'key': key});
      return null;
    }

    // Check if expired
    if (entry.isExpired) {
      _logger.debug('[QueryCache:$name] Cache expired', data: {'key': key});
      _cache.remove(key);
      _accessOrder.remove(key);
      return null;
    }

    // Update access order (LRU)
    _accessOrder.remove(key);
    _accessOrder.add(key);

    _logger.debug('[QueryCache:$name] Cache hit', data: {'key': key});
    return entry.value;
  }

  /// Store a value in cache
  void set(K key, V value) {
    // Remove if exists to update access order
    if (_cache.containsKey(key)) {
      _accessOrder.remove(key);
    }

    // Add to cache
    _cache[key] = _CacheEntry(value: value, expiresAt: DateTime.now().add(ttl));
    _accessOrder.add(key);

    // Evict old entries if cache is full
    while (_accessOrder.length > maxSize) {
      final oldestKey = _accessOrder.removeAt(0);
      _cache.remove(oldestKey);
      _logger.debug('[QueryCache:$name] Evicted old entry', data: {'key': oldestKey});
    }

    _logger.debug('[QueryCache:$name] Cached value', data: {
      'key': key,
      'cacheSize': _cache.length,
    });
  }

  /// Get or compute a value
  Future<V> getOrCompute(K key, Future<V> Function() compute) async {
    final cached = get(key);
    if (cached != null) return cached;

    final value = await compute();
    set(key, value);
    return value;
  }

  /// Invalidate a specific key
  void invalidate(K key) {
    _cache.remove(key);
    _accessOrder.remove(key);
    _logger.debug('[QueryCache:$name] Invalidated key', data: {'key': key});
  }

  /// Invalidate keys matching a predicate
  void invalidateWhere(bool Function(K key) predicate) {
    final keysToRemove = _cache.keys.where(predicate).toList();
    for (final key in keysToRemove) {
      invalidate(key);
    }
    _logger.debug('[QueryCache:$name] Invalidated matching keys', data: {
      'count': keysToRemove.length,
    });
  }

  /// Clear the entire cache
  void clear() {
    _cache.clear();
    _accessOrder.clear();
    _logger.info('[QueryCache:$name] Cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final expired = _cache.entries.where((e) => e.value.expiresAt.isBefore(now)).length;

    return {
      'name': name,
      'size': _cache.length,
      'maxSize': maxSize,
      'expired': expired,
      'ttl': ttl.inSeconds,
    };
  }
}

class _CacheEntry<V> {
  const _CacheEntry({
    required this.value,
    required this.expiresAt,
  });

  final V value;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Manages multiple caches
class CacheManager {
  CacheManager({AppLogger? logger})
      : _logger = logger ?? LoggerFactory.instance;

  final AppLogger _logger;
  final Map<String, QueryCache> _caches = <String, dynamic>{};

  /// Register a new cache
  QueryCache<K, V> registerCache<K, V>({
    required String name,
    int maxSize = 100,
    Duration ttl = const Duration(minutes: 5),
  }) {
    if (_caches.containsKey(name)) {
      _logger.warning('[CacheManager] Cache already registered', data: {'name': name});
      return _caches[name] as QueryCache<K, V>;
    }

    final cache = QueryCache<K, V>(
      name: name,
      maxSize: maxSize,
      ttl: ttl,
      logger: _logger,
    );

    _caches[name] = cache;
    _logger.info('[CacheManager] Cache registered', data: {
      'name': name,
      'maxSize': maxSize,
      'ttl': ttl.inSeconds,
    });

    return cache;
  }

  /// Get a registered cache
  QueryCache<K, V>? getCache<K, V>(String name) {
    return _caches[name] as QueryCache<K, V>?;
  }

  /// Clear all caches
  void clearAll() {
    for (final cache in _caches.values) {
      cache.clear();
    }
    _logger.info('[CacheManager] All caches cleared');
  }

  /// Get statistics for all caches
  List<Map<String, dynamic>> getAllStats() {
    return _caches.values.map((cache) => cache.getStats()).toList();
  }

  /// Dispose all caches
  void dispose() {
    clearAll();
    _caches.clear();
    _logger.info('[CacheManager] Cache manager disposed');
  }
}