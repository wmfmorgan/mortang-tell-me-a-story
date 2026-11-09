# M10 Manage families

> Gate: plan only until approved. No app code before.
>
> On approval: copy file to `docs/superpowers/plans/2026-10-07-m10-manage-families.md` in first commit. Worktree `.worktrees/feat-m10-manage-families`, branch `feat/m10-manage-families`, from **`origin/main` `1dc7976`** (`feat(m9): reader modal (#22)`). Local `main` matches. No branching from leftover worktree.

**Goal:** Signed-in member opens Manage families from avatar menu: list active families, start root family, open family, rename, add/remove co-owners, remove member, transfer ownership, soft-delete or recover. Six screens = Stitch ids in Impl Spec §15 M10. Exit = Bill local smoke. Open one PR. No merge. No claiming Bill smoke. No CLOSED stamp.

**Architecture:** Role changes + family lifecycle writes via security-definer SQL functions. Eight Edge functions = thin JWT wrappers over them. Client never inserts/updates/deletes `memberships`. New `people.user_id` + trigger upserts `member` row when tagged person resolves to existing profile. Soft-delete sets `families.deleted_at`. Purge function hard-deletes after 60 days. Session family stays `FamilySelection` / `currentFamilyId()`.

**Tech stack:** Flutter 3.x, `albumTheme()`, `go_router`, existing `AlbumHeader`, Supabase Postgres, existing Edge `_shared` helpers. No new package. No SMS.

## Sources

- Impl Spec §15 M10, status **READY for Grok Build**, not CLOSED: https://app.notion.com/p/3e0c4bcef238814f9686d1d956b1f3f8
- Design Doc “M10 Manage families” (Gilfoyle 2026-10-07): https://app.notion.com/p/3e0c4bcef23881c0ba43db61e6195ec7
- UXD M10, cited by playbook: https://app.notion.com/p/3e0c4bcef238818dba09d617a2127cd4
- Stitch project `12192342757314667328`. Six screens = visual source. No open, edit, or codegen from Stitch.

| Surface | Screen id | Title | HTML file | Screenshot file |
| --- | --- | --- | --- | --- |
| Avatar menu | `6b07fcdcaa204d028e79ab4494ca975a` | iPad Family Timeline with Open BM Avatar Menu | `61229486c59a4f11a5266ec5004a6640` | `d5d2b55241774f6d82eaa9766970607e` |
| Hub | `b429823c1f6a44aea297aaeef195bedd` | Manage families hub — Tell Me a Story (R2 header) | `641f4d56805247328097a344b0d216c4` | `2763b12f0f27453893379f835d8848f1` |
| Start a family | `78ba55e6adf1449685fe9dadcc1ccdfc` | Start a family | `dd9ea1fd60b0477593f1a9ecdf456151` | `cb0aad212ca643d38748c3c678eec7ae` |
| Family detail | `1c097b0e40cd4703a76fb8b1baf1ebc7` | Family detail — owner | `1b5b186660894e96bf039837963058f9` | `de012f5a9f9842758474ebda8635916a` |
| Transfer | `5a400d28acc24b9eb8f17da6ac3074e9` | Transfer ownership | `3915c09d401b4111bc101c0adbd79338` | `d0fc8ce8d54c4be0997f7c5137513d0b` |
| Soft-delete confirm | `505fa619379b4ca797208e8087ccf630` | Delete family confirmation | `467db5d51231498a9df519e398a7ac7e` | `da2792cf89fe45b48c101d1def45de9b` |

Resource prefix: `projects/12192342757314667328/files/<id>`. Desktop frames. Hub, Start, Transfer, Delete 2560×2048. Detail 2560×3374.

**Ignore these screens and chrome:**

- Superseded hub `f1949c8fd1db41b4baf0c5e9fdb387ce`.
- Timeline drawn under avatar menu (Jenkins Family Chronicle, decade counts, Private Family Vault). Stand-in frame. No restyle of Macro, Mid, Full Cards.
- Page chrome behind Transfer + Delete modals: Export Album, Add Story, Family Members, Generations, Captured Stories, Contributors, Jenkins wordmark. Real page under dialogs = detail route with R2 header.
- M12 branch-mark screens `a6259996a3b1408486c6074a4fa75f5d`, `5a0fa5949a9647daa363c3daf34bd49e`, `974665ebd3a44254a61da7f1cf45a3f2`.

