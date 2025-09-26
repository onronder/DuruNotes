import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/core/security/secure_storage_manager.dart';
import 'package:duru_notes/core/security/security_monitor.dart';
import 'package:duru_notes/core/security/database_encryption.dart';
import 'package:duru_notes/core/migration/encryption_format_migration.dart';
import 'package:duru_notes/services/security/security_audit_trail.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/crypto/key_manager.dart';
import 'package:duru_notes/services/account_key_service.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for secure storage manager
final secureStorageManagerProvider = Provider<SecureStorageManager>((ref) {
  return SecureStorageManager.instance;
});

/// Provider for security monitor
final securityMonitorProvider = Provider<SecurityMonitor>((ref) {
  return SecurityMonitor.instance;
});

/// Provider for security audit trail
final securityAuditTrailProvider = Provider<SecurityAuditTrail>((ref) {
  return SecurityAuditTrail();
});

/// Provider for database encryption
final databaseEncryptionProvider = Provider<DatabaseEncryption>((ref) {
  return DatabaseEncryption();
});

/// Provider for encryption format migration
final encryptionMigrationProvider = Provider<EncryptionFormatMigration>((ref) {
  final supabase = Supabase.instance.client;
  final accountKeyService = AccountKeyService(
    ref,
    client: supabase,
  );
  final keyManager = KeyManager(
    accountKeyService: accountKeyService,
  );
  final cryptoBox = CryptoBox(keyManager);

  return EncryptionFormatMigration(
    db: AppDb(),
    supabase: supabase,
    cryptoBox: cryptoBox,
    keyManager: keyManager,
  );
});

/// Provider for current security threat level
final threatLevelProvider = StreamProvider<SecurityThreatLevel>((ref) {
  final monitor = ref.watch(securityMonitorProvider);
  return monitor.metricsStream
      .map((metrics) => metrics.threatLevel)
      .distinct();
});

/// Provider for security alerts
final securityAlertsProvider = StreamProvider<SecurityAlert>((ref) {
  final monitor = ref.watch(securityMonitorProvider);
  return monitor.alertStream;
});

/// Provider for security metrics
final securityMetricsProvider = StreamProvider<SecurityMetrics>((ref) {
  final monitor = ref.watch(securityMonitorProvider);
  return monitor.metricsStream;
});

/// Provider for lockdown state
final lockdownStateProvider = Provider<bool>((ref) {
  final monitor = ref.watch(securityMonitorProvider);
  return monitor.isInLockdown;
});

/// Security service for managing all security operations
class SecurityService {
  SecurityService({
    required this.storageManager,
    required this.monitor,
    required this.auditTrail,
    required this.dbEncryption,
  });

  final SecureStorageManager storageManager;
  final SecurityMonitor monitor;
  final SecurityAuditTrail auditTrail;
  final DatabaseEncryption dbEncryption;

  /// Initialize all security services
  Future<void> initialize() async {
    await storageManager.initialize();
    await monitor.initialize();
    await auditTrail.initialize();
  }

  /// Perform security health check
  Future<SecurityHealthStatus> performHealthCheck() async {
    final status = SecurityHealthStatus();

    // Check secure storage
    status.secureStorageAvailable = await storageManager.isAvailable();

    // Check threat level
    status.currentThreatLevel = monitor.threatLevel;

    // Check lockdown status
    status.isInLockdown = monitor.isInLockdown;

    // Check database encryption
    try {
      final dbKey = await dbEncryption.getDatabaseKey();
      status.databaseEncrypted = dbKey.isNotEmpty;
    } catch (e) {
      status.databaseEncrypted = false;
    }

    return status;
  }

  /// Rotate all encryption keys
  Future<void> rotateAllKeys() async {
    // Rotate secure storage keys
    await storageManager.rotateKeys();

    // Rotate database encryption key
    await dbEncryption.rotateDatabaseKey();

    // Log the rotation
    await auditTrail.logKeyRotation(
      oldKeyId: 'all_keys',
      newKeyId: 'rotated_keys',
      itemsRotated: -1, // Unknown count
    );
  }

  /// Clear all user data (for logout)
  Future<void> clearUserData() async {
    await storageManager.clearUserData();
    await dbEncryption.clearDatabaseKey();
  }

  /// Handle security incident
  Future<void> handleSecurityIncident(String description) async {
    await auditTrail.logViolation(
      type: 'manual_report',
      description: description,
    );

    // Monitor will automatically handle the incident
  }
}

/// Provider for security service
final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService(
    storageManager: ref.watch(secureStorageManagerProvider),
    monitor: ref.watch(securityMonitorProvider),
    auditTrail: ref.watch(securityAuditTrailProvider),
    dbEncryption: ref.watch(databaseEncryptionProvider),
  );
});

/// Security health status
class SecurityHealthStatus {
  bool secureStorageAvailable = false;
  bool databaseEncrypted = false;
  SecurityThreatLevel currentThreatLevel = SecurityThreatLevel.low;
  bool isInLockdown = false;

  Map<String, dynamic> toJson() => {
        'secureStorageAvailable': secureStorageAvailable,
        'databaseEncrypted': databaseEncrypted,
        'currentThreatLevel': currentThreatLevel.name,
        'isInLockdown': isInLockdown,
      };
}