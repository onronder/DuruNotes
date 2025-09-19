import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:duru_notes/app/app.dart';
import 'package:duru_notes/core/android_optimizations.dart';
import 'package:duru_notes/core/config/environment_config.dart';
import 'package:duru_notes/core/logging/logger_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/monitoring/error_boundary.dart';
import 'package:duru_notes/core/monitoring/sentry_config.dart';
import 'package:duru_notes/firebase_options.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/template_initialization_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Global navigation key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global instances (will be initialized)
late AppLogger logger;
late AnalyticsService analytics;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize environment configuration first
    await EnvironmentConfig.initialize();

    // Initialize logger configuration
    LoggerConfig.initialize();

    // Initialize logger instance early
    LoggerFactory.initialize();
    logger = LoggerFactory.instance;

    // Initialize Android optimizations
    await AndroidOptimizations.initialize();

    // Initialize Sentry for error tracking
    await SentryConfig.initialize();

    if (EnvironmentConfig.current.debugMode) {
      debugPrint(
        'Environment: ${EnvironmentConfig.current.currentEnvironment.name}',
      );
      debugPrint('Debug Mode: ${EnvironmentConfig.current.debugMode}');
      debugPrint(
        'Sentry Configured: ${EnvironmentConfig.current.isSentryConfigured}',
      );
    }

    // Validate configuration
    if (!EnvironmentConfig.validateConfig()) {
      throw Exception('Invalid environment configuration');
    }

    // Initialize Firebase with proper options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (EnvironmentConfig.current.debugMode) {
      debugPrint('✅ Firebase initialized successfully');
    }

    // Initialize Supabase
    await Supabase.initialize(
      url: EnvironmentConfig.current.supabaseUrl,
      anonKey: EnvironmentConfig.current.supabaseAnonKey,
      debug: EnvironmentConfig.current.debugMode,
    );
    if (EnvironmentConfig.current.debugMode) {
      debugPrint('✅ Supabase initialized successfully');
    }

    // Initialize remaining services
    await _initializeServices();

    if (EnvironmentConfig.current.debugMode) {
      debugPrint(
        '📊 Config Summary: ${EnvironmentConfig.getSafeConfigSummary()}',
      );
    }

    // Track app launch
    analytics.event(
      AnalyticsEvents.noteCreate,
      properties: {
        'environment': EnvironmentConfig.current.currentEnvironment.name,
        'debug_mode': EnvironmentConfig.current.debugMode,
      },
    );
  } catch (e, stackTrace) {
    debugPrint('❌ Initialization Error: $e');
    if (kDebugMode) {
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // Run the app
  runApp(
    ProviderScope(
      child: DefaultAssetBundle(
        bundle: SentryAssetBundle(),
        child: ErrorBoundary(
          child: _AppWithShareExtension(navigatorKey: navigatorKey),
        ),
      ),
    ),
  );
}

/// Initialize all services
Future<void> _initializeServices() async {
  // Logger already initialized in main()
  
  // Initialize analytics
  AnalyticsFactory.initialize();
  analytics = AnalyticsFactory.instance;

  // Initialize Adapty SDK with optimized configuration
  try {
    // Set log level - use warning level in debug to reduce verbosity
    await Adapty().setLogLevel(
      EnvironmentConfig.current.debugMode
          ? AdaptyLogLevel.warn  // Changed from verbose to reduce logging
          : AdaptyLogLevel.error,
    );

    // Activate Adapty with optimized configuration
    await Adapty().activate(
      configuration:
          AdaptyConfiguration(
              apiKey: 'public_live_auSluPc0.Qso83VlJGyzNxUmeZn6j',
            )
            // Activate AdaptyUI for Paywall Builder support
            ..withActivateUI(true)
            // Privacy-compliant configuration
            ..withAppleIdfaCollectionDisabled(true) // Disable to reduce tracking calls
            ..withIpAddressCollectionDisabled(
              true,
            ) // Disable to reduce network calls
            // Optimized media cache configuration
            ..withMediaCacheConfiguration(
              const AdaptyUIMediaCacheConfiguration(
                memoryStorageTotalCostLimit: 50 * 1024 * 1024, // Reduced to 50 MB
                memoryStorageCountLimit: 100, // Reduced from max int
                diskStorageSizeLimit: 50 * 1024 * 1024, // Reduced to 50 MB
              ),
            ),
    );

    logger.info('Adapty SDK initialized successfully with full configuration');

    // Track successful Adapty initialization
    analytics.event(
      AnalyticsEvents.noteCreate,
      properties: {
        'adapty_initialized': true,
        'adapty_ui_enabled': true,
        'environment': EnvironmentConfig.current.currentEnvironment.name,
      },
    );
  } catch (e) {
    logger.error('Failed to initialize Adapty SDK: $e');

    // Track Adapty initialization failure
    analytics.event(
      AnalyticsEvents.noteCreate,
      properties: {
        'adapty_initialized': false,
        'adapty_error': e.toString(),
        'environment': EnvironmentConfig.current.currentEnvironment.name,
      },
    );
  }

  logger.info('Services initialized successfully');
}

/// App wrapper that initializes share extension service
class _AppWithShareExtension extends ConsumerStatefulWidget {
  const _AppWithShareExtension({required this.navigatorKey});
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  ConsumerState<_AppWithShareExtension> createState() =>
      _AppWithShareExtensionState();
}

class _AppWithShareExtensionState
    extends ConsumerState<_AppWithShareExtension> {
  @override
  void initState() {
    super.initState();

    // Initialize services after app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  Future<void> _initializeServices() async {
    // Initialize share extension
    await _initializeShareExtension();
    
    // Initialize default templates for new users
    await _initializeTemplates();
  }

  Future<void> _initializeShareExtension() async {
    try {
      final shareExtensionService = ref.read(shareExtensionServiceProvider);
      await shareExtensionService.initialize();

      logger.info('Share extension service initialized successfully');
    } catch (e) {
      logger.error('Failed to initialize share extension service: $e');
    }
  }
  
  Future<void> _initializeTemplates() async {
    try {
      final notesRepository = ref.read(notesRepositoryProvider);
      
      // Check if user already has templates
      final existingTemplates = await notesRepository.listTemplates();
      
      if (existingTemplates.isEmpty) {
        logger.info('Initializing default templates for new user...');
        
        // Import our template initialization service
        final templateService = TemplateInitializationService(
          notesRepository: notesRepository,
        );
        
        await templateService.initializeDefaultTemplates();
        logger.info('Default templates initialized');
      } else {
        logger.info('User already has ${existingTemplates.length} templates');
      }
    } catch (e) {
      logger.error('Failed to initialize templates: $e');
      // Non-critical error, continue without templates
    }
  }

  @override
  Widget build(BuildContext context) {
    return App(navigatorKey: widget.navigatorKey);
  }
}
