-- M12: branch_year, tree-read helpers, people_tree_read, and SELECT policies.
-- Design Doc "M12 amendments (LOCKED Bill 2026-10-10)".
-- SELECT policies are to authenticated. The member check comes first so a
-- member does not start the tree walk. INSERT, UPDATE, and DELETE stay.

alter table public.families add column branch_year int null
  check (branch_year is null or (branch_year >= 1 and branch_year <= 9999));

create or replace function public.family_tree_root(fid uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  with recursive walk as (
    select f.id, f.parent_family_id, 0 as depth, array[f.id] as path
    from public.families f
    where f.id = fid and f.deleted_at is null
    union all
    select p.id, p.parent_family_id, w.depth + 1, w.path || p.id
    from walk w
    join public.families p on p.id = w.parent_family_id
    where p.deleted_at is null and w.depth < 64 and not p.id = any(w.path)
  )
  select id from walk order by depth desc limit 1;
$$;

create or replace function public.is_family_tree_readable(fid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select exists (
      select 1
      from public.memberships m
      join public.families mf on mf.id = m.family_id and mf.deleted_at is null
      where m.user_id = auth.uid()
        and public.family_tree_root(m.family_id) = public.family_tree_root(fid)
    )
  ), false);
$$;

create or replace function public.list_family_tree(fid uuid)
returns table (id uuid, name text, parent_family_id uuid, branch_year int)
language sql
stable
security definer
set search_path = public
as $$
  with recursive down as (
    select f.id, f.name, f.parent_family_id, f.branch_year, 0 as depth, array[f.id] as path
    from public.families f
    where f.id = public.family_tree_root(fid) and f.deleted_at is null
    union all
    select c.id, c.name, c.parent_family_id, c.branch_year, d.depth + 1, d.path || c.id
    from public.families c
    join down d on c.parent_family_id = d.id
    where c.deleted_at is null and d.depth < 64 and not c.id = any(d.path)
  )
  select down.id, down.name, down.parent_family_id, down.branch_year
  from down
  where public.is_family_tree_readable(fid);
$$;

create view public.people_tree_read with (security_barrier = true) as
  select p.id, p.family_id, p.name, p.relationship
  from public.people p
  where public.is_family_member(p.family_id)
     or public.is_family_tree_readable(p.family_id);

revoke all on function public.family_tree_root(uuid) from public, anon, authenticated;
revoke all on function public.is_family_tree_readable(uuid) from public, anon;
revoke all on function public.list_family_tree(uuid) from public, anon;
grant execute on function public.is_family_tree_readable(uuid) to authenticated, service_role;
grant execute on function public.list_family_tree(uuid) to authenticated, service_role;
revoke all on public.people_tree_read from public, anon, authenticated;
grant select on public.people_tree_read to authenticated;

-- families: member first, then the M10 soft-delete clause.
drop policy if exists families_select_member on public.families;
create policy families_select_member
  on public.families for select
  to authenticated
  using (
    (
      public.is_family_member(id)
      or public.is_family_tree_readable(id)
    )
    and (
      deleted_at is null
      or public.is_family_owner(id)
      or public.is_family_co_owner(id)
    )
  );

drop policy if exists stories_select_member on public.stories;
create policy stories_select_member
  on public.stories for select
  to authenticated
  using (
    public.is_family_member(family_id)
    or (
      public.is_family_tree_readable(family_id)
      and status = 'published'
    )
  );

drop policy if exists places_select_member on public.places;
create policy places_select_member
  on public.places for select
  to authenticated
  using (
    public.is_family_member(family_id)
    or public.is_family_tree_readable(family_id)
  );

drop policy if exists photos_select_member on public.photos;
create policy photos_select_member
  on public.photos for select
  to authenticated
  using (
    public.is_family_member(family_id)
    or (
      public.is_family_tree_readable(family_id)
      and exists (
        select 1
        from public.stories s
        where s.id = story_id
          and s.status = 'published'
      )
    )
  );

drop policy if exists comments_select_member on public.comments;
create policy comments_select_member
  on public.comments for select
  to authenticated
  using (
    public.is_family_member(family_id)
    or (
      public.is_family_tree_readable(family_id)
      and exists (
        select 1
        from public.stories s
        where s.id = story_id
          and s.status = 'published'
      )
    )
  );

drop policy if exists perspectives_select_member on public.perspectives;
create policy perspectives_select_member
  on public.perspectives for select
  to authenticated
  using (
    public.is_family_member(family_id)
    or (
      public.is_family_tree_readable(family_id)
      and exists (
        select 1
        from public.stories s
        where s.id = story_id
          and s.status = 'published'
      )
    )
  );

drop policy if exists story_people_select_member on public.story_people;
create policy story_people_select_member
  on public.story_people for select
  to authenticated
  using (
    exists (
      select 1
      from public.stories s
      where s.id = story_id
        and (
          public.is_family_member(s.family_id)
          or (
            public.is_family_tree_readable(s.family_id)
            and s.status = 'published'
          )
        )
    )
  );

drop policy if exists story_photos_select_member on storage.objects;
create policy story_photos_select_member
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'story-photos'
    and (
      public.is_family_member((storage.foldername(name))[1]::uuid)
      or (
        public.is_family_tree_readable((storage.foldername(name))[1]::uuid)
        and exists (
          select 1
          from public.stories s
          where s.id = (storage.foldername(name))[2]::uuid
            and s.family_id = (storage.foldername(name))[1]::uuid
            and s.status = 'published'
        )
      )
    )
  );
