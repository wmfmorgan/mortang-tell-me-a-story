# Data model review: handoff (2026-11-07)

Status: **RESOLVED 2026-11-07.** The user chose option B (docs plus server change), with a re-collapsed init migration and a banner-only P1 plan. See `docs/migration/data-model-review.md` for what was applied and verified. The commit hashes below are from before the branch was rewritten: `52306a4` → `f76ea21`, `f05a7d4` → `088ac68`, `fbb47d5` → `3519f88`, `56d83c6` → `d804f95`, `5cd9003` → `2f15f72`.

Original status: blocked before step 1. The approved plan follows this report in full ("Original approved plan").

## Blocker
The plan's precondition failed: `apps/server` already exists on `feat/serverpod-migration`, so Phase 1 has started. The plan says to stop and report in that case.

There are 15 commits after `d9729f7`; the branch head was `257fc54` when checked:
- `52306a4`: Serverpod 4.1.1 server and client scaffold.
- `f05a7d4`: schema models and init migration. There are 17 `*.spy.yaml` files plus `app_exception` in `apps/server/lib/src/models/`. `5cd9003` collapsed the migrations into `apps/server/migrations/20261107130018947-init`.
- `fbb47d5`: `apps/server/lib/src/db/constraints.dart`, which holds `constraintsSql` and applies it on boot. Its test is `apps/server/test/integration/constraints_test.dart`.
- `56d83c6`: constraint definitions are now **immutable by name**. Each one is created only if its name doesn't exist yet. To change one, add it under a new name and drop the old name in the same SQL.
- The other commits cover auth (email-code login), `AppException`, family authorization predicates, and fixes.

## Why the plan can't run as written
1. **Baseline is stale.** Steps 1–7 rewrite `schema-design.md` and the P1 plan's YAML and `constraintsSql`. The new text would no longer match the models, migration and constraints already committed in `apps/server`.
2. **The constraint rule conflicts.** The plan says "Nothing has been deployed, so constraints are edited in place." That contradicts `56d83c6`. Every replaced constraint would need a new name plus a drop of the old name: `families_branch_year_range`, `users_birth_midnight` → `users_birth_shape`, and the removal of `people_family_tree_fk`.
3. **The deliverable has changed.** Applying the review now means server changes: model YAML, a new Serverpod migration, `constraintsSql`, and `constraints_test.dart`. The plan was docs-only.

Also note the worktree `~/.herdr/worktrees/mortang-tell-me-a-story/worktree-silver-valley-593f` (branch `worktree/silver-valley-593f`). It sits at exactly `d9729f7`, before `apps/server` existed, and is probably another session's. It was left untouched. Don't use it as the base.

## Options (the user decides)
- **A. Re-baseline, docs only (recommended).** Base on `feat/serverpod-migration` HEAD. Rerun the review against the committed `apps/server` models and constraints. Write the revised migration docs and `data-model-review.md` as a proposal. Express constraint changes as new name + drop old name, and still check the SQL on a throwaway Postgres 17 (plan step 8). Don't touch server code.
- **B. Docs plus server change.** Do A, then add a Phase 1 follow-up that changes the models, generates a new migration, updates `constraintsSql` and extends `constraints_test.dart`. This crosses the plan's no-code line and needs explicit approval. Under AGENTS.md, server work follows TDD: commit a failing test first.
- **C. Hold** until Phase 1 lands, then apply the review as a schema-change PR.

## Notes for re-baselining (option A or B)
- Re-derive every line-number anchor. The plan's anchors refer to `d9729f7`.
- Diff `apps/server/lib/src/models/*.spy.yaml` and `constraints.dart` against `schema-design.md` §1 and §3.3 first. Phase 1 may already have diverged from the docs.
- The findings F1–F16 still need re-checking against the committed server code. Each one may already be fixed, partly fixed, or changed.

---

# Original approved plan (verbatim)

# Data model review: schema as source of truth, with analytical dimensions

## Context
The app is moving from Supabase to Serverpod 4.1.1 (branch `feat/serverpod-migration`). The target schema exists only as docs: `docs/migration/schema-design.md`, which the Phase 1 plan copies word for word. `apps/server` doesn't exist yet. The user asked for a full review of the data structures so the architecture is data-driven. In this review that means two things:
- the schema (Serverpod models plus DB constraints) is the single source of truth for relationships and integrity;
- time, place, people, family/branch and authorship are modeled as proper dimensions, so the timeline, filters and search become server queries over them.

**Worktree setup (do this first).** Run every command from the root of a fresh git worktree.
- The worktree's branch must be based on `feat/serverpod-migration` at or after commit `d9729f7` ("docs: Serverpod migration audit, roadmap, and phase 1-2 plans"), suggested name `docs/data-model-review`.
- Before editing, check that `docs/migration/schema-design.md`, `docs/migration/endpoint-contract.md`, `docs/migration/business-rules.md` and `docs/superpowers/plans/2026-11-06-serverpod-phase1-server-foundation.md` exist and that `apps/server` does **not** exist.
- If `apps/server` already exists, Phase 1 has started. Stop and report, because this plan only edits docs.
- Line numbers in this plan refer to `d9729f7`. Re-read each anchor before editing.
- Step 8 uses `/tmp/tmas-dm-review` and port 54329. If either is in use, use `/tmp/tmas-dm-review-2` and port 54330.

Choices the user confirmed:
- New domain structure is in scope: person-to-person kinship as parent and partner edges, birth and death dates on every Person, and tree-scoped places.
- The deliverable is revised migration docs, a review doc, and the revised constraints checked on a throwaway local Postgres.

