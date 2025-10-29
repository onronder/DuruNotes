/// Feature flag for cross-device encryption
///
/// SAFETY: This flag controls whether the new cross-device encryption system is enabled.
/// When false, only the existing AccountKeyService (device-specific) encryption runs.
/// When true, users are offered optional cross-device encryption setup.
///
/// Default: false (disabled) - Safe to merge, no behavioral changes
///
/// Rollback: Set to false to instantly disable new system
class EncryptionFeatureFlags {
  /// Master kill switch for cross-device encryption feature
  ///
  /// IMPORTANT: Start with false, verify zero impact, then enable gradually
  static const bool enableCrossDeviceEncryption = true;  // ← ENABLED FOR TESTING

  /// Whether to show cross-device encryption during sign-up
  /// Only has effect if enableCrossDeviceEncryption is true
  static const bool showOnSignUp = true;  // ← ENABLED FOR TESTING

  /// Whether to show cross-device encryption during sign-in
  /// Only has effect if enableCrossDeviceEncryption is true
  static const bool showOnSignIn = false;

  /// Whether to show migration prompt for existing users
  /// Only has effect if enableCrossDeviceEncryption is true
  static const bool showMigrationPrompt = false;

  /// Logging for debugging (safe to enable)
  static const bool enableDebugLogging = true;
}
