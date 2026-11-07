# Phase 3.0: Server Endpoints — Shared Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land everything the six Phase 3 endpoint slices share, so they can run in parallel without touching the same files: live-family `Authz` checks and story predicates, every protocol DTO, blob keys and the `blob_deletions` queue, account helpers for invite email binding (D2) and branch person rows (D6d), the live-event channel helper, and shared test fixtures.

**Architecture:** Server-side helpers under `apps/server/lib/src/` (`authz/`, `media/`, `accounts/`, `live/`, `errors.dart`) plus non-table DTO models under `lib/src/models/dto/`. No endpoint classes yet; each slice adds its own. All DTOs are generated here once, so slices never regenerate `protocol.dart` concurrently.

**Tech Stack:** Dart 3.13.5, Serverpod 4.1.1 (`serverpod`, `serverpod_auth_idp_server`, `serverpod_test`), embedded Postgres 16, just.

**Verified:** every file below was written and run on 2026-11-07 in a scratch worktree of `feat/serverpod-migration` at `93646e1`. `dart analyze` was clean on the server and the generated client, `dart format` left nothing to change, and `dart test` gave 92/92 (58 before). A throwaway probe endpoint also confirmed the endpoint conventions in the Phase 3 index (`2026-11-07-serverpod-phase3-server-endpoints.md` §Conventions) and was then deleted.

**References:** `docs/migration/business-rules.md` §1 (predicates), `docs/migration/schema-design.md` §3.2, §3.5, §4.2, §4.3, `docs/migration/endpoint-contract.md` §2.1, roadmap "Product decisions (2026-11-07)".

All commands run from the repo root unless a step says otherwise.

---

## File map

| Path | Responsibility |
|---|---|
| `apps/server/test/integration/support/fixtures.dart` | Shared row builders (`Fx`), `asUser`/`sessionFor`, `throwsAppError`, `pgError` |
| `apps/server/lib/src/errors.dart` | `forbidden`/`notFound`/`validation`/`conflict` `AppException` shorthands |
| `apps/server/lib/src/authz/authz.dart` | Adds live-family require helpers, `effectiveOrigin`, `canReadStory`, `canEditStory`, `canContribute` |
| `apps/server/lib/src/models/dto/*.spy.yaml` | Every DTO and enum in endpoint-contract §2.1 (32 classes, 2 enums) |
| `apps/server/lib/src/media/blob_keys.dart` | Key builders per schema-design §4.2, size limits, `sniffImageMime` |
| `apps/server/lib/src/media/blob_outbox.dart` | `queueBlobDeletions` (same transaction) and `drainBlobDeletions` |
| `apps/server/lib/src/accounts/accounts.dart` | `normalizeEmail`, `accountEmail`, `linkedPersonName`, `ensureLinkedPerson` |
| `apps/server/lib/src/live/live_events.dart` | `familyChannel`, `storyChannel`, `postLiveEvent` |

---

### Task 1: Shared test fixtures

Every slice writes integration tests against the shared (non-rolled-back) test database. Move the row builders out of `constraints_test.dart` so all tests use one `Fx`.

**Files:**
- Create: `apps/server/test/integration/support/fixtures.dart`
- Modify: `apps/server/test/integration/constraints_test.dart:1-167`

- [ ] **Step 1: Create the fixtures file**

`apps/server/test/integration/support/fixtures.dart` (Task 6 adds `userWithEmail` to it later):

```dart
import 'dart:math';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import '../test_tools/serverpod_test_tools.dart';

/// Postgres error with [code] (SQLSTATE), raised by [constraint] when given.
Matcher pgError(String code, [String? constraint]) {
  var m = isA<DatabaseQueryException>().having((e) => e.code, 'code', code);
  if (constraint != null) {
    m = m.having((e) => e.constraintName, 'constraintName', constraint);
  }
  return m;
}

const fkViolation = '23503';
const checkViolation = '23514';
const uniqueViolation = '23505';

/// Throws an [AppException] with [code] and, when given, exactly [message].
Matcher throwsAppError(AppErrorCode code, [String? message]) {
  var m = isA<AppException>().having((e) => e.code, 'code', code);
  if (message != null) {
    m = m.having((e) => e.message, 'message', message);
  }
  return throwsA(m);
}

/// A session authenticated as [user], or anonymous when [user] is null.
Session sessionFor(TestSessionBuilder sessionBuilder, UuidValue? user) =>
    asUser(sessionBuilder, user).build();

/// [sessionBuilder] authenticated as [user], or anonymous when [user] is null.
/// Pass the result to `endpoints.<name>.<method>(...)`.
TestSessionBuilder asUser(TestSessionBuilder sessionBuilder, UuidValue? user) =>
    user == null
    ? sessionBuilder
    : sessionBuilder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(
          user.uuid,
          {},
        ),
      );

final _random = Random.secure();

/// A well-formed, unique token hash (invites_token_hash_uidx is global).
String tokenHash() =>
    List.generate(64, (_) => _random.nextInt(16).toRadixString(16)).join();

/// Row builders. Every test makes its own users and trees, so tests stay
/// independent on the shared (non-rolled-back) test database.
class Fx {
  Fx(this.s);

  final Session s;

  /// A new auth user. `configureAuth` must have run (its hook creates the
  /// matching `users` row).
  Future<UuidValue> user() async =>
      (await AuthServices.instance.authUsers.create(s)).id;

  Future<Membership> join(
    Family family,
    UuidValue user, [
    MembershipRole role = MembershipRole.member,
  ]) => Membership.db.insertRow(
    s,
    Membership(familyId: family.id!, userId: user, role: role),
  );

  Future<Tree> tree() => Tree.db.insertRow(s, Tree());

  Future<Family> family(
    Tree tree, {
    UuidValue? parentId,
    int? branchYear,
    String name = 'Mortang',
    DateTime? deletedAt,
  }) => Family.db.insertRow(
    s,
    Family(
      treeId: tree.id!,
      parentId: parentId,
      name: name,
      branchYear: branchYear,
      deletedAt: deletedAt,
    ),
  );

  Future<Person> person(
    Family home, {
    UuidValue? treeId,
    UuidValue? userId,
    String name = 'Ada',
    DateTime? birthDate,
    DatePrecision? birthPrecision,
    DateTime? deathDate,
    DatePrecision? deathPrecision,
    bool passedAway = false,
  }) => Person.db.insertRow(
    s,
    Person(
      treeId: treeId ?? home.treeId,
      homeFamilyId: home.id!,
      userId: userId,
      name: name,
      birthDate: birthDate,
      birthPrecision: birthPrecision,
      deathDate: deathDate,
      deathPrecision: deathPrecision,
      passedAway: passedAway,
    ),
  );

  Future<Place> place(Tree tree, {String? mapboxPlaceId}) => Place.db.insertRow(
    s,
    Place(
      treeId: tree.id!,
      label: 'Home',
      address: '1 Main St',
      lat: 1,
      lng: 2,
      mapboxPlaceId: mapboxPlaceId,
    ),
  );

  /// A year-precision story in 1950, published unless [status] says otherwise.
  Future<Story> story(
    Family family, {
    UuidValue? treeId,
    UuidValue? placeId,
    UuidValue? authorId,
    StoryStatus status = StoryStatus.published,
  }) => Story.db.insertRow(
    s,
    Story(
      familyId: family.id!,
      treeId: treeId ?? family.treeId,
      authorId: authorId,
      title: 'A story',
      status: status,
      dateStart: DateTime.utc(1950),
      dateEnd: DateTime.utc(1950, 12, 31),
      datePrecision: DatePrecision.year,
      placeId: placeId,
      publishedAt: status == StoryStatus.published
          ? DateTime.now().toUtc()
          : null,
    ),
  );

  Future<StoryPerson> tag(Story story, Person person) =>
      StoryPerson.db.insertRow(
        s,
        StoryPerson(
          storyId: story.id!,
          personId: person.id!,
          treeId: story.treeId,
        ),
      );

  Future<Kinship> kinship(
    Person from,
    Person to, {
    KinshipKind kind = KinshipKind.parentOf,
    UuidValue? createdById,
  }) => Kinship.db.insertRow(
    s,
    Kinship(
      treeId: from.treeId,
      kind: kind,
      fromPersonId: from.id!,
      toPersonId: to.id!,
      createdById: createdById,
    ),
  );

  Future<Invite> invite(Family family, {UuidValue? personId}) =>
      Invite.db.insertRow(
        s,
        Invite(
          familyId: family.id!,
          treeId: family.treeId,
          personId: personId,
          tokenHash: tokenHash(),
          expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
        ),
      );

  /// Two people in one tree, ordered so `first.id < second.id` as Postgres
  /// compares uuids (byte order, which matches the canonical string order).
  Future<(Person, Person)> orderedPair(Family home) async {
    final a = await person(home, name: 'A');
    final b = await person(home, name: 'B');
    return a.id!.uuid.compareTo(b.id!.uuid) < 0 ? (a, b) : (b, a);
  }

  Future<bool> constraintExists(String name) async {
    final rows = await s.db.unsafeQuery(
      "SELECT 1 FROM pg_constraint WHERE conname = '$name'",
    );
    return rows.isNotEmpty;
  }
}
```

