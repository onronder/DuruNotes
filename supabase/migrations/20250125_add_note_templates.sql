-- Migration: Add note templates support
-- Description: Adds note_type column to distinguish between regular notes and templates

-- Add note_type column with default value 'note'
ALTER TABLE notes 
ADD COLUMN IF NOT EXISTS note_type TEXT DEFAULT 'note' 
CHECK (note_type IN ('note', 'template'));

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_notes_note_type ON notes(note_type);
CREATE INDEX IF NOT EXISTS idx_notes_user_type ON notes(user_id, note_type);

-- Update existing RLS policies to be template-aware
-- (existing policies continue to work, templates are treated as notes)

-- Function to get user's template count
CREATE OR REPLACE FUNCTION get_template_count(user_uuid UUID)
RETURNS INTEGER AS $$
  SELECT COUNT(*)::INTEGER 
  FROM notes 
  WHERE user_id = user_uuid 
  AND note_type = 'template' 
  AND deleted = false;
$$ LANGUAGE SQL SECURITY DEFINER;

-- Function to list user's templates
CREATE OR REPLACE FUNCTION get_user_templates(user_uuid UUID)
RETURNS TABLE (
  id UUID,
  title_enc BYTEA,
  props_enc BYTEA,
  updated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
) AS $$
  SELECT id, title_enc, props_enc, updated_at, created_at
  FROM notes 
  WHERE user_id = user_uuid 
  AND note_type = 'template' 
  AND deleted = false
  ORDER BY updated_at DESC;
$$ LANGUAGE SQL SECURITY DEFINER;

-- Grant access to the functions
GRANT EXECUTE ON FUNCTION get_template_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_templates(UUID) TO authenticated;

-- Add comment for documentation
COMMENT ON COLUMN notes.note_type IS 'Type of note: "note" for regular notes, "template" for reusable templates';
