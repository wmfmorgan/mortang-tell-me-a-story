-- M22 Family Landing: cover path, bucket policies, purge fail-closed.

begin;
create extension if not exists pgtap with schema extensions;

select plan(35);

create temporary table m22 (
  owner_id uuid primary key,
  co_id uuid not null,
  member_id uuid not null,
  out_id uuid not null,
  family_id uuid
);

grant all on table m22 to authenticated, anon, service_role;

insert into m22 (owner_id, co_id, member_id, out_id)
values (
  'a2200000-0000-4000-8000-0000000000a2',
  'b2200000-0000-4000-8000-0000000000b2',
  'c2200000-0000-4000-8000-0000000000c2',
  'd2200000-0000-4000-8000-0000000000d2'
);

insert into auth.users (id, email, raw_user_meta_data)
select owner_id, 'owner-m22@test.local', '{"display_name":"Owner"}'::jsonb from m22
union all
select co_id, 'co-m22@test.local', '{"display_name":"Co"}'::jsonb from m22
union all
select member_id, 'member-m22@test.local', '{"display_name":"Member"}'::jsonb from m22
union all
select out_id, 'out-m22@test.local', '{"display_name":"Out"}'::jsonb from m22;

set local role authenticated;
set local request.jwt.claim.sub = 'a2200000-0000-4000-8000-0000000000a2';
set local request.jwt.claim.role = 'authenticated';

update m22
set family_id = (select id from public.create_family('Landing Archive'));

reset role;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', '', true);

insert into public.memberships (family_id, user_id, role)
select family_id, co_id, 'co_owner'::public.membership_role from m22
union all
select family_id, member_id, 'member'::public.membership_role from m22;

select has_column(
  'public', 'families', 'cover_photo_path',
  'families.cover_photo_path exists'
);
select hasnt_column(
  'public', 'families', 'featured_story_ids',
  'no featured_story_ids column'
);

select is(
  (select public from storage.buckets where id = 'family-covers'),
  false,
  'family-covers is private'
);
select is(
  (select file_size_limit from storage.buckets where id = 'family-covers'),
  5242880::bigint,
  'family-covers is 5 MiB'
);
select ok(
  (
    select allowed_mime_types <@ array['image/jpeg', 'image/png', 'image/webp']::text[]
      and allowed_mime_types @> array['image/jpeg', 'image/png', 'image/webp']::text[]
    from storage.buckets
    where id = 'family-covers'
  ),
  'family-covers allows jpeg, png, and webp only'
);

select throws_ok(
  $$ update public.families
     set cover_photo_path = 'https://evil.example/a.jpg'
     where id = (select family_id from m22) $$,
  '23514',
  null,
  'CHECK rejects a URL'
);
select throws_ok(
  $$ update public.families
     set cover_photo_path = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/cover.jpg'
     where id = (select family_id from m22) $$,
  '23514',
  null,
  'CHECK rejects another family prefix'
);
select throws_ok(
  $$ update public.families
     set cover_photo_path = '../cover.jpg'
     where id = (select family_id from m22) $$,
  '23514',
  null,
  'CHECK rejects a traversal path'
);
select throws_ok(
  $$ update public.families
     set cover_photo_path = (select family_id::text || '/cover.gif' from m22)
     where id = (select family_id from m22) $$,
  '23514',
  null,
  'CHECK rejects a non-cover basename'
);
select lives_ok(
  $$ update public.families
     set cover_photo_path = (select family_id::text || '/cover.jpg' from m22)
     where id = (select family_id from m22) $$,
  'CHECK accepts cover.jpg'
);
select lives_ok(
  $$ update public.families
     set cover_photo_path = (select family_id::text || '/cover.jpeg' from m22)
     where id = (select family_id from m22) $$,
  'CHECK accepts cover.jpeg'
);
select lives_ok(
  $$ update public.families
     set cover_photo_path = (select family_id::text || '/cover.png' from m22)
     where id = (select family_id from m22) $$,
  'CHECK accepts cover.png'
);
select lives_ok(
  $$ update public.families
     set cover_photo_path = (select family_id::text || '/cover.webp' from m22)
     where id = (select family_id from m22) $$,
  'CHECK accepts cover.webp'
);
select lives_ok(
  $$ update public.families
     set cover_photo_path = null
     where id = (select family_id from m22) $$,
  'CHECK accepts null'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a2200000-0000-4000-8000-0000000000a2';
set local request.jwt.claim.role = 'authenticated';

select lives_ok(
  $$ update public.families
     set cover_photo_path = (select family_id::text || '/cover.jpg' from m22)
     where id = (select family_id from m22) $$,
  'owner can set cover_photo_path'
);
select throws_ok(
  $$ update public.families
     set cover_photo_path = 'https://evil.example/a.jpg'
     where id = (select family_id from m22) $$,
  'P0001',
  'VALIDATION: cover_photo_path must be {family_id}/cover.(jpg|jpeg|png|webp)',
  'guard rejects a URL'
);

set local request.jwt.claim.sub = 'b2200000-0000-4000-8000-0000000000b2';

select lives_ok(
  $$ update public.families
     set cover_photo_path = (select family_id::text || '/cover.png' from m22)
     where id = (select family_id from m22) $$,
  'co-owner can set cover_photo_path'
);

set local request.jwt.claim.sub = 'c2200000-0000-4000-8000-0000000000c2';

select lives_ok(
  $$ update public.families
     set cover_photo_path = (select family_id::text || '/cover.jpg' from m22)
     where id = (select family_id from m22) $$,
  'member update is attempted'
);
select is(
  (
    select cover_photo_path from public.families
    where id = (select family_id from m22)
  ),
  (select family_id::text || '/cover.png' from m22),
  'member cannot change cover_photo_path'
);

select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id)
     select 'family-covers', family_id::text || '/cover.jpg', member_id::text
     from m22 $$,
  '42501',
  null,
  'member cannot insert a cover'
);

