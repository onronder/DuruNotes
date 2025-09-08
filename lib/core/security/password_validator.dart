import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
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
      validator: (password) => RegExp('[A-Z]').hasMatch(password),
      weight: 15,
    ),
    PasswordCriterion(
      id: 'lowercase',
      description: 'At least one lowercase letter (a-z)',
      validator: (password) => RegExp('[a-z]').hasMatch(password),
      weight: 15,
    ),
    PasswordCriterion(
      id: 'number',
      description: 'At least one number (0-9)',
      validator: (password) => RegExp('[0-9]').hasMatch(password),
      weight: 15,
    ),
    PasswordCriterion(
      id: 'special_char',
      description: r'At least one special character (!@#$%^&*)',
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
    var totalScore = 0;

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
        return r'Add at least one special character (!@#$%^&*)';
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
    for (var i = 0; i < password.length - 2; i++) {
      if (password[i] == password[i + 1] && password[i] == password[i + 2]) {
        return true;
      }
    }

    return false;
  }

  /// Get all password criteria for UI display
  static List<PasswordCriterion> getCriteria() => _criteria;

  /// Generate secure password hash for history comparison using PBKDF2
  /// 
  /// Uses PBKDF2 with SHA-256, 100,000 iterations, and a unique salt per password
  /// This provides protection against rainbow table and dictionary attacks
  static String hashPassword(String password, {String? providedSalt}) {
    // Generate a unique salt if not provided (for new passwords)
    final salt = providedSalt ?? _generateSalt();
    
    // Use PBKDF2 with SHA-256, 100,000 iterations for security
    const iterations = 100000;
    const keyLength = 32; // 256 bits
    
    final passwordBytes = utf8.encode(password);
    final saltBytes = utf8.encode(salt);
    
    // Perform PBKDF2 key derivation
    final derivedKey = _pbkdf2(passwordBytes, saltBytes, iterations, keyLength);
    
    // Return salt:hash format for storage
    final hashHex = _bytesToHex(derivedKey);
    return '$salt:$hashHex';
  }
  
  /// Generate a cryptographically secure random salt
  static String _generateSalt({int length = 32}) {
    final random = Random.secure();
    final saltBytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      saltBytes[i] = random.nextInt(256);
    }
    return _bytesToHex(saltBytes);
  }
  
  /// PBKDF2 implementation using HMAC-SHA256
  static Uint8List _pbkdf2(List<int> password, List<int> salt, int iterations, int keyLength) {
    final hmac = Hmac(sha256, password);
    final derivedKey = Uint8List(keyLength);
    var currentBlock = 1;
    var pos = 0;
    
    while (pos < keyLength) {
      final blockData = Uint8List.fromList([...salt, ...(_intToBytes(currentBlock))]);
      var u = hmac.convert(blockData).bytes;
      final result = List<int>.from(u);
      
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < result.length; j++) {
          result[j] ^= u[j];
        }
      }
      
      final copyLength = keyLength - pos < result.length ? keyLength - pos : result.length;
      derivedKey.setRange(pos, pos + copyLength, result);
      pos += copyLength;
      currentBlock++;
    }
    
    return derivedKey;
  }
  
  /// Convert integer to 4-byte big-endian representation
  static List<int> _intToBytes(int value) {
    return [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
  }
  
  /// Convert bytes to hexadecimal string
  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
  
  /// Verify a password against a stored hash
  static bool verifyPassword(String password, String storedHash) {
    try {
      final parts = storedHash.split(':');
      if (parts.length != 2) return false;
      
      final salt = parts[0];
      final expectedHash = parts[1];
      
      final computedHash = hashPassword(password, providedSalt: salt);
      final computedHashPart = computedHash.split(':')[1];
      
      return _constantTimeEquals(expectedHash, computedHashPart);
    } catch (e) {
      return false;
    }
  }
  
  /// Constant-time string comparison to prevent timing attacks
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
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
