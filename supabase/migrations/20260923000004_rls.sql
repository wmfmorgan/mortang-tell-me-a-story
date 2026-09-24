-- Design Doc §2: is_family_member + RLS matrix
-- families INSERT: create_family(name) security definer RPC inserts family + membership atomically
-- (client cannot INSERT memberships; Edge/security definer only)

create or replace function public.is_family_member(fid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.memberships m
    where m.family_id = fid and m.user_id = auth.uid()
  );
$$;

revoke all on function public.is_family_member(uuid) from public;
grant execute on function public.is_family_member(uuid) to authenticated, service_role;

create or replace function public.create_family(p_name text)
returns public.families
language plpgsql
security definer
set search_path = public
as $$
declare
  new_family public.families;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  insert into public.families (name, created_by)
  values (p_name, auth.uid())
  returning * into new_family;

  insert into public.memberships (family_id, user_id, role)
  values (new_family.id, auth.uid(), 'member');

  return new_family;
end;
$$;

revoke all on function public.create_family(text) from public;
grant execute on function public.create_family(text) to authenticated, service_role;

alter table public.profiles enable row level security;
alter table public.families enable row level security;
alter table public.memberships enable row level security;
alter table public.people enable row level security;
alter table public.places enable row level security;
alter table public.stories enable row level security;
alter table public.story_people enable row level security;
alter table public.photos enable row level security;
alter table public.comments enable row level security;
alter table public.perspectives enable row level security;
alter table public.invites enable row level security;

-- profiles: SELECT/UPDATE/DELETE own id; INSERT trigger only (no client insert policy)
create policy profiles_select_own
  on public.profiles for select
  to authenticated
  using (id = auth.uid());

create policy profiles_update_own
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy profiles_delete_own
  on public.profiles for delete
  to authenticated
  using (id = auth.uid());

-- families: SELECT/UPDATE/DELETE member; INSERT via create_family only
create policy families_select_member
  on public.families for select
  to authenticated
  using (public.is_family_member(id));

create policy families_update_member
  on public.families for update
  to authenticated
  using (public.is_family_member(id))
  with check (public.is_family_member(id));

create policy families_delete_member
  on public.families for delete
  to authenticated
  using (public.is_family_member(id));

-- memberships: SELECT member; INSERT/UPDATE/DELETE Edge/security definer only (no client policies)
create policy memberships_select_member
  on public.memberships for select
  to authenticated
  using (public.is_family_member(family_id));

-- people
create policy people_select_member
  on public.people for select
  to authenticated
  using (public.is_family_member(family_id));

create policy people_insert_member
  on public.people for insert
  to authenticated
  with check (public.is_family_member(family_id));

create policy people_update_member
  on public.people for update
  to authenticated
  using (public.is_family_member(family_id))
  with check (public.is_family_member(family_id));

create policy people_delete_member
  on public.people for delete
  to authenticated
  using (public.is_family_member(family_id));

-- places
create policy places_select_member
  on public.places for select
  to authenticated
  using (public.is_family_member(family_id));

create policy places_insert_member
  on public.places for insert
  to authenticated
  with check (public.is_family_member(family_id));

create policy places_update_member
  on public.places for update
  to authenticated
  using (public.is_family_member(family_id))
  with check (public.is_family_member(family_id));

create policy places_delete_member
  on public.places for delete
  to authenticated
  using (public.is_family_member(family_id));

-- stories: SELECT member; INSERT member + author_id = uid;
-- UPDATE/DELETE author + is_family_member (blocks cross-family move / ex-member writes)
create policy stories_select_member
  on public.stories for select
  to authenticated
  using (public.is_family_member(family_id));

create policy stories_insert_member_author
  on public.stories for insert
  to authenticated
  with check (
    public.is_family_member(family_id)
    and author_id = auth.uid()
  );

create policy stories_update_author
  on public.stories for update
  to authenticated
  using (
    author_id = auth.uid()
    and public.is_family_member(family_id)
  )
  with check (
    author_id = auth.uid()
    and public.is_family_member(family_id)
  );

