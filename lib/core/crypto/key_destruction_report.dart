import 'dart:convert';

/// Report of encryption key destruction operation for GDPR Article 17 anonymization
///
/// This class tracks the complete destruction of all encryption key copies across
/// all storage locations (local keychain, remote database tables) to ensure
/// irreversible anonymization as required by GDPR Recital 26.
///
/// **Purpose:**
/// - Verify all key locations were checked
/// - Confirm successful deletion of each key
/// - Provide audit trail for GDPR compliance
/// - Enable debugging if destruction fails
///
/// **Key Storage Locations (6 total):**
/// 1. `mk:{userId}` - Legacy device-bound master key (local keychain)
/// 2. `amk:{userId}` - Account Master Key (local keychain)
/// 3. `amk_meta:{userId}` - AMK metadata/salt (local keychain)
/// 4. `encryption_sync_amk:{userId}` - Cross-device AMK (local keychain)
/// 5. `user_keys.wrapped_key` - Encrypted AMK (Supabase database)
/// 6. `user_encryption_keys.encrypted_amk` - Cross-device encrypted AMK (Supabase database)
///
/// **Usage:**
/// ```dart
/// final report = await keyManager.securelyDestroyAllKeys(
///   userId: userId,
///   confirmationToken: 'DESTROY_ALL_KEYS_$userId',
/// );
///
/// if (report.allKeysDestroyed) {
///   print('✅ All keys destroyed successfully');
/// } else {
///   print('❌ Destruction incomplete: ${report.errors}');
/// }
/// ```
///
/// **GDPR Compliance:**
/// - Article 17 (Right to Erasure): Provides proof of deletion
/// - Recital 26 (Anonymization): Verifies irreversibility
/// - ISO 27001:2022: Secure disposal audit trail
class KeyDestructionReport {
  /// Create a new destruction report for the specified user
  KeyDestructionReport({required this.userId});

  /// User ID whose keys are being destroyed
  final String userId;

  /// Timestamp when destruction operation started
  final DateTime timestamp = DateTime.now();

  // =========================================================================
  // Pre-Destruction Verification
  // =========================================================================
  //
  // Tracks which keys existed BEFORE destruction attempt.
  // Used to determine if destruction was complete or if keys were missing.

  /// Legacy device key existed in keychain before destruction
  bool legacyKeyExistedBeforeDestruction = false;

  /// Account Master Key existed in local keychain before destruction
  bool amkExistedBeforeDestruction = false;

  /// Remote wrapped AMK existed in user_keys table before destruction
  bool remoteAmkExistedBeforeDestruction = false;

  /// Cross-device AMK existed in local keychain before destruction
  bool crossDeviceAmkExistedBeforeDestruction = false;

  /// Remote cross-device key existed in user_encryption_keys table before destruction
  bool remoteCrossDeviceKeyExistedBeforeDestruction = false;

  // =========================================================================
  // Destruction Results
  // =========================================================================
  //
  // Tracks which keys were successfully destroyed.
  // All flags must be true for complete destruction.

  /// In-memory cached key was overwritten and cleared
  bool memoryKeyDestroyed = false;

  /// Legacy device key (mk:{userId}) was deleted from keychain
  bool legacyKeyDestroyed = false;

  /// Local Account Master Key (amk:{userId}) was deleted from keychain
  bool localAmkDestroyed = false;

  /// Remote wrapped AMK was deleted from user_keys database table
  bool remoteAmkDestroyed = false;

  /// Local cross-device AMK was deleted from keychain
  bool localCrossDeviceKeyDestroyed = false;

  /// Remote cross-device key was deleted from user_encryption_keys table
  bool remoteCrossDeviceKeyDestroyed = false;

  // =========================================================================
  // Error Tracking
  // =========================================================================

  /// List of errors encountered during destruction
  ///
  /// Empty list indicates successful destruction with no errors.
  /// Non-empty list indicates partial or failed destruction.
  final List<String> errors = [];

  // =========================================================================
  // Computed Properties
  // =========================================================================

  /// True if ALL applicable keys were successfully destroyed with zero errors
  ///
  /// This is the primary indicator of successful anonymization.
  /// Returns false if:
  /// - Any errors occurred
  /// - Any key destruction flag is false
  bool get allKeysDestroyed {
    return errors.isEmpty &&
        legacyKeyDestroyed &&
        localAmkDestroyed &&
        remoteAmkDestroyed &&
        localCrossDeviceKeyDestroyed &&
        remoteCrossDeviceKeyDestroyed &&
        memoryKeyDestroyed;
  }

