-- BACKWARD COMPATIBLE fix for clipper_inbox table structure
-- This migration preserves compatibility with existing app code

-- First, let's backup any existing data
CREATE TEMP TABLE IF NOT EXISTS clipper_inbox_backup AS 
SELECT * FROM clipper_inbox;

-- Check if we have the old structure (with payload_json) or new structure
DO $$
DECLARE
    has_payload_json BOOLEAN;
    has_title_column BOOLEAN;
BEGIN
    -- Check if payload_json column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'clipper_inbox' 
        AND column_name = 'payload_json'
    ) INTO has_payload_json;
    
    -- Check if title column exists (indicator of new structure)
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'clipper_inbox' 
        AND column_name = 'title'
    ) INTO has_title_column;
    
    -- Only proceed if we have old structure
    IF has_payload_json AND NOT has_title_column THEN
        RAISE NOTICE 'Migrating from old structure with payload_json to new structure';
        
        -- Drop the old table (cascade will remove policies and indexes)
        DROP TABLE IF EXISTS clipper_inbox CASCADE;
        
        -- Create the table with the new structure INCLUDING payload_json for backward compatibility
        CREATE TABLE public.clipper_inbox (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
            source_type TEXT NOT NULL CHECK (source_type IN ('email_in', 'web')),
            title TEXT,
            content TEXT,
            html TEXT,
            metadata JSONB DEFAULT '{}'::jsonb,
            payload_json JSONB DEFAULT '{}'::jsonb, -- Keep for backward compatibility!
            message_id TEXT,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW(),
            converted_to_note_id UUID,
            converted_at TIMESTAMPTZ
        );
        
        -- Migrate existing data from backup
        INSERT INTO clipper_inbox (
            id,
            user_id,
            source_type,
            title,
            content,
            html,
            metadata,
            payload_json, -- Keep original payload_json
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
                    ELSE jsonb_build_object(
                        'from', payload_json->>'from',
                        'to', payload_json->>'to',
                        'url', payload_json->>'url',
                        'clipped_at', payload_json->>'clipped_at'
                    )
                END,
                '{}'::jsonb
            ) as metadata,
            payload_json, -- Keep original for backward compatibility
            message_id,
            created_at
        FROM clipper_inbox_backup;
        
    ELSIF has_title_column AND NOT has_payload_json THEN
        RAISE NOTICE 'Adding payload_json column for backward compatibility';
        
        -- Add payload_json column if it doesn't exist
        ALTER TABLE clipper_inbox 
        ADD COLUMN IF NOT EXISTS payload_json JSONB DEFAULT '{}'::jsonb;
        
        -- Populate payload_json from existing columns for backward compatibility
        UPDATE clipper_inbox
        SET payload_json = CASE
            WHEN source_type = 'email_in' THEN
                jsonb_build_object(
                    'to', metadata->>'to',
                    'from', metadata->>'from',
                    'subject', title,
                    'text', content,
                    'html', html,
                    'message_id', message_id,
                    'attachments', metadata->'attachments',
                    'headers', metadata->'headers',
                    'received_at', metadata->>'received_at'
                )
            WHEN source_type = 'web' THEN
                jsonb_build_object(
                    'title', title,
                    'text', content,
                    'html', html,
                    'url', metadata->>'url',
                    'clipped_at', metadata->>'clipped_at',
                    'clip_timestamp', metadata->>'clip_timestamp'
                )
            ELSE '{}'::jsonb
        END
        WHERE payload_json = '{}'::jsonb OR payload_json IS NULL;
        
    ELSE
        RAISE NOTICE 'Table structure is already correct';
    END IF;
