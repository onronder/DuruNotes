import 'package:duru_notes/core/bootstrap/bootstrap_error.dart';
import 'package:duru_notes/core/bootstrap/enhanced_app_bootstrap.dart';
import 'package:flutter/material.dart';

/// Loading screen shown during application bootstrap
class BootstrapLoadingScreen extends StatefulWidget {
  const BootstrapLoadingScreen({
    super.key,
    required this.stage,
    required this.progress,
    this.message,
  });

  final BootstrapStage stage;
  final double progress;
  final String? message;

  @override
  State<BootstrapLoadingScreen> createState() => _BootstrapLoadingScreenState();
}

class _BootstrapLoadingScreenState extends State<BootstrapLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getStageMessage(BootstrapStage stage) {
    switch (stage) {
      case BootstrapStage.environment:
        return 'Initializing environment...';
      case BootstrapStage.logging:
        return 'Setting up logging...';
      case BootstrapStage.platform:
        return 'Optimizing platform...';
      case BootstrapStage.monitoring:
        return 'Configuring monitoring...';
      case BootstrapStage.firebase:
        return 'Connecting to services...';
      case BootstrapStage.supabase:
        return 'Loading database...';
      case BootstrapStage.featureFlags:
        return 'Loading features...';
      case BootstrapStage.analytics:
        return 'Setting up analytics...';
      case BootstrapStage.adapty:
        return 'Loading premium features...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App logo or icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.note_add,
                        size: 50,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // App name
                    Text(
                      'Duru Notes',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Progress indicator
                    SizedBox(
                      width: 200,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: widget.progress,
                              minHeight: 6,
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Progress percentage
                          Text(
                            '${(widget.progress * 100).toInt()}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Stage message
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        widget.message ?? _getStageMessage(widget.stage),
                        key: ValueKey(widget.stage),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Error screen shown when bootstrap fails
class BootstrapErrorScreen extends StatelessWidget {
  const BootstrapErrorScreen({
    super.key,
    required this.errors,
    this.onRetry,
    this.onContinueDegraded,
    this.onContactSupport,
  });

  final List<BootstrapError> errors;
  final VoidCallback? onRetry;
  final VoidCallback? onContinueDegraded;
  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Find the most severe error
    final criticalErrors = errors.where((e) => e.isCritical).toList();
    final primaryError = criticalErrors.isNotEmpty
        ? criticalErrors.first
        : errors.first;

    final canRetry = errors.any((e) => e.retryable);
    final canContinue = !errors.any(
      (e) => e.severity == BootstrapErrorSeverity.fatal,
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),

              // Error icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  primaryError.severity == BootstrapErrorSeverity.warning
                      ? Icons.warning_amber
                      : Icons.error_outline,
                  size: 40,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 32),

              // Error title
              Text(
                _getErrorTitle(primaryError),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Error description
              Text(
                primaryError.userDescription,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Suggested action
              Text(
                primaryError.suggestedAction,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              if (errors.length > 1) ...[
                const SizedBox(height: 24),
                // Additional errors
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional issues:',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      ...errors
                          .skip(1)
                          .take(3)
                          .map(
                            (error) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _getErrorIcon(error.severity),
                                    size: 16,
                                    color: _getErrorColor(
                                      error.severity,
                                      theme,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      error.userDescription,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Action buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (canRetry && onRetry != null)
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                  if (canContinue && onContinueDegraded != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: onContinueDegraded,
                      child: const Text('Continue with limited features'),
                    ),
                  ],
                  if (onContactSupport != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: onContactSupport,
                      child: const Text('Contact Support'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getErrorTitle(BootstrapError error) {
    switch (error.severity) {
      case BootstrapErrorSeverity.warning:
        return 'Minor Issue Detected';
      case BootstrapErrorSeverity.important:
        return 'Some Features Unavailable';
      case BootstrapErrorSeverity.critical:
        return 'Connection Problem';
      case BootstrapErrorSeverity.fatal:
        return 'Unable to Start';
    }
  }

  IconData _getErrorIcon(BootstrapErrorSeverity severity) {
    switch (severity) {
      case BootstrapErrorSeverity.warning:
        return Icons.warning_amber;
      case BootstrapErrorSeverity.important:
        return Icons.info_outline;
      case BootstrapErrorSeverity.critical:
        return Icons.error_outline;
      case BootstrapErrorSeverity.fatal:
        return Icons.cancel_outlined;
    }
  }

  Color _getErrorColor(BootstrapErrorSeverity severity, ThemeData theme) {
    switch (severity) {
      case BootstrapErrorSeverity.warning:
        return theme.colorScheme.tertiary;
      case BootstrapErrorSeverity.important:
        return theme.colorScheme.primary;
      case BootstrapErrorSeverity.critical:
      case BootstrapErrorSeverity.fatal:
        return theme.colorScheme.error;
    }
  }
}

/// Widget to manage bootstrap UI flow
class BootstrapFlowWidget extends StatefulWidget {
  const BootstrapFlowWidget({
    super.key,
    required this.onBootstrapComplete,
    this.bootstrapTimeout = const Duration(seconds: 30),
  });

  final void Function(BuildContext context, dynamic result) onBootstrapComplete;
  final Duration bootstrapTimeout;

  @override
  State<BootstrapFlowWidget> createState() => _BootstrapFlowWidgetState();
}

class _BootstrapFlowWidgetState extends State<BootstrapFlowWidget> {
  BootstrapStage _currentStage = BootstrapStage.environment;
  double _progress = 0.0;
  String? _message;
  List<BootstrapError> _errors = [];
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _startBootstrap();
  }

  Future<void> _startBootstrap() async {
    setState(() {
      _isRetrying = true;
      _errors = [];
    });

    try {
      final bootstrap = EnhancedAppBootstrap(
        maxBootstrapDuration: widget.bootstrapTimeout,
        progressCallback: _onProgress,
      );

      final result = await bootstrap.initialize();

      if (!mounted) return;

      if (result.hasCriticalErrors && !result.offlineMode) {
        setState(() {
          _errors = result.errorManager.errors;
          _isRetrying = false;
        });
      } else {
        // Success or degraded mode
        widget.onBootstrapComplete(context, result);
      }
    } catch (error, stackTrace) {
      if (!mounted) return;

      setState(() {
        _errors = [
          BootstrapError(
            stage: _currentStage,
            error: error,
            stackTrace: stackTrace,
            severity: BootstrapErrorSeverity.fatal,
            message: 'Unexpected error during initialization',
          ),
        ];
        _isRetrying = false;
      });
    }
  }

  void _onProgress(BootstrapStage stage, double progress, String? message) {
    if (!mounted) return;

    setState(() {
      _currentStage = stage;
      _progress = progress;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errors.isNotEmpty && !_isRetrying) {
      return BootstrapErrorScreen(
        errors: _errors,
        onRetry: _startBootstrap,
        onContinueDegraded: () {
          // Create a degraded result and continue
          widget.onBootstrapComplete(context, null);
        },
        onContactSupport: () {
          // Open support link or email
        },
      );
    }

    return BootstrapLoadingScreen(
      stage: _currentStage,
      progress: _progress,
      message: _message,
    );
  }
}
