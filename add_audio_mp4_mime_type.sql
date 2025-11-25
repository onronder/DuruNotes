-- Add audio/mp4 MIME type to attachments bucket
-- This fixes the "mime type audio/mp4 is not supported" error for iOS voice recordings

begin;

-- Add audio/mp4 to allowed MIME types (only if not already present)
update storage.buckets
set allowed_mime_types = array_append(allowed_mime_types, 'audio/mp4')
where id = 'attachments'
  and not ('audio/mp4' = any(allowed_mime_types));

commit;

-- Verify the update
select
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
from storage.buckets
where id = 'attachments';
