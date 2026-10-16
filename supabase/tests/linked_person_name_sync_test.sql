-- M14.3 item 10: a linked person name follows the profile. Rolls back.

begin;
create extension if not exists pgtap with schema extensions;

select plan(11);

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

alter table public.people disable trigger user;
update public.people
set name = 'Drift'
where id = (select person_a from m14n_ctx);
alter table public.people enable trigger user;

create function pg_temp.run_linked_name_backfill()
returns int
language plpgsql
as $$
declare
  n int;
begin
  update public.people p
  set name = pr.display_name
  from public.profiles pr
  where p.user_id = pr.id
    and p.name is distinct from pr.display_name;
  get diagnostics n = row_count;
  return n;
end;
$$;

select is(
  pg_temp.run_linked_name_backfill() > 0,
  true,
  'backfill repairs a drifted linked name'
);

select is(
  (select name from public.people where id = (select person_a from m14n_ctx)),
  'Sam Renamed',
  'backfill copies the profile name onto a drifted linked row'
);

select is(
  pg_temp.run_linked_name_backfill(),
  0,
  'a second backfill updates 0 rows'
);

select is(
  (select count(*)::int from pg_policies),
  47,
  'policy count is 47'
);

select * from finish();
rollback;
