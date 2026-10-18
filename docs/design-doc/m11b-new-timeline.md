## M11b Start a new timeline (LOCKED — Bill, 2026-10-11)
> ✅ Bill said yes to decisions 4 (63-level depth guard), 7 (starter not auto-added) and 8 (any 4-digit year, no future-year rule) as written, 2026-10-11. The whole section is locked.
Gilfoyle, 2026-10-11, 2:20 PM CT. Locked against UXD M11b (LOCKED by Bill at 1:58 PM CT, story-first) and the PRD/Decisions M11 rows (Jared). It is built on main `7cd6bc4` **plus M11a.2**, and M11b branches only after the M11a.2 PR merges. Where a mock differs from the UXD written rules, the rules win. M13 waits until M11b ships. This replaces the PROPOSED v2 draft.
### Scope
- A new timeline is a child family. Create makes it in one transaction with `parent_family_id`, `branch_year`, `origin_story_id` (required: a published story in the parent family), an owner, and the picked members. Nothing is written before Create. No timeline exists without an origin, and there is no pending or waiting state.
- **Entry A, the reader.** "Start a new timeline from this story" goes in the reader's existing ⋯ story-actions menu. It shows only on a published story, and only to live members of that story's own family. Parent = `story.family_id`. The origin is that story, and it's fixed in the create modal.
- **Entry B, the family menu.** "Start a new timeline" opens the **Pick the origin story** modal, which lists the open (parent) family's published stories with a "Write a new story" row. Picking a story opens the create modal with that origin, and the modal shows a "Change" link back to the picker. "Write a new story" goes to the normal New story screen. Publish returns to the create modal with that story attached. Save draft or Cancel ends the flow.
- No entry from dial or timeline marks. The wording "Start a branch" doesn't appear anywhere.
- **After Create**, the starter stays on the parent timeline and sees the toast "\{Name\} timeline created". The new ring appears beside the origin story through the M11a placement. When anyone opens the new timeline, it shows the origin story with the tag exactly as M11a shipped it (`Origin · from {Parent}`) and the parent ring. M11b doesn't change the tag.
- Nesting is allowed. There is no product limit; the only limit is the technical depth guard (decision 4).
- No parent-side revoke (Bill, 2026-10-11).
### Decisions (architecture)
1. **One atomic RPC.** `create_branch_family` takes a required `p_origin_story_id` and sets `origin_story_id` in the same transaction, using the `app.family_origin` flag path. `families_guard_update()` is not changed.
2. **Who may start:** any live member of the parent, in any role. The starter sets the origin at create even if they won't be an owner or co-owner of the new timeline. Changing it later is owner or co-owner only, through `set_family_origin` (M11a.2), which is unchanged.
3. **Origin errors are a uniform ****`NOT_FOUND`****.** A missing story, a draft, a story in another family or a sibling, a story in the grandparent, and null all raise the same error. This matches M11a.2.
4. **Depth guard.** The M12 walks stop at depth 64, so a new family may sit at most 63 levels below its root. Deeper raises `VALIDATION: too many levels`. This is a guard against runaway walks, not a product limit, and no real family tree will reach it.
5. **Picked people are copied.** Each picked parent `people` row is copied into the new family. A copy that resolves to an account becomes a `member` through M10's `resolve_person_user` and `upsert_story_member`.
6. **The owner must be a live member of the parent and have an account.** It defaults to the caller.
7. **No implicit starter membership.** The starter joins the new timeline only as its owner or through a picked `people` row that resolves to them. The UXD gives the starter no other role, so I'm not inventing one. They always stay a member of the parent.
8. **`branch_year`**** is a four-digit year (1000–9999).** The RPC enforces that, and the column CHECK is unchanged. There's no future-year rule, because the UXD doesn't lock one.
9. **Cycle refusal.** A self-parent CHECK on `families`. Updates to `parent_family_id` are already locked by the guard, and the RPC only inserts, so no client path can make a cycle.
10. **No new table, column, enum value, policy or route path.** The policy count stays exactly 44.
### Data (one new migration; do not edit earlier files)
File: `supabase/migrations/20261011200000_start_a_timeline.sql`. It sorts after M11a.2's `20261011190823`. Apply with `supabase migration up --local`. Never run `db reset`, `db pull` or `migration down`.
- **Row locks (Trinity T5, Gilfoyle 2026-10-11): no ****`FOR SHARE`****.** The two foreign keys already take a key-share lock on the parent family and origin story rows during the insert, so neither can be hard-deleted mid-call. A concurrent soft-delete, unpublish or member removal lands in the same state as one made a moment after create, and `family_origin()` and the M10 rules already handle that state at read time. An explicit `FOR SHARE` would only block owners' soft-deletes and add deadlock risk.
- `alter table public.families add constraint families_parent_not_self check (parent_family_id is null or parent_family_id <> id);`
- Nothing else in the schema changes. `families` still has no INSERT policy.
### RPC
`public.create_branch_family(p_parent_family_id uuid, p_origin_story_id uuid, p_name text, p_branch_year int, p_owner_user_id uuid, p_person_ids uuid[] default '{}') returns public.families`
It's security definer with `set search_path = ''`, every name schema-qualified (M11a.2 standard), and `(select auth.uid())`. A null uid fails closed.
Checks run in this order. Messages use main's `CODE: detail` style, mapped by `_shared/manage.ts` `mapRpcError`.
1. `FORBIDDEN: member only` when there's no uid or `public.is_live_family_member(p_parent_family_id)` is false. That covers strangers, tree readers who aren't members, and a soft-deleted parent.
2. `NOT_FOUND: story` unless the story exists, is `published`, and has `family_id = p_parent_family_id`. Every miss gives the same error.
3. `VALIDATION: name is required` when `trim(p_name)` is empty.
4. `VALIDATION: attach year must be four digits` when the year is null or outside 1000–9999.
5. `VALIDATION: owner must be a member of the parent family` when `p_owner_user_id` is null or has no membership on the parent.
6. `VALIDATION: members must come from the parent family` when any de-duplicated id in `p_person_ids` isn't a `people` row on the parent.
7. `VALIDATION: too many levels` when the parent is 63 or more levels below its root, measured by the M12 upward walk (path guard, cap 64). A walk that hits the cap also counts.
Then, in the same transaction:
1. Insert into `public.families` (trimmed name, `p_parent_family_id`, `created_by` = caller, `p_branch_year`) returning the new row.
2. `perform pg_catalog.set_config('app.family_origin', 'on', true)`, update `origin_story_id`, then `perform pg_catalog.set_config('app.family_origin', 'off', true)`. As a backstop, `public.family_origin(new.id) = p_origin_story_id` must hold, or the function raises `NOT_FOUND: story` and the whole transaction rolls back.
3. Insert a membership with `role = 'owner'` for `p_owner_user_id`.
4. For each distinct picked person: insert a copy into the new family (`name`, `relationship`, `email`, `user_id`, `created_by` = caller), then `perform public.upsert_story_member(new.id, public.resolve_person_user(user_id, email))`. On conflict nothing happens, so the owner keeps the owner role.
5. Return the row. The starter's role in the parent doesn't change.
Any raised error rolls everything back. Grants: `revoke all … from public, anon; grant execute … to authenticated, service_role;`
### Edge (thin wrapper, M10 pattern)
`POST /create-branch-family`. Body: `{ parent_family_id, origin_story_id, name, branch_year, owner_user_id, person_ids? }`. Response: `201 { family_id }`.
- Built like `create-root-family`: `handleManage` (JWT, `AUTH_REQUIRED`), one `userSb.rpc` call, then `mapRpcError`.
- Pre-checks return `VALIDATION` for a missing `parent_family_id` or `origin_story_id`, a blank name, or a non-integer year.
- No service role. No new error codes.
### RLS and grants
- No policy changes. The count stays exactly 44. The RPC is the only way to insert a family or a membership.
- Reads need nothing new. Members read the new family as members, tree members read it through `is_family_tree_readable`, and `list_family_tree` returns it with a non-null `origin_story_id`.
- Child members contribute to the origin through M11a's `can_contribute_to_story`.
### Client
**Routes.** No new route path. Two query parameters are added to existing routes:
- `/stories/new?newTimelineFrom=<parentFamilyId>` marks a story written from Entry B.
- `/timeline?newTimelineOrigin=<storyId>` reopens the create modal with that origin attached and "Change" shown. TimelinePage opens it once, then clears the parameter.
**Gateway.** `ManageFamiliesGateway.createBranchFamily({parentFamilyId, originStoryId, name, branchYear, ownerUserId, personIds})` calls `_invoke('create-branch-family', …)` and returns the new id. Errors map to the §12 catalog.
**Reader ⋯ menu (Entry A).** Add "Start a new timeline from this story" to the existing M11a overflow. Show it only when the story is `published` and the caller has a membership on `story.family_id` (`listMine`, live families only). It's hidden in tree-read views and on a parent's origin story viewed from a child. It opens the create modal with the origin fixed (no "Change") and the year prefilled from `story.timeframeStart.year`. A decade-only story still stores `timeframe_start` as the decade's first year, so it prefills that year (e.g. 1970). That's the UXD's "year (or decade)", and the field stays editable. The server is the real gate.
**Family menu (Entry B).** The frozen M10 block is unchanged except for one added row:
1. the "Your families" label and your families (monogram, terracotta check on the current one)
2. a divider
3. "+ Start a family", then **"Start a new timeline"** (no "+"), then "Manage families" (owner/co-owner gate unchanged)
4. the M12 related block: a divider, the "Related families" label, and the whole tree as indented rows with monograms, the open family checked, and no years
Long names truncate with an ellipsis at the menu's max width. "Start a new timeline" shows when the caller is a live member of the open family.
**Pick the origin story (modal).**
- `showFamilyBlurDialog`, titled "Pick the origin story", subtitle "Published stories from \{Parent\}".
- A search field filters by title on the client.
- Rows are the parent family's published stories (title + year) from the timeline's loaded `_published`. Drafts, and a borrowed origin from a grandparent, are excluded.
- A "Write a new story" row goes to `/stories/new?newTimelineFrom=<parentId>`. NewStoryPage keeps the parent as the session family. On Publish it goes to `/timeline?newTimelineOrigin=<newId>`. Save draft or Cancel ends the flow with no call.
- Cancel is an ink outline button.
**Create modal "Start a new timeline".**
- `showFamilyBlurDialog`. The origin card (title + year) sits at the top, with "Change" only on the menu path.
- Timeline name, placeholder "e.g. The Morgan-Reyes".
- Owner: a single-select of the parent's members with accounts, from `FamiliesApi.listMembers(parentId)`, factored out of the `loadDetail` roster query. The default label reads exactly "You".
- Members: chips from `PeopleGateway.listPeople(parentId)`, sage when selected and outline when not. No add-member input.
- "Attaches in \*": one YEAR box, prefilled from the origin's year and editable.
- One line: "You'll stay in \{Parent\}." Cancel (ink outline) and Create timeline (terracotta). No other helper copy.
- Create timeline stays disabled until name, owner and a four-digit year are set. `VALIDATION`, `NOT_FOUND` and `FORBIDDEN` show inline, and the modal stays open.
- On success: close the modal, invalidate the `list_family_tree` cache, reload the parent timeline, and show the toast "\{Name\} timeline created". Don't change `FamilySelection` and don't navigate.
**Carried client items** (from §15 M11a Out and the M12 closed notes):
- A dated Macro mark in a decade with no stories draws as a lone mark.
- Dial ring labels get the menu's ellipsis rule. This is carried from §15 M11a Out, not from the M11b UXD.
- Dinesh's M11a nits.
### Tests (mandatory)
**pgTAP**, new file `supabase/tests/start_timeline.sql`. Big Head pins the count. It covers:
- **Success:** a member, a co-owner and an owner each create a timeline. The row fields are right. The origin is set at create (`family_origin` returns it), `list_family_tree` and `list_origin_dependents` include the new family, and there is exactly one owner.
- **Non-owner starter:** a member starter picks user B as owner. The create succeeds with the origin set, and the starter has no membership in the new timeline. The starter's `set_family_origin` on it raises `FORBIDDEN`, and B's succeeds. A direct `origin_story_id` update still raises `FORBIDDEN: field is locked`.
- **People:** a picked person with a `user_id`, one with a matching email, and one with no account. The owner role is preserved, and the row count equals the distinct picks.
- **Uniform ****`NOT_FOUND: story`****:** a random uuid, a draft, another family's story, a sibling's, the grandparent's, and null. Each leaves no family row behind.
- **`FORBIDDEN`****:** a tree reader who isn't a member, a stranger, no uid, and a soft-deleted parent.
- **`VALIDATION`****:** a blank name, the year values null, 987 and 10000, an owner who isn't a parent member, a foreign person, and the depth guard (depth 63 succeeds, and the next level is refused).
- **Atomicity:** after a person error, no family, membership or origin was written.
- **Nesting:** a grandchild's origin must come from its own parent, so a root story gives `NOT_FOUND`.
- **Cycles and inserts:** a direct authenticated INSERT gives 42501. A self-parent insert as service role gives 23514. A `parent_family_id` update raises `FORBIDDEN: field is locked`.
- **Grants:** anon has no execute and authenticated does. `search_path = ''` on the RPC.
- **Carried:** a member of a soft-deleted family gets 0 rows when deleting a photo row or a `story-photos` object.
- Policy count is exactly 44.
**Edge (Deno):** 401 with no JWT. 400 for a missing origin, a blank name, or a non-integer year. 404 and 403 passed through from the RPC. 201 on success.
**`flutter test`****:**
- Reader item: shows for a member on a published story. Hidden on a draft, for a tree reader, and on a borrowed origin.
- Family menu: order exactly as above, no "+" on the new row, ellipsis.
- Picker: published only, search works, "Write a new story" routing, and Publish reopens create with the origin.
- Create modal: Create stays disabled until name, owner and year are set. The owner default reads "You". The gateway gets the right arguments. Errors show inline.
- After create: the toast text is right, the tree cache is invalidated, `FamilySelection` is unchanged, and the route stays on the parent.
- The carried Macro and label items.
**Smoke (Bill, local, second account):**
1. Start a timeline from the reader.
2. Start one from the menu by picking a story.
3. Start one from the menu by writing and publishing a story.
4. As a member, make the second account the owner: the origin is set, and only the owner can change it.
5. Pick one person with an account and one without.
6. Nest one level.
7. The parent ring sits beside the origin, and the toast shows on the parent.
### Not in M11b
- Dial or timeline-mark entries. "Start a branch". Timelines with no origin or a draft origin. A pending state.
- Landing on the new timeline after create.
- A future-year rule. Changing `branch_year` after create. Co-owner assignment in the modal.
- A clear-origin RPC. Copying the origin story. Parent-side revoke.
- Re-parenting or merging timelines.
- Anything in M13.
- Any new table, column, enum, policy, route path or package.
> 🚫 FORBIDDEN:
> - Inserting a family without an origin.
> - Writing `origin_story_id` outside `set_family_origin` or this RPC's flag path.
> - Editing `families_guard_update()`.
> - Origin errors that tell the cases apart.
> - Auto-adding the starter to the new timeline.
> - Client INSERTs into `families` or `memberships`.
> - Any change to the M10 menu block other than the added row.
> - A "+" on "Start a new timeline".
> - Demo names from the mocks. Mock-only chrome.
> - A policy count other than 44.
> - Editing earlier migrations, or running `db reset`, `db pull` or `migration down`.
> - Folding M13 in.
> - Branching before M11a.2 merges.
> - Stamping CLOSED.