- [ ] **Step 2: Point `constraints_test.dart` at it**

Replace lines 1–167 (the imports through the closing brace of `class Fx` and the blank line after it, just before `void main() {`) with:

```dart
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/db/constraints.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

```

- [ ] **Step 3: Run the suite**

Run: `mise exec -- just server-test`
Expected: `+58: All tests passed!`

- [ ] **Step 4: Commit**

```bash
git add apps/server/test/integration/support/fixtures.dart apps/server/test/integration/constraints_test.dart
git commit -m "test(server): shared integration fixtures"
```

---

### Task 2: Live-family and story predicates in `Authz`

D6b makes every write and every member read require a live family. Slices call `requireLiveMember` / `requireLiveSteward` / `requireLiveOwner` instead of re-deriving the check, and use the story predicates from business-rules §1 (`canContribute`, `canEditStory`) and schema-design §3.5 (`effectiveOrigin`). The messages are the §5.2 catalogue strings.

**Files:**
- Create: `apps/server/lib/src/errors.dart`
- Modify: `apps/server/lib/src/authz/authz.dart` (full content below)
- Modify: `apps/server/test/integration/authz_test.dart` (full content below)

- [ ] **Step 1: Write the failing tests**

`apps/server/test/integration/authz_test.dart`:

```dart
import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/authz/authz.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given families in one tree', (sessionBuilder, endpoints) {
    late Fx fx;
    late UuidValue owner, coOwner, member, branchOwner, branchMember, stranger;
    late Family root, branch, deletedBranch;

    Authz authzFor(UuidValue? user) => Authz(sessionFor(sessionBuilder, user));

    setUp(() async {
      fx = Fx(sessionBuilder.build());
      owner = await fx.user();
      coOwner = await fx.user();
      member = await fx.user();
      branchOwner = await fx.user();
      branchMember = await fx.user();
      stranger = await fx.user();
      final tree = await fx.tree();
      root = await fx.family(tree, name: 'Root');
      branch = await fx.family(tree, parentId: root.id, name: 'Branch');
      deletedBranch = await fx.family(
        tree,
        parentId: root.id,
        name: 'Gone',
        deletedAt: DateTime.now().toUtc(),
      );
      await fx.join(root, owner, MembershipRole.owner);
      await fx.join(root, coOwner, MembershipRole.coOwner);
      await fx.join(root, member);
      await fx.join(branch, branchOwner, MembershipRole.owner);
      await fx.join(branch, branchMember);
      await fx.join(deletedBranch, member, MembershipRole.owner);
    });

    test('owner is steward and member is not', () async {
      expect(await authzFor(owner).isSteward(root.id!), isTrue);
      expect(await authzFor(member).isSteward(root.id!), isFalse);
    });

    test('membership in a soft-deleted family is not live', () async {
      expect(await authzFor(member).isMember(deletedBranch.id!), isTrue);
      expect(await authzFor(member).isLiveMember(deletedBranch.id!), isFalse);
    });

    test('branch member can read the parent family through the tree', () async {
      expect(await authzFor(branchMember).isTreeReadable(root.id!), isTrue);
      expect(await authzFor(branchMember).isMember(root.id!), isFalse);
    });

    test('a soft-deleted family is not a tree member target', () async {
      expect(await authzFor(owner).isTreeMember(deletedBranch.id!), isFalse);
    });

    test('a soft-deleted family is not tree-readable', () async {
      expect(
        await authzFor(branchMember).isTreeReadable(deletedBranch.id!),
        isFalse,
      );
    });

    test('stranger and anonymous callers get nothing', () async {
      expect(await authzFor(stranger).isTreeReadable(root.id!), isFalse);
      expect(await authzFor(null).isMember(root.id!), isFalse);
      expect(
        () => authzFor(null).requireUser(),
        throwsAppError(AppErrorCode.authRequired),
      );
    });

    group('require helpers', () {
      test('a live member gets their role back', () async {
        expect(
          await authzFor(member).requireLiveMember(root.id!),
          MembershipRole.member,
        );
      });

      test(
        'membership in a soft-deleted family is refused as member only',
        () async {
          await expectLater(
            authzFor(member).requireLiveMember(deletedBranch.id!),
            throwsAppError(AppErrorCode.forbidden, 'member only'),
          );
        },
      );

      test('an unknown family is refused the same way as a stranger', () async {
        await expectLater(
          authzFor(member).requireLiveMember(
            UuidValue.fromString('00000000-0000-7000-8000-000000000000'),
          ),
          throwsAppError(AppErrorCode.forbidden, 'member only'),
        );
        await expectLater(
          authzFor(stranger).requireLiveMember(root.id!),
          throwsAppError(AppErrorCode.forbidden, 'member only'),
        );
      });

      test('co-owner passes the steward check and member does not', () async {
        expect(
          await authzFor(coOwner).requireLiveSteward(root.id!),
          MembershipRole.coOwner,
        );
        await expectLater(
          authzFor(member).requireLiveSteward(root.id!),
          throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
        );
      });

      test('owner of a soft-deleted family is not a live steward', () async {
        expect(
          await authzFor(member).isLiveSteward(deletedBranch.id!),
          isFalse,
        );
        await expectLater(
          authzFor(member).requireLiveSteward(deletedBranch.id!),
          throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
        );
      });

      test('only the owner passes the owner check', () async {
        await authzFor(owner).requireLiveOwner(root.id!);
        await expectLater(
          authzFor(coOwner).requireLiveOwner(root.id!),
          throwsAppError(AppErrorCode.forbidden, 'owner only'),
        );
      });
    });

    group('effective origin', () {
      test('a branch origin is a published story of the parent', () async {
        final story = await fx.story(root, authorId: owner);
        final b = await Family.db.updateRow(
          fx.s,
          branch.copyWith(originStoryId: story.id),
        );
        expect(await authzFor(owner).effectiveOrigin(b), story.id);
      });

      test('a root origin is a published story of its own family', () async {
        final story = await fx.story(root, authorId: owner);
        final r = await Family.db.updateRow(
          fx.s,
          root.copyWith(originStoryId: story.id),
        );
        expect(await authzFor(owner).effectiveOrigin(r), story.id);
      });

      test('an unpublished origin hides until republished', () async {
        final story = await fx.story(root, authorId: owner);
        final b = await Family.db.updateRow(
          fx.s,
          branch.copyWith(originStoryId: story.id),
        );
        final draft = await Story.db.updateRow(
          fx.s,
          story.copyWith(status: StoryStatus.draft, publishedAt: null),
        );
        expect(await authzFor(owner).effectiveOrigin(b), isNull);
        await Story.db.updateRow(
          fx.s,
          draft.copyWith(
            status: StoryStatus.published,
            publishedAt: DateTime.now().toUtc(),
          ),
        );
        expect(await authzFor(owner).effectiveOrigin(b), story.id);
      });

      test('a soft-deleted parent hides the origin', () async {
        final tree = await fx.tree();
        final parent = await fx.family(tree);
        final story = await fx.story(parent);
        final child = await fx.family(tree, parentId: parent.id);
        final c = await Family.db.updateRow(
          fx.s,
          child.copyWith(originStoryId: story.id),
        );
        await Family.db.updateRow(
          fx.s,
          parent.copyWith(deletedAt: DateTime.now().toUtc()),
        );
        expect(await authzFor(owner).effectiveOrigin(c), isNull);
      });
    });

    group('story access', () {
      late Story published, draft, origin;

      setUp(() async {
        published = await fx.story(root, authorId: member);
        draft = await fx.story(
          root,
          authorId: member,
          status: StoryStatus.draft,
        );
        origin = await fx.story(root, authorId: owner);
        branch = await Family.db.updateRow(
          fx.s,
          branch.copyWith(originStoryId: origin.id),
        );
      });

      test('a draft is readable by its author only', () async {
        expect(await authzFor(member).canReadStory(draft), isTrue);
        expect(await authzFor(owner).canReadStory(draft), isFalse);
        expect(await authzFor(branchMember).canReadStory(draft), isFalse);
      });

      test(
        'a published story is readable by members and tree readers',
        () async {
          expect(await authzFor(owner).canReadStory(published), isTrue);
          expect(await authzFor(branchMember).canReadStory(published), isTrue);
          expect(await authzFor(stranger).canReadStory(published), isFalse);
        },
      );

      test('the author edits own draft and published story', () async {
        expect(await authzFor(member).canEditStory(draft), isTrue);
        expect(await authzFor(member).canEditStory(published), isTrue);
      });

      test(
        'stewards edit published stories of others but not drafts',
        () async {
          expect(await authzFor(coOwner).canEditStory(published), isTrue);
          expect(await authzFor(owner).canEditStory(draft), isFalse);
        },
      );

      test('a plain member cannot edit someone else\'s story', () async {
        expect(await authzFor(member).canEditStory(origin), isFalse);
      });

      test(
        'a child-family owner cannot edit the parent origin story',
        () async {
          expect(await authzFor(branchOwner).canEditStory(origin), isFalse);
        },
      );

      test('nobody edits in a soft-deleted family', () async {
        final gone = await fx.story(deletedBranch, authorId: member);
        expect(await authzFor(member).canEditStory(gone), isFalse);
      });

      test('members contribute to published stories only', () async {
        expect(await authzFor(owner).canContribute(published), isTrue);
        expect(await authzFor(owner).canContribute(draft), isFalse);
        expect(await authzFor(member).canContribute(draft), isTrue);
      });

      test('origin contributors contribute to the origin story only', () async {
        expect(await authzFor(branchMember).canContribute(origin), isTrue);
        expect(await authzFor(branchMember).canContribute(published), isFalse);
      });

      test('an unpublished origin ends origin contribution', () async {
        final drafted = await Story.db.updateRow(
          fx.s,
          origin.copyWith(status: StoryStatus.draft, publishedAt: null),
        );
        expect(await authzFor(branchMember).canContribute(drafted), isFalse);
      });
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `cd apps/server && mise exec -- dart test test/integration/authz_test.dart`
Expected: compile errors, starting with `The method 'requireLiveMember' isn't defined for the type 'Authz'.`

