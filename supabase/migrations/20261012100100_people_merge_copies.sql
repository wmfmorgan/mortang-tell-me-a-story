-- M14: collapse people copied onto branch families back onto the parent row.
-- One call. Clients cannot execute it.

create or replace function public.merge_copied_people()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  branch_id uuid;
  parent_id uuid;
  copy public.people;
  survivor_id uuid;
  match_count int;
begin
  for branch_id, parent_id in
    with recursive walk as (
      select f.id, f.parent_family_id, 0 as depth
      from public.families f
      where f.parent_family_id is null
      union all
      select child.id, child.parent_family_id, w.depth + 1
      from walk w
      join public.families child on child.parent_family_id = w.id
      where w.depth < 64
    )
    select walk.id, walk.parent_family_id
    from walk
    where walk.parent_family_id is not null
    order by walk.depth desc, walk.id
  loop
    for copy in
      select p.*
      from public.people p
      where p.family_id = branch_id
    loop
      select count(*)::int, (pg_catalog.array_agg(c.id))[1]
      into match_count, survivor_id
      from public.people c
      where c.family_id = parent_id
        and (
          (copy.user_id is not null and c.user_id = copy.user_id)
          or (
            nullif(lower(btrim(coalesce(copy.email, ''))), '') is not null
            and nullif(lower(btrim(coalesce(c.email, ''))), '') is not null
            and lower(btrim(c.email)) = lower(btrim(copy.email))
          )
          or (
            nullif(
              regexp_replace(lower(btrim(coalesce(copy.name, ''))), '\s+', ' ', 'g'),
              ''
            ) is not null
            and regexp_replace(lower(btrim(coalesce(copy.name, ''))), '\s+', ' ', 'g')
              = regexp_replace(lower(btrim(coalesce(c.name, ''))), '\s+', ' ', 'g')
            and not (
              copy.user_id is not null
              and c.user_id is not null
              and c.user_id <> copy.user_id
            )
            and not (
              nullif(lower(btrim(coalesce(copy.email, ''))), '') is not null
              and nullif(lower(btrim(coalesce(c.email, ''))), '') is not null
              and lower(btrim(copy.email)) <> lower(btrim(c.email))
            )
          )
        );

      if match_count is distinct from 1 or survivor_id is null then
        continue;
      end if;

      insert into public.story_people (story_id, person_id)
      select sp.story_id, survivor_id
      from public.story_people sp
      where sp.person_id = copy.id
      on conflict do nothing;

      delete from public.story_people
      where person_id = copy.id;

      update public.invites
      set person_id = survivor_id
      where person_id = copy.id;

      update public.people
      set
        user_id = coalesce(user_id, copy.user_id),
        email = coalesce(email, copy.email)
      where id = survivor_id;

      delete from public.people
      where id = copy.id;
    end loop;
  end loop;
end;
$$;

revoke all on function public.merge_copied_people() from public, anon, authenticated;

select public.merge_copied_people();
