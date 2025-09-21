import 'dart:async';
import 'dart:convert';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Multi-level cache manager for optimal performance
///
/// Cache Levels:
/// 1. L1: In-memory cache (hot data, LRU eviction)
/// 2. L2: Persistent cache (SharedPreferences for small data)
/// 3. L3: Database cache (indexed queries)
class CacheManager {
  CacheManager({
    required this.maxMemoryItems,
    required this.maxMemorySizeBytes,
    required this.ttlSeconds,
  });

  final int maxMemoryItems;
  final int maxMemorySizeBytes;
  final int ttlSeconds;

  final _logger = LoggerFactory.instance;

  // L1: Memory cache with LRU eviction
  final _memoryCache = LRUCache<String, CacheEntry>(maxSize: 1000);
  final _memorySizeBytes = ValueNotifier<int>(0);

  // L2: Persistent cache
  SharedPreferences? _prefs;

  // Cache statistics
  final _stats = CacheStatistics();

  // Cache invalidation listeners
  final _invalidationListeners = <String, List<VoidCallback>>{};

  /// Initialize the cache manager
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    // Clean up expired entries on startup
    await _cleanupExpiredEntries();

    // Start periodic cleanup
    Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupExpiredEntries();
    });

    _logger.info(
      'CacheManager initialized',
      data: {
        'max_memory_items': maxMemoryItems,
        'max_memory_size_mb': maxMemorySizeBytes / (1024 * 1024),
        'ttl_seconds': ttlSeconds,
      },
    );
  }

  /// Get value from cache (checks all levels)
  Future<T?> get<T>(String key) async {
    _stats.totalRequests++;

    // L1: Check memory cache
    final memoryEntry = _memoryCache.get(key);
    if (memoryEntry != null && !memoryEntry.isExpired) {
      _stats.l1Hits++;
      _stats.calculateHitRates();
      return memoryEntry.value as T?;
    }

    // L2: Check persistent cache
    if (_prefs != null) {
      final persistedJson = _prefs!.getString('cache_$key');
      if (persistedJson != null) {
        try {
          final raw = jsonDecode(persistedJson);
          if (raw is Map<String, dynamic>) {
            final entry = CacheEntry.fromJson(raw);
            if (!entry.isExpired) {
              _stats.l2Hits++;

              // Promote to L1
              _memoryCache.put(key, entry);
              _updateMemorySize(entry);

              _stats.calculateHitRates();
              return entry.value as T?;
            }
          }
        } catch (e) {
          _logger.warning(
            'Failed to deserialize cache entry',
            data: {'error': e.toString(), 'key': key},
          );
        }
      }
    }

    _stats.misses++;
    _stats.calculateHitRates();
    return null;
  }

  /// Put value into cache (writes to appropriate levels)
  Future<void> put<T>(
    String key,
    T value, {
    CacheLevel level = CacheLevel.all,
    int? ttlOverride,
  }) async {
    final entry = CacheEntry(
      key: key,
      value: value,
      timestamp: DateTime.now(),
      ttlSeconds: ttlOverride ?? ttlSeconds,
      sizeBytes: _estimateSize(value),
    );

    // L1: Always write to memory if allowed
    if (level == CacheLevel.all || level == CacheLevel.memory) {
      // Check memory constraints
      if (_shouldEvict(entry)) {
        _evictLRU();
      }

      _memoryCache.put(key, entry);
      _updateMemorySize(entry);
    }

    // L2: Write to persistent storage for important data
    if (level == CacheLevel.all || level == CacheLevel.persistent) {
      if (_prefs != null && _shouldPersist(value)) {
        try {
          final json = jsonEncode(entry.toJson());
          await _prefs!.setString('cache_$key', json);
        } catch (e) {
          _logger.warning(
            'Failed to persist cache entry',
            data: {'error': e.toString(), 'key': key},
          );
        }
      }
    }

    _stats.writes++;
  }

  /// Invalidate cache entry
  Future<void> invalidate(String key) async {
    _memoryCache.remove(key);
    await _prefs?.remove('cache_$key');

    // Notify listeners
    final listeners = _invalidationListeners[key];
    if (listeners != null) {
      for (final listener in listeners) {
        listener();
      }
    }

    _stats.invalidations++;
  }

  /// Invalidate entries matching pattern
  Future<void> invalidatePattern(String pattern) async {
    final regex = RegExp(pattern);

    // Clear from memory cache
    final keysToRemove =
        _memoryCache.keys.where((key) => regex.hasMatch(key)).toList();
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
    }

    // Clear from persistent cache
    if (_prefs != null) {
      final allKeys = _prefs!.getKeys();
      final cacheKeys = allKeys.where(
        (key) => key.startsWith('cache_') && regex.hasMatch(key.substring(6)),
      );
      for (final key in cacheKeys) {
        await _prefs!.remove(key);
      }
    }

    _stats.invalidations += keysToRemove.length;
  }

  /// Clear all cache
  Future<void> clear() async {
    _memoryCache.clear();
    _memorySizeBytes.value = 0;

    if (_prefs != null) {
      final allKeys = _prefs!.getKeys();
      final cacheKeys = allKeys.where((key) => key.startsWith('cache_'));
      for (final key in cacheKeys) {
        await _prefs!.remove(key);
      }
    }

    _stats.reset();

    _logger.info('Cache cleared');
  }

  /// Add invalidation listener
  void addInvalidationListener(String key, VoidCallback listener) {
    _invalidationListeners.putIfAbsent(key, () => []).add(listener);
  }

  /// Remove invalidation listener
  void removeInvalidationListener(String key, VoidCallback listener) {
    _invalidationListeners[key]?.remove(listener);
  }

  /// Get cache statistics
  CacheStatistics get statistics => _stats;

  /// Get current memory usage
  int get memoryUsageBytes => _memorySizeBytes.value;

  // Private helper methods

  bool _shouldEvict(CacheEntry entry) {
    return _memoryCache.length >= maxMemoryItems ||
        _memorySizeBytes.value + entry.sizeBytes > maxMemorySizeBytes;
  }

  void _evictLRU() {
    final oldest = _memoryCache.removeOldest();
    if (oldest != null) {
      _memorySizeBytes.value -= oldest.sizeBytes;
      _stats.evictions++;
    }
  }

  void _updateMemorySize(CacheEntry entry) {
    _memorySizeBytes.value += entry.sizeBytes;
  }

  bool _shouldPersist(dynamic value) {
    // Persist only serializable and reasonably sized data
    if (value == null) return false;
    if (value is! Map &&
        value is! List &&
        value is! String &&
        value is! num &&
        value is! bool) {
      return false;
    }

    final size = _estimateSize(value);
    return size < 100 * 1024; // Don't persist items larger than 100KB
  }

  int _estimateSize(dynamic value) {
    try {
      if (value == null) return 0;
      if (value is String) return value.length * 2; // Approximate UTF-16 size
      if (value is num || value is bool) return 8;

      // For complex objects, serialize and measure
      final json = jsonEncode(value);
      return json.length * 2;
    } catch (e) {
      return 1024; // Default estimate
    }
  }

  Future<void> _cleanupExpiredEntries() async {
    // Clean memory cache
    final expiredKeys = <String>[];
    for (final entry in _memoryCache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _memoryCache.remove(key);
    }

    // Clean persistent cache
    if (_prefs != null) {
      final allKeys = _prefs!.getKeys();
      final cacheKeys = allKeys.where((key) => key.startsWith('cache_'));

      for (final key in cacheKeys) {
        final json = _prefs!.getString(key);
        if (json != null) {
          try {
            final raw = jsonDecode(json);
            if (raw is Map<String, dynamic>) {
              final entry = CacheEntry.fromJson(raw);
              if (entry.isExpired) {
                await _prefs!.remove(key);
              }
            } else {
              await _prefs!.remove(key);
            }
          } catch (_) {
            // Remove corrupted entries
            await _prefs!.remove(key);
          }
        }
      }
    }

    if (expiredKeys.isNotEmpty) {
      _logger.debug('Cleaned up ${expiredKeys.length} expired cache entries');
    }
  }
}

