-- Drafts stay visible to the author until publish. Policy count stays 47.
-- The existing can_contribute_to_story predicate is parenthesized so the
-- author check applies to both the live-member branch and the child branch.

alter policy stories_select_member on public.stories
  using (
    (is_live_family_member(family_id) AND (status = 'published' OR author_id = (select auth.uid())))
    OR (is_family_tree_readable(family_id) AND status = 'published')
  );

alter policy comments_select_member on public.comments
  using (
    public.is_live_family_member(comments.family_id)
    and exists (
      select 1
      from public.stories s
      where s.id = comments.story_id
        and (
          s.status = 'published'
          or s.author_id = (select auth.uid())
        )
    )
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

alter policy perspectives_select_member on public.perspectives
  using (
    public.is_live_family_member(perspectives.family_id)
    and exists (
      select 1
      from public.stories s
      where s.id = perspectives.story_id
        and (
          s.status = 'published'
          or s.author_id = (select auth.uid())
        )
    )
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

alter policy photos_select_member on public.photos
  using (
    public.is_live_family_member(photos.family_id)
    and exists (
      select 1
      from public.stories s
      where s.id = photos.story_id
        and (
          s.status = 'published'
          or s.author_id = (select auth.uid())
        )
    )
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

alter policy story_people_select_member on public.story_people
  using (
    exists (
      select 1
      from public.stories s
      where s.id = story_people.story_id
        and (
          public.is_live_family_member(s.family_id)
          and (
            s.status = 'published'
            or s.author_id = (select auth.uid())
          )
          or (
            public.is_family_tree_readable(s.family_id)
            and s.status = 'published'
          )
        )
    )
  );

alter policy story_photos_select_member on storage.objects
  using (
    bucket_id = 'story-photos'
    and (
      (
        public.is_live_family_member(
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
            and (
              s.status = 'published'
              or s.author_id = (select auth.uid())
            )
        )
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

create or replace function public.can_contribute_to_story(fid uuid, sid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (
      public.is_live_family_member(fid)
      or exists (
        select 1
        from public.families c
        where c.parent_family_id = fid
          and c.deleted_at is null
          and public.family_origin(c.id) = sid
          and public.is_live_family_member(c.id)
      )
    )
    and exists (
      select 1
      from public.stories s
      where s.id = sid
        and (
          s.status = 'published'
          or s.author_id = (select auth.uid())
        )
    );
$$;
