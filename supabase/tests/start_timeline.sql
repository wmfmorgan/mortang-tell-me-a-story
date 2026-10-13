-- M11b start a timeline. One transaction, rolled back.
-- create_branch_family does not exist until 20261011200000_start_a_timeline.sql.

begin;
create extension if not exists pgtap with schema extensions;

-- Local databases may still have this trigger from work that never landed in a
-- migration. Dropping it here is transaction-local and rolls back with the test.
drop trigger if exists memberships_ensure_person on public.memberships;

create temporary table m11b_ctx (
  user_a uuid primary key,
  user_b uuid not null,
  user_c uuid not null,
  user_d uuid not null,
  user_e uuid not null,
  user_f uuid not null,
  user_g uuid not null,
  user_h uuid not null,
  parent_id uuid,
  ada_id uuid,
  bea_id uuid,
  grand_id uuid,
  other_id uuid,
  gone_id uuid,
  s_root uuid,
  s_root2 uuid,
  s_draft uuid,
  s_ada uuid,
  s_bea uuid,
  s_other uuid,
  s_gone uuid,
  person_b uuid,
  person_c uuid,
  person_none uuid,
  person_foreign uuid,
  member_branch uuid,
  co_branch uuid,
  owner_branch uuid,
  year_far uuid,
  year_low uuid,
  year_high uuid,
  nested uuid,
  deep_parent uuid,
  deep_story uuid,
  deep_branch uuid,
  photo_id uuid
);

grant all on table m11b_ctx to authenticated, anon, service_role;

insert into m11b_ctx (
  user_a, user_b, user_c, user_d, user_e, user_f, user_g, user_h
) values (
  'a11b0000-0000-4000-8000-0000000000a1',
  'b11b0000-0000-4000-8000-0000000000b2',
  'c11b0000-0000-4000-8000-0000000000c1',
  'd11b0000-0000-4000-8000-0000000000d1',
  'e11b0000-0000-4000-8000-0000000000e1',
  'f11b0000-0000-4000-8000-0000000000f1',
  '611b1111-0000-4000-8000-000000000061',
  'a11b0000-0000-4000-8000-0000000000b8'
);

insert into auth.users (id, email, raw_user_meta_data)
select user_a, 'm11b-a@test.local', '{"display_name":"M11b A"}'::jsonb from m11b_ctx
union all
select user_b, 'm11b-b@test.local', '{"display_name":"M11b B"}'::jsonb from m11b_ctx
union all
select user_c, 'm11b-c@test.local', '{"display_name":"M11b C"}'::jsonb from m11b_ctx
union all
select user_d, 'm11b-d@test.local', '{"display_name":""}'::jsonb from m11b_ctx
union all
select user_e, 'm11b-e@test.local', '{"display_name":"M11b E"}'::jsonb from m11b_ctx
union all
select user_f, 'm11b-f@test.local', '{"display_name":"M11b F"}'::jsonb from m11b_ctx
union all
select user_g, 'm11b-g@test.local', '{"display_name":"M11b G"}'::jsonb from m11b_ctx
union all
select user_h, 'm11b-h@test.local', '{"display_name":"M11b H"}'::jsonb from m11b_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a11b0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

update m11b_ctx set parent_id = (public.create_family('Parent')).id;
update m11b_ctx set gone_id = (public.create_family('Gone')).id;