END $$;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_clipper_inbox_user_id ON public.clipper_inbox(user_id);
CREATE INDEX IF NOT EXISTS idx_clipper_inbox_created_at ON public.clipper_inbox(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clipper_inbox_source_type ON public.clipper_inbox(source_type);
CREATE INDEX IF NOT EXISTS idx_clipper_inbox_converted ON public.clipper_inbox(converted_to_note_id) WHERE converted_to_note_id IS NOT NULL;

-- Create unique index for message deduplication
CREATE UNIQUE INDEX IF NOT EXISTS idx_clipper_inbox_user_message_id 
    ON public.clipper_inbox(user_id, message_id) 
    WHERE message_id IS NOT NULL;

-- Enable RLS
ALTER TABLE public.clipper_inbox ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to recreate them
DROP POLICY IF EXISTS "Users can view own inbox items" ON public.clipper_inbox;
DROP POLICY IF EXISTS "Users can delete own inbox items" ON public.clipper_inbox;
DROP POLICY IF EXISTS "Users can update own inbox items" ON public.clipper_inbox;
DROP POLICY IF EXISTS "Service role can insert inbox items" ON public.clipper_inbox;
DROP POLICY IF EXISTS "clipper-inbox-select-own" ON public.clipper_inbox;
DROP POLICY IF EXISTS "clipper-inbox-delete-own" ON public.clipper_inbox;
DROP POLICY IF EXISTS "clipper_inbox_select_own" ON public.clipper_inbox;
DROP POLICY IF EXISTS "clipper_inbox_del_own" ON public.clipper_inbox;
DROP POLICY IF EXISTS "clipper_inbox_ins_own" ON public.clipper_inbox;

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

-- Create or replace function to sync payload_json with other columns
CREATE OR REPLACE FUNCTION sync_clipper_inbox_payload_json()
RETURNS TRIGGER AS $$
BEGIN
    -- On INSERT or UPDATE, sync payload_json with individual columns
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        -- If payload_json is empty but we have data in columns, build it
        IF (NEW.payload_json = '{}'::jsonb OR NEW.payload_json IS NULL) 
           AND (NEW.title IS NOT NULL OR NEW.content IS NOT NULL) THEN
            NEW.payload_json = CASE
                WHEN NEW.source_type = 'email_in' THEN
                    jsonb_build_object(
                        'to', NEW.metadata->>'to',
                        'from', NEW.metadata->>'from',
                        'subject', NEW.title,
                        'text', NEW.content,
                        'html', NEW.html,
                        'message_id', NEW.message_id,
                        'attachments', NEW.metadata->'attachments',
                        'headers', NEW.metadata->'headers',
                        'received_at', NEW.metadata->>'received_at'
                    )
                WHEN NEW.source_type = 'web' THEN
                    jsonb_build_object(
                        'title', NEW.title,
                        'text', NEW.content,
                        'html', NEW.html,
                        'url', NEW.metadata->>'url',
                        'clipped_at', NEW.metadata->>'clipped_at',
                        'clip_timestamp', NEW.metadata->>'clip_timestamp'
                    )
                ELSE NEW.payload_json
            END;
        -- If we have payload_json but empty columns, extract to columns
        ELSIF NEW.payload_json != '{}'::jsonb 
              AND (NEW.title IS NULL AND NEW.content IS NULL) THEN
            NEW.title = COALESCE(
                NEW.payload_json->>'title',
                NEW.payload_json->>'subject',
                CASE 
                    WHEN NEW.source_type = 'web' THEN 'Web Clip'
                    ELSE 'Email'
                END
            );
            NEW.content = COALESCE(
                NEW.payload_json->>'content',
                NEW.payload_json->>'text',
                NEW.payload_json->>'body',
                ''
            );
            NEW.html = COALESCE(
                NEW.payload_json->>'html',
                NEW.payload_json->>'html_body'
            );
            -- Merge metadata
            NEW.metadata = NEW.metadata || CASE
                WHEN NEW.source_type = 'email_in' THEN
                    jsonb_build_object(
                        'from', NEW.payload_json->>'from',
                        'to', NEW.payload_json->>'to',
                        'headers', NEW.payload_json->'headers',
                        'attachments', NEW.payload_json->'attachments',
                        'received_at', NEW.payload_json->>'received_at'
                    )
                WHEN NEW.source_type = 'web' THEN
                    jsonb_build_object(
                        'url', NEW.payload_json->>'url',
                        'clipped_at', NEW.payload_json->>'clipped_at',
                        'clip_timestamp', NEW.payload_json->>'clip_timestamp'
                    )
                ELSE '{}'::jsonb
            END;
        END IF;
        
        -- Always update the updated_at timestamp
        NEW.updated_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for syncing payload_json
DROP TRIGGER IF EXISTS sync_clipper_inbox_payload_json_trigger ON public.clipper_inbox;
CREATE TRIGGER sync_clipper_inbox_payload_json_trigger
    BEFORE INSERT OR UPDATE ON public.clipper_inbox
    FOR EACH ROW
    EXECUTE FUNCTION sync_clipper_inbox_payload_json();

-- Clean up temp table
DROP TABLE IF EXISTS clipper_inbox_backup;

-- Add comment explaining the dual structure
COMMENT ON TABLE public.clipper_inbox IS 'Inbox for emails and web clips. Uses both individual columns (title, content, html) and payload_json for backward compatibility.';
COMMENT ON COLUMN public.clipper_inbox.payload_json IS 'Legacy column for backward compatibility. Automatically synced with title, content, html, and metadata columns.';
