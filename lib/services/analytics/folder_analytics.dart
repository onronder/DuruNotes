import 'package:duru_notes/services/analytics/analytics_service.dart';

/// Folder management analytics events
class FolderAnalyticsEvents {
  // === USER ENGAGEMENT METRICS ===

  // Folder creation & modification
  static const String folderCreated = 'folder_created';
  static const String folderDeleted = 'folder_deleted';
  static const String folderRenamed = 'folder_renamed';
  static const String folderMoved = 'folder_moved';
  static const String folderColorChanged = 'folder_color_changed';
  static const String folderIconChanged = 'folder_icon_changed';

  // Folder navigation & usage
  static const String folderOpened = 'folder_opened';
  static const String folderClosed = 'folder_closed';
  static const String folderNavigatedTo = 'folder_navigated_to';
  static const String folderBreadcrumbUsed = 'folder_breadcrumb_used';
  static const String folderTreeToggled = 'folder_tree_toggled';
  static const String folderViewChanged = 'folder_view_changed';

  // === FEATURE ADOPTION TRACKING ===

  // New user experience
  static const String firstFolderCreated = 'first_folder_created';
  static const String folderOnboardingStarted = 'folder_onboarding_started';
  static const String folderOnboardingCompleted = 'folder_onboarding_completed';
  static const String folderOnboardingSkipped = 'folder_onboarding_skipped';

  // Advanced features
  static const String bulkFolderOperation = 'bulk_folder_operation';
  static const String folderTemplateUsed = 'folder_template_used';
  static const String folderSortingChanged = 'folder_sorting_changed';
  static const String folderFilterApplied = 'folder_filter_applied';
  static const String folderShared = 'folder_shared';
  static const String folderPermissionsChanged = 'folder_permissions_changed';
  static const String folderPinned = 'folder_pinned';
  static const String folderUnpinned = 'folder_unpinned';

  // Search & discovery
  static const String folderSearchInitiated = 'folder_search_initiated';
  static const String folderSearchCompleted = 'folder_search_completed';
  static const String folderQuickAccessUsed = 'folder_quick_access_used';
  static const String recentFoldersViewed = 'recent_folders_viewed';

  // Organization features
  static const String notesMovedToFolder = 'notes_moved_to_folder';
  static const String notesRemovedFromFolder = 'notes_removed_from_folder';
  static const String folderReorganizationStarted = 'folder_reorganization_started';
  static const String folderReorganizationCompleted = 'folder_reorganization_completed';
  static const String folderMerged = 'folder_merged';
  static const String folderSplit = 'folder_split';

  // === PERFORMANCE METRICS ===

  static const String folderLoadStarted = 'folder_load_started';
  static const String folderLoadCompleted = 'folder_load_completed';
  static const String folderLoadFailed = 'folder_load_failed';
  static const String folderSyncStarted = 'folder_sync_started';
  static const String folderSyncCompleted = 'folder_sync_completed';
  static const String folderSyncFailed = 'folder_sync_failed';
  static const String folderTreeLoadTime = 'folder_tree_load_time';
  static const String folderContentsLoadTime = 'folder_contents_load_time';

  // === BUSINESS IMPACT METRICS ===

  static const String folderFeatureDiscovered = 'folder_feature_discovered';
  static const String folderUpgradePromptShown = 'folder_upgrade_prompt_shown';
  static const String folderUpgradeInitiated = 'folder_upgrade_initiated';
  static const String folderLimitReached = 'folder_limit_reached';
}

/// Folder analytics properties
class FolderAnalyticsProperties {
  // Folder identifiers
  static const String folderId = 'folder_id';
  static const String parentFolderId = 'parent_folder_id';
  static const String folderPath = 'folder_path';
  static const String folderName = 'folder_name';

  // Folder metrics
  static const String folderDepth = 'folder_depth';
  static const String folderNoteCount = 'folder_note_count';
  static const String folderSubfolderCount = 'folder_subfolder_count';
  static const String folderTotalItemCount = 'folder_total_item_count';
  static const String folderSizeBytes = 'folder_size_bytes';
  static const String folderAge = 'folder_age_days';

  // User behavior metrics
  static const String userFolderCount = 'user_folder_count';
  static const String sessionFolderCount = 'session_folder_count';
  static const String averageFolderDepth = 'average_folder_depth';
  static const String maxFolderDepth = 'max_folder_depth';
  static const String folderAccessFrequency = 'folder_access_frequency';
  static const String lastFolderAccessTime = 'last_folder_access_time';

