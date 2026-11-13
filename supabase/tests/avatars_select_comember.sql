-- M9: a co-member can read an avatar object. A stranger cannot.
-- B's update and delete do not change A's object. The insert attempt is
-- swallowed only so this script can check the row. The assertion is the row.
-- Harness matches profiles_comember_select.sql. Entire script rolls back.

begin;
create extension if not exists pgtap with schema extensions;

select plan(5);

create temporary table test_ctx (
  user_a uuid primary key,
  user_b uuid not null,
  user_c uuid not null,
  family_a uuid,
  family_c uuid
);

grant all on table test_ctx to authenticated, anon, service_role;

insert into test_ctx (user_a, user_b, user_c)
values (
  'f1111111-1111-4111-8111-111111111111',
  'f2222222-2222-4222-8222-222222222222',
  'f3333333-3333-4333-8333-333333333333'
);

insert into auth.users (id, email, raw_user_meta_data)
select user_a, 'avatar-a@test.local', '{"display_name":"User A"}'::jsonb from test_ctx
union all
select user_b, 'avatar-b@test.local', '{"display_name":"User B"}'::jsonb from test_ctx
union all
select user_c, 'avatar-c@test.local', '{"display_name":"User C"}'::jsonb from test_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'f1111111-1111-4111-8111-111111111111';
set local request.jwt.claim.role = 'authenticated';

update test_ctx
set family_a = (public.create_family('Family A')).id;

set local request.jwt.claim.sub = 'f3333333-3333-4333-8333-333333333333';

update test_ctx
set family_c = (public.create_family('Family C')).id;

reset role;

insert into public.memberships (family_id, user_id, role)
select family_a, user_b, 'member' from test_ctx;

insert into storage.objects (bucket_id, name, owner_id)
select 'avatars', user_a::text || '/avatar.jpg', user_a::text
from test_ctx;

set local role authenticated;
set local request.jwt.claim.sub = 'f2222222-2222-4222-8222-222222222222';
set local request.jwt.claim.role = 'authenticated';

select is(
  (select count(*)::int from storage.objects
   where bucket_id = 'avatars'
     and name = (select user_a::text || '/avatar.jpg' from test_ctx)),
  1,
  'co-member B can select A avatar object'
);

set local request.jwt.claim.sub = 'f3333333-3333-4333-8333-333333333333';

select is(
  (select count(*)::int from storage.objects
   where bucket_id = 'avatars'
     and name = (select user_a::text || '/avatar.jpg' from test_ctx)),
  0,
  'stranger C cannot select A avatar object'
);

set local request.jwt.claim.sub = 'f2222222-2222-4222-8222-222222222222';

update storage.objects
  set metadata = '{"touched": true}'::jsonb
  where bucket_id = 'avatars'
    and name = (select user_a::text || '/avatar.jpg' from test_ctx);

-- storage.protect_delete rejects every direct delete, including the owner.
-- Swallow it so the script can assert the row. The assertion is the row.
do $$
begin
  delete from storage.objects
    where bucket_id = 'avatars'
      and name = (select user_a::text || '/avatar.jpg' from test_ctx);
exception when others then
  null;
end $$;

do $$
begin
  insert into storage.objects (bucket_id, name, owner_id)
  select 'avatars', user_a::text || '/avatar.jpg', user_b::text
  from test_ctx;
exception when others then
  null;
end $$;

reset role;

select is(
  (select count(*)::int from storage.objects
   where bucket_id = 'avatars'
     and name = (select user_a::text || '/avatar.jpg' from test_ctx)),
  1,
  'A avatar object is still there after B write attempts'
);

select is(
  (select name from storage.objects
   where bucket_id = 'avatars'
     and name = (select user_a::text || '/avatar.jpg' from test_ctx)),
  (select user_a::text || '/avatar.jpg' from test_ctx),
  'A avatar object name is unchanged'
);

select ok(
  (select metadata is null from storage.objects
   where bucket_id = 'avatars'
     and name = (select user_a::text || '/avatar.jpg' from test_ctx)),
  'A avatar metadata is unchanged'
);

select * from finish();
rollback;
