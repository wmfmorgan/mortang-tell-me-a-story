-- #84 D1–D4. Original storage_path and attachment policies remain intact.
alter table public.photos
  add column edited_storage_path text null,
  add column edit_version bigint not null default 0;

alter table public.photos
  add constraint photos_edit_version_nonnegative
  check (edit_version >= 0),
  add constraint photos_edited_path_version_positive
  check (edited_storage_path is null or edit_version > 0),
  add constraint photos_edited_path_shape
  check (
    edited_storage_path is null
    or edited_storage_path =
      (family_id::text || '/' || story_id::text || '/' || id::text
       || '.edited.' || edit_version::text || '.jpg')
  );

-- Rev 1.2 M84-01: privileges, not a caller-settable GUC, are the primary
-- authenticated/anon write boundary. On main PhotosApi.setHeroPhoto is the
-- only photo UPDATE site and sets sort_order only. Existing SELECT/INSERT/
-- DELETE behavior is unchanged. The definer owner is outside these client
-- role revocations; table/superuser bypass is outside the client trust model.
-- Rev 1.4: drop triggers before narrowing table UPDATE to sort_order. The
-- baseline before-update guard must not inspect new edit columns when an
-- authenticated client subsequently updates only sort_order. Re-equip one
-- trigger before clients can run post-migration writes.
drop trigger if exists photos_guard_update on public.photos;
drop trigger if exists photos_edit_fields_guard on public.photos;
drop function if exists public.photo_edit_fields_guard();
revoke update on public.photos from public, anon, authenticated;
revoke update (edited_storage_path, edit_version) on public.photos
  from public, anon, authenticated;
grant update (sort_order) on public.photos to authenticated;

-- Rev 1.4a: scope authenticated INSERT to the exact PhotosApi.attach payload
-- (created_at is DB-defaulted and is not a client-supplied insert field).
-- Save/reset only UPDATE. Main has no photo-row-insert RPC/Edge Function.
-- PUBLIC was the migration-dated INSERT grantee on main; anon has no INSERT
-- policy and is explicitly revoked as part of default-deny hardening.
revoke insert on public.photos from public, anon, authenticated;
grant insert (
  id, family_id, story_id, uploader_id, storage_path, sort_order
) on public.photos to authenticated;

-- SECURITY INVOKER is retained from 20261011190823. Baseline behavior is
-- retained verbatim in the ordinary branch. Only the trusted shared-owner
-- path allows the two edit columns, still with all other fields locked.
-- current_user is the invoker: an RPC's definer owner inside its SQL update
-- (not session_user, auth.uid(), or a caller-controlled GUC). Requiring BOTH
-- object owners to equal current_user is robust across local postgres versus
-- production supabase_admin role names, provided migrations own both objects.
create or replace function public.photos_guard_update()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.edited_storage_path is not null
       or new.edit_version is distinct from 0 then
      raise exception 'FORBIDDEN: field is locked';
    end if;
    return new;
  end if;
  if (to_jsonb(new) - 'sort_order')
       is distinct from (to_jsonb(old) - 'sort_order') then
    if not (
      (to_jsonb(new) - 'sort_order' - 'edited_storage_path' - 'edit_version')
        is not distinct from
      (to_jsonb(old) - 'sort_order' - 'edited_storage_path' - 'edit_version')
      and current_user = (
        select r.rolname
        from pg_catalog.pg_class c
        join pg_catalog.pg_roles r on r.oid = c.relowner
        where c.oid = 'public.photos'::regclass
      )
      and current_user = (
        select r.rolname
        from pg_catalog.pg_proc p
        join pg_catalog.pg_roles r on r.oid = p.proowner
        where p.oid = 'public.save_photo_edit(uuid, bigint, text)'::regprocedure
      )
      and current_user = (
        select r.rolname
        from pg_catalog.pg_proc p
        join pg_catalog.pg_roles r on r.oid = p.proowner
        where p.oid = 'public.reset_photo_edit(uuid, bigint)'::regprocedure
      )
    ) then
      raise exception 'FORBIDDEN: field is locked';
    end if;
    if new.edit_version is distinct from old.edit_version + 1 then
      raise exception 'FORBIDDEN: field is locked';
    end if;
  end if;
  return new;
end;
$$;

create trigger photos_guard_update
  before insert or update on public.photos
  for each row
  execute function public.photos_guard_update();

revoke all on function public.photos_guard_update()
  from public, anon, authenticated;

