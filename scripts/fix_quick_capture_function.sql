-- Fix the Quick Capture RPC function to work with encrypted columns
-- and remove the INSERT statement that causes volatility issues

-- Drop the existing function first
DROP FUNCTION IF EXISTS public.rpc_get_quick_capture_summaries(UUID, INTEGER);

-- Recreate the function with correct column names and as STABLE
CREATE OR REPLACE FUNCTION public.rpc_get_quick_capture_summaries(
    p_user_id UUID DEFAULT NULL,
    p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
    id UUID,
    title_enc TEXT,
    snippet TEXT,
    created_at TIMESTAMPTZ,
    metadata JSONB,
    is_pinned BOOLEAN,
    tags TEXT[]
)
LANGUAGE plpgsql
STABLE  -- Changed from SECURITY DEFINER to STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Use current user if not specified
    v_user_id := COALESCE(p_user_id, auth.uid());
    
    -- Check if user is authenticated
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;
    
    -- Check authorization
    IF v_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;
    
    -- Return recent widget captures
    RETURN QUERY
    SELECT 
        n.id,
        n.title_enc,
        -- Since props_enc is encrypted, we can't extract a snippet
        -- Return a placeholder or the encrypted metadata info
        CASE 
            WHEN n.encrypted_metadata IS NOT NULL 
            THEN 'Widget capture'
            ELSE 'Quick capture'
        END as snippet,
        n.created_at,
        -- Parse encrypted_metadata safely (TEXT column containing JSON)
        CASE 
            WHEN n.encrypted_metadata IS NOT NULL 
            THEN n.encrypted_metadata::json::jsonb
            ELSE '{}'::jsonb
        END as metadata,
        COALESCE(n.is_pinned, false) as is_pinned,
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
        COALESCE(n.is_pinned, false) DESC,  -- Pinned notes first
        n.created_at DESC   -- Then by recency
    LIMIT p_limit;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.rpc_get_quick_capture_summaries TO authenticated;

-- Revoke from anonymous users
REVOKE EXECUTE ON FUNCTION public.rpc_get_quick_capture_summaries FROM anon;

-- Add comment
COMMENT ON FUNCTION public.rpc_get_quick_capture_summaries IS 
'Retrieves recent quick capture notes created from widgets with full metadata and tags';

-- Also check if is_pinned column exists, if not add it
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'notes' 
        AND column_name = 'is_pinned'
    ) THEN
        ALTER TABLE public.notes ADD COLUMN is_pinned BOOLEAN DEFAULT false;
    END IF;
END $$;
