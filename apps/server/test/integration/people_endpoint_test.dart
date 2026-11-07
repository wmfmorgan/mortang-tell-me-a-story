import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/media/blob_keys.dart';
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
  }, rollbackDatabase: RollbackDatabase.disabled);
}
