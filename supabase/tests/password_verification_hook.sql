-- Password sign-in is closed. GoTrue calls this hook on a password grant.
-- Magic link does not. A correct password is rejected the same as a wrong one,
-- so a hash stored before email confirm cannot be used later.

begin;
create extension if not exists pgtap with schema extensions;

select plan(6);

select is(
  public.hook_password_verification_attempt(
    jsonb_build_object(
      'user_id', '00000000-0000-0000-0000-000000000001',
      'valid', true
    )
  ) ->> 'decision',
  'reject',
  'a correct password is rejected'
);

select is(
  public.hook_password_verification_attempt(
    jsonb_build_object(
      'user_id', '00000000-0000-0000-0000-000000000001',
      'valid', false
    )
  ) ->> 'decision',
  'reject',
  'a wrong password is rejected'
);

select is(
  public.hook_password_verification_attempt(
    jsonb_build_object(
      'user_id', '00000000-0000-0000-0000-000000000001',
      'valid', true
    )
  ) ->> 'should_logout_user',
  'false',
  'a rejected password attempt does not log out other sessions'
);

select is(
  public.hook_password_verification_attempt(
    jsonb_build_object(
      'user_id', '00000000-0000-0000-0000-000000000001',
      'valid', true
    )
  ) ->> 'message',
  'Password sign-in is disabled.',
  'the hook tells the caller that password sign-in is disabled'
);

select ok(
  has_function_privilege(
    'supabase_auth_admin',
    'public.hook_password_verification_attempt(jsonb)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.hook_password_verification_attempt(jsonb)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.hook_password_verification_attempt(jsonb)',
    'execute'
  ),
  'only supabase_auth_admin may execute the password hook'
);

select ok(
  not has_function_privilege(
    'public',
    'public.hook_password_verification_attempt(jsonb)',
    'execute'
  ),
  'public cannot execute the password hook'
);

select * from finish();
rollback;
