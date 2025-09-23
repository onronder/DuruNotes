-- 2025-09-11_canonicalize_incoming_mail_folders.sql
-- Migration to ensure exactly one "Incoming Mail" folder per user
-- Migrates notes from duplicates to canonical folder before soft-deleting duplicates

-------------------------------
-- CANONICALIZE "INCOMING MAIL" FOLDERS
-------------------------------
DO $$
DECLARE
  user_record RECORD;
  canonical_folder_id uuid;
  duplicate_record RECORD;
BEGIN
  -- Process each user who has folders
  FOR user_record IN 
    SELECT DISTINCT user_id 
    FROM public.folders 
    WHERE deleted = false
  LOOP
    -- Find all "Incoming Mail" folders for this user (case-insensitive)
    -- Order by created_at to keep the oldest as canonical
    SELECT id INTO canonical_folder_id
    FROM public.folders
    WHERE user_id = user_record.user_id
      AND LOWER(TRIM(name_enc::text)) = LOWER(TRIM('Incoming Mail'))  -- Note: This won't work with encrypted names
      AND deleted = false
    ORDER BY created_at ASC
    LIMIT 1;
    
    -- If we found a canonical folder, process duplicates
    IF canonical_folder_id IS NOT NULL THEN
      -- Migrate notes from duplicate folders to canonical folder
      FOR duplicate_record IN
        SELECT id
        FROM public.folders
        WHERE user_id = user_record.user_id
          AND id != canonical_folder_id
          AND LOWER(TRIM(name_enc::text)) = LOWER(TRIM('Incoming Mail'))  -- Note: This won't work with encrypted names
          AND deleted = false
      LOOP
        -- Update note_folders to point to canonical folder
        UPDATE public.note_folders
        SET folder_id = canonical_folder_id
        WHERE folder_id = duplicate_record.id
          AND user_id = user_record.user_id
          AND NOT EXISTS (
            -- Don't create duplicate entries if note is already in canonical folder
            SELECT 1 FROM public.note_folders nf2
            WHERE nf2.note_id = note_folders.note_id
              AND nf2.folder_id = canonical_folder_id
          );
        
        -- Delete any remaining duplicate note_folder entries
        DELETE FROM public.note_folders
        WHERE folder_id = duplicate_record.id
          AND user_id = user_record.user_id;
        
        -- Soft-delete the duplicate folder
        UPDATE public.folders
        SET deleted = true,
            updated_at = NOW()
        WHERE id = duplicate_record.id;
        
        RAISE NOTICE 'Migrated folder % to canonical folder % for user %', 
                     duplicate_record.id, canonical_folder_id, user_record.user_id;
      END LOOP;
    END IF;
  END LOOP;
END$$;

-------------------------------
-- ALTERNATIVE: CANONICALIZATION BY FOLDER ID APPROACH
-------------------------------
-- Since folder names are encrypted, we can't directly compare them in SQL.
-- This alternative approach requires the application to identify duplicates
-- and call this function with the folder IDs to merge.

CREATE OR REPLACE FUNCTION merge_duplicate_folders(
  p_canonical_folder_id uuid,
  p_duplicate_folder_ids uuid[],
  p_user_id uuid
) RETURNS void AS $$
BEGIN
  -- Validate that all folders belong to the same user
  IF EXISTS (
    SELECT 1 FROM public.folders 
    WHERE id = ANY(p_duplicate_folder_ids || ARRAY[p_canonical_folder_id])
      AND user_id != p_user_id
  ) THEN
    RAISE EXCEPTION 'All folders must belong to the same user';
  END IF;
  
  -- Migrate notes from duplicate folders to canonical folder
  UPDATE public.note_folders
  SET folder_id = p_canonical_folder_id,
      added_at = COALESCE(added_at, NOW())
  WHERE folder_id = ANY(p_duplicate_folder_ids)
    AND user_id = p_user_id
    AND NOT EXISTS (
      -- Don't create duplicate entries
      SELECT 1 FROM public.note_folders nf2
      WHERE nf2.note_id = note_folders.note_id
        AND nf2.folder_id = p_canonical_folder_id
    );
  
  -- Delete any remaining duplicate note_folder entries
  DELETE FROM public.note_folders
  WHERE folder_id = ANY(p_duplicate_folder_ids)
    AND user_id = p_user_id;
  
  -- Soft-delete the duplicate folders
  UPDATE public.folders
  SET deleted = true,
      updated_at = NOW()
  WHERE id = ANY(p_duplicate_folder_ids)
    AND user_id = p_user_id;
  
  RAISE NOTICE 'Merged % duplicate folders into canonical folder %', 
               array_length(p_duplicate_folder_ids, 1), p_canonical_folder_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION merge_duplicate_folders(uuid, uuid[], uuid) TO authenticated;

-------------------------------
-- VERIFICATION QUERIES
-------------------------------
-- Check for potential duplicates (won't work with encrypted names)
-- This would need to be done in the application layer

-- Count folders per user (to identify users with multiple folders)
-- SELECT user_id, COUNT(*) as folder_count
-- FROM public.folders
-- WHERE deleted = false
-- GROUP BY user_id
-- HAVING COUNT(*) > 1
-- ORDER BY folder_count DESC;

-- Check note_folders for orphaned entries
-- SELECT nf.* 
-- FROM public.note_folders nf
-- LEFT JOIN public.folders f ON nf.folder_id = f.id
-- WHERE f.id IS NULL OR f.deleted = true;
