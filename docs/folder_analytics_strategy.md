# Folder Management Analytics Strategy

## Executive Summary

This document outlines the comprehensive analytics strategy for Duru Notes' folder management system, designed to drive data-informed product decisions, optimize user engagement, and maximize business impact.

## Implementation Overview

### Core Analytics Files

1. **`lib/services/analytics/folder_analytics.dart`**
   - Event definitions and properties
   - KPI configurations
   - Analytics service implementation

2. **`lib/services/analytics/folder_dashboard_config.dart`**
   - Dashboard layouts and widgets
   - Alert configurations
   - Visualization specifications

3. **`lib/services/analytics/folder_ab_testing.dart`**
   - Active A/B test configurations
   - Variant management
   - Statistical analysis tools

4. **`lib/services/analytics/folder_analytics_implementation.dart`**
   - Production-ready implementation example
   - Integration patterns
   - Best practices

## Key Performance Indicators (KPIs)

### 1. User Engagement Metrics

| KPI | Target | Alert Threshold | Business Impact |
|-----|--------|-----------------|-----------------|
| Folder Creation Rate | 2.5 folders/user/week | < 1.0 | Direct correlation with retention |
| Average Folders Per User | 8.0 | < 3.0 | Indicates feature adoption depth |
| Daily Active Folder Users | 60% of DAU | < 30% | Feature engagement health |
| Folder Depth Distribution | Median: 3 | P95 > 6 | Organization complexity indicator |

### 2. Feature Adoption Metrics

| KPI | Target | Alert Threshold | Business Impact |
|-----|--------|-----------------|-----------------|
| New User Folder Creation | 70% in 7 days | < 40% | Onboarding effectiveness |
| Advanced Feature Adoption | 35% | < 15% | Power user development |
| Search Within Folders | 45% of searches | < 20% | Feature discovery |

### 3. Performance Metrics

| KPI | Target | Alert Threshold | Business Impact |
|-----|--------|-----------------|-----------------|
| Average Load Time | 200ms | > 500ms | User experience quality |
| Sync Success Rate | 99.5% | < 97% | System reliability |
| Error Rate | 0.1% | > 1.0% | Product stability |

### 4. Business Impact Metrics

| KPI | Target | Alert Threshold | Business Impact |
|-----|--------|-----------------|-----------------|
| Folder User Retention | 1.5x baseline | < 1.2x | Revenue retention |
| Productivity Increase | 2x notes created | < 1.3x | User value delivery |
| Premium Conversion | 15% at limits | < 5% | Monetization efficiency |

## Event Schema

### Core Events

```dart
// User creates a folder
event: 'folder_created'
properties: {
  folder_id: string
  parent_folder_id: string?
  folder_depth: number
  is_first_time: boolean
  creation_source: string
  has_custom_color: boolean
  has_custom_icon: boolean
  creation_time_ms: number
}

// User opens a folder
event: 'folder_opened'
properties: {
  folder_id: string
  navigation_method: string
  folder_note_count: number
  folder_subfolder_count: number
  view_type: string
}

// Folder search performed
event: 'folder_search_completed'
properties: {
  search_query: string
  search_scope: string
  search_result_count: number
  response_time_ms: number
}
```

## Dashboard Requirements

### Main Dashboard Components

1. **Real-time Metrics Row**
   - Active folder users percentage
   - Average folders per user
   - Weekly creation rate
   - Operation success rate

2. **Engagement Trends**
   - 30-day DAU trend with folder interactions
   - Folder creation velocity
   - Usage heatmap by hour/day

3. **Feature Adoption Funnel**
   - Discovery → First Folder → Multiple Folders → Advanced Features → Power User

4. **Performance Monitoring**
   - Load time percentiles (P50, P75, P95, P99)
   - Error rate tracking
   - Slow operation analysis

## A/B Testing Strategy

### Active Tests

1. **Enhanced Onboarding (folder_onboarding_v2)**
   - Control: Current flow
   - Variant A: Guided onboarding
   - Variant B: Auto-setup with templates
   - Primary Metric: First folder creation rate

