# Phase 3a: Families, Places, Profile — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `FamilyEndpoint` (every method in endpoint-contract §2.2, cover upload included), `PlaceEndpoint` and `ProfileEndpoint` (inline avatar included) on Serverpod 4.1.1, with the business-rules §7 cases listed for slice 3a ported as integration tests.

**Architecture:** Three endpoint classes under `apps/server/lib/src/endpoints/`, built on the landed 3.0 foundation: `Authz` for every check (live checks everywhere except the recovery reads, D6b), `ensureLinkedPerson` for createRoot/createBranch (D6d), `blob_keys.dart` for server-made keys and `queueBlobDeletions` for every replaced key. Writes run in one `session.db.transaction`, locking the family row where schema-design §3.2 asks. No live events (family-level writes don't post). No schema change, no new DTO.

**Tech Stack:** Dart 3.13.5, Serverpod 4.1.1, embedded Postgres 16, just, mise.

**Spec of record:** `docs/superpowers/plans/2026-11-07-serverpod-phase3-server-endpoints.md` (row "3a" and §Conventions), `docs/migration/endpoint-contract.md` §2.0–§2.2, `docs/migration/business-rules.md` §2.1, §2.2, §2.4, §2.10, §3.1–§3.3, §3.5, §3.6, §5.2, §7, `docs/migration/schema-design.md` §3.2, §3.5, §4.

---

## Decisions this plan takes (inside the slice)

- **Order of checks** follows business-rules §3 per method; authorization first. A missing or soft-deleted family is FORBIDDEN like a stranger (`Authz.requireLive*`), except the recovery reads (`listStewarded`, `directory`, `detail`) and `recover`, which use the caller's (possibly deleted) steward membership.
- **`detail`** throws FORBIDDEN (`member only`) for a non-member or missing family and `owner or co-owner only` for a plain member of a deleted family, so it never returns null although the contract type is nullable. On a deleted family it returns the members and an empty `pendingInvites` (D6b).
- **`listTree`** and **`listOriginDependents`** return an empty list to callers who can't read them, as `list_family_tree` / `list_origin_dependents` did (BR 30, 48).
- **`setOrigin`** keeps the bare FORBIDDEN of `set_family_origin` (`errors.dart` default message) and uses `NOT_FOUND: story` for the story check.
- **`softDelete`** uses `requireLiveOwner`, so repeating it on an already-deleted family is FORBIDDEN rather than a no-op (Conventions: live checks everywhere but recovery). It only sets `deletedAt`; the purge is 3f.
- **`removeMember`** walks every family with the family's `treeId`, soft-deleted ones included (business-rules §6 item 9), and unlinks the target's person in that tree.
- **`createBranch` depth** walks `parentId` through deleted families too (D8: a deleted family doesn't split the tree).
- **Covers:** `startCoverUpload` validates `mimeType` with `extForMime` (`unsupported image type`) and the declared size (`file is empty` / `file is too large`), then pins it with `UploadOptions(maxFileSize: coverMaxBytes, contentLength: byteLength, preventOverwrite: true)`. `finishCoverUpload` accepts only keys of the shape `families/{familyId}/cover/{uuid}.{jpg|png|webp}` (`invalid cover key`), `verifyUpload`s (`upload not found`), re-checks the stored size and sniffs the bytes against the key's extension; a rejected upload is queued in `blob_deletions`. Finishing with the current cover key is a no-op that returns it.
- **Profile:** `me` creates the `users` row if the auth hook didn't (`ensureAppUser` fallback). `saveName`/`saveAccount` store a blank display name as null and then don't touch linked names (BR 107); otherwise every linked person in every tree takes the new name in the same transaction. `saveAccount` aligns the birth date to its precision at UTC midnight and checks year 1000–9999 and `about` ≤ 500 with local VALIDATION messages; a null `birthVisibility` keeps the current one. `saveAvatar` accepts JPEG ≤ 2 MiB (sniffed), stores it under `userAvatarKey` with `preventOverwrite`, then swaps the key and queues the old one.
- **Places:** reads and writes need the family to be live and the caller to read its tree (`Authz.isTreeReadable`, member or tree reader, D6b); place rows are checked by `treeId` (`isTreeMemberOf`). `create` trims and requires label and address, returns the existing row for a known `(treeId, mapboxPlaceId)` (also on a lost insert race), and stamps `lastUsedAt`. `get` returns null for a missing or unreadable place.
- **Generated client:** Serverpod 4.1.1 drops parameter defaults on the client, so `createBranch(personIds:)` and `recents(limit:)` are required named parameters in the client and test tools; the server keeps the contract defaults.

## Not ported, or ported in another shape

- BR 3, 55 (null session): one `ServerpodUnauthenticatedException` test per endpoint class (Conventions).
- BR 14, 22, 39 (direct client writes): no endpoint writes memberships directly or touches `id`/`createdById`/`parentId`/`treeId`/`originStoryId` outside setOrigin; the tests pin that the API leaves them unchanged.
- BR 18: family-level parts only (members, tree, places). Stories, people and photos of a deleted family are 3b–3d reads on the same `Authz` predicates.
- BR 23/24: reshaped per the index (server-made keys).
- BR 49: superseded (places are tree-wide, business-rules §8 item 1).
- BR 61: Dart argument checks (blank name, year bounds) — the null/uuid-shape parts can't occur with typed parameters.
- BR 106: "a later direct rename still raises" is the people endpoint's linked-name lock (3b).
- BR 107: "invite accept with null display name" is 3e; the email-local-part fallback is covered through createRoot.
- BR 109: OTP sign-up has no metadata display name and the 3.0 auth hook creates `users` with a null display name; ported as "me returns the stored display name and the login email".
- BR 110: avatar *reads* are `MediaEndpoint` (3d); ported through `listMembers` (co-member sees name and avatar key, stranger FORBIDDEN) and `saveAvatar` only writing the caller's own row.

## File map

| File | Responsibility |
|---|---|
| `apps/server/lib/src/endpoints/profile_endpoint.dart` | `ProfileEndpoint`: me, saveName, saveAccount, saveAvatar, clearAvatar; linked-name sync |
| `apps/server/lib/src/endpoints/place_endpoint.dart` | `PlaceEndpoint`: list, favorites, recents, create, markUsed, setFavorite, findByMapboxId, get |
| `apps/server/lib/src/endpoints/family_endpoint.dart` | `FamilyEndpoint`: all §2.2 family methods |
| `apps/server/test/integration/support/families_fixtures.dart` | Slice-only `Fx` extension: simulated uploads, queued keys, role/linked-person lookups, family/story row tweaks |
| `apps/server/test/integration/profile_endpoint_test.dart` | ProfileEndpoint tests |
| `apps/server/test/integration/place_endpoint_test.dart` | PlaceEndpoint tests |
| `apps/server/test/integration/family_endpoint_test.dart` | FamilyEndpoint tests, one group per task |
| generated (`endpoints.dart`, `serverpod_test_tools.dart`, client `client.dart` + protocol) | `just server-generate` after each endpoint change; never edited by hand |

Run every command from the worktree root unless it starts with `cd`.

---

### Task 1: ProfileEndpoint

**Files:**
- Create: `apps/server/lib/src/endpoints/profile_endpoint.dart`
- Test: `apps/server/test/integration/profile_endpoint_test.dart`
- Create: `apps/server/test/integration/support/families_fixtures.dart`
- Regenerate: `apps/server/lib/src/generated/endpoints.dart`, `apps/server/test/integration/test_tools/serverpod_test_tools.dart`, `packages/tell_me_a_story_client/lib/src/protocol/client.dart`

Ports: BR 106, 107, 109, 111 (and 110 write part).

- [ ] **Step 1: Add the slice fixtures**

`apps/server/test/integration/support/families_fixtures.dart`:

```dart
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/media/blob_keys.dart';

import 'fixtures.dart';

/// Smallest byte strings [sniffImageMime] recognizes.
final jpegBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0];
final pngBytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0];
final svgBytes = '<svg xmlns="http://www.w3.org/2000/svg"/>'.codeUnits;

ByteData byteData(List<int> bytes) =>
    ByteData.sublistView(Uint8List.fromList(bytes));

/// A unique email, so tests never collide on the email-account index.
String uniqueEmail([String local = 'user']) =>
    '$local-${const Uuid().v4()}@example.com';

/// Builders for slice 3a (families, places, profile).
extension FamiliesFx on Fx {
  /// What a client upload through a `createUploadDescription` URL leaves in
  /// the dev database storage: an unverified file at [key].
  Future<void> upload(String key, List<int> bytes) =>
      (s.server.serverpod.storage[blobStorageId]! as DatabaseCloudStorage)
          .storeUnverifiedFile(
            session: s,
            path: key,
            byteData: byteData(bytes),
          );

  Future<Set<String>> queuedBlobKeys() async => {
    for (final row in await BlobDeletion.db.find(s)) row.key,
  };

  Future<Family> reload(Family family) async =>
      (await Family.db.findById(s, family.id!))!;

  Future<MembershipRole?> roleOf(Family family, UuidValue user) async =>
      (await Membership.db.findFirstRow(
        s,
        where: (t) => t.familyId.equals(family.id!) & t.userId.equals(user),
      ))?.role;

  Future<List<Person>> linkedPeople(UuidValue treeId, UuidValue user) =>
      Person.db.find(
        s,
        where: (t) => t.treeId.equals(treeId) & t.userId.equals(user),
      );

  /// A root family in a new tree with [owner] as owner.
  Future<Family> rootOwnedBy(UuidValue owner, {String name = 'Root'}) async {
    final family = await this.family(await tree(), name: name);
    await join(family, owner, MembershipRole.owner);
    return family;
  }

  /// A live child of [parent] in the same tree, owned by [owner].
  Future<Family> childOf(
    Family parent, {
    UuidValue? owner,
    String name = 'Child',
    int branchYear = 1990,
    DateTime? deletedAt,
  }) async {
    final child = await Family.db.insertRow(
      s,
      Family(
        treeId: parent.treeId,
        parentId: parent.id,
        name: name,
        branchYear: branchYear,
        deletedAt: deletedAt,
      ),
    );
    if (owner != null) await join(child, owner, MembershipRole.owner);
    return child;
  }

  Future<Family> setOriginRow(Family family, Story? story) =>
      Family.db.updateRow(
        s,
        family.copyWith(originStoryId: story?.id),
        columns: (c) => [c.originStoryId],
      );

  Future<Family> setDeletedAt(Family family, DateTime? deletedAt) =>
      Family.db.updateRow(
        s,
        family.copyWith(deletedAt: deletedAt),
        columns: (c) => [c.deletedAt],
      );

  Future<Story> setStatus(Story story, StoryStatus status) =>
      Story.db.updateRow(
        s,
        story.copyWith(
          status: status,
          publishedAt: status == StoryStatus.published
              ? DateTime.now().toUtc()
              : null,
        ),
        columns: (c) => [c.status, c.publishedAt],
      );
}
```

- [ ] **Step 2: Write the failing tests**

`apps/server/test/integration/profile_endpoint_test.dart`:

```dart
import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'support/families_fixtures.dart';
import 'support/fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given ProfileEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    setUp(() => fx = Fx(sessionBuilder.build()));

    Future<AppUser> appUser(UuidValue user) async =>
        (await AppUser.db.findFirstRow(
          fx.s,
          where: (t) => t.authUserId.equals(user),
        ))!;

    test('when signed out then the call is rejected before the body', () async {
      await expectLater(
        endpoints.profile.me(sessionBuilder),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    // BR 109
    test(
      'when a signed-up account reads me then it gets its display name and '
      'its login email, read-only',
      () async {
        final email = uniqueEmail('ada');
        final user = await fx.userWithEmail(email, displayName: 'Ada');
        final me = await endpoints.profile.me(asUser(sessionBuilder, user));
        expect(me.authUserId, user);
        expect(me.displayName, 'Ada');
        expect(me.email, email);
        expect(me.birthVisibility, BirthVisibility.hidden);
      },
    );

    test('when the users row is missing then me creates it', () async {
      final user = await fx.user();
      await AppUser.db.deleteWhere(
        fx.s,
        where: (t) => t.authUserId.equals(user),
      );
      final me = await endpoints.profile.me(asUser(sessionBuilder, user));
      expect(me.authUserId, user);
      expect(me.email, isNull);
      expect(await appUser(user), isNotNull);
    });

    // BR 106
    test(
      'when the display name changes then every linked person in any tree '
      'takes it and unlinked people are untouched',
      () async {
        final user = await fx.user();
        final a = await fx.family(await fx.tree());
        final b = await fx.family(await fx.tree());
        final linkedA = await fx.person(a, userId: user, name: 'Old');
        final linkedB = await fx.person(b, userId: user, name: 'Old');
        final unlinked = await fx.person(a, name: 'Other');

        await endpoints.profile.saveName(
          asUser(sessionBuilder, user),
          '  New Name ',
        );

        expect((await appUser(user)).displayName, 'New Name');
        for (final p in [linkedA, linkedB]) {
          expect((await Person.db.findById(fx.s, p.id!))!.name, 'New Name');
        }
        expect((await Person.db.findById(fx.s, unlinked.id!))!.name, 'Other');
      },
    );

    // BR 107
    test(
      'when the display name is whitespace then no error and linked names '
      'keep their previous value',
      () async {
        final user = await fx.user();
        final home = await fx.family(await fx.tree());
        final linked = await fx.person(home, userId: user, name: 'Kept');

        await endpoints.profile.saveName(asUser(sessionBuilder, user), '   ');

        expect((await appUser(user)).displayName, isNull);
        expect((await Person.db.findById(fx.s, linked.id!))!.name, 'Kept');
      },
    );

    test(
      'when saving the account then name, birth (aligned to its precision), '
      'visibility and about are stored and linked names follow',
      () async {
        final user = await fx.user();
        final home = await fx.family(await fx.tree());
        final linked = await fx.person(home, userId: user, name: 'Old');

        await endpoints.profile.saveAccount(
          asUser(sessionBuilder, user),
          displayName: 'Grace',
          birthDate: DateTime.utc(1950, 6, 17),
          birthPrecision: DatePrecision.month,
          birthVisibility: BirthVisibility.year,
          about: ' Writer ',
        );

        final me = await endpoints.profile.me(asUser(sessionBuilder, user));
        expect(me.displayName, 'Grace');
        expect(me.birthDate, DateTime.utc(1950, 6));
        expect(me.birthPrecision, DatePrecision.month);
        expect(me.birthVisibility, BirthVisibility.year);
        expect(me.about, 'Writer');
        expect((await Person.db.findById(fx.s, linked.id!))!.name, 'Grace');

        await endpoints.profile.saveAccount(
          asUser(sessionBuilder, user),
          displayName: 'Grace',
        );
        final cleared = await endpoints.profile.me(
          asUser(sessionBuilder, user),
        );
        expect(cleared.birthDate, isNull);
        expect(cleared.birthPrecision, isNull);
        expect(cleared.birthVisibility, BirthVisibility.year);
        expect(cleared.about, isNull);
      },
    );

    test('when saving the account with bad input then VALIDATION', () async {
      final user = await fx.user();
      final session = asUser(sessionBuilder, user);
      await expectLater(
        endpoints.profile.saveAccount(
          session,
          displayName: 'A',
          birthDate: DateTime.utc(1950),
        ),
        throwsAppError(AppErrorCode.validation, 'birth precision is required'),
      );
      await expectLater(
        endpoints.profile.saveAccount(
          session,
          displayName: 'A',
          birthDate: DateTime.utc(999),
          birthPrecision: DatePrecision.year,
        ),
        throwsAppError(
          AppErrorCode.validation,
          'birth year must be four digits',
        ),
      );
      await expectLater(
        endpoints.profile.saveAccount(
          session,
          displayName: 'A',
          about: 'x' * 501,
        ),
        throwsAppError(
          AppErrorCode.validation,
          'about must be at most 500 characters',
        ),
      );
    });

    // BR 111
    test(
      'when saving an avatar then a fresh users/{uid}/avatar key is stored '
      'and the previous key is queued for deletion',
      () async {
        final user = await fx.user();
        final session = asUser(sessionBuilder, user);

        final first = await endpoints.profile.saveAvatar(
          session,
          byteData(jpegBytes),
        );
        expect(
          first,
          matches(RegExp('^users/${user.uuid}/avatar/[0-9a-f-]{36}\\.jpg\$')),
        );
        final second = await endpoints.profile.saveAvatar(
          session,
          byteData(jpegBytes),
        );

        expect(second, isNot(first));
        expect((await appUser(user)).avatarKey, second);
        expect(await fx.queuedBlobKeys(), contains(first));
        final stored = await fx.s.storage.retrieveFile(
          storageId: 'private',
          path: second,
        );
        expect(stored.lengthInBytes, jpegBytes.length);
      },
    );

    // BR 111
    test(
      'when the avatar is not a JPEG or too large then VALIDATION',
      () async {
        final user = await fx.user();
        final session = asUser(sessionBuilder, user);
        await expectLater(
          endpoints.profile.saveAvatar(session, byteData(pngBytes)),
          throwsAppError(AppErrorCode.validation, 'unsupported image type'),
        );
        await expectLater(
          endpoints.profile.saveAvatar(
            session,
            byteData([...jpegBytes, ...List.filled(2097152, 0)]),
          ),
          throwsAppError(AppErrorCode.validation, 'file is too large'),
        );
        expect((await appUser(user)).avatarKey, isNull);
      },
    );

    test(
      'when clearing the avatar then the key is queued and nulled',
      () async {
        final user = await fx.user();
        final session = asUser(sessionBuilder, user);
        final key = await endpoints.profile.saveAvatar(
          session,
          byteData(jpegBytes),
        );

        await endpoints.profile.clearAvatar(session);

        expect((await appUser(user)).avatarKey, isNull);
        expect(await fx.queuedBlobKeys(), contains(key));
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 3: Run them to verify they fail**

Run: `cd apps/server && mise exec -- dart test test/integration/profile_endpoint_test.dart`
Expected: compile error — `endpoints.profile` does not exist.

- [ ] **Step 4: Implement**

`apps/server/lib/src/endpoints/profile_endpoint.dart`:

```dart
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../accounts/accounts.dart';
import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';
import '../media/blob_keys.dart';
import '../media/blob_outbox.dart';

/// The caller's own account (business-rules.md §2.10). Email is the login
/// identity and read-only (D1); account deletion is not offered (D7).
class ProfileEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<OwnProfileDto> me(Session session) async {
    final uid = Authz(session).requireUser();
    final user = await _ensureAppUser(session, uid);
    return OwnProfileDto(
      authUserId: uid,
      displayName: user.displayName,
      email: await accountEmail(session, uid),
      avatarKey: user.avatarKey,
      birthDate: user.birthDate,
      birthPrecision: user.birthPrecision,
      birthVisibility: user.birthVisibility,
      about: user.about,
    );
  }

  /// Sets the display name (blank clears it) and renames every person linked
  /// to the caller, in every tree. A blank name leaves linked names alone.
  Future<void> saveName(Session session, String displayName) async {
    final uid = Authz(session).requireUser();
    final name = _trimmedOrNull(displayName);
    await _ensureAppUser(session, uid);
    await session.db.transaction((t) async {
      final user = await _lockAppUser(session, uid, t);
      await AppUser.db.updateRow(
        session,
        user.copyWith(displayName: name, updatedAt: _now()),
        transaction: t,
      );
      await _syncLinkedNames(session, uid, name, t);
    });
  }

  /// One Save of the account form: display name, birth and about are written
  /// as given (null clears); a null [birthVisibility] keeps the current one.
  Future<void> saveAccount(
    Session session, {
    required String displayName,
    DateTime? birthDate,
    DatePrecision? birthPrecision,
    BirthVisibility? birthVisibility,
    String? about,
  }) async {
    final uid = Authz(session).requireUser();
    final name = _trimmedOrNull(displayName);
    final birth = _normalizedBirth(birthDate, birthPrecision);
    final aboutText = _trimmedOrNull(about ?? '');
    if (aboutText != null && aboutText.length > 500) {
      throw validation('about must be at most 500 characters');
    }
    await _ensureAppUser(session, uid);
    await session.db.transaction((t) async {
      final user = await _lockAppUser(session, uid, t);
      await AppUser.db.updateRow(
        session,
        user.copyWith(
          displayName: name,
          birthDate: birth?.$1,
          birthPrecision: birth?.$2,
          birthVisibility: birthVisibility ?? user.birthVisibility,
          about: aboutText,
          updatedAt: _now(),
        ),
        transaction: t,
      );
      await _syncLinkedNames(session, uid, name, t);
    });
  }

  /// Stores a JPEG (≤ 2 MiB) under a fresh key and points the account at it;
  /// the previous key is queued for deletion in the same transaction.
  Future<String> saveAvatar(Session session, ByteData jpeg) async {
    final uid = Authz(session).requireUser();
    if (jpeg.lengthInBytes > avatarMaxBytes) {
      throw validation('file is too large');
    }
    if (sniffImageMime(jpeg) != 'image/jpeg') {
      throw validation('unsupported image type');
    }
    await _ensureAppUser(session, uid);
    final key = userAvatarKey(authUserId: uid);
    await session.storage.storeFile(
      storageId: blobStorageId,
      path: key,
      byteData: jpeg,
      options: const StoreFileOptions(
        preventOverwrite: true,
        metadata: FileMetadata(contentType: 'image/jpeg'),
      ),
    );
    try {
      await session.db.transaction((t) async {
        final user = await _lockAppUser(session, uid, t);
        await queueBlobDeletions(session, [user.avatarKey], transaction: t);
        await AppUser.db.updateRow(
          session,
          user.copyWith(avatarKey: key, updatedAt: _now()),
          transaction: t,
        );
      });
    } catch (_) {
      await queueBlobDeletions(session, [key]);
      rethrow;
    }
    return key;
  }

  Future<void> clearAvatar(Session session) async {
    final uid = Authz(session).requireUser();
    await _ensureAppUser(session, uid);
    await session.db.transaction((t) async {
      final user = await _lockAppUser(session, uid, t);
      if (user.avatarKey == null) return;
      await queueBlobDeletions(session, [user.avatarKey], transaction: t);
      await AppUser.db.updateRow(
        session,
        user.copyWith(avatarKey: null, updatedAt: _now()),
        transaction: t,
      );
    });
  }
}

DateTime _now() => DateTime.now().toUtc();

String? _trimmedOrNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// The `users` row is created by the auth hook; this is the fallback for an
/// account that predates it.
Future<AppUser> _ensureAppUser(Session session, UuidValue uid) async {
  final existing = await AppUser.db.findFirstRow(
    session,
    where: (t) => t.authUserId.equals(uid),
  );
  if (existing != null) return existing;
  try {
    return await AppUser.db.insertRow(session, AppUser(authUserId: uid));
  } on DatabaseQueryException catch (e) {
    if (e.code != '23505') rethrow;
    final raced = await AppUser.db.findFirstRow(
      session,
      where: (t) => t.authUserId.equals(uid),
    );
    return raced!;
  }
}

Future<AppUser> _lockAppUser(
  Session session,
  UuidValue uid,
  Transaction t,
) async {
  final user = await AppUser.db.findFirstRow(
    session,
    where: (u) => u.authUserId.equals(uid),
    transaction: t,
    lockMode: LockMode.forUpdate,
  );
  return user!;
}

/// Linked person name = display name (schema-design.md §3.2); a blank name
/// keeps the existing person names.
Future<void> _syncLinkedNames(
  Session session,
  UuidValue uid,
  String? name,
  Transaction t,
) async {
  if (name == null) return;
  await Person.db.updateWhere(
    session,
    columnValues: (p) => [p.name(name), p.updatedAt(_now())],
    where: (p) => p.userId.equals(uid),
    transaction: t,
  );
}

/// Birth date aligned to [precision] at UTC midnight, or null when no date.
(DateTime, DatePrecision)? _normalizedBirth(
  DateTime? date,
  DatePrecision? precision,
) {
  if (date == null) return null;
  if (precision == null) throw validation('birth precision is required');
  if (date.year < 1000 || date.year > 9999) {
    throw validation('birth year must be four digits');
  }
  final aligned = switch (precision) {
    DatePrecision.year => DateTime.utc(date.year),
    DatePrecision.month => DateTime.utc(date.year, date.month),
    DatePrecision.day => DateTime.utc(date.year, date.month, date.day),
  };
  return (aligned, precision);
}
```

- [ ] **Step 5: Regenerate and run the tests**

Run: `mise exec -- just server-generate` then `cd apps/server && mise exec -- dart test test/integration/profile_endpoint_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/server/lib/src/endpoints/profile_endpoint.dart apps/server/test/integration/profile_endpoint_test.dart apps/server/test/integration/support/families_fixtures.dart apps/server/lib/src/generated apps/server/test/integration/test_tools packages/tell_me_a_story_client
git commit -m "feat(server): ProfileEndpoint with linked-name sync and inline avatar"
```

### Task 2: PlaceEndpoint

**Files:**
- Create: `apps/server/lib/src/endpoints/place_endpoint.dart`
- Test: `apps/server/test/integration/place_endpoint_test.dart`
- Regenerate: `apps/server/lib/src/generated/endpoints.dart`, `apps/server/test/integration/test_tools/serverpod_test_tools.dart`, `packages/tell_me_a_story_client/lib/src/protocol/client.dart`

Ports: BR 137 (place part).

- [ ] **Step 1: Write the failing tests**

`apps/server/test/integration/place_endpoint_test.dart`:

```dart
import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'support/families_fixtures.dart';
import 'support/fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given PlaceEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    late UuidValue member, childMember, stranger;
    late Tree tree;
    late Family root, child;

    PlaceInputDto input(String label, {String? mapboxPlaceId}) => PlaceInputDto(
      label: label,
      address: '1 Main St',
      lat: 1.5,
      lng: 2.5,
      mapboxPlaceId: mapboxPlaceId,
      isFavorite: false,
    );

    setUp(() async {
      fx = Fx(sessionBuilder.build());
      member = await fx.user();
      childMember = await fx.user();
      stranger = await fx.user();
      tree = await fx.tree();
      root = await fx.family(tree);
      child = await fx.childOf(root, owner: childMember);
      await fx.join(root, member);
      await fx.join(await fx.family(await fx.tree()), stranger);
    });

    test('when signed out then the call is rejected before the body', () async {
      await expectLater(
        endpoints.place.list(sessionBuilder, root.id!),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    test(
      'when a member creates a place then every family in the tree lists it',
      () async {
        final created = await endpoints.place.create(
          asUser(sessionBuilder, member),
          root.id!,
          input('  Farm '),
        );
        expect(created.label, 'Farm');
        expect(created.treeId, root.treeId);
        expect(created.lastUsedAt, isNotNull);

        final fromChild = await endpoints.place.list(
          asUser(sessionBuilder, childMember),
          child.id!,
        );
        expect(fromChild.map((p) => p.id), [created.id]);
        expect(
          await endpoints.place.get(
            asUser(sessionBuilder, childMember),
            created.id,
          ),
          isNotNull,
        );
      },
    );

    test('when a stranger reads or writes then FORBIDDEN or null', () async {
      final place = await fx.place(tree);
      final session = asUser(sessionBuilder, stranger);
      await expectLater(
        endpoints.place.list(session, root.id!),
        throwsAppError(AppErrorCode.forbidden),
      );
      await expectLater(
        endpoints.place.create(session, root.id!, input('X')),
        throwsAppError(AppErrorCode.forbidden),
      );
      await expectLater(
        endpoints.place.setFavorite(session, place.id!, true),
        throwsAppError(AppErrorCode.forbidden),
      );
      await expectLater(
        endpoints.place.markUsed(session, place.id!),
        throwsAppError(AppErrorCode.forbidden),
      );
      expect(await endpoints.place.get(session, place.id!), isNull);
    });

    // BR 137 (place part)
    test(
      'when a member creates a place through a soft-deleted family then '
      'FORBIDDEN and nothing changes',
      () async {
        final gone = await fx.childOf(
          root,
          owner: member,
          name: 'Gone',
          deletedAt: DateTime.now().toUtc(),
        );
        final before = await Place.db.count(
          fx.s,
          where: (t) => t.treeId.equals(root.treeId),
        );
        await expectLater(
          endpoints.place.create(
            asUser(sessionBuilder, member),
            gone.id!,
            input('Nope'),
          ),
          throwsAppError(AppErrorCode.forbidden),
        );
        await expectLater(
          endpoints.place.list(asUser(sessionBuilder, member), gone.id!),
          throwsAppError(AppErrorCode.forbidden),
        );
        expect(
          await Place.db.count(
            fx.s,
            where: (t) => t.treeId.equals(root.treeId),
          ),
          before,
        );
      },
    );

    test(
      'when a place with the same Mapbox id exists in the tree then create '
      'returns it and findByMapboxId finds it',
      () async {
        final session = asUser(sessionBuilder, member);
        final first = await endpoints.place.create(
          session,
          root.id!,
          input('Farm', mapboxPlaceId: 'mbx.1'),
        );
        final again = await endpoints.place.create(
          asUser(sessionBuilder, childMember),
          child.id!,
          input('Other label', mapboxPlaceId: 'mbx.1'),
        );
        expect(again.id, first.id);
        expect(again.label, 'Farm');
        final found = await endpoints.place.findByMapboxId(
          session,
          child.id!,
          'mbx.1',
        );
        expect(found?.id, first.id);
        expect(
          await endpoints.place.findByMapboxId(session, root.id!, 'mbx.2'),
          isNull,
        );
      },
    );

    test('when the label or address is blank then VALIDATION', () async {
      final session = asUser(sessionBuilder, member);
      await expectLater(
        endpoints.place.create(session, root.id!, input('  ')),
        throwsAppError(AppErrorCode.validation, 'label is required'),
      );
      await expectLater(
        endpoints.place.create(
          session,
          root.id!,
          PlaceInputDto(
            label: 'Farm',
            address: ' ',
            lat: 0,
            lng: 0,
            isFavorite: false,
          ),
        ),
        throwsAppError(AppErrorCode.validation, 'address is required'),
      );
    });

    test(
      'when marking used and favoriting then recents and favorites follow',
      () async {
        final session = asUser(sessionBuilder, member);
        final a = await fx.place(tree);
        final b = await fx.place(tree);

        await endpoints.place.markUsed(session, a.id!);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final usedB = await endpoints.place.markUsed(session, b.id!);
        expect(usedB.lastUsedAt, isNotNull);
        final fav = await endpoints.place.setFavorite(session, a.id!, true);
        expect(fav.isFavorite, isTrue);

        final recents = await endpoints.place.recents(
          session,
          root.id!,
          limit: 10,
        );
        expect(recents.map((p) => p.id), [b.id, a.id]);
        final limited = await endpoints.place.recents(
          session,
          root.id!,
          limit: 1,
        );
        expect(limited.map((p) => p.id), [b.id]);
        final favorites = await endpoints.place.favorites(session, root.id!);
        expect(favorites.map((p) => p.id), [a.id]);
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd apps/server && mise exec -- dart test test/integration/place_endpoint_test.dart`
Expected: compile error — `endpoints.place` does not exist.

- [ ] **Step 3: Implement**

`apps/server/lib/src/endpoints/place_endpoint.dart`:

```dart
import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';

/// Places are shared by every family in a tree (business-rules.md §2.4, §8
/// item 1). `familyId` parameters resolve the family's tree; the caller must
/// be a live member of a live family in that tree, and the family itself must
/// be live (D6b). Place rows are checked by their `treeId` (D8).
class PlaceEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<List<PlaceDto>> list(Session session, UuidValue familyId) async {
    final treeId = await _readableTree(session, familyId);
    final rows = await Place.db.find(
      session,
      where: (t) => t.treeId.equals(treeId),
      orderByList: (t) => [t.label.asc(), t.id.asc()],
    );
    return rows.map(_dto).toList();
  }

  Future<List<PlaceDto>> favorites(Session session, UuidValue familyId) async {
    final treeId = await _readableTree(session, familyId);
    final rows = await Place.db.find(
      session,
      where: (t) => t.treeId.equals(treeId) & t.isFavorite.equals(true),
      orderByList: (t) => [t.label.asc(), t.id.asc()],
    );
    return rows.map(_dto).toList();
  }

  Future<List<PlaceDto>> recents(
    Session session,
    UuidValue familyId, {
    int limit = 10,
  }) async {
    final treeId = await _readableTree(session, familyId);
    final rows = await Place.db.find(
      session,
      where: (t) => t.treeId.equals(treeId) & t.lastUsedAt.notEquals(null),
      orderByList: (t) => [t.lastUsedAt.desc(), t.id.asc()],
      limit: limit.clamp(1, 100),
    );
    return rows.map(_dto).toList();
  }

  /// Creates a place in the family's tree, marked used now. A place with the
  /// same Mapbox id already in the tree is returned instead (schema-design.md
  /// §3.2, places).
  Future<PlaceDto> create(
    Session session,
    UuidValue familyId,
    PlaceInputDto input,
  ) async {
    final treeId = await _readableTree(session, familyId);
    final label = input.label.trim();
    final address = input.address.trim();
    if (label.isEmpty) throw validation('label is required');
    if (address.isEmpty) throw validation('address is required');
    final mapboxPlaceId = input.mapboxPlaceId?.trim();
    final mapboxId = mapboxPlaceId == null || mapboxPlaceId.isEmpty
        ? null
        : mapboxPlaceId;
    if (mapboxId != null) {
      final existing = await _byMapboxId(session, treeId, mapboxId);
      if (existing != null) return _dto(existing);
    }
    try {
      final row = await Place.db.insertRow(
        session,
        Place(
          treeId: treeId,
          label: label,
          address: address,
          lat: input.lat,
          lng: input.lng,
          mapboxPlaceId: mapboxId,
          isFavorite: input.isFavorite,
          lastUsedAt: DateTime.now().toUtc(),
        ),
      );
      return _dto(row);
    } on DatabaseQueryException catch (e) {
      if (e.code != '23505' || e.constraintName != 'places_tree_mapbox_uidx') {
        rethrow;
      }
      return _dto((await _byMapboxId(session, treeId, mapboxId!))!);
    }
  }

  Future<PlaceDto> markUsed(Session session, UuidValue placeId) async {
    final place = await _writablePlace(session, placeId);
    final row = await Place.db.updateRow(
      session,
      place.copyWith(lastUsedAt: DateTime.now().toUtc()),
      columns: (t) => [t.lastUsedAt],
    );
    return _dto(row);
  }

  Future<PlaceDto> setFavorite(
    Session session,
    UuidValue placeId,
    bool isFavorite,
  ) async {
    final place = await _writablePlace(session, placeId);
    final row = await Place.db.updateRow(
      session,
      place.copyWith(isFavorite: isFavorite),
      columns: (t) => [t.isFavorite],
    );
    return _dto(row);
  }

  Future<PlaceDto?> findByMapboxId(
    Session session,
    UuidValue familyId,
    String mapboxPlaceId,
  ) async {
    final treeId = await _readableTree(session, familyId);
    final row = await _byMapboxId(session, treeId, mapboxPlaceId.trim());
    return row == null ? null : _dto(row);
  }

  /// Null when the place doesn't exist or the caller can't read its tree.
  Future<PlaceDto?> get(Session session, UuidValue placeId) async {
    final place = await Place.db.findById(session, placeId);
    if (place == null || !await Authz(session).isTreeMemberOf(place.treeId)) {
      return null;
    }
    return _dto(place);
  }
}

/// The tree of live [familyId] when the caller reads it (member or tree
/// reader); otherwise FORBIDDEN, also for a missing or soft-deleted family.
Future<UuidValue> _readableTree(Session session, UuidValue familyId) async {
  final family = await Family.db.findById(session, familyId);
  if (family == null || !await Authz(session).isTreeReadable(familyId)) {
    throw forbidden();
  }
  return family.treeId;
}

/// [placeId] when the caller is a live member of a live family in its tree;
/// a missing place is refused the same way.
Future<Place> _writablePlace(Session session, UuidValue placeId) async {
  final place = await Place.db.findById(session, placeId);
  if (place == null || !await Authz(session).isTreeMemberOf(place.treeId)) {
    throw forbidden();
  }
  return place;
}

Future<Place?> _byMapboxId(
  Session session,
  UuidValue treeId,
  String mapboxPlaceId,
) => Place.db.findFirstRow(
  session,
  where: (t) => t.treeId.equals(treeId) & t.mapboxPlaceId.equals(mapboxPlaceId),
);

PlaceDto _dto(Place p) => PlaceDto(
  id: p.id!,
  treeId: p.treeId,
  label: p.label,
  address: p.address,
  lat: p.lat,
  lng: p.lng,
  mapboxPlaceId: p.mapboxPlaceId,
  isFavorite: p.isFavorite,
  lastUsedAt: p.lastUsedAt,
);
```

- [ ] **Step 4: Regenerate and run the tests**

Run: `mise exec -- just server-generate` then `cd apps/server && mise exec -- dart test test/integration/place_endpoint_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/endpoints/place_endpoint.dart apps/server/test/integration/place_endpoint_test.dart apps/server/lib/src/generated apps/server/test/integration/test_tools packages/tell_me_a_story_client
git commit -m "feat(server): PlaceEndpoint, tree-wide places"
```

### Task 3: FamilyEndpoint — createRoot

**Files:**
- Create: `apps/server/lib/src/endpoints/family_endpoint.dart`
- Test: `apps/server/test/integration/family_endpoint_test.dart`
- Regenerate: `apps/server/lib/src/generated/endpoints.dart`, `apps/server/test/integration/test_tools/serverpod_test_tools.dart`, `packages/tell_me_a_story_client/lib/src/protocol/client.dart`

Ports: BR 1, 2, 3, 107 (email-local-part fallback).

- [ ] **Step 1: Write the failing tests**

`apps/server/test/integration/family_endpoint_test.dart`:

```dart
import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'support/families_fixtures.dart';
import 'support/fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given FamilyEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    setUp(() => fx = Fx(sessionBuilder.build()));

    TestSessionBuilder by(UuidValue user) => asUser(sessionBuilder, user);

    group('createRoot', () {
      // BR 3
      test(
        'when signed out then the call is rejected before the body',
        () async {
          await expectLater(
            endpoints.family.createRoot(sessionBuilder, 'Morgans'),
            throwsA(isA<ServerpodUnauthenticatedException>()),
          );
        },
      );

      // BR 1
      test(
        'when creating "  Morgans " then the name is trimmed, the caller is '
        'the only owner and has one linked person',
        () async {
          final user = await fx.userWithEmail(
            uniqueEmail(),
            displayName: 'Ada',
          );
          final id = await endpoints.family.createRoot(by(user), '  Morgans ');

          final family = (await Family.db.findById(fx.s, id))!;
          expect(family.name, 'Morgans');
          expect(family.parentId, isNull);
          expect(family.branchYear, isNull);
          expect(family.createdById, user);
          final memberships = await Membership.db.find(
            fx.s,
            where: (t) => t.familyId.equals(id),
          );
          expect(memberships.map((m) => (m.userId, m.role)), [
            (user, MembershipRole.owner),
          ]);
          final linked = await fx.linkedPeople(family.treeId, user);
          expect(linked, hasLength(1));
          expect(linked.single.name, 'Ada');
          expect(linked.single.homeFamilyId, id);
        },
      );

      // BR 107 (new person name falls back to the email local part)
      test(
        'when the creator has no display name then the linked person uses the '
        'email local part',
        () async {
          final user = await fx.userWithEmail('nora-${const Uuid().v4()}@x.io');
          final id = await endpoints.family.createRoot(by(user), 'Kin');
          final family = (await Family.db.findById(fx.s, id))!;
          final linked = await fx.linkedPeople(family.treeId, user);
          expect(linked.single.name, startsWith('nora-'));
        },
      );

      // BR 2
      test(
        'when the name is blank then VALIDATION "name is required"',
        () async {
          final user = await fx.user();
          await expectLater(
            endpoints.family.createRoot(by(user), '   '),
            throwsAppError(AppErrorCode.validation, 'name is required'),
          );
        },
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd apps/server && mise exec -- dart test test/integration/family_endpoint_test.dart`
Expected: compile error — `endpoints.family` does not exist.

- [ ] **Step 3: Implement**

`apps/server/lib/src/endpoints/family_endpoint.dart`:

```dart
import 'package:serverpod/serverpod.dart';

import '../accounts/accounts.dart';
import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';

/// Families, memberships and covers (business-rules.md §2.1, §2.2, §3.1–§3.3,
/// §3.5, §3.6; schema-design.md §3.2). Every write and member read needs a
/// live family (D6b); only `recover` and the steward reads `listStewarded`,
/// `directory` and `detail` reach a soft-deleted family.
class FamilyEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  // ── create root ──────────────────────────────────────────────────────

  /// A new tree with one family; the caller is its owner and gets a linked
  /// person (business-rules.md §3.1).
  Future<UuidValue> createRoot(Session session, String name) async {
    final uid = Authz(session).requireUser();
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw validation('name is required');
    return session.db.transaction((t) async {
      final tree = await Tree.db.insertRow(session, Tree(), transaction: t);
      final family = await Family.db.insertRow(
        session,
        Family(treeId: tree.id!, name: trimmed, createdById: uid),
        transaction: t,
      );
      await Membership.db.insertRow(
        session,
        Membership(
          familyId: family.id!,
          userId: uid,
          role: MembershipRole.owner,
        ),
        transaction: t,
      );
      await ensureLinkedPerson(
        session,
        treeId: tree.id!,
        homeFamilyId: family.id!,
        userId: uid,
        transaction: t,
      );
      return family.id!;
    });
  }
}
```

- [ ] **Step 4: Regenerate and run the tests**

Run: `mise exec -- just server-generate` then `cd apps/server && mise exec -- dart test test/integration/family_endpoint_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/endpoints/family_endpoint.dart apps/server/test/integration/family_endpoint_test.dart apps/server/lib/src/generated apps/server/test/integration/test_tools packages/tell_me_a_story_client
git commit -m "feat(server): FamilyEndpoint.createRoot"
```

### Task 4: FamilyEndpoint reads

**Files:**
- Modify: `apps/server/lib/src/endpoints/family_endpoint.dart`
- Modify: `apps/server/test/integration/family_endpoint_test.dart`
- Regenerate: `apps/server/lib/src/generated/endpoints.dart`, `apps/server/test/integration/test_tools/serverpod_test_tools.dart`, `packages/tell_me_a_story_client/lib/src/protocol/client.dart`

Ports: BR 17, 18 (family-level), 29, 30, 31, 32, 110 (read part).

- [ ] **Step 1: Write the failing tests**

Append this group inside `withServerpod` in `apps/server/test/integration/family_endpoint_test.dart`, after the previous group:

```dart
    group('reads', () {
      late UuidValue owner, coOwner, member, stranger;
      late Family root, child, gone;

      setUp(() async {
        owner = await fx.userWithEmail(uniqueEmail(), displayName: 'Owner');
        coOwner = await fx.user();
        member = await fx.user();
        stranger = await fx.user();
        root = await fx.rootOwnedBy(owner);
        await fx.join(root, coOwner, MembershipRole.coOwner);
        await fx.join(root, member);
        child = await fx.childOf(root, owner: member, branchYear: 1987);
        gone = await fx.childOf(
          root,
          owner: owner,
          name: 'Gone',
          deletedAt: DateTime.now().toUtc().subtract(const Duration(days: 3)),
        );
        await fx.join(gone, coOwner, MembershipRole.coOwner);
        await fx.join(gone, member);
      });

      test('listMine returns live families with the caller role', () async {
        final mine = await endpoints.family.listMine(by(member));
        expect(mine.map((f) => (f.id, f.role)), [
          (root.id, MembershipRole.member),
          (child.id, MembershipRole.owner),
        ]);
        expect(mine.last.parentId, root.id);
        expect(mine.last.branchYear, 1987);
      });

      test(
        'listStewarded includes soft-deleted families inside the window only',
        () async {
          final old = await fx.childOf(
            root,
            owner: owner,
            name: 'Old',
            deletedAt: DateTime.now().toUtc().subtract(
              const Duration(days: 61),
            ),
          );
          final stewarded = await endpoints.family.listStewarded(by(owner));
          final ids = stewarded.map((f) => f.id).toList();
          expect(ids, containsAll([root.id, gone.id]));
          expect(ids, isNot(contains(old.id)));
          expect(
            stewarded.singleWhere((f) => f.id == gone.id).deletedAt,
            isNotNull,
          );
          expect(await endpoints.family.listStewarded(by(stranger)), isEmpty);
        },
      );

      // BR 110 (co-members read each other's profile; strangers don't)
      test(
        'listMembers returns roles, names and avatar keys to a live member; '
        'a stranger is FORBIDDEN',
        () async {
          final members = await endpoints.family.listMembers(
            by(member),
            root.id!,
          );
          expect(members.map((m) => (m.userId, m.role)), [
            (owner, MembershipRole.owner),
            (coOwner, MembershipRole.coOwner),
            (member, MembershipRole.member),
          ]);
          expect(members.first.displayName, 'Owner');
          await expectLater(
            endpoints.family.listMembers(by(stranger), root.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
        },
      );

      test(
        'directory counts members and published stories, and lists deleted '
        'stewarded families as recoverable',
        () async {
          await fx.story(root);
          await fx.story(root, status: StoryStatus.draft);
          final directory = await endpoints.family.directory(by(coOwner));
          expect(directory.active.map((r) => r.id), [root.id]);
          final active = directory.active.single;
          expect(active.role, MembershipRole.coOwner);
          expect(active.memberCount, 3);
          expect(active.publishedCount, 1);
          expect(directory.recoverable.map((r) => r.id), [gone.id]);
          expect(directory.recoverable.single.deletedAt, isNotNull);

          final plain = await endpoints.family.directory(by(member));
          expect(plain.active.map((r) => r.id), [child.id]);
          expect(plain.recoverable, isEmpty);
        },
      );

      test(
        'detail returns members and pending invites to a live member',
        () async {
          final pending = await fx.invite(root);
          final accepted = await fx.invite(root);
          await Invite.db.updateRow(
            fx.s,
            accepted.copyWith(
              acceptedAt: DateTime.now().toUtc(),
              acceptedById: member,
            ),
          );
          final detail = await endpoints.family.detail(by(member), root.id!);
          expect(detail!.name, root.name);
          expect(detail.myRole, MembershipRole.member);
          expect(detail.members, hasLength(3));
          expect(detail.pendingInvites.map((i) => i.id), [pending.id]);
          expect(detail.pendingInvites.single.sentAt, pending.lastSentAt);
        },
      );

      // BR 17
      test(
        'when a family is soft-deleted then a plain member and a stranger '
        'cannot read it; the owner and co-owner can',
        () async {
          await fx.invite(gone);
          for (final user in [member, stranger]) {
            await expectLater(
              endpoints.family.detail(by(user), gone.id!),
              throwsAppError(AppErrorCode.forbidden),
            );
            final mine = await endpoints.family.listMine(by(user));
            expect(mine.map((f) => f.id), isNot(contains(gone.id)));
          }
          for (final user in [owner, coOwner]) {
            final detail = await endpoints.family.detail(by(user), gone.id!);
            expect(detail!.members, hasLength(3));
            expect(detail.pendingInvites, isEmpty);
          }
        },
      );

      // BR 18 (family-level reads; stories, people and photos are 3b–3d)
      test(
        'when a family is soft-deleted then its members read no members, no '
        'tree and no places through it',
        () async {
          for (final user in [owner, member]) {
            await expectLater(
              endpoints.family.listMembers(by(user), gone.id!),
              throwsAppError(AppErrorCode.forbidden),
            );
            expect(
              await endpoints.family.listTree(by(user), gone.id!),
              isEmpty,
            );
            await expectLater(
              endpoints.place.list(by(user), gone.id!),
              throwsAppError(AppErrorCode.forbidden),
            );
          }
        },
      );

      // BR 29
      test(
        'when a parent member lists the tree then it gets parent and child '
        'with branch year and effective origin; a lone family lists itself',
        () async {
          final origin = await fx.story(root);
          await fx.setOriginRow(child, origin);
          final tree = await endpoints.family.listTree(by(coOwner), root.id!);
          expect(tree.map((f) => f.id), [root.id, child.id]);
          final listedChild = tree.last;
          expect(listedChild.parentId, root.id);
          expect(listedChild.branchYear, 1987);
          expect(listedChild.effectiveOriginStoryId, origin.id);
          expect(tree.first.effectiveOriginStoryId, isNull);

          final lone = await fx.rootOwnedBy(stranger);
          final alone = await endpoints.family.listTree(by(stranger), lone.id!);
          expect(alone.map((f) => f.id), [lone.id]);
        },
      );

      // BR 30
      test(
        'when a child is soft-deleted then it is absent for parent members and '
        'its own owner; membership only in a deleted family reads no tree',
        () async {
          final onlyGone = await fx.user();
          await fx.join(gone, onlyGone);
          final forParent = await endpoints.family.listTree(
            by(coOwner),
            root.id!,
          );
          expect(forParent.map((f) => f.id), isNot(contains(gone.id)));
          final forOwner = await endpoints.family.listTree(by(owner), root.id!);
          expect(forOwner.map((f) => f.id), isNot(contains(gone.id)));
          expect(
            await endpoints.family.listTree(by(onlyGone), gone.id!),
            isEmpty,
          );
          expect(
            await endpoints.family.listTree(by(onlyGone), root.id!),
            isEmpty,
          );
        },
      );

      // BR 31
      test(
        'when grandparent→parent(deleted)→child then grandparent and child '
        'members still read each other (D8)',
        () async {
          final grandMember = await fx.user();
          final childMember = await fx.user();
          final grand = await fx.rootOwnedBy(grandMember, name: 'Grand');
          final middle = await fx.childOf(
            grand,
            name: 'Middle',
            deletedAt: DateTime.now().toUtc(),
          );
          final leaf = await fx.childOf(
            middle,
            owner: childMember,
            name: 'Leaf',
          );
          final fromGrand = await endpoints.family.listTree(
            by(grandMember),
            leaf.id!,
          );
          expect(fromGrand.map((f) => f.id), [grand.id, leaf.id]);
          final fromLeaf = await endpoints.family.listTree(
            by(childMember),
            grand.id!,
          );
          expect(fromLeaf.map((f) => f.id), [grand.id, leaf.id]);
        },
      );

      // BR 32
      test(
        'when the parent links form a cycle then the tree lists each id once',
        () async {
          final a = await fx.rootOwnedBy(stranger, name: 'A');
          final b = await fx.childOf(a, name: 'B');
          await Family.db.updateRow(
            fx.s,
            a.copyWith(parentId: b.id),
            columns: (c) => [c.parentId],
          );
          final tree = await endpoints.family.listTree(by(stranger), a.id!);
          expect(tree.map((f) => f.id), [a.id, b.id]);
        },
      );
    });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd apps/server && mise exec -- dart test test/integration/family_endpoint_test.dart`
Expected: compile error — the `endpoints.family` methods used by the new group don't exist yet.

- [ ] **Step 3: Add the imports and constants**

Add above the class doc comment:

```dart
/// A soft-deleted family can be recovered for this long (business-rules.md
/// §3.5); the 3f purge removes it afterwards.
const recoveryWindow = Duration(days: 60);
```

- [ ] **Step 4: Implement**

Add to `FamilyEndpoint`, after the previous section:

```dart
  // ── reads ────────────────────────────────────────────────────────────

  /// The caller's live families, any role.
  Future<List<MemberFamilyDto>> listMine(Session session) async {
    final roles = await _myRoles(session);
    if (roles.isEmpty) return [];
    final families = await Family.db.find(
      session,
      where: (t) => t.id.inSet(roles.keys.toSet()) & t.deletedAt.equals(null),
      orderByList: (t) => [t.createdAt.asc(), t.id.asc()],
    );
    return [
      for (final f in families)
        MemberFamilyDto(
          id: f.id!,
          name: f.name,
          parentId: f.parentId,
          branchYear: f.branchYear,
          createdAt: f.createdAt,
          role: roles[f.id]!,
          coverKey: f.coverKey,
        ),
    ];
  }

  /// Families the caller owns or co-owns: live ones and soft-deleted ones
  /// still inside the recovery window (recovery read, D6b).
  Future<List<StewardFamilyDto>> listStewarded(Session session) async {
    final roles = await _myRoles(session, stewardOnly: true);
    if (roles.isEmpty) return [];
    final cutoff = DateTime.now().toUtc().subtract(recoveryWindow);
    final families = await Family.db.find(
      session,
      where: (t) =>
          t.id.inSet(roles.keys.toSet()) &
          (t.deletedAt.equals(null) | (t.deletedAt >= cutoff)),
      orderByList: (t) => [t.createdAt.asc(), t.id.asc()],
    );
    return [
      for (final f in families)
        StewardFamilyDto(
          id: f.id!,
          name: f.name,
          role: roles[f.id]!,
          deletedAt: f.deletedAt,
        ),
    ];
  }

  /// Live families sharing [familyId]'s tree (D8), with their effective
  /// origin. Empty unless the caller reads that tree.
  Future<List<TreeFamilyDto>> listTree(
    Session session,
    UuidValue familyId,
  ) async {
    final authz = Authz(session);
    if (!await authz.isTreeReadable(familyId)) return [];
    final family = await Family.db.findById(session, familyId);
    final families = await Family.db.find(
      session,
      where: (t) => t.treeId.equals(family!.treeId) & t.deletedAt.equals(null),
      orderByList: (t) => [t.createdAt.asc(), t.id.asc()],
    );
    return [
      for (final f in families)
        TreeFamilyDto(
          id: f.id!,
          name: f.name,
          parentId: f.parentId,
          branchYear: f.branchYear,
          effectiveOriginStoryId: await authz.effectiveOrigin(f),
        ),
    ];
  }

  Future<List<FamilyMemberDto>> listMembers(
    Session session,
    UuidValue familyId,
  ) async {
    await Authz(session).requireLiveMember(familyId);
    return _members(session, familyId);
  }

  /// The caller's stewarded families with member and published-story counts,
  /// in one query: live ones are `active`; soft-deleted ones inside the
  /// recovery window are `recoverable` (recovery read, D6b).
  Future<FamilyDirectoryDto> directory(Session session) async {
    final uid = Authz(session).requireUser();
    final rows = await session.db.unsafeQuery(
      '''
SELECT f."id", f."name", m."role", f."deletedAt",
  (SELECT count(*) FROM "memberships" c WHERE c."familyId" = f."id"),
  (SELECT count(*) FROM "stories" s
     WHERE s."familyId" = f."id" AND s."status" = 'published')
FROM "memberships" m
JOIN "families" f ON f."id" = m."familyId"
WHERE m."userId" = @uid::uuid AND m."role" IN ('owner', 'coOwner')
ORDER BY f."createdAt", f."id"
''',
      parameters: QueryParameters.named({'uid': uid.uuid}),
    );
    final cutoff = DateTime.now().toUtc().subtract(recoveryWindow);
    final active = <FamilyRosterDto>[];
    final recoverable = <FamilyRosterDto>[];
    for (final row in rows) {
      final deletedAt = row[3] as DateTime?;
      final roster = FamilyRosterDto(
        id: UuidValue.fromString(row[0].toString()),
        name: row[1] as String,
        role: MembershipRole.fromJson(row[2] as String),
        memberCount: row[4] as int,
        publishedCount: row[5] as int,
        deletedAt: deletedAt,
      );
      if (deletedAt == null) {
        active.add(roster);
      } else if (!deletedAt.isBefore(cutoff)) {
        recoverable.add(roster);
      }
    }
    return FamilyDirectoryDto(active: active, recoverable: recoverable);
  }

  /// Family, members and pending invites. Live members read a live family;
  /// owners and co-owners also read a soft-deleted one (recovery read, D6b),
  /// whose invites are not readable, so `pendingInvites` is empty.
  Future<FamilyDetailDto?> detail(Session session, UuidValue familyId) async {
    final family = await Family.db.findById(session, familyId);
    final role = await Authz(session).roleIn(familyId);
    if (family == null || role == null) throw forbidden('member only');
    final deleted = family.deletedAt != null;
    if (deleted && role == MembershipRole.member) {
      throw forbidden('owner or co-owner only');
    }
    final invites = deleted
        ? const <Invite>[]
        : await Invite.db.find(
            session,
            where: (t) =>
                t.familyId.equals(familyId) &
                t.acceptedAt.equals(null) &
                t.revokedAt.equals(null),
            orderByList: (t) => [t.email.asc(), t.createdAt.asc()],
          );
    return FamilyDetailDto(
      id: family.id!,
      name: family.name,
      myRole: role,
      members: await _members(session, familyId),
      pendingInvites: [
        for (final i in invites)
          PendingInviteDto(
            id: i.id!,
            email: i.email,
            personId: i.personId,
            sentAt: i.lastSentAt,
            expiresAt: i.expiresAt,
            createdAt: i.createdAt,
          ),
      ],
    );
  }
```

Append to the end of `apps/server/lib/src/endpoints/family_endpoint.dart`:

```dart
/// The caller's role per family id, optionally owners and co-owners only.
Future<Map<UuidValue, MembershipRole>> _myRoles(
  Session session, {
  bool stewardOnly = false,
}) async {
  final uid = Authz(session).requireUser();
  final memberships = await Membership.db.find(
    session,
    where: (t) => stewardOnly
        ? t.userId.equals(uid) &
              t.role.inSet({MembershipRole.owner, MembershipRole.coOwner})
        : t.userId.equals(uid),
  );
  return {for (final m in memberships) m.familyId: m.role};
}

Future<List<FamilyMemberDto>> _members(
  Session session,
  UuidValue familyId,
) async {
  final memberships = await Membership.db.find(
    session,
    where: (t) => t.familyId.equals(familyId),
    orderByList: (t) => [t.createdAt.asc(), t.id.asc()],
  );
  if (memberships.isEmpty) return [];
  final users = await AppUser.db.find(
    session,
    where: (t) => t.authUserId.inSet({for (final m in memberships) m.userId}),
  );
  final byId = {for (final u in users) u.authUserId: u};
  return [
    for (final m in memberships)
      FamilyMemberDto(
        userId: m.userId,
        role: m.role,
        displayName: byId[m.userId]?.displayName,
        avatarKey: byId[m.userId]?.avatarKey,
      ),
  ];
}
```

- [ ] **Step 5: Regenerate and run the tests**

Run: `mise exec -- just server-generate` then `cd apps/server && mise exec -- dart test test/integration/family_endpoint_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/server/lib/src/endpoints/family_endpoint.dart apps/server/test/integration/family_endpoint_test.dart apps/server/lib/src/generated apps/server/test/integration/test_tools packages/tell_me_a_story_client
git commit -m "feat(server): family reads, directory and recovery reads"
```

### Task 5: FamilyEndpoint names and roles

**Files:**
- Modify: `apps/server/lib/src/endpoints/family_endpoint.dart`
- Modify: `apps/server/test/integration/family_endpoint_test.dart`
- Regenerate: `apps/server/lib/src/generated/endpoints.dart`, `apps/server/test/integration/test_tools/serverpod_test_tools.dart`, `packages/tell_me_a_story_client/lib/src/protocol/client.dart`

Ports: BR 4–15.

- [ ] **Step 1: Write the failing tests**

Append this group inside `withServerpod` in `apps/server/test/integration/family_endpoint_test.dart`, after the previous group:

```dart
    group('roles', () {
      late UuidValue owner, coOwner, member, member2, member3;
      late Family root;

      setUp(() async {
        owner = await fx.user();
        coOwner = await fx.user();
        member = await fx.user();
        member2 = await fx.user();
        member3 = await fx.user();
        root = await fx.rootOwnedBy(owner);
        await fx.join(root, coOwner, MembershipRole.coOwner);
        for (final m in [member, member2, member3]) {
          await fx.join(root, m);
        }
      });

      // BR 4
      test(
        'when the owner promotes two members then both succeed; a third is '
        'VALIDATION "co-owner cap is 2"',
        () async {
          final fresh = await fx.rootOwnedBy(owner);
          for (final m in [member, member2, member3]) {
            await fx.join(fresh, m);
          }
          await endpoints.family.addCoOwner(by(owner), fresh.id!, member);
          await endpoints.family.addCoOwner(by(owner), fresh.id!, member2);
          await expectLater(
            endpoints.family.addCoOwner(by(owner), fresh.id!, member3),
            throwsAppError(AppErrorCode.validation, 'co-owner cap is 2'),
          );
          expect(await fx.roleOf(fresh, member3), MembershipRole.member);
        },
      );

      // BR 5
      test(
        'when a co-owner promotes a member then it succeeds; a plain member '
        'is FORBIDDEN',
        () async {
          await endpoints.family.addCoOwner(by(coOwner), root.id!, member);
          expect(await fx.roleOf(root, member), MembershipRole.coOwner);
          await expectLater(
            endpoints.family.addCoOwner(by(member2), root.id!, member3),
            throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
          );
        },
      );

      // BR 6, BR 14 (no membership is ever written for a non-member)
      test(
        'when promoting a non-member or an existing co-owner then VALIDATION '
        '"target must be a member" and no membership is written',
        () async {
          final outsider = await fx.user();
          await expectLater(
            endpoints.family.addCoOwner(by(owner), root.id!, outsider),
            throwsAppError(AppErrorCode.validation, 'target must be a member'),
          );
          expect(await fx.roleOf(root, outsider), isNull);
          await expectLater(
            endpoints.family.addCoOwner(by(owner), root.id!, coOwner),
            throwsAppError(AppErrorCode.validation, 'target must be a member'),
          );
        },
      );

      // BR 7
      test(
        'when the owner transfers to a member who is not a co-owner then '
        'FORBIDDEN "target must be a co-owner"',
        () async {
          await expectLater(
            endpoints.family.transferOwnership(
              by(owner),
              root.id!,
              member,
              MembershipRole.member,
            ),
            throwsAppError(AppErrorCode.forbidden, 'target must be a co-owner'),
          );
        },
      );

      // BR 8
      test(
        'when transferring with former=member then the target is owner and the '
        'caller member; with former=co_owner the caller is co-owner',
        () async {
          await endpoints.family.transferOwnership(
            by(owner),
            root.id!,
            coOwner,
            MembershipRole.member,
          );
          expect(await fx.roleOf(root, coOwner), MembershipRole.owner);
          expect(await fx.roleOf(root, owner), MembershipRole.member);

          final other = await fx.rootOwnedBy(owner);
          await fx.join(other, member, MembershipRole.coOwner);
          await endpoints.family.transferOwnership(
            by(owner),
            other.id!,
            member,
            MembershipRole.coOwner,
          );
          expect(await fx.roleOf(other, member), MembershipRole.owner);
          expect(await fx.roleOf(other, owner), MembershipRole.coOwner);
        },
      );

      // BR 8 (former role)
      test('when former=owner then VALIDATION', () async {
        await expectLater(
          endpoints.family.transferOwnership(
            by(owner),
            root.id!,
            coOwner,
            MembershipRole.owner,
          ),
          throwsAppError(
            AppErrorCode.validation,
            'former role must be co_owner or member',
          ),
        );
      });

      // BR 9
      test('when a co-owner transfers then FORBIDDEN "owner only"', () async {
        await expectLater(
          endpoints.family.transferOwnership(
            by(coOwner),
            root.id!,
            coOwner,
            MembershipRole.member,
          ),
          throwsAppError(AppErrorCode.forbidden, 'owner only'),
        );
      });

      // BR 10
      test(
        'when the owner demotes a co-owner then member; a co-owner caller is '
        'FORBIDDEN "owner only"; a non-co-owner target is VALIDATION',
        () async {
          await expectLater(
            endpoints.family.removeCoOwner(by(coOwner), root.id!, coOwner),
            throwsAppError(AppErrorCode.forbidden, 'owner only'),
          );
          await expectLater(
            endpoints.family.removeCoOwner(by(owner), root.id!, member),
            throwsAppError(
              AppErrorCode.validation,
              'target must be a co-owner',
            ),
          );
          await endpoints.family.removeCoOwner(by(owner), root.id!, coOwner);
          expect(await fx.roleOf(root, coOwner), MembershipRole.member);
        },
      );

      // BR 11
      test(
        'when the owner removes a member then every membership in the tree '
        'goes, soft-deleted families included, linked people are unlinked '
        'and story tags remain',
        () async {
          final child = await fx.childOf(root, owner: owner);
          final gone = await fx.childOf(
            root,
            owner: owner,
            name: 'Gone',
            deletedAt: DateTime.now().toUtc(),
          );
          await fx.join(child, member);
          await fx.join(gone, member);
          final otherTree = await fx.rootOwnedBy(owner);
          await fx.join(otherTree, member);
          final linked = await fx.person(root, userId: member);
          final elsewhere = await fx.person(otherTree, userId: member);
          final story = await fx.story(root);
          await fx.tag(story, linked);

          await endpoints.family.removeMember(by(owner), root.id!, member);

          for (final f in [root, child, gone]) {
            expect(await fx.roleOf(f, member), isNull);
          }
          expect(await fx.roleOf(otherTree, member), MembershipRole.member);
          expect((await Person.db.findById(fx.s, linked.id!))!.userId, isNull);
          expect(
            (await Person.db.findById(fx.s, elsewhere.id!))!.userId,
            member,
          );
          expect(
            await StoryPerson.db.count(
              fx.s,
              where: (t) => t.personId.equals(linked.id!),
            ),
            1,
          );
        },
      );

      // BR 12
      test(
        'when a co-owner removes the owner, another co-owner or self then '
        'FORBIDDEN with the matching message',
        () async {
          final otherCo = member3;
          await endpoints.family.addCoOwner(by(owner), root.id!, otherCo);
          await expectLater(
            endpoints.family.removeMember(by(coOwner), root.id!, owner),
            throwsAppError(AppErrorCode.forbidden, 'cannot remove an owner'),
          );
          await expectLater(
            endpoints.family.removeMember(by(coOwner), root.id!, otherCo),
            throwsAppError(AppErrorCode.forbidden, 'cannot remove a co-owner'),
          );
          await expectLater(
            endpoints.family.removeMember(by(coOwner), root.id!, coOwner),
            throwsAppError(AppErrorCode.forbidden, 'cannot remove yourself'),
          );
          expect(await fx.roleOf(root, otherCo), MembershipRole.coOwner);
        },
      );

      // BR 12 (owner anywhere in the tree)
      test(
        'when the target owns another family in the tree then FORBIDDEN '
        '"cannot remove an owner"; the owner may remove a co-owner',
        () async {
          await fx.childOf(root, owner: member);
          await expectLater(
            endpoints.family.removeMember(by(owner), root.id!, member),
            throwsAppError(AppErrorCode.forbidden, 'cannot remove an owner'),
          );
          await endpoints.family.removeMember(by(owner), root.id!, coOwner);
          expect(await fx.roleOf(root, coOwner), isNull);
        },
      );

      // BR 13
      test('when the owner removes self then FORBIDDEN', () async {
        await expectLater(
          endpoints.family.removeMember(by(owner), root.id!, owner),
          throwsAppError(AppErrorCode.forbidden, 'cannot remove yourself'),
        );
      });

      // BR 15
      test(
        'when a steward renames with a blank name then VALIDATION; a plain '
        'member is FORBIDDEN; a steward renames trimmed',
        () async {
          await expectLater(
            endpoints.family.rename(by(coOwner), root.id!, '  '),
            throwsAppError(AppErrorCode.validation, 'name is required'),
          );
          await expectLater(
            endpoints.family.rename(by(member), root.id!, 'X'),
            throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
          );
          await endpoints.family.rename(by(coOwner), root.id!, ' Reyes ');
          expect((await fx.reload(root)).name, 'Reyes');
        },
      );
    });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd apps/server && mise exec -- dart test test/integration/family_endpoint_test.dart`
Expected: compile error — the `endpoints.family` methods used by the new group don't exist yet.

- [ ] **Step 3: Implement**

Add to `FamilyEndpoint`, after the previous section:

```dart
  // ── names and roles ──────────────────────────────────────────────────

  Future<void> rename(Session session, UuidValue familyId, String name) async {
    final trimmed = name.trim();
    await Authz(session).requireLiveSteward(familyId);
    if (trimmed.isEmpty) throw validation('name is required');
    await session.db.transaction((t) async {
      final family = (await Family.db.findById(
        session,
        familyId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      ))!;
      await Family.db.updateRow(
        session,
        family.copyWith(name: trimmed),
        columns: (c) => [c.name],
        transaction: t,
      );
    });
  }

  /// Owner or co-owner promotes a plain member; at most two co-owners, counted
  /// under the family row lock.
  Future<void> addCoOwner(
    Session session,
    UuidValue familyId,
    UuidValue userId,
  ) async {
    await Authz(session).requireLiveSteward(familyId);
    await session.db.transaction((t) async {
      await _lockFamily(session, familyId, t);
      final target = await _membership(session, familyId, userId, t);
      if (target == null || target.role != MembershipRole.member) {
        throw validation('target must be a member');
      }
      final coOwners = await Membership.db.count(
        session,
        where: (m) =>
            m.familyId.equals(familyId) & m.role.equals(MembershipRole.coOwner),
        transaction: t,
      );
      if (coOwners >= 2) throw validation('co-owner cap is 2');
      await _setRole(session, target, MembershipRole.coOwner, t);
    });
  }

  Future<void> removeCoOwner(
    Session session,
    UuidValue familyId,
    UuidValue userId,
  ) async {
    await Authz(session).requireLiveOwner(familyId);
    await session.db.transaction((t) async {
      await _lockFamily(session, familyId, t);
      final target = await _membership(session, familyId, userId, t);
      if (target == null || target.role != MembershipRole.coOwner) {
        throw validation('target must be a co-owner');
      }
      await _setRole(session, target, MembershipRole.member, t);
    });
  }

  /// Business-rules.md §3.6. Writes demote the caller, promote the target,
  /// then make the caller co-owner if asked, so the one-owner index and the
  /// co-owner cap hold at every step.
  Future<void> transferOwnership(
    Session session,
    UuidValue familyId,
    UuidValue newOwnerUserId,
    MembershipRole formerOwnerBecomes,
  ) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    await authz.requireLiveOwner(familyId);
    if (formerOwnerBecomes == MembershipRole.owner) {
      throw validation('former role must be co_owner or member');
    }
    await session.db.transaction((t) async {
      await _lockFamily(session, familyId, t);
      final target = await _membership(session, familyId, newOwnerUserId, t);
      if (target == null || target.role != MembershipRole.coOwner) {
        throw forbidden('target must be a co-owner');
      }
      final me = (await _membership(session, familyId, uid, t))!;
      await _setRole(session, me, MembershipRole.member, t);
      await _setRole(session, target, MembershipRole.owner, t);
      if (formerOwnerBecomes == MembershipRole.coOwner) {
        await _setRole(session, me, MembershipRole.coOwner, t);
      }
    });
  }

  /// Removes [userId] from every family in the tree, soft-deleted ones
  /// included (so recovery can't restore them), and unlinks their person in
  /// the tree; story tags stay (business-rules.md §2.2).
  Future<void> removeMember(
    Session session,
    UuidValue familyId,
    UuidValue userId,
  ) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    final role = await authz.requireLiveSteward(familyId);
    if (userId == uid) throw forbidden('cannot remove yourself');
    await session.db.transaction((t) async {
      final family = await _lockFamily(session, familyId, t);
      final treeFamilies = await Family.db.find(
        session,
        where: (f) => f.treeId.equals(family.treeId),
        transaction: t,
      );
      final treeFamilyIds = {for (final f in treeFamilies) f.id!};
      final targetRoles = await Membership.db.find(
        session,
        where: (m) => m.userId.equals(userId) & m.familyId.inSet(treeFamilyIds),
        transaction: t,
      );
      if (targetRoles.any((m) => m.role == MembershipRole.owner)) {
        throw forbidden('cannot remove an owner');
      }
      if (targetRoles.any((m) => m.role == MembershipRole.coOwner) &&
          role != MembershipRole.owner) {
        throw forbidden('cannot remove a co-owner');
      }
      await Membership.db.deleteWhere(
        session,
        where: (m) => m.userId.equals(userId) & m.familyId.inSet(treeFamilyIds),
        transaction: t,
      );
      await Person.db.updateWhere(
        session,
        columnValues: (p) => [
          p.userId(null),
          p.updatedAt(DateTime.now().toUtc()),
        ],
        where: (p) => p.userId.equals(userId) & p.treeId.equals(family.treeId),
        transaction: t,
      );
    });
  }
```

Append to the end of `apps/server/lib/src/endpoints/family_endpoint.dart`:

```dart
Future<Family> _lockFamily(
  Session session,
  UuidValue familyId,
  Transaction t,
) async => (await Family.db.findById(
  session,
  familyId,
  transaction: t,
  lockMode: LockMode.forUpdate,
))!;

Future<Membership?> _membership(
  Session session,
  UuidValue familyId,
  UuidValue userId,
  Transaction t,
) => Membership.db.findFirstRow(
  session,
  where: (m) => m.familyId.equals(familyId) & m.userId.equals(userId),
  transaction: t,
);

Future<void> _setRole(
  Session session,
  Membership membership,
  MembershipRole role,
  Transaction t,
) => Membership.db.updateRow(
  session,
  membership.copyWith(role: role),
  columns: (m) => [m.role],
  transaction: t,
);
```

- [ ] **Step 4: Regenerate and run the tests**

Run: `mise exec -- just server-generate` then `cd apps/server && mise exec -- dart test test/integration/family_endpoint_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/endpoints/family_endpoint.dart apps/server/test/integration/family_endpoint_test.dart apps/server/lib/src/generated apps/server/test/integration/test_tools packages/tell_me_a_story_client
git commit -m "feat(server): rename, co-owners, transfer and remove member"
```

### Task 6: FamilyEndpoint soft delete and recover

**Files:**
- Modify: `apps/server/lib/src/endpoints/family_endpoint.dart`
- Modify: `apps/server/test/integration/family_endpoint_test.dart`
- Regenerate: `apps/server/lib/src/generated/endpoints.dart`, `apps/server/test/integration/test_tools/serverpod_test_tools.dart`, `packages/tell_me_a_story_client/lib/src/protocol/client.dart`

Ports: BR 16, 19.

- [ ] **Step 1: Write the failing tests**

Append this group inside `withServerpod` in `apps/server/test/integration/family_endpoint_test.dart`, after the previous group:

```dart
    group('soft delete and recover', () {
      late UuidValue owner, coOwner, member;
      late Family root;

      setUp(() async {
        owner = await fx.user();
        coOwner = await fx.user();
        member = await fx.user();
        root = await fx.rootOwnedBy(owner);
        await fx.join(root, coOwner, MembershipRole.coOwner);
        await fx.join(root, member);
      });

      // BR 16
      test(
        'when a co-owner soft-deletes then FORBIDDEN "owner only"; the owner '
        'sets deletedAt and a child keeps its parent link',
        () async {
          final child = await fx.childOf(root);
          await expectLater(
            endpoints.family.softDelete(by(coOwner), root.id!),
            throwsAppError(AppErrorCode.forbidden, 'owner only'),
          );
          await endpoints.family.softDelete(by(owner), root.id!);
          expect((await fx.reload(root)).deletedAt, isNotNull);
          expect((await fx.reload(child)).parentId, root.id);
        },
      );

      // BR 19
      test(
        'when a co-owner recovers 10 days after delete then deletedAt is '
        'cleared; 61 days → FORBIDDEN "recovery window closed"; not deleted '
        '→ VALIDATION "family is not deleted"',
        () async {
          await expectLater(
            endpoints.family.recover(by(coOwner), root.id!),
            throwsAppError(AppErrorCode.validation, 'family is not deleted'),
          );
          final now = DateTime.now().toUtc();
          await fx.setDeletedAt(root, now.subtract(const Duration(days: 61)));
          await expectLater(
            endpoints.family.recover(by(coOwner), root.id!),
            throwsAppError(AppErrorCode.forbidden, 'recovery window closed'),
          );
          await fx.setDeletedAt(root, now.subtract(const Duration(days: 10)));
          await endpoints.family.recover(by(coOwner), root.id!);
          expect((await fx.reload(root)).deletedAt, isNull);
        },
      );

      test('when a plain member recovers then FORBIDDEN', () async {
        await fx.setDeletedAt(root, DateTime.now().toUtc());
        await expectLater(
          endpoints.family.recover(by(member), root.id!),
          throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
        );
      });

      test(
        'when the family is soft-deleted then writes are FORBIDDEN',
        () async {
          await fx.setDeletedAt(root, DateTime.now().toUtc());
          await expectLater(
            endpoints.family.rename(by(owner), root.id!, 'X'),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.family.softDelete(by(owner), root.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.family.addCoOwner(by(owner), root.id!, member),
            throwsAppError(AppErrorCode.forbidden),
          );
        },
      );
    });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd apps/server && mise exec -- dart test test/integration/family_endpoint_test.dart`
Expected: compile error — the `endpoints.family` methods used by the new group don't exist yet.

- [ ] **Step 3: Implement**

Add to `FamilyEndpoint`, after the previous section:

```dart
  // ── soft delete ──────────────────────────────────────────────────────

  /// Owner only. Only sets `deletedAt`; the purge (3f) removes the family
  /// after the recovery window.
  Future<void> softDelete(Session session, UuidValue familyId) async {
    await Authz(session).requireLiveOwner(familyId);
    await session.db.transaction((t) async {
      final family = await _lockFamily(session, familyId, t);
      await Family.db.updateRow(
        session,
        family.copyWith(deletedAt: DateTime.now().toUtc()),
        columns: (c) => [c.deletedAt],
        transaction: t,
      );
    });
  }

  /// Owner or co-owner of the soft-deleted family, inside the recovery
  /// window (recovery exception, D6b).
  Future<void> recover(Session session, UuidValue familyId) async {
    if (!await Authz(session).isSteward(familyId)) {
      throw forbidden('owner or co-owner only');
    }
    await session.db.transaction((t) async {
      final family = await _lockFamily(session, familyId, t);
      final deletedAt = family.deletedAt;
      if (deletedAt == null) throw validation('family is not deleted');
      final cutoff = DateTime.now().toUtc().subtract(recoveryWindow);
      if (deletedAt.isBefore(cutoff)) {
        throw forbidden('recovery window closed');
      }
      await Family.db.updateRow(
        session,
        family.copyWith(deletedAt: null),
        columns: (c) => [c.deletedAt],
        transaction: t,
      );
    });
  }
```

- [ ] **Step 4: Regenerate and run the tests**

Run: `mise exec -- just server-generate` then `cd apps/server && mise exec -- dart test test/integration/family_endpoint_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/endpoints/family_endpoint.dart apps/server/test/integration/family_endpoint_test.dart apps/server/lib/src/generated apps/server/test/integration/test_tools packages/tell_me_a_story_client
git commit -m "feat(server): family soft delete and recover"
```

### Task 7: FamilyEndpoint origin

**Files:**
- Modify: `apps/server/lib/src/endpoints/family_endpoint.dart`
- Modify: `apps/server/test/integration/family_endpoint_test.dart`
- Regenerate: `apps/server/lib/src/generated/endpoints.dart`, `apps/server/test/integration/test_tools/serverpod_test_tools.dart`, `packages/tell_me_a_story_client/lib/src/protocol/client.dart`

Ports: BR 34–42, 48.

- [ ] **Step 1: Write the failing tests**

Append this group inside `withServerpod` in `apps/server/test/integration/family_endpoint_test.dart`, after the previous group:

```dart
    group('origin', () {
      late UuidValue parentOwner, childOwner, childCo, childMember, outsider;
      late Family parent, child;
      late Story published;

      setUp(() async {
        parentOwner = await fx.user();
        childOwner = await fx.user();
        childCo = await fx.user();
        childMember = await fx.user();
        outsider = await fx.user();
        parent = await fx.rootOwnedBy(parentOwner, name: 'Parent');
        child = await fx.childOf(parent, owner: childOwner);
        await fx.join(child, childCo, MembershipRole.coOwner);
        await fx.join(child, childMember);
        await fx.rootOwnedBy(outsider);
        published = await fx.story(parent);
      });

      Future<UuidValue?> effectiveOrigin(
        UuidValue reader,
        Family family,
      ) async {
        final tree = await endpoints.family.listTree(by(reader), family.id!);
        return tree
            .singleWhere((f) => f.id == family.id)
            .effectiveOriginStoryId;
      }

      // BR 34
      test(
        'when the child owner sets a published parent story then the effective '
        'origin returns it; the child co-owner can change it',
        () async {
          await endpoints.family.setOrigin(
            by(childOwner),
            child.id!,
            published.id!,
          );
          expect(await effectiveOrigin(childMember, child), published.id);
          final another = await fx.story(parent);
          await endpoints.family.setOrigin(by(childCo), child.id!, another.id!);
          expect(await effectiveOrigin(childMember, child), another.id);
        },
      );

      // BR 35
      test(
        'when a child plain member or a non-member sets origin then bare '
        'FORBIDDEN, before NOT_FOUND for a missing or draft story',
        () async {
          final draft = await fx.story(parent, status: StoryStatus.draft);
          for (final user in [childMember, outsider]) {
            for (final storyId in [
              published.id!,
              draft.id!,
              const Uuid().v7obj(),
            ]) {
              await expectLater(
                endpoints.family.setOrigin(by(user), child.id!, storyId),
                throwsAppError(
                  AppErrorCode.forbidden,
                  "You don't have access to that.",
                ),
              );
            }
          }
        },
      );

      // BR 36
      test(
        'when the owner sets a draft, missing or wrong-family story then '
        'NOT_FOUND; a root must use its own story',
        () async {
          final draft = await fx.story(parent, status: StoryStatus.draft);
          final own = await fx.story(child);
          for (final storyId in [draft.id!, const Uuid().v7obj(), own.id!]) {
            await expectLater(
              endpoints.family.setOrigin(by(childOwner), child.id!, storyId),
              throwsAppError(AppErrorCode.notFound),
            );
          }
          await expectLater(
            endpoints.family.setOrigin(by(parentOwner), parent.id!, own.id!),
            throwsAppError(AppErrorCode.notFound),
          );
          await endpoints.family.setOrigin(
            by(parentOwner),
            parent.id!,
            published.id!,
          );
          expect(await effectiveOrigin(parentOwner, parent), published.id);
        },
      );

      // BR 37
      test(
        'when the parent is soft-deleted then setOrigin is VALIDATION '
        '"parent family is deleted"',
        () async {
          await fx.setDeletedAt(parent, DateTime.now().toUtc());
          await expectLater(
            endpoints.family.setOrigin(
              by(childOwner),
              child.id!,
              published.id!,
            ),
            throwsAppError(AppErrorCode.validation, 'parent family is deleted'),
          );
        },
      );

      // BR 38
      test('when two children set the same origin then both have it', () async {
        final sibling = await fx.childOf(parent, owner: childOwner);
        await endpoints.family.setOrigin(
          by(childOwner),
          child.id!,
          published.id!,
        );
        await endpoints.family.setOrigin(
          by(childOwner),
          sibling.id!,
          published.id!,
        );
        expect(await effectiveOrigin(childOwner, child), published.id);
        expect(await effectiveOrigin(childOwner, sibling), published.id);
      });

      // BR 39
      test(
        'when the origin is drafted or the parent deleted then no endpoint '
        'clears originStoryId; the stored value stays',
        () async {
          await fx.setOriginRow(child, published);
          await fx.setStatus(published, StoryStatus.draft);
          await fx.setDeletedAt(parent, DateTime.now().toUtc());
          await expectLater(
            endpoints.family.setOrigin(
              by(childOwner),
              child.id!,
              published.id!,
            ),
            throwsAppError(AppErrorCode.validation, 'parent family is deleted'),
          );
          expect((await fx.reload(child)).originStoryId, published.id);
        },
      );

      // BR 40
      test(
        'when the parent is soft-deleted then the child effective origin is '
        'null; after recovery it returns',
        () async {
          await fx.setOriginRow(child, published);
          await endpoints.family.softDelete(by(parentOwner), parent.id!);
          expect(await effectiveOrigin(childMember, child), isNull);
          await endpoints.family.recover(by(parentOwner), parent.id!);
          expect(await effectiveOrigin(childMember, child), published.id);
        },
      );

      // BR 41
      test(
        'when the origin is unpublished then the effective origin is null; '
        'after republish it is restored',
        () async {
          await fx.setOriginRow(child, published);
          await fx.setStatus(published, StoryStatus.draft);
          expect(await effectiveOrigin(childMember, child), isNull);
          await fx.setStatus(published, StoryStatus.published);
          expect(await effectiveOrigin(childMember, child), published.id);
        },
      );

      // BR 42
      test(
        'when the origin story is deleted then originStoryId is null',
        () async {
          await fx.setOriginRow(child, published);
          await Story.db.deleteRow(fx.s, published);
          expect((await fx.reload(child)).originStoryId, isNull);
        },
      );

      // BR 48
      test(
        'when a parent member lists origin dependents then it sees the child; '
        'an outsider sees none',
        () async {
          await fx.setOriginRow(child, published);
          final dependents = await endpoints.family.listOriginDependents(
            by(parentOwner),
            published.id!,
          );
          expect(dependents.map((d) => (d.familyId, d.name)), [
            (child.id, child.name),
          ]);
          final stranger = await fx.user();
          expect(
            await endpoints.family.listOriginDependents(
              by(stranger),
              published.id!,
            ),
            isEmpty,
          );
        },
      );
    });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd apps/server && mise exec -- dart test test/integration/family_endpoint_test.dart`
Expected: compile error — the `endpoints.family` methods used by the new group don't exist yet.

- [ ] **Step 3: Implement**

Add to `FamilyEndpoint`, after the previous section:

```dart
  // ── origin ───────────────────────────────────────────────────────────

  /// Business-rules.md §3.3: bare FORBIDDEN first, then a deleted parent,
  /// then a story that is missing, unpublished or not in
  /// `coalesce(parent, family)`.
  Future<void> setOrigin(
    Session session,
    UuidValue familyId,
    UuidValue storyId,
  ) async {
    final authz = Authz(session);
    authz.ensure(await authz.isLiveSteward(familyId));
    await session.db.transaction((t) async {
      final family = (await Family.db.findById(
        session,
        familyId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      ))!;
      final parentId = family.parentId;
      if (parentId != null) {
        final parent = await Family.db.findById(
          session,
          parentId,
          transaction: t,
        );
        if (parent == null || parent.deletedAt != null) {
          throw validation('parent family is deleted');
        }
      }
      final story = await Story.db.findById(session, storyId, transaction: t);
      if (story == null ||
          story.status != StoryStatus.published ||
          story.familyId != (parentId ?? familyId)) {
        throw notFound('story');
      }
      await Family.db.updateRow(
        session,
        family.copyWith(originStoryId: storyId),
        columns: (c) => [c.originStoryId],
        transaction: t,
      );
    });
  }

  /// Families whose effective origin is [storyId]. Empty unless the caller is
  /// a live member of the story's family.
  Future<List<OriginDependentDto>> listOriginDependents(
    Session session,
    UuidValue storyId,
  ) async {
    final authz = Authz(session);
    final story = await Story.db.findById(session, storyId);
    if (story == null || !await authz.isLiveMember(story.familyId)) return [];
    final families = await Family.db.find(
      session,
      where: (t) => t.originStoryId.equals(storyId) & t.deletedAt.equals(null),
      orderByList: (t) => [t.createdAt.asc(), t.id.asc()],
    );
    return [
      for (final f in families)
        if (await authz.effectiveOrigin(f) == storyId)
          OriginDependentDto(familyId: f.id!, name: f.name),
    ];
  }
```

- [ ] **Step 4: Regenerate and run the tests**

Run: `mise exec -- just server-generate` then `cd apps/server && mise exec -- dart test test/integration/family_endpoint_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/endpoints/family_endpoint.dart apps/server/test/integration/family_endpoint_test.dart apps/server/lib/src/generated apps/server/test/integration/test_tools packages/tell_me_a_story_client
git commit -m "feat(server): family origin and origin dependents"
```

### Task 8: FamilyEndpoint createBranch

**Files:**
- Modify: `apps/server/lib/src/endpoints/family_endpoint.dart`
- Modify: `apps/server/test/integration/family_endpoint_test.dart`
- Regenerate: `apps/server/lib/src/generated/endpoints.dart`, `apps/server/test/integration/test_tools/serverpod_test_tools.dart`, `packages/tell_me_a_story_client/lib/src/protocol/client.dart`

Ports: BR 50–60, 61 (Dart argument checks), 115, D6d, and the linked-person race.

The race test holds an uncommitted linked person in a second session while `createBranch` runs: the endpoint's insert blocks on `people_tree_user_uidx`, fails with 23505 when the holder commits, and the rerun reuses the committed person. Removing the retry makes this test fail with `DatabaseUniqueViolationException`.

- [ ] **Step 1: Write the failing tests**

Append this group inside `withServerpod` in `apps/server/test/integration/family_endpoint_test.dart`, after the previous group:

```dart
    group('createBranch', () {
      late UuidValue parentOwner, starter, owner, coOwner, stranger;
      late Family parent;
      late Story origin;

      setUp(() async {
        parentOwner = await fx.user();
        starter = await fx.user();
        owner = await fx.userWithEmail(uniqueEmail(), displayName: 'Xavier');
        coOwner = await fx.user();
        stranger = await fx.user();
        parent = await fx.rootOwnedBy(parentOwner, name: 'Morgans');
        await fx.join(parent, starter);
        await fx.join(parent, owner);
        await fx.join(parent, coOwner, MembershipRole.coOwner);
        origin = await fx.story(parent);
      });

      Future<UuidValue> branch(
        UuidValue caller, {
        Family? from,
        UuidValue? originStoryId,
        String name = 'Branch',
        int branchYear = 1987,
        UuidValue? ownerUserId,
        List<UuidValue> personIds = const [],
      }) => endpoints.family.createBranch(
        by(caller),
        parentFamilyId: (from ?? parent).id!,
        originStoryId: originStoryId ?? origin.id!,
        name: name,
        branchYear: branchYear,
        ownerUserId: ownerUserId ?? owner,
        personIds: personIds,
      );

      Future<int> familyCount() => Family.db.count(
        fx.s,
        where: (t) => t.treeId.equals(parent.treeId),
      );

      // BR 50
      test(
        'when a parent member creates " The Morgan-Reyes " for X then the '
        'branch is trimmed, parented, dated, created by the caller, has the '
        'origin and exactly one owner X',
        () async {
          final id = await branch(starter, name: ' The Morgan-Reyes ');
          final created = (await Family.db.findById(fx.s, id))!;
          expect(created.name, 'The Morgan-Reyes');
          expect(created.parentId, parent.id);
          expect(created.treeId, parent.treeId);
          expect(created.branchYear, 1987);
          expect(created.createdById, starter);
          expect(created.originStoryId, origin.id);
          final owners = await Membership.db.find(
            fx.s,
            where: (t) =>
                t.familyId.equals(id) & t.role.equals(MembershipRole.owner),
          );
          expect(owners.map((m) => m.userId), [owner]);
        },
      );

      // BR 51
      test(
        'when the caller is neither picked nor owner then it is not a member '
        'of the branch and stays owner of the parent',
        () async {
          final id = await branch(parentOwner);
          expect(
            await fx.roleOf((await Family.db.findById(fx.s, id))!, parentOwner),
            isNull,
          );
          expect(await fx.roleOf(parent, parentOwner), MembershipRole.owner);
        },
      );

      // BR 52 (D6d)
      test(
        'when people are picked then linked ones become members, unlinked get '
        'nothing, no people are copied, the owner keeps owner, and the owner '
        'and each linked member have exactly one linked person in the tree',
        () async {
          final linkedUser = await fx.user();
          await fx.join(parent, linkedUser);
          final linked = await fx.person(parent, userId: linkedUser);
          final unlinked = await fx.person(parent, name: 'No account');
          final ownerPerson = await fx.person(parent, userId: owner);
          final peopleBefore = await Person.db.count(
            fx.s,
            where: (t) => t.treeId.equals(parent.treeId),
          );

          final id = await branch(
            starter,
            personIds: [linked.id!, unlinked.id!, ownerPerson.id!, linked.id!],
          );

          final created = (await Family.db.findById(fx.s, id))!;
          final memberships = await Membership.db.find(
            fx.s,
            where: (t) => t.familyId.equals(id),
          );
          expect(
            {for (final m in memberships) m.userId: m.role},
            {owner: MembershipRole.owner, linkedUser: MembershipRole.member},
          );
          expect(
            await Person.db.count(
              fx.s,
              where: (t) => t.treeId.equals(created.treeId),
            ),
            peopleBefore,
          );
          for (final user in [owner, linkedUser]) {
            expect(await fx.linkedPeople(parent.treeId, user), hasLength(1));
          }
        },
      );

      // BR 52 (D6d: owner without a linked person gets one in the branch)
      test(
        'when the owner has no linked person in the tree then one is created '
        'in the branch with the display name',
        () async {
          final id = await branch(starter);
          final linked = await fx.linkedPeople(parent.treeId, owner);
          expect(linked, hasLength(1));
          expect(linked.single.homeFamilyId, id);
          expect(linked.single.name, 'Xavier');
        },
      );

      // BR 115
      test(
        'when a user is a member of parent and child then exactly one linked '
        'person is in the tree',
        () async {
          await fx.person(parent, userId: owner);
          await branch(starter);
          expect(await fx.linkedPeople(parent.treeId, owner), hasLength(1));
        },
      );

      // BR 53
      test(
        'when a parent co-owner creates with itself as owner then OK; the new '
        'owner can change origin and the starter cannot',
        () async {
          final id = await branch(coOwner, ownerUserId: coOwner);
          final other = await fx.story(parent);
          await endpoints.family.setOrigin(by(coOwner), id, other.id!);
          final viaStarter = await branch(starter);
          await expectLater(
            endpoints.family.setOrigin(by(starter), viaStarter, other.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
          expect(
            (await Family.db.findById(fx.s, id))!.originStoryId,
            other.id,
          );
        },
      );

      // BR 54
      test(
        'when the origin is random, draft, sibling or grandparent then '
        'NOT_FOUND "story" and no family is written',
        () async {
          final draft = await fx.story(parent, status: StoryStatus.draft);
          final sibling = await fx.childOf(parent, owner: starter);
          final siblingStory = await fx.story(sibling);
          final child = await fx.childOf(parent, owner: starter);
          final before = await familyCount();
          for (final storyId in [
            const Uuid().v7obj(),
            draft.id!,
            siblingStory.id!,
          ]) {
            await expectLater(
              branch(starter, originStoryId: storyId),
              throwsAppError(AppErrorCode.notFound, 'story'),
            );
          }
          await expectLater(
            branch(
              starter,
              from: child,
              originStoryId: origin.id!,
              ownerUserId: starter,
            ),
            throwsAppError(AppErrorCode.notFound, 'story'),
          );
          expect(await familyCount(), before);
        },
      );

      // BR 55
      test(
        'when a stranger, a tree reader who is not a parent member, or a '
        'missing parent then FORBIDDEN "member only" before story and name',
        () async {
          final reader = await fx.user();
          await fx.childOf(parent, owner: reader);
          for (final user in [stranger, reader]) {
            await expectLater(
              branch(
                user,
                originStoryId: const Uuid().v7obj(),
                name: ' ',
              ),
              throwsAppError(AppErrorCode.forbidden, 'member only'),
            );
          }
          await expectLater(
            endpoints.family.createBranch(
              by(starter),
              parentFamilyId: const Uuid().v7obj(),
              originStoryId: origin.id!,
              name: 'X',
              branchYear: 1987,
              ownerUserId: owner,
              personIds: const [],
            ),
            throwsAppError(AppErrorCode.forbidden, 'member only'),
          );
        },
      );

      // BR 56
      test(
        'when the origin is bad and the name blank then NOT_FOUND',
        () async {
          await expectLater(
            branch(starter, originStoryId: const Uuid().v7obj(), name: ' '),
            throwsAppError(AppErrorCode.notFound, 'story'),
          );
        },
      );

      // BR 57, BR 61 (Dart argument checks)
      test(
        'when the name is blank then "name is required"; year 987 or 10000 '
        'then "attach year must be four digits"',
        () async {
          await expectLater(
            branch(starter, name: ' \t '),
            throwsAppError(AppErrorCode.validation, 'name is required'),
          );
          for (final year in [987, 10000]) {
            await expectLater(
              branch(starter, branchYear: year),
              throwsAppError(
                AppErrorCode.validation,
                'attach year must be four digits',
              ),
            );
          }
        },
      );

      // BR 58
      test(
        'when the owner is not a parent member then VALIDATION "owner must be '
        'a member of the parent family"',
        () async {
          await expectLater(
            branch(starter, ownerUserId: stranger),
            throwsAppError(
              AppErrorCode.validation,
              'owner must be a member of the parent family',
            ),
          );
        },
      );

      // BR 59
      test(
        'when a picked person is from another family then VALIDATION "members '
        'must come from the parent family" and nothing is written',
        () async {
          final sibling = await fx.childOf(parent, owner: starter);
          final siblingPerson = await fx.person(sibling);
          final foreign = await fx.person(await fx.rootOwnedBy(stranger));
          final before = await familyCount();
          for (final p in [siblingPerson, foreign]) {
            await expectLater(
              branch(starter, personIds: [p.id!]),
              throwsAppError(
                AppErrorCode.validation,
                'members must come from the parent family',
              ),
            );
          }
          await expectLater(
            branch(starter, personIds: [const Uuid().v7obj()]),
            throwsAppError(
              AppErrorCode.validation,
              'members must come from the parent family',
            ),
          );
          expect(await familyCount(), before);
          expect(await fx.linkedPeople(parent.treeId, owner), isEmpty);
        },
      );

      // BR 60
      test(
        'when the parent is at depth 62 then create succeeds; one deeper is '
        'VALIDATION "too many levels" and nothing is written',
        () async {
          var deepest = parent;
          for (var depth = 1; depth <= 62; depth++) {
            deepest = await fx.childOf(deepest, name: 'L$depth');
          }
          await fx.join(deepest, owner);
          final atDepth63 = await branch(
            owner,
            from: deepest,
            originStoryId: (await fx.story(deepest)).id!,
            ownerUserId: owner,
          );
          final deeper = (await Family.db.findById(fx.s, atDepth63))!;
          final before = await familyCount();
          await expectLater(
            branch(
              owner,
              from: deeper,
              originStoryId: (await fx.story(deeper)).id!,
              ownerUserId: owner,
            ),
            throwsAppError(AppErrorCode.validation, 'too many levels'),
          );
          expect(await familyCount(), before);
        },
      );

      test(
        'when the owner linked person is inserted concurrently then the lost '
        'people_tree_user_uidx race reruns once and reuses that person',
        () async {
          final racer = sessionBuilder.build();
          late Person raced;
          final insert = racer.db.transaction((t) async {
            raced = await Person.db.insertRow(
              racer,
              Person(
                treeId: parent.treeId,
                homeFamilyId: parent.id!,
                userId: owner,
                name: 'Raced',
              ),
              transaction: t,
            );
            // Hold the uncommitted row so the endpoint's insert blocks on it.
            await Future<void>.delayed(const Duration(milliseconds: 500));
          });
          await Future<void>.delayed(const Duration(milliseconds: 50));
          final id = await branch(starter);
          await insert;

          final linked = await fx.linkedPeople(parent.treeId, owner);
          expect(linked.map((p) => p.id), [raced.id]);
          expect(
            await fx.roleOf((await Family.db.findById(fx.s, id))!, owner),
            MembershipRole.owner,
          );
        },
      );
    });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd apps/server && mise exec -- dart test test/integration/family_endpoint_test.dart`
Expected: compile error — the `endpoints.family` methods used by the new group don't exist yet.

- [ ] **Step 3: Add the imports and constants**

Add above the class doc comment:

```dart
/// Branch creation refuses a parent this many levels deep (business-rules.md
/// §3.2 step 7).
const maxBranchDepth = 63;
```

- [ ] **Step 4: Implement**

Add to `FamilyEndpoint`, after the previous section:

```dart
  // ── branch ───────────────────────────────────────────────────────────

  /// "Start a new timeline" (business-rules.md §3.2, in that check order).
  /// The owner and each picked linked member get a linked person in the tree
  /// (D6d). A lost race on `people_tree_user_uidx` reruns the write once.
  Future<UuidValue> createBranch(
    Session session, {
    required UuidValue parentFamilyId,
    required UuidValue originStoryId,
    required String name,
    required int branchYear,
    required UuidValue ownerUserId,
    List<UuidValue> personIds = const [],
  }) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    await authz.requireLiveMember(parentFamilyId);
    final parent = (await Family.db.findById(session, parentFamilyId))!;
    final story = await Story.db.findById(session, originStoryId);
    if (story == null ||
        story.status != StoryStatus.published ||
        story.familyId != parentFamilyId) {
      throw notFound('story');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw validation('name is required');
    if (branchYear < 1000 || branchYear > 9999) {
      throw validation('attach year must be four digits');
    }
    final ownerMembership = await Membership.db.findFirstRow(
      session,
      where: (t) =>
          t.familyId.equals(parentFamilyId) & t.userId.equals(ownerUserId),
    );
    if (ownerMembership == null) {
      throw validation('owner must be a member of the parent family');
    }
    final pickedIds = personIds.toSet();
    final picked = pickedIds.isEmpty
        ? const <Person>[]
        : await Person.db.find(
            session,
            where: (t) => t.id.inSet(pickedIds),
          );
    if (picked.length != pickedIds.length ||
        picked.any((p) => p.homeFamilyId != parentFamilyId)) {
      throw validation('members must come from the parent family');
    }
    if (await _depth(session, parent) >= maxBranchDepth) {
      throw validation('too many levels');
    }
    final memberIds = {
      for (final p in picked)
        if (p.userId != null) p.userId!,
    };

    Future<UuidValue> write() => session.db.transaction((t) async {
      final branch = await Family.db.insertRow(
        session,
        Family(
          treeId: parent.treeId,
          parentId: parentFamilyId,
          name: trimmed,
          branchYear: branchYear,
          originStoryId: originStoryId,
          createdById: uid,
        ),
        transaction: t,
      );
      await Membership.db.insertRow(
        session,
        Membership(
          familyId: branch.id!,
          userId: ownerUserId,
          role: MembershipRole.owner,
        ),
        transaction: t,
      );
      for (final memberId in memberIds.difference({ownerUserId})) {
        await Membership.db.insertRow(
          session,
          Membership(familyId: branch.id!, userId: memberId),
          transaction: t,
        );
      }
      for (final userId in {ownerUserId, ...memberIds}) {
        await ensureLinkedPerson(
          session,
          treeId: parent.treeId,
          homeFamilyId: branch.id!,
          userId: userId,
          transaction: t,
        );
      }
      return branch.id!;
    });

    try {
      return await write();
    } on DatabaseQueryException catch (e) {
      if (e.code != '23505' || e.constraintName != 'people_tree_user_uidx') {
        rethrow;
      }
      return write();
    }
  }
```

Append to the end of `apps/server/lib/src/endpoints/family_endpoint.dart`:

```dart
/// Ancestors above [family], walking `parentId` (deleted families included,
/// D8); cycle-safe and capped one past [maxBranchDepth].
Future<int> _depth(Session session, Family family) async {
  final seen = {family.id!};
  var depth = 0;
  var cursor = family;
  while (cursor.parentId != null && depth <= maxBranchDepth) {
    final up = await Family.db.findById(session, cursor.parentId!);
    if (up == null || !seen.add(up.id!)) break;
    depth++;
    cursor = up;
  }
  return depth;
}
```

- [ ] **Step 5: Regenerate and run the tests**

Run: `mise exec -- just server-generate` then `cd apps/server && mise exec -- dart test test/integration/family_endpoint_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/server/lib/src/endpoints/family_endpoint.dart apps/server/test/integration/family_endpoint_test.dart apps/server/lib/src/generated apps/server/test/integration/test_tools packages/tell_me_a_story_client
git commit -m "feat(server): createBranch with linked people and race retry"
```

### Task 9: FamilyEndpoint cover upload

**Files:**
- Modify: `apps/server/lib/src/endpoints/family_endpoint.dart`
- Modify: `apps/server/test/integration/family_endpoint_test.dart`
- Regenerate: `apps/server/lib/src/generated/endpoints.dart`, `apps/server/test/integration/test_tools/serverpod_test_tools.dart`, `packages/tell_me_a_story_client/lib/src/protocol/client.dart`

Ports: BR 22, 23, 24 (reshaped).

- [ ] **Step 1: Write the failing tests**

Append this group inside `withServerpod` in `apps/server/test/integration/family_endpoint_test.dart`, after the previous group:

```dart
    group('cover', () {
      late UuidValue owner, coOwner, member;
      late Family family;

      setUp(() async {
        owner = await fx.user();
        coOwner = await fx.user();
        member = await fx.user();
        family = await fx.rootOwnedBy(owner);
        await fx.join(family, coOwner, MembershipRole.coOwner);
        await fx.join(family, member);
      });

      Future<String> uploadCover(
        UuidValue steward, {
        String mimeType = 'image/jpeg',
        List<int>? bytes,
      }) async {
        final body = bytes ?? jpegBytes;
        final ticket = await endpoints.family.startCoverUpload(
          by(steward),
          family.id!,
          mimeType,
          body.length,
        );
        await fx.upload(ticket.key, body);
        return ticket.key;
      }

      // BR 23
      test(
        'when the owner or co-owner uploads a cover then it is stored and the '
        'previous key is queued; a plain member is FORBIDDEN',
        () async {
          final first = await uploadCover(owner);
          expect(
            first,
            matches(
              RegExp(
                '^families/${family.id!.uuid}/cover/[0-9a-f-]{36}\\.jpg\$',
              ),
            ),
          );
          expect(
            await endpoints.family.finishCoverUpload(
              by(owner),
              family.id!,
              first,
            ),
            first,
          );
          expect((await fx.reload(family)).coverKey, first);

          final second = await uploadCover(
            coOwner,
            mimeType: 'image/png',
            bytes: pngBytes,
          );
          expect(second, endsWith('.png'));
          await endpoints.family.finishCoverUpload(
            by(coOwner),
            family.id!,
            second,
          );
          expect((await fx.reload(family)).coverKey, second);
          expect(await fx.queuedBlobKeys(), contains(first));

          await expectLater(
            endpoints.family.startCoverUpload(
              by(member),
              family.id!,
              'image/jpeg',
              10,
            ),
            throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
          );
          await expectLater(
            endpoints.family.finishCoverUpload(by(member), family.id!, second),
            throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
          );
        },
      );

      // BR 24
      test(
        'when the type is unsupported or the declared size is over 5 MiB then '
        'startCoverUpload is VALIDATION',
        () async {
          await expectLater(
            endpoints.family.startCoverUpload(
              by(owner),
              family.id!,
              'image/svg+xml',
              10,
            ),
            throwsAppError(AppErrorCode.validation, 'unsupported image type'),
          );
          await expectLater(
            endpoints.family.startCoverUpload(
              by(owner),
              family.id!,
              'image/jpeg',
              5242881,
            ),
            throwsAppError(AppErrorCode.validation, 'file is too large'),
          );
        },
      );

      // BR 24
      test(
        'when the bytes are not an image, not the declared type, or over '
        '5 MiB then VALIDATION, the blob is queued and the cover unchanged',
        () async {
          final svg = await uploadCover(owner, bytes: svgBytes);
          final mismatch = await uploadCover(owner, mimeType: 'image/png');
          final ticket = await endpoints.family.startCoverUpload(
            by(owner),
            family.id!,
            'image/jpeg',
            10,
          );
          await fx.upload(ticket.key, [
            ...jpegBytes,
            ...List.filled(5242880, 0),
          ]);
          for (final (key, message) in [
            (svg, 'unsupported image type'),
            (mismatch, 'unsupported image type'),
            (ticket.key, 'file is too large'),
          ]) {
            await expectLater(
              endpoints.family.finishCoverUpload(by(owner), family.id!, key),
              throwsAppError(AppErrorCode.validation, message),
            );
          }
          expect(
            await fx.queuedBlobKeys(),
            containsAll([svg, mismatch, ticket.key]),
          );
          expect((await fx.reload(family)).coverKey, isNull);
        },
      );

      // BR 24
      test(
        'when the key is not one the server issues for this family, or was '
        'never uploaded, then VALIDATION',
        () async {
          final other = await fx.rootOwnedBy(owner);
          for (final key in [
            'https://example.com/cover.jpg',
            'families/${other.id}/cover/${const Uuid().v7()}.jpg',
            'families/${family.id}/cover/../../x.jpg',
            'families/${family.id}/avatar/${const Uuid().v7()}.jpg',
            'families/${family.id}/cover/${const Uuid().v7()}.gif',
          ]) {
            await expectLater(
              endpoints.family.finishCoverUpload(by(owner), family.id!, key),
              throwsAppError(AppErrorCode.validation, 'invalid cover key'),
            );
          }
          await expectLater(
            endpoints.family.finishCoverUpload(
              by(owner),
              family.id!,
              'families/${family.id}/cover/${const Uuid().v7()}.jpg',
            ),
            throwsAppError(AppErrorCode.validation, 'upload not found'),
          );
        },
      );

      test('when a steward clears the cover then the key is queued', () async {
        final key = await uploadCover(owner);
        await endpoints.family.finishCoverUpload(by(owner), family.id!, key);
        await expectLater(
          endpoints.family.clearCover(by(member), family.id!),
          throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
        );
        await endpoints.family.clearCover(by(coOwner), family.id!);
        expect((await fx.reload(family)).coverKey, isNull);
        expect(await fx.queuedBlobKeys(), contains(key));
      });

      // BR 22
      test(
        'when stewards write through the API then id, createdById, parentId '
        'and treeId never change (no endpoint writes them)',
        () async {
          final child = await fx.childOf(family, owner: owner);
          final before = await fx.reload(child);
          await endpoints.family.rename(by(owner), child.id!, 'Renamed');
          await endpoints.family.clearCover(by(owner), child.id!);
          await endpoints.family.softDelete(by(owner), child.id!);
          await endpoints.family.recover(by(owner), child.id!);
          final after = await fx.reload(child);
          expect(after.id, before.id);
          expect(after.createdById, before.createdById);
          expect(after.parentId, before.parentId);
          expect(after.treeId, before.treeId);
        },
      );
    });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd apps/server && mise exec -- dart test test/integration/family_endpoint_test.dart`
Expected: compile error — the `endpoints.family` methods used by the new group don't exist yet.

- [ ] **Step 3: Add the imports and constants**

Add to the imports of `apps/server/lib/src/endpoints/family_endpoint.dart`:

```dart
import '../media/blob_keys.dart';
import '../media/blob_outbox.dart';
```

Add above the class doc comment:

```dart
const _mimeByExt = {
  'jpg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
};
```

- [ ] **Step 4: Implement**

Add to `FamilyEndpoint`, after the previous section:

```dart
  // ── cover ────────────────────────────────────────────────────────────

  /// Steward of the live family. [mimeType] (jpeg, png or webp) picks the key
  /// extension; [byteLength] is pinned in the upload, at most 5 MiB.
  Future<CoverUploadTicketDto> startCoverUpload(
    Session session,
    UuidValue familyId,
    String mimeType,
    int byteLength,
  ) async {
    await Authz(session).requireLiveSteward(familyId);
    final key = familyCoverKey(familyId: familyId, mimeType: mimeType);
    if (byteLength < 1) throw validation('file is empty');
    if (byteLength > coverMaxBytes) throw validation('file is too large');
    final description = await session.storage.createUploadDescription(
      storageId: blobStorageId,
      path: key,
      options: UploadOptions(
        maxFileSize: coverMaxBytes,
        contentLength: byteLength,
        preventOverwrite: true,
        metadata: FileMetadata(contentType: mimeType),
      ),
    );
    return CoverUploadTicketDto(key: key, uploadDescription: description);
  }

  /// Verifies the upload at [key], checks its size and that its bytes are the
  /// image type its extension names, then makes it the cover. A rejected blob
  /// is queued for deletion; the previous cover key is queued in the same
  /// transaction that replaces it.
  Future<String> finishCoverUpload(
    Session session,
    UuidValue familyId,
    String key,
  ) async {
    await Authz(session).requireLiveSteward(familyId);
    final mimeType = _coverKeyMime(familyId, key);
    final current = await Family.db.findById(session, familyId);
    if (current!.coverKey == key) return key;
    final uploaded = await session.storage.verifyUpload(
      storageId: blobStorageId,
      path: key,
    );
    if (!uploaded) throw validation('upload not found');
    final bytes = await session.storage.retrieveFile(
      storageId: blobStorageId,
      path: key,
    );
    if (bytes.lengthInBytes > coverMaxBytes) {
      await queueBlobDeletions(session, [key]);
      throw validation('file is too large');
    }
    if (sniffImageMime(bytes) != mimeType) {
      await queueBlobDeletions(session, [key]);
      throw validation('unsupported image type');
    }
    try {
      await session.db.transaction((t) async {
        final family = (await Family.db.findById(
          session,
          familyId,
          transaction: t,
          lockMode: LockMode.forUpdate,
        ))!;
        await queueBlobDeletions(session, [family.coverKey], transaction: t);
        await Family.db.updateRow(
          session,
          family.copyWith(coverKey: key),
          columns: (c) => [c.coverKey],
          transaction: t,
        );
      });
    } catch (_) {
      await queueBlobDeletions(session, [key]);
      rethrow;
    }
    return key;
  }

  Future<void> clearCover(Session session, UuidValue familyId) async {
    await Authz(session).requireLiveSteward(familyId);
    await session.db.transaction((t) async {
      final family = (await Family.db.findById(
        session,
        familyId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      ))!;
      if (family.coverKey == null) return;
      await queueBlobDeletions(session, [family.coverKey], transaction: t);
      await Family.db.updateRow(
        session,
        family.copyWith(coverKey: null),
        columns: (c) => [c.coverKey],
        transaction: t,
      );
    });
  }
```

Append to the end of `apps/server/lib/src/endpoints/family_endpoint.dart`:

```dart
/// The MIME type a cover [key] of [familyId] names by its extension;
/// VALIDATION for any key the server could not have issued for this family.
String _coverKeyMime(UuidValue familyId, String key) {
  final prefix = 'families/$familyId/cover/';
  final match = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$',
  ).firstMatch(key.startsWith(prefix) ? key.substring(prefix.length) : '');
  if (match == null) throw validation('invalid cover key');
  return _mimeByExt[match.group(1)]!;
}
```

- [ ] **Step 5: Regenerate and run the tests**

Run: `mise exec -- just server-generate` then `cd apps/server && mise exec -- dart test test/integration/family_endpoint_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/server/lib/src/endpoints/family_endpoint.dart apps/server/test/integration/family_endpoint_test.dart apps/server/lib/src/generated apps/server/test/integration/test_tools packages/tell_me_a_story_client
git commit -m "feat(server): family cover upload with sniffing and blob queue"
```

### Task 10: Gate and self-review

- [ ] **Step 1: Format, analyze, test**

Run:
```bash
mise exec -- dart format --output=none --set-exit-if-changed apps/server/lib apps/server/test
(cd apps/server && mise exec -- dart analyze lib test)
(cd packages/tell_me_a_story_client && mise exec -- dart analyze)
mise exec -- just server-test
```
Expected: `0 changed`, `No issues found!` twice, `All tests passed!`.

- [ ] **Step 2: Keep this plan in sync**

If any landed code differs from a code block above, update the block and commit `docs: sync Phase 3a plan with landed code`.

- [ ] **Step 3: Self-review against the slice row**

| Port case | Test |
|---|---|
| 1, 2, 3 | createRoot group |
| 4–13 | roles group |
| 14 | roles: BR 6 / BR 14 |
| 15 | roles: BR 15 |
| 16, 19 | soft delete and recover group |
| 17, 18 | reads group |
| 22 | cover group: BR 22 |
| 23, 24 | cover group |
| 29–32 | reads group |
| 34–42, 48 | origin group |
| 50–60, 61, 115 | createBranch group |
| 106, 107, 109, 111 | profile_endpoint_test |
| 110 | reads (listMembers) + profile avatar |
| 137 (place part) | place_endpoint_test |
