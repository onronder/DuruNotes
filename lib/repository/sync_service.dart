import 'dart:async';
import 'dart:math';

import 'package:duru_notes/core/errors.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/result.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/services/debounced_update_service.dart';
import 'package:duru_notes/services/unified_realtime_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sync operation result with detailed status
@Deprecated('Use Result<SyncSuccess, AppError> instead')
class SyncResult {
  const SyncResult({
    required this.success,
    this.error,
    this.isAuthError = false,
    this.isRateLimited = false,
    this.retryAfter,
  });

  final bool success;
  final String? error;
  final bool isAuthError;
  final bool isRateLimited;
  final Duration? retryAfter;
}

/// Successful sync operation data
class SyncSuccess {
  const SyncSuccess({
    required this.itemsSynced,
    required this.syncedAt,
    required this.duration,
  });
  final int itemsSynced;
  final DateTime syncedAt;
  final Duration duration;
}

class SyncService {
  SyncService(this.repo) : _logger = LoggerFactory.instance;

  final NotesRepository repo;
  final AppLogger _logger;

  static const _kLastPullBase = 'last_pull_at';
  String _lastPullKey(String userId) => '$_kLastPullBase:$userId';

  // REMOVED: RealtimeChannel - using unified service instead
  // Use debounced update service instead of manual timer
  final _debouncer = DebouncedUpdateService(
    defaultDelay: const Duration(milliseconds: 400),
  );

  // Subscriptions to unified realtime
  StreamSubscription<DatabaseChangeEvent>? _notesSubscription;
  StreamSubscription<DatabaseChangeEvent>? _foldersSubscription;
  StreamSubscription<AuthState>? _authSub;

  // Reference to unified realtime service
  UnifiedRealtimeService? _unifiedRealtime;

  Future<void>? _ongoingSync;

  DateTime? _nextAllowedSyncAt;
  int _consecutiveFailures = 0;

  // Enhanced retry configuration
  static const Duration _baseRetryDelay = Duration(seconds: 1);
  static const Duration _maxRetryDelay = Duration(minutes: 5);
  static const int _maxRetries = 5;

  bool get _isBackoffActive =>
      _nextAllowedSyncAt != null &&
      DateTime.now().isBefore(_nextAllowedSyncAt!);

  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  Future<void> syncNow() {
    if (_isBackoffActive) {
      _logger.debug(
        'Sync skipped due to backoff',
        data: {'nextAllowedAt': _nextAllowedSyncAt?.toIso8601String()},
      );
      return Future.value();
    }

    final inFlight = _ongoingSync;
    if (inFlight != null) return inFlight;

    final future = _syncInternal();
    _ongoingSync = future;
    return future.whenComplete(() {
      _ongoingSync = null;
    });
  }

