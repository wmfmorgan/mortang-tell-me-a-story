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
