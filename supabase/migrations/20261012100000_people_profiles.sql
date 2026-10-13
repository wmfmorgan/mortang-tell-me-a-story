-- M14 people profiles. Columns, tree membership, and later RLS in this file.
-- Sorts after 20261011210000_fit_and_finish.sql.

alter table public.people
  add column birth_date date,
  add column birth_precision public.story_date_precision,
  add column passing_date date,
  add column passing_precision public.story_date_precision,
  add column about text,
  add column avatar_path text,
  add column updated_at timestamptz not null default now();

alter table public.people
  alter column relationship drop not null;

alter table public.people
  add constraint people_birth_pair check (
    (birth_date is null) = (birth_precision is null)
  ),
  add constraint people_birth_no_decade check (
    birth_precision is null or birth_precision <> 'decade'
  ),
  add constraint people_passing_pair check (
    (passing_date is null) = (passing_precision is null)
  ),
  add constraint people_passing_no_decade check (
    passing_precision is null or passing_precision <> 'decade'
  ),
  add constraint people_about_len check (
    about is null or char_length(about) <= 500
  ),
  add constraint people_avatar_path_own check (
    avatar_path is null or avatar_path = (id::text || '/avatar.jpg')
  );

alter table public.profiles
  add column birth_date date,
  add column birth_precision public.story_date_precision,
  add column about text;

alter table public.profiles
  add constraint profiles_birth_pair check (
    (birth_date is null) = (birth_precision is null)
  ),
  add constraint profiles_birth_no_decade check (
    birth_precision is null or birth_precision <> 'decade'
  ),
  add constraint profiles_about_len check (
    about is null or char_length(about) <= 500
  );

create or replace function public.is_tree_member(fid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select auth.uid()) is not null
    and exists (
      select 1
      from public.memberships m
      join public.families mine on mine.id = m.family_id
      join public.families target on target.id = fid
      where m.user_id = (select auth.uid())
        and mine.deleted_at is null
        and target.deleted_at is null
        and public.family_tree_root(m.family_id) = public.family_tree_root(fid)
    ),
    false
  );
$$;

revoke all on function public.is_tree_member(uuid) from public, anon;
grant execute on function public.is_tree_member(uuid) to authenticated;
