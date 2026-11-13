-- M14.3 item 10: a linked person name follows the profile. Rolls back.

begin;
create extension if not exists pgtap with schema extensions;

select plan(32);

create temporary table m14n_ctx (
  owner_id uuid primary key,
  member_id uuid not null,
  tree_a uuid,
  tree_b uuid,
  tree_c uuid,
  person_a uuid,
  person_b uuid,
  unlinked_id uuid,
  link_id uuid
);

grant all on table m14n_ctx to authenticated, anon, service_role;

insert into m14n_ctx (owner_id, member_id)
values (
  'a14b0000-0000-4000-8000-0000000000a1',
  'b14b0000-0000-4000-8000-0000000000b1'
);

insert into auth.users (id, email, raw_user_meta_data)
select owner_id, 'm14n-owner@test.local', '{"display_name":"Olivia Owner"}'::jsonb
from m14n_ctx
union all
select member_id, 'm14n-member@test.local', '{"display_name":"Sam Member"}'::jsonb
from m14n_ctx;

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a14b0000-0000-4000-8000-0000000000a1';

update m14n_ctx
set tree_a = (public.create_family('Tree One')).id;
update m14n_ctx
set tree_b = (public.create_family('Tree Two')).id;
update m14n_ctx
set tree_c = (public.create_family('Tree Three')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.memberships (family_id, user_id, role)
select tree_a, member_id, 'member'::public.membership_role from m14n_ctx
union all
select tree_b, member_id, 'member'::public.membership_role from m14n_ctx
union all
select tree_c, member_id, 'member'::public.membership_role from m14n_ctx;

update m14n_ctx
set
  person_a = '11111111-14b1-4111-8111-111111111111',
  person_b = '22222222-14b1-4111-8111-222222222222',
  unlinked_id = '33333333-14b1-4111-8111-333333333333',
  link_id = '44444444-14b1-4111-8111-444444444444';

insert into public.people (id, family_id, name, created_by, user_id)
select person_a, tree_a, 'Wrong A', owner_id, member_id from m14n_ctx
union all
select person_b, tree_b, 'Wrong B', owner_id, member_id from m14n_ctx;

select results_eq(
  $$select name from public.people
    where id in (
      (select person_a from m14n_ctx),
      (select person_b from m14n_ctx)
    )
    order by id$$,
  $$values ('Sam Member'::text), ('Sam Member')$$,
  'inserting a linked row takes the profile name'
);

insert into public.people (id, family_id, name, created_by)
select link_id, tree_c, 'Sent Name', owner_id from m14n_ctx;

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'b14b0000-0000-4000-8000-0000000000b1';

select public.link_accepted_person((select link_id from m14n_ctx));

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  (select name from public.people where id = (select link_id from m14n_ctx)),
  'Sam Member',
  'linking an existing row takes the profile name'
);

insert into public.people (id, family_id, name, created_by)
select unlinked_id, tree_a, 'Cousin', owner_id from m14n_ctx;

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'b14b0000-0000-4000-8000-0000000000b1';

update public.profiles
set display_name = 'Sam Renamed'
where id = 'b14b0000-0000-4000-8000-0000000000b1';

reset role;
select set_config('request.jwt.claim.sub', '', true);

select results_eq(
  $$select name from public.people
    where id in (
      (select person_a from m14n_ctx),
      (select person_b from m14n_ctx)
    )
    order by id$$,
  $$values ('Sam Renamed'::text), ('Sam Renamed')$$,
  'a profile rename propagates to linked rows in two different trees'
);

