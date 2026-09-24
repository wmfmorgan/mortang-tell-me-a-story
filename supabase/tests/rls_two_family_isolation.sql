-- §14 two-family RLS isolation: User A cannot SELECT family 2 tenant rows.
-- Harness: insert auth.users (trigger → profiles); SET LOCAL ROLE authenticated
-- + request.jwt.claim.sub/role; create_family as each user; seed as family owner;
-- assert cross-family SELECTs empty. Entire script runs in a transaction + ROLLBACK.

begin;
create extension if not exists pgtap with schema extensions;

select plan(7);

create temporary table test_ctx (
  user_a uuid primary key,
  user_b uuid not null,
  family_a uuid,
  family_b uuid
);

grant all on table test_ctx to authenticated, anon, service_role;

insert into test_ctx (user_a, user_b)
values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
);

insert into auth.users (id, email, raw_user_meta_data)
select user_a, 'user-a@test.local', '{"display_name":"User A"}'::jsonb from test_ctx
union all
select user_b, 'user-b@test.local', '{"display_name":"User B"}'::jsonb from test_ctx;

-- User A creates family 1
set local role authenticated;
set local request.jwt.claim.sub = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
set local request.jwt.claim.role = 'authenticated';

update test_ctx
set family_a = (public.create_family('Family A')).id;

-- User B creates family 2 and seeds tenant rows
set local request.jwt.claim.sub = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

update test_ctx
set family_b = (public.create_family('Family B')).id;

insert into public.people (id, family_id, name, relationship, created_by)
select
  'b1000000-0000-4000-8000-000000000001',
  family_b,
  'Uncle Bob',
  'uncle',
  user_b
from test_ctx;

insert into public.places (id, family_id, label, address, lat, lng)
select
  'b2000000-0000-4000-8000-000000000002',
  family_b,
  'Cabin',
  '1 Lake Rd',
  45.0,
  -93.0
from test_ctx;

insert into public.stories (
  id, family_id, author_id, title, body, timeframe_start, place_id, status
)
select
  'b3000000-0000-4000-8000-000000000003',
  family_b,
  user_b,
  'Family B Story',
  'secret body',
  '2000-01-01'::date,
  'b2000000-0000-4000-8000-000000000002',
  'draft'::public.story_status
from test_ctx;

insert into public.photos (
  id, story_id, family_id, uploader_id, storage_path, sort_order
)
select
  'b4000000-0000-4000-8000-000000000004',
  'b3000000-0000-4000-8000-000000000003',
  family_b,
  user_b,
  family_b::text
    || '/b3000000-0000-4000-8000-000000000003/b4000000-0000-4000-8000-000000000004.jpg',
  0
from test_ctx;

insert into public.invites (id, family_id, invited_by, email, token, status)
select
  'b5000000-0000-4000-8000-000000000005',
  family_b,
  user_b,
  'invitee@test.local',
  'token-family-b-only',
  'pending'::public.invite_status
from test_ctx;

-- Switch to User A: must not see any family B rows
set local request.jwt.claim.sub = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

select is(
  (select count(*)::int from public.stories s
   join test_ctx c on s.family_id = c.family_b),
  0,
  'User A cannot SELECT family 2 stories'
);

select is(
  (select count(*)::int from public.photos p
   join test_ctx c on p.family_id = c.family_b),
  0,
  'User A cannot SELECT family 2 photos'
);

select is(
  (select count(*)::int from public.people p
   join test_ctx c on p.family_id = c.family_b),
  0,
  'User A cannot SELECT family 2 people'
);

select is(
  (select count(*)::int from public.places p
   join test_ctx c on p.family_id = c.family_b),
  0,
  'User A cannot SELECT family 2 places'
);

select is(
  (select count(*)::int from public.invites i
   join test_ctx c on i.family_id = c.family_b),
  0,
  'User A cannot SELECT family 2 invites'
);

select isnt(
  (select count(*)::int from public.families f
   join test_ctx c on f.id = c.family_a),
  0,
  'User A can SELECT own family'
);

select is_empty(
  $$select id from public.stories where id = 'b3000000-0000-4000-8000-000000000003'$$,
  'User A cannot SELECT family 2 story by primary key'
);

select * from finish();
rollback;
