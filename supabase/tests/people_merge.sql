-- M14 merge of people copied onto branch families. Rolls back.

begin;
create extension if not exists pgtap with schema extensions;

select plan(20);

create temporary table m14m_ctx (
  user_a uuid primary key,
  user_b uuid not null,
  user_c uuid not null,
  user_d uuid not null
);

grant all on table m14m_ctx to authenticated, anon, service_role;

insert into m14m_ctx (user_a, user_b, user_c, user_d)
values (
  'a14e0000-0000-4000-8000-0000000000a1',
  'b14e0000-0000-4000-8000-0000000000b1',
  'c14e0000-0000-4000-8000-0000000000c1',
  'd14e0000-0000-4000-8000-0000000000d1'
);

insert into auth.users (id, email, raw_user_meta_data)
select user_a, 'merge-a@test.local', '{"display_name":"Ada"}'::jsonb from m14m_ctx
union all
select user_b, 'merge-b@test.local', '{"display_name":"Bea"}'::jsonb from m14m_ctx
union all
select user_c, 'merge-c@test.local', '{"display_name":"Cam"}'::jsonb from m14m_ctx
union all
select user_d, 'merge-d@test.local', '{"display_name":"Dee"}'::jsonb from m14m_ctx;

insert into public.families (id, name, created_by, parent_family_id)
select '11111111-14e1-4111-8111-111111111111'::uuid, 'Uid root', user_a, null::uuid from m14m_ctx
union all
select '11111111-14e1-4111-8111-111111111112', 'Uid child', user_a, '11111111-14e1-4111-8111-111111111111' from m14m_ctx
union all
select '22222222-14e1-4111-8111-222222222221', 'Mail root', user_a, null from m14m_ctx
union all
select '22222222-14e1-4111-8111-222222222222', 'Mail child', user_a, '22222222-14e1-4111-8111-222222222221' from m14m_ctx
union all
select '33333333-14e1-4111-8111-333333333331', 'Null root', user_a, null from m14m_ctx
union all
select '33333333-14e1-4111-8111-333333333332', 'Null child', user_a, '33333333-14e1-4111-8111-333333333331' from m14m_ctx
union all
select '44444444-14e1-4111-8111-444444444441', 'Blank root', user_a, null from m14m_ctx
union all
select '44444444-14e1-4111-8111-444444444442', 'Blank child', user_a, '44444444-14e1-4111-8111-444444444441' from m14m_ctx
union all
select '55555555-14e1-4111-8111-555555555551', 'Name root', user_a, null from m14m_ctx
union all
select '55555555-14e1-4111-8111-555555555552', 'Name child', user_a, '55555555-14e1-4111-8111-555555555551' from m14m_ctx
union all
select '66666666-14e1-4111-8111-666666666661', 'Mail clash root', user_a, null from m14m_ctx
union all
select '66666666-14e1-4111-8111-666666666662', 'Mail clash child', user_a, '66666666-14e1-4111-8111-666666666661' from m14m_ctx
union all
select '77777777-14e1-4111-8111-777777777771', 'Uid clash root', user_a, null from m14m_ctx
union all
select '77777777-14e1-4111-8111-777777777772', 'Uid clash child', user_a, '77777777-14e1-4111-8111-777777777771' from m14m_ctx
union all
select '88888888-14e1-4111-8111-888888888881', 'Two root', user_a, null from m14m_ctx
union all
select '88888888-14e1-4111-8111-888888888882', 'Two child', user_a, '88888888-14e1-4111-8111-888888888881' from m14m_ctx
union all
select '99999999-14e1-4111-8111-999999999991', 'Sam root', user_a, null from m14m_ctx
union all
select '99999999-14e1-4111-8111-999999999992', 'Sam child', user_a, '99999999-14e1-4111-8111-999999999991' from m14m_ctx
union all
select '99999999-14e1-4111-8111-999999999993', 'Sam grand', user_a, '99999999-14e1-4111-8111-999999999992' from m14m_ctx;

