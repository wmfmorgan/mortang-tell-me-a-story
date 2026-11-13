# M12 Timeline branch marks

> Gate: plan only until this plan is approved. Do not write application code before that.
>
> On approval: copy this file to `docs/superpowers/plans/2026-10-10-m12-branch-marks.md` in the first commit. Worktree `.worktrees/feat-m12-branch-marks`, branch `feat/m12-branch-marks`, from **`origin/main` `bbedef6`** (`feat(m10): manage families (#23)`). Local `main` is `1dc7976` and is one commit behind. Do not branch from the local checkout. Do not use `.worktrees/feat-m10-manage-families`. Do not start M11.

**Goal:** On Macro, Mid, and Full Cards, paint dashed sage hollow-ring marks for the other families in the current branch tree. A mark, or a row in the family menu’s related list, opens that family’s own timeline for read. The other family’s stories never join the dial you were on. Until a branch exists, the marks and the related list are empty. Exit is Bill local smoke. Open one PR. Do not merge. Do not claim Bill smoke. Do not stamp CLOSED.

**Architecture:** One migration adds nullable `families.branch_year`, the locked helpers and `list_family_tree`, the `people_tree_read` view, and SELECT-only policy changes. `people` SELECT stays member-only. Writes stay membership-only. The client loads the tree once for the session family, caches it in memory, and paints marks and the menu from that same result. No new table, Edge function, route, or package.

**Tech stack:** Flutter 3.x, `albumTheme()`, `go_router`, PostgREST, existing `FamilySelection`. Local Supabase only. Do not `db reset`.

## Sources

- Impl Spec §15 M12, status READY, not CLOSED, including the 2026-10-10 amendments: https://app.notion.com/p/3e0c4bcef238814f9686d1d956b1f3f8
- Design Doc “M12 Timeline branch marks” (Gilfoyle 2026-10-07) and “M12 amendments (LOCKED Bill 2026-10-10)”. The amendment SQL wins over the original helper SQL: https://app.notion.com/p/3e0c4bcef23881c0ba43db61e6195ec7
- UXD M12 (Mugatu, UX locked 2026-10-06) and “M12 Related families menu (LOCKED Bill 2026-10-10)”: https://app.notion.com/p/3e0c4bcef238818dba09d617a2127cd4
- PRD M12 (Jared, locked 2026-10-06): https://app.notion.com/p/3e0c4bcef238813e843af14d12c9a4b2
- Stitch project `12192342757314667328`. Branch chrome only:
  - Macro `a6259996a3b1408486c6074a4fa75f5d` (supersedes `02972cf4` for marks only)
  - Mid `5a0fa5949a9647daa363c3daf34bd49e` (supersedes `0cd5bfaa` for marks only)
  - Full Cards `974665ebd3a44254a61da7f1cf45a3f2` (supersedes `c2c1a5e9` for marks only)
- Code base is `origin/main` `bbedef6`. `parent_family_id` already exists. `family_tree_ids` already exists and is revoked from `public`. `families.deleted_at` and owner/co-owner already exist. Do not edit those migrations.

## Global constraints

- Do not reopen M1–M10, R2, or R3. Do not restyle the R2 header. Do not change zoom fade, newest-first order, the 240ms zoom pill, or the M9 tap map (Macro decade, decade node, and story dot open Mid; Mid stub and full card open the reader; Mid rail node opens Full Cards).
- Do not build branch create, “Start a branch”, tree-wide write, notifications, or a year editor. Those are M11. M11 is on hold.
- No new graph table. No new Edge function. No new package. No seed and no fake branches in the local database.
- Do not invent `branch_year` from `created_at`. M11 is the only writer. M12 only reads. Roots stay null.
- Do not merge another family’s stories into the current dial.
- Do not widen `people` SELECT. Do not add `email` to `people_tree_read`. Do not grant `family_tree_root` to any client role.
- Do not widen `profiles` SELECT or `avatars` storage. A tree reader who is not a co-member already sees `Member` and no photo. Leave that fallback.
- Do not widen draft SELECT. Non-members never see drafts.
- Realtime stays `family_id=eq.<current session family>`. No second channel and no cross-family fan-in.
- Ignore superseded Stitch chrome on the three frames: Stories, Family Members, Places, Help, Save draft, Publish, the all-caps “CONTINUOUS FAMILY DIAL” bar, `+/−`, and Fit all. The shipped sub-header and R2 bar stay.
- Demo copy stays off: Jenkins, Everest Cousins, Oak Ridge, “Est. ~1972”, “Archive Node”, “union joined archive” as a new string. The existing M6 rail label stays; this PR does not add another copy of it.
- Tokens stay parchment `#FBF7F2`, terracotta `#8B5E4B`, sage `#7A8B74`, ink `#2C2416`.

