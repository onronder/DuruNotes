-- Create attachments storage bucket for voice notes and file uploads
-- This bucket stores user-uploaded files with user-scoped path structure: {user_id}/attachments/{filename}
-- Created: 2025-11-24
-- Purpose: Enable voice recording upload functionality

begin;

-- Create the attachments bucket
-- public = true allows public URL access, but access is still controlled by RLS policies
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'attachments',
  'attachments',
  true,
  52428800,  -- 50MB limit (50 * 1024 * 1024 bytes)
  array[
    -- Audio formats (voice notes, recordings)
    'audio/m4a',
    'audio/mp4',        -- iOS voice recordings
    'audio/aac',
    'audio/mp3',
    'audio/mpeg',
    'audio/wav',
    'audio/webm',

    -- Image formats (photos, screenshots, scanned documents)
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/heic',
    'image/heif',

    -- Video formats (video notes)
    'video/mp4',
    'video/mov',
    'video/quicktime',
    'video/webm',

    -- Document formats
    'application/pdf',
    'text/plain'
  ]
)
on conflict (id) do nothing;

-- RLS Policy: Users can only upload files to their own user folder
-- Path structure: {user_id}/attachments/{filename}
drop policy if exists "Users can upload to their own folder" on storage.objects;
create policy "Users can upload to their own folder"
on storage.objects
for insert
with check (
  bucket_id = 'attachments'
  and auth.uid()::text = split_part(name, '/', 1)
);

-- RLS Policy: Users can read files from their own folder
drop policy if exists "Users can read from their own folder" on storage.objects;
create policy "Users can read from their own folder"
on storage.objects
for select
using (
  bucket_id = 'attachments'
  and auth.uid()::text = split_part(name, '/', 1)
);

-- RLS Policy: Users can update/replace files in their own folder
drop policy if exists "Users can update their own files" on storage.objects;
create policy "Users can update their own files"
on storage.objects
for update
using (
  bucket_id = 'attachments'
  and auth.uid()::text = split_part(name, '/', 1)
);

-- RLS Policy: Users can delete files from their own folder
drop policy if exists "Users can delete from their own folder" on storage.objects;
create policy "Users can delete from their own folder"
on storage.objects
for delete
using (
  bucket_id = 'attachments'
  and auth.uid()::text = split_part(name, '/', 1)
);

commit;
