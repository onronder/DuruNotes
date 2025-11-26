/// Operational configuration for reminder services
/// Holds all configurable values for reminder encryption, sync, and geofencing
class ReminderServiceConfig {
  // Encryption retry queue configuration
  final int maxRetries;
  final int maxQueueSize;
  final Duration queueMaxAge;

  // Encryption lock configuration
  final Duration lockTimeout;

  // Sync configuration
  final int syncBatchSize;

  // Geofence configuration
  final int geofenceIntervalMs;
  final int geofenceAccuracyMeters;
  final int geofenceLoiteringDelayMs;
  final int geofenceStatusChangeDelayMs;
  final bool geofenceUseActivityRecognition;
  final bool geofenceAllowMockLocations;
  final double geofenceDefaultRadiusMeters;

  const ReminderServiceConfig({
    this.maxRetries = 10,
    this.maxQueueSize = 1000,
    this.queueMaxAge = const Duration(hours: 1),
    this.lockTimeout = const Duration(seconds: 30),
    this.syncBatchSize = 10,
    this.geofenceIntervalMs = 5000,
    this.geofenceAccuracyMeters = 100,
    this.geofenceLoiteringDelayMs = 60000,
    this.geofenceStatusChangeDelayMs = 10000,
    this.geofenceUseActivityRecognition = true,
    this.geofenceAllowMockLocations = false,
    this.geofenceDefaultRadiusMeters = 100.0,
  });

  /// Creates default reminder configuration with production-safe defaults
  factory ReminderServiceConfig.defaultConfig() {
    return const ReminderServiceConfig();
  }

  /// Creates development configuration with more relaxed limits
  factory ReminderServiceConfig.developmentConfig() {
    return const ReminderServiceConfig(
      maxRetries: 20, // Allow more retries in development
      maxQueueSize: 5000, // Larger queue for testing
      queueMaxAge: Duration(hours: 24), // Keep entries longer
      lockTimeout: Duration(minutes: 1), // Longer timeout for debugging
      syncBatchSize: 50, // Larger batches for faster syncing
      geofenceIntervalMs: 10000, // Less frequent updates to save battery
      geofenceAccuracyMeters: 200, // Lower accuracy for testing
      geofenceLoiteringDelayMs: 30000, // Shorter delay for testing
      geofenceStatusChangeDelayMs: 5000, // Shorter delay for testing
      geofenceAllowMockLocations: true, // Allow mock locations for testing
      geofenceDefaultRadiusMeters: 50.0, // Smaller radius for easier testing
    );
  }

