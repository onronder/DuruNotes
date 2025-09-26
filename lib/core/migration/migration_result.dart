/// Migration result data class
class MigrationResult {
  final int totalNotes;
  final int successfulDecryptions;
  final int failedDecryptions;
  final int recoveredNotes;
  final List<String> errors;

  MigrationResult({
    required this.totalNotes,
    required this.successfulDecryptions,
    required this.failedDecryptions,
    required this.recoveredNotes,
    required this.errors,
  });
}

/// Helper class for decryption results
class DecryptionResult<T> {
  final bool success;
  final T? value;
  final String? error;

  DecryptionResult._({
    required this.success,
    this.value,
    this.error,
  });

  factory DecryptionResult.success(T value) => DecryptionResult._(
    success: true,
    value: value,
  );

  factory DecryptionResult.failure(String error) => DecryptionResult._(
    success: false,
    error: error,
  );
}