# M12 Timeline branch marks

> Gate: plan only until approved. No application code before.
>
> On approval: copy file to `docs/superpowers/plans/2026-10-10-m12-branch-marks.md` in first commit. Worktree `.worktrees/feat-m12-branch-marks`, branch `feat/m12-branch-marks`, from **`origin/main` `bbedef6`** (`feat(m10): manage families (#23)`). Local `main` is `1dc7976`, one commit behind. No branching from local checkout. No `.worktrees/feat-m10-manage-families`. No M11 start.

**Goal:** On Macro, Mid, Full Cards, paint dashed sage hollow-ring marks for other families in current branch tree. Mark, or row in family menu's related list, opens that family's own timeline for read. Other family's stories never join current dial. No branch → marks and related list empty. Exit = Bill local smoke. Open one PR. No merge. No claiming Bill smoke. No stamping CLOSED.

**Architecture:** One migration adds nullable `families.branch_year`, locked helpers and `list_family_tree`, `people_tree_read` view, SELECT-only policy changes. `people` SELECT stays member-only. Writes stay membership-only. Client loads tree once for session family, caches in memory, paints marks + menu from same result. No new table, Edge function, route, or package.

**Tech stack:** Flutter 3.x, `albumTheme()`, `go_router`, PostgREST, existing `FamilySelection`. Local Supabase only. No `db reset`.

## Sources

- Impl Spec §15 M12, status READY, not CLOSED, incl. 2026-10-10 amendments: https://app.notion.com/p/3e0c4bcef238814f9686d1d956b1f3f8
- Design Doc "M12 Timeline branch marks" (Gilfoyle 2026-10-07) and "M12 amendments (LOCKED Bill 2026-10-10)". Amendment SQL beats original helper SQL: https://app.notion.com/p/3e0c4bcef23881c0ba43db61e6195ec7
- UXD M12 (Mugatu, UX locked 2026-10-06) and "M12 Related families menu (LOCKED Bill 2026-10-10)": https://app.notion.com/p/3e0c4bcef238818dba09d617a2127cd4
- PRD M12 (Jared, locked 2026-10-06): https://app.notion.com/p/3e0c4bcef238813e843af14d12c9a4b2
- Stitch project `12192342757314667328`. Branch chrome only:
  - Macro `a6259996a3b1408486c6074a4fa75f5d` (supersedes `02972cf4` for marks only)
  - Mid `5a0fa5949a9647daa363c3daf34bd49e` (supersedes `0cd5bfaa` for marks only)
  - Full Cards `974665ebd3a44254a61da7f1cf45a3f2` (supersedes `c2c1a5e9` for marks only)
- Code base = `origin/main` `bbedef6`. `parent_family_id` exists. `family_tree_ids` exists, revoked from `public`. `families.deleted_at` and owner/co-owner exist. Don't edit those migrations.

## Global constraints

- Don't reopen M1–M10, R2, R3. Don't restyle R2 header. Don't change zoom fade, newest-first order, 240ms zoom pill, or M9 tap map (Macro decade, decade node, story dot open Mid; Mid stub and full card open reader; Mid rail node opens Full Cards).
- Don't build branch create, "Start a branch", tree-wide write, notifications, year editor. Those = M11. M11 on hold.
- No new graph table, Edge function, package. No seed, no fake branches in local DB.
- Don't invent `branch_year` from `created_at`. M11 sole writer. M12 reads only. Roots stay null.
- Don't merge other family's stories into current dial.
- Don't widen `people` SELECT. No `email` in `people_tree_read`. Don't grant `family_tree_root` to any client role.
- Don't widen `profiles` SELECT or `avatars` storage. Non-co-member tree reader already sees `Member`, no photo. Keep fallback.
- Don't widen draft SELECT. Non-members never see drafts.
- Realtime stays `family_id=eq.<current session family>`. No second channel, no cross-family fan-in.
- Ignore superseded Stitch chrome on three frames: Stories, Family Members, Places, Help, Save draft, Publish, all-caps "CONTINUOUS FAMILY DIAL" bar, `+/−`, Fit all. Shipped sub-header and R2 bar stay.
- Demo copy off: Jenkins, Everest Cousins, Oak Ridge, "Est. ~1972", "Archive Node", "union joined archive" as new string. Existing M6 rail label stays; PR adds no extra copy.
- Tokens: parchment `#FBF7F2`, terracotta `#8B5E4B`, sage `#7A8B74`, ink `#2C2416`.

