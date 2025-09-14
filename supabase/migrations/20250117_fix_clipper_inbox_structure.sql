-- Fix clipper_inbox table structure to match what the app expects
-- This migration transforms the payload_json structure to proper columns

-- First, let's backup any existing data
CREATE TEMP TABLE clipper_inbox_backup AS 
SELECT * FROM clipper_inbox;

-- Drop the old table (cascade will remove policies and indexes)
DROP TABLE IF EXISTS clipper_inbox CASCADE;

-- Create the table with the correct structure
CREATE TABLE public.clipper_inbox (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    source_type TEXT NOT NULL CHECK (source_type IN ('email_in', 'web')),
    title TEXT,
    content TEXT,
    html TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    message_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    converted_to_note_id UUID,
    converted_at TIMESTAMPTZ
);

-- Migrate existing data from backup (extract from payload_json)
INSERT INTO clipper_inbox (
    id,
    user_id,
    source_type,
    title,
    content,
    html,
    metadata,
    message_id,
    created_at
)
SELECT 
    id,
    user_id,
    source_type,
    COALESCE(
        payload_json->>'title',
        payload_json->>'subject',
        CASE 
            WHEN source_type = 'web' THEN 'Web Clip'
            ELSE 'Email'
        END
    ) as title,
    COALESCE(
        payload_json->>'content',
        payload_json->>'text',
        payload_json->>'body',
        ''
    ) as content,
    COALESCE(
        payload_json->>'html',
        payload_json->>'html_body',
        null
    ) as html,
    COALESCE(
        CASE 
            WHEN payload_json ? 'metadata' THEN payload_json->'metadata'
            ELSE payload_json
        END,
        '{}'::jsonb
    ) as metadata,
    message_id,
    created_at
FROM clipper_inbox_backup;

-- Create indexes for performance
CREATE INDEX idx_clipper_inbox_user_id ON public.clipper_inbox(user_id);
CREATE INDEX idx_clipper_inbox_created_at ON public.clipper_inbox(created_at DESC);
CREATE INDEX idx_clipper_inbox_source_type ON public.clipper_inbox(source_type);
CREATE INDEX idx_clipper_inbox_converted ON public.clipper_inbox(converted_to_note_id) WHERE converted_to_note_id IS NOT NULL;

-- Create unique index for message deduplication
CREATE UNIQUE INDEX idx_clipper_inbox_user_message_id 
    ON public.clipper_inbox(user_id, message_id) 
    WHERE message_id IS NOT NULL;

-- Enable RLS
ALTER TABLE public.clipper_inbox ENABLE ROW LEVEL SECURITY;

-- Create comprehensive RLS policies
CREATE POLICY "Users can view own inbox items" 
    ON public.clipper_inbox
    FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own inbox items" 
    ON public.clipper_inbox
    FOR DELETE 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own inbox items" 
    ON public.clipper_inbox
    FOR UPDATE 
    USING (auth.uid() = user_id);

-- Service role and Edge functions can insert
CREATE POLICY "Service role can insert inbox items" 
    ON public.clipper_inbox
    FOR INSERT 
    WITH CHECK (true);

-- Create a function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_clipper_inbox_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
CREATE TRIGGER update_clipper_inbox_updated_at
    BEFORE UPDATE ON public.clipper_inbox
    FOR EACH ROW
    EXECUTE FUNCTION update_clipper_inbox_updated_at();

-- Add a helper view for easier querying
CREATE OR REPLACE VIEW public.inbox_items_view AS
SELECT 
    ci.id,
    ci.user_id,
    ci.source_type,
    ci.title,
    ci.content,
    ci.html,
    ci.metadata,
    ci.message_id,
    ci.created_at,
    ci.updated_at,
    ci.converted_to_note_id,
    ci.converted_at,
    CASE 
        WHEN ci.converted_to_note_id IS NOT NULL THEN true
        ELSE false
    END as is_converted,
    COALESCE(ci.title, 
        CASE 
            WHEN ci.source_type = 'email_in' THEN 'Email: ' || COALESCE((ci.metadata->>'from')::text, 'Unknown Sender')
            WHEN ci.source_type = 'web' THEN 'Web: ' || COALESCE((ci.metadata->>'url')::text, 'Unknown URL')
            ELSE 'Untitled'
        END
    ) as display_title
FROM public.clipper_inbox ci;

-- Grant permissions on the view
GRANT SELECT ON public.inbox_items_view TO authenticated;

-- Clean up temp table
DROP TABLE IF EXISTS clipper_inbox_backup;
