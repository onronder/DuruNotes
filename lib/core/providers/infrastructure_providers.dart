import 'package:duru_notes/core/bootstrap/bootstrap_providers.dart';
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Logger provider
final loggerProvider = Provider<AppLogger>((ref) {
  return ref.watch(bootstrapLoggerProvider);
});

/// Analytics provider
final analyticsProvider = Provider<AnalyticsService>((ref) {
  return ref.watch(bootstrapAnalyticsProvider);
});

/// Migration configuration provider - controls gradual domain model adoption
/// PRODUCTION CONFIG: All features enabled (no live users, fresh start)
final migrationConfigProvider = Provider<MigrationConfig>((ref) {
  // All domain features enabled for production-ready architecture
  // No legacy users to migrate - using domain architecture from start
  return MigrationConfig.developmentConfig(); // All features: true
});

/// Migration status provider - tracks migration progress
final migrationStatusProvider = Provider<Map<String, dynamic>>((ref) {
  final config = ref.watch(migrationConfigProvider);
  return {
    'notes': config.isFeatureEnabled('notes'),
    'folders': config.isFeatureEnabled('folders'),
    'templates': config.isFeatureEnabled('templates'),
    'tasks': config.isFeatureEnabled('tasks'),
    'tags': config.isFeatureEnabled('tags'),
    'search': config.isFeatureEnabled('search'),
    'progress': config.migrationProgress,
    'isValid': config.isValid,
    'version': config.version,
  };
});
