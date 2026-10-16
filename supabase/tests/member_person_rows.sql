-- M14.1a: every live member has one linked people row.
-- Rolls back. Does not change policies.

begin;
create extension if not exists pgtap with schema extensions;

select plan(6);

create temporary table m14a_ctx (
  owner_id uuid primary key,
  invitee_id uuid not null,
  member_id uuid not null,
  open_id uuid not null,
  family_id uuid,
  other_person uuid,
  invite_person uuid,
  email_person uuid,
  people_snapshot text
);

grant all on table m14a_ctx to authenticated, anon, service_role;

insert into m14a_ctx (owner_id, invitee_id, member_id, open_id)
values (
  'a14a0000-0000-4000-8000-0000000000a1',
  'b14a0000-0000-4000-8000-0000000000b1',
  'c14a0000-0000-4000-8000-0000000000c1',
  'd14a0000-0000-4000-8000-0000000000d1'
);

insert into auth.users (id, email, raw_user_meta_data)
select owner_id, 'owner@test.local', '{"display_name":"Ada Owner"}'::jsonb
from m14a_ctx
union all
select invitee_id, 'invitee@test.local', '{"display_name":"Bea Invitee"}'::jsonb
from m14a_ctx
union all
select member_id, 'Member@test.local', '{"display_name":"Cam Member"}'::jsonb
from m14a_ctx
union all
select open_id, 'open@test.local', '{"display_name":"Open Member"}'::jsonb
from m14a_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a14a0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

update m14a_ctx
set family_id = (public.create_family('Member People')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

select results_eq(
  $$select p.name::text, p.user_id
    from public.people p
    join m14a_ctx c on c.family_id = p.family_id and c.owner_id = p.user_id$$,
  $$select 'Ada Owner'::text, owner_id from m14a_ctx$$,
  'owner gets a linked person on create_family'
);

update m14a_ctx
set other_person = '11111111-14a1-4111-8111-111111111111',
    invite_person = '22222222-14a1-4111-8111-222222222222',
    email_person = '33333333-14a1-4111-8111-333333333333';

insert into public.people (id, family_id, name, created_by)
select other_person, family_id, 'Other Kin', owner_id from m14a_ctx
union all
select invite_person, family_id, 'Invite Kin', owner_id from m14a_ctx;

insert into public.memberships (family_id, user_id, role)
select family_id, invitee_id, 'member'::public.membership_role from m14a_ctx
union all
select family_id, member_id, 'member'::public.membership_role from m14a_ctx
union all
select family_id, open_id, 'member'::public.membership_role from m14a_ctx;

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a14a0000-0000-4000-8000-0000000000a1';

select public.link_accepted_person((select other_person from m14a_ctx));

reset role;
select set_config('request.jwt.claim.sub', '', true);

select results_eq(
  $$select
      (select count(*)
        from public.people p
        join m14a_ctx c on c.family_id = p.family_id and c.owner_id = p.user_id),
      (select user_id from public.people where id = (select other_person from m14a_ctx))$$,
  $$values (1::bigint, null::uuid)$$,
  'accept with an already-linked person creates no duplicate'
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'b14a0000-0000-4000-8000-0000000000b1';

select public.link_accepted_person((select invite_person from m14a_ctx));

reset role;
select set_config('request.jwt.claim.sub', '', true);

select results_eq(
  $$select
      (select user_id from public.people where id = (select invite_person from m14a_ctx)),
      (select count(*)
        from public.people p
        join m14a_ctx c on c.family_id = p.family_id and c.invitee_id = p.user_id)$$,
  $$select invitee_id, 1::bigint from m14a_ctx$$,
  'accept with an invite person links it'
);

insert into public.invites (
  family_id, invited_by, email, token, status, expires_at, person_id
)
select
  family_id,
  owner_id,
  'open@test.local',
  'tok_m14a_open',
  'pending'::public.invite_status,
  now() + interval '7 days',
  null
from m14a_ctx;

update public.invites
set status = 'accepted',
    accepted_by = (select open_id from m14a_ctx),
    accepted_at = now()
where token = 'tok_m14a_open';

select results_eq(
  $$select count(*)::int, min(p.name)::text
    from public.people p
    join m14a_ctx c on c.family_id = p.family_id and c.open_id = p.user_id$$,
  $$values (1, 'Open Member'::text)$$,
  'accept without an invite person creates one linked row'
);

insert into public.people (id, family_id, name, email, created_by)
select email_person, family_id, 'Email Kin', 'member@test.local', owner_id
from m14a_ctx;

select public.backfill_member_person_rows();

select results_eq(
  $$select
      (select user_id from public.people where id = (select email_person from m14a_ctx)),
      (select count(*) from public.people p
        join m14a_ctx c on c.family_id = p.family_id)$$,
  $$select member_id, 5::bigint from m14a_ctx$$,
  'backfill links a same-email unlinked person instead of inserting'
);

update m14a_ctx
set people_snapshot = (
  select coalesce(
    string_agg(p.id::text || ':' || coalesce(p.user_id::text, ''), ',' order by p.id),
    ''
  )
  from public.people p
  join m14a_ctx c on c.family_id = p.family_id
);

select public.backfill_member_person_rows();

select is(
  (
    select coalesce(
      string_agg(p.id::text || ':' || coalesce(p.user_id::text, ''), ',' order by p.id),
      ''
    )
    from public.people p
    join m14a_ctx c on c.family_id = p.family_id
  ),
  (select people_snapshot from m14a_ctx),
  'backfill run twice changes nothing'
);

select * from finish();
rollback;