  // Operation details
  static const String operationType = 'operation_type';
  static const String operationSource = 'operation_source';
  static const String itemCount = 'item_count';
  static const String bulkOperationSize = 'bulk_operation_size';
  static const String moveDistance = 'move_distance';

  // Performance metrics
  static const String loadTimeMs = 'load_time_ms';
  static const String syncTimeMs = 'sync_time_ms';
  static const String responseTimeMs = 'response_time_ms';
  static const String errorCode = 'error_code';
  static const String errorReason = 'error_reason';
  static const String retryCount = 'retry_count';

  // Search & navigation
  static const String searchQuery = 'search_query';
  static const String searchScope = 'search_scope';
  static const String searchResultCount = 'search_result_count';
  static const String navigationMethod = 'navigation_method';
  static const String viewType = 'view_type';
  static const String sortOrder = 'sort_order';

  // Feature usage
  static const String featureType = 'feature_type';
  static const String templateId = 'template_id';
  static const String sharingMethod = 'sharing_method';
  static const String permissionLevel = 'permission_level';
  static const String isPinned = 'is_pinned';
  static const String hasCustomColor = 'has_custom_color';
  static const String hasCustomIcon = 'has_custom_icon';

  // Business metrics
  static const String isFirstTime = 'is_first_time';
  static const String isPremiumFeature = 'is_premium_feature';
  static const String userTier = 'user_tier';
  static const String daysUntilFirstFolder = 'days_until_first_folder';
  static const String folderCreationRate = 'folder_creation_rate';
}

/// Folder analytics KPI definitions
class FolderKPIs {
  // === USER ENGAGEMENT KPIS ===

  static const FolderKPI folderCreationRate = FolderKPI(
    name: 'Folder Creation Rate',
    description: 'Average folders created per active user per week',
    calculation: 'COUNT(folder_created) / COUNT(DISTINCT user_id) / 7',
    targetValue: 2.5,
    alertThreshold: 1.0,
  );

  static const FolderKPI averageFoldersPerUser = FolderKPI(
    name: 'Average Folders Per User',
    description: 'Mean number of folders per active user',
    calculation: 'COUNT(DISTINCT folder_id) / COUNT(DISTINCT user_id)',
    targetValue: 8.0,
    alertThreshold: 3.0,
  );

  static const FolderKPI folderDepthDistribution = FolderKPI(
    name: 'Folder Depth Distribution',
    description: 'Distribution of folder hierarchy depths',
    calculation: 'PERCENTILE(folder_depth, [25, 50, 75, 95])',
    targetValue: 3.0, // median depth
    alertThreshold: 6.0, // 95th percentile
  );

  static const FolderKPI dailyActiveFolderUsers = FolderKPI(
    name: 'Daily Active Folder Users',
    description: 'Users who interacted with folders in last 24h',
    calculation: 'COUNT(DISTINCT user_id WHERE folder_event IN last_24h)',
    targetValue: 0.6, // 60% of DAU
    alertThreshold: 0.3,
  );

  // === FEATURE ADOPTION KPIS ===

  static const FolderKPI newUserFolderCreation = FolderKPI(
    name: 'New User Folder Creation',
    description: 'Percentage of new users creating folder in first 7 days',
    calculation: 'COUNT(first_folder_created) / COUNT(new_users) * 100',
    targetValue: 70.0,
    alertThreshold: 40.0,
  );

  static const FolderKPI advancedFeatureAdoption = FolderKPI(
    name: 'Advanced Feature Adoption',
    description: 'Users using advanced folder features (bulk ops, templates, etc)',
    calculation: 'COUNT(DISTINCT user_id WITH advanced_feature) / COUNT(DISTINCT user_id)',
    targetValue: 0.35,
    alertThreshold: 0.15,
  );

  static const FolderKPI searchWithinFoldersUsage = FolderKPI(
    name: 'Search Within Folders Usage',
    description: 'Percentage of searches scoped to folders',
    calculation: 'COUNT(folder_search) / COUNT(all_searches) * 100',
    targetValue: 45.0,
    alertThreshold: 20.0,
  );

  // === PERFORMANCE KPIS ===

  static const FolderKPI averageFolderLoadTime = FolderKPI(
    name: 'Average Folder Load Time',
    description: 'Mean time to load folder contents',
    calculation: 'AVG(folder_load_time_ms)',
    targetValue: 200.0, // ms
    alertThreshold: 500.0,
  );

  static const FolderKPI folderSyncSuccessRate = FolderKPI(
    name: 'Folder Sync Success Rate',
    description: 'Percentage of successful folder sync operations',
    calculation: 'COUNT(sync_success) / COUNT(sync_attempts) * 100',
    targetValue: 99.5,
    alertThreshold: 97.0,
  );

