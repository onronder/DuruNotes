import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Cache entry with metadata
@immutable
class CacheEntry<T> {
  const CacheEntry({
    required this.value,
    required this.timestamp,
    required this.expiresAt,
    this.eTag,
    this.metadata = const {},
  });

  final T value;
  final DateTime timestamp;
  final DateTime? expiresAt;
  final String? eTag;
  final Map<String, dynamic> metadata;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  Duration get age => DateTime.now().difference(timestamp);

  CacheEntry<T> copyWith({
    T? value,
    DateTime? timestamp,
    DateTime? expiresAt,
    String? eTag,
    Map<String, dynamic>? metadata,
  }) {
    return CacheEntry(
      value: value ?? this.value,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
      eTag: eTag ?? this.eTag,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Cache eviction policy
enum CacheEvictionPolicy {
  /// Least Recently Used
  lru,

  /// Least Frequently Used
  lfu,

  /// First In First Out
  fifo,

  /// Time To Live only
  ttl,
}

/// Cache configuration
@immutable
class CacheConfig {
  const CacheConfig({
    this.maxSize = 100,
    this.defaultTtl = const Duration(minutes: 5),
    this.evictionPolicy = CacheEvictionPolicy.lru,
    this.enableStats = true,
  });

  final int maxSize;
  final Duration defaultTtl;
  final CacheEvictionPolicy evictionPolicy;
  final bool enableStats;
}

/// Generic cache manager
class CacheManager<K, V> {
  CacheManager({
    CacheConfig? config,
  }) : _config = config ?? const CacheConfig();

  final CacheConfig _config;
  final Map<K, CacheEntry<V>> _cache = {};
  final Map<K, int> _accessCount = {};
  final Queue<K> _accessOrder = Queue();

  int _hits = 0;
  int _misses = 0;

  /// Get value from cache
  V? get(K key) {
    final entry = _cache[key];

    if (entry == null) {
      if (_config.enableStats) _misses++;
      return null;
    }

    if (entry.isExpired) {
      _cache.remove(key);
      if (_config.enableStats) _misses++;
      return null;
    }

    if (_config.enableStats) _hits++;
    _updateAccessInfo(key);
    return entry.value;
  }

  /// Put value in cache
  void put(
    K key,
    V value, {
    Duration? ttl,
    String? eTag,
    Map<String, dynamic>? metadata,
  }) {
    // Check if we need to evict
    if (_cache.length >= _config.maxSize && !_cache.containsKey(key)) {
      _evict();
    }

    final now = DateTime.now();
    final expiresAt = ttl != null
        ? now.add(ttl)
        : (_config.defaultTtl != Duration.zero
            ? now.add(_config.defaultTtl)
            : null);

    _cache[key] = CacheEntry(
      value: value,
      timestamp: now,
      expiresAt: expiresAt,
      eTag: eTag,
      metadata: metadata ?? const {},
    );

    _updateAccessInfo(key);
  }

  /// Get or compute value
  Future<V> getOrCompute(
    K key,
    Future<V> Function() compute, {
    Duration? ttl,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = get(key);
      if (cached != null) {
        return cached;
      }
    }

    final value = await compute();
    put(key, value, ttl: ttl);
    return value;
  }

  /// Check if key exists and is not expired
  bool containsKey(K key) {
    final entry = _cache[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      _cache.remove(key);
      return false;
    }
    return true;
  }

  /// Remove specific entry
  void remove(K key) {
    _cache.remove(key);
    _accessCount.remove(key);
    _accessOrder.remove(key);
  }

  /// Clear all cache
  void clear() {
    _cache.clear();
    _accessCount.clear();
    _accessOrder.clear();
    _hits = 0;
    _misses = 0;
  }

  /// Clear expired entries
  void clearExpired() {
    final keysToRemove = <K>[];
    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      remove(key);
    }
  }

  /// Get cache statistics
  CacheStatistics getStats() {
    return CacheStatistics(
      size: _cache.length,
      maxSize: _config.maxSize,
      hits: _hits,
      misses: _misses,
      evictionPolicy: _config.evictionPolicy.name,
    );
  }

  /// Reset statistics
  void resetStats() {
    _hits = 0;
    _misses = 0;
  }

  /// Get all keys
  Iterable<K> get keys => _cache.keys;

  /// Get cache size
  int get size => _cache.length;

  /// Check if cache is full
  bool get isFull => _cache.length >= _config.maxSize;

  /// Get cache info for debugging
  Map<String, dynamic> getDebugInfo() {
    return {
      'size': _cache.length,
      'maxSize': _config.maxSize,
      'policy': _config.evictionPolicy.name,
      'hits': _hits,
      'misses': _misses,
      'hitRate': _hits > 0 ? _hits / (_hits + _misses) : 0.0,
      'entries': _cache.entries.map((e) => {
            'key': e.key.toString(),
            'age': e.value.age.inSeconds,
            'expired': e.value.isExpired,
          }).toList(),
    };
  }

  void _updateAccessInfo(K key) {
    switch (_config.evictionPolicy) {
      case CacheEvictionPolicy.lru:
        _accessOrder.remove(key);
        _accessOrder.addLast(key);
        break;
      case CacheEvictionPolicy.lfu:
        _accessCount[key] = (_accessCount[key] ?? 0) + 1;
        break;
      case CacheEvictionPolicy.fifo:
        if (!_accessOrder.contains(key)) {
          _accessOrder.addLast(key);
        }
        break;
      case CacheEvictionPolicy.ttl:
        // TTL doesn't need access tracking
        break;
    }
  }

  void _evict() {
    K? keyToEvict;

    switch (_config.evictionPolicy) {
      case CacheEvictionPolicy.lru:
        keyToEvict = _accessOrder.isNotEmpty ? _accessOrder.first : null;
        break;

      case CacheEvictionPolicy.lfu:
        if (_accessCount.isNotEmpty) {
          var minCount = double.infinity;
          for (final entry in _accessCount.entries) {
            if (entry.value < minCount) {
              minCount = entry.value.toDouble();
              keyToEvict = entry.key;
            }
          }
        }
        break;

      case CacheEvictionPolicy.fifo:
        keyToEvict = _accessOrder.isNotEmpty ? _accessOrder.first : null;
        break;

      case CacheEvictionPolicy.ttl:
        // Find oldest entry
        DateTime? oldestTime;
        for (final entry in _cache.entries) {
          if (oldestTime == null ||
              entry.value.timestamp.isBefore(oldestTime)) {
            oldestTime = entry.value.timestamp;
            keyToEvict = entry.key;
          }
        }
        break;
    }

    if (keyToEvict != null) {
      remove(keyToEvict);
    }
  }
}

/// Cache statistics
@immutable
class CacheStatistics {
  const CacheStatistics({
    required this.size,
    required this.maxSize,
    required this.hits,
    required this.misses,
    required this.evictionPolicy,
  });

  final int size;
  final int maxSize;
  final int hits;
  final int misses;
  final String evictionPolicy;

  double get hitRate => hits > 0 ? hits / (hits + misses) : 0.0;
  double get fillRate => maxSize > 0 ? size / maxSize : 0.0;

  Map<String, dynamic> toJson() => {
        'size': size,
        'maxSize': maxSize,
        'hits': hits,
        'misses': misses,
        'hitRate': hitRate,
        'fillRate': fillRate,
        'evictionPolicy': evictionPolicy,
      };
}

/// Two-level cache with memory and persistent storage
abstract class TwoLevelCache<K, V> {
  TwoLevelCache({
    CacheConfig? memoryConfig,
    CacheConfig? diskConfig,
  })  : _memoryCache = CacheManager(config: memoryConfig),
        _diskConfig = diskConfig ?? const CacheConfig();

  final CacheManager<K, V> _memoryCache;
  // ignore: unused_field
  final CacheConfig _diskConfig;

  /// Read from persistent storage
  @protected
  Future<V?> readFromDisk(K key);

  /// Write to persistent storage
  @protected
  Future<void> writeToDisk(K key, V value);

  /// Delete from persistent storage
  @protected
  Future<void> deleteFromDisk(K key);

  /// Clear all persistent storage
  @protected
  Future<void> clearDisk();

  /// Get value from cache (memory first, then disk)
  Future<V?> get(K key) async {
    // Check memory cache first
    var value = _memoryCache.get(key);
    if (value != null) {
      return value;
    }

    // Check disk cache
    value = await readFromDisk(key);
    if (value != null) {
      // Promote to memory cache
      _memoryCache.put(key, value);
    }

    return value;
  }

  /// Put value in both caches
  Future<void> put(K key, V value, {Duration? ttl}) async {
    _memoryCache.put(key, value, ttl: ttl);
    await writeToDisk(key, value);
  }

  /// Remove from both caches
  Future<void> remove(K key) async {
    _memoryCache.remove(key);
    await deleteFromDisk(key);
  }

  /// Clear both caches
  Future<void> clear() async {
    _memoryCache.clear();
    await clearDisk();
  }

  /// Get or compute with two-level caching
  Future<V> getOrCompute(
    K key,
    Future<V> Function() compute, {
    Duration? ttl,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await get(key);
      if (cached != null) {
        return cached;
      }
    }

    final value = await compute();
    await put(key, value, ttl: ttl);
    return value;
  }
}

/// Cache invalidation strategies
class CacheInvalidator {
  CacheInvalidator();

  final Set<String> _tags = {};
  final Map<String, Set<String>> _taggedKeys = {};

  /// Tag a key for group invalidation
  void tag(String key, String tag) {
    _tags.add(tag);
    _taggedKeys.putIfAbsent(tag, () => {}).add(key);
  }

  /// Invalidate all keys with a tag
  Set<String> invalidateByTag(String tag) {
    final keys = _taggedKeys[tag] ?? {};
    _taggedKeys.remove(tag);
    if (!_taggedKeys.values.any((set) => set.contains(tag))) {
      _tags.remove(tag);
    }
    return keys;
  }

  /// Clear all tags
  void clearTags() {
    _tags.clear();
    _taggedKeys.clear();
  }

  /// Get all tags
  Set<String> get tags => Set.unmodifiable(_tags);

  /// Get keys for a tag
  Set<String> getKeysForTag(String tag) {
    return Set.unmodifiable(_taggedKeys[tag] ?? {});
  }
}