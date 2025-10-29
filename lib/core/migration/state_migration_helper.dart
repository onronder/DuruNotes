import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/data/local/app_db.dart' hide NoteLink;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/entities/template.dart' as domain;
import 'package:duru_notes/domain/entities/task.dart' as domain;
// import 'package:duru_notes/domain/entities/tag.dart' as domain; // Unused
import 'package:duru_notes/infrastructure/mappers/folder_mapper.dart';
import 'package:duru_notes/infrastructure/mappers/template_mapper.dart';
// import 'package:duru_notes/infrastructure/mappers/tag_mapper.dart'; // Unused

/// Production-grade state migration helper for safe provider transitions
/// Handles conversion between legacy and domain entities during migration
class StateMigrationHelper {
  static const String _logTag = 'StateMigrationHelper';

  /// Safely migrate provider state from legacy to domain
  static Future<void> migrateProviderState<TLocal, TDomain>({
    required String providerName,
    required TDomain Function(TLocal) mapper,
    required Ref ref,
    required AutoDisposeFutureProvider<List<TLocal>> localProvider,
    required AutoDisposeFutureProvider<List<TDomain>> domainProvider,
  }) async {
    try {
      debugPrint('[$_logTag] Starting provider migration: $providerName');

      // Get current local state
      final localState = await ref.read(localProvider.future);

      // Convert to domain state
      final domainState = localState.map(mapper).toList();

      // Validate conversion
      if (domainState.length != localState.length) {
        throw MigrationException(
          'State migration failed: count mismatch for $providerName '
          'Expected: ${localState.length}, Got: ${domainState.length}',
        );
      }

      // Cache domain state for immediate use
      ref.invalidate(domainProvider);

      debugPrint(
        '[$_logTag] Successfully migrated provider: $providerName '
        '(${localState.length} items)',
      );
    } catch (e) {
      debugPrint('[$_logTag] Failed to migrate provider: $providerName - $e');
      rethrow;
    }
  }

  /// Convert legacy notes to domain notes with full relationship loading.
  ///
  /// OBSOLETE: kept for historical reference only. The zero-knowledge
  /// encryption model requires asynchronous decryption, which is now handled
  /// by `NotesCoreRepository`. This stub remains so older call sites compile
  /// but it simply returns an empty list.
  static Future<List<domain.Note>> convertNotesToDomain(
    List<LocalNote> localNotes,
    AppDb db,
  ) async {
    debugPrint(
      '[$_logTag] convertNotesToDomain is obsolete – use NotesCoreRepository instead.',
    );
    return const [];
  }

  /// Convert legacy folders to domain folders
  static List<domain.Folder> convertFoldersToDomain(
    List<LocalFolder> localFolders,
  ) {
    return localFolders.map(FolderMapper.toDomain).toList();
  }

  /// Convert legacy templates to domain templates
  static List<domain.Template> convertTemplatesToDomain(
    List<LocalTemplate> localTemplates,
  ) {
    return localTemplates.map(TemplateMapper.toDomain).toList();
  }

  /// Convert legacy tasks to domain tasks.
  ///
  /// OBSOLETE: left in place for binary compatibility. `TaskCoreRepository`
  /// performs the required decryption; this stub signals callers to migrate
  /// by logging and returning an empty list.
  static List<domain.Task> convertTasksToDomain(List<NoteTask> localTasks) {
    debugPrint(
      '[$_logTag] convertTasksToDomain is obsolete – use TaskCoreRepository instead.',
    );
    return const [];
  }

  /// Create a dual-mode provider that switches based on migration config
  static Provider<T> createDualProvider<T>({
    required Provider<T> legacyProvider,
    required Provider<T> domainProvider,
    required String feature,
    required Provider<MigrationConfig> configProvider,
  }) {
    return Provider<T>((ref) {
      final config = ref.watch(configProvider);
      if (config.isFeatureEnabled(feature)) {
        return ref.watch(domainProvider);
      }
      return ref.watch(legacyProvider);
    });
  }

  /// Create a dual-mode future provider
  static FutureProvider<List<T>> createDualFutureProvider<TLocal, T>({
    required FutureProvider<List<TLocal>> legacyProvider,
    required FutureProvider<List<T>> domainProvider,
    required T Function(TLocal) converter,
    required String feature,
    required Provider<MigrationConfig> configProvider,
  }) {
    return FutureProvider<List<T>>((ref) async {
      final config = ref.watch(configProvider);
      if (config.isFeatureEnabled(feature)) {
        return ref.watch(domainProvider.future);
      }

      // Convert legacy data to domain format
      final legacyData = await ref.watch(legacyProvider.future);
      return legacyData.map(converter).toList();
    });
  }