## Picks where the sources overlap

1. **Related-families list lives in the existing family menu.** PRD says the entry points are the dial mark and the family menu. UXD “M12 Related families menu (LOCKED Bill 2026-10-10)” puts that list under the M10 block. The membership block stays exactly as M10 locked it: live families, check on the current one, divider, “+ Start a family”, “Manage families” only for an owner or co-owner. Below that, a divider, a disabled `Related families` label, then one row per other family in the tree (same monogram plus `families.name`, no year). The whole block, divider included, hides when that list is empty. Soft-deleted families are absent for everyone, owners included. Recover stays on the Manage hub. When the open family is a related row you are not a member of, that row shows the check and no membership row is checked.
2. **Null `branch_year` does not pick a decade.** Until M11, every child row has a null year. Those marks sort by `families.id` ascending and render as their own group, with the name and no year. They do not sit on a story dot, a decade row, or a card. Macro and Mid put the group at the newest end of the rail (the top). Full Cards put the group above the first card. When `branch_year` is set, placement follows the year rules below. This is the reading of “stable sort among nulls” and “do not invent a year from `created_at`”.

## Data

One new migration, `supabase/migrations/20261010230000_family_tree_read.sql`, after `20261010184643_invite_resend_revoke.sql`. Do not edit older files. No new table. Apply with `supabase migration up --local`. Do not reset the database.

Copy this SQL as written. Do not rewrite the walks. `union` does not dedupe rows that carry `depth`; the `path` array is what stops a cycle. `parent_family_id` is not cleared. `family_tree_ids` stays as M10 shipped it. Do not grant it.

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

No backfill. No trigger writes `branch_year`. A soft-deleted family has no root, so nothing tree-reads it. `list_family_tree` returns live families only, and it returns no rows when the caller cannot read `fid`. The client calls `list_family_tree` once per session family and does not walk `parent_family_id` itself.

### SELECT policies

Replace SELECT only. INSERT, UPDATE, and DELETE stay as they are on `bbedef6`.

Every new SELECT policy that calls `is_family_tree_readable` is `to authenticated`. In each policy the member check comes first (`is_family_member(...) or is_family_tree_readable(...)`) so a member never starts the tree walk.

| Object | New SELECT |
| --- | --- |
| `families` | (`is_family_member(id)` OR `is_family_tree_readable(id)`) AND the M10 soft-delete clause (`deleted_at` is null OR owner OR co-owner). Drop and recreate `families_select_member`. |
| `stories` | member OR (tree-readable AND `status = 'published'`). Drafts stay member-only. |
| `photos`, `comments`, `perspectives`, `story_people` | member of the story’s family OR (tree-readable AND that story is `published`). |
| `places` | member OR tree-readable. |
| `people` | member only. Leave `people_select_member` as it is. `people.email` does not reach a tree reader. |

Storage `story-photos` SELECT becomes: member of the path family, OR (tree-readable AND a `published` story in that family owns that object path). Insert, update, and delete stay member-only.

`profiles` and `avatars` stay co-member only.

`people_tree_read` is the name source for a tree reader. Columns are `id`, `family_id`, `name`, `relationship`. The view filter is the SQL above (`is_family_member` OR `is_family_tree_readable`) and it is the only gate, because the view runs with owner rights. The reader queries this view only when the viewer is not a member of the session family. Members keep reading `people`.

### Tests (pgTAP)

`supabase/tests/family_tree_read.sql`, transaction plus rollback, same harness style as `rls_two_family_isolation.sql`. Insert the link with SQL (`update families set parent_family_id = …`). That is the RLS proof. It is not a product seed.

Assert all of these:

- A member of the parent who is not a member of the child can SELECT the child’s published story, its photo row, a comment, a perspective, and a place.
- That same user cannot SELECT the child’s draft, cannot SELECT `people` (no email), and can SELECT `people_tree_read` for that child (`name` and `relationship` only).
- That same user cannot INSERT a comment or a photo on the child.
- A signed-in user outside the tree gets 0 rows from `people_tree_read` and cannot SELECT the child’s published story.
- As `anon`, selecting from `stories` returns 0 rows and does not error.
- A soft-deleted child is absent from `list_family_tree` for a parent member and for the child’s owner.
- `is_family_tree_readable` is false for a soft-deleted `fid`.
- A user whose only tree link is a membership in a soft-deleted family cannot read the tree.
- A soft-deleted parent splits the walk: the child’s visible root is the child, and the parent’s other relatives do not see the child.
- Two families parented to each other: the walk ends and returns each id once.
- `list_family_tree` on a family with no `parent_family_id` and no children returns that one family.
- `branch_year` rejects `0` and `10000` and accepts null.
- `people_tree_read` has no `email` column.
- `has_function_privilege('anon', 'public.family_tree_root(uuid)', 'execute')` is false, and the same is false for `is_family_tree_readable(uuid)` and `list_family_tree(uuid)`.
- `has_function_privilege('authenticated', 'public.family_tree_root(uuid)', 'execute')` is false.
- `has_table_privilege('anon', 'public.people_tree_read', 'select')` is false.

Run the Supabase SQL test the repo already uses for pgTAP. Paste the output in the PR.

## Client

### Tree cache

Add `listFamilyTree(familyId)` on the families gateway (`apps/tell_me_a_story/lib/data/families_api.dart` or the manage gateway if that is where `origin/main` already reads families — follow the file that owns `listMine`). Call `list_family_tree` once. Map `branch_year`. Marks and the menu share that result. Do not call it a second time for the menu.

Cache the rows in memory, keyed by the session family id. Drop the cache when `FamilySelection` changes. Do not persist it.

`relatedMarks(tree, currentId)` returns every row except `currentId`, sorted by `branch_year` nulls first, then year ascending, then `id` ascending.

### Family menu

In `apps/tell_me_a_story/lib/core/theme/album_header.dart`, the M10 block does not move: membership rows, divider, “+ Start a family”, “Manage families”.

Related rows are every `list_family_tree` row whose id is not in `listMine`, including the open session family when the viewer is not a member of it. Show the block only when that list is non-empty. Marks keep using `relatedMarks` (every tree row except `currentId`). The menu and the marks share one `list_family_tree` call and one cache.

Below the M10 block, when that non-membership list is non-empty:

- Divider, key `family-menu-related-divider`.
- A disabled label row `Related families`.
- One `PopupMenuItem` per related row, key `family-menu-related-{id}`. The row is `FamilyMonogram` plus `families.name`. No year.
- When that id is the open session family, the row shows the same check the M10 rows use, and no membership row is checked.
- `onSelected` is the existing family-id path: `FamilySelection.remember`, then the timeline reloads in place. From Manage hub or detail, keep `_openFamilyTimeline`.

A family you belong to stays in the M10 block only. Soft-deleted families never appear, because the function omits them.

### Marks

Hollow ring: sage stroke about 2px, transparent fill, outer size about 16, not terracotta, not a filled story dot. Label beside it is the family name. When `branch_year` is non-null, the label adds the year as `Name · 1972`. No tilde, no “Est.”. Key `timeline-branch-mark-{familyId}`. Tooltip is the same label. Cursor is the click pointer. Tap calls the same select path as the menu. It does not call `_openStory`, `_openMid`, or `_openNear`.

Keep the existing M6 dashed sage rail, `timeline-branch-{storyId}`, `{NAME} BRANCH`, and `← {name} union joined archive`. Those still come from `childFamily` over memberships. Marks are a second set of widgets. A story dot stays `timeline-dot-{storyId}`.

Placement when `branch_year` is set:

| Zoom | Where |
| --- | --- |
| Macro | On the decade row whose start year is `branch_year - (branch_year % 10)`. Several marks on one decade stack by `id`. |
| Mid | Beside the published story whose `timeframe_start` year is closest to `branch_year`. Tie breaks to the newer story. |
| Full Cards | Between cards, newest-first. The mark sits after the last card with year greater than `branch_year` and before the first card with year less than or equal to it. A year past both ends sits at that end. |

Placement when `branch_year` is null: the group described in pick 2. The group is not inside a story row’s hit target.

The three rails keep their story taps, arrow keys, fade, and zoom switch.

### Read-only session family

