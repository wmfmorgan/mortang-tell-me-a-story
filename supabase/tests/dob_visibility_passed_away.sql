-- M14.3 DOB visibility and passed away. One transaction, rolled back.

begin;
create extension if not exists pgtap with schema extensions;

select plan(57);

create temporary table m143_ctx (
  owner_id uuid primary key,
  co_id uuid not null,
  member_id uuid not null,
  branch_id uuid not null,
  outsider_id uuid not null,
  plain_id uuid not null,
  home_id uuid,
  owner_person uuid,
  member_person uuid
);

grant all on table m143_ctx to authenticated, anon, service_role;

insert into m143_ctx (owner_id, co_id, member_id, branch_id, outsider_id, plain_id)
values (
  'a1430000-0000-4000-8000-0000000000a1',
  'b1430000-0000-4000-8000-0000000000b1',
  'c1430000-0000-4000-8000-0000000000c1',
  'd1430000-0000-4000-8000-0000000000d1',
  'e1430000-0000-4000-8000-0000000000e1',
  'f1430000-0000-4000-8000-0000000000f1'
);

insert into auth.users (id, email, raw_user_meta_data)
select owner_id, 'm143-owner@test.local', '{"display_name":"Owner"}'::jsonb from m143_ctx
union all
select co_id, 'm143-co@test.local', '{"display_name":"Co"}'::jsonb from m143_ctx
union all
select member_id, 'm143-member@test.local', '{"display_name":"Member"}'::jsonb from m143_ctx
union all
select branch_id, 'm143-branch@test.local', '{"display_name":"Branch"}'::jsonb from m143_ctx
union all
select outsider_id, 'm143-out@test.local', '{"display_name":"Out"}'::jsonb from m143_ctx
union all
select plain_id, 'm143-plain@test.local', '{"display_name":"Plain"}'::jsonb from m143_ctx;

select results_eq(
  $$select e.enumlabel::text collate "C"
      from pg_enum e
      join pg_type t on t.oid = e.enumtypid
      join pg_namespace n on n.oid = t.typnamespace
      where n.nspname = 'public' and t.typname = 'dob_visibility'
      order by e.enumsortorder$$,
  $$values ('hidden'::text collate "C"), ('year'::text collate "C"), ('year_month'::text collate "C"), ('full'::text collate "C")$$,
  'dob_visibility is hidden, year, year_month, full'
);