insert into public.people (id, family_id, name, email, user_id, created_by)
select 'a1111111-14e1-4111-8111-a11111111111'::uuid, '11111111-14e1-4111-8111-111111111111'::uuid, 'Root Bee', null::text, user_b, user_a from m14m_ctx
union all
select 'a1111111-14e1-4111-8111-a11111111112', '11111111-14e1-4111-8111-111111111112', 'Copy Bee', null, user_b, user_a from m14m_ctx
union all
select 'a2222222-14e1-4111-8111-a22222222221', '22222222-14e1-4111-8111-222222222221', 'Mail Root', 'Ada@test.local', null, user_a from m14m_ctx
union all
select 'a2222222-14e1-4111-8111-a22222222222', '22222222-14e1-4111-8111-222222222222', 'Mail Copy', '  ada@test.local ', null, user_a from m14m_ctx
union all
select 'a3333333-14e1-4111-8111-a33333333331', '33333333-14e1-4111-8111-333333333331', 'Ann', null, null, user_a from m14m_ctx
union all
select 'a3333333-14e1-4111-8111-a33333333332', '33333333-14e1-4111-8111-333333333332', 'Bob', null, null, user_a from m14m_ctx
union all
select 'a4444444-14e1-4111-8111-a44444444441', '44444444-14e1-4111-8111-444444444441', 'Cath', '', null, user_a from m14m_ctx
union all
select 'a4444444-14e1-4111-8111-a44444444442', '44444444-14e1-4111-8111-444444444442', 'Dan', '   ', null, user_a from m14m_ctx
union all
select 'a5555555-14e1-4111-8111-a55555555551', '55555555-14e1-4111-8111-555555555551', 'Ada  Lovelace', null, null, user_a from m14m_ctx
union all
select 'a5555555-14e1-4111-8111-a55555555552', '55555555-14e1-4111-8111-555555555552', 'ada lovelace', 'Ada@Example.com', user_b, user_a from m14m_ctx
union all
select 'a6666666-14e1-4111-8111-a66666666661', '66666666-14e1-4111-8111-666666666661', 'Eve', 'eve@test.local', null, user_a from m14m_ctx
union all
select 'a6666666-14e1-4111-8111-a66666666662', '66666666-14e1-4111-8111-666666666662', 'Eve', 'other@test.local', null, user_a from m14m_ctx
union all
select 'a7777777-14e1-4111-8111-a77777777771', '77777777-14e1-4111-8111-777777777771', 'Finn', null, user_c, user_a from m14m_ctx
union all
select 'a7777777-14e1-4111-8111-a77777777772', '77777777-14e1-4111-8111-777777777772', 'Finn', null, user_d, user_a from m14m_ctx
union all
select 'a8888888-14e1-4111-8111-a88888888881', '88888888-14e1-4111-8111-888888888881', 'Glen', null, null, user_a from m14m_ctx
union all
select 'a8888888-14e1-4111-8111-a88888888882', '88888888-14e1-4111-8111-888888888881', 'Glen', null, null, user_a from m14m_ctx
union all
select 'a8888888-14e1-4111-8111-a88888888883', '88888888-14e1-4111-8111-888888888882', 'Glen', null, null, user_a from m14m_ctx
union all
select 'a9999999-14e1-4111-8111-a99999999991', '99999999-14e1-4111-8111-999999999991', 'Sam', null, null, user_a from m14m_ctx
union all
select 'a9999999-14e1-4111-8111-a99999999992', '99999999-14e1-4111-8111-999999999992', 'Sam', null, null, user_a from m14m_ctx
union all
select 'a9999999-14e1-4111-8111-a99999999993', '99999999-14e1-4111-8111-999999999993', 'Sam', null, null, user_a from m14m_ctx;

insert into public.stories (id, family_id, author_id, title, timeframe_start, status)
values
  (
    'b1111111-14e1-4111-8111-b11111111111',
    '11111111-14e1-4111-8111-111111111112',
    'a14e0000-0000-4000-8000-0000000000a1',
    'Bee tale',
    '1990-01-01',
    'published'
  ),
  (
    'b9999999-14e1-4111-8111-b99999999999',
    '99999999-14e1-4111-8111-999999999993',
    'a14e0000-0000-4000-8000-0000000000a1',
    'Sam tale',
    '1991-01-01',
    'published'
  );

insert into public.story_people (story_id, person_id)
values
  ('b1111111-14e1-4111-8111-b11111111111', 'a1111111-14e1-4111-8111-a11111111112'),
  ('b9999999-14e1-4111-8111-b99999999999', 'a9999999-14e1-4111-8111-a99999999993');

