-- M11a.2 origin stories hardening. One transaction, rolled back.

begin;
create extension if not exists pgtap with schema extensions;


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

select plan(99);

-- Ada's origin is the parent's second published story.
set local role authenticated;
set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';
set local request.jwt.claim.role = 'authenticated';

select lives_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    (select s2 from m11_ctx)
  )$$,
  'setup sets Ada origin to s2'
);

-- M11A-02. A member is FORBIDDEN before the story is judged.
set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b1';

select throws_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    '99999999-11a1-4111-8111-999999999999'
  )$$,
  'P0001',
  'FORBIDDEN',
  'a member gets FORBIDDEN before NOT_FOUND for a missing story'
);

select throws_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    (select draft_id from m11_ctx)
  )$$,
  'P0001',
  'FORBIDDEN',
  'a member gets FORBIDDEN before NOT_FOUND for a draft'
);

select throws_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    (select other_story from m11_ctx)
  )$$,
  'P0001',
  'FORBIDDEN',
  'a member gets FORBIDDEN before NOT_FOUND for a story in another family'
);

set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';

select throws_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    '99999999-11a1-4111-8111-999999999999'
  )$$,
  'P0001',
  'NOT_FOUND',
  'an owner gets NOT_FOUND for a missing story'
);

-- A deleted parent wins over a missing story id.
set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';
select public.soft_delete_family((select parent_id from m11_ctx));

set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';

select throws_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    '99999999-11a1-4111-8111-999999999999'
  )$$,
  'P0001',
  'VALIDATION: parent family is deleted',
  'a deleted parent wins over a missing story'
);

set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';
select public.recover_family((select parent_id from m11_ctx));

-- M11A-01. Whitelist. User A can contribute to s1 and s2.
insert into public.comments (id, story_id, family_id, author_id, body)
select
  'c0c0c0c0-11a2-4111-8111-c0c0c0c0c0c0',
  s1, parent_id, user_a, 'guard comment'
from m11_ctx;

insert into public.perspectives (id, story_id, family_id, author_id, body)
select
  'd0d0d0d0-11a2-4111-8111-d0d0d0d0d0d0',
  s1, parent_id, user_a, 'guard perspective'
from m11_ctx;

insert into public.photos (id, story_id, family_id, uploader_id, storage_path, sort_order)
select
  'e0e0e0e0-11a2-4111-8111-e0e0e0e0e0e0',
  s1, parent_id, user_a,
  parent_id::text || '/' || s1::text || '/guard.jpg',
  0
from m11_ctx;

select lives_ok(
  $$update public.comments
    set body = 'edited', updated_at = now()
    where id = 'c0c0c0c0-11a2-4111-8111-c0c0c0c0c0c0'$$,
  'a comment body and updated_at can change'
);

select lives_ok(
  $$update public.perspectives
    set body = 'edited', updated_at = now()
    where id = 'd0d0d0d0-11a2-4111-8111-d0d0d0d0d0d0'$$,
  'a perspective body and updated_at can change'
);

select lives_ok(
  $$update public.comments
    set updated_at = now()
    where id = 'c0c0c0c0-11a2-4111-8111-c0c0c0c0c0c0'$$,
  'a comment update that changes only updated_at is allowed'
);

select lives_ok(
  $$update public.perspectives
    set updated_at = now()
    where id = 'd0d0d0d0-11a2-4111-8111-d0d0d0d0d0d0'$$,
  'a perspective update that changes only updated_at is allowed'
);

select lives_ok(
  $$update public.photos
    set sort_order = 3
    where id = 'e0e0e0e0-11a2-4111-8111-e0e0e0e0e0e0'$$,
  'a photo sort_order can change'
);

select throws_ok(
  $$update public.comments
    set id = 'c1c1c1c1-11a2-4111-8111-c1c1c1c1c1c1'
    where id = 'c0c0c0c0-11a2-4111-8111-c0c0c0c0c0c0'$$,
  'P0001', 'FORBIDDEN: field is locked',
  'comment id is locked'
);
select throws_ok(
  $$update public.comments
    set story_id = (select s2 from m11_ctx)
    where id = 'c0c0c0c0-11a2-4111-8111-c0c0c0c0c0c0'$$,
  'P0001', 'FORBIDDEN: field is locked',
  'a comment cannot move to another story the author can contribute to'
);
select throws_ok(
  $$update public.comments
    set family_id = (select other_id from m11_ctx)
    where id = 'c0c0c0c0-11a2-4111-8111-c0c0c0c0c0c0'$$,
  'P0001', 'FORBIDDEN: field is locked',
  'comment family_id is locked'
);
select throws_ok(
  $$update public.comments
    set author_id = (select user_b from m11_ctx)
    where id = 'c0c0c0c0-11a2-4111-8111-c0c0c0c0c0c0'$$,
  'P0001', 'FORBIDDEN: field is locked',
  'comment author_id is locked'
);
select throws_ok(
  $$update public.comments
    set created_at = '1999-01-01 00:00:00+00'
    where id = 'c0c0c0c0-11a2-4111-8111-c0c0c0c0c0c0'$$,
  'P0001', 'FORBIDDEN: field is locked',
  'comment created_at is locked'
);

