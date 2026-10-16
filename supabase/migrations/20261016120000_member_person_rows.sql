-- M14.1a member person rows. One linked people row per account per tree.
-- App inserts still cannot set user_id. No new policies.

create or replace function public.ensure_member_person(
  p_family_id uuid,
  p_user_id uuid,
  p_link_email boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  profile public.profiles;
  match_id uuid;
  person_name text;
begin
  if p_family_id is null or p_user_id is null then
    return;
  end if;

  if exists (
    select 1
    from public.people p
    join public.families mine on mine.id = p.family_id
    join public.families target on target.id = p_family_id
    where p.user_id = p_user_id
      and mine.deleted_at is null
      and target.deleted_at is null
      and public.family_tree_root(p.family_id)
        = public.family_tree_root(p_family_id)
  ) then
    return;
  end if;

  select * into profile
  from public.profiles
  where id = p_user_id;

  if not found then
    return;
  end if;

  if p_link_email
     and profile.email is not null
     and btrim(profile.email) <> '' then
    select p.id into match_id
    from public.people p
    where p.family_id = p_family_id
      and p.user_id is null
      and p.email is not null
      and lower(btrim(p.email)) = lower(btrim(profile.email))
    order by p.id
    limit 1;

    if match_id is not null then
      update public.people
      set user_id = p_user_id
      where id = match_id
        and user_id is null;
      return;
    end if;
  end if;

  person_name := coalesce(
    nullif(btrim(profile.display_name), ''),
    nullif(btrim(profile.email), ''),
    'Member'
  );

  insert into public.people (family_id, name, created_by, user_id, email)
  values (
    p_family_id,
    person_name,
    p_user_id,
    p_user_id,
    nullif(btrim(profile.email), '')
  );
end;
$$;

create or replace function public.backfill_member_person_rows()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  rec record;
begin
  for rec in
    select m.family_id, m.user_id
    from public.memberships m
    join public.families f on f.id = m.family_id
    where f.deleted_at is null
  loop
    perform public.ensure_member_person(rec.family_id, rec.user_id, true);
  end loop;
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

drop trigger if exists people_keep_one_member_link on public.people;
drop function if exists public.people_keep_one_member_link();

-- One user_id per family. The earlier migration creates this index.
-- Recreate it so a database that applied the dropped version gets it back.
create unique index if not exists people_family_user_uidx
  on public.people (family_id, user_id)
  where user_id is not null;

create or replace function public.ensure_accepted_invite_person()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'accepted'::public.invite_status
     and old.status is distinct from 'accepted'::public.invite_status
     and new.person_id is null
     and new.accepted_by is not null then
    perform public.ensure_member_person(new.family_id, new.accepted_by, false);
  end if;
  return new;
end;
$$;

drop trigger if exists invites_ensure_member_person on public.invites;
create trigger invites_ensure_member_person
  after update of status on public.invites
  for each row
  execute function public.ensure_accepted_invite_person();

create or replace function public.create_family(p_name text)
returns public.families
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_family public.families;
  caller uuid := (select auth.uid());
  trimmed text := btrim(coalesce(p_name, ''));
begin
  if caller is null then
    raise exception 'FORBIDDEN: sign-in required';
  end if;
  if trimmed = '' then
    raise exception 'VALIDATION: name is required';
  end if;

  insert into public.families (name, created_by)
  values (trimmed, caller)
  returning * into new_family;

  insert into public.memberships (family_id, user_id, role)
  values (new_family.id, caller, 'owner'::public.membership_role);

  perform public.ensure_member_person(new_family.id, caller, false);

  return new_family;
end;
$$;

revoke all on function public.ensure_member_person(uuid, uuid, boolean)
  from public, anon, authenticated, service_role;
revoke all on function public.backfill_member_person_rows()
  from public, anon, authenticated, service_role;
revoke all on function public.ensure_accepted_invite_person()
  from public, anon, authenticated, service_role;
revoke all on function public.link_accepted_person(uuid)
  from public, anon, service_role;
revoke all on function public.create_family(text) from public;

grant execute on function public.link_accepted_person(uuid) to authenticated;
grant execute on function public.create_family(text) to authenticated, service_role;

select public.backfill_member_person_rows();

drop function public.backfill_member_person_rows();
