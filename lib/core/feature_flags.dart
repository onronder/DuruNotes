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
    'use_unified_reminders': true, // ENABLED for development
    'use_new_block_editor': true, // ENABLED for development
    'use_refactored_components': true, // ENABLED for development
    'use_unified_permission_manager': true, // ENABLED for development
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

  // Convenience getters for specific flags
  bool get useUnifiedReminders => isEnabled('use_unified_reminders');
  bool get useNewBlockEditor => isEnabled('use_new_block_editor');
  bool get useRefactoredComponents => isEnabled('use_refactored_components');
  bool get useUnifiedPermissionManager =>
      isEnabled('use_unified_permission_manager');
}
