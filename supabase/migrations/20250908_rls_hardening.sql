-- RLS hardening for user_keys, notes, folders, note_folders

-- user_keys
create table if not exists public.user_keys (
  user_id uuid primary key references auth.users(id) on delete cascade,
  wrapped_key bytea not null,
  kdf text not null default 'pbkdf2-hmac-sha256',
  kdf_params jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_keys enable row level security;

create or replace function public.touch_user_keys_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger where tgname = 'trg_touch_user_keys_updated_at'
  ) then
    create trigger trg_touch_user_keys_updated_at
      before update on public.user_keys
      for each row execute function public.touch_user_keys_updated_at();
  end if;
end $$;

-- Drop overly broad or duplicate policies if they exist (no-op if missing)
do $$ begin
  perform 1 from pg_policies where schemaname='public' and tablename='user_keys' and policyname='Users manage own user_keys';
  if found then execute 'drop policy "Users manage own user_keys" on public.user_keys'; end if;
end $$;

-- Strict policies: only owner can see/modify, no anonymous access
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='user_keys' and policyname='user_keys_select_own'
  ) then
    create policy user_keys_select_own on public.user_keys
      for select using (auth.uid() = user_id);
  end if;
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='user_keys' and policyname='user_keys_upsert_own'
  ) then
    create policy user_keys_upsert_own on public.user_keys
      for insert with check (auth.uid() = user_id);
  end if;
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='user_keys' and policyname='user_keys_update_own'
  ) then
    create policy user_keys_update_own on public.user_keys
      for update using (auth.uid() = user_id);
  end if;
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='user_keys' and policyname='user_keys_delete_own'
  ) then
    create policy user_keys_delete_own on public.user_keys
      for delete using (auth.uid() = user_id);
  end if;
end $$;

-- notes RLS (idempotent)
alter table if exists public.notes enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='notes' and policyname='notes_select_own') then
    create policy notes_select_own on public.notes for select using (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='notes' and policyname='notes_insert_own') then
    create policy notes_insert_own on public.notes for insert with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='notes' and policyname='notes_update_own') then
    create policy notes_update_own on public.notes for update using (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='notes' and policyname='notes_delete_own') then
    create policy notes_delete_own on public.notes for delete using (auth.uid() = user_id);
  end if;
end $$;

-- folders RLS (idempotent)
alter table if exists public.folders enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='folders' and policyname='folders_select_own') then
    create policy folders_select_own on public.folders for select using (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='folders' and policyname='folders_insert_own') then
    create policy folders_insert_own on public.folders for insert with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='folders' and policyname='folders_update_own') then
    create policy folders_update_own on public.folders for update using (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='folders' and policyname='folders_delete_own') then
    create policy folders_delete_own on public.folders for delete using (auth.uid() = user_id);
  end if;
end $$;

-- note_folders RLS (idempotent)
alter table if exists public.note_folders enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='note_folders' and policyname='note_folders_select_own') then
    create policy note_folders_select_own on public.note_folders for select using (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='note_folders' and policyname='note_folders_insert_own') then
    create policy note_folders_insert_own on public.note_folders for insert with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='note_folders' and policyname='note_folders_update_own') then
    create policy note_folders_update_own on public.note_folders for update using (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='note_folders' and policyname='note_folders_delete_own') then
    create policy note_folders_delete_own on public.note_folders for delete using (auth.uid() = user_id);
  end if;
end $$;

-- Helpful indexes
create index if not exists idx_user_keys_updated_at on public.user_keys(updated_at desc);
create index if not exists idx_notes_user_deleted on public.notes(user_id, deleted);
create index if not exists idx_notes_updated_at on public.notes(updated_at desc);
create index if not exists idx_folders_user_id on public.folders(user_id);
create index if not exists idx_folders_user_deleted on public.folders(user_id, deleted);
create index if not exists idx_folders_updated_at on public.folders(updated_at desc);
create index if not exists idx_note_folders_user_id on public.note_folders(user_id);
create index if not exists idx_note_folders_folder_id on public.note_folders(folder_id);

-- Verification
select 'user_keys' as table, to_regclass('public.user_keys') is not null as exists
union all select 'notes', to_regclass('public.notes') is not null
union all select 'folders', to_regclass('public.folders') is not null
union all select 'note_folders', to_regclass('public.note_folders') is not null;