## Picks where the sources overlap

1. **Related-families list lives in existing family menu.** PRD: entry points = dial mark + family menu. UXD "M12 Related families menu (LOCKED Bill 2026-10-10)" puts list under M10 block. Membership block stays exactly as M10 locked: live families, check on current, divider, "+ Start a family", "Manage families" only for owner/co-owner. Below: divider, disabled `Related families` label, one row per other tree family (same monogram + `families.name`, no year). Whole block, divider included, hides when list empty. Soft-deleted families absent for everyone, owners included. Recover stays on Manage hub. When open family = related row you're not member of, that row checked, no membership row checked.
2. **Null `branch_year` picks no decade.** Until M11, every child row null year. Those marks sort by `families.id` ascending, render as own group, name, no year. Not on story dot, decade row, or card. Macro + Mid put group at newest end of rail (top). Full Cards put group above first card. When `branch_year` set, placement follows year rules below. This = reading of "stable sort among nulls" and "do not invent a year from `created_at`".

## Data

One new migration, `supabase/migrations/20261010230000_family_tree_read.sql`, after `20261010184643_invite_resend_revoke.sql`. Don't edit older files. No new table. Apply via `supabase migration up --local`. No DB reset.

Copy SQL as written. Don't rewrite walks. `union` doesn't dedupe rows carrying `depth`; `path` array stops cycles. `parent_family_id` not cleared. `family_tree_ids` stays as M10 shipped. Don't grant it.

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

No backfill. No trigger writes `branch_year`. Soft-deleted family has no root → nothing tree-reads it. `list_family_tree` returns live families only; returns no rows when caller can't read `fid`. Client calls `list_family_tree` once per session family; doesn't walk `parent_family_id` itself.

### SELECT policies

Replace SELECT only. INSERT, UPDATE, DELETE stay as on `bbedef6`.

Every new SELECT policy calling `is_family_tree_readable` is `to authenticated`. Member check first in each (`is_family_member(...) or is_family_tree_readable(...)`) so members never start tree walk.

| Object | New SELECT |
| --- | --- |
| `families` | (`is_family_member(id)` OR `is_family_tree_readable(id)`) AND M10 soft-delete clause (`deleted_at` is null OR owner OR co-owner). Drop + recreate `families_select_member`. |
| `stories` | member OR (tree-readable AND `status = 'published'`). Drafts member-only. |
| `photos`, `comments`, `perspectives`, `story_people` | member of story's family OR (tree-readable AND story `published`). |
| `places` | member OR tree-readable. |
| `people` | member only. Leave `people_select_member` as is. `people.email` never reaches tree reader. |

Storage `story-photos` SELECT: member of path family, OR (tree-readable AND `published` story in that family owns object path). Insert/update/delete stay member-only.

`profiles` and `avatars` stay co-member only.

`people_tree_read` = name source for tree reader. Columns `id`, `family_id`, `name`, `relationship`. View filter = SQL above (`is_family_member` OR `is_family_tree_readable`), sole gate, since view runs with owner rights. Reader queries view only when viewer not member of session family. Members keep reading `people`.

### Tests (pgTAP)

`supabase/tests/family_tree_read.sql`, transaction + rollback, same harness style as `rls_two_family_isolation.sql`. Insert link via SQL (`update families set parent_family_id = …`). That = RLS proof, not product seed.

Assert all:

- Parent member who isn't child member can SELECT child's published story, its photo row, comment, perspective, place.
- Same user can't SELECT child's draft, can't SELECT `people` (no email), can SELECT `people_tree_read` for child (`name` and `relationship` only).
- Same user can't INSERT comment or photo on child.
- Signed-in user outside tree gets 0 rows from `people_tree_read`, can't SELECT child's published story.
- As `anon`, selecting from `stories` returns 0 rows, no error.
- Soft-deleted child absent from `list_family_tree` for parent member and for child's owner.
- `is_family_tree_readable` false for soft-deleted `fid`.
- User whose only tree link is membership in soft-deleted family can't read tree.
- Soft-deleted parent splits walk: child's visible root = child; parent's other relatives don't see child.
- Two families parented to each other: walk ends, returns each id once.
- `list_family_tree` on family with no `parent_family_id` and no children returns that one family.
- `branch_year` rejects `0` and `10000`, accepts null.
- `people_tree_read` has no `email` column.
- `has_function_privilege('anon', 'public.family_tree_root(uuid)', 'execute')` false; same false for `is_family_tree_readable(uuid)` and `list_family_tree(uuid)`.
- `has_function_privilege('authenticated', 'public.family_tree_root(uuid)', 'execute')` false.
- `has_table_privilege('anon', 'public.people_tree_read', 'select')` false.

Run repo's existing Supabase SQL test for pgTAP. Paste output in PR.

## Client

### Tree cache

Add `listFamilyTree(familyId)` on families gateway (`apps/tell_me_a_story/lib/data/families_api.dart` or manage gateway if `origin/main` reads families there — follow file owning `listMine`). Call `list_family_tree` once. Map `branch_year`. Marks + menu share result. No second call for menu.

Cache rows in memory, keyed by session family id. Drop cache on `FamilySelection` change. Don't persist.

`relatedMarks(tree, currentId)` returns every row except `currentId`, sorted `branch_year` nulls first, then year asc, then `id` asc.

### Family menu

In `apps/tell_me_a_story/lib/core/theme/album_header.dart`, M10 block doesn't move: membership rows, divider, "+ Start a family", "Manage families".

Related rows = every `list_family_tree` row whose id not in `listMine`, incl. open session family when viewer not member. Show block only when list non-empty. Marks keep using `relatedMarks` (every tree row except `currentId`). Menu + marks share one `list_family_tree` call, one cache.

Below M10 block, when non-membership list non-empty:

- Divider, key `family-menu-related-divider`.
- Disabled label row `Related families`.
- One `PopupMenuItem` per related row, key `family-menu-related-{id}`. Row = `FamilyMonogram` + `families.name`. No year.
- When id = open session family, row shows same check as M10 rows; no membership row checked.
- `onSelected` = existing family-id path: `FamilySelection.remember`, then timeline reloads in place. From Manage hub or detail, keep `_openFamilyTimeline`.

Family you belong to stays in M10 block only. Soft-deleted families never appear (function omits them).

### Marks

Hollow ring: sage stroke ~2px, transparent fill, outer size ~16, not terracotta, not filled story dot. Label beside = family name. Non-null `branch_year` → label `Name · 1972`. No tilde, no "Est.". Key `timeline-branch-mark-{familyId}`. Tooltip = same label. Cursor = click pointer. Tap calls same select path as menu. Doesn't call `_openStory`, `_openMid`, `_openNear`.

Keep existing M6 dashed sage rail, `timeline-branch-{storyId}`, `{NAME} BRANCH`, `← {name} union joined archive`. Those still come from `childFamily` over memberships. Marks = second widget set. Story dot stays `timeline-dot-{storyId}`.

Placement when `branch_year` set:

| Zoom | Where |
| --- | --- |
| Macro | On decade row with start year `branch_year - (branch_year % 10)`. Multiple marks on one decade stack by `id`. |
| Mid | Beside published story whose `timeframe_start` year closest to `branch_year`. Tie → newer story. |
| Full Cards | Between cards, newest-first. Mark after last card with year > `branch_year`, before first card with year ≤ it. Year past either end sits at that end. |

Placement when `branch_year` null: group per pick 2. Group not inside story row's hit target.

Three rails keep story taps, arrow keys, fade, zoom switch.

### Read-only session family

