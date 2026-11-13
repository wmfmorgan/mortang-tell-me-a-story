-- #72: drop the vestigial people_tree_read view (LOCKED, Bill 2026-10-20).
-- M14 (20261012100000 l.78-87) dropped and re-created it. The revoke on l.86
-- left out authenticated, so the schema default ACL (20260923000002 l.124-127)
-- gave authenticated ALL on an owner-postgres, non-invoker, auto-updatable
-- view. That let callers UPDATE and DELETE people rows past RLS.
-- people_select_member (is_tree_member) already returns every row the view
-- returned, and the client reads list_family_tree + people, never this view.
-- No CASCADE: if anything depends on the view, this must fail.
drop view if exists public.people_tree_read;
