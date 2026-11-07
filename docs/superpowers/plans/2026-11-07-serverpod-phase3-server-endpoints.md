# Phase 3: Server Endpoints — Index

> **For agentic workers:** This is the Phase 3 index. Land 3.0 first with superpowers:executing-plans or superpowers:subagent-driven-development. Then each slice 3a–3f runs in parallel, on its own branch, from its own detailed plan (§Slice plans).

**Goal:** Implement every endpoint in `docs/migration/endpoint-contract.md` §2.2 that has a client caller, on Serverpod 4.1.1. Each endpoint is tested against the business rules as amended by the 2026-11-07 decisions (D1–D9), so that Phase 4 can switch the Flutter gateways over in one cutover.

**Architecture:** One endpoint class per resource under `apps/server/lib/src/endpoints/`, each owned by exactly one slice. Authorization, blob keys, the blob deletion queue, account helpers, live-event channels, DTOs and test fixtures come from 3.0 and are shared. Writes run in one transaction, queue old blob keys inside it, and post live events after it commits. The purge and the blob drain are recurring future calls owned by 3f.

**Tech Stack:** Dart 3.13.5, Serverpod 4.1.1, embedded Postgres 16, just.

**Spec of record:** `docs/migration/business-rules.md` §2, §3, §7 (as amended); `docs/migration/schema-design.md` §3.2, §3.5, §4; `docs/migration/endpoint-contract.md` §2; roadmap "Product decisions (2026-11-07)". If code and these docs disagree, stop and report the difference; don't reconcile silently.

---

## Status

| Part | Plan | Depends on | Status |
|---|---|---|---|
| 3.0 Shared foundation | `2026-11-07-serverpod-phase3-0-foundation.md` | — | landed (server tests 96/96) |
| 3a Families, places, profile | `2026-11-07-serverpod-phase3a-families.md` | 3.0 | plan written at slice start |
| 3b People | `2026-11-07-serverpod-phase3b-people.md` | 3.0 | plan written at slice start |
| 3c Stories, tags, notes, search | `2026-11-07-serverpod-phase3c-stories.md` | 3.0 | plan written at slice start |
| 3d Photos and media | `2026-11-07-serverpod-phase3d-photos-media.md` | 3.0 | plan written at slice start |
| 3e Invites | `2026-11-07-serverpod-phase3e-invites.md` | 3.0 | plan written at slice start |
| 3f Live streams, purge, blob drain | `2026-11-07-serverpod-phase3f-live-purge.md` | 3.0 | plan written at slice start |

No slice depends on another slice's code. Every cross-slice need (predicates, keys, the blob queue, `ensureLinkedPerson`, channel names, DTOs) is in 3.0.

## Slice plans

Each slice's executor writes its detailed plan with superpowers:writing-plans at slice start, on top of the landed 3.0. Like 3.0, the plan is verified by running its code in a scratch worktree before execution, so its code blocks are real. The slice table below is the scope contract for those plans: a slice plan covers every method and test case its row lists, and nothing outside it.

---

## Conventions (verified with a probe endpoint on 2026-11-07)

**Endpoint shape.** Each file is `apps/server/lib/src/endpoints/<name>_endpoint.dart`, and each class sets `requireLogin`:

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

- **Order of checks.** Authorization comes first, then existence, then validation, in the order business-rules §3 states for that operation. A missing or soft-deleted family is refused as `forbidden`, exactly like a stranger (`Authz.requireLive*`), so ids don't leak.
- **Errors.** Throw only `AppException`, through `lib/src/errors.dart` (`forbidden`, `notFound`, `validation`, `conflict`) or `AppException(code: AppErrorCode.inviteInvalid | inviteAccepted | inviteExpired | photoCap | storageFailed, …)`. Messages are the business-rules §5.2 strings. Never return raw database text. Catch a known constraint violation (`DatabaseQueryException.code`) only to map it to a catalogue message; anything else propagates.
- **Transactions.** Pass `transaction: t` to every DB call inside `session.db.transaction`. Lock the parent row (`lockMode: LockMode.forUpdate`) wherever schema-design §3.2 asks for a lock (co-owner cap, photo cap, kinship cycle).
- **Linked-person race.** `ensureLinkedPerson` can lose a race on `people_tree_user_uidx`, for example on a double-tapped invite accept, or when a branch is created while that member accepts an invite. The losing transaction fails with `23505`. `createBranch` (3a) and `InviteEndpoint.accept` (3e) catch a `DatabaseQueryException` with code `23505` and constraint `people_tree_user_uidx` and rerun their transaction once; the rerun finds the committed person. Pin this with a test that inserts the person between the lookup and the insert, or that runs two accepts concurrently.
- **Blobs.** Never call `deleteFile` from an endpoint. Old keys go through `queueBlobDeletions(session, keys, transaction: t)` inside the write transaction. New keys come from `blob_keys.dart`. Uploaded bytes are checked with `sniffImageMime` before a row is written.
- **Live events.** Call `postLiveEvent(session, LiveEventDto(...))` after `session.db.transaction` returns, never inside it. Story, photo and note writes post (kinds `story`, `photo`, `note`); family-level writes don't.
- **Anonymous callers** never reach a method body: `requireLogin` makes Serverpod throw `ServerpodUnauthenticatedException`. Don't add per-method anonymous tests. One test per endpoint class is enough.

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

