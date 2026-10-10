-- M12 security amendments: same-family child rows, safe storage casts,
-- and live membership. Runs in a transaction and rolls back.

begin;
create extension if not exists pgtap with schema extensions;

select plan(16);

create temporary table m12g_ctx (
  user_a uuid primary key,
  user_b uuid not null,
  user_c uuid not null,
  home_id uuid,
  other_id uuid,
  gone_id uuid,
  child_id uuid,
  home_story uuid,
  other_person uuid,
  gone_story uuid,
  gone_draft uuid,
  child_story uuid
);

grant all on table m12g_ctx to authenticated, anon, service_role;

insert into m12g_ctx (user_a, user_b, user_c)
values (
  'a3300000-0000-4000-8000-00000000000a',
  'b3300000-0000-4000-8000-00000000000b',
  'c3300000-0000-4000-8000-00000000000c'
);

insert into auth.users (id, email, raw_user_meta_data)
select user_a, 'm12g-a@test.local', '{"display_name":"M12G A"}'::jsonb from m12g_ctx
union all
select user_b, 'm12g-b@test.local', '{"display_name":"M12G B"}'::jsonb from m12g_ctx
union all
select user_c, 'm12g-c@test.local', '{"display_name":"M12G C"}'::jsonb from m12g_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a3300000-0000-4000-8000-00000000000a';
set local request.jwt.claim.role = 'authenticated';

