-- Design Doc §3: private story-photos bucket + path-prefix is_family_member policies
-- Path: {family_id}/{story_id}/{photo_id}.(jpg|jpeg|png|webp)

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'story-photos',
  'story-photos',
  false,
  52428800,
  array['image/jpeg', 'image/png', 'image/webp']
);

create policy story_photos_select_member
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'story-photos'
    and public.is_family_member((storage.foldername(name))[1]::uuid)
  );

create policy story_photos_insert_member
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'story-photos'
    and public.is_family_member((storage.foldername(name))[1]::uuid)
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

create policy story_photos_update_member
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'story-photos'
    and public.is_family_member((storage.foldername(name))[1]::uuid)
  )
  with check (
    bucket_id = 'story-photos'
    and public.is_family_member((storage.foldername(name))[1]::uuid)
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

create policy story_photos_delete_member
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'story-photos'
    and public.is_family_member((storage.foldername(name))[1]::uuid)
  );
