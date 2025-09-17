-- Create note_tasks table for task management
CREATE TABLE IF NOT EXISTS public.note_tasks (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    note_id TEXT NOT NULL,
    content TEXT NOT NULL,
    status INTEGER NOT NULL DEFAULT 0, -- 0: open, 1: completed, 2: cancelled
    priority INTEGER NOT NULL DEFAULT 1, -- 0: low, 1: medium, 2: high, 3: urgent
    due_date TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    completed_by TEXT,
    position INTEGER NOT NULL DEFAULT 0,
    content_hash TEXT NOT NULL,
    reminder_id INTEGER,
    labels JSONB,
    notes TEXT,
    estimated_minutes INTEGER,
    actual_minutes INTEGER,
    parent_task_id TEXT REFERENCES public.note_tasks(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_note_tasks_user_id ON public.note_tasks (user_id);
CREATE INDEX IF NOT EXISTS idx_note_tasks_note_id ON public.note_tasks (note_id);
CREATE INDEX IF NOT EXISTS idx_note_tasks_status ON public.note_tasks (status) WHERE deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_note_tasks_due_date ON public.note_tasks (due_date) WHERE status = 0 AND deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_note_tasks_parent ON public.note_tasks (parent_task_id) WHERE parent_task_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_note_tasks_reminder ON public.note_tasks (reminder_id) WHERE reminder_id IS NOT NULL;
-- Ensure unique identity per note using stable content hash
DO $$
BEGIN
  -- Drop prior unique index if it exists (content_hash only could block valid duplicates)
  IF EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE schemaname = 'public' AND indexname = 'uniq_note_tasks_note_contenthash'
  ) THEN
    EXECUTE 'DROP INDEX IF EXISTS public.uniq_note_tasks_note_contenthash';
  END IF;

  -- Create safer unique index that allows same content on different positions
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE schemaname = 'public' AND indexname = 'uniq_note_tasks_note_contenthash_position'
  ) THEN
    EXECUTE 'CREATE UNIQUE INDEX uniq_note_tasks_note_contenthash_position
             ON public.note_tasks (note_id, content_hash, position)
             WHERE deleted = FALSE';
  END IF;
END $$;


-- Enable RLS
ALTER TABLE public.note_tasks ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their own tasks" ON public.note_tasks
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own tasks" ON public.note_tasks
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tasks" ON public.note_tasks
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own tasks" ON public.note_tasks
    FOR DELETE USING (auth.uid() = user_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_note_tasks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-update updated_at
CREATE TRIGGER update_note_tasks_updated_at_trigger
    BEFORE UPDATE ON public.note_tasks
    FOR EACH ROW
    EXECUTE FUNCTION update_note_tasks_updated_at();

-- Create function to get task statistics
CREATE OR REPLACE FUNCTION get_task_statistics(p_user_id UUID)
RETURNS TABLE (
    total_open INTEGER,
    total_overdue INTEGER,
    due_today INTEGER,
    completed_today INTEGER,
    completed_this_week INTEGER,
    high_priority INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*) FILTER (WHERE status = 0 AND deleted = FALSE) AS total_open,
        COUNT(*) FILTER (WHERE status = 0 AND due_date < NOW() AND deleted = FALSE) AS total_overdue,
        COUNT(*) FILTER (WHERE status = 0 AND due_date::DATE = CURRENT_DATE AND deleted = FALSE) AS due_today,
        COUNT(*) FILTER (WHERE status = 1 AND completed_at::DATE = CURRENT_DATE AND deleted = FALSE) AS completed_today,
        COUNT(*) FILTER (WHERE status = 1 AND completed_at >= DATE_TRUNC('week', CURRENT_DATE) AND deleted = FALSE) AS completed_this_week,
        COUNT(*) FILTER (WHERE status = 0 AND priority >= 2 AND deleted = FALSE) AS high_priority
    FROM public.note_tasks
    WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get tasks by date range for calendar view
CREATE OR REPLACE FUNCTION get_tasks_by_date_range(
    p_user_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    task_date DATE,
    tasks JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        due_date::DATE AS task_date,
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', id,
                'note_id', note_id,
                'content', content,
                'status', status,
                'priority', priority,
                'due_date', due_date,
                'completed_at', completed_at
            ) ORDER BY priority DESC, due_date
        ) AS tasks
    FROM public.note_tasks
    WHERE 
        user_id = p_user_id
        AND deleted = FALSE
        AND due_date::DATE BETWEEN p_start_date AND p_end_date
    GROUP BY due_date::DATE
    ORDER BY task_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create view for overdue tasks
CREATE OR REPLACE VIEW overdue_tasks AS
SELECT *
FROM public.note_tasks
WHERE 
    status = 0 
    AND deleted = FALSE
    AND due_date < NOW()
ORDER BY priority DESC, due_date;

-- Grant access to the view
GRANT SELECT ON overdue_tasks TO authenticated;

-- Create function to bulk update task positions (for reordering)
CREATE OR REPLACE FUNCTION update_task_positions(
    p_user_id UUID,
    p_positions JSONB
)
RETURNS VOID AS $$
DECLARE
    task_record RECORD;
BEGIN
    FOR task_record IN SELECT * FROM JSONB_ARRAY_ELEMENTS(p_positions)
    LOOP
        UPDATE public.note_tasks
        SET position = (task_record.value->>'position')::INTEGER,
            updated_at = NOW()
        WHERE 
            id = task_record.value->>'id'
            AND user_id = p_user_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to complete subtasks when parent is completed
CREATE OR REPLACE FUNCTION complete_subtasks()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 1 AND OLD.status != 1 THEN
        UPDATE public.note_tasks
        SET 
            status = 1,
            completed_at = NOW(),
            completed_by = NEW.completed_by,
            updated_at = NOW()
        WHERE 
            parent_task_id = NEW.id
            AND status = 0;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-complete subtasks
CREATE TRIGGER complete_subtasks_trigger
    AFTER UPDATE ON public.note_tasks
    FOR EACH ROW
    WHEN (NEW.status = 1 AND OLD.status != 1)
    EXECUTE FUNCTION complete_subtasks();

-- Add comments for documentation
COMMENT ON TABLE public.note_tasks IS 'Stores tasks extracted from notes with full task management capabilities';
COMMENT ON COLUMN public.note_tasks.status IS '0: open, 1: completed, 2: cancelled';
COMMENT ON COLUMN public.note_tasks.priority IS '0: low, 1: medium, 2: high, 3: urgent';
COMMENT ON COLUMN public.note_tasks.position IS 'Position of task within the note for ordering';
COMMENT ON COLUMN public.note_tasks.content_hash IS 'Hash of task content for deduplication';

