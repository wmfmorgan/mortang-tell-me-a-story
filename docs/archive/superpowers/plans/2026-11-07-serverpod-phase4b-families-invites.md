# Phase 4b — Families, directory, covers, invites (Serverpod cutover)

> Agentic workers: run task by task via `skill://executing-plans`; each task = failing test → implement → pass → commit.

**Goal:** Move `FamiliesApi`, `FamilyCoversApi`, `ManageFamiliesApi`, `InviteApi`, `InviteLinkApi` from Supabase to Serverpod client, per 4b row of `2026-11-07-serverpod-phase4-client-cutover.md`.

**Architecture:** Each `*Api` keeps name + interface, takes `{server.Client? client}`, reads `serverClient` lazily. Every call wrapped in `withServerErrors`. DTO → domain mapping = `fromDto` factory beside each domain class. Covers: start (`image/jpeg`) → `FileUploader(desc).uploadByteData` → finish.

**Tech stack:** Flutter, `tell_me_a_story_client` (prefix `server`), `serverpod_client` `FileUploader`, `flutter_test`, live tests vs `just server`.

## File map

| File | Change |
|---|---|
| `lib/data/families_api.dart` | `MemberFamily/StewardFamily/TreeFamily/FamilyRoster/FamilyPerson/FamilyInvite/FamilyDetail.fromDto`; `FamiliesApi` on `family.*`; delete `familiesCoverColumnMissing`, `_originError`, `fromJson`. `FamilyInvite` takes server `sentAt`/`createdAt`. `loadDetail` maps forbidden/notFound → null. Member avatars via `media.getMany`. |
| `lib/data/family_covers.dart` | `FamilyCoversApi` on `media.get` / `startCoverUpload` → upload → `finishCoverUpload` / `clearCover`. Delete `familyCoverObjectPath`, `familyCoversBucket`, `familyCoverExtensions`. Keep `familyCoverMaxBytes`, `CoverPhotoException`, `FamilyCoverClient`. |
| `lib/data/manage_families_api.dart` | `ManageFamiliesApi` on `family.*` / `invite.resend` / `invite.revoke`; `transferOwnership` uses `roleFromName`. |
| `lib/data/invite_api.dart` | `InviteApi` on `family.listMine` + `FamilySelection.id` / `family.createRoot` / `invite.create` / `invite.sendEmail(id, token)` / `invite.accept`; `InviteLinkApi` on `invitePublic.preview`. `CreateInviteResult.expiresAt` → `DateTime`; `AcceptInviteResult` drops `membershipId`; `sendInviteEmail` gains `required String token`. |
| `lib/features/invites/invite_modal.dart` | `_pendingSend` keeps `CreateInviteResult` (id + token). |
| `lib/features/people/add_person_modal.dart`, `edit_person_dialog.dart` | send call passes `token`. |
| `test/families_api_test.dart` (new) | `fromDto` tests. |
| `test/family_landing_latest_test.dart` | drop cover-column + object-path cases. |
| `test/family_menu_tree_test.dart` | `MemberFamily.fromJson` test → `fromDto`. |
| `test/gateway_errors_test.dart` | delete Supabase-only `InviteApi`/`ManageFamiliesApi` no-session + `setFamilyOrigin` RPC-error cases (`withServerErrors` covers server errors). |
| `test/invite_chrome_test.dart` | fake records tokens; retry case asserts same token resent. |
| every `InviteGateway` fake (19 files) | `sendInviteEmail({inviteId, token})`, `AcceptInviteResult(familyId:)`, `CreateInviteResult(expiresAt: DateTime)`. |
| `test/live/families_live_test.dart` (new) | listMine, listStewarded, createRoot, rename, tree, members, directory, detail, cover round trip, manage ops. |
| `test/live/invite_live_test.dart` (new) | create → preview → accept (second user, own `client:`) → resend → revoke; currentFamilyId. |

## Tasks

### Task 1 — mapping (`fromDto`)
1. Write `test/families_api_test.dart`: build `server.MemberFamilyDto`, `StewardFamilyDto`, `TreeFamilyDto`, `FamilyRosterDto`, `FamilyMemberDto`, `PendingInviteDto`, `FamilyDetailDto`; assert domain fields (`role` == `co_owner` for `coOwner`, `parentFamilyId`, `coverPhotoPath` ← `coverKey`, `originStoryId` ← `effectiveOriginStoryId`, invite `sentAt`/`createdAt` from server, blank name → `Family`).
2. Run `flutter test test/families_api_test.dart` → fails (no `fromDto`).
3. Add factories; delete `fromJson`; rewrite `family_menu_tree_test` case to `fromDto`.
4. Pass; commit `feat(client): families fromDto mapping`.

### Task 2 — invite interface change
1. Change every `InviteGateway` fake to new signature + `AcceptInviteResult(familyId:)`, `CreateInviteResult(expiresAt: DateTime)`; `flutter analyze` fails.
2. Change interface, result classes, four callers (`invite_modal` ×2, `add_person_modal`, `edit_person_dialog`); `_pendingSend` maps person id → `CreateInviteResult`.
3. `flutter test` passes; commit `feat(client): sendInviteEmail carries the token`.

### Task 3 — live tests (failing)
Write `test/live/families_live_test.dart` + `test/live/invite_live_test.dart` (tag `live`, `setUpAll(waitForLiveServer)`, `signInLive(freshEmail(...))`; second user's gateways get `client:`). `just test-live` fails (Supabase gateways). Commit with Task 4.

### Task 4 — gateways on Serverpod
Rewrite `FamiliesApi`, `FamilyCoversApi`, `ManageFamiliesApi`, `InviteApi`, `InviteLinkApi`. Delete cover-column helper/tests + `familyCoverObjectPath`. `currentFamilyId`: signed out → null; else `listMine`, remembered `FamilySelection.id` if in list, else first. `just test-live` + `flutter test` pass; commit `feat(client): families, covers, invites on Serverpod`.

### Task 5 — gate
`dart format --set-exit-if-changed`, `flutter analyze` ≤ 23, `flutter test`, `just test-live`.

## As landed
- Commits: `feat(client): families and covers on Serverpod with fromDto mapping` (Tasks 1 + 4 families/covers), `feat(client): invites and family management on Serverpod; sendInviteEmail carries the token` (Task 2 + 4 invites/manage), `test(client): families and invite live tests` (Task 3).
- Live setup for origin/branch/directory publishes story via raw client (`people.create` + `place.create` + `story.createDraft` + `publish`); publish needs person + place.
- `FamilyInvite` gains `lastSentAt` (server `sentAt`); `sentAt` falls back to `createdAt`, then expiry − 7 days, so existing widget fixtures stay valid.
- `listMembers`/`loadDetail` fetch member avatars in one `media.getMany`; failed fetch → initials.

## Notes
- `setCoverPhoto.previousPath` / `clearCoverPhoto.path` stay in interface (feature code outside 4b passes them), but server replaces/queues old blob itself.
- `loadDetail` returns null for forbidden/notFound only.