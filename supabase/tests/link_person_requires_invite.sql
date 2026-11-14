-- A person link requires the caller's own pending invite in that family tree.

begin;
create extension if not exists pgtap with schema extensions;

select plan(15);

create temporary table link_ctx (
  owner_id uuid primary key,
  member_id uuid not null,
  mate_id uuid not null,
  stranger_id uuid not null,
  parent_id uuid,
  child_id uuid,
  other_id uuid,
  kin_id uuid,
  foreign_id uuid
);

grant all on table link_ctx to authenticated, anon, service_role;

insert into link_ctx (owner_id, member_id, mate_id, stranger_id)
values (
  'a14c0000-0000-4000-8000-0000000000a1',
  'b14c0000-0000-4000-8000-0000000000b1',
  'c14c0000-0000-4000-8000-0000000000c1',
  'd14c0000-0000-4000-8000-0000000000d1'
);

insert into auth.users (id, email, raw_user_meta_data)
select owner_id, 'link-owner@test.local', '{"display_name":"Owner"}'::jsonb from link_ctx
union all
select member_id, 'link-member@test.local', '{"display_name":"Member"}'::jsonb from link_ctx
union all
select mate_id, 'link-mate@test.local', '{"display_name":"Mate"}'::jsonb from link_ctx
union all
select stranger_id, 'link-stranger@test.local', '{"display_name":"Stranger"}'::jsonb from link_ctx;

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a14c0000-0000-4000-8000-0000000000a1';

update link_ctx set parent_id = (public.create_family('Link Parent')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.families (id, name, parent_family_id, created_by)
select
  '11111111-14c1-4111-8111-111111111111'::uuid,
  'Link Child',
  parent_id,
  owner_id
from link_ctx;

update link_ctx
set child_id = '11111111-14c1-4111-8111-111111111111';

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a14c0000-0000-4000-8000-0000000000a1';

update link_ctx set other_id = (public.create_family('Other Tree')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.memberships (family_id, user_id, role)
select parent_id, member_id, 'member'::public.membership_role from link_ctx
union all
select child_id, mate_id, 'member'::public.membership_role from link_ctx;

insert into public.people (id, family_id, name, created_by)
select
  '22222222-14c1-4111-8111-222222222222'::uuid,
  parent_id,
  'Kin',
  owner_id
from link_ctx
union all
select
  '33333333-14c1-4111-8111-333333333333'::uuid,
  other_id,
  'Foreign',
  owner_id
from link_ctx;

update link_ctx
set
  kin_id = '22222222-14c1-4111-8111-222222222222',
  foreign_id = '33333333-14c1-4111-8111-333333333333';

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'b14c0000-0000-4000-8000-0000000000b1';

select throws_ok(
  $$select public.link_accepted_person((select kin_id from link_ctx))$$,
  '42501',
  null,
  'a member cannot link a person by id'
);

set local request.jwt.claim.sub = 'c14c0000-0000-4000-8000-0000000000c1';

select throws_ok(
  $$select public.link_accepted_person((select kin_id from link_ctx))$$,
  '42501',
  null,
  'a tree-mate cannot link a person by id'
);

set local request.jwt.claim.sub = 'd14c0000-0000-4000-8000-0000000000d1';

select throws_ok(
  $$select public.link_accepted_person((select kin_id from link_ctx))$$,
  '42501',
  null,
  'a stranger cannot link a person by id'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  (select user_id from public.people where id = (select kin_id from link_ctx)),
  null,
  'the person stays unlinked'
);

insert into public.invites (family_id, invited_by, email, token, person_id)
select parent_id, owner_id, 'Link-Member@test.local', 'tok-member', kin_id from link_ctx;

select throws_ok(
  $$select public.link_accepted_person(
      (select id from public.invites where token = 'tok-member'),
      (select stranger_id from link_ctx)
    )$$,
  'P0001',
  'INVITE_INVALID:',
  'a stranger cannot accept another person''s invite'
);

insert into public.invites (family_id, invited_by, email, token, person_id)
select parent_id, owner_id, 'link-mate@test.local', 'tok-mate-foreign', foreign_id
from link_ctx;

select throws_ok(
  $$select public.link_accepted_person(
      (select id from public.invites where token = 'tok-mate-foreign'),
      (select mate_id from link_ctx)
    )$$,
  'P0001',
  'NOT_FOUND:',
  'a tree-mate cannot link a person outside the invite tree'
);

select is(
  (select status::text from public.invites where token = 'tok-mate-foreign'),
  'pending',
  'an out-of-tree invite stays pending'
);

insert into public.invites (family_id, invited_by, email, token, person_id)
select parent_id, owner_id, 'link-member@test.local', 'tok-deleted', kin_id from link_ctx;

update public.families
set deleted_at = now()
where id = (select other_id from link_ctx);

update public.families
set deleted_at = now()
where id = (select parent_id from link_ctx);

select throws_ok(
  $$select public.link_accepted_person(
      (select id from public.invites where token = 'tok-deleted'),
      (select member_id from link_ctx)
    )$$,
  'P0001',
  'INVITE_INVALID:',
  'a member cannot accept an invite for a soft-deleted family'
);

update public.families
set deleted_at = null
where id = (select parent_id from link_ctx);

select lives_ok(
  $$select public.link_accepted_person(
      (select id from public.invites where token = 'tok-member'),
      (select member_id from link_ctx)
    )$$,
  'a matching invite links the member'
);

select is(
  (select user_id from public.people where id = (select kin_id from link_ctx)),
  (select member_id from link_ctx),
  'the member is linked'
);

select throws_ok(
  $$select public.link_accepted_person(
      (select id from public.invites where token = 'tok-member'),
      (select member_id from link_ctx)
    )$$,
  'P0001',
  'INVITE_INVALID:',
  'a second accept of the same invite is refused'
);

select is(
  has_function_privilege(
    'service_role',
    'public.link_accepted_person(uuid, uuid)',
    'execute'
  ),
  true,
  'service_role can link from an invite'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.link_accepted_person(uuid, uuid)',
    'execute'
  ),
  false,
  'authenticated cannot execute the invite link'
);

insert into public.people (id, family_id, name, created_by)
select
  '44444444-14c1-4111-8111-444444444444'::uuid,
  parent_id,
  'Open Kin',
  owner_id
from link_ctx;

insert into public.invites (family_id, invited_by, email, token, person_id)
select
  parent_id,
  owner_id,
  null,
  'tok-open',
  '44444444-14c1-4111-8111-444444444444'
from link_ctx;

select lives_ok(
  $$select public.link_accepted_person(
      (select id from public.invites where token = 'tok-open'),
      (select stranger_id from link_ctx)
    )$$,
  'a shareable link with no email can be accepted'
);

select is(
  (select user_id from public.people where id = '44444444-14c1-4111-8111-444444444444'),
  (select stranger_id from link_ctx),
  'the shareable link links the accepting user'
);

select * from finish();
rollback;
