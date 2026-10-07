-- M10: roles, soft-delete, tree remove, transfer, story-tag membership.
-- Harness matches the other pgTAP files: auth.users insert, SET LOCAL role,
-- request.jwt.claim.sub. The script rolls back.

begin;
create extension if not exists pgtap with schema extensions;

select plan(30);

create temporary table m10_ctx (
  user_a uuid primary key,
  user_b uuid not null,
  user_c uuid not null,
  user_d uuid not null,
  user_e uuid not null,
  user_g uuid not null,
  user_m uuid not null,
  family_a uuid,
  family_t uuid,
  child_id uuid
);

grant all on table m10_ctx to authenticated, anon, service_role;

insert into m10_ctx (
  user_a, user_b, user_c, user_d, user_e, user_g, user_m
)
values (
  'a10a0000-0000-4000-8000-00000000000a',
  'b10b0000-0000-4000-8000-00000000000b',
  'c10c0000-0000-4000-8000-00000000000c',
  'd10d0000-0000-4000-8000-00000000000d',
  'e10e0000-0000-4000-8000-00000000000e',
  'f10f0000-0000-4000-8000-000000000010',
  '11111111-1111-4111-8111-000000000011'
);

insert into auth.users (id, email, raw_user_meta_data)
select user_a, 'a@test.local', '{"display_name":"User A"}'::jsonb from m10_ctx
union all
select user_b, 'b@test.local', '{"display_name":"User B"}'::jsonb from m10_ctx
union all
select user_c, 'c@test.local', '{"display_name":"User C"}'::jsonb from m10_ctx
union all
select user_d, 'd@test.local', '{"display_name":"User D"}'::jsonb from m10_ctx
union all
select user_e, 'e@test.local', '{"display_name":"User E"}'::jsonb from m10_ctx
union all
select user_g, 'g@test.local', '{"display_name":"User G"}'::jsonb from m10_ctx
union all
select user_m, 'm@test.local', '{"display_name":"User M"}'::jsonb from m10_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a10a0000-0000-4000-8000-00000000000a';
set local request.jwt.claim.role = 'authenticated';

update m10_ctx
set family_a = (public.create_family('Family A')).id;

select throws_ok(
  $$ select public.create_family('   ') $$,
  'P0001',
  'VALIDATION: name is required',
  'blank family name is rejected'
);

select is(
  (
    select role::text
    from public.memberships
    where family_id = (select family_a from m10_ctx)
      and user_id = (select user_a from m10_ctx)
  ),
  'owner',
  'create_family inserts the caller as owner'
);

