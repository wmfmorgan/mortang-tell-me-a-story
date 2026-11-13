-- §14 profile bootstrap: auth.users insert → profiles row via trigger;
-- client-style upsert is unnecessary (no authenticated INSERT policy).
-- Harness: service/postgres inserts auth.users; assert profiles; assert
-- authenticated INSERT into profiles is denied. ROLLBACK at end.

begin;
create extension if not exists pgtap with schema extensions;

select plan(4);

insert into auth.users (id, email, raw_user_meta_data)
values (
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'trigger-user@test.local',
  '{"display_name":"Trigger User"}'::jsonb
);

select is(
  (select count(*)::int from public.profiles
   where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  1,
  'handle_new_user inserts profiles row for new auth.users'
);

select is(
  (select email from public.profiles
   where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  'trigger-user@test.local',
  'profiles.email matches auth.users.email'
);

select is(
  (select display_name from public.profiles
   where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  'Trigger User',
  'profiles.display_name comes from raw_user_meta_data'
);

-- Client bootstrap upsert must not be required / allowed
set local role authenticated;
set local request.jwt.claim.sub = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
set local request.jwt.claim.role = 'authenticated';

select throws_ok(
  $$insert into public.profiles (id, email, display_name)
    values (
      'dddddddd-dddd-dddd-dddd-dddddddddddd',
      'client-upsert@test.local',
      'Should Fail'
    )$$,
  '42501',
  null,
  'authenticated cannot INSERT profiles (trigger-only bootstrap)'
);

select * from finish();
rollback;