create or replace function public.save_photo_edit(
  p_photo_id uuid,
  p_expected_version bigint,
  p_edited_path text
)
returns table(edit_version bigint, previous_path text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_row public.photos;
begin
  select p.* into current_row
  from public.photos p
  where p.id = p_photo_id
  for update;
  if not found or not public.can_edit_story(current_row.story_id) then
    raise exception 'FORBIDDEN: photo edit denied';
  end if;
  if current_row.edit_version <> p_expected_version then
    raise exception 'CONFLICT: photo edit version';
  end if;
  if p_edited_path is null
     or p_edited_path <> (
       current_row.family_id::text || '/' || current_row.story_id::text
       || '/' || current_row.id::text || '.edited.'
       || (p_expected_version + 1)::text || '.jpg'
     ) then
    raise exception 'VALIDATION: invalid edited path';
  end if;
  return query
    update public.photos p
    set edited_storage_path = p_edited_path,
        edit_version = p_expected_version + 1
    where p.id = p_photo_id
      and p.edit_version = p_expected_version
    returning p.edit_version, current_row.edited_storage_path;
end;
$$;

create or replace function public.reset_photo_edit(
  p_photo_id uuid,
  p_expected_version bigint
)
returns table(edit_version bigint, previous_path text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_row public.photos;
begin
  select p.* into current_row
  from public.photos p
  where p.id = p_photo_id
  for update;
  if not found or not public.can_edit_story(current_row.story_id) then
    raise exception 'FORBIDDEN: photo edit denied';
  end if;
  if current_row.edit_version <> p_expected_version then
    raise exception 'CONFLICT: photo edit version';
  end if;
  return query
    update public.photos p
    set edited_storage_path = null,
        edit_version = p_expected_version + 1
    where p.id = p_photo_id
      and p.edit_version = p_expected_version
    returning p.edit_version, current_row.edited_storage_path;
end;
$$;

revoke all on function public.save_photo_edit(uuid, bigint, text)
  from public, anon, authenticated;
revoke all on function public.reset_photo_edit(uuid, bigint)
  from public, anon, authenticated;
grant execute on function public.save_photo_edit(uuid, bigint, text)
  to authenticated;
grant execute on function public.reset_photo_edit(uuid, bigint)
  to authenticated;

-- Helpers used below return NULL for malformed names instead of casting
-- attacker-controlled path segments to uuid.
create or replace function public.story_photo_story_id(object_name text)
returns uuid
language sql
immutable
strict
security invoker
set search_path = ''
as $$
  select case
    when array_length(storage.foldername(object_name), 1) = 2
     and (storage.foldername(object_name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then (storage.foldername(object_name))[2]::uuid
  end;
$$;

create or replace function public.story_photo_family_id(object_name text)
returns uuid
language sql
immutable
strict
security invoker
set search_path = ''
as $$
  select case
    when array_length(storage.foldername(object_name), 1) = 2
     and (storage.foldername(object_name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then (storage.foldername(object_name))[1]::uuid
  end;
$$;

create or replace function public.story_photo_exists(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.stories s
    where s.id = public.story_photo_story_id(object_name)
      and s.family_id = public.story_photo_family_id(object_name)
  );
$$;

-- The locked paste called can_edit_story(p) outside the subquery, which does
-- not parse. This is the join that same comment describes: no row is false.
create or replace function public.can_edit_story_photo_object(object_name text)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce((
    select public.can_edit_story(p.story_id)
    from public.photos p
    join public.stories s on s.id = p.story_id and s.family_id = p.family_id
    where p.story_id = public.story_photo_story_id(object_name)
      and p.family_id = public.story_photo_family_id(object_name)
      and (s.status = 'published' or s.author_id = (select auth.uid()))
      and object_name like '%.edited.%'
      and object_name = (
        p.family_id::text || '/' || p.story_id::text || '/' || p.id::text
        || '.edited.' || regexp_replace(
          storage.filename(object_name), '^.*\.edited\.([0-9]+)\.jpg$', '\1'
        ) || '.jpg'
      )
  ), false);
$$;

revoke all on function public.story_photo_story_id(text)
  from public, anon, authenticated;
grant execute on function public.story_photo_story_id(text) to authenticated;
revoke all on function public.story_photo_family_id(text)
  from public, anon, authenticated;
grant execute on function public.story_photo_family_id(text) to authenticated;
revoke all on function public.story_photo_exists(text)
  from public, anon, authenticated;
revoke all on function public.can_edit_story_photo_object(text)
  from public, anon;
grant execute on function public.can_edit_story_photo_object(text)
  to authenticated;

-- Rev 1.3: INSERT keeps the origin_stories predicate for names that are not
-- edited objects. UPDATE and DELETE keep the draft_write_policies predicates
-- word for word, including the published-or-author check and the delete
-- story_row_exists orphan branch. Edited names use can_edit_story_photo_object.
drop policy if exists story_photos_insert_member on storage.objects;
create policy story_photos_insert_member
  on storage.objects for insert
  to authenticated
  with check (
    ((storage.objects.name not like '%.edited.%') and
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
    )
    or (
      bucket_id = 'story-photos'
      and storage.objects.name like '%.edited.%'
      and public.can_edit_story_photo_object(storage.objects.name)
    )
  );

drop policy if exists story_photos_update_member on storage.objects;
create policy story_photos_update_member
  on storage.objects for update
  to authenticated
  using (
    ((storage.objects.name not like '%.edited.%') and
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
    or (
      bucket_id = 'story-photos'
      and storage.objects.name like '%.edited.%'
      and public.can_edit_story_photo_object(storage.objects.name)
    )
  )
  with check (
    ((storage.objects.name not like '%.edited.%') and
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
    )
    or (
      bucket_id = 'story-photos'
      and storage.objects.name like '%.edited.%'
      and public.can_edit_story_photo_object(storage.objects.name)
    )
  );

drop policy if exists story_photos_delete_member on storage.objects;
create policy story_photos_delete_member
  on storage.objects for delete
  to authenticated
  using (
    ((storage.objects.name not like '%.edited.%') and
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
    )
    or (
      bucket_id = 'story-photos'
      and storage.objects.name like '%.edited.%'
      and public.can_edit_story_photo_object(storage.objects.name)
    )
  );
