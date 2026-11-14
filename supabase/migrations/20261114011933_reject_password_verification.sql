-- Magic link does not call this hook.
-- event.valid is ignored so a password stored before confirm cannot be used.

create function public.hook_password_verification_attempt(event jsonb)
returns jsonb
language plpgsql
set search_path = ''
as $$
begin
  return jsonb_build_object(
    'decision', 'reject',
    'message', 'Password sign-in is disabled.',
    'should_logout_user', false
  );
end;
$$;

revoke execute on function public.hook_password_verification_attempt(jsonb)
  from public, anon, authenticated;

grant execute on function public.hook_password_verification_attempt(jsonb)
  to supabase_auth_admin;
