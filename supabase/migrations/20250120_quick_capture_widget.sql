-- Quick Capture Widget Infrastructure Migration
-- Production-grade implementation for billion-dollar app
-- Author: Senior Architect
-- Date: 2025-01-20

-- ============================================
-- PART 1: PERFORMANCE INDEXES
-- ============================================

-- Index for filtering notes by metadata source
-- Since encrypted_metadata is TEXT containing JSON, we use a functional index
CREATE INDEX IF NOT EXISTS idx_notes_metadata_source 
ON public.notes ((encrypted_metadata::json->>'source')) 
WHERE encrypted_metadata IS NOT NULL;

-- Specialized index for widget-tagged notes
-- Partial index for better performance on widget-specific queries
CREATE INDEX IF NOT EXISTS idx_notes_metadata_widget 
ON public.notes ((encrypted_metadata::json->>'source')) 
WHERE encrypted_metadata IS NOT NULL 
  AND encrypted_metadata::json->>'source' = 'widget';

-- Composite index for user-specific widget notes with recent ordering
-- Critical for widget cache updates and recent captures display
CREATE INDEX IF NOT EXISTS idx_notes_widget_recent 
ON public.notes (user_id, created_at DESC) 
WHERE deleted = false 
  AND encrypted_metadata IS NOT NULL
  AND encrypted_metadata::json->>'source' = 'widget';

-- ============================================
-- PART 2: RATE LIMITING TABLE
-- ============================================

-- Create rate limiting table for widget capture throttling
CREATE TABLE IF NOT EXISTS public.rate_limits (
    key TEXT PRIMARY KEY,
    count INTEGER NOT NULL DEFAULT 0,
    window_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Add constraint to ensure count is non-negative
    CONSTRAINT positive_count CHECK (count >= 0)
);

-- Index for efficient cleanup of old rate limit entries
CREATE INDEX IF NOT EXISTS idx_rate_limits_window_start 
ON public.rate_limits (window_start);

-- Enable RLS on rate_limits table
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

-- RLS policy: Users can only manage their own rate limits
CREATE POLICY "Users can manage own rate limits" ON public.rate_limits
    FOR ALL
    USING (
        -- Extract user_id from key format: 'widget_capture:user_id'
        split_part(key, ':', 2) = auth.uid()::text
    )
    WITH CHECK (
        split_part(key, ':', 2) = auth.uid()::text
    );

-- ============================================
-- PART 3: ANALYTICS EVENTS TABLE
-- ============================================