select throws_ok(
  $$update public.perspectives
    set id = 'd1d1d1d1-11a2-4111-8111-d1d1d1d1d1d1'
    where id = 'd0d0d0d0-11a2-4111-8111-d0d0d0d0d0d0'$$,
  'P0001', 'FORBIDDEN: field is locked',
  'perspective id is locked'
);
select throws_ok(
  $$update public.perspectives
    set story_id = (select s2 from m11_ctx)
    where id = 'd0d0d0d0-11a2-4111-8111-d0d0d0d0d0d0'$$,
  'P0001', 'FORBIDDEN: field is locked',
  'a perspective cannot move to another story the author can contribute to'
);
select throws_ok(
  $$update public.perspectives
    set family_id = (select other_id from m11_ctx)
    where id = 'd0d0d0d0-11a2-4111-8111-d0d0d0d0d0d0'$$,
  'P0001', 'FORBIDDEN: field is locked',
  'perspective family_id is locked'
);
select throws_ok(
  $$update public.perspectives
    set author_id = (select user_b from m11_ctx)
    where id = 'd0d0d0d0-11a2-4111-8111-d0d0d0d0d0d0'$$,
  'P0001', 'FORBIDDEN: field is locked',
  'perspective author_id is locked'
);
select throws_ok(
  $$update public.perspectives
    set created_at = '1999-01-01 00:00:00+00'
    where id = 'd0d0d0d0-11a2-4111-8111-d0d0d0d0d0d0'$$,
  'P0001', 'FORBIDDEN: field is locked',
  'perspective created_at is locked'
);