select is(
  (
    select count(*)
    from public.memberships
    where family_id = (select family_a from m10_ctx)
      and role = 'owner'
  ),
  1::bigint,
  'exactly one owner'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.memberships (family_id, user_id, role)
select family_a, user_b, 'member'::public.membership_role from m10_ctx
union all
select family_a, user_c, 'member'::public.membership_role from m10_ctx
union all
select family_a, user_d, 'member'::public.membership_role from m10_ctx
union all
select family_a, user_m, 'member'::public.membership_role from m10_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a10a0000-0000-4000-8000-00000000000a';
set local request.jwt.claim.role = 'authenticated';

select lives_ok(
  $$ select public.add_co_owner(
    (select family_a from m10_ctx),
    (select user_b from m10_ctx)
  ) $$,
  'first co-owner'
);

select lives_ok(
  $$ select public.add_co_owner(
    (select family_a from m10_ctx),
    (select user_c from m10_ctx)
  ) $$,
  'second co-owner'
);

select throws_ok(
  $$ select public.add_co_owner(
    (select family_a from m10_ctx),
    (select user_d from m10_ctx)
  ) $$,
  'P0001',
  'VALIDATION: co-owner cap is 2',
  'third co-owner fails'
);

-- Transfer family stays owned by A so Family A can still be soft-deleted.
update m10_ctx
set family_t = (public.create_family('Family T')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.memberships (family_id, user_id, role)
select family_t, user_c, 'member'::public.membership_role from m10_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a10a0000-0000-4000-8000-00000000000a';
set local request.jwt.claim.role = 'authenticated';

select lives_ok(
  $$ select public.add_co_owner(
    (select family_t from m10_ctx),
    (select user_c from m10_ctx)
  ) $$,
  'co-owner on the transfer family'
);

select throws_ok(
  $$ select public.transfer_ownership(
    (select family_t from m10_ctx),
    (select user_d from m10_ctx),
    'member'
  ) $$,
  'P0001',
  'FORBIDDEN: target must be a co-owner',
  'transfer rejects a target who is not a co-owner'
);

select lives_ok(
  $$ select public.transfer_ownership(
    (select family_t from m10_ctx),
    (select user_c from m10_ctx),
    'member'
  ) $$,
  'transfer is immediate'
);

select is(
  (
    select role::text
    from public.memberships
    where family_id = (select family_t from m10_ctx)
      and user_id = (select user_c from m10_ctx)
  ),
  'owner',
  'new owner is owner immediately'
);

select is(
  (
    select role::text
    from public.memberships
    where family_id = (select family_t from m10_ctx)
      and user_id = (select user_a from m10_ctx)
  ),
  'member',
  'former owner is a member immediately'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

update m10_ctx
set child_id = 'c10c0000-0000-4000-8000-0000000000c1';

insert into public.families (id, name, parent_family_id, created_by)
select child_id, 'Child', family_a, user_a from m10_ctx;

insert into public.memberships (family_id, user_id, role)
select child_id, user_a, 'owner'::public.membership_role from m10_ctx
union all
select child_id, user_d, 'member'::public.membership_role from m10_ctx;

insert into public.stories (
  id, family_id, author_id, body, timeframe_start, status
)
select
  '51000000-0000-4000-8000-000000000051',
  family_a,
  user_a,
  'kept',
  '1990-01-01'::date,
  'published'
from m10_ctx;

insert into public.people (id, family_id, name, relationship, email, created_by)
select
  '61000000-0000-4000-8000-000000000061',
  family_a,
  'Dee',
  'Sibling',
  'd@test.local',
  user_a
from m10_ctx;

insert into public.story_people (story_id, person_id)
values (
  '51000000-0000-4000-8000-000000000051',
  '61000000-0000-4000-8000-000000000061'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a10a0000-0000-4000-8000-00000000000a';
set local request.jwt.claim.role = 'authenticated';

select lives_ok(
  $$ select public.remove_member(
    (select family_a from m10_ctx),
    (select user_d from m10_ctx)
  ) $$,
  'owner removes a member from the tree'
);

select is(
  (
    select count(*)
    from public.memberships
    where user_id = (select user_d from m10_ctx)
      and family_id in (
        (select family_a from m10_ctx),
        (select child_id from m10_ctx)
      )
  ),
  0::bigint,
  'remove-member drops every tree membership'
);

select is(
  (
    select count(*)
    from public.story_people
    where person_id = '61000000-0000-4000-8000-000000000061'
  ),
  1::bigint,
  'remove-member leaves story_people'
);

-- Tagging a resolved person upserts member and does not demote owner.
reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.people (id, family_id, name, relationship, email, created_by)
select
  '62000000-0000-4000-8000-000000000062',
  family_a,
  'Gee',
  'Cousin',
  'g@test.local',
  user_a
from m10_ctx;

insert into public.people (id, family_id, name, relationship, email, created_by)
select
  '63000000-0000-4000-8000-000000000063',
  family_a,
  'Nope',
  'Other',
  'nobody@test.local',
  user_a
from m10_ctx;

insert into public.people (id, family_id, name, relationship, email, created_by)
select
  '64000000-0000-4000-8000-000000000064',
  family_a,
  'Owner tag',
  'Other',
  'a@test.local',
  user_a
from m10_ctx;

insert into public.story_people (story_id, person_id)
values
  ('51000000-0000-4000-8000-000000000051', '62000000-0000-4000-8000-000000000062'),
  ('51000000-0000-4000-8000-000000000051', '63000000-0000-4000-8000-000000000063'),
  ('51000000-0000-4000-8000-000000000051', '64000000-0000-4000-8000-000000000064');

select is(
  (
    select role::text
    from public.memberships
    where family_id = (select family_a from m10_ctx)
      and user_id = (select user_g from m10_ctx)
  ),
  'member',
  'tagging a matching email upserts member'
);

select is(
  (
    select role::text
    from public.memberships
    where family_id = (select family_a from m10_ctx)
      and user_id = (select user_a from m10_ctx)
  ),
  'owner',
  'tagging the owner does not demote them'
);

select is(
  (select count(*) from auth.users where email = 'nobody@test.local'),
  0::bigint,
  'an unknown email does not create an auth user'
);

set local role authenticated;
set local request.jwt.claim.sub = 'c10c0000-0000-4000-8000-00000000000c';
set local request.jwt.claim.role = 'authenticated';

select throws_ok(
  $$ select public.soft_delete_family((select family_a from m10_ctx)) $$,
  'P0001',
  'FORBIDDEN: owner only',
  'co-owner cannot soft-delete'
);

set local request.jwt.claim.sub = 'a10a0000-0000-4000-8000-00000000000a';

select lives_ok(
  $$ select public.soft_delete_family((select family_a from m10_ctx)) $$,
  'owner soft-deletes'
);

select is(
  (
    select parent_family_id
    from public.families
    where id = (select child_id from m10_ctx)
  ),
  (select family_a from m10_ctx),
  'soft-delete keeps the child parent link'
);

set local request.jwt.claim.sub = '11111111-1111-4111-8111-000000000011';

select is(
  (
    select count(*)
    from public.families
    where id = (select family_a from m10_ctx)
  ),
  0::bigint,
  'a plain member cannot select a soft-deleted family'
);

set local request.jwt.claim.sub = 'e10e0000-0000-4000-8000-00000000000e';

select is(
  (
    select count(*)
    from public.families
    where id = (select family_a from m10_ctx)
  ),
  0::bigint,
  'a stranger cannot select a soft-deleted family'
);

set local request.jwt.claim.sub = 'c10c0000-0000-4000-8000-00000000000c';

select is(
  (
    select count(*)
    from public.families
    where id = (select family_a from m10_ctx)
  ),
  1::bigint,
  'a co-owner can select a soft-deleted family'
);

select lives_ok(
  $$ select public.recover_family((select family_a from m10_ctx)) $$,
  'co-owner recovers inside 60 days'
);

select ok(
  (
    select deleted_at is null
    from public.families
    where id = (select family_a from m10_ctx)
  ),
  'recover clears deleted_at'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', '', true);

update public.families
set deleted_at = now() - interval '61 days'
where id = (select family_a from m10_ctx);

set local role authenticated;
set local request.jwt.claim.sub = 'a10a0000-0000-4000-8000-00000000000a';
set local request.jwt.claim.role = 'authenticated';

select throws_ok(
  $$ select public.recover_family((select family_a from m10_ctx)) $$,
  'P0001',
  'FORBIDDEN: recovery window closed',
  'recover fails after 60 days'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', '', true);

select lives_ok(
  $$ select public.purge_expired_families() $$,
  'purge runs'
);

select is(
  (
    select parent_family_id
    from public.families
    where id = (select child_id from m10_ctx)
  ),
  null,
  'purge nulls the child parent link'
);

select is(
  (
    select count(*)
    from public.families
    where id = (select family_a from m10_ctx)
  ),
  0::bigint,
  'purge hard-deletes the parent'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a10a0000-0000-4000-8000-00000000000a';
set local request.jwt.claim.role = 'authenticated';

select throws_ok(
  $$
    insert into public.memberships (family_id, user_id, role)
    select family_t, user_e, 'member'::public.membership_role
    from m10_ctx
  $$,
  '42501',
  'new row violates row-level security policy for table "memberships"',
  'authenticated client cannot insert memberships'
);

select * from finish();
rollback;
