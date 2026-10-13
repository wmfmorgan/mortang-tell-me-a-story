-- M14 people profiles. One transaction, rolled back.

begin;
create extension if not exists pgtap with schema extensions;

select plan(16);

create temporary table m14_ctx (
  user_a uuid primary key,
  user_b uuid not null,
  user_c uuid not null,
  user_d uuid not null,
  parent_id uuid,
  child_id uuid,
  dead_id uuid,
  person_id uuid
);

grant all on table m14_ctx to authenticated, anon, service_role;

insert into m14_ctx (user_a, user_b, user_c, user_d)
values (
  'a1400000-0000-4000-8000-0000000000a1',
  'b1400000-0000-4000-8000-0000000000b1',
  'c1400000-0000-4000-8000-0000000000c1',
  'd1400000-0000-4000-8000-0000000000d1'
);

insert into auth.users (id, email, raw_user_meta_data)
select user_a, 'm14-a@test.local', '{"display_name":"Ada"}'::jsonb from m14_ctx
union all
select user_b, 'm14-b@test.local', '{"display_name":"Bea"}'::jsonb from m14_ctx
union all
select user_c, 'm14-c@test.local', '{"display_name":"Cam"}'::jsonb from m14_ctx
union all
select user_d, 'm14-d@test.local', '{"display_name":"Dee"}'::jsonb from m14_ctx;

select is(
  has_function_privilege('anon', 'public.is_tree_member(uuid)', 'execute'),
  false,
  'anon cannot execute is_tree_member'
);
select is(
  has_function_privilege('authenticated', 'public.is_tree_member(uuid)', 'execute'),
  true,
  'authenticated can execute is_tree_member'
);
select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'is_tree_member'
      and 'search_path=""' = any (p.proconfig)
  ),
  'is_tree_member has search_path=""'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a1400000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';
update m14_ctx set parent_id = (public.create_family('Parent')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.families (id, name, created_by, parent_family_id)
select '11111111-14a1-4111-8111-111111111111', 'Child', user_b, parent_id
from m14_ctx;
update m14_ctx set child_id = '11111111-14a1-4111-8111-111111111111';

insert into public.memberships (family_id, user_id, role)
select child_id, user_b, 'member'::public.membership_role from m14_ctx;

insert into public.families (id, name, created_by, deleted_at)
select '22222222-14a1-4111-8111-222222222222', 'Dead', user_d, now()
from m14_ctx;
update m14_ctx set dead_id = '22222222-14a1-4111-8111-222222222222';

insert into public.memberships (family_id, user_id, role)
select dead_id, user_d, 'owner'::public.membership_role from m14_ctx;

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'b1400000-0000-4000-8000-0000000000b1';

select is(
  public.is_tree_member((select parent_id from m14_ctx)),
  true,
  'a child member is a tree member of the parent'
);

set local request.jwt.claim.sub = 'a1400000-0000-4000-8000-0000000000a1';

select is(
  public.is_tree_member((select child_id from m14_ctx)),
  true,
  'a parent member is a tree member of the child'
);

set local request.jwt.claim.sub = 'c1400000-0000-4000-8000-0000000000c1';

select is(
  public.is_tree_member((select parent_id from m14_ctx)),
  false,
  'an outsider is not a tree member'
);

set local request.jwt.claim.sub = 'd1400000-0000-4000-8000-0000000000d1';

select is(
  public.is_tree_member((select dead_id from m14_ctx)),
  false,
  'a soft-deleted family is not a tree'
);

set local request.jwt.claim.sub = 'a1400000-0000-4000-8000-0000000000a1';

select is(
  public.is_tree_member((select dead_id from m14_ctx)),
  false,
  'a live member is not a tree member of a soft-deleted family'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', '', true);

select is(
  public.is_tree_member((select parent_id from m14_ctx)),
  false,
  'a null uid is not a tree member'
);

select throws_ok(
  $$insert into public.people (family_id, name, relationship, created_by, birth_precision)
    select parent_id, 'Decade', 'kin', user_a, 'decade'::public.story_date_precision
    from m14_ctx$$,
  '23514',
  null,
  'people.birth_precision refuses decade'
);

select throws_ok(
  $$update public.profiles
      set birth_precision = 'decade'::public.story_date_precision
      where id = 'a1400000-0000-4000-8000-0000000000a1'$$,
  '23514',
  null,
  'profiles.birth_precision refuses decade'
);

select throws_ok(
  $$insert into public.people (
      family_id, name, relationship, created_by, birth_date
    )
    select parent_id, 'Half', 'kin', user_a, '1980-01-01'::date
    from m14_ctx$$,
  '23514',
  null,
  'a birth date without precision fails'
);

select throws_ok(
  $$insert into public.people (
      family_id, name, relationship, created_by, passing_precision
    )
    select parent_id, 'Half pass', 'kin', user_a, 'year'::public.story_date_precision
    from m14_ctx$$,
  '23514',
  null,
  'a passing precision without a date fails'
);

select throws_ok(
  $$insert into public.people (family_id, name, relationship, created_by, about)
    select parent_id, 'Long', 'kin', user_a, repeat('a', 501)
    from m14_ctx$$,
  '23514',
  null,
  'about over 500 characters fails'
);

select throws_ok(
  $$insert into public.people (id, family_id, name, relationship, created_by, avatar_path)
    select '33333333-14a1-4111-8111-333333333333', parent_id, 'Pic', 'kin', user_a,
           'nope.jpg'
    from m14_ctx$$,
  '23514',
  null,
  'avatar_path must be {id}/avatar.jpg'
);

select lives_ok(
  $$insert into public.people (id, family_id, name, relationship, created_by)
    select '44444444-14a1-4111-8111-444444444444', parent_id, 'No kin', null, user_a
    from m14_ctx$$,
  'relationship may be null'
);

select * from finish();
rollback;
