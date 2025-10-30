import 'package:duru_notes/services/analytics/folder_analytics.dart';

/// A/B Testing configuration for folder features
class FolderABTests {
  /// Active A/B test configurations
  static final List<ABTestConfig> activeTests = [
    ABTestConfig(
      id: 'folder_onboarding_v2',
      name: 'Enhanced Folder Onboarding',
      description: 'Test new onboarding flow with guided folder creation',
      hypothesis:
          'Guided onboarding will increase first folder creation by 25%',
      variants: [
        TestVariant(
          id: 'control',
          name: 'Current Onboarding',
          allocation: 0.5,
          config: {'show_onboarding': false, 'auto_create_folders': false},
        ),
        TestVariant(
          id: 'guided',
          name: 'Guided Onboarding',
          allocation: 0.25,
          config: {
            'show_onboarding': true,
            'onboarding_steps': ['intro', 'create_first', 'organize', 'search'],
            'auto_create_folders': false,
          },
        ),
        TestVariant(
          id: 'auto_setup',
          name: 'Auto Setup with Templates',
          allocation: 0.25,
          config: {
            'show_onboarding': true,
            'auto_create_folders': true,
            'default_folders': ['Personal', 'Work', 'Archive'],
          },
        ),
      ],
      primaryMetric: 'first_folder_creation_rate',
      secondaryMetrics: [
        'time_to_first_folder',
        '7_day_retention',
        'folders_created_week_1',
      ],
      segmentation: ['user_source', 'platform', 'country'],
      minimumSampleSize: 1000,
      maxDuration: Duration(days: 30),
    ),

    ABTestConfig(
      id: 'folder_tree_navigation',
      name: 'Folder Tree UI Variations',
      description: 'Test different folder navigation UI patterns',
      hypothesis: 'Collapsible tree view will increase folder usage by 20%',
      variants: [
        TestVariant(
          id: 'list_view',
          name: 'Simple List',
          allocation: 0.33,
          config: {
            'navigation_type': 'list',
            'show_icons': true,
            'indent_levels': false,
          },
        ),
        TestVariant(
          id: 'tree_view',
          name: 'Collapsible Tree',
          allocation: 0.33,
          config: {
            'navigation_type': 'tree',
            'auto_expand': false,
            'show_counts': true,
          },
        ),
        TestVariant(
          id: 'hybrid_view',
          name: 'Hybrid Navigation',
          allocation: 0.34,
          config: {
            'navigation_type': 'hybrid',
            'show_recent': true,
            'quick_access': true,
          },
        ),
      ],
      primaryMetric: 'folder_navigation_frequency',
      secondaryMetrics: [
        'avg_folder_depth',
        'time_to_find_note',
        'navigation_errors',
      ],
      segmentation: ['user_experience_level', 'folder_count_bucket'],
      minimumSampleSize: 2000,
      maxDuration: Duration(days: 21),
    ),

    ABTestConfig(
      id: 'bulk_operations',
      name: 'Bulk Folder Operations',
      description: 'Test impact of bulk operation features',
      hypothesis: 'Bulk operations will increase power user engagement by 30%',
      variants: [
        TestVariant(
          id: 'no_bulk',
          name: 'Single Operations Only',
          allocation: 0.5,
          config: {'bulk_enabled': false},
        ),
        TestVariant(
          id: 'basic_bulk',
          name: 'Basic Bulk Operations',
          allocation: 0.25,
          config: {
            'bulk_enabled': true,
            'operations': ['move', 'delete'],
            'max_selection': 20,
          },
        ),
        TestVariant(
          id: 'advanced_bulk',
          name: 'Advanced Bulk Operations',
          allocation: 0.25,
          config: {
            'bulk_enabled': true,
            'operations': ['move', 'delete', 'tag', 'export', 'share'],
            'max_selection': 100,
            'drag_drop': true,
          },
        ),
      ],
      primaryMetric: 'bulk_operation_usage',
      secondaryMetrics: [
        'organization_time_saved',
        'error_rate',
        'user_satisfaction_score',
      ],
      segmentation: ['folder_count_bucket', 'user_tier'],
      minimumSampleSize: 1500,
      maxDuration: Duration(days: 28),
    ),

    ABTestConfig(
      id: 'folder_limits',
      name: 'Folder Limit Strategy',
      description: 'Test different folder limit approaches for free tier',
      hypothesis:
          'Soft limits with upgrade prompts will increase conversion by 40%',
      variants: [
        TestVariant(
          id: 'no_limit',
          name: 'Unlimited Folders',
          allocation: 0.25,
          config: {'folder_limit': null, 'show_upgrade_prompts': false},
        ),
        TestVariant(
          id: 'hard_limit',
          name: 'Hard Limit (10 folders)',
          allocation: 0.25,
          config: {
            'folder_limit': 10,
            'limit_type': 'hard',
            'show_upgrade_prompts': true,
          },
        ),
        TestVariant(
          id: 'soft_limit',
          name: 'Soft Limit with Prompts',
          allocation: 0.25,
          config: {
            'folder_limit': 10,
            'limit_type': 'soft',
            'grace_folders': 5,
            'show_upgrade_prompts': true,
            'prompt_frequency': 'progressive',
          },
        ),
        TestVariant(
          id: 'depth_limit',
          name: 'Depth-based Limits',
          allocation: 0.25,
          config: {
            'folder_limit': 20,
            'depth_limit': 2,
            'show_upgrade_prompts': true,
          },
        ),
      ],
      primaryMetric: 'premium_conversion_rate',
      secondaryMetrics: [
        'user_churn_rate',
        'folder_creation_rate',
        'user_satisfaction',
      ],
      segmentation: ['user_creation_date', 'engagement_level'],
      minimumSampleSize: 5000,
      maxDuration: Duration(days: 45),
    ),

    ABTestConfig(
      id: 'smart_suggestions',
      name: 'AI-Powered Folder Suggestions',
      description: 'Test ML-based folder organization suggestions',
      hypothesis:
          'Smart suggestions will improve organization efficiency by 35%',
      variants: [
        TestVariant(
          id: 'no_suggestions',
          name: 'No Suggestions',
          allocation: 0.5,
          config: {'suggestions_enabled': false},
        ),
        TestVariant(
          id: 'basic_suggestions',
          name: 'Rule-based Suggestions',
          allocation: 0.25,
          config: {
            'suggestions_enabled': true,
            'suggestion_type': 'rules',
            'frequency': 'on_demand',
          },
        ),
        TestVariant(
          id: 'ml_suggestions',
          name: 'ML-based Suggestions',
          allocation: 0.25,
          config: {
            'suggestions_enabled': true,
            'suggestion_type': 'ml',
            'frequency': 'proactive',
            'confidence_threshold': 0.8,
          },
        ),
      ],
      primaryMetric: 'suggestion_acceptance_rate',
      secondaryMetrics: [
        'organization_score',
        'time_to_organize',
        'folder_structure_quality',
      ],
      segmentation: ['note_count_bucket', 'organization_level'],
      minimumSampleSize: 3000,
      maxDuration: Duration(days: 30),
    ),
  ];

