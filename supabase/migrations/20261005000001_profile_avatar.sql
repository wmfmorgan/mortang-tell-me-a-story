-- Design Doc M8 profile. avatar_path and the private avatars bucket.
-- The client does not write profiles.email. This trigger copies auth.users.email
-- onto profiles.email only after that column changes.

alter table public.profiles
  add column avatar_path text;

alter table public.profiles
  add constraint profiles_avatar_path_own
  check (
    avatar_path is null
    or avatar_path = (id::text || '/avatar.jpg')
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  false,
  2097152,
  array['image/jpeg']
);

create policy avatars_select_own
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and name = (auth.uid()::text || '/avatar.jpg')
  );

create policy avatars_insert_own
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and name = (auth.uid()::text || '/avatar.jpg')
  );

create policy avatars_update_own
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and name = (auth.uid()::text || '/avatar.jpg')
  )
  with check (
    bucket_id = 'avatars'
    and name = (auth.uid()::text || '/avatar.jpg')
  );

create policy avatars_delete_own
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and name = (auth.uid()::text || '/avatar.jpg')
  );

create or replace function public.sync_profile_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
    set email = new.email,
        updated_at = now()
    where id = new.id;
  return new;
end;
$$;

create trigger on_auth_user_email_updated
  after update of email on auth.users
  for each row
  when (new.email is distinct from old.email)
  execute function public.sync_profile_email();