set local request.jwt.claim.sub = 'a2200000-0000-4000-8000-0000000000a2';

select lives_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id)
     select 'family-covers', family_id::text || '/cover.jpg', owner_id::text
     from m22 $$,
  'owner can insert cover.jpg'
);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id)
     select 'family-covers', family_id::text || '/cover.svg', owner_id::text
     from m22 $$,
  '42501',
  null,
  'owner cannot insert svg'
);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id)
     select 'family-covers', family_id::text || '/extra/cover.jpg', owner_id::text
     from m22 $$,
  '42501',
  null,
  'owner cannot insert a nested cover'
);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id)
     select 'family-covers', family_id::text || '/notes.png', owner_id::text
     from m22 $$,
  '42501',
  null,
  'owner cannot insert a non-cover basename'
);

set local request.jwt.claim.sub = 'c2200000-0000-4000-8000-0000000000c2';

select is(
  (
    select count(*)::int from storage.objects
    where bucket_id = 'family-covers'
      and name = (select family_id::text || '/cover.jpg' from m22)
  ),
  1,
  'member can select the cover'
);

set local request.jwt.claim.sub = 'd2200000-0000-4000-8000-0000000000d2';

select is(
  (
    select count(*)::int from storage.objects
    where bucket_id = 'family-covers'
      and name = (select family_id::text || '/cover.jpg' from m22)
  ),
  0,
  'non-member cannot select the cover'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', '', true);

update public.families
set deleted_at = now()
where id = (select family_id from m22);

set local role authenticated;
set local request.jwt.claim.sub = 'c2200000-0000-4000-8000-0000000000c2';
set local request.jwt.claim.role = 'authenticated';

select is(
  (
    select count(*)::int from storage.objects
    where bucket_id = 'family-covers'
      and name = (select family_id::text || '/cover.jpg' from m22)
  ),
  1,
  'soft-deleted member can still select the cover'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', '', true);

update public.families
set deleted_at = now() - interval '61 days'
where id = (select family_id from m22);

delete from vault.secrets where name = 'service_role_key';

select throws_ok(
  $$ select public.purge_expired_families() $$,
  'P0001',
  'VALIDATION: service role key is not configured for cover purge',
  'purge does not drop a family when the Storage API key is missing'
);
select is(
  (select count(*)::int from public.families where id = (select family_id from m22)),
  1,
  'family row remains when cover purge cannot run'
);

select ok(
  position(
    'extensions.http'
    in pg_get_functiondef('public.delete_family_cover_objects(uuid)'::regprocedure)
  ) > 0,
  'cover purge calls the Storage HTTP API'
);
select ok(
  position(
    '/object/list/family-covers'
    in pg_get_functiondef('public.delete_family_cover_objects(uuid)'::regprocedure)
  ) > 0
  and position(
    '/object/family-covers/'
    in pg_get_functiondef('public.delete_family_cover_objects(uuid)'::regprocedure)
  ) > 0,
  'cover purge lists and deletes the family prefix'
);
select ok(
  position(
    'delete from storage.objects'
    in lower(pg_get_functiondef('public.delete_family_cover_objects(uuid)'::regprocedure))
  ) = 0
  and position(
    'delete from storage.objects'
    in lower(pg_get_functiondef('public.purge_expired_families()'::regprocedure))
  ) = 0,
  'purge does not delete storage.objects in SQL'
);
select ok(
  not has_function_privilege(
    'anon', 'public.delete_family_cover_objects(uuid)', 'execute'
  ),
  'anon cannot execute cover purge'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public.delete_family_cover_objects(uuid)', 'execute'
  ),
  'authenticated cannot execute cover purge'
);
select ok(
  position(
    'is_family_member'
    in (
      select qual from pg_policies
      where policyname = 'family_covers_select_member'
    )
  ) > 0
  and position(
    'is_live_family_member'
    in (
      select qual from pg_policies
      where policyname = 'family_covers_select_member'
    )
  ) = 0,
  'cover SELECT uses is_family_member'
);

select * from finish();
rollback;
