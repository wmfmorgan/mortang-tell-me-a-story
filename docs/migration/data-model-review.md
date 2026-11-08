# Data model review (2026-11-07)

## Scope
The review makes the Serverpod schema (model YAML plus `constraintsSql`) the single source of truth for relationships and integrity. It also models time, place, people, family/branch and authorship as dimensions, so the timeline, filters and search become server queries.

It was applied to both the docs and `apps/server` on branch `docs/data-model-review`:
- `3738f76`: models, regenerated code, the re-collapsed init migration `apps/server/migrations/20261107133050788-init`, and the constraint tests.
- `e12e879`: `constraintsSql`.

The init migration was re-collapsed because nothing is deployed yet. Local dev and test databases must be recreated.

## Findings
Evidence was rechecked at `4260dfb`, and every finding still held. `SD` = `schema-design.md`, `BR` = `business-rules.md`, `EC` = `endpoint-contract.md`. Client paths are under `apps/tell_me_a_story/lib`.

| ID | Finding | Evidence | Decision | Applied in |
|---|---|---|---|---|
| F1 | Person is tree-scoped in the product but family-owned in the schema. A Cascade on the home family would delete a person tagged in sibling branches. | `add_person_modal.dart:115-117,186-187,239-280`; `people_api.dart:245-255` | `people.treeId` is the owner (Cascade from trees). `homeFamilyId` is NOT NULL with Restrict. The purge job reassigns the home family before deleting it. | `person.spy.yaml`, `people_home_family_tree_fk`; SD §1, §4.3 |
| F2 | Places are per family, so one real place is duplicated per branch. Nothing ties a story's place to the story's family. | `all_stories_logic.dart:247-304`; `places_api.dart:55-66,110-114` | Places are tree-scoped. `stories_place_tree_fk` holds a story's place in the story's tree. | `place.spy.yaml`, `story.spy.yaml`; SD §1, §3.1 |
| F3 | Cross-entity scoping is enforced only in the app layer or RLS: tags, invite person, origin story. | `supabase/migrations/20261018000000_story_people_same_tree.sql:1-31` | `treeId` copies on stories, story_people and invites, plus composite same-tree FKs (including `families_origin_tree_fk`). | `constraintsSql`; SD §3.1 |
| F4 | `people.relationship` is dead. It is written only as a literal null, and its only reader is a path that never selects it. Kinship isn't modeled. | `people_api.dart:232,324`; `story_reader_page.dart:1363-1366` | Drop `relationship`. Add `kinships` with `parentOf` and `partnerOf`. | `kinship.spy.yaml`, `kinship_kind.spy.yaml`; SD §1, BR §2.12 |
| F5 | Unlinked people have no life dates, but the client model carries birth and passing fields. | `people_api.dart:18-21,34-37,51-54` | Person gets birth and death date/precision, with pair and shape checks. While a person is linked, the account's birth wins on read. | `person.spy.yaml`, `people_birth_*`, `people_death_*` |
| F6 | SD gets the origin rule wrong: stewards can change the origin, and a root's origin is in its own family. The effective origin is never specified. | `20261011190823_origin_stories_hardening.sql:72-151` | Comments fixed. SD §3.5 now specifies the effective origin. The DTO field is `effectiveOriginStoryId`. | `family.spy.yaml`; SD §3.2, §3.5; EC §2.1 |
| F7 | SD says tagging auto-creates a membership, but BR says it doesn't. | `20261012100000_people_profiles.sql:276-277` | No side effect. SD now follows BR. | SD §3.2 |
| F8 | Some rules are missing from SD §3.2: invite person validity, the unlinked-picker exclusion, tree-wide removeMember, the creator's person row, depth cap 63, branch year 1000–9999. | BR:326-327 | Added to SD §3.2. `branchYear` is now a DB CHECK. | `families_branch_year_1000_9999`; SD §3.2 |
| F9 | The docs disagree on enums and names (`MemberRole`, a decade precision, snake_case names, a non-null `StoryDto.datePrecision`). | EC (old lines 17-315) | EC aligned to SD. | EC §0, §2.1, §2.2 |
| F10 | EC parses blob key prefixes and deletes blobs inline; SD uses an outbox. | EC §2.0 | Media access goes through a lookup of the row that holds the key. Old keys go to `blob_deletions` in the same transaction. | SD §4.2; EC §2.0 |
| F11 | Search and facets run in the client. Decade chips are bounded to 1900–2020, and people chips are family-only. | `search_api.dart:37-38,123-185,197-207`; `search_page.dart:113,136-145`; `timeframe_chips.dart:31-32` | New `story.search` and `story.facets` contracts with exact semantics. They are contract only; the endpoints aren't built yet. | EC §2.2 |
| F12 | The invite's sent date is back-computed as `expiresAt − 7d`. | `families_api.dart:280-285` | `invites.lastSentAt`. | `invite.spy.yaml` |
| F13 | Note and photo DTOs carry a `familyId` that has no source. | `photos_api.dart:18,28,41,256` | Derived from the story server-side and not stored. | EC §2.1 |
| F14 | `birthVisibility` has no value CHECK, and birth dates aren't checked against their precision. | SD §3.3 (old) | `users_birth_visibility_valid`. `users_birth_midnight` is retired in favor of `users_birth_shape`. | `constraintsSql` |
| F15 | Stale docs: the `serverpod-notes.md` model sketch and `design-doc/data-model.md`, plus `constraints.sql` vs the Dart const. | `serverpod-notes.md` §4 | The sketch now points to SD §1. `data-model.md` has a superseded banner. SD documents the `constraintsSql` const. | SD §0.4; notes; data-model.md |
| F16 | Client-only issues; see Phase 4 client items below. | below | Recorded; no schema change. | EC §3 |

