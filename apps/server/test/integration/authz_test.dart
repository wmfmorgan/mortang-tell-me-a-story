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
