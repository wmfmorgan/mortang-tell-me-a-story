-- M14 people profiles. One transaction, rolled back.

begin;
create extension if not exists pgtap with schema extensions;

select plan(68);

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
  $$update public.profiles
      set birth_precision = 'decade'::public.story_date_precision
      where id = 'a1400000-0000-4000-8000-0000000000a1'$$,
  '23514',
  null,
  'profiles.birth_precision refuses decade'
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

insert into public.people (
  id, family_id, name, created_by, about, passed_away
)
select
  '55555555-14a1-4111-8111-555555555555',
  parent_id,
  'Ada Person',
  user_a,
  'from the row',
  true
from m14_ctx;

select results_eq(
  $$select column_name::text collate "C"
    from information_schema.columns
    where table_schema = 'public' and table_name = 'people_tree_read'
    order by ordinal_position$$,
  $$values ('id'::text collate "C"), ('family_id'::text collate "C"), ('name'::text collate "C")$$,
  'people_tree_read is id, family_id, name'
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'b1400000-0000-4000-8000-0000000000b1';

select is(
  (select about from public.people where id = '55555555-14a1-4111-8111-555555555555'),
  'from the row',
  'a tree member reads the full person row'
);

select lives_ok(
  $$update public.people
      set name = 'Edited'
      where id = '55555555-14a1-4111-8111-555555555555'$$,
  'a tree member edits an unlinked person'
);

reset role;
update public.people
set user_id = 'b1400000-0000-4000-8000-0000000000b1'
where id = '55555555-14a1-4111-8111-555555555555';

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1400000-0000-4000-8000-0000000000a1';
update public.people
set name = 'Hacked'
where id = '55555555-14a1-4111-8111-555555555555';

reset role;
select is(
  (select name from public.people where id = '55555555-14a1-4111-8111-555555555555'),
  'Edited',
  'another tree member cannot edit a linked person'
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'b1400000-0000-4000-8000-0000000000b1';
update public.people
set name = 'Mine'
where id = '55555555-14a1-4111-8111-555555555555';

reset role;
select is(
  (select name from public.people where id = '55555555-14a1-4111-8111-555555555555'),
  'Mine',
  'the linked user can edit their person row'
);

update public.people
set user_id = null
where id = '55555555-14a1-4111-8111-555555555555';

set local role authenticated;
set local request.jwt.claim.sub = 'b1400000-0000-4000-8000-0000000000b1';
update public.people
set name = 'Open'
where id = '55555555-14a1-4111-8111-555555555555';

reset role;
select is(
  (select name from public.people where id = '55555555-14a1-4111-8111-555555555555'),
  'Open',
  'clearing user_id reopens tree edits'
);

set local role authenticated;
set local request.jwt.claim.sub = 'c1400000-0000-4000-8000-0000000000c1';
select is(
  (select count(*) from public.people where id = '55555555-14a1-4111-8111-555555555555'),
  0::bigint,
  'an outsider cannot read the people row'
);

set local request.jwt.claim.sub = 'a1400000-0000-4000-8000-0000000000a1';
select throws_ok(
  $$update public.people
      set user_id = 'b1400000-0000-4000-8000-0000000000b1'
      where id = '55555555-14a1-4111-8111-555555555555'$$,
  '42501',
  null,
  'a client cannot update people.user_id'
);

reset role;
select is(
  has_function_privilege('anon', 'public.person_profile(uuid)', 'execute'),
  false,
  'anon cannot execute person_profile'
);
select is(
  has_function_privilege('public', 'public.person_profile(uuid)', 'execute'),
  false,
  'public cannot execute person_profile'
);
select is(
  has_function_privilege('authenticated', 'public.person_profile(uuid)', 'execute'),
  true,
  'authenticated can execute person_profile'
);
select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'person_profile'
      and 'search_path=""' = any (p.proconfig)
  ),
  'person_profile has search_path=""'
);
select ok(
  position('user_id' in pg_get_function_result('public.person_profile(uuid)'::regprocedure)) = 0
    and position('email' in pg_get_function_result('public.person_profile(uuid)'::regprocedure)) = 0,
  'person_profile returns no user_id or email'
);
select ok(
  (select qual from pg_policies where policyname = 'profiles_select_own_or_comember')
    not like '%is_tree_member%',
  'profiles select is not widened'
);