select throws_ok(
  $$update public.photos
    set id = 'e1e1e1e1-11a2-4111-8111-e1e1e1e1e1e1'
    where id = 'e0e0e0e0-11a2-4111-8111-e0e0e0e0e0e0'$$,
  'P0001', 'FORBIDDEN: field is locked',
  'photo id is locked'
);
select throws_ok(
  $$update public.photos
    set story_id = (select s2 from m11_ctx)
    where id = 'e0e0e0e0-11a2-4111-8111-e0e0e0e0e0e0'$$,
  'P0001', 'FORBIDDEN: field is locked',
  'a photo cannot move to another story the author can contribute to'
);
select throws_ok(
  $$update public.photos
    set family_id = (select other_id from m11_ctx)
    where id = 'e0e0e0e0-11a2-4111-8111-e0e0e0e0e0e0'$$,
  'P0001', 'FORBIDDEN: field is locked',
  'photo family_id is locked'
);
select throws_ok(
  $$update public.photos
    set uploader_id = (select user_b from m11_ctx)
    where id = 'e0e0e0e0-11a2-4111-8111-e0e0e0e0e0e0'$$,
  'P0001', 'FORBIDDEN: field is locked',
  'photo uploader_id is locked'
);
select throws_ok(
  $$update public.photos
    set storage_path = (select parent_id::text || '/' || s2::text || '/moved.jpg' from m11_ctx)
    where id = 'e0e0e0e0-11a2-4111-8111-e0e0e0e0e0e0'$$,
  'P0001', 'FORBIDDEN: field is locked',
  'photo storage_path is locked'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
set local role service_role;

select throws_ok(
  $$update public.comments
    set story_id = (select s2 from m11_ctx)
    where id = 'c0c0c0c0-11a2-4111-8111-c0c0c0c0c0c0'$$,
  'P0001', 'FORBIDDEN: field is locked',
  'service_role cannot change a locked comment column'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
set local role authenticated;
set local request.jwt.claim.role = 'authenticated';

-- Different parent story. Origin is still s2.
set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b1';

select throws_ok(
  $$insert into public.perspectives (story_id, family_id, author_id, body)
    select s3, parent_id, user_b, 'not this one' from m11_ctx$$,
  '42501',
  'new row violates row-level security policy for table "perspectives"',
  'a child member cannot add a perspective on a different parent story'
);
select throws_ok(
  $$insert into public.photos (story_id, family_id, uploader_id, storage_path)
    select s3, parent_id, user_b, parent_id::text || '/' || s3::text || '/nope.jpg'
    from m11_ctx$$,
  '42501',
  'new row violates row-level security policy for table "photos"',
  'a child member cannot add a photo on a different parent story'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    select 'story-photos', parent_id::text || '/' || s3::text || '/nope.jpg', user_b::text
    from m11_ctx$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'a child member cannot upload storage on a different parent story'
);

set local request.jwt.claim.sub = 'f11f0000-0000-4000-8000-0000000000f1';

select throws_ok(
  $$insert into public.comments (story_id, family_id, author_id, body)
    select s2, parent_id, user_f, 'sibling' from m11_ctx$$,
  '42501',
  'new row violates row-level security policy for table "comments"',
  'a tree member outside the child family cannot comment on the origin'
);

set local request.jwt.claim.sub = 'e11e0000-0000-4000-8000-0000000000e1';

select throws_ok(
  $$insert into public.perspectives (story_id, family_id, author_id, body)
    select s2, parent_id, user_e, 'outside' from m11_ctx$$,
  '42501',
  'new row violates row-level security policy for table "perspectives"',
  'an outsider cannot add a perspective on the origin story'
);
select throws_ok(
  $$insert into public.photos (story_id, family_id, uploader_id, storage_path)
    select s2, parent_id, user_e, parent_id::text || '/' || s2::text || '/out.jpg'
    from m11_ctx$$,
  '42501',
  'new row violates row-level security policy for table "photos"',
  'an outsider cannot add a photo on the origin story'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    select 'story-photos', parent_id::text || '/' || s2::text || '/out.jpg', user_e::text
    from m11_ctx$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'an outsider cannot upload storage on the origin story'
);

-- Soft-deleted child.
set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';
select public.soft_delete_family((select child_id from m11_ctx));
set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b1';

select throws_ok(
  $$insert into public.comments (story_id, family_id, author_id, body)
    select s2, parent_id, user_b, 'deleted child' from m11_ctx$$,
  '42501',
  'new row violates row-level security policy for table "comments"',
  'a member of a soft-deleted child family cannot comment'
);

set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';
select public.recover_family((select child_id from m11_ctx));

-- Unpublished origin.
set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';
update public.stories
set status = 'draft'::public.story_status
where id = (select s2 from m11_ctx);

set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b1';

select throws_ok(
  $$insert into public.comments (story_id, family_id, author_id, body)
    select s2, parent_id, user_b, 'unpublished' from m11_ctx$$,
  '42501',
  'new row violates row-level security policy for table "comments"',
  'a child member cannot comment after the origin story is unpublished'
);

set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';
update public.stories
set status = 'published'::public.story_status
where id = (select s2 from m11_ctx);

-- Rows the child writes, then the origin moves.
set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b1';

insert into public.comments (id, story_id, family_id, author_id, body)
select 'b0b0b0b0-11a2-4111-8111-b0b0b0b0b0b0', s2, parent_id, user_b, 'child comment'
from m11_ctx;
insert into public.perspectives (id, story_id, family_id, author_id, body)
select 'b1b1b1b1-11a2-4111-8111-b1b1b1b1b1b1', s2, parent_id, user_b, 'child perspective'
from m11_ctx;
insert into public.photos (id, story_id, family_id, uploader_id, storage_path)
select 'b2b2b2b2-11a2-4111-8111-b2b2b2b2b2b2', s2, parent_id, user_b,
  parent_id::text || '/' || s2::text || '/child-row.jpg'
from m11_ctx;

set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';
select public.set_family_origin(
  (select child_id from m11_ctx),
  (select s3 from m11_ctx)
);

set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b1';

update public.comments set body = 'too late'
where id = 'b0b0b0b0-11a2-4111-8111-b0b0b0b0b0b0';
select is(
  (select body from public.comments where id = 'b0b0b0b0-11a2-4111-8111-b0b0b0b0b0b0'),
  'child comment',
  'a child member cannot edit a comment after the origin moves'
);
delete from public.comments where id = 'b0b0b0b0-11a2-4111-8111-b0b0b0b0b0b0';
select is(
  (select count(*) from public.comments where id = 'b0b0b0b0-11a2-4111-8111-b0b0b0b0b0b0'),
  1::bigint,
  'a child member cannot delete a comment after the origin moves'
);

update public.perspectives set body = 'too late'
where id = 'b1b1b1b1-11a2-4111-8111-b1b1b1b1b1b1';
select is(
  (select body from public.perspectives where id = 'b1b1b1b1-11a2-4111-8111-b1b1b1b1b1b1'),
  'child perspective',
  'a child member cannot edit a perspective after the origin moves'
);
delete from public.perspectives where id = 'b1b1b1b1-11a2-4111-8111-b1b1b1b1b1b1';
select is(
  (select count(*) from public.perspectives where id = 'b1b1b1b1-11a2-4111-8111-b1b1b1b1b1b1'),
  1::bigint,
  'a child member cannot delete a perspective after the origin moves'
);

update public.photos set sort_order = 9
where id = 'b2b2b2b2-11a2-4111-8111-b2b2b2b2b2b2';
select is(
  (select sort_order from public.photos where id = 'b2b2b2b2-11a2-4111-8111-b2b2b2b2b2b2'),
  0,
  'a child member cannot edit a photo after the origin moves'
);
delete from public.photos where id = 'b2b2b2b2-11a2-4111-8111-b2b2b2b2b2b2';
select is(
  (select count(*) from public.photos where id = 'b2b2b2b2-11a2-4111-8111-b2b2b2b2b2b2'),
  1::bigint,
  'a child member cannot delete a photo after the origin moves'
);

select throws_ok(
  $$insert into public.perspectives (story_id, family_id, author_id, body)
    select s2, parent_id, user_b, 'after move' from m11_ctx$$,
  '42501',
  'new row violates row-level security policy for table "perspectives"',
  'a child member cannot add a perspective after the origin moves'
);
select throws_ok(
  $$insert into public.photos (story_id, family_id, uploader_id, storage_path)
    select s2, parent_id, user_b, parent_id::text || '/' || s2::text || '/after.jpg'
    from m11_ctx$$,
  '42501',
  'new row violates row-level security policy for table "photos"',
  'a child member cannot add a photo after the origin moves'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    select 'story-photos', parent_id::text || '/' || s2::text || '/after.jpg', user_b::text
    from m11_ctx$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'a child member cannot upload storage after the origin moves'
);

-- Put the origin back for the abuse and cap checks.
set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';
select public.set_family_origin(
  (select child_id from m11_ctx),
  (select s2 from m11_ctx)
);

set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b1';

select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    select 'story-photos', parent_id::text || '/' || s3::text || '/abuse.jpg', user_b::text
    from m11_ctx$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'a child member cannot upload storage for a non-origin story'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    select 'story-photos', child_id::text || '/' || s2::text || '/abuse.jpg', user_b::text
    from m11_ctx$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'a child member cannot upload under the child family path'
);
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    select 'story-photos', parent_id::text || '/' || s2::text || '/child.jpg', user_b::text
    from m11_ctx$$,
  'a child member can upload storage on the origin story'
);

