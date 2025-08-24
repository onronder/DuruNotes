import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType;

import 'package:duru_notes_app/repository/notes_repository.dart';

class SyncService {
  SyncService(this.repo);

  final NotesRepository repo;

  static const _kLastPullBase = 'last_pull_at';
  String get _lastPullKey {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    return '$_kLastPullBase:$uid';
  }

  RealtimeChannel? _notesChannel;
  StreamSubscription<AuthState>? _authSub;
  Timer? _debounce;

  Future<void>? _ongoingSync;

  DateTime? _nextAllowedSyncAt;
  int _consecutiveFailures = 0;

  bool get _isBackoffActive =>
      _nextAllowedSyncAt != null &&
      DateTime.now().isBefore(_nextAllowedSyncAt!);

  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  Future<void> syncNow() {
    if (_isBackoffActive) {
      if (kDebugMode) {
        debugPrint('Sync skipped (backoff active until $_nextAllowedSyncAt)');
      }
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
      if (kDebugMode) debugPrint('Sync skipped: no active session');
      return;
    }

    try {
      await repo.pushAllPending().timeout(const Duration(seconds: 10));

      final prefs = await SharedPreferences.getInstance();
      final sinceIso = prefs.getString(_lastPullKey);
      final since = sinceIso != null ? DateTime.tryParse(sinceIso) : null;

      await repo.pullSince(since).timeout(const Duration(seconds: 10));

      final remoteIds =
          await repo.fetchRemoteActiveIds().timeout(const Duration(seconds: 10));
      await repo.reconcileHardDeletes(remoteIds);

      await prefs.setString(
        _lastPullKey,
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
    if (kDebugMode) {
      debugPrint('syncNow $label -> backoff ${backoff.inSeconds}s ($e)');
    }
  }

  Future<void> reset() async {
    await repo.db.clearAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastPullKey);
    _consecutiveFailures = 0;
    _nextAllowedSyncAt = null;
    _changes.add(null);
  }

  void startRealtime() {
    final client = Supabase.instance.client;

    _authSub?.cancel();
    _authSub = client.auth.onAuthStateChange.listen((event) {
      if (kDebugMode) debugPrint('Auth state changed: ${event.event}');
      _bindRealtime();

      if (event.session != null) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 250), () {
          if (!_isBackoffActive) {
            unawaited(syncNow());
          }
        });
      } else {
        unawaited(reset());
      }
    });

    _bindRealtime();
  }

  void _bindRealtime() {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;

    if (_notesChannel != null) {
      client.removeChannel(_notesChannel!);
      _notesChannel = null;
    }
    if (uid == null) return;

    final ch = client.channel('realtime:notes:$uid');

    void register(PostgresChangeEvent ev) {
      ch.onPostgresChanges(
        event: ev,
        schema: 'public',
        table: 'notes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: uid,
        ),
        callback: (_) {
          if (_isBackoffActive) return;

          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 400), () {
            unawaited(syncNow());
          });

          if (kDebugMode) {
            debugPrint('Realtime ${ev.name} on notes');
          }
        },
      );
    }

    register(PostgresChangeEvent.insert);
    register(PostgresChangeEvent.update);
    register(PostgresChangeEvent.delete);

    ch.subscribe((status, _) {
      if (kDebugMode) debugPrint('Realtime channel status: $status');
    });

    _notesChannel = ch;
  }

  void stopRealtime() {
    _debounce?.cancel();
    _debounce = null;

    final client = Supabase.instance.client;
    if (_notesChannel != null) {
      client.removeChannel(_notesChannel!);
      _notesChannel = null;
    }

    _authSub?.cancel();
    _authSub = null;
  }
}
