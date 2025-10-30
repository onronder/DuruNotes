import 'package:duru_notes/core/bootstrap/bootstrap_providers.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// A widget that catches and handles errors in its child widget tree.
class ErrorBoundary extends ConsumerStatefulWidget {
  const ErrorBoundary({
    required this.child,
    super.key,
    this.fallback,
    this.onError,
    this.captureErrors = true,
  });

  final Widget child;
  final Widget? fallback;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final bool captureErrors;

  @override
  ConsumerState<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends ConsumerState<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;
  bool _hasError = false;
  late final AppLogger _logger;
  FlutterExceptionHandler? _previousHandler;

  @override
  void initState() {
    super.initState();
    _logger = ref.read(bootstrapLoggerProvider);
    _previousHandler = FlutterError.onError;

    FlutterError.onError = (details) {
      _handleError(details.exception, details.stack);
      _previousHandler?.call(details);
    };
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    if (mounted) {
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

    _logger.error(
      'ErrorBoundary caught error',
      error: error,
      stackTrace: stackTrace,
      data: {
        'boundary': 'ErrorBoundary',
        'widget': widget.child.runtimeType.toString(),
      },
    );

    if (widget.captureErrors) {
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.level = SentryLevel.error;
          scope.setTag('error_source', 'error_boundary');
          scope.setTag('widget_type', widget.child.runtimeType.toString());
          scope.setTag(
            'has_custom_fallback',
            widget.fallback != null ? 'true' : 'false',
          );
        },
      );
    }

    if (widget.onError != null) {
      try {
        widget.onError!(error, stackTrace ?? StackTrace.current);
      } catch (handlerError, handlerStack) {
        _logger.error(
          'Error in custom error handler',
          error: handlerError,
          stackTrace: handlerStack,
        );
      }
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _stackTrace = null;
      _hasError = false;
    });

    _logger.info('ErrorBoundary: User retried after error');
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallback ?? _buildDefaultErrorWidget(context);
    }

    return widget.child;
  }

  Widget _buildDefaultErrorWidget(BuildContext context) {
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
                padding: const EdgeInsets.all(24),
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
                      "We're sorry, but something unexpected happened. The error has been reported and we'll look into it.",
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
              Text('Error:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                _error.toString(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
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

  @override
  void dispose() {
    FlutterError.onError = _previousHandler;
    super.dispose();
  }
}
