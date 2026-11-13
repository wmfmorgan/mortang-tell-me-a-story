-- M13 Fit & Finish. Partial dates and editor rights.
-- Sorts after 20261011200000_start_a_timeline.sql. Does not edit earlier files.

create type public.story_date_precision as enum ('decade', 'year', 'month', 'day');

alter table public.stories
  add column date_precision public.story_date_precision,
  add column created_at timestamptz;

update public.stories
set created_at = coalesce(published_at, now())
where created_at is null;

alter table public.stories
  alter column created_at set default now(),
  alter column created_at set not null;

update public.stories
set timeframe_end = timeframe_start
where timeframe_end is null;

update public.stories
set date_precision = case
  when timeframe_start = timeframe_end then 'day'::public.story_date_precision
  when extract(year from timeframe_start)::int % 10 = 0
    and timeframe_start = make_date(extract(year from timeframe_start)::int, 1, 1)
    and timeframe_end = make_date(extract(year from timeframe_start)::int + 9, 12, 31)
    then 'decade'::public.story_date_precision
  when timeframe_start = make_date(extract(year from timeframe_start)::int, 1, 1)
    and timeframe_end = make_date(extract(year from timeframe_start)::int, 12, 31)
    then 'year'::public.story_date_precision
  when extract(day from timeframe_start) = 1
    and timeframe_end = (
      date_trunc('month', timeframe_start::timestamp) + interval '1 month - 1 day'
    )::date
    then 'month'::public.story_date_precision
  else null
end
where date_precision is null;

do $$
declare
  bad text;
begin
  select string_agg(id::text, ', ' order by id::text)
    into bad
  from public.stories
  where date_precision is null;
  if bad is not null then
    raise exception 'stories date shape does not match a precision: %', bad;
  end if;
end $$;

alter table public.stories
  alter column date_precision set not null,
  alter column timeframe_end set not null;

alter table public.stories drop constraint stories_timeframe_end_gte_start;

alter table public.stories add constraint stories_date_shape check (
  extract(year from timeframe_start) between 1000 and 9999
  and (
    (
      date_precision = 'day'::public.story_date_precision
      and timeframe_start = timeframe_end
    )
    or (
      date_precision = 'month'::public.story_date_precision
      and extract(day from timeframe_start) = 1
      and timeframe_end = (
        date_trunc('month', timeframe_start::timestamp) + interval '1 month - 1 day'
      )::date
    )
    or (
      date_precision = 'year'::public.story_date_precision
      and timeframe_start = make_date(extract(year from timeframe_start)::int, 1, 1)
      and timeframe_end = make_date(extract(year from timeframe_start)::int, 12, 31)
    )
    or (
      date_precision = 'decade'::public.story_date_precision
      and extract(year from timeframe_start)::int % 10 = 0
      and timeframe_start = make_date(extract(year from timeframe_start)::int, 1, 1)
      and timeframe_end = make_date(extract(year from timeframe_start)::int + 9, 12, 31)
    )
  )
);

create or replace function public.stories_date_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  -- Old inserts stored a single day as a null end. Fill that shape only.
  if new.timeframe_end is null then
    new.timeframe_end := new.timeframe_start;
  end if;
  if new.date_precision is null
     and new.timeframe_start is not distinct from new.timeframe_end then
    new.date_precision := 'day';
  end if;

  if tg_op = 'INSERT'
     and new.date_precision = 'decade'::public.story_date_precision then
    raise exception 'VALIDATION: year required';
  end if;

  if tg_op = 'UPDATE'
     and new.date_precision = 'decade'::public.story_date_precision
     and (
       old.date_precision is distinct from 'decade'::public.story_date_precision
       or new.timeframe_start is distinct from old.timeframe_start
       or new.timeframe_end is distinct from old.timeframe_end
     ) then
    raise exception 'VALIDATION: year required';
  end if;

  return new;
end;
$$;

drop trigger if exists stories_date_guard on public.stories;
create trigger stories_date_guard
  before insert or update on public.stories
  for each row
  execute function public.stories_date_guard();

revoke all on function public.stories_date_guard() from public, anon;

drop index if exists public.stories_family_id_timeframe_idx;

create index stories_family_id_order_idx
  on public.stories (family_id, timeframe_start, date_precision, created_at, id);

create or replace function public.can_edit_story(sid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select
      exists (
        select 1
        from public.families f
        where f.id = s.family_id
          and f.deleted_at is null
      )
      and (
        (
          s.author_id = (select auth.uid())
          and public.is_live_family_member(s.family_id)
        )
        or (
          s.status = 'published'::public.story_status
          and exists (
            select 1
            from public.memberships m
            where m.family_id = s.family_id
              and m.user_id = (select auth.uid())
              and m.role in (
                'owner'::public.membership_role,
                'co_owner'::public.membership_role
              )
          )
        )
      )
    from public.stories s
    where s.id = sid
  ), false);
$$;

revoke all on function public.can_edit_story(uuid) from public, anon;
grant execute on function public.can_edit_story(uuid) to authenticated;

create or replace function public.stories_edit_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.author_id is distinct from old.author_id
     or new.family_id is distinct from old.family_id
     or new.created_at is distinct from old.created_at then
    raise exception 'FORBIDDEN: field is locked';
  end if;
  if (select auth.uid()) is distinct from old.author_id then
    if new.status is distinct from old.status
       or new.published_at is distinct from old.published_at then
      raise exception 'FORBIDDEN: field is locked';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists stories_edit_guard on public.stories;
create trigger stories_edit_guard
  before update on public.stories
  for each row
  execute function public.stories_edit_guard();

revoke all on function public.stories_edit_guard() from public, anon;

drop policy if exists stories_update_author on public.stories;
create policy stories_update_editor
  on public.stories for update
  to authenticated
  using (public.can_edit_story(stories.id))
  with check (public.can_edit_story(stories.id));

drop policy if exists story_people_insert_author on public.story_people;
create policy story_people_insert_editor
  on public.story_people for insert
  to authenticated
  with check (
    public.can_edit_story(story_people.story_id)
    and exists (
      select 1
      from public.people p
      join public.stories s on s.id = story_people.story_id
      where p.id = story_people.person_id
        and p.family_id = s.family_id
    )
  );

drop policy if exists story_people_update_author on public.story_people;
create policy story_people_update_editor
  on public.story_people for update
  to authenticated
  using (public.can_edit_story(story_people.story_id))
  with check (
    public.can_edit_story(story_people.story_id)
    and exists (
      select 1
      from public.people p
      join public.stories s on s.id = story_people.story_id
      where p.id = story_people.person_id
        and p.family_id = s.family_id
    )
  );

drop policy if exists story_people_delete_author on public.story_people;
create policy story_people_delete_editor
  on public.story_people for delete
  to authenticated
  using (public.can_edit_story(story_people.story_id));

drop policy if exists photos_update_uploader_or_author on public.photos;
create policy photos_update_uploader_or_author
  on public.photos for update
  to authenticated
  using (
    public.can_contribute_to_story(photos.family_id, photos.story_id)
    and (
      photos.uploader_id = (select auth.uid())
      or public.can_edit_story(photos.story_id)
    )
  )
  with check (
    public.can_contribute_to_story(photos.family_id, photos.story_id)
    and (
      photos.uploader_id = (select auth.uid())
      or public.can_edit_story(photos.story_id)
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
      or public.can_edit_story(photos.story_id)
    )
    and (
      public.is_family_member(photos.family_id)
      or public.can_contribute_to_story(photos.family_id, photos.story_id)
    )
  );
