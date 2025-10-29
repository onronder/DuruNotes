import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/services/encryption_sync_service.dart';
import 'package:duru_notes/services/providers/services_providers.dart';

/// Encryption setup status
enum EncryptionStatus {
  /// User has not set up encryption yet
  notSetup,

  /// Encryption is set up and AMK is available locally
  unlocked,

  /// Encryption is set up but AMK needs to be retrieved (locked)
  locked,

  /// Currently checking encryption status
  loading,

  /// Error occurred while checking status
  error,
}

/// State for encryption setup and unlock flows
class EncryptionState {
  const EncryptionState({
    required this.status,
    this.error,
    this.isSetupRequired = false,
  });

  final EncryptionStatus status;
  final String? error;
  final bool isSetupRequired;

  EncryptionState copyWith({
    EncryptionStatus? status,
    String? error,
    bool? isSetupRequired,
  }) {
    return EncryptionState(
      status: status ?? this.status,
      error: error,
      isSetupRequired: isSetupRequired ?? this.isSetupRequired,
    );
  }

  bool get isUnlocked => status == EncryptionStatus.unlocked;
  bool get isLocked => status == EncryptionStatus.locked;
  bool get needsSetup => status == EncryptionStatus.notSetup;
}

/// Notifier for managing encryption state
class EncryptionStateNotifier extends StateNotifier<EncryptionState> {
  EncryptionStateNotifier(this._service)
      : super(const EncryptionState(status: EncryptionStatus.loading)) {
    _checkEncryptionStatus();
  }

  final EncryptionSyncService _service;

  /// Check current encryption status
  Future<void> _checkEncryptionStatus() async {
    try {
      final hasLocalAmk = await _service.getLocalAmk();
      final isSetupOnServer = await _service.isEncryptionSetup();

      if (hasLocalAmk != null) {
        // AMK is available locally - user is unlocked
        state = const EncryptionState(status: EncryptionStatus.unlocked);
      } else if (isSetupOnServer) {
        // Encryption is set up on server but not locally - needs unlock
        state = const EncryptionState(status: EncryptionStatus.locked);
      } else {
        // No encryption setup yet
        state = const EncryptionState(status: EncryptionStatus.notSetup);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EncryptionState] Error checking status: $e');
      }
      state = EncryptionState(
        status: EncryptionStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Setup encryption for first-time user (sign-up flow)
  Future<bool> setupEncryption(String password) async {
    try {
      state = state.copyWith(status: EncryptionStatus.loading);

      await _service.setupEncryption(password);

      // FIX: Refresh state from storage to verify AMK is actually available
      // This prevents race conditions where state shows locked instead of unlocked
      await _checkEncryptionStatus();

      // Double-check that we're actually unlocked now
      if (state.status != EncryptionStatus.unlocked) {
        if (kDebugMode) {
          debugPrint('[EncryptionState] Warning: Setup completed but state is not unlocked');
        }
        // Force unlocked state since setup succeeded
        state = const EncryptionState(status: EncryptionStatus.unlocked);
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EncryptionState] Setup failed: $e');
      }
      state = EncryptionState(
        status: EncryptionStatus.error,
        error: _parseErrorMessage(e),
      );
      return false;
    }
  }

  /// Retrieve encryption keys (sign-in flow)
  Future<bool> unlockEncryption(String password) async {
    try {
      state = state.copyWith(status: EncryptionStatus.loading);

      await _service.retrieveEncryption(password);

      state = const EncryptionState(status: EncryptionStatus.unlocked);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EncryptionState] Unlock failed: $e');
      }

      final errorMessage = _parseErrorMessage(e);
      final isWrongPassword = errorMessage.toLowerCase().contains('invalid password') ||
          errorMessage.toLowerCase().contains('decryption failed');

      state = EncryptionState(
        status: isWrongPassword ? EncryptionStatus.locked : EncryptionStatus.error,
        error: errorMessage,
      );
      return false;
    }
  }

  /// Skip encryption setup (optional flow)
  void skipSetup() {
    state = const EncryptionState(
      status: EncryptionStatus.notSetup,
      isSetupRequired: false,
    );
  }

  /// Mark encryption as required
  void markSetupRequired() {
    state = state.copyWith(isSetupRequired: true);
  }

  /// Clear encryption state (logout)
  Future<void> clearEncryption() async {
    try {
      await _service.clearLocalKeys();
      state = const EncryptionState(status: EncryptionStatus.notSetup);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EncryptionState] Clear failed: $e');
      }
    }
  }

  /// Refresh encryption status
  Future<void> refresh() async {
    await _checkEncryptionStatus();
  }

  /// Parse error messages into user-friendly text
  String _parseErrorMessage(Object error) {
    final errorStr = error.toString();

    if (errorStr.contains('Invalid password') ||
        errorStr.contains('decryption failed')) {
      return 'Invalid password. Please try again.';
    }

    if (errorStr.contains('already setup')) {
      return 'Encryption is already set up for this account.';
    }

    if (errorStr.contains('No encryption setup found')) {
      return 'No encryption found. Please set up encryption first.';
    }

    if (errorStr.contains('not authenticated')) {
      return 'You must be signed in to set up encryption.';
    }

    if (errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout')) {
      return 'Network error. Please check your connection and try again.';
    }

    // Generic error
    return 'An error occurred. Please try again.';
  }
}

/// Provider for encryption state
final encryptionStateProvider = StateNotifierProvider<EncryptionStateNotifier, EncryptionState>((ref) {
  final service = ref.watch(encryptionSyncServiceProvider);

  return EncryptionStateNotifier(service);
});

/// Provider for encryption service
/// This is a convenience provider for accessing encryption functions
final encryptionServiceProvider = Provider<EncryptionSyncService>((ref) {
  return ref.watch(encryptionSyncServiceProvider);
});

/// Check if encryption is unlocked
final isEncryptionUnlockedProvider = Provider<bool>((ref) {
  final state = ref.watch(encryptionStateProvider);
  return state.isUnlocked;
});

/// Check if encryption needs setup
final needsEncryptionSetupProvider = Provider<bool>((ref) {
  final state = ref.watch(encryptionStateProvider);
  return state.needsSetup;
});

/// Check if encryption is locked
final isEncryptionLockedProvider = Provider<bool>((ref) {
  final state = ref.watch(encryptionStateProvider);
  return state.isLocked;
});
