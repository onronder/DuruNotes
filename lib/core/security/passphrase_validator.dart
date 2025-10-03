import 'dart:math';

/// Validates passphrase strength for encryption key derivation
///
/// Enforces:
/// - Minimum 12 characters
/// - Minimum entropy threshold
/// - Character diversity requirements
class PassphraseValidator {
  static const int minLength = 12;
  static const int minEntropyBits = 50;

  /// Validates passphrase strength
  /// Returns null if valid, error message if invalid
  static String? validate(String passphrase) {
    if (passphrase.isEmpty) {
      return 'Passphrase cannot be empty';
    }

    if (passphrase.length < minLength) {
      return 'Passphrase must be at least $minLength characters';
    }

    // Check character diversity
    final hasLowercase = passphrase.contains(RegExp(r'[a-z]'));
    final hasUppercase = passphrase.contains(RegExp(r'[A-Z]'));
    final hasDigits = passphrase.contains(RegExp(r'[0-9]'));
    final hasSpecial = passphrase.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    int diversityScore = 0;
    if (hasLowercase) diversityScore++;
    if (hasUppercase) diversityScore++;
    if (hasDigits) diversityScore++;
    if (hasSpecial) diversityScore++;

    if (diversityScore < 3) {
      return 'Passphrase must contain at least 3 of: lowercase, uppercase, digits, special characters';
    }

    // Calculate entropy
    final entropy = calculateEntropy(passphrase);
    if (entropy < minEntropyBits) {
      return 'Passphrase is too weak (entropy: ${entropy.toStringAsFixed(1)} bits, minimum: $minEntropyBits bits)';
    }

    // Check for common weak patterns
    if (_isCommonPattern(passphrase)) {
      return 'Passphrase contains common weak patterns';
    }

    return null; // Valid
  }

  /// Calculate Shannon entropy in bits
  static double calculateEntropy(String passphrase) {
    if (passphrase.isEmpty) return 0.0;

    final frequencies = <String, int>{};
    for (var i = 0; i < passphrase.length; i++) {
      final char = passphrase[i];
      frequencies[char] = (frequencies[char] ?? 0) + 1;
    }

    double entropy = 0.0;
    final length = passphrase.length;

    for (final count in frequencies.values) {
      final probability = count / length;
      entropy -= probability * (log(probability) / ln2);
    }

    return entropy * length;
  }

  /// Check for common weak patterns
  static bool _isCommonPattern(String passphrase) {
    final lower = passphrase.toLowerCase();

    // Common weak patterns
    final weakPatterns = [
      'password',
      '12345',
      'qwerty',
      'abc123',
      'letmein',
      'admin',
      'welcome',
      'monkey',
      '111111',
      'password1',
    ];

    for (final pattern in weakPatterns) {
      if (lower.contains(pattern)) {
        return true;
      }
    }

    // Sequential characters (abc, 123, etc.)
    if (_hasSequentialChars(passphrase, 4)) {
      return true;
    }

    // Repeated characters (aaaa, 1111, etc.)
    if (_hasRepeatedChars(passphrase, 4)) {
      return true;
    }

    return false;
  }

  /// Check for sequential characters
  static bool _hasSequentialChars(String str, int minLength) {
    for (var i = 0; i <= str.length - minLength; i++) {
      bool isSequential = true;
      for (var j = 0; j < minLength - 1; j++) {
        if (str.codeUnitAt(i + j + 1) != str.codeUnitAt(i + j) + 1) {
          isSequential = false;
          break;
        }
      }
      if (isSequential) return true;
    }
    return false;
  }

  /// Check for repeated characters
  static bool _hasRepeatedChars(String str, int minLength) {
    for (var i = 0; i <= str.length - minLength; i++) {
      final char = str[i];
      bool isRepeated = true;
      for (var j = 1; j < minLength; j++) {
        if (str[i + j] != char) {
          isRepeated = false;
          break;
        }
      }
      if (isRepeated) return true;
    }
    return false;
  }

  /// Get passphrase strength level
  static PassphraseStrength getStrength(String passphrase) {
    final error = validate(passphrase);
    if (error != null) {
      return PassphraseStrength.weak;
    }

    final entropy = calculateEntropy(passphrase);

    if (entropy >= 80) {
      return PassphraseStrength.veryStrong;
    } else if (entropy >= 65) {
      return PassphraseStrength.strong;
    } else if (entropy >= 50) {
      return PassphraseStrength.medium;
    } else {
      return PassphraseStrength.weak;
    }
  }
}

enum PassphraseStrength {
  weak,
  medium,
  strong,
  veryStrong,
}