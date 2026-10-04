-- M6: Realtime postgres_changes filtered by family_id.
-- family_id is not the primary key, so deletes only match that filter
-- when the old row is fully replicated.

alter table public.stories replica identity full;
alter table public.photos replica identity full;
alter table public.comments replica identity full;
alter table public.perspectives replica identity full;

do $$
declare
  tbl text;
begin
  foreach tbl in array array['stories', 'photos', 'comments', 'perspectives']
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = tbl
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        tbl
      );
    end if;
  end loop;
end $$;
