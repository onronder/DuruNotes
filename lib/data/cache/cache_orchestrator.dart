import 'dart:async';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/cache/enhanced_cache_strategy.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/models/note_kind.dart';
import 'package:drift/drift.dart';

/// Production-grade cache orchestrator for optimal performance
///
/// This implements sophisticated caching patterns:
/// - Read-through caching with automatic loading
/// - Write-through caching with immediate persistence
/// - Cache-aside pattern for complex queries
/// - Predictive cache warming for better UX
/// - Automatic cache invalidation on writes
class CacheOrchestrator {
  CacheOrchestrator({
    required AppDb db,
    AppLogger? logger,
  })  : _db = db,
        _logger = logger ?? LoggerFactory.instance {
    _initialize();
  }

  final AppDb _db;
  final AppLogger _logger;
  late final EnhancedCacheStrategy _cacheStrategy;

  // Cache warming indicators
  bool _isWarmingCache = false;
  final Set<String> _warmingOperations = <String>{};

  // Performance tracking
  final _operationMetrics = <String, List<int>>{};

  void _initialize() {
    _cacheStrategy = EnhancedCacheStrategy(logger: _logger);
    _startPeriodicCacheOptimization();
    _warmInitialCache();
  }

  // ============================================================================
  // CACHE HELPERS
  // ============================================================================

  /// Cache a note to the strategy
  Future<void> _cacheNote(domain.Note note) async {
    await _cacheStrategy.cacheNote(note.id, _serializeNote(note));
  }

  // ============================================================================
  // READ-THROUGH CACHING PATTERN
  // ============================================================================

  /// Get note with read-through caching
  Future<domain.Note?> getNoteCached({
    required String noteId,
    required Future<domain.Note?> Function() loader,
  }) async {
    final startTime = DateTime.now();

    try {
      // Check cache first
      final cached = await _cacheStrategy.getCachedNote(noteId);
      if (cached != null) {
        _trackOperation('note_cache_hit', startTime);
        return _deserializeNote(cached);
      }

      // Cache miss - load from database
      _trackOperation('note_cache_miss', startTime);
      final note = await loader();

      if (note != null) {
        // Cache the loaded note
        await _cacheNote(note);
      }

      return note;
    } catch (e) {
      _logger.error('[CacheOrchestrator] Failed to get cached note: $e',
          data: {'noteId': noteId});
      // Fallback to direct load
      return await loader();
    }
  }

  /// Get multiple notes with batch caching
  Future<List<domain.Note>> getNotesCached({
    required List<String> noteIds,
    required Future<List<domain.Note>> Function(List<String>) loader,
  }) async {
    final startTime = DateTime.now();
    final results = <domain.Note>[];
    final uncachedIds = <String>[];

    try {
      // Check cache for each note
      for (final noteId in noteIds) {
        final cached = await _cacheStrategy.getCachedNote(noteId);
        if (cached != null) {
          results.add(_deserializeNote(cached));
        } else {
          uncachedIds.add(noteId);
        }
      }

      // Load uncached notes in batch
      if (uncachedIds.isNotEmpty) {
        final loadedNotes = await loader(uncachedIds);

        // Cache loaded notes
        for (final note in loadedNotes) {
          await _cacheNote(note);
          results.add(note);
        }
      }

      _trackOperation('batch_note_load', startTime);
      _logger.debug('[CacheOrchestrator] Batch load complete', data: {
        'total': noteIds.length,
        'cached': noteIds.length - uncachedIds.length,
        'loaded': uncachedIds.length,
      });

      return results;
    } catch (e) {
      _logger.error('[CacheOrchestrator] Batch load failed: $e');
      // Fallback to direct load
      return await loader(noteIds);
    }
  }

  // ============================================================================
  // WRITE-THROUGH CACHING PATTERN
  // ============================================================================

  /// Save note with write-through caching
  Future<domain.Note> saveNoteWithCache({
    required domain.Note note,
    required Future<domain.Note> Function(domain.Note) saver,
  }) async {
    try {
      // Save to database first
      final saved = await saver(note);

      // Update cache immediately
      await _cacheNote(saved);

      // Invalidate related caches
      _invalidateRelatedCaches(saved.id, 'note');

      return saved;
    } catch (e) {
      _logger.error('[CacheOrchestrator] Failed to save note with cache: $e',
          data: {'noteId': note.id});
      rethrow;
    }
  }

  /// Delete note with cache invalidation
  Future<void> deleteNoteWithCache({
    required String noteId,
    required Future<void> Function(String) deleter,
  }) async {
    try {
      // Delete from database
      await deleter(noteId);

      // Invalidate all related caches
      _cacheStrategy.invalidateNoteCache(noteId);
      _invalidateRelatedCaches(noteId, 'note');

    } catch (e) {
      _logger.error('[CacheOrchestrator] Failed to delete note with cache: $e',
          data: {'noteId': noteId});
      rethrow;
    }
  }