M12 “ship M12 first” lock = M12 before M11. Not blocking M10. No M11/M12 in this PR.

## Global constraints

- No reopening M1–M9, FA, R2, R3. No R2 header restyle except inserting **Manage families** between Settings and Logout in existing avatar menu.
- No editing migrations on main. Latest on main: `20261005000002_avatars_select_comember.sql`.
- No `supabase db reset`. Apply new files forward.
- No new graph table. No `branch_year`. No tree-wide write RLS. Branch create stays M11. Dial marks stay M12.
- Client never writes `memberships`. No INSERT/UPDATE/DELETE policy for `authenticated` on `memberships`.
- No auto-create auth user or invite from name tag. No promote to `owner`/`co_owner` from tag.
- Transfer immediate. No accept step, no pending-transfer column.
- Only `owner` soft-deletes, transfers, removes co-owner. Co-owner/member cannot soft-delete.
- R2 family menu = only control switching session family. Enter on hub card opens detail. No `FamilySelection.remember` call.
- Tokens: parchment `#FBF7F2`, terracotta `#8B5E4B`, sage `#7A8B74`, ink `#2C2416`. Newsreader headlines, Literata body, Source Sans 3 labels. Cards 8–12px.
- Demo names off UI: Jenkins, Morgan, Eleanor, Sarah, Aunt Clara, Uncle Jim, Julian, Everest, Oak Ridge. Paint `families.name`, `profiles.display_name`, real counts.
- No `memberships.created_at`. Transfer line “Added Oct 2021” has no column. Leave off.
- No **Primary** chip. No column supports it.
- Leave off Transfer info sentence “Eleanor Morgan will need to confirm acceptance of primary ownership.” Playbook marks it non-binding. Painting it implies handshake milestone doesn't do.
- Error shape stays `{ "code", "message" }` with existing codes `AUTH_REQUIRED`, `FORBIDDEN`, `NOT_FOUND`, `VALIDATION`. No new code.
- No CLOSED stamp. Bill local smoke = exit.

## Data

Two migrations. Postgres can't use new enum label in same transaction that adds it. Supabase runs each migration file in one transaction.

### `supabase/migrations/20261007000001_membership_roles.sql`

Enum values only. No backfill, no policy writing `owner`/`co_owner`.

```sql
alter type public.membership_role add value if not exists 'owner';
alter type public.membership_role add value if not exists 'co_owner';
```

`member` stays. No edit to `20260923000001_enums.sql`.

### `supabase/migrations/20261007000002_manage_families.sql`

**Columns**

```sql
alter table public.families
  add column deleted_at timestamptz null;

create index families_deleted_at_idx
  on public.families (deleted_at)
  where deleted_at is not null;

alter table public.people
  add column user_id uuid null references public.profiles (id);

create unique index people_family_user_uidx
  on public.people (family_id, user_id)
  where user_id is not null;

create unique index memberships_one_owner_uidx
  on public.memberships (family_id)
  where role = 'owner';
```

**Backfill.** Per family: if `created_by` has membership, set role `owner`. If none, insert one with role `owner`. All other memberships stay `member`. Result: each existing family has one owner.

**`create_family`.** `create or replace` in this migration. Keep signature `create_family(p_name text) returns public.families`. Reject null `auth.uid()` and blank trimmed name. Insert family with `parent_family_id` null, `created_by = auth.uid()`, then membership role `owner`. Timeline path calling this RPC when no family keeps working, still yields owner. No edit to `20260923000004_rls.sql`.

**Role helpers.** `is_family_owner(fid uuid)` and `is_family_co_owner(fid uuid)`, both `security definer`, `search_path = public`, granted to `authenticated` + `service_role`. Co-owner = role `co_owner` only, not owner.

