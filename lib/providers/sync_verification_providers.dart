import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/core/sync/sync_integrity_validator.dart';
import 'package:duru_notes/core/sync/conflict_resolution_engine.dart';
import 'package:duru_notes/core/sync/data_consistency_checker.dart';
import 'package:duru_notes/core/sync/sync_recovery_manager.dart';
import 'package:duru_notes/core/providers/database_providers.dart' show appDbProvider;
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/features/notes/providers/notes_repository_providers.dart'
    show supabaseNoteApiProvider;

/// Providers for sync verification and integrity management
///
/// These providers enable comprehensive sync verification throughout
/// the app, ensuring data consistency between local and remote databases.

/// Provider for sync integrity validator
final syncIntegrityValidatorProvider = Provider<SyncIntegrityValidator>((ref) {
  final appDb = ref.watch(appDbProvider);
  final remoteApi = ref.watch(supabaseNoteApiProvider);
  final logger = ref.watch(loggerProvider);

  if (remoteApi == null) {
    throw StateError('SyncIntegrityValidator requires authenticated user');
  }

  return SyncIntegrityValidator(
    localDb: appDb,
    remoteApi: remoteApi,
    logger: logger,
  );
});

/// Provider for conflict resolution engine
final conflictResolutionEngineProvider = Provider<ConflictResolutionEngine>((ref) {
  final appDb = ref.watch(appDbProvider);
  final remoteApi = ref.watch(supabaseNoteApiProvider);
  final logger = ref.watch(loggerProvider);

  if (remoteApi == null) {
    throw StateError('ConflictResolutionEngine requires authenticated user');
  }

  return ConflictResolutionEngine(
    localDb: appDb,
    remoteApi: remoteApi,
    logger: logger,
  );
});

/// Provider for data consistency checker
final dataConsistencyCheckerProvider = Provider<DataConsistencyChecker>((ref) {
  final appDb = ref.watch(appDbProvider);
  final remoteApi = ref.watch(supabaseNoteApiProvider);
  final logger = ref.watch(loggerProvider);

  if (remoteApi == null) {
    throw StateError('DataConsistencyChecker requires authenticated user');
  }

  return DataConsistencyChecker(
    localDb: appDb,
    remoteApi: remoteApi,
    logger: logger,
  );
});

/// Provider for sync recovery manager
final syncRecoveryManagerProvider = Provider<SyncRecoveryManager>((ref) {
  final appDb = ref.watch(appDbProvider);
  final remoteApi = ref.watch(supabaseNoteApiProvider);
  final validator = ref.watch(syncIntegrityValidatorProvider);
  final conflictEngine = ref.watch(conflictResolutionEngineProvider);
  final logger = ref.watch(loggerProvider);

  if (remoteApi == null) {
    throw StateError('SyncRecoveryManager requires authenticated user');
  }

  return SyncRecoveryManager(
    localDb: appDb,
    remoteApi: remoteApi,
    validator: validator,
    conflictEngine: conflictEngine,
    logger: logger,
  );
});

/// Provider for running sync integrity validation
final syncValidationProvider = FutureProvider.family<ValidationResult, SyncValidationParams>(
  (ref, params) async {
    final validator = ref.watch(syncIntegrityValidatorProvider);

    return validator.validateSyncIntegrity(
      deepValidation: params.deepValidation,
      validationWindow: params.validationWindow,
    );
  },
);

/// Provider for conflict detection and resolution
final conflictResolutionProvider = FutureProvider.family<ConflictResolutionResult, ConflictResolutionParams>(
  (ref, params) async {
    final engine = ref.watch(conflictResolutionEngineProvider);

    return engine.detectAndResolveNoteConflicts(
      strategy: params.strategy,
      conflictWindow: params.conflictWindow,
    );
  },
);

/// Provider for data consistency checking
final consistencyCheckProvider = FutureProvider.family<ConsistencyCheckResult, ConsistencyCheckParams>(
  (ref, params) async {
    final checker = ref.watch(dataConsistencyCheckerProvider);

    return checker.performConsistencyCheck(
      checkSince: params.checkSince,
      deepCheck: params.deepCheck,
      specificTables: params.specificTables,
    );
  },
);

/// Provider for sync recovery operations
final syncRecoveryProvider = FutureProvider.family<SyncRecoveryResult, SyncRecoveryParams>(
  (ref, params) async {
    final recoveryManager = ref.watch(syncRecoveryManagerProvider);

    return recoveryManager.recoverSync(
      strategy: params.strategy,
      recoveryWindow: params.recoveryWindow,
      forceRecovery: params.forceRecovery,
    );
  },
);

