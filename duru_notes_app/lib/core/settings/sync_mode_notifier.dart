import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repository/notes_repository.dart';
import 'sync_mode.dart';

/// Helper function to fire and forget async operations
void unawaited(Future<void> future) {
  // Intentionally ignore the future to avoid blocking
}

/// Notifier for managing sync mode settings
class SyncModeNotifier extends StateNotifier<SyncMode> {
  SyncModeNotifier(this._notesRepository, [this._onSyncComplete]) : super(SyncMode.automatic) {
    _loadSyncMode();
  }

  final NotesRepository _notesRepository;
  final VoidCallback? _onSyncComplete;
  static const String _syncModeKey = 'sync_mode';
  
  // Timer for periodic sync in automatic mode
  Timer? _autoSyncTimer;
  
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
  
  /// Start periodic sync timer for automatic mode
  void _startPeriodicSync() {
    _stopPeriodicSync(); // Cancel any existing timer
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) async {
      // Perform background sync without blocking UI
      final success = await manualSync();
      if (success) {
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
    _stopPeriodicSync();
    super.dispose();
  }
}
