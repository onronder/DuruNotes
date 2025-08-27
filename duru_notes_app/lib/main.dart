import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/environment_config.dart';
import 'core/monitoring/app_logger.dart';
import 'services/analytics/analytics_service.dart';

// Global navigation key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global instances (will be initialized)
late AppLogger logger;
late AnalyticsService analytics;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize environment configuration
    await EnvironmentConfig.initialize();
    
    if (EnvironmentConfig.current.debugMode) {
      print('Environment: ${EnvironmentConfig.current.currentEnvironment.name}');
      print('Debug Mode: ${EnvironmentConfig.current.debugMode}');
      print('Sentry Configured: ${EnvironmentConfig.current.isSentryConfigured}');
    }

    // Validate configuration
    if (!EnvironmentConfig.validateConfig()) {
      throw Exception('Invalid environment configuration');
    }

    // Initialize Supabase
    await Supabase.initialize(
      url: EnvironmentConfig.current.supabaseUrl,
      anonKey: EnvironmentConfig.current.supabaseAnonKey,
      debug: EnvironmentConfig.current.debugMode,
    );

    // Initialize services
    await _initializeServices();

    if (EnvironmentConfig.current.debugMode) {
      print('📊 Config Summary: ${EnvironmentConfig.getSafeConfigSummary()}');
    }

    // Track app launch
    analytics.event(AnalyticsEvents.noteCreate, properties: {
      'environment': EnvironmentConfig.current.currentEnvironment.name,
      'debug_mode': EnvironmentConfig.current.debugMode,
    });

  } catch (e, stackTrace) {
    print('❌ Initialization Error: $e');
    if (kDebugMode) {
      print('Stack trace: $stackTrace');
    }
  }

  // Run the app
  runApp(
    ProviderScope(
      child: App(navigatorKey: navigatorKey),
    ),
  );
}

/// Initialize all services
Future<void> _initializeServices() async {
  // Initialize logger
  LoggerFactory.initialize();
  logger = LoggerFactory.instance;

  // Initialize analytics
  AnalyticsFactory.initialize();
  analytics = AnalyticsFactory.instance;

  // Initialize Adapty SDK
  try {
    await Adapty().activate(
      configuration: AdaptyConfiguration(
        apiKey: 'public_live_auSluPc0.Qso83VlJGyzNxUmeZn6j',
      ),
    );
    logger.info('Adapty SDK initialized successfully');
  } catch (e) {
    logger.error('Failed to initialize Adapty SDK: $e');
  }

  logger.info('Services initialized successfully');
}