-- M11a origin stories. One transaction, rolled back.
-- Asserts follow Design Doc "M11a Tests" and Impl Spec §15.

begin;
create extension if not exists pgtap with schema extensions;

select plan(57);

create temporary table m11_ctx (
  user_a uuid primary key,
  user_b uuid not null,
  user_c uuid not null,
  user_d uuid not null,
  user_e uuid not null,
  user_f uuid not null,
  user_g uuid not null,
  parent_id uuid,
  child_id uuid,
  child2_id uuid,
  other_id uuid,
  s1 uuid,
  s2 uuid,
  s3 uuid,
  draft_id uuid,
  other_story uuid,
  place_id uuid,
  person_id uuid
);

grant all on table m11_ctx to authenticated, anon, service_role;

insert into m11_ctx (user_a, user_b, user_c, user_d, user_e, user_f, user_g)
values (
  'a11a0000-0000-4000-8000-0000000000a1',
  'b11b0000-0000-4000-8000-0000000000b1',
  'c11c0000-0000-4000-8000-0000000000c1',
  'd11d0000-0000-4000-8000-0000000000d1',
  'e11e0000-0000-4000-8000-0000000000e1',
  'f11f0000-0000-4000-8000-0000000000f1',
  '61161111-0000-4000-8000-000000000061'
);

insert into auth.users (id, email, raw_user_meta_data)
select user_a, 'm11-a@test.local', '{"display_name":"M11 A"}'::jsonb from m11_ctx
union all
select user_b, 'm11-b@test.local', '{"display_name":"M11 B"}'::jsonb from m11_ctx
union all
select user_c, 'm11-c@test.local', '{"display_name":"M11 C"}'::jsonb from m11_ctx
union all
select user_d, 'm11-d@test.local', '{"display_name":"M11 D"}'::jsonb from m11_ctx
union all
select user_e, 'm11-e@test.local', '{"display_name":"M11 E"}'::jsonb from m11_ctx
union all
select user_f, 'm11-f@test.local', '{"display_name":"M11 F"}'::jsonb from m11_ctx
union all
select user_g, 'm11-g@test.local', '{"display_name":"M11 G"}'::jsonb from m11_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

update m11_ctx set parent_id = (public.create_family('Parent')).id;

set local request.jwt.claim.sub = '61161111-0000-4000-8000-000000000061';

update m11_ctx set other_id = (public.create_family('Other')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

with inserted as (
  insert into public.families (name, created_by, parent_family_id)
  select 'Ada', user_c, parent_id from m11_ctx
  returning id
)
update m11_ctx set child_id = inserted.id from inserted;

with inserted as (
  insert into public.families (name, created_by, parent_family_id)
  select 'Bea', user_f, parent_id from m11_ctx
  returning id
)
update m11_ctx set child2_id = inserted.id from inserted;

insert into public.memberships (family_id, user_id, role)
select child_id, user_c, 'owner'::public.membership_role from m11_ctx
union all
select child_id, user_b, 'member'::public.membership_role from m11_ctx
union all
select child_id, user_d, 'member'::public.membership_role from m11_ctx
union all
select child2_id, user_f, 'owner'::public.membership_role from m11_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';
set local request.jwt.claim.role = 'authenticated';

select public.add_co_owner(
  (select child_id from m11_ctx),
  (select user_d from m11_ctx)
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

update m11_ctx set
  s1 = '11111111-11a1-4111-8111-111111111111',
  s2 = '22222222-11a1-4111-8111-222222222222',
  s3 = '33333333-11a1-4111-8111-333333333333',
  draft_id = '44444444-11a1-4111-8111-444444444444',
  other_story = '55555555-11a1-4111-8111-555555555555',
  place_id = '66666666-11a1-4111-8111-666666666666',
  person_id = '77777777-11a1-4111-8111-777777777777';

insert into public.places (id, family_id, label, address, lat, lng)
select place_id, parent_id, 'Draft porch', '1 Draft Lane', 1, 2 from m11_ctx;

insert into public.stories (
  id, family_id, author_id, title, timeframe_start, status
)
select s1, parent_id, user_a, 'First', '1980-01-01'::date, 'published'::public.story_status from m11_ctx
union all
select s2, parent_id, user_a, 'Second', '1981-01-01'::date, 'published'::public.story_status from m11_ctx
union all
select s3, parent_id, user_a, 'Third', '1982-01-01'::date, 'published'::public.story_status from m11_ctx
union all
select draft_id, parent_id, user_a, 'Draft', '1983-01-01'::date, 'draft'::public.story_status from m11_ctx
union all
select other_story, other_id, user_g, 'Elsewhere', '1984-01-01'::date, 'published'::public.story_status from m11_ctx;

update public.stories s
set place_id = c.place_id
from m11_ctx c
where s.id = c.draft_id;

insert into public.people (id, family_id, name, relationship, created_by)
select person_id, parent_id, 'Draft Kin', 'kin', user_a from m11_ctx;

insert into public.story_people (story_id, person_id)
select draft_id, person_id from m11_ctx;

-- 1. Child owner sets the parent's published story.
set local role authenticated;
set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';
set local request.jwt.claim.role = 'authenticated';

select lives_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    (select s1 from m11_ctx)
  )$$,
  'child owner sets a published parent story as origin'
);