No app or server code is written. The plan ends with one docs commit on the current branch, with no push.

## Findings the revision fixes
Evidence is file:line. `SD` = `docs/migration/schema-design.md`, `BR` = `docs/migration/business-rules.md`, `EC` = `docs/migration/endpoint-contract.md`, `P1` = `docs/superpowers/plans/2026-11-06-serverpod-phase1-server-foundation.md`.

| ID | Finding | Evidence | Decision |
|---|---|---|---|
| F1 | Person is tree-scoped in the product but family-owned in the schema. `familyId` Cascade means purging a person's home family deletes a person who is tagged in sibling branches. | m14-people-profiles.md:4 ("Scope is the tree"); SD:261; `add_person_modal.dart:226-253` tags people across branches | Person gets `treeId` (owning, Cascade from trees) and `homeFamilyId` (NOT NULL, Restrict). The purge reassigns the home family first (§Model, Purge). |
| F2 | Places are per family, so the same real place is duplicated per branch. Nothing enforces that a story's place is in the story's family. | SD:301,313-316; BR:125; `all_stories_logic.dart:259-300` | Places become tree-scoped. A composite FK ties `stories.placeId` to the story's tree. |
| F3 | Most cross-entity scoping is app-layer only: tags in the same tree, an invite's person in the same tree, the origin story in the same tree. | SD:632; SchemaGaps G5; `20261018000000` | `treeId` copies on stories, story_people and invites, each held equal by composite FKs. |
| F4 | `relationship` is a dead free-text column: it is never written, and it is read only on a path that never selects it. Kinship isn't modeled. | `people_api.dart:233,308`; `story_reader_page.dart:1368`; m14-people-profiles.md:6 | Drop `relationship`. Add `kinships` edges (`parentOf`, `partnerOf`). |
| F5 | Unlinked people have no life dates. The client model still carries birth and passing fields. | `people_api.dart:16-19`; SD:537 | Person gets birthDate/birthPrecision/deathDate/deathPrecision. While a person is linked, the account's birth wins on read. |
| F6 | The origin rule in the schema is wrong. The product lets stewards change the origin, and a root's origin is a story in its own family. The effective origin is derived and is not specified anywhere. | SD:208,633; `20261011190823:72-151`; impl-spec.md:1368-1369 | Fix the comments and §3.2. Add §3.5 "Effective origin". The DTO field becomes `effectiveOriginStoryId`. |
| F7 | Tagging a person auto-creates a membership in SD, but BR and M14 Lock 1 say it doesn't. | SD:640 vs BR:149; `20261012100000:276-277` | No side effect. SD follows BR. |
| F8 | Rules missing from SD §3.2: invite person validity, the unlinked-picker exclusion, tree-wide removeMember, the creator's person row, depth cap 63, branch year 1000–9999. | SchemaGaps G5–G9; BR:326-327 | Add them to §3.2. `branchYear` 1000–9999 becomes a DB CHECK. |
| F9 | The docs disagree on enums and names: `DatePrecision` has decade in EC:188; `MemberRole` vs `MembershipRole`; snake_case `app_user`/`tree_id`/`cover_key` in EC; `StoryDto.datePrecision` non-null against nullable drafts; `saveAccount` takes `String birthPrecision`. | EC:17,177,181,188,191,219,223,235,313,315 | EC is aligned to SD. |
| F10 | Blob keys and media authorization disagree. EC parses key prefixes and deletes blobs inline; SD uses an outbox and says "nobody parses keys". | EC:153-159,222-224,287,325; SD:805,819 | SD §4.2 key table is authoritative. Media reads look up the row that holds the key. Deletions go through `blob_deletions`. Transport stays `ByteData`, as EC and Phase 2 say. |
| F11 | Search and facets run in the client: it fetches every published story and filters in Dart. Decade chips are fixed at 1900–2020. People chips are family-only while tagging is tree-wide. | `search_api.dart:37-46,123-209`; `search_page.dart:113,136-149`; EC:339 | New `story.search` and `story.facets` endpoints with exact semantics (§Contract). |
| F12 | The invite "sent" date is back-computed as `expiresAt − 7d`. | `families_api.dart:290`; BR §3.4 | Add `invites.lastSentAt`. |
| F13 | DTOs carry derived `familyId` with no source: NoteDto, LiveEventDto, and client `Photo.familyId`. | EC:207; MigrationDocs #19 | NoteDto and PhotoDto carry a server-derived `familyId` (story join) that isn't stored. |
| F14 | `users.birthVisibility` has no value CHECK, unlike the other text enums. Birth dates aren't checked for precision alignment. | SD:691-695 | Add `users_birth_visibility_valid`. Replace `users_birth_midnight` with `users_birth_shape`. |
| F15 | `serverpod-notes.md` §4 has a stale model sketch. `docs/design-doc/data-model.md` is stale. The constraints location is `constraints.sql` in SD but a Dart const in P1. | serverpod-notes.md:103-146; SchemaGaps §4; P1:900 | Point the sketch at SD §1. Add a superseded banner to data-model.md. SD adopts the Dart const `constraintsSql` in `apps/server/lib/src/db/constraints.dart`. |
| F16 | Client-only issues with no schema change, recorded for Phase 4: three different story sort orders; `relatedMarks` puts null years first; non-null client `authorId`/`uploaderId` against SetNull FKs; `Place.familyId` read by no feature; `co_owner` literals at about 10 sites. | ClientDomain report §2, issues 10-11 | Listed in the review doc and in EC §3 (client change list). No schema change. |

