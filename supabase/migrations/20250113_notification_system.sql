-- =====================================================
-- Production-Grade Notification System Database Schema
-- =====================================================

-- Drop existing objects if they exist (for clean migration)
DROP TRIGGER IF EXISTS email_inbox_notification_trigger ON public.clipper_inbox CASCADE;
DROP TRIGGER IF EXISTS note_share_notification_trigger ON public.notes CASCADE;
DROP FUNCTION IF EXISTS public.trigger_notification_event CASCADE;
DROP FUNCTION IF EXISTS public.process_notification_queue CASCADE;
DROP FUNCTION IF EXISTS public.send_push_notification CASCADE;
DROP FUNCTION IF EXISTS public.cleanup_old_notifications CASCADE;

-- =====================================================
-- 1. Notification Events Queue (Core Event System)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.notification_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    event_source TEXT NOT NULL, -- 'email_inbox', 'web_clipper', 'note_event', etc.
    priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'critical')),
    payload JSONB NOT NULL DEFAULT '{}',
    
    -- Scheduling and processing
    scheduled_for TIMESTAMPTZ DEFAULT now() NOT NULL,
    processed_at TIMESTAMPTZ,
    
    -- Status tracking
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'delivered', 'failed', 'cancelled')),
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 5,
    
    -- Deduplication
    dedupe_key TEXT,
    
    -- Error tracking
    error_message TEXT,
    error_details JSONB,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    
    -- Unique constraint for deduplication
    UNIQUE(user_id, dedupe_key)
);

-- Indexes for efficient queue processing
CREATE INDEX IF NOT EXISTS idx_notification_events_status_scheduled 
    ON public.notification_events(status, scheduled_for) 
    WHERE status IN ('pending', 'processing');
    
CREATE INDEX IF NOT EXISTS idx_notification_events_user_id 
    ON public.notification_events(user_id);
    
CREATE INDEX IF NOT EXISTS idx_notification_events_created_at 
    ON public.notification_events(created_at);

CREATE INDEX IF NOT EXISTS idx_notification_events_dedupe 
    ON public.notification_events(user_id, dedupe_key) 
    WHERE dedupe_key IS NOT NULL;

