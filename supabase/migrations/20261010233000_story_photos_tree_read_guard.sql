-- M12 security amendments (LOCKED Bill 2026-10-10).
-- Same-family child rows, safe storage path casts, and live-family membership.
-- Does not edit 20261010230000_family_tree_read.sql.

create or replace function public.is_live_family_member(fid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select auth.uid()) is not null
    and exists (
      select 1
      from public.memberships m
      join public.families f on f.id = m.family_id
      where m.family_id = fid
        and f.deleted_at is null
        and m.user_id = (select auth.uid())
    ),
    false
  );
$$;

revoke all on function public.is_live_family_member(uuid) from public, anon;
grant execute on function public.is_live_family_member(uuid)
  to authenticated, service_role;

create or replace function public.ensure_story_person_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  person public.people;
  resolved uuid;
  story_family uuid;
begin
  if tg_table_name = 'story_people' then
    select * into person from public.people where id = new.person_id;
    if not found then
      return new;
    end if;
    select s.family_id into story_family
    from public.stories s
    where s.id = new.story_id;
    if person.family_id is distinct from story_family then
      raise exception 'FORBIDDEN: person is not in this family';
    end if;
    resolved := public.resolve_person_user(person.user_id, person.email);
    perform public.upsert_story_member(story_family, resolved);
    return new;
  end if;

  if not exists (
    select 1
    from public.story_people sp
    join public.stories s on s.id = sp.story_id
    where sp.person_id = new.id
  ) then
    return new;
  end if;

  resolved := public.resolve_person_user(new.user_id, new.email);
  for story_family in
    select distinct s.family_id
    from public.story_people sp
    join public.stories s on s.id = sp.story_id
    where sp.person_id = new.id
  loop
    if new.family_id is distinct from story_family then
      raise exception 'FORBIDDEN: person is not in this family';
    end if;
    perform public.upsert_story_member(story_family, resolved);
  end loop;
  return new;
end;
$$;

revoke all on function public.ensure_story_person_membership() from public;

create or replace view public.people_tree_read
with (security_barrier = true) as
  select p.id, p.family_id, p.name, p.relationship
  from public.people p
  where public.is_live_family_member(p.family_id)
     or public.is_family_tree_readable(p.family_id);

-- stories
drop policy if exists stories_select_member on public.stories;
create policy stories_select_member
  on public.stories for select
  to authenticated
  using (
    public.is_live_family_member(stories.family_id)
    or (
      public.is_family_tree_readable(stories.family_id)
      and stories.status = 'published'
    )
  );

drop policy if exists stories_insert_member_author on public.stories;
create policy stories_insert_member_author
  on public.stories for insert
  to authenticated
  with check (
    public.is_live_family_member(stories.family_id)
    and stories.author_id = (select auth.uid())
  );

drop policy if exists stories_update_author on public.stories;
create policy stories_update_author
  on public.stories for update
  to authenticated
  using (
    stories.author_id = (select auth.uid())
    and public.is_live_family_member(stories.family_id)
  )
  with check (
    stories.author_id = (select auth.uid())
    and public.is_live_family_member(stories.family_id)
  );

-- people. SELECT stays member-only. Tree readers use people_tree_read.
drop policy if exists people_select_member on public.people;
create policy people_select_member
  on public.people for select
  to authenticated
  using (public.is_live_family_member(people.family_id));

drop policy if exists people_insert_member on public.people;
create policy people_insert_member
  on public.people for insert
  to authenticated
  with check (public.is_live_family_member(people.family_id));

drop policy if exists people_update_member on public.people;
create policy people_update_member
  on public.people for update
  to authenticated
  using (public.is_live_family_member(people.family_id))
  with check (public.is_live_family_member(people.family_id));

-- places
drop policy if exists places_select_member on public.places;
create policy places_select_member
  on public.places for select
  to authenticated
  using (
    public.is_live_family_member(places.family_id)
    or public.is_family_tree_readable(places.family_id)
  );

drop policy if exists places_insert_member on public.places;
create policy places_insert_member
  on public.places for insert
  to authenticated
  with check (public.is_live_family_member(places.family_id));

drop policy if exists places_update_member on public.places;
create policy places_update_member
  on public.places for update
  to authenticated
  using (public.is_live_family_member(places.family_id))
  with check (public.is_live_family_member(places.family_id));

-- photos
drop policy if exists photos_select_member on public.photos;
create policy photos_select_member
  on public.photos for select
  to authenticated
  using (
    public.is_live_family_member(photos.family_id)
    or (
      public.is_family_tree_readable(photos.family_id)
      and exists (
        select 1
        from public.stories s
        where s.id = photos.story_id
          and s.status = 'published'
      )
    )
  );