Out of scope, so left as they are: the error-type disagreement (EC:16 vs P1:1182), realtime channel names, request-size limits, photo width/height columns.

## Model (authoritative content for SD §1 and §3.3)
Unchanged models: `AppUser` (YAML), `Tree`, `Membership`, `Photo`, `StoryNote`, `BlobDeletion`, and the enums `MembershipRole`, `StoryStatus`, `DatePrecision` (year, month, day; byIndex, append-only), `BirthVisibility`, `NoteKind`. Use the YAML below verbatim for the changed and new models.

### `family.spy.yaml` (comment and branch-year changes only)
- The `branchYear` comment becomes `### Attach year, 1000..9999 (CHECK families_branch_year_range). Null for roots.`
- The `originStoryId` comment becomes `### Origin story: published, in the parent family (branch) or this family (root). Set at branch creation, changeable by stewards (setOrigin). Same tree enforced by families_origin_tree_fk; the effective origin is derived (§3.5).`
- The `families_id_tree_uidx` comment becomes `### Target of the composite FKs (stories, people, invites, parent) in constraintsSql.`

### `person.spy.yaml`
```yaml
### A human in one tree, shared by every family (timeline) in the tree.
class: Person
table: people
fields:
  id: UuidValue?, defaultPersist=random_v7
  ### Owning tree. Deleted with the tree, or explicitly.
  treeId: UuidValue, relation(parent=trees, onDelete=Cascade)
  ### Family the person was added in; its stewards hold steward-only rights.
  ### Same tree enforced by people_home_family_tree_fk. The purge job reassigns it before deleting the family (§4.3).
  homeFamilyId: UuidValue, relation(parent=families, onDelete=Restrict)
  ### Linked account. Unique per tree; NULLs are distinct.
  userId: UuidValue?, relation(parent=serverpod_auth_core_user, onDelete=SetNull)
  ### For linked people this mirrors AppUser.displayName (app-layer sync, §3.2).
  name: String
  ### Lower-cased, trimmed, non-empty or null (CHECK).
  email: String?
  ### ≤ 500 chars (CHECK).
  about: String?
  ### Blob key, see §4. trees/{treeId}/people/{personId}/avatar/{blobId}.jpg
  avatarKey: String?
  ### UTC midnight aligned to precision (CHECK people_birth_shape). While linked, AppUser birth wins on read.
  birthDate: DateTime?
  birthPrecision: DatePrecision?
  ### UTC midnight aligned to precision (CHECK people_death_shape). Requires passedAway.
  deathDate: DateTime?
  deathPrecision: DatePrecision?
  passedAway: bool, default=false
  createdById: UuidValue?, relation(parent=serverpod_auth_core_user, onDelete=SetNull)
  createdAt: DateTime, default=now
  updatedAt: DateTime, default=now
indexes:
  people_tree_user_uidx:
    fields: treeId, userId
    unique: true
  ### Target of the composite FKs (story_people, invites, kinships).
  people_id_tree_uidx:
    fields: id, treeId
    unique: true
  ### Tree-wide person picker.
  people_tree_name_idx:
    fields: treeId, name
  ### listFamily(familyId) and the Restrict check on family delete.
  people_home_family_name_idx:
    fields: homeFamilyId, name
  people_user_idx:
    fields: userId
```

### `place.spy.yaml`
```yaml
### A real-world place, shared by every family in the tree.
class: Place
table: places
fields:
  id: UuidValue?, defaultPersist=random_v7
  treeId: UuidValue, relation(parent=trees, onDelete=Cascade)
  label: String
  address: String
  lat: double
  lng: double
  mapboxPlaceId: String?
  isFavorite: bool, default=false
  lastUsedAt: DateTime?
  createdAt: DateTime, default=now
indexes:
  ### Target of stories_place_tree_fk.
  places_id_tree_uidx:
    fields: id, treeId
    unique: true
  places_tree_label_idx:
    fields: treeId, label
  ### One row per Mapbox place per tree; create returns the existing row.
  places_tree_mapbox_uidx:
    fields: treeId, mapboxPlaceId
    unique: true
  places_tree_last_used_idx:
    fields: treeId, lastUsedAt
```

### `story.spy.yaml` (additions)
- Add after `familyId`: `### Copy of families.treeId (immutable), kept equal by stories_family_tree_fk.` followed by `treeId: UuidValue`.
- The `placeId` comment becomes `### Same tree enforced by stories_place_tree_fk (SET NULL placeId only).`
- Add the index `stories_id_tree_uidx: fields: id, treeId, unique: true`, with the comment `### Target of story_people_story_tree_fk and families_origin_tree_fk.`

### `story_person.spy.yaml` (addition)
Add `### Copy of the story's treeId; story_people_story_tree_fk and story_people_person_tree_fk make tags same-tree.` followed by `treeId: UuidValue` after `personId`.

### `invite.spy.yaml` (changes)
- Add after `familyId`: `### Copy of families.treeId, kept equal by invites_family_tree_fk; invites_person_tree_fk keeps personId in the tree.` followed by `treeId: UuidValue`.
- Add before `expiresAt`: `### Set on create and on every resend.` followed by `lastSentAt: DateTime, default=now`.
- In the header comment, replace `InviteSummary DTO (id, email, personId, status, expiresAt, createdAt)` with `PendingInviteDto (id, email, personId, sentAt, expiresAt, createdAt)`.