-- 2. Co-owner changes it to another published parent story.
set local request.jwt.claim.sub = 'd11d0000-0000-4000-8000-0000000000d1';

select lives_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    (select s2 from m11_ctx)
  )$$,
  'child co-owner changes the origin'
);

-- 3. A member cannot set the origin.
set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b1';

select throws_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    (select s1 from m11_ctx)
  )$$,
  'P0001',
  'FORBIDDEN',
  'a child member cannot set the origin'
);

-- 4. A user with no membership cannot set the origin.
set local request.jwt.claim.sub = 'e11e0000-0000-4000-8000-0000000000e1';

select throws_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    (select s1 from m11_ctx)
  )$$,
  'P0001',
  'FORBIDDEN',
  'a user with no membership cannot set the origin'
);

-- 5. A missing sign-in cannot set the origin.
select set_config('request.jwt.claim.sub', '', true);

select throws_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    (select s1 from m11_ctx)
  )$$,
  'P0001',
  'FORBIDDEN',
  'a missing sign-in cannot set the origin'
);

select set_config(
  'request.jwt.claim.sub',
  'c11c0000-0000-4000-8000-0000000000c1',
  true
);

-- 6. A draft cannot be an origin.
select throws_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    (select draft_id from m11_ctx)
  )$$,
  'P0001',
  'NOT_FOUND',
  'a draft cannot be an origin'
);

-- 7. A story from another family cannot origin a child.
select throws_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    (select other_story from m11_ctx)
  )$$,
  'P0001',
  'NOT_FOUND',
  'a child origin must be in the parent family'
);

-- 8. A root cannot take another family's story.
set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';

select throws_ok(
  $$select public.set_family_origin(
    (select parent_id from m11_ctx),
    (select other_story from m11_ctx)
  )$$,
  'P0001',
  'NOT_FOUND',
  'a root origin must be in this family'
);

-- 9. A soft-deleted parent blocks the set. Restore before later asserts.
select public.soft_delete_family((select parent_id from m11_ctx));

set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';

select throws_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    (select s1 from m11_ctx)
  )$$,
  'P0001',
  'VALIDATION: parent family is deleted',
  'a deleted parent family cannot supply an origin'
);

set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';
select public.recover_family((select parent_id from m11_ctx));

-- 10. The root owner sets the root's own published story.
select lives_ok(
  $$select public.set_family_origin(
    (select parent_id from m11_ctx),
    (select s1 from m11_ctx)
  )$$,
  'root owner sets a published story in this family'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  public.family_origin((select parent_id from m11_ctx)),
  (select s1 from m11_ctx),
  'family_origin returns the root origin'
);

-- 11. The child owner sets the same parent story.
set local role authenticated;
set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';
set local request.jwt.claim.role = 'authenticated';