- `RollbackDatabase.disabled` everywhere: the endpoints use transactions and streams. Each test builds its own users and trees through `Fx`, so tests stay independent on the shared database.
- Name tests by the business-rules §7 case they port (`// BR 117`) and keep its given/when/then wording.
- Streams: subscribe, wait about 50 ms so the listener is registered, then write, then `await first.timeout(...)`. The probe confirmed this works with `postLiveEvent`.
- Slice-only builders go in `test/integration/support/<slice>_fixtures.dart`. `fixtures.dart` changes only by appending a method, so parallel merges stay trivial.

## Shared files and merging

- **Generated code.** Adding an endpoint changes `apps/server/lib/src/generated/endpoints.dart`, `apps/server/test/integration/test_tools/serverpod_test_tools.dart` and `packages/tell_me_a_story_client/lib/src/protocol/client.dart`. On a merge conflict in any generated file, take either side and run `mise exec -- just server-generate`; never hand-merge generated code.
- **New models or migrations.** No slice needs a table change. If one turns out to, stop and report it (schema-design is the spec), because two slices creating migrations at once would collide in `migration_registry.txt`.
- **`lib/server.dart`** is owned by 3f, which registers the future calls.
- **Branches.** Each slice runs on `feat/p3<x>-<name>` off the 3.0 commit and merges back into `feat/serverpod-migration` with `--no-ff`. After each merge, regenerate and run `just server-test`.

---

## Slices

The test case numbers are business-rules §7. "Port" means rewrite as a Serverpod integration test with the same given/when/then. Where a decision changed the expected outcome, the amended §7 text is already the target.