### New `kinship_kind.spy.yaml`
```yaml
### parentOf: fromPerson is a parent of toPerson. partnerOf: symmetric, stored with fromPersonId < toPersonId.
### Siblings, grandparents and cousins are derived, never stored.
enum: KinshipKind
serialized: byName
values:
  - parentOf
  - partnerOf
```

### New `kinship.spy.yaml`
```yaml
### Person-to-person edge inside one tree. Replaces the dropped free-text people.relationship.
class: Kinship
table: kinships
fields:
  id: UuidValue?, defaultPersist=random_v7
  treeId: UuidValue, relation(parent=trees, onDelete=Cascade)
  kind: KinshipKind
  fromPersonId: UuidValue, relation(parent=people, onDelete=Cascade)
  toPersonId: UuidValue, relation(parent=people, onDelete=Cascade)
  createdById: UuidValue?, relation(parent=serverpod_auth_core_user, onDelete=SetNull)
  createdAt: DateTime, default=now
indexes:
  kinships_from_to_kind_uidx:
    fields: fromPersonId, toPersonId, kind
    unique: true
  kinships_to_idx:
    fields: toPersonId
  kinships_tree_idx:
    fields: treeId
```

### `constraintsSql` changes (SD §3.3, the full block is rewritten)
Keep every existing entry except the ones replaced below. Add entries in table order. All column names are quoted camelCase. DatePrecision is stored as 0 year, 1 month, 2 day.
- **Replace** `families_branch_year_range` with `CHECK ("branchYear" IS NULL OR "branchYear" BETWEEN 1000 AND 9999)`.
- **Add** `families_origin_tree_fk`: `FOREIGN KEY ("originStoryId", "treeId") REFERENCES stories ("id", "treeId") ON DELETE SET NULL ("originStoryId")`.
- **Remove** `people_family_tree_fk`. **Add** `people_home_family_tree_fk`: `FOREIGN KEY ("homeFamilyId", "treeId") REFERENCES families ("id", "treeId") ON DELETE RESTRICT`.
- **Add** to people (the date shape pattern is the same for both columns; `<D>`/`<P>` = `birthDate`/`birthPrecision` or `deathDate`/`deathPrecision`):
  - `people_birth_pair`: `CHECK (("birthDate" IS NULL) = ("birthPrecision" IS NULL))`
  - `people_death_pair`: same pattern for death.
  - `people_birth_shape` / `people_death_shape`: `CHECK ("<D>" IS NULL OR ("<D>" = date_trunc('day', "<D>") AND extract(year FROM "<D>") BETWEEN 1000 AND 9999 AND ("<P>" = 2 OR ("<P>" = 1 AND "<D>" = date_trunc('month', "<D>")) OR ("<P>" = 0 AND "<D>" = date_trunc('year', "<D>")))))`
  - `people_death_needs_passed_away`: `CHECK ("deathDate" IS NULL OR "passedAway")`
  - `people_death_after_birth`: `CHECK ("deathDate" IS NULL OR "birthDate" IS NULL OR extract(year FROM "deathDate") >= extract(year FROM "birthDate"))`. Years only, so a coarse birth can't reject a finer death date in the same year.
- **Replace** `users_birth_midnight` with `users_birth_shape`: the same shape as `people_birth_shape`, on `users`.
- **Add** `users_birth_visibility_valid`: `CHECK ("birthVisibility" IN ('hidden', 'year', 'yearMonth', 'full'))`.
- **Add** to stories:
  - `stories_family_tree_fk`: `FOREIGN KEY ("familyId", "treeId") REFERENCES families ("id", "treeId") ON DELETE CASCADE`
  - `stories_place_tree_fk`: `FOREIGN KEY ("placeId", "treeId") REFERENCES places ("id", "treeId") ON DELETE SET NULL ("placeId")`
- **Add** to story_people:
  - `story_people_story_tree_fk`: `FOREIGN KEY ("storyId", "treeId") REFERENCES stories ("id", "treeId") ON DELETE CASCADE`
  - `story_people_person_tree_fk`: `FOREIGN KEY ("personId", "treeId") REFERENCES people ("id", "treeId") ON DELETE CASCADE`
- **Add** to invites:
  - `invites_family_tree_fk`: `FOREIGN KEY ("familyId", "treeId") REFERENCES families ("id", "treeId") ON DELETE CASCADE`
  - `invites_person_tree_fk`: `FOREIGN KEY ("personId", "treeId") REFERENCES people ("id", "treeId") ON DELETE SET NULL ("personId")`
- **Add** to kinships:
  - `kinships_from_tree_fk`: `FOREIGN KEY ("fromPersonId", "treeId") REFERENCES people ("id", "treeId") ON DELETE CASCADE`
  - `kinships_to_tree_fk`: the same for `toPersonId`.
  - `kinships_not_self`: `CHECK ("fromPersonId" <> "toPersonId")`
  - `kinships_kind_valid`: `CHECK ("kind" IN ('parentOf', 'partnerOf'))`
  - `kinships_partner_canonical`: `CHECK ("kind" <> 'partnerOf' OR "fromPersonId" < "toPersonId")`
- Nothing has been deployed, so constraints are edited in place with no rename/drop dance. Keep the existing SD caveat for after first deploy.

