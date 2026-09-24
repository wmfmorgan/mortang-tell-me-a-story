-- Design Doc §1 enums
create type public.story_status as enum ('draft', 'published');
create type public.invite_status as enum ('pending', 'accepted', 'revoked', 'expired');
create type public.membership_role as enum ('member');
