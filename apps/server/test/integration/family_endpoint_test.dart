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
  }, rollbackDatabase: RollbackDatabase.disabled);
}