### App-layer rules (SD §3.2; replace the table's affected rows, add the rest)
- **Story tags:** same tree is now enforced by the DB (move this row to §3.1). Tagging has **no** membership side effect; delete the "auto-adds their account as member" row.
- **Origin (setOrigin, steward of the family):**
  - the family is live, and the parent (if any) is live, else `VALIDATION: parent family is deleted`;
  - the story is published and `story.familyId == coalesce(family.parentId, family.id)`, else `NOT_FOUND`;
  - `parentId`, `treeId` and `createdById` are immutable; `originStoryId` changes only through setOrigin or branch creation.
- **Invite create:** if `personId` is set, the person must be in the tree (DB), unlinked and not passedAway, else `VALIDATION`. Create and resend set `lastSentAt = now` and `expiresAt = now + 7 days`.
- **Unlinked picker (`people.listUnlinked`):** people in the tree with `userId` null and `passedAway` false, excluding any person with a pending invite (`acceptedAt IS NULL AND revokedAt IS NULL AND expiresAt > now()`).
- **removeMember:** applies to every family with the same `treeId`. It deletes those memberships and unlinks the user's person in the tree. It is refused if the target owns any family in the tree.
- **createRoot:** in one transaction, insert the tree, the family, the owner membership, and a linked person (`homeFamilyId` = new family, name = display name, else email local-part, else `Member`).
- **createBranch:**
  - the caller and the new owner are live members of the parent;
  - depth ≤ 63 (walk `parentId`, refuse at ≥ 63);
  - `branchYear` 1000–9999 (DB);
  - each picked person has `homeFamilyId == parentId`. Picked linked people's accounts become members; no person rows are copied.
- **Kinship add (`people.addKinship`):** the caller is a live member of a live family in the tree.
  - Lock the `trees` row `forUpdate`.
  - For `partnerOf`, store the smaller id as `fromPersonId`.
  - For `parentOf`, reject with `VALIDATION: kinship would create a cycle` when `toPersonId` is `fromPersonId` or an ancestor of it (recursive walk over `parentOf` edges in the tree).
  - A duplicate returns the existing edge.
- **Kinship remove:** same caller rule. No cycle check is needed.
- **Life dates:**
  - The server normalizes input to precision-aligned UTC midnight.
  - Writing birth fields on a linked person is refused with `VALIDATION: birth date comes from the account`.
  - Death fields: same rights as passedAway (linked person: steward of the home family only, never self).
  - Setting `passedAway = false` also clears the death fields.
