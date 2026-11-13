-- #84 M1. Photo edit columns, RPCs, privileges, and edited-object storage.
-- Runs in a transaction and rolls back.

begin;
create extension if not exists pgtap with schema extensions;

select plan(78);

create temporary table m84 (
  author_id uuid primary key,
  owner_id uuid not null,
  co_owner_id uuid not null,
  member_id uuid not null,
  uploader_id uuid not null,
  tree_id uuid not null,
  other_id uuid not null,
  family_id uuid,
  child_id uuid,
  other_family_id uuid,
  published_id uuid not null,
  draft_id uuid not null,
  other_story_id uuid not null,
  pub_photo uuid not null,
  owner_photo uuid not null,
  draft_photo uuid not null,
  check_photo uuid not null,
  shape_photo uuid not null,
  search_photo uuid not null
);

grant all on table m84 to authenticated, anon, service_role;

insert into m84 (
  author_id, owner_id, co_owner_id, member_id, uploader_id, tree_id, other_id,
  published_id, draft_id, other_story_id,
  pub_photo, owner_photo, draft_photo, check_photo, shape_photo, search_photo
) values (
  'a8400000-0000-4000-8000-0000000000a1',
  'a8400000-0000-4000-8000-0000000000a2',
  'a8400000-0000-4000-8000-0000000000a3',
  'a8400000-0000-4000-8000-0000000000a4',
  'a8400000-0000-4000-8000-0000000000a5',
  'a8400000-0000-4000-8000-0000000000a6',
  'a8400000-0000-4000-8000-0000000000a7',
  'a8400000-0000-4000-8000-0000000000c1',
  'a8400000-0000-4000-8000-0000000000c2',
  'a8400000-0000-4000-8000-0000000000c3',
  'a8400000-0000-4000-8000-0000000000b1',
  'a8400000-0000-4000-8000-0000000000b2',
  'a8400000-0000-4000-8000-0000000000b3',
  'a8400000-0000-4000-8000-0000000000b4',
  'a8400000-0000-4000-8000-0000000000b5',
  'a8400000-0000-4000-8000-0000000000b8'
);

create function pg_temp.edited_path(fam uuid, story uuid, photo uuid, ver bigint)
returns text
language sql
immutable
as $$
  select fam::text || '/' || story::text || '/' || photo::text
    || '.edited.' || ver::text || '.jpg'
$$;

insert into auth.users (id, email, raw_user_meta_data)
select author_id, 'm84-author@test.local', '{"display_name":"Author"}'::jsonb from m84
union all
select owner_id, 'm84-owner@test.local', '{"display_name":"Owner"}'::jsonb from m84
union all
select co_owner_id, 'm84-co@test.local', '{"display_name":"Co-owner"}'::jsonb from m84
union all
select member_id, 'm84-member@test.local', '{"display_name":"Member"}'::jsonb from m84
union all
select uploader_id, 'm84-up@test.local', '{"display_name":"Uploader"}'::jsonb from m84
union all
select tree_id, 'm84-tree@test.local', '{"display_name":"Tree"}'::jsonb from m84
union all
select other_id, 'm84-other@test.local', '{"display_name":"Other"}'::jsonb from m84;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a8400000-0000-4000-8000-0000000000a2', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
update m84 set family_id = (public.create_family('M84 Family')).id;

set local request.jwt.claim.sub = 'a8400000-0000-4000-8000-0000000000a6';
update m84 set child_id = (public.create_family('M84 Child')).id;