update public.stories set title = 'taken' where id = (select s2 from m11_ctx);
select is(
  (select title from public.stories where id = (select s2 from m11_ctx)),
  'Second',
  'a child contributor cannot update the origin story'
);

-- Photo cap on a fresh published story.
reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.stories (
  id, family_id, author_id, title, timeframe_start, status
)
select
  'aaaaaaaa-11a2-4111-8111-aaaaaaaaaaaa',
  parent_id, user_a, 'Cap', '1990-01-01'::date, 'published'::public.story_status
from m11_ctx;

select is(
  (select count(*) from public.photos
    where story_id = 'aaaaaaaa-11a2-4111-8111-aaaaaaaaaaaa'),
  0::bigint,
  'a fresh story has no photos'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

select lives_ok(
  $$insert into public.photos (story_id, family_id, uploader_id, storage_path, sort_order)
    select
      'aaaaaaaa-11a2-4111-8111-aaaaaaaaaaaa',
      parent_id, user_a,
      parent_id::text || '/aaaaaaaa-11a2-4111-8111-aaaaaaaaaaaa/' || g || '.jpg',
      g
    from m11_ctx
    cross join generate_series(1, 19) as g$$,
  'photos 1 through 19 insert'
);
select lives_ok(
  $$insert into public.photos (story_id, family_id, uploader_id, storage_path, sort_order)
    select
      'aaaaaaaa-11a2-4111-8111-aaaaaaaaaaaa',
      parent_id, user_a,
      parent_id::text || '/aaaaaaaa-11a2-4111-8111-aaaaaaaaaaaa/20.jpg',
      20
    from m11_ctx$$,
  'the 20th photo inserts'
);
select throws_ok(
  $$insert into public.photos (story_id, family_id, uploader_id, storage_path, sort_order)
    select
      'aaaaaaaa-11a2-4111-8111-aaaaaaaaaaaa',
      parent_id, user_a,
      parent_id::text || '/aaaaaaaa-11a2-4111-8111-aaaaaaaaaaaa/21.jpg',
      21
    from m11_ctx$$,
  'P0001',
  'VALIDATION: photo limit reached',
  'the 21st photo is rejected'
);

insert into public.photos (story_id, family_id, uploader_id, storage_path, sort_order)
select
  s2, parent_id, user_a,
  parent_id::text || '/' || s2::text || '/cap-' || g || '.jpg',
  g
from m11_ctx
cross join generate_series(
  1,
  20 - (
    select count(*)::integer
    from public.photos
    where story_id = (select s2 from m11_ctx)
  )
) as g;

set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b1';

select throws_ok(
  $$insert into public.photos (story_id, family_id, uploader_id, storage_path)
    select s2, parent_id, user_b, parent_id::text || '/' || s2::text || '/cap-child.jpg'
    from m11_ctx$$,
  'P0001',
  'VALIDATION: photo limit reached',
  'a child contributor insert at the cap is rejected'
);

-- Empty search_path, and one live call each.
reset role;
select set_config('request.jwt.claim.sub', '', true);

select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'story_row_exists'
      and pg_get_function_identity_arguments(p.oid) = 'sid uuid'
      and 'search_path=""' = any (p.proconfig)
      and not ('search_path=public' = any (p.proconfig))
  ),
  'story_row_exists search_path is empty'
);
select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'family_origin'
      and pg_get_function_identity_arguments(p.oid) = 'fid uuid'
      and 'search_path=""' = any (p.proconfig)
      and not ('search_path=public' = any (p.proconfig))
  ),
  'family_origin search_path is empty'
);
select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'set_family_origin'
      and pg_get_function_identity_arguments(p.oid) = 'p_family_id uuid, p_story_id uuid'
      and 'search_path=""' = any (p.proconfig)
      and not ('search_path=public' = any (p.proconfig))
  ),
  'set_family_origin search_path is empty'
);
select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'list_origin_dependents'
      and pg_get_function_identity_arguments(p.oid) = 'p_story_id uuid'
      and 'search_path=""' = any (p.proconfig)
      and not ('search_path=public' = any (p.proconfig))
  ),
  'list_origin_dependents search_path is empty'
);
select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'can_contribute_to_story'
      and pg_get_function_identity_arguments(p.oid) = 'fid uuid, sid uuid'
      and 'search_path=""' = any (p.proconfig)
      and not ('search_path=public' = any (p.proconfig))
  ),
  'can_contribute_to_story search_path is empty'
);
select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'list_family_tree'
      and pg_get_function_identity_arguments(p.oid) = 'fid uuid'
      and 'search_path=""' = any (p.proconfig)
      and not ('search_path=public' = any (p.proconfig))
  ),
  'list_family_tree search_path is empty'
);

