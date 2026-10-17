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