  /// True if any errors were encountered during destruction
  bool get hasErrors => errors.isNotEmpty;

  /// True if destruction was successful (synonym for allKeysDestroyed)
  bool get success => allKeysDestroyed;

  /// True if any keys existed before destruction attempt
  ///
  /// If false, user may not have had any keys set up (unusual but possible).
  bool get anyKeysExisted {
    return legacyKeyExistedBeforeDestruction ||
        amkExistedBeforeDestruction ||
        remoteAmkExistedBeforeDestruction ||
        crossDeviceAmkExistedBeforeDestruction ||
        remoteCrossDeviceKeyExistedBeforeDestruction;
  }

  /// Count of keys that existed before destruction
  int get keysExistedCount {
    int count = 0;
    if (legacyKeyExistedBeforeDestruction) count++;
    if (amkExistedBeforeDestruction) count++;
    if (remoteAmkExistedBeforeDestruction) count++;
    if (crossDeviceAmkExistedBeforeDestruction) count++;
    if (remoteCrossDeviceKeyExistedBeforeDestruction) count++;
    return count;
  }

  /// Count of keys successfully destroyed
  int get keysDestroyedCount {
    int count = 0;
    if (memoryKeyDestroyed) count++;
    if (legacyKeyDestroyed) count++;
    if (localAmkDestroyed) count++;
    if (remoteAmkDestroyed) count++;
    if (localCrossDeviceKeyDestroyed) count++;
    if (remoteCrossDeviceKeyDestroyed) count++;
    return count;
  }

  // =========================================================================
  // Serialization
  // =========================================================================

