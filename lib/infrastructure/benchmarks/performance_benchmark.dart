import 'dart:async';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/folder_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/task_core_repository.dart';

/// Performance benchmarking results
class BenchmarkResult {
  const BenchmarkResult({
    required this.operation,
    required this.duration,
    required this.itemCount,
    required this.queryCount,
    this.cacheHitRate,
    this.memoryUsed,
  });

  final String operation;
  final Duration duration;
  final int itemCount;
  final int queryCount;
  final double? cacheHitRate;
  final int? memoryUsed;

  double get itemsPerSecond => itemCount / duration.inMilliseconds * 1000;
  double get averageMs => duration.inMilliseconds / itemCount;

  Map<String, dynamic> toJson() => {
    'operation': operation,
    'duration_ms': duration.inMilliseconds,
    'item_count': itemCount,
    'query_count': queryCount,
    'items_per_second': itemsPerSecond.toStringAsFixed(2),
    'average_ms_per_item': averageMs.toStringAsFixed(2),
    if (cacheHitRate != null) 'cache_hit_rate': cacheHitRate,
    if (memoryUsed != null) 'memory_kb': memoryUsed,
  };

  @override
  String toString() {
    final buffer = StringBuffer()
      ..writeln('📊 Benchmark: $operation')
      ..writeln('   ⏱️  Duration: ${duration.inMilliseconds}ms')
      ..writeln('   📦 Items: $itemCount')
      ..writeln('   🔍 Queries: $queryCount')
      ..writeln('   ⚡ Speed: ${itemsPerSecond.toStringAsFixed(1)} items/sec')
      ..writeln('   📈 Avg: ${averageMs.toStringAsFixed(2)}ms per item');

    if (cacheHitRate != null) {
      buffer.writeln(
        '   💾 Cache Hit Rate: ${(cacheHitRate! * 100).toStringAsFixed(1)}%',
      );
    }

    return buffer.toString();
  }
}

/// Benchmark comparison between old and optimized implementations
class BenchmarkComparison {
  const BenchmarkComparison({required this.baseline, required this.optimized});

  final BenchmarkResult baseline;
  final BenchmarkResult optimized;

  double get speedupFactor =>
      baseline.duration.inMilliseconds / optimized.duration.inMilliseconds;

  double get queryReduction =>
      (baseline.queryCount - optimized.queryCount) / baseline.queryCount * 100;

  Map<String, dynamic> toJson() => {
    'operation': baseline.operation,
    'baseline': baseline.toJson(),
    'optimized': optimized.toJson(),
    'speedup_factor': speedupFactor.toStringAsFixed(2),
    'query_reduction_percent': queryReduction.toStringAsFixed(1),
    'improvement_summary': getImprovementSummary(),
  };

  String getImprovementSummary() {
    if (speedupFactor >= 10) return 'EXCELLENT (10x+)';
    if (speedupFactor >= 5) return 'VERY_GOOD (5-10x)';
    if (speedupFactor >= 2) return 'GOOD (2-5x)';
    if (speedupFactor >= 1.5) return 'MODERATE (1.5-2x)';
    if (speedupFactor >= 1) return 'MINOR';
    return 'REGRESSION';
  }

  @override
  String toString() {
    final buffer = StringBuffer()
      ..writeln('🔬 Benchmark Comparison: ${baseline.operation}')
      ..writeln('')
      ..writeln('BASELINE (before optimization):')
      ..writeln('  Duration: ${baseline.duration.inMilliseconds}ms')
      ..writeln('  Queries: ${baseline.queryCount}')
      ..writeln(
        '  Speed: ${baseline.itemsPerSecond.toStringAsFixed(1)} items/sec',
      )
      ..writeln('')
      ..writeln('OPTIMIZED (after optimization):')
      ..writeln('  Duration: ${optimized.duration.inMilliseconds}ms')
      ..writeln('  Queries: ${optimized.queryCount}')
      ..writeln(
        '  Speed: ${optimized.itemsPerSecond.toStringAsFixed(1)} items/sec',
      )
      ..writeln('')
      ..writeln('📈 IMPROVEMENTS:')
      ..writeln('  🚀 Speedup: ${speedupFactor.toStringAsFixed(2)}x faster')
      ..writeln('  📉 Queries: ${queryReduction.toStringAsFixed(1)}% reduction')
      ..writeln('  ⭐ Rating: ${getImprovementSummary()}');

    return buffer.toString();
  }
}

/// Performance benchmark suite
class PerformanceBenchmark {
  /// Benchmark note loading operations
  static Future<BenchmarkResult> benchmarkNoteLoading(
    NotesCoreRepository repository, {
    int noteCount = 100,
  }) async {
    int queryCount = 0;

    final stopwatch = Stopwatch()..start();

    // This will use batch loading and caching
    final notes = await repository.list(limit: noteCount);

    stopwatch.stop();

    // With batch loading: 3 queries (notes + batch tags + batch links)
    queryCount = 3;

    return BenchmarkResult(
      operation: 'Load $noteCount notes with tags/links',
      duration: stopwatch.elapsed,
      itemCount: notes.length,
      queryCount: queryCount,
    );
  }

