## M12 Timeline branch marks (Gilfoyle, 2026-10-07)
Architecture lock only. Not a stamp. Product/UX locked 2026-10-06. Supersedes Macro/Mid/Full Cards chrome for **branch marks only** (Stitch `a6259996a3b1408486c6074a4fa75f5d`, `5a0fa5949a9647daa363c3daf34bd49e`, `974665ebd3a44254a61da7f1cf45a3f2`). Does **not** reopen M6–M10 / R2 / R3 chrome rules (ignore superseded Stories / Family Members / Places chrome on some Stitch frames).
### Scope
- Dial **hollow-ring** marks (dashed sage) on Macro, Mid, and Full Cards = related families in the **branch tree**, not stories. Solid dots/nodes stay published stories.
- Mark tap → open that related family’s timeline for **read** (set session family to that id via existing R2 selection path, or navigate then set — same `FamilySelection`). Does **not** merge the other family’s stories into the current dial.
- Related-families **list** shows every family linked by `parent_family_id` in the whole tree (root + all descendants), **including families you are not a member of**.
- Entry points: dial mark **and** related-families list. Switching current family for write/session still uses the **R2 family menu** when you are a member.
- Branch **create** UX remains **M11**. M12 only renders marks/nav for trees that already exist via `parent_family_id`.
- **Ship order (LOCKED Bill 2026-10-07):** M12 may ship **before** M11. Until branches exist, dial marks and the related-families list are **empty** (same chrome as today). No seed/fake branches required.
### Data
- Graph: existing `families.parent_family_id` only. No new graph table.
- Fork year for Full Cards placement / labels:
```sql
alter table public.families add column branch_year int null
  check (branch_year is null or (branch_year >= 1 and branch_year <= 9999));
```
- Roots: `branch_year` null. Child families: year of the fork (calendar year). **M11** writes `branch_year` on branch create. M12 reads it; if null, show the mark/label **without** a year and place Full Cards markers by stable sort among nulls (do not invent a year from `created_at`).
### Read access (amends RLS for tree read)
Product: you may **open and read** stories on related timelines in the tree even without membership; **write** still requires membership (M10/M11 rules).
Security-definer helpers (original 2026-10-07 sketch, **superseded by "M12 amendments (LOCKED Bill 2026-10-10)" below**; build from the amendment SQL):
```sql
create or replace function public.family_tree_root(fid uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  with recursive walk as (
    select id, parent_family_id from public.families where id = fid
    union all
    select f.id, f.parent_family_id
    from public.families f
    join walk w on f.id = w.parent_family_id
  )
  select id from walk where parent_family_id is null
  limit 1;
$$;

create or replace function public.is_family_tree_readable(fid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and public.family_tree_root(m.family_id) is not distinct from public.family_tree_root(fid)
  );
$$;
```
- `stories` / `photos` / `comments` / `perspectives` / `story_people` / `places` **SELECT** (`people` removed 2026-10-10, see amendments): existing `is_family_member(family_id)` **OR** (`is_family_tree_readable(family_id)` **and** published-only where status applies — drafts stay `is_family_member` only). **LOCKED (Bill 2026-10-07):** non-members never see drafts on a related timeline.
- `families` SELECT: member **OR** `is_family_tree_readable(id)` (still respect soft-delete rules from M10: non-owner/co_owner must not see `deleted_at is not null`).
- INSERT/UPDATE/DELETE policies unchanged (still membership / author). Tree read does **not** grant write.
- Storage `story-photos` SELECT: same tree-readable rule as member for published story paths; do not widen writes.
- Realtime: still filter `family_id=eq.<uuid>` for the **current** session family. No cross-family Realtime fan-in on one channel.
### Client
- Build related list: call `list_family_tree(fid)` (security-definer RPC, see amendments). Do not walk `parent_family_id` from the client. Cache in memory for the session family; invalidate on family switch.
- Macro/Mid/Full Cards: paint hollow-ring marks for related families other than current; labels use `families.name` + optional `branch_year`.
- Full Cards: place marks **between** cards at `branch_year` when set.
- Zoom taps from M9 stay in force (Macro dot → Mid, etc.). Marks are an additional target type.
### Tests
- Non-member who shares a tree can SELECT published stories on a related family; stranger outside the tree cannot.
- Non-member cannot INSERT comment/photo on a related family.
- Soft-deleted related family hidden from marks/list for everyone, owner/co_owner included (amended 2026-10-10). Recover stays in the Manage hub only.
- Marks do not appear as story dots; story open paths unchanged.
> 🚫 FORBIDDEN: Loading another family’s stories into the current dial. Tree-wide write in M12. New graph tables. Using superseded Stitch header chrome as requirements. Inventing `branch_year` from `created_at`. Stamping §15 here.
### M12 amendments (LOCKED Bill 2026-10-10)
From the M12 plan review. These win over the original helper SQL and the `people` rule above.
1. **Root walk skips soft-deleted ancestors** (M10 delete rule). A soft-deleted family has no root (null), so nothing tree-reads it. Both walks carry a visited-id `path` array and stop on a repeat, with a depth-64 cap as a backstop (`union` alone does not dedupe rows that carry depth). pgTAP: two families parented to each other; walk terminates and returns each id once. Also: a signed-in non-tree user gets 0 rows from `people_tree_read`; the view has no `email` column; `has_table_privilege('anon', 'public.people_tree_read', 'select')` is false.
2. **`list_family_tree(fid)`** is the only client read for the tree. Returns `id, name, parent_family_id, branch_year` for live families under the visible root. Soft-deleted families are excluded for **everyone**, owner/co_owner included, so no mark or Related row can switch the session to a deleted family. Recover stays in the Manage hub.
3. **`is_family_tree_readable`** is false when `fid` is soft-deleted, and ignores the caller's memberships in soft-deleted families.
4. **`people`**** SELECT stays member-only.** `people.email` must not reach tree readers. Tree readers read names through the view `people_tree_read` (no `email` column). The reader uses it only when the viewer is not a member of the session family.
5. **Grants.** Supabase grants function EXECUTE and table privileges to `anon`/`authenticated` by default, so `revoke … from public` alone is not enough. Revoke explicitly as below.
```sql
alter table public.families add column branch_year int null
  check (branch_year is null or (branch_year >= 1 and branch_year <= 9999));

create or replace function public.family_tree_root(fid uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  with recursive walk as (
    select f.id, f.parent_family_id, 0 as depth, array[f.id] as path
    from public.families f
    where f.id = fid and f.deleted_at is null
    union all
    select p.id, p.parent_family_id, w.depth + 1, w.path || p.id
    from walk w
    join public.families p on p.id = w.parent_family_id
    where p.deleted_at is null and w.depth < 64 and not p.id = any(w.path)
  )
  select id from walk order by depth desc limit 1;
$$;

create or replace function public.is_family_tree_readable(fid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select exists (
      select 1
      from public.memberships m
      join public.families mf on mf.id = m.family_id and mf.deleted_at is null
      where m.user_id = auth.uid()
        and public.family_tree_root(m.family_id) = public.family_tree_root(fid)
    )
  ), false);
$$;

create or replace function public.list_family_tree(fid uuid)
returns table (id uuid, name text, parent_family_id uuid, branch_year int)
language sql
stable
security definer
set search_path = public
as $$
  with recursive down as (
    select f.id, f.name, f.parent_family_id, f.branch_year, 0 as depth, array[f.id] as path
    from public.families f
    where f.id = public.family_tree_root(fid) and f.deleted_at is null
    union all
    select c.id, c.name, c.parent_family_id, c.branch_year, d.depth + 1, d.path || c.id
    from public.families c
    join down d on c.parent_family_id = d.id
    where c.deleted_at is null and d.depth < 64 and not c.id = any(d.path)
  )
  select down.id, down.name, down.parent_family_id, down.branch_year
  from down
  where public.is_family_tree_readable(fid);
$$;

create view public.people_tree_read with (security_barrier = true) as
  select p.id, p.family_id, p.name, p.relationship
  from public.people p
  where public.is_family_member(p.family_id)
     or public.is_family_tree_readable(p.family_id);

revoke all on function public.family_tree_root(uuid) from public, anon, authenticated;
revoke all on function public.is_family_tree_readable(uuid) from public, anon;
revoke all on function public.list_family_tree(uuid) from public, anon;
grant execute on function public.is_family_tree_readable(uuid) to authenticated, service_role;
grant execute on function public.list_family_tree(uuid) to authenticated, service_role;
revoke all on public.people_tree_read from public, anon, authenticated;
grant select on public.people_tree_read to authenticated;
```
- SELECT policies (replace SELECT only; INSERT/UPDATE/DELETE unchanged): `families` = (member OR `is_family_tree_readable(id)`) AND M10 soft-delete clause. `stories` = member OR (tree-readable AND `status = 'published'`). `photos` / `comments` / `perspectives` / `story_people` = member of the story's family OR (tree-readable AND story published). `places` = member OR tree-readable. `people` = member only (unchanged). Storage `story-photos` SELECT = member OR (tree-readable AND a published story in that family owns the path). `profiles` / `avatars` unchanged (co-member only).
- pgTAP adds: deleted child absent from `list_family_tree` for a parent member **and** for the child's owner; `is_family_tree_readable` false on a soft-deleted `fid`; a user whose only tree link is a membership in a soft-deleted family cannot read the tree; tree reader cannot SELECT `people` (no email) but can SELECT `people_tree_read`; `has_function_privilege('anon', …, 'execute')` false for all three functions and `has_function_privilege('authenticated', 'public.family_tree_root(uuid)', 'execute')` false.
- Family dropdown (Bill 2026-10-10): a Related families block below the M10 block, fed by the same `list_family_tree` result as the marks. No extra read, and the block is hidden when the list is empty. The open family's row gets the checkmark. Picking a row switches `FamilySelection` like a mark tap.
> 🚫 FORBIDDEN: Granting `family_tree_root` to any client role. An `email` column on `people_tree_read`. Returning soft-deleted rows from `list_family_tree`. Widening `people` SELECT.
### Open questions (Bill) — M12
1. **Ship order:** **LOCKED (Bill 2026-10-07)** — do M12 first; empty marks until M11 creates branches.
2. **Drafts on related families:** **LOCKED (Bill 2026-10-07)** — yes; non-members never see drafts on a related timeline (member-only SELECT for drafts).
## M12 security amendments (LOCKED Bill 2026-10-10, from Trinity PR #24 review)
Ship in PR #24 fix push, migration `20261010233000_story_photos_tree_read_guard.sql` (new file; do not edit `20261010230000`). Apply with `supabase migration up`.
1. **story_people same-family (TMAS-24-01 High).** `story_people` INSERT and UPDATE WITH CHECK add: `exists (select 1 from public.people p join public.stories s on s.id = story_people.story_id where p.id = story_people.person_id and p.family_id = s.family_id)`. `ensure_story_person_membership()` raises `FORBIDDEN` when `person.family_id <> story_family` (defense in depth).
2. **Child rows tied to story family (TMAS-24-02).** `photos`, `comments`, `perspectives` INSERT (and UPDATE where present) WITH CHECK add `exists (select 1 from public.stories s where s.id = <tbl>.story_id and s.family_id = <tbl>.family_id)` with `<tbl>` = photos / comments / perspectives. Always qualify outer columns inside exists(); a bare `family_id` binds to stories and is a tautology.
3. **Storage insert/update.** `story_photos_insert_member` and the update policy: exactly two folders; both segments cast only via `case when seg ~* '<uuid regex>' then seg::uuid end` (never a bare or `and`-guarded cast); segment 2 is a story in the segment-1 family the uploader can write to; extension allowlist unchanged. Select policy: guarded cast (already in fix item 4).
4. **Soft-deleted family goes dark.** New security-definer `is_live_family_member(fid)` = member AND `families.deleted_at is null`. Every content SELECT/INSERT/UPDATE policy (stories, people, places, photos, comments, perspectives, story_people, storage story-photos, `people_tree_read` member branch) uses it instead of `is_family_member`. `families` and `memberships` keep `is_family_member` so owner/co_owner still see the deleted row to restore from Manage families.
5. **auth.uid().** Use `(select auth.uid())` in new/rewritten policies and helpers. Null uid fails closed.
6. **pgTAP:** cross-family person link denied; child row with mismatched family_id denied; non-story / 3-folder / non-uuid storage paths rejected on insert with `42501` via `throws_ok` (not `22P02`); member of a soft-deleted family reads 0 stories/people/photos (drafts included) while owner still reads the families row; no-uid call returns false/0 rows.
7. **Deferred to M11:** TMAS-24-05 (places and `people_tree_read` scoped to published stories).
