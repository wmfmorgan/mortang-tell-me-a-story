-- #72 standing catalog guard (Trinity §9 A–E). Enforced by the CI pgtap job.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

select hasnt_view('public', 'people_tree_read', '#72: public.people_tree_read is dropped');

-- A. anon/authenticated hold no non-SELECT privilege on any exposed view/matview
select is_empty($$
  select n.nspname, c.relname, r.rolname, p.priv
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  cross join (values ('anon'),('authenticated')) r(rolname)
  cross join (values ('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),('REFERENCES'),('TRIGGER')) p(priv)
  where c.relkind in ('v','m') and n.nspname in ('public','graphql_public')
    and has_table_privilege(r.rolname, c.oid, p.priv)
$$, 'A: no non-SELECT privilege for anon/authenticated on any exposed view');

-- B. no exposed view readable by anon; no RLS-bypassing-owner view without security_invoker
select is_empty($$
  select n.nspname, c.relname
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  join pg_roles o on o.oid = c.relowner
  where c.relkind in ('v','m') and n.nspname in ('public','graphql_public')
    and ( has_table_privilege('anon', c.oid, 'SELECT')
       or (c.relkind = 'v' and (o.rolbypassrls or o.rolsuper)
           and not coalesce('security_invoker=true' = any(c.reloptions)
                         or 'security_invoker=on' = any(c.reloptions), false)) )
$$, 'B: no anon-readable view and no definer-owner view without security_invoker');

-- C. every public table has RLS
select is_empty($$
  select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where c.relkind in ('r','p') and n.nspname = 'public' and not c.relrowsecurity
$$, 'C: every public table has RLS enabled');

-- E. anon executes no non-trigger public function
select is_empty($$
  select p.oid::regprocedure::text
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prorettype <> 'trigger'::regtype
    and has_function_privilege('anon', p.oid, 'EXECUTE')
$$, 'E: anon cannot execute any non-trigger public function');

-- D. WARN-ONLY until the Part D follow-up lands (prod today: 66 rows = 11 tables x 2 roles x 3 privs)
select todo('Part D follow-up (alter default privileges + revoke 66 grants) not landed; delete this todo when it does', 1);
select is_empty($$
  select c.relname, r.rolname, p.priv
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  cross join (values ('anon'),('authenticated')) r(rolname)
  cross join (values ('TRUNCATE'),('REFERENCES'),('TRIGGER')) p(priv)
  where c.relkind in ('r','p') and n.nspname = 'public'
    and has_table_privilege(r.rolname, c.oid, p.priv)
$$, 'D: no TRUNCATE/REFERENCES/TRIGGER for anon/authenticated on public tables');

-- Definer allowlist (PR #39). Prod 2026-10-20: exactly these 30.
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef
     and has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  30, 'exactly 30 SECURITY DEFINER functions are executable by authenticated');
select set_eq($$
  select format('%s(%s)', p.proname, oidvectortypes(p.proargtypes))
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
    and has_function_privilege('authenticated', p.oid, 'EXECUTE')
$$, $$values
  ('add_co_owner(uuid, uuid)'),('assert_invite_person(uuid, uuid)'),
  ('can_contribute_to_story(uuid, uuid)'),('can_edit_story(uuid)'),
  ('create_branch_family(uuid, uuid, text, integer, uuid, uuid[])'),('create_family(text)'),
  ('is_family_co_owner(uuid)'),('is_family_member(uuid)'),('is_family_owner(uuid)'),
  ('is_family_tree_readable(uuid)'),('is_live_family_member(uuid)'),('is_tree_member(uuid)'),
  ('link_accepted_person(uuid)'),('list_family_tree(uuid)'),('list_origin_dependents(uuid)'),
  ('list_unlinked_people(uuid)'),('mark_passed_away(uuid, boolean)'),('my_profile()'),
  ('person_profile(uuid)'),('recover_family(uuid)'),('remove_co_owner(uuid, uuid)'),
  ('remove_member(uuid, uuid)'),('rename_family(uuid, text)'),('resend_invite(uuid)'),
  ('revoke_invite(uuid)'),('same_family_tree(uuid, uuid)'),('set_family_origin(uuid, uuid)'),
  ('soft_delete_family(uuid)'),('story_row_exists(uuid)'),('transfer_ownership(uuid, uuid, text)')
$$, 'authenticated-executable SECURITY DEFINER set equals the PR #39 allowlist');

select * from finish();
rollback;