select lives_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    (select s1 from m11_ctx)
  )$$,
  'child owner sets the parent story again'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  public.family_origin((select child_id from m11_ctx)),
  (select s1 from m11_ctx),
  'family_origin returns the child origin'
);

-- 12. A second child of the same parent uses the same story.
set local role authenticated;
set local request.jwt.claim.sub = 'f11f0000-0000-4000-8000-0000000000f1';
set local request.jwt.claim.role = 'authenticated';

select lives_ok(
  $$select public.set_family_origin(
    (select child2_id from m11_ctx),
    (select s1 from m11_ctx)
  )$$,
  'a second child sets the same origin story'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  public.family_origin((select child_id from m11_ctx)),
  (select s1 from m11_ctx),
  'the first child still origins the shared story'
);
select is(
  public.family_origin((select child2_id from m11_ctx)),
  (select s1 from m11_ctx),
  'the second child origins the same story'
);

-- 13. The flag is off, so a direct write still throws in this transaction.
set local role authenticated;
set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';
set local request.jwt.claim.role = 'authenticated';

select throws_ok(
  $$
    update public.families
    set origin_story_id = '88888888-11a1-4111-8111-888888888888'
    where id = (select child_id from m11_ctx)
  $$,
  'P0001',
  'FORBIDDEN: field is locked',
  'a direct origin_story_id update is locked'
);

select throws_ok(
  $$
    update public.families
    set origin_story_id = null
    where id = (select child_id from m11_ctx)
  $$,
  'P0001',
  'FORBIDDEN: field is locked',
  'a direct clear is locked while the story still exists'
);

-- 14. Soft-deleting the parent hides the origin. Recovering brings it back.
set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';
select public.soft_delete_family((select parent_id from m11_ctx));

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  public.family_origin((select child_id from m11_ctx)),
  null,
  'a soft-deleted parent hides the child origin'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';
select public.recover_family((select parent_id from m11_ctx));

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  public.family_origin((select child_id from m11_ctx)),
  (select s1 from m11_ctx),
  'recovering the parent restores the child origin'
);

-- 15. An unpublished origin reads as unset. Publishing it restores the read.
set local role authenticated;
set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

update public.stories
set status = 'draft'
where id = (select s1 from m11_ctx);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  public.family_origin((select child_id from m11_ctx)),
  null,
  'an unpublished origin reads as unset'
);

-- The story row is still there, so a child owner cannot clear the stored id.
set local role authenticated;
set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';
set local request.jwt.claim.role = 'authenticated';

select throws_ok(
  $$
    update public.families
    set origin_story_id = null
    where id = (select child_id from m11_ctx)
  $$,
  'P0001',
  'FORBIDDEN: field is locked',
  'a child owner cannot clear the origin after it is drafted'
);

set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';
select public.soft_delete_family((select parent_id from m11_ctx));

set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';

select throws_ok(
  $$
    update public.families
    set origin_story_id = null
    where id = (select child_id from m11_ctx)
  $$,
  'P0001',
  'FORBIDDEN: field is locked',
  'a child owner cannot clear the origin while the parent is soft-deleted'
);

set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';
select public.recover_family((select parent_id from m11_ctx));

set local role authenticated;
set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

update public.stories
set status = 'published'
where id = (select s1 from m11_ctx);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  public.family_origin((select child_id from m11_ctx)),
  (select s1 from m11_ctx),
  'publishing the origin restores the read'
);

-- 16. Deleting the story clears the stored id.
set local role authenticated;
set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

delete from public.stories where id = (select s1 from m11_ctx);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  public.family_origin((select child_id from m11_ctx)),
  null,
  'deleting the origin story unsets family_origin'
);
select is(
  (select origin_story_id from public.families where id = (select child_id from m11_ctx)),
  null,
  'deleting the origin story clears origin_story_id'
);

-- The deleted story can no longer be the origin. Use the surviving one.
set local role authenticated;
set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';
set local request.jwt.claim.role = 'authenticated';