select is(
  public.story_row_exists((select s1 from m11_ctx)),
  true,
  'story_row_exists runs'
);
select is(
  public.family_origin((select child_id from m11_ctx)),
  (select s2 from m11_ctx),
  'family_origin runs'
);

set local role authenticated;
set local request.jwt.claim.sub = 'c11c0000-0000-4000-8000-0000000000c1';
set local request.jwt.claim.role = 'authenticated';

select lives_ok(
  $$select public.set_family_origin(
    (select child_id from m11_ctx),
    (select s2 from m11_ctx)
  )$$,
  'set_family_origin runs'
);

set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';

select lives_ok(
  $$select * from public.list_origin_dependents((select s2 from m11_ctx))$$,
  'list_origin_dependents runs'
);
select lives_ok(
  $$select * from public.list_family_tree((select parent_id from m11_ctx))$$,
  'list_family_tree runs'
);

set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b1';

select is(
  public.can_contribute_to_story(
    (select parent_id from m11_ctx),
    (select s2 from m11_ctx)
  ),
  true,
  'can_contribute_to_story runs'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  has_function_privilege('anon', 'public.story_row_exists(uuid)', 'execute'),
  false,
  'anon cannot execute story_row_exists'
);
select is(
  has_function_privilege('authenticated', 'public.story_row_exists(uuid)', 'execute'),
  true,
  'authenticated can execute story_row_exists'
);

