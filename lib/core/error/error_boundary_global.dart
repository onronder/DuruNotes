import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Production-grade Global Error Boundary
/// Provides comprehensive error handling for the entire application
/// Features:
/// - Graceful error recovery
/// - User-friendly error messages
/// - Error reporting to monitoring services
/// - Automatic retry mechanisms
/// - Error state persistence
class GlobalErrorBoundary extends ConsumerStatefulWidget {
  final Widget child;
  final ErrorReportingService? errorReportingService;
  final bool enableAutoRecovery;
  final Duration recoveryDelay;

  const GlobalErrorBoundary({
    super.key,
    required this.child,
    this.errorReportingService,
    this.enableAutoRecovery = true,
    this.recoveryDelay = const Duration(seconds: 3),
  });

  @override
  ConsumerState<GlobalErrorBoundary> createState() => _GlobalErrorBoundaryState();
}

class _GlobalErrorBoundaryState extends ConsumerState<GlobalErrorBoundary> {
  FlutterErrorDetails? _errorDetails;
  int _errorCount = 0;
  DateTime? _lastErrorTime;
  Timer? _recoveryTimer;
  bool _isRecovering = false;

  @override
  void initState() {
    super.initState();
    _setupErrorHandlers();
  }

  void _setupErrorHandlers() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleError(details);
      // Also report to default handler for logging
      FlutterError.presentError(details);
    };

    // Handle async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleAsyncError(error, stack);
      return true; // Prevent app crash
    };

    // Handle platform channel errors
    SystemChannels.platform.setMethodCallHandler((call) async {
      if (call.method == 'SystemNavigator.pop') {
        // Handle back button on Android
        return _handleBackButton();
      }
      return null;
    });
  }

  void _handleError(FlutterErrorDetails details) {
    setState(() {
      _errorDetails = details;
      _errorCount++;
      _lastErrorTime = DateTime.now();
    });

    // Report to monitoring service
    _reportError(details.exception, details.stack);

    // Attempt auto-recovery if enabled
    if (widget.enableAutoRecovery && _shouldAttemptRecovery()) {
      _scheduleRecovery();
    }
  }

  void _handleAsyncError(Object error, StackTrace? stack) {
    final details = FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'Async Error',
      context: ErrorDescription('Unhandled async error'),
    );
    _handleError(details);
  }

  bool _shouldAttemptRecovery() {
    // Don't attempt recovery if too many errors in short time
    if (_errorCount > 3) {
      final timeSinceLastError = DateTime.now().difference(_lastErrorTime!);
      if (timeSinceLastError < const Duration(minutes: 1)) {
        return false; // Too many errors, don't auto-recover
      }
    }
    return true;
  }

  void _scheduleRecovery() {
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(widget.recoveryDelay, () {
      if (mounted) {
        setState(() {
          _isRecovering = true;
        });

        // Attempt to recover
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _attemptRecovery();
          }
        });
      }
    });
  }

  void _attemptRecovery() {
    try {
      setState(() {
        _errorDetails = null;
        _isRecovering = false;
        _errorCount = 0;
      });
    } catch (e) {
      // Recovery failed, show persistent error
      _reportError(e, null);
    }
  }

  void _reportError(Object error, StackTrace? stack) {
    // Report to Sentry or other monitoring service
    if (widget.errorReportingService != null) {
      widget.errorReportingService!.reportError(
        error,
        stack,
        metadata: {
          'errorCount': _errorCount,
          'lastErrorTime': _lastErrorTime?.toIso8601String(),
        },
      );
    }

    // Log to console in debug mode
    if (kDebugMode) {
      debugPrint('🔴 Error Boundary Caught: $error');
      if (stack != null) {
        debugPrint('Stack trace:\n$stack');
      }
    }
  }

  Future<bool> _handleBackButton() async {
    if (_errorDetails != null) {
      // Clear error on back button
      setState(() {
        _errorDetails = null;
      });
      return false; // Don't exit app
    }
    return true; // Allow normal back behavior
  }

  @override
  void dispose() {
    _recoveryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorDetails != null) {
      return _buildErrorUI(context);
    }

    if (_isRecovering) {
      return _buildRecoveryUI(context);
    }

    // Use ErrorWidget.builder to catch widget build errors
    return ErrorWidgetBuilder(
      onError: _handleError,
      child: widget.child,
    );
  }

  Widget _buildErrorUI(BuildContext context) {
    final error = _errorDetails!.exception;
    final errorType = _categorizeError(error);

    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Error icon with animation
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: _getErrorColor(errorType).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getErrorIcon(errorType),
                            size: 60,
                            color: _getErrorColor(errorType),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Error title
                  Text(
                    _getErrorTitle(errorType),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1C1E),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Error message
                  Text(
                    _getErrorMessage(errorType),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF44474E),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Action buttons
                  Column(
                    children: [
                      // Retry button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _attemptRecovery,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF048ABF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Try Again',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Report button
                      TextButton(
                        onPressed: () => _showErrorDetails(context),
                        child: const Text(
                          'Show Details',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF048ABF),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Debug info (only in debug mode)
                  if (kDebugMode) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Debug Info:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            error.runtimeType.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            'Error count: $_errorCount',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
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

  Widget _buildRecoveryUI(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF048ABF)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Recovering...',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF44474E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Error Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailSection(
                        'Error Message',
                        _errorDetails!.exception.toString(),
                      ),
                      if (_errorDetails!.stack != null)
                        _buildDetailSection(
                          'Stack Trace',
                          _errorDetails!.stack.toString(),
                          isMonospace: true,
                        ),
                      _buildDetailSection(
                        'Additional Info',
                        'Time: ${_lastErrorTime?.toLocal()}\n'
                        'Error Count: $_errorCount\n'
                        'App Version: ${_getAppVersion()}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _copyErrorToClipboard();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF048ABF),
                      ),
                      child: const Text(
                        'Copy Error',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _sendErrorReport(),
                      child: const Text('Send Report'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, String content, {bool isMonospace = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              content,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontFamily: isMonospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  ErrorType _categorizeError(Object error) {
    if (error is SocketException || error.toString().contains('Network')) {
      return ErrorType.network;
    }
    if (error is FormatException || error is TypeError) {
      return ErrorType.data;
    }
    if (error.toString().contains('Permission') || error.toString().contains('denied')) {
      return ErrorType.permission;
    }
    if (error is OutOfMemoryError || error.toString().contains('Memory')) {
      return ErrorType.memory;
    }
    return ErrorType.unknown;
  }

  IconData _getErrorIcon(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off_rounded;
      case ErrorType.data:
        return Icons.error_outline_rounded;
      case ErrorType.permission:
        return Icons.lock_outline_rounded;
      case ErrorType.memory:
        return Icons.memory_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color _getErrorColor(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Colors.orange;
      case ErrorType.data:
        return Colors.red;
      case ErrorType.permission:
        return Colors.purple;
      case ErrorType.memory:
        return Colors.deepOrange;
      default:
        return Colors.red;
    }
  }

  String _getErrorTitle(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'Connection Issue';
      case ErrorType.data:
        return 'Data Error';
      case ErrorType.permission:
        return 'Permission Required';
      case ErrorType.memory:
        return 'Memory Issue';
      default:
        return 'Something Went Wrong';
    }
  }

  String _getErrorMessage(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'Please check your internet connection and try again.';
      case ErrorType.data:
        return 'We encountered an issue processing data. Please try again.';
      case ErrorType.permission:
        return 'This feature requires additional permissions to work properly.';
      case ErrorType.memory:
        return 'The app is running low on memory. Please close other apps and try again.';
      default:
        return 'An unexpected error occurred. Please try again or contact support if the problem persists.';
    }
  }

  void _copyErrorToClipboard() {
    final errorText = '''
Error Report
============
Time: ${_lastErrorTime?.toLocal()}
Error: ${_errorDetails?.exception}
Stack Trace:
${_errorDetails?.stack}
    ''';
    Clipboard.setData(ClipboardData(text: errorText));
  }

  void _sendErrorReport() {
    // Implement error report sending
    _reportError(_errorDetails!.exception, _errorDetails!.stack);
  }

  String _getAppVersion() {
    // In production, get from package info
    return '1.0.0';
  }
}

/// Error widget builder that catches widget build errors
class ErrorWidgetBuilder extends StatefulWidget {
  final Widget child;
  final Function(FlutterErrorDetails) onError;

  const ErrorWidgetBuilder({
    super.key,
    required this.child,
    required this.onError,
  });

  @override
  State<ErrorWidgetBuilder> createState() => _ErrorWidgetBuilderState();
}

class _ErrorWidgetBuilderState extends State<ErrorWidgetBuilder> {
  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      widget.onError(details);
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 60,
              ),
              const SizedBox(height: 16),
              Text(
                kDebugMode
                    ? details.exception.toString()
                    : 'An error occurred while building this widget',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    };

    return widget.child;
  }
}

/// Error types for categorization
enum ErrorType {
  network,
  data,
  permission,
  memory,
  unknown,
}

/// Error reporting service interface
abstract class ErrorReportingService {
  Future<void> reportError(
    Object error,
    StackTrace? stack, {
    Map<String, dynamic>? metadata,
  });
}

/// Default error reporting implementation using Sentry
class SentryErrorReportingService implements ErrorReportingService {
  @override
  Future<void> reportError(
    Object error,
    StackTrace? stack, {
    Map<String, dynamic>? metadata,
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stack,
      withScope: (scope) {
        if (metadata != null) {
          metadata.forEach((key, value) {
            scope.setExtra(key, value);
          });
        }
      },
    );
  }
}