alter table public.stories alter column timeframe_start drop not null;
alter table public.stories alter column timeframe_end drop not null;
alter table public.stories alter column date_precision drop not null;

alter table public.stories
  add constraint stories_published_needs_date
  check (
    status <> 'published'
    or (timeframe_start is not null
        and timeframe_end is not null
        and date_precision is not null)
  );

create or replace function public.stories_date_guard()
 returns trigger
 language plpgsql
 set search_path to ''
as $function$
begin
  -- Old inserts stored a single day as a null end. Fill that shape only.
  if new.timeframe_end is null then
    new.timeframe_end := new.timeframe_start;
  end if;
  -- Default to day only when a date exists. Dateless drafts keep null precision.
  if new.date_precision is null
     and new.timeframe_start is not null
     and new.timeframe_start is not distinct from new.timeframe_end then
    new.date_precision := 'day';
  end if;

  if new.status = 'published'
     and (new.timeframe_start is null or new.date_precision is null) then
    raise exception 'VALIDATION: date required';
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
$function$;
