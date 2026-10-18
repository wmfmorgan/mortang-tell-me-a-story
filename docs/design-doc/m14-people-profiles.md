## M14 — People profiles (LOCKED 2026-10-12, Bill)
Intake: PRD M14 (7 items, 10 locks, 2026-10-11) · UXD M14 (8 screens, LOCKED 2026-10-12) · main @ 0f47be8.
### Data
- `people` keeps `family_id` as the **home family** (where the person was added). Scope is the tree: new `public.is_tree_member(fid)` = caller has a live membership in any live family sharing `family_tree_root(fid)`. SECURITY DEFINER, `search_path = ''`.
- New columns on `people`: `birth_date date`, `birth_precision date_precision`, `passing_date date`, `passing_precision date_precision` (reuse the M13 enum and helper; both pairs null-together check), `about text` (≤ 500 chars, check), `avatar_path text` (check `= id::text || '/avatar.jpg'`), `updated_at`.
- `relationship` becomes nullable (Add person has no Relationship field; v2 owns relationships).
- `people.user_id`: unique per tree, enforced in the write RPCs (partial index stays per family).
- New private bucket `person-avatars`, path `{person_id}/avatar.jpg`. Read: tree members. Write: same rule as profile edit (below).
- **Account owns the profile once linked (Bill 2026-10-12):** add `profiles.birth_date`, `profiles.birth_precision`, `profiles.about` (same checks); `profiles.avatar_path` already exists (M8). For a linked person, each field shows the account's value when set, else the person row's value (so an uploaded picture stays until the person replaces it). Date of passing stays on `people`. One account in two separate trees = one profile everywhere; each tree's `people` row keeps only name and story tags.
- Display picture: account picture if set; else `people.avatar_path`; else empty circle (M8 rule).
- `invites.person_id uuid null references people(id) on delete set null`.
### One profile per tree
- `create_branch_family` stops copying `people` rows. Picked people are already tree people; the picker only seeds who gets an invite or membership, as M11b locked.
- **Merge M11b copies (Bill 2026-10-12):** one migration finds `people` rows in a branch family whose name, email and user_id match a row in the parent family's people list at branch time, repoints `story_people` to the parent's row (on conflict do nothing), then deletes the copy. pgTAP asserts zero duplicates per tree afterward.
### Membership (Lock 1)
- Drop `story_people_ensure_membership` and `people_ensure_membership` triggers. Tagging a story or adding an email never creates a membership. Membership comes only from accepting an invite. This retires my M10 auto-membership lock.
### RLS (people)
- SELECT full row: `is_tree_member(family_id)`.
- Name-only for tree readers who aren't members: `people_tree_read` stays `id, family_id, name` (drop `relationship`); no new columns.
- INSERT: `is_live_family_member(family_id)`.
- UPDATE: `user_id is null and is_tree_member(family_id)` OR `user_id = auth.uid()`. Column `user_id` not client-writable (revoke update on that column; Edge/RPC only).
- DELETE: unchanged.
- Policy count (pgTAP counts all of `pg_policies`, storage included): **44 → 47**. `people` policies are replaced in place (net 0). `person-avatars` adds 3 on `storage.objects`: select (tree member of the person's home family), insert and update (same rule as profile edit). `profiles` adds 0: tree members read a linked person's account DOB, About and picture through a security-definer `person_profile(p_person_id)` RPC that checks `is_tree_member`, not by widening `profiles` select. Settings writes go through the existing `profiles_update_own`.
### Linking (Locks 4, 7, 9)
- `create-invite` accepts optional `person_id` (must be tree person, `user_id is null`, `passing_date is null`). Email path: client shows the "Send invite to \{name\}?" confirm; "Not now" still saves the email, no invite row.
- `accept-invite`: if `invites.person_id` set and that person is still unlinked → set `user_id = caller`. If already linked to someone else → accept membership, skip link (no error to invitee). If null → no link (Someone new). No email-match auto-link.
- `remove-member`: null `user_id` on that user's people rows in the tree. Tags stay.
- Settings: one Save writes the caller's `profiles` row (name, DOB, About, picture). RLS: own row only.
### Picker (invite link)
- `list_unlinked_people(p_family_id)`: tree people with `user_id is null` and `passing_date is null` (Bill 2026-10-12: people who have passed are blocked), and no open invite on that person (2026-10-13). Lock 13 (2026-10-13): the existing Email / Text (SMS) / Link invite stays as is; the Not invited yet list renders below it; no separate "Someone new" section.
- Add email (2026-10-13): plain `people` update by a tree member (existing update policy; email editable only while `user_id is null`), then `create-invite` with `person_id`. No new endpoint, no new policy; count stays 47.
### Errors
No new prefixes. Reuse `VALIDATION:`, `NOT_FOUND:`, `FORBIDDEN:`. `mapRpcError` stays at four.
### Tests
pgTAP: tree-member read/write, edit lock after link, removed member reopens edit, name-only view, no auto-membership on tag, link on accept, double-link refused, bucket policies. Deno: create-invite person_id rules, accept-invite link paths.
### OPEN
None. Bill answered all three on 2026-10-12.
## M14.1 Existing-person picker — LOCKED (Bill, 2026-10-15)
- Client-only. Restores the existing-person picker removed in `ef92451` ("Choose existing" links the tapped person). "Create new person" reuses the M14 form unchanged.
- Screen of record: Stitch `f821c61746fe4895b48c94b2e4e13349`.
- No changes under `supabase/`. Policies stay at 47; `mapRpcError` stays at 4 prefixes. Only DB command: `migration up --local`.
- Sequencing: the `manage_families_page_test` date-fix PR merges before `feat/m14-1-person-picker` branches.
## M14.1a Member person rows (LOCKED 2026-10-16)
Bill: "yes. I want this fixed in #33"
- Rule: every family member has exactly one `people` row in each family they belong to, linked by `user_id`.
- `create_family` also inserts a `people` row for the owner (`family_id`, `user_id = auth.uid()`, name from `profiles`).
- Invite accept: after `link_accepted_person`, if no `people` row in that family has `user_id` = invitee, insert one. If the invite already targets a person, link only, never duplicate.
- Backfill in the same new migration, idempotent: for each membership without a linked person in that family, link an existing unlinked person with matching email; otherwise insert one.
- Guardrails: client `people` insert policy still refuses non-null `user_id`; writes happen only in SECURITY DEFINER functions. Policy count stays 47. `mapRpcError` stays at 4 prefixes. New migration only; never edit earlier migrations.
- pgTAP: owner gets a person on create; invite accept never duplicates; backfill re-run is a no-op.
- Ships in PR #33 (scope widened from client-only). All five reviews re-run at the new head.
### M14.1a amendment: one person per tree (LOCKED 2026-10-16, Bill picked (b))
- A member has at most one linked person per family tree. This keeps the M14 rule of one profile per account.
- ensure_member_person returns early if the user is already linked to a person in any live family with the same family_tree_root. Inside that, it matches an unlinked person by email first, otherwise it inserts one.
- The Add person picker lists people across the whole tree, filtered by is_tree_member and soft-delete. The logged-in user appears once.
- Drop the people_keep_one_member_link trigger. No silent clearing of user_id.
- The backfill runs once in the migration and the function is dropped afterward (or it runs as a DO block).
- link_accepted_person's tree-wide check stays as it is on main.
- pgTAP adds a case for a member of both a parent and a child family: exactly one linked person in the tree after create, accept, and backfill.
- Still 47 policies, 4 prefixes, a new migration only. The app change for the tree-wide picker comes back for Mugatu's recheck. Ships in #33.
## M14 amendment: #51, story people from anywhere in the tree (LOCKED 2026-10-18)

### Problem
`story_people_insert_editor` and `story_people_update_editor` require `p.family_id = s.family_id`. Since `20261016120000_member_person_rows.sql` there is one person row per tree, so parent-timeline people live only in the parent family. The tree-wide picker offers them and the insert refuses them (Bill, "Liam is Born" in The WFM Morgans, could not add William F Morgan or txmorgan from WHM Morgans).

### Decision
A person can be linked to a story when the person's family and the story's family are in the same live tree. Story-side rights are unchanged (`can_edit_story`).

`family_tree_root` is security definer and NOT executable by `authenticated` on prod, so it cannot be called directly from a policy. `is_tree_member(p.family_id)` is not enough either: it checks the caller, not the story, so a user in two trees could link a person from tree B onto a story in tree A. We do not widen `family_tree_root` (it would hand any signed-in user the root id of any family uuid). Instead, one boolean-only helper.

### Migration: `20261018000000_story_people_same_tree.sql` (new file, no edits to shipped migrations)

```sql
create function public.same_family_tree(a uuid, b uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select coalesce(public.family_tree_root(a) = public.family_tree_root(b), false);
$$;
revoke all on function public.same_family_tree(uuid, uuid) from public, anon;
grant execute on function public.same_family_tree(uuid, uuid) to authenticated;

alter policy story_people_insert_editor on public.story_people
  with check (
    public.can_edit_story(story_id)
    and exists (
      select 1 from public.people p
      join public.stories s on s.id = story_people.story_id
      where p.id = story_people.person_id
        and public.same_family_tree(p.family_id, s.family_id)
    )
  );

alter policy story_people_update_editor on public.story_people
  using (public.can_edit_story(story_id))
  with check (
    public.can_edit_story(story_id)
    and exists (
      select 1 from public.people p
      join public.stories s on s.id = story_people.story_id
      where p.id = story_people.person_id
        and public.same_family_tree(p.family_id, s.family_id)
    )
  );
```

Soft deletes: `family_tree_root` returns null for a soft-deleted family and stops climbing at a soft-deleted parent, so a person in a deleted family is refused, and a child timeline whose parent is deleted counts as its own tree (matches the M10 lock). Existing links are untouched.

### Gates
- Policies: 47, unchanged (alter only).
- Definer allowlist: 29 to 30 (`same_family_tree`). Update the allowlist test.
- Error prefixes: 4, unchanged. No client change.
- pgTAP: 739 plus the new tests.

### pgTAP (`supabase/tests/story_people_same_tree.sql`)
1. Live member who can edit a story in a child timeline links a person whose row is in the parent timeline: passes.
2. Same, person in the story's own timeline: passes (no regression).
3. Person in an unrelated tree, where the caller is also a member of that tree: refused (42501). This is the case `is_tree_member` alone would let through.
4. Person whose family is soft-deleted: refused.
5. Child timeline whose parent is soft-deleted, person in that parent: refused.
6. Update an existing link to a person in an unrelated tree: refused.
7. `same_family_tree` is not executable by anon; executable by authenticated; is security definer with `search_path=''`.