**Co-owner cap.** `before insert or update` constraint trigger on `memberships` raises when statement would leave >2 `co_owner` rows per `family_id`. Unique owner index covers one-owner rule. Edge and SQL both hit these checks.

**RLS on `families`.**

- Replace `families_select_member`. Member selects row when `deleted_at is null`, or when `deleted_at` set and caller is `owner`/`co_owner` of family. Plain member + stranger can't see soft-deleted family.
- Replace `families_update_member`. `USING` + `WITH CHECK` require `is_family_owner` or `is_family_co_owner`. `before update` guard raises unless caller owner/co-owner when `name` changes or `deleted_at` cleared; raises unless caller owner when `deleted_at` goes null → timestamp. Service role bypasses RLS. Purge function = hard-delete path.
- Drop `families_delete_member`. Authenticated clients get no DELETE policy.

**Tree walk, remove-member only.** Walk `parent_family_id` to root, then every descendant, incl. rows with `deleted_at` set. Removing person drops their membership on each. Walk grants no story write on those families. M12 “children act as roots while the parent is soft-deleted” rule = marks, not this delete.

**Security-definer functions** (JWT `auth.uid()`, `search_path = public`, execute revoked from `public`, granted to `authenticated`). Each raises `VALIDATION:` or `FORBIDDEN:` so Edge wrapper maps existing codes. SQL tests call directly.

| Function | Rule |
| --- | --- |
| `rename_family(fid, name)` | Owner or co-owner. Trimmed name required. |
| `add_co_owner(fid, target)` | Owner or co-owner. Target has membership on `fid` with role `member`. Promote to `co_owner`. Cap trigger rejects third. |
| `remove_co_owner(fid, target)` | Owner only. Target role on `fid` is `co_owner`. Set to `member`. No row delete. |
| `remove_member(fid, target)` | Owner or co-owner. Delete target membership on every family in branch tree. No delete of `people` or `story_people`. Reject removing `auth.uid()`, removing `owner`, removing `co_owner` when caller not `owner`. |
| `transfer_ownership(fid, new_owner, former_becomes)` | Owner only. `new_owner` is current `co_owner` on `fid`. `former_becomes` is `co_owner` or `member`. Swap in one transaction. No invite, no second confirm. |
| `soft_delete_family(fid)` | Owner only. Set `deleted_at = now()` when null. No delete of child rows or storage. Children keep `parent_family_id`. |
| `recover_family(fid)` | Owner or co-owner. Clear `deleted_at` when within 60 days. After 60 days raise `FORBIDDEN:`. |
| `purge_expired_families()` | No caller check beyond execute grant to `service_role` only. Per family with `deleted_at` >60 days old: null each direct child's `parent_family_id`, then `delete` parent. Existing FKs cascade parent rows. No Storage object delete. Spec names row cascade, not bucket purge. |

`purge_expired_families` not client call. If `pg_cron` installed, schedule daily inside `do` block. Extension missing → migration still succeeds. Tests call function. No client button.

**Named on a story.** Trigger `ensure_story_person_membership`, security definer:

- After `story_people` insert, and after `people.user_id` or `people.email` change while person on ≥1 story in same family.
- Resolve account: `people.user_id` when set, else one case-insensitive match of non-null `people.email` to `profiles.email`. Zero or >1 email matches → nothing.
- Upsert `memberships` on story's `family_id` role `member`. User already `owner`/`co_owner` there → leave role. No auth user insert.
- Membership = that story's family only.

Client may set `people.user_id` on existing people update when known profile chosen. No new “link account” screen. Add Person form unchanged. Email-only tags still auto-member via trigger.

## Edge

One folder per contract, same shape as `supabase/functions/create-invite/index.ts` (`corsHeaders`, `errorResponse`, bearer JWT, user client). User client calls RPC so `auth.uid()` = caller. No service role for these eight.

