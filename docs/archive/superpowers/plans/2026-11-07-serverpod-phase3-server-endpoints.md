# Phase 3: Server Endpoints — Index

> **For agentic workers:** Phase 3 index. Land 3.0 first via superpowers:executing-plans or superpowers:subagent-driven-development. Then slices 3a–3f run parallel, each own branch, own detailed plan (§Slice plans).

**Goal:** Implement every endpoint in `docs/migration/endpoint-contract.md` §2.2 with client caller, on Serverpod 4.1.1. Each tested against business rules as amended by 2026-11-07 decisions (D1–D9), so Phase 4 switches Flutter gateways in one cutover.

**Architecture:** One endpoint class per resource under `apps/server/lib/src/endpoints/`, each owned by exactly one slice. Authz, blob keys, blob deletion queue, account helpers, live-event channels, DTOs, test fixtures come from 3.0, shared. Writes run in one transaction, queue old blob keys inside it, post live events after commit. Purge + blob drain = recurring future calls owned by 3f.

**Tech Stack:** Dart 3.13.5, Serverpod 4.1.1, embedded Postgres 16, just.

**Spec of record:** `docs/migration/business-rules.md` §2, §3, §7 (amended); `docs/migration/schema-design.md` §3.2, §3.5, §4; `docs/migration/endpoint-contract.md` §2; roadmap "Product decisions (2026-11-07)". Code vs docs disagree → stop, report diff; no silent reconcile.

---

## Status

| Part | Plan | Depends on | Status |
|---|---|---|---|
| 3.0 Shared foundation | `2026-11-07-serverpod-phase3-0-foundation.md` | — | landed (server tests 100/100) |
| 3a Families, places, profile | `2026-11-07-serverpod-phase3a-families.md` | 3.0 | landed (merge `0e07f17`) |
| 3b People | `2026-11-07-serverpod-phase3b-people.md` | 3.0 | landed (merge `af56009`) |
| 3c Stories, tags, notes, search | `2026-11-07-serverpod-phase3c-stories.md` | 3.0 | landed (merge `9e54065`) |
| 3d Photos and media | `2026-11-07-serverpod-phase3d-photos-media.md` | 3.0 | landed (merge `33236ee`) |
| 3e Invites | `2026-11-07-serverpod-phase3e-invites.md` | 3.0 | landed (merge `cfa17fc`) |
| 3f Live streams, purge, blob drain | `2026-11-07-serverpod-phase3f-live-purge.md` | 3.0 | landed (merge `1a14d83`) |

No slice depends on another slice's code. Every cross-slice need (predicates, keys, blob queue, `ensureLinkedPerson`, channel names, DTOs) in 3.0.

## Slice plans

Slice executor writes detailed plan via superpowers:writing-plans at slice start, atop landed 3.0. Like 3.0, plan verified by running its code in scratch worktree before execution, so code blocks real. Slice table below = scope contract: plan covers every method + test case its row lists, nothing outside.

---

## Conventions (verified with a probe endpoint on 2026-11-07)

**Endpoint shape.** Each file `apps/server/lib/src/endpoints/<name>_endpoint.dart`; each class sets `requireLogin`:

```dart
class FamilyEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<void> rename(Session session, UuidValue familyId, String name) async {
    final trimmed = name.trim();
    await Authz(session).requireLiveSteward(familyId); // authz before any NOT_FOUND / VALIDATION
    if (trimmed.isEmpty) throw validation('name is required');
    await session.db.transaction((t) async {
      final family = await Family.db.findById(
        session,
        familyId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      );
      await Family.db.updateRow(session, family!.copyWith(name: trimmed), transaction: t);
    });
  }
}
```

