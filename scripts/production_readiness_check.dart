#!/usr/bin/env dart
// Production Readiness Security Checklist
// Run this before deploying to production

import 'dart:io';
import 'dart:convert';

void main() async {
  print('🔒 PRODUCTION READINESS SECURITY CHECK');
  print('=' * 60);

  final checklist = ProductionSecurityChecklist();
  await checklist.runAllChecks();

  print('\n${'=' * 60}');
  checklist.printSummary();
}

class ProductionSecurityChecklist {
  final Map<String, CheckResult> results = {};
  int critical = 0;
  int high = 0;
  int medium = 0;
  int passed = 0;

  Future<void> runAllChecks() async {
    // CRITICAL CHECKS
    await checkNoExposedSecrets();
    await checkEncryptionImplementation();
    await checkSearchImplementation();
    await checkAuthenticationSecurity();

    // HIGH PRIORITY CHECKS
    await checkFirebaseConfiguration();
    await checkRepositoryPermissions();
    await checkRateLimiting();
    await checkSQLInjectionProtection();

    // MEDIUM PRIORITY CHECKS
    await checkAuditTrail();
    await checkSecurityHeaders();
    await checkErrorHandling();
    await checkDataValidation();

    // COMPLIANCE CHECKS
    await checkGDPRCompliance();
    await checkDataRetention();
    await checkSecurityMonitoring();
  }

  Future<void> checkNoExposedSecrets() async {
    print('\n📋 Checking for exposed secrets...');

    final patterns = [
      RegExp(
        'api[_-]?key\\s*[:=]\\s*["\'][\\w\\-]+["\']',
        caseSensitive: false,
      ),
      RegExp('secret\\s*[:=]\\s*["\'][\\w\\-]+["\']', caseSensitive: false),
      RegExp('password\\s*[:=]\\s*["\'][\\w\\-]+["\']', caseSensitive: false),
      RegExp('token\\s*[:=]\\s*["\'][\\w\\-]+["\']', caseSensitive: false),
    ];

    final files = await Directory('lib')
        .list(recursive: true)
        .where((entity) => entity.path.endsWith('.dart'))
        .toList();

    var found = false;
    for (final file in files) {
      if (file is File) {
        final content = await file.readAsString();
        for (final pattern in patterns) {
          if (pattern.hasMatch(content)) {
            print('   ⚠️  Potential secret in: \${file.path}');
            found = true;
          }
        }
      }
    }

    results['exposed_secrets'] = CheckResult(
      name: 'No Exposed Secrets',
      passed: !found,
      severity: Severity.critical,
      message: found ? 'Found potential exposed secrets' : 'No secrets found',
    );

    if (!found) {
      print('   ✅ No exposed secrets found');
      passed++;
    } else {
      print('   ❌ CRITICAL: Exposed secrets detected');
      critical++;
    }
  }

  Future<void> checkEncryptionImplementation() async {
    print('\n📋 Checking encryption implementation...');

    final encryptionFile = File(
      'lib/services/security/proper_encryption_service.dart',
    );
    final exists = await encryptionFile.exists();

    if (exists) {
      final content = await encryptionFile.readAsString();
      final hasAES = content.contains('AesGcm.with256bits');
      final hasKeyManagement = content.contains('SecretKey');
      final hasSecureStorage = content.contains('FlutterSecureStorage');

      final allGood = hasAES && hasKeyManagement && hasSecureStorage;

      results['encryption'] = CheckResult(
        name: 'Encryption Implementation',
        passed: allGood,
        severity: Severity.critical,
        message: allGood
            ? 'Proper encryption in place'
            : 'Encryption issues found',
      );

      if (allGood) {
        print('   ✅ Proper AES-256-GCM encryption implemented');
        passed++;
      } else {
        print('   ❌ CRITICAL: Encryption implementation incomplete');
        critical++;
      }
    } else {
      print('   ❌ CRITICAL: Encryption service not found');
      critical++;
    }
  }

