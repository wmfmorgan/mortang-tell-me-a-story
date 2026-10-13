-- A member insert cannot attach an account. Linking happens through accept-invite.

drop policy if exists people_insert_member on public.people;
create policy people_insert_member
  on public.people for insert
  to authenticated
  with check (
    public.is_live_family_member(family_id)
    and user_id is null
  );
