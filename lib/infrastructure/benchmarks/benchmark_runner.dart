import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/parser/note_indexer.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/secure_api_wrapper.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/folder_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/task_core_repository.dart';
import 'package:duru_notes/infrastructure/benchmarks/performance_benchmark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Benchmark runner for database performance testing
class BenchmarkRunner {
  /// Run all performance benchmarks and print results
  static Future<void> runAll({
    required AppDb db,
    required SupabaseClient client,
    required CryptoBox crypto,
    required Ref ref,
  }) async {
    print('\n${'=' * 80}');
    print('🔥 DATABASE PERFORMANCE OPTIMIZATION BENCHMARKS');
    print('${'=' * 80}\n');

    // Initialize repositories
    final noteIndexer = NoteIndexer(ref);
    final secureApi = SecureApiWrapper(client);

    final notesRepo = NotesCoreRepository(
      db: db,
      crypto: crypto,
      client: client,
      indexer: noteIndexer,
      secureApi: secureApi,
    );

    final folderRepo = FolderCoreRepository(
      db: db,
      client: client,
      crypto: crypto,
    );

    final taskRepo = TaskCoreRepository(
      db: db,
      client: client,
      crypto: crypto,
    );

    // Run benchmarks
    final results = await PerformanceBenchmark.runFullSuite(
      notesRepo: notesRepo,
      folderRepo: folderRepo,
      taskRepo: taskRepo,
    );

    // Print report
    print(PerformanceBenchmark.generateReport(results));

    // Generate comparisons with baseline (N+1 pattern)
    print('\n${'=' * 80}');
    print('📈 OPTIMIZATION IMPACT ANALYSIS');
    print('${'=' * 80}\n');

    for (final result in results) {
      if (result.operation.contains('Load') && result.itemCount > 10) {
        // Compare with N+1 baseline (2 queries per item: tags + links)
        final comparison = PerformanceBenchmark.compareWithBaseline(
          optimized: result,
          baselineQueryMultiplier: 2,
        );
        print(comparison.toString());
        print('\n${'-' * 80}\n');
      }
    }

    // Print performance goals
    _printPerformanceGoals(results);
  }

  /// Run specific benchmark
  static Future<BenchmarkResult> runNotesLoadingBenchmark({
    required NotesCoreRepository repository,
    int noteCount = 100,
  }) async {
    print('🔬 Running notes loading benchmark for $noteCount notes...\n');

    final result = await PerformanceBenchmark.benchmarkNoteLoading(
      repository,
      noteCount: noteCount,
    );

    print(result.toString());

    final comparison = PerformanceBenchmark.compareWithBaseline(
      optimized: result,
      baselineQueryMultiplier: 2, // N+1 for tags + links
    );

    print('\n${comparison.toString()}');

    return result;
  }

  /// Validate performance goals
  static void _printPerformanceGoals(List<BenchmarkResult> results) {
    print('=' * 80);
    print('🎯 PERFORMANCE GOALS VALIDATION');
    print('=' * 80 + '\n');

    final goals = {
      'Load 100 notes': {'target_ms': 100, 'target_queries': 10},
      'Search queries': {'target_ms': 100, 'target_queries': 5},
      'Decrypt 100 notes': {'target_ms': 500, 'target_queries': 0},
    };

    for (final result in results) {
      for (final entry in goals.entries) {
        if (result.operation.contains(entry.key)) {
          final targetMs = entry.value['target_ms'] as int;
          final targetQueries = entry.value['target_queries'] as int;

          final durationMet = result.duration.inMilliseconds <= targetMs;
          final queriesMet = result.queryCount <= targetQueries;

          final status = durationMet && queriesMet ? '✅ PASS' : '❌ FAIL';

          print('$status ${entry.key}');
          print('   Duration: ${result.duration.inMilliseconds}ms (target: <${targetMs}ms)');
          print('   Queries: ${result.queryCount} (target: <$targetQueries)');
          print('');
        }
      }
    }

    print('=' * 80 + '\n');
  }

  /// Quick performance check
  static Future<bool> quickCheck({
    required NotesCoreRepository repository,
  }) async {
    print('⚡ Running quick performance check...\n');

    final result = await PerformanceBenchmark.benchmarkNoteLoading(
      repository,
      noteCount: 100,
    );

    final passed = result.duration.inMilliseconds < 100 && result.queryCount <= 10;

    if (passed) {
      print('✅ Performance check PASSED!');
      print('   100 notes loaded in ${result.duration.inMilliseconds}ms with ${result.queryCount} queries');
    } else {
      print('❌ Performance check FAILED!');
      print('   Duration: ${result.duration.inMilliseconds}ms (target: <100ms)');
      print('   Queries: ${result.queryCount} (target: <10)');
    }

    return passed;
  }

  /// Cache effectiveness analysis
  static Future<void> analyzeCacheEffectiveness({
    required NotesCoreRepository repository,
  }) async {
    print('💾 Analyzing cache effectiveness...\n');

    // First load (cold cache)
    final stopwatch1 = Stopwatch()..start();
    await repository.list(limit: 100);
    stopwatch1.stop();
    final coldCacheDuration = stopwatch1.elapsedMilliseconds;

    // Second load (warm cache)
    final stopwatch2 = Stopwatch()..start();
    await repository.list(limit: 100);
    stopwatch2.stop();
    final warmCacheDuration = stopwatch2.elapsedMilliseconds;

    final speedup = coldCacheDuration / warmCacheDuration;

    print('Cold cache: ${coldCacheDuration}ms');
    print('Warm cache: ${warmCacheDuration}ms');
    print('Speedup: ${speedup.toStringAsFixed(2)}x');

    if (speedup >= 2) {
      print('✅ Cache is effective (${speedup.toStringAsFixed(1)}x speedup)');
    } else {
      print('⚠️  Cache impact is minimal (${speedup.toStringAsFixed(1)}x speedup)');
    }
  }
}

/// Example usage
///
/// ```dart
/// await BenchmarkRunner.runAll(
///   db: db,
///   client: supabaseClient,
///   crypto: cryptoBox,
///   ref: ref, // ProviderRef from Riverpod
/// );
/// ```