-- Create analytics events table if not exists
CREATE TABLE IF NOT EXISTS public.analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    properties JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for analytics events table
CREATE INDEX IF NOT EXISTS idx_analytics_event_type ON public.analytics_events (event_type);
CREATE INDEX IF NOT EXISTS idx_analytics_user_id ON public.analytics_events (user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_created_at ON public.analytics_events (created_at DESC);

-- Enable RLS on analytics_events
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

-- RLS policy: Users can only insert their own events
CREATE POLICY "Users can insert own analytics events" ON public.analytics_events
    FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- RLS policy: Service role can read all events
CREATE POLICY "Service role can read all analytics events" ON public.analytics_events
    FOR SELECT
    USING (auth.role() = 'service_role');

-- ============================================
-- PART 4: QUICK CAPTURE RPC FUNCTION
-- ============================================

-- Function for retrieving recent widget captures with optimized performance
CREATE OR REPLACE FUNCTION public.rpc_get_quick_capture_summaries(
    p_user_id UUID DEFAULT NULL,
    p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    snippet TEXT,
    created_at TIMESTAMPTZ,
    metadata JSONB,
    is_pinned BOOLEAN,
    tags TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE  -- Function returns same results for same inputs
PARALLEL SAFE  -- Can be executed in parallel
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Use current user if not specified
    v_user_id := COALESCE(p_user_id, auth.uid());
    
    -- Validate user authorization
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' 
            USING HINT = 'User must be authenticated to access quick captures';
    END IF;
    
    -- Check RLS: user can only access their own captures
    IF v_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied' 
            USING HINT = 'Users can only access their own quick captures',
            ERRCODE = 'insufficient_privilege';
    END IF;
    
    -- Validate limit parameter
    IF p_limit < 1 OR p_limit > 100 THEN
        RAISE EXCEPTION 'Invalid limit parameter' 
            USING HINT = 'Limit must be between 1 and 100';
    END IF;
    
    RETURN QUERY
    SELECT 
        n.id,
        n.title,
        -- Safely extract first 100 chars with ellipsis if truncated
        CASE 
            WHEN LENGTH(n.body) > 100 
            THEN LEFT(n.body, 97) || '...'
            ELSE n.body
        END as snippet,
        n.created_at,
        -- Parse encrypted_metadata safely (TEXT column containing JSON)
        CASE 
            WHEN n.encrypted_metadata IS NOT NULL 
            THEN n.encrypted_metadata::json::jsonb
            ELSE '{}'::jsonb
        END as metadata,
        n.is_pinned,
        -- Get associated tags
        COALESCE(
            ARRAY(
                SELECT nt.tag 
                FROM public.note_tags nt 
                WHERE nt.note_id = n.id 
                ORDER BY nt.tag
            ), 
            ARRAY[]::TEXT[]
        ) as tags
    FROM public.notes n
    WHERE 
        n.user_id = v_user_id
        AND n.deleted = false
        AND n.encrypted_metadata IS NOT NULL
        AND n.encrypted_metadata::json->>'source' = 'widget'
    ORDER BY 
        n.is_pinned DESC,  -- Pinned notes first
        n.created_at DESC   -- Then by recency
    LIMIT p_limit;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error for monitoring
        INSERT INTO public.analytics_events (user_id, event_type, properties)
        VALUES (
            v_user_id,
            'quick_capture.rpc_error',
            jsonb_build_object(
                'error_code', SQLSTATE,
                'error_message', SQLERRM,
                'function', 'rpc_get_quick_capture_summaries'
            )
        );
        -- Re-raise the exception
        RAISE;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.rpc_get_quick_capture_summaries TO authenticated;

-- Revoke execute from anon to ensure authentication
REVOKE EXECUTE ON FUNCTION public.rpc_get_quick_capture_summaries FROM anon;

-- ============================================
-- PART 5: CLEANUP FUNCTION FOR RATE LIMITS
-- ============================================

-- Function to clean up old rate limit entries
CREATE OR REPLACE FUNCTION public.cleanup_old_rate_limits()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    -- Delete rate limit entries older than 1 hour
    DELETE FROM public.rate_limits
    WHERE window_start < NOW() - INTERVAL '1 hour';
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    -- Log cleanup activity
    IF v_deleted_count > 0 THEN
        INSERT INTO public.analytics_events (
            user_id,
            event_type,
            properties
        ) VALUES (
            '00000000-0000-0000-0000-000000000000'::UUID,  -- System user
            'system.rate_limits_cleanup',
            jsonb_build_object('deleted_count', v_deleted_count)
        );
    END IF;
    
    RETURN v_deleted_count;
END;
$$;

-- ============================================
-- PART 6: TRIGGER FOR UPDATED_AT
-- ============================================

-- Create trigger function for updating updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger to rate_limits table
CREATE TRIGGER update_rate_limits_updated_at
    BEFORE UPDATE ON public.rate_limits
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================
-- PART 7: PERFORMANCE STATISTICS
-- ============================================

-- Create statistics for better query planning
ANALYZE public.notes;
ANALYZE public.note_tags;

-- ============================================
-- PART 8: COMMENTS FOR DOCUMENTATION
-- ============================================

COMMENT ON FUNCTION public.rpc_get_quick_capture_summaries IS 
    'Retrieves recent quick capture notes created from home screen widgets. 
     Returns up to p_limit notes with metadata, tags, and pin status.
     Enforces RLS to ensure users can only access their own captures.';

COMMENT ON TABLE public.rate_limits IS 
    'Tracks rate limiting for various operations including widget captures.
     Key format: operation_type:user_id (e.g., widget_capture:user_uuid)';

COMMENT ON TABLE public.analytics_events IS 
    'Stores analytics events for monitoring and insights.
     Used for tracking widget usage, errors, and performance metrics.';

COMMENT ON INDEX idx_notes_metadata_source IS 
    'Optimizes queries filtering notes by metadata source (e.g., widget, email, web)';

COMMENT ON INDEX idx_notes_metadata_widget IS 
    'Specialized index for high-performance widget note queries';

COMMENT ON INDEX idx_notes_widget_recent IS 
    'Composite index for efficient retrieval of recent widget captures per user';

-- ============================================
-- PART 9: VALIDATION
-- ============================================

-- Validate that all required tables exist
DO $$
BEGIN
    -- Check notes table
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables 
                   WHERE table_schema = 'public' AND table_name = 'notes') THEN
        RAISE EXCEPTION 'Required table "notes" does not exist';
    END IF;
    
    -- Check note_tags table
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables 
                   WHERE table_schema = 'public' AND table_name = 'note_tags') THEN
        RAISE EXCEPTION 'Required table "note_tags" does not exist';
    END IF;
    
    -- Verify encrypted_metadata column exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'notes' 
                   AND column_name = 'encrypted_metadata') THEN
        RAISE EXCEPTION 'Required column "encrypted_metadata" does not exist in notes table';
    END IF;
    
    RAISE NOTICE 'Quick Capture Widget migration completed successfully';
END;
$$;
