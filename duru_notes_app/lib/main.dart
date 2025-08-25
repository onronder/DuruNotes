import 'dart:async';
import 'dart:convert';

import 'package:duru_notes_app/app/app.dart';
import 'package:duru_notes_app/core/config/environment_config.dart';
import 'package:duru_notes_app/core/monitoring/app_logger.dart';
import 'package:duru_notes_app/services/analytics/analytics_service.dart';
import 'package:duru_notes_app/services/analytics/analytics_sentry.dart';
import 'package:duru_notes_app/services/reminder_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;

// Global notification plugin instance
final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

// Navigation key for deep linking
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize environment configuration
    await EnvironmentConfig.initialize();
    
    if (kDebugMode) {
      print('🚀 Initializing Duru Notes');
      print('Environment: ${EnvironmentConfig.currentEnvironment.name}');
      print('Debug Mode: ${EnvironmentConfig.debugMode}');
      print('Sentry Configured: ${EnvironmentConfig.isSentryConfigured}');
    }
    
    // Validate configuration before proceeding
    if (!EnvironmentConfig.validateConfig()) {
      throw Exception('Invalid environment configuration');
    }
    
    // Initialize monitoring and analytics services
    await _initializeServices();
    
    // Initialize notifications
    await _initializeNotifications();
    
    // Initialize Supabase with environment-specific settings
    await Supabase.initialize(
      url: EnvironmentConfig.supabaseUrl,
      anonKey: EnvironmentConfig.supabaseAnonKey,
      debug: EnvironmentConfig.debugMode,
    );
    
    logger.info('Supabase initialized successfully');
    
    if (kDebugMode) {
      print('✅ All services initialized successfully');
      print('📊 Config Summary: ${EnvironmentConfig.getSafeConfigSummary()}');
    }
    
    // Track app launch
    analytics.event(AnalyticsEvents.appLaunch, properties: {
      'environment': EnvironmentConfig.currentEnvironment.name,
      'debug_mode': EnvironmentConfig.debugMode,
    });
    
    _runAppWithErrorHandling();
    
  } catch (error, stackTrace) {
    if (kDebugMode) {
      print('❌ Failed to initialize app: $error');
      print('Stack trace: $stackTrace');
    }
    
    // Show error screen for critical initialization failures
    runApp(
      MaterialApp(
        title: 'Duru Notes - Initialization Error',
        home: Scaffold(
          backgroundColor: Colors.red[50],
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Initialization Error',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to start the application. Please check your configuration.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red[700],
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Error: $error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Initialize monitoring and analytics services
Future<void> _initializeServices() async {
  // Initialize logger factory
  LoggerFactory.initialize(useSentry: EnvironmentConfig.isSentryConfigured);
  
  // Initialize analytics
  await AnalyticsFactory.initialize();
  
  logger.info('Monitoring services initialized', data: {
    'sentryConfigured': EnvironmentConfig.isSentryConfigured,
    'analyticsEnabled': EnvironmentConfig.analyticsEnabled,
  });
}

/// Initialize notification system
Future<void> _initializeNotifications() async {
  try {
    // Initialize timezone data
    tz.initializeTimeZones();
    
    // Initialize the notifications plugin
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // We'll request this manually when needed
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    logger.info('Notification system initialized');
          analytics.event('app.feature_enabled', properties: {
        'feature': 'notifications',
      });
    
  } catch (e, stack) {
    logger.error('Failed to initialize notifications', error: e, stackTrace: stack);
    // Don't rethrow - app should still work without notifications
  }
}

/// Handle notification tap - deep link to the note
void _onNotificationTapped(NotificationResponse response) {
  try {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    
    // Parse the payload to get noteId
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final noteId = data['noteId'] as String?;
    
    if (noteId != null) {
      logger.info('Notification tapped - navigating to note', data: {
        'noteId': noteId,
      });
      
      analytics.event('reminder.notification_tapped', properties: {
        'note_id_present': true,
      });
      
      // Navigate to the note
      _navigateToNote(noteId);
    }
  } catch (e, stack) {
    logger.error('Failed to handle notification tap', error: e, stackTrace: stack);
    analytics.event('reminder.notification_tap_error', properties: {
      'error': e.toString(),
    });
  }
}

/// Navigate to a specific note
void _navigateToNote(String noteId) {
  final navigator = navigatorKey.currentState;
  if (navigator == null) {
    logger.warn('Navigator not available for deep linking');
    return;
  }
  
  // We'll implement the actual navigation in the App widget
  // For now, just log the intention
  logger.info('Deep link navigation requested', data: {
    'noteId': noteId,
  });
  
  // TODO: Implement actual navigation to EditNoteScreen
  // This will be handled in the App widget by storing the pending noteId
  // and navigating once the app is ready
}

/// Run the app with Sentry error handling if configured
void _runAppWithErrorHandling() {
  if (EnvironmentConfig.isSentryConfigured) {
    _runAppWithSentry();
  } else {
    _runAppWithoutSentry();
  }
}

/// Run app with Sentry error handling
void _runAppWithSentry() {
  SentryFlutter.init(
    (options) {
      options.dsn = EnvironmentConfig.sentryDsn;
      options.environment = EnvironmentConfig.currentEnvironment.name;
      options.tracesSampleRate = EnvironmentConfig.sentryTracesSampleRate;
      options.profilesSampleRate = 0.0; // Disable profiling by default
      options.enableAutoSessionTracking = EnvironmentConfig.enableAutoSessionTracking;
      options.sendDefaultPii = EnvironmentConfig.sendDefaultPii;
      options.attachStacktrace = true;
      options.enableAutoPerformanceTracing = false; // We'll do manual performance tracking
      
      // Add release information
      options.release = 'duru-notes@1.0.0+1';
      
      // Configure beforeSend to filter events
      options.beforeSend = (SentryEvent event, Hint hint) {
        // Allow all events in development for testing
        // In production, you might want to add additional filtering here
        if (kDebugMode) {
          print('🔍 Sentry event: ${event.message} (env: ${EnvironmentConfig.currentEnvironment.name})');
        }
        
        return event;
      };
      
      if (kDebugMode) {
        print('🔍 Sentry initialized for ${options.environment}');
        print('📊 Traces sample rate: ${options.tracesSampleRate}');
      }
    },
    appRunner: () {
      // Set up global error handlers
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        
        logger.error(
          'Flutter framework error',
          error: details.exception,
          stackTrace: details.stack,
          data: {
            'library': details.library,
            'context': details.context?.toString(),
          },
        );
        
        Sentry.captureException(
          details.exception,
          stackTrace: details.stack,
                      withScope: (scope) {
              scope.level = SentryLevel.error;
              scope.setTag('error_source', 'flutter_framework');
              scope.setTag('library', details.library ?? 'unknown');
            },
        );
      };
      
      // Catch errors not caught by Flutter framework
      runZonedGuarded(
        () => runApp(ProviderScope(child: App(navigatorKey: navigatorKey))),
        (error, stackTrace) {
          logger.error(
            'Uncaught zone error',
            error: error,
            stackTrace: stackTrace,
          );
          
          Sentry.captureException(
            error,
            stackTrace: stackTrace,
            withScope: (scope) {
              scope.level = SentryLevel.fatal;
              scope.setTag('error_source', 'zone_guarded');
              scope.setTag('error_type', 'uncaught_zone_error');
            },
          );
        },
      );
    },
  );
}

/// Run app without Sentry (development mode)
void _runAppWithoutSentry() {
  // Set up basic error handling for development
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    
    logger.error(
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
      data: {
        'library': details.library,
        'context': details.context?.toString(),
      },
    );
  };
  
  runZonedGuarded(
    () => runApp(ProviderScope(child: App(navigatorKey: navigatorKey))),
    (error, stackTrace) {
      logger.error(
        'Uncaught zone error',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}