set local request.jwt.claim.sub = 'a8400000-0000-4000-8000-0000000000a7';
update m84 set other_family_id = (public.create_family('M84 Other')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

update public.families f
set parent_family_id = c.family_id, branch_year = 1984
from m84 c
where f.id = c.child_id;

insert into public.memberships (family_id, user_id, role)
select family_id, author_id, 'member'::public.membership_role from m84
union all
select family_id, member_id, 'member'::public.membership_role from m84
union all
select family_id, uploader_id, 'member'::public.membership_role from m84
union all
select family_id, co_owner_id, 'member'::public.membership_role from m84;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a8400000-0000-4000-8000-0000000000a2', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select public.add_co_owner((select family_id from m84), (select co_owner_id from m84));

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.stories (
  id, family_id, author_id, title, status, published_at,
  timeframe_start, timeframe_end, date_precision
)
select
  published_id, family_id, author_id, 'Published', 'published'::public.story_status, now(),
  '1980-03-14'::date, '1980-03-14'::date, 'day'::public.story_date_precision
from m84;

insert into public.stories (
  id, family_id, author_id, title, status,
  timeframe_start, timeframe_end, date_precision
)
select
  draft_id, family_id, author_id, 'Draft', 'draft'::public.story_status,
  '1981-01-01'::date, '1981-01-01'::date, 'day'::public.story_date_precision
from m84;

insert into public.stories (
  id, family_id, author_id, title, status, published_at,
  timeframe_start, timeframe_end, date_precision
)
select
  other_story_id, other_family_id, other_id, 'Other', 'published'::public.story_status, now(),
  '1970-01-01'::date, '1970-01-01'::date, 'day'::public.story_date_precision
from m84;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a8400000-0000-4000-8000-0000000000a6', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select public.set_family_origin((select child_id from m84), (select published_id from m84));
reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.photos (id, story_id, family_id, uploader_id, storage_path, sort_order)
select pub_photo, published_id, family_id, uploader_id,
  family_id::text || '/' || published_id::text || '/' || pub_photo::text || '.jpg', 2
from m84
union all
select owner_photo, published_id, family_id, author_id,
  family_id::text || '/' || published_id::text || '/' || owner_photo::text || '.jpg', 3
from m84
union all
select draft_photo, draft_id, family_id, author_id,
  family_id::text || '/' || draft_id::text || '/' || draft_photo::text || '.jpg', 0
from m84
union all
select check_photo, published_id, family_id, author_id,
  family_id::text || '/' || published_id::text || '/' || check_photo::text || '.jpg', 4
from m84
union all
select shape_photo, published_id, family_id, author_id,
  family_id::text || '/' || published_id::text || '/' || shape_photo::text || '.jpg', 5
from m84
union all
select search_photo, published_id, family_id, author_id,
  family_id::text || '/' || published_id::text || '/' || search_photo::text || '.jpg', 6
from m84;

insert into storage.objects (bucket_id, name, owner_id)
select 'story-photos', p.storage_path, p.uploader_id::text
from public.photos p
join m84 c on p.id in (c.pub_photo, c.owner_photo, c.draft_photo, c.check_photo);

insert into storage.objects (bucket_id, name, owner_id)
select 'story-photos',
  family_id::text || '/' || published_id::text || '/spare.jpg',
  member_id::text
from m84;

insert into storage.objects (bucket_id, name, owner_id)
select 'story-photos',
  family_id::text || '/' || published_id::text || '/' || pub_photo::text || '.edited.1.jpg',
  author_id::text
from m84;

-- Privileges. Column grants are the write boundary.
select ok(
  not has_table_privilege('public', 'public.photos', 'UPDATE'),
  'PUBLIC lacks table UPDATE on photos'
);
select ok(
  not has_table_privilege('anon', 'public.photos', 'UPDATE'),
  'anon lacks table UPDATE on photos'
);
select ok(
  not has_table_privilege('authenticated', 'public.photos', 'UPDATE'),
  'authenticated lacks table UPDATE on photos'
);
select ok(
  not has_column_privilege('authenticated', 'public.photos', 'edited_storage_path', 'UPDATE'),
  'authenticated lacks UPDATE on edited_storage_path'
);
select ok(
  not has_column_privilege('authenticated', 'public.photos', 'edit_version', 'UPDATE'),
  'authenticated lacks UPDATE on edit_version'
);
select set_eq(
  $$select a.attname
    from pg_attribute a
    join pg_class c on c.oid = a.attrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'photos'
      and a.attnum > 0 and not a.attisdropped
      and has_column_privilege('authenticated', a.attrelid, a.attnum, 'UPDATE')$$,
  $$values ('sort_order')$$,
  'authenticated photo UPDATE is sort_order only'
);
select ok(
  not has_table_privilege('public', 'public.photos', 'INSERT'),
  'PUBLIC lacks table INSERT on photos'
);
select ok(
  not has_table_privilege('anon', 'public.photos', 'INSERT'),
  'anon lacks table INSERT on photos'
);
select ok(
  not has_table_privilege('authenticated', 'public.photos', 'INSERT'),
  'authenticated lacks table INSERT on photos'
);
select set_eq(
  $$select a.attname
    from pg_attribute a
    join pg_class c on c.oid = a.attrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'photos'
      and a.attnum > 0 and not a.attisdropped
      and has_column_privilege('authenticated', a.attrelid, a.attnum, 'INSERT')
    order by 1$$,
  $$values ('family_id'),('id'),('sort_order'),('storage_path'),('story_id'),('uploader_id')$$,
  'authenticated photo INSERT is the six attach columns'
);

select is(
  (select c.relowner from pg_class c where c.oid = 'public.photos'::regclass),
  (select p.proowner from pg_proc p
    where p.oid = 'public.save_photo_edit(uuid,bigint,text)'::regprocedure),
  'photos owner matches save_photo_edit'
);
select is(
  (select c.relowner from pg_class c where c.oid = 'public.photos'::regclass),
  (select p.proowner from pg_proc p
    where p.oid = 'public.reset_photo_edit(uuid,bigint)'::regprocedure),
  'photos owner matches reset_photo_edit'
);
select ok(
  not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'photo_edit_fields_guard'
  ),
  'photo_edit_fields_guard is not created'
);
select is(
  (select count(*)::int from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'photos'
      and not t.tgisinternal and t.tgname = 'photos_guard_update'),
  1,
  'photos_guard_update is the only photo guard trigger'
);
select ok(
  exists (
    select 1 from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    where c.relname = 'photos' and t.tgname = 'photos_guard_update'
      and (t.tgtype & 2) = 2
      and (t.tgtype & 4) = 4
      and (t.tgtype & 16) = 16
  ),
  'photos_guard_update is BEFORE INSERT OR UPDATE'
);
select is(
  (select p.prosecdef from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'photos_guard_update'),
  false,
  'photos_guard_update is security invoker'
);
select is(
  (select p.proconfig::text from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'photos_guard_update'),
  E'{"search_path=\\"\\""}',
  'photos_guard_update pins an empty search_path'
);
select is(
  (select p.prosecdef from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'can_edit_story_photo_object'),
  false,
  'can_edit_story_photo_object is security invoker'
);
select ok(
  not has_function_privilege('authenticated', 'public.story_photo_exists(text)', 'execute'),
  'authenticated cannot execute story_photo_exists'
);