Write still requires membership of the family on screen. Tree read does not grant it. M11’s tree-wide write is out.

`listMine` is the membership set. When the session family is absent from it:

- AlbumHeader omits Invite and New story. Timeline, Drafts, and the search chip stay.
- `/stories/new` redirects to `/timeline`. No new error screen and no new copy.
- The reader hides `+ Add comment`, `+ Add your perspective`, and `+ Add photos`. Existing comments and perspectives still render. People chips load from `people_tree_read` (`name`, `relationship` only). Author name stays the current fallback (`Member` when the profile row is invisible).
- Drafts load returns the empty state, because draft SELECT is still member-only. Do not show an error in place of that empty copy.
- Search keeps querying the session family and keeps excluding drafts. Published stories of the family you opened are in scope because you switched the session family. Search does not query the whole tree in one request.

When the session family is in `listMine`, those controls stay as they are today.

### Realtime

On a family switch, the existing stories subscription must filter to the new id only. If the timeline already resubscribes on family change, leave that path. Do not add a channel that listens to sibling families.

## Files

- `supabase/migrations/20261010230000_family_tree_read.sql`
- `supabase/tests/family_tree_read.sql`
- `apps/tell_me_a_story/lib/data/families_api.dart` (tree read and the cache type)
- `apps/tell_me_a_story/lib/core/theme/album_header.dart`
- `apps/tell_me_a_story/lib/features/timeline/timeline_page.dart`
- `apps/tell_me_a_story/lib/features/timeline/timeline_zoom.dart` (mark placement helpers only)
- Reader page, only to hide the three write controls when the viewer is not a member
- New story route guard in the router
- Tests: `test/timeline_page_test.dart`, `test/m10_navigation_test.dart` or the header test that already covers the menu, plus a small reader test for the hidden write controls

Fakes that construct the families gateway gain `listFamilyTree`. Default returns the current family only, so existing tests stay on the empty-mark path.

## Widget tests

- A tree of one family paints no `timeline-branch-mark-` widget and no `Related families` label, on far, mid, and near.
- A second family with null `branch_year` paints one hollow-ring mark on each zoom, labeled with the name and no year, and does not paint that id as `timeline-dot-`.
- A second family with `branch_year` 1972 paints `Name · 1972` on the 1970s Macro row, beside the closest Mid story, and between Full Cards at that year.
- Tapping the mark remembers that family id and the next build shows that family’s stories, not a mix.
- Macro story dots still open Mid. Mid stubs still open the reader. The M6 `MARTINEZ BRANCH` rail still paints when a membership child exists.
- The family menu still shows Start and Manage in the same order. A related row selects that family. Widget test: a two-family tree where the open family is the related one shows the related block, that row is checked, and no membership row is checked. The related block is absent when every tree row is in `listMine`.
- A session family that is not a membership hides Invite, New story, and the three reader write controls.

`flutter test` from `apps/tell_me_a_story`. Paste the summary in the PR.

## Out

- M11 branch create, owner assignment, member copy, attach-year editor, parent-delete email, tree-wide write.
- Seeding `parent_family_id` or `branch_year` in the local app database. pgTAP may insert both inside its rolled-back transaction.
- Loading sibling stories onto the current dial.
- A new graph table, Edge function, route, or package.
- Widening draft SELECT, `people` SELECT, profile SELECT, or avatar SELECT.
- An `email` column on `people_tree_read`. Granting `family_tree_root` to `anon` or `authenticated`. Returning a soft-deleted family from `list_family_tree`.
- Cross-family Realtime.
- Replacing the M6 dashed rail.
- Stamping CLOSED. Bill local smoke closes the milestone. Cloud staging stays a separate open item.

## Smoke (Bill)

On a family with no branches, Macro, Mid, and Full Cards look as they do today: no hollow-ring marks, no Related families block. Story taps, zoom, search, invite, and new story still work.

A SQL-linked child is optional and is not required to close the empty-mark smoke. If Bill wants the read path exercised, link a family in the local database outside the app, reload, and confirm the mark opens that timeline, a published story is readable, a draft is not listed, and New story and Invite are absent for a non-member.

## PR

Branch `feat/m12-branch-marks`. One PR against `main`. Title `feat(m12): timeline branch marks`. Body says M11 is not in the PR, marks are empty until a branch exists, and Bill smoke is not claimed. Do not merge.