  static const FolderKPI folderErrorRate = FolderKPI(
    name: 'Folder Error Rate',
    description: 'Percentage of folder operations resulting in errors',
    calculation: 'COUNT(folder_errors) / COUNT(folder_operations) * 100',
    targetValue: 0.1,
    alertThreshold: 1.0,
  );

  // === BUSINESS IMPACT KPIS ===

  static const FolderKPI folderUserRetention = FolderKPI(
    name: 'Folder User Retention',
    description: '30-day retention for users who create folders vs those who don\'t',
    calculation: 'RETENTION(folder_creators, 30) / RETENTION(non_folder_creators, 30)',
    targetValue: 1.5, // 50% better retention
    alertThreshold: 1.2,
  );

  static const FolderKPI folderDrivenProductivity = FolderKPI(
    name: 'Folder-Driven Productivity',
    description: 'Average notes created per user with folders vs without',
    calculation: 'AVG(notes_created | has_folders) / AVG(notes_created | no_folders)',
    targetValue: 2.0,
    alertThreshold: 1.3,
  );

  static const FolderKPI premiumConversionImpact = FolderKPI(
    name: 'Premium Conversion Impact',
    description: 'Conversion rate for users hitting folder limits',
    calculation: 'COUNT(upgraded_after_limit) / COUNT(hit_folder_limit) * 100',
    targetValue: 15.0,
    alertThreshold: 5.0,
  );
}

/// Folder KPI model
class FolderKPI {
  final String name;
  final String description;
  final String calculation;
  final double targetValue;
  final double alertThreshold;

  const FolderKPI({
    required this.name,
    required this.description,
    required this.calculation,
    required this.targetValue,
    required this.alertThreshold,
  });
}

/// Folder analytics implementation
class FolderAnalyticsService {
  final AnalyticsService _analyticsService;
  final Map<String, DateTime> _timingEvents = {};

  FolderAnalyticsService(this._analyticsService);

  // === ENGAGEMENT TRACKING ===

  void trackFolderCreated({
    required String folderId,
    String? parentFolderId,
    required int depth,
    required bool isFirstFolder,
    Map<String, dynamic>? additionalProperties,
  }) {
    _analyticsService.event(
      FolderAnalyticsEvents.folderCreated,
      properties: {
        FolderAnalyticsProperties.folderId: folderId,
        if (parentFolderId != null) FolderAnalyticsProperties.parentFolderId: parentFolderId,
        FolderAnalyticsProperties.folderDepth: depth,
        FolderAnalyticsProperties.isFirstTime: isFirstFolder,
        ...?additionalProperties,
      },
    );

    if (isFirstFolder) {
      _analyticsService.event(FolderAnalyticsEvents.firstFolderCreated);
    }
  }

  void trackFolderOpened({
    required String folderId,
    required String navigationMethod,
    required int noteCount,
    required int subfolderCount,
    Map<String, dynamic>? additionalProperties,
  }) {
    _analyticsService.event(
      FolderAnalyticsEvents.folderOpened,
      properties: {
        FolderAnalyticsProperties.folderId: folderId,
        FolderAnalyticsProperties.navigationMethod: navigationMethod,
        FolderAnalyticsProperties.folderNoteCount: noteCount,
        FolderAnalyticsProperties.folderSubfolderCount: subfolderCount,
        ...?additionalProperties,
      },
    );
  }

  void trackFolderReorganization({
    required String operationType,
    required List<String> folderIds,
    required int itemCount,
    Map<String, dynamic>? additionalProperties,
  }) {
    _analyticsService.event(
      FolderAnalyticsEvents.folderReorganizationStarted,
      properties: {
        FolderAnalyticsProperties.operationType: operationType,
        FolderAnalyticsProperties.itemCount: itemCount,
        FolderAnalyticsProperties.bulkOperationSize: folderIds.length,
        ...?additionalProperties,
      },
    );
  }

  // === PERFORMANCE TRACKING ===

  void startFolderLoad(String folderId) {
    final key = '${FolderAnalyticsEvents.folderLoadStarted}_$folderId';
    _timingEvents[key] = DateTime.now();

    _analyticsService.event(
      FolderAnalyticsEvents.folderLoadStarted,
      properties: {
        FolderAnalyticsProperties.folderId: folderId,
      },
    );
  }

