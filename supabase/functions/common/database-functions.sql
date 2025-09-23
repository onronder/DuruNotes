-- Enhanced Database Functions for FCM Notification Processing
-- These functions support the production-grade FCM integration

-- Function to claim notification events with priority ordering
CREATE OR REPLACE FUNCTION claim_priority_notification_events(
  batch_limit INT DEFAULT 50,
  max_age_minutes INT DEFAULT 60
)
RETURNS TABLE(
  id UUID,
  user_id UUID,
  event_type TEXT,
  priority TEXT,
  payload JSONB,
  notification_templates JSONB,
  collapse_key TEXT,
  tag TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
  claim_id UUID := gen_random_uuid();
  cutoff_time TIMESTAMPTZ := NOW() - (max_age_minutes || ' minutes')::INTERVAL;
BEGIN
  -- Atomically claim notifications using advisory lock
  PERFORM pg_advisory_lock(hashtext('notification_claim_lock'));

  -- Mark notifications as claimed
  UPDATE notification_events
  SET
    status = 'processing',
    claim_id = claim_priority_notification_events.claim_id,
    updated_at = NOW()
  FROM (
    SELECT ne.id
    FROM notification_events ne
    WHERE
      ne.status = 'pending'
      AND ne.created_at > cutoff_time
      AND ne.scheduled_for <= NOW()
    ORDER BY
      CASE ne.priority
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'normal' THEN 3
        WHEN 'low' THEN 4
        ELSE 5
      END,
      ne.created_at ASC
    LIMIT batch_limit
    FOR UPDATE SKIP LOCKED
  ) claimed
  WHERE notification_events.id = claimed.id;

  -- Release the lock
  PERFORM pg_advisory_unlock(hashtext('notification_claim_lock'));

  -- Return the claimed notifications
  RETURN QUERY
  SELECT
    ne.id,
    ne.user_id,
    ne.event_type,
    ne.priority,
    ne.payload,
    ne.notification_templates,
    ne.collapse_key,
    ne.tag,
    ne.created_at
  FROM notification_events ne
  WHERE ne.claim_id = claim_priority_notification_events.claim_id
  ORDER BY
    CASE ne.priority
      WHEN 'critical' THEN 1
      WHEN 'high' THEN 2
      WHEN 'normal' THEN 3
      WHEN 'low' THEN 4
      ELSE 5
    END,
    ne.created_at ASC;
END;
$$;

-- Function to get active user devices with enhanced filtering
CREATE OR REPLACE FUNCTION get_active_user_devices(
  _user_id UUID
)
RETURNS TABLE(
  device_id UUID,
  push_token TEXT,
  platform TEXT,
  app_version TEXT,
  last_active TIMESTAMPTZ,
  notification_preferences JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ud.device_id,
    ud.push_token,
    ud.platform,
    ud.app_version,
    ud.last_active,
    ud.notification_preferences
  FROM user_devices ud
  LEFT JOIN invalid_tokens it ON it.token = ud.push_token
  WHERE
    ud.user_id = _user_id
    AND ud.push_token IS NOT NULL
    AND ud.push_token != ''
    AND it.token IS NULL  -- Not in invalid tokens list
    AND ud.is_active = true
    AND ud.last_active > (NOW() - INTERVAL '30 days')  -- Active within 30 days
  ORDER BY ud.last_active DESC;
END;
$$;

-- Function to cleanup old notification events
CREATE OR REPLACE FUNCTION cleanup_old_notifications(
  retention_days INT DEFAULT 30
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  deleted_count INT;
  cutoff_date TIMESTAMPTZ := NOW() - (retention_days || ' days')::INTERVAL;
BEGIN
  -- Delete old notification events and their deliveries
  WITH deleted_notifications AS (
    DELETE FROM notification_events
    WHERE created_at < cutoff_date
    AND status IN ('delivered', 'failed', 'expired')
    RETURNING id
  ),
  deleted_deliveries AS (
    DELETE FROM notification_deliveries
    WHERE notification_event_id IN (SELECT id FROM deleted_notifications)
    RETURNING 1
  )
  SELECT COUNT(*) INTO deleted_count FROM deleted_notifications;

  -- Cleanup invalid tokens older than retention period
  DELETE FROM invalid_tokens
  WHERE invalidated_at < cutoff_date;

  RETURN deleted_count;
END;
$$;

-- Function to get notification analytics
CREATE OR REPLACE FUNCTION get_notification_analytics(
  start_date TIMESTAMPTZ DEFAULT NOW() - INTERVAL '24 hours',
  end_date TIMESTAMPTZ DEFAULT NOW()
)
RETURNS TABLE(
  event_type TEXT,
  priority TEXT,
  total_sent BIGINT,
  total_delivered BIGINT,
  total_failed BIGINT,
  delivery_rate NUMERIC,
  avg_processing_time NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ne.event_type,
    ne.priority,
    COUNT(*) as total_sent,
    COUNT(CASE WHEN ne.status = 'delivered' THEN 1 END) as total_delivered,
    COUNT(CASE WHEN ne.status = 'failed' THEN 1 END) as total_failed,
    ROUND(
      (COUNT(CASE WHEN ne.status = 'delivered' THEN 1 END)::NUMERIC / COUNT(*)::NUMERIC) * 100,
      2
    ) as delivery_rate,
    ROUND(
      EXTRACT(EPOCH FROM AVG(ne.delivered_at - ne.created_at)) * 1000,
      2
    ) as avg_processing_time
  FROM notification_events ne
  WHERE
    ne.created_at >= start_date
    AND ne.created_at <= end_date
    AND ne.status IN ('delivered', 'failed')
  GROUP BY ne.event_type, ne.priority
  ORDER BY total_sent DESC;
END;
$$;

-- Function to requeue failed notifications
CREATE OR REPLACE FUNCTION requeue_failed_notifications(
  max_retries INT DEFAULT 3,
  retry_delay_minutes INT DEFAULT 15
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  requeued_count INT;
BEGIN
  WITH requeued AS (
    UPDATE notification_events
    SET
      status = 'pending',
      retry_count = COALESCE(retry_count, 0) + 1,
      scheduled_for = NOW() + (retry_delay_minutes || ' minutes')::INTERVAL,
      updated_at = NOW(),
      error_message = NULL
    WHERE
      status = 'failed'
      AND COALESCE(retry_count, 0) < max_retries
      AND created_at > (NOW() - INTERVAL '24 hours')  -- Only retry recent failures
    RETURNING id
  )
  SELECT COUNT(*) INTO requeued_count FROM requeued;

  RETURN requeued_count;
END;
$$;

-- Function to update device token validation status
CREATE OR REPLACE FUNCTION validate_device_tokens()
RETURNS TABLE(
  validated_count INT,
  invalidated_count INT
)
LANGUAGE plpgsql
AS $$
DECLARE
  validated INT := 0;
  invalidated INT := 0;
BEGIN
  -- Mark tokens as invalid if they've had multiple recent delivery failures
  WITH failing_tokens AS (
    SELECT
      ud.push_token,
      COUNT(*) as failure_count
    FROM user_devices ud
    JOIN notification_deliveries nd ON nd.device_id = ud.device_id
    WHERE
      nd.status = 'failed'
      AND nd.delivered_at > (NOW() - INTERVAL '7 days')
      AND nd.error_message LIKE '%Invalid registration token%'
    GROUP BY ud.push_token
    HAVING COUNT(*) >= 3
  ),
  invalidated_tokens AS (
    INSERT INTO invalid_tokens (token, invalidated_at, reason)
    SELECT
      ft.push_token,
      NOW(),
      'Multiple delivery failures'
    FROM failing_tokens ft
    ON CONFLICT (token) DO NOTHING
    RETURNING token
  ),
  removed_devices AS (
    DELETE FROM user_devices
    WHERE push_token IN (SELECT token FROM invalidated_tokens)
    RETURNING device_id
  )
  SELECT COUNT(*) INTO invalidated FROM invalidated_tokens;

  -- Update last validated timestamp for remaining tokens
  UPDATE user_devices
  SET last_validated = NOW()
  WHERE
    push_token IS NOT NULL
    AND push_token NOT IN (SELECT token FROM invalid_tokens);

  SELECT COUNT(*) INTO validated
  FROM user_devices
  WHERE last_validated = NOW();

  RETURN QUERY SELECT validated, invalidated;
END;
$$;

-- Create indexes for better performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notification_events_claim
ON notification_events (status, scheduled_for, priority, created_at)
WHERE status = 'pending';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notification_events_analytics
ON notification_events (created_at, event_type, priority, status);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_devices_active
ON user_devices (user_id, is_active, last_active)
WHERE is_active = true;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notification_deliveries_analytics
ON notification_deliveries (delivered_at, status, notification_event_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_invalid_tokens_lookup
ON invalid_tokens (token);

-- Create or update the invalid_tokens table if it doesn't exist
CREATE TABLE IF NOT EXISTS invalid_tokens (
  token TEXT PRIMARY KEY,
  invalidated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add retry_count and claim_id columns if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name = 'notification_events'
                 AND column_name = 'retry_count') THEN
    ALTER TABLE notification_events ADD COLUMN retry_count INT DEFAULT 0;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name = 'notification_events'
                 AND column_name = 'claim_id') THEN
    ALTER TABLE notification_events ADD COLUMN claim_id UUID;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name = 'notification_events'
                 AND column_name = 'scheduled_for') THEN
    ALTER TABLE notification_events ADD COLUMN scheduled_for TIMESTAMPTZ DEFAULT NOW();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name = 'user_devices'
                 AND column_name = 'last_validated') THEN
    ALTER TABLE user_devices ADD COLUMN last_validated TIMESTAMPTZ;
  END IF;
END $$;