select is(
  has_function_privilege('anon', 'public.merge_copied_people()', 'execute'),
  false,
  'anon cannot execute merge_copied_people'
);
select is(
  has_function_privilege('authenticated', 'public.merge_copied_people()', 'execute'),
  false,
  'authenticated cannot execute merge_copied_people'
);
select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'merge_copied_people'
      and 'search_path=""' = any (p.proconfig)
  ),
  'merge_copied_people has search_path=""'
);

select public.merge_copied_people();

select is(
  (select count(*) from public.people where id = 'a1111111-14e1-4111-8111-a11111111112'),
  0::bigint,
  'an equal user_id merges the copy away'
);
select is(
  (
    select person_id
    from public.story_people
    where story_id = 'b1111111-14e1-4111-8111-b11111111111'
  ),
  'a1111111-14e1-4111-8111-a11111111111'::uuid,
  'story tags point at the parent row'
);
select is(
  (select count(*) from public.people where id = 'a2222222-14e1-4111-8111-a22222222222'),
  0::bigint,
  'email matches under lower trim'
);
select is(
  (
    select count(*)
    from public.people
    where id in (
      'a3333333-14e1-4111-8111-a33333333331',
      'a3333333-14e1-4111-8111-a33333333332'
    )
  ),
  2::bigint,
  'null email and null user_id do not match'
);
select is(
  (
    select count(*)
    from public.people
    where id in (
      'a4444444-14e1-4111-8111-a44444444441',
      'a4444444-14e1-4111-8111-a44444444442'
    )
  ),
  2::bigint,
  'blank email does not match'
);
select is(
  (
    select count(*)
    from public.people
    where family_id in (
      '55555555-14e1-4111-8111-555555555551',
      '55555555-14e1-4111-8111-555555555552'
    )
  ),
  1::bigint,
  'a normalized name merges'
);
select is(
  (select count(*) from public.people where id = 'a5555555-14e1-4111-8111-a55555555551'),
  1::bigint,
  'the name match keeps the parent row'
);
select is(
  (select email from public.people where id = 'a5555555-14e1-4111-8111-a55555555551'),
  'Ada@Example.com',
  'a null survivor email is filled from the copy'
);
select is(
  (select user_id from public.people where id = 'a5555555-14e1-4111-8111-a55555555551'),
  'b14e0000-0000-4000-8000-0000000000b1'::uuid,
  'a null survivor user_id is filled from the copy'
);
select is(
  (select email from public.people where id = 'a2222222-14e1-4111-8111-a22222222221'),
  'Ada@test.local',
  'a set survivor email is kept'
);
select is(
  (
    select count(*)
    from public.people
    where id in (
      'a6666666-14e1-4111-8111-a66666666661',
      'a6666666-14e1-4111-8111-a66666666662'
    )
  ),
  2::bigint,
  'different emails block a name match'
);
select is(
  (
    select count(*)
    from public.people
    where id in (
      'a7777777-14e1-4111-8111-a77777777771',
      'a7777777-14e1-4111-8111-a77777777772'
    )
  ),
  2::bigint,
  'different user ids block a name match'
);
select is(
  (select count(*) from public.people where id = 'a8888888-14e1-4111-8111-a88888888883'),
  1::bigint,
  'two parent candidates leave the copy in place'
);
select is(
  (select count(*) from public.people where id = 'a9999999-14e1-4111-8111-a99999999993'),
  0::bigint,
  'a grandchild copy is merged away'
);
select is(
  (select count(*) from public.people where id = 'a9999999-14e1-4111-8111-a99999999992'),
  0::bigint,
  'the child copy merges to the root in the same call'
);
select is(
  (
    select person_id
    from public.story_people
    where story_id = 'b9999999-14e1-4111-8111-b99999999999'
  ),
  'a9999999-14e1-4111-8111-a99999999991'::uuid,
  'the grandchild tag points at the root person'
);

select public.merge_copied_people();

select is(
  (select count(*) from public.people where id = 'a9999999-14e1-4111-8111-a99999999991'),
  1::bigint,
  'a second call is idempotent'
);

select * from finish();
rollback;
