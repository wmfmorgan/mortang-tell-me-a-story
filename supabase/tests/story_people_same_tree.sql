-- M14.6 #51: a story can link a person from anywhere in the same live tree.

begin;
create extension if not exists pgtap with schema extensions;

select plan(14);

create temporary table m51_ctx (
  owner_id uuid primary key,
  editor_id uuid not null,
  outsider_id uuid not null,
  root_id uuid,
  child_id uuid,
  gone_sib_id uuid,
  other_root_id uuid,
  dead_parent_id uuid,
  orphan_child_id uuid,
  root_person uuid,
  child_person uuid,
  child_person2 uuid,
  gone_person uuid,
  other_person uuid,
  dead_parent_person uuid,
  child_story uuid,
  orphan_story_id uuid
);

grant all on table m51_ctx to authenticated, anon, service_role;

insert into m51_ctx (
  owner_id, editor_id, outsider_id,
  root_person, child_person, child_person2, gone_person, other_person, dead_parent_person,
  child_story, orphan_story_id
)
values (
  'a5100000-0000-4000-8000-0000000000a1',
  'a5100000-0000-4000-8000-0000000000a2',
  'a5100000-0000-4000-8000-0000000000a3',
  'a5100000-0000-4000-8000-0000000000b1',
  'a5100000-0000-4000-8000-0000000000b2',
  'a5100000-0000-4000-8000-0000000000b3',
  'a5100000-0000-4000-8000-0000000000b4',
  'a5100000-0000-4000-8000-0000000000b5',
  'a5100000-0000-4000-8000-0000000000b6',
  'a5100000-0000-4000-8000-0000000000c1',
  'a5100000-0000-4000-8000-0000000000c2'
);

insert into auth.users (id, email, raw_user_meta_data)
select owner_id, 'm51-owner@test.local', '{"display_name":"Owner"}'::jsonb from m51_ctx
union all
select editor_id, 'm51-editor@test.local', '{"display_name":"Editor"}'::jsonb from m51_ctx
union all
select outsider_id, 'm51-outsider@test.local', '{"display_name":"Outsider"}'::jsonb from m51_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a5100000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