set local request.jwt.claim.sub = '611b1111-0000-4000-8000-000000000061';
update m11b_ctx set other_id = (public.create_family('Other')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.memberships (family_id, user_id, role)
select parent_id, user_b, 'member'::public.membership_role from m11b_ctx
union all
select parent_id, user_e, 'member'::public.membership_role from m11b_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a11b0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

select public.add_co_owner(
  (select parent_id from m11b_ctx),
  (select user_e from m11b_ctx)
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

with inserted as (
  insert into public.families (name, created_by, parent_family_id)
  select 'Ada', user_h, parent_id from m11b_ctx
  returning id
)
update m11b_ctx set ada_id = inserted.id from inserted;

with inserted as (
  insert into public.families (name, created_by, parent_family_id)
  select 'Bea', user_c, parent_id from m11b_ctx
  returning id
)
update m11b_ctx set bea_id = inserted.id from inserted;

with inserted as (
  insert into public.families (name, created_by, parent_family_id)
  select 'Grand', user_h, ada_id from m11b_ctx
  returning id
)
update m11b_ctx set grand_id = inserted.id from inserted;

insert into public.memberships (family_id, user_id, role)
select ada_id, user_h, 'owner'::public.membership_role from m11b_ctx
union all
select bea_id, user_c, 'owner'::public.membership_role from m11b_ctx
union all
select grand_id, user_h, 'owner'::public.membership_role from m11b_ctx;

update m11b_ctx set
  s_root = '11111111-11b1-4111-8111-111111111111',
  s_root2 = '12121212-11b1-4111-8111-121212121212',
  s_draft = '44444444-11b1-4111-8111-444444444444',
  s_ada = '13131313-11b1-4111-8111-131313131313',
  s_bea = '14141414-11b1-4111-8111-141414141414',
  s_other = '55555555-11b1-4111-8111-555555555555',
  s_gone = '16161616-11b1-4111-8111-161616161616',
  person_b = 'b0b0b0b0-11b1-4111-8111-b0b0b0b0b0b0',
  person_c = 'c0c0c0c0-11b1-4111-8111-c0c0c0c0c0c0',
  person_none = 'd0d0d0d0-11b1-4111-8111-d0d0d0d0d0d0',
  person_foreign = 'e0e0e0e0-11b1-4111-8111-e0e0e0e0e0e0',
  photo_id = 'f0f0f0f0-11b1-4111-8111-f0f0f0f0f0f0';

insert into public.stories (
  id, family_id, author_id, title, timeframe_start, status
)
select s_root, parent_id, user_a, 'The beginning', '1970-01-01'::date, 'published'::public.story_status from m11b_ctx
union all
select s_root2, parent_id, user_a, 'Later', '1982-06-01'::date, 'published'::public.story_status from m11b_ctx
union all
select s_draft, parent_id, user_a, 'Draft', '1983-01-01'::date, 'draft'::public.story_status from m11b_ctx
union all
select s_ada, ada_id, user_h, 'Ada tale', '1990-01-01'::date, 'published'::public.story_status from m11b_ctx
union all
select s_bea, bea_id, user_c, 'Bea tale', '1991-01-01'::date, 'published'::public.story_status from m11b_ctx
union all
select s_other, other_id, user_g, 'Elsewhere', '1984-01-01'::date, 'published'::public.story_status from m11b_ctx
union all
select s_gone, gone_id, user_a, 'Gone tale', '1985-01-01'::date, 'published'::public.story_status from m11b_ctx;

insert into public.people (id, family_id, name, relationship, email, user_id, created_by)
select person_b, parent_id, 'Bee', 'kin', null, user_b, user_a from m11b_ctx
union all
select person_c, parent_id, 'Cee', 'kin', 'm11b-c@test.local', null, user_a from m11b_ctx
union all
select person_none, parent_id, 'No Account', 'kin', null, null, user_a from m11b_ctx
union all
select person_foreign, other_id, 'Foreign', 'kin', null, user_g, user_g from m11b_ctx;

insert into public.photos (id, story_id, family_id, uploader_id, storage_path)
select
  photo_id, s_gone, gone_id, user_a,
  gone_id::text || '/' || s_gone::text || '/gone.jpg'
from m11b_ctx;

insert into storage.objects (bucket_id, name, owner_id)
select
  'story-photos',
  gone_id::text || '/' || s_gone::text || '/gone.jpg',
  user_a::text
from m11b_ctx;

update public.families set deleted_at = now() where id = (select gone_id from m11b_ctx);

-- Parent at 62 levels below the root. The next create is level 63.
do $$
declare
  i int;
  prev uuid;
  nid uuid;
  maker uuid;
begin
  select parent_id, user_a into prev, maker from m11b_ctx;
  for i in 1..62 loop
    insert into public.families (name, created_by, parent_family_id)
    values ('Level ' || i, maker, prev)
    returning id into nid;
    prev := nid;
  end loop;
  update m11b_ctx set deep_parent = prev, deep_story = '17171717-11b1-4111-8111-171717171717';
end $$;

insert into public.stories (
  id, family_id, author_id, title, timeframe_start, status
)
select deep_story, deep_parent, user_a, 'Deep', '2000-01-01'::date, 'published'::public.story_status
from m11b_ctx;

insert into public.memberships (family_id, user_id, role)
select deep_parent, user_a, 'owner'::public.membership_role from m11b_ctx;

select plan(77);

-- Member starter. Not added unless chosen. Owner is B. People copied.
set local role authenticated;
set local request.jwt.claim.sub = 'a11b0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

update m11b_ctx set member_branch = (
  select id from public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root from m11b_ctx),
    '  Member line  ',
    1972,
    (select user_b from m11b_ctx),
    array[
      (select person_b from m11b_ctx),
      (select person_c from m11b_ctx),
      (select person_none from m11b_ctx),
      (select person_c from m11b_ctx)
    ]
  )
);

