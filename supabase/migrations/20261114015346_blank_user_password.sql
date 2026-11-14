-- GoTrue v2.197 treats '' as no password (HasPassword and Authenticate).
-- Confirm, sign-in, and recovery all update auth.users, so a hash written
-- on any of those paths has to be cleared in the same write.
-- The password verification hook is Teams-only, so it does not ship.

drop function if exists public.hook_password_verification_attempt(jsonb);

create function public.blank_user_password()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.encrypted_password := '';
  return new;
end;
$$;

create trigger blank_user_password
  before insert or update on auth.users
  for each row
  execute function public.blank_user_password();

revoke execute on function public.blank_user_password()
  from public, anon, authenticated;

update auth.users
set encrypted_password = ''
where encrypted_password is distinct from '';