- **Order of checks.** Authz first, then existence, then validation, in order business-rules §3 states for that op. Missing or soft-deleted family refused as `forbidden`, same as stranger (`Authz.requireLive*`), so ids don't leak. Pass `message:` when catalogue wants different text (invite create/send: `'Not a family member'`).
- **Recovery exception (D6b).** Only checks ignoring soft delete = recovery ones: `recover`, and steward reads of deleted family's row + memberships (`listStewarded`, `directory`, `detail`). Use `isSteward(familyId)` there, throw `forbidden('owner or co-owner only')`. All else uses `requireLive*`.
- **Tree-scoped rows.** Places + people checked via `Authz.isTreeMemberOf(row.treeId)`, never `isTreeReadable(person.homeFamilyId)`: soft-deleted home family must not hide person from rest of tree (D8).
- **Errors.** Throw only `AppException`, via `lib/src/errors.dart` (`forbidden`, `notFound`, `validation`, `conflict`) or `AppException(code: AppErrorCode.inviteInvalid | inviteAccepted | inviteExpired | photoCap | storageFailed, …)`. Messages = business-rules §5.2 strings. Photo cap = `AppException(code: AppErrorCode.photoCap, message: 'photo limit reached')`. Never return raw DB text. Catch known constraint violation (`DatabaseQueryException.code`) only to map to catalogue message; rest propagates.
- **Transactions.** Pass `transaction: t` to every DB call inside `session.db.transaction`. Lock parent row (`lockMode: LockMode.forUpdate`) wherever schema-design §3.2 asks (co-owner cap, photo cap, kinship cycle).
- **Linked-person race.** `ensureLinkedPerson` can lose race on `people_tree_user_uidx`, e.g. double-tapped invite accept, or branch created while that member accepts invite. Loser fails with `23505`. `createBranch` (3a) + `InviteEndpoint.accept` (3e) catch `DatabaseQueryException` with code `23505` and constraint `people_tree_user_uidx`, rerun transaction once; rerun finds committed person. Pin with test inserting person between lookup and insert, or running two accepts concurrently.
- **Blobs.** Never call `deleteFile` from endpoint. Old keys via `queueBlobDeletions(session, keys, transaction: t)` inside write transaction. New keys from `blob_keys.dart`. Uploaded bytes checked with `sniffImageMime` before row written.
- **Live events.** Call `postLiveEvent(session, LiveEventDto(...))` after `session.db.transaction` returns, never inside. Story, photo, note writes post (kinds `story`, `photo`, `note`), only for published stories, plus publish/unpublish transitions themselves. Draft edits post nothing, so draft ids never reach other members or tree readers on family channel. Family-level writes don't post.
- **Anonymous callers** never reach method body: `requireLogin` makes Serverpod throw `ServerpodUnauthenticatedException`. No per-method anonymous tests. One test per endpoint class enough.

**Test shape.** One `test/integration/<name>_endpoint_test.dart` per endpoint class:

```dart
void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given FamilyEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    setUp(() => fx = Fx(sessionBuilder.build()));

    test('when a plain member renames then FORBIDDEN', () async {
      final member = await fx.user();
      final family = await fx.family(await fx.tree());
      await fx.join(family, member);
      await expectLater(
        endpoints.family.rename(asUser(sessionBuilder, member), family.id!, 'X'),
        throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- `RollbackDatabase.disabled` everywhere: endpoints use transactions + streams. Each test builds own users + trees via `Fx`, so tests independent on shared DB.
- Name tests by business-rules §7 case ported (`// BR 117`), keep its given/when/then wording.
- Streams: subscribe, wait ~50 ms so listener registered, write, then `await first.timeout(...)`. Probe confirmed works with `postLiveEvent`.
- Slice-only builders go in `test/integration/support/<slice>_fixtures.dart`. `fixtures.dart` changes only by appending method or adding optional named param to existing builder (e.g. `email:` on `Fx.invite` for 3e), so parallel merges trivial.

## Shared files and merging

- **Generated code.** Adding endpoint changes `apps/server/lib/src/generated/endpoints.dart`, `apps/server/test/integration/test_tools/serverpod_test_tools.dart`, `packages/tell_me_a_story_client/lib/src/protocol/client.dart`. Merge conflict in generated file → take either side, run `mise exec -- just server-generate`; never hand-merge generated code.
- **New models or migrations.** No slice needs table change. If one does, stop + report (schema-design is spec): two slices creating migrations at once collide in `migration_registry.txt`.
- **`lib/server.dart`** owned by 3f, which registers future calls.
- **Branches.** Each slice on `feat/p3<x>-<name>` off 3.0 commit, merges back into `feat/serverpod-migration` with `--no-ff`. After each merge, regenerate + run `just server-test`.

