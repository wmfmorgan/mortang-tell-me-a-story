# Phase 3b: People Endpoint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `PeopleEndpoint` with `listFamily`, `listTree`, `create`, `forEdit`, `profile`, `update`, `listUnlinked`, `isHomeFamilySteward`, `markPassedAway`, `delete`. Covered by business-rules §7 cases 26 and 28 (people part), 95–100, 102–105, 116, 120, 136.

**Architecture:** One endpoint class on landed 3.0 foundation (`Authz`, `errors.dart`, `blob_keys.dart`, `blob_outbox.dart`, DTOs, `Fx`). People tree-scoped: reads + unlinked edits check `Authz.isTreeMemberOf(person.treeId)`, never home family, so soft-deleted home family doesn't hide person (D8). Steward-only actions (`markPassedAway`, `delete`) check **live** home family (D5, D6b). Pure write + DOB rules in `lib/src/people/person_rules.dart`, unit-tested. Pictures stored inline under fresh `personAvatarKey`; replaced/cleared/deleted keys go to `blob_deletions` in write transaction. No live events.

**Tech Stack:** Dart 3.13, Serverpod 4.1.1, embedded Postgres 16, just, mise.

**Spec of record:** Phase 3 index row "3b People"; business-rules §2.3, §4.3, §4.6, §5.2, §7; schema-design §3.2 (passedAway, life dates, linked person name lock, person delete D5, unlinked picker), §4.2; endpoint-contract §2.2 `PeopleEndpoint`.

---

## Decisions taken at slice start (approved by Main, 2026-11-07)