select is(
  (select name from public.people where id = (select unlinked_id from m14n_ctx)),
  'Cousin',
  'an unlinked row is untouched by a profile rename'
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'b14b0000-0000-4000-8000-0000000000b1';

select throws_ok(
  $$update public.people
      set name = 'Later Rename'
      where id = (select person_b from m14n_ctx)$$,
  '42501',
  'FORBIDDEN: linked_person_name_locked',
  'a direct rename later in the same transaction still raises'
);

select throws_ok(
  $$update public.people
      set name = 'Member Rename'
      where id = (select person_a from m14n_ctx)$$,
  '42501',
  'FORBIDDEN: linked_person_name_locked',
  'the linked member cannot rename the row'
);

set local request.jwt.claim.sub = 'a14b0000-0000-4000-8000-0000000000a1';

select throws_ok(
  $$update public.people
      set name = 'Owner Rename'
      where id = (select person_a from m14n_ctx)$$,
  '42501',
  'FORBIDDEN: linked_person_name_locked',
  'an owner cannot rename a linked row'
);

set local request.jwt.claim.sub = 'b14b0000-0000-4000-8000-0000000000b1';

select lives_ok(
  $$update public.people
      set about = 'A note'
      where id = (select person_a from m14n_ctx)$$,
  'an update that leaves the profile name passes'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into auth.users (id, email, raw_user_meta_data)
values (
  'c14b0000-0000-4000-8000-0000000000c1',
  'm14n-hidden@test.local',
  '{"display_name":"Hidden Profile"}'
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a14b0000-0000-4000-8000-0000000000a1';

select is(
  (select count(*) from public.profiles
    where id = 'c14b0000-0000-4000-8000-0000000000c1'),
  0::bigint,
  'the caller cannot read the linked profile'
);

reset role;
alter table public.people disable row level security;

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a14b0000-0000-4000-8000-0000000000a1';

select lives_ok(
  $$insert into public.people (id, family_id, name, created_by, user_id)
    select
      '55555555-14b1-4111-8111-555555555555',
      tree_a,
      'Sent Hidden',
      owner_id,
      'c14b0000-0000-4000-8000-0000000000c1'
    from m14n_ctx$$,
  'a caller who cannot read the profile can still link the row'
);

reset role;
alter table public.people enable row level security;

select is(
  (select name from public.people
    where id = '55555555-14b1-4111-8111-555555555555'),
  'Hidden Profile',
  'the linked name still comes from the profile'
);

alter table public.people disable trigger user;
update public.people
set name = 'Drift'
where id = (select person_a from m14n_ctx);
alter table public.people enable trigger user;

select is(
  public.backfill_linked_person_names() > 0,
  true,
  'backfill repairs a drifted linked name'
);

select is(
  (select name from public.people where id = (select person_a from m14n_ctx)),
  'Sam Renamed',
  'backfill copies the profile name onto a drifted linked row'
);

select is(
  public.backfill_linked_person_names(),
  0,
  'a second backfill updates 0 rows'
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'b14b0000-0000-4000-8000-0000000000b1';

select lives_ok(
  $$update public.profiles
      set display_name = null
      where id = 'b14b0000-0000-4000-8000-0000000000b1'$$,
  'a null display name sync raises no error'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select results_eq(
  $$select name from public.people
    where id in (
      (select person_a from m14n_ctx),
      (select person_b from m14n_ctx)
    )
    order by id$$,
  $$values ('Sam Renamed'::text), ('Sam Renamed')$$,
  'a null display name keeps the linked names'
);

insert into auth.users (id, email, raw_user_meta_data)
values (
  'd14b0000-0000-4000-8000-0000000000d1',
  'm14n-blank@test.local',
  '{"display_name":"Blank Null"}'
);

update public.profiles
set display_name = null
where id = 'd14b0000-0000-4000-8000-0000000000d1';

select lives_ok(
  $$insert into public.people (id, family_id, name, created_by, user_id)
    select
      '66666666-14b1-4111-8111-666666666666',
      tree_a,
      'Kept Null',
      owner_id,
      'd14b0000-0000-4000-8000-0000000000d1'
    from m14n_ctx$$,
  'a null display name does not raise when linking a person'
);

select is(
  (select name from public.people
    where id = '66666666-14b1-4111-8111-666666666666'),
  'Kept Null',
  'a null display name keeps the name on the new linked person'
);

alter table public.profiles disable trigger profiles_sync_linked_person_name;
update public.profiles
set display_name = null
where id = 'b14b0000-0000-4000-8000-0000000000b1';
alter table public.profiles enable trigger profiles_sync_linked_person_name;

select lives_ok(
  $$select public.backfill_linked_person_names()$$,
  'backfill raises no error when a display name is null'
);

select is(
  (select name from public.people where id = (select person_a from m14n_ctx)),
  'Sam Renamed',
  'backfill keeps the person name when the display name is null'
);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'b14b0000-0000-4000-8000-0000000000b1';

select lives_ok(
  $$update public.profiles
      set display_name = '   '
      where id = 'b14b0000-0000-4000-8000-0000000000b1'$$,
  'a whitespace display name sync raises no error'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select results_eq(
  $$select name from public.people
    where id in (
      (select person_a from m14n_ctx),
      (select person_b from m14n_ctx)
    )
    order by id$$,
  $$values ('Sam Renamed'::text), ('Sam Renamed')$$,
  'a whitespace display name keeps the linked names'
);

insert into auth.users (id, email, raw_user_meta_data)
values (
  'e14b0000-0000-4000-8000-0000000000e1',
  'm14n-space@test.local',
  '{"display_name":"Blank Space"}'
);

update public.profiles
set display_name = '   '
where id = 'e14b0000-0000-4000-8000-0000000000e1';

select lives_ok(
  $$insert into public.people (id, family_id, name, created_by, user_id)
    select
      '77777777-14b1-4111-8111-777777777777',
      tree_a,
      'Kept Space',
      owner_id,
      'e14b0000-0000-4000-8000-0000000000e1'
    from m14n_ctx$$,
  'a whitespace display name does not raise when linking a person'
);

select is(
  (select name from public.people
    where id = '77777777-14b1-4111-8111-777777777777'),
  'Kept Space',
  'a whitespace display name keeps the name on the new linked person'
);

alter table public.people disable trigger user;
update public.people
set name = 'Drift Space'
where id = (select person_b from m14n_ctx);
alter table public.people enable trigger user;

select lives_ok(
  $$select public.backfill_linked_person_names()$$,
  'backfill raises no error when a display name is whitespace'
);

select is(
  (select name from public.people where id = (select person_b from m14n_ctx)),
  'Drift Space',
  'backfill keeps the person name when the display name is whitespace'
);

insert into auth.users (id, email, raw_user_meta_data)
values (
  'f14b0000-0000-4000-8000-0000000000f1',
  'm14n-invite-null@test.local',
  '{"display_name":"Invite Null"}'
);

update public.profiles
set display_name = null
where id = 'f14b0000-0000-4000-8000-0000000000f1';

insert into public.invites (
  family_id, invited_by, email, token, status, expires_at, person_id
)
select
  tree_a,
  owner_id,
  'm14n-invite-null@test.local',
  'tok_m14n_blank_null',
  'pending'::public.invite_status,
  now() + interval '7 days',
  null
from m14n_ctx;

select lives_ok(
  $$update public.invites
      set status = 'accepted',
          accepted_by = 'f14b0000-0000-4000-8000-0000000000f1',
          accepted_at = now()
      where token = 'tok_m14n_blank_null'$$,
  'an invite accept with a null display name succeeds'
);

select results_eq(
  $$select name, user_id::text
    from public.people
    where user_id = 'f14b0000-0000-4000-8000-0000000000f1'$$,
  $$values (
    'm14n-invite-null@test.local'::text,
    'f14b0000-0000-4000-8000-0000000000f1'
  )$$,
  'an invite accept with a null display name keeps the email fallback'
);

insert into auth.users (id, email, raw_user_meta_data)
values (
  'a14c0000-0000-4000-8000-0000000000c2',
  'm14n-link-space@test.local',
  '{"display_name":"Link Space"}'
);

update public.profiles
set display_name = '   '
where id = 'a14c0000-0000-4000-8000-0000000000c2';

insert into public.people (id, family_id, name, created_by)
select
  '88888888-14b1-4111-8111-888888888888',
  tree_a,
  'Kept Link',
  owner_id
from m14n_ctx;

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = 'a14c0000-0000-4000-8000-0000000000c2';

select lives_ok(
  $$select public.link_accepted_person('88888888-14b1-4111-8111-888888888888')$$,
  'a person link with a whitespace display name succeeds'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select results_eq(
  $$select name, user_id::text
    from public.people
    where id = '88888888-14b1-4111-8111-888888888888'$$,
  $$values (
    'Kept Link'::text,
    'a14c0000-0000-4000-8000-0000000000c2'
  )$$,
  'a person link with a whitespace display name keeps the existing name'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.backfill_linked_person_names()',
    'execute'
  ),
  false,
  'authenticated cannot execute backfill_linked_person_names'
);

select is(
  (select count(*)::int from pg_policies),
  51,
  'policy count is 51'
);

select * from finish();
rollback;
