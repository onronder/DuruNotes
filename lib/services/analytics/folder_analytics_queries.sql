-- Folder Analytics SQL Queries
-- These queries can be used to generate analytics data from your database

-- ============================================
-- USER ENGAGEMENT METRICS
-- ============================================

-- Folder Creation Rate (folders per user per week)
WITH weekly_creation AS (
  SELECT
    user_id,
    DATE_TRUNC('week', created_at) as week,
    COUNT(*) as folders_created
  FROM folders
  WHERE created_at >= CURRENT_DATE - INTERVAL '4 weeks'
  GROUP BY user_id, week
)
SELECT
  AVG(folders_created) as avg_weekly_creation_rate,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY folders_created) as median_creation_rate,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY folders_created) as p95_creation_rate
FROM weekly_creation;

-- Average Folders Per User
SELECT
  COUNT(DISTINCT folder_id) / NULLIF(COUNT(DISTINCT user_id), 0) as avg_folders_per_user,
  COUNT(DISTINCT CASE WHEN folder_count > 0 THEN user_id END) / NULLIF(COUNT(DISTINCT user_id), 0) * 100 as pct_users_with_folders
FROM (
  SELECT
    u.user_id,
    COUNT(f.folder_id) as folder_count
  FROM users u
  LEFT JOIN folders f ON u.user_id = f.user_id
  WHERE u.is_active = true
  GROUP BY u.user_id
) user_folders;

-- Folder Depth Distribution
SELECT
  folder_depth,
  COUNT(*) as folder_count,
  COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage
FROM folders
GROUP BY folder_depth
ORDER BY folder_depth;

-- Daily Active Folder Users
SELECT
  DATE(event_timestamp) as date,
  COUNT(DISTINCT user_id) as folder_dau,
  COUNT(DISTINCT CASE WHEN event_name = 'folder_created' THEN user_id END) as creators,
  COUNT(DISTINCT CASE WHEN event_name = 'folder_opened' THEN user_id END) as navigators,
  COUNT(*) as total_folder_events
FROM analytics_events
WHERE event_name LIKE 'folder_%'
  AND event_timestamp >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(event_timestamp)
ORDER BY date DESC;

-- ============================================
-- FEATURE ADOPTION TRACKING
-- ============================================

-- New User Folder Creation (within 7 days)
WITH new_users AS (
  SELECT
    user_id,
    created_at as signup_date
  FROM users
  WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
),
first_folders AS (
  SELECT
    f.user_id,
    MIN(f.created_at) as first_folder_date
  FROM folders f
  INNER JOIN new_users nu ON f.user_id = nu.user_id
  WHERE f.created_at <= nu.signup_date + INTERVAL '7 days'
  GROUP BY f.user_id
)
SELECT
  COUNT(DISTINCT ff.user_id) * 100.0 / NULLIF(COUNT(DISTINCT nu.user_id), 0) as pct_new_users_creating_folders,
  AVG(EXTRACT(EPOCH FROM (ff.first_folder_date - nu.signup_date)) / 86400) as avg_days_to_first_folder
FROM new_users nu
LEFT JOIN first_folders ff ON nu.user_id = ff.user_id;

-- Advanced Feature Adoption
SELECT
  feature_name,
  COUNT(DISTINCT user_id) as unique_users,
  COUNT(*) as total_uses,
  COUNT(DISTINCT user_id) * 100.0 / (SELECT COUNT(DISTINCT user_id) FROM users WHERE is_active = true) as adoption_rate
FROM (
  SELECT
    user_id,
    CASE
      WHEN event_name = 'bulk_folder_operation' THEN 'Bulk Operations'
      WHEN event_name = 'folder_template_used' THEN 'Templates'
      WHEN event_name = 'folder_shared' THEN 'Sharing'
      WHEN event_name = 'folder_search_completed' THEN 'Search'
      WHEN event_name = 'folder_reorganization_completed' THEN 'Reorganization'
    END as feature_name
  FROM analytics_events
  WHERE event_name IN ('bulk_folder_operation', 'folder_template_used', 'folder_shared',
                       'folder_search_completed', 'folder_reorganization_completed')
    AND event_timestamp >= CURRENT_DATE - INTERVAL '30 days'
) features
GROUP BY feature_name
ORDER BY adoption_rate DESC;

