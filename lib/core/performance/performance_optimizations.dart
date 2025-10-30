/// Performance optimization utilities for Duru Notes
///
/// This file contains various performance optimization techniques
/// to ensure smooth and efficient app operation.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Debouncer for search and other frequent operations
class Debouncer {
  Debouncer({required this.milliseconds});
  final int milliseconds;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Throttler for scroll and gesture events
class Throttler {
  Throttler({required this.milliseconds});
  final int milliseconds;
  Timer? _timer;
  bool _canRun = true;

  void run(VoidCallback action) {
    if (!_canRun) return;

    action();
    _canRun = false;

    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), () {
      _canRun = true;
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Memory cache with size limit and LRU eviction
class LRUCache<K, V> {
  LRUCache({required this.maxSize});
  final int maxSize;
  final Map<K, V> _cache = {};
  final List<K> _keys = [];

  V? get(K key) {
    final value = _cache[key];
    if (value != null) {
      _keys.remove(key);
      _keys.add(key);
    }
    return value;
  }

  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _keys.remove(key);
    } else if (_cache.length >= maxSize) {
      final evictKey = _keys.removeAt(0);
      _cache.remove(evictKey);
    }
    _cache[key] = value;
    _keys.add(key);
  }

  void clear() {
    _cache.clear();
    _keys.clear();
  }

  int get size => _cache.length;
}

/// Image cache manager for attachments
class ImageCacheManager {
  factory ImageCacheManager() => _instance;
  ImageCacheManager._internal();
  static final ImageCacheManager _instance = ImageCacheManager._internal();

  final LRUCache<String, Uint8List> _memoryCache = LRUCache(maxSize: 50);

  Future<Uint8List?> getCachedImage(String key) async {
    return _memoryCache.get(key);
  }

  void cacheImage(String key, Uint8List imageData) {
    // Only cache images smaller than 5MB
    if (imageData.length < 5 * 1024 * 1024) {
      _memoryCache.put(key, imageData);
    }
  }

  void clearCache() {
    _memoryCache.clear();
  }
}

/// Lazy loading widget for heavy content
class LazyLoadWidget extends StatefulWidget {
  const LazyLoadWidget({
    required this.builder,
    super.key,
    this.placeholder = const CircularProgressIndicator(),
    this.delay = const Duration(milliseconds: 100),
  });
  final Widget Function() builder;
  final Widget placeholder;
  final Duration delay;

  @override
  State<LazyLoadWidget> createState() => _LazyLoadWidgetState();
}

class _LazyLoadWidgetState extends State<LazyLoadWidget> {
  late Future<Widget> _widgetFuture;

  @override
  void initState() {
    super.initState();
    _widgetFuture = Future<Widget>.delayed(widget.delay, widget.builder);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _widgetFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.data!;
        }
        return Center(child: widget.placeholder);
      },
    );
  }
}

/// Optimized list view with viewport caching
class OptimizedListView extends StatelessWidget {
  const OptimizedListView({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
    this.controller,
    this.padding,
  });
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final ScrollController? controller;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      // Performance optimizations
      addAutomaticKeepAlives: false,
      cacheExtent: 200, // Cache 200 pixels outside viewport
      physics: const BouncingScrollPhysics(),
    );
  }
}

/// Frame rate monitor for development
class FrameRateMonitor extends StatefulWidget {
  const FrameRateMonitor({required this.child, super.key});
  final Widget child;

  @override
  State<FrameRateMonitor> createState() => _FrameRateMonitorState();
}

class _FrameRateMonitorState extends State<FrameRateMonitor> {
  double _fps = 60;
  int _frameCount = 0;
  DateTime _lastTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      SchedulerBinding.instance.addPostFrameCallback(_onFrame);
    }
  }

  void _onFrame(Duration duration) {
    _frameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(_lastTime).inMilliseconds;

    if (elapsed >= 1000) {
      setState(() {
        _fps = (_frameCount * 1000 / elapsed).clamp(0, 120);
        _frameCount = 0;
        _lastTime = now;
      });
    }

    SchedulerBinding.instance.addPostFrameCallback(_onFrame);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (kDebugMode)
          Positioned(
            top: 50,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _fps < 30
                    ? Colors.red.withValues(alpha: 0.8)
                    : _fps < 50
                    ? Colors.orange.withValues(alpha: 0.8)
                    : Colors.green.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'FPS: ${_fps.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Batch operation executor for database operations
class BatchOperationExecutor<T> {
  BatchOperationExecutor({
    required this.executor,
    this.batchDelay = const Duration(milliseconds: 500),
    this.maxBatchSize = 50,
  });
  final Future<void> Function(List<T>) executor;
  final Duration batchDelay;
  final int maxBatchSize;

  final List<T> _queue = [];
  Timer? _timer;

  void add(T item) {
    _queue.add(item);

    if (_queue.length >= maxBatchSize) {
      _executeBatch();
    } else {
      _scheduleBatch();
    }
  }

  void _scheduleBatch() {
    _timer?.cancel();
    _timer = Timer(batchDelay, _executeBatch);
  }

  Future<void> _executeBatch() async {
    if (_queue.isEmpty) return;

    final batch = List<T>.from(_queue);
    _queue.clear();
    _timer?.cancel();

    try {
      await executor(batch);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Batch operation failed: $e');
      }
    }
  }

  void dispose() {
    _timer?.cancel();
    if (_queue.isNotEmpty) {
      _executeBatch();
    }
  }
}

/// Memory pressure monitor
class MemoryPressureMonitor {
  static void startMonitoring() {
    if (!kDebugMode) return;

    Timer.periodic(const Duration(seconds: 30), (timer) {
      final memoryUsage = ProcessInfo.currentRss / 1024 / 1024; // Convert to MB

      if (memoryUsage > 500) {
        debugPrint(
          '⚠️ High memory usage: ${memoryUsage.toStringAsFixed(2)} MB',
        );
        // Trigger cleanup
        imageCache.clear();
        ImageCacheManager().clearCache();
      }
    });
  }
}

/// Performance tips and best practices
class PerformanceTips {
  static const List<String> tips = [
    'Use const constructors wherever possible',
    'Avoid rebuilding widgets unnecessarily',
    'Use RepaintBoundary for complex widgets',
    'Implement pagination for large lists',
    'Cache network images',
    'Use IndexedStack for tab navigation',
    'Minimize setState() scope',
    'Use ValueListenableBuilder for single value changes',
    'Implement lazy loading for heavy content',
    'Use isolates for heavy computations',
    'Profile your app regularly',
    'Monitor memory usage',
    'Optimize image sizes',
    'Use efficient data structures',
    'Batch database operations',
  ];
}

// Extension methods for performance
extension PerformanceExtensions on Widget {
  /// Wrap widget with RepaintBoundary for performance
  Widget withRepaintBoundary() {
    return RepaintBoundary(child: this);
  }

  /// Wrap widget with lazy loading
  Widget withLazyLoad({Duration delay = const Duration(milliseconds: 100)}) {
    return LazyLoadWidget(builder: () => this, delay: delay);
  }

  /// Add hero animation
  Widget withHero(String tag) {
    return Hero(tag: tag, child: this);
  }
}
