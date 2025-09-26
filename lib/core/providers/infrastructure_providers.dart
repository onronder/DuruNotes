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
final migrationConfigProvider = Provider<MigrationConfig>((ref) {
  // Start with default config (all features disabled for safety)
  // This can be overridden by feature flags or environment variables
  // MIGRATION: Enabling notes feature for testing
  return MigrationConfigFactory.phase4Provider(
    enableNotes: true,     // ENABLED for domain model migration
    enableFolders: false,  // Will enable after notes work
    enableTemplates: false,  // Will enable after folders work
  );
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