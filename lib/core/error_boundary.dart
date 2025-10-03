import 'dart:async';
import 'dart:io';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Global error recovery manager
class ErrorRecoveryManager {
  static final ErrorRecoveryManager _instance =
      ErrorRecoveryManager._internal();
  factory ErrorRecoveryManager() => _instance;
  ErrorRecoveryManager._internal();

  final _logger = LoggerFactory.instance;
  final List<ErrorRecoveryStrategy> _strategies = [];
  final Map<String, DateTime> _errorTimestamps = {};
  final Map<String, int> _errorCounts = {};

  /// Register a recovery strategy
  void registerStrategy(ErrorRecoveryStrategy strategy) {
    _strategies.add(strategy);
    _strategies.sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// Attempt to recover from an error
  Future<bool> attemptRecovery(Object error, StackTrace? stackTrace) async {
    final errorKey = error.runtimeType.toString();

    // Track error frequency
    _trackError(errorKey);

    // Check if error is happening too frequently
    if (_isErrorTooFrequent(errorKey)) {
      _logger.error(
        'Error occurring too frequently, skipping recovery',
        error: error,
      );
      return false;
    }

    // Try each strategy in priority order
    for (final strategy in _strategies) {
      if (strategy.canHandle(error)) {
        try {
          _logger.info('Attempting recovery with ${strategy.name}');
          final recovered = await strategy.recover(error, stackTrace);
          if (recovered) {
            _logger.info('Recovery successful with ${strategy.name}');
            _resetErrorTracking(errorKey);
            return true;
          }
        } catch (e, stack) {
          _logger.error(
            'Recovery strategy failed',
            error: e,
            stackTrace: stack,
          );
        }
      }
    }

    return false;
  }

  void _trackError(String errorKey) {
    _errorTimestamps[errorKey] = DateTime.now();
    _errorCounts[errorKey] = (_errorCounts[errorKey] ?? 0) + 1;
  }

  bool _isErrorTooFrequent(String errorKey) {
    final count = _errorCounts[errorKey] ?? 0;
    final lastTime = _errorTimestamps[errorKey];

    if (count > 5 && lastTime != null) {
      final timeSinceFirst = DateTime.now().difference(lastTime);
      return timeSinceFirst.inSeconds < 60; // More than 5 errors in 60 seconds
    }

    return false;
  }

  void _resetErrorTracking(String errorKey) {
    _errorCounts.remove(errorKey);
    _errorTimestamps.remove(errorKey);
  }
}

/// Base class for error recovery strategies
abstract class ErrorRecoveryStrategy {
  String get name;
  int get priority; // Higher priority strategies are tried first

  bool canHandle(Object error);
  Future<bool> recover(Object error, StackTrace? stackTrace);
}

/// Network error recovery strategy
class NetworkErrorRecovery extends ErrorRecoveryStrategy {
  @override
  String get name => 'NetworkErrorRecovery';

  @override
  int get priority => 100;

  @override
  bool canHandle(Object error) {
    return error is SocketException ||
        error is HttpException ||
        error.toString().contains('NetworkException') ||
        error.toString().contains('Connection refused');
  }

  @override
  Future<bool> recover(Object error, StackTrace? stackTrace) async {
    // Wait and retry
    await Future<void>.delayed(const Duration(seconds: 2));

    // Check connectivity
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

/// Database error recovery strategy
class DatabaseErrorRecovery extends ErrorRecoveryStrategy {
  @override
  String get name => 'DatabaseErrorRecovery';

  @override
  int get priority => 90;

  @override
  bool canHandle(Object error) {
    return error.toString().contains('SqliteException') ||
        error.toString().contains('DatabaseException') ||
        error.toString().contains('database is locked');
  }

  @override
  Future<bool> recover(Object error, StackTrace? stackTrace) async {
    // Wait for database to unlock
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Could trigger database cleanup or migration here
    return true;
  }
}

/// Permission error recovery strategy
class PermissionErrorRecovery extends ErrorRecoveryStrategy {
  @override
  String get name => 'PermissionErrorRecovery';

  @override
  int get priority => 80;

  @override
  bool canHandle(Object error) {
    return error is PlatformException &&
        (error.code == 'PERMISSION_DENIED' ||
            error.code == 'PERMISSION_PERMANENTLY_DENIED');
  }

  @override
  Future<bool> recover(Object error, StackTrace? stackTrace) async {
    // Could trigger permission request flow here
    // For now, just return false to show error UI
    return false;
  }
}

/// Widget that provides error boundary functionality
class ErrorBoundary extends ConsumerStatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    this.onError,
    this.fallback,
    this.showErrorDetails = true,
    this.enableAutoRecovery = true,
  });

