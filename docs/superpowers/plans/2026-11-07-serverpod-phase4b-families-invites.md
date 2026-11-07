# Phase 4b — Families, directory, covers, invites (Serverpod cutover)

> For agentic workers: execute task by task with `skill://executing-plans`; each task is failing test → implement → pass → commit.

**Goal:** Move `FamiliesApi`, `FamilyCoversApi`, `ManageFamiliesApi`, `InviteApi` and `InviteLinkApi` from Supabase to the Serverpod client, per the 4b row of `2026-11-07-serverpod-phase4-client-cutover.md`.

**Architecture:** Each `*Api` keeps its name and interface, takes `{server.Client? client}` and reads `serverClient` lazily. Every call is wrapped in `withServerErrors`. DTO → domain mapping is a `fromDto` factory next to each domain class. Covers go start (`image/jpeg`) → `FileUploader(desc).uploadByteData` → finish.

**Tech stack:** Flutter, `tell_me_a_story_client` (prefixed `server`), `serverpod_client` `FileUploader`, `flutter_test`, live tests against `just server`.

## File map

| File | Change |
|---|---|
| `lib/data/families_api.dart` | `MemberFamily/StewardFamily/TreeFamily/FamilyRoster/FamilyPerson/FamilyInvite/FamilyDetail.fromDto`; `FamiliesApi` on `family.*`; delete `familiesCoverColumnMissing`, `_originError`, `fromJson`. `FamilyInvite` takes server `sentAt`/`createdAt`. `loadDetail` maps forbidden/notFound → null. Member avatars via `media.getMany`. |
| `lib/data/family_covers.dart` | `FamilyCoversApi` on `media.get` / `startCoverUpload` → upload → `finishCoverUpload` / `clearCover`. Delete `familyCoverObjectPath`, `familyCoversBucket`, `familyCoverExtensions`. Keep `familyCoverMaxBytes`, `CoverPhotoException`, `FamilyCoverClient`. |
| `lib/data/manage_families_api.dart` | `ManageFamiliesApi` on `family.*` / `invite.resend` / `invite.revoke`; `transferOwnership` uses `roleFromName`. |
| `lib/data/invite_api.dart` | `InviteApi` on `family.listMine` + `FamilySelection.id` / `family.createRoot` / `invite.create` / `invite.sendEmail(id, token)` / `invite.accept`; `InviteLinkApi` on `invitePublic.preview`. `CreateInviteResult.expiresAt` → `DateTime`; `AcceptInviteResult` loses `membershipId`; `sendInviteEmail` gains `required String token`. |
| `lib/features/invites/invite_modal.dart` | `_pendingSend` keeps the `CreateInviteResult` (id + token). |
| `lib/features/people/add_person_modal.dart`, `edit_person_dialog.dart` | send call passes `token`. |
| `test/families_api_test.dart` (new) | `fromDto` tests. |
| `test/family_landing_latest_test.dart` | drop the cover-column and object-path cases. |
| `test/family_menu_tree_test.dart` | `MemberFamily.fromJson` test → `fromDto`. |
| `test/gateway_errors_test.dart` | delete the Supabase-only `InviteApi`/`ManageFamiliesApi` no-session and `setFamilyOrigin` RPC-error cases (server errors are covered by `withServerErrors`). |
| `test/invite_chrome_test.dart` | fake records tokens; the retry case asserts the same token is resent. |
| every `InviteGateway` fake (19 files) | `sendInviteEmail({inviteId, token})`, `AcceptInviteResult(familyId:)`, `CreateInviteResult(expiresAt: DateTime)`. |
| `test/live/families_live_test.dart` (new) | listMine, listStewarded, createRoot, rename, tree, members, directory, detail, cover round trip, manage ops. |
| `test/live/invite_live_test.dart` (new) | create → preview → accept (second user, own `client:`) → resend → revoke; currentFamilyId. |

## Tasks

### Task 1 — mapping (`fromDto`)
1. Write `test/families_api_test.dart`: build `server.MemberFamilyDto`, `StewardFamilyDto`, `TreeFamilyDto`, `FamilyRosterDto`, `FamilyMemberDto`, `PendingInviteDto`, `FamilyDetailDto` and assert domain fields (`role` == `co_owner` for `coOwner`, `parentFamilyId`, `coverPhotoPath` ← `coverKey`, `originStoryId` ← `effectiveOriginStoryId`, invite `sentAt`/`createdAt` from server, blank name → `Family`).
2. Run `flutter test test/families_api_test.dart` → fails (no `fromDto`).
3. Add the factories; delete `fromJson`; rewrite the `family_menu_tree_test` case to `fromDto`.
4. Pass; commit `feat(client): families fromDto mapping`.

### Task 2 — invite interface change
1. Change every `InviteGateway` fake to the new signature and `AcceptInviteResult(familyId:)`, `CreateInviteResult(expiresAt: DateTime)`; `flutter analyze` fails.
2. Change the interface, the result classes and the four callers (`invite_modal` ×2, `add_person_modal`, `edit_person_dialog`); `_pendingSend` maps person id → `CreateInviteResult`.
3. `flutter test` passes; commit `feat(client): sendInviteEmail carries the token`.

### Task 3 — live tests (failing)
Write `test/live/families_live_test.dart` and `test/live/invite_live_test.dart` (tag `live`, `setUpAll(waitForLiveServer)`, `signInLive(freshEmail(...))`; the second user's gateways get `client:`). `just test-live` fails (Supabase gateways). Commit with Task 4.

### Task 4 — gateways on Serverpod
Rewrite `FamiliesApi`, `FamilyCoversApi`, `ManageFamiliesApi`, `InviteApi`, `InviteLinkApi`. Delete the cover-column helper/tests and `familyCoverObjectPath`. `currentFamilyId`: signed out → null; else `listMine`, remembered `FamilySelection.id` if in the list, else the first. `just test-live` and `flutter test` pass; commit `feat(client): families, covers, invites on Serverpod`.

### Task 5 — gate
`dart format --set-exit-if-changed`, `flutter analyze` ≤ 23, `flutter test`, `just test-live`.

## As landed
- Commits: `feat(client): families and covers on Serverpod with fromDto mapping` (Tasks 1 + 4 for families/covers), `feat(client): invites and family management on Serverpod; sendInviteEmail carries the token` (Task 2 + 4 for invites/manage), `test(client): families and invite live tests` (Task 3).
- Live setup for origin/branch/directory publishes a story through the raw client (`people.create` + `place.create` + `story.createDraft` + `publish`), since publish needs a person and a place.
- `FamilyInvite` gains `lastSentAt` (server `sentAt`); `sentAt` falls back to `createdAt`, then expiry − 7 days, so existing widget fixtures stay valid.
- `listMembers`/`loadDetail` fetch member avatars with one `media.getMany`; a failed fetch leaves initials.

## Notes
- `setCoverPhoto.previousPath` / `clearCoverPhoto.path` stay in the interface (feature code outside 4b passes them) but the server replaces/queues the old blob itself.
- `loadDetail` returns null for forbidden/notFound only.
