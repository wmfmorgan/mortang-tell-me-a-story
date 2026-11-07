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
  }, rollbackDatabase: RollbackDatabase.disabled);
}