-- =====================================================
-- 2. Notification Templates
-- =====================================================
CREATE TABLE IF NOT EXISTS public.notification_templates (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    event_type TEXT NOT NULL UNIQUE,
    
    -- Template content for different channels
    push_template JSONB DEFAULT '{}',
    email_template JSONB DEFAULT '{}',
    sms_template JSONB DEFAULT '{}',
    
    -- Configuration
    enabled BOOLEAN DEFAULT true,
    priority TEXT DEFAULT 'normal',
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Insert default templates
INSERT INTO public.notification_templates (event_type, push_template, priority) VALUES
    ('email_received', '{"title": "New Email", "body": "From {{from}}: {{subject}}", "icon": "email", "sound": "default", "badge": 1}', 'high'),
    ('web_clip_saved', '{"title": "Web Clip Saved", "body": "{{title}} has been saved to your notes", "icon": "bookmark", "sound": "default"}', 'normal'),
    ('note_shared', '{"title": "Note Shared", "body": "{{sharer_name}} shared a note with you", "icon": "share", "sound": "default"}', 'high'),
    ('reminder_due', '{"title": "Reminder", "body": "{{title}}", "icon": "bell", "sound": "reminder", "badge": 1}', 'critical'),
    ('note_mentioned', '{"title": "You were mentioned", "body": "{{user_name}} mentioned you in {{note_title}}", "icon": "mention", "sound": "default"}', 'high'),
    ('folder_shared', '{"title": "Folder Shared", "body": "{{sharer_name}} shared {{folder_name}} with you", "icon": "folder", "sound": "default"}', 'high'),
    ('sync_conflict', '{"title": "Sync Conflict", "body": "Conflict detected in {{note_title}}", "icon": "warning", "sound": "default"}', 'normal')
ON CONFLICT (event_type) DO NOTHING;

-- =====================================================
-- 3. Notification Deliveries (Tracking & Analytics)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.notification_deliveries (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    event_id UUID NOT NULL REFERENCES public.notification_events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Delivery details
    channel TEXT NOT NULL CHECK (channel IN ('push', 'email', 'sms', 'in_app')),
    device_id TEXT, -- For push notifications
    
    -- Status tracking
    status TEXT NOT NULL CHECK (status IN ('sent', 'delivered', 'failed', 'bounced', 'opened', 'clicked')),
    
    -- Provider response
    provider_response JSONB,
    provider_message_id TEXT,
    
    -- Timestamps
    sent_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    delivered_at TIMESTAMPTZ,
    opened_at TIMESTAMPTZ,
    clicked_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    
    -- Error tracking
    error_code TEXT,
    error_message TEXT,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Indexes for analytics
CREATE INDEX IF NOT EXISTS idx_notification_deliveries_event_id 
    ON public.notification_deliveries(event_id);
    
CREATE INDEX IF NOT EXISTS idx_notification_deliveries_user_channel 
    ON public.notification_deliveries(user_id, channel);
    
CREATE INDEX IF NOT EXISTS idx_notification_deliveries_sent_at 
    ON public.notification_deliveries(sent_at);

-- =====================================================
-- 4. User Notification Preferences
-- =====================================================
CREATE TABLE IF NOT EXISTS public.notification_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Global settings
    enabled BOOLEAN DEFAULT true,
    
    -- Channel preferences
    push_enabled BOOLEAN DEFAULT true,
    email_enabled BOOLEAN DEFAULT false,
    sms_enabled BOOLEAN DEFAULT false,
    in_app_enabled BOOLEAN DEFAULT true,
    
    -- Event type preferences (JSONB for flexibility)
    event_preferences JSONB DEFAULT '{}',
    
    -- Quiet hours (stored as HH:MM in user's timezone)
    quiet_hours_enabled BOOLEAN DEFAULT false,
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    timezone TEXT DEFAULT 'UTC',
    
    -- Do Not Disturb
    dnd_enabled BOOLEAN DEFAULT false,
    dnd_until TIMESTAMPTZ,
    
    -- Batching preferences
    batch_emails BOOLEAN DEFAULT false,
    batch_frequency TEXT DEFAULT 'daily' CHECK (batch_frequency IN ('realtime', 'hourly', 'daily', 'weekly')),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    
    UNIQUE(user_id)
);

-- Index for user lookups
CREATE INDEX IF NOT EXISTS idx_notification_preferences_user_id 
    ON public.notification_preferences(user_id);

-- =====================================================
-- 5. RLS Policies
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE public.notification_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

-- Notification Events policies
CREATE POLICY "Users can view their own notification events"
    ON public.notification_events FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Service role can manage all notification events"
    ON public.notification_events FOR ALL
    USING (auth.role() = 'service_role');

-- Notification Templates policies (read-only for users)
CREATE POLICY "Anyone can view notification templates"
    ON public.notification_templates FOR SELECT
    USING (true);

CREATE POLICY "Service role can manage notification templates"
    ON public.notification_templates FOR ALL
    USING (auth.role() = 'service_role');

-- Notification Deliveries policies
CREATE POLICY "Users can view their own deliveries"
    ON public.notification_deliveries FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Service role can manage all deliveries"
    ON public.notification_deliveries FOR ALL
    USING (auth.role() = 'service_role');

-- Notification Preferences policies
CREATE POLICY "Users can view their own preferences"
    ON public.notification_preferences FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can update their own preferences"
    ON public.notification_preferences FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can insert their own preferences"
    ON public.notification_preferences FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Service role can manage all preferences"
    ON public.notification_preferences FOR ALL
    USING (auth.role() = 'service_role');

-- =====================================================
-- 6. Helper Functions
-- =====================================================

-- Function to create a notification event
CREATE OR REPLACE FUNCTION public.create_notification_event(
    p_user_id UUID,
    p_event_type TEXT,
    p_event_source TEXT,
    p_payload JSONB DEFAULT '{}',
    p_priority TEXT DEFAULT 'normal',
    p_scheduled_for TIMESTAMPTZ DEFAULT now(),
    p_dedupe_key TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_event_id UUID;
    v_template notification_templates;
BEGIN
    -- Check if template exists and is enabled
    SELECT * INTO v_template
    FROM notification_templates
    WHERE event_type = p_event_type
    AND enabled = true;
    
    IF NOT FOUND THEN
        RAISE WARNING 'No enabled template found for event type: %', p_event_type;
        RETURN NULL;
    END IF;
    
    -- Check user preferences
    IF NOT EXISTS (
        SELECT 1 FROM notification_preferences
        WHERE user_id = p_user_id
        AND enabled = true
        AND (
            event_preferences IS NULL 
            OR event_preferences = '{}'
            OR COALESCE((event_preferences->p_event_type->>'enabled')::boolean, true) = true
        )
    ) THEN
        -- User has disabled this notification type
        RETURN NULL;
    END IF;
    
    -- Insert the event (with deduplication)
    INSERT INTO notification_events (
        user_id,
        event_type,
        event_source,
        payload,
        priority,
        scheduled_for,
        dedupe_key
    ) VALUES (
        p_user_id,
        p_event_type,
        p_event_source,
        p_payload,
        COALESCE(p_priority, v_template.priority, 'normal'),
        p_scheduled_for,
        p_dedupe_key
    )
    ON CONFLICT (user_id, dedupe_key) 
    WHERE dedupe_key IS NOT NULL
    DO UPDATE SET
        payload = EXCLUDED.payload,
        scheduled_for = EXCLUDED.scheduled_for,
        updated_at = now()
    RETURNING id INTO v_event_id;
    
    RETURN v_event_id;
END;
$$;

-- Function to trigger notification events (called from triggers)
CREATE OR REPLACE FUNCTION public.trigger_notification_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_event_type TEXT;
    v_event_source TEXT;
    v_payload JSONB;
    v_dedupe_key TEXT;
BEGIN
    -- Determine event details based on trigger source
    IF TG_TABLE_NAME = 'clipper_inbox' THEN
        v_user_id := NEW.user_id;
        v_event_source := NEW.source_type;
        
        IF NEW.source_type = 'email_in' THEN
            v_event_type := 'email_received';
            v_payload := jsonb_build_object(
                'inbox_id', NEW.id,
                'from', NEW.payload_json->>'from',
                'subject', NEW.payload_json->>'subject',
                'preview', LEFT(COALESCE(NEW.payload_json->>'text', ''), 100),
                'message_id', NEW.message_id
            );
            v_dedupe_key := 'email_' || NEW.message_id;
        ELSIF NEW.source_type = 'web' THEN
            v_event_type := 'web_clip_saved';
            v_payload := jsonb_build_object(
                'inbox_id', NEW.id,
                'title', NEW.payload_json->>'title',
                'url', NEW.payload_json->>'url',
                'clipped_at', NEW.payload_json->>'clipped_at'
            );
            v_dedupe_key := 'webclip_' || NEW.id::text;
        ELSE
            -- Unknown source type, skip
            RETURN NEW;
        END IF;
        
        -- Create the notification event
        PERFORM create_notification_event(
            v_user_id,
            v_event_type,
            v_event_source,
            v_payload,
            'normal',
            now(),
            v_dedupe_key
        );
    END IF;
    
    RETURN NEW;
END;
$$;

-- =====================================================
-- 7. Triggers for Automatic Notifications
-- =====================================================

-- Trigger for email inbox notifications
CREATE TRIGGER email_inbox_notification_trigger
    AFTER INSERT ON public.clipper_inbox
    FOR EACH ROW
    WHEN (NEW.source_type IN ('email_in', 'web'))
    EXECUTE FUNCTION trigger_notification_event();

-- =====================================================
-- 8. Maintenance Functions
-- =====================================================

-- Function to cleanup old notifications
CREATE OR REPLACE FUNCTION public.cleanup_old_notifications(
    p_days_old INTEGER DEFAULT 30
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    -- Delete old processed notifications
    DELETE FROM notification_events
    WHERE created_at < (now() - (p_days_old || ' days')::INTERVAL)
    AND status IN ('delivered', 'failed', 'cancelled');
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RETURN v_deleted_count;
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.create_notification_event TO service_role;
GRANT EXECUTE ON FUNCTION public.trigger_notification_event TO service_role;
GRANT EXECUTE ON FUNCTION public.cleanup_old_notifications TO service_role;

-- =====================================================
-- 9. Update Triggers
-- =====================================================

-- Auto-update updated_at columns
CREATE OR REPLACE FUNCTION public.update_notification_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER update_notification_events_updated_at
    BEFORE UPDATE ON public.notification_events
    FOR EACH ROW
    EXECUTE FUNCTION public.update_notification_updated_at();

CREATE TRIGGER update_notification_templates_updated_at
    BEFORE UPDATE ON public.notification_templates
    FOR EACH ROW
    EXECUTE FUNCTION public.update_notification_updated_at();

CREATE TRIGGER update_notification_preferences_updated_at
    BEFORE UPDATE ON public.notification_preferences
    FOR EACH ROW
    EXECUTE FUNCTION public.update_notification_updated_at();

-- =====================================================
-- 10. Analytics Views
-- =====================================================

-- View for notification delivery stats
CREATE OR REPLACE VIEW public.notification_stats AS
SELECT 
    ne.user_id,
    ne.event_type,
    ne.event_source,
    DATE(ne.created_at) as date,
    COUNT(DISTINCT ne.id) as events_created,
    COUNT(DISTINCT CASE WHEN ne.status = 'delivered' THEN ne.id END) as events_delivered,
    COUNT(DISTINCT CASE WHEN ne.status = 'failed' THEN ne.id END) as events_failed,
    COUNT(DISTINCT nd.id) as deliveries_attempted,
    COUNT(DISTINCT CASE WHEN nd.status = 'delivered' THEN nd.id END) as deliveries_successful,
    AVG(EXTRACT(EPOCH FROM (nd.delivered_at - nd.sent_at))) as avg_delivery_time_seconds
FROM notification_events ne
LEFT JOIN notification_deliveries nd ON ne.id = nd.event_id
GROUP BY ne.user_id, ne.event_type, ne.event_source, DATE(ne.created_at);

-- Grant read access to authenticated users for their own stats
GRANT SELECT ON public.notification_stats TO authenticated;

-- Comments for documentation
COMMENT ON TABLE public.notification_events IS 'Central queue for all notification events';
COMMENT ON TABLE public.notification_templates IS 'Templates for different notification types';
COMMENT ON TABLE public.notification_deliveries IS 'Tracking and analytics for notification delivery';
COMMENT ON TABLE public.notification_preferences IS 'User preferences for notifications';
COMMENT ON FUNCTION public.create_notification_event IS 'Create a new notification event with preference checking';
COMMENT ON FUNCTION public.trigger_notification_event IS 'Trigger function for automatic notifications';
COMMENT ON FUNCTION public.cleanup_old_notifications IS 'Clean up old notification records';
COMMENT ON VIEW public.notification_stats IS 'Analytics view for notification statistics';