  Future<void> _syncInternal() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _logger.debug('Sync skipped: no active session');
      return;
    }

    try {
      await repo.pushAllPending().timeout(const Duration(seconds: 30));

      final prefs = await SharedPreferences.getInstance();
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final sinceIso = prefs.getString(_lastPullKey(uid));
      var since = sinceIso != null ? DateTime.tryParse(sinceIso) : null;

      // If local store is empty, force a full pull regardless of 'since'
      final localCount = (await repo.db.allNotes()).length;
      if (localCount == 0) {
        _logger.info('Forcing full pull due to empty local store');
        since = null;
      }

      await repo.pullSince(since).timeout(const Duration(seconds: 30));

      final remoteIds = await repo.fetchRemoteActiveIds().timeout(
        const Duration(seconds: 30),
      );
      await repo.reconcileHardDeletes(remoteIds);

      await prefs.setString(
        _lastPullKey(uid),
        DateTime.now().toUtc().toIso8601String(),
      );

      _consecutiveFailures = 0;
      _nextAllowedSyncAt = null;

      _changes.add(null);
    } on TimeoutException catch (e) {
      _scheduleBackoff(e, label: 'timeout');
      rethrow;
    } catch (e) {
      _scheduleBackoff(e, label: 'error');
      rethrow;
    }
  }

  void _scheduleBackoff(Object e, {required String label}) {
    _consecutiveFailures = min(_consecutiveFailures + 1, 6);
    final seconds = pow(2, _consecutiveFailures).toInt();
    final backoff = Duration(seconds: min(seconds, 64));
    _nextAllowedSyncAt = DateTime.now().add(backoff);

    _logger.warning(
      'Scheduling sync backoff',
      data: {
        'label': label,
        'backoffSeconds': backoff.inSeconds,
        'consecutiveFailures': _consecutiveFailures,
        'error': e.toString(),
      },
    );
  }

  /// Modern sync with Result type for better error handling
  Future<Result<SyncSuccess, AppError>> sync() async {
    final stopwatch = Stopwatch()..start();

    if (_isBackoffActive) {
      _logger.debug(
        'Sync blocked by backoff',
        data: {'nextAllowedAt': _nextAllowedSyncAt?.toIso8601String()},
      );
      return Result.failure(
        RateLimitError(
          message: 'Sync is rate limited',
          retryAfter: _nextAllowedSyncAt?.difference(DateTime.now()),
        ),
      );
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _logger.info('Sync skipped: no active session');
      return Result.failure(
        const AuthError(
          message: 'No active session',
          type: AuthErrorType.sessionExpired,
        ),
      );
    }

    Exception? lastException;

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          final delay = _calculateRetryDelay(attempt - 1);
          _logger.debug(
            'Sync retry attempt',
            data: {'attempt': attempt, 'delaySeconds': delay.inSeconds},
          );
          await Future<void>.delayed(delay);
        }

        final itemCount = await _performSyncOperations();

        // Success - reset failure count
        _consecutiveFailures = 0;
        _nextAllowedSyncAt = null;
        _changes.add(null);

        stopwatch.stop();

        _logger.info(
          'Sync completed successfully',
          data: {
            'itemsSynced': itemCount,
            'durationMs': stopwatch.elapsedMilliseconds,
            'attempts': attempt + 1,
          },
        );

        return Result.success(
          SyncSuccess(
            itemsSynced: itemCount,
            syncedAt: DateTime.now(),
            duration: stopwatch.elapsed,
          ),
        );
      } on AuthException catch (e, stack) {
        _logger.error('Auth error during sync', error: e, stackTrace: stack);

        // Don't retry auth errors
        return Result.failure(AuthError.fromAuthException(e, stack));
      } on TimeoutException catch (e) {
        lastException = e;

        _logger.warning(
          'Sync timeout',
          data: {'attempt': attempt, 'maxRetries': _maxRetries},
        );

        if (attempt == _maxRetries - 1) {
          _scheduleBackoff(e, label: 'timeout');
        }
      } catch (e, stack) {
        lastException = Exception(e.toString());

        _logger.error(
          'Sync error',
          error: e,
          stackTrace: stack,
          data: {'attempt': attempt, 'maxRetries': _maxRetries},
        );

        // Check if it's a rate limiting error
        if (_isRateLimitError(e)) {
          final retryAfter = _extractRetryAfter(e);
          _scheduleBackoff(e, label: 'rate_limit');

          return Result.failure(
            RateLimitError(
              message: 'Sync rate limited',
              retryAfter: retryAfter,
              originalError: e,
              stackTrace: stack,
            ),
          );
        }

        // For other errors, continue retrying unless it's the last attempt
        if (attempt == _maxRetries - 1) {
          _scheduleBackoff(e, label: 'error');
        }
      }
    }

    // All retries failed
    stopwatch.stop();

    _logger.error(
      'Sync failed after all retries',
      data: {
        'attempts': _maxRetries,
        'durationMs': stopwatch.elapsedMilliseconds,
      },
    );

    return Result.failure(
      ErrorFactory.fromException(
        lastException ?? Exception('Sync failed after $_maxRetries attempts'),
      ),
    );
  }

  /// Enhanced sync with retry logic and better error handling
  @Deprecated('Use sync() which returns Result<SyncSuccess, AppError>')
  Future<SyncResult> syncWithRetry() async {
    if (_isBackoffActive) {
      _logger.debug(
        'Sync skipped (backoff active)',
        data: {'nextAllowedAt': _nextAllowedSyncAt?.toIso8601String()},
      );
      return SyncResult(
        success: false,
        error: 'Sync in backoff until $_nextAllowedSyncAt',
      );
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _logger.debug('Sync skipped: no active session');
      return const SyncResult(
        success: false,
        error: 'No active session',
        isAuthError: true,
      );
    }

    Exception? lastException;

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          final delay = _calculateRetryDelay(attempt - 1);
          _logger.debug(
            'Sync retry attempt',
            data: {'attempt': attempt, 'delaySeconds': delay.inSeconds},
          );
          await Future<void>.delayed(delay);
        }

        await _performSyncOperations();

        // Success - reset failure count
        _consecutiveFailures = 0;
        _nextAllowedSyncAt = null;
        _changes.add(null);

        return const SyncResult(success: true);
      } on AuthException catch (e) {
        lastException = e;

        // Don't retry auth errors
        return SyncResult(success: false, error: e.message, isAuthError: true);
      } on TimeoutException catch (e) {
        lastException = e;

        if (attempt == _maxRetries - 1) {
          _scheduleBackoff(e, label: 'timeout');
        }
      } catch (e) {
        lastException = Exception(e.toString());

        // Check if it's a rate limiting error
        if (_isRateLimitError(e)) {
          final retryAfter = _extractRetryAfter(e);
          _scheduleBackoff(e, label: 'rate_limit');

          return SyncResult(
            success: false,
            error: 'Rate limited',
            isRateLimited: true,
            retryAfter: retryAfter,
          );
        }

        // For other errors, continue retrying unless it's the last attempt
        if (attempt == _maxRetries - 1) {
          _scheduleBackoff(e, label: 'error');
        }
      }
    }

    // All retries failed
    return SyncResult(
      success: false,
      error:
          lastException?.toString() ??
          'Sync failed after $_maxRetries attempts',
    );
  }

  /// Perform the actual sync operations
  /// Returns the number of items synced
  Future<int> _performSyncOperations() async {
    var itemsSynced = 0;
    await repo.pushAllPending().timeout(const Duration(seconds: 10));

    final prefs = await SharedPreferences.getInstance();
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final sinceIso = prefs.getString(_lastPullKey(uid));
    var since = sinceIso != null ? DateTime.tryParse(sinceIso) : null;

    // If local is empty, force full pull
    final localCount = (await repo.db.allNotes()).length;
    if (localCount == 0) {
      _logger.info('Performing full pull (local store empty)');
      since = null;
    }

    await repo.pullSince(since).timeout(const Duration(seconds: 10));
    // Note: pullSince returns void, so we can't get exact count
    // Could be improved by modifying pullSince to return count
    itemsSynced = (await repo.db.allNotes()).length;

    final remoteIds = await repo.fetchRemoteActiveIds().timeout(
      const Duration(seconds: 10),
    );
    await repo.reconcileHardDeletes(remoteIds);

    await prefs.setString(
      _lastPullKey(uid),
      DateTime.now().toUtc().toIso8601String(),
    );

    return itemsSynced;
  }

  /// Calculate retry delay with exponential backoff and jitter
  Duration _calculateRetryDelay(int attemptNumber) {
    final exponentialDelay = Duration(
      milliseconds:
          _baseRetryDelay.inMilliseconds * pow(2, attemptNumber).toInt(),
    );

    // Add jitter to prevent thundering herd (±25% of delay)
    final jitterRange = (exponentialDelay.inMilliseconds * 0.25).toInt();
    final jitter = Duration(
      milliseconds: Random().nextInt(jitterRange * 2) - jitterRange,
    );

    final totalDelay = exponentialDelay + jitter;
    return totalDelay > _maxRetryDelay ? _maxRetryDelay : totalDelay;
  }

  /// Check if error indicates rate limiting
  bool _isRateLimitError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('rate limit') ||
        errorStr.contains('too many requests') ||
        errorStr.contains('429') ||
        errorStr.contains('quota exceeded');
  }

  /// Extract retry-after duration from error (if available)
  Duration? _extractRetryAfter(dynamic error) {
    // This would parse headers or error messages for retry-after values
    // For now, return a default delay
    return const Duration(seconds: 30);
  }

  Future<void> reset() async {
    await repo.db.clearAll();
    final prefs = await SharedPreferences.getInstance();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      await prefs.remove(_lastPullKey(uid));
    }
    _consecutiveFailures = 0;
    _nextAllowedSyncAt = null;
    _changes.add(null);
  }

  void startRealtime({UnifiedRealtimeService? unifiedService}) {
    final client = Supabase.instance.client;

    // Store reference to unified service
    _unifiedRealtime = unifiedService;

    _authSub?.cancel();
    _authSub = client.auth.onAuthStateChange.listen((event) {
      _logger.debug('Auth state changed', data: {'event': event.event.name});
      _bindRealtime();

      if (event.session != null) {
        _debouncer.scheduleUpdate('auth_sync', () {
          if (!_isBackoffActive) {
            unawaited(syncNow());
          }
        }, customDelay: const Duration(milliseconds: 250));
      } else {
        unawaited(reset());
      }
    });

    _bindRealtime();
  }

  void _bindRealtime() {
    // Cancel existing subscriptions
    _notesSubscription?.cancel();
    _foldersSubscription?.cancel();

    // If no unified service provided, skip realtime
    if (_unifiedRealtime == null) {
      _logger.debug('No unified realtime service available');
      return;
    }

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    // Subscribe to notes changes from unified service
    _notesSubscription = _unifiedRealtime!.notesStream.listen((event) {
      if (_isBackoffActive) return;

      _debouncer.scheduleUpdate('notes_sync', () {
        if (!_isBackoffActive) {
          unawaited(syncNow());
        }
      });

      _logger.debug(
        'Notes change received',
        data: {'eventType': event.eventType.name},
      );
    });

    // Subscribe to folders changes from unified service
    _foldersSubscription = _unifiedRealtime!.foldersStream.listen((event) {
      if (_isBackoffActive) return;

      _debouncer.scheduleUpdate('folders_sync', () {
        if (!_isBackoffActive) {
          unawaited(syncNow());
        }
      });

      _logger.debug(
        'Folders change received',
        data: {'eventType': event.eventType.name},
      );
    });

    _logger.info('Subscribed to unified realtime service');
  }

  void stopRealtime() {
    _debouncer.cancelAll();

    // Cancel unified realtime subscriptions
    _notesSubscription?.cancel();
    _notesSubscription = null;

    _foldersSubscription?.cancel();
    _foldersSubscription = null;

    _authSub?.cancel();
    _authSub = null;

    _unifiedRealtime = null;

    _logger.debug('Stopped realtime subscriptions');
  }
}