select throws_ok(
  $$select * from public.person_profile('99999999-14a1-4111-8111-999999999999')$$,
  'P0001',
  'NOT_FOUND:',
  'a missing id raises NOT_FOUND:'
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'c1400000-0000-4000-8000-0000000000c1';
select throws_ok(
  $$select * from public.person_profile('55555555-14a1-4111-8111-555555555555')$$,
  'P0001',
  'NOT_FOUND:',
  'an outsider raises NOT_FOUND:'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$select * from public.person_profile('55555555-14a1-4111-8111-555555555555')$$,
  'P0001',
  'NOT_FOUND:',
  'a null uid raises NOT_FOUND:'
);

update public.people
set user_id = 'b1400000-0000-4000-8000-0000000000b1',
    name = 'Open'
where id = '55555555-14a1-4111-8111-555555555555';
update public.profiles
set birth_date = '1984-01-01',
    birth_precision = 'year',
    about = null,
    avatar_path = 'b1400000-0000-4000-8000-0000000000b1/avatar.jpg'
where id = 'b1400000-0000-4000-8000-0000000000b1';

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'b1400000-0000-4000-8000-0000000000b1';

select is(
  (select birth_date from public.person_profile('55555555-14a1-4111-8111-555555555555')),
  '1984-01-01'::date,
  'a set account birth date wins'
);
select is(
  (select about from public.person_profile('55555555-14a1-4111-8111-555555555555')),
  'from the row',
  'an unset account about falls back to the person'
);
select is(
  (select passed_away from public.person_profile('55555555-14a1-4111-8111-555555555555')),
  true,
  'passed_away comes from the person row'
);
select is(
  (select is_linked from public.person_profile('55555555-14a1-4111-8111-555555555555')),
  true,
  'is_linked is true when user_id is set'
);
select is(
  (select is_linked from public.person_profile('44444444-14a1-4111-8111-444444444444')),
  false,
  'is_linked is false when user_id is null'
);

reset role;
select is(
  (select count(*)::int from pg_policies),
  47,
  'policy count is 47'
);
select ok(
  exists (
    select 1 from pg_policies
    where policyname = 'person_avatars_select_tree'
      and qual like '%is_tree_member%'
  ),
  'person avatar select is tree members'
);
select ok(
  exists (
    select 1 from pg_policies
    where policyname = 'person_avatars_insert_editor'
      and with_check like '%user_id%'
  )
  and exists (
    select 1 from pg_policies
    where policyname = 'person_avatars_update_editor'
      and qual like '%user_id%'
      and with_check like '%user_id%'
  ),
  'person avatar writes follow the edit rule'
);

update public.people
set user_id = null
where id = '55555555-14a1-4111-8111-555555555555';

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'c1400000-0000-4000-8000-0000000000c1';
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    values (
      'person-avatars',
      '55555555-14a1-4111-8111-555555555555/avatar.jpg',
      'c1400000-0000-4000-8000-0000000000c1'
    )$$,
  '42501',
  null,
  'an outsider cannot upload a person avatar'
);

set local request.jwt.claim.sub = 'a1400000-0000-4000-8000-0000000000a1';
select throws_ok(
  $$insert into public.people (family_id, name, created_by, user_id)
    select parent_id, 'Linked insert', user_a, user_a from m14_ctx$$,
  '42501',
  null,
  'a member insert with a non-null user_id is refused'
);
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    values (
      'person-avatars',
      '55555555-14a1-4111-8111-555555555555/avatar.jpg',
      'a1400000-0000-4000-8000-0000000000a1'
    )$$,
  'a tree member uploads an unlinked person avatar'
);
select is(
  (select count(*) from storage.objects
    where bucket_id = 'person-avatars'
      and name = '55555555-14a1-4111-8111-555555555555/avatar.jpg'),
  1::bigint,
  'a tree member can read the person avatar'
);

set local request.jwt.claim.sub = 'c1400000-0000-4000-8000-0000000000c1';
select is(
  (select count(*) from storage.objects
    where bucket_id = 'person-avatars'
      and name = '55555555-14a1-4111-8111-555555555555/avatar.jpg'),
  0::bigint,
  'an outsider cannot read the person avatar'
);

set local request.jwt.claim.sub = 'a1400000-0000-4000-8000-0000000000a1';
with updated as (
  update storage.objects
  set metadata = '{"n":1}'::jsonb
  where bucket_id = 'person-avatars'
    and name = '55555555-14a1-4111-8111-555555555555/avatar.jpg'
  returning 1
)
select is(
  (select count(*) from updated),
  1::bigint,
  'a tree member updates an unlinked person avatar'
);