  Future<void> checkSearchImplementation() async {
    print('\n📋 Checking search implementation...');

    final searchFile = File('lib/services/unified_search_service.dart');
    if (await searchFile.exists()) {
      final content = await searchFile.readAsString();
      final hasStub =
          content.contains('// TODO: Implement search') ||
          content.contains('final notes = <domain.Note>[];');

      results['search'] = CheckResult(
        name: 'Search Implementation',
        passed: !hasStub,
        severity: Severity.critical,
        message: hasStub
            ? 'Search using stub implementation'
            : 'Search properly implemented',
      );

      if (!hasStub) {
        print('   ✅ Search properly implemented');
        passed++;
      } else {
        print('   ❌ CRITICAL: Search still using stub');
        critical++;
      }
    }
  }

  Future<void> checkAuthenticationSecurity() async {
    print('\n📋 Checking authentication security...');

    final authFile = File('lib/core/auth/auth_service.dart');
    if (await authFile.exists()) {
      final content = await authFile.readAsString();

      final checks = {
        'Rate limiting': content.contains('_maxRetries'),
        'Exponential backoff': content.contains('_calculateDelay'),
        'Account lockout': content.contains('checkAccountLockout'),
        'Brute force protection': content.contains('LoginAttemptsService'),
      };

      final allPassed = checks.values.every((v) => v);

      results['authentication'] = CheckResult(
        name: 'Authentication Security',
        passed: allPassed,
        severity: Severity.critical,
        message: allPassed
            ? 'Authentication secure'
            : 'Authentication vulnerabilities',
      );

      for (final entry in checks.entries) {
        print('   ${entry.value ? "✅" : "❌"} ${entry.key}');
      }

      if (allPassed) {
        passed++;
      } else {
        critical++;
      }
    }
  }

  Future<void> checkFirebaseConfiguration() async {
    print('\n📋 Checking Firebase configuration...');

    final firebaseFile = File(
      'lib/core/config/firebase_environment_bridge.dart',
    );
    if (await firebaseFile.exists()) {
      final content = await firebaseFile.readAsString();

      final hasHardcodedValues =
          content.contains('259019439896') ||
          content.contains('durunotes.firebasestorage');

      results['firebase_config'] = CheckResult(
        name: 'Firebase Configuration',
        passed: !hasHardcodedValues,
        severity: Severity.high,
        message: hasHardcodedValues
            ? 'Hardcoded values found'
            : 'Environment-based config',
      );

      if (!hasHardcodedValues) {
        print('   ✅ No hardcoded Firebase values');
        passed++;
      } else {
        print('   ⚠️  HIGH: Hardcoded Firebase configuration');
        high++;
      }
    }
  }

  Future<void> checkRepositoryPermissions() async {
    print('\n📋 Checking repository permissions...');

    final repoFiles = await Directory(
      'lib/infrastructure/repositories',
    ).list().where((entity) => entity.path.endsWith('.dart')).toList();

    var hasPermissionChecks = false;
    for (final file in repoFiles) {
      if (file is File) {
        final content = await file.readAsString();
        if (content.contains('validateUserAccess') ||
            content.contains('currentUser?.id')) {
          hasPermissionChecks = true;
          break;
        }
      }
    }

    results['repository_permissions'] = CheckResult(
      name: 'Repository Permissions',
      passed: hasPermissionChecks,
      severity: Severity.high,
      message: hasPermissionChecks
          ? 'Permission checks found'
          : 'Missing permission validation',
    );

    if (hasPermissionChecks) {
      print('   ✅ Repository permission checks in place');
      passed++;
    } else {
      print('   ⚠️  HIGH: Repository permission validation missing');
      high++;
    }
  }

  Future<void> checkRateLimiting() async {
    print('\n📋 Checking rate limiting...');

    final rateLimiterFile = File('lib/core/middleware/rate_limiter.dart');
    final apiWrapperFile = File('lib/data/remote/secure_api_wrapper.dart');

    final rateLimiterExists = await rateLimiterFile.exists();
    final apiWrapperExists = await apiWrapperFile.exists();

    var hasRateLimiting = false;
    if (apiWrapperExists) {
      final content = await apiWrapperFile.readAsString();
      hasRateLimiting = content.contains('checkRateLimit');
    }

    results['rate_limiting'] = CheckResult(
      name: 'Rate Limiting',
      passed: rateLimiterExists && hasRateLimiting,
      severity: Severity.high,
      message: hasRateLimiting
          ? 'Rate limiting active'
          : 'Rate limiting incomplete',
    );

    if (rateLimiterExists && hasRateLimiting) {
      print('   ✅ Rate limiting properly configured');
      passed++;
    } else {
      print('   ⚠️  HIGH: Rate limiting not fully implemented');
      high++;
    }
  }