select is(
  (select name from public.families where id = (select member_branch from m11b_ctx)),
  'Member line',
  'a member create trims the name'
);
select is(
  (select parent_family_id from public.families where id = (select member_branch from m11b_ctx)),
  (select parent_id from m11b_ctx),
  'a member create sets the parent'
);
select is(
  (select branch_year from public.families where id = (select member_branch from m11b_ctx)),
  1972,
  'a member create stores the attach year'
);
select is(
  (select created_by from public.families where id = (select member_branch from m11b_ctx)),
  (select user_a from m11b_ctx),
  'created_by is the caller'
);
select is(
  (select origin_story_id from public.families where id = (select member_branch from m11b_ctx)),
  (select s_root from m11b_ctx),
  'origin_story_id is the published parent story'
);
reset role;
select set_config('request.jwt.claim.sub', '', true);
select is(
  public.family_origin((select member_branch from m11b_ctx)),
  (select s_root from m11b_ctx),
  'family_origin returns the origin'
);
select is(
  (select count(*) from public.memberships
    where family_id = (select member_branch from m11b_ctx)
      and role = 'owner'::public.membership_role),
  1::bigint,
  'exactly one owner'
);
select is(
  (select user_id from public.memberships
    where family_id = (select member_branch from m11b_ctx)
      and role = 'owner'::public.membership_role),
  (select user_b from m11b_ctx),
  'the picked owner is the owner'
);
select is(
  (select count(*) from public.memberships
    where family_id = (select member_branch from m11b_ctx)
      and user_id = (select user_a from m11b_ctx)),
  0::bigint,
  'the starter is not auto-added'
);
select is(
  (select role::text from public.memberships
    where family_id = (select parent_id from m11b_ctx)
      and user_id = (select user_a from m11b_ctx)),
  'owner',
  'the starter stays owner of the parent'
);
select is(
  (select count(*) from public.people
    where family_id = (select member_branch from m11b_ctx)),
  0::bigint,
  'a new timeline adds no people rows'
);
select is(
  (select role::text from public.memberships
    where family_id = (select member_branch from m11b_ctx)
      and user_id = (select user_b from m11b_ctx)),
  'owner',
  'picking the owner as a person keeps the owner role'
);
select is(
  (select count(*) from public.memberships
    where family_id = (select member_branch from m11b_ctx)
      and user_id = (select user_c from m11b_ctx)),
  0::bigint,
  'an email match does not become a member'
);
select is(
  (select count(*) from public.people
    where family_id = (select member_branch from m11b_ctx)
      and name = 'No Account'),
  0::bigint,
  'a person with no account is not copied'
);
select is(
  (select count(*) from public.memberships m
    join public.people p on p.user_id = m.user_id and p.family_id = m.family_id
    where m.family_id = (select member_branch from m11b_ctx)
      and p.name = 'No Account'),
  0::bigint,
  'a person with no account gets no membership'
);
set local role authenticated;
set local request.jwt.claim.sub = 'a11b0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';
select ok(
  exists (
    select 1 from public.list_family_tree((select parent_id from m11b_ctx)) t
    where t.id = (select member_branch from m11b_ctx)
      and t.origin_story_id = (select s_root from m11b_ctx)
  ),
  'list_family_tree includes the new family'
);
select ok(
  exists (
    select 1 from public.list_origin_dependents((select s_root from m11b_ctx)) d
    where d.family_id = (select member_branch from m11b_ctx)
  ),
  'list_origin_dependents includes the new family'
);