/// State notifier for managing sync verification operations
class SyncVerificationNotifier extends StateNotifier<AsyncValue<SyncVerificationState>> {
  final SyncIntegrityValidator _validator;
  final ConflictResolutionEngine _conflictEngine;
  final DataConsistencyChecker _consistencyChecker;
  final SyncRecoveryManager _recoveryManager;

  SyncVerificationNotifier({
    required SyncIntegrityValidator validator,
    required ConflictResolutionEngine conflictEngine,
    required DataConsistencyChecker consistencyChecker,
    required SyncRecoveryManager recoveryManager,
  })  : _validator = validator,
        _conflictEngine = conflictEngine,
        _consistencyChecker = consistencyChecker,
        _recoveryManager = recoveryManager,
        super(AsyncValue.data(SyncVerificationState.initial()));

  /// Perform comprehensive sync verification
  Future<void> performFullVerification({
    bool deepValidation = true,
    ConflictResolutionStrategy conflictStrategy = ConflictResolutionStrategy.lastWriteWins,
  }) async {
    state = const AsyncValue.loading();

    try {
      final verificationState = SyncVerificationState.initial();

      // Step 1: Integrity validation
      final validationResult = await _validator.validateSyncIntegrity(
        deepValidation: deepValidation,
      );
      verificationState.validationResult = validationResult;

      // Step 2: Conflict detection and resolution
      final conflictResult = await _conflictEngine.detectAndResolveNoteConflicts(
        strategy: conflictStrategy,
      );
      verificationState.conflictResult = conflictResult;

      // Step 3: Consistency checking
      final consistencyResult = await _consistencyChecker.performConsistencyCheck(
        deepCheck: deepValidation,
      );
      verificationState.consistencyResult = consistencyResult;

      // Step 4: Recovery if needed
      if (!validationResult.isValid || !consistencyResult.isConsistent) {
        final recoveryResult = await _recoveryManager.recoverSync(
          strategy: SyncRecoveryStrategy.automatic,
        );
        verificationState.recoveryResult = recoveryResult;
      }

      verificationState.isCompleted = true;
      verificationState.completedAt = DateTime.now();

      state = AsyncValue.data(verificationState);

    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Quick sync health check
  Future<void> performQuickHealthCheck() async {
    state = const AsyncValue.loading();

    try {
      final verificationState = SyncVerificationState.initial();

      // Quick validation without deep checks
      final validationResult = await _validator.validateSyncIntegrity(
        deepValidation: false,
      );
      verificationState.validationResult = validationResult;

      // Quick consistency check
      final consistencyResult = await _consistencyChecker.performConsistencyCheck(
        deepCheck: false,
      );
      verificationState.consistencyResult = consistencyResult;

      verificationState.isCompleted = true;
      verificationState.completedAt = DateTime.now();

      state = AsyncValue.data(verificationState);

    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Reset verification state
  void reset() {
    state = AsyncValue.data(SyncVerificationState.initial());
  }

  /// Get current sync health score
  double getCurrentHealthScore() {
    final currentState = state.value;
    if (currentState == null || !currentState.isCompleted) return 0.0;

    double score = 1.0;

    // Deduct for validation issues
    if (currentState.validationResult?.isValid == false) {
      final criticalIssues = currentState.validationResult!.criticalIssues.length;
      score -= (criticalIssues * 0.2);
    }

    // Deduct for consistency issues
    if (currentState.consistencyResult?.isConsistent == false) {
      final criticalIssues = currentState.consistencyResult!.criticalIssues.length;
      score -= (criticalIssues * 0.2);
    }

    // Deduct for unresolved conflicts
    if (currentState.conflictResult?.hasUnresolvedConflicts == true) {
      score -= 0.3;
    }

    return math.max(0.0, score);
  }
}

/// Provider for sync verification state management
final syncVerificationProvider = StateNotifierProvider<SyncVerificationNotifier, AsyncValue<SyncVerificationState>>((ref) {
  final validator = ref.watch(syncIntegrityValidatorProvider);
  final conflictEngine = ref.watch(conflictResolutionEngineProvider);
  final consistencyChecker = ref.watch(dataConsistencyCheckerProvider);
  final recoveryManager = ref.watch(syncRecoveryManagerProvider);

  return SyncVerificationNotifier(
    validator: validator,
    conflictEngine: conflictEngine,
    consistencyChecker: consistencyChecker,
    recoveryManager: recoveryManager,
  );
});

/// Provider for sync health monitoring
final syncHealthProvider = Provider<double>((ref) {
  final verificationNotifier = ref.watch(syncVerificationProvider.notifier);
  return verificationNotifier.getCurrentHealthScore();
});

/// Provider for checking if sync verification is needed
final syncVerificationNeededProvider = FutureProvider<bool>((ref) async {
  final validator = ref.watch(syncIntegrityValidatorProvider);

  try {
    // Quick validation to check if full verification is needed
    final result = await validator.validateSyncIntegrity(deepValidation: false);
    return !result.isValid || result.criticalIssues.isNotEmpty;
  } catch (e) {
    // If validation fails, assume verification is needed
    return true;
  }
});

// Parameter classes for providers

class SyncValidationParams {
  final bool deepValidation;
  final DateTime? validationWindow;

  SyncValidationParams({
    this.deepValidation = false,
    this.validationWindow,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncValidationParams &&
          runtimeType == other.runtimeType &&
          deepValidation == other.deepValidation &&
          validationWindow == other.validationWindow;

  @override
  int get hashCode => Object.hash(deepValidation, validationWindow);
}

class ConflictResolutionParams {
  final ConflictResolutionStrategy strategy;
  final DateTime? conflictWindow;

  ConflictResolutionParams({
    this.strategy = ConflictResolutionStrategy.lastWriteWins,
    this.conflictWindow,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConflictResolutionParams &&
          runtimeType == other.runtimeType &&
          strategy == other.strategy &&
          conflictWindow == other.conflictWindow;

  @override
  int get hashCode => Object.hash(strategy, conflictWindow);
}

class ConsistencyCheckParams {
  final DateTime? checkSince;
  final bool deepCheck;
  final Set<String>? specificTables;

  ConsistencyCheckParams({
    this.checkSince,
    this.deepCheck = false,
    this.specificTables,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsistencyCheckParams &&
          runtimeType == other.runtimeType &&
          checkSince == other.checkSince &&
          deepCheck == other.deepCheck &&
          specificTables == other.specificTables;

  @override
  int get hashCode => Object.hash(checkSince, deepCheck, specificTables);
}

class SyncRecoveryParams {
  final SyncRecoveryStrategy strategy;
  final DateTime? recoveryWindow;
  final bool forceRecovery;

  SyncRecoveryParams({
    this.strategy = SyncRecoveryStrategy.automatic,
    this.recoveryWindow,
    this.forceRecovery = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncRecoveryParams &&
          runtimeType == other.runtimeType &&
          strategy == other.strategy &&
          recoveryWindow == other.recoveryWindow &&
          forceRecovery == other.forceRecovery;

  @override
  int get hashCode => Object.hash(strategy, recoveryWindow, forceRecovery);
}

// State class for comprehensive sync verification

class SyncVerificationState {
  ValidationResult? validationResult;
  ConflictResolutionResult? conflictResult;
  ConsistencyCheckResult? consistencyResult;
  SyncRecoveryResult? recoveryResult;
  bool isCompleted;
  DateTime? completedAt;

  SyncVerificationState({
    this.validationResult,
    this.conflictResult,
    this.consistencyResult,
    this.recoveryResult,
    this.isCompleted = false,
    this.completedAt,
  });

  factory SyncVerificationState.initial() => SyncVerificationState();

  bool get hasErrors =>
      (validationResult?.isValid == false) ||
      (consistencyResult?.isConsistent == false) ||
      (recoveryResult?.isSuccessful == false);

  bool get needsAttention =>
      hasErrors ||
      (conflictResult?.hasUnresolvedConflicts == true) ||
      (validationResult?.criticalIssues.isNotEmpty == true);

  double get overallHealthScore {
    if (!isCompleted) return 0.0;

    double score = 1.0;

    if (validationResult?.isValid == false) score -= 0.3;
    if (consistencyResult?.isConsistent == false) score -= 0.3;
    if (conflictResult?.hasUnresolvedConflicts == true) score -= 0.2;
    if (recoveryResult?.isSuccessful == false) score -= 0.2;

    return math.max(0.0, score);
  }

  Map<String, dynamic> toJson() => {
    'validation_passed': validationResult?.isValid,
    'consistency_passed': consistencyResult?.isConsistent,
    'conflicts_resolved': conflictResult?.resolutionRate,
    'recovery_successful': recoveryResult?.isSuccessful,
    'is_completed': isCompleted,
    'completed_at': completedAt?.toIso8601String(),
    'health_score': overallHealthScore,
    'needs_attention': needsAttention,
  };
}