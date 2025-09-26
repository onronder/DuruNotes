import 'dart:async';
import 'dart:collection';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/security/security_audit_trail.dart';
import 'package:duru_notes/core/security/secure_storage_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Production-grade security monitoring system
class SecurityMonitor {
  SecurityMonitor._();

  static final SecurityMonitor _instance = SecurityMonitor._();
  static SecurityMonitor get instance => _instance;

  late final AppLogger _logger;
  late final SecurityAuditTrail _auditTrail;
  late final SecureStorageManager _storageManager;

  // Threat detection thresholds
  static const int _maxFailedAuthAttempts = 5;
  static const int _maxDecryptionFailures = 10;
  static const int _anomalyWindowMinutes = 5;
  static const int _maxAnomalousEvents = 20;

  // Tracking maps
  final Map<String, int> _failedAuthAttempts = {};
  final Map<String, int> _decryptionFailures = {};
  final Map<String, int> _legacyKeyFallbacks = {}; // Track legacy key usage
  final Queue<DateTime> _recentEvents = Queue();
  final Map<String, DateTime> _lastActivityByUser = {};

  // Security state
  bool _lockdownMode = false;
  SecurityThreatLevel _currentThreatLevel = SecurityThreatLevel.low;

  // Stream controllers
  final StreamController<SecurityAlert> _alertController =
      StreamController<SecurityAlert>.broadcast();
  final StreamController<SecurityMetrics> _metricsController =
      StreamController<SecurityMetrics>.broadcast();

  Timer? _metricsTimer;
  Timer? _cleanupTimer;

  /// Stream of security alerts
  Stream<SecurityAlert> get alertStream => _alertController.stream;

  /// Stream of security metrics
  Stream<SecurityMetrics> get metricsStream => _metricsController.stream;

  /// Current threat level
  SecurityThreatLevel get threatLevel => _currentThreatLevel;

  /// Whether system is in lockdown mode
  bool get isInLockdown => _lockdownMode;

  /// Access to audit trail for logging security events
  SecurityAuditTrail get auditTrail => _auditTrail;

  /// Initialize the security monitor
  Future<void> initialize() async {
    _logger = LoggerFactory.instance;
    _auditTrail = SecurityAuditTrail();
    _storageManager = SecureStorageManager.instance;

    await _auditTrail.initialize();
    await _storageManager.initialize();

    // Start monitoring timers
    _startMetricsCollection();
    _startCleanupTimer();

    // Subscribe to audit events
    _auditTrail.eventStream.listen(_processSecurityEvent);

    _logger.info('Security monitor initialized');
  }

  /// Process security events from audit trail
  void _processSecurityEvent(SecurityEvent event) {
    // Track event frequency
    _recentEvents.add(event.timestamp);
    _cleanupRecentEvents();

    // Update user activity
    if (event.userId != null) {
      _lastActivityByUser[event.userId!] = event.timestamp;
    }

    // Process based on event type
    switch (event.type) {
      case SecurityEventType.authentication:
        _handleAuthenticationEvent(event);
        break;
      case SecurityEventType.decryptionOperation:
        _handleDecryptionEvent(event);
        break;
      case SecurityEventType.securityViolation:
        _handleSecurityViolation(event);
        break;
      case SecurityEventType.accessControl:
        _handleAccessControl(event);
        break;
      default:
        break;
    }

    // Check for anomalies
    _detectAnomalies();
  }

  /// Handle authentication events
  void _handleAuthenticationEvent(SecurityEvent event) {
    final success = event.metadata?['success'] as bool? ?? false;
    final userId = event.metadata?['userId'] as String? ?? 'unknown';

    if (!success) {
      _failedAuthAttempts[userId] = (_failedAuthAttempts[userId] ?? 0) + 1;

      if (_failedAuthAttempts[userId]! >= _maxFailedAuthAttempts) {
        _raiseAlert(
          SecurityAlert(
            level: AlertLevel.high,
            type: AlertType.bruteForce,
            message: 'Multiple failed authentication attempts detected',
            details: {
              'userId': userId,
              'attempts': _failedAuthAttempts[userId],
            },
            timestamp: DateTime.now(),
          ),
        );

        // Consider lockdown
        _evaluateLockdown();
      }
    } else {
      // Reset counter on successful auth
      _failedAuthAttempts[userId] = 0;
    }
  }

  /// Handle decryption events
  void _handleDecryptionEvent(SecurityEvent event) {
    final success = event.metadata?['success'] as bool? ?? false;
    final keyId = event.metadata?['keyId'] as String? ?? 'unknown';

    if (!success) {
      _decryptionFailures[keyId] = (_decryptionFailures[keyId] ?? 0) + 1;

      if (_decryptionFailures[keyId]! >= _maxDecryptionFailures) {
        _raiseAlert(
          SecurityAlert(
            level: AlertLevel.critical,
            type: AlertType.encryptionFailure,
            message: 'Multiple decryption failures detected',
            details: {
              'keyId': keyId,
              'failures': _decryptionFailures[keyId],
            },
            timestamp: DateTime.now(),
          ),
        );

        // This could indicate compromised keys
        _initiateEmergencyProtocol();
      }
    }
  }

