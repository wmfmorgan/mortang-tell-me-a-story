-- M10 Manage families. Roles, soft-delete, and security-definer writes.
-- Does not edit earlier migrations. Client still cannot write memberships.

alter table public.families
  add column deleted_at timestamptz null;

create index families_deleted_at_idx
  on public.families (deleted_at)
  where deleted_at is not null;

alter table public.people
  add column user_id uuid null references public.profiles (id);

create unique index people_family_user_uidx
  on public.people (family_id, user_id)
  where user_id is not null;

create unique index memberships_one_owner_uidx
  on public.memberships (family_id)
  where role = 'owner';

-- One owner per existing family. Other memberships stay member.
update public.memberships m
set role = 'owner'
from public.families f
where m.family_id = f.id
  and m.user_id = f.created_by
  and m.role is distinct from 'owner';

insert into public.memberships (family_id, user_id, role)
select f.id, f.created_by, 'owner'
from public.families f
where not exists (
  select 1
  from public.memberships m
  where m.family_id = f.id
    and m.user_id = f.created_by
);

create or replace function public.create_family(p_name text)
returns public.families
language plpgsql
security definer
set search_path = public
as $$
declare
  new_family public.families;
  trimmed text := trim(coalesce(p_name, ''));
begin
  if auth.uid() is null then
    raise exception 'FORBIDDEN: sign-in required';
  end if;
  if trimmed = '' then
    raise exception 'VALIDATION: name is required';
  end if;

  insert into public.families (name, created_by)
  values (trimmed, auth.uid())
  returning * into new_family;

  insert into public.memberships (family_id, user_id, role)
  values (new_family.id, auth.uid(), 'owner');

  return new_family;
end;
$$;

revoke all on function public.create_family(text) from public;
grant execute on function public.create_family(text) to authenticated, service_role;

create or replace function public.is_family_owner(fid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.family_id = fid
      and m.user_id = auth.uid()
      and m.role = 'owner'
  );
$$;

create or replace function public.is_family_co_owner(fid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.family_id = fid
      and m.user_id = auth.uid()
      and m.role = 'co_owner'
  );
$$;

revoke all on function public.is_family_owner(uuid) from public;
revoke all on function public.is_family_co_owner(uuid) from public;
grant execute on function public.is_family_owner(uuid) to authenticated, service_role;
grant execute on function public.is_family_co_owner(uuid) to authenticated, service_role;

create or replace function public.memberships_co_owner_cap()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  others int;
begin
  if new.role is distinct from 'co_owner' then
    return new;
  end if;
  select count(*) into others
  from public.memberships
  where family_id = new.family_id
    and role = 'co_owner'
    and user_id is distinct from new.user_id;
  if others >= 2 then
    raise exception 'VALIDATION: co-owner cap is 2';
  end if;
  return new;
end;
$$;

drop trigger if exists memberships_co_owner_cap on public.memberships;
create trigger memberships_co_owner_cap
  before insert or update of role on public.memberships
  for each row
  execute function public.memberships_co_owner_cap();

revoke all on function public.memberships_co_owner_cap() from public;

create or replace function public.families_guard_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_setting('app.family_purge', true) = 'on' then
    return new;
  end if;

  if auth.uid() is null then
    if current_user in ('authenticated', 'anon') then
      raise exception 'FORBIDDEN: sign-in required';
    end if;
    return new;
  end if;

  if new.id is distinct from old.id
     or new.created_by is distinct from old.created_by
     or new.parent_family_id is distinct from old.parent_family_id then
    raise exception 'FORBIDDEN: field is locked';
  end if;

  if new.deleted_at is not null and old.deleted_at is null then
    if not public.is_family_owner(old.id) then
      raise exception 'FORBIDDEN: owner only';
    end if;
  elsif new.deleted_at is null and old.deleted_at is not null then
    if not (
      public.is_family_owner(old.id) or public.is_family_co_owner(old.id)
    ) then
      raise exception 'FORBIDDEN: owner or co-owner only';
    end if;
  elsif new.deleted_at is distinct from old.deleted_at then
    raise exception 'FORBIDDEN: owner only';
  end if;

  if new.name is distinct from old.name then
    if trim(coalesce(new.name, '')) = '' then
      raise exception 'VALIDATION: name is required';
    end if;
    if not (
      public.is_family_owner(old.id) or public.is_family_co_owner(old.id)
    ) then
      raise exception 'FORBIDDEN: owner or co-owner only';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists families_guard_update on public.families;
create trigger families_guard_update
  before update on public.families
  for each row
  execute function public.families_guard_update();

revoke all on function public.families_guard_update() from public;

