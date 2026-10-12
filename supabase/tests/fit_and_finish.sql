-- M13 Fit & Finish. One transaction, rolled back.

begin;
create extension if not exists pgtap with schema extensions;

create temporary table m13_ctx (
  owner_id uuid primary key,
  co_id uuid not null,
  author_id uuid not null,
  member_id uuid not null,
  child_owner_id uuid not null,
  child_member_id uuid not null,
  outsider_id uuid not null,
  parent_id uuid,
  child_id uuid,
  dead_id uuid,
  published_id uuid,
  draft_id uuid,
  other_draft_id uuid,
  person_id uuid,
  other_person_id uuid,
  photo_id uuid,
  photo2_id uuid
);

grant all on table m13_ctx to authenticated, anon, service_role;

insert into m13_ctx (
  owner_id, co_id, author_id, member_id, child_owner_id, child_member_id, outsider_id,
  published_id, draft_id, other_draft_id, person_id, other_person_id, photo_id, photo2_id
)
values (
  'a1300000-0000-4000-8000-0000000000a1',
  'b1300000-0000-4000-8000-0000000000b1',
  'c1300000-0000-4000-8000-0000000000c1',
  'd1300000-0000-4000-8000-0000000000d1',
  'e1300000-0000-4000-8000-0000000000e1',
  'f1300000-0000-4000-8000-0000000000f1',
  '61300000-0000-4000-8000-000000000061',
  '11111111-13a1-4111-8111-111111111111',
  '22222222-13a1-4111-8111-222222222222',
  '33333333-13a1-4111-8111-333333333333',
  '44444444-13a1-4111-8111-444444444444',
  '55555555-13a1-4111-8111-555555555555',
  '66666666-13a1-4111-8111-666666666666',
  '77777777-13a1-4111-8111-777777777777'
);

insert into auth.users (id, email, raw_user_meta_data)
select owner_id, 'm13-owner@test.local', '{"display_name":"Owner"}'::jsonb from m13_ctx
union all
select co_id, 'm13-co@test.local', '{"display_name":"Co"}'::jsonb from m13_ctx
union all
select author_id, 'm13-author@test.local', '{"display_name":"Author"}'::jsonb from m13_ctx
union all
select member_id, 'm13-member@test.local', '{"display_name":"Member"}'::jsonb from m13_ctx
union all
select child_owner_id, 'm13-child@test.local', '{"display_name":"Child"}'::jsonb from m13_ctx
union all
select child_member_id, 'm13-child-member@test.local', '{"display_name":"Child Member"}'::jsonb from m13_ctx
union all
select outsider_id, 'm13-out@test.local', '{"display_name":"Out"}'::jsonb from m13_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a1300000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

