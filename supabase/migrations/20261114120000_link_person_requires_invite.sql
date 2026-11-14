-- A person link happens only while accepting that person's pending invite.

create or replace function public.link_unlinked_person(
  p_person_id uuid,
  p_user_id uuid,
  p_root uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.people other
    join public.families mine on mine.id = other.family_id
    where other.user_id = p_user_id
      and other.id <> p_person_id
      and mine.deleted_at is null
      and public.family_tree_root(other.family_id) = p_root
  ) then
    return;
  end if;

  update public.people
  set user_id = p_user_id
  where id = p_person_id
    and user_id is null;
end;
$$;

create or replace function public.invite_email_matches(
  p_invite_email text,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_email text;
begin
  if p_invite_email is null or btrim(p_invite_email) = '' then
    return;
  end if;

  select u.email into caller_email
  from auth.users u
  where u.id = p_user_id;

  if caller_email is null
     or lower(btrim(caller_email))
       is distinct from lower(btrim(p_invite_email)) then
    raise exception 'INVITE_INVALID:';
  end if;
end;
$$;

create or replace function public.assert_invite_accept(
  p_invite public.invites,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  person public.people;
  invite_root uuid;
begin
  if exists (
    select 1
    from public.families f
    where f.id = p_invite.family_id
      and f.deleted_at is not null
  ) then
    raise exception 'INVITE_INVALID:';
  end if;

  perform public.invite_email_matches(p_invite.email, p_user_id);

  if p_invite.person_id is null then
    return;
  end if;

  select * into person
  from public.people
  where id = p_invite.person_id;

  if not found then
    raise exception 'NOT_FOUND:';
  end if;

  invite_root := public.family_tree_root(p_invite.family_id);
  if invite_root is null
     or invite_root is distinct from public.family_tree_root(person.family_id)
  then
    raise exception 'NOT_FOUND:';
  end if;

  perform public.link_unlinked_person(person.id, p_user_id, invite_root);
end;
$$;

create or replace function public.link_accepted_person(p_person_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_person_id is not null then
    raise exception 'INVITE_INVALID:';
  end if;
  raise exception 'INVITE_INVALID:';
end;
$$;

create or replace function public.link_accepted_person(
  p_invite_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  invite public.invites;
begin
  if p_user_id is null then
    raise exception 'NOT_FOUND:';
  end if;

  select * into invite
  from public.invites
  where id = p_invite_id
  for update;

  if not found
     or invite.status is distinct from 'pending'::public.invite_status then
    raise exception 'INVITE_INVALID:';
  end if;

  perform public.assert_invite_accept(invite, p_user_id);

  update public.invites
  set status = 'accepted',
      accepted_by = p_user_id,
      accepted_at = pg_catalog.now()
  where id = invite.id
    and status = 'pending'::public.invite_status;

  if not found then
    raise exception 'INVITE_INVALID:';
  end if;
end;
$$;

revoke all on function public.invite_email_matches(text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.link_unlinked_person(uuid, uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.assert_invite_accept(public.invites, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.link_accepted_person(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.link_accepted_person(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.link_accepted_person(uuid, uuid) to service_role;
