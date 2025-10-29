-- Storage policies for inbound email attachment buckets
-- Ensures users can only access their own objects in both the temp and final buckets.

begin;

-- Temp bucket: allow owners to read files at temp/<user_id>/...
drop policy if exists "Temp email attachments - owner read" on storage.objects;
create policy "Temp email attachments - owner read"
on storage.objects
for select
using (
  bucket_id = 'inbound-attachments-temp'
  and split_part(name, '/', 1) = 'temp'
  and split_part(name, '/', 2) = auth.uid()::text
);

-- Final bucket: allow owners to manage files at <user_id>/...
drop policy if exists "Inbound attachments - owner manage" on storage.objects;
create policy "Inbound attachments - owner manage"
on storage.objects
for all
using (
  bucket_id = 'inbound-attachments'
  and split_part(name, '/', 1) = auth.uid()::text
)
with check (
  bucket_id = 'inbound-attachments'
  and split_part(name, '/', 1) = auth.uid()::text
);

commit;
