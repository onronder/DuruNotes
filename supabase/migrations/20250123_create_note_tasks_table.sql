-- =====================================================
-- CREATE NOTE_TASKS TABLE (CRITICAL)
-- =====================================================
-- This table was missing from the database
-- Required for task management functionality
-- =====================================================

BEGIN;

-- Create the note_tasks table
CREATE TABLE IF NOT EXISTS public.note_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    note_id UUID NOT NULL REFERENCES public.notes(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Task content
    content TEXT NOT NULL,
    content_hash TEXT, -- For duplicate detection
    
    -- Task properties
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
    priority INTEGER DEFAULT 0,
    position INTEGER DEFAULT 0,
    
    -- Dates
    due_date TIMESTAMPTZ,
    reminder_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    -- Hierarchy
    parent_id UUID REFERENCES public.note_tasks(id) ON DELETE CASCADE,
    
    -- Metadata
    labels JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted BOOLEAN NOT NULL DEFAULT false,
    
    -- Constraints
    CONSTRAINT valid_priority CHECK (priority >= 0 AND priority <= 5),
    CONSTRAINT valid_position CHECK (position >= 0)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_note_tasks_user_id 
ON public.note_tasks (user_id);

CREATE INDEX IF NOT EXISTS idx_note_tasks_note_id 
ON public.note_tasks (note_id);

CREATE INDEX IF NOT EXISTS idx_note_tasks_status 
ON public.note_tasks (status) 
WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_note_tasks_due_date 
ON public.note_tasks (due_date) 
WHERE due_date IS NOT NULL AND deleted = false;

CREATE INDEX IF NOT EXISTS idx_note_tasks_parent 
ON public.note_tasks (parent_id) 
WHERE parent_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_note_tasks_reminder 
ON public.note_tasks (reminder_at) 
WHERE reminder_at IS NOT NULL AND deleted = false;

-- Unique constraint to prevent duplicate tasks
CREATE UNIQUE INDEX IF NOT EXISTS uniq_note_tasks_note_contenthash_position 
ON public.note_tasks (note_id, content_hash, position) 
WHERE deleted = false AND content_hash IS NOT NULL;

-- GIN index for labels (JSONB)
CREATE INDEX IF NOT EXISTS idx_note_tasks_labels_gin 
ON public.note_tasks USING gin (labels);

-- Enable Row Level Security
ALTER TABLE public.note_tasks ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- SELECT: Users can only see their own tasks
CREATE POLICY "users_select_own_tasks"
ON public.note_tasks
FOR SELECT
USING (auth.uid() = user_id);

-- INSERT: Users can create their own tasks
CREATE POLICY "users_insert_own_tasks"
ON public.note_tasks
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- UPDATE: Users can update their own tasks
CREATE POLICY "users_update_own_tasks"
ON public.note_tasks
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- DELETE: Users can delete their own tasks
CREATE POLICY "users_delete_own_tasks"
ON public.note_tasks
FOR DELETE
USING (auth.uid() = user_id);

-- Create trigger to update updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_note_tasks_updated_at
BEFORE UPDATE ON public.note_tasks
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Grant permissions
GRANT ALL ON public.note_tasks TO authenticated;
GRANT SELECT ON public.note_tasks TO anon;

-- Add comments
COMMENT ON TABLE public.note_tasks IS 'Stores tasks associated with notes';
COMMENT ON COLUMN public.note_tasks.content_hash IS 'Hash of content for duplicate detection';
COMMENT ON COLUMN public.note_tasks.position IS 'Order of task within the note';
COMMENT ON COLUMN public.note_tasks.labels IS 'Array of labels/tags for the task';
COMMENT ON COLUMN public.note_tasks.metadata IS 'Additional metadata for the task';

-- Verification
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'note_tasks'
    ) THEN
        RAISE NOTICE '✅ note_tasks table created successfully';
        
        -- Verify indexes
        IF EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE schemaname = 'public' 
            AND tablename = 'note_tasks'
        ) THEN
            RAISE NOTICE '✅ Indexes created for note_tasks';
        END IF;
        
        -- Verify RLS
        IF EXISTS (
            SELECT 1 FROM pg_tables 
            WHERE schemaname = 'public' 
            AND tablename = 'note_tasks' 
            AND rowsecurity = true
        ) THEN
            RAISE NOTICE '✅ RLS enabled for note_tasks';
        END IF;
    ELSE
        RAISE EXCEPTION 'Failed to create note_tasks table';
    END IF;
END $$;

COMMIT;
