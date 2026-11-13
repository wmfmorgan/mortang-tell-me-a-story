-- M8: own avatar_path, the path check, and the email copy trigger.
-- Harness: postgres inserts auth.users; ROLLBACK at end.

begin;
create extension if not exists pgtap with schema extensions;

select plan(4);

insert into auth.users (id, email, raw_user_meta_data)
values (
  'a1111111-1111-4111-8111-111111111111',
  'ada@test.local',
  '{"display_name":"Ada Lovelace"}'::jsonb
);

insert into auth.users (id, email, raw_user_meta_data)
values (
  'b2222222-2222-4222-8222-222222222222',
  'grace@test.local',
  '{"display_name":"Grace Hopper"}'::jsonb
);

update auth.users
  set email = 'ada.moved@test.local'
  where id = 'a1111111-1111-4111-8111-111111111111';

select is(
  (select email from public.profiles
   where id = 'a1111111-1111-4111-8111-111111111111'),
  'ada.moved@test.local',
  'auth.users.email update copies onto profiles.email'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a1111111-1111-4111-8111-111111111111';
set local request.jwt.claim.role = 'authenticated';

update public.profiles
  set avatar_path = id::text || '/avatar.jpg'
  where id = 'a1111111-1111-4111-8111-111111111111';

select is(
  (select avatar_path from public.profiles
   where id = 'a1111111-1111-4111-8111-111111111111'),
  'a1111111-1111-4111-8111-111111111111/avatar.jpg',
  'own user can store the legal avatar path'
);

select throws_ok(
  $$update public.profiles
      set avatar_path = 'other/avatar.jpg'
      where id = 'a1111111-1111-4111-8111-111111111111'$$,
  '23514',
  null,
  'a path other than {id}/avatar.jpg fails the check'
);

set local request.jwt.claim.sub = 'b2222222-2222-4222-8222-222222222222';

update public.profiles
  set avatar_path = 'a1111111-1111-4111-8111-111111111111/nope.jpg'
  where id = 'a1111111-1111-4111-8111-111111111111';

-- Grace shares no family, so profiles_select_own_or_comember hides Ada's row.
-- Read the stored path as the table owner after her update.
reset role;

select is(
  (select avatar_path from public.profiles
   where id = 'a1111111-1111-4111-8111-111111111111'),
  'a1111111-1111-4111-8111-111111111111/avatar.jpg',
  'another user cannot update the avatar path'
);

select * from finish();
rollback;
