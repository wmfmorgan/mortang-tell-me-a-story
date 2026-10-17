begin;
create extension if not exists pgtap with schema extensions;

select plan(68);

select ok(
  not has_function_privilege('anon', 'public.upsert_story_member(uuid, uuid)', 'execute'),
  'anon cannot execute upsert_story_member'
);
select ok(
  not has_function_privilege('authenticated', 'public.upsert_story_member(uuid, uuid)', 'execute'),
  'authenticated cannot execute upsert_story_member'
);
select ok(
  not has_function_privilege('anon', 'public.resolve_person_user(uuid, text)', 'execute'),
  'anon cannot execute resolve_person_user'
);
select ok(
  not has_function_privilege('authenticated', 'public.resolve_person_user(uuid, text)', 'execute'),
  'authenticated cannot execute resolve_person_user'
);
select ok(
  not has_function_privilege('anon', 'public.family_tree_ids(uuid)', 'execute'),
  'anon cannot execute family_tree_ids'
);
select ok(
  not has_function_privilege('authenticated', 'public.family_tree_ids(uuid)', 'execute'),
  'authenticated cannot execute family_tree_ids'
);
select ok(
  not has_function_privilege('anon', 'public._require_family(uuid)', 'execute'),
  'anon cannot execute _require_family'
);
select ok(
  not has_function_privilege('authenticated', 'public._require_family(uuid)', 'execute'),
  'authenticated cannot execute _require_family'
);
select ok(
  not has_function_privilege('anon', 'public.purge_expired_families()', 'execute'),
  'anon cannot execute purge_expired_families'
);
select ok(
  not has_function_privilege('authenticated', 'public.purge_expired_families()', 'execute'),
  'authenticated cannot execute purge_expired_families'
);
select ok(
  not has_function_privilege('anon', 'public.handle_new_user()', 'execute'),
  'anon cannot execute handle_new_user'
);
select ok(
  not has_function_privilege('authenticated', 'public.handle_new_user()', 'execute'),
  'authenticated cannot execute handle_new_user'
);
select ok(
  not has_function_privilege('anon', 'public.sync_profile_email()', 'execute'),
  'anon cannot execute sync_profile_email'
);
select ok(
  not has_function_privilege('authenticated', 'public.sync_profile_email()', 'execute'),
  'authenticated cannot execute sync_profile_email'
);
select ok(
  not has_function_privilege('anon', 'public.photos_cap_insert()', 'execute'),
  'anon cannot execute photos_cap_insert'
);
select ok(
  not has_function_privilege('authenticated', 'public.photos_cap_insert()', 'execute'),
  'authenticated cannot execute photos_cap_insert'
);
select ok(
  not has_function_privilege('anon', 'public.profiles_sync_linked_person_name()', 'execute'),
  'anon cannot execute profiles_sync_linked_person_name'
);
select ok(
  not has_function_privilege('authenticated', 'public.profiles_sync_linked_person_name()', 'execute'),
  'authenticated cannot execute profiles_sync_linked_person_name'
);
select ok(
  not has_function_privilege('anon', 'public.people_guard_linked_name()', 'execute'),
  'anon cannot execute people_guard_linked_name'
);
select ok(
  not has_function_privilege('authenticated', 'public.people_guard_linked_name()', 'execute'),
  'authenticated cannot execute people_guard_linked_name'
);

select ok(
  not has_function_privilege('anon', 'public.is_family_member(uuid)', 'execute'),
  'anon cannot execute is_family_member'
);
select ok(
  not has_function_privilege('anon', 'public.is_family_owner(uuid)', 'execute'),
  'anon cannot execute is_family_owner'
);
select ok(
  not has_function_privilege('anon', 'public.is_family_co_owner(uuid)', 'execute'),
  'anon cannot execute is_family_co_owner'
);
select ok(
  not has_function_privilege('anon', 'public.create_family(text)', 'execute'),
  'anon cannot execute create_family'
);
select ok(
  not has_function_privilege('anon', 'public.add_co_owner(uuid, uuid)', 'execute'),
  'anon cannot execute add_co_owner'
);
select ok(
  not has_function_privilege('anon', 'public.remove_co_owner(uuid, uuid)', 'execute'),
  'anon cannot execute remove_co_owner'
);
select ok(
  not has_function_privilege('anon', 'public.rename_family(uuid, text)', 'execute'),
  'anon cannot execute rename_family'
);
select ok(
  not has_function_privilege('anon', 'public.soft_delete_family(uuid)', 'execute'),
  'anon cannot execute soft_delete_family'
);
select ok(
  not has_function_privilege('anon', 'public.recover_family(uuid)', 'execute'),
  'anon cannot execute recover_family'
);
select ok(
  not has_function_privilege('anon', 'public.transfer_ownership(uuid, uuid, text)', 'execute'),
  'anon cannot execute transfer_ownership'
);
select ok(
  not has_function_privilege('anon', 'public.remove_member(uuid, uuid)', 'execute'),
  'anon cannot execute remove_member'
);
select ok(
  not has_function_privilege('anon', 'public.resend_invite(uuid)', 'execute'),
  'anon cannot execute resend_invite'
);
select ok(
  not has_function_privilege('anon', 'public.revoke_invite(uuid)', 'execute'),
  'anon cannot execute revoke_invite'
);

