-- #42 cleanup, TMAS-40-02: author-only draft writes (Gilfoyle, LOCKED 2026-10-19).
-- Runs in a transaction and rolls back.

begin;
create extension if not exists pgtap with schema extensions;

select plan(43);

create temporary table m42_ctx (
  author_id uuid primary key,
  member_id uuid not null,
  owner_id uuid not null,
  co_owner_id uuid not null,
  reader_id uuid not null,
  k_owner_id uuid not null,
  parent_id uuid,
  child_id uuid,
  k_family_id uuid,
  draft_id uuid not null,
  published_id uuid not null,
  person_id uuid not null,
  person2_id uuid not null,
  comment_b_id uuid not null,
  perspective_b_id uuid not null,
  photo_b_id uuid not null,
  comment_a_id uuid not null,
  perspective_a_id uuid not null,
  photo_a_id uuid not null,
  comment_p_id uuid not null,
  photo_p_id uuid not null
);

grant all on table m42_ctx to authenticated, anon, service_role;

insert into m42_ctx (
  author_id, member_id, owner_id, co_owner_id, reader_id, k_owner_id,
  draft_id, published_id, person_id, person2_id,
  comment_b_id, perspective_b_id, photo_b_id,
  comment_a_id, perspective_a_id, photo_a_id,
  comment_p_id, photo_p_id
) values (
  'a4200000-0000-4000-8000-0000000000a1',
  'a4200000-0000-4000-8000-0000000000a2',
  'a4200000-0000-4000-8000-0000000000a3',
  'a4200000-0000-4000-8000-0000000000a4',
  'a4200000-0000-4000-8000-0000000000a5',
  'a4200000-0000-4000-8000-0000000000a6',
  'a4200000-0000-4000-8000-0000000000b1',
  'a4200000-0000-4000-8000-0000000000b2',
  'a4200000-0000-4000-8000-0000000000c1',
  'a4200000-0000-4000-8000-0000000000c2',
  'a4200000-0000-4000-8000-0000000000d1',
  'a4200000-0000-4000-8000-0000000000d2',
  'a4200000-0000-4000-8000-0000000000d3',
  'a4200000-0000-4000-8000-0000000000d4',
  'a4200000-0000-4000-8000-0000000000d5',
  'a4200000-0000-4000-8000-0000000000d6',
  'a4200000-0000-4000-8000-0000000000e1',
  'a4200000-0000-4000-8000-0000000000e2'
);

insert into auth.users (id, email, raw_user_meta_data)
select author_id, 'm42-author@test.local', '{"display_name":"Author"}'::jsonb from m42_ctx
union all
select member_id, 'm42-member@test.local', '{"display_name":"Member"}'::jsonb from m42_ctx
union all
select owner_id, 'm42-owner@test.local', '{"display_name":"Owner"}'::jsonb from m42_ctx
union all
select co_owner_id, 'm42-co@test.local', '{"display_name":"Co-owner"}'::jsonb from m42_ctx
union all
select reader_id, 'm42-reader@test.local', '{"display_name":"Reader"}'::jsonb from m42_ctx
union all
select k_owner_id, 'm42-k@test.local', '{"display_name":"K"}'::jsonb from m42_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a4200000-0000-4000-8000-0000000000a5';
set local request.jwt.claim.role = 'authenticated';

update m42_ctx set parent_id = (public.create_family('M42 Parent')).id;

set local request.jwt.claim.sub = 'a4200000-0000-4000-8000-0000000000a3';

update m42_ctx set child_id = (public.create_family('M42 Child')).id;

set local request.jwt.claim.sub = 'a4200000-0000-4000-8000-0000000000a6';

