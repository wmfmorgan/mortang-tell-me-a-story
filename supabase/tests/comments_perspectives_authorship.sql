-- §14.3 comments/perspectives: member INSERT own row; author-only UPDATE/DELETE.
-- Harness: insert auth.users (trigger → profiles); SET LOCAL ROLE authenticated
-- + request.jwt.claim.sub/role; create_family as A; seed story as A;
-- postgres-only membership insert for B into family_a; C has family_c only.
-- Entire script runs in a transaction + ROLLBACK.

begin;
create extension if not exists pgtap with schema extensions;

select plan(12);

create temporary table test_ctx (
  user_a uuid primary key,
  user_b uuid not null,
  user_c uuid not null,
  family_a uuid,
  family_c uuid,
  story_a uuid,
  place_a uuid
);

grant all on table test_ctx to authenticated, anon, service_role;

insert into test_ctx (user_a, user_b, user_c, story_a, place_a)
values (
  'f1111111-1111-4111-8111-111111111111',
  'f2222222-2222-4222-8222-222222222222',
  'f3333333-3333-4333-8333-333333333333',
  'f3000000-0000-4000-8000-000000000003',
  'f2000000-0000-4000-8000-000000000002'
);

insert into auth.users (id, email, raw_user_meta_data)
select user_a, 'comment-a@test.local', '{"display_name":"User A"}'::jsonb from test_ctx
union all
select user_b, 'comment-b@test.local', '{"display_name":"User B"}'::jsonb from test_ctx
union all
select user_c, 'comment-c@test.local', '{"display_name":"User C"}'::jsonb from test_ctx;

-- User A creates family_a and seeds place + story
set local role authenticated;
set local request.jwt.claim.sub = 'f1111111-1111-4111-8111-111111111111';
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
  'published'::public.story_status
from test_ctx;

-- User C creates family_c (no membership in family_a)
set local request.jwt.claim.sub = 'f3333333-3333-4333-8333-333333333333';

update test_ctx
set family_c = (public.create_family('Family C')).id;

-- Test harness only: postgres inserts B as member of family_a (Edge-equivalent)
reset role;

insert into public.memberships (family_id, user_id, role)
select family_a, user_b, 'member' from test_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'f2222222-2222-4222-8222-222222222222';
set local request.jwt.claim.role = 'authenticated';

insert into public.comments (
  id, story_id, family_id, author_id, body
)
select
  'f6000000-0000-4000-8000-000000000006',
  story_a,
  family_a,
  user_b,
  'member B comment'
from test_ctx;

select is(
  (select count(*)::int from public.comments cm
   where cm.id = 'f6000000-0000-4000-8000-000000000006'
     and cm.author_id = (select user_b from test_ctx)),
  1,
  'User B can INSERT own comment as family_a member with author_id = uid'
);

insert into public.perspectives (
  id, story_id, family_id, author_id, body
)
select
  'f7000000-0000-4000-8000-000000000007',
  story_a,
  family_a,
  user_b,
  'member B perspective'
from test_ctx;

select is(
  (select count(*)::int from public.perspectives pv
   where pv.id = 'f7000000-0000-4000-8000-000000000007'
     and pv.author_id = (select user_b from test_ctx)),
  1,
  'User B can INSERT own perspective as family_a member with author_id = uid'
);

-- Other member (A) cannot UPDATE/DELETE B's rows
set local request.jwt.claim.sub = 'f1111111-1111-4111-8111-111111111111';

update public.comments cm
set body = 'hijacked comment'
where cm.id = 'f6000000-0000-4000-8000-000000000006';

select is(
  (select count(*)::int from public.comments cm
   where cm.id = 'f6000000-0000-4000-8000-000000000006'
     and cm.body = 'hijacked comment'),
  0,
  'User A cannot UPDATE User B comment'
);

delete from public.comments cm
where cm.id = 'f6000000-0000-4000-8000-000000000006';

select is(
  (select count(*)::int from public.comments cm
   where cm.id = 'f6000000-0000-4000-8000-000000000006'),
  1,
  'User A cannot DELETE User B comment'
);

update public.perspectives pv
set body = 'hijacked perspective'
where pv.id = 'f7000000-0000-4000-8000-000000000007';

select is(
  (select count(*)::int from public.perspectives pv
   where pv.id = 'f7000000-0000-4000-8000-000000000007'
     and pv.body = 'hijacked perspective'),
  0,
  'User A cannot UPDATE User B perspective'
);

delete from public.perspectives pv
where pv.id = 'f7000000-0000-4000-8000-000000000007';

select is(
  (select count(*)::int from public.perspectives pv
   where pv.id = 'f7000000-0000-4000-8000-000000000007'),
  1,
  'User A cannot DELETE User B perspective'
);

-- Author (B) can UPDATE/DELETE own rows
set local request.jwt.claim.sub = 'f2222222-2222-4222-8222-222222222222';

update public.comments cm
set body = 'edited comment'
where cm.id = 'f6000000-0000-4000-8000-000000000006';

select is(
  (select body from public.comments
   where id = 'f6000000-0000-4000-8000-000000000006'),
  'edited comment',
  'User B can UPDATE own comment'
);

delete from public.comments cm
where cm.id = 'f6000000-0000-4000-8000-000000000006';

select is(
  (select count(*)::int from public.comments cm
   where cm.id = 'f6000000-0000-4000-8000-000000000006'),
  0,
  'User B can DELETE own comment'
);

update public.perspectives pv
set body = 'edited perspective'
where pv.id = 'f7000000-0000-4000-8000-000000000007';

select is(
  (select body from public.perspectives
   where id = 'f7000000-0000-4000-8000-000000000007'),
  'edited perspective',
  'User B can UPDATE own perspective'
);

delete from public.perspectives pv
where pv.id = 'f7000000-0000-4000-8000-000000000007';

select is(
  (select count(*)::int from public.perspectives pv
   where pv.id = 'f7000000-0000-4000-8000-000000000007'),
  0,
  'User B can DELETE own perspective'
);

-- Non-member (C) INSERT on family_a fails
set local request.jwt.claim.sub = 'f3333333-3333-4333-8333-333333333333';

select throws_ok(
  $$insert into public.comments (id, story_id, family_id, author_id, body)
    select
      'f8000000-0000-4000-8000-000000000008',
      story_a,
      family_a,
      user_c,
      'stranger comment'
    from test_ctx$$,
  '42501',
  null,
  'User C cannot INSERT comment on family_a (not a member)'
);

select throws_ok(
  $$insert into public.perspectives (id, story_id, family_id, author_id, body)
    select
      'f9000000-0000-4000-8000-000000000009',
      story_a,
      family_a,
      user_c,
      'stranger perspective'
    from test_ctx$$,
  '42501',
  null,
  'User C cannot INSERT perspective on family_a (not a member)'
);

select * from finish();
rollback;