Write still requires membership of family on screen. Tree read doesn't grant it. M11 tree-wide write out.

`listMine` = membership set. When session family absent from it:

- AlbumHeader omits Invite and New story. Timeline, Drafts, search chip stay.
- `/stories/new` redirects to `/timeline`. No new error screen, no new copy.
- Reader hides `+ Add comment`, `+ Add your perspective`, `+ Add photos`. Existing comments + perspectives still render. People chips load from `people_tree_read` (`name`, `relationship` only). Author name keeps current fallback (`Member` when profile row invisible).
- Drafts load returns empty state (draft SELECT still member-only). No error in place of empty copy.
- Search keeps querying session family, keeps excluding drafts. Published stories of opened family in scope since session family switched. Search doesn't query whole tree in one request.

When session family in `listMine`, controls unchanged.

### Realtime

On family switch, existing stories subscription must filter to new id only. If timeline already resubscribes on family change, leave path. No channel listening to sibling families.

## Files

- `supabase/migrations/20261010230000_family_tree_read.sql`
- `supabase/tests/family_tree_read.sql`
- `apps/tell_me_a_story/lib/data/families_api.dart` (tree read + cache type)
- `apps/tell_me_a_story/lib/core/theme/album_header.dart`
- `apps/tell_me_a_story/lib/features/timeline/timeline_page.dart`
- `apps/tell_me_a_story/lib/features/timeline/timeline_zoom.dart` (mark placement helpers only)
- Reader page, only to hide three write controls for non-member
- New story route guard in router
- Tests: `test/timeline_page_test.dart`, `test/m10_navigation_test.dart` or header test already covering menu, plus small reader test for hidden write controls

Fakes constructing families gateway gain `listFamilyTree`. Default returns current family only → existing tests stay on empty-mark path.

## Widget tests

- One-family tree paints no `timeline-branch-mark-` widget, no `Related families` label, on far, mid, near.
- Second family with null `branch_year` paints one hollow-ring mark per zoom, labeled name, no year; doesn't paint that id as `timeline-dot-`.
- Second family with `branch_year` 1972 paints `Name · 1972` on 1970s Macro row, beside closest Mid story, between Full Cards at that year.
- Tapping mark remembers family id; next build shows that family's stories, not mix.
- Macro story dots still open Mid. Mid stubs still open reader. M6 `MARTINEZ BRANCH` rail still paints when membership child exists.
- Family menu still shows Start and Manage, same order. Related row selects that family. Widget test: two-family tree where open family = related one shows related block, that row checked, no membership row checked. Related block absent when every tree row in `listMine`.
- Non-membership session family hides Invite, New story, three reader write controls.

`flutter test` from `apps/tell_me_a_story`. Paste summary in PR.

## Out

- M11 branch create, owner assignment, member copy, attach-year editor, parent-delete email, tree-wide write.
- Seeding `parent_family_id` or `branch_year` in local app DB. pgTAP may insert both inside rolled-back transaction.
- Loading sibling stories onto current dial.
- New graph table, Edge function, route, package.
- Widening draft SELECT, `people` SELECT, profile SELECT, avatar SELECT.
- `email` column on `people_tree_read`. Granting `family_tree_root` to `anon` or `authenticated`. Returning soft-deleted family from `list_family_tree`.
- Cross-family Realtime.
- Replacing M6 dashed rail.
- Stamping CLOSED. Bill local smoke closes milestone. Cloud staging stays separate open item.

## Smoke (Bill)

Family with no branches: Macro, Mid, Full Cards look as today — no hollow-ring marks, no Related families block. Story taps, zoom, search, invite, new story still work.

SQL-linked child optional, not required to close empty-mark smoke. If Bill wants read path exercised: link family in local DB outside app, reload, confirm mark opens that timeline, published story readable, draft not listed, New story + Invite absent for non-member.

## PR

Branch `feat/m12-branch-marks`. One PR against `main`. Title `feat(m12): timeline branch marks`. Body: M11 not in PR, marks empty until branch exists, Bill smoke not claimed. No merge.