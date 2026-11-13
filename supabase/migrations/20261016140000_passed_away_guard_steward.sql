-- A linked passed_away change is refused unless the caller owns that family.
-- The self-flag block stays. Unlinked rows stay on the normal update path.
--
-- people_update_member used to hide linked rows from everyone but the linked
-- user, so a plain member's update never reached this trigger. USING now
-- includes tree members. WITH CHECK is unchanged, so a signed-in person's
-- other fields still cannot be rewritten. mark_passed_away is security
-- definer and bypasses the policy. The trigger still sees auth.uid().

create or replace function public.people_guard_passed_away()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.passed_away is distinct from old.passed_away
     and old.user_id = (select auth.uid()) then
    raise exception 'FORBIDDEN:';
  end if;

  if old.user_id is not null
     and new.passed_away is distinct from old.passed_away
     and not (
       public.is_family_owner(old.family_id)
       or public.is_family_co_owner(old.family_id)
     ) then
    raise exception 'FORBIDDEN:';
  end if;

  return new;
end;
$$;

revoke all on function public.people_guard_passed_away() from public, anon;

drop policy if exists people_update_member on public.people;
create policy people_update_member
  on public.people for update
  to authenticated
  using (public.is_tree_member(family_id))
  with check (
    (user_id is null and public.is_tree_member(family_id))
    or user_id = (select auth.uid())
  );