update m12g_ctx set home_id = (public.create_family('Home')).id;
update m12g_ctx set other_id = (public.create_family('Other')).id;
update m12g_ctx set gone_id = (public.create_family('Gone')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.memberships (family_id, user_id, role)
select home_id, user_b, 'member'::public.membership_role from m12g_ctx
union all
select gone_id, user_b, 'member'::public.membership_role from m12g_ctx;

with inserted as (
  insert into public.families (name, created_by, parent_family_id)
  select 'Child', user_c, home_id from m12g_ctx
  returning id
)
update m12g_ctx
set child_id = inserted.id
from inserted;

insert into public.memberships (family_id, user_id, role)
select child_id, user_c, 'owner'::public.membership_role from m12g_ctx;

insert into public.stories (id, family_id, author_id, title, timeframe_start, status)
select
  '11111111-3333-4333-8333-111111111111',
  home_id,
  user_a,
  'Home tale',
  '1980-01-01',
  'published'
from m12g_ctx;

update m12g_ctx set home_story = '11111111-3333-4333-8333-111111111111';

insert into public.stories (id, family_id, author_id, title, timeframe_start, status)
select
  '44444444-3333-4333-8333-444444444444',
  child_id,
  user_c,
  'Child tale',
  '1981-01-01',
  'published'
from m12g_ctx;

update m12g_ctx set child_story = '44444444-3333-4333-8333-444444444444';

insert into public.stories (id, family_id, author_id, title, timeframe_start, status)
select
  '55555555-3333-4333-8333-555555555555',
  gone_id,
  user_a,
  'Gone published',
  '1982-01-01',
  'published'
from m12g_ctx;

insert into public.stories (id, family_id, author_id, title, timeframe_start, status)
select
  '66666666-3333-4333-8333-666666666666',
  gone_id,
  user_a,
  'Gone draft',
  '1983-01-01',
  'draft'
from m12g_ctx;

update m12g_ctx
set
  gone_story = '55555555-3333-4333-8333-555555555555',
  gone_draft = '66666666-3333-4333-8333-666666666666';

insert into public.people (id, family_id, name, relationship, created_by)
select
  '22222222-3333-4333-8333-222222222222',
  other_id,
  'Other person',
  'Cousin',
  user_a
from m12g_ctx;

update m12g_ctx set other_person = '22222222-3333-4333-8333-222222222222';

insert into public.people (family_id, name, relationship, created_by)
select gone_id, 'Gone person', 'Sibling', user_a from m12g_ctx;

insert into public.photos (story_id, family_id, uploader_id, storage_path)
select gone_story, gone_id, user_a, 'gone/photo.jpg' from m12g_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a3300000-0000-4000-8000-00000000000a';
set local request.jwt.claim.role = 'authenticated';

select throws_ok(
  $$
    insert into public.story_people (story_id, person_id)
    select home_story, other_person from m12g_ctx
  $$,
  '42501',
  'new row violates row-level security policy for table "story_people"',
  'a cross-family person link is rejected'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select throws_ok(
  $$
    insert into public.story_people (story_id, person_id)
    select home_story, other_person from m12g_ctx
  $$,
  'P0001',
  'FORBIDDEN: person is not in this family',
  'ensure_story_person_membership rejects a cross-family person'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a3300000-0000-4000-8000-00000000000a';
set local request.jwt.claim.role = 'authenticated';

select throws_ok(
  $$
    insert into public.photos (story_id, family_id, uploader_id, storage_path)
    select home_story, other_id, user_a, 'mismatch.jpg' from m12g_ctx
  $$,
  '42501',
  'new row violates row-level security policy for table "photos"',
  'a photo with a mismatched family_id is rejected'
);

select throws_ok(
  $$
    insert into public.comments (story_id, family_id, author_id, body)
    select home_story, other_id, user_a, 'no' from m12g_ctx
  $$,
  '42501',
  'new row violates row-level security policy for table "comments"',
  'a comment with a mismatched family_id is rejected'
);

select throws_ok(
  $$
    insert into public.perspectives (story_id, family_id, author_id, body)
    select home_story, other_id, user_a, 'no' from m12g_ctx
  $$,
  '42501',
  'new row violates row-level security policy for table "perspectives"',
  'a perspective with a mismatched family_id is rejected'
);

select throws_ok(
  $$
    insert into storage.objects (bucket_id, name, owner_id)
    select
      'story-photos',
      home_id::text || '/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/x.jpg',
      user_a::text
    from m12g_ctx
  $$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'a storage path whose second folder is not a story is rejected'
);

select throws_ok(
  $$
    insert into storage.objects (bucket_id, name, owner_id)
    select
      'story-photos',
      home_id::text || '/' || home_story::text || '/extra/x.jpg',
      user_a::text
    from m12g_ctx
  $$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'a three-folder storage path is rejected'
);

select throws_ok(
  $$
    insert into storage.objects (bucket_id, name, owner_id)
    select
      'story-photos',
      home_id::text || '/not-a-uuid/x.jpg',
      user_a::text
    from m12g_ctx
  $$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'a non-uuid storage path is rejected without a cast error'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into storage.objects (bucket_id, name, owner_id)
select
  'story-photos',
  child_id::text || '/not-a-uuid/x.jpg',
  user_c::text
from m12g_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a3300000-0000-4000-8000-00000000000a';
set local request.jwt.claim.role = 'authenticated';

select lives_ok(
  $$
    select *
    from storage.objects
    where bucket_id = 'story-photos'
      and name = (
        select child_id::text || '/not-a-uuid/x.jpg' from m12g_ctx
      )
  $$,
  'a tree reader can select a non-uuid storage path without an error'
);

select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'story-photos'
      and name = (
        select child_id::text || '/not-a-uuid/x.jpg' from m12g_ctx
      )
  ),
  0::bigint,
  'a tree reader sees 0 rows for a non-uuid storage path'
);

update public.families
set deleted_at = now()
where id = (select gone_id from m12g_ctx);

set local request.jwt.claim.sub = 'b3300000-0000-4000-8000-00000000000b';

select is(
  (select count(*) from public.stories where family_id = (select gone_id from m12g_ctx)),
  0::bigint,
  'a member of a soft-deleted family reads 0 stories, drafts included'
);
select is(
  (select count(*) from public.people where family_id = (select gone_id from m12g_ctx)),
  0::bigint,
  'a member of a soft-deleted family reads 0 people'
);
select is(
  (select count(*) from public.photos where family_id = (select gone_id from m12g_ctx)),
  0::bigint,
  'a member of a soft-deleted family reads 0 photos'
);

set local request.jwt.claim.sub = 'a3300000-0000-4000-8000-00000000000a';

select is(
  (select count(*) from public.families where id = (select gone_id from m12g_ctx)),
  1::bigint,
  'the owner still reads the soft-deleted family row'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

select is(
  public.is_live_family_member((select home_id from m12g_ctx)),
  false,
  'a call with no uid returns false'
);
select is(
  (select count(*) from public.stories),
  0::bigint,
  'a call with no uid returns 0 story rows'
);

select * from finish();
rollback;