| Folder | Body | RPC |
| --- | --- | --- |
| `create-root-family` | `{ "name" }` | `create_family` → `201` `{ "family_id" }` |
| `rename-family` | `{ "family_id", "name" }` | `rename_family` |
| `add-co-owner` | `{ "family_id", "user_id" }` | `add_co_owner` |
| `remove-co-owner` | `{ "family_id", "user_id" }` | `remove_co_owner` |
| `remove-member` | `{ "family_id", "user_id" }` | `remove_member` |
| `transfer-ownership` | `{ "family_id", "new_owner_user_id", "former_owner_becomes" }` | `transfer_ownership` |
| `soft-delete-family` | `{ "family_id" }` | `soft_delete_family` |
| `recover-family` | `{ "family_id" }` | `recover_family` |

Raise message starting `FORBIDDEN:` → HTTP 403 `FORBIDDEN`. `VALIDATION:` → HTTP 400 `VALIDATION`. Missing auth → `AUTH_REQUIRED` 401. Unknown family → `NOT_FOUND` 404 when RPC says so.

Invite from detail page still uses `create-invite` + `send-invite-email` for that `family_id`. Accept still upserts `member` on invite's family. No change to those four functions.

## Client routes

`AppRoutes.manageFamilies = '/manage-families'`.

`AppRoutes.manageFamily = '/manage-families/:familyId'`.

`manageFamilyPath(id)` builds detail URL.

Both signed-in, use existing redirect. Register detail path as child or separate `GoRoute` so `familyId` is one segment.

Start, Transfer, Delete = dialogs on those routes. No added routes.

### Session family filter

`FamiliesApi.listMine` = R2 menu source. Return only families with `deleted_at` null. Selecting `memberships.role` not required for menu. Owner can still SELECT soft-deleted row, so filter goes in query (`families!inner` and `deleted_at=is.null`), not only RLS.

`InviteApi.currentFamilyId` and `_membershipFamilyIds` use same active set. Remembered id that's only a soft-deleted membership falls through to unordered `limit(1)` read among active families. No `order`. Never return soft-deleted id.

After successful soft-delete of remembered family, clear remembered id so next timeline read doesn't stick on it.

### Avatar menu — screen `6b07fcdcaa204d028e79ab4494ca975a`

File: `apps/tell_me_a_story/lib/core/theme/album_header.dart`.

Open menu = three rows, this order, on every page already showing avatar (timeline, Drafts, New story, Settings):

| Order | Label | Key | Action |
| --- | --- | --- | --- |
| 1 | Settings | `header-menu-settings` | Existing push to `/settings` |
| 2 | Manage families | `header-menu-manage-families` | `context.push('/manage-families')` |
| 3 | Logout | `header-menu-logout` | Existing sign-out |

New row icon: `Icons.diversity_3`, ink, same Source Sans 3 row style as Settings. Manage families not a row on Settings form. Menu surface stays current parchment popover (`#FFFDF9`, 12px radius, `#E6DCD1` border). No rebuild of timeline behind it.

### Hub — screen `b429823c1f6a44aea297aaeef195bedd`

File: `apps/tell_me_a_story/lib/features/family/manage_families_page.dart`.

R2 `AlbumHeader` on top. Page body, no second app bar:

- Newsreader title `Manage families`.
- Subtitle `Switch between your active family archives or create a new shared space.`
- Terracotta button `+ Start a family`, key `manage-families-start`. Opens Start dialog.
- Section label `Your families` + count `{n} active`.
- One white card per active membership. Role chip from `memberships.role`: `owner` → `Owner`, `co_owner` → `Co-owner`, `member` → `Member`. Meta line `{members} members · {stories} stories`. `stories` counts `status = published` only; drafts excluded. Trailing text button `Enter`, key `manage-family-enter-<id>`, pushes `/manage-families/<id>`.
- Section `Recoverable (60 days)` only when caller has ≥1 soft-deleted family as owner/co-owner. Card line `{name}`, then `deleted {n} days ago · Available for recovery for {remain} more days`, computed from `deleted_at` + 60-day window. Button `Recover`, key `manage-family-recover-<id>`, calls `recover-family`, reloads hub. Recover doesn't change session family.

Empty active list still shows title, subtitle, `+ Start a family`. No invented empty sentence.

### Start — screen `78ba55e6adf1449685fe9dadcc1ccdfc`

Dialog on hub, key `start-family-dialog`.

