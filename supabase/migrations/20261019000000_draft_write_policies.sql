-- #42 cleanup, TMAS-40-01: author-only drafts, write side (Gilfoyle, LOCKED 2026-10-19).
-- alter policy only. Policy count stays 47. No new function, no new grant.

alter policy comments_delete_author on public.comments
  using (author_id = (select auth.uid()) and public.can_contribute_to_story(family_id, story_id));

alter policy perspectives_delete_author on public.perspectives
  using (author_id = (select auth.uid()) and public.can_contribute_to_story(family_id, story_id));

alter policy photos_delete_uploader_or_author on public.photos
  using (
    (uploader_id = (select auth.uid()) or public.can_edit_story(story_id))
    and public.can_contribute_to_story(family_id, story_id)
  );

alter policy story_photos_update_member on storage.objects
  using (
    bucket_id = 'story-photos'
    and array_length(storage.foldername(storage.objects.name), 1) = 2
    and (
      public.is_live_family_member(
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
        and (s.status = 'published' or s.author_id = (select auth.uid()))
    )
  )
  with check (
    bucket_id = 'story-photos'
    and array_length(storage.foldername(storage.objects.name), 1) = 2
    and (
      public.is_live_family_member(
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
        and (s.status = 'published' or s.author_id = (select auth.uid()))
    )
    and lower(storage.extension(storage.objects.name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

alter policy story_photos_delete_member on storage.objects
  using (
    bucket_id = 'story-photos'
    and (
      (
        public.is_family_member(
          case
            when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            then (storage.foldername(storage.objects.name))[1]::uuid
          end
        )
        and (
          exists (
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
              and (s.status = 'published' or s.author_id = (select auth.uid()))
          )
          or not public.story_row_exists(
            case
              when (storage.foldername(storage.objects.name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
              then (storage.foldername(storage.objects.name))[2]::uuid
            end
          )
        )
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