  /// Test result analysis methods
  static ABTestResult analyzeTest(
    String testId,
    DateTime startDate,
    DateTime endDate,
  ) {
    // This would connect to your analytics backend
    return ABTestResult(
      testId: testId,
      variants: [],
      winner: null,
      statisticalSignificance: 0.0,
      recommendations: [],
    );
  }

  /// Get user's test variants
  static Map<String, String> getUserTestVariants(String userId) {
    // Implementation would check user's assigned variants
    return {};
  }

  /// Check if test should be concluded
  static bool shouldConcludeTest(ABTestConfig test, ABTestMetrics metrics) {
    return metrics.sampleSize >= test.minimumSampleSize &&
        metrics.duration >= test.maxDuration &&
        metrics.statisticalPower >= 0.8;
  }
}

/// A/B Test configuration model
class ABTestConfig {
  final String id;
  final String name;
  final String description;
  final String hypothesis;
  final List<TestVariant> variants;
  final String primaryMetric;
  final List<String> secondaryMetrics;
  final List<String> segmentation;
  final int minimumSampleSize;
  final Duration maxDuration;

  ABTestConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.hypothesis,
    required this.variants,
    required this.primaryMetric,
    required this.secondaryMetrics,
    required this.segmentation,
    required this.minimumSampleSize,
    required this.maxDuration,
  });
}

