import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:duru_notes/core/io/app_directory_resolver.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Security Audit Trail Service
/// Tracks security-related events for compliance and debugging
class SecurityAuditTrail {
  static final SecurityAuditTrail _instance = SecurityAuditTrail._internal();
  factory SecurityAuditTrail() => _instance;
  SecurityAuditTrail._internal();

  final AppLogger _logger = LoggerFactory.instance;
  final StreamController<SecurityEvent> _eventController =
      StreamController<SecurityEvent>.broadcast();

  final List<SecurityEvent> _recentEvents = [];
  static const int _maxRecentEvents = 100;

  File? _auditFile;
  bool _initialized = false;

  void _captureAuditException({
    required String operation,
    required Object error,
    StackTrace? stackTrace,
    SentryLevel level = SentryLevel.error,
  }) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.level = level;
          scope.setTag('service', 'SecurityAuditTrail');
          scope.setTag('operation', operation);
        },
      ),
    );
  }

  /// Stream of security events
  Stream<SecurityEvent> get eventStream => _eventController.stream;

  /// Recent security events (up to 100)
  List<SecurityEvent> get recentEvents => List.unmodifiable(_recentEvents);

  /// Initialize the audit trail
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Get secure directory for audit logs
      final directory = await resolveAppDocumentsDirectory();
      final auditDir = Directory('${directory.path}/security_audit');

      if (!await auditDir.exists()) {
        await auditDir.create(recursive: true);
      }

      // Create daily audit file
      final dateStr = DateTime.now().toIso8601String().split('T')[0];
      _auditFile = File('${auditDir.path}/audit_$dateStr.log');

      _initialized = true;
      await logEvent(
        SecurityEventType.auditStarted,
        'Security audit trail initialized',
      );
    } catch (error, stack) {
      _logger.error(
        'Failed to initialize security audit trail',
        error: error,
        stackTrace: stack,
      );
      _captureAuditException(
        operation: 'initialize',
        error: error,
        stackTrace: stack,
      );
    }
  }

  /// Log a security event
  Future<void> logEvent(
    SecurityEventType type,
    String description, {
    Map<String, dynamic>? metadata,
    SecuritySeverity severity = SecuritySeverity.info,
  }) async {
    final event = SecurityEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      type: type,
      description: description,
      metadata: metadata,
      severity: severity,
      userId: _getCurrentUserId(),
      deviceId: _getDeviceId(),
    );

    // Add to recent events
    _recentEvents.add(event);
    if (_recentEvents.length > _maxRecentEvents) {
      _recentEvents.removeAt(0);
    }

    // Emit to stream
    _eventController.add(event);

    // Write to audit file
    try {
      await _writeToFile(event);
    } catch (error, stack) {
      _logger.error(
        'Failed to write security event to audit file',
        error: error,
        stackTrace: stack,
      );
      _captureAuditException(
        operation: 'writeToFile',
        error: error,
        stackTrace: stack,
        level: SentryLevel.warning,
      );
    }

    // Log critical events
    if (severity == SecuritySeverity.critical) {
      _logger.error('CRITICAL SECURITY EVENT: $description', data: metadata);
    } else if (severity == SecuritySeverity.warning) {
      _logger.warning('Security warning: $description', data: metadata);
    }
  }

  /// Log encryption operation
  Future<void> logEncryption({
    required String dataType,
    required int dataSize,
    required String keyId,
    bool success = true,
    String? error,
  }) async {
    await logEvent(
      SecurityEventType.encryptionOperation,
      'Encrypted $dataType',
      metadata: {
        'dataType': dataType,
        'dataSize': dataSize,
        'keyId': keyId,
        'success': success,
        if (error != null) 'error': error,
      },
      severity: success ? SecuritySeverity.info : SecuritySeverity.warning,
    );
  }

  /// Log decryption operation
  Future<void> logDecryption({
    required String dataType,
    required String keyId,
    bool success = true,
    String? error,
  }) async {
    await logEvent(
      SecurityEventType.decryptionOperation,
      'Decrypted $dataType',
      metadata: {
        'dataType': dataType,
        'keyId': keyId,
        'success': success,
        if (error != null) 'error': error,
      },
      severity: success ? SecuritySeverity.info : SecuritySeverity.warning,
    );
  }

  /// Log authentication event
  Future<void> logAuthentication({
    required String method,
    required bool success,
    String? userId,
    String? error,
  }) async {
    await logEvent(
      SecurityEventType.authentication,
      success ? 'Authentication successful' : 'Authentication failed',
      metadata: {
        'method': method,
        'success': success,
        if (userId != null) 'userId': userId,
        if (error != null) 'error': error,
      },
      severity: success ? SecuritySeverity.info : SecuritySeverity.warning,
    );
  }

  /// Log key rotation
  Future<void> logKeyRotation({
    required String oldKeyId,
    required String newKeyId,
    required int itemsRotated,
  }) async {
    await logEvent(
      SecurityEventType.keyRotation,
      'Key rotation completed',
      metadata: {
        'oldKeyId': oldKeyId,
        'newKeyId': newKeyId,
        'itemsRotated': itemsRotated,
      },
      severity: SecuritySeverity.info,
    );
  }

  /// Log security violation
  Future<void> logViolation({
    required String type,
    required String description,
    Map<String, dynamic>? details,
  }) async {
    await logEvent(
      SecurityEventType.securityViolation,
      description,
      metadata: {'violationType': type, ...?details},
      severity: SecuritySeverity.critical,
    );
  }

  /// Log access attempt
  Future<void> logAccess({
    required String resource,
    required bool granted,
    String? reason,
  }) async {
    await logEvent(
      SecurityEventType.accessControl,
      granted ? 'Access granted to $resource' : 'Access denied to $resource',
      metadata: {
        'resource': resource,
        'granted': granted,
        if (reason != null) 'reason': reason,
      },
      severity: granted ? SecuritySeverity.info : SecuritySeverity.warning,
    );
  }

  /// Get audit report for date range
  Future<AuditReport> getAuditReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final events = <SecurityEvent>[];
    final directory = await resolveAppDocumentsDirectory();
    final auditDir = Directory('${directory.path}/security_audit');

    if (!await auditDir.exists()) {
      return AuditReport(events: [], startDate: startDate, endDate: endDate);
    }

    // Read audit files within date range
    await for (final file in auditDir.list()) {
      if (file is File && file.path.endsWith('.log')) {
        final lines = await file.readAsLines();
        for (final line in lines) {
          try {
            final event = SecurityEvent.fromJson(
              jsonDecode(line) as Map<String, dynamic>,
            );
            if (event.timestamp.isAfter(startDate) &&
                event.timestamp.isBefore(endDate)) {
              events.add(event);
            }
          } catch (e) {
            _logger.warning('Failed to parse audit line: $line');
          }
        }
      }
    }

    return AuditReport(events: events, startDate: startDate, endDate: endDate);
  }

  /// Clear old audit logs
  Future<void> cleanupOldLogs({int daysToKeep = 90}) async {
    try {
      final directory = await resolveAppDocumentsDirectory();
      final auditDir = Directory('${directory.path}/security_audit');

      if (!await auditDir.exists()) return;

      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      await for (final file in auditDir.list()) {
        if (file is File && file.path.endsWith('.log')) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await file.delete();
            _logger.info('Deleted old audit file: ${file.path}');
          }
        }
      }
    } catch (e) {
      _logger.error('Failed to cleanup old audit logs', error: e);
    }
  }

  // Private methods

  Future<void> _writeToFile(SecurityEvent event) async {
    if (!_initialized || _auditFile == null) return;

    try {
      final json = jsonEncode(event.toJson());
      await _auditFile!.writeAsString('$json\n', mode: FileMode.append);
    } catch (e) {
      _logger.error('Failed to write audit event to file', error: e);
    }
  }

  String? _getCurrentUserId() {
    try {
      final client = Supabase.instance.client;
      return client.auth.currentUser?.id;
    } catch (e) {
      _logger.warning(
        '[SecurityAudit] Failed to get current user ID',
        data: {'error': e.toString()},
      );
      return null;
    }
  }

  String _getDeviceId() {
    // Generate a device ID based on platform
    if (kIsWeb) {
      return 'web_${DateTime.now().millisecondsSinceEpoch}';
    }
    return '${Platform.operatingSystem}_${Platform.localHostname}';
  }

  /// Dispose resources
  void dispose() {
    _eventController.close();
  }
}

