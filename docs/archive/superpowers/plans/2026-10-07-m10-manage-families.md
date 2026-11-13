# M10 Manage families

> Gate: plan only until this plan is approved. Do not write application code before that.
>
> On approval: copy this file to `docs/superpowers/plans/2026-10-07-m10-manage-families.md` in the first commit. Worktree `.worktrees/feat-m10-manage-families`, branch `feat/m10-manage-families`, from **`origin/main` `1dc7976`** (`feat(m9): reader modal (#22)`). Local `main` matches that commit. Do not branch from a leftover worktree.

**Goal:** A signed-in member opens Manage families from the avatar menu and can list active families, start a root family, open a family, rename it, add or remove co-owners, remove a member, transfer ownership, and soft-delete or recover a family. The six screens are the Stitch ids in Impl Spec §15 M10. Exit is Bill local smoke. Open one PR. Do not merge. Do not claim Bill smoke. Do not stamp CLOSED.

**Architecture:** Role changes and family lifecycle writes go through security-definer SQL functions. Eight Edge functions are thin JWT wrappers around those functions. The client never inserts, updates, or deletes `memberships`. A new `people.user_id` plus a trigger upserts a `member` row when a tagged person resolves to an existing profile. Soft-delete sets `families.deleted_at`. A purge function hard-deletes after 60 days. Session family stays `FamilySelection` / `currentFamilyId()`.

**Tech stack:** Flutter 3.x, `albumTheme()`, `go_router`, existing `AlbumHeader`, Supabase Postgres, existing Edge `_shared` helpers. No new package. No SMS.

## Sources

- Impl Spec §15 M10, status **READY for Grok Build**, not CLOSED: https://app.notion.com/p/3e0c4bcef238814f9686d1d956b1f3f8
- Design Doc “M10 Manage families” (Gilfoyle 2026-10-07): https://app.notion.com/p/3e0c4bcef23881c0ba43db61e6195ec7
- UXD M10 is cited by that playbook: https://app.notion.com/p/3e0c4bcef238818dba09d617a2127cd4
- Stitch project `12192342757314667328`. These six screens are the visual source. Do not open, edit, or codegen from Stitch.

| Surface | Screen id | Title | HTML file | Screenshot file |
| --- | --- | --- | --- | --- |
| Avatar menu | `6b07fcdcaa204d028e79ab4494ca975a` | iPad Family Timeline with Open BM Avatar Menu | `61229486c59a4f11a5266ec5004a6640` | `d5d2b55241774f6d82eaa9766970607e` |
| Hub | `b429823c1f6a44aea297aaeef195bedd` | Manage families hub — Tell Me a Story (R2 header) | `641f4d56805247328097a344b0d216c4` | `2763b12f0f27453893379f835d8848f1` |
| Start a family | `78ba55e6adf1449685fe9dadcc1ccdfc` | Start a family | `dd9ea1fd60b0477593f1a9ecdf456151` | `cb0aad212ca643d38748c3c678eec7ae` |
| Family detail | `1c097b0e40cd4703a76fb8b1baf1ebc7` | Family detail — owner | `1b5b186660894e96bf039837963058f9` | `de012f5a9f9842758474ebda8635916a` |
| Transfer | `5a400d28acc24b9eb8f17da6ac3074e9` | Transfer ownership | `3915c09d401b4111bc101c0adbd79338` | `d0fc8ce8d54c4be0997f7c5137513d0b` |
| Soft-delete confirm | `505fa619379b4ca797208e8087ccf630` | Delete family confirmation | `467db5d51231498a9df519e398a7ac7e` | `da2792cf89fe45b48c101d1def45de9b` |

Resource prefix: `projects/12192342757314667328/files/<id>`. Desktop frames. Hub, Start, Transfer, and Delete are 2560×2048. Detail is 2560×3374.

**Ignore these screens and chrome:**

