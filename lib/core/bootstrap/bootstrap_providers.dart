import 'package:duru_notes/core/bootstrap/app_bootstrap.dart';
import 'package:duru_notes/core/config/environment_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/analytics/analytics_factory.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final bootstrapResultProvider = Provider<BootstrapResult>((ref) {
  final environment = EnvironmentConfig.fallback();
  LoggerFactory.initialize();
  AnalyticsFactory.reset();
  AnalyticsFactory.configure(
    config: environment,
    logger: LoggerFactory.instance,
  );
  final analytics = AnalyticsFactory.instance;

  return BootstrapResult(
    environment: environment,
    logger: LoggerFactory.instance,
    analytics: analytics,
    supabaseClient: null,
    firebaseApp: null,
    sentryEnabled: false,
    failures: const [],
    adaptyEnabled: false,
    warnings: const [],
    environmentSource: 'fallback',
    stageDurations: const {},
  );
});

final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((_) {
  return GlobalKey<NavigatorState>();
});

final environmentConfigProvider = Provider<EnvironmentConfig>((ref) {
  return ref.watch(bootstrapResultProvider).environment;
});

final bootstrapLoggerProvider = Provider<AppLogger>((ref) {
  return ref.watch(bootstrapResultProvider).logger;
});

final bootstrapAnalyticsProvider = Provider<AnalyticsService>((ref) {
  return ref.watch(bootstrapResultProvider).analytics;
});

final firebaseAppProvider = Provider<FirebaseApp?>((ref) {
  return ref.watch(bootstrapResultProvider).firebaseApp;
});

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  return ref.watch(bootstrapResultProvider).supabaseClient;
});

final bootstrapFailuresProvider = Provider<List<BootstrapFailure>>((ref) {
  return ref.watch(bootstrapResultProvider).failures;
});

final bootstrapWarningsProvider = Provider<List<String>>((ref) {
  return ref.watch(bootstrapResultProvider).warnings;
});

final bootstrapSentryEnabledProvider = Provider<bool>((ref) {
  return ref.watch(bootstrapResultProvider).sentryEnabled;
});

final bootstrapAdaptyEnabledProvider = Provider<bool>((ref) {
  return ref.watch(bootstrapResultProvider).adaptyEnabled;
});

final bootstrapEnvironmentSourceProvider = Provider<String>((ref) {
  return ref.watch(bootstrapResultProvider).environmentSource;
});
