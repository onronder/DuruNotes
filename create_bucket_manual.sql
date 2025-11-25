-- Manual bucket creation script
-- Run this if the migration didn't create the bucket

begin;

-- Delete existing bucket if it exists (to start fresh)
delete from storage.buckets where id = 'attachments';

-- Create the attachments bucket
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'attachments',
  'attachments',
  true,
  52428800,  -- 50MB
  array[
    'audio/m4a',
    'audio/mp4',  -- iOS voice recordings (CRITICAL!)
    'audio/aac',
    'audio/mp3',
    'audio/mpeg',
    'audio/wav',
    'audio/webm',
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/heic',
    'image/heif',
    'video/mp4',
    'video/mov',
    'video/quicktime',
    'video/webm',
    'application/pdf',
    'text/plain'
  ]
);

-- RLS Policies
drop policy if exists "Users can upload to their own folder" on storage.objects;
create policy "Users can upload to their own folder"
on storage.objects for insert
with check (
  bucket_id = 'attachments'
  and auth.uid()::text = split_part(name, '/', 1)
);

drop policy if exists "Users can read from their own folder" on storage.objects;
create policy "Users can read from their own folder"
on storage.objects for select
using (
  bucket_id = 'attachments'
  and auth.uid()::text = split_part(name, '/', 1)
);

drop policy if exists "Users can update their own files" on storage.objects;
create policy "Users can update their own files"
on storage.objects for update
using (
  bucket_id = 'attachments'
  and auth.uid()::text = split_part(name, '/', 1)
);

drop policy if exists "Users can delete from their own folder" on storage.objects;
create policy "Users can delete from their own folder"
on storage.objects for delete
using (
  bucket_id = 'attachments'
  and auth.uid()::text = split_part(name, '/', 1)
);

commit;

-- Verify bucket was created
select id, name, public, file_size_limit,
       cardinality(allowed_mime_types) as mime_type_count
from storage.buckets
where id = 'attachments';
