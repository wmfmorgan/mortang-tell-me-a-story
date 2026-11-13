-- Design Doc M9 avatar visibility. Co-members can read an avatar object.
-- Writes stay own-only. Do not edit 20261005000001_profile_avatar.sql.

drop policy if exists avatars_select_own on storage.objects;

create policy avatars_select_own_or_comember
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and (
      name = (auth.uid()::text || '/avatar.jpg')
      or exists (
        select 1
        from public.memberships mine
        join public.memberships theirs
          on theirs.family_id = mine.family_id
        where mine.user_id = auth.uid()
          and name = (theirs.user_id::text || '/avatar.jpg')
      )
    )
  );
