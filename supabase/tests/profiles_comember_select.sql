-- M5 profiles SELECT: co-member can read display_name; stranger cannot.
-- Harness: insert auth.users (trigger → profiles); SET LOCAL ROLE authenticated
-- + request.jwt.claim.sub/role; create_family as A and C; postgres-only
-- membership insert for B into family_a. Entire script begin + ROLLBACK.

begin;
create extension if not exists pgtap with schema extensions;

select plan(3);

create temporary table test_ctx (
  user_a uuid primary key,
  user_b uuid not null,
  user_c uuid not null,
  family_a uuid,
  family_c uuid
);

grant all on table test_ctx to authenticated, anon, service_role;

insert into test_ctx (user_a, user_b, user_c)
values (
  'e1111111-1111-4111-8111-111111111111',
  'e2222222-2222-4222-8222-222222222222',
  'e3333333-3333-4333-8333-333333333333'
);

insert into auth.users (id, email, raw_user_meta_data)
select user_a, 'comember-a@test.local', '{"display_name":"User A"}'::jsonb from test_ctx
union all
select user_b, 'comember-b@test.local', '{"display_name":"User B"}'::jsonb from test_ctx
union all
select user_c, 'stranger-c@test.local', '{"display_name":"User C"}'::jsonb from test_ctx;

-- User A creates family_a
set local role authenticated;
set local request.jwt.claim.sub = 'e1111111-1111-4111-8111-111111111111';
set local request.jwt.claim.role = 'authenticated';

update test_ctx
set family_a = (public.create_family('Family A')).id;

-- User C creates family_c (no shared membership with A/B)
set local request.jwt.claim.sub = 'e3333333-3333-4333-8333-333333333333';

update test_ctx
set family_c = (public.create_family('Family C')).id;

-- Test harness only: postgres inserts B as member of family_a (Edge-equivalent)
reset role;

insert into public.memberships (family_id, user_id, role)
select family_a, user_b, 'member' from test_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'e2222222-2222-4222-8222-222222222222';
set local request.jwt.claim.role = 'authenticated';

select is(
  (select display_name from public.profiles p
   join test_ctx c on p.id = c.user_a),
  'User A',
  'User B can SELECT co-member User A display_name'
);

set local request.jwt.claim.sub = 'e1111111-1111-4111-8111-111111111111';

select is(
  (select display_name from public.profiles p
   join test_ctx c on p.id = c.user_b),
  'User B',
  'User A can SELECT co-member User B display_name'
);

-- User C shares no family with A
set local request.jwt.claim.sub = 'e3333333-3333-4333-8333-333333333333';

select is(
  (select count(*)::int from public.profiles p
   join test_ctx c on p.id = c.user_a),
  0,
  'User C cannot SELECT User A profile (no shared family)'
);

select * from finish();
rollback;