set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b2';

select lives_ok(
  $$select public.set_family_origin(
    (select member_branch from m11b_ctx),
    (select s_root2 from m11b_ctx)
  )$$,
  'the new owner can change the origin'
);
reset role;
select set_config('request.jwt.claim.sub', '', true);
select is(
  public.family_origin((select member_branch from m11b_ctx)),
  (select s_root2 from m11b_ctx),
  'family_origin follows the owner change'
);
set local role authenticated;
set local request.jwt.claim.sub = 'a11b0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

set local request.jwt.claim.sub = 'a11b0000-0000-4000-8000-0000000000a1';

select throws_ok(
  $$select public.set_family_origin(
    (select member_branch from m11b_ctx),
    (select s_root from m11b_ctx)
  )$$,
  'P0001',
  'FORBIDDEN',
  'the starter who is not owner cannot change the origin'
);
set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b2';

select throws_ok(
  $$update public.families
    set origin_story_id = (select s_root from m11b_ctx)
    where id = (select member_branch from m11b_ctx)$$,
  'P0001',
  'FORBIDDEN: field is locked',
  'a direct origin_story_id update is locked'
);

set local request.jwt.claim.sub = 'a11b0000-0000-4000-8000-0000000000a1';

-- Co-owner and owner.
set local request.jwt.claim.sub = 'e11b0000-0000-4000-8000-0000000000e1';

update m11b_ctx set co_branch = (
  select id from public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root from m11b_ctx),
    'Co line',
    1980,
    (select user_e from m11b_ctx),
    '{}'::uuid[]
  )
);

select is(
  (select name from public.families where id = (select co_branch from m11b_ctx)),
  'Co line',
  'a co-owner create stores the name'
);
reset role;
select set_config('request.jwt.claim.sub', '', true);
select is(
  public.family_origin((select co_branch from m11b_ctx)),
  (select s_root from m11b_ctx),
  'a co-owner create sets the origin'
);
set local role authenticated;
set local request.jwt.claim.sub = 'e11b0000-0000-4000-8000-0000000000e1';
set local request.jwt.claim.role = 'authenticated';
select is(
  (select user_id from public.memberships
    where family_id = (select co_branch from m11b_ctx)
      and role = 'owner'::public.membership_role),
  (select user_e from m11b_ctx),
  'a co-owner can be the new owner'
);

set local request.jwt.claim.sub = 'a11b0000-0000-4000-8000-0000000000a1';

update m11b_ctx set owner_branch = (
  select id from public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root2 from m11b_ctx),
    'Owner line',
    1982,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )
);

