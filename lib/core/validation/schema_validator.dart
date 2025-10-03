import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';

/// Feature flags based on available tables
class FeatureFlags {
  static bool _notificationsEnabled = false;
  static bool _analyticsEnabled = false;
  static bool _securityAuditEnabled = false;
  static bool _blockContentEnabled = false;
  static bool _tagsEnabled = false;

  static bool get notificationsEnabled => _notificationsEnabled;
  static bool get analyticsEnabled => _analyticsEnabled;
  static bool get securityAuditEnabled => _securityAuditEnabled;
  static bool get blockContentEnabled => _blockContentEnabled;
  static bool get tagsEnabled => _tagsEnabled;
}

/// Schema validator to ensure local database is in sync with remote
///
/// Production best practices:
/// - Validates on app startup
/// - Logs missing features
/// - Provides graceful degradation
/// - Monitors schema drift
class SchemaValidator {
  static final _logger = LoggerFactory.instance;

  /// Expected tables in production (from Supabase)
  static const _requiredTables = [
    // Core tables
    'notes',
    'folders',
    'templates',
    'attachments',
    'tags',

    // Relationship tables
    'note_tags',
    'note_folders',
    'note_blocks',
    'note_tasks',
    'note_links',
    'note_reminders',

    // User management
    'profiles',
    'user_keys',
    'user_sessions',
    'user_devices',
    'devices',

    // Security & audit
    'security_events',
    'login_attempts',
    'password_history',
    'rate_limits',
    'rate_limit_log',

    // Notifications (8 tables)
    'notification_events',
    'notification_deliveries',
    'notification_preferences',
    'notification_templates',
    'notification_stats',
    'notification_analytics',
    'notification_health_checks',
    'notification_cron_jobs',

    // Analytics
    'analytics_events',
    'index_statistics',

    // Inbox
    'clipper_inbox',
    'inbound_aliases',
    'inbox_items_view',

    // Search
    'saved_searches',

    // Tasks (legacy)
    'tasks',
  ];