- **`forEdit` access.** Contract comment says "steward/self only", but business-rules §2.3 (read row = tree member; unlinked edit = any tree member, case 97) and client (`person_profile_dialog.dart` reads `forEdit().userId` to show Edit) need tree-member access. `forEdit` returns row to any tree member; null for missing person or outsider. Main fixes contract comment.
- **Duplicate email.** Contract says `update` maps duplicate email to `CONFLICT 'That email is already used'`, but schema has no unique index on `people.email` → path can't occur. Not implemented.
- **BR 101** (`my_profile`) belongs to `ProfileEndpoint.me` (3a); people part (linked self sees raw birth) under BR 100. **BR 102** ported as: `DatePrecision` has no `decade`, new account's `birthVisibility` is `hidden`.
- **BR 108** (linking existing person takes profile name) is invite accept (3e). Not ported here.
- **BR 99** read part (outsider can't read avatar) is `MediaEndpoint` (3d); here upload part ported, and outsider can't get key (profile NOT_FOUND, forEdit null).
- **BR 105** invite-targeting part (passed-away person can't be invited) is invite create (3e); here unlinked-list part ported.
- **Error choices.** Not-found messages `'person not found'` and `'family not found'` (agreed with 3e for catalogue's bare NOT_FOUND). Writes on missing or out-of-tree person → `FORBIDDEN` like stranger (ids don't leak); `profile` and `markPassedAway` → `NOT_FOUND` per §4.3/§7; `forEdit` returns null; `listUnlinked` → `NOT_FOUND 'family not found'` (BR 120). Bare catalogue FORBIDDEN uses `forbidden()`'s default text.
- **Write flags on create.** `create` honours `write*` flags like `update`; unset group keeps default (null / false).
- **New VALIDATION texts** (no catalogue entry; old DB checks surfaced as "Try again"): `about must be at most 500 characters`, `picture must be a JPEG image`, `picture is too large`, `<birth|death> date and precision must both be set`, `<birth|death> year must be between 1000 and 9999`, `death date needs passed away`, `death is before birth`. `birth date comes from the account` is schema-design §3.2's text.

## File map

| File | Responsibility |
|---|---|
| Create `apps/server/lib/src/people/person_rules.dart` | Pure rules: `normalizeLifeDate`, `shownBirth` (§4.6 coarsening), `applyPersonWrite` (field groups, trimming, life-date rules) |
| Create `apps/server/test/unit/person_rules_test.dart` | Rule unit tests (BR 96 about length, 100 coarsening table, 102 no decade) |
| Create `apps/server/lib/src/endpoints/people_endpoint.dart` | `PeopleEndpoint` |
| Create `apps/server/test/integration/support/people_fixtures.dart` | `personWrite(...)`, `jpegBytes()`, `pngBytes()`, `PeopleFx` (`account`, `reload`, `queued`) |
| Create `apps/server/test/integration/people_endpoint_test.dart` | Integration tests, one group per task |
| Generated | `apps/server/lib/src/generated/endpoints.dart`, `apps/server/test/integration/test_tools/serverpod_test_tools.dart`, `packages/tell_me_a_story_client/lib/src/protocol/client.dart` |

## Notes

- Run everything via `mise exec --`. Format after each step: `mise exec -- dart format apps/server/lib apps/server/test`.
- `just server-generate` with serverpod_cli 4.1.1 rewrites every client protocol file with blank line after first import, unlike committed 3.0 output. Only `client.dart` changes from this slice → restore other client files after generating.
- Integration tests share one DB (`RollbackDatabase.disabled`); `setUp` builds fresh tree: `parent` (owner, coOwner, member), `child` branch (childMember as owner), and `stranger` owning family in another tree.

---

### Task 1: Person rules

**Files:**
- Create: `apps/server/lib/src/people/person_rules.dart`
- Test: `apps/server/test/unit/person_rules_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/people/person_rules.dart';
import 'package:test/test.dart';

Matcher throwsValidation(String message) => throwsA(
  isA<AppException>()
      .having((e) => e.code, 'code', AppErrorCode.validation)
      .having((e) => e.message, 'message', message),
);

PersonWriteDto write({
  String name = 'Ada',
  String? about,
  bool writeAbout = false,
  String? email,
  bool writeEmail = false,
  bool? passedAway,
  bool writePassedAway = false,
  DateTime? birthDate,
  DatePrecision? birthPrecision,
  bool writeBirth = false,
  DateTime? deathDate,
  DatePrecision? deathPrecision,
  bool writeDeath = false,
}) => PersonWriteDto(
  name: name,
  about: about,
  writeAbout: writeAbout,
  email: email,
  writeEmail: writeEmail,
  passedAway: passedAway,
  writePassedAway: writePassedAway,
  clearPicture: false,
  birthDate: birthDate,
  birthPrecision: birthPrecision,
  writeBirth: writeBirth,
  deathDate: deathDate,
  deathPrecision: deathPrecision,
  writeDeath: writeDeath,
);

void main() {
  final treeId = UuidValue.fromString(const Uuid().v7());
  final familyId = UuidValue.fromString(const Uuid().v7());
  Person unlinked() =>
      Person(treeId: treeId, homeFamilyId: familyId, name: 'Old');

  AppUser account(
    BirthVisibility visibility,
    DateTime date,
    DatePrecision precision,
  ) => AppUser(
    authUserId: UuidValue.fromString(const Uuid().v7()),
    birthDate: date,
    birthPrecision: precision,
    birthVisibility: visibility,
  );

  group('Given a life date', () {
    test('when the precision is month then it becomes the 1st', () {
      final d = normalizeLifeDate(
        'birth',
        DateTime.utc(1950, 3, 17),
        DatePrecision.month,
      );
      expect(d.date, DateTime.utc(1950, 3));
      expect(d.precision, DatePrecision.month);
    });

    test('when the precision is year then it becomes 1 January', () {
      final d = normalizeLifeDate(
        'death',
        DateTime.utc(1950, 3, 17),
        DatePrecision.year,
      );
      expect(d.date, DateTime.utc(1950));
    });

    test('when only one half is set then VALIDATION', () {
      expect(
        () => normalizeLifeDate('birth', DateTime.utc(1950), null),
        throwsValidation('birth date and precision must both be set'),
      );
    });

    test('when the year is 999 then VALIDATION', () {
      expect(
        () => normalizeLifeDate('birth', DateTime.utc(999), DatePrecision.year),
        throwsValidation('birth year must be between 1000 and 9999'),
      );
    });
  });

  group('Given an account birth', () {
    final day = DateTime.utc(1950, 3, 17);

    // BR 100
    test('when visibility is hidden then others see nothing', () {
      final b = shownBirth(
        account(BirthVisibility.hidden, day, DatePrecision.day),
        self: false,
      );
      expect(b.date, isNull);
      expect(b.precision, isNull);
    });

    // BR 100
    test('when visibility is year then others see 1 January', () {
      final b = shownBirth(
        account(BirthVisibility.year, day, DatePrecision.day),
        self: false,
      );
      expect(b.date, DateTime.utc(1950));
      expect(b.precision, DatePrecision.year);
    });

    // BR 100
    test('when visibility is yearMonth then others see the 1st', () {
      final b = shownBirth(
        account(BirthVisibility.yearMonth, day, DatePrecision.day),
        self: false,
      );
      expect(b.date, DateTime.utc(1950, 3));
      expect(b.precision, DatePrecision.month);
    });

    // BR 100
    test('when visibility is full then others see the stored day', () {
      final b = shownBirth(
        account(BirthVisibility.full, day, DatePrecision.day),
        self: false,
      );
      expect(b.date, day);
      expect(b.precision, DatePrecision.day);
    });

    // BR 100
    test('when visibility is full and precision month then month', () {
      final b = shownBirth(
        account(
          BirthVisibility.full,
          DateTime.utc(1950, 3),
          DatePrecision.month,
        ),
        self: false,
      );
      expect(b.date, DateTime.utc(1950, 3));
      expect(b.precision, DatePrecision.month);
    });

    // BR 100
    test('when visibility is year and precision day then year', () {
      final b = shownBirth(
        account(BirthVisibility.year, day, DatePrecision.day),
        self: false,
      );
      expect(b.precision, DatePrecision.year);
    });

    // BR 100
    test('when the caller is the linked self then the birth is raw', () {
      final b = shownBirth(
        account(BirthVisibility.hidden, day, DatePrecision.day),
        self: true,
      );
      expect(b.date, day);
      expect(b.precision, DatePrecision.day);
    });
  });

  group('Given a person write', () {
    test('when the name is blank then VALIDATION', () {
      expect(
        () => applyPersonWrite(unlinked(), write(name: '  ')),
        throwsValidation('name is required'),
      );
    });

    // BR 96
    test('when about is over 500 chars then VALIDATION', () {
      expect(
        () => applyPersonWrite(
          unlinked(),
          write(about: 'x' * 501, writeAbout: true),
        ),
        throwsValidation('about must be at most 500 characters'),
      );
    });

    test('when fields are written then they are trimmed and normalized', () {
      final p = applyPersonWrite(
        unlinked(),
        write(
          name: ' Bea ',
          about: '  ',
          writeAbout: true,
          email: ' Bea@X.COM ',
          writeEmail: true,
        ),
      );
      expect(p.name, 'Bea');
      expect(p.about, isNull);
      expect(p.email, 'bea@x.com');
    });

    test('when a write flag is off then the field is kept', () {
      final p = applyPersonWrite(
        unlinked().copyWith(about: 'kept', email: 'k@x.com'),
        write(about: 'new', email: 'n@x.com'),
      );
      expect(p.about, 'kept');
      expect(p.email, 'k@x.com');
    });

    test('when birth is written on a linked person then VALIDATION', () {
      expect(
        () => applyPersonWrite(
          unlinked().copyWith(userId: UuidValue.fromString(const Uuid().v7())),
          write(
            birthDate: DateTime.utc(1950),
            birthPrecision: DatePrecision.year,
            writeBirth: true,
          ),
        ),
        throwsValidation('birth date comes from the account'),
      );
    });

    test(
      'when a death date is written without passed away then VALIDATION',
      () {
        expect(
          () => applyPersonWrite(
            unlinked(),
            write(
              deathDate: DateTime.utc(2000),
              deathPrecision: DatePrecision.year,
              writeDeath: true,
            ),
          ),
          throwsValidation('death date needs passed away'),
        );
      },
    );

    test('when passed away is cleared then the death fields clear', () {
      final p = applyPersonWrite(
        unlinked().copyWith(
          passedAway: true,
          deathDate: DateTime.utc(2000),
          deathPrecision: DatePrecision.year,
        ),
        write(passedAway: false, writePassedAway: true),
      );
      expect(p.passedAway, isFalse);
      expect(p.deathDate, isNull);
      expect(p.deathPrecision, isNull);
    });

    test('when death is before birth then VALIDATION', () {
      expect(
        () => applyPersonWrite(
          unlinked(),
          write(
            passedAway: true,
            writePassedAway: true,
            birthDate: DateTime.utc(1950),
            birthPrecision: DatePrecision.year,
            writeBirth: true,
            deathDate: DateTime.utc(1949),
            deathPrecision: DatePrecision.year,
            writeDeath: true,
          ),
        ),
        throwsValidation('death is before birth'),
      );
    });

    // BR 102
    test('when a precision is chosen then decade is not one of them', () {
      expect(DatePrecision.values.map((p) => p.name), [
        'year',
        'month',
        'day',
      ]);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/unit/person_rules_test.dart`
Expected: compile error, `person_rules.dart` missing.

- [ ] **Step 3: Implement**

```dart
import 'dart:math';

import '../accounts/accounts.dart';
import '../errors.dart';
import '../generated/protocol.dart';

/// A calendar date and its precision; both null or both set.
typedef LifeDate = ({DateTime? date, DatePrecision? precision});

const LifeDate _noDate = (date: null, precision: null);

/// [date] aligned to [precision] as UTC midnight (schema-design.md §0.3):
/// a year is 1 January, a month the 1st. Both null gives no date. [label]
/// (`birth` or `death`) names the field in the `VALIDATION` message.
LifeDate normalizeLifeDate(
  String label,
  DateTime? date,
  DatePrecision? precision,
) {
  if (date == null && precision == null) return _noDate;
  if (date == null || precision == null) {
    throw validation('$label date and precision must both be set');
  }
  final d = date.toUtc();
  if (d.year < 1000 || d.year > 9999) {
    throw validation('$label year must be between 1000 and 9999');
  }
  return (
    date: switch (precision) {
      DatePrecision.year => DateTime.utc(d.year),
      DatePrecision.month => DateTime.utc(d.year, d.month),
      DatePrecision.day => DateTime.utc(d.year, d.month, d.day),
    },
    precision: precision,
  );
}

/// The account birth of a linked person as the caller sees it
/// (business-rules.md §4.6): [self] sees it raw; others see it coarsened to
/// the lower of `birthVisibility` and the stored precision.
LifeDate shownBirth(AppUser? account, {required bool self}) {
  final date = account?.birthDate;
  final precision = account?.birthPrecision;
  if (account == null || date == null || precision == null) return _noDate;
  if (self) return (date: date, precision: precision);
  final visibility = switch (account.birthVisibility) {
    BirthVisibility.hidden => 0,
    BirthVisibility.year => 1,
    BirthVisibility.yearMonth => 2,
    BirthVisibility.full => 3,
  };
  return switch (min(visibility, precision.index + 1)) {
    0 => _noDate,
    1 => (date: DateTime.utc(date.year), precision: DatePrecision.year),
    2 => (
      date: DateTime.utc(date.year, date.month),
      precision: DatePrecision.month,
    ),
    _ => (
      date: DateTime.utc(date.year, date.month, date.day),
      precision: DatePrecision.day,
    ),
  };
}

/// [person] with the field groups [input] writes, validated and normalized
/// (business-rules.md §4.3; schema-design.md §3.2 life dates). Authorization
/// (who may write a linked person, the name lock) is the caller's job.
Person applyPersonWrite(Person person, PersonWriteDto input) {
  final name = input.name.trim();
  if (name.isEmpty) throw validation('name is required');
  var next = person.copyWith(name: name);
  if (input.writeAbout) {
    final about = input.about?.trim() ?? '';
    if (about.length > 500) {
      throw validation('about must be at most 500 characters');
    }
    next = next.copyWith(about: about.isEmpty ? null : about);
  }
  if (input.writeEmail) {
    final email = normalizeEmail(input.email ?? '');
    next = next.copyWith(email: email.isEmpty ? null : email);
  }
  if (input.writePassedAway) {
    next = next.copyWith(passedAway: input.passedAway ?? false);
  }
  if (input.writeBirth) {
    if (person.userId != null) {
      throw validation('birth date comes from the account');
    }
    final birth = normalizeLifeDate(
      'birth',
      input.birthDate,
      input.birthPrecision,
    );
    next = next.copyWith(
      birthDate: birth.date,
      birthPrecision: birth.precision,
    );
  }
  if (input.writeDeath) {
    final death = normalizeLifeDate(
      'death',
      input.deathDate,
      input.deathPrecision,
    );
    if (death.date != null && !next.passedAway) {
      throw validation('death date needs passed away');
    }
    next = next.copyWith(
      deathDate: death.date,
      deathPrecision: death.precision,
    );
  }
  if (!next.passedAway) {
    next = next.copyWith(deathDate: null, deathPrecision: null);
  }
  final birth = next.birthDate;
  final death = next.deathDate;
  if (birth != null && death != null && death.year < birth.year) {
    throw validation('death is before birth');
  }
  return next;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/server && mise exec -- dart test test/unit/person_rules_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/people apps/server/test/unit/person_rules_test.dart
git commit -m "feat(server): person write and birth visibility rules"
```

### Task 2: Reads — `listFamily`, `listTree`, `forEdit`, `profile`

**Files:**
- Create: `apps/server/lib/src/endpoints/people_endpoint.dart`
- Create: `apps/server/test/integration/support/people_fixtures.dart`
- Test: `apps/server/test/integration/people_endpoint_test.dart`

- [ ] **Step 1: Write the fixtures and the failing test**

`people_fixtures.dart`:

```dart
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';

import 'fixtures.dart';

/// The smallest bytes that sniff as JPEG.
ByteData jpegBytes() =>
    ByteData.sublistView(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 1]));

/// A PNG signature, refused for person pictures (JPEG only).
ByteData pngBytes() => ByteData.sublistView(
  Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
);

/// A [PersonWriteDto]; every field group is off unless its flag is set.
PersonWriteDto personWrite({
  String name = 'Ada',
  String? about,
  bool writeAbout = false,
  String? email,
  bool writeEmail = false,
  bool? passedAway,
  bool writePassedAway = false,
  bool clearPicture = false,
  DateTime? birthDate,
  DatePrecision? birthPrecision,
  bool writeBirth = false,
  DateTime? deathDate,
  DatePrecision? deathPrecision,
  bool writeDeath = false,
}) => PersonWriteDto(
  name: name,
  about: about,
  writeAbout: writeAbout,
  email: email,
  writeEmail: writeEmail,
  passedAway: passedAway,
  writePassedAway: writePassedAway,
  clearPicture: clearPicture,
  birthDate: birthDate,
  birthPrecision: birthPrecision,
  writeBirth: writeBirth,
  deathDate: deathDate,
  deathPrecision: deathPrecision,
  writeDeath: writeDeath,
);

/// People-slice builders.
extension PeopleFx on Fx {
  /// Sets [user]'s account profile fields on the app `users` row.
  Future<AppUser> account(
    UuidValue user, {
    String? displayName,
    String? about,
    String? avatarKey,
    DateTime? birthDate,
    DatePrecision? birthPrecision,
    BirthVisibility birthVisibility = BirthVisibility.hidden,
  }) async {
    final row = await AppUser.db.findFirstRow(
      s,
      where: (t) => t.authUserId.equals(user),
    );
    return AppUser.db.updateRow(
      s,
      row!.copyWith(
        displayName: displayName,
        about: about,
        avatarKey: avatarKey,
        birthDate: birthDate,
        birthPrecision: birthPrecision,
        birthVisibility: birthVisibility,
      ),
    );
  }

  Future<Person> reload(Person person) async =>
      (await Person.db.findById(s, person.id!))!;

  Future<bool> queued(String key) async =>
      await BlobDeletion.db.count(s, where: (t) => t.key.equals(key)) > 0;
}
```

`people_endpoint_test.dart` (anonymous test + `reads` group; later tasks add groups before closing `}, rollbackDatabase: …`):

```dart
import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/people_fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given PeopleEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    late Tree tree;
    late Family parent;
    late Family child;
    late UuidValue owner;
    late UuidValue coOwner;
    late UuidValue member;
    late UuidValue childMember;
    late UuidValue stranger;

    TestSessionBuilder as(UuidValue user) => asUser(sessionBuilder, user);

    setUp(() async {
      fx = Fx(sessionBuilder.build());
      tree = await fx.tree();
      parent = await fx.family(tree, name: 'Parent');
      child = await fx.family(
        tree,
        parentId: parent.id,
        branchYear: 1990,
        name: 'Child',
      );
      owner = await fx.user();
      coOwner = await fx.user();
      member = await fx.user();
      childMember = await fx.user();
      stranger = await fx.user();
      await fx.join(parent, owner, MembershipRole.owner);
      await fx.join(parent, coOwner, MembershipRole.coOwner);
      await fx.join(parent, member);
      await fx.join(child, childMember, MembershipRole.owner);
      await fx.join(
        await fx.family(await fx.tree(), name: 'Elsewhere'),
        stranger,
        MembershipRole.owner,
      );
    });

    test('when an anonymous caller lists people then it is refused', () async {
      await expectLater(
        endpoints.people.listFamily(sessionBuilder, parent.id!),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    group('reads', () {
      // BR 95
      test(
        'when a tree member in the child or the parent reads a person then '
        'the row comes back; an outsider gets nothing',
        () async {
          final ada = await fx.person(child, name: 'Ada');

          final fromChild = await endpoints.people.forEdit(
            as(childMember),
            ada.id!,
          );
          final fromParent = await endpoints.people.forEdit(
            as(member),
            ada.id!,
          );
          final fromOutsider = await endpoints.people.forEdit(
            as(stranger),
            ada.id!,
          );

          expect(fromChild!.name, 'Ada');
          expect(fromParent!.homeFamilyId, child.id);
          expect(fromOutsider, isNull);
        },
      );

      test(
        'when the person is linked then forEdit carries userId and email',
        () async {
          final linked = await fx.person(parent, userId: member, name: 'Me');
          await Person.db.updateRow(
            fx.s,
            linked.copyWith(email: 'me@x.com'),
          );

          final row = await endpoints.people.forEdit(as(owner), linked.id!);

          expect(row!.userId, member);
          expect(row.email, 'me@x.com');
        },
      );

      // BR 26 (people part)
      test(
        "when a parent member reads then the child's people are visible",
        () async {
          final kid = await fx.person(child, name: 'Kid');
          final elder = await fx.person(parent, name: 'Elder');

          final childPeople = await endpoints.people.listFamily(
            as(member),
            child.id!,
          );
          final treePeople = await endpoints.people.listTree(
            as(member),
            parent.id!,
          );

          expect(childPeople.map((p) => p.id), [kid.id]);
          expect(treePeople.map((p) => p.id), containsAll([kid.id, elder.id]));
        },
      );

      // BR 28 (people part)
      test('when a stranger reads then no people come back', () async {
        final kid = await fx.person(child, name: 'Kid');

        await expectLater(
          endpoints.people.listFamily(as(stranger), child.id!),
          throwsAppError(AppErrorCode.forbidden),
        );
        await expectLater(
          endpoints.people.listTree(as(stranger), child.id!),
          throwsAppError(AppErrorCode.forbidden),
        );
        await expectLater(
          endpoints.people.profile(as(stranger), kid.id!),
          throwsAppError(AppErrorCode.notFound, 'person not found'),
        );
      });

      // BR 116
      test(
        'when a tree member reads a person in another family of the tree then '
        'passedAway shows; out-of-tree people do not',
        () async {
          final gone = await fx.person(child, name: 'Gone', passedAway: true);
          final elsewhere = await fx.family(await fx.tree());
          final outside = await fx.person(elsewhere, name: 'Out');

          final profile = await endpoints.people.profile(as(member), gone.id!);
          final tree = await endpoints.people.listTree(as(member), parent.id!);

          expect(profile.passedAway, isTrue);
          expect(tree.singleWhere((p) => p.id == gone.id).passedAway, isTrue);
          await expectLater(
            endpoints.people.profile(as(member), outside.id!),
            throwsAppError(AppErrorCode.notFound, 'person not found'),
          );
          await expectLater(
            endpoints.people.listFamily(as(member), elsewhere.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
        },
      );

      // BR 98
      test(
        'when reading a profile then it never carries userId or email; '
        'missing and outsider are NOT_FOUND',
        () async {
          final ada = await fx.person(parent, name: 'Ada');

          final json = (await endpoints.people.profile(
            as(member),
            ada.id!,
          )).toJson();

          expect(json.containsKey('userId'), isFalse);
          expect(json.containsKey('email'), isFalse);
          await expectLater(
            endpoints.people.profile(
              as(member),
              UuidValue.fromString(const Uuid().v7()),
            ),
            throwsAppError(AppErrorCode.notFound, 'person not found'),
          );
          await expectLater(
            endpoints.people.profile(as(stranger), ada.id!),
            throwsAppError(AppErrorCode.notFound, 'person not found'),
          );
        },
      );

      // BR 98
      test(
        'when the person is linked then account about and avatar win when '
        'set, about falls back to the person, and isLinked follows userId',
        () async {
          final withAccount = await fx.person(
            parent,
            userId: member,
            name: 'Linked',
          );
          await Person.db.updateRow(
            fx.s,
            withAccount.copyWith(about: 'person about', avatarKey: 'p.jpg'),
          );
          await fx.account(member, about: 'account about', avatarKey: 'a.jpg');
          final fallback = await fx.person(
            parent,
            userId: coOwner,
            name: 'Fallback',
          );
          await Person.db.updateRow(
            fx.s,
            fallback.copyWith(about: 'person only'),
          );
          final plain = await fx.person(
            parent,
            name: 'Plain',
            passedAway: true,
          );

          final a = await endpoints.people.profile(as(owner), withAccount.id!);
          final b = await endpoints.people.profile(as(owner), fallback.id!);
          final c = await endpoints.people.profile(as(owner), plain.id!);

          expect(a.about, 'account about');
          expect(a.avatarKey, 'a.jpg');
          expect(a.isLinked, isTrue);
          expect(b.about, 'person only');
          expect(c.isLinked, isFalse);
          expect(c.passedAway, isTrue);
        },
      );

      // BR 100
      test(
        'when the account birth is year-visible then others see 1 January '
        'and the linked self sees it raw; a non-tree caller is refused',
        () async {
          final linked = await fx.person(parent, userId: member, name: 'Me');
          await fx.account(
            member,
            birthDate: DateTime.utc(1950, 3, 17),
            birthPrecision: DatePrecision.day,
            birthVisibility: BirthVisibility.year,
          );

          final other = await endpoints.people.profile(as(owner), linked.id!);
          final listed = (await endpoints.people.listTree(
            as(owner),
            parent.id!,
          )).singleWhere((p) => p.id == linked.id);
          final self = await endpoints.people.profile(as(member), linked.id!);

          expect(other.birthDate, DateTime.utc(1950));
          expect(other.birthPrecision, DatePrecision.year);
          expect(listed.birthDate, DateTime.utc(1950));
          expect(listed.birthPrecision, DatePrecision.year);
          expect(self.birthDate, DateTime.utc(1950, 3, 17));
          expect(self.birthPrecision, DatePrecision.day);
          await expectLater(
            endpoints.people.profile(as(stranger), linked.id!),
            throwsAppError(AppErrorCode.notFound, 'person not found'),
          );
        },
      );

      // BR 100
      test('when the account birth is hidden then others see none', () async {
        final linked = await fx.person(parent, userId: member, name: 'Me');
        await fx.account(
          member,
          birthDate: DateTime.utc(1950, 3, 17),
          birthPrecision: DatePrecision.day,
        );

        final other = await endpoints.people.profile(as(owner), linked.id!);

        expect(other.birthDate, isNull);
        expect(other.birthPrecision, isNull);
      });

      // BR 100
      test(
        'when a linked person has a birth on its own row and the account is '
        'hidden then other tree members see no birth',
        () async {
          final linked = await fx.person(
            parent,
            userId: member,
            name: 'Me',
            birthDate: DateTime.utc(1900),
            birthPrecision: DatePrecision.year,
          );
          await fx.account(member);

          final other = await endpoints.people.profile(as(owner), linked.id!);
          final listed = (await endpoints.people.listTree(
            as(owner),
            parent.id!,
          )).singleWhere((p) => p.id == linked.id);

          expect(other.birthDate, isNull);
          expect(other.birthPrecision, isNull);
          expect(listed.birthDate, isNull);
          expect(listed.birthPrecision, isNull);
        },
      );

      test(
        'when the person is unlinked then its own life dates show',
        () async {
          final ada = await fx.person(
            parent,
            birthDate: DateTime.utc(1900, 5),
            birthPrecision: DatePrecision.month,
            deathDate: DateTime.utc(1980),
            deathPrecision: DatePrecision.year,
            passedAway: true,
          );

          final p = await endpoints.people.profile(as(member), ada.id!);

          expect(p.birthDate, DateTime.utc(1900, 5));
          expect(p.birthPrecision, DatePrecision.month);
          expect(p.deathDate, DateTime.utc(1980));
          expect(p.deathPrecision, DatePrecision.year);
        },
      );

      // BR 102
      test(
        'when an account is created then birth visibility is hidden',
        () async {
          final user = await fx.user();
          final row = await AppUser.db.findFirstRow(
            fx.s,
            where: (t) => t.authUserId.equals(user),
          );
          expect(row!.birthVisibility, BirthVisibility.hidden);
        },
      );

      test(
        'when the home family is soft-deleted then the person stays readable '
        'to the tree, but that family cannot be listed',
        () async {
          final gone = await fx.family(
            tree,
            parentId: parent.id,
            branchYear: 1995,
            deletedAt: DateTime.now().toUtc(),
          );
          final ada = await fx.person(gone, name: 'Ada');

          final p = await endpoints.people.profile(as(member), ada.id!);

          expect(p.name, 'Ada');
          await expectLater(
            endpoints.people.listFamily(as(member), gone.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
        },
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/people_endpoint_test.dart`
Expected: compile error, `endpoints.people` missing.

- [ ] **Step 3: Implement the endpoint with the read methods and shared helpers**

```dart
import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';
import '../people/person_rules.dart';

/// People are tree-scoped: reads and unlinked edits need a live membership
/// somewhere in the person's tree (`Authz.isTreeMemberOf(person.treeId)`).
/// Steward-only actions (mark passed away, delete) check the live home family.
class PeopleEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// People whose home is [familyId], by name. The family must be live and
  /// in the caller's tree.
  Future<List<PersonDto>> listFamily(
    Session session,
    UuidValue familyId,
  ) async {
    final authz = Authz(session);
    if (!await authz.isTreeReadable(familyId)) throw forbidden();
    final people = await Person.db.find(
      session,
      where: (t) => t.homeFamilyId.equals(familyId),
      orderByList: (t) => [t.name.asc(), t.id.asc()],
    );
    return _toDtos(session, authz, people);
  }

  /// Every person in [familyId]'s tree, by name, in one call. Linked people
  /// carry their account birth, coarsened for everyone but themselves.
  Future<List<PersonDto>> listTree(Session session, UuidValue familyId) async {
    final authz = Authz(session);
    final family = await _readableFamily(authz, familyId);
    if (family == null) throw forbidden();
    final people = await Person.db.find(
      session,
      where: (t) => t.treeId.equals(family.treeId),
      orderByList: (t) => [t.name.asc(), t.id.asc()],
    );
    return _toDtos(session, authz, people);
  }

  /// The person row for the edit dialog, including `userId` and `email`, for
  /// any tree member; null when missing or outside the caller's trees.
  Future<PersonDto?> forEdit(Session session, UuidValue personId) async {
    final authz = Authz(session);
    final person = await _readablePerson(authz, personId);
    if (person == null) return null;
    return (await _toDtos(session, authz, [person])).single;
  }

  /// The profile dialog (old `person_profile`). Never carries `userId` or
  /// `email`. A linked account's about and avatar win when set; its birth is
  /// coarsened by `birthVisibility` for everyone but the linked self.
  Future<PersonProfileDto> profile(Session session, UuidValue personId) async {
    final authz = Authz(session);
    final person = await _readablePerson(authz, personId);
    if (person == null) throw notFound('person not found');
    final account = await _account(session, person.userId);
    final birth = _birth(person, account, authz.userId);
    return PersonProfileDto(
      id: person.id!,
      homeFamilyId: person.homeFamilyId,
      name: person.name,
      isLinked: person.userId != null,
      birthDate: birth.date,
      birthPrecision: birth.precision,
      deathDate: person.deathDate,
      deathPrecision: person.deathPrecision,
      about: account?.about ?? person.about,
      avatarKey: account?.avatarKey ?? person.avatarKey,
      passedAway: person.passedAway,
    );
  }

  /// [familyId] when it is live and in one of the caller's trees.
  Future<Family?> _readableFamily(Authz authz, UuidValue familyId) async {
    final family = await Family.db.findById(authz.session, familyId);
    if (family == null || family.deletedAt != null) return null;
    if (!await authz.isTreeMemberOf(family.treeId)) return null;
    return family;
  }

  /// [personId] when it exists and the caller is a member of its tree.
  Future<Person?> _readablePerson(Authz authz, UuidValue personId) async {
    final person = await Person.db.findById(authz.session, personId);
    if (person == null || !await authz.isTreeMemberOf(person.treeId)) {
      return null;
    }
    return person;
  }

  Future<AppUser?> _account(Session session, UuidValue? userId) =>
      userId == null
      ? Future.value()
      : AppUser.db.findFirstRow(
          session,
          where: (t) => t.authUserId.equals(userId),
        );

  /// The linked account's birth (coarsened unless [caller] is the linked
  /// self), else the person row's own birth.
  LifeDate _birth(Person person, AppUser? account, UuidValue? caller) =>
      person.userId == null
      ? (date: person.birthDate, precision: person.birthPrecision)
      : shownBirth(account, self: person.userId == caller);

  /// [people] as DTOs, loading every linked account in one query.
  Future<List<PersonDto>> _toDtos(
    Session session,
    Authz authz,
    List<Person> people,
  ) async {
    final userIds = {
      for (final p in people)
        if (p.userId != null) p.userId!,
    };
    final accounts = userIds.isEmpty
        ? const <UuidValue, AppUser>{}
        : {
            for (final a in await AppUser.db.find(
              session,
              where: (t) => t.authUserId.inSet(userIds),
            ))
              a.authUserId: a,
          };
    return [
      for (final p in people)
        _toDto(p, _birth(p, accounts[p.userId], authz.userId)),
    ];
  }

  PersonDto _toDto(Person p, LifeDate birth) => PersonDto(
    id: p.id!,
    treeId: p.treeId,
    homeFamilyId: p.homeFamilyId,
    name: p.name,
    email: p.email,
    about: p.about,
    avatarKey: p.avatarKey,
    userId: p.userId,
    passedAway: p.passedAway,
    birthDate: birth.date,
    birthPrecision: birth.precision,
    deathDate: p.deathDate,
    deathPrecision: p.deathPrecision,
  );
}
```

Then generate:

```bash
mise exec -- just server-generate
git checkout -- $(git diff --name-only packages | grep -v 'lib/src/protocol/client.dart')
```
Second line drops generator-only drift (blank line after first import) in client files this task doesn't change; see Notes.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/server && mise exec -- dart test test/integration/people_endpoint_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server packages/tell_me_a_story_client
git commit -m "feat(server): people reads with tree scope and birth coarsening"
```

### Task 3: Writes — `create`, `update` (inline pictures)

**Files:**
- Modify: `apps/server/lib/src/endpoints/people_endpoint.dart`
- Test: `apps/server/test/integration/people_endpoint_test.dart`

- [ ] **Step 1: Write the failing test** — add `import 'dart:async';` and `import 'package:tell_me_a_story_server/src/media/blob_keys.dart';`, plus this group after `reads`:

```dart
    group('writes', () {
      test(
        'when a live member creates a person with a picture then the row '
        'and the blob exist under a person avatar key',
        () async {
          final dto = await endpoints.people.create(
            as(member),
            parent.id!,
            personWrite(
              name: ' Bea ',
              about: 'hi',
              writeAbout: true,
              email: 'Bea@X.com',
              writeEmail: true,
            ),
            jpegBytes(),
          );

          final row = (await Person.db.findById(fx.s, dto.id))!;
          expect(row.name, 'Bea');
          expect(row.treeId, tree.id);
          expect(row.homeFamilyId, parent.id);
          expect(row.userId, isNull);
          expect(row.createdById, member);
          expect(row.email, 'bea@x.com');
          expect(dto.avatarKey, row.avatarKey);
          expect(
            row.avatarKey,
            matches(
              RegExp(
                '^trees/${tree.id}/people/${dto.id}/avatar/[0-9a-f-]{36}\\.jpg\$',
              ),
            ),
          );
          expect(
            await fx.s.storage.fileExists(
              storageId: blobStorageId,
              path: row.avatarKey!,
            ),
            isTrue,
          );
        },
      );

      test(
        'when a tree reader of another family or a member of a soft-deleted '
        'family creates then FORBIDDEN',
        () async {
          final gone = await fx.family(
            await fx.tree(),
            deletedAt: DateTime.now().toUtc(),
          );
          await fx.join(gone, stranger, MembershipRole.owner);

          await expectLater(
            endpoints.people.create(
              as(childMember),
              parent.id!,
              personWrite(),
              null,
            ),
            throwsAppError(AppErrorCode.forbidden, 'member only'),
          );
          await expectLater(
            endpoints.people.create(
              as(stranger),
              gone.id!,
              personWrite(),
              null,
            ),
            throwsAppError(AppErrorCode.forbidden, 'member only'),
          );
        },
      );

      test(
        'when the picture is not a JPEG then VALIDATION and no row',
        () async {
          final before = await Person.db.count(
            fx.s,
            where: (t) => t.homeFamilyId.equals(parent.id),
          );
          await expectLater(
            endpoints.people.create(
              as(member),
              parent.id!,
              personWrite(),
              pngBytes(),
            ),
            throwsAppError(
              AppErrorCode.validation,
              'picture must be a JPEG image',
            ),
          );
          expect(
            await Person.db.count(
              fx.s,
              where: (t) => t.homeFamilyId.equals(parent.id),
            ),
            before,
          );
        },
      );

      // BR 96
      test('when about is over 500 chars then VALIDATION', () async {
        final ada = await fx.person(parent);
        await expectLater(
          endpoints.people.update(
            as(member),
            ada.id!,
            personWrite(about: 'x' * 501, writeAbout: true),
            null,
          ),
          throwsAppError(
            AppErrorCode.validation,
            'about must be at most 500 characters',
          ),
        );
      });

      // BR 97
      test(
        'when a tree member edits an unlinked person then it saves; a linked '
        'person is refused; the linked user cannot rename; unlinking reopens',
        () async {
          final ada = await fx.person(child, name: 'Ada');
          final linked = await fx.person(parent, userId: coOwner, name: 'Co');

          final saved = await endpoints.people.update(
            as(member),
            ada.id!,
            personWrite(name: 'Ada B'),
            null,
          );
          expect(saved.name, 'Ada B');

          await expectLater(
            endpoints.people.update(
              as(member),
              linked.id!,
              personWrite(name: 'Co', about: 'x', writeAbout: true),
              null,
            ),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.people.update(
              as(coOwner),
              linked.id!,
              personWrite(name: 'New name'),
              null,
            ),
            throwsAppError(AppErrorCode.forbidden, 'linked_person_name_locked'),
          );
          expect((await fx.reload(linked)).name, 'Co');

          final own = await endpoints.people.update(
            as(coOwner),
            linked.id!,
            personWrite(name: 'Co', about: 'mine', writeAbout: true),
            null,
          );
          expect(own.about, 'mine');

          await Person.db.updateRow(fx.s, linked.copyWith(userId: null));
          final reopened = await endpoints.people.update(
            as(member),
            linked.id!,
            personWrite(name: 'Renamed'),
            null,
          );
          expect(reopened.name, 'Renamed');
        },
      );

      test(
        'when the person is linked to someone else while an edit waits for '
        'the row lock then the edit is refused and nothing changes',
        () async {
          final ada = await fx.person(parent, name: 'Ada');
          final locked = Completer<void>();
          final release = Completer<void>();
          final linker = fx.s.db.transaction((t) async {
            await Person.db.findById(
              fx.s,
              ada.id!,
              transaction: t,
              lockMode: LockMode.forUpdate,
            );
            locked.complete();
            await release.future;
            await Person.db.updateRow(
              fx.s,
              ada.copyWith(userId: coOwner),
              transaction: t,
            );
          });
          await locked.future;

          final outcome = endpoints.people
              .update(as(member), ada.id!, personWrite(name: 'Renamed'), null)
              .then<Object?>((_) => null, onError: (Object e) => e);
          await Future<void>.delayed(const Duration(milliseconds: 300));
          release.complete();
          await linker;

          expect(
            await outcome,
            isA<AppException>().having(
              (e) => e.code,
              'code',
              AppErrorCode.forbidden,
            ),
          );
          final row = await fx.reload(ada);
          expect(row.name, 'Ada');
          expect(row.userId, coOwner);
        },
      );

      // BR 99
      test(
        'when a tree member uploads an unlinked avatar then it saves and the '
        'old key is queued; an outsider and another member of a linked '
        'person are refused; the linked user can upload',
        () async {
          final ada = await fx.person(child, name: 'Ada');
          final first = await endpoints.people.update(
            as(member),
            ada.id!,
            personWrite(),
            jpegBytes(),
          );
          final second = await endpoints.people.update(
            as(childMember),
            ada.id!,
            personWrite(),
            jpegBytes(),
          );
          expect(second.avatarKey, isNot(first.avatarKey));
          expect(await fx.queued(first.avatarKey!), isTrue);

          await expectLater(
            endpoints.people.update(
              as(stranger),
              ada.id!,
              personWrite(),
              jpegBytes(),
            ),
            throwsAppError(AppErrorCode.forbidden),
          );

          final linked = await fx.person(parent, userId: coOwner, name: 'Co');
          await expectLater(
            endpoints.people.update(
              as(member),
              linked.id!,
              personWrite(name: 'Co'),
              jpegBytes(),
            ),
            throwsAppError(AppErrorCode.forbidden),
          );
          final own = await endpoints.people.update(
            as(coOwner),
            linked.id!,
            personWrite(name: 'Co'),
            jpegBytes(),
          );
          expect(
            own.avatarKey,
            startsWith('trees/${tree.id}/people/${linked.id}/'),
          );
        },
      );

      test('when the picture is cleared then the old key is queued', () async {
        final ada = await fx.person(parent);
        final withPicture = await endpoints.people.update(
          as(member),
          ada.id!,
          personWrite(),
          jpegBytes(),
        );

        final cleared = await endpoints.people.update(
          as(member),
          ada.id!,
          personWrite(clearPicture: true),
          null,
        );

        expect(cleared.avatarKey, isNull);
        expect(await fx.queued(withPicture.avatarKey!), isTrue);
      });

      // BR 104
      test(
        'when a linked user changes their own passedAway then FORBIDDEN',
        () async {
          final me = await fx.person(parent, userId: member, name: 'Me');
          await expectLater(
            endpoints.people.update(
              as(member),
              me.id!,
              personWrite(name: 'Me', passedAway: true, writePassedAway: true),
              null,
            ),
            throwsAppError(AppErrorCode.forbidden),
          );
          expect((await fx.reload(me)).passedAway, isFalse);
        },
      );

      // BR 105 (flag part)
      test(
        'when a tree member flags and unflags an unlinked person then it toggles',
        () async {
          final ada = await fx.person(child);

          final flagged = await endpoints.people.update(
            as(member),
            ada.id!,
            personWrite(passedAway: true, writePassedAway: true),
            null,
          );
          final cleared = await endpoints.people.update(
            as(member),
            ada.id!,
            personWrite(passedAway: false, writePassedAway: true),
            null,
          );

          expect(flagged.passedAway, isTrue);
          expect(cleared.passedAway, isFalse);
        },
      );

      test(
        'when life dates are written then they are aligned to precision; '
        'birth on a linked person is VALIDATION',
        () async {
          final ada = await fx.person(parent);
          final saved = await endpoints.people.update(
            as(member),
            ada.id!,
            personWrite(
              passedAway: true,
              writePassedAway: true,
              birthDate: DateTime.utc(1900, 5, 20),
              birthPrecision: DatePrecision.month,
              writeBirth: true,
              deathDate: DateTime.utc(1980, 7, 4),
              deathPrecision: DatePrecision.year,
              writeDeath: true,
            ),
            null,
          );
          expect(saved.birthDate, DateTime.utc(1900, 5));
          expect(saved.deathDate, DateTime.utc(1980));

          final me = await fx.person(parent, userId: member, name: 'Me');
          await expectLater(
            endpoints.people.update(
              as(member),
              me.id!,
              personWrite(
                name: 'Me',
                birthDate: DateTime.utc(1950),
                birthPrecision: DatePrecision.year,
                writeBirth: true,
              ),
              null,
            ),
            throwsAppError(
              AppErrorCode.validation,
              'birth date comes from the account',
            ),
          );
        },
      );
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/people_endpoint_test.dart`
Expected: compile error, `create`/`update` missing.

- [ ] **Step 3: Implement** — add `import 'dart:typed_data';`, `import '../media/blob_keys.dart';`, `import '../media/blob_outbox.dart';`; `create` after `listTree`; `update` + its `_checkLinkedWrite` helper after `profile`; picture helpers at end of class:

```dart
  /// Adds an unlinked person with [familyId] as home. A [picture] (JPEG,
  /// ≤ 2 MiB) is stored inline under a fresh `personAvatarKey`.
  Future<PersonDto> create(
    Session session,
    UuidValue familyId,
    PersonWriteDto input,
    ByteData? picture,
  ) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    await authz.requireLiveMember(familyId);
    final family = (await Family.db.findById(session, familyId))!;
    final person = applyPersonWrite(
      Person(
        id: UuidValue.fromString(const Uuid().v7()),
        treeId: family.treeId,
        homeFamilyId: familyId,
        name: '',
        createdById: uid,
      ),
      input,
    );
    if (picture != null) _checkPicture(picture);
    final key = picture == null
        ? null
        : await _storePicture(session, person, picture);
    final Person saved;
    try {
      saved = await session.db.transaction(
        (t) => Person.db.insertRow(
          session,
          person.copyWith(avatarKey: key),
          transaction: t,
        ),
      );
    } catch (_) {
      await queueBlobDeletions(session, [key]);
      rethrow;
    }
    return (await _toDtos(session, authz, [saved])).single;
  }

  /// Edits a person. Unlinked: any tree member. Linked: only the linked self,
  /// with the name locked to the account, and no passed-away or death change.
  /// A [picture] replaces the avatar; [PersonWriteDto.clearPicture] removes
  /// it. The old key is queued for deletion in the same transaction.
  Future<PersonDto> update(
    Session session,
    UuidValue personId,
    PersonWriteDto input,
    ByteData? picture,
  ) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    final person = await _readablePerson(authz, personId);
    if (person == null) throw forbidden();
    _checkLinkedWrite(person, uid, input);
    applyPersonWrite(person, input);
    if (picture != null) _checkPicture(picture);
    final key = picture == null
        ? null
        : await _storePicture(session, person, picture);
    final Person saved;
    try {
      saved = await session.db.transaction((t) async {
        final current = await Person.db.findById(
          session,
          personId,
          transaction: t,
          lockMode: LockMode.forUpdate,
        );
        if (current == null) throw forbidden();
        _checkLinkedWrite(current, uid, input);
        var next = applyPersonWrite(
          current,
          input,
        ).copyWith(updatedAt: DateTime.now().toUtc());
        if (key != null || input.clearPicture) {
          await queueBlobDeletions(session, [
            current.avatarKey,
          ], transaction: t);
          next = next.copyWith(avatarKey: key);
        }
        return Person.db.updateRow(session, next, transaction: t);
      });
    } catch (_) {
      await queueBlobDeletions(session, [key]);
      rethrow;
    }
    return (await _toDtos(session, authz, [saved])).single;
  }

  /// A linked row is written only by its linked self, keeping the account's
  /// name and leaving passed-away and death to stewards. Run on the read row
  /// (so a refused write stores no picture) and again on the locked row, so
  /// a person linked meanwhile is not edited by someone else.
  void _checkLinkedWrite(
    Person person,
    UuidValue caller,
    PersonWriteDto input,
  ) {
    final linkedId = person.userId;
    if (linkedId == null) return;
    if (linkedId != caller) throw forbidden();
    if (input.name.trim() != person.name) {
      throw forbidden('linked_person_name_locked');
    }
    if (input.writePassedAway &&
        (input.passedAway ?? false) != person.passedAway) {
      throw forbidden();
    }
    if (input.writeDeath) throw forbidden();
  }

  /// Person avatars are JPEG only, ≤ 2 MiB (schema-design.md §4.2).
  void _checkPicture(ByteData picture) {
    if (picture.lengthInBytes > avatarMaxBytes) {
      throw validation('picture is too large');
    }
    if (sniffImageMime(picture) != 'image/jpeg') {
      throw validation('picture must be a JPEG image');
    }
  }

  Future<String> _storePicture(
    Session session,
    Person person,
    ByteData picture,
  ) async {
    final key = personAvatarKey(treeId: person.treeId, personId: person.id!);
    await session.storage.storeFile(
      storageId: blobStorageId,
      path: key,
      byteData: picture,
      options: const StoreFileOptions(preventOverwrite: true),
    );
    return key;
  }
```

Then generate (same commands as Task 2).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/server && mise exec -- dart test test/integration/people_endpoint_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server packages/tell_me_a_story_client
git commit -m "feat(server): people create and update with inline pictures"
```

### Task 4: `markPassedAway`

**Files:**
- Modify: `apps/server/lib/src/endpoints/people_endpoint.dart`
- Test: `apps/server/test/integration/people_endpoint_test.dart`

- [ ] **Step 1: Write the failing test** — add after `writes`:

```dart
    group('markPassedAway', () {
      // BR 103
      test(
        'when the owner or co-owner of the home family marks a linked person '
        'then the flag toggles and name and about stay',
        () async {
          final linked = await fx.person(parent, userId: member, name: 'Me');
          await Person.db.updateRow(fx.s, linked.copyWith(about: 'about'));

          await endpoints.people.markPassedAway(as(owner), linked.id!, true);
          final marked = await fx.reload(linked);
          await endpoints.people.markPassedAway(as(coOwner), linked.id!, false);
          final unmarked = await fx.reload(linked);

          expect(marked.passedAway, isTrue);
          expect(unmarked.passedAway, isFalse);
          expect(unmarked.name, 'Me');
          expect(unmarked.about, 'about');
        },
      );

      test('when the flag is cleared then the death fields clear', () async {
        final linked = await fx.person(
          parent,
          userId: member,
          passedAway: true,
          deathDate: DateTime.utc(2000),
          deathPrecision: DatePrecision.year,
        );

        await endpoints.people.markPassedAway(as(owner), linked.id!, false);

        final row = await fx.reload(linked);
        expect(row.deathDate, isNull);
        expect(row.deathPrecision, isNull);
      });

      // BR 103
      test(
        'when another tree family owner, a plain member, self, an unlinked '
        'target or a non-tree caller marks then refused with §4.3 codes',
        () async {
          final linked = await fx.person(parent, userId: member, name: 'Me');
          final unlinked = await fx.person(parent, name: 'Ada');

          await expectLater(
            endpoints.people.markPassedAway(as(childMember), linked.id!, true),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.people.markPassedAway(as(coOwner), unlinked.id!, true),
            throwsAppError(AppErrorCode.validation, 'person has not signed in'),
          );
          await expectLater(
            endpoints.people.markPassedAway(as(member), linked.id!, true),
            throwsAppError(AppErrorCode.validation, 'cannot mark yourself'),
          );
          final other = await fx.person(parent, userId: owner, name: 'Owner');
          await expectLater(
            endpoints.people.markPassedAway(as(member), other.id!, true),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.people.markPassedAway(as(stranger), linked.id!, true),
            throwsAppError(AppErrorCode.notFound, 'person not found'),
          );
          await expectLater(
            endpoints.people.markPassedAway(
              as(owner),
              UuidValue.fromString(const Uuid().v7()),
              true,
            ),
            throwsAppError(AppErrorCode.notFound, 'person not found'),
          );
          expect((await fx.reload(linked)).passedAway, isFalse);
        },
      );
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/people_endpoint_test.dart`
Expected: compile error, `markPassedAway` missing.

- [ ] **Step 3: Implement** — add after `update`:

```dart
  /// Sets or clears a linked person's passed-away flag (old
  /// `mark_passed_away`). Checks in the business-rules.md §4.3 order;
  /// clearing the flag clears the death fields.
  Future<void> markPassedAway(
    Session session,
    UuidValue personId,
    bool value,
  ) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    final person = await _readablePerson(authz, personId);
    if (person == null) throw notFound('person not found');
    if (person.userId == null) throw validation('person has not signed in');
    if (person.userId == uid) throw validation('cannot mark yourself');
    if (!await authz.isLiveSteward(person.homeFamilyId)) throw forbidden();
    await session.db.transaction((t) async {
      final current = await Person.db.findById(
        session,
        personId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      );
      if (current == null) throw notFound('person not found');
      await Person.db.updateRow(
        session,
        current.copyWith(
          passedAway: value,
          deathDate: value ? current.deathDate : null,
          deathPrecision: value ? current.deathPrecision : null,
          updatedAt: DateTime.now().toUtc(),
        ),
        transaction: t,
      );
    });
  }
```

Then generate (same commands as Task 2).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/server && mise exec -- dart test test/integration/people_endpoint_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server packages/tell_me_a_story_client
git commit -m "feat(server): steward marks a linked person passed away"
```

### Task 5: `listUnlinked`, `isHomeFamilySteward`

**Files:**
- Modify: `apps/server/lib/src/endpoints/people_endpoint.dart`
- Test: `apps/server/test/integration/people_endpoint_test.dart`

- [ ] **Step 1: Write the failing test** — add between `writes` and `markPassedAway`:

```dart
    group('invite picker and steward check', () {
      // BR 120
      test(
        'when listing unlinked people then the whole live tree is covered, '
        'without linked, passed or pending-invite people; outsider and '
        'missing family are NOT_FOUND',
        () async {
          final inParent = await fx.person(parent, name: 'A parent');
          final inChild = await fx.person(child, name: 'B child');
          await fx.person(parent, userId: member, name: 'C linked');
          await fx.person(child, name: 'D passed', passedAway: true);
          final invited = await fx.person(parent, name: 'E invited');
          await fx.invite(parent, personId: invited.id);
          final expired = await fx.person(parent, name: 'F expired');
          final expiredInvite = await fx.invite(parent, personId: expired.id);
          await Invite.db.updateRow(
            fx.s,
            expiredInvite.copyWith(
              createdAt: DateTime.now().toUtc().subtract(
                const Duration(days: 9),
              ),
              expiresAt: DateTime.now().toUtc().subtract(
                const Duration(days: 1),
              ),
            ),
          );
          final revoked = await fx.person(parent, name: 'G revoked');
          final revokedInvite = await fx.invite(parent, personId: revoked.id);
          await Invite.db.updateRow(
            fx.s,
            revokedInvite.copyWith(revokedAt: DateTime.now().toUtc()),
          );

          final list = await endpoints.people.listUnlinked(
            as(childMember),
            child.id!,
          );

          expect(list.map((p) => p.id), [
            inParent.id,
            inChild.id,
            expired.id,
            revoked.id,
          ]);
          await expectLater(
            endpoints.people.listUnlinked(as(stranger), parent.id!),
            throwsAppError(AppErrorCode.notFound, 'family not found'),
          );
          await expectLater(
            endpoints.people.listUnlinked(
              as(member),
              UuidValue.fromString(const Uuid().v7()),
            ),
            throwsAppError(AppErrorCode.notFound, 'family not found'),
          );
        },
      );

      // BR 105
      test(
        'when an unlinked person is flagged then they leave the unlinked list '
        'and return when cleared; a linked person stays out after unmark',
        () async {
          final ada = await fx.person(parent, name: 'Ada');
          final linked = await fx.person(parent, userId: coOwner, name: 'Co');
          Future<List<UuidValue>> ids() async =>
              (await endpoints.people.listUnlinked(
                as(member),
                parent.id!,
              )).map((p) => p.id).toList();

          await endpoints.people.update(
            as(member),
            ada.id!,
            personWrite(passedAway: true, writePassedAway: true),
            null,
          );
          expect(await ids(), isNot(contains(ada.id)));

          await endpoints.people.update(
            as(member),
            ada.id!,
            personWrite(passedAway: false, writePassedAway: true),
            null,
          );
          expect(await ids(), contains(ada.id));

          await endpoints.people.markPassedAway(as(owner), linked.id!, true);
          await endpoints.people.markPassedAway(as(owner), linked.id!, false);
          expect(await ids(), isNot(contains(linked.id)));
        },
      );

      test(
        'when asking isHomeFamilySteward then owner and co-owner of the live '
        'family are true; members and other-family owners are false',
        () async {
          expect(
            await endpoints.people.isHomeFamilySteward(as(owner), parent.id!),
            isTrue,
          );
          expect(
            await endpoints.people.isHomeFamilySteward(as(coOwner), parent.id!),
            isTrue,
          );
          expect(
            await endpoints.people.isHomeFamilySteward(as(member), parent.id!),
            isFalse,
          );
          expect(
            await endpoints.people.isHomeFamilySteward(
              as(childMember),
              parent.id!,
            ),
            isFalse,
          );
          await Family.db.updateRow(
            fx.s,
            parent.copyWith(deletedAt: DateTime.now().toUtc()),
          );
          expect(
            await endpoints.people.isHomeFamilySteward(as(owner), parent.id!),
            isFalse,
          );
        },
      );
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/people_endpoint_test.dart`
Expected: compile error, `listUnlinked`/`isHomeFamilySteward` missing.

- [ ] **Step 3: Implement** — add before `markPassedAway`:

```dart
  /// The invite picker: people in [familyId]'s tree who are unlinked, not
  /// passed away, and have no pending invite (not accepted, not revoked,
  /// unexpired), by name.
  Future<List<PersonDto>> listUnlinked(
    Session session,
    UuidValue familyId,
  ) async {
    final authz = Authz(session);
    final family = await _readableFamily(authz, familyId);
    if (family == null) throw notFound('family not found');
    final people = await Person.db.find(
      session,
      where: (t) =>
          t.treeId.equals(family.treeId) &
          t.userId.equals(null) &
          t.passedAway.equals(false),
      orderByList: (t) => [t.name.asc(), t.id.asc()],
    );
    if (people.isEmpty) return const [];
    final invited = await Invite.db.find(
      session,
      where: (t) =>
          t.personId.inSet(people.map((p) => p.id!).toSet()) &
          t.acceptedAt.equals(null) &
          t.revokedAt.equals(null) &
          (t.expiresAt > DateTime.now().toUtc()),
    );
    final pending = invited.map((i) => i.personId).toSet();
    return _toDtos(session, authz, [
      for (final p in people)
        if (!pending.contains(p.id)) p,
    ]);
  }

  /// Whether the caller is an owner or co-owner of live [familyId].
  Future<bool> isHomeFamilySteward(Session session, UuidValue familyId) =>
      Authz(session).isLiveSteward(familyId);
```

Then generate (same commands as Task 2).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/server && mise exec -- dart test test/integration/people_endpoint_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server packages/tell_me_a_story_client
git commit -m "feat(server): unlinked person picker and home steward check"
```

### Task 6: `delete` (D5)

**Files:**
- Modify: `apps/server/lib/src/endpoints/people_endpoint.dart`
- Test: `apps/server/test/integration/people_endpoint_test.dart`

- [ ] **Step 1: Write the failing test** — add after `markPassedAway`:

```dart
    group('delete', () {
      // BR 136
      test(
        'when a plain member deletes an unlinked person then FORBIDDEN; the '
        'owner deletes it; a linked person is VALIDATION',
        () async {
          final ada = await fx.person(parent, name: 'Ada');
          final story = await fx.story(parent);
          await fx.tag(story, ada);
          final linked = await fx.person(parent, userId: member, name: 'Me');

          await expectLater(
            endpoints.people.delete(as(member), ada.id!),
            throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
          );
          expect(await Person.db.findById(fx.s, ada.id!), isNotNull);

          await endpoints.people.delete(as(owner), ada.id!);
          expect(await Person.db.findById(fx.s, ada.id!), isNull);
          expect(
            await StoryPerson.db.count(
              fx.s,
              where: (t) => t.personId.equals(ada.id),
            ),
            0,
          );

          await expectLater(
            endpoints.people.delete(as(owner), linked.id!),
            throwsAppError(
              AppErrorCode.validation,
              'person is linked to an account',
            ),
          );
          expect(await Person.db.findById(fx.s, linked.id!), isNotNull);
        },
      );

      test(
        'when a person with an invite is deleted then the invite stays with '
        'no person',
        () async {
          final ada = await fx.person(parent);
          final invite = await fx.invite(parent, personId: ada.id);

          await endpoints.people.delete(as(owner), ada.id!);

          final row = await Invite.db.findById(fx.s, invite.id!);
          expect(row, isNotNull);
          expect(row!.personId, isNull);
        },
      );

      test(
        'when a person with a picture is deleted then the key is queued',
        () async {
          final ada = await fx.person(parent);
          final withPicture = await endpoints.people.update(
            as(member),
            ada.id!,
            personWrite(),
            jpegBytes(),
          );

          await endpoints.people.delete(as(coOwner), ada.id!);

          expect(await fx.queued(withPicture.avatarKey!), isTrue);
        },
      );

      test(
        'when the home family is soft-deleted, the caller is an owner of '
        'another tree family, or the person is missing then FORBIDDEN',
        () async {
          final gone = await fx.family(
            tree,
            parentId: parent.id,
            branchYear: 1995,
            deletedAt: DateTime.now().toUtc(),
          );
          await fx.join(gone, owner, MembershipRole.owner);
          final inGone = await fx.person(gone);
          final inParent = await fx.person(parent);

          await expectLater(
            endpoints.people.delete(as(owner), inGone.id!),
            throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
          );
          await expectLater(
            endpoints.people.delete(as(childMember), inParent.id!),
            throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
          );
          await expectLater(
            endpoints.people.delete(
              as(owner),
              UuidValue.fromString(const Uuid().v7()),
            ),
            throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
          );
        },
      );
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/people_endpoint_test.dart`
Expected: compile error, `delete` missing.

- [ ] **Step 3: Implement** — add after `markPassedAway`:

```dart
  /// Deletes an unlinked person (D5): owner or co-owner of the live home
  /// family only. Tags and kinships cascade; invites keep a null person. The
  /// avatar key is queued for deletion in the same transaction.
  Future<void> delete(Session session, UuidValue personId) async {
    final authz = Authz(session);
    final person = await Person.db.findById(session, personId);
    if (person == null) throw forbidden('owner or co-owner only');
    await authz.requireLiveSteward(person.homeFamilyId);
    if (person.userId != null) {
      throw validation('person is linked to an account');
    }
    await session.db.transaction((t) async {
      final current = await Person.db.findById(
        session,
        personId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      );
      if (current == null) return;
      if (current.userId != null) {
        throw validation('person is linked to an account');
      }
      await queueBlobDeletions(session, [current.avatarKey], transaction: t);
      await Person.db.deleteRow(session, current, transaction: t);
    });
  }
```

Then generate (same commands as Task 2).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/server && mise exec -- dart test test/integration/people_endpoint_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server packages/tell_me_a_story_client
git commit -m "feat(server): stewards delete unlinked people"
```

### Task 7: Gate

- [ ] `mise exec -- dart format --output=none --set-exit-if-changed apps/server/lib apps/server/test` → `0 changed`.
- [ ] `cd apps/server && mise exec -- dart analyze lib test` and `cd packages/tell_me_a_story_client && mise exec -- dart analyze` → `No issues found!`.
- [ ] `mise exec -- just server-test` → all pass.

## Port coverage

| BR | Test |
|---|---|
| 26 (people part) | reads: "when a parent member reads then the child's people are visible" |
| 28 (people part) | reads: "when a stranger reads then no people come back" |
| 95 | reads: "when a tree member in the child or the parent reads a person …" (+ anonymous test) |
| 96 | unit: about > 500; writes: about > 500, picture key shape on create |
| 97 | writes: "when a tree member edits an unlinked person …"; "when the person is linked to someone else while an edit waits for the row lock …" (linked-row rules rechecked on locked row) |
| 98 | reads: two profile tests |
| 99 | writes: avatar upload test (read part is 3d) |
| 100 | unit: coarsening table; reads: year-visible, hidden, own-row birth ignored while linked |
| 102 | unit: no decade precision; reads: default visibility hidden |
| 103 | markPassedAway: both BR 103 tests |
| 104 | writes: linked user changes own passedAway |
| 105 | writes: flag/unflag; picker: leaves + returns to unlinked list |
| 116 | reads: passedAway across families, out-of-tree refused |
| 120 | picker: whole live tree, exclusions, NOT_FOUND |
| 136 | delete: four tests (incl. invite keeps null personId) |