select is(
  (select created_by from public.families where id = (select owner_branch from m11b_ctx)),
  (select user_a from m11b_ctx),
  'an owner create records the caller'
);
reset role;
select set_config('request.jwt.claim.sub', '', true);
select is(
  public.family_origin((select owner_branch from m11b_ctx)),
  (select s_root2 from m11b_ctx),
  'an owner create sets the origin'
);
set local role authenticated;
set local request.jwt.claim.sub = 'a11b0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';
select is(
  (select count(*) from public.memberships
    where family_id = (select owner_branch from m11b_ctx)
      and user_id = (select user_a from m11b_ctx)
      and role = 'owner'::public.membership_role),
  1::bigint,
  'the owner is in the new timeline only because they were picked'
);

update m11b_ctx set year_far = (
  select id from public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root from m11b_ctx),
    'Far year',
    2099,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )
);
update m11b_ctx set year_low = (
  select id from public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root from m11b_ctx),
    'Low year',
    1000,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )
);
update m11b_ctx set year_high = (
  select id from public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root from m11b_ctx),
    'High year',
    9999,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )
);

select is((select branch_year from public.families where id = (select year_far from m11b_ctx)), 2099, 'a future year 2099 is stored');
select is((select branch_year from public.families where id = (select year_low from m11b_ctx)), 1000, 'year 1000 is stored');
select is((select branch_year from public.families where id = (select year_high from m11b_ctx)), 9999, 'year 9999 is stored');

-- Uniform NOT_FOUND: story. Nothing is written.
select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    '99999999-11b1-4111-8111-999999999999',
    'Missing story',
    1970,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'NOT_FOUND: story',
  'a random story id is NOT_FOUND: story'
);
select is(
  (select count(*) from public.families where name = 'Missing story'),
  0::bigint,
  'a missing story writes no family'
);

select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_draft from m11b_ctx),
    'Draft origin',
    1970,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'NOT_FOUND: story',
  'a draft origin is NOT_FOUND: story'
);
select is(
  (select count(*) from public.families where name = 'Draft origin'),
  0::bigint,
  'a draft origin writes no family'
);

select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_other from m11b_ctx),
    'Other origin',
    1970,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'NOT_FOUND: story',
  'another family''s story is NOT_FOUND: story'
);
select is(
  (select count(*) from public.families where name = 'Other origin'),
  0::bigint,
  'another family''s story writes no family'
);

set local request.jwt.claim.sub = 'a11b0000-0000-4000-8000-0000000000b8';