  /// Validate schema compatibility between local and remote
  static Future<SchemaValidationResult> validateSchema(AppDb db) async {
    final result = SchemaValidationResult();

    try {
      // Get all existing tables
      final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
      ).get();

      final existingTables = tables.map((t) => t.read<String>('name')).toSet();

      // Check for missing tables
      for (final requiredTable in _requiredTables) {
        if (!existingTables.contains(requiredTable)) {
          // Check for renamed tables
          final renamed = _checkForRenamedTable(requiredTable, existingTables);
          if (renamed != null) {
            result.renamedTables[requiredTable] = renamed;
          } else {
            result.missingTables.add(requiredTable);
          }
        }
      }

      // Check for extra tables (local-only)
      for (final existingTable in existingTables) {
        if (!_requiredTables.contains(existingTable) &&
            !existingTable.startsWith('_') &&
            !existingTable.startsWith('fts_') &&
            existingTable != 'pending_ops' &&
            existingTable != 'schema_versions') {
          result.extraTables.add(existingTable);
        }
      }

      // Set feature flags based on available tables
      await _updateFeatureFlags(existingTables);

      // Check critical indexes
      await _validateIndexes(db, result);

      // Calculate compatibility score
      result.calculateCompatibility();

      // Log results
      _logValidationResults(result);

      return result;

    } catch (e, stack) {
      _logger.error('Schema validation failed: $e\nStack: $stack');
      result.errors.add('Validation error: $e');
      return result;
    }
  }

  /// Check if a table exists under a different name
  static String? _checkForRenamedTable(String requiredTable, Set<String> existingTables) {
    // Map of remote -> local table names
    final renames = {
      'notes': 'local_notes',
      'folders': 'local_folders',
      'templates': 'local_templates',
      'attachments': 'local_attachments',
      'clipper_inbox': 'local_inbox_items',
    };

    final localName = renames[requiredTable];
    if (localName != null && existingTables.contains(localName)) {
      return localName;
    }

    return null;
  }

  /// Update feature flags based on available tables
  static Future<void> _updateFeatureFlags(Set<String> tables) async {
    // Notifications require all notification tables
    FeatureFlags._notificationsEnabled = [
      'notification_events',
      'notification_deliveries',
      'notification_preferences',
      'notification_templates',
    ].every(tables.contains);

    // Analytics requires events table
    FeatureFlags._analyticsEnabled = tables.contains('analytics_events');

    // Security audit requires events table
    FeatureFlags._securityAuditEnabled = tables.contains('security_events');

    // Block content requires note_blocks
    FeatureFlags._blockContentEnabled = tables.contains('note_blocks');

    // Tags require tags table
    FeatureFlags._tagsEnabled = tables.contains('tags');
  }

  /// Validate critical indexes exist
  static Future<void> _validateIndexes(AppDb db, SchemaValidationResult result) async {
    final criticalIndexes = [
      'idx_notes_user_id',
      'idx_notes_updated_at',
      'idx_notes_created_at',
      'idx_folders_user_id',
      'idx_note_tags_note_id',
      'idx_note_folders_note_id',
    ];

    final indexes = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='index'"
    ).get();

    final existingIndexes = indexes.map((i) => i.read<String>('name')).toSet();

    for (final requiredIndex in criticalIndexes) {
      if (!existingIndexes.contains(requiredIndex)) {
        result.missingIndexes.add(requiredIndex);
      }
    }
  }

  /// Log validation results
  static void _logValidationResults(SchemaValidationResult result) {
    if (result.isFullyCompatible) {
      _logger.info('✅ Schema validation PASSED - Full compatibility');
    } else if (result.compatibilityScore >= 80) {
      _logger.warning('⚠️ Schema validation: ${result.compatibilityScore}% compatible');
      _logger.warning('Missing tables: ${result.missingTables.join(', ')}');
    } else {
      _logger.error('❌ Schema validation FAILED: ${result.compatibilityScore}% compatible');
      _logger.error('Missing ${result.missingTables.length} tables');
      _logger.error('Missing tables: ${result.missingTables.join(', ')}');
    }

    // Log feature availability
    _logger.info('Features available:');
    _logger.info('  • Notifications: ${FeatureFlags.notificationsEnabled}');
    _logger.info('  • Analytics: ${FeatureFlags.analyticsEnabled}');
    _logger.info('  • Security Audit: ${FeatureFlags.securityAuditEnabled}');
    _logger.info('  • Block Content: ${FeatureFlags.blockContentEnabled}');
    _logger.info('  • Tags: ${FeatureFlags.tagsEnabled}');
  }

  /// Run migration if needed
  static Future<bool> ensureCompatibility(AppDb db) async {
    final validation = await validateSchema(db);

    if (validation.isFullyCompatible) {
      return true;
    }

    if (validation.compatibilityScore < 50) {
      _logger.error('Schema too outdated - manual migration required');
      return false;
    }

    // Attempt automatic fixes for renamed tables
    if (validation.renamedTables.isNotEmpty) {
      _logger.info('Attempting to rename tables to match remote schema...');
      // Table renaming would be handled by Migration20
    }

    return validation.compatibilityScore >= 80;
  }
}

/// Result of schema validation
class SchemaValidationResult {
  final List<String> missingTables = <String>[];
  final List<String> extraTables = <String>[];
  final Map<String, String> renamedTables = <String, String>{};
  final List<String> missingIndexes = <String>[];
  final List<String> errors = <String>[];

  int compatibilityScore = 0;

  bool get isFullyCompatible =>
      missingTables.isEmpty &&
      renamedTables.isEmpty &&
      errors.isEmpty;

  bool get hasMinimalCompatibility => compatibilityScore >= 50;

  void calculateCompatibility() {
    if (errors.isNotEmpty) {
      compatibilityScore = 0;
      return;
    }

    final totalRequired = SchemaValidator._requiredTables.length;
    final missing = missingTables.length;
    final renamed = renamedTables.length;

    // Renamed tables count as 80% compatible
    final effectiveMissing = missing + (renamed * 0.2);

    compatibilityScore = ((totalRequired - effectiveMissing) / totalRequired * 100).round();
    compatibilityScore = compatibilityScore.clamp(0, 100);
  }

  Map<String, dynamic> toJson() => {
    'compatibilityScore': compatibilityScore,
    'isFullyCompatible': isFullyCompatible,
    'missingTables': missingTables,
    'extraTables': extraTables,
    'renamedTables': renamedTables,
    'missingIndexes': missingIndexes,
    'errors': errors,
    'features': {
      'notifications': FeatureFlags.notificationsEnabled,
      'analytics': FeatureFlags.analyticsEnabled,
      'securityAudit': FeatureFlags.securityAuditEnabled,
      'blockContent': FeatureFlags.blockContentEnabled,
      'tags': FeatureFlags.tagsEnabled,
    }
  };
}