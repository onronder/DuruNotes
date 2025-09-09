-- =========================================================
-- DuruNotes: Email-in consolidated migration (production-safe)
-- Idempotent; compatible with PostgreSQL (no CREATE POLICY IF NOT EXISTS).
-- =========================================================

-- 0) helper: check if a policy exists by (schema, table, policyname)
create or replace function public._policy_exists(
  schemaname text, tablename text, policyname text
) returns boolean
language sql
stable
as $$
  select exists(
    select 1 from pg_policies 
    where schemaname = $1 and tablename = $2 and policyname = $3
  );
$$;

-- ---------------------------------------------------------
-- 1) inbound_aliases: table + RLS + index + updated_at trigger
-- ---------------------------------------------------------
create table if not exists public.inbound_aliases (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  alias      text unique not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.inbound_aliases enable row level security;

do $$
begin
  if not public._policy_exists('public','inbound_aliases','users-can-view-own-alias') then
    create policy "users-can-view-own-alias"
      on public.inbound_aliases
      for select
      using (auth.uid() = user_id);
  end if;
end $$;

create index if not exists idx_inbound_aliases_alias 
  on public.inbound_aliases (alias);

-- shared trigger func
create or replace function public.update_updated_at_column()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end $$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'update_inbound_aliases_updated_at') then
    create trigger update_inbound_aliases_updated_at
      before update on public.inbound_aliases
      for each row execute function public.update_updated_at_column();
  end if;
end $$;

-- ---------------------------------------------------------
-- 2) Secure alias generator (SECURITY DEFINER with owner check)
-- ---------------------------------------------------------
create or replace function public.generate_user_alias(p_user_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_alias text;
  v_exists boolean;
  v_counter int := 0;
  v_max_attempts int := 10;
  v_random_suffix text;
begin
  -- only the authenticated caller can create THEIR OWN alias
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'not allowed';
  end if;

  -- return existing alias if present
  select alias into v_alias from public.inbound_aliases where user_id = p_user_id;
  if v_alias is not null then
    return v_alias;
  end if;

  -- generate unique alias note_<8-hex>
  loop
    v_random_suffix := lower(substring(md5(random()::text || clock_timestamp()::text), 1, 8));
    v_alias := 'note_' || v_random_suffix;

    select exists(select 1 from public.inbound_aliases where alias = v_alias) into v_exists;
    if not v_exists then
      insert into public.inbound_aliases (user_id, alias) values (p_user_id, v_alias);
      return v_alias;
    end if;

    v_counter := v_counter + 1;
    if v_counter >= v_max_attempts then
      raise exception 'Could not generate unique alias after % attempts', v_max_attempts;
    end if;
  end loop;
end;
$$;

revoke all on function public.generate_user_alias(uuid) from public;
grant execute on function public.generate_user_alias(uuid) to authenticated;

-- ---------------------------------------------------------
-- 3) clipper_inbox: message_id + user‑scoped unique index
-- ---------------------------------------------------------
alter table public.clipper_inbox
  add column if not exists message_id text;

-- clean up any old index names then create the intended one
drop index if exists public.idx_clipper_inbox_message_id;
drop index if exists public.idx_clip_inbox_user_msgid;

create unique index if not exists idx_clipper_inbox_user_message_id
  on public.clipper_inbox (user_id, message_id)
  where message_id is not null;

-- optional helper
create or replace function public.extract_message_id(headers text)
returns text
language plpgsql
as $$
declare v_message_id text;
begin
  select substring(headers from 'Message-ID:\s*<([^>]+)>') into v_message_id;
  return v_message_id;
end $$;

-- ---------------------------------------------------------
-- 4) Storage: private bucket + safe RLS (no client INSERT)
-- ---------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit)
values ('inbound-attachments', 'inbound-attachments', false, 52428800)
on conflict (id) do update set file_size_limit = excluded.file_size_limit;

-- drop permissive/old policies if they exist (from earlier drafts)
drop policy if exists "Service role can upload attachments" on storage.objects;
drop policy if exists "Service role can view attachments" on storage.objects;
drop policy if exists "Users can view own attachments" on storage.objects;
drop policy if exists "Users can delete own attachments" on storage.objects;

-- re-create safe client policies via DO blocks (Postgres has no CREATE POLICY IF NOT EXISTS)
do $$
begin
  if not public._policy_exists('storage','objects','Users can view own inbound attachments') then
    create policy "Users can view own inbound attachments"
      on storage.objects for select
      using (
        bucket_id = 'inbound-attachments'
        and auth.uid()::text = (storage.foldername(name))[1]
      );
  end if;
end $$;

do $$
begin
  if not public._policy_exists('storage','objects','Users can delete own inbound attachments') then
    create policy "Users can delete own inbound attachments"
      on storage.objects for delete
      using (
        bucket_id = 'inbound-attachments'
        and auth.uid()::text = (storage.foldername(name))[1]
      );
  end if;
end $$;

-- no INSERT policy on purpose: service-role (edge function) uploads and bypasses RLS
-- remove any placeholder DB "signer" function if present (sign URLs in app/edge only)
drop function if exists public.get_attachment_url(text, int);

-- ---------------------------------------------------------
-- 5) Documentation comments
-- ---------------------------------------------------------
comment on table public.inbound_aliases is 'Maps unique inbound email alias -> user_id';
comment on column public.clipper_inbox.message_id is 'Email Message-ID for duplicate prevention (scoped per user)';
