# Tell Me a Story — Business Rules Spec (extracted from Supabase final state)

Source of truth: `supabase/migrations/*.sql` (final state after all 38 files), `supabase/tests/*.sql` (27 pgTAP), `supabase/functions/**` (Deno Edge). This is the behaviour the Serverpod rewrite must reproduce (or consciously change — see §6 "Gaps / as-is oddities").

## 0. Citation aliases

All paths under `supabase/migrations/`. Line numbers are the line in that file.

| Alias | File |
|---|---|
| ddl | 20260923000002_ddl.sql |
| ptrg | 20260923000003_profile_trigger.sql |
| rls | 20260923000004_rls.sql |
| stor | 20260923000005_storage.sql |
| av | 20261005000001_profile_avatar.sql |
| avcm | 20261005000002_avatars_select_comember.sql |
| mf | 20261007000002_manage_families.sql |
| irr | 20261010184643_invite_resend_revoke.sql |
| ftr | 20261010230000_family_tree_read.sql |
| trg | 20261010233000_story_photos_tree_read_guard.sql |
| os | 20261011150000_origin_stories.sql |
| osh | 20261011190823_origin_stories_hardening.sql |
| st | 20261011200000_start_a_timeline.sql |
| ff | 20261011210000_fit_and_finish.sql |
| pp | 20261012100000_people_profiles.sql |
| pin | 20261013150000_people_insert_null_user.sql |
| mpr | 20261016120000_member_person_rows.sql |
| dob | 20261016130000_dob_visibility_passed_away.sql |
| pas | 20261016140000_passed_away_guard_steward.sql |
| lnb | 20261016235900_linked_person_name_blank_guard.sql |
| dnd | 20261017000000_story_draft_nullable_date.sql |
| dao | 20261017000100_drafts_author_only.sql |
| sst | 20261018000000_story_people_same_tree.sql |
| dwp | 20261019000000_draft_write_policies.sql |
| perf | 20261022000000_advisors_perf.sql |
| cov | 20261028180000_family_landing_cover.sql |
| pe | 20261106150000_photo_editing.sql |

Edge: `fn/<name>` = `supabase/functions/<name>/index.ts`; `fn/_shared/manage.ts`, `fn/_shared/invite_email.ts`, `fn/validate-invite-token/invite_decision.ts`.

## 1. Core predicates (implement these once as Dart authorization helpers)

All predicates use the caller's user id (`uid`). `uid == null` ⇒ every predicate is false.

| Predicate | Definition | Cite |
|---|---|---|
| `isMember(f)` | Caller has a membership row in `f` (**does not** check `f.deleted_at`). | rls:5-16 |
| `isOwner(f)` / `isCoOwner(f)` | Membership in `f` with role `owner` / `co_owner` (no deleted check). | mf:71-101 |
| `isSteward(f)` | `isOwner(f) || isCoOwner(f)`. Used everywhere "owner or co-owner". | — |
| `isLiveMember(f)` | Membership in `f` AND `f.deleted_at is null`. | trg:5-24 |
| `treeRoot(f)` | Walk `parent_id` upward from `f` **through live families only**; start must be live; cycle-safe; cap depth 64. A soft-deleted parent splits the tree (child becomes its own root). Returns null if `f` is deleted. | ftr:9-27 |
| `isTreeReadable(f)` | Caller has a membership in some **live** family `m` with `treeRoot(m) == treeRoot(f)`. | ftr:29-45 |
| `isTreeMember(f)` | Same as `isTreeReadable` but additionally requires `f` itself live. | pp:52-73 |
| `sameFamilyTree(a,b)` | `isTreeMember(a) && isTreeMember(b) && treeRoot(a)==treeRoot(b)`. | sst:1-7 |
| `familyOrigin(f)` ("effective origin") | `f.origin_story_id` only if: `f` live, story `published`, story's family live, and `story.family_id == coalesce(f.parent_id, f.id)`. Else null. | osh:135-151 |
| `canContribute(f, s)` | (`isLiveMember(f)` OR caller is live member of a **live child** `c` of `f` with `familyOrigin(c)==s`) AND story `s` is `published` OR caller is author of `s`. | dao:152-179 |
| `canEditStory(s)` | Story's family is live AND ( (caller is author AND `isLiveMember(story.family)`) OR (story `published` AND caller is owner/co_owner of story.family) ). Missing story ⇒ false. | ff:136-173 |
| `listFamilyTree(f)` | All live families from `treeRoot(f)` downward (cycle-safe, depth<64), returning id, name, parent_id, branch_year, `familyOrigin(id)`; empty unless `isTreeReadable(f)`. | osh:190-219 |
| `familyTreeIds(f)` (used only by remove_member) | Walk to root then all descendants, **ignoring deleted_at**. | mf:223-255 |

Actor vocabulary used below:
- **anon**: no session.
- **stranger**: signed in, no membership anywhere in the tree.
- **member / co_owner / owner**: role in the resource's own family (live unless noted).
- **author**: the story's `author_id` (and still a live member).
- **tree reader**: live member of a *different* live family in the same tree (parent, child, sibling, grandparent…). Read-only, published-only.
- **origin contributor**: live member of a live child family whose effective origin is this story (can comment/perspective/photo on that one parent story).
- **linked self**: the user whose `user_id` is on the `people` row.

## 2. Authorization matrix (final state)

### 2.1 Family

| Op | Allowed | Cite |
|---|---|---|
| Read row | (member OR tree reader) AND (family live OR caller is owner/co_owner). Plain member of a soft-deleted family cannot see it; stranger cannot. | ftr:85-98 |
| List tree | `listFamilyTree` — any tree reader/member. Soft-deleted families omitted. | osh:190-219 |
| Create root | Any signed-in user. Caller becomes `owner`; caller gets a linked person row. | mpr:180-209 |
| Create branch ("start a new timeline") | Live member (any role) of the parent. See §3.2. | pp:409-547 |
| Rename | owner or co_owner. Name trimmed, non-blank. | mf:277-297; guard cov:65-74 |
| Set/clear cover | owner or co_owner. | cov:76-88 |
| Read cover object | `isMember(f)` (also works while family soft-deleted — test "soft-deleted member can still select the cover"). | cov:136-143 |
| Upload/replace/delete cover object | owner or co_owner. | cov:145-187 |
| Set origin story | owner or co_owner of the family, family live. See §3.3. | osh:72-123 |
| Clear origin directly | Nobody (field locked). Only cleared automatically when the story row is deleted (FK `on delete set null`). | cov:39-49; os:5-7 |
| Soft delete | owner only. | mf:440-456; guard cov:51-54 |
| Recover | owner or co_owner, within 60 days of `deleted_at`. | mf:458-482; guard cov:55-60 |
| Hard delete | No client path. System purge only. | mf:219 (policy dropped); cov:321-344 |
| Change `id`, `created_by`, `parent_id` | Nobody ("FORBIDDEN: field is locked"). | cov:33-37 |
| Any update anon | "FORBIDDEN: sign-in required". | cov:26-31 |

### 2.2 Membership