select is(
  (select edit_version from public.photos where id = (select check_photo from m84)),
  0::bigint,
  'edit_version defaults to 0'
);
select is(
  (select edited_storage_path from public.photos where id = (select check_photo from m84)),
  null,
  'edited_storage_path defaults to null'
);

-- Owner-context locks. Privilege no longer hides these from the table owner.
select throws_ok(
  $$update public.photos
    set id = 'a8400000-0000-4000-8000-0000000000ff'
    where id = (select check_photo from m84)$$,
  'P0001', 'FORBIDDEN: field is locked',
  'the owner cannot change photo id'
);
select throws_ok(
  $$update public.photos p
    set story_id = c.draft_id
    from m84 c
    where p.id = c.check_photo$$,
  'P0001', 'FORBIDDEN: field is locked',
  'the owner cannot move a photo to another story'
);
select throws_ok(
  $$update public.photos p
    set family_id = c.other_family_id
    from m84 c
    where p.id = c.check_photo$$,
  'P0001', 'FORBIDDEN: field is locked',
  'the owner cannot change photo family_id'
);
select throws_ok(
  $$update public.photos p
    set uploader_id = c.member_id
    from m84 c
    where p.id = c.check_photo$$,
  'P0001', 'FORBIDDEN: field is locked',
  'the owner cannot change photo uploader_id'
);
select throws_ok(
  $$update public.photos
    set storage_path = 'nope.jpg'
    where id = (select check_photo from m84)$$,
  'P0001', 'FORBIDDEN: field is locked',
  'the owner cannot change storage_path'
);
select throws_ok(
  $$update public.photos p
    set edit_version = 2,
        edited_storage_path = pg_temp.edited_path(c.family_id, c.published_id, c.check_photo, 2)
    from m84 c
    where p.id = c.check_photo$$,
  'P0001', 'FORBIDDEN: field is locked',
  'the owner cannot jump the edit version'
);
select lives_ok(
  $$update public.photos p
    set edit_version = 1,
        edited_storage_path = pg_temp.edited_path(c.family_id, c.published_id, c.shape_photo, 1)
    from m84 c
    where p.id = c.shape_photo$$,
  'the owner can advance the edit columns by one'
);

select throws_ok(
  $$update public.photos p
    set edited_storage_path = 'not-a-path', edit_version = 1
    from m84 c
    where p.id = c.check_photo$$,
  '23514',
  'new row for relation "photos" violates check constraint "photos_edited_path_shape"',
  'a free-form edited path is rejected'
);