/// Security event types
enum SecurityEventType {
  authentication,
  encryptionOperation,
  decryptionOperation,
  keyRotation,
  securityViolation,
  accessControl,
  auditStarted,
  configurationChange,
  performanceHardening,
}

/// Security severity levels
enum SecuritySeverity { info, warning, critical }

/// Security event
class SecurityEvent {
  final String id;
  final DateTime timestamp;
  final SecurityEventType type;
  final String description;
  final Map<String, dynamic>? metadata;
  final SecuritySeverity severity;
  final String? userId;
  final String deviceId;

  SecurityEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.description,
    this.metadata,
    required this.severity,
    this.userId,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'description': description,
    'metadata': metadata,
    'severity': severity.name,
    'userId': userId,
    'deviceId': deviceId,
  };

  factory SecurityEvent.fromJson(Map<String, dynamic> json) => SecurityEvent(
    id: json['id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    type: SecurityEventType.values.firstWhere(
      (e) => e.name == json['type'] as String,
    ),
    description: json['description'] as String,
    metadata: json['metadata'] as Map<String, dynamic>?,
    severity: SecuritySeverity.values.firstWhere(
      (e) => e.name == json['severity'] as String,
    ),
    userId: json['userId'] as String?,
    deviceId: json['deviceId'] as String,
  );
}

/// Audit report
class AuditReport {
  final List<SecurityEvent> events;
  final DateTime startDate;
  final DateTime endDate;

  AuditReport({
    required this.events,
    required this.startDate,
    required this.endDate,
  });

  /// Get summary statistics
  Map<String, dynamic> get summary => {
    'totalEvents': events.length,
    'byType': _groupByType(),
    'bySeverity': _groupBySeverity(),
    'criticalEvents': events
        .where((e) => e.severity == SecuritySeverity.critical)
        .length,
    'violations': events
        .where((e) => e.type == SecurityEventType.securityViolation)
        .length,
  };

  Map<String, int> _groupByType() {
    final map = <String, int>{};
    for (final event in events) {
      map[event.type.name] = (map[event.type.name] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> _groupBySeverity() {
    final map = <String, int>{};
    for (final event in events) {
      map[event.severity.name] = (map[event.severity.name] ?? 0) + 1;
    }
    return map;
  }
}
