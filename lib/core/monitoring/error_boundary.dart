import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'app_logger.dart';

/// A widget that catches and handles errors in its child widget tree
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget? fallback;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final bool captureErrors;
  
  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
    this.onError,
    this.captureErrors = true,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    
    // Set up error handling for this boundary
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleError(details.exception, details.stack);
      
      // Call the original error handler to maintain default behavior
      FlutterError.presentError(details);
    };
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    // Defer UI state update to next frame to avoid setState during attach/build
    if (mounted) {
      // Ensure a frame is scheduled
      if (!SchedulerBinding.instance.hasScheduledFrame) {
        SchedulerBinding.instance.scheduleFrame();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _error = error;
          _stackTrace = stackTrace;
          _hasError = true;
        });
      });
    }
    
    // Log the error
    logger.error(
      'ErrorBoundary caught error',
      error: error,
      stackTrace: stackTrace,
      data: {
        'boundary': 'ErrorBoundary',
        'widget': widget.child.runtimeType.toString(),
      },
    );
    
    // Capture error in Sentry if enabled
    if (widget.captureErrors) {
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
                  withScope: (scope) {
            scope.level = SentryLevel.error;
            scope.setTag('error_source', 'error_boundary');
            scope.setTag('widget_type', widget.child.runtimeType.toString());
            scope.setTag('has_custom_fallback', widget.fallback != null ? 'true' : 'false');
          },
      );
    }
    
    // Call custom error handler if provided
    if (widget.onError != null) {
      try {
        widget.onError!(error, stackTrace ?? StackTrace.current);
      } catch (e) {
        // Prevent infinite error loops
        logger.error('Error in custom error handler', error: e);
      }
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _stackTrace = null;
      _hasError = false;
    });
    
    logger.info('ErrorBoundary: User retried after error');
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallback ?? _buildDefaultErrorWidget(context);
    }
    
    return widget.child;
  }

  Widget _buildDefaultErrorWidget(BuildContext context) {
    // Provide MaterialApp to ensure Directionality, Theme, and Localizations
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (ctx) {
          final colorScheme = Theme.of(ctx).colorScheme;
          final textTheme = Theme.of(ctx).textTheme;
          return Scaffold(
            backgroundColor: colorScheme.surface,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Something went wrong',
                      style: textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'We\'re sorry, but something unexpected happened. The error has been reported and we\'ll look into it.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton(
                          onPressed: _retry,
                          child: const Text('Try Again'),
                        ),
                        if (kDebugMode)
                          TextButton(
                            onPressed: () => _showErrorDetails(ctx),
                            child: const Text('Show Details'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showErrorDetails(BuildContext context) {
            showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Error:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _error.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              if (_stackTrace != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Stack Trace:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _stackTrace.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// A specialized error boundary for specific features
class FeatureErrorBoundary extends StatelessWidget {
  final Widget child;
  final String featureName;
  final Widget? fallback;
  
  const FeatureErrorBoundary({
    super.key,
    required this.child,
    required this.featureName,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      onError: (error, stackTrace) {
        logger.error(
          'Error in $featureName',
          error: error,
          stackTrace: stackTrace,
          data: {
            'feature': featureName,
            'context': 'FeatureErrorBoundary',
          },
        );
      },
      fallback: fallback ?? _buildFeatureErrorWidget(context),
      child: child,
    );
  }

  Widget _buildFeatureErrorWidget(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_outlined,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            '$featureName is temporarily unavailable',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Extension to wrap any widget with an error boundary
extension ErrorBoundaryExtension on Widget {
  /// Wrap this widget with an error boundary
  Widget withErrorBoundary({
    Widget? fallback,
    void Function(Object error, StackTrace stackTrace)? onError,
    bool captureErrors = true,
  }) {
    return ErrorBoundary(
      fallback: fallback,
      onError: onError,
      captureErrors: captureErrors,
      child: this,
    );
  }
  
  /// Wrap this widget with a feature-specific error boundary
  Widget withFeatureErrorBoundary(String featureName, {Widget? fallback}) {
    return FeatureErrorBoundary(
      featureName: featureName,
      fallback: fallback,
      child: this,
    );
  }
}