  /// Handle security violations
  void _handleSecurityViolation(SecurityEvent event) {
    _raiseAlert(
      SecurityAlert(
        level: AlertLevel.critical,
        type: AlertType.violation,
        message: event.description,
        details: event.metadata,
        timestamp: event.timestamp,
      ),
    );

    // Immediate threat level escalation
    _escalateThreatLevel();
  }

  /// Handle access control events
  void _handleAccessControl(SecurityEvent event) {
    final granted = event.metadata?['granted'] as bool? ?? false;
    final resource = event.metadata?['resource'] as String? ?? 'unknown';

    if (!granted) {
      // Track unauthorized access attempts
      _logger.warning('Access denied to resource: $resource');
    }
  }

  /// Detect anomalous behavior patterns
  void _detectAnomalies() {
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(minutes: _anomalyWindowMinutes));

    // Count events in time window
    final recentEventCount = _recentEvents
        .where((timestamp) => timestamp.isAfter(windowStart))
        .length;

    if (recentEventCount > _maxAnomalousEvents) {
      _raiseAlert(
        SecurityAlert(
          level: AlertLevel.medium,
          type: AlertType.anomaly,
          message: 'Unusual activity pattern detected',
          details: {
            'eventCount': recentEventCount,
            'timeWindow': '$_anomalyWindowMinutes minutes',
          },
          timestamp: now,
        ),
      );
    }
  }

  /// Raise a security alert
  void _raiseAlert(SecurityAlert alert) {
    _alertController.add(alert);

    // Log alert to audit trail
    _auditTrail.logEvent(
      SecurityEventType.securityViolation,
      alert.message,
      metadata: alert.toJson(),
      severity: _mapAlertLevelToSeverity(alert.level),
    );

    // Send to remote monitoring if critical
    if (alert.level == AlertLevel.critical) {
      _sendToRemoteMonitoring(alert);
    }
  }

  /// Send critical alerts to remote monitoring
  Future<void> _sendToRemoteMonitoring(SecurityAlert alert) async {
    try {
      final supabase = Supabase.instance.client;
      if (supabase.auth.currentUser != null) {
        await supabase.from('security_alerts').insert({
          'user_id': supabase.auth.currentUser!.id,
          'alert_level': alert.level.name,
          'alert_type': alert.type.name,
          'message': alert.message,
          'details': alert.details,
          'timestamp': alert.timestamp.toIso8601String(),
        });
      }
    } catch (e) {
      _logger.error('Failed to send alert to remote monitoring', error: e);
    }
  }

  /// Evaluate whether to enter lockdown mode
  void _evaluateLockdown() {
    final totalFailures = _failedAuthAttempts.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );

    if (totalFailures >= _maxFailedAuthAttempts * 3) {
      _enterLockdown();
    }
  }

  /// Enter security lockdown mode
  void _enterLockdown() {
    if (_lockdownMode) return;

    _lockdownMode = true;
    _currentThreatLevel = SecurityThreatLevel.critical;

    _raiseAlert(
      SecurityAlert(
        level: AlertLevel.critical,
        type: AlertType.lockdown,
        message: 'Security lockdown initiated',
        details: {
          'reason': 'Multiple security violations detected',
          'timestamp': DateTime.now().toIso8601String(),
        },
        timestamp: DateTime.now(),
      ),
    );

    // Clear sensitive data from memory
    _clearSensitiveData();

    _logger.error('SECURITY LOCKDOWN ACTIVATED');
  }

  /// Exit lockdown mode
  Future<void> exitLockdown() async {
    if (!_lockdownMode) return;

    _lockdownMode = false;
    _currentThreatLevel = SecurityThreatLevel.low;

    // Reset counters
    _failedAuthAttempts.clear();
    _decryptionFailures.clear();

    _logger.info('Security lockdown deactivated');
  }

  /// Initiate emergency security protocol
  void _initiateEmergencyProtocol() {
    _logger.error('EMERGENCY SECURITY PROTOCOL INITIATED');

    // Rotate all keys immediately
    _storageManager.rotateKeys();

    // Force re-authentication
    _forceReauthentication();

    // Enter lockdown
    _enterLockdown();
  }

  /// Force all users to re-authenticate
  void _forceReauthentication() {
    try {
      final supabase = Supabase.instance.client;
      supabase.auth.signOut();
    } catch (e) {
      _logger.error('Failed to force re-authentication', error: e);
    }
  }

  /// Clear sensitive data from memory
  void _clearSensitiveData() {
    // This would clear any cached encryption keys, tokens, etc.
    _lastActivityByUser.clear();
  }

  /// Log legacy key fallback usage
  void logLegacyKeyUsage(String noteId) {
    _legacyKeyFallbacks[noteId] = (_legacyKeyFallbacks[noteId] ?? 0) + 1;

    // Alert if too many legacy key uses
    if (_legacyKeyFallbacks[noteId]! > 3) {
      _raiseAlert(
        SecurityAlert(
          level: AlertLevel.low,
          type: AlertType.encryptionFailure,
          message: 'Frequent legacy key usage detected',
          details: {
            'noteId': noteId,
            'count': _legacyKeyFallbacks[noteId],
          },
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Escalate threat level
  void _escalateThreatLevel() {
    switch (_currentThreatLevel) {
      case SecurityThreatLevel.low:
        _currentThreatLevel = SecurityThreatLevel.medium;
        break;
      case SecurityThreatLevel.medium:
        _currentThreatLevel = SecurityThreatLevel.high;
        break;
      case SecurityThreatLevel.high:
        _currentThreatLevel = SecurityThreatLevel.critical;
        _evaluateLockdown();
        break;
      case SecurityThreatLevel.critical:
        // Already at maximum
        break;
    }
  }

  /// Collect and emit security metrics
  void _collectMetrics() {
    final metrics = SecurityMetrics(
      totalEvents: _recentEvents.length,
      failedAuthAttempts: _failedAuthAttempts.values.fold(0, (a, b) => a + b),
      decryptionFailures: _decryptionFailures.values.fold(0, (a, b) => a + b),
      legacyKeyFallbacks: _legacyKeyFallbacks.values.fold(0, (a, b) => a + b),
      activeUsers: _lastActivityByUser.length,
      threatLevel: _currentThreatLevel,
      isInLockdown: _lockdownMode,
      timestamp: DateTime.now(),
    );

    _metricsController.add(metrics);
  }

  /// Start metrics collection timer
  void _startMetricsCollection() {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _collectMetrics(),
    );
  }

  /// Start cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _performCleanup(),
    );
  }

  /// Clean up old events
  void _cleanupRecentEvents() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    while (_recentEvents.isNotEmpty && _recentEvents.first.isBefore(cutoff)) {
      _recentEvents.removeFirst();
    }
  }

  /// Perform periodic cleanup
  void _performCleanup() {
    // Clean up old failed attempts
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    _lastActivityByUser.removeWhere(
      (_, timestamp) => timestamp.isBefore(cutoff),
    );

    // Reduce threat level if no recent incidents
    if (_recentEvents.isEmpty && _currentThreatLevel != SecurityThreatLevel.low) {
      _currentThreatLevel = SecurityThreatLevel.low;
    }
  }

  /// Map alert level to severity
  SecuritySeverity _mapAlertLevelToSeverity(AlertLevel level) {
    switch (level) {
      case AlertLevel.low:
        return SecuritySeverity.info;
      case AlertLevel.medium:
        return SecuritySeverity.warning;
      case AlertLevel.high:
      case AlertLevel.critical:
        return SecuritySeverity.critical;
    }
  }

  /// Dispose of resources
  void dispose() {
    _metricsTimer?.cancel();
    _cleanupTimer?.cancel();
    _alertController.close();
    _metricsController.close();
  }
}