reset role;
update public.people
set user_id = 'b1400000-0000-4000-8000-0000000000b1'
where id = '55555555-14a1-4111-8111-555555555555';

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1400000-0000-4000-8000-0000000000a1';
with updated as (
  update storage.objects
  set metadata = '{"n":2}'::jsonb
  where bucket_id = 'person-avatars'
    and name = '55555555-14a1-4111-8111-555555555555/avatar.jpg'
  returning 1
)
select is(
  (select count(*) from updated),
  0::bigint,
  'another tree member cannot update a linked person avatar'
);

set local request.jwt.claim.sub = 'b1400000-0000-4000-8000-0000000000b1';
with updated as (
  update storage.objects
  set metadata = '{"n":3}'::jsonb
  where bucket_id = 'person-avatars'
    and name = '55555555-14a1-4111-8111-555555555555/avatar.jpg'
  returning 1
)
select is(
  (select count(*) from updated),
  1::bigint,
  'the linked user updates their person avatar'
);

reset role;
insert into public.people (id, family_id, name, created_by, user_id)
select
  '66666666-14a1-4111-8111-666666666666',
  child_id,
  'Linked Ada',
  user_a,
  user_a
from m14_ctx;

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'b1400000-0000-4000-8000-0000000000b1';
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    values (
      'person-avatars',
      '66666666-14a1-4111-8111-666666666666/avatar.jpg',
      'b1400000-0000-4000-8000-0000000000b1'
    )$$,
  '42501',
  null,
  'another tree member cannot upload a linked person avatar'
);

set local request.jwt.claim.sub = 'a1400000-0000-4000-8000-0000000000a1';
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    values (
      'person-avatars',
      '66666666-14a1-4111-8111-666666666666/avatar.jpg',
      'a1400000-0000-4000-8000-0000000000a1'
    )$$,
  'the linked user uploads their person avatar'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', '', true);

insert into public.people (
  id, family_id, name, created_by, passed_away
)
select
  '88888888-14a1-4111-8111-888888888888',
  parent_id,
  'Passed Pat',
  user_a,
  true
from m14_ctx;

insert into public.people (id, family_id, name, created_by, email)
select
  '12121212-14a1-4111-8111-121212121212',
  parent_id,
  'Open Olive',
  user_a,
  'olive@test.local'
from m14_ctx;

insert into public.invites (
  id, family_id, invited_by, email, token, status, expires_at, person_id
)
select
  '13131313-14a1-4111-8111-131313131313',
  parent_id,
  user_a,
  'olive@test.local',
  'tok_open_olive_m14',
  'pending'::public.invite_status,
  now() + interval '7 days',
  '12121212-14a1-4111-8111-121212121212'
from m14_ctx;

insert into public.people (id, family_id, name, created_by)
select
  '10101010-14a1-4111-8111-101010101010',
  parent_id,
  'Done Dee',
  user_a
from m14_ctx;

insert into public.invites (
  id, family_id, invited_by, email, token, status, expires_at, person_id
)
select
  '14141414-14a1-4111-8111-141414141414',
  parent_id,
  user_a,
  null,
  'tok_done_dee_m14',
  'accepted'::public.invite_status,
  now() + interval '7 days',
  '10101010-14a1-4111-8111-101010101010'
from m14_ctx;

insert into public.people (id, family_id, name, created_by)
select
  '77777777-14a1-4111-8111-777777777777',
  child_id,
  'Child Kin',
  user_a
from m14_ctx;

insert into public.people (id, family_id, name, created_by)
select
  '99999999-14a1-4111-8111-999999999999',
  dead_id,
  'Other Tree',
  user_d
from m14_ctx;

select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'invites'
      and column_name = 'person_id'
      and is_nullable = 'YES'
  ),
  'invites.person_id is nullable'
);

