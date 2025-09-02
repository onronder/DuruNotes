/// Synchronization mode options
enum SyncMode {
  /// Automatically sync changes on startup and periodically
  automatic,
  
  /// Only sync when manually requested by the user
  manual,
}

extension SyncModeExtension on SyncMode {
  /// Human-readable name for the sync mode
  String get displayName {
    switch (this) {
      case SyncMode.automatic:
        return 'Automatic';
      case SyncMode.manual:
        return 'Manual';
    }
  }
  
  /// Description of what this sync mode does
  String get description {
    switch (this) {
      case SyncMode.automatic:
        return 'Sync changes automatically';
      case SyncMode.manual:
        return 'Sync only when requested';
    }
  }
}
