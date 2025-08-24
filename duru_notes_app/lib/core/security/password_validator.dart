import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Password strength levels
enum PasswordStrength {
  weak,
  medium,
  strong,
  veryStrong,
}

/// Password validation result
class PasswordValidationResult {
  const PasswordValidationResult({
    required this.isValid,
    required this.strength,
    required this.score,
    required this.failedCriteria,
    required this.suggestions,
  });

  final bool isValid;
  final PasswordStrength strength;
  final int score; // 0-100
  final List<String> failedCriteria;
  final List<String> suggestions;
}

/// Individual password criteria
class PasswordCriterion {
  const PasswordCriterion({
    required this.id,
    required this.description,
    required this.validator,
    required this.weight,
  });

  final String id;
  final String description;
  final bool Function(String) validator;
  final int weight; // Contribution to overall score
}

/// Comprehensive password validator with real-time strength analysis
class PasswordValidator {
  PasswordValidator();

  // Password criteria with their weights
  static final List<PasswordCriterion> _criteria = [
    PasswordCriterion(
      id: 'min_length',
      description: 'At least 12 characters',
      validator: (password) => password.length >= 12,
      weight: 25,
    ),
    PasswordCriterion(
      id: 'uppercase',
      description: 'At least one uppercase letter (A-Z)',
      validator: (password) => RegExp(r'[A-Z]').hasMatch(password),
      weight: 15,
    ),
    PasswordCriterion(
      id: 'lowercase',
      description: 'At least one lowercase letter (a-z)',
      validator: (password) => RegExp(r'[a-z]').hasMatch(password),
      weight: 15,
    ),
    PasswordCriterion(
      id: 'number',
      description: 'At least one number (0-9)',
      validator: (password) => RegExp(r'[0-9]').hasMatch(password),
      weight: 15,
    ),
    PasswordCriterion(
      id: 'special_char',
      description: 'At least one special character (!@#\$%^&*)',
      validator: (password) => RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password),
      weight: 20,
    ),
    PasswordCriterion(
      id: 'no_common_patterns',
      description: 'No common patterns (123, abc, etc.)',
      validator: (password) => !_hasCommonPatterns(password),
      weight: 10,
    ),
  ];

  /// Validate password and return comprehensive result
  PasswordValidationResult validatePassword(String password) {
    final failedCriteria = <String>[];
    final suggestions = <String>[];
    int totalScore = 0;

    // Check each criterion
    for (final criterion in _criteria) {
      if (criterion.validator(password)) {
        totalScore += criterion.weight;
      } else {
        failedCriteria.add(criterion.description);
        suggestions.add(_getSuggestionForCriterion(criterion.id));
      }
    }

    // Add bonus points for length beyond minimum
    if (password.length > 12) {
      totalScore += (password.length - 12) * 2; // 2 points per extra char
    }

    // Add bonus for character diversity
    final uniqueChars = password.split('').toSet().length;
    if (uniqueChars > 8) {
      totalScore += (uniqueChars - 8) * 1; // 1 point per unique char beyond 8
    }

    // Cap score at 100
    totalScore = totalScore.clamp(0, 100);

    final strength = _calculateStrength(totalScore);
    final isValid = failedCriteria.isEmpty && totalScore >= 70;

    return PasswordValidationResult(
      isValid: isValid,
      strength: strength,
      score: totalScore,
      failedCriteria: failedCriteria,
      suggestions: suggestions,
    );
  }

  /// Calculate password strength based on score
  PasswordStrength _calculateStrength(int score) {
    if (score >= 90) return PasswordStrength.veryStrong;
    if (score >= 75) return PasswordStrength.strong;
    if (score >= 50) return PasswordStrength.medium;
    return PasswordStrength.weak;
  }

  /// Get user-friendly suggestion for failed criterion
  String _getSuggestionForCriterion(String criterionId) {
    switch (criterionId) {
      case 'min_length':
        return 'Use at least 12 characters for better security';
      case 'uppercase':
        return 'Add at least one uppercase letter (A-Z)';
      case 'lowercase':
        return 'Add at least one lowercase letter (a-z)';
      case 'number':
        return 'Add at least one number (0-9)';
      case 'special_char':
        return 'Add at least one special character (!@#\$%^&*)';
      case 'no_common_patterns':
        return 'Avoid common patterns like 123, abc, or repeated characters';
      default:
        return 'Improve password complexity';
    }
  }

  /// Check for common weak patterns
  static bool _hasCommonPatterns(String password) {
    final lowerPassword = password.toLowerCase();
    
    // Common sequential patterns
    final commonPatterns = [
      '123',
      'abc',
      'qwerty',
      'password',
      'admin',
      'user',
      'login',
    ];

    for (final pattern in commonPatterns) {
      if (lowerPassword.contains(pattern)) return true;
    }

    // Check for repeated characters (more than 3 in a row)
    for (int i = 0; i < password.length - 2; i++) {
      if (password[i] == password[i + 1] && password[i] == password[i + 2]) {
        return true;
      }
    }

    return false;
  }

  /// Get all password criteria for UI display
  static List<PasswordCriterion> getCriteria() => _criteria;

  /// Generate password hash for history comparison
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Get strength color for UI
  static String getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return '#f44336'; // Red
      case PasswordStrength.medium:
        return '#ff9800'; // Orange
      case PasswordStrength.strong:
        return '#4caf50'; // Green
      case PasswordStrength.veryStrong:
        return '#2e7d32'; // Dark Green
    }
  }

  /// Get strength description for UI
  static String getStrengthDescription(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.medium:
        return 'Medium';
      case PasswordStrength.strong:
        return 'Strong';
      case PasswordStrength.veryStrong:
        return 'Very Strong';
    }
  }
}