create policy stories_delete_author
  on public.stories for delete
  to authenticated
  using (
    author_id = auth.uid()
    and public.is_family_member(family_id)
  );

-- story_people: SELECT member (via story); INSERT/UPDATE/DELETE story author
create policy story_people_select_member
  on public.story_people for select
  to authenticated
  using (
    exists (
      select 1 from public.stories s
      where s.id = story_id and public.is_family_member(s.family_id)
    )
  );

create policy story_people_insert_author
  on public.story_people for insert
  to authenticated
  with check (
    exists (
      select 1 from public.stories s
      where s.id = story_id and s.author_id = auth.uid()
    )
  );

create policy story_people_update_author
  on public.story_people for update
  to authenticated
  using (
    exists (
      select 1 from public.stories s
      where s.id = story_id and s.author_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.stories s
      where s.id = story_id and s.author_id = auth.uid()
    )
  );

create policy story_people_delete_author
  on public.story_people for delete
  to authenticated
  using (
    exists (
      select 1 from public.stories s
      where s.id = story_id and s.author_id = auth.uid()
    )
  );

-- photos: SELECT member; INSERT member + uploader_id = uid;
-- UPDATE/DELETE (uploader or story author) + is_family_member
create policy photos_select_member
  on public.photos for select
  to authenticated
  using (public.is_family_member(family_id));

create policy photos_insert_member_uploader
  on public.photos for insert
  to authenticated
  with check (
    public.is_family_member(family_id)
    and uploader_id = auth.uid()
  );

create policy photos_update_uploader_or_author
  on public.photos for update
  to authenticated
  using (
    public.is_family_member(family_id)
    and (
      uploader_id = auth.uid()
      or exists (
        select 1 from public.stories s
        where s.id = story_id and s.author_id = auth.uid()
      )
    )
  )
  with check (
    public.is_family_member(family_id)
    and (
      uploader_id = auth.uid()
      or exists (
        select 1 from public.stories s
        where s.id = story_id and s.author_id = auth.uid()
      )
    )
  );

create policy photos_delete_uploader_or_author
  on public.photos for delete
  to authenticated
  using (
    public.is_family_member(family_id)
    and (
      uploader_id = auth.uid()
      or exists (
        select 1 from public.stories s
        where s.id = story_id and s.author_id = auth.uid()
      )
    )
  );

-- comments
create policy comments_select_member
  on public.comments for select
  to authenticated
  using (public.is_family_member(family_id));

create policy comments_insert_member_author
  on public.comments for insert
  to authenticated
  with check (
    public.is_family_member(family_id)
    and author_id = auth.uid()
  );

create policy comments_update_author
  on public.comments for update
  to authenticated
  using (
    author_id = auth.uid()
    and public.is_family_member(family_id)
  )
  with check (
    author_id = auth.uid()
    and public.is_family_member(family_id)
  );

create policy comments_delete_author
  on public.comments for delete
  to authenticated
  using (
    author_id = auth.uid()
    and public.is_family_member(family_id)
  );

-- perspectives
create policy perspectives_select_member
  on public.perspectives for select
  to authenticated
  using (public.is_family_member(family_id));

create policy perspectives_insert_member_author
  on public.perspectives for insert
  to authenticated
  with check (
    public.is_family_member(family_id)
    and author_id = auth.uid()
  );

create policy perspectives_update_author
  on public.perspectives for update
  to authenticated
  using (
    author_id = auth.uid()
    and public.is_family_member(family_id)
  )
  with check (
    author_id = auth.uid()
    and public.is_family_member(family_id)
  );

create policy perspectives_delete_author
  on public.perspectives for delete
  to authenticated
  using (
    author_id = auth.uid()
    and public.is_family_member(family_id)
  );

-- invites: SELECT member; INSERT member + invited_by = uid; UPDATE/DELETE Edge only
create policy invites_select_member
  on public.invites for select
  to authenticated
  using (public.is_family_member(family_id));

create policy invites_insert_member_inviter
  on public.invites for insert
  to authenticated
  with check (
    public.is_family_member(family_id)
    and invited_by = auth.uid()
  );
