-- §14 author rules + member photo INSERT (M1 RLS; no new policies).
-- Harness: insert auth.users (trigger → profiles); SET LOCAL ROLE authenticated
-- + request.jwt.claim.sub/role; create_family as each user; seed story as A;
-- postgres-only membership insert for B into family_a; assert as B.
-- Entire script runs in a transaction + ROLLBACK.

begin;
create extension if not exists pgtap with schema extensions;

select plan(4);

create temporary table test_ctx (
  user_a uuid primary key,
  user_b uuid not null,
  family_a uuid,
  family_b uuid,
  story_a uuid,
  place_a uuid
);

grant all on table test_ctx to authenticated, anon, service_role;

insert into test_ctx (user_a, user_b, story_a, place_a)
values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'a3000000-0000-4000-8000-000000000003',
  'a2000000-0000-4000-8000-000000000002'
);

insert into auth.users (id, email, raw_user_meta_data)
select user_a, 'author-a@test.local', '{"display_name":"User A"}'::jsonb from test_ctx
union all
select user_b, 'member-b@test.local', '{"display_name":"User B"}'::jsonb from test_ctx;

-- User A creates family_a and seeds place + story
set local role authenticated;
set local request.jwt.claim.sub = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
set local request.jwt.claim.role = 'authenticated';

update test_ctx
set family_a = (public.create_family('Family A')).id;

insert into public.places (id, family_id, label, address, lat, lng)
select
  place_a,
  family_a,
  'Kitchen',
  '1 Maple St',
  44.0,
  -93.0
from test_ctx;

insert into public.stories (
  id, family_id, author_id, title, body, timeframe_start, place_id, status
)
select
  story_a,
  family_a,
  user_a,
  null,
  'author body',
  '1990-01-01'::date,
  place_a,
  'draft'::public.story_status
from test_ctx;

-- User B creates family_b
set local request.jwt.claim.sub = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

update test_ctx
set family_b = (public.create_family('Family B')).id;

-- Test harness only: postgres inserts B as member of family_a (Edge-equivalent)
reset role;

insert into public.memberships (family_id, user_id, role)
select family_a, user_b, 'member' from test_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
set local request.jwt.claim.role = 'authenticated';

select is(
  (select count(*)::int from public.stories s
   join test_ctx c on s.id = c.story_a),
  1,
  'User B can SELECT story_a as family_a member'
);

update public.stories s
set body = 'hijacked'
from test_ctx c
where s.id = c.story_a;

select is(
  (select count(*)::int from public.stories s
   join test_ctx c on s.id = c.story_a
   where s.body = 'hijacked'),
  0,
  'User B cannot UPDATE story_a body (not author)'
);

insert into public.photos (
  id, story_id, family_id, uploader_id, storage_path, sort_order
)
select
  'a4000000-0000-4000-8000-000000000004',
  story_a,
  family_a,
  user_b,
  family_a::text
    || '/' || story_a::text
    || '/a4000000-0000-4000-8000-000000000004.jpg',
  0
from test_ctx;

select is(
  (select count(*)::int from public.photos p
   where p.id = 'a4000000-0000-4000-8000-000000000004'
     and p.uploader_id = (select user_b from test_ctx)),
  1,
  'User B can INSERT photo on story_a as member with uploader_id = self'
);

update public.stories s
set family_id = c.family_b
from test_ctx c
where s.id = c.story_a;

select is(
  (select count(*)::int from public.stories s
   join test_ctx c on s.id = c.story_a
   where s.family_id = c.family_b),
  0,
  'User B cannot UPDATE story_a family_id to family_b (WITH CHECK membership)'
);

select * from finish();
rollback;
