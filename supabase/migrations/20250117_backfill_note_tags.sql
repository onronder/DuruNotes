-- Migration: Backfill note_tags from hashtags in note body
-- This ensures all notes with hashtags have corresponding entries in note_tags table

BEGIN;

-- Create a temporary function to extract hashtags from text
CREATE OR REPLACE FUNCTION extract_hashtags(text_content TEXT)
RETURNS TEXT[] AS $$
DECLARE
    hashtags TEXT[];
BEGIN
    -- Extract all hashtags using regex
    SELECT ARRAY(
        SELECT DISTINCT LOWER(substring(match FROM 2))
        FROM regexp_split_to_table(text_content, E'\\s+') AS match
        WHERE match ~ '^#\w+$'
    ) INTO hashtags;
    
    RETURN COALESCE(hashtags, ARRAY[]::TEXT[]);
END;
$$ LANGUAGE plpgsql;

-- Backfill tags for notes that have hashtags in body but not in note_tags
DO $$
DECLARE
    note_record RECORD;
    tag_text TEXT;
    extracted_tags TEXT[];
    existing_tags TEXT[];
BEGIN
    -- Log start
    RAISE NOTICE 'Starting backfill of note_tags from hashtags in note bodies';
    
    -- Process each note
    FOR note_record IN 
        SELECT id, body, title
        FROM notes
        WHERE deleted = false
          AND body IS NOT NULL
          AND (body LIKE '%#%')  -- Only process notes that might have hashtags
    LOOP
        -- Extract hashtags from body
        extracted_tags := extract_hashtags(note_record.body);
        
        -- Get existing tags for this note
        SELECT ARRAY_AGG(tag) INTO existing_tags
        FROM note_tags
        WHERE note_id = note_record.id;
        
        -- Insert missing tags
        FOREACH tag_text IN ARRAY extracted_tags
        LOOP
            -- Skip if tag already exists
            IF existing_tags IS NULL OR NOT (tag_text = ANY(existing_tags)) THEN
                BEGIN
                    INSERT INTO note_tags (note_id, tag)
                    VALUES (note_record.id, tag_text)
                    ON CONFLICT (note_id, tag) DO NOTHING;
                    
                    RAISE NOTICE 'Added tag % to note %', tag_text, note_record.id;
                EXCEPTION WHEN OTHERS THEN
                    RAISE WARNING 'Failed to add tag % to note %: %', tag_text, note_record.id, SQLERRM;
                END;
            END IF;
        END LOOP;
    END LOOP;
    
    -- Special handling for known system tags
    -- Ensure Email notes have 'email' tag
    INSERT INTO note_tags (note_id, tag)
    SELECT DISTINCT n.id, 'email'
    FROM notes n
    WHERE n.deleted = false
      AND (n.body LIKE '%#Email%' OR n.body LIKE '%#email%')
      AND NOT EXISTS (
          SELECT 1 FROM note_tags nt 
          WHERE nt.note_id = n.id AND nt.tag = 'email'
      )
    ON CONFLICT DO NOTHING;
    
    -- Ensure Web notes have 'web' tag
    INSERT INTO note_tags (note_id, tag)
    SELECT DISTINCT n.id, 'web'
    FROM notes n
    WHERE n.deleted = false
      AND (n.body LIKE '%#Web%' OR n.body LIKE '%#web%')
      AND NOT EXISTS (
          SELECT 1 FROM note_tags nt 
          WHERE nt.note_id = n.id AND nt.tag = 'web'
      )
    ON CONFLICT DO NOTHING;
    
    -- Ensure Attachment notes have 'attachment' tag
    INSERT INTO note_tags (note_id, tag)
    SELECT DISTINCT n.id, 'attachment'
    FROM notes n
    WHERE n.deleted = false
      AND (n.body LIKE '%#Attachment%' OR n.body LIKE '%#attachment%')
      AND NOT EXISTS (
          SELECT 1 FROM note_tags nt 
          WHERE nt.note_id = n.id AND nt.tag = 'attachment'
      )
    ON CONFLICT DO NOTHING;
    
    -- Log completion
    RAISE NOTICE 'Backfill completed successfully';
END $$;

-- Create index for better tag query performance if not exists
CREATE INDEX IF NOT EXISTS idx_note_tags_tag_lower ON note_tags(LOWER(tag));

-- Drop the temporary function
DROP FUNCTION IF EXISTS extract_hashtags(TEXT);

COMMIT;

-- Verify the migration
DO $$
DECLARE
    total_notes INTEGER;
    notes_with_hashtags INTEGER;
    notes_with_tags INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_notes FROM notes WHERE deleted = false;
    SELECT COUNT(DISTINCT id) INTO notes_with_hashtags 
    FROM notes WHERE deleted = false AND body LIKE '%#%';
    SELECT COUNT(DISTINCT note_id) INTO notes_with_tags FROM note_tags;
    
    RAISE NOTICE 'Migration verification:';
    RAISE NOTICE '  Total active notes: %', total_notes;
    RAISE NOTICE '  Notes with hashtags in body: %', notes_with_hashtags;
    RAISE NOTICE '  Notes with tags in note_tags: %', notes_with_tags;
END $$;
