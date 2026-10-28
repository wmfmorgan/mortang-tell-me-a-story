-- M22 Family Landing. Cover column, path check, guard, private bucket, purge.
-- No featured_story_ids. family-covers is 5 MiB. Purge calls the Storage API.

alter table public.families
  add column cover_photo_path text null;

alter table public.families
  add constraint families_cover_photo_path_format check (
    cover_photo_path is null
    or cover_photo_path ~ (
      '^' || id::text || '/cover\.(jpg|jpeg|png|webp)$'
    )
  );

create or replace function public.families_guard_update()
returns trigger
language plpgsql
security invoker
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
      and not public.story_row_exists(old.origin_story_id)
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

  if new.cover_photo_path is distinct from old.cover_photo_path then
    if not (
      public.is_family_owner(old.id) or public.is_family_co_owner(old.id)
    ) then
      raise exception 'FORBIDDEN: owner or co-owner only';
    end if;
    if new.cover_photo_path is not null
       and new.cover_photo_path !~ (
         '^' || old.id::text || '/cover\.(jpg|jpeg|png|webp)$'
       ) then
      raise exception 'VALIDATION: cover_photo_path must be {family_id}/cover.(jpg|jpeg|png|webp)';
    end if;
  end if;

  return new;
end;
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'family-covers',
  'family-covers',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
);

create policy family_covers_select_member
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'family-covers'
    and array_length(storage.foldername(name), 1) = 1
    and lower(storage.filename(name)) in (
      'cover.jpg', 'cover.jpeg', 'cover.png', 'cover.webp'
    )
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
    and public.is_family_member(
      case
        when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then (storage.foldername(name))[1]::uuid
      end
    )
  );

create policy family_covers_insert_owner
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'family-covers'
    and array_length(storage.foldername(name), 1) = 1
    and lower(storage.filename(name)) in (
      'cover.jpg', 'cover.jpeg', 'cover.png', 'cover.webp'
    )
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
    and (
      public.is_family_owner(
        case
          when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (storage.foldername(name))[1]::uuid
        end
      )
      or public.is_family_co_owner(
        case
          when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (storage.foldername(name))[1]::uuid
        end
      )
    )
  );

create policy family_covers_update_owner
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'family-covers'
    and array_length(storage.foldername(name), 1) = 1
    and lower(storage.filename(name)) in (
      'cover.jpg', 'cover.jpeg', 'cover.png', 'cover.webp'
    )
    and (
      public.is_family_owner(
        case
          when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (storage.foldername(name))[1]::uuid
        end
      )
      or public.is_family_co_owner(
        case
          when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (storage.foldername(name))[1]::uuid
        end
      )
    )
  )
  with check (
    bucket_id = 'family-covers'
    and array_length(storage.foldername(name), 1) = 1
    and lower(storage.filename(name)) in (
      'cover.jpg', 'cover.jpeg', 'cover.png', 'cover.webp'
    )
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
    and (
      public.is_family_owner(
        case
          when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (storage.foldername(name))[1]::uuid
        end
      )
      or public.is_family_co_owner(
        case
          when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (storage.foldername(name))[1]::uuid
        end
      )
    )
  );

create policy family_covers_delete_owner
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'family-covers'
    and array_length(storage.foldername(name), 1) = 1
    and lower(storage.filename(name)) in (
      'cover.jpg', 'cover.jpeg', 'cover.png', 'cover.webp'
    )
    and (
      public.is_family_owner(
        case
          when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (storage.foldername(name))[1]::uuid
        end
      )
      or public.is_family_co_owner(
        case
          when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (storage.foldername(name))[1]::uuid
        end
      )
    )
  );

-- Synchronous Storage API client. pg_net queues until commit, so a purge
-- that must fail closed uses extensions.http instead.
create extension if not exists http with schema extensions;

create or replace function public.delete_family_cover_objects(p_family_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  api text;
  service_key text;
  headers extensions.http_header[];
  status int;
  content text;
  listed jsonb;
  item jsonb;
  object_name text;
  full_path text;
begin
  if p_family_id is null then
    return;
  end if;

  if current_setting('app.family_purge', true) is distinct from 'on' then
    raise exception 'FORBIDDEN: purge only';
  end if;

  if not exists (
    select 1
    from storage.objects as object
    where object.bucket_id = 'family-covers'
      and object.name like p_family_id::text || '/%'
  ) then
    return;
  end if;

  select secret.decrypted_secret
  into service_key
  from vault.decrypted_secrets as secret
  where secret.name = 'service_role_key'
  limit 1;

  if service_key is null or btrim(service_key) = '' then
    raise exception 'VALIDATION: service role key is not configured for cover purge';
  end if;

  select secret.decrypted_secret
  into api
  from vault.decrypted_secrets as secret
  where secret.name = 'storage_api_url'
  limit 1;

  if api is null or btrim(api) = '' then
    api := 'http://kong:8000/storage/v1';
  else
    api := rtrim(api, '/');
  end if;

  headers := array[
    extensions.http_header('Authorization', 'Bearer ' || service_key),
    extensions.http_header('apikey', service_key),
    extensions.http_header('Content-Type', 'application/json')
  ];

  select response.status, response.content
  into status, content
  from extensions.http((
    'POST',
    api || '/object/list/family-covers',
    headers,
    'application/json',
    jsonb_build_object(
      'prefix', p_family_id::text,
      'limit', 100,
      'offset', 0
    )::text
  )::extensions.http_request) as response;

  if status is null or status >= 300 then
    raise exception 'VALIDATION: cover purge failed';
  end if;

  listed := content::jsonb;
  if jsonb_typeof(listed) is distinct from 'array'
     or jsonb_array_length(listed) = 0 then
    select jsonb_agg(jsonb_build_object('name', 'cover.' || ext))
    into listed
    from unnest(array['jpg', 'jpeg', 'png', 'webp']) as ext;
  end if;

  for item in select value from jsonb_array_elements(listed)
  loop
    object_name := item->>'name';
    if object_name is null or btrim(object_name) = '' then
      continue;
    end if;
    if position('/' in object_name) > 0 then
      full_path := object_name;
    else
      full_path := p_family_id::text || '/' || object_name;
    end if;

    select response.status
    into status
    from extensions.http((
      'DELETE',
      api || '/object/family-covers/' || full_path,
      headers,
      null,
      null
    )::extensions.http_request) as response;

    if status is null or (status >= 300 and status <> 404) then
      raise exception 'VALIDATION: cover purge failed';
    end if;
  end loop;

  if exists (
    select 1
    from storage.objects as object
    where object.bucket_id = 'family-covers'
      and object.name like p_family_id::text || '/%'
  ) then
    raise exception 'VALIDATION: cover purge failed';
  end if;
end;
$$;

revoke all on function public.delete_family_cover_objects(uuid) from public, anon, authenticated;

create or replace function public.purge_expired_families()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  expired_id uuid;
begin
  perform set_config('app.family_purge', 'on', true);
  for expired_id in
    select id
    from public.families
    where deleted_at is not null
      and deleted_at < now() - interval '60 days'
  loop
    perform public.delete_family_cover_objects(expired_id);
    update public.families
    set parent_family_id = null
    where parent_family_id = expired_id;
    delete from public.families where id = expired_id;
  end loop;
end;
$$;

revoke all on function public.purge_expired_families() from public, anon, authenticated;
grant execute on function public.purge_expired_families() to service_role;
