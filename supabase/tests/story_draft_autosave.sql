-- M14.4 autosave drafts. Null dates on drafts, publish still needs a date,
-- and a draft is visible only to its author until it is published.
-- Runs in a transaction and rolls back.

begin;
create extension if not exists pgtap with schema extensions;

select plan(37);

create temporary table m14_ctx (
  author_id uuid primary key,
  owner_id uuid not null,
  co_owner_id uuid not null,
  member_id uuid not null,
  parent_user_id uuid not null,
  parent_id uuid,
  child_id uuid,
  null_id uuid not null,
  full_id uuid not null,
  kept_id uuid not null,
  vis_id uuid not null,
  hidden_id uuid not null,
  person_id uuid not null,
  comment_id uuid not null,
  perspective_id uuid not null,
  photo_id uuid not null
);

grant all on table m14_ctx to authenticated, anon, service_role;

insert into m14_ctx (
  author_id, owner_id, co_owner_id, member_id, parent_user_id,
  null_id, full_id, kept_id, vis_id, hidden_id,
  person_id, comment_id, perspective_id, photo_id
) values (
  'a14a0000-0000-4000-8000-0000000000a1',
  'a14b0000-0000-4000-8000-0000000000b1',
  'a14c0000-0000-4000-8000-0000000000c1',
  'a14d0000-0000-4000-8000-0000000000d1',
  'a14e0000-0000-4000-8000-0000000000e1',
  'a1400001-0000-4000-8000-000000000001',
  'a1400002-0000-4000-8000-000000000002',
  'a1400003-0000-4000-8000-000000000003',
  'a1400004-0000-4000-8000-000000000004',
  'a1400005-0000-4000-8000-000000000005',
  'a1400006-0000-4000-8000-000000000006',
  'a1400007-0000-4000-8000-000000000007',
  'a1400008-0000-4000-8000-000000000008',
  'a1400009-0000-4000-8000-000000000009'
);

insert into auth.users (id, email, raw_user_meta_data)
select author_id, 'm14-author@test.local', '{"display_name":"Author"}'::jsonb from m14_ctx
union all
select owner_id, 'm14-owner@test.local', '{"display_name":"Owner"}'::jsonb from m14_ctx
union all
select co_owner_id, 'm14-co@test.local', '{"display_name":"Co-owner"}'::jsonb from m14_ctx
union all
select member_id, 'm14-member@test.local', '{"display_name":"Member"}'::jsonb from m14_ctx
union all
select parent_user_id, 'm14-parent@test.local', '{"display_name":"Parent"}'::jsonb from m14_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a14e0000-0000-4000-8000-0000000000e1';
set local request.jwt.claim.role = 'authenticated';

update m14_ctx set parent_id = (public.create_family('M14 Parent')).id;

set local request.jwt.claim.sub = 'a14b0000-0000-4000-8000-0000000000b1';