  void endFolderLoad({
    required String folderId,
    required bool success,
    String? errorCode,
    int? itemCount,
  }) {
    final key = '${FolderAnalyticsEvents.folderLoadStarted}_$folderId';
    final startTime = _timingEvents[key];

    if (startTime != null) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      _timingEvents.remove(key);

      _analyticsService.event(
        success ? FolderAnalyticsEvents.folderLoadCompleted : FolderAnalyticsEvents.folderLoadFailed,
        properties: {
          FolderAnalyticsProperties.folderId: folderId,
          FolderAnalyticsProperties.loadTimeMs: duration,
          if (errorCode != null) FolderAnalyticsProperties.errorCode: errorCode,
          if (itemCount != null) FolderAnalyticsProperties.folderTotalItemCount: itemCount,
        },
      );
    }
  }

  // === FEATURE ADOPTION TRACKING ===

  void trackAdvancedFeatureUsage({
    required String featureType,
    required String folderId,
    Map<String, dynamic>? additionalProperties,
  }) {
    _analyticsService.featureUsed(
      featureType,
      properties: {
        FolderAnalyticsProperties.folderId: folderId,
        FolderAnalyticsProperties.featureType: featureType,
        ...?additionalProperties,
      },
    );
  }

  void trackFolderSearch({
    required String query,
    required String scope,
    required int resultCount,
    required int searchTimeMs,
  }) {
    _analyticsService.event(
      FolderAnalyticsEvents.folderSearchCompleted,
      properties: {
        FolderAnalyticsProperties.searchQuery: query,
        FolderAnalyticsProperties.searchScope: scope,
        FolderAnalyticsProperties.searchResultCount: resultCount,
        FolderAnalyticsProperties.responseTimeMs: searchTimeMs,
      },
    );
  }

  // === BUSINESS IMPACT TRACKING ===

  void trackFolderLimitReached({
    required String userId,
    required int currentFolderCount,
    required int limit,
    required String userTier,
  }) {
    _analyticsService.event(
      FolderAnalyticsEvents.folderLimitReached,
      properties: {
        AnalyticsProperties.userId: userId,
        FolderAnalyticsProperties.userFolderCount: currentFolderCount,
        FolderAnalyticsProperties.userTier: userTier,
        'limit': limit,
      },
    );
  }

  void trackUpgradePrompt({
    required String trigger,
    required String location,
    required bool isPremiumFeature,
  }) {
    _analyticsService.event(
      FolderAnalyticsEvents.folderUpgradePromptShown,
      properties: {
        'trigger': trigger,
        'location': location,
        FolderAnalyticsProperties.isPremiumFeature: isPremiumFeature,
      },
    );
  }

  // === UTILITY METHODS ===

  Map<String, dynamic> calculateUserEngagementMetrics({
    required String userId,
    required int folderCount,
    required double averageDepth,
    required int foldersCreatedThisWeek,
    required int foldersAccessedThisWeek,
  }) {
    return {
      'engagement_score': _calculateEngagementScore(
        folderCount: folderCount,
        averageDepth: averageDepth,
        weeklyCreation: foldersCreatedThisWeek,
        weeklyAccess: foldersAccessedThisWeek,
      ),
      'organization_level': _getOrganizationLevel(folderCount, averageDepth),
      'activity_status': _getActivityStatus(foldersAccessedThisWeek),
    };
  }

  double _calculateEngagementScore({
    required int folderCount,
    required double averageDepth,
    required int weeklyCreation,
    required int weeklyAccess,
  }) {
    // Weighted engagement score calculation
    final folderScore = (folderCount / 10).clamp(0.0, 1.0) * 0.25;
    final depthScore = (averageDepth / 4).clamp(0.0, 1.0) * 0.25;
    final creationScore = (weeklyCreation / 3).clamp(0.0, 1.0) * 0.25;
    final accessScore = (weeklyAccess / 7).clamp(0.0, 1.0) * 0.25;

    return (folderScore + depthScore + creationScore + accessScore) * 100;
  }

  String _getOrganizationLevel(int folderCount, double averageDepth) {
    if (folderCount >= 20 && averageDepth >= 3) return 'power_user';
    if (folderCount >= 10 && averageDepth >= 2) return 'organized';
    if (folderCount >= 5) return 'moderate';
    if (folderCount >= 1) return 'beginner';
    return 'not_started';
  }

  String _getActivityStatus(int weeklyAccess) {
    if (weeklyAccess >= 20) return 'very_active';
    if (weeklyAccess >= 10) return 'active';
    if (weeklyAccess >= 5) return 'moderate';
    if (weeklyAccess >= 1) return 'low';
    return 'inactive';
  }
}