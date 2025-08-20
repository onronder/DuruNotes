import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart'
    show
        PostgresChangeEvent,
        PostgresChangeFilter,
        PostgresChangeFilterType,
        PostgresChangePayload,
        RealtimeChannel;

import 'package:duru_notes_app/repository/notes_repository.dart';

class SyncService {
  SyncService(this.repo);

  final NotesRepository repo;

  // last_pull anahtarını kullanıcıya özel tut (çok kullanıcı güvenliği)
  static const _kLastPullBase = 'last_pull_at';
  String get _lastPullKey {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    return '$_kLastPullBase:$uid';
  }

  // Realtime
  RealtimeChannel? _notesChannel;
  StreamSubscription<AuthState>? _authSub;
  Timer? _debounce;

  // Sync reentrancy guard
  Future<void>? _ongoingSync;

  // UI invalidation için yayın
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  /// Ağ çağrıları için maksimum bekleme süresi
  static const Duration _networkTimeout = Duration(seconds: 10);

  Future<void> syncNow() {
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

    // 1) Pending değişiklikleri push et
    await repo.pushAllPending();

    // 2) Değişiklikleri Supabase’ten çek (zaman aşımı ile)
    final prefs = await SharedPreferences.getInstance();
    final sinceIso = prefs.getString(_lastPullKey);
    final since = sinceIso != null ? DateTime.tryParse(sinceIso) : null;

    try {
      await repo.pullSince(since).timeout(_networkTimeout);
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('pullSince timed out: $e');
    } on Object catch (e) {
      if (kDebugMode) debugPrint('pullSince failed: $e');
    }

    // 3) Hard delete uzaktan gerçeği kabul et (yine zaman aşımı ile)
    Set<String> remoteIds = const {};
    try {
      remoteIds =
          await repo.fetchRemoteActiveIds().timeout(_networkTimeout);
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('fetchRemoteActiveIds timed out: $e');
    } on Object catch (e) {
      if (kDebugMode) debugPrint('fetchRemoteActiveIds failed: $e');
    }

    try {
      if (remoteIds.isNotEmpty) {
        await repo.reconcileHardDeletes(remoteIds);
      }
    } on Object catch (e) {
      if (kDebugMode) debugPrint('reconcileHardDeletes failed: $e');
    }

    // 4) Son çekim zamanını güncelle
    await prefs.setString(
      _lastPullKey,
      DateTime.now().toUtc().toIso8601String(),
    );

    // 5) UI'ı bilgilendir
    _changes.add(null);
  }

  Future<void> reset() async {
    await repo.db.clearAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastPullKey);
    _changes.add(null);
  }

  /// Realtime aboneliğini başlat
  void startRealtime() {
    final client = Supabase.instance.client;

    _authSub?.cancel();
    _authSub = client.auth.onAuthStateChange.listen((event) {
      if (kDebugMode) debugPrint('Auth state changed: ${event.event}');
      _bindRealtime();

      // Girişten sonra küçük gecikmeyle sync
      if (event.session != null) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 250), () {
          unawaited(syncNow());
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

    // Eski kanalı kaldır
    if (_notesChannel != null) {
      client.removeChannel(_notesChannel!);
      _notesChannel = null;
    }

    if (uid == null) return;

    final ch = client.channel('public:notes');

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
        callback: (PostgresChangePayload payload) {
          // Olayları toplu sync’e dönüştür (debounce).
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 400), () {
            unawaited(syncNow());
          });

          if (kDebugMode) {
            final id = payload.newRecord['id'] ?? payload.oldRecord['id'];
            debugPrint('Realtime ${ev.name} on notes id=$id');
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