  final Widget child;
  final void Function(Object error, StackTrace? stackTrace)? onError;
  final Widget? fallback;
  final bool showErrorDetails;
  final bool enableAutoRecovery;

  @override
  ConsumerState<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends ConsumerState<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;
  bool _hasError = false;
  bool _isRecovering = false;
  int _retryCount = 0;

  final _logger = LoggerFactory.instance;
  final _recoveryManager = ErrorRecoveryManager();

  @override
  void initState() {
    super.initState();

    // Register default recovery strategies
    _recoveryManager.registerStrategy(NetworkErrorRecovery());
    _recoveryManager.registerStrategy(DatabaseErrorRecovery());
    _recoveryManager.registerStrategy(PermissionErrorRecovery());
  }

  void _handleError(Object error, StackTrace? stackTrace) async {
    // Log error
    _logger.error(
      'Error caught by ErrorBoundary',
      error: error,
      stackTrace: stackTrace,
    );

    // Report to Sentry
    await Sentry.captureException(error, stackTrace: stackTrace);

    // Call custom error handler
    widget.onError?.call(error, stackTrace);

    // Attempt auto-recovery if enabled
    if (widget.enableAutoRecovery && _retryCount < 3) {
      setState(() {
        _isRecovering = true;
      });

      final recovered = await _recoveryManager.attemptRecovery(
        error,
        stackTrace,
      );

      if (recovered) {
        setState(() {
          _hasError = false;
          _error = null;
          _stackTrace = null;
          _isRecovering = false;
          _retryCount = 0;
        });
        return;
      }
    }

    // Show error UI
    setState(() {
      _hasError = true;
      _error = error;
      _stackTrace = stackTrace;
      _isRecovering = false;
    });
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _error = null;
      _stackTrace = null;
      _retryCount++;
    });
  }

  void _report() async {
    if (_error != null) {
      await Sentry.captureException(
        _error,
        stackTrace: _stackTrace,
        withScope: (scope) {
          scope.level = SentryLevel.error;
          scope.setTag('user_reported', 'true');
          scope.setContexts('error_boundary', {
            'retry_count': _retryCount,
            'auto_recovery_enabled': widget.enableAutoRecovery,
          });
        },
      );

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorReportSent)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallback ?? _buildDefaultErrorWidget(context);
    }

    if (_isRecovering) {
      return _buildRecoveringWidget(context);
    }

    return ErrorBoundaryLayer(onError: _handleError, child: widget.child);
  }

  Widget _buildRecoveringWidget(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Attempting to recover...',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultErrorWidget(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 40,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.genericErrorTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.genericErrorMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.showErrorDetails && _error != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bug_report,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.errorDetails,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _error.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (kDebugMode && _stackTrace != null) ...[
                        const SizedBox(height: 8),
                        ExpansionTile(
                          title: Text(
                            'Stack Trace',
                            style: theme.textTheme.labelMedium,
                          ),
                          children: [
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  _stackTrace.toString(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _report,
                    icon: const Icon(Icons.flag),
                    label: Text(l10n.reportError),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
              if (_retryCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Retry attempt: $_retryCount',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Internal widget that captures errors
class ErrorBoundaryLayer extends StatefulWidget {
  const ErrorBoundaryLayer({
    super.key,
    required this.child,
    required this.onError,
  });

  final Widget child;
  final void Function(Object error, StackTrace? stackTrace) onError;

  @override
  State<ErrorBoundaryLayer> createState() => _ErrorBoundaryLayerState();
}

class _ErrorBoundaryLayerState extends State<ErrorBoundaryLayer> {
  @override
  void initState() {
    super.initState();

    // Capture Flutter errors in this subtree
    FlutterError.onError = (FlutterErrorDetails details) {
      widget.onError(details.exception, details.stack);
    };
  }

  @override
  Widget build(BuildContext context) {
    // Wrap in error widget to catch build errors
    ErrorWidget.builder = (FlutterErrorDetails details) {
      widget.onError(details.exception, details.stack);
      return const SizedBox.shrink();
    };

    return widget.child;
  }
}

/// Extension to easily wrap widgets with error boundary
extension ErrorBoundaryExtension on Widget {
  Widget withErrorBoundary({
    void Function(Object error, StackTrace? stackTrace)? onError,
    Widget? fallback,
    bool showErrorDetails = true,
    bool enableAutoRecovery = true,
  }) {
    return ErrorBoundary(
      onError: onError,
      fallback: fallback,
      showErrorDetails: showErrorDetails,
      enableAutoRecovery: enableAutoRecovery,
      child: this,
    );
  }
}
