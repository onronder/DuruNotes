-- Migration: Add notification customization fields to reminders table
-- Created: 2025-11-18
-- Purpose: Fix sync error - add missing columns that code is trying to read/write

-- Add notification customization columns
ALTER TABLE reminders
  ADD COLUMN IF NOT EXISTS notification_title TEXT,
  ADD COLUMN IF NOT EXISTS notification_body TEXT,
  ADD COLUMN IF NOT EXISTS notification_image TEXT,
  ADD COLUMN IF NOT EXISTS time_zone TEXT;

-- Add column comments for documentation
COMMENT ON COLUMN reminders.notification_title IS 'Custom title for push notification (optional override)';
COMMENT ON COLUMN reminders.notification_body IS 'Custom body text for push notification (optional override)';
COMMENT ON COLUMN reminders.notification_image IS 'URL to image for rich notification display';
COMMENT ON COLUMN reminders.time_zone IS 'User timezone identifier for accurate reminder scheduling (e.g., America/New_York)';

-- Add helpful index on time_zone for potential timezone-based queries
CREATE INDEX IF NOT EXISTS idx_reminders_time_zone ON reminders(time_zone) WHERE time_zone IS NOT NULL;

-- Log migration completion
DO $$
BEGIN
  RAISE NOTICE 'Migration completed: Added notification_title, notification_body, notification_image, time_zone to reminders table';
END $$;
