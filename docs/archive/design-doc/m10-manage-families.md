## M10 Manage families (Gilfoyle, 2026-10-07)
Architecture lock only. Not a stamp. Product/UX locked 2026-10-06 (PRD, Decisions, UXD). Supersedes Design Doc **Alternatives: “Admin role in v1 — rejected (****`member`**** only)”** for membership roles: Bill locked **Owner / Co-owner / Member**. That is not a generic admin role.
Stitch (project `12192342757314667328`): avatar menu `6b07fcdcaa204d028e79ab4494ca975a`, Manage hub `b429823c1f6a44aea297aaeef195bedd`, Start a family `78ba55e6adf1449685fe9dadcc1ccdfc`, Family detail `1c097b0e40cd4703a76fb8b1baf1ebc7`, Transfer `5a400d28acc24b9eb8f17da6ac3074e9`, Soft-delete confirm `505fa619379b4ca797208e8087ccf630`.
### Scope
- ~~Profile avatar menu owns Manage families: Settings · Manage families · Logout~~ **Superseded by M10 navigation (Bill 2026-10-10), below.** Avatar menu is **Settings · Logout** (M8 shape).
- R2 family menu stays the only control that switches **session current family** (`FamilySelection` process memory / `currentFamilyId()`). It now also carries **Start a family** and **Manage families** as actions (not session switches). No new table for session family.
- M10 is **root-family manage** only. Branch create is **M11**. Dial branch marks / related-families list are **M12**.
- Tree-wide **write** (member of any family in a tree can add/comment/attach on every family in that tree) ships with **M11**. M10 does not widen write RLS to the whole tree.
### Roles (amends §1 enums)
```sql
-- migration after latest on main; do not edit old enum migrations
alter type membership_role add value if not exists 'owner';
alter type membership_role add value if not exists 'co_owner';
-- existing 'member' stays
```
- Product chips: **Owner** = `owner`, **Co-owner** = `co_owner`, **Member** = `member`.
- Exactly **one** `owner` per family (enforced in Edge / security-definer writes, plus a unique partial index if Postgres allows on `(family_id) where role = 'owner'`).
- At most **two** `co_owner` rows per family (Edge check before insert/update).
- Co-owners have the **same powers as owner** except: only **`owner`** may soft-delete; only **`owner`** may transfer ownership; only **`owner`** may remove a `co_owner`. Owners cannot remove each other.
- Backfill: for each existing family, set `memberships.role = 'owner'` where `user_id = families.created_by` (create membership row if missing). All other memberships stay `member`.
### Soft-delete (amends `families`)
```sql
alter table public.families add column deleted_at timestamptz null;
create index families_deleted_at_idx on public.families (deleted_at) where deleted_at is not null;
```
- Soft-delete: **owner only**, type-to-confirm UI. Sets `deleted_at = now()`. Does not hard-delete rows or storage in M10.
- Active lists (`listMine`, timeline, R2 menu) exclude `deleted_at is not null`.
- Recoverable list (Manage hub): families where `deleted_at` is set, within **60 days**, and caller is `owner` or `co_owner` on that family. **Recover** clears `deleted_at` (restores memberships and links; they were never removed on soft-delete).
- After 60 days: scheduled **security-definer** purge (`pg_cron` or Supabase scheduled Edge calling SQL) hard-deletes the family row (cascade per existing FKs). No client purge button.
- Soft-delete of a family that already has children (`parent_family_id` pointing at it): **LOCKED (Bill 2026-10-07)** — allowed. While the parent has `deleted_at` set, tree walks / M12 marks treat those children as **roots** (skip the soft-deleted ancestor). Keep `parent_family_id` on the children during the 60-day window so **Recover** restores the parent link. On **permanent purge** after 60 days: set each direct child’s `parent_family_id` to null (they become true roots), then hard-delete the parent.
### RLS amendments
- `families` SELECT: member of that family **and** (`deleted_at is null` **or** caller is owner/co_owner of that family) — so recover list works; strangers and plain members do not see soft-deleted archives.
- `families` UPDATE (rename, clear `deleted_at` on recover): **owner or co_owner**. Soft-delete set of `deleted_at`: **owner only**.
- `families` hard DELETE: service role / purge job only. No client hard delete.
- `memberships` INSERT/UPDATE/DELETE stay **Edge / security definer only**. Client never writes roles.
### Root create
- Start a family: `parent_family_id` null, required `name`, `created_by = auth.uid()`, membership `role = owner` in the same security-definer flow (or Edge). Lands on that family’s empty timeline (set session family to new id).
- Anyone authenticated may create another root later.
### Edge / security-definer contracts (new; JWT required)
Exact paths may live under `/functions/v1/…`. Bodies use UUID strings.
<table header-row="true">
<tr>
<td>Call</td>
<td>Who</td>
<td>Behavior</td>
</tr>
<tr>
<td>`POST /create-root-family` `{ "name" }`</td>
<td>authenticated</td>
<td>Insert root family + owner membership; return `{ family_id }`</td>
</tr>
<tr>
<td>`POST /rename-family` `{ "family_id", "name" }`</td>
<td>owner or co_owner</td>
<td>Update `families.name`</td>
</tr>
<tr>
<td>`POST /add-co-owner` `{ "family_id", "user_id" }`</td>
<td>owner or co_owner</td>
<td>Promote/insert `co_owner` if under cap of 2; target must already be a member of this family</td>
</tr>
<tr>
<td>`POST /remove-co-owner` `{ "family_id", "user_id" }`</td>
<td>**owner only**</td>
<td>Demote that co_owner to `member`</td>
</tr>
<tr>
<td>`POST /remove-member` `{ "family_id", "user_id" }`</td>
<td>owner or co_owner</td>
<td>Drop membership for that user on **every family in the same branch tree** (walk `parent_family_id` to root, then all descendants). Do **not** delete `story_people` / people name tags. Cannot remove an `owner`. Cannot remove a `co_owner` unless caller is `owner`. Cannot remove self via this call.</td>
</tr>
<tr>
<td>`POST /transfer-ownership` `{ "family_id", "new_owner_user_id", "former_owner_becomes": "co_owner" | "member" }`</td>
<td>**owner only**</td>
<td>`new_owner_user_id` must be a current `co_owner`. Swap: new user → `owner`; former owner → chosen role. **Immediate** — no accept handshake (Stitch “will need to confirm” copy is non-binding; UXD/PRD have no accept step).</td>
</tr>
<tr>
<td>`POST /soft-delete-family` `{ "family_id" }`</td>
<td>**owner only**</td>
<td>Set `deleted_at = now()`</td>
</tr>
<tr>
<td>`POST /recover-family` `{ "family_id" }`</td>
<td>owner or co_owner</td>
<td>Clear `deleted_at` if within 60 days</td>
</tr>
</table>
Invite from Manage: still `create-invite` + `send-invite-email` / Link. Manage may invite to the **family on the detail screen**; R2 Invite stays. “Covers every family in the tree” means the Manage UI can open invite for any family in the tree you own/co-own — not a single token that inserts memberships on every family. Accept still upserts **`member`** on that invite’s `family_id`.
### Client routes (Flutter)
- `/manage-families` — hub (active + recoverable).
- `/manage-families/:familyId` — detail.
- Modals for Start / Transfer / Delete may be overlays on those routes; no new auth plane.
### Tests (mandatory)
- Role enum + backfill: one owner per family; co_owner cap 2.
- Soft-delete hidden from active lists; recover within 60 days; stranger cannot SELECT soft-deleted.
- remove-member drops all tree memberships; story_people unchanged.
- transfer-ownership immediate; rejects non-co_owner target.
- Two-family leak tests still pass for non-tree strangers.
> 🚫 FORBIDDEN: Client writes to `memberships`. Soft-delete by co_owner or member. Transfer accept/confirm step. Replacing R2 family menu with Manage for session switch. Shipping tree-wide write RLS in M10. Inventing SMS. Stamping Impl Spec §15 here.
### Named on a story → membership (LOCKED Bill 2026-10-07)
Amends `people`. PRD: you become a member if invited **or named on a story**.
```sql
alter table public.people add column user_id uuid null references public.profiles(id);
create unique index people_family_user_uidx
  on public.people (family_id, user_id)
  where user_id is not null;
```
- Resolve a person to an account by **`people.user_id`** when set, else by case-insensitive match of non-null `people.email` to `profiles.email`.
- Security-definer trigger (or Edge called from the same write path as tagging): on `story_people` INSERT, and when `people.user_id` / `people.email` changes while the person is already on any story in that family — if the person resolves to a user, **upsert** `memberships` for that story’s `family_id` with `role = member`. Do **not** demote `owner` / `co_owner`. Do **not** create an invite or account if no matching user exists.
- Membership is on the **story’s family only** in M10 (tree-wide write remains M11).
- Client may set `people.user_id` when the tagged person is a known profile; email-only tags still auto-member when the email matches an existing profile.
> 🚫 FORBIDDEN: Auto-creating auth users from a name tag. Promoting to owner/co_owner via tags. Client direct INSERT into `memberships` (trigger/Edge only).
### M10 navigation (LOCKED Bill 2026-10-10)
Architecture lock only. Not a stamp. Product re-stamped in PRD/Decisions 2026-10-10 (Jared). Stitch (project `12192342757314667328`): family dropdown `9dd2079031004573be8c92226a9c707f`, avatar menu `76b65f5e53684fd7a487148717af53a2`, Manage hub `622ceebb3b434b6c88143f888cca8ef9`. Supersedes avatar menu `6b07fcdcaa204d028e79ab4494ca975a` and hub `b429823c1f6a44aea297aaeef195bedd` for nav chrome. Ships in **M10 on PR #23**.
#### R2 family dropdown (order)
1. Live families you are a member of (any role), `deleted_at is null`, with a check on the session current family. Tap switches session family (unchanged).
2. Divider.
3. **+ Start a family** — every authenticated user. Opens the existing Start dialog over the current page; calls `create-root-family`; on success sets session family to the new id and goes to its timeline (unchanged contract).
4. **Manage families** — shown only if the caller is `owner` or `co_owner` on **at least one** family, **including soft-deleted families inside the 60-day window**. Members only: hidden. Opens `/manage-families`.
- The Manage gate is **not** tied to the session current family; switching to a family where you are `member` does not hide it.
#### Data for the gate (no schema / Edge change)
- Dropdown family list: existing active read (`deleted_at is null`).
- Manage gate + hub: separate read (or `includeDeleted` flag on the families API) of families where caller's `memberships.role in ('owner','co_owner')`, deleted or not. Existing M10 `families` SELECT already lets owner/co_owner read their own soft-deleted rows and keeps members/strangers out (PR #23 head `3018557`).
- Hub lists **only** families the caller owns or co-owns: active ones, then **Recoverable (60 days)** with Recover. After purge the row is gone; if it was the caller's last owned/co-owned family, Manage disappears from the dropdown.
#### Avatar menu
- **Settings · Logout** only (M8 shape). Manage families removed.
#### Header active state
- Add `AlbumHeaderPage.manageFamilies` (or equivalent value on the existing header). On `/manage-families` and `/manage-families/:familyId` the **family dropdown trigger** carries the same active ink underline/pill Timeline and Drafts use; Timeline and Drafts render plain. No new header nav item, no breadcrumbs, no new route.
#### Family monogram
- Dropdown and hub rows use a monogram circle: first letter of `families.name`, skipping a leading "The " (case-insensitive), uppercased, on the parchment circle. Client-computed. No family photo, no new column, no upload. ("Grandma Ruth's Side" → G.)
#### App-start landing
- Caller has ≥1 live family (any role): land on the session/default family timeline as today. Manage still shows if the gate passes.
- Caller has **no** live family **and** ≥1 soft-deleted family they own or co-own: land on `/manage-families` so Recover is first.
- Caller has neither: existing empty Start state.
- One client routing check at start. No backend change.
> 🚫 FORBIDDEN: Manage families in the avatar menu. Gating Manage on the session family's role. Showing Manage to `member`-only users. Listing families in the hub that the caller does not own or co-own. Soft-deleted families in the switch list. Underlining Timeline on Manage pages. A family photo/avatar column or upload. Any new table, column, Edge function, or package for this nav change.
### M10 Pending Invites: Resend and Cancel (LOCKED Bill 2026-10-10)
Architecture lock only. Not a stamp. Bill locked Mugatu's Pending Invites (Stitch `16384b751bcb46678b2483cb6b856d66`, UXD "M10 Pending Invites") on 2026-10-10, and it ships on PR #23. No new table, column, enum value, or package. Two new Edge functions, each backed by a security-definer RPC.
<table header-row="true">
<tr>
<td>Call</td>
<td>Who</td>
<td>Behavior</td>
</tr>
<tr>
<td>`POST /resend-invite` `{ "invite_id" }` → RPC `resend_invite(iid uuid)`</td>
<td>owner or co_owner of the invite's `family_id`</td>
<td>Allowed when `status` is `pending`, whether or not `expires_at` has passed. Nothing sets status `expired`; it returns `INVITE_INVALID`. Sets `status = 'pending'`, `expires_at = now() + 7 days`, and **rotates ****`token`**, so the old link stops working (Bill 2026-10-10). Then it sends the email through the same Resend path as `send-invite-email`; move that sender into `supabase/functions/_shared` rather than copying it. Returns `{ sent: true, expires_at }`. A row with `accepted` or `revoked` returns `INVITE_INVALID`. A null `email` returns `VALIDATION`. If Resend fails, it returns 502, the row stays rotated, and a retry is safe.</td>
</tr>
<tr>
<td>`POST /revoke-invite` `{ "invite_id" }` → RPC `revoke_invite(iid uuid)` (the UI calls it "Cancel invite")</td>
<td>owner or co_owner of the invite's `family_id`</td>
<td>Sets `status = 'revoked'`. Never deletes the row. An `accepted` row returns `INVITE_INVALID`. An already-`revoked` row does nothing and returns 200. `accept-invite` and `validate-invite-token` already reject `revoked`, so they don't change.</td>
</tr>
</table>
- Detail read: Family detail lists `invites` where `status = 'pending'` for that family through the existing member SELECT. The client paints Expired from `expires_at`. The section shows to the owner and co_owners only, and the RPCs enforce that rule too.
- Unchanged: any member can still create invites (`create-invite`, `send-invite-email`, link). Only resending and cancelling are limited to the owner and co_owners.
- Remove confirm (Bill 2026-10-10): the client asks for a confirm before `remove-member` on co-owner and member rows. It uses Mugatu's UXD text and the full-page blur modal. This is client only and doesn't change the contract.
#### Tests (mandatory)
- `throws_ok`: a plain member calls `resend_invite`. A plain member calls `revoke_invite`. `resend_invite` on an accepted invite. `resend_invite` on a revoked invite. `resend_invite` on a link-only invite with a null email.
- `lives_ok`: a co_owner resends, and the test asserts that `expires_at` moved later and `token` changed. A co_owner revokes, and accepting that token afterward fails with `INVITE_INVALID`.
- Already listed for this push: `remove-member` and `remove-co-owner` each have tests for every case they must refuse, plus `lives_ok` for the owner demoting a co_owner.
> 🚫 FORBIDDEN: Deleting invite rows. Client UPDATE or DELETE on `invites`. Resending without rotating the token. Resend or Cancel for plain members. Keeping a second copy of the Resend sender in `resend-invite`. New tables, columns, enum values, or packages for this.
### Open questions (Bill) — M10
1. **Named on a story → membership:** **LOCKED (Bill 2026-10-07)** — yes in M10 (see above).
2. **Soft-delete parent with children:** **LOCKED (Bill 2026-10-07)** — yes; children become roots (see Soft-delete above).
---