update m13_ctx set parent_id = (public.create_family('Parent')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.memberships (family_id, user_id, role)
select parent_id, co_id, 'co_owner'::public.membership_role from m13_ctx
union all
select parent_id, author_id, 'member'::public.membership_role from m13_ctx
union all
select parent_id, member_id, 'member'::public.membership_role from m13_ctx;

with inserted as (
  insert into public.families (name, created_by, parent_family_id)
  select 'Child', child_owner_id, parent_id from m13_ctx
  returning id
)
update m13_ctx set child_id = inserted.id from inserted;

insert into public.memberships (family_id, user_id, role)
select child_id, child_owner_id, 'owner'::public.membership_role from m13_ctx
union all
select child_id, child_member_id, 'member'::public.membership_role from m13_ctx;

set local role authenticated;
set local request.jwt.claim.sub = '61300000-0000-4000-8000-000000000061';
set local request.jwt.claim.role = 'authenticated';
update m13_ctx set dead_id = (public.create_family('Dead')).id;
select public.soft_delete_family((select dead_id from m13_ctx));

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.stories (
  id, family_id, author_id, title, body, timeframe_start, timeframe_end,
  date_precision, status, published_at, created_at
)
select published_id, parent_id, author_id, 'Published', 'body',
       '1980-03-14'::date, '1980-03-14'::date, 'day'::public.story_date_precision,
       'published'::public.story_status, now(), now()
from m13_ctx
union all
select draft_id, parent_id, author_id, 'Draft', 'body',
       '1981-01-01'::date, '1981-01-01'::date, 'day'::public.story_date_precision,
       'draft'::public.story_status, null, now()
from m13_ctx
union all
select other_draft_id, parent_id, member_id, 'Theirs', 'body',
       '1982-01-01'::date, '1982-01-01'::date, 'day'::public.story_date_precision,
       'draft'::public.story_status, null, now()
from m13_ctx;

insert into public.people (id, family_id, name, relationship, created_by)
select person_id, parent_id, 'Kin', 'kin', author_id from m13_ctx;

insert into public.people (id, family_id, name, relationship, created_by)
select other_person_id, child_id, 'Other kin', 'kin', child_owner_id from m13_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'e1300000-0000-4000-8000-0000000000e1';
set local request.jwt.claim.role = 'authenticated';
select public.set_family_origin(
  (select child_id from m13_ctx),
  (select published_id from m13_ctx)
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select plan(58);

-- Null end fills to start and day. A decade-shaped row stays decade.
insert into public.stories (
  id, family_id, author_id, title, timeframe_start, status
)
values (
  '88888888-13a1-4111-8111-888888888888',
  (select parent_id from m13_ctx),
  (select author_id from m13_ctx),
  'Filled day',
  '1974-07-24'::date,
  'published'::public.story_status
);

select is(
  (select timeframe_end from public.stories where id = '88888888-13a1-4111-8111-888888888888'),
  '1974-07-24'::date,
  'a null end is stored as the start'
);
select is(
  (select date_precision from public.stories where id = '88888888-13a1-4111-8111-888888888888'),
  'day'::public.story_date_precision,
  'a null end is a day'
);

alter table public.stories disable trigger stories_date_guard;
insert into public.stories (
  id, family_id, author_id, title, timeframe_start, timeframe_end,
  date_precision, status
)
values (
  '99999999-13a1-4111-8111-999999999999',
  (select parent_id from m13_ctx),
  (select author_id from m13_ctx),
  'Legacy decade',
  '1970-01-01'::date,
  '1979-12-31'::date,
  'decade'::public.story_date_precision,
  'published'::public.story_status
);
alter table public.stories enable trigger stories_date_guard;

select is(
  (select date_precision from public.stories where id = '99999999-13a1-4111-8111-999999999999'),
  'decade'::public.story_date_precision,
  'a decade range is decade'
);

select throws_ok(
  $$insert into public.stories (
      id, family_id, author_id, title, timeframe_start, timeframe_end, date_precision, status
    ) values (
      'aaaaaaa1-13a1-4111-8111-aaaaaaaaaaa1',
      (select parent_id from m13_ctx),
      (select author_id from m13_ctx),
      'bad day', '1987-03-14', '1987-03-15', 'day', 'draft'
    )$$,
  '23514',
  null,
  'a day whose end differs is rejected'
);

select throws_ok(
  $$insert into public.stories (
      id, family_id, author_id, title, timeframe_start, timeframe_end, date_precision, status
    ) values (
      'aaaaaaa2-13a1-4111-8111-aaaaaaaaaaa2',
      (select parent_id from m13_ctx),
      (select author_id from m13_ctx),
      'bad month', '1987-03-02', '1987-03-31', 'month', 'draft'
    )$$,
  '23514',
  null,
  'a month that does not start on the 1st is rejected'
);

select throws_ok(
  $$insert into public.stories (
      id, family_id, author_id, title, timeframe_start, timeframe_end, date_precision, status
    ) values (
      'aaaaaaa3-13a1-4111-8111-aaaaaaaaaaa3',
      (select parent_id from m13_ctx),
      (select author_id from m13_ctx),
      'bad year', '1987-01-01', '1987-06-30', 'year', 'draft'
    )$$,
  '23514',
  null,
  'a year that is not Jan 1 through Dec 31 is rejected'
);

alter table public.stories disable trigger stories_date_guard;
select throws_ok(
  $$insert into public.stories (
      id, family_id, author_id, title, timeframe_start, timeframe_end, date_precision, status
    ) values (
      'aaaaaaa4-13a1-4111-8111-aaaaaaaaaaa4',
      (select parent_id from m13_ctx),
      (select author_id from m13_ctx),
      'bad decade', '1981-01-01', '1990-12-31', 'decade', 'draft'
    )$$,
  '23514',
  null,
  'a decade that is not a zero year through nine years later is rejected'
);
alter table public.stories enable trigger stories_date_guard;

select throws_ok(
  $$insert into public.stories (
      id, family_id, author_id, title, timeframe_start, timeframe_end, date_precision, status
    ) values (
      'aaaaaaa5-13a1-4111-8111-aaaaaaaaaaa5',
      (select parent_id from m13_ctx),
      (select author_id from m13_ctx),
      'bad year number', '0999-01-01', '0999-01-01', 'day', 'draft'
    )$$,
  '23514',
  null,
  'a year outside 1000-9999 is rejected'
);

set local role authenticated;
set local request.jwt.claim.sub = 'c1300000-0000-4000-8000-0000000000c1';
set local request.jwt.claim.role = 'authenticated';

select throws_ok(
  $$insert into public.stories (
      family_id, author_id, title, timeframe_start, timeframe_end, date_precision, status
    )
    select parent_id, author_id, 'no decade', '1980-01-01', '1989-12-31', 'decade', 'draft'
    from m13_ctx$$,
  'P0001',
  'VALIDATION: year required',
  'inserting decade is refused'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select lives_ok(
  $$update public.stories set title = 'still a decade'
    where id = '99999999-13a1-4111-8111-999999999999'$$,
  'a legacy decade row survives an unrelated update'
);

select throws_ok(
  $$update public.stories
    set timeframe_end = '1988-12-31'
    where id = '99999999-13a1-4111-8111-999999999999'$$,
  'P0001',
  'VALIDATION: year required',
  'a legacy decade row cannot move its dates'
);

alter table public.stories disable trigger stories_date_guard;
insert into public.stories (
  id, family_id, author_id, title, timeframe_start, timeframe_end,
  date_precision, status, created_at
)
values
  ('aa000001-13a1-4111-8111-000000000001', (select parent_id from m13_ctx), (select author_id from m13_ctx), 'ord decade', '1960-01-01', '1969-12-31', 'decade', 'published', '2020-01-01'),
  ('aa000002-13a1-4111-8111-000000000002', (select parent_id from m13_ctx), (select author_id from m13_ctx), 'ord year early', '1960-01-01', '1960-12-31', 'year', 'published', '2020-01-01'),
  ('aa000003-13a1-4111-8111-000000000003', (select parent_id from m13_ctx), (select author_id from m13_ctx), 'ord year late', '1960-01-01', '1960-12-31', 'year', 'published', '2020-01-02'),
  ('aa000004-13a1-4111-8111-000000000004', (select parent_id from m13_ctx), (select author_id from m13_ctx), 'ord month', '1960-01-01', '1960-01-31', 'month', 'published', '2020-01-01'),
  ('aa000005-13a1-4111-8111-000000000005', (select parent_id from m13_ctx), (select author_id from m13_ctx), 'ord day', '1960-01-01', '1960-01-01', 'day', 'published', '2020-01-01');
alter table public.stories enable trigger stories_date_guard;

select is(
  (
    select array_agg(id order by timeframe_start, date_precision, created_at, id)
    from public.stories
    where id in (
      'aa000001-13a1-4111-8111-000000000001',
      'aa000002-13a1-4111-8111-000000000002',
      'aa000003-13a1-4111-8111-000000000003',
      'aa000004-13a1-4111-8111-000000000004',
      'aa000005-13a1-4111-8111-000000000005'
    )
  ),
  array[
    'aa000001-13a1-4111-8111-000000000001',
    'aa000002-13a1-4111-8111-000000000002',
    'aa000003-13a1-4111-8111-000000000003',
    'aa000004-13a1-4111-8111-000000000004',
    'aa000005-13a1-4111-8111-000000000005'
  ]::uuid[],
  'decade, year, month, and day sort by precision then created_at'
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';

set local request.jwt.claim.sub = 'c1300000-0000-4000-8000-0000000000c1';
select is(public.can_edit_story((select draft_id from m13_ctx)), true, 'the author can edit their draft');
select is(public.can_edit_story((select published_id from m13_ctx)), true, 'the author can edit their published story');

set local request.jwt.claim.sub = 'a1300000-0000-4000-8000-0000000000a1';
select is(public.can_edit_story((select published_id from m13_ctx)), true, 'the owner can edit a published story');
select is(public.can_edit_story((select draft_id from m13_ctx)), false, 'the owner cannot edit someone else''s draft');

set local request.jwt.claim.sub = 'b1300000-0000-4000-8000-0000000000b1';
select is(public.can_edit_story((select published_id from m13_ctx)), true, 'the co-owner can edit a published story');
select is(public.can_edit_story((select other_draft_id from m13_ctx)), false, 'the co-owner cannot edit someone else''s draft');

set local request.jwt.claim.sub = 'd1300000-0000-4000-8000-0000000000d1';
select is(public.can_edit_story((select published_id from m13_ctx)), false, 'a member cannot edit a story they did not write');

set local request.jwt.claim.sub = '61300000-0000-4000-8000-000000000061';
select is(public.can_edit_story((select published_id from m13_ctx)), false, 'a non-member cannot edit the story');

select set_config('request.jwt.claim.sub', '', true);
select is(public.can_edit_story((select published_id from m13_ctx)), false, 'a caller with no uid cannot edit the story');

set local request.jwt.claim.sub = 'e1300000-0000-4000-8000-0000000000e1';
select is(public.can_edit_story((select published_id from m13_ctx)), false, 'a child-family owner cannot edit the origin story');

-- Parent owner is not a member of a story on the soft-deleted family.
reset role;
select set_config('request.jwt.claim.sub', '', true);
insert into public.stories (
  id, family_id, author_id, title, timeframe_start, timeframe_end, date_precision, status
)
select
  'bbbbbbb1-13a1-4111-8111-bbbbbbbbbbb1',
  dead_id,
  outsider_id,
  'Dead story',
  '1984-01-01',
  '1984-01-01',
  'day',
  'published'
from m13_ctx;

set local role authenticated;
set local request.jwt.claim.sub = '61300000-0000-4000-8000-000000000061';
set local request.jwt.claim.role = 'authenticated';
select is(
  public.can_edit_story('bbbbbbb1-13a1-4111-8111-bbbbbbbbbbb1'),
  false,
  'nobody can edit a story in a soft-deleted family'
);

select is(
  public.can_edit_story('00000000-0000-4000-8000-000000000099'),
  false,
  'a missing story is not editable'
);

set local request.jwt.claim.sub = 'a1300000-0000-4000-8000-0000000000a1';
select throws_ok(
  $$update public.stories set status = 'draft' where id = (select published_id from m13_ctx)$$,
  'P0001',
  'FORBIDDEN: field is locked',
  'a non-author editor cannot change status'
);
select throws_ok(
  $$update public.stories set published_at = '2000-01-01 00:00:00+00'
    where id = (select published_id from m13_ctx)$$,
  'P0001',
  'FORBIDDEN: field is locked',
  'a non-author editor cannot change published_at'
);
select throws_ok(
  $$update public.stories set author_id = (select owner_id from m13_ctx) where id = (select published_id from m13_ctx)$$,
  'P0001',
  'FORBIDDEN: field is locked',
  'changing author_id is locked'
);

select lives_ok(
  $$update public.stories
    set title = 'Owner edit', body = 'owner body',
        timeframe_start = '1987-01-01', timeframe_end = '1987-12-31',
        date_precision = 'year'
    where id = (select published_id from m13_ctx)$$,
  'an owner can edit title, body, and date on a published story'
);

select lives_ok(
  $$insert into public.story_people (story_id, person_id)
    select published_id, person_id from m13_ctx$$,
  'an editor can insert story_people'
);
select lives_ok(
  $$update public.story_people set person_id = (select person_id from m13_ctx)
    where story_id = (select published_id from m13_ctx)$$,
  'an editor can update story_people'
);
select throws_ok(
  $$insert into public.story_people (story_id, person_id)
    select published_id, other_person_id from m13_ctx$$,
  '42501',
  'new row violates row-level security policy for table "story_people"',
  'a cross-family person link is rejected'
);
select lives_ok(
  $$delete from public.story_people where story_id = (select published_id from m13_ctx)$$,
  'an editor can delete story_people'
);

set local request.jwt.claim.sub = 'f1300000-0000-4000-8000-0000000000f1';
insert into public.photos (id, story_id, family_id, uploader_id, storage_path)
select photo_id, published_id, parent_id, child_member_id,
       parent_id::text || '/' || published_id::text || '/' || photo_id::text || '.jpg'
from m13_ctx;
insert into storage.objects (bucket_id, name, owner_id)
select 'story-photos',
       parent_id::text || '/' || published_id::text || '/' || photo_id::text || '.jpg',
       child_member_id::text
from m13_ctx;
insert into public.photos (id, story_id, family_id, uploader_id, storage_path)
select photo2_id, published_id, parent_id, child_member_id,
       parent_id::text || '/' || published_id::text || '/' || photo2_id::text || '.jpg'
from m13_ctx;
insert into storage.objects (bucket_id, name, owner_id)
select 'story-photos',
       parent_id::text || '/' || published_id::text || '/' || photo2_id::text || '.jpg',
       child_member_id::text
from m13_ctx;

set local request.jwt.claim.sub = 'a1300000-0000-4000-8000-0000000000a1';
select set_config('storage.allow_delete_query', 'true', true);
delete from public.photos where id = (select photo_id from m13_ctx);
delete from storage.objects
where bucket_id = 'story-photos'
  and name = (
    select parent_id::text || '/' || published_id::text || '/' || photo_id::text || '.jpg'
    from m13_ctx
  );
select is(
  (select count(*) from public.photos where id = (select photo_id from m13_ctx)),
  0::bigint,
  'a parent owner deletes the child member photo row'
);
select is(
  (select count(*) from storage.objects
    where name like '%' || (select photo_id::text from m13_ctx) || '%'),
  0::bigint,
  'a parent owner deletes the child member storage object'
);

set local request.jwt.claim.sub = 'b1300000-0000-4000-8000-0000000000b1';
delete from public.photos where id = (select photo2_id from m13_ctx);
delete from storage.objects
where bucket_id = 'story-photos'
  and name = (
    select parent_id::text || '/' || published_id::text || '/' || photo2_id::text || '.jpg'
    from m13_ctx
  );
select is(
  (select count(*) from public.photos where id = (select photo2_id from m13_ctx)),
  0::bigint,
  'a parent co-owner deletes the child member photo row'
);
select is(
  (select count(*) from storage.objects
    where name like '%' || (select photo2_id::text from m13_ctx) || '%'),
  0::bigint,
  'a parent co-owner deletes the child member storage object'
);

-- Recreate one object so the child owner is denied.
reset role;
select set_config('request.jwt.claim.sub', '', true);
insert into public.photos (id, story_id, family_id, uploader_id, storage_path)
select photo_id, published_id, parent_id, child_member_id,
       parent_id::text || '/' || published_id::text || '/' || photo_id::text || '.jpg'
from m13_ctx;
insert into storage.objects (bucket_id, name, owner_id)
select 'story-photos',
       parent_id::text || '/' || published_id::text || '/' || photo_id::text || '.jpg',
       child_member_id::text
from m13_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'e1300000-0000-4000-8000-0000000000e1';
set local request.jwt.claim.role = 'authenticated';
select set_config('storage.allow_delete_query', 'true', true);
delete from public.photos where id = (select photo_id from m13_ctx);
delete from storage.objects
where bucket_id = 'story-photos'
  and name = (
    select parent_id::text || '/' || published_id::text || '/' || photo_id::text || '.jpg'
    from m13_ctx
  );
update public.stories set title = 'child tried' where id = (select published_id from m13_ctx);

select is(
  (select count(*) from public.photos where id = (select photo_id from m13_ctx)),
  1::bigint,
  'a child-timeline owner deletes 0 photo rows'
);
select is(
  (select count(*) from storage.objects
    where name like '%' || (select photo_id::text from m13_ctx) || '%'),
  1::bigint,
  'a child-timeline owner deletes 0 storage objects'
);
select is(
  (select title from public.stories where id = (select published_id from m13_ctx)),
  'Owner edit',
  'a child-timeline owner cannot update the origin story'
);

set local request.jwt.claim.sub = '61300000-0000-4000-8000-000000000061';
select is(
  public.can_contribute_to_story(
    (select parent_id from m13_ctx),
    (select published_id from m13_ctx)
  ),
  false,
  'can_contribute_to_story still denies an outsider'
);

set local request.jwt.claim.sub = 'c1300000-0000-4000-8000-0000000000c1';
select throws_ok(
  $$update public.photos set storage_path = 'nope'
    where id = (select photo_id from m13_ctx)$$,
  'P0001',
  'FORBIDDEN: field is locked',
  'photos_guard_update still locks columns other than sort_order'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
insert into public.photos (story_id, family_id, uploader_id, storage_path, sort_order)
select published_id, parent_id, author_id, 'pad/' || g || '.jpg', g
from m13_ctx
cross join generate_series(1, 19) as g;

set local role authenticated;
set local request.jwt.claim.sub = 'c1300000-0000-4000-8000-0000000000c1';
set local request.jwt.claim.role = 'authenticated';
select throws_ok(
  $$insert into public.photos (story_id, family_id, uploader_id, storage_path)
    select published_id, parent_id, author_id, 'pad/over.jpg' from m13_ctx$$,
  'P0001',
  'VALIDATION: photo limit reached',
  'the 20-photo cap still holds'
);

select is(
  (select proconfig from pg_proc where proname = 'can_edit_story'),
  array['search_path=""']::text[],
  'can_edit_story has an empty search_path'
);
select lives_ok(
  $$select public.can_edit_story('00000000-0000-4000-8000-000000000000')$$,
  'can_edit_story is called once with no missing-function error'
);

set local role anon;
select throws_ok(
  $$select public.can_edit_story('00000000-0000-4000-8000-000000000000')$$,
  '42501',
  null,
  'anon cannot execute can_edit_story'
);

reset role;
select is(
  (select count(*)::int from pg_policies),
  44,
  'policy count is 44'
);

select is(
  coalesce((select qual from pg_policies where policyname = 'stories_update_editor'), ''),
  'can_edit_story(id)',
  'stories_update_editor qual'
);
select is(
  coalesce((select with_check from pg_policies where policyname = 'stories_update_editor'), ''),
  'can_edit_story(id)',
  'stories_update_editor with_check'
);
select is(
  coalesce((select qual from pg_policies where policyname = 'story_people_insert_editor'), ''),
  '',
  'story_people_insert_editor qual'
);
select is(
  coalesce((select with_check from pg_policies where policyname = 'story_people_insert_editor'), ''),
  $pol$(can_edit_story(story_id) AND (EXISTS ( SELECT 1
   FROM (people p
     JOIN stories s ON ((s.id = story_people.story_id)))
  WHERE ((p.id = story_people.person_id) AND (p.family_id = s.family_id)))))$pol$,
  'story_people_insert_editor with_check'
);
select is(
  coalesce((select qual from pg_policies where policyname = 'story_people_update_editor'), ''),
  'can_edit_story(story_id)',
  'story_people_update_editor qual'
);
select is(
  coalesce((select with_check from pg_policies where policyname = 'story_people_update_editor'), ''),
  $pol$(can_edit_story(story_id) AND (EXISTS ( SELECT 1
   FROM (people p
     JOIN stories s ON ((s.id = story_people.story_id)))
  WHERE ((p.id = story_people.person_id) AND (p.family_id = s.family_id)))))$pol$,
  'story_people_update_editor with_check'
);
select is(
  coalesce((select qual from pg_policies where policyname = 'story_people_delete_editor'), ''),
  'can_edit_story(story_id)',
  'story_people_delete_editor qual'
);
select is(
  coalesce((select with_check from pg_policies where policyname = 'story_people_delete_editor'), ''),
  '',
  'story_people_delete_editor with_check'
);
select is(
  coalesce((select qual from pg_policies where policyname = 'photos_update_uploader_or_author'), ''),
  $pol$(can_contribute_to_story(family_id, story_id) AND ((uploader_id = ( SELECT auth.uid() AS uid)) OR can_edit_story(story_id)))$pol$,
  'photos_update_uploader_or_author qual'
);
select is(
  coalesce((select with_check from pg_policies where policyname = 'photos_update_uploader_or_author'), ''),
  $pol$(can_contribute_to_story(family_id, story_id) AND ((uploader_id = ( SELECT auth.uid() AS uid)) OR can_edit_story(story_id)) AND (EXISTS ( SELECT 1
   FROM stories s
  WHERE ((s.id = photos.story_id) AND (s.family_id = photos.family_id)))))$pol$,
  'photos_update_uploader_or_author with_check'
);
select is(
  coalesce((select qual from pg_policies where policyname = 'photos_delete_uploader_or_author'), ''),
  $pol$(((uploader_id = ( SELECT auth.uid() AS uid)) OR can_edit_story(story_id)) AND (is_family_member(family_id) OR can_contribute_to_story(family_id, story_id)))$pol$,
  'photos_delete_uploader_or_author qual'
);
select is(
  coalesce((select with_check from pg_policies where policyname = 'photos_delete_uploader_or_author'), ''),
  '',
  'photos_delete_uploader_or_author with_check'
);

select * from finish();
rollback;
