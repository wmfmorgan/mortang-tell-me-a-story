-- M11a: origin stories. One column, the read helper, the only client write,
-- contribute checks, and the same policy names as today.
-- Design Doc "M11a Origin stories" wins on data and RLS.

alter table public.families
  add column origin_story_id uuid null
  references public.stories (id) on delete set null;

create index families_origin_story_id_idx
  on public.families (origin_story_id);

create or replace function public.families_guard_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_setting('app.family_purge', true) = 'on' then
    return new;
  end if;

  if auth.uid() is null then
    if current_user in ('authenticated', 'anon') then
      raise exception 'FORBIDDEN: sign-in required';
    end if;
    return new;
  end if;

  if new.id is distinct from old.id
     or new.created_by is distinct from old.created_by
     or new.parent_family_id is distinct from old.parent_family_id then
    raise exception 'FORBIDDEN: field is locked';
  end if;

  -- A client write of origin_story_id is forbidden. The FK may clear the
  -- column only after the story row is already gone.
  if new.origin_story_id is distinct from old.origin_story_id
     and current_setting('app.family_origin', true) is distinct from 'on' then
    if not (
      new.origin_story_id is null
      and not exists (
        select 1 from public.stories s where s.id = old.origin_story_id
      )
    ) then
      raise exception 'FORBIDDEN: field is locked';
    end if;
  end if;

  if new.deleted_at is not null and old.deleted_at is null then
    if not public.is_family_owner(old.id) then
      raise exception 'FORBIDDEN: owner only';
    end if;
  elsif new.deleted_at is null and old.deleted_at is not null then
    if not (
      public.is_family_owner(old.id) or public.is_family_co_owner(old.id)
    ) then
      raise exception 'FORBIDDEN: owner or co-owner only';
    end if;
  elsif new.deleted_at is distinct from old.deleted_at then
    raise exception 'FORBIDDEN: owner only';
  end if;

  if new.name is distinct from old.name then
    if trim(coalesce(new.name, '')) = '' then
      raise exception 'VALIDATION: name is required';
    end if;
    if not (
      public.is_family_owner(old.id) or public.is_family_co_owner(old.id)
    ) then
      raise exception 'FORBIDDEN: owner or co-owner only';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.family_origin(fid uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select s.id
  from public.families f
  join public.stories s on s.id = f.origin_story_id
  join public.families sf on sf.id = s.family_id
  where f.id = fid
    and f.deleted_at is null
    and s.status = 'published'
    and sf.deleted_at is null
    and s.family_id = coalesce(f.parent_family_id, f.id);
$$;

create or replace function public.set_family_origin(
  p_family_id uuid,
  p_story_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  fam public.families;
  story public.stories;
  story_family public.families;
  expected uuid;
begin
  if (select auth.uid()) is null
     or not exists (
       select 1
       from public.families f
       where f.id = p_family_id
         and f.deleted_at is null
     )
     or not (
       public.is_family_owner(p_family_id)
       or public.is_family_co_owner(p_family_id)
     ) then
    raise exception 'FORBIDDEN';
  end if;

  select * into story from public.stories where id = p_story_id;
  if not found then
    raise exception 'NOT_FOUND';
  end if;

  if story.status is distinct from 'published' then
    raise exception 'VALIDATION: origin must be published';
  end if;

  select * into fam from public.families where id = p_family_id;
  expected := coalesce(fam.parent_family_id, fam.id);
  if story.family_id is distinct from expected then
    if fam.parent_family_id is null then
      raise exception 'VALIDATION: origin must be in this family';
    end if;
    raise exception 'VALIDATION: origin must be in parent family';
  end if;

  select * into story_family from public.families where id = story.family_id;
  if story_family.deleted_at is not null then
    raise exception 'VALIDATION: parent family is deleted';
  end if;

  perform set_config('app.family_origin', 'on', true);
  update public.families
  set origin_story_id = p_story_id
  where id = p_family_id;
  perform set_config('app.family_origin', 'off', true);
end;
$$;

create or replace function public.list_origin_dependents(p_story_id uuid)
returns table (family_id uuid, name text)
language sql
stable
security definer
set search_path = public
as $$
  select f.id, f.name
  from public.families f
  where public.family_origin(f.id) = p_story_id
    and exists (
      select 1
      from public.stories s
      where s.id = p_story_id
        and public.is_live_family_member(s.family_id)
    );
$$;

create or replace function public.can_contribute_to_story(fid uuid, sid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_live_family_member(fid)
    or exists (
      select 1
      from public.families c
      where c.parent_family_id = fid
        and c.deleted_at is null
        and public.family_origin(c.id) = sid
        and public.is_live_family_member(c.id)
    );
$$;

drop function public.list_family_tree(uuid);

create function public.list_family_tree(fid uuid)
returns table (
  id uuid,
  name text,
  parent_family_id uuid,
  branch_year int,
  origin_story_id uuid
)
language sql
stable
security definer
set search_path = public
as $$
  with recursive down as (
    select f.id, f.name, f.parent_family_id, f.branch_year,
           0 as depth, array[f.id] as path
    from public.families f
    where f.id = public.family_tree_root(fid) and f.deleted_at is null
    union all
    select c.id, c.name, c.parent_family_id, c.branch_year,
           d.depth + 1, d.path || c.id
    from public.families c
    join down d on c.parent_family_id = d.id
    where c.deleted_at is null and d.depth < 64 and not c.id = any(d.path)
  )
  select down.id, down.name, down.parent_family_id, down.branch_year,
         public.family_origin(down.id)
  from down
  where public.is_family_tree_readable(fid);
$$;

revoke all on function public.family_origin(uuid) from public, anon, authenticated;
revoke all on function public.can_contribute_to_story(uuid, uuid) from public, anon;
revoke all on function public.set_family_origin(uuid, uuid) from public, anon;
revoke all on function public.list_origin_dependents(uuid) from public, anon;
revoke all on function public.list_family_tree(uuid) from public, anon;
grant execute on function public.can_contribute_to_story(uuid, uuid) to authenticated, service_role;
grant execute on function public.set_family_origin(uuid, uuid) to authenticated, service_role;
grant execute on function public.list_origin_dependents(uuid) to authenticated, service_role;
grant execute on function public.list_family_tree(uuid) to authenticated, service_role;

-- Write policies. Insert and update swap is_live_family_member for
-- can_contribute_to_story. Delete keeps today's check and ORs the child branch.
-- Same policy names, so the count stays 44.

drop policy if exists comments_insert_member_author on public.comments;
create policy comments_insert_member_author
  on public.comments for insert
  to authenticated
  with check (
    public.can_contribute_to_story(comments.family_id, comments.story_id)
    and comments.author_id = (select auth.uid())
    and exists (
      select 1
      from public.stories s
      where s.id = comments.story_id
        and s.family_id = comments.family_id
    )
  );

drop policy if exists comments_update_author on public.comments;
create policy comments_update_author
  on public.comments for update
  to authenticated
  using (
    comments.author_id = (select auth.uid())
    and public.can_contribute_to_story(comments.family_id, comments.story_id)
  )
  with check (
    comments.author_id = (select auth.uid())
    and public.can_contribute_to_story(comments.family_id, comments.story_id)
    and exists (
      select 1
      from public.stories s
      where s.id = comments.story_id
        and s.family_id = comments.family_id
    )
  );

drop policy if exists comments_delete_author on public.comments;
create policy comments_delete_author
  on public.comments for delete
  to authenticated
  using (
    comments.author_id = (select auth.uid())
    and (
      public.is_family_member(comments.family_id)
      or public.can_contribute_to_story(comments.family_id, comments.story_id)
    )
  );

drop policy if exists perspectives_insert_member_author on public.perspectives;
create policy perspectives_insert_member_author
  on public.perspectives for insert
  to authenticated
  with check (
    public.can_contribute_to_story(perspectives.family_id, perspectives.story_id)
    and perspectives.author_id = (select auth.uid())
    and exists (
      select 1
      from public.stories s
      where s.id = perspectives.story_id
        and s.family_id = perspectives.family_id
    )
  );

drop policy if exists perspectives_update_author on public.perspectives;
create policy perspectives_update_author
  on public.perspectives for update
  to authenticated
  using (
    perspectives.author_id = (select auth.uid())
    and public.can_contribute_to_story(perspectives.family_id, perspectives.story_id)
  )
  with check (
    perspectives.author_id = (select auth.uid())
    and public.can_contribute_to_story(perspectives.family_id, perspectives.story_id)
    and exists (
      select 1
      from public.stories s
      where s.id = perspectives.story_id
        and s.family_id = perspectives.family_id
    )
  );

drop policy if exists perspectives_delete_author on public.perspectives;
create policy perspectives_delete_author
  on public.perspectives for delete
  to authenticated
  using (
    perspectives.author_id = (select auth.uid())
    and (
      public.is_family_member(perspectives.family_id)
      or public.can_contribute_to_story(perspectives.family_id, perspectives.story_id)
    )
  );

drop policy if exists photos_insert_member_uploader on public.photos;
create policy photos_insert_member_uploader
  on public.photos for insert
  to authenticated
  with check (
    public.can_contribute_to_story(photos.family_id, photos.story_id)
    and photos.uploader_id = (select auth.uid())
    and exists (
      select 1
      from public.stories s
      where s.id = photos.story_id
        and s.family_id = photos.family_id
    )
  );

drop policy if exists photos_update_uploader_or_author on public.photos;
create policy photos_update_uploader_or_author
  on public.photos for update
  to authenticated
  using (
    public.can_contribute_to_story(photos.family_id, photos.story_id)
    and (
      photos.uploader_id = (select auth.uid())
      or exists (
        select 1
        from public.stories s
        where s.id = photos.story_id
          and s.author_id = (select auth.uid())
      )
    )
  )
  with check (
    public.can_contribute_to_story(photos.family_id, photos.story_id)
    and (
      photos.uploader_id = (select auth.uid())
      or exists (
        select 1
        from public.stories s
        where s.id = photos.story_id
          and s.author_id = (select auth.uid())
      )
    )
    and exists (
      select 1
      from public.stories s
      where s.id = photos.story_id
        and s.family_id = photos.family_id
    )
  );

drop policy if exists photos_delete_uploader_or_author on public.photos;
create policy photos_delete_uploader_or_author
  on public.photos for delete
  to authenticated
  using (
    (
      photos.uploader_id = (select auth.uid())
      or exists (
        select 1
        from public.stories s
        where s.id = photos.story_id
          and s.author_id = (select auth.uid())
      )
    )
    and (
      public.is_family_member(photos.family_id)
      or public.can_contribute_to_story(photos.family_id, photos.story_id)
    )
  );

drop policy if exists story_photos_insert_member on storage.objects;
create policy story_photos_insert_member
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'story-photos'
    and array_length(storage.foldername(storage.objects.name), 1) = 2
    and public.can_contribute_to_story(
      case
        when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then (storage.foldername(storage.objects.name))[1]::uuid
      end,
      case
        when (storage.foldername(storage.objects.name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then (storage.foldername(storage.objects.name))[2]::uuid
      end
    )
    and exists (
      select 1
      from public.stories s
      where s.id = case
          when (storage.foldername(storage.objects.name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (storage.foldername(storage.objects.name))[2]::uuid
        end
        and s.family_id = case
          when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (storage.foldername(storage.objects.name))[1]::uuid
        end
    )
    and lower(storage.extension(storage.objects.name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

drop policy if exists story_photos_update_member on storage.objects;
create policy story_photos_update_member
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'story-photos'
    and array_length(storage.foldername(storage.objects.name), 1) = 2
    and public.can_contribute_to_story(
      case
        when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then (storage.foldername(storage.objects.name))[1]::uuid
      end,
      case
        when (storage.foldername(storage.objects.name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then (storage.foldername(storage.objects.name))[2]::uuid
      end
    )
    and exists (
      select 1
      from public.stories s
      where s.id = case
          when (storage.foldername(storage.objects.name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (storage.foldername(storage.objects.name))[2]::uuid
        end
        and s.family_id = case
          when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (storage.foldername(storage.objects.name))[1]::uuid
        end
    )
  )
  with check (
    bucket_id = 'story-photos'
    and array_length(storage.foldername(storage.objects.name), 1) = 2
    and public.can_contribute_to_story(
      case
        when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then (storage.foldername(storage.objects.name))[1]::uuid
      end,
      case
        when (storage.foldername(storage.objects.name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then (storage.foldername(storage.objects.name))[2]::uuid
      end
    )
    and exists (
      select 1
      from public.stories s
      where s.id = case
          when (storage.foldername(storage.objects.name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (storage.foldername(storage.objects.name))[2]::uuid
        end
        and s.family_id = case
          when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (storage.foldername(storage.objects.name))[1]::uuid
        end
    )
    and lower(storage.extension(storage.objects.name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

drop policy if exists story_photos_delete_member on storage.objects;
create policy story_photos_delete_member
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'story-photos'
    and (
      public.is_family_member(
        case
          when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (storage.foldername(storage.objects.name))[1]::uuid
        end
      )
      or (
        owner_id = (select auth.uid())::text
        and public.can_contribute_to_story(
          case
            when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            then (storage.foldername(storage.objects.name))[1]::uuid
          end,
          case
            when (storage.foldername(storage.objects.name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            then (storage.foldername(storage.objects.name))[2]::uuid
          end
        )
      )
    )
  );

-- TMAS-24-05: a tree reader sees a person or place only through a published story.
create or replace view public.people_tree_read
with (security_barrier = true) as
  select p.id, p.family_id, p.name, p.relationship
  from public.people p
  where public.is_live_family_member(p.family_id)
     or (
       public.is_family_tree_readable(p.family_id)
       and exists (
         select 1
         from public.story_people sp
         join public.stories s on s.id = sp.story_id
         where sp.person_id = p.id
           and s.family_id = p.family_id
           and s.status = 'published'
       )
     );

revoke all on public.people_tree_read from public, anon;
grant select on public.people_tree_read to authenticated;

drop policy if exists places_select_member on public.places;
create policy places_select_member
  on public.places for select
  to authenticated
  using (
    public.is_live_family_member(places.family_id)
    or (
      public.is_family_tree_readable(places.family_id)
      and exists (
        select 1
        from public.stories s
        where s.place_id = places.id
          and s.family_id = places.family_id
          and s.status = 'published'
      )
    )
  );
