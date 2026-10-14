-- Animal Language — database schema for Supabase (Postgres).
-- Run this once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- It is safe to re-run.
--
-- Security model
--   * Visitors (the public "anon" role) can only READ approved rows, and can only
--     ADD rows through the two submit_* functions, which always create 'pending' rows.
--   * The admin is a single Supabase Auth user you create by hand (see README.md).
--     Any signed-in ("authenticated") user can moderate, so keep sign-ups disabled.

create table if not exists public.bb_languages (
  id         bigint generated always as identity primary key,
  code       text not null unique check (char_length(code) between 1 and 20),
  name       text not null check (char_length(name) between 1 and 100),
  native     text not null default '' check (char_length(native) <= 100),
  status     text not null default 'pending' check (status in ('pending','approved')),
  created_at timestamptz not null default now()
);

create table if not exists public.bb_contributions (
  id         bigint generated always as identity primary key,
  animal_id  text not null,
  lang_code  text not null check (char_length(lang_code) between 1 and 20),
  kind       text not null check (kind in ('words','sounds')),
  text       text check (text is null or char_length(text) <= 200),
  recording  text check (recording is null or
               (char_length(recording) <= 400000 and recording like 'data:audio/%')),
  status     text not null default 'pending' check (status in ('pending','approved')),
  created_at timestamptz not null default now(),
  check (text is not null or recording is not null)
);

-- The list of animals lives in one named constraint so it can be updated by re-running this file.
alter table public.bb_contributions drop constraint if exists bb_contributions_animal_id_check;
alter table public.bb_contributions add constraint bb_contributions_animal_id_check check (animal_id in
  ('dog','cat','cow','duck','pig','rooster','sheep','frog','owl','chick',
   'horse','goat','wolf','lion','monkey','mouse','bee','snake','elephant','turkey'));

-- Lets the page list recordings without downloading them (fetched on play instead).
alter table public.bb_contributions
  add column if not exists has_recording boolean generated always as (recording is not null) stored;

create index if not exists bb_languages_status_idx     on public.bb_languages (status);
create index if not exists bb_contributions_status_idx on public.bb_contributions (status);

-- ---------- Row level security ----------
alter table public.bb_languages     enable row level security;
alter table public.bb_contributions enable row level security;

drop policy if exists "public reads approved languages" on public.bb_languages;
create policy "public reads approved languages" on public.bb_languages
  for select to anon, authenticated using (status = 'approved');

drop policy if exists "public reads approved contributions" on public.bb_contributions;
create policy "public reads approved contributions" on public.bb_contributions
  for select to anon, authenticated using (status = 'approved');

drop policy if exists "admin manages languages" on public.bb_languages;
create policy "admin manages languages" on public.bb_languages
  for all to authenticated using (true) with check (true);

drop policy if exists "admin manages contributions" on public.bb_contributions;
create policy "admin manages contributions" on public.bb_contributions
  for all to authenticated using (true) with check (true);

-- Anonymous visitors get no direct write access at all.
revoke insert, update, delete on public.bb_languages, public.bb_contributions from anon;

-- ---------- Public submission functions ----------
-- Cap on how many unreviewed items can pile up, so spam can't fill the database.
create or replace function public.bb_pending_limit_reached()
returns boolean language sql stable security definer set search_path = public as $$
  select (select count(*) from bb_languages where status = 'pending') > 100
      or (select count(*) from bb_contributions where status = 'pending') > 500;
$$;

create or replace function public.submit_language(p_name text, p_code text default '', p_native text default '')
returns text language plpgsql security definer set search_path = public as $$
declare
  v_name   text := btrim(coalesce(p_name, ''));
  v_code   text := btrim(coalesce(p_code, ''));
  v_native text := btrim(coalesce(p_native, ''));
begin
  if v_name = '' or char_length(v_name) > 100 then
    raise exception 'Give the language a name (under 100 characters).' using errcode = 'P0001';
  end if;
  if bb_pending_limit_reached() then
    raise exception 'Too many submissions are waiting for review. Please try again later.' using errcode = 'P0001';
  end if;
  if v_code = '' then
    v_code := 'x-' || left(regexp_replace(lower(v_name), '[^a-z]', '', 'g'), 8)
              || '-' || substr(md5(random()::text || clock_timestamp()::text), 1, 4);
  end if;
  v_code := left(v_code, 20);
  insert into bb_languages (code, name, native, status) values (v_code, v_name, v_native, 'pending');
  return v_code;
exception when unique_violation then
  raise exception 'That language code is already in use — try leaving the code field blank.' using errcode = 'P0001';
end $$;

create or replace function public.submit_contribution(
  p_animal_id text, p_lang_code text, p_kind text, p_text text default '', p_recording text default '')
returns bigint language plpgsql security definer set search_path = public as $$
declare
  v_text text := nullif(btrim(coalesce(p_text, '')), '');
  v_rec  text := nullif(coalesce(p_recording, ''), '');
  v_id   bigint;
begin
  if v_text is null and v_rec is null then
    raise exception 'Add some text or a recording first.' using errcode = 'P0001';
  end if;
  if bb_pending_limit_reached() then
    raise exception 'Too many submissions are waiting for review. Please try again later.' using errcode = 'P0001';
  end if;
  insert into bb_contributions (animal_id, lang_code, kind, text, recording, status)
  values (p_animal_id, btrim(coalesce(p_lang_code, '')), p_kind, v_text, v_rec, 'pending')
  returning id into v_id;
  return v_id;
exception when check_violation then
  raise exception 'That submission was not valid (unknown animal, text too long, or bad recording).' using errcode = 'P0001';
end $$;

revoke all on function public.bb_pending_limit_reached() from public, anon, authenticated;
revoke all on function public.submit_language(text, text, text) from public;
revoke all on function public.submit_contribution(text, text, text, text, text) from public;
grant execute on function public.submit_language(text, text, text)                   to anon, authenticated;
grant execute on function public.submit_contribution(text, text, text, text, text)  to anon, authenticated;
