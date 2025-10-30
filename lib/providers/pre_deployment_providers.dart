/* COMMENTED OUT - 5 errors - depends on commented-out PreDeploymentValidator
 * This file depends on PreDeploymentValidator which was commented out due to errors.
 * Needs rewrite to use new architecture.
 */

/*
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/tools/pre_deployment_validator.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/providers/sync_verification_providers.dart';

/// Providers for pre-deployment validation system
///
/// These providers enable safe deployment validation before applying
/// Phase 3 database optimizations.

/// Provider for pre-deployment validator instance
final preDeploymentValidatorProvider = Provider<PreDeploymentValidator>((ref) {
  final appDb = ref.watch(appDbProvider);
  final remoteApi = ref.watch(supabaseNoteApiProvider);
  final validator = ref.watch(syncIntegrityValidatorProvider);
  final conflictEngine = ref.watch(conflictResolutionEngineProvider);
  final consistencyChecker = ref.watch(dataConsistencyCheckerProvider);
  final logger = ref.watch(loggerProvider);

  return PreDeploymentValidator(
    localDb: appDb,
    remoteApi: remoteApi,
    validator: validator,
    conflictEngine: conflictEngine,
    consistencyChecker: consistencyChecker,
    logger: logger,
  );
});

/// State notifier for managing pre-deployment validation
class PreDeploymentValidationNotifier extends StateNotifier<AsyncValue<PreDeploymentReport?>> {
  final PreDeploymentValidator _validator;

  PreDeploymentValidationNotifier(this._validator)
      : super(const AsyncValue.data(null));

  /// Run comprehensive pre-deployment validation
  Future<void> runPreDeploymentValidation({
    bool createBackupDocumentation = true,
    bool resolveExistingIssues = true,
  }) async {
    state = const AsyncValue.loading();

    try {
      final report = await _validator.performPreDeploymentValidation(
        createBackupDocumentation: createBackupDocumentation,
        resolveExistingIssues: resolveExistingIssues,
      );

      state = AsyncValue.data(report);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Run quick validation check
  Future<void> runQuickValidation() async {
    state = const AsyncValue.loading();

    try {
      final report = await _validator.performPreDeploymentValidation(
        createBackupDocumentation: false,
        resolveExistingIssues: false,
      );

      state = AsyncValue.data(report);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Reset validation state
  void reset() {
    state = const AsyncValue.data(null);
  }

  /// Get deployment readiness status
  bool get isDeploymentReady {
    final report = state.value;
    return report?.isDeploymentReady ?? false;
  }

  /// Get current health score
  double get healthScore {
    final report = state.value;
    return report?.syncHealthCheck?.healthScore ?? 0.0;
  }

  /// Get critical issues count
  int get criticalIssuesCount {
    final report = state.value;
    return report?.criticalIssuesCount ?? 0;
  }
}

/// Provider for pre-deployment validation state management
final preDeploymentValidationProvider = StateNotifierProvider<PreDeploymentValidationNotifier, AsyncValue<PreDeploymentReport?>>((ref) {
  final validator = ref.watch(preDeploymentValidatorProvider);
  return PreDeploymentValidationNotifier(validator);
});

/// Provider for deployment readiness status
final deploymentReadinessProvider = Provider<bool>((ref) {
  final validationNotifier = ref.watch(preDeploymentValidationProvider.notifier);
  return validationNotifier.isDeploymentReady;
});

/// Provider for current health score
final currentHealthScoreProvider = Provider<double>((ref) {
  final validationNotifier = ref.watch(preDeploymentValidationProvider.notifier);
  return validationNotifier.healthScore;
});

/// Provider for critical issues count
final criticalIssuesCountProvider = Provider<int>((ref) {
  final validationNotifier = ref.watch(preDeploymentValidationProvider.notifier);
  return validationNotifier.criticalIssuesCount;
});

/// Validation parameters for different validation types
class ValidationParams {
  final bool createBackupDocumentation;
  final bool resolveExistingIssues;
  final bool quickValidation;

  const ValidationParams({
    this.createBackupDocumentation = true,
    this.resolveExistingIssues = true,
    this.quickValidation = false,
  });

  const ValidationParams.quick()
      : createBackupDocumentation = false,
        resolveExistingIssues = false,
        quickValidation = true;

  const ValidationParams.full()
      : createBackupDocumentation = true,
        resolveExistingIssues = true,
        quickValidation = false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidationParams &&
          runtimeType == other.runtimeType &&
          createBackupDocumentation == other.createBackupDocumentation &&
          resolveExistingIssues == other.resolveExistingIssues &&
          quickValidation == other.quickValidation;

  @override
  int get hashCode => Object.hash(
        createBackupDocumentation,
        resolveExistingIssues,
        quickValidation,
      );
}
*/
