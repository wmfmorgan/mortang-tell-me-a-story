-- Resend and revoke pending invites. No new enum, column, or table.
-- Sent dates on the client are expires_at minus 7 days; invites have no created_at.

create or replace function public.resend_invite(iid uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  invite public.invites%rowtype;
  fam_name text;
  new_token text;
  new_exp timestamptz;
begin
  select * into invite from public.invites where id = iid;
  if not found then
    raise exception 'NOT_FOUND: invite not found';
  end if;
  if not (
    public.is_family_owner(invite.family_id)
    or public.is_family_co_owner(invite.family_id)
  ) then
    raise exception 'FORBIDDEN: owner or co-owner only';
  end if;
  if invite.status is distinct from 'pending' then
    raise exception 'INVITE_INVALID: invite is not pending';
  end if;
  if invite.email is null or length(trim(invite.email)) = 0 then
    raise exception 'VALIDATION: invite has no email address';
  end if;

  new_token := replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '');
  new_exp := now() + interval '7 days';

  update public.invites
  set token = new_token,
      expires_at = new_exp,
      status = 'pending'
  where id = iid;

  select name into fam_name from public.families where id = invite.family_id;

  return jsonb_build_object(
    'token', new_token,
    'email', trim(invite.email),
    'family_name', fam_name,
    'expires_at', new_exp
  );
end;
$$;

create or replace function public.revoke_invite(iid uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  invite public.invites%rowtype;
begin
  select * into invite from public.invites where id = iid;
  if not found then
    raise exception 'NOT_FOUND: invite not found';
  end if;
  if not (
    public.is_family_owner(invite.family_id)
    or public.is_family_co_owner(invite.family_id)
  ) then
    raise exception 'FORBIDDEN: owner or co-owner only';
  end if;
  if invite.status = 'accepted' then
    raise exception 'INVITE_INVALID: invite is not pending';
  end if;
  if invite.status = 'revoked' then
    return;
  end if;

  update public.invites
  set status = 'revoked'
  where id = iid;
end;
$$;

revoke all on function public.resend_invite(uuid) from public;
revoke all on function public.revoke_invite(uuid) from public;
grant execute on function public.resend_invite(uuid) to authenticated, service_role;
grant execute on function public.revoke_invite(uuid) to authenticated, service_role;