- Title `Start a family`. Close icon pops dialog.
- Body `Create a new root family archive. You become the owner.`
- Label `Family name`, hint `Required`.
- Note `You'll land on this family's empty timeline after create.`
- `Cancel` closes.
- `Create family` calls `create-root-family`. Blank name → no call, dialog stays open. Success: `FamilySelection.remember(familyId)`, then `context.go('/timeline')`. Existing empty timeline copy covers family with no published stories.

### Detail — screen `1c097b0e40cd4703a76fb8b1baf1ebc7`

File: `apps/tell_me_a_story/lib/features/family/manage_family_page.dart`. Key `manage-family-detail`.

R2 header, then back control `Manage families` (arrow) popping to hub. Title = `families.name`. Subtitle `Manage family settings, co-owners, members, and archival access permissions.`

| Block | Copy on the owner screen | Who sees the control |
| --- | --- | --- |
| Family Name | Helper `The primary display name for this shared family heritage archive.` Field shows saved name. Button `Rename`, key `manage-family-rename`. | Owner + co-owner. Hidden for member. |
| Your Role | Chip `Owner`, `Co-owner`, or `Member`. Owner helper: `Your permission level grants full administrative controls over the family archive.` Co-owner helper: `Co-owners have the same powers as the owner.` Member helper: `Family members with access to read and contribute stories to the album.` | Everyone who can open page. |
| Co-owners (up to two) | Heading helper `Co-owners share full administrative privileges with the primary owner.` Button `Add co-owner`. Each row: initials, `profiles.display_name` (fallback `Member`), chip `Co-owner`, `Remove` for owner only. Footnote `Co-owners have the same powers as the owner.` | Add: owner or co-owner, only while <2 co-owners. Remove: owner only, calls `remove-co-owner` (demote to member). |
| Members | Heading helper `Family members with access to read and contribute stories to the album.` Button `Invite`. Rows = role `member` only: initials, name, chip `Member`, `Remove`. | Invite: any member of family. Opens existing `InviteModal` with detail `familyId`, no `FamilySelection` change. Header `Invite` still targets session family. Remove calls `remove-member`, owner or co-owner. |
| Ownership Transfer | `Transfer primary ownership of {name} album and archive to another co-owner.` Button `Transfer ownership…`. | Owner only, only when ≥1 co-owner. |
| Soft-delete this family | `Hidden for 60 days, then permanently removed. Owner only. Recover from Manage families.` Button `Delete family…`. | Owner only. |

`Add co-owner` opens small dialog listing family's `member` rows by display name. Choosing one calls `add-co-owner`. No seventh Stitch screen for picker. No full-page picker.

Initials use M8 rule: first letter of each word of `display_name`. Blank name → no letters. Picture when `avatar_path` set, same circle as header. Co-member avatar read already exists.

Member (not owner/co-owner) still opens detail from Enter. Owner-only + co-owner blocks hidden, not disabled lookalikes with no spec.

### Transfer dialog — screen `5a400d28acc24b9eb8f17da6ac3074e9`

Key `transfer-ownership-dialog`. Title `Transfer ownership`. Close + `Cancel` dismiss.

- `Choose a new owner for {name}.`
- Label `New owner`. One radio per current co-owner: initials, display name, chip text `Co-owner`. No “Added …” date.
- Label `After transfer, you become:` with `(required)`.
- Choice `Co-owner` + line `Maintain full administrative editing rights and member management capabilities.`
- Choice `Member` + line `Standard contributor access to view and add memories to the family archive.`
- Button `Transfer ownership` disabled until co-owner + former-role both selected. Calls `transfer-ownership`, closes on success. Detail reloads. Caller's chip changes immediately. No waiting state.

### Delete dialog — screen `505fa619379b4ca797208e8087ccf630`

Key `delete-family-dialog`. Title `Delete {name}?`.

Body, exact: `Hidden for 60 days, then permanently removed. Owner/co-owner can Recover from Manage families. Story tags stay if people are tagged elsewhere.`

Prompt `Type {name} to confirm` + text field. `Confirm delete` disabled until trimmed field equals `families.name`. Calls `soft-delete-family`. Success closes dialog, returns to hub, drops family from active list. If id was session family, clear remembered id. `Cancel` dismisses.