select results_eq(
  $$select column_name::text collate "C"
    from information_schema.columns
    where table_schema = 'public' and table_name = 'people_tree_read'
    order by ordinal_position$$,
  $$values ('id'::text collate "C"), ('family_id'::text collate "C"), ('name'::text collate "C"), ('relationship'::text collate "C")$$,
  'people_tree_read exposes id, family_id, name, and relationship only'
);

insert into public.people (id, family_id, name, relationship, created_by)
select
  '88888888-11a2-4111-8111-888888888888',
  parent_id, 'Origin Kin', 'kin', user_a
from m11_ctx;
insert into public.story_people (story_id, person_id)
select s2, '88888888-11a2-4111-8111-888888888888' from m11_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'b11b0000-0000-4000-8000-0000000000b1';
set local request.jwt.claim.role = 'authenticated';

select results_eq(
  $$select name::text collate "C" from public.people_tree_read
    where id = '88888888-11a2-4111-8111-888888888888'$$,
  $$values ('Origin Kin'::text collate "C")$$,
  'a child member sees a person tagged on the origin story'
);

-- Deleting the origin clears the link.
set local request.jwt.claim.sub = 'a11a0000-0000-4000-8000-0000000000a1';
select public.set_family_origin(
  (select parent_id from m11_ctx),
  (select s1 from m11_ctx)
);
delete from public.stories where id = (select s1 from m11_ctx);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  (select origin_story_id from public.families
    where id = (select parent_id from m11_ctx)),
  null,
  'deleting the origin story clears origin_story_id'
);
select is(
  public.family_origin((select parent_id from m11_ctx)),
  null,
  'family_origin is null after that delete'
);

select is(
  (select count(*) from pg_policies where schemaname in ('public', 'storage')),
  44::bigint,
  'policy count stays 44'
);

select is(
  coalesce((select qual from pg_policies
    where schemaname = 'public' and policyname = 'comments_delete_author'), ''),
  $pol$((author_id = ( SELECT auth.uid() AS uid)) AND (is_family_member(family_id) OR can_contribute_to_story(family_id, story_id)))$pol$,
  'comments_delete_author qual matches main'
);
select is(
  coalesce((select with_check from pg_policies
    where schemaname = 'public' and policyname = 'comments_delete_author'), ''),
  $pol$$pol$,
  'comments_delete_author with_check matches main'
);

select is(
  coalesce((select qual from pg_policies
    where schemaname = 'public' and policyname = 'comments_insert_member_author'), ''),
  $pol$$pol$,
  'comments_insert_member_author qual matches main'
);
select is(
  coalesce((select with_check from pg_policies
    where schemaname = 'public' and policyname = 'comments_insert_member_author'), ''),
  $pol$(can_contribute_to_story(family_id, story_id) AND (author_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM stories s
  WHERE ((s.id = comments.story_id) AND (s.family_id = comments.family_id)))))$pol$,
  'comments_insert_member_author with_check matches main'
);

select is(
  coalesce((select qual from pg_policies
    where schemaname = 'public' and policyname = 'comments_update_author'), ''),
  $pol$((author_id = ( SELECT auth.uid() AS uid)) AND can_contribute_to_story(family_id, story_id))$pol$,
  'comments_update_author qual matches main'
);
select is(
  coalesce((select with_check from pg_policies
    where schemaname = 'public' and policyname = 'comments_update_author'), ''),
  $pol$((author_id = ( SELECT auth.uid() AS uid)) AND can_contribute_to_story(family_id, story_id) AND (EXISTS ( SELECT 1
   FROM stories s
  WHERE ((s.id = comments.story_id) AND (s.family_id = comments.family_id)))))$pol$,
  'comments_update_author with_check matches main'
);

select is(
  coalesce((select qual from pg_policies
    where schemaname = 'public' and policyname = 'perspectives_delete_author'), ''),
  $pol$((author_id = ( SELECT auth.uid() AS uid)) AND (is_family_member(family_id) OR can_contribute_to_story(family_id, story_id)))$pol$,
  'perspectives_delete_author qual matches main'
);
select is(
  coalesce((select with_check from pg_policies
    where schemaname = 'public' and policyname = 'perspectives_delete_author'), ''),
  $pol$$pol$,
  'perspectives_delete_author with_check matches main'
);