drop policy if exists families_select_member on public.families;
create policy families_select_member
  on public.families for select
  to authenticated
  using (
    public.is_family_member(id)
    and (
      deleted_at is null
      or public.is_family_owner(id)
      or public.is_family_co_owner(id)
    )
  );

drop policy if exists families_update_member on public.families;
create policy families_update_owner_or_co_owner
  on public.families for update
  to authenticated
  using (public.is_family_owner(id) or public.is_family_co_owner(id))
  with check (public.is_family_owner(id) or public.is_family_co_owner(id));

drop policy if exists families_delete_member on public.families;

drop function if exists public.family_tree_ids(uuid);

create or replace function public.family_tree_ids(fid uuid)
returns table (id uuid)
language sql
stable
security definer
set search_path = public
as $$
  with recursive up as (
    select f.id, f.parent_family_id
    from public.families f
    where f.id = fid
    union all
    select parent.id, parent.parent_family_id
    from public.families parent
    join up on up.parent_family_id = parent.id
  ),
  root as (
    select up.id
    from up
    where up.parent_family_id is null
    limit 1
  ),
  down as (
    select f.id
    from public.families f
    where f.id = (select root.id from root)
    union all
    select child.id
    from public.families child
    join down d on child.parent_family_id = d.id
  )
  select down.id from down;
$$;

revoke all on function public.family_tree_ids(uuid) from public;