select throws_ok(
  $$select public.create_branch_family(
    (select ada_id from m11b_ctx),
    (select s_bea from m11b_ctx),
    'Sibling origin',
    1991,
    (select user_h from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'NOT_FOUND: story',
  'a sibling story is NOT_FOUND: story'
);
select is(
  (select count(*) from public.families where name = 'Sibling origin'),
  0::bigint,
  'a sibling story writes no family'
);

select throws_ok(
  $$select public.create_branch_family(
    (select ada_id from m11b_ctx),
    (select s_root from m11b_ctx),
    'Grandparent origin',
    1970,
    (select user_h from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'NOT_FOUND: story',
  'a grandparent story is NOT_FOUND: story'
);
select is(
  (select count(*) from public.families where name = 'Grandparent origin'),
  0::bigint,
  'a grandparent story writes no family'
);

select throws_ok(
  $$select public.create_branch_family(
    (select grand_id from m11b_ctx),
    (select s_root from m11b_ctx),
    'Grandchild origin',
    1970,
    (select user_h from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'NOT_FOUND: story',
  'a grandchild cannot use a root story as its origin'
);
select is(
  (select count(*) from public.families where name = 'Grandchild origin'),
  0::bigint,
  'a root story on a grandchild writes no family'
);

set local request.jwt.claim.sub = 'a11b0000-0000-4000-8000-0000000000a1';

select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    null,
    'Null origin',
    1970,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'NOT_FOUND: story',
  'a null origin is NOT_FOUND: story'
);
select is(
  (select count(*) from public.families where name = 'Null origin'),
  0::bigint,
  'a null origin writes no family'
);

-- Check 1 before check 2, including a null parent.
set local request.jwt.claim.sub = 'f11b0000-0000-4000-8000-0000000000f1';

select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    '99999999-11b1-4111-8111-999999999999',
    'Stranger bad story',
    1970,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'FORBIDDEN: member only',
  'a non-member with a bad origin gets FORBIDDEN before NOT_FOUND'
);

select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root from m11b_ctx),
    'Stranger',
    1970,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'FORBIDDEN: member only',
  'a stranger is FORBIDDEN: member only'
);

set local request.jwt.claim.sub = 'a11b0000-0000-4000-8000-0000000000b8';

select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root from m11b_ctx),
    'Tree reader',
    1970,
    (select user_h from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'FORBIDDEN: member only',
  'a non-member tree reader is FORBIDDEN: member only'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root from m11b_ctx),
    'No uid',
    1970,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'FORBIDDEN: member only',
  'a null uid is FORBIDDEN: member only'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a11b0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

select throws_ok(
  $$select public.create_branch_family(
    null,
    (select s_root from m11b_ctx),
    'Null parent',
    1970,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'FORBIDDEN: member only',
  'a null parent_family_id is FORBIDDEN before the story check'
);

select throws_ok(
  $$select public.create_branch_family(
    (select gone_id from m11b_ctx),
    (select s_gone from m11b_ctx),
    'Gone parent',
    1985,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'FORBIDDEN: member only',
  'a member of a soft-deleted parent is FORBIDDEN: member only'
);

-- Check 2 before check 3.
select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    '99999999-11b1-4111-8111-999999999999',
    '   ',
    1970,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'NOT_FOUND: story',
  'a bad origin and a blank name is NOT_FOUND before the name check'
);

select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root from m11b_ctx),
    '   ',
    1970,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'VALIDATION: name is required',
  'a whitespace name is VALIDATION: name is required'
);
select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root from m11b_ctx),
    '',
    1970,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'VALIDATION: name is required',
  'a blank name is VALIDATION: name is required'
);

select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root from m11b_ctx),
    'Null year',
    null,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'VALIDATION: attach year must be four digits',
  'a null year is VALIDATION: attach year must be four digits'
);
select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root from m11b_ctx),
    'Short year',
    987,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'VALIDATION: attach year must be four digits',
  'year 987 is VALIDATION: attach year must be four digits'
);
select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root from m11b_ctx),
    'Long year',
    10000,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'VALIDATION: attach year must be four digits',
  'year 10000 is VALIDATION: attach year must be four digits'
);

select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root from m11b_ctx),
    'Null owner',
    1970,
    null,
    '{}'::uuid[]
  )$$,
  'P0001',
  'VALIDATION: owner must be a member of the parent family',
  'a null owner is rejected'
);
select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root from m11b_ctx),
    'Foreign owner',
    1970,
    (select user_f from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'VALIDATION: owner must be a member of the parent family',
  'an owner who is not a parent member is rejected'
);

select throws_ok(
  $$select public.create_branch_family(
    (select parent_id from m11b_ctx),
    (select s_root from m11b_ctx),
    'Atomic gap',
    1970,
    (select user_a from m11b_ctx),
    array[(select person_foreign from m11b_ctx)]
  )$$,
  'P0001',
  'VALIDATION: members must come from the parent family',
  'a foreign person is rejected'
);
select is(
  (select count(*) from public.families where name = 'Atomic gap'),
  0::bigint,
  'a person error writes no family'
);
select is(
  (select count(*) from public.memberships m
    join public.families f on f.id = m.family_id
    where f.name = 'Atomic gap'),
  0::bigint,
  'a person error writes no membership'
);
select is(
  (select count(*) from public.families
    where name = 'Atomic gap' and origin_story_id is not null),
  0::bigint,
  'a person error writes no origin'
);

