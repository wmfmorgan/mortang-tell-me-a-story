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
  }, rollbackDatabase: RollbackDatabase.disabled);
}
