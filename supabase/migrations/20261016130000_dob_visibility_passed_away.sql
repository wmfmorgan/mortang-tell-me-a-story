-- M14.3 DOB visibility and passed away.
-- The Supabase CLI already wraps this file in one transaction.
-- An inner begin/commit would commit that wrapper early, so this file has neither.
--
-- A column REVOKE is a no-op while table-level SELECT remains. The REVOKE
-- below is the spec statement. The table SELECT replacement is what makes
-- birth_date, birth_precision, and birth_visibility unreadable.

create type public.dob_visibility as enum (
  'hidden',
  'year',
  'year_month',
  'full'
);

alter table public.profiles
  add column birth_visibility public.dob_visibility not null default 'hidden';

alter table public.people
  add column passed_away boolean not null default false;

update public.people
set passed_away = true
where passing_date is not null;

do $$
begin
  if exists (
    select 1
    from public.people
    where passing_date is not null
      and passed_away is not true
  ) then
    raise exception 'carry-over left a passing_date without passed_away';
  end if;
end
$$;

alter table public.people
  drop constraint people_birth_pair,
  drop constraint people_birth_no_decade,
  drop constraint people_passing_pair,
  drop constraint people_passing_no_decade;

alter table public.people
  drop column birth_date,
  drop column birth_precision,
  drop column passing_date,
  drop column passing_precision;

revoke select on table public.profiles from authenticated, anon;

grant select (
  id,
  display_name,
  email,
  created_at,
  updated_at,
  avatar_path,
  about
) on table public.profiles to authenticated, anon;

revoke select (birth_date, birth_precision, birth_visibility)
  on table public.profiles
  from authenticated, anon;

revoke update on table public.people from authenticated, anon, public;

grant update (
  name,
  relationship,
  email,
  about,
  avatar_path,
  updated_at,
  passed_away
) on table public.people to authenticated;

create or replace function public.people_guard_passed_away()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.passed_away is distinct from old.passed_away
     and old.user_id = (select auth.uid()) then
    raise exception 'FORBIDDEN:';
  end if;
  return new;
end;
$$;

drop trigger if exists people_guard_passed_away on public.people;

create trigger people_guard_passed_away
  before update on public.people
  for each row
  execute function public.people_guard_passed_away();

revoke all on function public.people_guard_passed_away() from public, anon;

drop function public.person_profile(uuid);

