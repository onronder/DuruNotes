import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repository/notes_repository.dart';
import 'sync_mode.dart';

/// Notifier for managing sync mode settings
class SyncModeNotifier extends StateNotifier<SyncMode> {
  SyncModeNotifier(this._notesRepository) : super(SyncMode.automatic) {
    _loadSyncMode();
  }

  final NotesRepository _notesRepository;
  static const String _syncModeKey = 'sync_mode';

  /// Load sync mode from SharedPreferences
  Future<void> _loadSyncMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeString = prefs.getString(_syncModeKey);
      
      if (modeString != null) {
        final mode = SyncMode.values.firstWhere(
          (e) => e.name == modeString,
          orElse: () => SyncMode.automatic,
        );
        state = mode;
      }
    } catch (e) {
      // If loading fails, keep default automatic mode
      state = SyncMode.automatic;
    }
  }

  /// Set the sync mode and persist it
  Future<void> setMode(SyncMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_syncModeKey, mode.name);
      state = mode;
    } catch (e) {
      // Handle error silently - mode change will fail but won't crash
    }
  }

  /// Perform manual sync operation
  Future<bool> manualSync() async {
    try {
      // Push all pending changes first
      await _notesRepository.pushAllPending();
      
      // Then pull latest changes
      await _notesRepository.pullSince(null);
      
      return true;
    } catch (e) {
      return false;
    }
  }
}