alter table public.photos disable trigger photos_guard_update;
select throws_ok(
  $$update public.photos p
    set edited_storage_path = pg_temp.edited_path(c.family_id, c.published_id, c.check_photo, 0),
        edit_version = 0
    from m84 c
    where p.id = c.check_photo$$,
  '23514',
  'new row for relation "photos" violates check constraint "photos_edited_path_version_positive"',
  'a non-null path at version 0 is rejected'
);
select throws_ok(
  $$update public.photos set edit_version = -1 where id = (select check_photo from m84)$$,
  '23514',
  'new row for relation "photos" violates check constraint "photos_edit_version_nonnegative"',
  'a negative edit_version is rejected'
);
alter table public.photos enable trigger photos_guard_update;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a8400000-0000-4000-8000-0000000000a1', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok(
  $$update public.photos
    set edited_storage_path = 'blocked'
    where id = (select pub_photo from m84)$$,
  '42501', null,
  'direct edited_storage_path update is denied by privilege'
);
select throws_ok(
  $$select set_config('app.photo_edit_rpc', 'on', true);
    update public.photos set edit_version = 7 where id = (select pub_photo from m84)$$,
  '42501', null,
  'setting app.photo_edit_rpc does not grant the edit columns'
);
select throws_ok(
  $$insert into public.photos (
      id, story_id, family_id, uploader_id, storage_path, edited_storage_path
    )
    select 'a8400000-0000-4000-8000-0000000000b6',
      published_id, family_id, author_id,
      family_id::text || '/' || published_id::text || '/a8400000-0000-4000-8000-0000000000b6.jpg',
      'blocked'
    from m84$$,
  '42501', null,
  'a client insert cannot set edited_storage_path'
);
select throws_ok(
  $$insert into public.photos (
      id, story_id, family_id, uploader_id, storage_path, edit_version
    )
    select 'a8400000-0000-4000-8000-0000000000b7',
      published_id, family_id, author_id,
      family_id::text || '/' || published_id::text || '/a8400000-0000-4000-8000-0000000000b7.jpg',
      1
    from m84$$,
  '42501', null,
  'a client insert cannot set edit_version'
);
select lives_ok(
  $$insert into public.photos (id, story_id, family_id, uploader_id, storage_path, sort_order)
    select 'a8400000-0000-4000-8000-0000000000b9',
      published_id, family_id, author_id,
      family_id::text || '/' || published_id::text || '/a8400000-0000-4000-8000-0000000000b9.jpg',
      1
    from m84$$,
  'a plain attach insert still works'
);
select is(
  (select edit_version from public.photos
    where id = 'a8400000-0000-4000-8000-0000000000b9'),
  0::bigint,
  'a plain attach stores edit_version 0'
);
select is(
  (select edited_storage_path from public.photos
    where id = 'a8400000-0000-4000-8000-0000000000b9'),
  null,
  'a plain attach stores a null edited path'
);

create temporary table m84_ret (edit_version bigint, previous_path text);
grant all on table m84_ret to authenticated;

insert into m84_ret
select * from public.save_photo_edit(
  (select pub_photo from m84),
  0,
  (select pg_temp.edited_path(family_id, published_id, pub_photo, 1) from m84)
);
select is((select edit_version from m84_ret), 1::bigint, 'author save returns version 1');
select is((select previous_path from m84_ret), null, 'the first save returns a null previous path');
delete from m84_ret;

select throws_ok(
  $$select public.save_photo_edit(
      (select pub_photo from m84), 0,
      (select pg_temp.edited_path(family_id, published_id, pub_photo, 1) from m84)
    )$$,
  'P0001', 'CONFLICT: photo edit version',
  'a stale save conflicts'
);
insert into m84_ret
select * from public.save_photo_edit(
  (select pub_photo from m84), 1,
  (select pg_temp.edited_path(family_id, published_id, pub_photo, 2) from m84)
);
select is(
  (select previous_path from m84_ret),
  (select pg_temp.edited_path(family_id, published_id, pub_photo, 1) from m84),
  'a later save returns only the previous edited path'
);
delete from m84_ret;
insert into m84_ret
select * from public.reset_photo_edit((select pub_photo from m84), 2);
select is((select edit_version from m84_ret), 3::bigint, 'reset increments the version once');
select is(
  (select previous_path from m84_ret),
  (select pg_temp.edited_path(family_id, published_id, pub_photo, 2) from m84),
  'reset returns the edited path it cleared'
);
select is(
  (select edited_storage_path from public.photos where id = (select pub_photo from m84)),
  null,
  'reset clears edited_storage_path'
);
select is(
  (select storage_path from public.photos where id = (select pub_photo from m84)),
  (select family_id::text || '/' || published_id::text || '/' || pub_photo::text || '.jpg' from m84),
  'save and reset leave storage_path unchanged'
);

