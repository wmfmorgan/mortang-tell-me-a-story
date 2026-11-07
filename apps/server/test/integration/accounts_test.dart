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

    test('a person linked in another tree is not reused', () async {
      final user = await fx.userWithEmail('ed@example.com');
      final homeA = await fx.family(await fx.tree());
      final homeB = await fx.family(await fx.tree());

      final inA = await ensure(homeA, user);
      final inB = await ensure(homeB, user);

      expect(inB.id, isNot(inA.id));
      expect(inB.treeId, homeB.treeId);
      expect(inB.homeFamilyId, homeB.id);
    });

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
