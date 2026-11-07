import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/db/constraints.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given the raw SQL constraints', (sessionBuilder, endpoints) {
    late Session session;

    setUp(() async {
      session = sessionBuilder.build();
      await session.db.unsafeSimpleExecute(constraintsSql);
    });

    test('when a second owner is added to a family then the insert fails',
        () async {
      final a = await AuthServices.instance.authUsers.create(session);
      final b = await AuthServices.instance.authUsers.create(session);
      final tree = await Tree.db.insertRow(session, Tree());
      final family = await Family.db.insertRow(
        session,
        Family(treeId: tree.id!, name: 'Mortang'),
      );
      await Membership.db.insertRow(
        session,
        Membership(familyId: family.id!, userId: a.id, role: MembershipRole.owner),
      );

      await expectLater(
        Membership.db.insertRow(
          session,
          Membership(
            familyId: family.id!,
            userId: b.id,
            role: MembershipRole.owner,
          ),
        ),
        throwsA(isA<DatabaseQueryException>()),
      );
    });

    test('when the constraints run twice then the second run succeeds',
        () async {
      await session.db.unsafeSimpleExecute(constraintsSql);
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