Out of scope and left as they are: the error-type disagreement, realtime channel names, request-size limits, and photo width/height columns.

## Dimensions
Family/branch, time, place, people and authorship are specified in [SD §0.5](schema-design.md), with the ER diagram and the named orders (`timelineOrder`, `allStoriesOrder`, `latestOrder`). The facts are `stories`, `photos` and `story_notes`.

## Deliberate behavior changes
These match BR §8:
- Places are visible tree-wide.
- People survive a home-family purge; they are reassigned to a sibling family.
- Search decade labels apply to any decade, and facets drive the chips. People chips list people tagged on the family's published stories.
- Kinships and person life dates are new.
- `branchYear` 1000–9999 is checked in the DB.
- Invites carry `lastSentAt`.

## Phase 4 client items (F16)
- Story sort orders differ in three places: `stories_api.dart:852-876`, `all_stories_logic.dart:105-108` and `search_api.dart:153-185`. Converge them on the named orders.
- `relatedMarks` puts null years first (`timeline_zoom.dart:169-187`), while `compareChildren` puts them last.
- `authorId` and `uploaderId` are non-null on the client (`stories_api.dart:24,49,94`, `comments_api.dart:20,35`, `perspectives_api.dart:20,35`, `photos_api.dart:19,29,42`), but the FKs are SetNull.
- `Place.familyId` is never read (`places_api.dart:7,18,30`). It goes away with tree-scoped places.
- `co_owner` string literals appear at 14 code sites in 7 files. Use `MembershipRole`.
- `Person.relationship` is removed, and `Person` gains death fields.
- `search_page.dart` reads its chips from `story.facets`, and `search_api.dart` drops `filterSearchRecords` and the decade constants.

## Validation
The constraints were checked by `apps/server/test/integration/constraints_test.dart` under `just server-test`. That runs on Serverpod 4.1.1's embedded Postgres 16 against the real generated DDL. All 58 server tests pass, on a fresh database and again on a reused one.
- **Rejected**: cross-tree place, story tree, tag, invite person, origin story, kinship, home family and parent; kinship to self, an unknown kinship kind, non-canonical `partnerOf` and duplicate kinships; death without `passedAway`, death year before birth year, misaligned or partial birth and death dates; misaligned account birth and an unknown `birthVisibility`; `branchYear` 999; a blank family or person name; deleting a family that is someone's home; a duplicate Mapbox place in one tree. All of the carried-over checks were also re-run.
- **Accepted**: the same Mapbox place in two trees; one place used by two families of a tree; tagging a person from a sibling family; `parentOf` plus a canonical `partnerOf`; deleting a place nulls `placeId`; deleting a person; both purge simulations (non-last and last family); account deletion nulls `people.userId`, `stories.authorId`, `kinships.createdById` and `invites.acceptedById`. The carried-over cases are re-checked too: a co-owner, two unlinked people in one tree, an undated draft, and valid day, month (1984-02-29) and year spans.
- **Constraint changes**: the constraints run twice without error. Old constraint names on an existing database are dropped and their replacements added.
- **Two corrections to the review plan**:
  - Postgres reports `ON DELETE RESTRICT` as `23503`, not `23001`.
  - `serverpod generate` accepts two relations from `kinships` to `people`, so that question is settled.