-- Folder Feature Adoption Funnel
WITH funnel_stages AS (
  SELECT
    user_id,
    MAX(CASE WHEN has_discovered THEN 1 ELSE 0 END) as discovered,
    MAX(CASE WHEN has_created_first THEN 1 ELSE 0 END) as created_first,
    MAX(CASE WHEN has_created_multiple THEN 1 ELSE 0 END) as created_multiple,
    MAX(CASE WHEN has_used_advanced THEN 1 ELSE 0 END) as used_advanced,
    MAX(CASE WHEN is_power_user THEN 1 ELSE 0 END) as power_user
  FROM (
    SELECT
      u.user_id,
      EXISTS(SELECT 1 FROM analytics_events WHERE user_id = u.user_id AND event_name LIKE 'folder_%') as has_discovered,
      EXISTS(SELECT 1 FROM folders WHERE user_id = u.user_id) as has_created_first,
      (SELECT COUNT(*) FROM folders WHERE user_id = u.user_id) >= 5 as has_created_multiple,
      EXISTS(SELECT 1 FROM analytics_events WHERE user_id = u.user_id
             AND event_name IN ('bulk_folder_operation', 'folder_template_used')) as has_used_advanced,
      (SELECT COUNT(*) FROM folders WHERE user_id = u.user_id) >= 20 as is_power_user
    FROM users u
    WHERE u.is_active = true
  ) user_stages
  GROUP BY user_id
)
SELECT
  'Discovered Folders' as stage,
  SUM(discovered) as user_count,
  SUM(discovered) * 100.0 / COUNT(*) as percentage
FROM funnel_stages
UNION ALL
SELECT
  'Created First Folder',
  SUM(created_first),
  SUM(created_first) * 100.0 / COUNT(*)
FROM funnel_stages
UNION ALL
SELECT
  'Created Multiple Folders',
  SUM(created_multiple),
  SUM(created_multiple) * 100.0 / COUNT(*)
FROM funnel_stages
UNION ALL
SELECT
  'Used Advanced Features',
  SUM(used_advanced),
  SUM(used_advanced) * 100.0 / COUNT(*)
FROM funnel_stages
UNION ALL
SELECT
  'Power User',
  SUM(power_user),
  SUM(power_user) * 100.0 / COUNT(*)
FROM funnel_stages;

-- ============================================
-- PERFORMANCE METRICS
-- ============================================

-- Average Folder Load Time
SELECT
  DATE(event_timestamp) as date,
  AVG(CAST(properties->>'load_time_ms' AS INTEGER)) as avg_load_time_ms,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(properties->>'load_time_ms' AS INTEGER)) as median_load_time_ms,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY CAST(properties->>'load_time_ms' AS INTEGER)) as p95_load_time_ms,
  PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY CAST(properties->>'load_time_ms' AS INTEGER)) as p99_load_time_ms,
  COUNT(*) as total_loads
FROM analytics_events
WHERE event_name = 'folder_load_completed'
  AND event_timestamp >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(event_timestamp)
ORDER BY date DESC;

-- Folder Sync Success Rate
SELECT
  DATE(event_timestamp) as date,
  COUNT(CASE WHEN event_name = 'folder_sync_completed' THEN 1 END) * 100.0 /
    NULLIF(COUNT(CASE WHEN event_name IN ('folder_sync_completed', 'folder_sync_failed') THEN 1 END), 0) as success_rate,
  COUNT(CASE WHEN event_name = 'folder_sync_completed' THEN 1 END) as successful_syncs,
  COUNT(CASE WHEN event_name = 'folder_sync_failed' THEN 1 END) as failed_syncs
FROM analytics_events
WHERE event_name IN ('folder_sync_completed', 'folder_sync_failed')
  AND event_timestamp >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(event_timestamp)
ORDER BY date DESC;

-- Slow Operations Report
SELECT
  properties->>'operation_type' as operation,
  properties->>'folder_id' as folder_id,
  CAST(properties->>'response_time_ms' AS INTEGER) as duration_ms,
  user_id,
  event_timestamp