select throws_ok(
  $$select public.save_photo_edit((select owner_photo from m84), 0, null)$$,
  'P0001', 'VALIDATION: invalid edited path',
  'save rejects a null path'
);
select throws_ok(
  $$select public.save_photo_edit(
      (select owner_photo from m84), 0,
      (select family_id::text || '/' || published_id::text || '/spare.jpg' from m84)
    )$$,
  'P0001', 'VALIDATION: invalid edited path',
  'save rejects a non-edited object as the edited pointer'
);

set local request.jwt.claim.sub = 'a8400000-0000-4000-8000-0000000000a2';
delete from m84_ret;
insert into m84_ret
select * from public.save_photo_edit(
  (select owner_photo from m84), 0,
  (select pg_temp.edited_path(family_id, published_id, owner_photo, 1) from m84)
);
select is((select edit_version from m84_ret), 1::bigint, 'the owner can save');
set local request.jwt.claim.sub = 'a8400000-0000-4000-8000-0000000000a3';
delete from m84_ret;
insert into m84_ret
select * from public.reset_photo_edit((select owner_photo from m84), 1);
select is((select edit_version from m84_ret), 2::bigint, 'the co-owner can reset');

set local request.jwt.claim.sub = 'a8400000-0000-4000-8000-0000000000a1';
delete from m84_ret;
insert into m84_ret
select * from public.save_photo_edit(
  (select draft_photo from m84), 0,
  (select pg_temp.edited_path(family_id, draft_id, draft_photo, 1) from m84)
);
select is((select edit_version from m84_ret), 1::bigint, 'the draft author can save');
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    select 'story-photos',
      pg_temp.edited_path(family_id, draft_id, draft_photo, 1),
      author_id::text
    from m84$$,
  'the draft author can store the edited object'
);
select is(
  (select count(*) from storage.objects
    where name = (select family_id::text || '/' || draft_id::text || '/' || draft_photo::text || '.jpg' from m84)),
  1::bigint,
  'the draft author can read the original object'
);
select is(
  (select count(*) from storage.objects
    where name = (select pg_temp.edited_path(family_id, draft_id, draft_photo, 1) from m84)),
  1::bigint,
  'the draft author can read the edited object'
);

set local request.jwt.claim.sub = 'a8400000-0000-4000-8000-0000000000a4';
select is(
  (select count(*) from storage.objects
    where name = (select pg_temp.edited_path(family_id, draft_id, draft_photo, 1) from m84)),
  0::bigint,
  'another member cannot read the draft edit'
);
select throws_ok(
  $$select public.save_photo_edit(
      (select draft_photo from m84), 1,
      (select pg_temp.edited_path(family_id, draft_id, draft_photo, 2) from m84)
    )$$,
  'P0001', 'FORBIDDEN: photo edit denied',
  'a member cannot save a draft edit'
);
select throws_ok(
  $$select public.save_photo_edit(
      'a8400000-0000-4000-8000-000000000099', 0, 'missing.edited.1.jpg')$$,
  'P0001', 'FORBIDDEN: photo edit denied',
  'save denies a missing photo'
);
select throws_ok(
  $$select public.reset_photo_edit('a8400000-0000-4000-8000-000000000099', 0)$$,
  'P0001', 'FORBIDDEN: photo edit denied',
  'reset denies a missing photo'
);
select throws_ok(
  $$select public.save_photo_edit(
      (select pub_photo from m84), 3,
      (select pg_temp.edited_path(family_id, published_id, pub_photo, 4) from m84)
    )$$,
  'P0001', 'FORBIDDEN: photo edit denied',
  'save denies a member who is not an editor'
);