/// Test variant configuration
class TestVariant {
  final String id;
  final String name;
  final double allocation;
  final Map<String, dynamic> config;

  TestVariant({
    required this.id,
    required this.name,
    required this.allocation,
    required this.config,
  });
}

/// A/B Test metrics
class ABTestMetrics {
  final int sampleSize;
  final Duration duration;
  final double statisticalPower;
  final Map<String, VariantMetrics> variantMetrics;

  ABTestMetrics({
    required this.sampleSize,
    required this.duration,
    required this.statisticalPower,
    required this.variantMetrics,
  });
}

/// Metrics for a specific variant
class VariantMetrics {
  final String variantId;
  final int userCount;
  final double primaryMetricValue;
  final Map<String, double> secondaryMetrics;
  final double conversionRate;
  final double confidenceInterval;

  VariantMetrics({
    required this.variantId,
    required this.userCount,
    required this.primaryMetricValue,
    required this.secondaryMetrics,
    required this.conversionRate,
    required this.confidenceInterval,
  });
}

/// A/B Test result
class ABTestResult {
  final String testId;
  final List<VariantMetrics> variants;
  final String? winner;
  final double statisticalSignificance;
  final List<String> recommendations;

  ABTestResult({
    required this.testId,
    required this.variants,
    required this.winner,
    required this.statisticalSignificance,
    required this.recommendations,
  });
}

/// A/B Test service for managing experiments
class FolderABTestService {
  final FolderAnalyticsService _analyticsService;
  final Map<String, ABTestConfig> _activeTests = {};

  FolderABTestService(this._analyticsService) {
    // Initialize with configured tests
    for (final test in FolderABTests.activeTests) {
      _activeTests[test.id] = test;
    }
  }

  /// Assign user to test variants
  String assignUserToVariant(String userId, String testId) {
    final test = _activeTests[testId];
    if (test == null) return 'control';

    // Simple hash-based assignment (in production, use proper randomization)
    final hash = userId.hashCode;
    double cumulative = 0;

    for (final variant in test.variants) {
      cumulative += variant.allocation;
      if (hash % 100 < cumulative * 100) {
        _trackAssignment(userId, testId, variant.id);
        return variant.id;
      }
    }

    return test.variants.first.id;
  }

  /// Track test assignment
  void _trackAssignment(String userId, String testId, String variantId) {
    _analyticsService.event(
      'ab_test_assigned',
      properties: {
        'user_id': userId,
        'test_id': testId,
        'variant_id': variantId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Track test conversion
  void trackConversion(
    String userId,
    String testId,
    String metricName,
    dynamic value,
  ) {
    _analyticsService.event(
      'ab_test_conversion',
      properties: {
        'user_id': userId,
        'test_id': testId,
        'metric_name': metricName,
        'metric_value': value,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Get variant configuration for user
  Map<String, dynamic>? getVariantConfig(String userId, String testId) {
    final test = _activeTests[testId];
    if (test == null) return null;

    final variantId = assignUserToVariant(userId, testId);
    final variant = test.variants.firstWhere((v) => v.id == variantId);

    return variant.config;
  }

  /// Check if user is in test
  bool isUserInTest(String userId, String testId) {
    return _activeTests.containsKey(testId);
  }

  /// Get all active tests for user
  List<String> getActiveTestsForUser(String userId) {
    return _activeTests.keys.toList();
  }
}