-- Nesting. A parent 62 below the root can create. The next level cannot.
update m11b_ctx set deep_branch = (
  select id from public.create_branch_family(
    (select deep_parent from m11b_ctx),
    (select deep_story from m11b_ctx),
    'Level 63',
    2001,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )
);

select is(
  (select parent_family_id from public.families where id = (select deep_branch from m11b_ctx)),
  (select deep_parent from m11b_ctx),
  'a create whose parent walks to 62 succeeds'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.stories (
  id, family_id, author_id, title, timeframe_start, status
)
select
  '18181818-11b1-4111-8111-181818181818',
  deep_branch, user_a, 'Deeper', '2002-01-01'::date, 'published'::public.story_status
from m11b_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a11b0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

select throws_ok(
  $$select public.create_branch_family(
    (select deep_branch from m11b_ctx),
    '18181818-11b1-4111-8111-181818181818',
    'Level 64',
    2002,
    (select user_a from m11b_ctx),
    '{}'::uuid[]
  )$$,
  'P0001',
  'VALIDATION: too many levels',
  'the next level raises VALIDATION: too many levels'
);
select is(
  (select count(*) from public.families where name = 'Level 64'),
  0::bigint,
  'a refused level writes no family'
);

select throws_ok(
  $$insert into public.families (name, created_by)
    select 'Direct insert', user_a from m11b_ctx$$,
  '42501',
  'new row violates row-level security policy for table "families"',
  'an authenticated insert into families is 42501'
);

select throws_ok(
  $$update public.families
    set parent_family_id = (select ada_id from m11b_ctx)
    where id = (select owner_branch from m11b_ctx)$$,
  'P0001',
  'FORBIDDEN: field is locked',
  'a parent_family_id update is locked'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
set local role service_role;

select throws_ok(
  $$insert into public.families (id, name, created_by, parent_family_id)
    select
      'abababab-11b0-4111-8111-abababababab',
      'Self parent',
      user_a,
      'abababab-11b0-4111-8111-abababababab'
    from m11b_ctx$$,
  '23514',
  'new row for relation "families" violates check constraint "families_parent_not_self"',
  'a service-role self-parent insert is 23514'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select ok(
  not has_function_privilege(
    'anon',
    'public.create_branch_family(uuid, uuid, text, integer, uuid, uuid[])',
    'execute'
  ),
  'anon has no execute on create_branch_family'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.create_branch_family(uuid, uuid, text, integer, uuid, uuid[])',
    'execute'
  ),
  'authenticated can execute create_branch_family'
);
select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'create_branch_family'
      and 'search_path=""' = any (p.proconfig)
  ),
  'create_branch_family search_path is empty'
);
select ok(
  (select prosrc from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'family_tree_root')
    like '%w.depth < 64%',
  'family_tree_root walk cap stays 64'
);
select is(
  (select count(*) from pg_policies where schemaname in ('public', 'storage')),
  47::bigint,
  'policy count stays 47'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a11b0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

select is_empty(
  $$delete from public.photos
    where id = (select photo_id from m11b_ctx)
    returning 1$$,
  'a member of a soft-deleted family deletes 0 photo rows'
);
-- storage.protect_delete rejects every direct delete. The row must stay.
select lives_ok(
  $$do $body$
    begin
      delete from storage.objects
      where bucket_id = 'story-photos'
        and name = (
          select gone_id::text || '/' || s_gone::text || '/gone.jpg' from m11b_ctx
        );
    exception
      when others then
        null;
    end
    $body$;$$,
  'a member of a soft-deleted family does not remove a story-photos object'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  (select count(*) from public.photos where id = (select photo_id from m11b_ctx)),
  1::bigint,
  'the soft-deleted family photo row is still there'
);
select is(
  (select count(*) from storage.objects
    where bucket_id = 'story-photos'
      and name = (
        select gone_id::text || '/' || s_gone::text || '/gone.jpg' from m11b_ctx
      )),
  1::bigint,
  'the soft-deleted family storage object is still there'
);

select * from finish();
rollback;