  // ============================================================================
  // CACHE-ASIDE PATTERN FOR COMPLEX QUERIES
  // ============================================================================

  /// Search with caching
  Future<List<domain.Note>> searchNotesCached({
    required String query,
    required Map<String, dynamic> filters,
    required Future<List<domain.Note>> Function() searcher,
  }) async {
    final startTime = DateTime.now();

    try {
      // Check cache for search results
      final cached = _cacheStrategy.getCachedSearchResults(query, filters);
      if (cached != null) {
        _trackOperation('search_cache_hit', startTime);
        return cached.map((data) => _deserializeNote(data as Map<String, dynamic>)).toList();
      }

      // Cache miss - execute search
      _trackOperation('search_cache_miss', startTime);
      final results = await searcher();

      // Cache search results
      _cacheStrategy.cacheSearchResults(
        query,
        filters,
        results.map((note) => _serializeNote(note)).toList(),
      );

      return results;
    } catch (e) {
      _logger.error('[CacheOrchestrator] Search failed: $e');
      return [];
    }
  }

  // ============================================================================
  // PREDICTIVE CACHE WARMING
  // ============================================================================

  /// Warm cache with frequently accessed data
  Future<void> warmCache({
    String? userId,
    List<String>? recentNoteIds,
  }) async {
    if (_isWarmingCache) {
      _logger.debug('[CacheOrchestrator] Cache warming already in progress');
      return;
    }

    _isWarmingCache = true;
    final operationId = DateTime.now().millisecondsSinceEpoch.toString();
    _warmingOperations.add(operationId);

    try {
      _logger.info('[CacheOrchestrator] Starting cache warming');

      // Warm recent notes
      if (recentNoteIds != null && recentNoteIds.isNotEmpty) {
        await _warmRecentNotes(recentNoteIds);
      }

      // Warm popular tags
      if (userId != null) {
        await _warmPopularTags(userId);
      }

      // Warm folder structure
      await _warmFolderStructure(userId);

      _logger.info('[CacheOrchestrator] Cache warming completed');

    } catch (e) {
      _logger.warning('[CacheOrchestrator] Cache warming failed: $e');
    } finally {
      _warmingOperations.remove(operationId);
      _isWarmingCache = _warmingOperations.isNotEmpty;
    }
  }

  Future<void> _warmRecentNotes(List<String> noteIds) async {
    try {
      // Load notes in batches to warm cache
      const batchSize = 20;
      for (var i = 0; i < noteIds.length; i += batchSize) {
        final batch = noteIds.skip(i).take(batchSize).toList();

        // This would typically load from repository
        // For now, we're just demonstrating the pattern
        _logger.debug('[CacheOrchestrator] Warming note batch', data: {
          'batchStart': i,
          'batchSize': batch.length,
        });
      }
    } catch (e) {
      _logger.warning('[CacheOrchestrator] Failed to warm recent notes: $e');
    }
  }

  Future<void> _warmPopularTags(String userId) async {
    try {
      // Load and cache popular tags
      final tags = await _db.customSelect('''
        SELECT tag, COUNT(*) as count
        FROM note_tags nt
        INNER JOIN local_notes n ON n.id = nt.note_id
        WHERE n.user_id = ?
        GROUP BY tag
        ORDER BY count DESC
        LIMIT 100
      ''', variables: [Variable.withString(userId)]).get();

      final popularTags = tags.map((row) => row.read<String>('tag')).toList();
      _cacheStrategy.cachePopularTags(userId, popularTags);

      _logger.debug('[CacheOrchestrator] Warmed popular tags', data: {
        'userId': userId,
        'tagCount': popularTags.length,
      });
    } catch (e) {
      _logger.warning('[CacheOrchestrator] Failed to warm popular tags: $e');
    }
  }

  Future<void> _warmFolderStructure(String? userId) async {
    try {
      // Load and cache folder hierarchy
      final folders = await _db.customSelect('''
        SELECT f.*, COUNT(nf.note_id) as note_count
        FROM local_folders f
        LEFT JOIN note_folders nf ON f.id = nf.folder_id
        ${userId != null ? 'WHERE f.user_id = ?' : ''}
        GROUP BY f.id
        ORDER BY f.sort_order
      ''', variables: userId != null ? [Variable.withString(userId)] : []).get();

      for (final row in folders) {
        final folderData = {
          'id': row.read<String>('id'),
          'name': row.read<String>('name'),
          'note_count': row.read<int>('note_count'),
          'parent_id': row.read<String?>('parent_id'),
          'sort_order': row.read<int>('sort_order'),
        };
        _cacheStrategy.cacheFolderWithCount(
          row.read<String>('id'),
          folderData,
        );
      }

      _logger.debug('[CacheOrchestrator] Warmed folder structure', data: {
        'folderCount': folders.length,
      });
    } catch (e) {
      _logger.warning('[CacheOrchestrator] Failed to warm folder structure: $e');
    }
  }