select ok(
  has_function_privilege('authenticated', 'public.is_family_member(uuid)', 'execute'),
  'authenticated can execute is_family_member'
);
select ok(
  has_function_privilege('authenticated', 'public.is_family_owner(uuid)', 'execute'),
  'authenticated can execute is_family_owner'
);
select ok(
  has_function_privilege('authenticated', 'public.is_family_co_owner(uuid)', 'execute'),
  'authenticated can execute is_family_co_owner'
);
select ok(
  has_function_privilege('authenticated', 'public.create_family(text)', 'execute'),
  'authenticated can execute create_family'
);
select ok(
  has_function_privilege('authenticated', 'public.add_co_owner(uuid, uuid)', 'execute'),
  'authenticated can execute add_co_owner'
);
select ok(
  has_function_privilege('authenticated', 'public.remove_co_owner(uuid, uuid)', 'execute'),
  'authenticated can execute remove_co_owner'
);
select ok(
  has_function_privilege('authenticated', 'public.rename_family(uuid, text)', 'execute'),
  'authenticated can execute rename_family'
);
select ok(
  has_function_privilege('authenticated', 'public.soft_delete_family(uuid)', 'execute'),
  'authenticated can execute soft_delete_family'
);
select ok(
  has_function_privilege('authenticated', 'public.recover_family(uuid)', 'execute'),
  'authenticated can execute recover_family'
);
select ok(
  has_function_privilege('authenticated', 'public.transfer_ownership(uuid, uuid, text)', 'execute'),
  'authenticated can execute transfer_ownership'
);
select ok(
  has_function_privilege('authenticated', 'public.remove_member(uuid, uuid)', 'execute'),
  'authenticated can execute remove_member'
);
select ok(
  has_function_privilege('authenticated', 'public.resend_invite(uuid)', 'execute'),
  'authenticated can execute resend_invite'
);
select ok(
  has_function_privilege('authenticated', 'public.revoke_invite(uuid)', 'execute'),
  'authenticated can execute revoke_invite'
);
select ok(
  has_function_privilege('authenticated', 'public.is_live_family_member(uuid)', 'execute'),
  'authenticated can execute is_live_family_member'
);
select ok(
  has_function_privilege('authenticated', 'public.is_family_tree_readable(uuid)', 'execute'),
  'authenticated can execute is_family_tree_readable'
);
select ok(
  has_function_privilege('authenticated', 'public.is_tree_member(uuid)', 'execute'),
  'authenticated can execute is_tree_member'
);
select ok(
  has_function_privilege('authenticated', 'public.can_contribute_to_story(uuid, uuid)', 'execute'),
  'authenticated can execute can_contribute_to_story'
);
select ok(
  has_function_privilege('authenticated', 'public.can_edit_story(uuid)', 'execute'),
  'authenticated can execute can_edit_story'
);
select ok(
  has_function_privilege('authenticated', 'public.list_family_tree(uuid)', 'execute'),
  'authenticated can execute list_family_tree'
);
select ok(
  has_function_privilege('authenticated', 'public.list_origin_dependents(uuid)', 'execute'),
  'authenticated can execute list_origin_dependents'
);
select ok(
  has_function_privilege('authenticated', 'public.set_family_origin(uuid, uuid)', 'execute'),
  'authenticated can execute set_family_origin'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.create_branch_family(uuid, uuid, text, integer, uuid, uuid[])',
    'execute'
  ),
  'authenticated can execute create_branch_family'
);
select ok(
  has_function_privilege('authenticated', 'public.assert_invite_person(uuid, uuid)', 'execute'),
  'authenticated can execute assert_invite_person'
);
select ok(
  has_function_privilege('authenticated', 'public.link_accepted_person(uuid)', 'execute'),
  'authenticated can execute link_accepted_person'
);
select ok(
  has_function_privilege('authenticated', 'public.list_unlinked_people(uuid)', 'execute'),
  'authenticated can execute list_unlinked_people'
);
select ok(
  has_function_privilege('authenticated', 'public.mark_passed_away(uuid, boolean)', 'execute'),
  'authenticated can execute mark_passed_away'
);
select ok(
  has_function_privilege('authenticated', 'public.my_profile()', 'execute'),
  'authenticated can execute my_profile'
);
select ok(
  has_function_privilege('authenticated', 'public.person_profile(uuid)', 'execute'),
  'authenticated can execute person_profile'
);

select ok(
  to_regprocedure('public.ensure_story_person_membership()') is null,
  'ensure_story_person_membership is gone'
);