select col_not_null(
  'public',
  'profiles',
  'birth_visibility',
  'profiles.birth_visibility is not null'
);
select is(
  (
    select birth_visibility::text
    from public.profiles
    where id = 'c1430000-0000-4000-8000-0000000000c1'
  ),
  'hidden',
  'birth_visibility defaults to hidden for an existing profile'
);
select col_not_null(
  'public',
  'people',
  'passed_away',
  'people.passed_away is not null'
);
select col_default_is(
  'public',
  'people',
  'passed_away',
  'false',
  'people.passed_away defaults to false'
);
select hasnt_column(
  'public',
  'people',
  'birth_date',
  'people.birth_date is gone'
);
select hasnt_column(
  'public',
  'people',
  'birth_precision',
  'people.birth_precision is gone'
);
select hasnt_column(
  'public',
  'people',
  'passing_date',
  'people.passing_date is gone after the carry-over'
);
select hasnt_column(
  'public',
  'people',
  'passing_precision',
  'people.passing_precision is gone'
);
select is(
  (select count(*)::int from pg_policies),
  47,
  'policy count is 47'
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
update m143_ctx set home_id = (public.create_family('Home')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.families (id, name, created_by, parent_family_id)
select
  '33333333-1430-4111-8111-333333333333',
  'Branch',
  branch_id,
  home_id
from m143_ctx;

insert into public.memberships (family_id, user_id, role)
select
  '33333333-1430-4111-8111-333333333333',
  branch_id,
  'owner'::public.membership_role
from m143_ctx
union all
select home_id, co_id, 'member'::public.membership_role from m143_ctx
union all
select home_id, member_id, 'member'::public.membership_role from m143_ctx
union all
select home_id, plain_id, 'member'::public.membership_role from m143_ctx;

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
select public.add_co_owner(
  (select home_id from m143_ctx),
  'b1430000-0000-4000-8000-0000000000b1'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

update m143_ctx
set owner_person = (
  select id
  from public.people
  where user_id = 'a1430000-0000-4000-8000-0000000000a1'
    and family_id = (select home_id from m143_ctx)
);

insert into public.people (id, family_id, name, created_by, user_id, about)
select
  '11111111-1430-4111-8111-111111111111',
  home_id,
  'Member Cam',
  owner_id,
  member_id,
  'keep'
from m143_ctx;
update m143_ctx
set member_person = '11111111-1430-4111-8111-111111111111';

insert into public.people (id, family_id, name, created_by)
select
  '22222222-1430-4111-8111-222222222222',
  home_id,
  'Open Una',
  owner_id
from m143_ctx;

update public.profiles
set birth_date = '1984-03-14',
    birth_precision = 'day'
where id = 'c1430000-0000-4000-8000-0000000000c1';

update public.profiles
set birth_date = '1970-01-01',
    birth_precision = 'year'
where id = 'a1430000-0000-4000-8000-0000000000a1';

-- Direct selects of the raw columns are refused for every authenticated role.
set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
select throws_ok(
  $$select birth_date from public.profiles
    where id = 'c1430000-0000-4000-8000-0000000000c1'$$,
  '42501',
  null,
  'an owner cannot select profiles.birth_date'
);
select throws_ok(
  $$select birth_precision from public.profiles
    where id = 'c1430000-0000-4000-8000-0000000000c1'$$,
  '42501',
  null,
  'an owner cannot select profiles.birth_precision'
);
select throws_ok(
  $$select birth_visibility from public.profiles
    where id = 'c1430000-0000-4000-8000-0000000000c1'$$,
  '42501',
  null,
  'an owner cannot select profiles.birth_visibility'
);

set local request.jwt.claim.sub = 'b1430000-0000-4000-8000-0000000000b1';
select throws_ok(
  $$select birth_date from public.profiles
    where id = 'c1430000-0000-4000-8000-0000000000c1'$$,
  '42501',
  null,
  'a co-owner cannot select profiles.birth_date'
);
select throws_ok(
  $$select birth_precision from public.profiles
    where id = 'c1430000-0000-4000-8000-0000000000c1'$$,
  '42501',
  null,
  'a co-owner cannot select profiles.birth_precision'
);
select throws_ok(
  $$select birth_visibility from public.profiles
    where id = 'c1430000-0000-4000-8000-0000000000c1'$$,
  '42501',
  null,
  'a co-owner cannot select profiles.birth_visibility'
);

set local request.jwt.claim.sub = 'f1430000-0000-4000-8000-0000000000f1';
select throws_ok(
  $$select birth_date from public.profiles
    where id = 'c1430000-0000-4000-8000-0000000000c1'$$,
  '42501',
  null,
  'a co-member cannot select profiles.birth_date'
);
select throws_ok(
  $$select birth_precision from public.profiles
    where id = 'c1430000-0000-4000-8000-0000000000c1'$$,
  '42501',
  null,
  'a co-member cannot select profiles.birth_precision'
);
select throws_ok(
  $$select birth_visibility from public.profiles
    where id = 'c1430000-0000-4000-8000-0000000000c1'$$,
  '42501',
  null,
  'a co-member cannot select profiles.birth_visibility'
);

set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
select is(
  (select birth_date from public.person_profile('11111111-1430-4111-8111-111111111111')),
  null,
  'person_profile returns null when visibility is hidden'
);

reset role;
update public.profiles
set birth_visibility = 'year'
where id = 'c1430000-0000-4000-8000-0000000000c1';
set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
select is(
  (select birth_date from public.person_profile('11111111-1430-4111-8111-111111111111')),
  '1984-01-01'::date,
  'person_profile trims a full stored date to the year'
);
select is(
  (select birth_precision::text from public.person_profile('11111111-1430-4111-8111-111111111111')),
  'year',
  'year visibility returns year precision'
);

reset role;
update public.profiles
set birth_visibility = 'year_month'
where id = 'c1430000-0000-4000-8000-0000000000c1';
set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
select is(
  (select birth_date from public.person_profile('11111111-1430-4111-8111-111111111111')),
  '1984-03-01'::date,
  'person_profile trims to year and month'
);

reset role;
update public.profiles
set birth_visibility = 'full'
where id = 'c1430000-0000-4000-8000-0000000000c1';
set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
select is(
  (select birth_date from public.person_profile('11111111-1430-4111-8111-111111111111')),
  '1984-03-14'::date,
  'full visibility returns the stored day'
);

reset role;
update public.profiles
set birth_precision = 'month',
    birth_date = '1984-03-01',
    birth_visibility = 'full'
where id = 'c1430000-0000-4000-8000-0000000000c1';
set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
select is(
  (select birth_precision::text from public.person_profile('11111111-1430-4111-8111-111111111111')),
  'month',
  'person_profile uses the coarser of full visibility and month precision'
);

reset role;
update public.profiles
set birth_date = '1984-03-14',
    birth_precision = 'day',
    birth_visibility = 'year'
where id = 'c1430000-0000-4000-8000-0000000000c1';
set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
select is(
  (select birth_precision::text from public.person_profile('11111111-1430-4111-8111-111111111111')),
  'year',
  'person_profile uses the coarser of year visibility and day precision'
);

set local request.jwt.claim.sub = 'e1430000-0000-4000-8000-0000000000e1';
select throws_ok(
  $$select * from public.person_profile('11111111-1430-4111-8111-111111111111')$$,
  'P0001',
  'NOT_FOUND:',
  'person_profile refuses a non-tree caller'
);

set local request.jwt.claim.sub = 'c1430000-0000-4000-8000-0000000000c1';
select is(
  (select birth_date from public.person_profile('11111111-1430-4111-8111-111111111111')),
  '1984-03-14'::date,
  'the caller own row returns the raw birth date'
);
select is(
  (select birth_date from public.my_profile()),
  '1984-03-14'::date,
  'my_profile returns the caller raw birth date'
);
select is(
  (select birth_visibility::text from public.my_profile()),
  'year',
  'my_profile returns the caller raw visibility'
);

set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
select is(
  (select birth_date from public.my_profile()),
  '1970-01-01'::date,
  'my_profile returns only the caller raw birth date'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$select * from public.my_profile()$$,
  'P0001',
  'NOT_FOUND:',
  'my_profile fails closed for a null uid'
);

select is(
  has_function_privilege(
    'anon',
    'public.mark_passed_away(uuid, boolean)',
    'execute'
  ),
  false,
  'anon cannot execute mark_passed_away'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.mark_passed_away(uuid, boolean)',
    'execute'
  ),
  true,
  'authenticated can execute mark_passed_away'
);
select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'mark_passed_away'
      and 'search_path=""' = any (p.proconfig)
  ),
  'mark_passed_away has search_path=""'
);
select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'my_profile'
      and 'search_path=""' = any (p.proconfig)
  ),
  'my_profile has search_path=""'
);

