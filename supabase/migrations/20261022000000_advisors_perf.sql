-- #75 M17a: Supabase advisors clean, performance (Gilfoyle, LOCKED 2026-10-21, lock rev 2 Addendum A).
-- auth_rls_initplan: alter policy only. Each bare auth.uid() becomes (select auth.uid()) so it is
-- evaluated once per statement (initplan), not once per row. No semantic change. Roles, commands,
-- names and grants unchanged. Policy count stays 47. No new function, no new grant.
-- unindexed_foreign_keys: one btree index per FK (17, all single-column). Tiny tables; the migration
-- runs in one transaction, so no CONCURRENTLY.

-- profiles (20260923000004_rls.sql l.66-75; 20260927000001_profiles_select_comember.sql l.3-16)
alter policy profiles_update_own on public.profiles
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

alter policy profiles_delete_own on public.profiles
  using (id = (select auth.uid()));

alter policy profiles_select_own_or_comember on public.profiles
  using (
    id = (select auth.uid())
    or exists (
      select 1
      from public.memberships mine
      join public.memberships theirs
        on theirs.family_id = mine.family_id
      where mine.user_id = (select auth.uid())
        and theirs.user_id = profiles.id
    )
  );

-- stories (20260923000004_rls.sql l.171-177)
alter policy stories_delete_author on public.stories
  using (
    author_id = (select auth.uid())
    and public.is_family_member(family_id)
  );

-- invites (20260923000004_rls.sql l.353-359)
alter policy invites_insert_member_inviter on public.invites
  with check (
    public.is_family_member(family_id)
    and invited_by = (select auth.uid())
  );

-- FK covering indexes (advisor 0001 unindexed_foreign_keys, 17 findings)
create index if not exists comments_author_id_idx on public.comments (author_id);
create index if not exists comments_family_id_idx on public.comments (family_id);
create index if not exists comments_story_id_idx on public.comments (story_id);
create index if not exists families_created_by_idx on public.families (created_by);
create index if not exists invites_accepted_by_idx on public.invites (accepted_by);
create index if not exists invites_family_id_idx on public.invites (family_id);
create index if not exists invites_invited_by_idx on public.invites (invited_by);
create index if not exists invites_person_id_idx on public.invites (person_id);
create index if not exists people_created_by_idx on public.people (created_by);
create index if not exists people_user_id_idx on public.people (user_id);
create index if not exists perspectives_author_id_idx on public.perspectives (author_id);
create index if not exists perspectives_family_id_idx on public.perspectives (family_id);
create index if not exists perspectives_story_id_idx on public.perspectives (story_id);
create index if not exists photos_family_id_idx on public.photos (family_id);
create index if not exists photos_story_id_idx on public.photos (story_id);
create index if not exists photos_uploader_id_idx on public.photos (uploader_id);
create index if not exists stories_author_id_idx on public.stories (author_id);