update m42_ctx set k_family_id = (public.create_family('M42 K')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

update public.families f
set parent_family_id = c.parent_id, branch_year = 1972
from m42_ctx c
where f.id = c.child_id;

update public.families f
set parent_family_id = c.child_id, branch_year = 1990
from m42_ctx c
where f.id = c.k_family_id;

insert into public.memberships (family_id, user_id, role)
select child_id, author_id, 'member'::public.membership_role from m42_ctx
union all
select child_id, member_id, 'member'::public.membership_role from m42_ctx
union all
select child_id, co_owner_id, 'member'::public.membership_role from m42_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a4200000-0000-4000-8000-0000000000a3';
set local request.jwt.claim.role = 'authenticated';

select public.add_co_owner(
  (select child_id from m42_ctx),
  (select co_owner_id from m42_ctx)
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.stories (id, family_id, author_id, title, status)
select draft_id, child_id, author_id, 'Draft', 'draft'::public.story_status
from m42_ctx;

insert into public.stories (
  id, family_id, author_id, title, status, published_at,
  timeframe_start, timeframe_end, date_precision
)
select
  published_id, child_id, author_id, 'Published', 'published'::public.story_status, now(),
  '1980-03-14'::date, '1980-03-14'::date, 'day'::public.story_date_precision
from m42_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'a4200000-0000-4000-8000-0000000000a6';
set local request.jwt.claim.role = 'authenticated';

select public.set_family_origin(
  (select k_family_id from m42_ctx),
  (select published_id from m42_ctx)
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.people (id, family_id, name, created_by)
select person_id, child_id, 'Ada', author_id from m42_ctx
union all
select person2_id, child_id, 'Bea', author_id from m42_ctx;

insert into public.story_people (story_id, person_id)
select draft_id, person_id from m42_ctx;

insert into public.comments (id, story_id, family_id, author_id, body)
select comment_b_id, draft_id, child_id, member_id, 'member on draft' from m42_ctx
union all
select comment_a_id, draft_id, child_id, author_id, 'author on draft' from m42_ctx
union all
select comment_p_id, published_id, child_id, member_id, 'member on published' from m42_ctx;

insert into public.perspectives (id, story_id, family_id, author_id, body)
select perspective_b_id, draft_id, child_id, member_id, 'member on draft' from m42_ctx
union all
select perspective_a_id, draft_id, child_id, author_id, 'author on draft' from m42_ctx;

insert into public.photos (id, story_id, family_id, uploader_id, storage_path)
select
  photo_b_id, draft_id, child_id, member_id,
  child_id::text || '/' || draft_id::text || '/b.jpg'
from m42_ctx
union all
select
  photo_a_id, draft_id, child_id, author_id,
  child_id::text || '/' || draft_id::text || '/a.jpg'
from m42_ctx
union all
select
  photo_p_id, published_id, child_id, member_id,
  child_id::text || '/' || published_id::text || '/p.jpg'
from m42_ctx;

insert into storage.objects (bucket_id, name, owner_id)
select
  'story-photos',
  child_id::text || '/' || draft_id::text || '/b.jpg',
  member_id::text
from m42_ctx
union all
select
  'story-photos',
  child_id::text || '/' || draft_id::text || '/a.jpg',
  author_id::text
from m42_ctx
union all
select
  'story-photos',
  child_id::text || '/' || published_id::text || '/p.jpg',
  author_id::text
from m42_ctx;

-- G7. Tree reader R, then K, sees nothing on D.
set local role authenticated;
set local request.jwt.claim.sub = 'a4200000-0000-4000-8000-0000000000a5';
set local request.jwt.claim.role = 'authenticated';

select is(
  (select count(*) from public.comments where story_id = (select draft_id from m42_ctx)),
  0::bigint,
  'R sees no comments on D'
);
select is(
  (select count(*) from public.perspectives where story_id = (select draft_id from m42_ctx)),
  0::bigint,
  'R sees no perspectives on D'
);
select is(
  (select count(*) from public.photos where story_id = (select draft_id from m42_ctx)),
  0::bigint,
  'R sees no photos on D'
);
select is(
  (select count(*) from public.story_people where story_id = (select draft_id from m42_ctx)),
  0::bigint,
  'R sees no story_people on D'
);
select is(
  (select count(*) from storage.objects
    where name like (select child_id::text || '/' || draft_id::text || '/%' from m42_ctx)),
  0::bigint,
  'R sees no storage.objects on D'
);

set local request.jwt.claim.sub = 'a4200000-0000-4000-8000-0000000000a6';

select is(
  (select count(*) from public.comments where story_id = (select draft_id from m42_ctx)),
  0::bigint,
  'K sees no comments on D'
);
select is(
  (select count(*) from public.perspectives where story_id = (select draft_id from m42_ctx)),
  0::bigint,
  'K sees no perspectives on D'
);
select is(
  (select count(*) from public.photos where story_id = (select draft_id from m42_ctx)),
  0::bigint,
  'K sees no photos on D'
);
select is(
  (select count(*) from public.story_people where story_id = (select draft_id from m42_ctx)),
  0::bigint,
  'K sees no story_people on D'
);
select is(
  (select count(*) from storage.objects
    where name like (select child_id::text || '/' || draft_id::text || '/%' from m42_ctx)),
  0::bigint,
  'K sees no storage.objects on D'
);

-- G6. Co-owner C, then owner O, cannot write D.
set local request.jwt.claim.sub = 'a4200000-0000-4000-8000-0000000000a4';

update public.stories set title = 'Hijack' where id = (select draft_id from m42_ctx);
delete from public.stories where id = (select draft_id from m42_ctx);
update public.story_people
set person_id = (select person2_id from m42_ctx)
where story_id = (select draft_id from m42_ctx);
delete from public.story_people where story_id = (select draft_id from m42_ctx);

select throws_ok(
  $$insert into public.story_people (story_id, person_id)
    select draft_id, person2_id from m42_ctx$$,
  '42501',
  NULL,
  'C cannot insert story_people on D'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    select 'story-photos',
      child_id::text || '/' || draft_id::text || '/c.jpg',
      co_owner_id::text
    from m42_ctx$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'C cannot insert a story-photos object on D'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  (select title from public.stories where id = (select draft_id from m42_ctx)),
  'Draft',
  'D title is still Draft after C'
);
select is(
  (select count(*) from public.stories where id = (select draft_id from m42_ctx)),
  1::bigint,
  'D still exists after C'
);
select is(
  (select count(*) from public.story_people
    where story_id = (select draft_id from m42_ctx)
      and person_id = (select person2_id from m42_ctx)),
  0::bigint,
  'no (D, c2) link after C'
);
select is(
  (select count(*) from public.story_people
    where story_id = (select draft_id from m42_ctx)
      and person_id = (select person_id from m42_ctx)),
  1::bigint,
  '(D, c1) link is still there after C'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a4200000-0000-4000-8000-0000000000a3';
set local request.jwt.claim.role = 'authenticated';

update public.stories set title = 'Hijack' where id = (select draft_id from m42_ctx);
delete from public.stories where id = (select draft_id from m42_ctx);
update public.story_people
set person_id = (select person2_id from m42_ctx)
where story_id = (select draft_id from m42_ctx);
delete from public.story_people where story_id = (select draft_id from m42_ctx);

select throws_ok(
  $$insert into public.story_people (story_id, person_id)
    select draft_id, person2_id from m42_ctx$$,
  '42501',
  NULL,
  'O cannot insert story_people on D'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    select 'story-photos',
      child_id::text || '/' || draft_id::text || '/o.jpg',
      owner_id::text
    from m42_ctx$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'O cannot insert a story-photos object on D'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  (select title from public.stories where id = (select draft_id from m42_ctx)),
  'Draft',
  'D title is still Draft after O'
);
select is(
  (select count(*) from public.stories where id = (select draft_id from m42_ctx)),
  1::bigint,
  'D still exists after O'
);
select is(
  (select count(*) from public.story_people
    where story_id = (select draft_id from m42_ctx)
      and person_id = (select person2_id from m42_ctx)),
  0::bigint,
  'no (D, c2) link after O'
);
select is(
  (select count(*) from public.story_people
    where story_id = (select draft_id from m42_ctx)
      and person_id = (select person_id from m42_ctx)),
  1::bigint,
  '(D, c1) link is still there after O'
);

-- G1. B cannot delete B's own rows on D.
set local role authenticated;
set local request.jwt.claim.sub = 'a4200000-0000-4000-8000-0000000000a2';
set local request.jwt.claim.role = 'authenticated';

delete from public.comments where id = (select comment_b_id from m42_ctx);
delete from public.perspectives where id = (select perspective_b_id from m42_ctx);
delete from public.photos where id = (select photo_b_id from m42_ctx);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  (select count(*) from public.comments where id = (select comment_b_id from m42_ctx)),
  1::bigint,
  'B comment on D is still there'
);
select is(
  (select count(*) from public.perspectives where id = (select perspective_b_id from m42_ctx)),
  1::bigint,
  'B perspective on D is still there'
);
select is(
  (select count(*) from public.photos where id = (select photo_b_id from m42_ctx)),
  1::bigint,
  'B photo row on D is still there'
);

-- G2. B cannot update or delete B's object under child/D/.
set local role authenticated;
set local request.jwt.claim.sub = 'a4200000-0000-4000-8000-0000000000a2';
set local request.jwt.claim.role = 'authenticated';

update storage.objects
set metadata = '{"touched": true}'::jsonb
where name = (
  select child_id::text || '/' || draft_id::text || '/b.jpg' from m42_ctx
);

select set_config('storage.allow_delete_query', 'true', true);

delete from storage.objects
where name = (
  select child_id::text || '/' || draft_id::text || '/b.jpg' from m42_ctx
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  (select metadata from storage.objects
    where name = (
      select child_id::text || '/' || draft_id::text || '/b.jpg' from m42_ctx
    )),
  null::jsonb,
  'metadata is null on B object under D'
);
select is(
  (select count(*) from storage.objects
    where name = (
      select child_id::text || '/' || draft_id::text || '/b.jpg' from m42_ctx
    )),
  1::bigint,
  'B object under D still exists'
);

-- G3. A can delete A's own rows and object on D.
set local role authenticated;
set local request.jwt.claim.sub = 'a4200000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.role = 'authenticated';

delete from public.comments where id = (select comment_a_id from m42_ctx);
delete from public.perspectives where id = (select perspective_a_id from m42_ctx);
delete from public.photos where id = (select photo_a_id from m42_ctx);

select set_config('storage.allow_delete_query', 'true', true);

delete from storage.objects
where name = (
  select child_id::text || '/' || draft_id::text || '/a.jpg' from m42_ctx
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  (select count(*) from public.comments where id = (select comment_a_id from m42_ctx)),
  0::bigint,
  'A comment on D is gone'
);
select is(
  (select count(*) from public.perspectives where id = (select perspective_a_id from m42_ctx)),
  0::bigint,
  'A perspective on D is gone'
);
select is(
  (select count(*) from public.photos where id = (select photo_a_id from m42_ctx)),
  0::bigint,
  'A photo row on D is gone'
);
select is(
  (select count(*) from storage.objects
    where name = (
      select child_id::text || '/' || draft_id::text || '/a.jpg' from m42_ctx
    )),
  0::bigint,
  'A object under D is gone'
);

-- G4. On P, B deletes B's comment and photo row, and A's object.
set local role authenticated;
set local request.jwt.claim.sub = 'a4200000-0000-4000-8000-0000000000a2';
set local request.jwt.claim.role = 'authenticated';

delete from public.comments where id = (select comment_p_id from m42_ctx);
delete from public.photos where id = (select photo_p_id from m42_ctx);

select set_config('storage.allow_delete_query', 'true', true);

delete from storage.objects
where name = (
  select child_id::text || '/' || published_id::text || '/p.jpg' from m42_ctx
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  (select count(*) from public.comments where id = (select comment_p_id from m42_ctx)),
  0::bigint,
  'B comment on P is gone'
);
select is(
  (select count(*) from public.photos where id = (select photo_p_id from m42_ctx)),
  0::bigint,
  'B photo row on P is gone'
);
select is(
  (select count(*) from storage.objects
    where name = (
      select child_id::text || '/' || published_id::text || '/p.jpg' from m42_ctx
    )),
  0::bigint,
  'object under P is gone'
);

-- G8. Exact-text pins and unchanged can_contribute_to_story.
select is(
  coalesce((select qual from pg_policies
    where schemaname = 'public' and policyname = 'comments_delete_author'), ''),
  $pol$((author_id = ( SELECT auth.uid() AS uid)) AND can_contribute_to_story(family_id, story_id))$pol$,
  'comments_delete_author qual matches #42'
);

select is(
  coalesce((select qual from pg_policies
    where schemaname = 'public' and policyname = 'perspectives_delete_author'), ''),
  $pol$((author_id = ( SELECT auth.uid() AS uid)) AND can_contribute_to_story(family_id, story_id))$pol$,
  'perspectives_delete_author qual matches #42'
);

select is(
  coalesce((select qual from pg_policies
    where schemaname = 'public' and policyname = 'photos_delete_uploader_or_author'), ''),
  $pol$(((uploader_id = ( SELECT auth.uid() AS uid)) OR can_edit_story(story_id)) AND can_contribute_to_story(family_id, story_id))$pol$,
  'photos_delete_uploader_or_author qual matches #42'
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
        END) AND ((s.status = 'published'::story_status) OR (s.author_id = ( SELECT auth.uid() AS uid)))))))$pol$,
  'story_photos_update_member qual matches #42'
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
        END) AND ((s.status = 'published'::story_status) OR (s.author_id = ( SELECT auth.uid() AS uid)))))) AND (lower(storage.extension(name)) = ANY (ARRAY['jpg'::text, 'jpeg'::text, 'png'::text, 'webp'::text])))$pol$,
  'story_photos_update_member with_check matches #42'
);

