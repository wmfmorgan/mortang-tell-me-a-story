-- M11a.2: lock identity columns, one NOT_FOUND after a deleted-parent check,
-- empty search_path on the six origin definers, and a 20-photo cap.
-- No policy changes. Grants on the six definers stay as 20261011150000 left them.

create or replace function public.comments_guard_update()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (to_jsonb(new) - 'body' - 'updated_at')
       is distinct from (to_jsonb(old) - 'body' - 'updated_at') then
    raise exception 'FORBIDDEN: field is locked';
  end if;
  return new;
end;
$$;

create or replace function public.perspectives_guard_update()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (to_jsonb(new) - 'body' - 'updated_at')
       is distinct from (to_jsonb(old) - 'body' - 'updated_at') then
    raise exception 'FORBIDDEN: field is locked';
  end if;
  return new;
end;
$$;

create or replace function public.photos_guard_update()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (to_jsonb(new) - 'sort_order')
       is distinct from (to_jsonb(old) - 'sort_order') then
    raise exception 'FORBIDDEN: field is locked';
  end if;
  return new;
end;
$$;

drop trigger if exists comments_guard_update on public.comments;
create trigger comments_guard_update
  before update on public.comments
  for each row
  execute function public.comments_guard_update();

drop trigger if exists perspectives_guard_update on public.perspectives;
create trigger perspectives_guard_update
  before update on public.perspectives
  for each row
  execute function public.perspectives_guard_update();

drop trigger if exists photos_guard_update on public.photos;
create trigger photos_guard_update
  before update on public.photos
  for each row
  execute function public.photos_guard_update();

revoke all on function public.comments_guard_update() from public, anon;
revoke all on function public.perspectives_guard_update() from public, anon;
revoke all on function public.photos_guard_update() from public, anon;

create or replace function public.set_family_origin(
  p_family_id uuid,
  p_story_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  fam public.families;
  parent public.families;
  story public.stories;
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

  select * into fam from public.families where id = p_family_id;
  if fam.parent_family_id is not null then
    select * into parent from public.families where id = fam.parent_family_id;
    if not found or parent.deleted_at is not null then
      raise exception 'VALIDATION: parent family is deleted';
    end if;
  end if;

  expected := coalesce(fam.parent_family_id, fam.id);
  select * into story from public.stories where id = p_story_id;
  if not found
     or story.status is distinct from 'published'
     or story.family_id is distinct from expected then
    raise exception 'NOT_FOUND';
  end if;

  perform pg_catalog.set_config('app.family_origin', 'on', true);
  update public.families
  set origin_story_id = p_story_id
  where id = p_family_id;
  perform pg_catalog.set_config('app.family_origin', 'off', true);
end;
$$;

create or replace function public.story_row_exists(sid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.stories where id = sid);
$$;

create or replace function public.family_origin(fid uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
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

create or replace function public.list_origin_dependents(p_story_id uuid)
returns table (family_id uuid, name text)
language sql
stable
security definer
set search_path = ''
as $$
  select f.id, f.name
  from public.families f
  where f.origin_story_id = p_story_id
    and public.family_origin(f.id) = p_story_id
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
set search_path = ''
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

create or replace function public.list_family_tree(fid uuid)
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
set search_path = ''
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

create or replace function public.photos_cap_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  perform 1
  from public.stories
  where id = new.story_id
  for no key update;
  select count(*)::integer into n
  from public.photos
  where story_id = new.story_id;
  if n >= 20 then
    raise exception 'VALIDATION: photo limit reached';
  end if;
  return new;
end;
$$;

drop trigger if exists photos_cap_insert on public.photos;
create trigger photos_cap_insert
  before insert on public.photos
  for each row
  execute function public.photos_cap_insert();

revoke all on function public.photos_cap_insert() from public, anon;
