-- §14 #5–#6: invite expiry row + single-use accept status (DB plane for Edge).
begin;
create extension if not exists pgtap with schema extensions;

select plan(5);

create temporary table invite_ctx (
  user_a uuid primary key,
  user_b uuid not null,
  family_id uuid,
  invite_id uuid,
  token text
);

grant all on table invite_ctx to authenticated, anon, service_role;

insert into invite_ctx (user_a, user_b)
values (
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'dddddddd-dddd-dddd-dddd-dddddddddddd'
);

insert into auth.users (id, email, raw_user_meta_data)
select user_a, 'invite-a@test.local', '{"display_name":"Invite A"}'::jsonb from invite_ctx
union all
select user_b, 'invite-b@test.local', '{"display_name":"Invite B"}'::jsonb from invite_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
set local request.jwt.claim.role = 'authenticated';

update invite_ctx
set family_id = (public.create_family('Invite Family')).id;

reset role;

insert into public.invites (
  id, family_id, invited_by, email, token, status, expires_at
)
select
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  family_id,
  user_a,
  'invite-b@test.local',
  'tok_live_m2_test',
  'pending',
  now() + interval '7 days'
from invite_ctx;

update invite_ctx
set invite_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    token = 'tok_live_m2_test';

insert into public.invites (
  family_id, invited_by, email, token, status, expires_at
)
select
  family_id,
  user_a,
  'invite-b@test.local',
  'tok_expired_m2_test',
  'pending',
  now() - interval '1 day'
from invite_ctx;

select ok(
  exists (
    select 1 from public.invites
    where token = 'tok_expired_m2_test'
      and expires_at < now()
      and status = 'pending'
  ),
  'expired pending invite exists for INVITE_EXPIRED'
);

select ok(
  exists (
    select 1 from public.invites
    where token = 'tok_live_m2_test'
      and status = 'pending'
      and expires_at > now()
  ),
  'live pending invite exists'
);

insert into public.memberships (family_id, user_id, role)
select family_id, user_b, 'member'::public.membership_role from invite_ctx
on conflict (family_id, user_id) do update set role = excluded.role;

update public.invites
set status = 'accepted',
    accepted_by = 'dddddddd-dddd-dddd-dddd-dddddddddddd',
    accepted_at = now()
where token = 'tok_live_m2_test' and status = 'pending';

select is(
  (select status::text from public.invites where token = 'tok_live_m2_test'),
  'accepted',
  'invite marked accepted after join'
);

select ok(
  exists (
    select 1 from public.memberships
    where user_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
      and family_id = (select family_id from invite_ctx)
  ),
  'invitee membership exists'
);

select is(
  (select status::text from public.invites where token = 'tok_live_m2_test'),
  'accepted',
  'second accept would see INVITE_ACCEPTED'
);

select * from finish();
rollback;