select lives_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    (select s2 from m11_ctx)
  )$$,
  'child owner sets the surviving published story'
);

-- 17. A child member can write on the origin story.
set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b1';

select lives_ok(
  $$
    insert into public.comments (story_id, family_id, author_id, body)
    select s2, parent_id, user_b, 'from the child' from m11_ctx
  $$,
  'a child member comments on the origin story'
);
select lives_ok(
  $$
    insert into public.perspectives (story_id, family_id, author_id, body)
    select s2, parent_id, user_b, 'a child perspective' from m11_ctx
  $$,
  'a child member adds a perspective on the origin story'
);
select lives_ok(
  $$
    insert into public.photos (story_id, family_id, uploader_id, storage_path)
    select s2, parent_id, user_b, parent_id::text || '/' || s2::text || '/child.jpg'
    from m11_ctx
  $$,
  'a child member adds a photo row on the origin story'
);
select lives_ok(
  $$
    insert into storage.objects (bucket_id, name, owner_id)
    select
      'story-photos',
      parent_id::text || '/' || s2::text || '/child.jpg',
      user_b::text
    from m11_ctx
  $$,
  'a child member uploads a storage object on the origin story'
);

-- 18. The same member cannot write on a different parent story. An outsider cannot either.
select throws_ok(
  $$
    insert into public.comments (story_id, family_id, author_id, body)
    select s3, parent_id, user_b, 'not this one' from m11_ctx
  $$,
  '42501',
  'new row violates row-level security policy for table "comments"',
  'a child member cannot comment on a different parent story'
);

set local request.jwt.claim.sub = 'e11e0000-0000-4000-8000-0000000000e1';

select throws_ok(
  $$
    insert into public.comments (story_id, family_id, author_id, body)
    select s2, parent_id, user_e, 'outside' from m11_ctx
  $$,
  '42501',
  'new row violates row-level security policy for table "comments"',
  'an outsider cannot comment on the origin story'
);

-- 18b. A child member cannot delete a parent member's storage object.
reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into storage.objects (bucket_id, name, owner_id)
select
  'story-photos',
  parent_id::text || '/' || s2::text || '/parent.jpg',
  user_a::text
from m11_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b1';
set local request.jwt.claim.role = 'authenticated';

update storage.objects
set metadata = '{"touched": true}'::jsonb
where bucket_id = 'story-photos'
  and name = (
    select parent_id::text || '/' || s2::text || '/parent.jpg' from m11_ctx
  );

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'story-photos'
      and name = (
        select parent_id::text || '/' || s2::text || '/parent.jpg' from m11_ctx
      )
      and metadata = '{"touched": true}'::jsonb
  ),
  0::bigint,
  'a child member storage update on a parent member file changes 0 rows'
);

set local role authenticated;
set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b1';
set local request.jwt.claim.role = 'authenticated';
-- storage.protect_delete blocks every direct delete until this flag is on.
-- The flag lets the statement reach RLS.
select set_config('storage.allow_delete_query', 'true', true);

delete from storage.objects
where bucket_id = 'story-photos'
  and name = (
    select parent_id::text || '/' || s2::text || '/parent.jpg' from m11_ctx
  );

select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'story-photos'
      and name = (
        select parent_id::text || '/' || s2::text || '/parent.jpg' from m11_ctx
      )
  ),
  1::bigint,
  'a child member cannot delete a parent member storage file'
);

delete from storage.objects
where bucket_id = 'story-photos'
  and name = (
    select parent_id::text || '/' || s2::text || '/child.jpg' from m11_ctx
  );

select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'story-photos'
      and name = (
        select parent_id::text || '/' || s2::text || '/child.jpg' from m11_ctx
      )
  ),
  0::bigint,
  'a child member can delete the storage file they uploaded'
);

-- 19. After the origin moves, the old story is closed and the new one is open.
set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';

select public.set_family_origin(
  (select child_id from m11_ctx),
  (select s3 from m11_ctx)
);

set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b1';

