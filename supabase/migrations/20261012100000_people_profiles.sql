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

drop trigger if exists story_people_ensure_membership on public.story_people;
drop trigger if exists people_ensure_membership on public.people;

alter table public.invites
  add column person_id uuid null references public.people (id) on delete set null;

create or replace function public.list_unlinked_people(p_family_id uuid)
returns table (id uuid, family_id uuid, name text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null
     or not exists (
       select 1
       from public.families f
       where f.id = p_family_id
         and f.deleted_at is null
     )
     or not public.is_tree_member(p_family_id) then
    raise exception 'NOT_FOUND:';
  end if;

  return query
  select p.id, p.family_id, p.name
  from public.people p
  join public.families f on f.id = p.family_id
  where f.deleted_at is null
    and p.user_id is null
    and p.passing_date is null
    and public.family_tree_root(p.family_id) = public.family_tree_root(p_family_id)
  order by p.name, p.id;
end;
$$;

create or replace function public.assert_invite_person(
  p_family_id uuid,
  p_person_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  person public.people;
begin
  if (select auth.uid()) is null
     or not exists (
       select 1
       from public.families f
       where f.id = p_family_id
         and f.deleted_at is null
     )
     or not public.is_tree_member(p_family_id) then
    raise exception 'NOT_FOUND:';
  end if;

  select * into person
  from public.people
  where id = p_person_id;

  if not found
     or public.family_tree_root(person.family_id)
        is distinct from public.family_tree_root(p_family_id) then
    raise exception 'NOT_FOUND:';
  end if;

  if person.user_id is not null then
    raise exception 'VALIDATION: person is already linked';
  end if;

  if person.passing_date is not null then
    raise exception 'VALIDATION: person has passed';
  end if;
end;
$$;

create or replace function public.link_accepted_person(p_person_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  person public.people;
  caller uuid;
begin
  caller := (select auth.uid());
  if caller is null then
    raise exception 'NOT_FOUND:';
  end if;

  select * into person
  from public.people
  where id = p_person_id;

  if not found or person.user_id is not null then
    return;
  end if;

  if exists (
    select 1
    from public.people other
    join public.families mine on mine.id = other.family_id
    join public.families target on target.id = person.family_id
    where other.user_id = caller
      and other.id <> person.id
      and mine.deleted_at is null
      and target.deleted_at is null
      and public.family_tree_root(other.family_id)
        = public.family_tree_root(person.family_id)
  ) then
    return;
  end if;

  update public.people
  set user_id = caller
  where id = person.id
    and user_id is null;
end;
$$;

revoke all on function public.list_unlinked_people(uuid) from public, anon, service_role;
revoke all on function public.assert_invite_person(uuid, uuid) from public, anon, service_role;
revoke all on function public.link_accepted_person(uuid) from public, anon, service_role;
grant execute on function public.list_unlinked_people(uuid) to authenticated;
grant execute on function public.assert_invite_person(uuid, uuid) to authenticated;
grant execute on function public.link_accepted_person(uuid) to authenticated;

create or replace function public.create_branch_family(
  p_parent_family_id uuid,
  p_origin_story_id uuid,
  p_name text,
  p_branch_year int,
  p_owner_user_id uuid,
  p_person_ids uuid[] default '{}'
)
returns public.families
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid;
  story public.stories;
  fam public.families;
  person public.people;
  pid uuid;
  levels int;
begin
  caller := (select auth.uid());
  if caller is null
     or not public.is_live_family_member(p_parent_family_id) then
    raise exception 'FORBIDDEN: member only';
  end if;

  if p_origin_story_id is null then
    raise exception 'NOT_FOUND: story';
  end if;

  select * into story
  from public.stories
  where id = p_origin_story_id;

  if not found
     or story.status is distinct from 'published'::public.story_status
     or story.family_id is distinct from p_parent_family_id then
    raise exception 'NOT_FOUND: story';
  end if;

  if trim(coalesce(p_name, '')) = '' then
    raise exception 'VALIDATION: name is required';
  end if;

  if p_branch_year is null
     or p_branch_year < 1000
     or p_branch_year > 9999 then
    raise exception 'VALIDATION: attach year must be four digits';
  end if;

  if p_owner_user_id is null
     or not exists (
       select 1
       from public.memberships m
       where m.family_id = p_parent_family_id
         and m.user_id = p_owner_user_id
     ) then
    raise exception 'VALIDATION: owner must be a member of the parent family';
  end if;

  if exists (
    select 1
    from pg_catalog.unnest(coalesce(p_person_ids, '{}'::uuid[])) as picked(id)
    where not exists (
      select 1
      from public.people p
      where p.id = picked.id
        and p.family_id = p_parent_family_id
    )
  ) then
    raise exception 'VALIDATION: members must come from the parent family';
  end if;

  select coalesce(pg_catalog.max(walk.depth), 0)
  into levels
  from (
    with recursive walk as (
      select f.id, f.parent_family_id, 0 as depth, array[f.id] as path
      from public.families f
      where f.id = p_parent_family_id
        and f.deleted_at is null
      union all
      select parent.id, parent.parent_family_id, w.depth + 1, w.path || parent.id
      from walk w
      join public.families parent on parent.id = w.parent_family_id
      where parent.deleted_at is null
        and w.depth < 64
        and not parent.id = any (w.path)
    )
    select walk.depth
    from walk
  ) walk;

  if levels >= 63 then
    raise exception 'VALIDATION: too many levels';
  end if;

  insert into public.families (name, parent_family_id, created_by, branch_year)
  values (trim(p_name), p_parent_family_id, caller, p_branch_year)
  returning * into fam;

  perform pg_catalog.set_config('app.family_origin', 'on', true);
  update public.families
  set origin_story_id = p_origin_story_id
  where id = fam.id;
  perform pg_catalog.set_config('app.family_origin', 'off', true);

  if public.family_origin(fam.id) is distinct from p_origin_story_id then
    raise exception 'NOT_FOUND: story';
  end if;

  insert into public.memberships (family_id, user_id, role)
  values (fam.id, p_owner_user_id, 'owner'::public.membership_role);

  for pid in
    select distinct picked
    from pg_catalog.unnest(coalesce(p_person_ids, '{}'::uuid[])) as picked
  loop
    select * into person
    from public.people
    where id = pid
      and family_id = p_parent_family_id;

    perform public.upsert_story_member(
      fam.id,
      public.resolve_person_user(person.user_id, null)
    );
  end loop;

  select * into fam from public.families where id = fam.id;
  return fam;
end;
$$;

revoke all on function public.create_branch_family(uuid, uuid, text, int, uuid, uuid[])
  from public, anon;
grant execute on function public.create_branch_family(uuid, uuid, text, int, uuid, uuid[])
  to authenticated, service_role;

create or replace function public.remove_member(fid uuid, target uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  tree_ids uuid[];
begin
  perform public._require_family(fid);
  if not (public.is_family_owner(fid) or public.is_family_co_owner(fid)) then
    raise exception 'FORBIDDEN: owner or co-owner only';
  end if;
  if target = (select auth.uid()) then
    raise exception 'FORBIDDEN: cannot remove yourself';
  end if;

  select coalesce(array_agg(id), '{}') into tree_ids
  from public.family_tree_ids(fid);

  if exists (
    select 1
    from public.memberships
    where user_id = target
      and family_id = any (tree_ids)
      and role = 'owner'
  ) then
    raise exception 'FORBIDDEN: cannot remove an owner';
  end if;

  if exists (
    select 1
    from public.memberships
    where user_id = target
      and family_id = any (tree_ids)
      and role = 'co_owner'
  ) and not public.is_family_owner(fid) then
    raise exception 'FORBIDDEN: cannot remove a co-owner';
  end if;

  delete from public.memberships
  where user_id = target
    and family_id = any (tree_ids);

  update public.people
  set user_id = null
  where user_id = target
    and family_id = any (tree_ids);
end;
$$;