- Superseded hub `f1949c8fd1db41b4baf0c5e9fdb387ce`.
- The timeline drawn under the avatar menu (Jenkins Family Chronicle, decade counts, Private Family Vault). That frame is a stand-in. Do not restyle Macro, Mid, or Full Cards.
- Page chrome drawn behind the Transfer and Delete modals: Export Album, Add Story, Family Members, Generations, Captured Stories, Contributors, Jenkins wordmark. The real page under those dialogs is the detail route with the R2 header.
- M12 branch-mark screens `a6259996a3b1408486c6074a4fa75f5d`, `5a0fa5949a9647daa363c3daf34bd49e`, `974665ebd3a44254a61da7f1cf45a3f2`.

M12’s “ship M12 first” lock is M12 before M11. It does not block M10. Do not build M11 or M12 in this PR.

## Global constraints

- Do not reopen M1–M9, FA, R2, or R3. Do not restyle the R2 header except inserting **Manage families** between Settings and Logout in the existing avatar menu.
- Do not edit migrations already on main. Latest on main is `20261005000002_avatars_select_comember.sql`.
- Do not `supabase db reset`. Apply the new files forward.
- No new graph table. No `branch_year`. No tree-wide write RLS. Branch create stays M11. Dial marks stay M12.
- Client never writes `memberships`. Do not add an INSERT/UPDATE/DELETE policy for `authenticated` on `memberships`.
- Do not auto-create an auth user or an invite from a name tag. Do not promote to `owner` or `co_owner` from a tag.
- Transfer is immediate. There is no accept step and no pending-transfer column.
- Only `owner` soft-deletes, transfers, or removes a co-owner. A co-owner or member cannot soft-delete.
- R2 family menu stays the only control that switches the session family. Enter on a hub card opens detail. It does not call `FamilySelection.remember`.
- Tokens stay parchment `#FBF7F2`, terracotta `#8B5E4B`, sage `#7A8B74`, ink `#2C2416`. Newsreader headlines, Literata body, Source Sans 3 labels. Cards 8–12px.
- Demo names stay off the UI: Jenkins, Morgan, Eleanor, Sarah, Aunt Clara, Uncle Jim, Julian, Everest, Oak Ridge. Paint `families.name`, `profiles.display_name`, and real counts.
- Do not add `memberships.created_at`. The Transfer line “Added Oct 2021” has no column. Leave it off.
- Do not paint a **Primary** chip. No column supports it.
- Leave off the Transfer info sentence “Eleanor Morgan will need to confirm acceptance of primary ownership.” The playbook marks that copy non-binding. Painting it would describe a handshake this milestone does not do.
- Error shape stays `{ "code", "message" }` with the existing codes `AUTH_REQUIRED`, `FORBIDDEN`, `NOT_FOUND`, `VALIDATION`. Do not add a new code.
- Do not stamp CLOSED. Bill local smoke is the exit.

## Data

Two migrations. Postgres cannot use a new enum label in the same transaction that adds it. Supabase runs each migration file in one transaction.

### `supabase/migrations/20261007000001_membership_roles.sql`

Enum values only. No backfill and no policy that writes `owner` or `co_owner`.

```sql
alter type public.membership_role add value if not exists 'owner';
alter type public.membership_role add value if not exists 'co_owner';
```

`member` stays. Do not edit `20260923000001_enums.sql`.

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

**Backfill.** For each family, if `created_by` has a membership, set that row’s role to `owner`. If `created_by` has no membership, insert one with role `owner`. Every other membership stays `member`. After this, each existing family has one owner.

**`create_family`.** `create or replace` the function in this migration. Keep the signature `create_family(p_name text) returns public.families`. Reject a null `auth.uid()` and a blank trimmed name. Insert the family with `parent_family_id` null and `created_by = auth.uid()`, then insert the membership with role `owner`. The timeline path that calls this RPC when there is no family keeps working and still produces an owner. Do not edit `20260923000004_rls.sql`.

**Role helpers.** `is_family_owner(fid uuid)` and `is_family_co_owner(fid uuid)`, both `security definer`, `search_path = public`, granted to `authenticated` and `service_role`. Co-owner means role `co_owner` only, not owner.