  Future<void> checkSQLInjectionProtection() async {
    print('\n📋 Checking SQL injection protection...');

    final validationFile = File(
      'lib/services/security/input_validation_service.dart',
    );
    if (await validationFile.exists()) {
      final content = await validationFile.readAsString();

      final hasSQLPatterns = content.contains('_sqlKeywordPattern');
      final hasValidation = content.contains('validateAndSanitizeText');

      results['sql_injection'] = CheckResult(
        name: 'SQL Injection Protection',
        passed: hasSQLPatterns && hasValidation,
        severity: Severity.high,
        message: (hasSQLPatterns && hasValidation)
            ? 'SQL injection protection active'
            : 'SQL injection protection incomplete',
      );

      if (hasSQLPatterns && hasValidation) {
        print('   ✅ SQL injection protection in place');
        passed++;
      } else {
        print('   ⚠️  HIGH: SQL injection protection incomplete');
        high++;
      }
    }
  }

  Future<void> checkAuditTrail() async {
    print('\n📋 Checking audit trail...');

    final auditFile = File('lib/services/security/security_audit_trail.dart');
    final exists = await auditFile.exists();

    results['audit_trail'] = CheckResult(
      name: 'Security Audit Trail',
      passed: exists,
      severity: Severity.medium,
      message: exists ? 'Audit trail configured' : 'Audit trail missing',
    );

    if (exists) {
      print('   ✅ Security audit trail in place');
      passed++;
    } else {
      print('   ⚠️  MEDIUM: Audit trail not configured');
      medium++;
    }
  }

  Future<void> checkSecurityHeaders() async {
    print('\n📋 Checking security headers configuration...');

    final configFile = File('lib/config/security_config.dart');
    final exists = await configFile.exists();

    if (exists) {
      final content = await configFile.readAsString();
      final hasCSP = content.contains('Content-Security-Policy');
      final hasHSTS = content.contains('Strict-Transport-Security');

      results['security_headers'] = CheckResult(
        name: 'Security Headers',
        passed: hasCSP && hasHSTS,
        severity: Severity.medium,
        message: (hasCSP && hasHSTS)
            ? 'Headers configured'
            : 'Headers incomplete',
      );

      if (hasCSP && hasHSTS) {
        print('   ✅ Security headers configured');
        passed++;
      } else {
        print('   ⚠️  MEDIUM: Security headers incomplete');
        medium++;
      }
    } else {
      print('   ⚠️  MEDIUM: Security config not found');
      medium++;
    }
  }

  Future<void> checkErrorHandling() async {
    print('\n📋 Checking error handling...');

    final errorService = File('lib/services/error_logging_service.dart');
    final exists = await errorService.exists();

    results['error_handling'] = CheckResult(
      name: 'Error Handling',
      passed: exists,
      severity: Severity.medium,
      message: exists
          ? 'Error logging configured'
          : 'Error handling incomplete',
    );

    if (exists) {
      print('   ✅ Error handling service configured');
      passed++;
    } else {
      print('   ⚠️  MEDIUM: Error handling incomplete');
      medium++;
    }
  }

  Future<void> checkDataValidation() async {
    print('\n📋 Checking data validation...');

    final validationFile = File(
      'lib/services/security/input_validation_service.dart',
    );
    final exists = await validationFile.exists();

    if (exists) {
      final content = await validationFile.readAsString();

      final checks = {
        'XSS protection': content.contains('_htmlTagPattern'),
        'Path traversal': content.contains('_pathTraversalPattern'),
        'Email validation': content.contains('_emailPattern'),
        'Command injection': content.contains('_commandInjectionPattern'),
      };

      final allPassed = checks.values.every((v) => v);

      results['data_validation'] = CheckResult(
        name: 'Data Validation',
        passed: allPassed,
        severity: Severity.high,
        message: allPassed ? 'Comprehensive validation' : 'Validation gaps',
      );

      for (final entry in checks.entries) {
        print('   ${entry.value ? "✅" : "❌"} ${entry.key}');
      }

      if (allPassed) {
        passed++;
      } else {
        high++;
      }
    }
  }