set local request.jwt.claim.sub = 'a8400000-0000-4000-8000-0000000000a5';
select throws_ok(
  $$select public.reset_photo_edit((select pub_photo from m84), 3)$$,
  'P0001', 'FORBIDDEN: photo edit denied',
  'the uploader cannot reset without story-edit rights'
);
select lives_ok(
  $$update public.photos set sort_order = 0 where id = (select pub_photo from m84)$$,
  'the uploader can still set sort_order'
);
select is(
  (select sort_order from public.photos where id = (select pub_photo from m84)),
  0,
  'hero ordering writes sort_order'
);

set local request.jwt.claim.sub = 'a8400000-0000-4000-8000-0000000000a6';
select throws_ok(
  $$select public.save_photo_edit(
      (select pub_photo from m84), 3,
      (select pg_temp.edited_path(family_id, published_id, pub_photo, 4) from m84)
    )$$,
  'P0001', 'FORBIDDEN: photo edit denied',
  'a tree reader cannot save'
);
select is(
  (select count(*) from storage.objects
    where name = (select family_id::text || '/' || published_id::text || '/' || pub_photo::text || '.jpg' from m84)),
  1::bigint,
  'a tree reader can read the published original'
);

set local request.jwt.claim.sub = 'a8400000-0000-4000-8000-0000000000a1';
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    select 'story-photos',
      family_id::text || '/' || published_id::text || '/extra.jpg',
      author_id::text
    from m84$$,
  'an editor can still insert an original object'
);
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    select 'story-photos',
      pg_temp.edited_path(family_id, published_id, owner_photo, 3),
      author_id::text
    from m84$$,
  'an editor can insert the edited object name'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    select 'story-photos',
      pg_temp.edited_path(family_id, published_id, 'a8400000-0000-4000-8000-0000000000ee', 1),
      author_id::text
    from m84$$,
  '42501', null,
  'an edited name for an unknown photo is denied'
);

set local request.jwt.claim.sub = 'a8400000-0000-4000-8000-0000000000a4';
select set_config('storage.allow_delete_query', 'true', true);
select lives_ok(
  $$delete from storage.objects
    where name = (select family_id::text || '/' || published_id::text || '/spare.jpg' from m84)$$,
  'a member can still delete an original object'
);
select is(
  (select count(*) from storage.objects
    where name = (select family_id::text || '/' || published_id::text || '/spare.jpg' from m84)),
  0::bigint,
  'the original spare object is gone'
);

reset role;
select set_config('request.jwt.claim.sub', 'a8400000-0000-4000-8000-0000000000a1', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
create schema m84_trap;
create function m84_trap.can_edit_story(sid uuid)
returns boolean language sql as $$ select false $$;
set local search_path = m84_trap, pg_temp, pg_catalog;
delete from m84_ret;
insert into m84_ret
select * from public.save_photo_edit(
  (select search_photo from m84), 0,
  (select pg_temp.edited_path(family_id, published_id, search_photo, 1) from m84)
);
set local search_path = public, extensions;
select is((select edit_version from m84_ret), 1::bigint, 'save still succeeds when search_path hides public');

select is(
  (select cmd from pg_policies
    where schemaname = 'storage' and policyname = 'story_photos_insert_member'),
  'INSERT',
  'story_photos_insert_member is INSERT'
);
select is(
  (select roles::text from pg_policies
    where schemaname = 'storage' and policyname = 'story_photos_insert_member'),
  '{authenticated}',
  'story_photos_insert_member is to authenticated'
);
select is(
  coalesce((select qual from pg_policies
    where schemaname = 'storage' and policyname = 'story_photos_insert_member'), ''),
  '',
  'story_photos_insert_member has no USING clause'
);
select is(
  (select cmd from pg_policies
    where schemaname = 'storage' and policyname = 'story_photos_update_member'),
  'UPDATE',
  'story_photos_update_member is UPDATE'
);
select is(
  (select roles::text from pg_policies
    where schemaname = 'storage' and policyname = 'story_photos_update_member'),
  '{authenticated}',
  'story_photos_update_member is to authenticated'
);
select is(
  (select cmd from pg_policies
    where schemaname = 'storage' and policyname = 'story_photos_delete_member'),
  'DELETE',
  'story_photos_delete_member is DELETE'
);
select is(
  (select roles::text from pg_policies
    where schemaname = 'storage' and policyname = 'story_photos_delete_member'),
  '{authenticated}',
  'story_photos_delete_member is to authenticated'
);
select is(
  coalesce((select with_check from pg_policies
    where schemaname = 'storage' and policyname = 'story_photos_delete_member'), ''),
  '',
  'story_photos_delete_member has no WITH CHECK clause'
);

select * from finish();
rollback;
