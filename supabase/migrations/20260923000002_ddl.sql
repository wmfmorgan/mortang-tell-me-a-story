-- Design Doc §1 DDL (columns/indexes locked; uuid PKs where appropriate)

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  parent_family_id uuid references public.families (id),
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index families_parent_family_id_idx on public.families (parent_family_id);

create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.membership_role not null default 'member',
  unique (family_id, user_id)
);

create index memberships_user_id_idx on public.memberships (user_id);
create index memberships_family_id_idx on public.memberships (family_id);

create table public.people (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  name text not null,
  relationship text not null,
  email text,
  created_by uuid not null references public.profiles (id)
);

create table public.places (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  label text not null,
  address text not null,
  lat double precision not null,
  lng double precision not null,
  mapbox_place_id text,
  is_favorite boolean not null default false,
  last_used_at timestamptz
);

create table public.stories (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  author_id uuid not null references public.profiles (id),
  title text,
  body text,
  timeframe_start date not null,
  timeframe_end date,
  place_id uuid references public.places (id),
  status public.story_status not null default 'draft',
  published_at timestamptz,
  constraint stories_timeframe_end_gte_start check (
    timeframe_end is null or timeframe_end >= timeframe_start
  )
);

create index stories_family_id_status_idx on public.stories (family_id, status);
create index stories_family_id_timeframe_idx
  on public.stories (family_id, timeframe_start, timeframe_end);

create table public.story_people (
  story_id uuid not null references public.stories (id) on delete cascade,
  person_id uuid not null references public.people (id) on delete cascade,
  primary key (story_id, person_id)
);

create table public.photos (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references public.stories (id) on delete cascade,
  family_id uuid not null references public.families (id) on delete cascade,
  uploader_id uuid not null references public.profiles (id),
  storage_path text not null,
  sort_order integer not null default 0
);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references public.stories (id) on delete cascade,
  family_id uuid not null references public.families (id) on delete cascade,
  author_id uuid not null references public.profiles (id),
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.perspectives (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references public.stories (id) on delete cascade,
  family_id uuid not null references public.families (id) on delete cascade,
  author_id uuid not null references public.profiles (id),
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.invites (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  invited_by uuid not null references public.profiles (id),
  email text,
  token text not null unique,
  status public.invite_status not null default 'pending',
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_by uuid references public.profiles (id),
  accepted_at timestamptz
);

grant usage on schema public to anon, authenticated, service_role;
grant all on all tables in schema public to anon, authenticated, service_role;
grant all on all sequences in schema public to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to anon, authenticated, service_role;
