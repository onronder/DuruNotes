#!/usr/bin/env dart
// Critical Security Fixes Application Script
// This script updates the broken encryption service to use proper encryption

import 'dart:io';

void main() async {
  print('🔒 Applying Critical Security Fixes for Duru Notes');
  print('=' * 60);

  // Step 1: Backup existing encryption service
  print('\n1. Backing up existing encryption service...');
  final encryptionFile = File('lib/services/security/encryption_service.dart');
  final backupFile = File(
    'lib/services/security/encryption_service.dart.backup',
  );

  if (await encryptionFile.exists()) {
    await encryptionFile.copy(backupFile.path);
    print('   ✅ Backup created: ${backupFile.path}');
  }

  // Step 2: Update encryption service to use proper implementation
  print('\n2. Updating encryption service to use proper implementation...');

  final updatedEncryptionContent = '''
// CRITICAL SECURITY FIX: Redirecting to proper encryption implementation
// The original implementation was using stub methods that didn't actually encrypt data
// This has been fixed in ProperEncryptionService

export 'proper_encryption_service.dart';

@Deprecated('Use ProperEncryptionService instead - original had critical vulnerability')
class EncryptionService extends ProperEncryptionService {
  // Maintaining backwards compatibility while redirecting to secure implementation
}
''';

  await encryptionFile.writeAsString(updatedEncryptionContent);
  print('   ✅ Encryption service updated to use secure implementation');

  // Step 3: Create security configuration file
  print('\n3. Creating security configuration...');

  final securityConfig = '''
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
    'Content-Security-Policy': "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';",
  };
}
''';

  final configFile = File('lib/config/security_config.dart');
  await configFile.writeAsString(securityConfig);
  print('   ✅ Security configuration created: ${configFile.path}');

  // Step 4: Update pubspec.yaml to ensure cryptography package is included
  print('\n4. Verifying cryptography dependency...');
  final pubspecFile = File('pubspec.yaml');
  final pubspecContent = await pubspecFile.readAsString();

  if (!pubspecContent.contains('cryptography:')) {
    print('   ⚠️  cryptography package not found in pubspec.yaml');
    print('   Please add: cryptography: ^2.7.0 to dependencies');
  } else {
    print('   ✅ cryptography package already included');
  }

  // Step 5: Create environment template
  print('\n5. Creating secure environment template...');

  final envTemplate = '''
# Duru Notes - Environment Variables Template
# Copy this to .env.local and fill in your values
# NEVER commit .env.local to git!

# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here

# Encryption
ENCRYPTION_KEY=generate-with-openssl-rand-base64-32

# Push Notifications
FCM_SERVER_KEY=your-fcm-key-here
APNS_KEY_ID=your-apns-key-id
APNS_TEAM_ID=your-apns-team-id

# Analytics
SENTRY_DSN=your-sentry-dsn-here
MIXPANEL_TOKEN=your-mixpanel-token
ADAPTY_PUBLIC_KEY=your-adapty-key

# API Keys
OPENAI_API_KEY=your-openai-key-here

# Security
INBOUND_HMAC_SECRET=generate-with-openssl-rand-base64-32
''';

  final envTemplateFile = File('.env.template');
  await envTemplateFile.writeAsString(envTemplate);
  print('   ✅ Environment template created: ${envTemplateFile.path}');

  // Step 6: Add security files to .gitignore
  print('\n6. Updating .gitignore...');
  final gitignoreFile = File('.gitignore');
  final gitignoreContent = await gitignoreFile.readAsString();

  final securityIgnores = '''

# Security - Never commit these files
.env.local
.env.production
*.pem
*.key
*.p12
*.jks
**/google-services.json
**/firebase_options*.dart
environments/*.env
secrets/
''';

  if (!gitignoreContent.contains('.env.local')) {
    await gitignoreFile.writeAsString(gitignoreContent + securityIgnores);
    print('   ✅ Security patterns added to .gitignore');
  } else {
    print('   ✅ .gitignore already configured');
  }

  // Step 7: Generate security checklist
  print('\n7. Generating security checklist...');

  final checklist = '''
# Production Security Checklist

## Before Deployment (CRITICAL)
- [ ] Replace all uses of EncryptionService with ProperEncryptionService
- [ ] Rotate ALL production secrets and API keys
- [ ] Remove secrets from git history using git-filter-repo
- [ ] Configure security headers on production server
- [ ] Enable WAF (Web Application Firewall)
- [ ] Set up DDoS protection
- [ ] Configure SSL/TLS with strong ciphers only
- [ ] Enable HSTS (HTTP Strict Transport Security)

## Testing Required
- [ ] Test encryption/decryption with real data
- [ ] Test GDPR data export functionality
- [ ] Test GDPR data deletion functionality
- [ ] Verify rate limiting works correctly
- [ ] Test authentication lockout mechanism
- [ ] Validate all input sanitization
- [ ] Run security scanner (OWASP ZAP or similar)
- [ ] Check for exposed secrets in APK/IPA

## Configuration
- [ ] Set all environment variables in production
- [ ] Configure monitoring and alerting
- [ ] Set up audit logging
- [ ] Configure backup and disaster recovery
- [ ] Document incident response procedures

## Compliance
- [ ] Update Privacy Policy for GDPR
- [ ] Update Terms of Service
- [ ] Prepare Data Processing Agreements
- [ ] Document data retention policies
- [ ] Set up user consent management

## Post-Deployment
- [ ] Monitor security events
- [ ] Review audit logs regularly
- [ ] Schedule penetration testing
- [ ] Plan security training for team
- [ ] Set up bug bounty program (optional)
''';

  final checklistFile = File('SECURITY_CHECKLIST.md');
  await checklistFile.writeAsString(checklist);
  print('   ✅ Security checklist created: ${checklistFile.path}');

  print('\n${'=' * 60}');
  print('✅ CRITICAL SECURITY FIXES APPLIED SUCCESSFULLY');
  print('=' * 60);

  print('\n⚠️  IMPORTANT NEXT STEPS:');
  print('1. Run: flutter pub get');
  print('2. Run: flutter test test/security/');
  print('3. Search and replace all uses of EncryptionService');
  print('4. Rotate all production secrets immediately');
  print('5. Review SECURITY_CHECKLIST.md before deployment');

  print('\n🔐 Security Report: PRODUCTION_SECURITY_AUDIT_REPORT.md');
  print('📋 Checklist: SECURITY_CHECKLIST.md');
  print('🔑 Environment Template: .env.template');

  print('\n⛔ DO NOT DEPLOY WITHOUT COMPLETING ALL SECURITY FIXES');
}
