import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:duru_notes/core/errors.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/monitoring/sentry_config.dart';
import 'package:duru_notes/core/result.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A wrapper for network operations with automatic error handling,
/// retry logic, and offline detection
class NetworkAwareService {
  static final AppLogger _logger = LoggerFactory.instance;

  /// Check if we have network connectivity
  static Future<bool> hasConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return !results.contains(ConnectivityResult.none);
    } catch (e) {
      _logger.warning(
        'Failed to check connectivity',
        data: {'error': e.toString()},
      );
      return true; // Assume online if check fails
    }
  }

  /// Execute a network operation with error handling and retry logic
  static Future<Result<T, AppError>> execute<T>({
    required Future<T> Function() operation,
    required String operationName,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
    bool requiresAuth = false,
    bool showUserFeedback = true,
    BuildContext? context,
  }) async {
    // Check connectivity first
    final isOnline = await hasConnectivity();
    if (!isOnline) {
      _logger.info(
        'Operation skipped - offline',
        data: {'operation': operationName},
      );

      if (showUserFeedback && context != null && context.mounted) {
        _showOfflineSnackbar(context);
      }

      return Result.failure(
        const NetworkError(message: 'No internet connection', code: 'OFFLINE'),
      );
    }

    // Check authentication if required
    if (requiresAuth) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        _logger.warning(
          'Operation requires auth but no session',
          data: {'operation': operationName},
        );

        if (showUserFeedback && context != null && context.mounted) {
          _showAuthRequiredSnackbar(context);
        }

        return Result.failure(
          const AuthError(
            message: 'Authentication required',
            type: AuthErrorType.sessionExpired,
          ),
        );
      }
    }

    // Add breadcrumb for operation tracking
    SentryConfig.addBreadcrumb(
      message: 'Starting network operation: $operationName',
      category: 'network',
      data: {'maxRetries': maxRetries},
    );

    // Start performance tracking
    final transaction = SentryConfig.startTransaction(
      operationName,
      'network.operation',
    );

    Exception? lastException;

    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          _logger.debug(
            'Retrying operation',
            data: {
              'operation': operationName,
              'attempt': attempt + 1,
              'maxRetries': maxRetries,
            },
          );

          // Exponential backoff
          final delay = retryDelay * (attempt * 2);
          await Future<void>.delayed(delay);

          // Check connectivity again before retry
          final stillOnline = await hasConnectivity();
          if (!stillOnline) {
            throw const SocketException('Lost connectivity during retry');
          }
        }

        // Execute the operation
        final result = await operation().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException(
              'Operation timed out',
              const Duration(seconds: 30),
            );
          },
        );

        // Success
        transaction?.finish();

        _logger.info(
          'Operation completed successfully',
          data: {'operation': operationName, 'attempts': attempt + 1},
        );

        return Result.success(result);
      } on PostgrestException catch (e, stack) {
        lastException = e;

        _logger.error(
          'Database error in operation',
          error: e,
          stackTrace: stack,
          data: {
            'operation': operationName,
            'attempt': attempt + 1,
            'code': e.code,
          },
        );

        // Don't retry on certain errors
        if (e.code == '23505') {
          // Unique violation
          transaction?.finish(status: const SpanStatus.internalError());

          if (showUserFeedback && context != null && context.mounted) {
            _showErrorSnackbar(context, 'This item already exists');
          }

          return Result.failure(
            ValidationError(
              message: 'Duplicate entry',
              code: e.code,
              originalError: e,
              stackTrace: stack,
            ),
          );
        }

        // Don't retry on 4xx errors (client errors)
        final statusCode = int.tryParse(e.code ?? '');
        if (statusCode != null && statusCode >= 400 && statusCode < 500) {
          transaction?.finish(status: const SpanStatus.internalError());

          if (showUserFeedback && context != null && context.mounted) {
            _showErrorSnackbar(
              context,
              'Request failed. Please check your input.',
            );
          }

          return Result.failure(NetworkError.fromPostgrestException(e, stack));
        }
      } on AuthException catch (e, stack) {
        transaction?.finish(status: const SpanStatus.unauthenticated());

        _logger.error(
          'Auth error in operation',
          error: e,
          stackTrace: stack,
          data: {'operation': operationName},
        );

        if (showUserFeedback && context != null && context.mounted) {
          _showAuthRequiredSnackbar(context);
        }

        // Don't retry auth errors
        return Result.failure(AuthError.fromAuthException(e, stack));
      } on SocketException catch (e, stack) {
        lastException = e;

        _logger.error(
          'Network error in operation',
          error: e,
          stackTrace: stack,
          data: {'operation': operationName, 'attempt': attempt + 1},
        );

        // Check if we're offline
        final isOnline = await hasConnectivity();
        if (!isOnline) {
          transaction?.finish(status: const SpanStatus.unavailable());

          if (showUserFeedback && context != null && context.mounted) {
            _showOfflineSnackbar(context);
          }

          return Result.failure(
            NetworkError(
              message: 'Lost internet connection',
              code: 'OFFLINE',
              originalError: e,
              stackTrace: stack,
            ),
          );
        }
      } on TimeoutException catch (e, stack) {
        lastException = e;

        _logger.error(
          'Timeout in operation',
          error: e,
          stackTrace: stack,
          data: {'operation': operationName, 'attempt': attempt + 1},
        );

        if (attempt == maxRetries - 1 &&
            showUserFeedback &&
            context != null &&
            context.mounted) {
          _showErrorSnackbar(
            context,
            'Operation is taking too long. Please try again.',
          );
        }
      } catch (e, stack) {
        lastException = e as Exception;

        _logger.error(
          'Unexpected error in operation',
          error: e,
          stackTrace: stack,
          data: {'operation': operationName, 'attempt': attempt + 1},
        );

        // Capture unexpected errors to Sentry
        if (attempt == maxRetries - 1) {
          await SentryConfig.captureException(
            e,
            stackTrace: stack,
            tags: {
              'operation': operationName,
              'attempts': (attempt + 1).toString(),
            },
            extra: {'requiresAuth': requiresAuth},
          );
        }
      }
    }

    // All retries failed
    transaction?.finish(status: const SpanStatus.deadlineExceeded());

    _logger.error(
      'Operation failed after all retries',
      data: {'operation': operationName, 'attempts': maxRetries},
    );

    if (showUserFeedback && context != null && context.mounted) {
      _showErrorSnackbar(
        context,
        'Operation failed. Please check your connection and try again.',
      );
    }

    return Result.failure(
      ErrorFactory.fromException(
        lastException ??
            Exception('Operation failed after $maxRetries attempts'),
      ),
    );
  }

  /// Execute a batch of network operations with transaction semantics
  static Future<Result<List<T>, AppError>> executeBatch<T>({
    required List<Future<T> Function()> operations,
    required String batchName,
    bool parallel = false,
    bool stopOnFirstError = true,
    BuildContext? context,
  }) async {
    _logger.info(
      'Starting batch operation',
      data: {
        'batch': batchName,
        'count': operations.length,
        'parallel': parallel,
      },
    );

    final results = <T>[];
    final errors = <AppError>[];

    if (parallel) {
      // Execute all operations in parallel
      final futures = operations
          .map(
            (op) => execute(
              operation: op,
              operationName: '$batchName-item',
              showUserFeedback: false,
            ),
          )
          .toList();

      final batchResults = await Future.wait(futures);

      for (final result in batchResults) {
        result.when(
          success: results.add,
          failure: (error) {
            errors.add(error);
          },
        );
        // Check if we should stop on first error
        if (stopOnFirstError && errors.isNotEmpty) {
          return Result<List<T>, AppError>.failure(errors.first);
        }
      }
    } else {
      // Execute operations sequentially
      for (var i = 0; i < operations.length; i++) {
        final result = await execute(
          operation: operations[i],
          operationName: '$batchName-item-$i',
          showUserFeedback: false,
        );

        final shouldStop = result.when(
          success: (value) {
            results.add(value);
            return false;
          },
          failure: (error) {
            errors.add(error);
            return stopOnFirstError;
          },
        );

        if (shouldStop) {
          return Result.failure(errors.first);
        }
      }
    }

    if (errors.isNotEmpty) {
      _logger.warning(
        'Batch operation had errors',
        data: {
          'batch': batchName,
          'successCount': results.length,
          'errorCount': errors.length,
        },
      );

      if (context != null && context.mounted) {
        _showErrorSnackbar(
          context,
          'Some operations failed (${errors.length} of ${operations.length})',
        );
      }

      return Result.failure(
        UnexpectedError(
          message: 'Batch operation partially failed',
          context: {
            'successCount': results.length,
            'errorCount': errors.length,
            'errors': errors.map((e) => e.message).toList(),
          },
        ),
      );
    }

    _logger.info(
      'Batch operation completed successfully',
      data: {'batch': batchName, 'count': results.length},
    );

    return Result.success(results);
  }

  // Helper methods for showing user feedback

  static void _showOfflineSnackbar(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text('No internet connection. Please check your network.'),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  static void _showAuthRequiredSnackbar(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.lock, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('Please sign in to continue')),
          ],
        ),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Sign In',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to auth screen
            // Navigator.of(context).pushNamed('/auth');
          },
        ),
      ),
    );
  }

  static void _showErrorSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }
}