create function public.person_profile(p_person_id uuid)
returns table (
  id uuid,
  family_id uuid,
  name text,
  birth_date date,
  birth_precision public.story_date_precision,
  about text,
  avatar_path text,
  passed_away boolean,
  is_linked boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  person public.people%rowtype;
  account_birth_date date;
  account_birth_precision public.story_date_precision;
  account_visibility public.dob_visibility;
  account_about text;
  account_avatar text;
  visibility_rank int;
  precision_rank int;
  coarse int;
  shown_date date;
  shown_precision public.story_date_precision;
begin
  if (select auth.uid()) is null or p_person_id is null then
    raise exception 'NOT_FOUND:';
  end if;

  select * into person
  from public.people
  where public.people.id = p_person_id;

  if not found or not public.is_tree_member(person.family_id) then
    raise exception 'NOT_FOUND:';
  end if;

  if person.user_id is not null then
    select
      profiles.birth_date,
      profiles.birth_precision,
      profiles.birth_visibility,
      profiles.about,
      profiles.avatar_path
    into
      account_birth_date,
      account_birth_precision,
      account_visibility,
      account_about,
      account_avatar
    from public.profiles
    where profiles.id = person.user_id;
  end if;

  if person.user_id is not null and person.user_id = (select auth.uid()) then
    shown_date := account_birth_date;
    shown_precision := account_birth_precision;
  elsif person.user_id is not null then
    visibility_rank := case account_visibility
      when 'hidden' then 0
      when 'year' then 1
      when 'year_month' then 2
      when 'full' then 3
      else 0
    end;
    precision_rank := case account_birth_precision
      when 'decade' then 0
      when 'year' then 1
      when 'month' then 2
      when 'day' then 3
      else 0
    end;
    coarse := least(visibility_rank, precision_rank);
    if account_birth_date is null or coarse = 0 then
      shown_date := null;
      shown_precision := null;
    elsif coarse = 1 then
      shown_date := date_trunc('year', account_birth_date)::date;
      shown_precision := 'year';
    elsif coarse = 2 then
      shown_date := date_trunc('month', account_birth_date)::date;
      shown_precision := 'month';
    else
      shown_date := account_birth_date;
      shown_precision := 'day';
    end if;
  end if;

  return query
  select
    person.id,
    person.family_id,
    person.name,
    shown_date,
    shown_precision,
    case
      when person.user_id is not null and account_about is not null
        then account_about
      else person.about
    end,
    case
      when person.user_id is not null and account_avatar is not null
        then account_avatar
      else person.avatar_path
    end,
    person.passed_away,
    person.user_id is not null;
end;
$$;

revoke all on function public.person_profile(uuid) from public, anon;
grant execute on function public.person_profile(uuid) to authenticated;

create function public.my_profile()
returns table (
  birth_date date,
  birth_precision public.story_date_precision,
  birth_visibility public.dob_visibility
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'NOT_FOUND:';
  end if;

  return query
  select profiles.birth_date, profiles.birth_precision, profiles.birth_visibility
  from public.profiles
  where profiles.id = (select auth.uid());
end;
$$;

revoke all on function public.my_profile() from public, anon;
grant execute on function public.my_profile() to authenticated;

create function public.mark_passed_away(p_person_id uuid, p_value boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  person public.people%rowtype;
begin
  if uid is null or p_person_id is null then
    raise exception 'NOT_FOUND:';
  end if;

  select * into person
  from public.people
  where public.people.id = p_person_id;

  if not found or not public.is_tree_member(person.family_id) then
    raise exception 'NOT_FOUND:';
  end if;

  if person.user_id is null then
    raise exception 'VALIDATION: person has not signed in';
  end if;

  if person.user_id = uid then
    raise exception 'VALIDATION: cannot mark yourself';
  end if;

  if not (
    public.is_family_owner(person.family_id)
    or public.is_family_co_owner(person.family_id)
  ) then
    raise exception 'FORBIDDEN:';
  end if;

  update public.people
  set passed_away = p_value,
      updated_at = now()
  where public.people.id = person.id;
end;
$$;

revoke all on function public.mark_passed_away(uuid, boolean) from public, anon;
grant execute on function public.mark_passed_away(uuid, boolean) to authenticated;

create or replace function public.list_unlinked_people(p_family_id uuid)
returns table (id uuid, family_id uuid, name text, email text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null
     or not exists (
       select 1
       from public.families f
       where f.id = p_family_id
         and f.deleted_at is null
     )
     or not public.is_tree_member(p_family_id) then
    raise exception 'NOT_FOUND:';
  end if;

  return query
  select p.id, p.family_id, p.name, p.email
  from public.people p
  join public.families f on f.id = p.family_id
  where f.deleted_at is null
    and p.user_id is null
    and not p.passed_away
    and public.family_tree_root(p.family_id) = public.family_tree_root(p_family_id)
    and not exists (
      select 1
      from public.invites i
      where i.person_id = p.id
        and i.status = 'pending'
        and i.expires_at > now()
    )
  order by p.name, p.id;
end;
$$;

revoke all on function public.list_unlinked_people(uuid) from public, anon, service_role;
grant execute on function public.list_unlinked_people(uuid) to authenticated;

create or replace function public.assert_invite_person(
  p_family_id uuid,
  p_person_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  person public.people;
begin
  if (select auth.uid()) is null
     or not exists (
       select 1
       from public.families f
       where f.id = p_family_id
         and f.deleted_at is null
     )
     or not public.is_tree_member(p_family_id) then
    raise exception 'NOT_FOUND:';
  end if;

  select * into person
  from public.people
  where id = p_person_id;

  if not found
     or public.family_tree_root(person.family_id)
        is distinct from public.family_tree_root(p_family_id) then
    raise exception 'NOT_FOUND:';
  end if;

  if person.user_id is not null then
    raise exception 'VALIDATION: person is already linked';
  end if;

  if person.passed_away then
    raise exception 'VALIDATION: person has passed';
  end if;
end;
$$;
