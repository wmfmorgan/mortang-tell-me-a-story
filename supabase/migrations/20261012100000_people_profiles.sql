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

drop view if exists public.people_tree_read;
create view public.people_tree_read
with (security_barrier = true) as
  select p.id, p.family_id, p.name
  from public.people p
  where public.is_live_family_member(p.family_id)
     or public.is_family_tree_readable(p.family_id);

revoke all on public.people_tree_read from public, anon;
grant select on public.people_tree_read to authenticated;

drop policy if exists people_select_member on public.people;
create policy people_select_member
  on public.people for select
  to authenticated
  using (public.is_tree_member(family_id));

drop policy if exists people_insert_member on public.people;
create policy people_insert_member
  on public.people for insert
  to authenticated
  with check (public.is_live_family_member(family_id));

drop policy if exists people_update_member on public.people;
create policy people_update_member
  on public.people for update
  to authenticated
  using (
    (user_id is null and public.is_tree_member(family_id))
    or user_id = (select auth.uid())
  )
  with check (
    (user_id is null and public.is_tree_member(family_id))
    or user_id = (select auth.uid())
  );

revoke update on table public.people from authenticated, anon, public;
grant update (
  name,
  relationship,
  email,
  birth_date,
  birth_precision,
  passing_date,
  passing_precision,
  about,
  avatar_path,
  updated_at
) on table public.people to authenticated;

create or replace function public.person_profile(p_person_id uuid)
returns table (
  id uuid,
  family_id uuid,
  name text,
  birth_date date,
  birth_precision public.story_date_precision,
  about text,
  avatar_path text,
  passing_date date,
  passing_precision public.story_date_precision,
  is_linked boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  person public.people%rowtype;
  account_birth_date date;
  account_birth_precision public.story_date_precision;
  account_about text;
  account_avatar text;
begin
  if (select auth.uid()) is null or p_person_id is null then
    raise exception 'NOT_FOUND:';
  end if;

  select * into person
  from public.people
  where public.people.id = p_person_id;

  if not found or not public.is_tree_member(person.family_id) then
    raise exception 'NOT_FOUND:';
  end if;

  if person.user_id is not null then
    select profiles.birth_date, profiles.birth_precision, profiles.about, profiles.avatar_path
      into account_birth_date, account_birth_precision, account_about, account_avatar
    from public.profiles
    where profiles.id = person.user_id;
  end if;

  return query
  select
    person.id,
    person.family_id,
    person.name,
    case
      when person.user_id is not null and account_birth_date is not null
        then account_birth_date
      else person.birth_date
    end,
    case
      when person.user_id is not null and account_birth_precision is not null
        then account_birth_precision
      else person.birth_precision
    end,
    case
      when person.user_id is not null and account_about is not null
        then account_about
      else person.about
    end,
    case
      when person.user_id is not null and account_avatar is not null
        then account_avatar
      else person.avatar_path
    end,
    person.passing_date,
    person.passing_precision,
    person.user_id is not null;
end;
$$;

revoke all on function public.person_profile(uuid) from public, anon;
grant execute on function public.person_profile(uuid) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'person-avatars',
  'person-avatars',
  false,
  2097152,
  array['image/jpeg']
);

create policy person_avatars_select_tree
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'person-avatars'
    and exists (
      select 1
      from public.people p
      where (storage.foldername(objects.name))[1] = p.id::text
        and objects.name = (p.id::text || '/avatar.jpg')
        and public.is_tree_member(p.family_id)
    )
  );

create policy person_avatars_insert_editor
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'person-avatars'
    and exists (
      select 1
      from public.people p
      where (storage.foldername(objects.name))[1] = p.id::text
        and objects.name = (p.id::text || '/avatar.jpg')
        and (
          (p.user_id is null and public.is_tree_member(p.family_id))
          or p.user_id = (select auth.uid())
        )
    )
  );

create policy person_avatars_update_editor
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'person-avatars'
    and exists (
      select 1
      from public.people p
      where (storage.foldername(objects.name))[1] = p.id::text
        and objects.name = (p.id::text || '/avatar.jpg')
        and (
          (p.user_id is null and public.is_tree_member(p.family_id))
          or p.user_id = (select auth.uid())
        )
    )
  )
  with check (
    bucket_id = 'person-avatars'
    and exists (
      select 1
      from public.people p
      where (storage.foldername(objects.name))[1] = p.id::text
        and objects.name = (p.id::text || '/avatar.jpg')
        and (
          (p.user_id is null and public.is_tree_member(p.family_id))
          or p.user_id = (select auth.uid())
        )
    )
  );
