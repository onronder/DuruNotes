import 'package:duru_notes/core/bootstrap/bootstrap_providers.dart'
    show
        bootstrapLoggerProvider,
        bootstrapAnalyticsProvider,
        environmentConfigProvider;
import 'package:duru_notes/core/migration/migration_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/adapty/adapty_service.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client provider - provides access to the Supabase client
/// This provider-based approach allows for better testability and dependency injection
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

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

/// Adapty service provider - handles deferred Adapty initialization
/// CRITICAL: Adapty must be initialized AFTER first frame to prevent main thread blocking
final adaptyServiceProvider = Provider<AdaptyService>((ref) {
  return AdaptyService(
    environment: ref.watch(environmentConfigProvider),
    logger: ref.watch(loggerProvider),
    analytics: ref.watch(analyticsProvider),
  );
});