select is(
  coalesce((select qual from pg_policies
    where schemaname = 'public' and policyname = 'perspectives_insert_member_author'), ''),
  $pol$$pol$,
  'perspectives_insert_member_author qual matches main'
);
select is(
  coalesce((select with_check from pg_policies
    where schemaname = 'public' and policyname = 'perspectives_insert_member_author'), ''),
  $pol$(can_contribute_to_story(family_id, story_id) AND (author_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM stories s
  WHERE ((s.id = perspectives.story_id) AND (s.family_id = perspectives.family_id)))))$pol$,
  'perspectives_insert_member_author with_check matches main'
);

select is(
  coalesce((select qual from pg_policies
    where schemaname = 'public' and policyname = 'perspectives_update_author'), ''),
  $pol$((author_id = ( SELECT auth.uid() AS uid)) AND can_contribute_to_story(family_id, story_id))$pol$,
  'perspectives_update_author qual matches main'
);
select is(
  coalesce((select with_check from pg_policies
    where schemaname = 'public' and policyname = 'perspectives_update_author'), ''),
  $pol$((author_id = ( SELECT auth.uid() AS uid)) AND can_contribute_to_story(family_id, story_id) AND (EXISTS ( SELECT 1
   FROM stories s
  WHERE ((s.id = perspectives.story_id) AND (s.family_id = perspectives.family_id)))))$pol$,
  'perspectives_update_author with_check matches main'
);

select is(
  coalesce((select qual from pg_policies
    where schemaname = 'public' and policyname = 'photos_delete_uploader_or_author'), ''),
  $pol$(((uploader_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM stories s
  WHERE ((s.id = photos.story_id) AND (s.author_id = ( SELECT auth.uid() AS uid)))))) AND (is_family_member(family_id) OR can_contribute_to_story(family_id, story_id)))$pol$,
  'photos_delete_uploader_or_author qual matches main'
);
select is(
  coalesce((select with_check from pg_policies
    where schemaname = 'public' and policyname = 'photos_delete_uploader_or_author'), ''),
  $pol$$pol$,
  'photos_delete_uploader_or_author with_check matches main'
);

select is(
  coalesce((select qual from pg_policies
    where schemaname = 'public' and policyname = 'photos_insert_member_uploader'), ''),
  $pol$$pol$,
  'photos_insert_member_uploader qual matches main'
);
select is(
  coalesce((select with_check from pg_policies
    where schemaname = 'public' and policyname = 'photos_insert_member_uploader'), ''),
  $pol$(can_contribute_to_story(family_id, story_id) AND (uploader_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM stories s
  WHERE ((s.id = photos.story_id) AND (s.family_id = photos.family_id)))))$pol$,
  'photos_insert_member_uploader with_check matches main'
);

select is(
  coalesce((select qual from pg_policies
    where schemaname = 'public' and policyname = 'photos_update_uploader_or_author'), ''),
  $pol$(can_contribute_to_story(family_id, story_id) AND ((uploader_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM stories s
  WHERE ((s.id = photos.story_id) AND (s.author_id = ( SELECT auth.uid() AS uid)))))))$pol$,
  'photos_update_uploader_or_author qual matches main'
);
select is(
  coalesce((select with_check from pg_policies
    where schemaname = 'public' and policyname = 'photos_update_uploader_or_author'), ''),
  $pol$(can_contribute_to_story(family_id, story_id) AND ((uploader_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM stories s
  WHERE ((s.id = photos.story_id) AND (s.author_id = ( SELECT auth.uid() AS uid)))))) AND (EXISTS ( SELECT 1
   FROM stories s
  WHERE ((s.id = photos.story_id) AND (s.family_id = photos.family_id)))))$pol$,
  'photos_update_uploader_or_author with_check matches main'
);

select is(
  coalesce((select qual from pg_policies
    where schemaname = 'public' and policyname = 'places_select_member'), ''),
  $pol$(is_live_family_member(family_id) OR (is_family_tree_readable(family_id) AND (EXISTS ( SELECT 1
   FROM stories s
  WHERE ((s.place_id = places.id) AND (s.family_id = places.family_id) AND (s.status = 'published'::story_status))))))$pol$,
  'places_select_member qual matches main'
);
select is(
  coalesce((select with_check from pg_policies
    where schemaname = 'public' and policyname = 'places_select_member'), ''),
  $pol$$pol$,
  'places_select_member with_check matches main'
);

