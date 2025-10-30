import 'package:duru_notes/app/app.dart';
import 'package:duru_notes/core/bootstrap/app_bootstrap.dart';
import 'package:duru_notes/core/bootstrap/bootstrap_providers.dart';
import 'package:duru_notes/core/config/environment_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/monitoring/error_boundary.dart';
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show analyticsProvider;
import 'package:duru_notes/services/analytics/analytics_factory.dart';
import 'package:duru_notes/ui/widgets/blocks/feature_flagged_block_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapHost());
}

/// Hosts the asynchronous bootstrap flow and wires Riverpod overrides.
class BootstrapHost extends StatefulWidget {
  const BootstrapHost({super.key});

  @override
  State<BootstrapHost> createState() => _BootstrapHostState();
}

class _BootstrapHostState extends State<BootstrapHost> {
  late Future<BootstrapResult> _bootstrapFuture;
  GlobalKey<NavigatorState>? _navigatorKey;

  @override
  void initState() {
    super.initState();
    _runBootstrap();
  }

  void _runBootstrap() {
    _bootstrapFuture = AppBootstrap().initialize();
  }

  void _retryBootstrap() {
    setState(_runBootstrap);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BootstrapResult>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        // Always provide the same number of overrides to avoid Riverpod container error
        _navigatorKey ??= GlobalKey<NavigatorState>();

        final overrides = <Override>[
          // Always override with either actual data or fallback
          bootstrapResultProvider.overrideWithValue(
            snapshot.hasData && snapshot.data != null
                ? snapshot.data!
                : _createFallbackBootstrapResult(),
          ),
          navigatorKeyProvider.overrideWithValue(_navigatorKey!),
        ];

        return ProviderScope(
          overrides: overrides,
          child: _BootstrapBody(
            snapshot: snapshot,
            navigatorKey: _navigatorKey,
            onRetry: _retryBootstrap,
          ),
        );
      },
    );
  }

  BootstrapResult _createFallbackBootstrapResult() {
    return BootstrapResult(
      environment: EnvironmentConfig.fallback(),
      logger: LoggerFactory.instance,
      analytics: AnalyticsFactory.instance,
      supabaseClient: null,
      firebaseApp: null,
      sentryEnabled: false,
      failures: const [],
      adaptyEnabled: false,
      warnings: const [],
      environmentSource: 'fallback-loading',
    );
  }
}

class _BootstrapBody extends StatelessWidget {
  const _BootstrapBody({
    required this.snapshot,
    required this.navigatorKey,
    required this.onRetry,
  });

  final AsyncSnapshot<BootstrapResult> snapshot;
  final GlobalKey<NavigatorState>? navigatorKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const _BootstrapLoadingApp();
    }

    if (snapshot.hasError || !snapshot.hasData) {
      final failure = BootstrapFailure(
        stage: BootstrapStage.environment,
        error: snapshot.error ?? 'Unknown bootstrap error',
        stackTrace: snapshot.stackTrace ?? StackTrace.current,
        critical: true,
      );
      return BootstrapFailureApp(
        failures: [failure],
        warnings: const [],
        onRetry: onRetry,
      );
    }

    final result = snapshot.data!;
    final key = navigatorKey ?? GlobalKey<NavigatorState>();
    return BootstrapShell(result: result, navigatorKey: key, onRetry: onRetry);
  }
}

class _BootstrapLoadingApp extends StatelessWidget {
  const _BootstrapLoadingApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

class BootstrapShell extends StatelessWidget {
  const BootstrapShell({
    required this.result,
    required this.navigatorKey,
    required this.onRetry,
    super.key,
  });

  final BootstrapResult result;
  final GlobalKey<NavigatorState> navigatorKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (result.hasCriticalFailures) {
      return BootstrapFailureApp(
        failures: result.failures,
        warnings: result.warnings,
        onRetry: onRetry,
      );
    }

    // Ensure feature flag factory prints state when in debug for diagnostics.
    if (result.environment.debugMode) {
      FeatureFlaggedBlockFactory.logFeatureFlagState();
    }

    return DefaultAssetBundle(
      bundle: SentryAssetBundle(),
      child: ErrorBoundary(
        fallback: BootstrapFailureContent(
          failures: result.failures,
          warnings: result.warnings,
          onRetry: onRetry,
        ),
        child: _AppWithShareExtension(navigatorKey: navigatorKey),
      ),
    );
  }
}

class BootstrapFailureApp extends StatelessWidget {
  const BootstrapFailureApp({
    required this.failures,
    required this.warnings,
    required this.onRetry,
    super.key,
  });

  final List<BootstrapFailure> failures;
  final List<String> warnings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BootstrapFailureContent(
        failures: failures,
        warnings: warnings,
        onRetry: onRetry,
      ),
    );
  }
}

class BootstrapFailureContent extends StatelessWidget {
  const BootstrapFailureContent({
    required this.failures,
    required this.warnings,
    required this.onRetry,
    super.key,
  });

  final List<BootstrapFailure> failures;
  final List<String> warnings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Text(
                  'Unable to start Duru Notes',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  'We ran into some issues while preparing the app. '
                  'You can retry or contact support if the problem persists.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (failures.isNotEmpty) ...[
                  Text(
                    'Errors',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...failures.map(
                    (failure) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              failure.stage.name,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(failure.error.toString()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Warnings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...warnings.map(
                    (warning) => Card(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(warning),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// App wrapper - removed share extension initialization
/// Share extension is now initialized in app.dart AFTER security services
class _AppWithShareExtension extends ConsumerWidget {
  const _AppWithShareExtension({required this.navigatorKey});
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Log bootstrap ready event
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final analytics = ref.read(analyticsProvider);
        analytics.event(
          'bootstrap_ready',
          properties: {'phase': 'postBootstrap'},
        );
      } catch (e) {
        // Ignore analytics errors
        debugPrint('Analytics event failed: $e');
      }
    });

    return App(navigatorKey: navigatorKey);
  }
}