select is(
  coalesce((select qual from pg_policies
    where schemaname = 'storage' and policyname = 'story_photos_delete_member'), ''),
  $pol$((bucket_id = 'story-photos'::text) AND ((is_family_member(
CASE
    WHEN ((storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(name))[1])::uuid
    ELSE NULL::uuid
END) AND ((EXISTS ( SELECT 1
   FROM stories s
  WHERE ((s.id =
        CASE
            WHEN ((storage.foldername(objects.name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(objects.name))[2])::uuid
            ELSE NULL::uuid
        END) AND (s.family_id =
        CASE
            WHEN ((storage.foldername(objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(objects.name))[1])::uuid
            ELSE NULL::uuid
        END) AND ((s.status = 'published'::story_status) OR (s.author_id = ( SELECT auth.uid() AS uid)))))) OR (NOT story_row_exists(
CASE
    WHEN ((storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(name))[2])::uuid
    ELSE NULL::uuid
END)))) OR ((owner_id = (( SELECT auth.uid() AS uid))::text) AND can_contribute_to_story(
CASE
    WHEN ((storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(name))[1])::uuid
    ELSE NULL::uuid
END,
CASE
    WHEN ((storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text) THEN ((storage.foldername(name))[2])::uuid
    ELSE NULL::uuid
END))))$pol$,
  'story_photos_delete_member qual matches #42'
);

select is(
  md5(pg_get_functiondef('public.can_contribute_to_story(uuid,uuid)'::regprocedure)),
  '17e9a6b5b7125801173c2e544593b3cd',
  'can_contribute_to_story is unchanged'
);

-- G9. Policy count and definer allowlist.
select is(
  (select count(*)::int from pg_policies),
  51,
  'policy count is 51'
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
  30,
  'the definer allowlist is 30'
);

select * from finish();
rollback;