/// Cache entry with metadata
class CacheEntry {
  CacheEntry({
    required this.key,
    required this.value,
    required this.timestamp,
    required this.ttlSeconds,
    required this.sizeBytes,
  });

  final String key;
  final dynamic value;
  final DateTime timestamp;
  final int ttlSeconds;
  final int sizeBytes;

  bool get isExpired {
    final age = DateTime.now().difference(timestamp);
    return age.inSeconds > ttlSeconds;
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        'timestamp': timestamp.toIso8601String(),
        'ttl_seconds': ttlSeconds,
        'size_bytes': sizeBytes,
      };

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      key: json['key'] as String,
      value: json['value'],
      timestamp: DateTime.parse(json['timestamp'] as String),
      ttlSeconds: json['ttl_seconds'] as int,
      sizeBytes: json['size_bytes'] as int,
    );
  }
}

/// LRU (Least Recently Used) cache implementation
class LRUCache<K, V> {
  LRUCache({required this.maxSize});

  final int maxSize;
  final _cache = <K, V>{};

  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value; // Move to end (most recently used)
    }
    return value;
  }

  void put(K key, V value) {
    _cache.remove(key);
    _cache[key] = value;

    if (_cache.length > maxSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  V? remove(K key) {
    return _cache.remove(key);
  }

  V? removeOldest() {
    if (_cache.isEmpty) return null;
    final key = _cache.keys.first;
    return _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }

  int get length => _cache.length;

  Iterable<K> get keys => _cache.keys;

  Iterable<MapEntry<K, V>> get entries => _cache.entries;
}

/// Cache levels for fine-grained control
enum CacheLevel { memory, persistent, all }

/// Cache statistics for monitoring
class CacheStatistics {
  int totalRequests = 0;
  int l1Hits = 0;
  int l2Hits = 0;
  int misses = 0;
  int writes = 0;
  int evictions = 0;
  int invalidations = 0;

  double l1HitRate = 0.0;
  double l2HitRate = 0.0;
  double overallHitRate = 0.0;

  void calculateHitRates() {
    if (totalRequests == 0) return;

    l1HitRate = l1Hits / totalRequests;
    l2HitRate = l2Hits / totalRequests;
    overallHitRate = (l1Hits + l2Hits) / totalRequests;
  }

  void reset() {
    totalRequests = 0;
    l1Hits = 0;
    l2Hits = 0;
    misses = 0;
    writes = 0;
    evictions = 0;
    invalidations = 0;
    l1HitRate = 0.0;
    l2HitRate = 0.0;
    overallHitRate = 0.0;
  }

  Map<String, dynamic> toJson() => {
        'total_requests': totalRequests,
        'l1_hits': l1Hits,
        'l2_hits': l2Hits,
        'misses': misses,
        'writes': writes,
        'evictions': evictions,
        'invalidations': invalidations,
        'l1_hit_rate': (l1HitRate * 100).toStringAsFixed(2),
        'l2_hit_rate': (l2HitRate * 100).toStringAsFixed(2),
        'overall_hit_rate': (overallHitRate * 100).toStringAsFixed(2),
      };
}

/// Specialized cache for folder hierarchy
class FolderHierarchyCache {
  FolderHierarchyCache(this._cacheManager);

  final CacheManager _cacheManager;

  // Cache keys
  static const String _rootFoldersKey = 'folders:root';
  static const String _allFoldersKey = 'folders:all';
  static const String _folderChildrenPrefix = 'folders:children:';
  static const String _folderPathPrefix = 'folders:path:';
  static const String _folderCountPrefix = 'folders:count:';

  Future<List<LocalFolder>?> getRootFolders() async {
    final cached = await _cacheManager.get<List<dynamic>>(_rootFoldersKey);
    if (cached != null) {
      return cached
          .map((json) => LocalFolder.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return null;
  }

  Future<void> setRootFolders(List<LocalFolder> folders) async {
    await _cacheManager.put(
      _rootFoldersKey,
      folders.map((f) => f.toJson()).toList(),
      ttlOverride: 300, // 5 minutes
    );
  }

  Future<List<LocalFolder>?> getChildFolders(String parentId) async {
    final cached = await _cacheManager.get<List<dynamic>>(
      '$_folderChildrenPrefix$parentId',
    );
    if (cached != null) {
      return cached
          .map((json) => LocalFolder.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return null;
  }

  Future<void> setChildFolders(
    String parentId,
    List<LocalFolder> folders,
  ) async {
    await _cacheManager.put(
      '$_folderChildrenPrefix$parentId',
      folders.map((f) => f.toJson()).toList(),
      ttlOverride: 300,
    );
  }

  Future<int?> getFolderNoteCount(String folderId) async {
    return await _cacheManager.get<int>('$_folderCountPrefix$folderId');
  }

  Future<void> setFolderNoteCount(String folderId, int count) async {
    await _cacheManager.put(
      '$_folderCountPrefix$folderId',
      count,
      ttlOverride: 60, // 1 minute
    );
  }

  Future<void> invalidateFolderHierarchy() async {
    await _cacheManager.invalidatePattern(r'^folders:');
  }

  Future<void> invalidateFolderCounts() async {
    await _cacheManager.invalidatePattern(r'^folders:count:');
  }
}

/// Cache manager provider
final cacheManagerProvider = Provider<CacheManager>((ref) {
  final cache = CacheManager(
    maxMemoryItems: 1000,
    maxMemorySizeBytes: 50 * 1024 * 1024, // 50MB
    ttlSeconds: 3600, // 1 hour default TTL
  );

  // Initialize asynchronously
  cache.initialize();

  return cache;
});

/// Folder hierarchy cache provider
final folderHierarchyCacheProvider = Provider<FolderHierarchyCache>((ref) {
  final cacheManager = ref.watch(cacheManagerProvider);
  return FolderHierarchyCache(cacheManager);
});

/// Cache statistics provider
final cacheStatisticsProvider = Provider<CacheStatistics>((ref) {
  final cacheManager = ref.watch(cacheManagerProvider);
  return cacheManager.statistics;
});
