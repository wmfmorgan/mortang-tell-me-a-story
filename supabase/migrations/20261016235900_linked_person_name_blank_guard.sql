-- people.name is not null. A blank display_name keeps the name already on the row.

create or replace function public.profiles_sync_linked_person_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform set_config('app.name_sync','on',true);
  update public.people
  set name = coalesce(nullif(btrim(new.display_name), ''), name)
  where user_id = new.id
    and name is distinct from coalesce(nullif(btrim(new.display_name), ''), name);
  perform set_config('app.name_sync','',true);
  return new;
end;
$$;

create or replace function public.people_guard_linked_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.user_id is null then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and new.name is not distinct from old.name
     and new.user_id is not distinct from old.user_id then
    return new;
  end if;

  if tg_op = 'INSERT' or new.user_id is distinct from old.user_id then
    if tg_op = 'INSERT' then
      new.name := coalesce(
        nullif(btrim((select display_name from public.profiles where id = new.user_id)), ''),
        new.name
      );
    else
      new.name := coalesce(
        nullif(btrim((select display_name from public.profiles where id = new.user_id)), ''),
        old.name
      );
    end if;
    return new;
  end if;

  if new.name is distinct from coalesce(
       nullif(btrim((select display_name from public.profiles where id = new.user_id)), ''),
       old.name
     )
     and coalesce(current_setting('app.name_sync', true), '') <> 'on' then
    raise exception 'FORBIDDEN: linked_person_name_locked'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

create or replace function public.backfill_linked_person_names()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  n int;
begin
  update public.people p
  set name = coalesce(nullif(btrim(pr.display_name), ''), p.name)
  from public.profiles pr
  where p.user_id = pr.id
    and p.name is distinct from coalesce(nullif(btrim(pr.display_name), ''), p.name);
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.backfill_linked_person_names()
  from public, anon, authenticated, service_role;

select public.backfill_linked_person_names();