update public.people
set updated_at = '2000-01-01'
where id = '11111111-1430-4111-8111-111111111111';

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
select lives_ok(
  $$select public.mark_passed_away('11111111-1430-4111-8111-111111111111', true)$$,
  'the home-family owner can mark passed away'
);

reset role;
select is(
  (select name from public.people where id = '11111111-1430-4111-8111-111111111111'),
  'Member Cam',
  'mark_passed_away does not change the name'
);
select is(
  (select about from public.people where id = '11111111-1430-4111-8111-111111111111'),
  'keep',
  'mark_passed_away does not change about'
);
select is(
  (select passed_away from public.people where id = '11111111-1430-4111-8111-111111111111'),
  true,
  'mark_passed_away sets the flag'
);
select ok(
  (
    select updated_at > '2000-01-01'
    from public.people
    where id = '11111111-1430-4111-8111-111111111111'
  ),
  'mark_passed_away sets updated_at'
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
select lives_ok(
  $$select public.mark_passed_away('11111111-1430-4111-8111-111111111111', false)$$,
  'p_value false clears the flag'
);
reset role;
select is(
  (select passed_away from public.people where id = '11111111-1430-4111-8111-111111111111'),
  false,
  'undo clears passed_away'
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
select ok(
  not exists (
    select 1
    from public.list_unlinked_people((select home_id from m143_ctx))
    where id = '11111111-1430-4111-8111-111111111111'
  ),
  'a linked person stays out of list_unlinked_people after unmark'
);

set local request.jwt.claim.sub = 'b1430000-0000-4000-8000-0000000000b1';
select lives_ok(
  $$select public.mark_passed_away('11111111-1430-4111-8111-111111111111', true)$$,
  'the home-family co-owner can mark passed away'
);
select lives_ok(
  $$select public.mark_passed_away('11111111-1430-4111-8111-111111111111', false)$$,
  'the home-family co-owner can unmark passed away'
);

set local request.jwt.claim.sub = 'd1430000-0000-4000-8000-0000000000d1';
select throws_ok(
  $$select public.mark_passed_away('11111111-1430-4111-8111-111111111111', true)$$,
  'P0001',
  'FORBIDDEN:',
  'an owner of another family in the tree is refused'
);

set local request.jwt.claim.sub = 'f1430000-0000-4000-8000-0000000000f1';
select throws_ok(
  $$select public.mark_passed_away('11111111-1430-4111-8111-111111111111', true)$$,
  'P0001',
  'FORBIDDEN:',
  'a plain member is refused'
);

set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
select throws_ok(
  $$select public.mark_passed_away((select owner_person from m143_ctx), true)$$,
  'P0001',
  'VALIDATION: cannot mark yourself',
  'a caller cannot mark themselves'
);
select throws_ok(
  $$select public.mark_passed_away('22222222-1430-4111-8111-222222222222', true)$$,
  'P0001',
  'VALIDATION: person has not signed in',
  'an unlinked target is refused'
);

set local request.jwt.claim.sub = 'e1430000-0000-4000-8000-0000000000e1';
select throws_ok(
  $$select public.mark_passed_away('11111111-1430-4111-8111-111111111111', true)$$,
  'P0001',
  'NOT_FOUND:',
  'a non-tree caller is refused'
);

set local request.jwt.claim.sub = 'c1430000-0000-4000-8000-0000000000c1';
select throws_ok(
  $$update public.people
      set passed_away = true
      where id = '11111111-1430-4111-8111-111111111111'$$,
  'P0001',
  'FORBIDDEN:',
  'a linked user cannot change passed_away on their own row'
);

set local request.jwt.claim.sub = 'f1430000-0000-4000-8000-0000000000f1';
select lives_ok(
  $$update public.people
      set passed_away = true
      where id = '22222222-1430-4111-8111-222222222222'$$,
  'a tree member can flag an unlinked row'
);

set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
select ok(
  not exists (
    select 1
    from public.list_unlinked_people((select home_id from m143_ctx))
    where id = '22222222-1430-4111-8111-222222222222'
  ),
  'list_unlinked_people excludes flagged people'
);

set local request.jwt.claim.sub = 'f1430000-0000-4000-8000-0000000000f1';
select lives_ok(
  $$update public.people
      set passed_away = false
      where id = '22222222-1430-4111-8111-222222222222'$$,
  'a tree member can clear the flag on an unlinked row'
);

set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
select ok(
  exists (
    select 1
    from public.list_unlinked_people((select home_id from m143_ctx))
    where id = '22222222-1430-4111-8111-222222222222'
  ),
  'an unlinked person returns to list_unlinked_people only after the flag is cleared'
);

reset role;
update public.people
set passed_away = true
where id = '22222222-1430-4111-8111-222222222222';

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a1430000-0000-4000-8000-0000000000a1';
select throws_ok(
  $$select public.assert_invite_person(
      (select home_id from m143_ctx),
      '22222222-1430-4111-8111-222222222222'
    )$$,
  'P0001',
  'VALIDATION: person has passed',
  'assert_invite_person rejects passed_away'
);

select * from finish();
rollback;