FROM analytics_events
WHERE event_name LIKE 'folder_%'
  AND CAST(properties->>'response_time_ms' AS INTEGER) > 1000
  AND event_timestamp >= CURRENT_DATE - INTERVAL '24 hours'
ORDER BY duration_ms DESC
LIMIT 20;

-- ============================================
-- BUSINESS IMPACT METRICS
-- ============================================

-- Folder User Retention Comparison
WITH user_cohorts AS (
  SELECT
    u.user_id,
    DATE_TRUNC('week', u.created_at) as cohort_week,
    CASE WHEN EXISTS(SELECT 1 FROM folders WHERE user_id = u.user_id) THEN 'has_folders' ELSE 'no_folders' END as user_type
  FROM users u
  WHERE u.created_at >= CURRENT_DATE - INTERVAL '90 days'
),
retention_data AS (
  SELECT
    uc.cohort_week,
    uc.user_type,
    COUNT(DISTINCT uc.user_id) as cohort_size,
    COUNT(DISTINCT CASE WHEN ae.user_id IS NOT NULL THEN uc.user_id END) as retained_users
  FROM user_cohorts uc
  LEFT JOIN (
    SELECT DISTINCT user_id
    FROM analytics_events
    WHERE event_timestamp >= CURRENT_DATE - INTERVAL '30 days'
  ) ae ON uc.user_id = ae.user_id
  GROUP BY uc.cohort_week, uc.user_type
)
SELECT
  cohort_week,
  MAX(CASE WHEN user_type = 'has_folders' THEN retained_users * 100.0 / NULLIF(cohort_size, 0) END) as folder_user_retention,
  MAX(CASE WHEN user_type = 'no_folders' THEN retained_users * 100.0 / NULLIF(cohort_size, 0) END) as non_folder_user_retention,
  MAX(CASE WHEN user_type = 'has_folders' THEN retained_users * 100.0 / NULLIF(cohort_size, 0) END) /
    NULLIF(MAX(CASE WHEN user_type = 'no_folders' THEN retained_users * 100.0 / NULLIF(cohort_size, 0) END), 0) as retention_multiplier
FROM retention_data
GROUP BY cohort_week
ORDER BY cohort_week DESC;

-- Folder-Driven Productivity
WITH user_productivity AS (
  SELECT
    u.user_id,
    COUNT(DISTINCT f.folder_id) as folder_count,
    COUNT(DISTINCT n.note_id) as notes_created_last_30d,
    CASE
      WHEN COUNT(DISTINCT f.folder_id) = 0 THEN 'no_folders'
      WHEN COUNT(DISTINCT f.folder_id) BETWEEN 1 AND 5 THEN 'few_folders'
      WHEN COUNT(DISTINCT f.folder_id) BETWEEN 6 AND 15 THEN 'moderate_folders'
      ELSE 'many_folders'
    END as folder_segment
  FROM users u
  LEFT JOIN folders f ON u.user_id = f.user_id
  LEFT JOIN notes n ON u.user_id = n.user_id AND n.created_at >= CURRENT_DATE - INTERVAL '30 days'
  WHERE u.is_active = true
  GROUP BY u.user_id
)
SELECT
  folder_segment,
  COUNT(*) as user_count,
  AVG(notes_created_last_30d) as avg_notes_created,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY notes_created_last_30d) as median_notes_created
FROM user_productivity
GROUP BY folder_segment
ORDER BY
  CASE folder_segment
    WHEN 'no_folders' THEN 1
    WHEN 'few_folders' THEN 2
    WHEN 'moderate_folders' THEN 3
    WHEN 'many_folders' THEN 4
  END;

-- Premium Conversion via Folder Limits
WITH limit_events AS (
  SELECT
    user_id,
    MAX(CASE WHEN event_name = 'folder_limit_reached' THEN 1 ELSE 0 END) as hit_limit,
    MAX(CASE WHEN event_name = 'folder_upgrade_prompt_shown' THEN 1 ELSE 0 END) as saw_prompt,
    MAX(CASE WHEN event_name = 'folder_upgrade_initiated' THEN 1 ELSE 0 END) as started_upgrade,
    MAX(CASE WHEN event_name = 'premium_conversion' THEN 1 ELSE 0 END) as converted
  FROM analytics_events
  WHERE event_timestamp >= CURRENT_DATE - INTERVAL '90 days'
  GROUP BY user_id
)
SELECT
  'Hit Folder Limit' as stage,
  SUM(hit_limit) as user_count,
  100.0 as percentage
