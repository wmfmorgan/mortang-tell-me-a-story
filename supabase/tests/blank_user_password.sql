-- GoTrue v2.197 treats a blank encrypted_password as no password.
-- Signup, confirm, sign-in, and recovery all write auth.users, so the
-- blank has to win on every insert and update.

begin;
create extension if not exists pgtap with schema extensions;

select plan(7);

select hasnt_function(
  'public',
  'hook_password_verification_attempt',
  array['jsonb'],
  'the password verification hook is gone'
);

select has_trigger(
  'auth',
  'users',
  'blank_user_password',
  'auth.users clears a password on write'
);

insert into auth.users (id, email, encrypted_password)
values (
  'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1',
  'blank-insert@test.local',
  '$2a$10$abcdefghijklmnopqrstuuuuuuuuuuuuuuuuuuuuuuuuuuuu'
);

select is(
  (select encrypted_password from auth.users
    where id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1'),
  '',
  'an inserted password hash is stored blank'
);

update auth.users
set encrypted_password = '$2a$10$updatedhashshouldnotstickxxxxxxxxxxxxxxxxxxxxxxxxx'
where id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1';

select is(
  (select encrypted_password from auth.users
    where id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1'),
  '',
  'an updated password hash is stored blank'
);

update auth.users
set last_sign_in_at = now(),
    encrypted_password = '$2a$10$signinhashshouldnotstickxxxxxxxxxxxxxxxxxxxxxxxxx'
where id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1';

select is(
  (select encrypted_password from auth.users
    where id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1'),
  '',
  'a sign-in update cannot restore a password'
);

insert into auth.users (id, email)
values (
  'b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2',
  'blank-null@test.local'
);

select is(
  (select encrypted_password from auth.users
    where id = 'b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2'),
  '',
  'a user inserted without a password is stored blank'
);

select ok(
  not has_function_privilege(
    'anon', 'public.blank_user_password()', 'execute'
  )
  and not has_function_privilege(
    'authenticated', 'public.blank_user_password()', 'execute'
  )
  and not has_function_privilege(
    'public', 'public.blank_user_password()', 'execute'
  ),
  'anon, authenticated, and public cannot execute the password trigger'
);

select * from finish();
rollback;
