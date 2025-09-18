-- Clean up duplicate folders created during testing
-- This script identifies and removes duplicate folders with the same name

-- First, let's see what duplicates we have
SELECT name, COUNT(*) as count 
FROM local_folders 
WHERE deleted = 0 
GROUP BY name 
HAVING COUNT(*) > 1;

-- Delete duplicate "Egg" folders, keeping only the first one
DELETE FROM local_folders 
WHERE id NOT IN (
  SELECT MIN(id) 
  FROM local_folders 
  WHERE name = 'Egg' AND deleted = 0
) 
AND name = 'Egg' AND deleted = 0;

-- Delete duplicate "WTF" folders, keeping only the first one  
DELETE FROM local_folders 
WHERE id NOT IN (
  SELECT MIN(id) 
  FROM local_folders 
  WHERE name = 'WTF' AND deleted = 0
) 
AND name = 'WTF' AND deleted = 0;

-- Clean up any orphaned note-folder relationships
DELETE FROM note_folders 
WHERE folder_id NOT IN (
  SELECT id FROM local_folders WHERE deleted = 0
);