select throws_ok(
  $$
    insert into public.comments (story_id, family_id, author_id, body)
    select s2, parent_id, user_b, 'too late' from m11_ctx
  $$,
  '42501',
  'new row violates row-level security policy for table "comments"',
  'a child member cannot comment after the origin moves'
);

select lives_ok(
  $$
    insert into public.comments (story_id, family_id, author_id, body)
    select s3, parent_id, user_b, 'on the new origin' from m11_ctx
  $$,
  'a child member comments on the new origin'
);

-- 20. Dependents are visible to a member of the story's family only.
set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';

select results_eq(
  $$
    select family_id, name
    from public.list_origin_dependents((select s3 from m11_ctx))
    order by name
  $$,
  $$select child_id, 'Ada'::text from m11_ctx$$,
  'a parent member lists the child that origins this story'
);

set local request.jwt.claim.sub = 'e11e0000-0000-4000-8000-0000000000e1';

select is_empty(
  $$select * from public.list_origin_dependents((select s3 from m11_ctx))$$,
  'a user outside the story family sees no dependents'
);

-- 21. A draft-only place stays hidden from a tree reader.
-- M14: a person who lives in the tree is visible to a tree member, even when
-- the only story tag is a draft. Outside-tree readers still get zero rows.
set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b1';

select is(
  (select count(*) from public.places where id = (select place_id from m11_ctx)),
  0::bigint,
  'a tree reader does not see a draft-only place'
);
select is(
  (select count(*) from public.people_tree_read where id = (select person_id from m11_ctx)),
  1::bigint,
  'a tree reader sees a person who lives in the tree'
);

set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';

select is(
  (select count(*) from public.places where id = (select place_id from m11_ctx)),
  1::bigint,
  'a member still sees a draft-only place'
);
select is(
  (select count(*) from public.people_tree_read where id = (select person_id from m11_ctx)),
  1::bigint,
  'a member still sees a draft-only person'
);

-- 22-24. Grants.
reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  has_function_privilege('anon', 'public.family_origin(uuid)', 'execute'),
  false,
  'anon cannot execute family_origin'
);
select is(
  has_function_privilege('anon', 'public.can_contribute_to_story(uuid, uuid)', 'execute'),
  false,
  'anon cannot execute can_contribute_to_story'
);
select is(
  has_function_privilege('anon', 'public.set_family_origin(uuid, uuid)', 'execute'),
  false,
  'anon cannot execute set_family_origin'
);
select is(
  has_function_privilege('anon', 'public.list_origin_dependents(uuid)', 'execute'),
  false,
  'anon cannot execute list_origin_dependents'
);
select is(
  has_function_privilege('anon', 'public.list_family_tree(uuid)', 'execute'),
  false,
  'anon cannot execute list_family_tree'
);
select is(
  has_function_privilege('authenticated', 'public.family_origin(uuid)', 'execute'),
  false,
  'authenticated cannot execute family_origin'
);
select is(
  has_function_privilege('authenticated', 'public.can_contribute_to_story(uuid, uuid)', 'execute'),
  true,
  'authenticated can execute can_contribute_to_story'
);
select is(
  has_function_privilege('anon', 'public.family_origin(uuid)', 'execute'),
  false,
  'anon stays unable to execute family_origin'
);
select is(
  has_function_privilege('anon', 'public.can_contribute_to_story(uuid, uuid)', 'execute'),
  false,
  'anon stays unable to execute can_contribute_to_story'
);
select is(
  has_function_privilege('authenticated', 'public.set_family_origin(uuid, uuid)', 'execute'),
  true,
  'authenticated can execute set_family_origin'
);
select is(
  has_function_privilege('authenticated', 'public.list_origin_dependents(uuid)', 'execute'),
  true,
  'authenticated can execute list_origin_dependents'
);
select is(
  has_function_privilege('authenticated', 'public.list_family_tree(uuid)', 'execute'),
  true,
  'authenticated can execute list_family_tree'
);

-- 25.
select is(
  (select count(*) from pg_policies where schemaname in ('public', 'storage')),
  47::bigint,
  'policy count is 47'
);

select * from finish();
rollback;