**Co-owner cap.** A `before insert or update` constraint trigger on `memberships` raises when the statement would leave more than two `co_owner` rows for one `family_id`. The unique owner index covers the one-owner rule. Edge and SQL both hit these checks.

**RLS on `families`.**

- Replace `families_select_member`. A member may select the row when `deleted_at is null`, or when `deleted_at` is set and the caller is `owner` or `co_owner` of that family. A plain member and a stranger cannot see a soft-deleted family.
- Replace `families_update_member`. `USING` and `WITH CHECK` require `is_family_owner` or `is_family_co_owner`. A `before update` guard raises unless the caller is owner or co-owner when `name` changes or `deleted_at` is cleared, and raises unless the caller is owner when `deleted_at` changes from null to a timestamp. Service role bypasses RLS. The purge function is the hard-delete path.
- Drop `families_delete_member`. Authenticated clients get no DELETE policy.

**Tree walk used only by remove-member.** Walk `parent_family_id` to the root, then every descendant, including rows with `deleted_at` set. Removing a person drops their membership on each of those families. This walk does not grant story write on those families. The M12 “children act as roots while the parent is soft-deleted” rule is for marks, not for this delete.

**Security-definer functions** (JWT `auth.uid()`, `search_path = public`, execute revoked from `public`, granted to `authenticated`). Each raises `VALIDATION:` or `FORBIDDEN:` so the Edge wrapper can map the existing error codes. SQL tests call them directly.

| Function | Rule |
| --- | --- |
| `rename_family(fid, name)` | Owner or co-owner. Trimmed name required. |
| `add_co_owner(fid, target)` | Owner or co-owner. Target already has a membership on `fid` with role `member`. Promotes that row to `co_owner`. The cap trigger rejects a third. |
| `remove_co_owner(fid, target)` | Owner only. Target’s role on `fid` is `co_owner`. Sets it to `member`. Does not delete the row. |
| `remove_member(fid, target)` | Owner or co-owner. Deletes the target’s membership on every family in the branch tree. Does not delete `people` or `story_people`. Rejects removing `auth.uid()`, removing an `owner`, and removing a `co_owner` when the caller is not `owner`. |
| `transfer_ownership(fid, new_owner, former_becomes)` | Owner only. `new_owner` is a current `co_owner` on `fid`. `former_becomes` is `co_owner` or `member`. Swap in one transaction. No invite and no second confirmation. |
| `soft_delete_family(fid)` | Owner only. Sets `deleted_at = now()` when it is null. Does not delete child rows or storage. Children keep `parent_family_id`. |
| `recover_family(fid)` | Owner or co-owner. Clears `deleted_at` when it is within 60 days. After 60 days, raise `FORBIDDEN:`. |
| `purge_expired_families()` | No caller check beyond execute grant to `service_role` only. For each family with `deleted_at` older than 60 days: set each direct child’s `parent_family_id` to null, then `delete` the parent. Existing FKs cascade the parent’s rows. Do not delete Storage objects. The spec names the row cascade and does not name a bucket purge. |

`purge_expired_families` is not a client call. If `pg_cron` is installed, schedule it daily inside a `do` block. If the extension is missing, the migration still succeeds. Tests call the function. Do not add a client button.

**Named on a story.** Trigger `ensure_story_person_membership`, security definer:

- After `story_people` insert, and after `people.user_id` or `people.email` changes while that person is on at least one story in the same family.
- Resolve the account: `people.user_id` when set, otherwise one case-insensitive match of non-null `people.email` to `profiles.email`. Zero matches or more than one email match does nothing.
- Upsert `memberships` on that story’s `family_id` with role `member`. If the user is already `owner` or `co_owner` on that family, leave the role. Do not insert an auth user.
- Membership is that story’s family only.

Client may set `people.user_id` on the existing people update when a known profile is chosen. Do not add a new “link account” screen. The Add Person form stays as it is. Email-only tags still auto-member through the trigger.

## Edge

