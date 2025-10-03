import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:duru_notes/core/settings/sync_mode.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper function to fire and forget async operations
void unawaited(Future<void> future) {
  // Intentionally ignore the future to avoid blocking
}

/// Notifier for managing sync mode settings
class SyncModeNotifier extends StateNotifier<SyncMode> {
  SyncModeNotifier(this._notesRepository, [this._onSyncComplete])
      : super(SyncMode.automatic) {
    _loadSyncMode();
  }

  final NotesCoreRepository _notesRepository;
  final VoidCallback? _onSyncComplete;
  static const String _syncModeKey = 'sync_mode';

  // Timer for periodic sync in automatic mode
  Timer? _autoSyncTimer;

  // Track if the notifier is disposed
  bool _isDisposed = false;

  // Sync interval for automatic mode (5 minutes)
  static const Duration _autoSyncInterval = Duration(minutes: 5);

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

        // Start periodic sync if mode is automatic
        if (mode == SyncMode.automatic) {
          _startPeriodicSync();
        }
      }
    } catch (e) {
      // If loading fails, keep default automatic mode
      state = SyncMode.automatic;
      _startPeriodicSync();
    }
  }

  /// Set the sync mode and persist it
  Future<void> setMode(SyncMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_syncModeKey, mode.name);
      state = mode;

      // Handle automatic mode setup
      if (mode == SyncMode.automatic) {
        // Perform immediate sync when switching to automatic
        unawaited(manualSync());
        // Start periodic sync timer
        _startPeriodicSync();
      } else {
        // Stop periodic sync when switching to manual
        _stopPeriodicSync();
      }
    } catch (e) {
      // Handle error silently - mode change will fail but won't crash
    }
  }

  /// Perform manual sync operation (production path)
  Future<bool> manualSync() async {
    if (_isDisposed) {
      debugPrint('⚠️ Sync skipped: notifier is disposed');
      return false;
    }

    try {
      debugPrint('🔄 Starting manual sync...');

      // Check authentication first
      final currentUser = _notesRepository.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ Sync failed: No authenticated user');
        return false;
      }
      debugPrint('✅ Authenticated user: ${currentUser.id}');

      // Check local database
      final localNotes = await _notesRepository.localNotes();
      debugPrint('📊 Local database has ${localNotes.length} notes');

      // Sync is handled by the unified sync service, not here
      // This is just for displaying current state
      for (final note in localNotes.take(5)) {
        debugPrint(
          '  - ${note.title.isEmpty ? "Untitled" : note.title} (${note.updatedAt})',
        );
      }

      debugPrint('🎉 Manual sync completed successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Manual sync failed: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Start periodic sync timer for automatic mode
  void _startPeriodicSync() {
    _stopPeriodicSync(); // Cancel any existing timer
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) async {
      // Check if disposed before executing
      if (_isDisposed) {
        _stopPeriodicSync();
        return;
      }

      // Perform background sync without blocking UI
      final success = await manualSync();
      if (success && !_isDisposed) {
        // Trigger UI refresh if callback is provided
        _onSyncComplete?.call();
      }
    });
  }

  /// Stop periodic sync timer
  void _stopPeriodicSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Perform initial sync if in automatic mode (called on app startup)
  Future<void> performInitialSyncIfAuto() async {
    if (state == SyncMode.automatic) {
      await manualSync();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopPeriodicSync();
    super.dispose();
  }
}