FROM limit_events
WHERE hit_limit = 1
UNION ALL
SELECT
  'Viewed Upgrade Prompt',
  SUM(saw_prompt),
  SUM(saw_prompt) * 100.0 / NULLIF(SUM(hit_limit), 0)
FROM limit_events
WHERE hit_limit = 1
UNION ALL
SELECT
  'Started Trial/Upgrade',
  SUM(started_upgrade),
  SUM(started_upgrade) * 100.0 / NULLIF(SUM(hit_limit), 0)
FROM limit_events
WHERE hit_limit = 1
UNION ALL
SELECT
  'Converted to Premium',
  SUM(converted),
  SUM(converted) * 100.0 / NULLIF(SUM(hit_limit), 0)
FROM limit_events
WHERE hit_limit = 1;

-- ============================================
-- A/B TEST ANALYSIS
-- ============================================

-- A/B Test Results Summary
SELECT
  properties->>'test_id' as test_id,
  properties->>'variant_id' as variant_id,
  COUNT(DISTINCT user_id) as user_count,
  AVG(CASE WHEN properties->>'metric_name' = 'first_folder_created'
      THEN CAST(properties->>'metric_value' AS FLOAT) END) as first_folder_rate,
  AVG(CASE WHEN properties->>'metric_name' = 'days_to_first_folder'
      THEN CAST(properties->>'metric_value' AS FLOAT) END) as avg_days_to_folder
FROM analytics_events
WHERE event_name IN ('ab_test_assigned', 'ab_test_conversion')
  AND properties->>'test_id' = 'folder_onboarding_v2'
GROUP BY properties->>'test_id', properties->>'variant_id';

-- Statistical Significance Calculation
WITH variant_performance AS (
  SELECT
    properties->>'variant_id' as variant,
    COUNT(DISTINCT CASE WHEN properties->>'metric_value' = '1' THEN user_id END) as conversions,
    COUNT(DISTINCT user_id) as total_users
  FROM analytics_events
  WHERE event_name = 'ab_test_conversion'
    AND properties->>'test_id' = 'folder_onboarding_v2'
    AND properties->>'metric_name' = 'first_folder_created'
  GROUP BY properties->>'variant_id'
)
SELECT
  variant,
  conversions,
  total_users,
  conversions * 100.0 / NULLIF(total_users, 0) as conversion_rate,
  -- Calculate z-score for significance (simplified)
  ABS(conversions * 100.0 / NULLIF(total_users, 0) -
      LAG(conversions * 100.0 / NULLIF(total_users, 0)) OVER (ORDER BY variant)) /
      SQRT((conversions * 100.0 / NULLIF(total_users, 0)) *
           (1 - conversions * 100.0 / NULLIF(total_users, 0)) / NULLIF(total_users, 0)) as z_score
FROM variant_performance;

-- ============================================
-- REAL-TIME MONITORING QUERIES
-- ============================================

-- Current Active Folder Sessions
SELECT
  COUNT(DISTINCT user_id) as active_users,
  COUNT(*) as total_events,
  AVG(CASE WHEN event_name = 'folder_load_completed'
      THEN CAST(properties->>'load_time_ms' AS INTEGER) END) as avg_load_time_ms
FROM analytics_events
WHERE event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '5 minutes'
  AND event_name LIKE 'folder_%';

-- Error Rate Monitoring
SELECT
  DATE_TRUNC('hour', event_timestamp) as hour,
  COUNT(CASE WHEN event_name LIKE '%_failed' OR event_name = 'error_occurred' THEN 1 END) * 100.0 /
    NULLIF(COUNT(*), 0) as error_rate,
  COUNT(CASE WHEN event_name LIKE '%_failed' OR event_name = 'error_occurred' THEN 1 END) as error_count,
  COUNT(*) as total_operations
FROM analytics_events
WHERE event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
  AND event_name LIKE 'folder_%'
GROUP BY DATE_TRUNC('hour', event_timestamp)
ORDER BY hour DESC;