select is(
  coalesce((select qual from pg_policies
    where schemaname = 'storage' and policyname = 'story_photos_delete_member'), ''),
  $pol$((bucket_id = 'story-photos'::text) AND (is_family_member(
CASE
    WHEN ((storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(name))[1])::uuid
    ELSE NULL::uuid
END) OR ((owner_id = (( SELECT auth.uid() AS uid))::text) AND can_contribute_to_story(
CASE
    WHEN ((storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(name))[1])::uuid
    ELSE NULL::uuid
END,
CASE
    WHEN ((storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(name))[2])::uuid
    ELSE NULL::uuid
END))))$pol$,
  'story_photos_delete_member qual matches main'
);
select is(
  coalesce((select with_check from pg_policies
    where schemaname = 'storage' and policyname = 'story_photos_delete_member'), ''),
  $pol$$pol$,
  'story_photos_delete_member with_check matches main'
);

select is(
  coalesce((select qual from pg_policies
    where schemaname = 'storage' and policyname = 'story_photos_insert_member'), ''),
  $pol$$pol$,
  'story_photos_insert_member qual matches main'
);
select is(
  coalesce((select with_check from pg_policies
    where schemaname = 'storage' and policyname = 'story_photos_insert_member'), ''),
  $pol$((bucket_id = 'story-photos'::text) AND (array_length(storage.foldername(name), 1) = 2) AND can_contribute_to_story(
CASE
    WHEN ((storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(name))[1])::uuid
    ELSE NULL::uuid
END,
CASE
    WHEN ((storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(name))[2])::uuid
    ELSE NULL::uuid
END) AND (EXISTS ( SELECT 1
   FROM stories s
  WHERE ((s.id =
        CASE
            WHEN ((storage.foldername(objects.name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(objects.name))[2])::uuid
            ELSE NULL::uuid
        END) AND (s.family_id =
        CASE
            WHEN ((storage.foldername(objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(objects.name))[1])::uuid
            ELSE NULL::uuid
        END)))) AND (lower(storage.extension(name)) = ANY (ARRAY['jpg'::text, 'jpeg'::text, 'png'::text, 'webp'::text])))$pol$,
  'story_photos_insert_member with_check matches main'
);

select is(
  coalesce((select qual from pg_policies
    where schemaname = 'storage' and policyname = 'story_photos_update_member'), ''),
  $pol$((bucket_id = 'story-photos'::text) AND (array_length(storage.foldername(name), 1) = 2) AND (is_live_family_member(
CASE
    WHEN ((storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(name))[1])::uuid
    ELSE NULL::uuid
END) OR ((owner_id = (( SELECT auth.uid() AS uid))::text) AND can_contribute_to_story(
CASE
    WHEN ((storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(name))[1])::uuid
    ELSE NULL::uuid
END,
CASE
    WHEN ((storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(name))[2])::uuid
    ELSE NULL::uuid
END))) AND (EXISTS ( SELECT 1
   FROM stories s
  WHERE ((s.id =
        CASE
            WHEN ((storage.foldername(objects.name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(objects.name))[2])::uuid
            ELSE NULL::uuid
        END) AND (s.family_id =
        CASE
            WHEN ((storage.foldername(objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(objects.name))[1])::uuid
            ELSE NULL::uuid
        END)))))$pol$,
  'story_photos_update_member qual matches main'
);
select is(
  coalesce((select with_check from pg_policies
    where schemaname = 'storage' and policyname = 'story_photos_update_member'), ''),
  $pol$((bucket_id = 'story-photos'::text) AND (array_length(storage.foldername(name), 1) = 2) AND (is_live_family_member(
CASE
    WHEN ((storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(name))[1])::uuid
    ELSE NULL::uuid
END) OR ((owner_id = (( SELECT auth.uid() AS uid))::text) AND can_contribute_to_story(
CASE
    WHEN ((storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(name))[1])::uuid
    ELSE NULL::uuid
END,
CASE
    WHEN ((storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(name))[2])::uuid
    ELSE NULL::uuid
END))) AND (EXISTS ( SELECT 1
   FROM stories s
  WHERE ((s.id =
        CASE
            WHEN ((storage.foldername(objects.name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(objects.name))[2])::uuid
            ELSE NULL::uuid
        END) AND (s.family_id =
        CASE
            WHEN ((storage.foldername(objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(objects.name))[1])::uuid
            ELSE NULL::uuid
        END)))) AND (lower(storage.extension(name)) = ANY (ARRAY['jpg'::text, 'jpeg'::text, 'png'::text, 'webp'::text])))$pol$,
  'story_photos_update_member with_check matches main'
);

select * from finish();
rollback;