One folder per contract, same shape as `supabase/functions/create-invite/index.ts` (`corsHeaders`, `errorResponse`, bearer JWT, user client). The user client calls the RPC so `auth.uid()` is the caller. Do not use the service role for these eight.

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

Map a raise whose message starts with `FORBIDDEN:` to HTTP 403 `FORBIDDEN`. `VALIDATION:` to HTTP 400 `VALIDATION`. Missing auth is `AUTH_REQUIRED` 401. Unknown family is `NOT_FOUND` 404 when the RPC says so.

Invite from the detail page still uses `create-invite` and `send-invite-email` for that `family_id`. Accept still upserts `member` on that invite’s family. Do not change those four functions.

## Client routes

`AppRoutes.manageFamilies = '/manage-families'`.

`AppRoutes.manageFamily = '/manage-families/:familyId'`.

`manageFamilyPath(id)` builds the detail URL.

Both routes are signed-in. They use the existing redirect. Register the detail path as a child or as a separate `GoRoute` so `familyId` is one segment.

Start, Transfer, and Delete are dialogs on those routes. They do not add routes.

### Session family filter

`FamiliesApi.listMine` is the R2 menu source. It must return only families with `deleted_at` null. Select `memberships.role` is not required for the menu. An owner can still SELECT a soft-deleted row, so the filter belongs in the query (`families!inner` and `deleted_at=is.null`), not only in RLS.

`InviteApi.currentFamilyId` and `_membershipFamilyIds` use that same active set. A remembered id that is only a soft-deleted membership falls through to the unordered `limit(1)` read among active families. Do not add an `order`. Do not return a soft-deleted id.

After a successful soft-delete of the remembered family, clear that remembered id so the next timeline read does not stick on it.

### Avatar menu — screen `6b07fcdcaa204d028e79ab4494ca975a`

File: `apps/tell_me_a_story/lib/core/theme/album_header.dart`.

The open menu is three rows, in this order, on every page that already shows the avatar (timeline, Drafts, New story, Settings):

| Order | Label | Key | Action |
| --- | --- | --- | --- |
| 1 | Settings | `header-menu-settings` | Existing push to `/settings` |
| 2 | Manage families | `header-menu-manage-families` | `context.push('/manage-families')` |
| 3 | Logout | `header-menu-logout` | Existing sign-out |

Icon for the new row: `Icons.diversity_3`, ink, same Source Sans 3 row style as Settings. Manage families is not a row on the Settings form. The menu surface stays the current parchment popover (`#FFFDF9`, 12px radius, `#E6DCD1` border). Do not rebuild the timeline behind it.

### Hub — screen `b429823c1f6a44aea297aaeef195bedd`

File: `apps/tell_me_a_story/lib/features/family/manage_families_page.dart`.

R2 `AlbumHeader` on top. Page body, not a second app bar:

- Newsreader title `Manage families`.
- Subtitle `Switch between your active family archives or create a new shared space.`
- Terracotta button `+ Start a family`, key `manage-families-start`. Opens the Start dialog.
- Section label `Your families` and a count `{n} active`.
- One white card per active membership. Role chip from `memberships.role`: `owner` → `Owner`, `co_owner` → `Co-owner`, `member` → `Member`. Meta line `{members} members · {stories} stories`. `stories` counts `status = published` only. Drafts stay out of the number. Trailing text button `Enter`, key `manage-family-enter-<id>`, pushes `/manage-families/<id>`.
- Section `Recoverable (60 days)` only when the caller has at least one soft-deleted family as owner or co-owner. Card line `{name}`, then `deleted {n} days ago · Available for recovery for {remain} more days`, computed from `deleted_at` and a 60-day window. Button `Recover`, key `manage-family-recover-<id>`, calls `recover-family` and reloads the hub. Recover does not change the session family.

Empty active list still shows the title, the subtitle, and `+ Start a family`. No invented empty sentence.

### Start — screen `78ba55e6adf1449685fe9dadcc1ccdfc`

Dialog on the hub, key `start-family-dialog`.

