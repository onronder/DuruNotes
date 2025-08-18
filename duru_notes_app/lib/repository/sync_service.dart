import 'package:duru_notes_app/repository/notes_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncService {
  SyncService(this.repo);
  final NotesRepository repo;
  static const _kLastPull = 'last_pull_at';

  Future<void> syncNow() async {
    await repo.pushAllPending();

    final prefs = await SharedPreferences.getInstance();
    final sinceIso = prefs.getString(_kLastPull);
    final since = sinceIso != null ? DateTime.tryParse(sinceIso) : null;

    await repo.pullSince(since);

    // NEW: hard-delete reconciliation (always on)
    final remoteIds = await repo.fetchRemoteActiveIds();
    await repo.reconcileHardDeletes(remoteIds);

    await prefs.setString(_kLastPull, DateTime.now().toUtc().toIso8601String());
  }

  Future<void> reset() async {
    await repo.db.clearAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastPull);
  }
}