---

## Slices

Test case numbers = business-rules §7. "Port" = rewrite as Serverpod integration test, same given/when/then. Where decision changed expected outcome, amended §7 text already target.

### 3a Families, places, profile
- **Owns:** `FamilyEndpoint` (all methods in endpoint-contract §2.2, cover upload included), `PlaceEndpoint`, `ProfileEndpoint` (avatar included).
- **Rules:** business-rules §2.1, §2.2, §2.4, §2.10, §3.1–§3.3, §3.5 (soft delete + recover; purge is 3f), §3.6; schema-design §3.2 rows: co-owner cap, origin, immutables, soft delete/recover, createRoot, createBranch (D6d), removeMember, places, linked person name; §3.5 effective origin (use `Authz.effectiveOrigin`).
- **Decisions:**
  - D6b: live checks everywhere except recovery exception above. `detail` on soft-deleted family returns members but empty `pendingInvites`, since invites unreadable while family deleted.
  - D6d: `ensureLinkedPerson` for new owner + each picked member.
  - D8: `listTree` = live families with same `treeId`.
  - D1: no email change; `me` returns email read-only.
- **Port:** 1–19, 22, 29–32, 34–42, 48, 50–60, 106, 107, 109–111, 115; 137 (place part: creating place via soft-deleted family refused).
  - Cases 23–24 change shape, since server now makes cover key: steward upload stored, plain member refused (23); non-image bytes, sniffed type ≠ declared `mimeType`, oversize, unsupported type refused with `VALIDATION` (24).
  - Case 61 (Edge request checks) → Dart arg checks: blank name + year bounds still give `VALIDATION`.
  - Case 49 superseded, places tree-wide (business-rules §8 item 1).
- **Live events:** none.

### 3b People
- **Owns:** `PeopleEndpoint`: `listFamily`, `listTree`, `create`, `forEdit`, `profile`, `update`, `listUnlinked`, `isHomeFamilySteward`, `markPassedAway`, `delete`. Person pictures written inline via `create`/`update` (`personAvatarKey`, old key queued).
- **Rules:** business-rules §2.3, §4.6 (DOB coarsening by `birthVisibility`); schema-design §3.2 rows: passedAway, life dates, linked person name lock, person delete (D5), unlinked picker.
- **Decisions:** D5 (`delete`: owner/co-owner of live home family; linked → `VALIDATION: person is linked to an account`).
- **Port:** 95–105, 108, 116, 120, 136; 26 and 28 (people part).
- **Out of scope:** `listKinships`/`addKinship`/`removeKinship`. Endpoint-contract §2.2 marks contract-only until UX spec exists.
- **Live events:** none.

### 3c Stories, tags, notes, search
- **Owns:** `StoryEndpoint` (all methods, incl. `search` + `facets` with semantics under endpoint-contract §2.2), `NoteEndpoint`.
- **Rules:** business-rules §2.5, §2.6, §2.8, §4.4, §4.8; schema-design §3.2 rows: story locks, notes body-only, notes delete (D4); §0.5 named orders.
- **Decisions:** D4 (`NoteEndpoint.delete` and `NoteDto.canDelete`: author with `canContribute`, or owner/co-owner of story's live family on published story; never on parent's origin story from child family), D6b.
- **Port:** 26–28 (story, comment, perspective part), 43–45, 62–77, 83 (comment/perspective part), 93, 94; 137 (story part).
- **Live events:** `story` on publish, unpublish, updates or discard of published story; `note` on note create/update/delete (notes only exist on stories caller can contribute to). Draft edits post nothing.