- Title `Start a family`. Close icon pops the dialog.
- Body `Create a new root family archive. You become the owner.`
- Label `Family name` and the hint `Required`.
- Note `You'll land on this family's empty timeline after create.`
- `Cancel` closes.
- `Create family` calls `create-root-family`. Blank name does not call and keeps the dialog open. Success: `FamilySelection.remember(familyId)`, then `context.go('/timeline')`. The existing empty timeline copy covers a family with no published stories.

### Detail — screen `1c097b0e40cd4703a76fb8b1baf1ebc7`

File: `apps/tell_me_a_story/lib/features/family/manage_family_page.dart`. Key `manage-family-detail`.

R2 header, then a back control `Manage families` (arrow) that pops to the hub. Title is `families.name`. Subtitle `Manage family settings, co-owners, members, and archival access permissions.`

| Block | Copy on the owner screen | Who sees the control |
| --- | --- | --- |
| Family Name | Helper `The primary display name for this shared family heritage archive.` Field shows the saved name. Button `Rename`, key `manage-family-rename`. | Owner and co-owner. Hidden for member. |
| Your Role | Chip `Owner`, `Co-owner`, or `Member`. Owner helper: `Your permission level grants full administrative controls over the family archive.` Co-owner helper: `Co-owners have the same powers as the owner.` Member helper: `Family members with access to read and contribute stories to the album.` | Everyone who can open the page. |
| Co-owners (up to two) | Heading helper `Co-owners share full administrative privileges with the primary owner.` Button `Add co-owner`. Each row: initials, `profiles.display_name` (fallback `Member`), chip `Co-owner`, and `Remove` for the owner only. Footnote `Co-owners have the same powers as the owner.` | Add is owner or co-owner, and only while fewer than two co-owners. Remove is owner only and calls `remove-co-owner` (demote to member). |
| Members | Heading helper `Family members with access to read and contribute stories to the album.` Button `Invite`. Rows are role `member` only: initials, name, chip `Member`, `Remove`. | Invite is any member of this family. It opens the existing `InviteModal` with this detail `familyId` and does not change `FamilySelection`. The header `Invite` still targets the session family. Remove calls `remove-member` and is owner or co-owner. |
| Ownership Transfer | `Transfer primary ownership of {name} album and archive to another co-owner.` Button `Transfer ownership…`. | Owner only, and only when there is at least one co-owner. |
| Soft-delete this family | `Hidden for 60 days, then permanently removed. Owner only. Recover from Manage families.` Button `Delete family…`. | Owner only. |

`Add co-owner` opens a small dialog that lists this family’s `member` rows by display name. Choosing one calls `add-co-owner`. There is no seventh Stitch screen for that picker. Do not invent a full-page picker.

Initials use the M8 rule: first letter of each word of `display_name`. No letters when the name is blank. Picture when `avatar_path` is set, same circle as the header. Co-member avatar read already exists.

A member who is not owner or co-owner still opens detail from Enter. Owner-only and co-owner blocks are hidden, not disabled lookalikes with no spec.

### Transfer dialog — screen `5a400d28acc24b9eb8f17da6ac3074e9`

Key `transfer-ownership-dialog`. Title `Transfer ownership`. Close and `Cancel` dismiss.

- `Choose a new owner for {name}.`
- Label `New owner`. One radio per current co-owner: initials, display name, chip text `Co-owner`. No “Added …” date.
- Label `After transfer, you become:` with `(required)`.
- Choice `Co-owner` and the line `Maintain full administrative editing rights and member management capabilities.`
- Choice `Member` and the line `Standard contributor access to view and add memories to the family archive.`
- Button `Transfer ownership` stays disabled until both a co-owner and a former-role are selected. It calls `transfer-ownership` and closes on success. The detail reloads. The caller’s chip changes immediately. There is no waiting state.

### Delete dialog — screen `505fa619379b4ca797208e8087ccf630`

Key `delete-family-dialog`. Title `Delete {name}?`.