update m14_ctx set child_id = (public.create_family('M14 Child')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

update public.families f
set parent_family_id = c.parent_id, branch_year = 1972
from m14_ctx c
where f.id = c.child_id;

insert into public.memberships (family_id, user_id, role)
select child_id, author_id, 'member'::public.membership_role from m14_ctx
union all
select child_id, co_owner_id, 'member'::public.membership_role from m14_ctx
union all
select child_id, member_id, 'member'::public.membership_role from m14_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a14b0000-0000-4000-8000-0000000000b1';
set local request.jwt.claim.role = 'authenticated';

select public.add_co_owner(
  (select child_id from m14_ctx),
  (select co_owner_id from m14_ctx)
);

set local request.jwt.claim.sub = 'a14a0000-0000-4000-8000-0000000000a1';

select lives_ok(
  $$insert into public.stories (
      id, family_id, author_id, title, body,
      timeframe_start, timeframe_end, date_precision, status
    )
    select
      null_id, child_id, author_id, 'Undated', 'Still writing',
      null, null, null, 'draft'::public.story_status
    from m14_ctx$$,
  'a draft insert with null dates succeeds'
);

select is(
  (select timeframe_start from public.stories where id = (select null_id from m14_ctx)),
  null::date,
  'the null draft keeps a null timeframe_start'
);

select throws_ok(
  $$update public.stories
    set status = 'published'::public.story_status, published_at = now()
    where id = (select null_id from m14_ctx)$$,
  '23514',
  'new row for relation "stories" violates check constraint "stories_published_needs_date"',
  'publishing a draft with a null date fails on stories_published_needs_date'
);

select lives_ok(
  $$insert into public.stories (
      id, family_id, author_id, title, body,
      timeframe_start, timeframe_end, date_precision, status
    )
    select
      full_id, child_id, author_id, 'Dated', 'Ready',
      '1980-06-01'::date, '1980-06-01'::date, 'day'::public.story_date_precision,
      'draft'::public.story_status
    from m14_ctx$$,
  'a dated draft insert succeeds'
);

select lives_ok(
  $$update public.stories
    set status = 'published'::public.story_status, published_at = now()
    where id = (select full_id from m14_ctx)$$,
  'publishing with all dates set succeeds'
);

select is(
  (select status from public.stories where id = (select full_id from m14_ctx)),
  'published'::public.story_status,
  'the dated draft is published'
);

select lives_ok(
  $$insert into public.stories (
      id, family_id, author_id, title, body,
      timeframe_start, timeframe_end, date_precision, status, published_at
    )
    select
      kept_id, child_id, author_id, 'Kept', 'Already out',
      '1972-04-01'::date, '1972-04-01'::date, 'day'::public.story_date_precision,
      'published'::public.story_status, now()
    from m14_ctx$$,
  'an already published row with dates still inserts'
);

select is(
  (select timeframe_start from public.stories where id = (select kept_id from m14_ctx)),
  '1972-04-01'::date,
  'an existing published row keeps its start date'
);
select is(
  (select timeframe_end from public.stories where id = (select kept_id from m14_ctx)),
  '1972-04-01'::date,
  'an existing published row keeps its end date'
);
select is(
  (select date_precision from public.stories where id = (select kept_id from m14_ctx)),
  'day'::public.story_date_precision,
  'an existing published row keeps its date precision'
);

select lives_ok(
  $$insert into public.stories (
      id, family_id, author_id, title, body,
      timeframe_start, timeframe_end, date_precision, status
    )
    select
      vis_id, child_id, author_id, 'Visible to author', 'Draft body',
      '1991-03-02'::date, '1991-03-02'::date, 'day'::public.story_date_precision,
      'draft'::public.story_status
    from m14_ctx$$,
  'the visibility draft inserts'
);

select lives_ok(
  $$insert into public.stories (
      id, family_id, author_id, title,
      timeframe_start, timeframe_end, date_precision, status
    )
    select
      hidden_id, child_id, author_id, 'Stays a draft',
      '1994-01-01'::date, '1994-12-31'::date, 'year'::public.story_date_precision,
      'draft'::public.story_status
    from m14_ctx$$,
  'a second draft stays unpublished'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.people (id, family_id, name, created_by)
select person_id, child_id, 'Ada', author_id from m14_ctx;

insert into public.comments (id, story_id, family_id, author_id, body)
select comment_id, vis_id, child_id, author_id, 'author note' from m14_ctx;

insert into public.perspectives (id, story_id, family_id, author_id, body)
select perspective_id, vis_id, child_id, author_id, 'author view' from m14_ctx;

insert into public.photos (id, story_id, family_id, uploader_id, storage_path)
select
  photo_id, vis_id, child_id, author_id,
  child_id::text || '/' || vis_id::text || '/' || photo_id::text || '.jpg'
from m14_ctx;

insert into public.story_people (story_id, person_id)
select vis_id, person_id from m14_ctx;

insert into storage.objects (bucket_id, name, owner_id)
select
  'story-photos',
  child_id::text || '/' || vis_id::text || '/' || photo_id::text || '.jpg',
  author_id::text
from m14_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a14a0000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

select is(
  (select count(*)::int from public.stories where id = (select vis_id from m14_ctx)),
  1,
  'the author sees their own draft'
);
select is(
  (select count(*)::int from public.comments where id = (select comment_id from m14_ctx)),
  1,
  'the author sees a comment on their draft'
);
select is(
  (select count(*)::int from public.perspectives where id = (select perspective_id from m14_ctx)),
  1,
  'the author sees a perspective on their draft'
);
select is(
  (select count(*)::int from public.photos where id = (select photo_id from m14_ctx)),
  1,
  'the author sees a photo row on their draft'
);
select is(
  (select count(*)::int from public.story_people where story_id = (select vis_id from m14_ctx)),
  1,
  'the author sees story_people on their draft'
);
select is(
  (select count(*)::int from storage.objects
    where bucket_id = 'story-photos'
      and name = (
        select child_id::text || '/' || vis_id::text || '/' || photo_id::text || '.jpg'
        from m14_ctx
      )),
  1,
  'the author sees the draft photo object'
);

set local request.jwt.claim.sub = 'a14d0000-0000-4000-8000-0000000000d1';

select is(
  (select count(*)::int from public.stories where id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.comments where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.perspectives where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.photos where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.story_people where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from storage.objects
      where name = (
        select child_id::text || '/' || vis_id::text || '/' || photo_id::text || '.jpg'
        from m14_ctx
      )),
  0,
  'a non-author live member sees none of a draft'
);

set local request.jwt.claim.sub = 'a14b0000-0000-4000-8000-0000000000b1';

select is(
  (select count(*)::int from public.stories where id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.comments where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.perspectives where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.photos where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.story_people where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from storage.objects
      where name = (
        select child_id::text || '/' || vis_id::text || '/' || photo_id::text || '.jpg'
        from m14_ctx
      )),
  0,
  'an owner sees none of someone else''s draft'
);

set local request.jwt.claim.sub = 'a14c0000-0000-4000-8000-0000000000c1';

select is(
  (select count(*)::int from public.stories where id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.comments where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.perspectives where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.photos where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.story_people where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from storage.objects
      where name = (
        select child_id::text || '/' || vis_id::text || '/' || photo_id::text || '.jpg'
        from m14_ctx
      )),
  0,
  'a co-owner sees none of someone else''s draft'
);

set local request.jwt.claim.sub = 'a14e0000-0000-4000-8000-0000000000e1';

select is(
  (select count(*)::int from public.stories where id = (select kept_id from m14_ctx)),
  1,
  'a tree-readable non-member sees a published story'
);
select is(
  (select count(*)::int from public.stories where id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.stories where id = (select hidden_id from m14_ctx)),
  0,
  'a tree-readable non-member sees published stories only'
);

set local request.jwt.claim.sub = 'a14d0000-0000-4000-8000-0000000000d1';

select throws_ok(
  $$insert into public.comments (id, story_id, family_id, author_id, body)
    select
      'a140000a-0000-4000-8000-00000000000a',
      vis_id, child_id, member_id, 'not the author'
    from m14_ctx$$,
  '42501',
  null,
  'a non-author member cannot insert a comment on a draft'
);
select throws_ok(
  $$insert into public.perspectives (id, story_id, family_id, author_id, body)
    select
      'a140000b-0000-4000-8000-00000000000b',
      vis_id, child_id, member_id, 'not the author'
    from m14_ctx$$,
  '42501',
  null,
  'a non-author member cannot insert a perspective on a draft'
);
select throws_ok(
  $$insert into public.photos (id, story_id, family_id, uploader_id, storage_path)
    select
      'a140000c-0000-4000-8000-00000000000c',
      vis_id, child_id, member_id,
      child_id::text || '/' || vis_id::text || '/a140000c-0000-4000-8000-00000000000c.jpg'
    from m14_ctx$$,
  '42501',
  null,
  'a non-author member cannot insert a photo on a draft'
);
select throws_ok(
  $$insert into public.story_people (story_id, person_id)
    select vis_id, person_id from m14_ctx$$,
  '42501',
  null,
  'a non-author member cannot insert story_people on a draft'
);

set local request.jwt.claim.sub = 'a14b0000-0000-4000-8000-0000000000b1';

select throws_ok(
  $$insert into public.comments (id, story_id, family_id, author_id, body)
    select
      'a140000d-0000-4000-8000-00000000000d',
      vis_id, child_id, owner_id, 'owner note'
    from m14_ctx$$,
  '42501',
  null,
  'an owner cannot insert a comment on someone else''s draft'
);

set local request.jwt.claim.sub = 'a14a0000-0000-4000-8000-0000000000a1';

select lives_ok(
  $$update public.stories
    set status = 'published'::public.story_status, published_at = now()
    where id = (select vis_id from m14_ctx)$$,
  'the author can publish the visibility draft'
);

set local request.jwt.claim.sub = 'a14d0000-0000-4000-8000-0000000000d1';

select is(
  (select count(*)::int from public.stories where id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.comments where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.perspectives where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.photos where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.story_people where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from storage.objects
      where name = (
        select child_id::text || '/' || vis_id::text || '/' || photo_id::text || '.jpg'
        from m14_ctx
      )),
  6,
  'after publish a live member sees the story and its rows'
);

set local request.jwt.claim.sub = 'a14b0000-0000-4000-8000-0000000000b1';

select is(
  (select count(*)::int from public.stories where id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.comments where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.perspectives where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.photos where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.story_people where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from storage.objects
      where name = (
        select child_id::text || '/' || vis_id::text || '/' || photo_id::text || '.jpg'
        from m14_ctx
      )),
  6,
  'after publish the owner sees the story and its rows'
);

set local request.jwt.claim.sub = 'a14c0000-0000-4000-8000-0000000000c1';

select is(
  (select count(*)::int from public.stories where id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.comments where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.perspectives where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.photos where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from public.story_people where story_id = (select vis_id from m14_ctx))
  + (select count(*)::int from storage.objects
      where name = (
        select child_id::text || '/' || vis_id::text || '/' || photo_id::text || '.jpg'
        from m14_ctx
      )),
  6,
  'after publish a co-owner sees the story and its rows'
);

set local request.jwt.claim.sub = 'a14e0000-0000-4000-8000-0000000000e1';

select is(
  (select count(*)::int from public.stories where id = (select hidden_id from m14_ctx)),
  0,
  'a tree-readable non-member still cannot see an unpublished draft'
);
select is(
  (select count(*)::int from public.stories where id = (select vis_id from m14_ctx)),
  1,
  'a tree-readable non-member sees the draft once it is published'
);

select is(
  (select timeframe_start from public.stories where id = (select kept_id from m14_ctx)),
  '1972-04-01'::date,
  'publishing other rows leaves an existing published date in place'
);

reset role;

select is(
  (select count(*)::int from pg_policies),
  47,
  'policy count is 47'
);

select is(
  (
    select count(*)::int
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and pg_catalog.has_function_privilege('authenticated', p.oid, 'execute')
  ),
  29,
  'the definer allowlist is 29'
);

select * from finish();
rollback;
