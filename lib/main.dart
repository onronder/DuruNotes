import 'dart:async';

import 'package:duru_notes/app/app.dart';
import 'package:duru_notes/core/bootstrap/app_bootstrap.dart';
import 'package:duru_notes/core/bootstrap/bootstrap_providers.dart';
import 'package:duru_notes/core/monitoring/error_boundary.dart';
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show analyticsProvider;
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/ui/widgets/blocks/feature_flagged_block_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[main] Starting fast bootstrap before runApp()');
  final bootstrap = AppBootstrap();
  final bootstrapResult = await bootstrap.initializeFast();
  debugPrint('[main] Fast bootstrap complete, launching app');
  runApp(
    BootstrapApp(initialResult: bootstrapResult, bootstrapOverride: bootstrap),
  );
}

/// Hosts the fully initialized application with Riverpod overrides.
class BootstrapApp extends StatefulWidget {
  const BootstrapApp({
    required this.initialResult,
    this.bootstrapOverride,
    this.appBuilder,
    super.key,
  });

  final BootstrapResult initialResult;
  final AppBootstrap? bootstrapOverride;
  final WidgetBuilder? appBuilder;

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late BootstrapResult _result;
  late final AppBootstrap _bootstrap;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _isInitializing = false;
  bool _backendInitStarted = false;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
    _bootstrap = widget.bootstrapOverride ?? AppBootstrap();
    _startBackendInitialization();
  }

  void _startBackendInitialization() {
    if (_backendInitStarted) return;
    _backendInitStarted = true;
    // Fire-and-forget backend bootstrap; this should never block the first UI.
    unawaited(_initializeBackend());
  }

  Future<void> _initializeBackend() async {
    try {
      final updated = await _bootstrap.initializeBackend(_result);
      if (!mounted) return;
      setState(() {
        _result = updated;
      });
    } catch (error, stack) {
      debugPrint('[BootstrapApp] Backend init failed: $error\n$stack');
      // We intentionally do not surface this as a hard failure; the app can
      // continue in a degraded mode with whatever the fast phase provided.
    }
  }

  Future<void> _retryBootstrap() async {
    if (_isInitializing) return;
    setState(() {
      _isInitializing = true;
    });
    try {
      final newResult = await _bootstrap.initialize();
      if (!mounted) return;
      setState(() {
        _result = newResult;
        _isInitializing = false;
        _backendInitStarted = false;
      });
      _startBackendInitialization();
    } catch (error, stack) {
      debugPrint('[BootstrapApp] Retry failed: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final overrides = <Override>[
      bootstrapResultProvider.overrideWithValue(_result),
      navigatorKeyProvider.overrideWithValue(_navigatorKey),
    ];

    return ProviderScope(
      overrides: overrides,
      child: _isInitializing
          ? const _BootstrapLoadingApp()
          : BootstrapShell(
              result: _result,
              navigatorKey: _navigatorKey,
              onRetry: () => unawaited(_retryBootstrap()),
              appBuilder: widget.appBuilder,
            ),
    );
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
    this.appBuilder,
    super.key,
  });

  final BootstrapResult result;
  final GlobalKey<NavigatorState> navigatorKey;
  final VoidCallback onRetry;
  final WidgetBuilder? appBuilder;

  @override
  Widget build(BuildContext context) {
    if (result.hasCriticalFailures) {
      return BootstrapFailureApp(
        failures: result.failures,
        warnings: result.warnings,
        onRetry: onRetry,
        stageDurations: result.stageDurations,
      );
    }

    final readinessFailures = _runtimeReadinessFailures(result);
    if (readinessFailures.isNotEmpty) {
      return BootstrapFailureApp(
        failures: [...result.failures, ...readinessFailures],
        warnings: result.warnings,
        onRetry: onRetry,
        stageDurations: result.stageDurations,
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
          stageDurations: result.stageDurations,
        ),
        child: Builder(
          builder: (context) {
            final widget = appBuilder != null
                ? appBuilder!(context)
                : _AppWithShareExtension(navigatorKey: navigatorKey);
            return widget;
          },
        ),
      ),
    );
  }

  List<BootstrapFailure> _runtimeReadinessFailures(BootstrapResult result) {
    final issues = <BootstrapFailure>[];
    if (result.environment.requiresSupabase && result.supabaseClient == null) {
      issues.add(
        BootstrapFailure(
          stage: BootstrapStage.supabase,
          error: StateError(
            'Supabase credentials were provided but the client failed to initialize.',
          ),
          stackTrace: StackTrace.current,
          critical: true,
        ),
      );
    }
    // Only validate Sentry after backend initialization completes
    if (result.backendInitialized &&
        result.environment.requiresSentry &&
        !result.sentryEnabled) {
      issues.add(
        BootstrapFailure(
          stage: BootstrapStage.monitoring,
          error: StateError('Sentry is required but initialization failed.'),
          stackTrace: StackTrace.current,
          critical: true,
        ),
      );
    }
    return issues;
  }
}

class BootstrapFailureApp extends StatelessWidget {
  const BootstrapFailureApp({
    required this.failures,
    required this.warnings,
    required this.onRetry,
    this.stageDurations = const {},
    super.key,
  });

  final List<BootstrapFailure> failures;
  final List<String> warnings;
  final VoidCallback onRetry;
  final Map<BootstrapStage, Duration> stageDurations;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // GDPR FIX: Add localization delegates to prevent "No MaterialLocalizations found" errors
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('tr', ''),
        Locale('es', ''),
        Locale('de', ''),
        Locale('fr', ''),
      ],
      home: BootstrapFailureContent(
        failures: failures,
        warnings: warnings,
        onRetry: onRetry,
        stageDurations: stageDurations,
      ),
    );
  }
}

class BootstrapFailureContent extends StatelessWidget {
  const BootstrapFailureContent({
    required this.failures,
    required this.warnings,
    required this.onRetry,
    this.stageDurations = const {},
    super.key,
  });

  final List<BootstrapFailure> failures;
  final List<String> warnings;
  final VoidCallback onRetry;
  final Map<BootstrapStage, Duration> stageDurations;

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
                            if (failure.timedOut)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 4,
                                ),
                                child: Text(
                                  'Stage timed out — retried on next launch.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.tertiary,
                                      ),
                                ),
                              ),
                            if (failure.duration != null)
                              Text(
                                'Duration: ${_formatDuration(failure.duration!)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
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
                if (stageDurations.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Bootstrap timings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sortedStageDurations()
                        .map(
                          (entry) => Chip(
                            label: Text(
                              '${entry.key.name}: ${_formatDuration(entry.value)}',
                            ),
                          ),
                        )
                        .toList(),
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

  Iterable<MapEntry<BootstrapStage, Duration>> _sortedStageDurations() {
    final entries = stageDurations.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds >= 1) {
      return '${(duration.inMilliseconds / 1000).toStringAsFixed(1)} s';
    }
    return '${duration.inMilliseconds} ms';
  }
}

/// App wrapper - removed share extension initialization
/// Share extension is now initialized in app.dart AFTER security services
class _AppWithShareExtension extends ConsumerWidget {
  const _AppWithShareExtension({required this.navigatorKey});
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('[AppWithShareExtension] build start');
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