Body, exact: `Hidden for 60 days, then permanently removed. Owner/co-owner can Recover from Manage families. Story tags stay if people are tagged elsewhere.`

Prompt `Type {name} to confirm` and a text field. `Confirm delete` stays disabled until the trimmed field equals `families.name`. It calls `soft-delete-family`. Success closes the dialog, returns to the hub, and drops the family from the active list. If that id was the session family, clear the remembered id. `Cancel` dismisses.

The detail block says “Owner only.” The dialog body says “Owner/co-owner can Recover.” Both strings are on their screens. Recover stays owner or co-owner. The delete button stays owner only.

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
- `apps/tell_me_a_story/lib/data/families_api.dart` — active `listMine`, plus hub and detail reads
- `apps/tell_me_a_story/lib/data/manage_families_api.dart` — the eight Edge calls
- `apps/tell_me_a_story/lib/data/invite_api.dart` — active-only `currentFamilyId`
- `apps/tell_me_a_story/lib/core/theme/album_header.dart` — menu row
- `apps/tell_me_a_story/lib/core/router/app_router.dart` — two routes
- `apps/tell_me_a_story/lib/features/family/manage_families_page.dart`
- `apps/tell_me_a_story/lib/features/family/manage_family_page.dart`
- `apps/tell_me_a_story/lib/features/family/start_family_dialog.dart`
- `apps/tell_me_a_story/lib/features/family/transfer_ownership_dialog.dart`
- `apps/tell_me_a_story/lib/features/family/delete_family_dialog.dart`
- Widget tests beside the existing `test/` suite: menu order, hub cards and recover visibility, start-family navigation, detail role gates, transfer requires both choices, delete confirm matches the name

Fakes in timeline, drafts, settings, and router tests that construct `FamiliesGateway` must keep compiling when `listMine` still returns `List<MemberFamily>`. Add the new gateway as an optional router argument, the same way `FamiliesGateway` is optional today.

## Tests

From `apps/tell_me_a_story`: `flutter test`.

From the repo root, with local Supabase already running: `supabase test db`. Do not reset the database.

`supabase/tests/manage_families.sql` covers:

- Backfill and `create_family` leave exactly one `owner`.
- A third `co_owner` write fails.
- Soft-deleted family is hidden from a plain member and from a stranger. Owner and co-owner can still select it.
- `recover_family` clears `deleted_at` inside 60 days and fails after.
- Soft-delete of a parent keeps each child’s `parent_family_id`. `purge_expired_families` nulls those children, then deletes the parent.
- `remove_member` deletes tree memberships and leaves `story_people`.
- `transfer_ownership` swaps immediately and rejects a target who is not a co-owner.
- Tagging a person whose email matches one profile inserts `member`. It does not demote an owner. An unknown email does not create `auth.users`.
- An authenticated client still cannot insert into `memberships`.
- The existing two-family leak tests still pass.

Paste both command outputs in the PR. PR title `feat(m10): manage families`. Branch `feat/m10-manage-families`. No push to main.

## Out

Tree-wide write RLS (M11). Branch-create UX (M11). Hollow-ring marks and the related-families list (M12). Replacing the R2 family menu with Manage as the session switch. A transfer accept step. Soft-delete by a co-owner or member. Client writes to `memberships`. Auth users created from name tags. Promotion to owner or co-owner by a tag. SMS. Storage-object purge. A `Primary` chip. An “Added …” date. The superseded hub. Stamping CLOSED.

## Bill smoke (do not claim)

Signed in on local `:3000`. Avatar menu shows Settings, Manage families, Logout. Hub lists the current family with an Owner chip. Start a family with a new name lands on that family’s empty timeline, and the R2 menu shows it. Detail rename persists. Add co-owner from a member, then transfer to that co-owner and become Member. The previous owner, still a co-owner on a second check, soft-deletes and sees the family under Recoverable. Recover puts it back on the active list. A plain member does not see Delete family or Transfer. A person tagged with an email that matches an existing profile becomes a member of that story’s family.