  /// Creates conservative configuration for production rollout
  factory ReminderServiceConfig.productionRollout() {
    return const ReminderServiceConfig(
      maxRetries: 5, // Conservative retry limit
      maxQueueSize: 500, // Smaller queue
      queueMaxAge: Duration(minutes: 30), // Shorter retention
      lockTimeout: Duration(seconds: 15), // Faster timeout
      syncBatchSize: 5, // Smaller batches
      geofenceIntervalMs: 7000, // Slightly less aggressive for battery life
      geofenceAccuracyMeters: 150, // Moderate accuracy
      geofenceLoiteringDelayMs: 90000, // Longer delay to prevent false triggers
      geofenceStatusChangeDelayMs: 15000, // Longer delay for stability
      geofenceDefaultRadiusMeters: 150.0, // Larger radius for reliability
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderServiceConfig &&
          runtimeType == other.runtimeType &&
          maxRetries == other.maxRetries &&
          maxQueueSize == other.maxQueueSize &&
          queueMaxAge == other.queueMaxAge &&
          lockTimeout == other.lockTimeout &&
          syncBatchSize == other.syncBatchSize &&
          geofenceIntervalMs == other.geofenceIntervalMs &&
          geofenceAccuracyMeters == other.geofenceAccuracyMeters &&
          geofenceLoiteringDelayMs == other.geofenceLoiteringDelayMs &&
          geofenceStatusChangeDelayMs == other.geofenceStatusChangeDelayMs &&
          geofenceUseActivityRecognition ==
              other.geofenceUseActivityRecognition &&
          geofenceAllowMockLocations == other.geofenceAllowMockLocations &&
          geofenceDefaultRadiusMeters == other.geofenceDefaultRadiusMeters;

  @override
  int get hashCode =>
      maxRetries.hashCode ^
      maxQueueSize.hashCode ^
      queueMaxAge.hashCode ^
      lockTimeout.hashCode ^
      syncBatchSize.hashCode ^
      geofenceIntervalMs.hashCode ^
      geofenceAccuracyMeters.hashCode ^
      geofenceLoiteringDelayMs.hashCode ^
      geofenceStatusChangeDelayMs.hashCode ^
      geofenceUseActivityRecognition.hashCode ^
      geofenceAllowMockLocations.hashCode ^
      geofenceDefaultRadiusMeters.hashCode;

  @override
  String toString() {
    return 'ReminderServiceConfig('
        'maxRetries: $maxRetries, '
        'maxQueueSize: $maxQueueSize, '
        'queueMaxAge: $queueMaxAge, '
        'lockTimeout: $lockTimeout, '
        'syncBatchSize: $syncBatchSize, '
        'geofenceIntervalMs: $geofenceIntervalMs, '
        'geofenceAccuracyMeters: $geofenceAccuracyMeters, '
        'geofenceLoiteringDelayMs: $geofenceLoiteringDelayMs, '
        'geofenceStatusChangeDelayMs: $geofenceStatusChangeDelayMs, '
        'geofenceUseActivityRecognition: $geofenceUseActivityRecognition, '
        'geofenceAllowMockLocations: $geofenceAllowMockLocations, '
        'geofenceDefaultRadiusMeters: $geofenceDefaultRadiusMeters'
        ')';
  }

  Map<String, dynamic> toJson() {
    return {
      'maxRetries': maxRetries,
      'maxQueueSize': maxQueueSize,
      'queueMaxAge': queueMaxAge.inMilliseconds,
      'lockTimeout': lockTimeout.inMilliseconds,
      'syncBatchSize': syncBatchSize,
      'geofenceIntervalMs': geofenceIntervalMs,
      'geofenceAccuracyMeters': geofenceAccuracyMeters,
      'geofenceLoiteringDelayMs': geofenceLoiteringDelayMs,
      'geofenceStatusChangeDelayMs': geofenceStatusChangeDelayMs,
      'geofenceUseActivityRecognition': geofenceUseActivityRecognition,
      'geofenceAllowMockLocations': geofenceAllowMockLocations,
      'geofenceDefaultRadiusMeters': geofenceDefaultRadiusMeters,
    };
  }

  factory ReminderServiceConfig.fromJson(Map<String, dynamic> json) {
    return ReminderServiceConfig(
      maxRetries: json['maxRetries'] as int? ?? 10,
      maxQueueSize: json['maxQueueSize'] as int? ?? 1000,
      queueMaxAge: Duration(
        milliseconds: json['queueMaxAge'] as int? ?? 3600000,
      ),
      lockTimeout: Duration(milliseconds: json['lockTimeout'] as int? ?? 30000),
      syncBatchSize: json['syncBatchSize'] as int? ?? 10,
      geofenceIntervalMs: json['geofenceIntervalMs'] as int? ?? 5000,
      geofenceAccuracyMeters: json['geofenceAccuracyMeters'] as int? ?? 100,
      geofenceLoiteringDelayMs:
          json['geofenceLoiteringDelayMs'] as int? ?? 60000,
      geofenceStatusChangeDelayMs:
          json['geofenceStatusChangeDelayMs'] as int? ?? 10000,
      geofenceUseActivityRecognition:
          json['geofenceUseActivityRecognition'] as bool? ?? true,
      geofenceAllowMockLocations:
          json['geofenceAllowMockLocations'] as bool? ?? false,
      geofenceDefaultRadiusMeters:
          (json['geofenceDefaultRadiusMeters'] as num?)?.toDouble() ?? 100.0,
    );
  }
}

/// Production-grade migration configuration system for gradual domain model migration
/// Provides feature flags and configuration for safe, incremental migration
class MigrationConfig {
  final bool useDomainModels;
  final Map<String, bool> enabledFeatures;
  final int version;
  final DateTime configurationDate;
  final ReminderServiceConfig reminderConfig;

  MigrationConfig({
    required this.useDomainModels,
    required this.enabledFeatures,
    this.version = 1,
    DateTime? configurationDate,
    ReminderServiceConfig? reminderConfig,
  }) : configurationDate = configurationDate ?? DateTime.now(),
       reminderConfig = reminderConfig ?? ReminderServiceConfig.defaultConfig();

  /// Creates a default configuration with all features disabled
  factory MigrationConfig.defaultConfig() {
    return MigrationConfig(
      useDomainModels: false,
      enabledFeatures: {
        'notes': false,
        'folders': false,
        'templates': false,
        'tasks': false,
        'tags': false,
        'search': false,
        'attachments': false,
        'sync': false,
      },
      configurationDate: DateTime.now(),
    );
  }

  /// Creates a configuration for production rollout with specific percentages
  factory MigrationConfig.productionRollout({
    required Map<String, bool> features,
    bool enableDomainModels = false,
  }) {
    return MigrationConfig(
      useDomainModels: enableDomainModels,
      enabledFeatures: features,
      version: 1,
      configurationDate: DateTime.now(),
    );
  }

  /// Creates a development configuration with all features enabled
  factory MigrationConfig.developmentConfig() {
    return MigrationConfig(
      useDomainModels: true,
      enabledFeatures: {
        'notes': true,
        'folders': true,
        'templates': true,
        'tasks': true,
        'tags': true,
        'search': true,
        'attachments': true,
        'sync': true,
      },
      configurationDate: DateTime.now(),
      reminderConfig: ReminderServiceConfig.developmentConfig(),
    );
  }

  /// Checks if a specific feature is enabled for domain model usage
  bool isFeatureEnabled(String feature) {
    return enabledFeatures[feature] ?? false;
  }

  /// Creates a new config with a feature enabled
  MigrationConfig enableFeature(String feature) {
    return MigrationConfig(
      useDomainModels: useDomainModels,
      enabledFeatures: {...enabledFeatures, feature: true},
      version: version,
      configurationDate: configurationDate,
    );
  }

  /// Creates a new config with a feature disabled
  MigrationConfig disableFeature(String feature) {
    return MigrationConfig(
      useDomainModels: useDomainModels,
      enabledFeatures: {...enabledFeatures, feature: false},
      version: version,
      configurationDate: configurationDate,
    );
  }

  /// Creates a new config with multiple features enabled/disabled
  MigrationConfig updateFeatures(Map<String, bool> featureUpdates) {
    return MigrationConfig(
      useDomainModels: useDomainModels,
      enabledFeatures: {...enabledFeatures, ...featureUpdates},
      version: version + 1,
      configurationDate: DateTime.now(),
    );
  }

  /// Gets the percentage of features that are enabled
  double get migrationProgress {
    if (enabledFeatures.isEmpty) return 0.0;
    final enabledCount = enabledFeatures.values
        .where((enabled) => enabled)
        .length;
    return enabledCount / enabledFeatures.length;
  }

  /// Gets a list of enabled features
  List<String> get enabledFeaturesList {
    return enabledFeatures.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// Gets a list of disabled features
  List<String> get disabledFeaturesList {
    return enabledFeatures.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// Validates that all required features are defined
  bool get isValid {
    const requiredFeatures = [
      'notes',
      'folders',
      'templates',
      'tasks',
      'tags',
      'search',
    ];

    return requiredFeatures.every(
      (feature) => enabledFeatures.containsKey(feature),
    );
  }

  /// Checks if the configuration is ready for full migration
  bool get isReadyForFullMigration {
    return isValid && migrationProgress == 1.0 && useDomainModels;
  }

  /// Checks if this is a rollback configuration (all features disabled)
  bool get isRollbackConfig {
    return !useDomainModels && migrationProgress == 0.0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MigrationConfig &&
          runtimeType == other.runtimeType &&
          useDomainModels == other.useDomainModels &&
          _mapEquals(enabledFeatures, other.enabledFeatures) &&
          version == other.version;

  @override
  int get hashCode =>
      useDomainModels.hashCode ^ enabledFeatures.hashCode ^ version.hashCode;

  /// Helper method for map equality comparison
  bool _mapEquals(Map<String, bool> map1, Map<String, bool> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (map1[key] != map2[key]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'MigrationConfig('
        'useDomainModels: $useDomainModels, '
        'progress: ${(migrationProgress * 100).toStringAsFixed(1)}%, '
        'enabled: ${enabledFeaturesList.join(', ')}, '
        'version: $version'
        ')';
  }

  /// Converts to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'useDomainModels': useDomainModels,
      'enabledFeatures': enabledFeatures,
      'version': version,
      'configurationDate': configurationDate.toIso8601String(),
      'reminderConfig': reminderConfig.toJson(),
    };
  }

  /// Creates from JSON
  factory MigrationConfig.fromJson(Map<String, dynamic> json) {
    return MigrationConfig(
      useDomainModels: json['useDomainModels'] as bool? ?? false,
      enabledFeatures: Map<String, bool>.from(
        json['enabledFeatures'] as Map? ?? {},
      ),
      version: json['version'] as int? ?? 1,
      configurationDate:
          DateTime.tryParse(json['configurationDate'] as String? ?? '') ??
          DateTime.now(),
      reminderConfig: json['reminderConfig'] != null
          ? ReminderServiceConfig.fromJson(
              json['reminderConfig'] as Map<String, dynamic>,
            )
          : ReminderServiceConfig.defaultConfig(),
    );
  }
}

/// Exception thrown when migration configuration is invalid
class MigrationConfigException implements Exception {
  final String message;
  final MigrationConfig? config;

  const MigrationConfigException(this.message, [this.config]);

  @override
  String toString() {
    return 'MigrationConfigException: $message${config != null ? ' (config: $config)' : ''}';
  }
}

/// Factory for creating common migration configurations
class MigrationConfigFactory {
  /// Phase 1: Emergency stabilization - everything disabled
  static MigrationConfig phase1Stabilization() {
    return MigrationConfig.defaultConfig();
  }

  /// Phase 2: Infrastructure foundation - core entities enabled
  static MigrationConfig phase2Infrastructure() {
    return MigrationConfig.productionRollout(
      features: {
        'notes': false, // Still disabled for safety
        'folders': false,
        'templates': false,
        'tasks': false,
        'tags': false,
        'search': false,
        'attachments': false,
        'sync': false,
      },
    );
  }

  /// Phase 3: Repository layer - repositories enabled but not UI
  static MigrationConfig phase3Repository() {
    return MigrationConfig.productionRollout(
      features: {
        'notes': false, // UI still uses legacy
        'folders': false,
        'templates': false,
        'tasks': false,
        'tags': false,
        'search': false,
        'attachments': false,
        'sync': false,
      },
    );
  }

  /// Phase 4: Provider migration - gradual feature enablement
  static MigrationConfig phase4Provider({
    bool enableNotes = false,
    bool enableFolders = false,
    bool enableTemplates = false,
  }) {
    return MigrationConfig.productionRollout(
      features: {
        'notes': enableNotes,
        'folders': enableFolders,
        'templates': enableTemplates,
        'tasks': false,
        'tags': false,
        'search': false,
        'attachments': false,
        'sync': false,
      },
    );
  }

  /// Production rollout configurations
  static MigrationConfig productionPhase1({required int rolloutPercentage}) {
    final enabled = rolloutPercentage > 0;
    return MigrationConfig.productionRollout(
      features: {
        'notes': enabled,
        'folders': false,
        'templates': false,
        'tasks': false,
        'tags': false,
        'search': false,
        'attachments': false,
        'sync': false,
      },
    );
  }

  static MigrationConfig productionPhase2({required int rolloutPercentage}) {
    final enabled = rolloutPercentage > 0;
    return MigrationConfig.productionRollout(
      features: {
        'notes': enabled,
        'folders': enabled,
        'templates': false,
        'tasks': false,
        'tags': enabled,
        'search': false,
        'attachments': false,
        'sync': false,
      },
    );
  }

  static MigrationConfig fullProduction() {
    return MigrationConfig.developmentConfig();
  }

  /// Emergency rollback configuration
  static MigrationConfig emergencyRollback() {
    return MigrationConfig(
      useDomainModels: false,
      enabledFeatures: {
        'notes': false,
        'folders': false,
        'templates': false,
        'tasks': false,
        'tags': false,
        'search': false,
        'attachments': false,
        'sync': false,
      },
      version: 0,
      configurationDate: DateTime.now(),
    );
  }
}