create or replace function public._require_family(fid uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'FORBIDDEN: sign-in required';
  end if;
  if not exists (select 1 from public.families where id = fid) then
    raise exception 'NOT_FOUND: family';
  end if;
end;
$$;

revoke all on function public._require_family(uuid) from public;

create or replace function public.rename_family(fid uuid, name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  trimmed text := trim(coalesce(name, ''));
begin
  perform public._require_family(fid);
  if trimmed = '' then
    raise exception 'VALIDATION: name is required';
  end if;
  if not (public.is_family_owner(fid) or public.is_family_co_owner(fid)) then
    raise exception 'FORBIDDEN: owner or co-owner only';
  end if;
  update public.families
  set name = trimmed, updated_at = now()
  where id = fid;
end;
$$;

create or replace function public.add_co_owner(fid uuid, target uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._require_family(fid);
  if not (public.is_family_owner(fid) or public.is_family_co_owner(fid)) then
    raise exception 'FORBIDDEN: owner or co-owner only';
  end if;
  update public.memberships
  set role = 'co_owner'
  where family_id = fid
    and user_id = target
    and role = 'member';
  if not found then
    raise exception 'VALIDATION: target must be a member';
  end if;
end;
$$;

create or replace function public.remove_co_owner(fid uuid, target uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._require_family(fid);
  if not public.is_family_owner(fid) then
    raise exception 'FORBIDDEN: owner only';
  end if;
  update public.memberships
  set role = 'member'
  where family_id = fid
    and user_id = target
    and role = 'co_owner';
  if not found then
    raise exception 'VALIDATION: target must be a co-owner';
  end if;
end;
$$;

create or replace function public.remove_member(fid uuid, target uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  tree_ids uuid[];
begin
  perform public._require_family(fid);
  if not (public.is_family_owner(fid) or public.is_family_co_owner(fid)) then
    raise exception 'FORBIDDEN: owner or co-owner only';
  end if;
  if target = auth.uid() then
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
end;
$$;

create or replace function public.transfer_ownership(
  fid uuid,
  new_owner uuid,
  former_becomes text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := auth.uid();
begin
  perform public._require_family(fid);
  if not public.is_family_owner(fid) then
    raise exception 'FORBIDDEN: owner only';
  end if;
  if former_becomes is distinct from 'co_owner'
     and former_becomes is distinct from 'member' then
    raise exception 'VALIDATION: former role must be co_owner or member';
  end if;
  if not exists (
    select 1
    from public.memberships
    where family_id = fid
      and user_id = new_owner
      and role = 'co_owner'
  ) then
    raise exception 'FORBIDDEN: target must be a co-owner';
  end if;

  -- Demote first so the one-owner index and the co-owner cap both hold.
  update public.memberships
  set role = 'member'
  where family_id = fid
    and user_id = caller;

  update public.memberships
  set role = 'owner'
  where family_id = fid
    and user_id = new_owner;

  if former_becomes = 'co_owner' then
    update public.memberships
    set role = 'co_owner'
    where family_id = fid
      and user_id = caller;
  end if;
end;
$$;

create or replace function public.soft_delete_family(fid uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._require_family(fid);
  if not public.is_family_owner(fid) then
    raise exception 'FORBIDDEN: owner only';
  end if;
  update public.families
  set deleted_at = now(), updated_at = now()
  where id = fid
    and deleted_at is null;
end;
$$;

create or replace function public.recover_family(fid uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted timestamptz;
begin
  perform public._require_family(fid);
  if not (public.is_family_owner(fid) or public.is_family_co_owner(fid)) then
    raise exception 'FORBIDDEN: owner or co-owner only';
  end if;
  select deleted_at into deleted from public.families where id = fid;
  if deleted is null then
    raise exception 'VALIDATION: family is not deleted';
  end if;
  if deleted < now() - interval '60 days' then
    raise exception 'FORBIDDEN: recovery window closed';
  end if;
  update public.families
  set deleted_at = null, updated_at = now()
  where id = fid;
end;
$$;

create or replace function public.purge_expired_families()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  expired_id uuid;
begin
  perform set_config('app.family_purge', 'on', true);
  for expired_id in
    select id
    from public.families
    where deleted_at is not null
      and deleted_at < now() - interval '60 days'
  loop
    update public.families
    set parent_family_id = null
    where parent_family_id = expired_id;
    delete from public.families where id = expired_id;
  end loop;
end;
$$;

revoke all on function public.rename_family(uuid, text) from public;
revoke all on function public.add_co_owner(uuid, uuid) from public;
revoke all on function public.remove_co_owner(uuid, uuid) from public;
revoke all on function public.remove_member(uuid, uuid) from public;
revoke all on function public.transfer_ownership(uuid, uuid, text) from public;
revoke all on function public.soft_delete_family(uuid) from public;
revoke all on function public.recover_family(uuid) from public;
revoke all on function public.purge_expired_families() from public;

grant execute on function public.rename_family(uuid, text) to authenticated, service_role;
grant execute on function public.add_co_owner(uuid, uuid) to authenticated, service_role;
grant execute on function public.remove_co_owner(uuid, uuid) to authenticated, service_role;
grant execute on function public.remove_member(uuid, uuid) to authenticated, service_role;
grant execute on function public.transfer_ownership(uuid, uuid, text) to authenticated, service_role;
grant execute on function public.soft_delete_family(uuid) to authenticated, service_role;
grant execute on function public.recover_family(uuid) to authenticated, service_role;
grant execute on function public.purge_expired_families() to service_role;

create or replace function public.upsert_story_member(fid uuid, resolved uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if resolved is null or fid is null then
    return;
  end if;
  insert into public.memberships (family_id, user_id, role)
  values (fid, resolved, 'member')
  on conflict (family_id, user_id) do nothing;
end;
$$;

revoke all on function public.upsert_story_member(uuid, uuid) from public;

create or replace function public.resolve_person_user(
  p_user_id uuid,
  p_email text
)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  matches int;
  resolved uuid;
begin
  if p_user_id is not null then
    return p_user_id;
  end if;
  if p_email is null or trim(p_email) = '' then
    return null;
  end if;
  select count(*) into matches
  from public.profiles
  where email is not null
    and lower(email) = lower(trim(p_email));
  if matches is distinct from 1 then
    return null;
  end if;
  select id into resolved
  from public.profiles
  where email is not null
    and lower(email) = lower(trim(p_email));
  return resolved;
end;
$$;

revoke all on function public.resolve_person_user(uuid, text) from public;

create or replace function public.ensure_story_person_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  person public.people;
  resolved uuid;
  story_family uuid;
begin
  if tg_table_name = 'story_people' then
    select * into person from public.people where id = new.person_id;
    if not found then
      return new;
    end if;
    resolved := public.resolve_person_user(person.user_id, person.email);
    select family_id into story_family
    from public.stories
    where id = new.story_id;
    perform public.upsert_story_member(story_family, resolved);
    return new;
  end if;

  if not exists (
    select 1
    from public.story_people sp
    join public.stories s on s.id = sp.story_id
    where sp.person_id = new.id
  ) then
    return new;
  end if;

  resolved := public.resolve_person_user(new.user_id, new.email);
  for story_family in
    select distinct s.family_id
    from public.story_people sp
    join public.stories s on s.id = sp.story_id
    where sp.person_id = new.id
  loop
    perform public.upsert_story_member(story_family, resolved);
  end loop;
  return new;
end;
$$;

drop trigger if exists story_people_ensure_membership on public.story_people;
create trigger story_people_ensure_membership
  after insert on public.story_people
  for each row
  execute function public.ensure_story_person_membership();

drop trigger if exists people_ensure_membership on public.people;
create trigger people_ensure_membership
  after update of user_id, email on public.people
  for each row
  when (
    old.user_id is distinct from new.user_id
    or old.email is distinct from new.email
  )
  execute function public.ensure_story_person_membership();

revoke all on function public.ensure_story_person_membership() from public;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'purge-expired-families',
      '15 3 * * *',
      'select public.purge_expired_families()'
    );
  end if;
exception
  when undefined_table or undefined_function or insufficient_privilege then
    null;
end;
$$;