- [ ] **Step 3: Add the error shorthands**

`apps/server/lib/src/errors.dart`:

```dart
import 'generated/protocol.dart';

/// Shorthands for the [AppException]s endpoints throw. Messages follow the
/// business-rules.md §5.2 catalogue; never put raw database text in them.
AppException forbidden([String message = "You don't have access to that."]) =>
    AppException(code: AppErrorCode.forbidden, message: message);

AppException notFound(String message) =>
    AppException(code: AppErrorCode.notFound, message: message);

AppException validation(String message) =>
    AppException(code: AppErrorCode.validation, message: message);

AppException conflict(String message) =>
    AppException(code: AppErrorCode.conflict, message: message);
```

- [ ] **Step 4: Implement the predicates**

`apps/server/lib/src/authz/authz.dart`:

```dart
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import '../errors.dart';
import '../generated/protocol.dart';

/// Family- and story-level authorization predicates (business-rules.md §1,
/// with the 2026-11-07 decisions: every write and member read needs a live
/// family, D6b).
///
/// Every predicate is false for an unauthenticated session. "Live" means the
/// family has no `deletedAt`. Tree membership is equality on `treeId`; tree
/// reads require both the target family and the caller's family to be live.
class Authz {
  Authz(this.session);

  final Session session;

  UuidValue? get userId => session.authenticated?.authUserId;

  /// Returns the caller's id or throws `AppException(AppErrorCode.authRequired)`.
  UuidValue requireUser() {
    final id = userId;
    if (id == null) {
      throw AppException(
        code: AppErrorCode.authRequired,
        message: 'Sign in to continue.',
      );
    }
    return id;
  }

  Future<MembershipRole?> roleIn(UuidValue familyId) async {
    final uid = userId;
    if (uid == null) return null;
    final row = await Membership.db.findFirstRow(
      session,
      where: (t) => t.familyId.equals(familyId) & t.userId.equals(uid),
    );
    return row?.role;
  }

  /// Membership in [familyId], ignoring soft delete.
  Future<bool> isMember(UuidValue familyId) async =>
      await roleIn(familyId) != null;

  Future<bool> isOwner(UuidValue familyId) async =>
      await roleIn(familyId) == MembershipRole.owner;

  /// Owner or co-owner, ignoring soft delete.
  Future<bool> isSteward(UuidValue familyId) async {
    final role = await roleIn(familyId);
    return role == MembershipRole.owner || role == MembershipRole.coOwner;
  }

  /// Membership in [familyId] and the family is not soft-deleted.
  Future<bool> isLiveMember(UuidValue familyId) async =>
      await _liveRole(familyId) != null;

  /// Owner or co-owner of [familyId], and the family is live.
  Future<bool> isLiveSteward(UuidValue familyId) async {
    final role = await _liveRole(familyId);
    return role == MembershipRole.owner || role == MembershipRole.coOwner;
  }

  /// The caller's role in live [familyId]; otherwise
  /// `AppException(forbidden, 'member only')`. A missing or soft-deleted
  /// family is refused the same way, so ids don't leak.
  Future<MembershipRole> requireLiveMember(UuidValue familyId) async {
    final role = await _liveRole(familyId);
    if (role == null) throw forbidden('member only');
    return role;
  }

  /// Owner or co-owner of live [familyId]; otherwise
  /// `AppException(forbidden, 'owner or co-owner only')`.
  Future<MembershipRole> requireLiveSteward(UuidValue familyId) async {
    final role = await _liveRole(familyId);
    if (role != MembershipRole.owner && role != MembershipRole.coOwner) {
      throw forbidden('owner or co-owner only');
    }
    return role!;
  }

  /// Owner of live [familyId]; otherwise `AppException(forbidden, 'owner only')`.
  Future<void> requireLiveOwner(UuidValue familyId) async {
    if (await _liveRole(familyId) != MembershipRole.owner) {
      throw forbidden('owner only');
    }
  }

  Future<MembershipRole?> _liveRole(UuidValue familyId) async {
    final family = await Family.db.findById(session, familyId);
    if (family == null || family.deletedAt != null) return null;
    return roleIn(familyId);
  }

  /// [familyId] is live and the caller is a member of some live family in the
  /// same tree.
  Future<bool> isTreeReadable(UuidValue familyId) async {
    final uid = userId;
    if (uid == null) return false;
    final family = await Family.db.findById(session, familyId);
    if (family == null || family.deletedAt != null) return false;
    final memberships = await Membership.db.find(
      session,
      where: (t) => t.userId.equals(uid),
    );
    if (memberships.isEmpty) return false;
    final count = await Family.db.count(
      session,
      where: (t) =>
          t.id.inSet(memberships.map((m) => m.familyId).toSet()) &
          t.treeId.equals(family.treeId) &
          t.deletedAt.equals(null),
    );
    return count > 0;
  }

  /// Same as [isTreeReadable]; kept as the business-rules name.
  Future<bool> isTreeMember(UuidValue familyId) => isTreeReadable(familyId);

  /// `familyOrigin(f)` (schema-design.md §3.5): [family]'s origin story when
  /// [family] is live, the story is published, the story's family is live,
  /// and the story belongs to the parent (branch) or to [family] (root).
  Future<UuidValue?> effectiveOrigin(Family family) async {
    final storyId = family.originStoryId;
    if (storyId == null || family.deletedAt != null) return null;
    final story = await Story.db.findById(session, storyId);
    if (story == null || story.status != StoryStatus.published) return null;
    if (story.familyId != (family.parentId ?? family.id)) return null;
    final owner = await Family.db.findById(session, story.familyId);
    if (owner == null || owner.deletedAt != null) return null;
    return storyId;
  }

  /// Drafts: the author while a live member. Published: live members of the
  /// story's family and tree readers.
  Future<bool> canReadStory(Story story) async {
    if (story.status == StoryStatus.draft) {
      return _isAuthor(story) && await isLiveMember(story.familyId);
    }
    return await isLiveMember(story.familyId) ||
        await isTreeReadable(story.familyId);
  }

  /// `canEditStory`: the family is live and the caller is the author (live
  /// member), or the story is published and the caller is a steward of the
  /// story's family.
  Future<bool> canEditStory(Story story) async {
    final role = await _liveRole(story.familyId);
    if (role == null) return false;
    if (_isAuthor(story)) return true;
    return story.status == StoryStatus.published &&
        (role == MembershipRole.owner || role == MembershipRole.coOwner);
  }

  /// `canContribute`: the story is published or the caller wrote it, and the
  /// caller is a live member of its family, or a live member of a live child
  /// family whose effective origin is this story (origin contributor).
  Future<bool> canContribute(Story story) async {
    if (story.status != StoryStatus.published && !_isAuthor(story)) {
      return false;
    }
    if (await isLiveMember(story.familyId)) return true;
    final children = await Family.db.find(
      session,
      where: (t) =>
          t.parentId.equals(story.familyId) &
          t.originStoryId.equals(story.id) &
          t.deletedAt.equals(null),
    );
    for (final child in children) {
      if (await effectiveOrigin(child) == story.id &&
          await isLiveMember(child.id!)) {
        return true;
      }
    }
    return false;
  }

  bool _isAuthor(Story story) {
    final uid = userId;
    return uid != null && story.authorId == uid;
  }

  /// Throws `AppException(AppErrorCode.forbidden)` unless [allowed].
  void ensure(bool allowed) {
    if (!allowed) throw forbidden();
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `mise exec -- just server-test`
Expected: `+78: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/server/lib/src/errors.dart apps/server/lib/src/authz/authz.dart apps/server/test/integration/authz_test.dart
git commit -m "feat(server): live-family checks and story predicates in Authz"
```

---

### Task 3: Every protocol DTO, generated once

The DTOs come from endpoint-contract §2.1. They are not tables, so no migration changes. Generating them all here means the parallel slices only add endpoint classes. Their generated files (`generated/endpoints.dart`, the client's `client.dart`, `test_tools/serverpod_test_tools.dart`) are rebuilt with `just server-generate` after each merge.

**Files:**
- Create: the 34 files under `apps/server/lib/src/models/dto/` listed below
- Generated: `apps/server/lib/src/generated/**`, `packages/tell_me_a_story_client/lib/src/protocol/**`

- [ ] **Step 1: Write the model files**

`apps/server/lib/src/models/dto/cover_upload_ticket_dto.spy.yaml`
```yaml
### Returned by FamilyEndpoint.startCoverUpload.
class: CoverUploadTicketDto
fields:
  key: String
  uploadDescription: String
```

`apps/server/lib/src/models/dto/created_invite_dto.spy.yaml`
```yaml
### Returned once by InviteEndpoint.create; token is never stored (only its hash).
class: CreatedInviteDto
fields:
  inviteId: UuidValue
  token: String
  expiresAt: DateTime
  inviteUrl: String
```

`apps/server/lib/src/models/dto/decade_facet_dto.spy.yaml`
```yaml
### Search facet: a decade and its story count.
class: DecadeFacetDto
fields:
  decade: int
  storyCount: int
```

`apps/server/lib/src/models/dto/family_detail_dto.spy.yaml`
```yaml
### Family + members + pending invites in one call (FamilyEndpoint.detail).
class: FamilyDetailDto
fields:
  id: UuidValue
  name: String
  myRole: MembershipRole
  members: List<FamilyMemberDto>
  pendingInvites: List<PendingInviteDto>
```

`apps/server/lib/src/models/dto/family_directory_dto.spy.yaml`
```yaml
### The caller's families, split into active and recoverable (FamilyEndpoint.directory).
class: FamilyDirectoryDto
fields:
  active: List<FamilyRosterDto>
  recoverable: List<FamilyRosterDto>
```

`apps/server/lib/src/models/dto/family_member_dto.spy.yaml`
```yaml
### A member of a family. No email: other users' emails are not exposed.
class: FamilyMemberDto
fields:
  userId: UuidValue
  role: MembershipRole
  displayName: String?
  avatarKey: String?
```

`apps/server/lib/src/models/dto/family_roster_dto.spy.yaml`
```yaml
### One row of the family directory.
class: FamilyRosterDto
fields:
  id: UuidValue
  name: String
  role: MembershipRole
  memberCount: int
  publishedCount: int
  deletedAt: DateTime?
```

`apps/server/lib/src/models/dto/invite_preview_dto.spy.yaml`
```yaml
### Anonymous invite preview. Invalid previews carry no family or inviter.
class: InvitePreviewDto
fields:
  valid: bool
  familyId: UuidValue?
  familyName: String?
  inviterName: String?
```

`apps/server/lib/src/models/dto/kinship_dto.spy.yaml`
```yaml
### A kinship edge (contract only; no client UI yet).
class: KinshipDto
fields:
  id: UuidValue
  kind: KinshipKind
  fromPersonId: UuidValue
  toPersonId: UuidValue
```

`apps/server/lib/src/models/dto/live_event_dto.spy.yaml`
```yaml
### Posted after commit to family:<familyId> and, when storyId is set, story:<storyId>.
class: LiveEventDto
fields:
  familyId: UuidValue
  storyId: UuidValue?
  kind: LiveKind
  storyStatus: StoryStatus?
  deleted: bool
```

`apps/server/lib/src/models/dto/live_kind.spy.yaml`
```yaml
### What changed in a LiveEventDto.
enum: LiveKind
serialized: byName
values:
  - story
  - photo
  - note
```

`apps/server/lib/src/models/dto/member_family_dto.spy.yaml`
```yaml
### A family the caller belongs to (FamilyEndpoint.listMine).
class: MemberFamilyDto
fields:
  id: UuidValue
  name: String
  parentId: UuidValue?
  branchYear: int?
  createdAt: DateTime
  role: MembershipRole
  coverKey: String?
```

`apps/server/lib/src/models/dto/note_dto.spy.yaml`
```yaml
### A comment or perspective. familyId is derived from the story. canDelete is computed for the caller (D4).
class: NoteDto
fields:
  id: UuidValue
  storyId: UuidValue
  familyId: UuidValue
  kind: NoteKind
  authorId: UuidValue?
  authorName: String?
  body: String
  createdAt: DateTime
  canDelete: bool
```

`apps/server/lib/src/models/dto/origin_dependent_dto.spy.yaml`
```yaml
### A family whose effective origin is a given story.
class: OriginDependentDto
fields:
  familyId: UuidValue
  name: String
```

`apps/server/lib/src/models/dto/own_profile_dto.spy.yaml`
```yaml
### The caller's own account (ProfileEndpoint.me). email is read-only (D1).
class: OwnProfileDto
fields:
  authUserId: UuidValue
  displayName: String?
  email: String?
  avatarKey: String?
  birthDate: DateTime?
  birthPrecision: DatePrecision?
  birthVisibility: BirthVisibility
  about: String?
```

`apps/server/lib/src/models/dto/pending_invite_dto.spy.yaml`
```yaml
### An invite that is not accepted or revoked. sentAt is invites.lastSentAt.
class: PendingInviteDto
fields:
  id: UuidValue
  email: String?
  personId: UuidValue?
  sentAt: DateTime
  expiresAt: DateTime
  createdAt: DateTime
```

`apps/server/lib/src/models/dto/person_dto.spy.yaml`
```yaml
### A person in the tree. Birth comes from the linked AppUser (coarsened by birthVisibility) when linked, else from the person row.
class: PersonDto
fields:
  id: UuidValue
  treeId: UuidValue
  homeFamilyId: UuidValue
  name: String
  email: String?
  about: String?
  avatarKey: String?
  userId: UuidValue?
  passedAway: bool
  birthDate: DateTime?
  birthPrecision: DatePrecision?
  deathDate: DateTime?
  deathPrecision: DatePrecision?
```

`apps/server/lib/src/models/dto/person_facet_dto.spy.yaml`
```yaml
### Search facet: a tagged person and their story count.
class: PersonFacetDto
fields:
  personId: UuidValue
  name: String
  storyCount: int
```

`apps/server/lib/src/models/dto/person_profile_dto.spy.yaml`
```yaml
### The person profile dialog. Never carries userId or email.
class: PersonProfileDto
fields:
  id: UuidValue
  homeFamilyId: UuidValue
  name: String
  isLinked: bool
  birthDate: DateTime?
  birthPrecision: DatePrecision?
  deathDate: DateTime?
  deathPrecision: DatePrecision?
  about: String?
  avatarKey: String?
  passedAway: bool
```

`apps/server/lib/src/models/dto/person_write_dto.spy.yaml`
```yaml
### Person create/update input. Each write* flag says whether its field group is written.
class: PersonWriteDto
fields:
  name: String
  about: String?
  writeAbout: bool
  email: String?
  writeEmail: bool
  passedAway: bool?
  writePassedAway: bool
  clearPicture: bool
  birthDate: DateTime?
  birthPrecision: DatePrecision?
  writeBirth: bool
  deathDate: DateTime?
  deathPrecision: DatePrecision?
  writeDeath: bool
```

`apps/server/lib/src/models/dto/photo_dto.spy.yaml`
```yaml
### A story photo. familyId is derived from the story, not stored.
class: PhotoDto
fields:
  id: UuidValue
  storyId: UuidValue
  familyId: UuidValue
  uploaderId: UuidValue?
  originalKey: String
  editedKey: String?
  editVersion: int
  sortOrder: int
```

`apps/server/lib/src/models/dto/photo_ref_dto.spy.yaml`
```yaml
### A story photo as the story card needs it. key = editedKey ?? originalKey.
class: PhotoRefDto
fields:
  id: UuidValue
  key: String
  sortOrder: int
```

`apps/server/lib/src/models/dto/photo_upload_ticket_dto.spy.yaml`
```yaml
### Returned by PhotoEndpoint.startUpload; uploadDescription feeds the client FileUploader.
class: PhotoUploadTicketDto
fields:
  photoId: UuidValue
  key: String
  uploadDescription: String
```

`apps/server/lib/src/models/dto/place_dto.spy.yaml`
```yaml
### A place, shared by every family in the tree.
class: PlaceDto
fields:
  id: UuidValue
  treeId: UuidValue
  label: String
  address: String
  lat: double
  lng: double
  mapboxPlaceId: String?
  isFavorite: bool
  lastUsedAt: DateTime?
```

`apps/server/lib/src/models/dto/place_facet_dto.spy.yaml`
```yaml
### Search facet: a place and its story count.
class: PlaceFacetDto
fields:
  placeId: UuidValue
  label: String
  storyCount: int
```

`apps/server/lib/src/models/dto/place_input_dto.spy.yaml`
```yaml
### Place create input.
class: PlaceInputDto
fields:
  label: String
  address: String
  lat: double
  lng: double
  mapboxPlaceId: String?
  isFavorite: bool
```

`apps/server/lib/src/models/dto/search_sort.spy.yaml`
```yaml
### StorySearchDto.sort.
enum: SearchSort
serialized: byName
values:
  - relevant
  - chronological
  - recentlyAdded
```

`apps/server/lib/src/models/dto/steward_family_dto.spy.yaml`
```yaml
### A family the caller stewards, including soft-deleted ones still inside the 60-day window.
class: StewardFamilyDto
fields:
  id: UuidValue
  name: String
  role: MembershipRole
  deletedAt: DateTime?
```

`apps/server/lib/src/models/dto/story_dto.spy.yaml`
```yaml
### A story with everything the timeline and reader show.
class: StoryDto
fields:
  id: UuidValue
  familyId: UuidValue
  authorId: UuidValue?
  title: String?
  body: String?
  dateStart: DateTime?
  dateEnd: DateTime?
  datePrecision: DatePrecision?
  createdAt: DateTime
  placeId: UuidValue?
  placeLabel: String?
  placeAddress: String?
  status: StoryStatus
  publishedAt: DateTime?
  people: List<StoryPersonDto>
  photos: List<PhotoRefDto>
  authorName: String?
  authorAvatarKey: String?
  commentCount: int
  perspectiveCount: int
```

`apps/server/lib/src/models/dto/story_facets_dto.spy.yaml`
```yaml
### StoryEndpoint.facets result.
class: StoryFacetsDto
fields:
  decades: List<DecadeFacetDto>
  people: List<PersonFacetDto>
  places: List<PlaceFacetDto>
```

`apps/server/lib/src/models/dto/story_person_dto.spy.yaml`
```yaml
### A person tagged on a story.
class: StoryPersonDto
fields:
  personId: UuidValue
  name: String
  userId: UuidValue?
```

`apps/server/lib/src/models/dto/story_search_dto.spy.yaml`
```yaml
### StoryEndpoint.search input (endpoint-contract.md, search semantics). Pass text '' for no text.
class: StorySearchDto
fields:
  familyId: UuidValue
  text: String
  personIds: List<UuidValue>
  placeId: UuidValue?
  rangeStart: DateTime?
  rangeEnd: DateTime?
  decades: List<int>
  sort: SearchSort
```

`apps/server/lib/src/models/dto/story_write_dto.spy.yaml`
```yaml
### Draft input. personIds null = leave story_people alone.
class: StoryWriteDto
fields:
  dateStart: DateTime?
  dateEnd: DateTime?
  datePrecision: DatePrecision?
  title: String?
  body: String?
  placeId: UuidValue?
  clearPlace: bool
  personIds: List<UuidValue>?
```

`apps/server/lib/src/models/dto/tree_family_dto.spy.yaml`
```yaml
### A live family in the caller's tree (FamilyEndpoint.listTree).
class: TreeFamilyDto
fields:
  id: UuidValue
  name: String
  parentId: UuidValue?
  branchYear: int?
  ### Derived, schema-design.md §3.5.
  effectiveOriginStoryId: UuidValue?
```

- [ ] **Step 2: Generate**

Run: `mise exec -- just server-generate`
Expected: `Generating code done.`, and `git status --short apps/server/migrations` prints nothing.

- [ ] **Step 3: Analyze both packages**

Run: `cd apps/server && mise exec -- dart analyze lib test && cd ../../packages/tell_me_a_story_client && mise exec -- dart analyze`
Expected: `No issues found!` twice.

- [ ] **Step 4: Commit**

```bash
git add apps/server/lib/src/models/dto apps/server/lib/src/generated packages/tell_me_a_story_client/lib
git commit -m "feat(server): protocol DTOs for the Phase 3 endpoints"
```

---

### Task 4: Blob keys and image sniffing

Keys are produced only by the server and stored in full (schema-design §4.2). Every replacement gets a new key. Uploads are checked by magic bytes before a row is written.

**Files:**
- Create: `apps/server/lib/src/media/blob_keys.dart`
- Test: `apps/server/test/unit/blob_keys_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/media/blob_keys.dart';
import 'package:test/test.dart';

ByteData bytes(List<int> b) => ByteData.sublistView(Uint8List.fromList(b));

void main() {
  final family = UuidValue.fromString('0190d7a0-0000-7000-8000-000000000001');
  final story = UuidValue.fromString('0190d7a0-0000-7000-8000-000000000002');
  final photo = UuidValue.fromString('0190d7a0-0000-7000-8000-000000000003');
  final tree = UuidValue.fromString('0190d7a0-0000-7000-8000-000000000004');
  final person = UuidValue.fromString('0190d7a0-0000-7000-8000-000000000005');
  const blob = '0190d7a0-0000-7000-8000-0000000000ff';

  group('keys follow schema-design.md §4.2', () {
    test('photo original and edited', () {
      expect(
        photoOriginalKey(
          familyId: family,
          storyId: story,
          photoId: photo,
          mimeType: 'image/png',
        ),
        'families/$family/stories/$story/photos/$photo/original.png',
      );
      expect(
        photoEditedKey(
          familyId: family,
          storyId: story,
          photoId: photo,
          editVersion: 3,
        ),
        'families/$family/stories/$story/photos/$photo/edited-3.jpg',
      );
    });

    test('cover and avatars get a fresh blob id', () {
      expect(
        familyCoverKey(familyId: family, mimeType: 'image/webp', blobId: blob),
        'families/$family/cover/$blob.webp',
      );
      expect(
        personAvatarKey(treeId: tree, personId: person, blobId: blob),
        'trees/$tree/people/$person/avatar/$blob.jpg',
      );
      expect(
        userAvatarKey(authUserId: person, blobId: blob),
        'users/$person/avatar/$blob.jpg',
      );
      expect(
        familyCoverKey(familyId: family, mimeType: 'image/jpeg'),
        isNot(familyCoverKey(familyId: family, mimeType: 'image/jpeg')),
      );
    });

    test('keys use only lowercase, digits, dash, slash and dot', () {
      final key = familyCoverKey(familyId: family, mimeType: 'image/jpeg');
      expect(key, matches(RegExp(r'^[a-z0-9\-/.]+$')));
    });

    test('an unsupported type is a validation error', () {
      expect(
        () => familyCoverKey(familyId: family, mimeType: 'image/svg+xml'),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.validation,
          ),
        ),
      );
    });
  });

  group('sniffImageMime reads magic bytes', () {
    test('jpeg, png and webp', () {
      expect(sniffImageMime(bytes([0xFF, 0xD8, 0xFF, 0xE0, 0])), 'image/jpeg');
      expect(
        sniffImageMime(bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])),
        'image/png',
      );
      expect(
        sniffImageMime(
          bytes([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]),
        ),
        'image/webp',
      );
    });

    test('anything else, or too short, is null', () {
      expect(sniffImageMime(bytes('<svg'.codeUnits)), isNull);
      expect(sniffImageMime(bytes([0xFF, 0xD8])), isNull);
      expect(
        sniffImageMime(
          bytes([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WAVE'.codeUnits]),
        ),
        isNull,
      );
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `cd apps/server && mise exec -- dart test test/unit/blob_keys_test.dart`
Expected: `Error when reading 'lib/src/media/blob_keys.dart': No such file or directory`

- [ ] **Step 3: Implement**

```dart
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../errors.dart';

/// Every blob lives in this storage (schema-design.md §4.2).
const blobStorageId = 'private';

/// Size limits per object, same as the old buckets (schema-design.md §4.2).
const photoMaxBytes = 52428800;
const coverMaxBytes = 5242880;
const avatarMaxBytes = 2097152;

const _extByMime = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

/// File extension for a supported image MIME type; anything else is
/// `AppException(validation, 'unsupported image type')`.
String extForMime(String mimeType) =>
    _extByMime[mimeType] ?? (throw validation('unsupported image type'));

String _newBlobId() => const Uuid().v7();

String photoOriginalKey({
  required UuidValue familyId,
  required UuidValue storyId,
  required UuidValue photoId,
  required String mimeType,
}) =>
    'families/$familyId/stories/$storyId/photos/$photoId/original.'
    '${extForMime(mimeType)}';

String photoEditedKey({
  required UuidValue familyId,
  required UuidValue storyId,
  required UuidValue photoId,
  required int editVersion,
}) =>
    'families/$familyId/stories/$storyId/photos/$photoId/edited-$editVersion.jpg';

/// [blobId] defaults to a fresh UUID v7; every replacement gets a new key.
String familyCoverKey({
  required UuidValue familyId,
  required String mimeType,
  String? blobId,
}) =>
    'families/$familyId/cover/${blobId ?? _newBlobId()}.${extForMime(mimeType)}';

String personAvatarKey({
  required UuidValue treeId,
  required UuidValue personId,
  String? blobId,
}) => 'trees/$treeId/people/$personId/avatar/${blobId ?? _newBlobId()}.jpg';

String userAvatarKey({required UuidValue authUserId, String? blobId}) =>
    'users/$authUserId/avatar/${blobId ?? _newBlobId()}.jpg';

/// The image type named by the first bytes of [data]: JPEG `FF D8 FF`,
/// PNG `89 50 4E 47 0D 0A 1A 0A`, WebP `RIFF????WEBP`. Null for anything else.
String? sniffImageMime(ByteData data) {
  final b = Uint8List.sublistView(data);
  bool at(int offset, List<int> magic) {
    if (b.length < offset + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (b[offset + i] != magic[i]) return false;
    }
    return true;
  }

  if (at(0, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) return 'image/webp';
  return null;
}
```

- [ ] **Step 4: Run it**

Run: `cd apps/server && mise exec -- dart test test/unit/blob_keys_test.dart`
Expected: `+6: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/media/blob_keys.dart apps/server/test/unit/blob_keys_test.dart
git commit -m "feat(server): blob keys and image type sniffing"
```

---

### Task 5: The `blob_deletions` queue

Writers queue old keys in the same transaction that drops or replaces the reference; a recurring future call (slice 3f) drains the queue. This is how D6c's "fail closed" holds: a failed purge transaction queues nothing and keeps the family row.

**Files:**
- Create: `apps/server/lib/src/media/blob_outbox.dart`
- Test: `apps/server/test/integration/blob_outbox_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/media/blob_keys.dart';
import 'package:tell_me_a_story_server/src/media/blob_outbox.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given the blob deletion queue', (sessionBuilder, endpoints) {
    late Session session;

    String uniqueKey() => 'test/${const Uuid().v7()}.jpg';

    Future<List<BlobDeletion>> rowsFor(String key) =>
        BlobDeletion.db.find(session, where: (t) => t.key.equals(key));

    setUp(() => session = sessionBuilder.build());

    test(
      'when the queuing transaction fails then nothing is queued',
      () async {
        final key = uniqueKey();
        await expectLater(
          session.db.transaction((t) async {
            await queueBlobDeletions(session, [key, null], transaction: t);
            throw StateError('purge failed');
          }),
          throwsStateError,
        );
        expect(await rowsFor(key), isEmpty);
      },
    );

    test('when the drain runs then the blob and its row are gone', () async {
      final key = uniqueKey();
      await session.storage.storeFile(
        storageId: blobStorageId,
        path: key,
        byteData: ByteData.sublistView(Uint8List.fromList([1, 2, 3])),
      );
      await queueBlobDeletions(session, [key]);

      await drainBlobDeletions(session);

      expect(await rowsFor(key), isEmpty);
      expect(
        await session.storage.fileExists(storageId: blobStorageId, path: key),
        isFalse,
      );
    });

    test(
      'when a blob delete fails then its row stays with one more attempt',
      () async {
        final key = uniqueKey();
        await queueBlobDeletions(session, [key]);

        await drainBlobDeletions(
          session,
          delete: (k) async {
            if (k == key) throw StateError('storage down');
          },
        );

        final rows = await rowsFor(key);
        expect(rows.single.attempts, 1);
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `cd apps/server && mise exec -- dart test test/integration/blob_outbox_test.dart`
Expected: `Error when reading 'lib/src/media/blob_outbox.dart': No such file or directory`

- [ ] **Step 3: Implement**

```dart
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'blob_keys.dart';

/// Queues [keys] (nulls skipped) for deletion. Call it in the SAME
/// transaction that drops or replaces the rows referencing them, so a failed
/// write queues nothing and a committed one can't leak a blob
/// (schema-design.md §4.3).
Future<void> queueBlobDeletions(
  Session session,
  Iterable<String?> keys, {
  Transaction? transaction,
}) async {
  final rows = [
    for (final key in keys)
      if (key != null) BlobDeletion(key: key),
  ];
  if (rows.isEmpty) return;
  await BlobDeletion.db.insert(session, rows, transaction: transaction);
}

/// Deletes one blob from storage. Tests pass a failing one.
typedef BlobDeleter = Future<void> Function(String key);

/// Deletes up to [batchSize] queued blobs, fewest attempts first. A blob that
/// fails to delete is logged and keeps its row with `attempts + 1`, so the
/// next run retries it. Returns how many were deleted.
Future<int> drainBlobDeletions(
  Session session, {
  int batchSize = 100,
  BlobDeleter? delete,
}) async {
  final deleteBlob =
      delete ??
      (key) => session.storage.deleteFile(storageId: blobStorageId, path: key);
  final rows = await BlobDeletion.db.find(
    session,
    orderByList: (t) => [t.attempts.asc(), t.createdAt.asc()],
    limit: batchSize,
  );
  var deleted = 0;
  for (final row in rows) {
    try {
      await deleteBlob(row.key);
    } catch (e, stackTrace) {
      session.log(
        'blob delete failed: ${row.key}',
        level: LogLevel.warning,
        exception: e,
        stackTrace: stackTrace,
      );
      await BlobDeletion.db.updateRow(
        session,
        row.copyWith(attempts: row.attempts + 1),
      );
      continue;
    }
    await BlobDeletion.db.deleteRow(session, row);
    deleted++;
  }
  return deleted;
}
```

- [ ] **Step 4: Run it**

Run: `cd apps/server && mise exec -- dart test test/integration/blob_outbox_test.dart`
Expected: `+3: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/media/blob_outbox.dart apps/server/test/integration/blob_outbox_test.dart
git commit -m "feat(server): blob deletion queue and drain"
```

---

### Task 6: Account helpers (D2, D6d)

`accountEmail` is the email invite acceptance compares against (D2). `ensureLinkedPerson` is the one place a linked person is created: createRoot (3a), createBranch for the owner and each picked member (3a, D6d), and invite accept (3e).

**Files:**
- Create: `apps/server/lib/src/accounts/accounts.dart`
- Modify: `apps/server/test/integration/support/fixtures.dart` (add `userWithEmail` to `Fx`, after `user()`)
- Test: `apps/server/test/integration/accounts_test.dart`

- [ ] **Step 1: Add the fixture**

In `apps/server/test/integration/support/fixtures.dart`, insert this method right after `user()`. No new import is needed: `package:serverpod_auth_idp_server/core.dart` already exports `EmailAccount`.

```dart
  /// A new auth user with an email login, as the email-code sign-up leaves
  /// it, and optionally a display name on the app's `users` row.
  Future<UuidValue> userWithEmail(String email, {String? displayName}) async {
    final id = await user();
    await EmailAccount.db.insertRow(
      s,
      EmailAccount(authUserId: id, email: email, passwordHash: ''),
    );
    if (displayName != null) {
      final appUser = await AppUser.db.findFirstRow(
        s,
        where: (t) => t.authUserId.equals(id),
      );
      await AppUser.db.updateRow(
        s,
        appUser!.copyWith(displayName: displayName),
      );
    }
    return id;
  }
```

- [ ] **Step 2: Write the failing test**

```dart
import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/accounts/accounts.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given signed-up accounts', (sessionBuilder, endpoints) {
    late Session session;
    late Fx fx;

    Future<Person> ensure(Family home, UuidValue user) =>
        session.db.transaction(
          (t) => ensureLinkedPerson(
            session,
            treeId: home.treeId,
            homeFamilyId: home.id!,
            userId: user,
            transaction: t,
          ),
        );

    setUp(() {
      session = sessionBuilder.build();
      fx = Fx(session);
    });

    test('the account email comes back trimmed and lower-cased', () async {
      final user = await fx.userWithEmail(' Ana@Example.COM ');
      expect(await accountEmail(session, user), 'ana@example.com');
    });

    test('a user without an email account has no email', () async {
      expect(await accountEmail(session, await fx.user()), isNull);
    });

    test(
      'when a user has no person in the tree then one is created at home',
      () async {
        final user = await fx.userWithEmail(
          'bo@example.com',
          displayName: ' Bo ',
        );
        final home = await fx.family(await fx.tree());

        final person = await ensure(home, user);

        expect(person.userId, user);
        expect(person.homeFamilyId, home.id);
        expect(person.name, 'Bo');
        expect(person.email, isNull);
      },
    );

    test(
      'when a user is already linked in the tree then that person is reused',
      () async {
        final user = await fx.userWithEmail('cy@example.com');
        final tree = await fx.tree();
        final root = await fx.family(tree);
        final branch = await fx.family(tree, parentId: root.id);
        final existing = await ensure(root, user);

        final again = await ensure(branch, user);

        expect(again.id, existing.id);
        expect(
          await Person.db.count(
            session,
            where: (t) => t.treeId.equals(tree.id) & t.userId.equals(user),
          ),
          1,
        );
      },
    );

    test(
      'without a display name the email local part, then Member, is used',
      () async {
        final home = await fx.family(await fx.tree());
        final withEmail = await fx.userWithEmail('dee.dee@example.com');
        expect((await ensure(home, withEmail)).name, 'dee.dee');
        expect((await ensure(home, await fx.user())).name, 'Member');
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 3: Run it to see it fail**

Run: `cd apps/server && mise exec -- dart test test/integration/accounts_test.dart`
Expected: `Error when reading 'lib/src/accounts/accounts.dart': No such file or directory`

- [ ] **Step 4: Implement**

```dart
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import '../generated/protocol.dart';

/// Trimmed and lower-cased, the form invite emails are compared in (D2).
String normalizeEmail(String email) => email.trim().toLowerCase();

/// The login email of [authUserId], normalized; null when the user has no
/// email login.
Future<String?> accountEmail(
  Session session,
  UuidValue authUserId, {
  Transaction? transaction,
}) async {
  final account = await EmailAccount.db.findFirstRow(
    session,
    where: (t) => t.authUserId.equals(authUserId),
    transaction: transaction,
  );
  return account == null ? null : normalizeEmail(account.email);
}

/// Name for a new linked person: the display name, else the email local
/// part, else `Member` (schema-design.md §3.2, createRoot).
String linkedPersonName({String? displayName, String? email}) {
  final name = displayName?.trim() ?? '';
  if (name.isNotEmpty) return name;
  final local = email?.split('@').first.trim() ?? '';
  if (local.isNotEmpty) return local;
  return 'Member';
}

/// The person linked to [userId] in tree [treeId]. Reuses the existing one
/// anywhere in the tree; otherwise creates one with [homeFamilyId] as its
/// home (createRoot, createBranch D6d, invite accept). The person's own email
/// stays null: the account email is never copied onto a person.
Future<Person> ensureLinkedPerson(
  Session session, {
  required UuidValue treeId,
  required UuidValue homeFamilyId,
  required UuidValue userId,
  required Transaction transaction,
}) async {
  final existing = await Person.db.findFirstRow(
    session,
    where: (t) => t.treeId.equals(treeId) & t.userId.equals(userId),
    transaction: transaction,
  );
  if (existing != null) return existing;
  final appUser = await AppUser.db.findFirstRow(
    session,
    where: (t) => t.authUserId.equals(userId),
    transaction: transaction,
  );
  final email = await accountEmail(session, userId, transaction: transaction);
  return Person.db.insertRow(
    session,
    Person(
      treeId: treeId,
      homeFamilyId: homeFamilyId,
      userId: userId,
      name: linkedPersonName(displayName: appUser?.displayName, email: email),
      createdById: userId,
    ),
    transaction: transaction,
  );
}
```

- [ ] **Step 5: Run it**

Run: `cd apps/server && mise exec -- dart test test/integration/accounts_test.dart`
Expected: `+5: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/server/lib/src/accounts apps/server/test/integration/accounts_test.dart apps/server/test/integration/support/fixtures.dart
git commit -m "feat(server): account email and linked-person helpers"
```

---

### Task 7: Live-event channels

Writers in 3a–3e post after commit; `LiveEndpoint` (3f) subscribes with the same channel names. This is a two-line contract with no logic of its own; 3f's stream tests cover it end to end.

**Files:**
- Create: `apps/server/lib/src/live/live_events.dart`

- [ ] **Step 1: Write the helper**

```dart
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// Channel names shared by every writer and by `LiveEndpoint` (slice 3f).
String familyChannel(UuidValue familyId) => 'family:$familyId';
String storyChannel(UuidValue storyId) => 'story:$storyId';

/// Posts [event] to its family channel and, when it names a story, to the
/// story channel. Call it only AFTER the write's transaction has committed,
/// so subscribers never see a change that rolled back. Local delivery only
/// (no Redis): one server instance, as in serverpod-notes.md §8.
Future<void> postLiveEvent(Session session, LiveEventDto event) async {
  await session.messages.postMessage(familyChannel(event.familyId), event);
  final storyId = event.storyId;
  if (storyId != null) {
    await session.messages.postMessage(storyChannel(storyId), event);
  }
}
```

- [ ] **Step 2: Analyze**

Run: `cd apps/server && mise exec -- dart analyze lib`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add apps/server/lib/src/live/live_events.dart
git commit -m "feat(server): live event channel helper"
```

---

### Task 8: Gate

- [ ] **Step 1: Format, analyze, test**

Run:
```bash
mise exec -- dart format --output=none --set-exit-if-changed apps/server/lib apps/server/test
(cd apps/server && mise exec -- dart analyze lib test)
mise exec -- just server-test
mise exec -- just test
```
Expected: `0 changed`, `No issues found!`, `+92: All tests passed!`, and the Flutter suite unchanged at `+708: All tests passed!`.

- [ ] **Step 2: Mark 3.0 done in the Phase 3 index**

In `docs/superpowers/plans/2026-11-07-serverpod-phase3-server-endpoints.md`, set the 3.0 row's status to `landed`, then commit:

```bash
git add docs/superpowers/plans/2026-11-07-serverpod-phase3-server-endpoints.md
git commit -m "docs: Phase 3.0 foundation landed"
```