select is(
  has_function_privilege('anon', 'public.list_unlinked_people(uuid)', 'execute'),
  false,
  'anon cannot execute list_unlinked_people'
);
select is(
  has_function_privilege('authenticated', 'public.link_accepted_person(uuid)', 'execute'),
  true,
  'authenticated can execute link_accepted_person'
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1400000-0000-4000-8000-0000000000a1';

select results_eq(
  $$select id, family_id, name
    from public.list_unlinked_people((select parent_id from m14_ctx))
    order by name, id$$,
  $$values
      (
        '77777777-14a1-4111-8111-777777777777'::uuid,
        '11111111-14a1-4111-8111-111111111111'::uuid,
        'Child Kin'::text
      ),
      (
        '10101010-14a1-4111-8111-101010101010'::uuid,
        (select parent_id from m14_ctx),
        'Done Dee'::text
      ),
      (
        '44444444-14a1-4111-8111-444444444444'::uuid,
        (select parent_id from m14_ctx),
        'No kin'::text
      )$$,
  'list_unlinked_people covers the tree and omits linked and passed people'
);

select ok(
  not exists (
    select 1
    from public.list_unlinked_people((select parent_id from m14_ctx))
    where name in ('Passed Pat', 'Open Olive')
  ),
  'list_unlinked_people excludes anyone with an open invite or a date of passing'
);

set local request.jwt.claim.sub = 'c1400000-0000-4000-8000-0000000000c1';
select throws_ok(
  $$select public.list_unlinked_people((select parent_id from m14_ctx))$$,
  'P0001',
  'NOT_FOUND:',
  'an outsider cannot list unlinked people'
);

set local request.jwt.claim.sub = 'a1400000-0000-4000-8000-0000000000a1';
select throws_ok(
  $$select public.list_unlinked_people('00000000-0000-4000-8000-00000000ffff')$$,
  'P0001',
  'NOT_FOUND:',
  'a missing family is not found'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$select public.list_unlinked_people((select parent_id from m14_ctx))$$,
  'P0001',
  'NOT_FOUND:',
  'a null uid cannot list unlinked people'
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1400000-0000-4000-8000-0000000000a1';

select throws_ok(
  $$select public.assert_invite_person(
      (select parent_id from m14_ctx),
      '00000000-0000-4000-8000-00000000eeee'
    )$$,
  'P0001',
  'NOT_FOUND:',
  'a missing person is not found'
);
select throws_ok(
  $$select public.assert_invite_person(
      (select parent_id from m14_ctx),
      '99999999-14a1-4111-8111-999999999999'
    )$$,
  'P0001',
  'NOT_FOUND:',
  'a person outside the tree is not found'
);
select throws_ok(
  $$select public.assert_invite_person(
      (select parent_id from m14_ctx),
      '66666666-14a1-4111-8111-666666666666'
    )$$,
  'P0001',
  'VALIDATION: person is already linked',
  'a linked person cannot be invited'
);
select throws_ok(
  $$select public.assert_invite_person(
      (select parent_id from m14_ctx),
      '88888888-14a1-4111-8111-888888888888'
    )$$,
  'P0001',
  'VALIDATION: person has passed',
  'a person who has passed cannot be invited'
);
select lives_ok(
  $$select public.assert_invite_person(
      (select parent_id from m14_ctx),
      '77777777-14a1-4111-8111-777777777777'
    )$$,
  'an unlinked living tree person can be invited'
);

set local request.jwt.claim.sub = 'c1400000-0000-4000-8000-0000000000c1';
select lives_ok(
  $$select public.link_accepted_person('77777777-14a1-4111-8111-777777777777')$$,
  'link_accepted_person sets user_id when it was null'
);
reset role;
select is(
  (select user_id from public.people where id = '77777777-14a1-4111-8111-777777777777'),
  'c1400000-0000-4000-8000-0000000000c1'::uuid,
  'the caller is linked'
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'c1400000-0000-4000-8000-0000000000c1';
select lives_ok(
  $$select public.link_accepted_person('55555555-14a1-4111-8111-555555555555')$$,
  'a person already linked to someone else does not raise'
);
reset role;
select is(
  (select user_id from public.people where id = '55555555-14a1-4111-8111-555555555555'),
  'b1400000-0000-4000-8000-0000000000b1'::uuid,
  'an already linked person stays linked'
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1400000-0000-4000-8000-0000000000a1';
select lives_ok(
  $$select public.link_accepted_person('44444444-14a1-4111-8111-444444444444')$$,
  'a caller already linked in the tree does not raise'
);
reset role;
select is(
  (select user_id from public.people where id = '44444444-14a1-4111-8111-444444444444'),
  null,
  'a caller already linked in the tree does not get a second row'
);

select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$select public.link_accepted_person('44444444-14a1-4111-8111-444444444444')$$,
  'P0001',
  'NOT_FOUND:',
  'a null uid cannot link a person'
);

select * from finish();
rollback;