### 3a Families, places, profile
- **Owns:** `FamilyEndpoint` (all methods in endpoint-contract §2.2, cover upload included), `PlaceEndpoint`, `ProfileEndpoint` (avatar included).
- **Rules:** business-rules §2.1, §2.2, §2.4, §2.10, §3.1–§3.3, §3.5 (soft delete and recover; purge is 3f), §3.6; schema-design §3.2 rows: co-owner cap, origin, immutables, soft delete/recover, createRoot, createBranch (D6d), removeMember, places, linked person name; §3.5 effective origin (use `Authz.effectiveOrigin`).
- **Decisions:** D6b (live checks; owner/co-owner may still read a soft-deleted family's row and memberships, through `listStewarded`/`directory`/`detail`), D6d (`ensureLinkedPerson` for the new owner and each picked member), D8 (`listTree` = live families with the same `treeId`), D1 (no email change; `me` returns the email read-only).
- **Port:** 1–19, 22, 29–32, 34–42, 48, 50–60, 106, 107, 109–111, 115; 137 (place part). Cases 23–24 change shape, because the server now makes the cover key: a steward's upload is stored and a plain member is refused (23); non-image bytes, oversize files and an unsupported type are refused with `VALIDATION` (24). Case 61 (Edge request checks) becomes Dart argument checks: a blank name and year bounds still give `VALIDATION`. Case 49 is superseded, because places are tree-wide (business-rules §8 item 1).
- **Live events:** none.

### 3b People
- **Owns:** `PeopleEndpoint`: `listFamily`, `listTree`, `create`, `forEdit`, `profile`, `update`, `listUnlinked`, `isHomeFamilySteward`, `markPassedAway`, `delete`. Person pictures are written inline through `create`/`update` (`personAvatarKey`, old key queued).
- **Rules:** business-rules §2.3, §4.6 (DOB coarsening by `birthVisibility`); schema-design §3.2 rows: passedAway, life dates, linked person name lock, person delete (D5), unlinked picker.
- **Decisions:** D5 (`delete`: owner/co-owner of the live home family; linked → `VALIDATION: person is linked to an account`).
- **Port:** 95–105, 108, 116, 120, 136; 26 and 28 (people part).
- **Out of scope:** `listKinships`/`addKinship`/`removeKinship`. Endpoint-contract §2.2 marks them contract-only until a UX spec exists.
- **Live events:** none.

### 3c Stories, tags, notes, search
- **Owns:** `StoryEndpoint` (all methods, including `search` and `facets` with the semantics under endpoint-contract §2.2), `NoteEndpoint`.
- **Rules:** business-rules §2.5, §2.6, §2.8, §4.4, §4.8; schema-design §3.2 rows: story locks, notes body-only, notes delete (D4); §0.5 named orders.
- **Decisions:** D4 (`NoteEndpoint.delete` and `NoteDto.canDelete`: the author with `canContribute`, or an owner/co-owner of the story's live family on a published story; never on the parent's origin story from a child family), D6b.
- **Port:** 26–28 (story, comment and perspective part), 43–45, 62–77, 83 (comment/perspective part), 93, 94; 137 (story part).
- **Live events:** `story` on create/update/publish/discard, `note` on note create/update/delete.

### 3d Photos and media
- **Owns:** `PhotoEndpoint` (`list`, `startUpload`, `finishUpload`, `delete`, `setHero`), `MediaEndpoint` (`get`, `getMany`).
- **Rules:** business-rules §2.7 (rows except save/reset edit), §4.5; schema-design §4.2 (upload flow, sniffing, limits); endpoint-contract §2.0 (media authorizes by finding the row that holds the key).
- **Port:** 25 (cover read: a member of a soft-deleted family cannot read it, D6b), 27, 46, 47, 78–83 (photo part), 90 (reads only).
- **Out of scope:** photo edit save/reset (business-rules §2.7, cases 84–89, 91). The client has no caller yet (`photos_api.dart` only reads `editedKey`), and the endpoint contract lists no such method.
- **Live events:** `photo` on finishUpload/delete/setHero.

### 3e Invites
- **Owns:** `InviteEndpoint`, `InvitePublicEndpoint` (`requireLogin => false`), and invite email delivery. Reuse the Resend transport in `lib/src/auth/login_code_sender.dart` by extracting it, not copying it.
- **Rules:** business-rules §2.9, §3.4, §4.7; schema-design §3.2 rows: invite create, invite accept, resend/revoke.
- **Decisions:** D2 (accept compares `accountEmail` with `invite.email`, both trimmed and lower-cased; mismatch → `inviteInvalid` "Invite was sent to a different email"), D3 (any live member creates and sends), D6a (accept into a soft-deleted family → `inviteInvalid` "Invite is not valid"; both checks before the accepted/re-entry check). Accept links the person or calls `ensureLinkedPerson`.
- **Port:** 112–114, 117–119, 121–131, 133–135; 137 (invite read part). The old 503/502 email failures become `validation` errors with the same messages ("Email is not configured", "Could not send invite email"), per business-rules §3.4.
- **Live events:** none.

### 3f Live streams, purge, blob drain
- **Owns:** `LiveEndpoint` (`watchFamily`, `watchStory`; authorize once at subscribe: `requireLiveMember` or tree reader for the family; `canReadStory` for the story), the purge future call (schema-design §4.3 steps, D6c), the blob drain future call (`drainBlobDeletions`), and their registration in `lib/server.dart` after `pod.start()` (cancel, then re-register, per serverpod-notes §9).
- **Port:** 20, 21 (purge, as amended for the queue), plus stream authorization tests: a member receives events, a stranger is refused at subscribe.
- **Live events:** consumes them.

---

## Exit criteria for Phase 3

- Every endpoint-contract §2.2 method that is in scope above exists and is covered by ported §7 cases.
- `dart format --set-exit-if-changed`, `dart analyze` (server and client) and `just server-test` pass on `feat/serverpod-migration`. `just test` (Flutter) still passes; the app is untouched.
- `just server` boots, applies migrations and constraints, and registers both future calls without duplicates on a second boot.
- Then write the Phase 4 (client cutover) plan.