select is_empty(
  $$
    select p.oid::regprocedure::text
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and pg_catalog.has_function_privilege('anon', p.oid, 'execute')
      and p.oid <> all (array[]::oid[])
  $$,
  'no public security definer function is executable by anon'
);

select is_empty(
  $$
    select p.oid::regprocedure::text
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and pg_catalog.has_function_privilege('authenticated', p.oid, 'execute')
      and p.oid <> all (array[
        'public.add_co_owner(uuid,uuid)'::regprocedure,
        'public.assert_invite_person(uuid,uuid)'::regprocedure,
        'public.can_contribute_to_story(uuid,uuid)'::regprocedure,
        'public.can_edit_story(uuid)'::regprocedure,
        'public.create_branch_family(uuid,uuid,text,integer,uuid,uuid[])'::regprocedure,
        'public.create_family(text)'::regprocedure,
        'public.is_family_co_owner(uuid)'::regprocedure,
        'public.is_family_member(uuid)'::regprocedure,
        'public.is_family_owner(uuid)'::regprocedure,
        'public.is_family_tree_readable(uuid)'::regprocedure,
        'public.is_live_family_member(uuid)'::regprocedure,
        'public.is_tree_member(uuid)'::regprocedure,
        'public.link_accepted_person(uuid)'::regprocedure,
        'public.list_family_tree(uuid)'::regprocedure,
        'public.list_origin_dependents(uuid)'::regprocedure,
        'public.list_unlinked_people(uuid)'::regprocedure,
        'public.mark_passed_away(uuid,boolean)'::regprocedure,
        'public.my_profile()'::regprocedure,
        'public.person_profile(uuid)'::regprocedure,
        'public.recover_family(uuid)'::regprocedure,
        'public.remove_co_owner(uuid,uuid)'::regprocedure,
        'public.remove_member(uuid,uuid)'::regprocedure,
        'public.rename_family(uuid,text)'::regprocedure,
        'public.resend_invite(uuid)'::regprocedure,
        'public.revoke_invite(uuid)'::regprocedure,
        'public.set_family_origin(uuid,uuid)'::regprocedure,
        'public.soft_delete_family(uuid)'::regprocedure,
        'public.story_row_exists(uuid)'::regprocedure,
        'public.transfer_ownership(uuid,uuid,text)'::regprocedure
      ]::oid[])
  $$,
  'every public security definer authenticated can execute is on the allowlist'
);

create temporary table dg_ctx (
  user_a uuid,
  user_b uuid,
  family_id uuid,
  story_id uuid,
  person_id uuid,
  branch_id uuid
);

grant all on table dg_ctx to authenticated, anon, service_role;

insert into dg_ctx (user_a, user_b) values (
  'a0000000-def0-4000-8000-00000000000a',
  'b0000000-def0-4000-8000-00000000000b'
);

insert into auth.users (id, email, raw_user_meta_data)
select user_a, 'def-a@test.local', '{"display_name":"Def A"}'::jsonb from dg_ctx
union all
select user_b, 'def-b@test.local', '{"display_name":"Def B"}'::jsonb from dg_ctx;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a0000000-def0-4000-8000-00000000000a', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

update dg_ctx set family_id = (public.create_family('Parent')).id;

reset role;
select set_config('request.jwt.claim.sub', '', true);

insert into public.memberships (family_id, user_id, role)
select family_id, user_b, 'member'::public.membership_role from dg_ctx;

update dg_ctx set story_id = '51000000-def0-4000-8000-000000000051';
insert into public.stories (
  id, family_id, author_id, title, timeframe_start, status
)
select
  story_id,
  family_id,
  user_a,
  'Origin',
  '1990-01-01'::date,
  'published'::public.story_status
from dg_ctx;

update dg_ctx set person_id = '61000000-def0-4000-8000-000000000061';
insert into public.people (id, family_id, name, created_by, user_id)
select person_id, family_id, 'Bee', user_a, user_b from dg_ctx;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a0000000-def0-4000-8000-00000000000a', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
  $$
    update dg_ctx set branch_id = (
      select id from public.create_branch_family(
        (select family_id from dg_ctx),
        (select story_id from dg_ctx),
        'Branch line',
        1990,
        (select user_a from dg_ctx),
        array[(select person_id from dg_ctx)]
      )
    )
  $$,
  'create_branch_family with a picked person still runs'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  (
    select role::text
    from public.memberships
    where family_id = (select branch_id from dg_ctx)
      and user_id = (select user_b from dg_ctx)
  ),
  'member',
  'a picked person still gets a membership'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a0000000-def0-4000-8000-00000000000a', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
  $$
    select public.remove_member(
      (select family_id from dg_ctx),
      (select user_b from dg_ctx)
    )
  $$,
  'remove_member still runs'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select is(
  (
    select count(*)
    from public.memberships
    where user_id = (select user_b from dg_ctx)
      and family_id in (
        (select family_id from dg_ctx),
        (select branch_id from dg_ctx)
      )
  ),
  0::bigint,
  'remove_member still drops the membership'
);

select * from finish();
rollback;
