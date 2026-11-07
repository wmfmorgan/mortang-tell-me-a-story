import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/invites/invites.dart';
import 'package:tell_me_a_story_server/src/mail/mailer.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/invite_fixtures.dart';
import 'support/mail_fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

/// Holds a write open in its own transaction until [release] runs, so a test
/// can make an endpoint call collide with it (constraint races).
Future<void Function()> holdOpen(
  Session s,
  Future<void> Function(Transaction t) write,
) async {
  final written = Completer<void>();
  final release = Completer<void>();
  unawaited(
    s.db.transaction((t) async {
      await write(t);
      written.complete();
      await release.future;
    }),
  );
  await written.future;
  return release.complete;
}

/// Long enough for an endpoint call to reach the statement that blocks on a
/// [holdOpen] row.
const raceDelay = Duration(milliseconds: 300);

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given InviteEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    late RecordingMailTransport mail;

    setUp(() {
      fx = Fx(sessionBuilder.build());
      mailTransportOverride = mail = RecordingMailTransport();
    });
    tearDown(() => mailTransportOverride = null);

    /// A family in a new tree with [user] joined as [role].
    Future<Family> familyOf(
      UuidValue user, {
      MembershipRole role = MembershipRole.member,
      DateTime? deletedAt,
      String name = 'Mortang',
    }) async {
      final family = await fx.family(
        await fx.tree(),
        deletedAt: deletedAt,
        name: name,
      );
      await fx.join(family, user, role);
      return family;
    }
    group('create', () {
      // BR 117
      test(
        'when a live member creates an invite without a person then a '
        'token, expiresAt (+7d) and invite_url come back',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final before = DateTime.now().toUtc();

          final created = await endpoints.invite.create(
            asUser(sessionBuilder, member),
            family.id!,
            email: '  Kim@Example.COM ',
          );

          expect(created.token, matches(RegExp(r'^[0-9a-f]{64}$')));
          expect(
            created.inviteUrl,
            'http://127.0.0.1:3000/timeline?invite=${created.token}',
          );
          expect(
            created.expiresAt
                .difference(before.add(inviteLifetime))
                .inSeconds
                .abs(),
            lessThan(5),
          );
          final row = (await Invite.db.findById(fx.s, created.inviteId))!;
          expect(row.tokenHash, hashInviteToken(created.token));
          expect(row.email, 'kim@example.com');
          expect(row.invitedById, member);
          expect(row.treeId, family.treeId);
          expect(row.personId, isNull);
          expect(row.lastSentAt, isNotNull);
          expect(mail.sent, isEmpty);
        },
      );

      // BR 117
      test('when the email is blank then the invite is link-only', () async {
        final member = await fx.user();
        final family = await familyOf(member);

        final created = await endpoints.invite.create(
          asUser(sessionBuilder, member),
          family.id!,
          email: '   ',
        );

        expect((await Invite.db.findById(fx.s, created.inviteId))!.email, null);
      });

      // BR 117
      test(
        'when a non-member creates then FORBIDDEN "Not a family member"',
        () async {
          final family = await fx.family(await fx.tree());
          await expectLater(
            endpoints.invite.create(
              asUser(sessionBuilder, await fx.user()),
              family.id!,
            ),
            throwsAppError(AppErrorCode.forbidden, 'Not a family member'),
          );
          expect(await fx.inviteCount(family), 0);
        },
      );

      // BR 117
      test(
        'when a member of a soft-deleted family creates then FORBIDDEN',
        () async {
          final member = await fx.user();
          final family = await familyOf(
            member,
            role: MembershipRole.owner,
            deletedAt: DateTime.now().toUtc(),
          );
          await expectLater(
            endpoints.invite.create(asUser(sessionBuilder, member), family.id!),
            throwsAppError(AppErrorCode.forbidden, 'Not a family member'),
          );
          expect(await fx.inviteCount(family), 0);
        },
      );

      // BR 118
      test(
        'when the person is unknown or in another tree then the same '
        'NOT_FOUND',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final elsewhere = await fx.person(
            await fx.family(await fx.tree()),
          );

          for (final personId in [
            UuidValue.fromString('00000000-0000-4000-8000-000000000000'),
            elsewhere.id!,
          ]) {
            await expectLater(
              endpoints.invite.create(
                asUser(sessionBuilder, member),
                family.id!,
                personId: personId,
              ),
              throwsAppError(AppErrorCode.notFound, 'person not found'),
            );
          }
          expect(await fx.inviteCount(family), 0);
        },
      );

      // BR 118
      test(
        'when the person is linked or passed then VALIDATION; an unlinked '
        'living tree person is OK',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final linked = await fx.person(family, userId: await fx.user());
          final passed = await fx.person(family, passedAway: true);
          final branch = await fx.family(
            Tree(id: family.treeId),
            parentId: family.id,
            branchYear: 1990,
          );
          final unlinked = await fx.person(branch);
          final session = asUser(sessionBuilder, member);

          await expectLater(
            endpoints.invite.create(
              session,
              family.id!,
              personId: linked.id,
            ),
            throwsAppError(AppErrorCode.validation, 'person is already linked'),
          );
          await expectLater(
            endpoints.invite.create(
              session,
              family.id!,
              personId: passed.id,
            ),
            throwsAppError(AppErrorCode.validation, 'person has passed'),
          );
          final created = await endpoints.invite.create(
            session,
            family.id!,
            personId: unlinked.id,
          );
          final row = (await Invite.db.findById(fx.s, created.inviteId))!;
          expect(row.personId, unlinked.id);
        },
      );

      // BR 119
      test(
        'when the insert fails then VALIDATION "Could not create invite" '
        'with no raw database text',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final person = await fx.person(family);
          // The person passes the checks, then its delete commits while the
          // invite insert waits on the FK.
          final release = await holdOpen(
            fx.s,
            (t) => Person.db.deleteRow(fx.s, person, transaction: t),
          );
          final creating = expectLater(
            endpoints.invite.create(
              asUser(sessionBuilder, member),
              family.id!,
              personId: person.id,
            ),
            throwsAppError(AppErrorCode.validation, 'Could not create invite'),
          );
          await Future<void>.delayed(raceDelay);
          release();
          await creating;
          expect(await fx.inviteCount(family), 0);
        },
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