2. **Navigation UI (folder_tree_navigation)**
   - Control: Simple list
   - Variant A: Collapsible tree
   - Variant B: Hybrid navigation
   - Primary Metric: Navigation frequency

3. **Folder Limits (folder_limits)**
   - Control: Unlimited
   - Variant A: Hard limit (10)
   - Variant B: Soft limit with prompts
   - Variant C: Depth-based limits
   - Primary Metric: Premium conversion rate

4. **Smart Suggestions (smart_suggestions)**
   - Control: No suggestions
   - Variant A: Rule-based
   - Variant B: ML-powered
   - Primary Metric: Suggestion acceptance rate

## Implementation Guide

### Quick Start Integration

```dart
// 1. Initialize analytics
final analytics = AnalyticsService();
final folderAnalytics = FolderAnalyticsService(analytics);
final abTestService = FolderABTestService(folderAnalytics);

// 2. Track folder creation
await folderAnalytics.trackFolderCreated(
  folderId: newFolderId,
  parentFolderId: parentId,
  depth: calculatedDepth,
  isFirstFolder: userMetrics.totalFolders == 0,
);

// 3. Track performance
folderAnalytics.startFolderLoad(folderId);
// ... load folder contents ...
folderAnalytics.endFolderLoad(
  folderId: folderId,
  success: true,
  itemCount: contents.length,
);

// 4. Check A/B test variants
final variant = abTestService.getVariantConfig(
  userId,
  'folder_onboarding_v2',
);
```

### Best Practices

1. **Event Naming Convention**
   - Use snake_case for event names
   - Follow pattern: `{entity}_{action}_{status}`
   - Example: `folder_created`, `folder_load_completed`

2. **Property Standards**
   - Always include user_id and timestamp
   - Use consistent data types
   - Avoid PII in properties

3. **Performance Tracking**
   - Track start and end of operations
   - Include error codes and retry counts
   - Monitor API response times

4. **A/B Test Guidelines**
   - Minimum 1000 users per variant
   - Run for statistical significance (p < 0.05)
   - Document learnings and iterate

## Alert Thresholds

### Critical Alerts (Immediate Response)
- Folder sync success rate < 97%
- Error rate > 1%
- Average load time > 1 second

### Warning Alerts (Within 4 Hours)
- Folder creation rate drop > 50%
- New user adoption < 40%
- Load time > 500ms

### Info Alerts (Daily Review)
- Feature usage changes > 20%
- A/B test reaching significance
- Approaching folder limits

## Data Retention Policy

- Raw events: 90 days
- Aggregated metrics: 2 years
- User-level data: Until account deletion
- A/B test results: Permanent

## Privacy Considerations

1. **User Consent**
   - Obtain explicit consent for analytics
   - Provide opt-out mechanism
   - Document data usage in privacy policy

2. **Data Minimization**
   - Only collect necessary data
   - Avoid storing folder content
   - Hash sensitive identifiers

3. **Access Control**
   - Restrict dashboard access
   - Audit analytics queries
   - Implement role-based permissions

## Success Metrics

### Month 1 Goals
- Implement core event tracking
- Deploy main dashboard
- Start first A/B test

### Month 3 Goals
- Achieve 70% new user folder creation
- Reduce average load time to < 300ms
- Complete 2 A/B tests with learnings

### Month 6 Goals
- Increase folder user retention by 50%
- Achieve 35% advanced feature adoption
- Optimize based on 5+ completed tests

## Reporting Cadence

- **Daily**: Performance metrics, error rates
- **Weekly**: Engagement trends, A/B test progress
- **Monthly**: Business impact, cohort analysis
- **Quarterly**: Strategic review, roadmap impact

## Next Steps

1. Review and approve KPI definitions
2. Set up analytics infrastructure
3. Implement tracking in folder service
4. Configure dashboards in analytics platform
5. Launch first A/B test
6. Establish monitoring rotation

## Contact

For questions about this analytics strategy:
- Technical Implementation: Engineering Team
- Dashboard Access: Analytics Team
- Business Metrics: Product Team