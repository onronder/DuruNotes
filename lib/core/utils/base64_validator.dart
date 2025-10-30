import 'dart:convert';

/// Utility class for validating and sanitizing base64-encoded data
///
/// This is critical for production security to prevent corrupted data
/// from propagating through the system.
class Base64Validator {
  /// Check if a string is valid base64
  ///
  /// Returns true if the string can be successfully decoded as base64
  static bool isValidBase64(String? value) {
    if (value == null || value.isEmpty) return false;

    // Base64 must have length divisible by 4 (with padding)
    if (value.length % 4 != 0) return false;

    // Base64 pattern: alphanumeric + / + plus padding
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/]+={0,2}$', multiLine: false);

    if (!base64Pattern.hasMatch(value)) return false;

    // Try to decode - this is the definitive test
    try {
      base64.decode(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate and sanitize base64 string
  ///
  /// Returns sanitized base64 string if valid, null otherwise
  /// Removes whitespace and validates format
  static String? validateAndSanitize(String? value) {
    if (value == null || value.isEmpty) return null;

    // Remove all whitespace (common corruption issue)
    final sanitized = value.replaceAll(RegExp(r'\s'), '');

    // Check if valid after sanitization
    if (isValidBase64(sanitized)) return sanitized;

    return null; // Invalid base64
  }

  /// Decode base64 with validation
  ///
  /// Throws FormatException with descriptive message if invalid
  /// Returns decoded bytes if successful
  static List<int> decodeWithValidation(String value, {String? context}) {
    final sanitized = validateAndSanitize(value);

    if (sanitized == null) {
      final contextMsg = context != null ? ' for $context' : '';
      throw FormatException(
        'Invalid base64 format$contextMsg. '
        'Length: ${value.length}, Contains whitespace: ${value.contains(RegExp(r'\s'))}',
      );
    }

    try {
      return base64.decode(sanitized);
    } catch (e) {
      final contextMsg = context != null ? ' for $context' : '';
      throw FormatException('Failed to decode base64$contextMsg: $e');
    }
  }

  /// Encode bytes to base64 with validation
  ///
  /// Ensures output is valid base64
  static String encodeWithValidation(List<int> bytes, {String? context}) {
    if (bytes.isEmpty) {
      final contextMsg = context != null ? ' for $context' : '';
      throw ArgumentError('Cannot encode empty bytes$contextMsg');
    }

    try {
      final encoded = base64.encode(bytes);

      // Verify it's valid (sanity check)
      if (!isValidBase64(encoded)) {
        throw FormatException('Generated invalid base64 (should never happen)');
      }

      return encoded;
    } catch (e) {
      final contextMsg = context != null ? ' for $context' : '';
      throw FormatException('Failed to encode base64$contextMsg: $e');
    }
  }

  /// Check if base64 string has correct padding
  static bool hasCorrectPadding(String value) {
    // Base64 strings should be padded to multiple of 4
    if (value.length % 4 != 0) return false;

    // Count padding characters
    final paddingCount = value.length - value.replaceAll('=', '').length;

    // Should have 0, 1, or 2 padding characters
    return paddingCount >= 0 && paddingCount <= 2;
  }

  /// Get detailed validation result for debugging
  static ValidationResult validate(String? value) {
    if (value == null) {
      return ValidationResult(isValid: false, error: 'Value is null');
    }

    if (value.isEmpty) {
      return ValidationResult(isValid: false, error: 'Value is empty');
    }

    if (value.length % 4 != 0) {
      return ValidationResult(
        isValid: false,
        error: 'Length ${value.length} is not divisible by 4',
      );
    }

    final base64Pattern = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');
    if (!base64Pattern.hasMatch(value)) {
      return ValidationResult(
        isValid: false,
        error: 'Contains invalid characters',
      );
    }

    try {
      base64.decode(value);
      return ValidationResult(isValid: true);
    } catch (e) {
      return ValidationResult(isValid: false, error: 'Decode failed: $e');
    }
  }
}

/// Result of base64 validation with details
class ValidationResult {
  const ValidationResult({required this.isValid, this.error});

  final bool isValid;
  final String? error;

  @override
  String toString() => isValid ? 'Valid' : 'Invalid: $error';
}