/// Security threat levels
enum SecurityThreatLevel {
  low,
  medium,
  high,
  critical,
}

/// Alert levels
enum AlertLevel {
  low,
  medium,
  high,
  critical,
}

/// Alert types
enum AlertType {
  bruteForce,
  encryptionFailure,
  violation,
  anomaly,
  lockdown,
}

/// Security alert
class SecurityAlert {
  SecurityAlert({
    required this.level,
    required this.type,
    required this.message,
    this.details,
    required this.timestamp,
  });

  final AlertLevel level;
  final AlertType type;
  final String message;
  final Map<String, dynamic>? details;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'type': type.name,
        'message': message,
        'details': details,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Security metrics
class SecurityMetrics {
  SecurityMetrics({
    required this.totalEvents,
    required this.failedAuthAttempts,
    required this.decryptionFailures,
    this.legacyKeyFallbacks = 0,
    required this.activeUsers,
    required this.threatLevel,
    required this.isInLockdown,
    required this.timestamp,
  });

  final int totalEvents;
  final int failedAuthAttempts;
  final int decryptionFailures;
  final int legacyKeyFallbacks;
  final int activeUsers;
  final SecurityThreatLevel threatLevel;
  final bool isInLockdown;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'totalEvents': totalEvents,
        'failedAuthAttempts': failedAuthAttempts,
        'decryptionFailures': decryptionFailures,
        'legacyKeyFallbacks': legacyKeyFallbacks,
        'activeUsers': activeUsers,
        'threatLevel': threatLevel.name,
        'isInLockdown': isInLockdown,
        'timestamp': timestamp.toIso8601String(),
      };
}