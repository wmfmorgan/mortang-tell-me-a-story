-- app.name_sync is how the profile trigger copies a name past the guard.

create or replace function public.profiles_sync_linked_person_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform set_config('app.name_sync','on',true);
  update public.people
  set name = new.display_name
  where user_id = new.id
    and name is distinct from new.display_name;
  return new;
end;
$$;

drop trigger if exists profiles_sync_linked_person_name on public.profiles;

create trigger profiles_sync_linked_person_name
  after update of display_name on public.profiles
  for each row
  execute function public.profiles_sync_linked_person_name();

revoke all on function public.profiles_sync_linked_person_name() from public, anon;

create or replace function public.people_guard_linked_name()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.user_id is null then
    return new;
  end if;

  if tg_op = 'INSERT' or new.user_id is distinct from old.user_id then
    new.name := (select display_name from public.profiles where id = new.user_id);
    return new;
  end if;

  if new.name is distinct from (select display_name from public.profiles where id = new.user_id)
     and coalesce(current_setting('app.name_sync', true), '') <> 'on' then
    raise exception 'FORBIDDEN: linked_person_name_locked'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists people_guard_linked_name on public.people;

create trigger people_guard_linked_name
  before insert or update on public.people
  for each row
  execute function public.people_guard_linked_name();

revoke all on function public.people_guard_linked_name() from public, anon;

update public.people p
set name = pr.display_name
from public.profiles pr
where p.user_id = pr.id
  and p.name is distinct from pr.display_name;
