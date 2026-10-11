-- M12 tree read: a parent member can read a child's published rows and
-- people_tree_read, and cannot read drafts, people, or write.
-- Soft-deleted families drop out of the walk. A two-family cycle returns
-- each id once. The script runs in a transaction and rolls back.

begin;
create extension if not exists pgtap with schema extensions;

select plan(37);

create temporary table m12_ctx (
  user_a uuid primary key,
  user_b uuid not null,
  user_c uuid not null,
  user_d uuid not null,
  parent_id uuid,
  child_id uuid,
  lone_id uuid,
  grand_id uuid,
  mid_id uuid,
  leaf_id uuid,
  cycle_a uuid,
  cycle_b uuid
);

grant all on table m12_ctx to authenticated, anon, service_role;

insert into m12_ctx (user_a, user_b, user_c, user_d)
values (
  'a12a0000-0000-4000-8000-00000000000a',
  'b12b0000-0000-4000-8000-00000000000b',
  'c12c0000-0000-4000-8000-00000000000c',
  'd12d0000-0000-4000-8000-00000000000d'
);

insert into auth.users (id, email, raw_user_meta_data)
select user_a, 'm12-a@test.local', '{"display_name":"M12 A"}'::jsonb from m12_ctx
union all
select user_b, 'm12-b@test.local', '{"display_name":"M12 B"}'::jsonb from m12_ctx
union all
select user_c, 'm12-c@test.local', '{"display_name":"M12 C"}'::jsonb from m12_ctx
union all
select user_d, 'm12-d@test.local', '{"display_name":"M12 D"}'::jsonb from m12_ctx;

select is(
  has_function_privilege('anon', 'public.family_tree_root(uuid)', 'execute'),
  false,
  'anon cannot execute family_tree_root'
);
select is(
  has_function_privilege('anon', 'public.is_family_tree_readable(uuid)', 'execute'),
  false,
  'anon cannot execute is_family_tree_readable'
);
select is(
  has_function_privilege('anon', 'public.list_family_tree(uuid)', 'execute'),
  false,
  'anon cannot execute list_family_tree'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.family_tree_root(uuid)',
    'execute'
  ),
  false,
  'authenticated cannot execute family_tree_root'
);
select is(
  has_table_privilege('anon', 'public.people_tree_read', 'select'),
  false,
  'anon cannot select people_tree_read'
);
select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'people_tree_read'
      and column_name = 'email'
  ),
  0::bigint,
  'people_tree_read has no email column'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a12a0000-0000-4000-8000-00000000000a';
set local request.jwt.claim.role = 'authenticated';

update m12_ctx set parent_id = (public.create_family('Parent')).id;
update m12_ctx set lone_id = (public.create_family('Lone')).id;
update m12_ctx set grand_id = (public.create_family('Grand')).id;
update m12_ctx set mid_id = (public.create_family('Mid')).id;
update m12_ctx set cycle_a = (public.create_family('Cycle A')).id;
update m12_ctx set cycle_b = (public.create_family('Cycle B')).id;

set local request.jwt.claim.sub = 'b12b0000-0000-4000-8000-00000000000b';

update m12_ctx set child_id = (public.create_family('Child')).id;

set local request.jwt.claim.sub = 'd12d0000-0000-4000-8000-00000000000d';

