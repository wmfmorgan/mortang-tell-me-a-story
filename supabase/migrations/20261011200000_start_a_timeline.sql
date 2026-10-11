-- M11b: start a new timeline. One constraint, one function, its grants.
-- No new table, column, enum, or policy. families_guard_update() is unchanged.

alter table public.families
  add constraint families_parent_not_self
  check (parent_family_id is null or parent_family_id <> id);

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

    insert into public.people (
      family_id, name, relationship, email, user_id, created_by
    ) values (
      fam.id,
      person.name,
      person.relationship,
      person.email,
      person.user_id,
      caller
    );

    perform public.upsert_story_member(
      fam.id,
      public.resolve_person_user(person.user_id, person.email)
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