update m51_ctx set root_id = (public.create_family('Root')).id;
update m51_ctx set other_root_id = (public.create_family('Other')).id;
update m51_ctx set dead_parent_id = (public.create_family('Dead parent')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

with inserted as (
  insert into public.families (name, created_by, parent_family_id)
  select 'Child', owner_id, root_id from m51_ctx
  returning id
)
update m51_ctx set child_id = inserted.id from inserted;

with inserted as (
  insert into public.families (name, created_by, parent_family_id)
  select 'Gone sibling', owner_id, root_id from m51_ctx
  returning id
)
update m51_ctx set gone_sib_id = inserted.id from inserted;

with inserted as (
  insert into public.families (name, created_by, parent_family_id)
  select 'Orphan child', owner_id, dead_parent_id from m51_ctx
  returning id
)
update m51_ctx set orphan_child_id = inserted.id from inserted;

insert into public.memberships (family_id, user_id, role)
select child_id, editor_id, 'member'::public.membership_role from m51_ctx
union all
select other_root_id, editor_id, 'member'::public.membership_role from m51_ctx
union all
select orphan_child_id, editor_id, 'member'::public.membership_role from m51_ctx;

insert into public.people (id, family_id, name, relationship, created_by)
select root_person, root_id, 'Root person', 'kin', owner_id from m51_ctx
union all
select child_person, child_id, 'Child person', 'kin', editor_id from m51_ctx
union all
select child_person2, child_id, 'Child person two', 'kin', editor_id from m51_ctx
union all
select gone_person, gone_sib_id, 'Gone person', 'kin', owner_id from m51_ctx
union all
select other_person, other_root_id, 'Other person', 'kin', owner_id from m51_ctx
union all
select dead_parent_person, dead_parent_id, 'Dead parent person', 'kin', owner_id from m51_ctx;

insert into public.stories (
  id, family_id, author_id, title, timeframe_start, status
)
select child_story, child_id, editor_id, 'Child story',
       '2010-01-01'::date, 'published'::public.story_status
from m51_ctx
union all
select orphan_story_id, orphan_child_id, editor_id, 'Orphan story',
       '2011-01-01'::date, 'published'::public.story_status
from m51_ctx;

insert into public.story_people (story_id, person_id)
select child_story, child_person from m51_ctx;

update public.families
set deleted_at = now()
where id = (select gone_sib_id from m51_ctx)
   or id = (select dead_parent_id from m51_ctx);

set local role authenticated;
set local request.jwt.claim.sub = 'a5100000-0000-4000-8000-0000000000a2';
set local request.jwt.claim.role = 'authenticated';

select ok(
  public.is_tree_member((select child_id from m51_ctx))
    and public.is_tree_member((select other_root_id from m51_ctx)),
  'the caller is a live member of both trees (#51 cases 3 and 6)'
);

select lives_ok(
  $$insert into public.story_people (story_id, person_id)
    select child_story, root_person from m51_ctx$$,
  'a child-timeline story links a parent-timeline person (#51 case 1)'
);

select lives_ok(
  $$insert into public.story_people (story_id, person_id)
    select child_story, child_person2 from m51_ctx$$,
  'a same-timeline person link still passes (#51 case 2)'
);

select throws_ok(
  $$insert into public.story_people (story_id, person_id)
    select child_story, other_person from m51_ctx$$,
  '42501',
  'new row violates row-level security policy for table "story_people"',
  'an unrelated-tree person is refused when the caller is a member of both trees (#51 case 3)'
);

select throws_ok(
  $$insert into public.story_people (story_id, person_id)
    select child_story, gone_person from m51_ctx$$,
  '42501',
  'new row violates row-level security policy for table "story_people"',
  'a person in a soft-deleted family is refused (#51 case 4)'
);

select throws_ok(
  $$insert into public.story_people (story_id, person_id)
    select orphan_story_id, dead_parent_person from m51_ctx$$,
  '42501',
  'new row violates row-level security policy for table "story_people"',
  'a child timeline whose parent is soft-deleted refuses a person in that parent (#51 case 5)'
);

select throws_ok(
  $$update public.story_people set person_id = (select other_person from m51_ctx)
    where story_id = (select child_story from m51_ctx)
      and person_id = (select child_person from m51_ctx)$$,
  '42501',
  null,
  'moving an existing link to an unrelated-tree person is refused (#51 case 6)'
);

select is(
  public.same_family_tree(
    (select child_id from m51_ctx),
    (select root_id from m51_ctx)
  ),
  true,
  'same_family_tree is true for a child and its live root when the caller is in the tree (TMAS-53-01)'
);
select is(
  public.same_family_tree(
    (select child_id from m51_ctx),
    (select gone_sib_id from m51_ctx)
  ),
  false,
  'same_family_tree is false for a soft-deleted sibling (TMAS-53-01)'
);
select is(
  public.same_family_tree(
    (select orphan_child_id from m51_ctx),
    (select dead_parent_id from m51_ctx)
  ),
  false,
  'same_family_tree is false for an orphan child and its soft-deleted parent (TMAS-53-01)'
);

set local request.jwt.claim.sub = 'a5100000-0000-4000-8000-0000000000a3';

select is(
  public.same_family_tree(
    (select child_id from m51_ctx),
    (select root_id from m51_ctx)
  ),
  false,
  'same_family_tree is false for an outsider with no memberships (TMAS-53-01)'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select ok(
  not has_function_privilege('anon', 'public.same_family_tree(uuid, uuid)', 'execute'),
  'anon cannot execute same_family_tree'
);
select ok(
  has_function_privilege('authenticated', 'public.same_family_tree(uuid, uuid)', 'execute'),
  'authenticated can execute same_family_tree'
);
select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'same_family_tree'
      and p.prosecdef
      and 'search_path=""' = any (p.proconfig)
  ),
  'same_family_tree is security definer with search_path=""'
);

select * from finish();
rollback;
