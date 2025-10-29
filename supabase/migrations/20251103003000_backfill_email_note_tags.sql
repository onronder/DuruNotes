-- Backfill tags for notes converted from email inbox items.
-- Ensures every converted email note has the 'Email' tag and,
-- when attachments were present, the 'Attachment' tag.

begin;

insert into note_tags (note_id, tag, user_id)
select
  ci.converted_to_note_id,
  'Email',
  ci.user_id
from clipper_inbox ci
inner join notes n
  on n.id = ci.converted_to_note_id
group by ci.converted_to_note_id, ci.user_id
on conflict (note_id, tag) do nothing;

insert into note_tags (note_id, tag, user_id)
select
  ci.converted_to_note_id,
  'Attachment',
  ci.user_id
from clipper_inbox ci
inner join notes n
  on n.id = ci.converted_to_note_id
where coalesce(
  (ci.payload_json -> 'attachments' ->> 'count')::int,
  0
) > 0
group by ci.converted_to_note_id, ci.user_id
on conflict (note_id, tag) do nothing;

-- Touch the associated notes so updated_at reflects the change.
update notes
set updated_at = timezone('utc', now())
where id in (
  select ci.converted_to_note_id
  from clipper_inbox ci
  inner join notes n on n.id = ci.converted_to_note_id
);

commit;