  /// Convert report to JSON for audit logging
  ///
  /// Used for:
  /// - Anonymization event audit trail
  /// - GDPR compliance proof
  /// - Debugging destruction failures
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'timestamp': timestamp.toIso8601String(),
    'preDestruction': {
      'legacyKeyExisted': legacyKeyExistedBeforeDestruction,
      'amkExisted': amkExistedBeforeDestruction,
      'remoteAmkExisted': remoteAmkExistedBeforeDestruction,
      'crossDeviceAmkExisted': crossDeviceAmkExistedBeforeDestruction,
      'remoteCrossDeviceKeyExisted':
          remoteCrossDeviceKeyExistedBeforeDestruction,
      'anyKeysExisted': anyKeysExisted,
      'keysExistedCount': keysExistedCount,
    },
    'destruction': {
      'memoryKeyDestroyed': memoryKeyDestroyed,
      'legacyKeyDestroyed': legacyKeyDestroyed,
      'localAmkDestroyed': localAmkDestroyed,
      'remoteAmkDestroyed': remoteAmkDestroyed,
      'localCrossDeviceKeyDestroyed': localCrossDeviceKeyDestroyed,
      'remoteCrossDeviceKeyDestroyed': remoteCrossDeviceKeyDestroyed,
      'keysDestroyedCount': keysDestroyedCount,
    },
    'result': {
      'success': success,
      'allKeysDestroyed': allKeysDestroyed,
      'hasErrors': hasErrors,
      'errors': errors,
    },
  };

  /// Convert JSON to KeyDestructionReport (for audit log retrieval)
  factory KeyDestructionReport.fromJson(Map<String, dynamic> json) {
    final report = KeyDestructionReport(userId: json['userId'] as String);

    // Parse pre-destruction state
    final preDestruction = json['preDestruction'] as Map<String, dynamic>?;
    if (preDestruction != null) {
      report.legacyKeyExistedBeforeDestruction =
          preDestruction['legacyKeyExisted'] as bool? ?? false;
      report.amkExistedBeforeDestruction =
          preDestruction['amkExisted'] as bool? ?? false;
      report.remoteAmkExistedBeforeDestruction =
          preDestruction['remoteAmkExisted'] as bool? ?? false;
      report.crossDeviceAmkExistedBeforeDestruction =
          preDestruction['crossDeviceAmkExisted'] as bool? ?? false;
      report.remoteCrossDeviceKeyExistedBeforeDestruction =
          preDestruction['remoteCrossDeviceKeyExisted'] as bool? ?? false;
    }

    // Parse destruction results
    final destruction = json['destruction'] as Map<String, dynamic>?;
    if (destruction != null) {
      report.memoryKeyDestroyed =
          destruction['memoryKeyDestroyed'] as bool? ?? false;
      report.legacyKeyDestroyed =
          destruction['legacyKeyDestroyed'] as bool? ?? false;
      report.localAmkDestroyed =
          destruction['localAmkDestroyed'] as bool? ?? false;
      report.remoteAmkDestroyed =
          destruction['remoteAmkDestroyed'] as bool? ?? false;
      report.localCrossDeviceKeyDestroyed =
          destruction['localCrossDeviceKeyDestroyed'] as bool? ?? false;
      report.remoteCrossDeviceKeyDestroyed =
          destruction['remoteCrossDeviceKeyDestroyed'] as bool? ?? false;
    }

    // Parse errors
    final result = json['result'] as Map<String, dynamic>?;
    if (result != null) {
      final errorsList = result['errors'] as List<dynamic>?;
      if (errorsList != null) {
        report.errors.addAll(errorsList.cast<String>());
      }
    }

    return report;
  }

  /// Convert report to pretty-printed JSON string for logging
  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }

  /// Convert report to compact string representation
  @override
  String toString() => jsonEncode(toJson());

  /// Create a summary string for quick status checks
  ///
  /// Example: "✅ 6/6 keys destroyed successfully"
  /// Example: "❌ 4/6 keys destroyed (2 errors)"
  String toSummary() {
    if (allKeysDestroyed) {
      return '✅ $keysDestroyedCount/6 keys destroyed successfully';
    } else if (hasErrors) {
      return '❌ $keysDestroyedCount/6 keys destroyed (${errors.length} error${errors.length == 1 ? '' : 's'})';
    } else {
      return '⚠️ $keysDestroyedCount/6 keys destroyed (incomplete)';
    }
  }

  /// Create detailed report for debugging
  ///
  /// Shows exactly which keys were destroyed and which failed.
  String toDetailedReport() {
    final buffer = StringBuffer();

    buffer.writeln('=== Key Destruction Report ===');
    buffer.writeln('User ID: $userId');
    buffer.writeln('Timestamp: ${timestamp.toIso8601String()}');
    buffer.writeln('');

    buffer.writeln('Pre-Destruction State:');
    buffer.writeln('  Legacy Key Existed: $legacyKeyExistedBeforeDestruction');
    buffer.writeln('  AMK Existed: $amkExistedBeforeDestruction');
    buffer.writeln('  Remote AMK Existed: $remoteAmkExistedBeforeDestruction');
    buffer.writeln(
      '  Cross-Device AMK Existed: $crossDeviceAmkExistedBeforeDestruction',
    );
    buffer.writeln(
      '  Remote Cross-Device Key Existed: $remoteCrossDeviceKeyExistedBeforeDestruction',
    );
    buffer.writeln('  Total Keys Found: $keysExistedCount');
    buffer.writeln('');

    buffer.writeln('Destruction Results:');
    buffer.writeln('  Memory Key Destroyed: ${memoryKeyDestroyed ? '✅' : '❌'}');
    buffer.writeln('  Legacy Key Destroyed: ${legacyKeyDestroyed ? '✅' : '❌'}');
    buffer.writeln('  Local AMK Destroyed: ${localAmkDestroyed ? '✅' : '❌'}');
    buffer.writeln('  Remote AMK Destroyed: ${remoteAmkDestroyed ? '✅' : '❌'}');
    buffer.writeln(
      '  Local Cross-Device Key Destroyed: ${localCrossDeviceKeyDestroyed ? '✅' : '❌'}',
    );
    buffer.writeln(
      '  Remote Cross-Device Key Destroyed: ${remoteCrossDeviceKeyDestroyed ? '✅' : '❌'}',
    );
    buffer.writeln('  Total Keys Destroyed: $keysDestroyedCount/6');
    buffer.writeln('');

    buffer.writeln(
      'Overall Status: ${allKeysDestroyed ? '✅ SUCCESS' : '❌ FAILED'}',
    );

    if (hasErrors) {
      buffer.writeln('');
      buffer.writeln('Errors (${errors.length}):');
      for (var i = 0; i < errors.length; i++) {
        buffer.writeln('  ${i + 1}. ${errors[i]}');
      }
    }

    buffer.writeln('==============================');

    return buffer.toString();
  }
}

/// Exception thrown when key destruction fails due to security policy
class SecurityException implements Exception {
  SecurityException(this.message, {this.originalError});

  final String message;
  final Object? originalError;

  @override
  String toString() =>
      'SecurityException: $message'
      '${originalError != null ? ' (caused by: $originalError)' : ''}';
}
