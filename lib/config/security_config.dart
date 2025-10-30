// Security Configuration for Production
class SecurityConfig {
  // Encryption settings
  static const bool useEncryption = true;
  static const String encryptionAlgorithm = 'AES-256-GCM';
  static const int keyRotationDays = 90;

  // Rate limiting
  static const int requestsPerMinute = 100;
  static const int requestsPerHour = 1000;

  // Authentication
  static const int maxLoginAttempts = 5;
  static const Duration accountLockDuration = Duration(minutes: 15);

  // GDPR compliance
  static const bool gdprEnabled = true;
  static const Duration dataRetentionPeriod = Duration(days: 730); // 2 years

  // Security headers (configure in production server)
  static const Map<String, String> securityHeaders = {
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'Content-Security-Policy':
        "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';",
  };
}
