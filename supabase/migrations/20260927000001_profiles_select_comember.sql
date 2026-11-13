drop policy profiles_select_own on public.profiles;

create policy profiles_select_own_or_comember
  on public.profiles for select
  to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1
      from public.memberships mine
      join public.memberships theirs
        on theirs.family_id = mine.family_id
      where mine.user_id = auth.uid()
        and theirs.user_id = profiles.id
    )
  );