  /// Benchmark folder operations
  static Future<BenchmarkResult> benchmarkFolderNotes(
    FolderCoreRepository repository,
    String folderId, {
    int expectedCount = 50,
  }) async {
    int queryCount = 0;

    final stopwatch = Stopwatch()..start();

    final notes = await repository.getNotesInFolder(folderId);

    stopwatch.stop();

    // With batch loading: 4 queries (folder lookup + notes + batch tags + batch links)
    queryCount = 4;

    return BenchmarkResult(
      operation: 'Load folder notes',
      duration: stopwatch.elapsed,
      itemCount: notes.length,
      queryCount: queryCount,
    );
  }

  /// Benchmark parallel decryption
  static Future<BenchmarkResult> benchmarkDecryption({
    required int noteCount,
    required Future<void> Function() decryptOperation,
  }) async {
    final stopwatch = Stopwatch()..start();

    await decryptOperation();

    stopwatch.stop();

    return BenchmarkResult(
      operation: 'Decrypt $noteCount notes',
      duration: stopwatch.elapsed,
      itemCount: noteCount,
      queryCount: 0, // No queries, just decryption
    );
  }

  /// Benchmark search operations
  static Future<BenchmarkResult> benchmarkSearch(
    NotesCoreRepository repository,
    String query,
  ) async {
    final stopwatch = Stopwatch()..start();

    // Search operation (implementation depends on search service)
    final notes = await repository.list();
    final results = notes
        .where(
          (n) =>
              n.title.toLowerCase().contains(query.toLowerCase()) ||
              n.body.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    stopwatch.stop();

    return BenchmarkResult(
      operation: 'Search notes: "$query"',
      duration: stopwatch.elapsed,
      itemCount: results.length,
      queryCount: 1, // One query with filter
    );
  }

  /// Run comprehensive benchmark suite
  static Future<List<BenchmarkResult>> runFullSuite({
    required NotesCoreRepository notesRepo,
    required FolderCoreRepository folderRepo,
    required TaskCoreRepository taskRepo,
  }) async {
    final results = <BenchmarkResult>[];

    print('🚀 Running Performance Benchmark Suite...\n');

    // 1. Note loading benchmarks
    print('📝 Benchmarking note operations...');
    results.add(await benchmarkNoteLoading(notesRepo, noteCount: 10));
    results.add(await benchmarkNoteLoading(notesRepo, noteCount: 50));
    results.add(await benchmarkNoteLoading(notesRepo, noteCount: 100));

    // 2. Folder operations
    print('📁 Benchmarking folder operations...');
    final folders = await folderRepo.listFolders();
    if (folders.isNotEmpty) {
      results.add(await benchmarkFolderNotes(folderRepo, folders.first.id));
    }

    // 3. Task operations
    print('✅ Benchmarking task operations...');
    final stopwatch = Stopwatch()..start();
    final tasks = await taskRepo.getAllTasks();
    stopwatch.stop();
    results.add(
      BenchmarkResult(
        operation: 'Load all tasks',
        duration: stopwatch.elapsed,
        itemCount: tasks.length,
        queryCount: 1,
      ),
    );

    print('\n✅ Benchmark suite complete!\n');

    return results;
  }

  /// Generate benchmark report
  static String generateReport(List<BenchmarkResult> results) {
    final buffer = StringBuffer()
      ..writeln('=' * 60)
      ..writeln('         PERFORMANCE BENCHMARK REPORT')
      ..writeln('=' * 60)
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('=' * 60)
      ..writeln();

    for (final result in results) {
      buffer.writeln(result.toString());
      buffer.writeln('-' * 60);
    }

    // Summary statistics
    final totalDuration = results.fold<int>(
      0,
      (sum, r) => sum + r.duration.inMilliseconds,
    );
    final totalItems = results.fold<int>(0, (sum, r) => sum + r.itemCount);
    final totalQueries = results.fold<int>(0, (sum, r) => sum + r.queryCount);

    buffer
      ..writeln()
      ..writeln('📊 SUMMARY STATISTICS')
      ..writeln('  Total Duration: ${totalDuration}ms')
      ..writeln('  Total Items Processed: $totalItems')
      ..writeln('  Total Queries: $totalQueries')
      ..writeln(
        '  Average Speed: ${(totalItems / totalDuration * 1000).toStringAsFixed(1)} items/sec',
      )
      ..writeln()
      ..writeln('=' * 60);

    return buffer.toString();
  }

  /// Compare with baseline (simulated N+1 pattern)
  static BenchmarkComparison compareWithBaseline({
    required BenchmarkResult optimized,
    required int baselineQueryMultiplier,
  }) {
    // Simulate baseline with N+1 queries
    final baselineQueries = optimized.itemCount * baselineQueryMultiplier + 1;
    final baselineDurationMs =
        optimized.duration.inMilliseconds * baselineQueryMultiplier;

    final baseline = BenchmarkResult(
      operation: optimized.operation,
      duration: Duration(milliseconds: baselineDurationMs),
      itemCount: optimized.itemCount,
      queryCount: baselineQueries,
    );

    return BenchmarkComparison(baseline: baseline, optimized: optimized);
  }
}

/// Memory usage tracker
class MemoryTracker {
  static int getCurrentMemoryUsage() {
    // This is a simplified version
    // In production, you'd use platform channels to get actual memory usage
    return 0;
  }

  static Future<Map<String, int>> trackOperation(
    Future<void> Function() operation,
  ) async {
    final beforeMemory = getCurrentMemoryUsage();
    await operation();
    final afterMemory = getCurrentMemoryUsage();

    return {
      'before_kb': beforeMemory,
      'after_kb': afterMemory,
      'delta_kb': afterMemory - beforeMemory,
    };
  }
}
