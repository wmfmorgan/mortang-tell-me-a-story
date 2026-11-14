-- Column names live in stories_columns.txt. psql \copy reads that file
-- from the pg_prove mount of supabase/tests. The database container cannot.
begin;
create extension if not exists pgtap with schema extensions;

select plan(1);

create temporary table expected_stories_columns (
  ord bigint generated always as identity,
  column_name text not null
);

\copy expected_stories_columns (column_name) from 'stories_columns.txt'

select results_eq(
  $$select column_name::text collate "C"
      from information_schema.columns
     where table_schema = 'public'
       and table_name = 'stories'
     order by ordinal_position$$,
  $$select column_name collate "C"
      from expected_stories_columns
     order by ord$$,
  'public.stories columns match supabase/tests/stories_columns.txt'
);

select * from finish();
rollback;