  Future<void> checkGDPRCompliance() async {
    print('\n📋 Checking GDPR compliance...');

    final gdprFile = File('lib/services/gdpr_compliance_service.dart');
    final exists = await gdprFile.exists();

    results['gdpr_compliance'] = CheckResult(
      name: 'GDPR Compliance',
      passed: exists,
      severity: Severity.medium,
      message: exists ? 'GDPR service configured' : 'GDPR compliance missing',
    );

    if (exists) {
      print('   ✅ GDPR compliance service found');
      passed++;
    } else {
      print('   ⚠️  MEDIUM: GDPR compliance not configured');
      medium++;
    }
  }

  Future<void> checkDataRetention() async {
    print('\n📋 Checking data retention policies...');
    // Simplified check - would need actual implementation
    print('   ℹ️  Manual review required for data retention policies');
  }

  Future<void> checkSecurityMonitoring() async {
    print('\n📋 Checking security monitoring...');

    final monitorFile = File('lib/core/security/security_monitor.dart');
    final exists = await monitorFile.exists();

    if (exists) {
      final content = await monitorFile.readAsString();
      final hasAlerts = content.contains('SecurityAlert');
      final hasMetrics = content.contains('SecurityMetrics');
      final hasThreatDetection = content.contains('_detectAnomalies');

      final allGood = hasAlerts && hasMetrics && hasThreatDetection;

      results['security_monitoring'] = CheckResult(
        name: 'Security Monitoring',
        passed: allGood,
        severity: Severity.high,
        message: allGood ? 'Monitoring active' : 'Monitoring incomplete',
      );

      if (allGood) {
        print('   ✅ Security monitoring configured');
        passed++;
      } else {
        print('   ⚠️  HIGH: Security monitoring incomplete');
        high++;
      }
    }
  }

  void printSummary() {
    final total = results.length;

    print('\n📊 SECURITY ASSESSMENT SUMMARY');
    print('-' * 60);
    print('Total Checks: \$total');
    print('✅ Passed: \$passed');
    print('🔴 Critical Issues: \$critical');
    print('🟠 High Priority Issues: \$high');
    print('🟡 Medium Priority Issues: \$medium');

    final score = (passed / total * 100).toStringAsFixed(1);
    print('\nSecurity Score: \$score%');

    if (critical > 0) {
      print('\n⛔ DEPLOYMENT BLOCKED - Critical issues must be fixed');
      print('\nCritical Issues:');
      results.forEach((key, result) {
        if (!result.passed && result.severity == Severity.critical) {
          print('  ❌ \${result.name}: \${result.message}');
        }
      });
    } else if (high > 0) {
      print('\n⚠️  HIGH RISK - Fix high priority issues before production');
      print('\nHigh Priority Issues:');
      results.forEach((key, result) {
        if (!result.passed && result.severity == Severity.high) {
          print('  ⚠️  \${result.name}: \${result.message}');
        }
      });
    } else {
      print(
        '\n✅ PRODUCTION READY - All critical and high priority checks passed',
      );
    }

    // Generate report file
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'score': double.parse(score),
      'total_checks': total,
      'passed': passed,
      'critical_issues': critical,
      'high_issues': high,
      'medium_issues': medium,
      'production_ready': critical == 0 && high == 0,
      'details': results.map(
        (key, value) => MapEntry(key, {
          'passed': value.passed,
          'severity': value.severity.toString(),
          'message': value.message,
        }),
      ),
    };

    File(
      'production_readiness_report.json',
    ).writeAsStringSync(jsonEncode(report));

    print('\n📄 Report saved to: production_readiness_report.json');

    if (critical > 0 || high > 0) {
      exit(1); // Exit with error code if not production ready
    }
  }
}

class CheckResult {
  final String name;
  final bool passed;
  final Severity severity;
  final String message;

  CheckResult({
    required this.name,
    required this.passed,
    required this.severity,
    required this.message,
  });
}

enum Severity { critical, high, medium, low }
