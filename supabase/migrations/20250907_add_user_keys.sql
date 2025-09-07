-- User keys table to store wrapped account master keys (AMK)
create table if not exists public.user_keys (
  user_id uuid primary key references auth.users(id) on delete cascade,
  wrapped_key bytea not null,
  kdf text not null default 'argon2id',
  kdf_params jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_keys enable row level security;

create policy "Users can manage their own user_keys" on public.user_keys
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists idx_user_keys_updated_at on public.user_keys(updated_at desc);

create or replace function public.touch_user_keys_updated_at() returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_touch_user_keys_updated_at on public.user_keys;
create trigger trg_touch_user_keys_updated_at before update on public.user_keys
  for each row execute function public.touch_user_keys_updated_at();