update m12_ctx set leaf_id = (public.create_family('Leaf')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

update public.families f
set parent_family_id = c.parent_id, branch_year = 1972
from m12_ctx c
where f.id = c.child_id;

update public.families f
set parent_family_id = c.grand_id
from m12_ctx c
where f.id = c.mid_id;

update public.families f
set parent_family_id = c.mid_id
from m12_ctx c
where f.id = c.leaf_id;

update public.families f
set parent_family_id = c.cycle_b
from m12_ctx c
where f.id = c.cycle_a;

update public.families f
set parent_family_id = c.cycle_a
from m12_ctx c
where f.id = c.cycle_b;

select throws_ok(
  $$ update public.families set branch_year = 0 where id = (select lone_id from m12_ctx) $$,
  '23514',
  'new row for relation "families" violates check constraint "families_branch_year_check"',
  'branch_year rejects 0'
);
select throws_ok(
  $$ update public.families set branch_year = 10000 where id = (select lone_id from m12_ctx) $$,
  '23514',
  'new row for relation "families" violates check constraint "families_branch_year_check"',
  'branch_year rejects 10000'
);
select lives_ok(
  $$ update public.families set branch_year = null where id = (select lone_id from m12_ctx) $$,
  'branch_year accepts null'
);

set local role authenticated;
set local request.jwt.claim.sub = 'b12b0000-0000-4000-8000-00000000000b';
set local request.jwt.claim.role = 'authenticated';

insert into public.people (id, family_id, name, relationship, email, created_by)
select
  '33333333-3333-4333-8333-333333333333',
  child_id,
  'Cousin Cora',
  'cousin',
  'cora@test.local',
  user_b
from m12_ctx;

insert into public.places (id, family_id, label, address, lat, lng)
select
  '44444444-4444-4444-8444-444444444444',
  child_id,
  'Cabin',
  '1 Lake Rd',
  45.0,
  -93.0
from m12_ctx;

insert into public.stories (
  id, family_id, author_id, title, body, timeframe_start, place_id, status
)
select
  '11111111-1111-4111-8111-111111111111',
  child_id,
  user_b,
  'Published',
  'visible body',
  '1972-06-01'::date,
  '44444444-4444-4444-8444-444444444444',
  'published'::public.story_status
from m12_ctx;

insert into public.stories (
  id, family_id, author_id, title, body, timeframe_start, status
)
select
  '22222222-2222-4222-8222-222222222222',
  child_id,
  user_b,
  'Draft',
  'secret body',
  '1973-01-01'::date,
  'draft'::public.story_status
from m12_ctx;

insert into public.photos (
  id, story_id, family_id, uploader_id, storage_path, sort_order
)
select
  '55555555-5555-4555-8555-555555555555',
  '11111111-1111-4111-8111-111111111111',
  child_id,
  user_b,
  child_id::text
    || '/11111111-1111-4111-8111-111111111111/55555555-5555-4555-8555-555555555555.jpg',
  0
from m12_ctx;

insert into public.comments (id, story_id, family_id, author_id, body)
select
  '66666666-6666-4666-8666-666666666666',
  '11111111-1111-4111-8111-111111111111',
  child_id,
  user_b,
  'child comment'
from m12_ctx;

insert into public.perspectives (id, story_id, family_id, author_id, body)
select
  '77777777-7777-4777-8777-777777777777',
  '11111111-1111-4111-8111-111111111111',
  child_id,
  user_b,
  'child perspective'
from m12_ctx;

insert into public.story_people (story_id, person_id)
values (
  '11111111-1111-4111-8111-111111111111',
  '33333333-3333-4333-8333-333333333333'
);

set local request.jwt.claim.sub = 'a12a0000-0000-4000-8000-00000000000a';

select is(
  (select count(*) from public.stories where id = '11111111-1111-4111-8111-111111111111'),
  1::bigint,
  'parent member can select the child published story'
);
select is(
  (select count(*) from public.photos where id = '55555555-5555-4555-8555-555555555555'),
  1::bigint,
  'parent member can select the child photo'
);
select is(
  (select count(*) from public.comments where id = '66666666-6666-4666-8666-666666666666'),
  1::bigint,
  'parent member can select the child comment'
);
select is(
  (select count(*) from public.perspectives where id = '77777777-7777-4777-8777-777777777777'),
  1::bigint,
  'parent member can select the child perspective'
);
select is(
  (select count(*) from public.places where id = '44444444-4444-4444-8444-444444444444'),
  1::bigint,
  'parent member can select the child place'
);
select is(
  (
    select count(*)
    from public.story_people
    where story_id = '11111111-1111-4111-8111-111111111111'
  ),
  1::bigint,
  'parent member can select the child story people'
);
select is(
  (select count(*) from public.stories where id = '22222222-2222-4222-8222-222222222222'),
  0::bigint,
  'parent member cannot select the child draft'
);
select is(
  (select count(*) from public.people where family_id = (select child_id from m12_ctx)),
  0::bigint,
  'parent member cannot select child people'
);
select is(
  (
    select name
    from public.people_tree_read
    where id = '33333333-3333-4333-8333-333333333333'
  ),
  'Cousin Cora',
  'parent member reads the child name from people_tree_read'
);
select is(
  (
    select relationship
    from public.people_tree_read
    where id = '33333333-3333-4333-8333-333333333333'
  ),
  'cousin',
  'parent member reads the child relationship from people_tree_read'
);

select throws_ok(
  $$
    insert into public.comments (story_id, family_id, author_id, body)
    select
      '11111111-1111-4111-8111-111111111111',
      child_id,
      user_a,
      'nope'
    from m12_ctx
  $$,
  '42501',
  'new row violates row-level security policy for table "comments"',
  'parent member cannot insert a comment on the child'
);
select throws_ok(
  $$
    insert into public.photos (story_id, family_id, uploader_id, storage_path)
    select
      '11111111-1111-4111-8111-111111111111',
      child_id,
      user_a,
      child_id::text || '/11111111-1111-4111-8111-111111111111/nope.jpg'
    from m12_ctx
  $$,
  '42501',
  'new row violates row-level security policy for table "photos"',
  'parent member cannot insert a photo on the child'
);

select is(
  (
    select array_agg(id order by id)
    from public.list_family_tree((select parent_id from m12_ctx))
  ),
  (
    select array_agg(id order by id)
    from (
      select parent_id as id from m12_ctx
      union all
      select child_id from m12_ctx
    ) expected
  ),
  'parent member lists the parent and the child'
);

set local request.jwt.claim.sub = 'c12c0000-0000-4000-8000-00000000000c';

select is(
  (select count(*) from public.people_tree_read),
  0::bigint,
  'a signed-in user outside the tree gets 0 people_tree_read rows'
);
select is(
  (select count(*) from public.stories where id = '11111111-1111-4111-8111-111111111111'),
  0::bigint,
  'a signed-in user outside the tree cannot select the child published story'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

update public.families
set deleted_at = now()
where id = (select child_id from m12_ctx);

set local role authenticated;
set local request.jwt.claim.sub = 'a12a0000-0000-4000-8000-00000000000a';
set local request.jwt.claim.role = 'authenticated';

select is(
  public.is_family_tree_readable((select child_id from m12_ctx)),
  false,
  'is_family_tree_readable is false for a soft-deleted family'
);
select is(
  (
    select count(*)
    from public.list_family_tree((select parent_id from m12_ctx)) t
    where t.id = (select child_id from m12_ctx)
  ),
  0::bigint,
  'soft-deleted child is absent from list_family_tree for the parent member'
);

set local request.jwt.claim.sub = 'b12b0000-0000-4000-8000-00000000000b';

select is(
  (select count(*) from public.list_family_tree((select child_id from m12_ctx))),
  0::bigint,
  'soft-deleted child is absent from list_family_tree for its owner'
);
select is(
  (select count(*) from public.list_family_tree((select parent_id from m12_ctx))),
  0::bigint,
  'a membership only in a soft-deleted family cannot read the tree'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

update public.families
set deleted_at = now()
where id = (select mid_id from m12_ctx);

select is(
  public.family_tree_root((select leaf_id from m12_ctx)),
  (select leaf_id from m12_ctx),
  'a soft-deleted parent splits the walk so the child is its own root'
);
select is(
  public.family_tree_root((select grand_id from m12_ctx)),
  (select grand_id from m12_ctx),
  'the grandparent root stays the grandparent'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a12a0000-0000-4000-8000-00000000000a';
set local request.jwt.claim.role = 'authenticated';

select is(
  (
    select count(*)
    from public.list_family_tree((select grand_id from m12_ctx)) t
    where t.id = (select leaf_id from m12_ctx)
  ),
  0::bigint,
  'the grandparent member does not see the child below a deleted parent'
);

set local request.jwt.claim.sub = 'd12d0000-0000-4000-8000-00000000000d';

select is(
  (
    select count(*)
    from public.list_family_tree((select leaf_id from m12_ctx)) t
    where t.id = (select grand_id from m12_ctx)
  ),
  0::bigint,
  'the child member does not see the grandparent above a deleted parent'
);

set local request.jwt.claim.sub = 'a12a0000-0000-4000-8000-00000000000a';

select is(
  (
    select count(*)
    from public.list_family_tree((select cycle_a from m12_ctx))
  ),
  2::bigint,
  'a cycle walk returns two rows and ends'
);
select is(
  (
    select count(*)
    from (
      select distinct id
      from public.list_family_tree((select cycle_a from m12_ctx))
    ) d
  ),
  2::bigint,
  'a cycle walk returns each id once'
);

select is(
  (
    select array_agg(id)
    from public.list_family_tree((select lone_id from m12_ctx))
  ),
  array[(select lone_id from m12_ctx)],
  'a family with no parent and no children lists itself'
);

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'anon', true);

select lives_ok(
  'select count(*) from public.stories',
  'anon selecting stories does not error'
);
select is(
  (select count(*) from public.stories),
  0::bigint,
  'anon selecting stories returns 0 rows'
);

select * from finish();
rollback;