### 3d Photos and media
- **Owns:** `PhotoEndpoint` (`list`, `startUpload`, `finishUpload`, `delete`, `setHero`), `MediaEndpoint` (`get`, `getMany`).
- **Rules:** business-rules §2.7 (rows except save/reset edit), §4.5; schema-design §4.2 (upload flow, sniffing, limits); endpoint-contract §2.0 (media authorizes by finding row holding key).
- **Port:** 25 (cover read: member of soft-deleted family can't read, D6b), 27, 46, 47, 78–83 (photo part), 90 (reads only).
- **Out of scope:** photo edit save/reset (business-rules §2.7, cases 84–89, 91). Client has no caller yet (`photos_api.dart` only reads `editedKey`), endpoint contract lists no such method.
- **Live events:** `photo` on finishUpload/delete/setHero of published story's photo.

### 3e Invites
- **Owns:** `InviteEndpoint`, `InvitePublicEndpoint` (`requireLogin => false`), invite email delivery. Reuse Resend transport in `lib/src/auth/login_code_sender.dart` by extracting, not copying.
- **Rules:** business-rules §2.9, §3.4, §4.7; schema-design §3.2 rows: invite create, invite accept, resend/revoke.
- **Decisions:** D2 (accept compares `accountEmail` with `invite.email`, both trimmed + lower-cased; mismatch → `inviteInvalid` "Invite was sent to a different email"), D3 (any live member creates + sends), D6a (accept into soft-deleted family → `inviteInvalid` "Invite is not valid"; both checks before accepted/re-entry check). Accept links person or calls `ensureLinkedPerson`.
- **Port:** 112–114, 117–119, 121–131, 133–135; 137 (invite read part). Old 503/502 email failures → `validation` errors, same messages ("Email is not configured", "Could not send invite email"), per business-rules §3.4.
- **Live events:** none.

### 3f Live streams, purge, blob drain
- **Owns:** `LiveEndpoint` (`watchFamily`, `watchStory`; authorize once at subscribe: `requireLiveMember` or tree reader for family; `canReadStory` for story), purge future call (schema-design §4.3 steps, D6c), blob drain future call (`drainBlobDeletions`), and their registration in `lib/server.dart` after `pod.start()` (cancel, then re-register, per serverpod-notes §9).
- **Port:** 20, 21 (purge, amended for queue), plus stream authz tests: member receives events, stranger refused at subscribe.
- **Live events:** consumes them.

---

## Exit criteria for Phase 3

- Every in-scope endpoint-contract §2.2 method exists, covered by ported §7 cases.
- `dart format --set-exit-if-changed`, `dart analyze` (server + client), `just server-test` pass on `feat/serverpod-migration`. `just test` (Flutter) still passes; app untouched.
- `just server` boots, applies migrations + constraints, registers both future calls without duplicates on second boot.
- Then write Phase 4 (client cutover) plan.

**Met on 2026-11-07 at `9e54065`:** format 0 changed; analyze clean server + client; `just server-test` +422; `just test` +708. `just server` booted 3× on one dev DB: every endpoint route answers 401 without session; `serverpod_future_call` holds one row each for `purge-families` and `drain-blobs`. Boot warning re missing foreign keys expected (schema-design §3.3 caveats).

**Missed by these checks, fixed in `f203a6d`:** `run()` never installed auth handler → every signed-in call on real server failed HTTP 500 (`UnimplementedError`). Integration tests inject identities via `AuthenticationOverride`; boot smoke only checked anonymous calls get 401; neither exercised real token. Phase 4 planning smoke against `just server` found it. `login_test` now authenticates real login token via `installAuthenticationHandler`; Phase 4 adds live client tests (`just test-live`) to catch this bug class.

**Decided by the product owner (2026-11-07, roadmap D10–D13):**
- D10: only owner of linked person's live home family sets death date, via `people.setDeathDate` (added, BR 138). Co-owners still toggle passed-away flag.
- D11: blob uploaded for story deleted before `finishUpload` stays in storage. Accepted; no sweep.
- D12: no unpublish endpoint.
- D13: email-code sign-up has no display name; new linked person falls back to email local part. Accepted.

**Still open:**
- `InvitePreviewDto` has no error code → preview can't tell accepted from expired. App shows one message for both anyway.
- Production needs `inviteAppOrigin` password set (no committed template).
- Generated client methods turn Dart param defaults into required named params (`createDraft.allowUndated`, `listLatestPublished.withinDays/limit`, `recents.limit`, `createBranch.personIds`). Phase 4 callers pass explicitly.