  /// Create a dual-mode stream provider
  ///
  /// NOTE: Riverpod 3.0+ - Using .future.asStream() instead of deprecated .stream
  static StreamProvider<List<T>> createDualStreamProvider<TLocal, T>({
    required StreamProvider<List<TLocal>> legacyProvider,
    required StreamProvider<List<T>> domainProvider,
    required T Function(TLocal) converter,
    required String feature,
    required Provider<MigrationConfig> configProvider,
  }) {
    return StreamProvider<List<T>>((ref) async* {
      final config = ref.watch(configProvider);
      if (config.isFeatureEnabled(feature)) {
        // Riverpod 3.0: Use .future instead of deprecated .stream
        final data = await ref.watch(domainProvider.future);
        yield data;

        // Listen for updates
        ref.listen(domainProvider, (previous, next) {});
      } else {
        // Convert legacy data to domain format
        final legacyData = await ref.watch(legacyProvider.future);
        yield legacyData.map(converter).toList();

        // Listen for updates
        ref.listen(legacyProvider, (previous, next) {});
      }
    });
  }

  /// Validate state consistency between legacy and domain data
  static Future<bool> validateStateConsistency<TLocal, TDomain>({
    required List<TLocal> legacyData,
    required List<TDomain> domainData,
    required String Function(TLocal) getLocalId,
    required String Function(TDomain) getDomainId,
  }) async {
    try {
      // Check counts match
      if (legacyData.length != domainData.length) {
        debugPrint(
          '[$_logTag] Count mismatch: '
          'Legacy=${legacyData.length}, Domain=${domainData.length}',
        );
        return false;
      }

      // Check IDs match
      final legacyIds = legacyData.map(getLocalId).toSet();
      final domainIds = domainData.map(getDomainId).toSet();

      if (!setEquals(legacyIds, domainIds)) {
        debugPrint('[$_logTag] ID mismatch detected');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[$_logTag] Validation error: $e');
      return false;
    }
  }

  /// Perform gradual migration with validation
  static Future<MigrationResult> performGradualMigration({
    required String feature,
    required MigrationConfig currentConfig,
    required Future<void> Function() migrationAction,
    required Future<bool> Function() validationAction,
  }) async {
    try {
      debugPrint('[$_logTag] Starting gradual migration for feature: $feature');

      // Perform the migration action
      await migrationAction();

      // Validate the migration
      final isValid = await validationAction();

      if (!isValid) {
        throw MigrationException(
          'Migration validation failed for feature: $feature',
        );
      }

      // Create updated config
      final updatedConfig = currentConfig.enableFeature(feature);

      debugPrint('[$_logTag] Successfully migrated feature: $feature');

      return MigrationResult.success(
        feature: feature,
        updatedConfig: updatedConfig,
      );
    } catch (e, stack) {
      debugPrint('[$_logTag] Migration failed for feature $feature: $e');

      return MigrationResult.failure(
        feature: feature,
        error: e.toString(),
        stackTrace: stack,
      );
    }
  }

  /// Clear cached provider state for clean migration
  static void invalidateProviders(
    Ref ref,
    List<ProviderBase<Object?>> providers,
  ) {
    try {
      for (final provider in providers) {
        ref.invalidate(provider);
      }
      debugPrint('[$_logTag] Invalidated ${providers.length} providers');
    } catch (e) {
      debugPrint('[$_logTag] Failed to invalidate providers: $e');
    }
  }

  /// Monitor migration performance
  static Future<T> measureMigrationPerformance<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await operation();
      stopwatch.stop();

      debugPrint(
        '[$_logTag] $operationName completed in '
        '${stopwatch.elapsedMilliseconds}ms',
      );

      return result;
    } catch (e) {
      stopwatch.stop();
      debugPrint(
        '[$_logTag] $operationName failed after '
        '${stopwatch.elapsedMilliseconds}ms: $e',
      );
      rethrow;
    }
  }
}

/// Result of a migration operation
class MigrationResult {
  final String feature;
  final bool success;
  final MigrationConfig? updatedConfig;
  final String? error;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  MigrationResult({
    required this.feature,
    required this.success,
    this.updatedConfig,
    this.error,
    this.stackTrace,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory MigrationResult.success({
    required String feature,
    required MigrationConfig updatedConfig,
  }) {
    return MigrationResult(
      feature: feature,
      success: true,
      updatedConfig: updatedConfig,
      timestamp: DateTime.now(),
    );
  }

  factory MigrationResult.failure({
    required String feature,
    required String error,
    StackTrace? stackTrace,
  }) {
    return MigrationResult(
      feature: feature,
      success: false,
      error: error,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'MigrationResult(feature: $feature, success: $success'
        '${error != null ? ', error: $error' : ''})';
  }
}

/// Exception thrown during migration operations
class MigrationException implements Exception {
  final String message;
  final String? feature;

  const MigrationException(this.message, [this.feature]);

  @override
  String toString() {
    return 'MigrationException: $message${feature != null ? ' (feature: $feature)' : ''}';
  }
}
