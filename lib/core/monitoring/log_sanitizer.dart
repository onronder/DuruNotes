/// Sanitizes sensitive data from logs to prevent data leakage
class LogSanitizer {
  /// Sensitive field names that should be redacted
  static const _sensitiveFields = {
    'password',
    'passphrase',
    'token',
    'access_token',
    'refresh_token',
    'accessToken',
    'refreshToken',
    'api_key',
    'apiKey',
    'secret',
    'secretKey',
    'private_key',
    'privateKey',
    'encryption_key',
    'encryptionKey',
    'salt',
    'amk',
    'wrapped_key',
    'wrappedKey',
    'session_id',
    'sessionId',
    'csrf',
    'csrfToken',
    'otp',
    'totp',
    'mfa',
    'ssn',
    'credit_card',
    'creditCard',
    'cvv',
    'pin',
  };

  /// Patterns that indicate sensitive content
  static final _sensitivePatterns = [
    RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'), // Email
    RegExp(r'\b\d{3}-\d{2}-\d{4}\b'), // SSN
    RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'), // Credit card
    RegExp(r'\b[A-Za-z0-9+/]{32,}={0,2}\b'), // Base64 tokens (32+ chars)
    RegExp(r'\b[0-9a-f]{32,}\b', caseSensitive: false), // Hex tokens
  ];

  /// Sanitize a map of data by redacting sensitive fields
  static Map<String, dynamic> sanitizeData(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return {};

    final sanitized = <String, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;

      if (_isSensitiveKey(key)) {
        sanitized[entry.key] = _redactValue(value);
      } else if (value is String && _containsSensitivePattern(value)) {
        sanitized[entry.key] = _redactString(value);
      } else if (value is Map) {
        sanitized[entry.key] = sanitizeData(value.cast<String, dynamic>());
      } else if (value is List) {
        sanitized[entry.key] = _sanitizeList(value);
      } else {
        sanitized[entry.key] = value;
      }
    }

    return sanitized;
  }

  /// Sanitize a message string by redacting sensitive patterns
  static String sanitizeMessage(String message) {
    var sanitized = message;

    for (final pattern in _sensitivePatterns) {
      sanitized = sanitized.replaceAllMapped(pattern, (match) {
        final value = match.group(0)!;
        return _redactValue(value);
      });
    }

    return sanitized;
  }

  /// Sanitize an error object
  static Object? sanitizeError(Object? error) {
    if (error == null) return null;

    final errorStr = error.toString();
    return sanitizeMessage(errorStr);
  }

  /// Check if a key name is sensitive
  static bool _isSensitiveKey(String key) {
    return _sensitiveFields.any((field) => key.contains(field));
  }

  /// Check if a string contains sensitive patterns
  static bool _containsSensitivePattern(String value) {
    if (value.length < 8) return false; // Skip short strings

    return _sensitivePatterns.any((pattern) => pattern.hasMatch(value));
  }

  /// Redact a value based on its type and length
  static String _redactValue(dynamic value) {
    if (value == null) return 'null';

    final str = value.toString();
    if (str.length <= 4) {
      return '****';
    } else if (str.length <= 8) {
      return '${str.substring(0, 2)}****';
    } else {
      // Show first 2 and last 2 characters for longer values
      return '${str.substring(0, 2)}****${str.substring(str.length - 2)}';
    }
  }

  /// Redact sensitive patterns in a string while preserving structure
  static String _redactString(String value) {
    var sanitized = value;

    for (final pattern in _sensitivePatterns) {
      sanitized = sanitized.replaceAllMapped(pattern, (match) {
        final matched = match.group(0)!;
        if (matched.length <= 8) {
          return '[REDACTED]';
        } else {
          return '[REDACTED:${matched.length}chars]';
        }
      });
    }

    return sanitized;
  }

  /// Sanitize a list by sanitizing each element
  static List<dynamic> _sanitizeList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map) {
        return sanitizeData(item.cast<String, dynamic>());
      } else if (item is String && _containsSensitivePattern(item)) {
        return _redactString(item);
      } else if (item is List) {
        return _sanitizeList(item);
      } else {
        return item;
      }
    }).toList();
  }

  /// Create a sanitized copy of data suitable for logging
  static Map<String, dynamic> forLogging(Map<String, dynamic> data) {
    return sanitizeData(data);
  }

  /// Get a safe representation of user data for logging
  static Map<String, String> safeUserInfo(String userId, {String? email}) {
    return {
      'userId': userId.length > 8
          ? '${userId.substring(0, 4)}****${userId.substring(userId.length - 4)}'
          : '****',
      if (email != null) 'email': _maskEmail(email),
    };
  }

  /// Mask an email address (show first char and domain)
  static String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return '[REDACTED_EMAIL]';

    final localPart = parts[0];
    final domain = parts[1];

    if (localPart.isEmpty) return '[REDACTED_EMAIL]';

    return '${localPart[0]}***@$domain';
  }
}