| Op | Allowed | Cite |
|---|---|---|
| Read memberships of family | `isMember(f)` (incl. soft-deleted). | rls:95-98 |
| Insert/update/delete directly | Nobody from client; only via server ops (create family, create branch, accept invite, role ops, remove member). Test "authenticated client cannot insert memberships". | rls:94 |
| Promote member→co_owner (`add_co_owner`) | owner **or co_owner**. Target must currently be role `member` in this family. Cap 2 co-owners. | mf:299-319, 108-135 |
| Demote co_owner→member (`remove_co_owner`) | owner only. Target must be `co_owner`. | mf:321-341 |
| Transfer ownership | owner only; target must be current co_owner; former owner becomes `co_owner` or `member` (caller's choice). Immediate. | mf:389-438 |
| Remove member | owner or co_owner of `f`; cannot remove self; cannot remove anyone who is owner of **any** family in the tree; removing someone who is co_owner anywhere in the tree requires caller be owner of `f`. Removes target from **every** family in the tree and unlinks their person rows in the tree; story tags stay. | pp:549-598 |
| Leave family (self-remove) | Not supported ("FORBIDDEN: cannot remove yourself"). | pp:562-564 |

### 2.3 Person (`people`)

| Op | Allowed | Cite |
|---|---|---|
| Read row | `isTreeMember(person.family)` — any live member of any live family in the tree. | pp:89-93 |
| Read profile (`person_profile`) | `isTreeMember`. Never returns `user_id`/`email`. DOB per §4.6. | dob:104-217 |
| Create | `isLiveMember(family)` and `user_id` must be null (linking only via invite accept / server). | pin:3-10 |
| Update unlinked row | Any tree member. Updatable columns: name, relationship, email, about, avatar_path, updated_at, passed_away. | pas:36-44; dob:67-77 |
| Update linked row | Only the linked self (USING tree member; WITH CHECK `user_id is null` or `user_id = uid`). Name still locked (follows profile). | pas:36-44; lnb:20-63 |
| Rename linked row | Nobody directly (incl. linked self and owner): "FORBIDDEN: linked_person_name_locked". Name follows `profiles.display_name`. | lnb:20-63 |
| Toggle passed_away, unlinked row | Any tree member (normal update). | pas:21-28 |
| Toggle passed_away, linked row | owner/co_owner of the person's family via `mark_passed_away` (also needs tree member; target ≠ self). Linked self can never flip own flag. | dob:248-290; pas:10-32 |
| Delete | `isMember(person.family)` (any role, linked or not, even family soft-deleted). | rls:117-120 |
| List unlinked (invite picker) | Tree member of live family. | dob:295-331 |
| Upload person avatar | Unlinked: any tree member. Linked: only linked self. Path `{person_id}/avatar.jpg`. No delete policy. | pp:229-274 |
| Read person avatar | Tree member. | pp:215-227 |

### 2.4 Place

| Op | Allowed | Cite |
|---|---|---|
| Read | Live member of place's family; OR tree reader if the place is attached to a **published** story of that family. | os:577-593 |
| Create / update | Live member. | trg:156-167 |
| Delete | `isMember` (any role). | rls:139-142 |

### 2.5 Story

| Op | Allowed | Cite |
|---|---|---|
| Read draft | Author only (and only while live member). Not owner, not co_owner. | dao:5-9 |
| Read published | Live member of the story's family; tree reader. Stranger/anon: no. | dao:5-9 |
| Create | Live member; `author_id = uid`. | trg:105-111 |
| Update content (title, body, dates, place) | `canEditStory`: author (draft or published) OR owner/co_owner if published. Child-family owner cannot edit parent's origin story. | ff:209-213 |
| Publish / unpublish (status, published_at) | Author only ("FORBIDDEN: field is locked" for non-author editor). | ff:178-204 |
| Change author_id / family_id / created_at | Nobody. | ff:185-189 |
| Delete | Author with `isMember(family)` (not live-checked). Owners cannot delete others' stories. | perf:30-34 |
| List origin dependents (families whose effective origin is story) | Live member of the story's family. | osh:153-170 |

### 2.6 story_people (tags)

| Op | Allowed | Cite |
|---|---|---|
| Read | Same as story visibility (author for draft; live member/tree reader for published). | dao:80-98 |
| Insert / update | `canEditStory(story)` AND `sameFamilyTree(person.family, story.family)` (person may be in parent/child timeline of the same tree; unrelated tree refused even if caller is in both). | sst:11-32 |
| Delete | `canEditStory(story)`. | ff:246-250 |
| Side effects | None. Tagging does NOT create memberships (auto-membership triggers dropped). | pp:276-277; mf test "auto-membership triggers are gone" |

### 2.7 Photo

| Op | Allowed | Cite |
|---|---|---|
| Read row & object | Live member if story published or caller is author; tree reader if published. | dao:57-78, 100-150 |
| Attach (insert) | `canContribute(family, story)` AND `uploader_id = uid` AND `photo.family_id == story.family_id`. Insert columns: id, family_id, story_id, uploader_id, storage_path, sort_order. Edit fields must be null/0. ≤20 per story. | os:345-358; pe:41-44, 60-66; osh:221-248 |
| Reorder (sort_order / hero) | `canContribute` AND (uploader OR `canEditStory`). Only `sort_order` is client-updatable. | ff:252-275; pe:31-34 |
| Delete | (uploader OR `canEditStory`) AND `canContribute`. Parent owner/co_owner can delete a child origin-contributor's photo on a published story; child-timeline owner cannot delete parent story photos. | dwp:10-14 |
| Save edit / reset edit | `canEditStory(story)` only (author; owner/co_owner if published). Uploader without edit rights refused. Tree reader refused. | pe:110-181 |
| Locked columns | Everything except `sort_order` (+ edit fields via save/reset only). | pe:53-105 |

### 2.8 Comment / Perspective (identical rules; new design `story_notes.kind`)

| Op | Allowed | Cite |
|---|---|---|
| Read | Live member if story published or caller is story author; tree reader if published. | dao:11-55 |
| Create | `canContribute(family, story)` AND `author_id = uid` AND note.family == story.family. Origin contributors may post on the origin story only. Non-author members cannot post on drafts; owner cannot post on someone else's draft. | os:253-266, 299-312 |
| Edit | Author AND `canContribute`. Only `body` (and updated_at) may change. | os:268-285, 314-331; osh:5-33 |
| Delete | Author AND `canContribute`. **No moderator delete** (owner cannot delete others' comments). | dwp:4-8 |
| Child contributor after origin moves/unpublished | Loses insert/edit/delete. | osh tests 492-585 |

### 2.9 Invite

| Op | Allowed | Cite |
|---|---|---|
| Read invites of family | `isMember(f)`. | rls:348-351 |
| Create | Any member (`isMember`, any role). Optional `person_id` must pass `assert_invite_person`. | fn/create-invite:123-131; dob:336-378 |
| Send email | Any member; invite must be pending, unexpired, have email. | fn/send-invite-email:38-79 |
| Validate token (preview) | Anyone incl. anon. | fn/validate-invite-token |
| Accept | Any signed-in user holding the token (not bound to invite email). | fn/accept-invite:112-209 |
| Resend (rotate token+expiry, email) | owner or co_owner. | irr:4-56 |
| Revoke | owner or co_owner. | irr:58-88 |
| Update/delete row directly | Nobody. | rls:347 |

### 2.10 Profile (user account)

| Op | Allowed | Cite |
|---|---|---|
| Read | Self, or any user sharing ≥1 family membership (any family, even soft-deleted; tree readers NOT included). Readable columns: id, display_name, email, created_at, updated_at, avatar_path, about. `birth_date`, `birth_precision`, `birth_visibility` never readable by others (only via `my_profile` for self, `person_profile` filtered). | perf:16-27; dob:51-65 |
| Create | Server only, on signup. | ptrg:3-25 |
| Update | Self only. `email` is synced from auth, not client-written. | perf:9-11; av:60-79 |
| Delete | Self (policy exists). | perf:13-14 |
| Avatar object read | Self or co-member. | avcm:6-22 |
| Avatar object write/delete | Self only, path `{uid}/avatar.jpg`. | av:32-58 |

### 2.11 Summary grid (✓ = allowed, P = only on published stories, D = also own drafts)

| Resource / op | anon | stranger | tree reader | origin contributor | member | co_owner | owner | author |
|---|---|---|---|---|---|---|---|---|
| family read | – | – | ✓(live) | ✓ (as tree reader) | ✓(live) | ✓(+deleted) | ✓(+deleted) | – |
| family rename/cover/origin | – | – | – | – | – | ✓ | ✓ | – |
| family soft-delete | – | – | – | – | – | – | ✓ | – |
| family recover | – | – | – | – | – | ✓ | ✓ | – |
| create branch from parent | – | – | – | – | ✓ | ✓ | ✓ | – |
| add co-owner | – | – | – | – | – | ✓ | ✓ | – |
| remove co-owner / transfer | – | – | – | – | – | – | ✓ | – |
| remove member | – | – | – | – | – | ✓ (not owners/co-owners) | ✓ (not owners) | – |
| person read | – | – | ✓ | ✓ | ✓ | ✓ | ✓ | – |
| person create | – | – | – | – | ✓ | ✓ | ✓ | – |
| person edit (unlinked) | – | – | ✓ | ✓ | ✓ | ✓ | ✓ | – |
| mark linked passed away | – | – | – | – | – | ✓ (own family) | ✓ (own family) | – |
| person delete | – | – | – | – | ✓ | ✓ | ✓ | – |
| place read | – | – | P | P | ✓ | ✓ | ✓ | – |
| place create/update/delete | – | – | – | – | ✓ | ✓ | ✓ | – |
| story read | – | – | P | P | P | P | P | D |
| story create | – | – | – | – | ✓ | ✓ | ✓ | – |
| story edit content | – | – | – | – | – | P | P | D |
| story publish/unpublish | – | – | – | – | – | – | – | ✓ |
| story delete | – | – | – | – | – | – | – | ✓ |
| tag people | – | – | – | – | – | P | P | D |
| photo attach | – | – | – | P (origin only) | P | P | P | D |
| photo delete others' | – | – | – | – | – | P | P | D |
| photo edit save/reset | – | – | – | – | – | P | P | D |
| comment/perspective create | – | – | – | P (origin only) | P | P | P | D |
| comment/perspective edit/delete | own only, subject to `canContribute` |
| invite create/send | – | – | – | – | ✓ | ✓ | ✓ | – |
| invite resend/revoke | – | – | – | – | – | ✓ | ✓ | – |

## 3. Workflows

### 3.1 Create root family — `create_family` (mpr:180-209), Edge `fn/create-root-family`
1. No session → `FORBIDDEN: sign-in required` (Edge returns 401 AUTH_REQUIRED "Sign-in required" before RPC: fn/_shared/manage.ts:36-58).
2. Name trimmed; blank → `VALIDATION: name is required` (Edge also pre-checks: "name is required").
3. Insert family (`created_by = uid`, no parent, `branch_year` null).
4. Insert membership `owner` for caller.
5. `ensure_member_person(family, uid, link_email=false)` (mpr:4-81): if caller already has a linked person anywhere in this live tree → nothing; else insert people row `name = coalesce(trim(display_name), trim(email), 'Member')`, `user_id = uid`, `email = profile email`, `created_by = uid`.
6. Response 201 `{family_id}`.

### 3.2 Create branch family ("start a new timeline") — `create_branch_family` (pp:409-547), Edge `fn/create-branch-family:46-105`
Edge pre-validation (before RPC, 400 VALIDATION): `parent_family_id` missing → "parent_family_id is required"; not uuid → "That id is not valid."; `origin_story_id` missing → "origin_story_id is required"; not uuid → "That id is not valid."; name blank → "name is required"; `branch_year` not a JSON integer → "attach year must be four digits"; `owner_user_id` not uuid → "That id is not valid."; `person_ids` not array of uuids → "That id is not valid.". Success 201 `{family_id}`.
RPC order (order matters; tests assert it):
1. Caller null or not `isLiveMember(parent)` → `FORBIDDEN: member only` (checked before anything else, incl. null parent and bad story).
2. Origin null, missing, not published, or not in parent family (sibling/grandparent/root-for-grandchild) → `NOT_FOUND: story` (checked before name).
3. Trimmed name blank → `VALIDATION: name is required`.
4. Year null or <1000 or >9999 → `VALIDATION: attach year must be four digits`.
5. `owner_user_id` null or not a member (any role) of parent → `VALIDATION: owner must be a member of the parent family`.
6. Any `person_id` not a people row of the parent family → `VALIDATION: members must come from the parent family`.
7. Parent ancestry depth (live ancestors) ≥ 63 → `VALIDATION: too many levels` (parent at depth 62 OK).
8. Insert family (name trimmed, parent, `created_by = caller`, branch_year), set origin (server-privileged), verify `familyOrigin(new) == origin` else `NOT_FOUND: story`.
9. Insert membership `owner` for `owner_user_id` (may be someone other than caller; a co-owner of the parent can be the new owner).
10. For each distinct picked person: if person has a linked account (`user_id`, email ignored) → insert membership `member` if none (no demotion: picking the owner keeps owner). People without an account get nothing. **No people rows are copied** into the branch (people live once per tree).
11. Caller is NOT auto-added (unless they are the owner or a picked linked person).
12. All-or-nothing: any error writes no family/membership/origin.

### 3.3 Set origin story — `set_family_origin` (osh:72-123)
1. No uid, family missing/soft-deleted, or caller not owner/co_owner of family → `FORBIDDEN` (bare, no detail) — FORBIDDEN is returned before any NOT_FOUND.
2. If family has a parent and parent missing/deleted → `VALIDATION: parent family is deleted`.
3. Story missing, not published, or `story.family != coalesce(parent_id, id)` (root: own family; branch: parent family) → `NOT_FOUND` (bare).
4. Set `origin_story_id`. Multiple children may share one origin.
Read side: effective origin hides (returns null) when the story is unpublished, the parent is soft-deleted, or the story is deleted (FK sets column null). Recovering the parent / republishing restores it. Clients cannot clear it while the story row exists, even when drafted or parent deleted.

### 3.4 Invites
**Create** (`fn/create-invite:87-156`):
1. POST only; bearer required → else 401 AUTH_REQUIRED "Sign-in required".
2. Body JSON; `family_id` required → "family_id is required". `email` optional (trimmed, empty → null = link-only invite). `person_id` optional.
3. Caller must be `isMember(family)` (any role) → else 403 FORBIDDEN "Not a family member".
4. If `person_id`: `assert_invite_person` (dob:336-378): caller tree member of live family else `NOT_FOUND:`; person missing or in another tree → `NOT_FOUND:` (same body for unknown and out-of-tree); linked → `VALIDATION: person is already linked`; passed_away → `VALIDATION: person has passed`.
5. Token: 64 hex chars (two random UUIDs without dashes). Status pending, `expires_at = now + 7 days` (ddl:116).
6. Insert failure → 400 VALIDATION "Could not create invite" (raw DB text hidden).
7. 201 `{invite_id, token, expires_at, invite_url}`; `invite_url = {INVITE_APP_ORIGIN}/timeline?invite={token}` (fn/_shared/supabase.ts:26-34).
Note: people with a pending unexpired invite are excluded from `list_unlinked_people` (dob:322-328).

**Send email** (`fn/send-invite-email`): invite not found → 404 NOT_FOUND "Invite not found"; not member → 403 "Not a family member"; status ≠ pending → 400 INVITE_INVALID "Invite is not pending"; expired → 400 INVITE_EXPIRED "Invite link expired"; no email → 400 VALIDATION "Invite has no email address to send to". Email: subject `Invite to {family}`, body "You're invited to join **{family}** on Tell Me a Story." + accept link + "This link expires in 7 days and can only be used once." (fn/_shared/invite_email.ts:25-31). No provider configured → 503 VALIDATION "Email is not configured"; provider failure → 502 VALIDATION "Could not send invite email".

**Validate / preview** (anon GET `?token=`; `invite_decision.ts:21-67`, always HTTP 200 body):
- Missing token → `{valid:false, code:"VALIDATION", message:"token is required"}`.
- Unknown token → INVITE_INVALID "Invite is not valid".
- Family soft-deleted → INVITE_INVALID (checked before status).
- status accepted → INVITE_ACCEPTED "Invite already used".
- status revoked/expired → INVITE_INVALID.
- `expires_at <= now` → INVITE_EXPIRED "Invite link expired".
- Valid → `{valid:true, family_id, family_name, inviter_name (trimmed display_name or null), status, expires_at}`. Invalid results null out family_id/family_name/inviter_name but keep status/expires_at.

**Accept** (`fn/accept-invite:112-209`):
1. Bearer required → 401 AUTH_REQUIRED. Body `token` required → "token is required". Unknown → 400 INVITE_INVALID "Invite is not valid".
2. If status accepted: same user as `accepted_by` → idempotent success returning existing `{family_id, membership_id}` (re-entry after magic link); if their membership is gone → 400 VALIDATION "Could not check membership". Different user → 400 INVITE_ACCEPTED "Invite already used".
3. status ≠ pending (revoked) → INVITE_INVALID. `expires_at <= now` → 400 INVITE_EXPIRED "Invite link expired".
4. Existing membership in family kept as-is (**no demotion** — owner opening own invite stays owner); else insert `member`. Failures → "Could not check membership" / "Could not create membership" (raw text hidden).
5. If `person_id`: `link_accepted_person` (mpr:103-146): no uid → `NOT_FOUND:` → Edge returns 401 AUTH_REQUIRED and does NOT mark accepted. If person already linked (to anyone) → silent no-op (accept still succeeds). If caller already linked to another person in same live tree → no-op (no second link). Else set `user_id = caller` (name then snaps to profile display_name; blank display name keeps existing name). Works on passed_away-flagged person too (test "accept-invite still accepts a pending invite on a flagged person").
6. Mark invite `accepted`, `accepted_by`, `accepted_at` (guarded `status = pending`).
7. Trigger (mpr:157-178): if invite had **no** person_id → `ensure_member_person(family, user, link_email=false)` → creates one linked person row unless user already linked in the tree.
8. Response `{family_id, membership_id}`. Client then lands on Family Landing.
Not checked at accept: family soft-deleted, invite email matching the signed-in email (see §6).

**Resend** (irr:4-56; `fn/resend-invite`): `invite_id` required; email provider configured else 503 before RPC. Lock row. Missing → `NOT_FOUND: invite not found`; not owner/co_owner → `FORBIDDEN: owner or co-owner only`; status ≠ pending → `INVITE_INVALID: invite is not pending` (accepted, revoked); no/blank email → `VALIDATION: invite has no email address` (link-only invites can't be resent). Rotate token (new 64-hex), `expires_at = now + 7 days`. Send email; if send fails token stays rotated (retry safe). Response `{sent:true, expires_at}`. Note: an expired-but-pending invite CAN be resent (revives it).

**Revoke** (irr:58-88): missing → NOT_FOUND; not steward → FORBIDDEN; accepted → `INVITE_INVALID: invite is not pending`; already revoked → no-op success; else status `revoked` (row & token kept; accept on that token then fails INVITE_INVALID).

UI: "Sent" date shown = `expires_at − 7 days` (irr:2 comment; new schema has `created_at`). Pending list shows "Expired"/"Pending" computed from `expires_at` (apps/tell_me_a_story/lib/features/family/manage_family_page.dart:1026-1027). Status value `expired` exists in the enum but is never written (only time-derived).

### 3.5 Soft delete / recover / purge
- Soft delete (mf:440-456): owner only; sets `deleted_at = now` if not already (repeat is no-op). Children keep their `parent_id` link but the tree splits at the deleted node (child becomes its own root for read purposes; grandparent members no longer see below; child members no longer see above).
- While deleted: plain members can't see the family; owner/co_owner can (to recover); members see 0 stories/people/photos; `isLiveMember` false so no writes; invites to it validate as INVITE_INVALID; cover still readable by members.
- Recover (mf:458-482): owner or co_owner; not deleted → `VALIDATION: family is not deleted`; `deleted_at < now − 60 days` → `FORBIDDEN: recovery window closed`; else clear `deleted_at`. Child origins reappear.
- Purge (cov:321-344): daily job (cron `15 3 * * *`, mf:645-658) for families with `deleted_at < now − 60 days`: delete cover objects first (fail closed — if storage delete fails the family row stays: "VALIDATION: cover purge failed" / "service role key is not configured…"), set children's `parent_id = null` (they become roots), hard-delete family (cascade: memberships, people, places, stories → photos/notes/tags, invites). Story-photo blobs are not cleaned by purge [as-is gap].

### 3.6 Transfer ownership (mf:389-438)
Owner only → `FORBIDDEN: owner only`. `former_becomes ∉ {co_owner, member}` → `VALIDATION: former role must be co_owner or member` (Edge pre-check message: "family_id, new_owner_user_id, and former_owner_becomes are required"). Target not a co_owner → `FORBIDDEN: target must be a co-owner`. Order of writes: demote caller to member, promote target to owner, then if requested promote caller to co_owner (keeps one-owner index and co-owner cap valid; target's co-owner slot is freed first). Effective immediately.

### 3.7 Photo edit versioning (pe:110-181)
- Row fields: `storage_path` (original, immutable), `edited_storage_path` (nullable), `edit_version` (≥0, starts 0).
- **Save** `(photo_id, expected_version, edited_path)`: lock row; missing photo or not `canEditStory` → `FORBIDDEN: photo edit denied`; `edit_version != expected` → `CONFLICT: photo edit version`; `edited_path` must equal exactly `{family_id}/{story_id}/{photo_id}.edited.{expected+1}.jpg` else `VALIDATION: invalid edited path`; set edited path, `edit_version = expected+1`; return `(new_version, previous_edited_path)` so the client deletes the superseded blob (first save returns null previous).
- **Reset** `(photo_id, expected_version)`: same auth/CAS; set `edited_storage_path = null`, `edit_version = expected+1`; return `(new_version, cleared_path)`.
- Client upload order: upload edited blob at the next-version key (allowed only if `canEditStory` and the photo exists for that family/story; draft visible to author only), then call save. Original blob never overwritten. Edited blob readable by whoever can read the photo.
- Invariants: `edit_version >= 0`; `edited_path != null ⇒ edit_version > 0`; edited path shape fixed; version can only advance by exactly 1; client cannot write edit fields directly.

### 3.8 Linked person / member person rows
- One linked person per user per tree: `ensure_member_person` skips if user already linked anywhere in the live tree; `link_accepted_person` same; DB unique `(family_id, user_id)` (mpr:153-155).
- Linked name sync (lnb:3-63): on link/insert the name becomes `trim(profile.display_name)` (blank/null → keep existing name); profile rename propagates to all linked rows across trees; direct rename of a linked row raises `FORBIDDEN: linked_person_name_locked`; unlinking (remove member sets `user_id = null`) reopens edits.
- `person_profile` overlay: if linked and account has about/avatar set, those win over the person row's (dob:204-213).

## 4. Invariants & validations (exact numbers)

### 4.1 Families
- `name` required, trimmed, non-blank — create, rename, branch (mf:53-55, 287-289; cov:65-68; pp:450-452).
- `branch_year`: DB check `null or 1..9999` (ftr:6-7); branch creation requires **1000–9999** (pp:454-458). Root families have null.
- `parent_id <> id` (st:4-6). Max ancestry depth 63 (branch refused at ≥63; tree walks cap at 64) (pp:503-505).
- Locked columns: `id`, `created_by`, `parent_id`; `origin_story_id` only via set-origin/branch-create or FK null-out (cov:33-49).
- `deleted_at` transitions: set ⇒ owner; clear ⇒ owner/co_owner; any other change (e.g. move timestamp) ⇒ `FORBIDDEN: owner only` (cov:51-63).
- Cover path: null or exactly `{family_id}/cover.(jpg|jpeg|png|webp)` (cov:7-13, 82-87); rejects URLs, other family prefix, traversal, other basenames. Bucket `family-covers`: private, **5 MiB (5242880 bytes)**, MIME `image/jpeg, image/png, image/webp`; objects must be single-folder `{family_id}/cover.{ext}` (cov:94-129).
- Recovery window **60 days**; purge daily at 03:15 (mf:475, 498, 650).

### 4.2 Memberships
- `(family_id, user_id)` unique (ddl:27).
- Exactly ≤1 `owner` per family (partial unique index, mf:18-20); every family has one (creation always inserts owner).
- ≤ **2** `co_owner` per family: `VALIDATION: co-owner cap is 2` (mf:108-135).
- Roles: `owner | co_owner | member`.

### 4.3 People
- `name` not null; `relationship` nullable (pp:13-14); `about` ≤ **500** chars (pp:29-31); `avatar_path` null or `{id}/avatar.jpg` (pp:32-34); `passed_away` boolean default false (dob:19-20).
- `user_id` unique per family (mf:14-16); client inserts must have `user_id = null` (pin:3-10); client can't update `user_id`, `family_id`, `created_by` (column grants dob:67-77).
- Linked-name lock (§3.8). passed_away guard (pas:10-32): linked self can't change own; linked row only by owner/co_owner of that family; error `FORBIDDEN:`.
- `mark_passed_away` (dob:248-290): order → no uid/null id `NOT_FOUND:`; missing / not tree member `NOT_FOUND:`; unlinked → `VALIDATION: person has not signed in`; self → `VALIDATION: cannot mark yourself`; not owner/co_owner of person's family (owner of another tree family is refused) → `FORBIDDEN:`. Sets flag (true/false, i.e., undo supported) and `updated_at`; does not change name/about.
- Person avatars bucket `person-avatars`: private, **2 MiB (2097152)**, `image/jpeg` only, path `{person_id}/avatar.jpg` (pp:206-213).
- Unlinked list excludes: linked, passed_away, people with pending unexpired invite, people in deleted families; ordered by name, id (dob:295-331).

### 4.4 Stories & dates
- `status ∈ {draft, published}`.
- Drafts may have null `date_start/date_end/date_precision` (dnd:1-3). Published requires all three: `VALIDATION: date required` (dnd:5-12, 31-34).
- Normalisation (dnd:20-29): null end ⇒ end = start; null precision with start present and start==end ⇒ `day`.
- Date shape (ff:60-86): year of start in **1000–9999**; `day`: start = end; `month`: start is 1st, end is last day of that month; `year`: Jan 1 – Dec 31 same year; `decade`: start year %10 = 0, Jan 1 of Y to Dec 31 of Y+9.
- `decade` cannot be inserted; on update a row may only stay decade with unchanged dates (legacy) — else `VALIDATION: year required` (dnd:36-49). With fresh start, decade is effectively unusable for new data [decide whether to keep enum value].
- Timeline ordering: `(family_id, date_start, date_precision[decade<year<month<day], created_at, id)` (ff:133-134; test "decade, year, month, and day sort by precision then created_at").
- Locked: `author_id`, `family_id`, `created_at`; `status` + `published_at` author-only (ff:178-204).
- Places: label, address, lat, lng (not null), mapbox_place_id, is_favorite (default false), last_used_at (ddl:42-52).

### 4.5 Photos
- ≤ **20** photos per story, serialized via story row lock: `VALIDATION: photo limit reached` (osh:221-248).
- `photo.family_id == story.family_id` on insert/update (os:352-357).
- Story-photos bucket: private, **50 MiB (52428800)**, MIME `image/jpeg, image/png, image/webp`; key `{family_id}/{story_id}/{photo_id}.(jpg|jpeg|png|webp)` exactly two folders, uuids validated without cast errors; edited `{photo_id}.edited.{n}.jpg` (stor:4-11; trg; pe:11-17).
- Locked: everything but `sort_order`; edit fields only via save/reset with +1 version (pe:53-105).
- Delete of a story-photo object whose story row no longer exists is allowed for family members (orphan cleanup) (dwp:120-125 / pe:445-450).

### 4.6 Profiles & DOB visibility
- Created on signup: `display_name = coalesce(nonblank metadata.display_name, email local-part)`, `email` from auth (ptrg:10-18). Email change in auth syncs to profile (av:60-79).
- `about` ≤ **500**; `birth_date`/`birth_precision` both null or both set; precision ≠ `decade` (pp:41-50); `birth_visibility ∈ {hidden, year, year_month, full}` default `hidden` (dob:9-17).
- Avatar `avatar_path` null or `{uid}/avatar.jpg` (av:8-13); bucket `avatars` private **2 MiB**, `image/jpeg` only (av:15-22).
- DOB shown to others (dob:163-195): rank visibility hidden0/year1/year_month2/full3, precision decade0/year1/month2/day3; `coarse = min`; 0 or no date ⇒ null; 1 ⇒ Jan 1 of year, precision `year`; 2 ⇒ 1st of month, `month`; 3 ⇒ full date, `day`. Self (own linked person) sees raw. Unlinked people have no DOB at all (people.birth_* dropped, dob:45-49). `my_profile` returns own raw birth date/precision/visibility; fails `NOT_FOUND:` without session.

### 4.7 Invites
- Token unique, 64 hex chars; expires **7 days** after create/resend (ddl:114-116; irr:33-35).
- `person_id` nullable FK, set null if person deleted (pp:279-280).
- Expiry comparison: expired when `expires_at <= now` (Edge).

### 4.8 Comments/perspectives
- `body` not null; only `body` + `updated_at` mutable (osh:5-33); `note.family_id == story.family_id`.

## 5. Error codes & messages

### 5.1 Envelope & mapping (fn/_shared/cors.ts:18-24; fn/_shared/manage.ts:10-24)
- Error body `{code, message}`. RPC exceptions `PREFIX: detail` map: `NOT_FOUND:`→404 NOT_FOUND, `FORBIDDEN:`→403 FORBIDDEN, `VALIDATION:`→400 VALIDATION, `INVITE_INVALID:`→400 INVITE_INVALID; message = detail after prefix (or full text if detail empty). Prefix must be at start. Anything else (incl. raw constraint text, `RATE_LIMITED:`) → 400 VALIDATION "Try again".
- Non-POST → 405 VALIDATION "Method not allowed"; bad JSON → 400 "Invalid JSON body"; no/invalid bearer → 401 AUTH_REQUIRED "Sign-in required".
- Client mirror: `apps/tell_me_a_story/lib/data/rpc_error.dart:4-19` (same four prefixes; null ⇒ UI shows generic copy).
- `CONFLICT: photo edit version` is raised by save/reset but not in the mapped prefix list [rewrite: add CONFLICT 409].

### 5.2 Full catalogue of server messages
| Code | Message | Source |
|---|---|---|
| AUTH_REQUIRED | Sign-in required | manage.ts:38,57; accept-invite:125,142,194 |
| FORBIDDEN | sign-in required | create_family, _require_family, families guard |
| FORBIDDEN | owner only | soft delete, remove_co_owner, transfer, deleted_at misuse |
| FORBIDDEN | owner or co-owner only | rename, add_co_owner, remove_member, recover, resend, revoke, cover, deleted_at clear |
| FORBIDDEN | cannot remove yourself / cannot remove an owner / cannot remove a co-owner | remove_member |
| FORBIDDEN | target must be a co-owner | transfer |
| FORBIDDEN | recovery window closed | recover |
| FORBIDDEN | field is locked | families/stories/photos/comments/perspectives guards |
| FORBIDDEN | linked_person_name_locked | people guard |
| FORBIDDEN | member only | create_branch_family |
| FORBIDDEN | photo edit denied | save/reset photo edit |
| FORBIDDEN | (bare `FORBIDDEN` / `FORBIDDEN:`) | set_family_origin, mark_passed_away, passed_away guard |
| FORBIDDEN | Not a family member | create-invite, send-invite-email |
| NOT_FOUND | family | _require_family (mf:259-273) |
| NOT_FOUND | story | create_branch_family |
| NOT_FOUND | invite not found / Invite not found | resend/revoke; send-invite-email |
| NOT_FOUND | (bare) | set_family_origin, person_profile, list_unlinked_people, assert_invite_person, mark_passed_away, my_profile, link_accepted_person |
| VALIDATION | name is required | create/rename/branch |
| VALIDATION | co-owner cap is 2 | trigger |
| VALIDATION | target must be a member / target must be a co-owner | add/remove co-owner |
| VALIDATION | former role must be co_owner or member | transfer |
| VALIDATION | family is not deleted | recover |
| VALIDATION | attach year must be four digits | branch |
| VALIDATION | owner must be a member of the parent family | branch |
| VALIDATION | members must come from the parent family | branch |
| VALIDATION | too many levels | branch |
| VALIDATION | parent family is deleted | set origin |
| VALIDATION | person is already linked / person has passed | assert_invite_person |
| VALIDATION | person has not signed in / cannot mark yourself | mark_passed_away |
| VALIDATION | date required / year required | stories date guard |
| VALIDATION | photo limit reached | photo cap |
| VALIDATION | invalid edited path | save photo edit |
| VALIDATION | cover_photo_path must be {family_id}/cover.(jpg\|jpeg\|png\|webp) | families guard |
| VALIDATION | invite has no email address | resend |
| VALIDATION | Invite has no email address to send to | send-invite-email |
| VALIDATION | family_id is required / invite_id is required / token is required / name is required / family_id and user_id are required / family_id and name are required / parent_family_id is required / origin_story_id is required / That id is not valid. / family_id, new_owner_user_id, and former_owner_becomes are required | Edge body checks |
| VALIDATION | Could not create invite / Could not resend invite / Could not check membership / Could not create membership / Try again | Edge (raw DB text hidden) |
| VALIDATION | Email is not configured (503) / Could not send invite email (502) | invite_email.ts |
| VALIDATION | cover purge failed / service role key is not configured for cover purge | purge (system) |
| INVITE_INVALID | invite is not pending | resend/revoke |
| INVITE_INVALID | Invite is not valid / Invite is not pending | accept, validate / send-invite-email |
| INVITE_ACCEPTED | Invite already used | accept, validate |
| INVITE_EXPIRED | Invite link expired | accept, validate, send-invite-email |
| CONFLICT | photo edit version | save/reset |

### 5.3 UI copy keyed off errors (Flutter)
- Invite landing, any invalid/expired/used/failed accept: "This invite link no longer works. Ask your family for a new one." (`lib/features/auth/invite_sign_in_page.dart:21-22`, used at 95,102,125). Before validating, a signed-in user attempts accept first so a re-opened accepted invite still lands in the family (lines 84-89).
- Invite landing other copy: "Join {family}", "Email me a sign-in link", "We sent a sign-in link to {email}. Tap it to join {family}.", "Please enter a full email address.", "Request failed" (same file 132-157, 302-335, 447-464). With 6-digit codes these become code-entry copy.
- Start timeline dialog: NOT_FOUND → "That story isn't available anymore. Pick another one."; FORBIDDEN → "You're not a member of {parentName} anymore."; internal message → "Try again"; else server message verbatim (`lib/features/family/start_timeline_dialog.dart:215-226`).
- Origin RPC errors: FORBIDDEN → "You do not have permission to do that."; NOT_FOUND → "Not found."; VALIDATION → detail (`lib/data/families_api.dart:148-166`).
- Generic fallbacks: "Couldn't create the family. Try again.", "Couldn't send invite. Try again." (or `InviteApiException.message`), "Couldn't save person. Try again.", "Couldn't save the family photo. Try again.", "Couldn't save your profile. Try again.", "Couldn't save draft. Try again.", "Couldn't publish story. Try again.", "Couldn't upload the photo. Check your connection and try again.", plain "Try again" (various `lib/features/**`). Many screens show `mapRpcError(error)` detail verbatim (e.g. "co-owner cap is 2", "person has passed").

## 6. Gaps / as-is oddities (decide explicitly in the rewrite)
1. Accept does not check the family is soft-deleted (validate does) — accept into a deleted family succeeds.
2. Invites are bearer tokens: not bound to the invited email.
3. Any member (not just stewards) can create and send invites; only stewards can resend/revoke.
4. `isMember` (not live) still gates: story delete by author, person delete, place delete, invite read/create, membership read, cover read, profile co-member visibility.
5. Person delete is allowed for any member, even for linked people.
6. No moderation: owners can't delete others' comments/perspectives/stories.
7. Purge does not delete story-photo/person-avatar blobs; only cover objects.
8. Resend revives an expired-but-pending invite; enum `expired` unused.
9. `remove_member` uses `familyTreeIds` which ignores soft-deletion (removes from deleted families in the tree too).
10. Branch owner gets no `ensure_member_person` call (relies on already being linked in the parent tree).
11. Profile `delete own` policy exists though account deletion flow is not defined.

## 7. Test port list (behaviour-level; given / when / then)

Families & roles
1. Given signed-in user, when creating family "  Morgans ", then family name "Morgans", caller is owner, exactly one owner, and caller has one linked person row.
2. Given blank/whitespace name, when creating family, then VALIDATION "name is required".
3. Given no session, when creating family, then AUTH_REQUIRED.
4. Given owner, when promoting two members to co_owner, then both succeed; when promoting a third, then VALIDATION "co-owner cap is 2".
5. Given co_owner, when promoting a member, then succeeds; given plain member, when promoting, then FORBIDDEN.
6. Given add_co_owner on a non-member or existing co_owner, then VALIDATION "target must be a member".
7. Given owner, when transferring to a member who is not co_owner, then FORBIDDEN "target must be a co-owner".
8. Given owner + co_owner, when transferring with former=member, then target is owner and caller member immediately; with former=co_owner, caller is co_owner.
9. Given co_owner, when calling transfer, then FORBIDDEN "owner only".
10. Given owner, when demoting a co_owner, then role member; given co_owner caller, then FORBIDDEN "owner only"; given target not co_owner, then VALIDATION "target must be a co-owner".
11. Given owner, when removing a member, then the member loses every membership in the tree, their linked person rows in the tree are unlinked, and their story tags remain.
12. Given co_owner, when removing the owner → FORBIDDEN "cannot remove an owner"; removing another co_owner → FORBIDDEN "cannot remove a co-owner"; removing self → FORBIDDEN "cannot remove yourself".
13. Given owner, when removing self, then FORBIDDEN "cannot remove yourself".
14. Given client, when inserting a membership directly, then refused.
15. Given owner/co_owner, when renaming with blank name → VALIDATION; plain member rename → FORBIDDEN.
16. Given co_owner, when soft-deleting → FORBIDDEN "owner only"; owner soft-delete → deleted_at set, child keeps parent link.
17. Given soft-deleted family, then plain member and stranger cannot read it; co_owner and owner can.
18. Given soft-deleted family, then its members read 0 stories (incl. their drafts), 0 people, 0 photos.
19. Given co_owner and family deleted 10 days ago, when recovering, then deleted_at cleared; given 61 days ago, then FORBIDDEN "recovery window closed"; given not deleted, then VALIDATION "family is not deleted".
20. Given family deleted 61 days ago with a child, when purge runs, then family hard-deleted and child's parent_id null.
21. Given purge and cover blob deletion fails, then the family row remains (fail closed).
22. Given client update of id/created_by/parent_id, then FORBIDDEN "field is locked".
Covers
23. Given owner or co_owner, when setting cover path `{id}/cover.jpg|jpeg|png|webp`, then saved; plain member → FORBIDDEN.
24. Given cover path that is a URL / other family prefix / traversal / non-cover basename, then VALIDATION; null accepted.
25. Given cover upload of svg, nested path, or >5 MiB, then rejected; member can read cover; non-member cannot; member of soft-deleted family can still read cover.
Tree reading
26. Given parent and child families, when parent member reads, then sees child's published story, its photos, comments, perspectives, story_people, place, and child people; does not see child's drafts.
27. Given parent member (tree reader), when inserting comment or photo on child story, then refused.
28. Given stranger or anon, then 0 people rows and cannot read child published story.
29. Given list_family_tree from parent member, then returns parent and child (with branch_year and effective origin); a family with no parent/children lists itself.
30. Given soft-deleted child, then absent from tree list for parent member and for its own owner; membership only in a soft-deleted family reads no tree.
31. Given grandparent→parent(deleted)→child, then child is its own root; grandparent member doesn't see child; child member doesn't see grandparent.
32. Given a parent cycle in data, then tree walk terminates and lists each id once.
33. Given branch_year 0 or 10000 at storage level, then rejected; null accepted (root).
Origin stories
34. Given child owner, when setting a published parent story as origin, then effective origin returns it; child co_owner can change it.
35. Given child plain member / non-member / no session, when setting origin, then FORBIDDEN (before NOT_FOUND for missing/draft/foreign story).
36. Given owner, when setting a draft, missing, or wrong-family story (child: must be parent's; root: must be own), then NOT_FOUND.
37. Given child whose parent is soft-deleted, when setting origin, then VALIDATION "parent family is deleted".
38. Given two children, when both set the same origin, then both effective origins are that story.
39. Given client direct update or clear of origin_story_id (incl. after drafting or while parent deleted), then FORBIDDEN "field is locked".
40. Given parent soft-deleted, then child's effective origin is null; after recovery it returns.
41. Given origin unpublished, then effective origin null; after republish restored.
42. Given origin story deleted, then origin_story_id becomes null.
43. Given child member, when commenting/adding perspective/attaching photo/uploading blob on the origin story, then allowed; on any other parent story, then refused.
44. Given tree member outside the child family or outsider, when contributing to origin story, then refused.
45. Given origin moved or unpublished, then child member can no longer comment, edit own comment/perspective/photo, or upload.
46. Given child member, when uploading under child-family path for the origin story, then refused.
47. Given child member, when updating/deleting a parent member's blob, then 0 rows; can delete own uploaded blob.
48. Given parent member, when listing origin dependents of a story, then sees the child; outsider sees none.
49. Given tree reader, then does not see a place used only by drafts; member does.
Branch creation
50. Given parent member, when creating branch " The Morgan-Reyes " with year 1987 and owner X, then name trimmed, parent set, branch_year stored, created_by caller, origin set, exactly one owner = X.
51. Given caller not picked and not owner, then caller is not a member of the branch; caller stays owner of parent.
52. Given picked persons, then linked ones become members, unlinked/email-only ones get nothing, no people rows are copied, picking the owner keeps owner role.
53. Given co_owner of parent, when creating with themselves as owner, then OK; new owner can change origin; starter (non-owner) cannot.
54. Given random/draft/sibling/grandparent/null origin, then NOT_FOUND "story" and no family written.
55. Given stranger, tree reader non-member, null session, or null parent, then FORBIDDEN "member only" (before story/name checks).
56. Given bad origin and blank name, then NOT_FOUND (story before name).
57. Given blank/whitespace name → VALIDATION "name is required"; year null/987/10000 → "attach year must be four digits".
58. Given owner not a parent member or null → VALIDATION "owner must be a member of the parent family".
59. Given a person from another family → VALIDATION "members must come from the parent family" and nothing written.
60. Given parent at depth 62, then create succeeds; one deeper → VALIDATION "too many levels" and nothing written.
61. Edge: missing JWT → 401; missing/bad ids → 400 without calling service; integer year passed through; non-prefixed DB error → "Try again"; success 201 `{family_id}`.
Stories, drafts & dates
62. Given member, when inserting a draft with null dates, then stored with null start/end/precision.
63. Given dateless draft, when publishing or inserting as published, then VALIDATION "date required"; with dates set, publish succeeds.
64. Given start with null end, then end = start and precision day.
65. Given day with differing end / month not on 1st / year not full / decade misaligned / year outside 1000–9999, then rejected.
66. Given insert with precision decade, then VALIDATION "year required"; legacy decade row may be updated without date change but not moved.
67. Given mixed precisions on same start, then ordering is decade, year, month, day, then created_at.
68. Given draft, then only author sees it and its comments/perspectives/photos/tags/blobs; other members, owner, co_owner, tree readers see none.
69. Given non-author member or owner, when commenting, adding perspective, photo or tag on someone's draft, then refused.
70. Given author publishes, then live members, owner, co_owner and tree readers see story and child rows.
71. Given author, then can edit own draft and published story; owner/co_owner can edit others' published stories (title, body, date) but not drafts; plain member cannot edit others'; non-member and no-session cannot; child-family owner cannot edit parent origin story; nobody can edit in soft-deleted family; missing story not editable.
72. Given non-author editor, when changing status or published_at, then FORBIDDEN "field is locked"; changing author_id/family_id/created_at always locked.
73. Given non-author, when updating story or moving it to another family, then refused.
74. Given cross-family reads, then user of family A sees none of family B stories, photos, people, places, invites, comments, perspectives, nor B's profiles when sharing no family.
Tags
75. Given editor, then can insert/update/delete tags; tagging a person from parent or child timeline in same tree succeeds.
76. Given caller member of two unrelated trees, when tagging/moving tag to person in the other tree, then refused; cross-family-in-other-tree link refused.
77. Given tagging a person with matching email or the owner, then no membership is created or changed.
Photos
78. Given story with 20 photos, when attaching 21st, then VALIDATION "photo limit reached".
79. Given photo/comment/perspective whose family_id ≠ story family, then refused.
80. Given storage key with second folder not a story, three folders, or non-uuid segments, then refused without errors; tree reader selecting such keys gets 0 rows.
81. Given photo, when changing id/story/family/uploader/storage_path, then FORBIDDEN "field is locked"; sort_order change allowed (uploader or editor).
82. Given parent owner/co_owner, then can delete a child contributor's photo row and blob on the published origin story; child-timeline owner deletes 0 parent photos.
83. Given story D reverted to draft with member B's comment/perspective/photo/blob on it, when B tries to delete them, then nothing changes (B can't contribute to someone else's draft); author A can delete A's own rows/blobs on D; on published P, B deletes own comment/photo and blob.
Photo editing
84. Given new photo, then edit_version 0 and edited path null; client cannot set edit fields on insert or update.
85. Given author save at expected 0 with path `.edited.1.jpg`, then version 1, previous null; second save returns previous edited path.
86. Given stale expected version, then CONFLICT "photo edit version".
87. Given null or non-edited/free-form path or wrong version number, then VALIDATION "invalid edited path".
88. Given reset, then version +1, edited path null, returns cleared path; original storage_path unchanged by save/reset.
89. Given owner (published) can save; co_owner can reset; draft author can save; member on draft, non-editor member, uploader without edit rights, tree reader → FORBIDDEN "photo edit denied"; missing photo → FORBIDDEN.
90. Given draft edit, then author reads original and edited blobs; other member cannot read edited blob; tree reader reads published original.
91. Given edited blob key for unknown photo, then upload denied; editor can upload original and edited keys.
92. Constraints: edit_version ≥ 0; edited path non-null requires version > 0; edited path shape exact; version cannot jump by more than 1.
Comments / perspectives
93. Given member B, then can create, edit, delete own comment/perspective; member A cannot edit or delete B's; stranger cannot create.
94. Given comment/perspective, when changing id, story, family, author, created_at, then FORBIDDEN "field is locked" (also for server/admin writes).
People & profiles
95. Given tree member (child or parent family), then reads the person row; outsider and null session do not.
96. Given person about > 500 chars → rejected; avatar path not `{id}/avatar.jpg` → rejected; relationship may be null.
97. Given tree member, then edits unlinked person; cannot edit linked person; linked user cannot rename own row; refused edits leave profile-derived name; clearing user_id reopens edits.
98. Given person_profile, then never returns user_id/email; missing id, outsider, null uid → NOT_FOUND; account birth/about/avatar win when set, about falls back to person; is_linked true/false; passed_away from person.
99. Given person avatar, then tree member uploads unlinked person's avatar; outsider cannot upload/read; other tree member cannot upload linked person's; linked user can.
100. Given DOB visibility hidden → null; year → Jan 1 + 'year'; year_month → 1st of month + 'month'; full → stored day; full visibility + month precision → month; year visibility + day precision → year; non-tree caller refused; self sees raw.
101. Given my_profile, then returns only caller's raw birth date/precision/visibility; null uid → NOT_FOUND.
102. Given profile birth precision decade → rejected; birth_visibility defaults hidden.
103. Given owner or co_owner of the person's family, when mark_passed_away true/false, then flag toggles, name/about unchanged; owner of another tree family, plain member, self, unlinked target, non-tree caller → refused with codes in §4.3.
104. Given linked user, when updating own passed_away directly, then FORBIDDEN.
105. Given tree member, then can flag/unflag an unlinked person directly; flagged people excluded from unlinked list and from invite targeting; return when cleared; linked person stays out of unlinked list after unmark.
106. Given profile display_name change, then all linked person rows (in any tree) take the new name; unlinked rows untouched; a later direct rename still raises.
107. Given null or whitespace display_name, then sync raises no error and linked names keep previous value; linking such a user keeps the existing person name; invite accept with null display name succeeds and new person uses email fallback.
108. Given linking an existing person, then its name becomes the profile name even if caller can't read that profile.
109. Given signup with metadata display_name, then profile display_name = it, email = auth email; without, display_name = email local-part; auth email change syncs profile email.
110. Given co-members, then each can read the other's profile and avatar; stranger cannot; co-member cannot write another's avatar.
111. Given own avatar path `{uid}/avatar.jpg`, then stored; any other path rejected.
Member person rows
112. Given accept with invite person already linked to someone, then no duplicate row and accept succeeds.
113. Given accept with unlinked invite person, then person linked to acceptor.
114. Given accept without invite person, then exactly one linked row created for acceptor (unless already linked in tree).
115. Given user member of parent and child, then exactly one linked person in the tree.
116. Given tree member, then reads passed_away of a person in another family of the tree; cannot read out-of-tree family people.
Invites
117. Given any member, when creating invite without person, then 201 with token, expires_at (+7d), invite_url; non-member → 403 "Not a family member".
118. Given invite with person: unknown and out-of-tree → identical NOT_FOUND body; linked → VALIDATION "person is already linked"; passed → VALIDATION "person has passed"; unlinked living tree person → OK.
119. Given insert DB error, then VALIDATION "Could not create invite" (no raw text).
120. Given list_unlinked_people, then covers the whole live tree, omits linked, passed, and people with an open unexpired invite; outsider/missing family/null uid → NOT_FOUND.
121. Given validate on live invite, then valid with family and inviter name (null if missing); unknown → INVITE_INVALID; soft-deleted family → INVITE_INVALID (200-shaped); accepted → INVITE_ACCEPTED; revoked → INVITE_INVALID; past expiry → INVITE_EXPIRED; invalid responses hide family/inviter.
122. Given accept of pending live invite, then membership `member` created, invite accepted with accepted_by/at; second accept by another user → INVITE_ACCEPTED "Invite already used"; same user again → success with same family/membership.
123. Given owner opens own family's invite, then accept succeeds and role stays owner.
124. Given expired pending invite, when accepting, then INVITE_EXPIRED; revoked → INVITE_INVALID.
125. Given person link fails for missing session, then 401 and invite not marked accepted.
126. Given membership lookup/insert failure, then VALIDATION with "Could not check membership"/"Could not create membership" (no raw text).
127. Given plain member, when resending or revoking, then FORBIDDEN "owner or co-owner only".
128. Given resend on accepted/revoked → INVITE_INVALID "invite is not pending"; on link-only invite → VALIDATION "invite has no email address".
129. Given co_owner resend, then token rotated, expires_at moved to now+7d, status pending, email sent; email not configured → 503 before rotation.
130. Given revoke, then row kept as revoked and accept with that token fails; revoke twice is no-op; revoke accepted → INVITE_INVALID.
131. Given send-invite-email on non-pending/expired/no-email invite, then INVITE_INVALID / INVITE_EXPIRED / VALIDATION respectively.
Error mapping
132. Given server error "PREFIX: detail" with prefix at start among NOT_FOUND/FORBIDDEN/VALIDATION/INVITE_INVALID, then code+status 404/403/400/400 and message=detail; prefix mid-message or unknown prefix → 400 VALIDATION "Try again".