Detail block says “Owner only.” Dialog body says “Owner/co-owner can Recover.” Both strings on their screens. Recover stays owner or co-owner. Delete button stays owner only.

## Files

- `supabase/migrations/20261007000001_membership_roles.sql`
- `supabase/migrations/20261007000002_manage_families.sql`
- `supabase/tests/manage_families.sql`
- `supabase/functions/create-root-family/index.ts`
- `supabase/functions/rename-family/index.ts`
- `supabase/functions/add-co-owner/index.ts`
- `supabase/functions/remove-co-owner/index.ts`
- `supabase/functions/remove-member/index.ts`
- `supabase/functions/transfer-ownership/index.ts`
- `supabase/functions/soft-delete-family/index.ts`
- `supabase/functions/recover-family/index.ts`
- `apps/tell_me_a_story/lib/data/families_api.dart` — active `listMine`, plus hub + detail reads
- `apps/tell_me_a_story/lib/data/manage_families_api.dart` — eight Edge calls
- `apps/tell_me_a_story/lib/data/invite_api.dart` — active-only `currentFamilyId`
- `apps/tell_me_a_story/lib/core/theme/album_header.dart` — menu row
- `apps/tell_me_a_story/lib/core/router/app_router.dart` — two routes
- `apps/tell_me_a_story/lib/features/family/manage_families_page.dart`
- `apps/tell_me_a_story/lib/features/family/manage_family_page.dart`
- `apps/tell_me_a_story/lib/features/family/start_family_dialog.dart`
- `apps/tell_me_a_story/lib/features/family/transfer_ownership_dialog.dart`
- `apps/tell_me_a_story/lib/features/family/delete_family_dialog.dart`
- Widget tests beside existing `test/` suite: menu order, hub cards + recover visibility, start-family navigation, detail role gates, transfer requires both choices, delete confirm matches name

Fakes in timeline, drafts, settings, router tests constructing `FamiliesGateway` must keep compiling while `listMine` still returns `List<MemberFamily>`. Add new gateway as optional router arg, same as `FamiliesGateway` today.

## Tests

From `apps/tell_me_a_story`: `flutter test`.

From repo root, local Supabase running: `supabase test db`. No DB reset.

`supabase/tests/manage_families.sql` covers:

- Backfill + `create_family` leave exactly one `owner`.
- Third `co_owner` write fails.
- Soft-deleted family hidden from plain member + stranger. Owner + co-owner still select it.
- `recover_family` clears `deleted_at` inside 60 days, fails after.
- Parent soft-delete keeps each child's `parent_family_id`. `purge_expired_families` nulls children, then deletes parent.
- `remove_member` deletes tree memberships, leaves `story_people`.
- `transfer_ownership` swaps immediately, rejects non-co-owner target.
- Tagging person whose email matches one profile inserts `member`. No owner demotion. Unknown email creates no `auth.users`.
- Authenticated client still can't insert into `memberships`.
- Existing two-family leak tests still pass.

Paste both command outputs in PR. PR title `feat(m10): manage families`. Branch `feat/m10-manage-families`. No push to main.

## Out

Tree-wide write RLS (M11). Branch-create UX (M11). Hollow-ring marks + related-families list (M12). Replacing R2 family menu with Manage as session switch. Transfer accept step. Soft-delete by co-owner or member. Client writes to `memberships`. Auth users from name tags. Promotion to owner/co-owner by tag. SMS. Storage-object purge. `Primary` chip. “Added …” date. Superseded hub. Stamping CLOSED.

## Bill smoke (do not claim)

Signed in on local `:3000`. Avatar menu shows Settings, Manage families, Logout. Hub lists current family with Owner chip. Start a family with new name → lands on its empty timeline; R2 menu shows it. Detail rename persists. Add co-owner from member, transfer to that co-owner, become Member. Previous owner, still co-owner on second check, soft-deletes, sees family under Recoverable. Recover returns it to active list. Plain member sees no Delete family or Transfer. Person tagged with email matching existing profile becomes member of story's family.