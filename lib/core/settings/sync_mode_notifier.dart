import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:duru_notes/core/settings/sync_mode.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/services/unified_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper function to fire and forget async operations
void unawaited(Future<void> future) {
  // Intentionally ignore the future to avoid blocking
}

/// Notifier for managing sync mode settings
class SyncModeNotifier extends StateNotifier<SyncMode> {
  SyncModeNotifier(this._notesRepository, this._syncService)
    : super(SyncMode.automatic) {
    _loadSyncMode();
  }

  final NotesCoreRepository _notesRepository;
  final UnifiedSyncService _syncService;
  static const String _syncModeKey = 'sync_mode';

  // Timer for periodic sync in automatic mode
  Timer? _autoSyncTimer;

  // Track if the notifier is disposed
  bool _isDisposed = false;

  // Prevent concurrent mode changes (production safety)
  bool _isChangingMode = false;

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
  /// PRODUCTION FIX: Non-blocking implementation to prevent UI freeze
  Future<void> setMode(SyncMode mode) async {
    // Prevent concurrent mode changes (production safety)
    if (_isChangingMode) {
      debugPrint(
        '⚠️ Mode change already in progress, ignoring duplicate request',
      );
      return;
    }
    _isChangingMode = true;

    try {
      // CRITICAL: Stop any active periodic sync IMMEDIATELY
      // This prevents race conditions between old timer and new mode
      _stopPeriodicSync();

      // Update UI state FIRST (non-blocking, immediate feedback)
      state = mode;

      // Persist to storage in background (don't block UI)
      // If this fails, the mode will revert on next app launch, which is acceptable
      unawaited(_persistModeToStorage(mode));

      // Setup new mode behavior
      if (mode == SyncMode.automatic) {
        // Start periodic sync timer
        _startPeriodicSync();
        // PRODUCTION FIX: Don't trigger immediate sync to avoid rate limiting
        // The periodic timer will handle the first sync after 5 minutes
        // If user wants immediate sync, they can use the Sync Now button
        debugPrint('📅 Automatic sync enabled - next sync in 5 minutes');
      }
      // If manual mode, timer is already stopped above
    } catch (e) {
      debugPrint('⚠️ Error changing sync mode: $e');
      // Don't crash - degraded mode is better than app crash
    } finally {
      _isChangingMode = false;
    }
  }

  /// Persist sync mode to SharedPreferences (background operation)
  Future<void> _persistModeToStorage(SyncMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
      );
      await prefs.setString(_syncModeKey, mode.name);
      debugPrint('✅ Sync mode persisted: ${mode.name}');
    } catch (e) {
      debugPrint('⚠️ Failed to persist sync mode (will revert on restart): $e');
      // Non-fatal: User's in-session mode change still works
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

      // CRITICAL FIX: Actually call the unified sync service!
      debugPrint('📥 Calling UnifiedSyncService.syncAll()...');
      final syncResult = await _syncService.syncAll();

      if (syncResult.success) {
        debugPrint('✅ Sync completed successfully');
        debugPrint(
          '📊 Synced: ${syncResult.syncedNotes} notes, ${syncResult.syncedTasks} tasks',
        );

        // Check local database after sync
        final localNotes = await _notesRepository.localNotes();
        debugPrint('📊 Local database now has ${localNotes.length} notes');

        // Note: UI will refresh automatically through Riverpod streams
        debugPrint(
          '📱 Sync complete - UI will refresh through repository streams',
        );

        return true;
      } else {
        debugPrint('⚠️ Sync completed with errors: ${syncResult.message}');
        for (final error in syncResult.errors) {
          debugPrint('  ❌ $error');
        }
        return false;
      }
    } catch (e, stackTrace) {
      // Handle rate limiting gracefully - it's not an error, just throttling
      if (e.toString().contains('SyncRateLimitedException') ||
          e.toString().contains('Sync rate limited')) {
        debugPrint('ℹ️ Sync rate limited - will retry later');
        return true; // Return true since this isn't a real error
      }

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
      // NOTE: manualSync() now calls _onSyncComplete internally, no need to call it here
      await manualSync();
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
