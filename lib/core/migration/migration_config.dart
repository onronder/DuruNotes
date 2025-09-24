/// Production-grade migration configuration system for gradual domain model migration
/// Provides feature flags and configuration for safe, incremental migration
class MigrationConfig {
  final bool useDomainModels;
  final Map<String, bool> enabledFeatures;
  final int version;
  final DateTime configurationDate;

  MigrationConfig({
    required this.useDomainModels,
    required this.enabledFeatures,
    this.version = 1,
    DateTime? configurationDate,
  }) : configurationDate = configurationDate ?? DateTime.now();

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
    final enabledCount = enabledFeatures.values.where((enabled) => enabled).length;
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

    return requiredFeatures.every((feature) => enabledFeatures.containsKey(feature));
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
      useDomainModels.hashCode ^
      enabledFeatures.hashCode ^
      version.hashCode;

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
    };
  }

  /// Creates from JSON
  factory MigrationConfig.fromJson(Map<String, dynamic> json) {
    return MigrationConfig(
      useDomainModels: json['useDomainModels'] as bool? ?? false,
      enabledFeatures: Map<String, bool>.from(json['enabledFeatures'] as Map? ?? {}),
      version: json['version'] as int? ?? 1,
      configurationDate: DateTime.tryParse(json['configurationDate'] as String? ?? '') ??
          DateTime.now(),
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
        'notes': false,  // Still disabled for safety
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
        'notes': false,  // UI still uses legacy
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