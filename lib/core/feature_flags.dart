/// Feature flags for gradual rollout of refactored components
///
/// This system allows us to enable/disable new features without deploying new code,
/// enabling A/B testing and gradual rollouts with easy rollback capability.
class FeatureFlags {
  FeatureFlags._();

  // Singleton instance
  static final FeatureFlags _instance = FeatureFlags._();
  static FeatureFlags get instance => _instance;

  // Feature flag storage (in production, these would come from remote config)
  final Map<String, bool> _flags = {
    'use_new_block_editor': true, // ENABLED for development
    'use_refactored_components': true, // ENABLED for development
    'use_unified_permission_manager': true, // ENABLED for development
    'use_block_editor_for_notes':
        false, // ❌ DISABLED - Breaks regular note creation, needs proper integration
    'enable_userid_filtering': false, // SECURITY: Gradual rollout gate
    'enable_automatic_trash_purge':
        false, // TRASH: Auto-purge overdue items on app startup
    'voice_dictation_enabled': true, // Voice dictation in note editor
  };

  // Cohort rollout percentages (0.0 → disabled, 1.0 → 100% users)
  final Map<String, double> _rolloutPercentages = {
    'enable_userid_filtering': 0.0,
  };

  // Override flags for testing/development
  final Map<String, bool> _overrides = {};

  /// Get the value of a feature flag
  bool isEnabled(String flagName) {
    // Check overrides first
    if (_overrides.containsKey(flagName)) {
      return _overrides[flagName]!;
    }
    // Fall back to default value
    return _flags[flagName] ?? false;
  }

  /// Evaluate flag with rollout percentage using a stable per-user bucket.
  ///
  /// When [userId] is null, only the base flag value is considered.
  /// Rollout values are [0.0, 1.0]. Example: 0.1 == 10% of users.
  bool isEnabledForUser(String flagName, {String? userId}) {
    if (!isEnabled(flagName)) return false;

    final rollout = _rolloutPercentages[flagName];
    if (rollout == null) {
      return true; // No staged rollout configured
    }

    if (rollout >= 1.0) {
      return true; // 100% rollout
    }

    if (userId == null || userId.isEmpty) {
      // Without a stable identifier we cannot bucket deterministically
      return false;
    }

    final bucket = _stableBucket(userId);
    return bucket < (rollout * 100).ceil();
  }

  /// Set an override for testing purposes
  void setOverride(String flagName, bool value) {
    _overrides[flagName] = value;
  }

  /// Clear all overrides
  void clearOverrides() {
    _overrides.clear();
  }

  /// Update flags from remote config (placeholder for future implementation)
  Future<void> updateFromRemoteConfig() async {
    // In production, this would fetch from Firebase Remote Config or similar
    // For now, we'll use local defaults
  }

  /// Set rollout percentage for a flag (0.0 → disabled, 1.0 → 100%).
  void setRolloutPercentage(String flagName, double percentage) {
    _rolloutPercentages[flagName] = percentage.clamp(0.0, 1.0);
  }

  /// Convenience accessor for security rollout flag.
  bool get enableUserIdFiltering => isEnabled('enable_userid_filtering');

  /// Evaluate security rollout flag for a specific user.
  bool enableUserIdFilteringFor(String? userId) =>
      isEnabledForUser('enable_userid_filtering', userId: userId);

  // Convenience getters for specific flags
  bool get useNewBlockEditor => isEnabled('use_new_block_editor');
  bool get useRefactoredComponents => isEnabled('use_refactored_components');
  bool get useUnifiedPermissionManager =>
      isEnabled('use_unified_permission_manager');

  /// Sprint 1: Use BlockEditor for notes instead of plain TextField
  /// When enabled, notes are parsed into blocks and todos become interactive
  bool get useBlockEditorForNotes => isEnabled('use_block_editor_for_notes');

  /// Phase 1.1: Auto-purge trash items after 30-day retention period
  /// When enabled, overdue trash items are automatically deleted on app startup
  bool get enableAutomaticTrashPurge =>
      isEnabled('enable_automatic_trash_purge');

  /// Voice dictation in note editor
  /// When enabled, shows mic button in formatting toolbar for speech-to-text
  bool get voiceDictationEnabled => isEnabled('voice_dictation_enabled');

  int _stableBucket(String userId) {
    final hash = userId.hashCode & 0x7fffffff;
    return hash % 100;
  }
}
