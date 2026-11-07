import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/authz/authz.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given families in one tree', (sessionBuilder, endpoints) {
    late Session db;
    late UuidValue owner, member, branchMember, stranger;
    late Family root, branch, deletedBranch;

    Authz authzFor(UuidValue? user) => Authz(
          (user == null
                  ? sessionBuilder
                  : sessionBuilder.copyWith(
                      authentication: AuthenticationOverride.authenticationInfo(
                        user.uuid,
                        {},
                      ),
                    ))
              .build(),
        );

    Future<UuidValue> newUser() async =>
        (await AuthServices.instance.authUsers.create(db)).id;

    Future<void> join(Family f, UuidValue user, MembershipRole role) =>
        Membership.db.insertRow(
          db,
          Membership(familyId: f.id!, userId: user, role: role),
        );

    setUp(() async {
      db = sessionBuilder.build();
      owner = await newUser();
      member = await newUser();
      branchMember = await newUser();
      stranger = await newUser();
      final tree = await Tree.db.insertRow(db, Tree());
      root = await Family.db.insertRow(
        db,
        Family(treeId: tree.id!, name: 'Root'),
      );
      branch = await Family.db.insertRow(
        db,
        Family(treeId: tree.id!, parentId: root.id, name: 'Branch'),
      );
      deletedBranch = await Family.db.insertRow(
        db,
        Family(
          treeId: tree.id!,
          parentId: root.id,
          name: 'Gone',
          deletedAt: DateTime.now().toUtc(),
        ),
      );
      await join(root, owner, MembershipRole.owner);
      await join(root, member, MembershipRole.member);
      await join(branch, branchMember, MembershipRole.member);
      await join(deletedBranch, member, MembershipRole.owner);
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
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'auth_required')),
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