  void _warmInitialCache() {
    // Start initial cache warming in background
    Timer.run(() async {
      await Future<void>.delayed(const Duration(seconds: 2)); // Wait for app to stabilize
      await warmCache();
    });
  }

  // ============================================================================
  // CACHE INVALIDATION
  // ============================================================================

  void _invalidateRelatedCaches(String entityId, String entityType) {
    try {
      switch (entityType) {
        case 'note':
          // Invalidate note-specific caches
          _cacheStrategy.invalidateNoteCache(entityId);
          _cacheStrategy.invalidateTagCaches(entityId);
          break;

        case 'folder':
          // Invalidate folder-specific caches
          _cacheStrategy.invalidateFolderCache(entityId);
          break;

        case 'tag':
          // Invalidate tag-related caches
          _cacheStrategy.invalidateTagCaches(null);
          break;
      }
    } catch (e) {
      _logger.warning('[CacheOrchestrator] Failed to invalidate related caches',
          data: {'entityId': entityId, 'entityType': entityType});
    }
  }

  // ============================================================================
  // PERFORMANCE OPTIMIZATION
  // ============================================================================

  void _startPeriodicCacheOptimization() {
    // Optimize cache every 5 minutes
    Timer.periodic(const Duration(minutes: 5), (_) {
      _optimizeCache();
    });
  }

  void _optimizeCache() {
    try {
      final stats = _cacheStrategy.getCacheStatistics();
      final hitRatio = stats['hit_ratio'] as double;

      if (hitRatio < 0.7) {
        _logger.info('[CacheOrchestrator] Low cache hit ratio detected', data: {
          'hit_ratio': hitRatio,
        });

        // Trigger cache warming for frequently accessed data
        warmCache();
      }

      // Optimize cache performance
      _cacheStrategy.optimizeCachePerformance();

      // Log performance metrics
      _logPerformanceMetrics();

    } catch (e) {
      _logger.warning('[CacheOrchestrator] Cache optimization failed: $e');
    }
  }

  void _trackOperation(String operation, DateTime startTime) {
    final duration = DateTime.now().difference(startTime).inMilliseconds;
    _operationMetrics[operation] ??= <int>[];
    _operationMetrics[operation]!.add(duration);

    // Keep only last 100 metrics per operation
    if (_operationMetrics[operation]!.length > 100) {
      _operationMetrics[operation] = _operationMetrics[operation]!.skip(50).toList();
    }
  }

  void _logPerformanceMetrics() {
    final metrics = <String, dynamic>{};

    for (final entry in _operationMetrics.entries) {
      final durations = entry.value;
      if (durations.isEmpty) continue;

      final avg = durations.reduce((a, b) => a + b) / durations.length;
      final min = durations.reduce((a, b) => a < b ? a : b);
      final max = durations.reduce((a, b) => a > b ? a : b);

      metrics[entry.key] = {
        'avg': avg.round(),
        'min': min,
        'max': max,
        'count': durations.length,
      };
    }

    _logger.info('[CacheOrchestrator] Performance metrics', data: metrics);
  }

  // ============================================================================
  // SERIALIZATION HELPERS
  // ============================================================================

  Map<String, dynamic> _serializeNote(domain.Note note) {
    return {
      'id': note.id,
      'title': note.title,
      'body': note.body,
      'tags': note.tags,
      'updatedAt': note.updatedAt.toIso8601String(),
      'isPinned': note.isPinned,
      'folderId': note.folderId,
      'metadata': note.metadata,
      'deleted': note.deleted,
      'userId': note.userId,
      'version': note.version,
      'noteType': note.noteType,
    };
  }

  domain.Note _deserializeNote(Map<String, dynamic> data) {
    return domain.Note(
      id: data['id'] as String,
      title: data['title'] as String,
      body: data['body'] as String,
      tags: List<String>.from(data['tags'] as List? ?? []),
      createdAt: DateTime.parse(data['createdAt'] as String? ?? data['updatedAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
      isPinned: data['isPinned'] as bool? ?? false,
      folderId: data['folderId'] as String?,
      metadata: data['metadata'] as String?,
      deleted: data['deleted'] as bool? ?? false,
      userId: data['userId'] as String,
      version: data['version'] as int? ?? 1,
      noteType: NoteKind.values[data['noteType'] as int? ?? 0],
    );
  }

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    return {
      ..._cacheStrategy.getCacheStatistics(),
      'is_warming': _isWarmingCache,
      'warming_operations': _warmingOperations.length,
      'operation_metrics': _operationMetrics.map(
        (k, v) => MapEntry(k, {
          'count': v.length,
          'avg_ms': v.isEmpty ? 0 : v.reduce((a, b) => a + b) ~/ v.length,
        }),
      ),
    };
  }

  /// Clear all caches
  void clearAllCaches() {
    _cacheStrategy.clearAllCaches();
    _operationMetrics.clear();
    _logger.info('[CacheOrchestrator] All caches cleared');
  }

  /// Dispose the orchestrator
  void dispose() {
    _cacheStrategy.dispose();
  }
}