- **Places:** read = any live member of a live family in the tree. Create/markUsed/setFavorite = live member of a live family in the tree. Create with an existing `(treeId, mapboxPlaceId)` returns that row. No delete endpoint exists, which matches the client.
- **Person delete:** a member of the home family (unchanged, BR §6 #5).

### Effective origin (new SD §3.5)
`effectiveOrigin(f)` = `f.originStoryId` when all of these hold, else null:
- `f` is live;
- the story is published;
- the story's family is live;
- `story.familyId == coalesce(f.parentId, f.id)`.

`TreeFamilyDto.effectiveOriginStoryId` carries it. A child of a soft-deleted parent stays in the tree (`treeId`), and its effective origin is null while the parent is deleted (roadmap open decision 3).

### Purge (SD §4.3, step list replaced)
For each family with `deletedAt < now() - 60 days`, in one transaction:
1. If it is the **last family in its tree**:
   - write every photo key (original and edited) for its stories, its `coverKey`, and every `people.avatarKey` in the tree to `blob_deletions`;
   - delete the tree's `people` (this cascades kinships, story_people and the invite personId);
   - delete the family (this cascades stories, photos, notes, memberships and invites);
   - delete the `trees` row (this cascades places).
2. Otherwise:
   - pick the successor family: the same tree, not this family, ordered by (`deletedAt IS NOT NULL`, `createdAt`, `id`);
   - set `homeFamilyId = successor` on people whose home is this family;
   - write the photo keys and `coverKey` to `blob_deletions`;
   - delete the family. The FKs null children's `parentId` and other families' `originStoryId`.

### Dimensions (new SD §0.5)
Include a mermaid `erDiagram` of every table and its FK cardinalities from the YAML above, then this table:

| Dimension | Key / scope | Attributes | Join path |
|---|---|---|---|
| Family / branch | `families.id`, grouped by `treeId` | name, parentId, branchYear, effective origin, deletedAt | stories.familyId; tenancy = family, reading = tree |
| Time | derived from the story | `dateStart`, `dateEnd` (stored, server-derived from start + precision, for range overlap), `datePrecision`; decade = `floor(year/10)*10`, computed in queries, never stored; documented time = `publishedAt`; life dates on people; `branchYear` = attach year | stories columns |
| Place | `places.id`, tree-scoped | label, address, lat/lng, mapboxPlaceId | stories.placeId (same tree by FK) |
| People | `people.id`, tree-scoped | name, life dates, passedAway, linked user | story_people (tags), kinships (parentOf/partnerOf; siblings share a parent) |
| Authorship | `serverpod_auth_core_user.id` | AppUser displayName/avatar | the author's person = `people` where `userId = authorId AND treeId = story.treeId` |

The facts are `stories` (one row per story), `photos` and `story_notes`. Named orders:
- `timelineOrder`: dateStart, datePrecision, createdAt, id (ascending);
- `allStoriesOrder`: dateStart desc, publishedAt desc, id;
- `latestOrder`: publishedAt desc, id desc.

## Contract changes (EC)
- §0 "Schema" row (line 17): rewrite it to point to `docs/migration/schema-design.md` and to state that people carry life dates and that the account birth wins while a person is linked. Email is read from `serverpod_auth_idp_email_account.email`.
- §2.0 blob keys (153-159): replace the list with "Keys per schema-design.md §4.2". Replace "parses the prefix" with "finds the row holding the key (photos.originalKey/editedKey, families.coverKey, people.avatarKey, users.avatarKey) and checks tree/family access". Replace inline blob deletes (222-224, 278, 287) with "old keys go to `blob_deletions` in the same transaction". Change the cover content type comment (222) to jpeg/png/webp.
- §2.1 DTOs:
  - `MemberRole` → `MembershipRole` everywhere (177, 235, and any others found by grep).
  - `DatePrecision # year, month, day (byIndex, append-only)`.
  - `StoryDto.datePrecision: DatePrecision?`.
  - `TreeFamilyDto`: `originStoryId?` → `effectiveOriginStoryId?`.
  - `PendingInviteDto # id, email?, personId?, sentAt, expiresAt, createdAt`.
  - `PersonDto # id, treeId, homeFamilyId, name, email?, about?, avatarKey?, userId?, passedAway, birthDate?, birthPrecision?, deathDate?, deathPrecision?`, with `relationship` removed. The birth fields come from the linked AppUser (coarsened) when linked, else from the person row.
  - `PersonProfileDto`: `familyId` → `homeFamilyId`; add `deathDate?, deathPrecision?`.
  - `PersonWriteDto`: add `birthDate?, birthPrecision?, writeBirth, deathDate?, deathPrecision?, writeDeath`.
  - `PlaceDto`: `familyId` → `treeId`.
  - `PhotoDto`: add `familyId` (derived, not stored).
  - Change line 207 to say that `familyId` on NoteDto, PhotoDto and LiveEventDto is derived from the story and not stored.
  - Add `KinshipDto # id, kind: KinshipKind, fromPersonId, toPersonId`, `enum: KinshipKind # parentOf, partnerOf`, `StorySearchDto`, `SearchSort`, `StoryFacetsDto`, `DecadeFacetDto # decade: int, storyCount: int`, `PersonFacetDto # personId, name, storyCount: int`, `PlaceFacetDto # placeId, label, storyCount: int`.
- §2.2 signatures:
  - `PeopleEndpoint`: add `listKinships(Session s, UuidValue familyId)` (whole tree; tree reader), `addKinship(Session s, UuidValue familyId, KinshipKind kind, UuidValue fromPersonId, UuidValue toPersonId) → KinshipDto`, and `removeKinship(Session s, UuidValue kinshipId)`. Comment: "no client UI yet; a UX spec must precede a gateway method".
  - `PlaceEndpoint` keeps its `familyId` params, with the comment "resolves the family's tree; results are tree-wide".
  - `ProfileEndpoint.me` comment: "AppUser created in onAfterAuthUserCreated; ensureAppUser fallback".
  - `saveAccount`: `DatePrecision? birthPrecision`.
  - `StoryEndpoint`: add `Future<List<StoryDto>> search(Session s, StorySearchDto q)` and `Future<StoryFacetsDto> facets(Session s, UuidValue familyId)`.
- Line 339: replace "There is no SearchEndpoint…" with the search semantics:
  - `StorySearchDto{familyId, text = '', personIds: List<UuidValue>, placeId?, rangeStart?, rangeEnd?, decades: List<int>, sort: SearchSort}`, with `SearchSort { relevant, chronological, recentlyAdded }`.
  - Scope: published stories with `familyId` = the request's family.
  - personIds use AND semantics. `placeId` matches exactly. When `decades` is non-empty, it filters on `floor(year(dateStart)/10)*10 ∈ decades`. Otherwise, if both range bounds are set, it filters on overlap (`dateStart <= rangeEnd AND rangeStart <= dateEnd`).
  - Text: a case-insensitive substring match (`ILIKE` with `%`/`_`/`\` escaped) over title, body, place label, place address, tagged person names, the start year as text, and the decade label `'<decade>s'` for **any** decade (the 1900–2020 bound is dropped).
  - Relevance tiers: 3 = title; 2 = a person name or place label/address; 1 = body, year or decade.
  - Sorts:
    - `relevant`: tier desc, then reverse `timelineOrder`;
    - `chronological`: reverse `timelineOrder`;
    - `recentlyAdded`: `publishedAt` desc nulls last, then reverse `timelineOrder`.
  - `facets(familyId)` covers the same story scope. Decades ascend; people are the people tagged on those stories (any home family), ordered by name; places are ordered by label. This replaces the second boot search and the family-only people chips.
- §2.3 map: `Search.search` → `story.search`. Add a row: search page boot → `story.facets`.
- §3 client change list: add the F16 items, plus `search_page.dart` reading chips from `facets`, `search_api.dart` deleting `filterSearchRecords` and the decade constants at cutover, the `Person.relationship` removal, `Person` gaining death fields, and `Place.familyId` removal.
- Fix the snake_case data names `app_user`, `tree_id` and `cover_key` (lines 17, 191, 219, 223, 313) to `AppUser`/`users`, `treeId` and `coverKey`.

## Approach
Steps 1–7 only edit docs and don't depend on each other's output. Each step uses the authoritative content in §Model and §Contract changes above. Step 8 depends on steps 1 and 2.

1. **SD §0 and §1** (`docs/migration/schema-design.md`):
   - §0.4: replace the "keep raw SQL in `constraints.sql` + `File(...)`" decision with: the Dart const `constraintsSql` in `apps/server/lib/src/db/constraints.dart`, applied by `applyConstraints()` after `pod.start()`, as P1 Task 5 does.
   - Add §0.5 Dimensions (ER mermaid + table + named orders).
   - In §1, replace the YAML for Family (comments), Person, Place, Story, StoryPerson and Invite. Add `KinshipKind` (under Enums) and `Kinship` (after Invite).
   - Update the "Index coverage notes": the cascade parents gain `people.treeId`, `places.treeId`, `kinships.fromPersonId` and `kinships.toPersonId`; `people.homeFamilyId` is covered by `people_home_family_name_idx`.
   - §0.3: add "Person life dates use the same precision-aligned UTC-midnight convention".
2. **SD §2–§4:**
   - §2 mapping tables:
     - people: `family_id` → `homeFamilyId` (Restrict, reassigned on purge); `relationship` ✗ (dead; replaced by kinships); birth/passing → **+** birthDate/birthPrecision/deathDate/deathPrecision (re-added with a shape CHECK; decade is not allowed); **+** `treeId` as the owning FK.
     - places: `family_id` → `treeId`, **+** `createdAt`.
     - stories, story_people and invites: **+** `treeId`. Invites also get **+** `lastSentAt`.
     - New "kinships (new)" subsection.
   - §3.1 table: add rows for the new composite FKs (same tree for story/place/tag/invite person/origin/kinship), life-date shape, kinship self/canonical, and visibility valid. Move the tag same-tree row here.
   - Replace §3.3 with the full rewritten SQL block.
   - Apply the §3.2 rule edits.
   - Add §3.5 Effective origin.
   - Replace §3.4 "What was verified" with the step 8 results.
   - §4.2: change the person-avatar key to `trees/{treeId}/people/{personId}/avatar/{blobId}.jpg`. Replace the `temporaryDownloadUrl` sentence with "reads go through `MediaEndpoint`, which finds the row holding the key, checks access, and returns bytes from `retrieveFile`".
   - Replace the §4.3 purge steps.
3. **P1 plan** (`docs/superpowers/plans/2026-11-06-serverpod-phase1-server-foundation.md`):
   - row 26 and line 224: "17" → "19";
   - replace the YAML blocks for family (303-337), invite (339-371), person (414-450), place (474-498), story (500-535) and story_person (556-572) with the SD versions;
   - insert the `kinship.spy.yaml` and `kinship_kind.spy.yaml` blocks after invite, in alphabetical order;
   - replace the `constraintsSql` body (902-1023) with the new SD §3.3 SQL verbatim;
   - change line 900's reference to "schema-design.md §3.3".

   The Task 5/6 tests only build Tree, Family and Membership with fields that don't change, so the `+9` gate (1308) stays.
4. **EC** (`docs/migration/endpoint-contract.md`): apply §Contract changes.
5. **BR** (`docs/migration/business-rules.md`):
   - fix 318 and 341 to "unique per tree (`people_tree_user_uidx`); people are tree-scoped with a home family";
   - remove decade from the DOB rank at 368;
   - 326: note that the DB CHECK is now 1000–9999;
   - add `### 2.12 Kinship` (read: tree reader; add/remove: live member of a live family in the tree; cycle rule) and add a life-date invariants bullet in §4.3;
   - append `## 8. Deliberate changes in the Serverpod rewrite (data-model review)`, listing:
     - places are visible tree-wide;
     - people survive a home-family purge (reassigned);
     - search decade labels apply to any decade, and facets drive the chips;
     - kinships and life dates are new;
     - `branchYear` is checked in the DB;
     - invites carry `lastSentAt`.
6. **Stale docs:**
   - in `docs/migration/serverpod-notes.md` §4 (103-146), replace the model sketch with one line: "Model files are specified in `schema-design.md` §1; this section only covers syntax." Keep line 104's syntax note.
   - `docs/design-doc/data-model.md` line 1: add the banner `> Superseded for the Serverpod rewrite by docs/migration/schema-design.md. Describes the Supabase state as of 2026-10-16.`
   - in `docs/superpowers/plans/2026-11-06-serverpod-migration-roadmap.md` "Reference inputs", add `docs/migration/data-model-review.md`.
7. **Review doc** `docs/migration/data-model-review.md`:
   - title and date (2026-11-07);
   - scope (two sentences);
   - the Findings table above (ID, finding, evidence, decision, applied in);
   - the Dimensions summary (link to SD §0.5);
   - the deliberate behavior changes (same list as BR §8);
   - the Phase 4 client items (F16);
   - the validation summary from step 8.
8. **Validate the SQL** on a throwaway Postgres 17 outside the repo, in `/tmp/tmas-dm-review`:
   1. `mise install postgres@17.11`. The existing symlink `~/.local/share/mise/installs/postgres/17 -> 17.11` is dangling. Then set `PGBIN="$(mise where postgres@17.11)/bin"`.
   2. Start the server: `$PGBIN/initdb -D /tmp/tmas-dm-review/data -U postgres --auth=trust`, then `$PGBIN/pg_ctl -D /tmp/tmas-dm-review/data -o "-p 54329 -k /tmp/tmas-dm-review" -l /tmp/tmas-dm-review/pg.log start`, then `$PGBIN/createdb -h /tmp/tmas-dm-review -p 54329 -U postgres check`.
   3. Write `00_stub.sql` with `serverpod_auth_core_user(id uuid PK default gen_random_uuid())`.
   4. Write `01_ddl.sql`, which emulates Serverpod DDL from the final SD YAML:
      - quoted camelCase columns; `uuid` ids with `DEFAULT gen_random_uuid()`;
      - `text` for byName enums and `bigint` for DatePrecision and `int`;
      - `timestamp without time zone`, `double precision`, `boolean`;
      - all tables created first, then every `relation()` FK added with `ALTER TABLE ONLY … ADD CONSTRAINT <table>_fk_N … ON DELETE <action>` (this handles the families↔stories cycle);
      - every YAML index.
   5. Write `02_constraints.sql`, copied verbatim from the new SD §3.3.
   6. Write `03_cases.sql`. It defines plpgsql helpers `expect_ok(sql text)` and `expect_fail(sql text, state text)`; `expect_fail` raises unless the statement fails with exactly that SQLSTATE. Run the cases in §Verification.
   7. Run `psql -v ON_ERROR_STOP=1 -h /tmp/tmas-dm-review -p 54329 -U postgres check -f` on 00, 01, 02, then 02 **again** (idempotency), then 03.
   8. Paste the pass summary into SD §3.4 and the review doc.
   9. Clean up: `$PGBIN/pg_ctl -D /tmp/tmas-dm-review/data stop && rm -rf /tmp/tmas-dm-review`.

   If a case fails, fix the SQL or YAML in SD and P1 together and rerun from step 2.
9. **Commit** on the worktree's own branch: `git add docs && git commit -m "docs(migration): data model review — tree-scoped people/places, kinships, life dates, same-tree FKs, search facets"`. Don't push or merge.

## Critical files & anchors
- `docs/migration/schema-design.md`: §0.4 (58-72), §1 (76-484), §2 (488-606), §3.2 (625-643), §3.3 (645-758), §3.4 (760-779), §4.2-4.3 (793-825).
- `docs/superpowers/plans/2026-11-06-serverpod-phase1-server-foundation.md`: 26, 224, YAML 232-592, const 900-1023. It must match SD byte for byte.
- `docs/migration/endpoint-contract.md`: 17, 153-207, 216-339, the §3 client list (392+).
- `docs/migration/business-rules.md`: 318, 326, 341, 368, append §2.12 and §8.

## Verification
- **SQL** (step 8), using these `03_cases.sql` cases. Each one must give the stated outcome, and the script must exit 0.
  - Rejected: `23503` foreign key, `23514` check, `23505` unique, `23001` restrict.
    - story whose `placeId` is in another tree → 23503
    - story whose `treeId` ≠ its family's tree → 23503
    - tag a person from another tree → 23503
    - invite whose `personId` is in another tree → 23503
    - `originStoryId` from another tree → 23503
    - kinship across trees → 23503
    - kinship to self → 23514
    - `partnerOf` with from > to → 23514
    - duplicate kinship → 23505
    - deathDate with passedAway=false → 23514
    - death year < birth year → 23514
    - month-precision birth on day 15 → 23514
    - partial birth pair → 23514
    - `branchYear` 999 → 23514
    - `birthVisibility` 'bogus' → 23514
    - delete a family that is a person's home → 23001
    - duplicate `(treeId, mapboxPlaceId)` → 23505
    - every rejection listed in the current SD §3.4 (cross-tree parent, blank name, second owner, the same user linked twice in a tree, unnormalized email, wrong month end, partial-null story dates, undated published, year 999, time-of-day date, raw token).
  - Accepted:
    - the same mapboxPlaceId in two trees;
    - one place used by stories in two families of one tree;
    - tagging a person whose home is a sibling family;
    - `parentOf` A→B plus canonical `partnerOf`;
    - deleting a place nulls `stories.placeId` while `familyId`/`treeId` are kept;
    - deleting a person removes their story_people and kinships and nulls `invites.personId`;
    - purge simulation, non-last family: reassign `homeFamilyId`, delete the family; the people remain, its stories are gone, and a sibling `originStoryId` that pointed at a purged story becomes NULL;
    - purge simulation, last family: delete people, family and tree, and the places are gone;
    - deleting an auth user nulls `people.userId`, `stories.authorId` and `kinships.createdById`, and every CHECK still passes;
    - every acceptance listed in the current SD §3.4.
- **Doc consistency** (run from the repo root; each should return nothing, or only intended hits):
  - grep `docs/migration docs/superpowers/plans/2026-11-06-serverpod-phase1-server-foundation.md` for `MemberRole\b|decade, year|people_family_tree_fk|places_family_|relationship\?|app_user|tree_id|cover_key|InviteSummary|auto-adds`. Expected: no hits, except historical "old" columns in SD §2 and the BR §6 quotes.
  - Diff the P1 YAML and const blocks against SD: extract each fenced block and `diff` it. Expected: identical.
- **Not verifiable here:** that `serverpod generate` accepts two id relations to the same parent (`kinships.fromPersonId/toPersonId`, already the pattern on `invites`). It stays listed as [UNVERIFIED] in SD §3.4 and is checked by P1 Task 3.

## Assumptions & contingencies
- If `mise install postgres@17.11` fails, run `brew install postgresql@17` and use `$(brew --prefix postgresql@17)/bin`. If both fail, finish steps 1–7 and 9, mark SD §3.4 "not executed on this revision", and report the blocker. Don't use the Homebrew PG 14 (it lacks `ON DELETE SET NULL (col)`).
- The search people chips now list only people tagged on the family's published stories, not every family person, and decade labels match any decade. These are deliberate behavior changes and are recorded in BR §8. If the user wants exact parity, keep the old `listPeople`-based chips and the 1900–2020 bound in the EC text instead.
- Kinship gets a model and endpoints but no client UI. The UI needs a UX spec first, as noted in EC.