drop policy if exists photos_insert_member_uploader on public.photos;
create policy photos_insert_member_uploader
  on public.photos for insert
  to authenticated
  with check (
    public.is_live_family_member(photos.family_id)
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
    public.is_live_family_member(photos.family_id)
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
    public.is_live_family_member(photos.family_id)
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

-- comments
drop policy if exists comments_select_member on public.comments;
create policy comments_select_member
  on public.comments for select
  to authenticated
  using (
    public.is_live_family_member(comments.family_id)
    or (
      public.is_family_tree_readable(comments.family_id)
      and exists (
        select 1
        from public.stories s
        where s.id = comments.story_id
          and s.status = 'published'
      )
    )
  );

drop policy if exists comments_insert_member_author on public.comments;
create policy comments_insert_member_author
  on public.comments for insert
  to authenticated
  with check (
    public.is_live_family_member(comments.family_id)
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
    and public.is_live_family_member(comments.family_id)
  )
  with check (
    comments.author_id = (select auth.uid())
    and public.is_live_family_member(comments.family_id)
    and exists (
      select 1
      from public.stories s
      where s.id = comments.story_id
        and s.family_id = comments.family_id
    )
  );

-- perspectives
drop policy if exists perspectives_select_member on public.perspectives;
create policy perspectives_select_member
  on public.perspectives for select
  to authenticated
  using (
    public.is_live_family_member(perspectives.family_id)
    or (
      public.is_family_tree_readable(perspectives.family_id)
      and exists (
        select 1
        from public.stories s
        where s.id = perspectives.story_id
          and s.status = 'published'
      )
    )
  );

drop policy if exists perspectives_insert_member_author on public.perspectives;
create policy perspectives_insert_member_author
  on public.perspectives for insert
  to authenticated
  with check (
    public.is_live_family_member(perspectives.family_id)
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
    and public.is_live_family_member(perspectives.family_id)
  )
  with check (
    perspectives.author_id = (select auth.uid())
    and public.is_live_family_member(perspectives.family_id)
    and exists (
      select 1
      from public.stories s
      where s.id = perspectives.story_id
        and s.family_id = perspectives.family_id
    )
  );

-- story_people
drop policy if exists story_people_select_member on public.story_people;
create policy story_people_select_member
  on public.story_people for select
  to authenticated
  using (
    exists (
      select 1
      from public.stories s
      where s.id = story_people.story_id
        and (
          public.is_live_family_member(s.family_id)
          or (
            public.is_family_tree_readable(s.family_id)
            and s.status = 'published'
          )
        )
    )
  );

drop policy if exists story_people_insert_author on public.story_people;
create policy story_people_insert_author
  on public.story_people for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.stories s
      where s.id = story_people.story_id
        and s.author_id = (select auth.uid())
        and public.is_live_family_member(s.family_id)
    )
    and exists (
      select 1
      from public.people p
      join public.stories s on s.id = story_people.story_id
      where p.id = story_people.person_id
        and p.family_id = s.family_id
    )
  );

drop policy if exists story_people_update_author on public.story_people;
create policy story_people_update_author
  on public.story_people for update
  to authenticated
  using (
    exists (
      select 1
      from public.stories s
      where s.id = story_people.story_id
        and s.author_id = (select auth.uid())
        and public.is_live_family_member(s.family_id)
    )
  )
  with check (
    exists (
      select 1
      from public.stories s
      where s.id = story_people.story_id
        and s.author_id = (select auth.uid())
        and public.is_live_family_member(s.family_id)
    )
    and exists (
      select 1
      from public.people p
      join public.stories s on s.id = story_people.story_id
      where p.id = story_people.person_id
        and p.family_id = s.family_id
    )
  );

-- story-photos. Every path segment is cast only through the uuid case.
drop policy if exists story_photos_select_member on storage.objects;
create policy story_photos_select_member
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'story-photos'
    and (
      public.is_live_family_member(
        case
          when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (storage.foldername(storage.objects.name))[1]::uuid
        end
      )
      or (
        public.is_family_tree_readable(
          case
            when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            then (storage.foldername(storage.objects.name))[1]::uuid
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
            and s.status = 'published'
        )
      )
    )
  );

drop policy if exists story_photos_insert_member on storage.objects;
create policy story_photos_insert_member
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'story-photos'
    and array_length(storage.foldername(storage.objects.name), 1) = 2
    and public.is_live_family_member(
      case
        when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then (storage.foldername(storage.objects.name))[1]::uuid
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
    and public.is_live_family_member(
      case
        when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then (storage.foldername(storage.objects.name))[1]::uuid
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
    and public.is_live_family_member(
      case
        when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then (storage.foldername(storage.objects.name))[1]::uuid
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
    and public.is_family_member(
      case
        when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then (storage.foldername(storage.objects.name))[1]::uuid
      end
    )
  );
