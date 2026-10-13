-- Hide people who already have an open invite from list_unlinked_people.
-- Return email on the same row so the invite dialog does not query again.

drop function if exists public.list_unlinked_people(uuid);

create function public.list_unlinked_people(p_family_id uuid)
returns table (id uuid, family_id uuid, name text, email text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null
     or not exists (
       select 1
       from public.families f
       where f.id = p_family_id
         and f.deleted_at is null
     )
     or not public.is_tree_member(p_family_id) then
    raise exception 'NOT_FOUND:';
  end if;

  return query
  select p.id, p.family_id, p.name, p.email
  from public.people p
  join public.families f on f.id = p.family_id
  where f.deleted_at is null
    and p.user_id is null
    and p.passing_date is null
    and public.family_tree_root(p.family_id) = public.family_tree_root(p_family_id)
    and not exists (
      select 1
      from public.invites i
      where i.person_id = p.id
        and i.status = 'pending'
        and i.expires_at > now()
    )
  order by p.name, p.id;
end;
$$;

revoke all on function public.list_unlinked_people(uuid) from public, anon, service_role;
grant execute on function public.list_unlinked_people(uuid) to authenticated;
