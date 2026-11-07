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
    group('accept', () {
      // BR 122
      test(
        'when a pending live invite is accepted then a member row is created '
        'and the invite is marked accepted; another user then gets '
        'INVITE_ACCEPTED; the same user again gets the same family',
        () async {
          final family = await fx.family(await fx.tree());
          final (:invite, :token) = await fx.tokenInvite(family);
          final joiner = await fx.user();

          final joined = await endpoints.invite.accept(
            asUser(sessionBuilder, joiner),
            token,
          );

          expect(joined, family.id);
          final membership = (await fx.membershipOf(family, joiner))!;
          expect(membership.role, MembershipRole.member);
          final row = await fx.reload(invite);
          expect(row.acceptedById, joiner);
          expect(row.acceptedAt, isNotNull);

          await expectLater(
            endpoints.invite.accept(
              asUser(sessionBuilder, await fx.user()),
              token,
            ),
            throwsAppError(AppErrorCode.inviteAccepted, 'Invite already used'),
          );
          expect(
            await endpoints.invite.accept(
              asUser(sessionBuilder, joiner),
              token,
            ),
            family.id,
          );
          expect((await fx.membershipOf(family, joiner))!.id, membership.id);
        },
      );

      // BR 123
      test(
        'when the owner opens their own family invite then accept succeeds '
        'and the role stays owner',
        () async {
          final owner = await fx.user();
          final family = await familyOf(owner, role: MembershipRole.owner);
          final (:invite, :token) = await fx.tokenInvite(family);

          expect(
            await endpoints.invite.accept(asUser(sessionBuilder, owner), token),
            family.id,
          );
          expect(
            (await fx.membershipOf(family, owner))!.role,
            MembershipRole.owner,
          );
          expect((await fx.reload(invite)).acceptedById, owner);
        },
      );

      // BR 124
      test(
        'when the pending invite is expired then INVITE_EXPIRED; revoked '
        'then INVITE_INVALID',
        () async {
          final family = await fx.family(await fx.tree());
          final expired = await fx.tokenInvite(family, expired: true);
          final revoked = await fx.tokenInvite(family, revoked: true);
          final joiner = await fx.user();

          await expectLater(
            endpoints.invite.accept(
              asUser(sessionBuilder, joiner),
              expired.token,
            ),
            throwsAppError(AppErrorCode.inviteExpired, 'Invite link expired'),
          );
          await expectLater(
            endpoints.invite.accept(
              asUser(sessionBuilder, joiner),
              revoked.token,
            ),
            throwsAppError(AppErrorCode.inviteInvalid, 'Invite is not valid'),
          );
          expect(await fx.membershipOf(family, joiner), isNull);
          expect((await fx.reload(expired.invite)).acceptedAt, isNull);
        },
      );

      test(
        'when the token is unknown then INVITE_INVALID; blank then '
        'VALIDATION "token is required"',
        () async {
          final user = asUser(sessionBuilder, await fx.user());
          await expectLater(
            endpoints.invite.accept(user, newInviteToken()),
            throwsAppError(AppErrorCode.inviteInvalid, 'Invite is not valid'),
          );
          await expectLater(
            endpoints.invite.accept(user, '  '),
            throwsAppError(AppErrorCode.validation, 'token is required'),
          );
        },
      );

      // BR 125
      test(
        'when the caller is signed out then the call is refused and the '
        'invite is not marked accepted',
        () async {
          final family = await fx.family(await fx.tree());
          final (:invite, :token) = await fx.tokenInvite(family);

          await expectLater(
            endpoints.invite.accept(sessionBuilder, token),
            throwsA(isA<ServerpodUnauthenticatedException>()),
          );
          expect((await fx.reload(invite)).acceptedAt, isNull);
        },
      );

      // BR 126
      test(
        'when the accepting user re-enters after their membership is gone '
        'then VALIDATION "Could not check membership"',
        () async {
          final family = await fx.family(await fx.tree());
          final (:invite, :token) = await fx.tokenInvite(family);
          final joiner = await fx.user();
          await endpoints.invite.accept(asUser(sessionBuilder, joiner), token);
          await Membership.db.deleteWhere(
            fx.s,
            where: (t) =>
                t.familyId.equals(family.id!) & t.userId.equals(joiner),
          );

          await expectLater(
            endpoints.invite.accept(asUser(sessionBuilder, joiner), token),
            throwsAppError(
              AppErrorCode.validation,
              'Could not check membership',
            ),
          );
          expect((await fx.reload(invite)).acceptedById, joiner);
        },
      );

      // BR 126
      test(
        'when the membership insert collides then VALIDATION "Could not '
        'create membership" and the invite stays pending',
        () async {
          final family = await fx.family(await fx.tree());
          final (:invite, :token) = await fx.tokenInvite(family);
          final joiner = await fx.user();
          final release = await holdOpen(
            fx.s,
            (t) => Membership.db.insertRow(
              fx.s,
              Membership(familyId: family.id!, userId: joiner),
              transaction: t,
            ),
          );
          final accepting = expectLater(
            endpoints.invite.accept(asUser(sessionBuilder, joiner), token),
            throwsAppError(
              AppErrorCode.validation,
              'Could not create membership',
            ),
          );
          await Future<void>.delayed(raceDelay);
          release();
          await accepting;
          expect((await fx.reload(invite)).acceptedAt, isNull);
        },
      );

      // BR 133
      test(
        'when an invite emailed to a@x.com is accepted by b@x.com then '
        'INVITE_INVALID "Invite was sent to a different email" and no '
        'membership; the " A@X.com " account then succeeds',
        () async {
          final family = await fx.family(await fx.tree());
          final a = uniqueEmail('a');
          final (:invite, :token) = await fx.tokenInvite(family, email: a);
          final b = await fx.userWithEmail(uniqueEmail('b'));

          await expectLater(
            endpoints.invite.accept(asUser(sessionBuilder, b), token),
            throwsAppError(
              AppErrorCode.inviteInvalid,
              'Invite was sent to a different email',
            ),
          );
          expect(await fx.membershipOf(family, b), isNull);
          expect((await fx.reload(invite)).acceptedAt, isNull);

          final noEmail = await fx.user();
          await expectLater(
            endpoints.invite.accept(asUser(sessionBuilder, noEmail), token),
            throwsAppError(
              AppErrorCode.inviteInvalid,
              'Invite was sent to a different email',
            ),
          );

          final owner = await fx.userWithEmail(' ${a.toUpperCase()} ');
          expect(
            await endpoints.invite.accept(asUser(sessionBuilder, owner), token),
            family.id,
          );
          expect(await fx.membershipOf(family, owner), isNotNull);
        },
      );

      // BR 134
      test(
        'when a link-only invite is accepted by any signed-in user then it '
        'succeeds',
        () async {
          final family = await fx.family(await fx.tree());
          final (invite: _, :token) = await fx.tokenInvite(family);
          final anyone = await fx.userWithEmail(uniqueEmail('anyone'));

          expect(
            await endpoints.invite.accept(
              asUser(sessionBuilder, anyone),
              token,
            ),
            family.id,
          );
          expect(await fx.membershipOf(family, anyone), isNotNull);
        },
      );

      // BR 135
      test(
        'when an invite to a soft-deleted family is accepted then '
        'INVITE_INVALID and no membership',
        () async {
          final family = await fx.family(
            await fx.tree(),
            deletedAt: DateTime.now().toUtc(),
          );
          final email = uniqueEmail('deleted');
          final (:invite, :token) = await fx.tokenInvite(family, email: email);
          final joiner = await fx.userWithEmail(email);

          await expectLater(
            endpoints.invite.accept(asUser(sessionBuilder, joiner), token),
            throwsAppError(AppErrorCode.inviteInvalid, 'Invite is not valid'),
          );
          expect(await fx.membershipOf(family, joiner), isNull);
          expect((await fx.reload(invite)).acceptedAt, isNull);
        },
      );

      // BR 135 (D6a, D2 order)
      test(
        'when the family is deleted and the email differs then the family '
        'check wins; both run before the accepted check',
        () async {
          final family = await fx.family(await fx.tree());
          final email = uniqueEmail('first');
          final (invite: _, :token) = await fx.tokenInvite(
            family,
            email: email,
            acceptedById: await fx.userWithEmail(email),
          );
          final other = await fx.userWithEmail(uniqueEmail('other'));

          await expectLater(
            endpoints.invite.accept(asUser(sessionBuilder, other), token),
            throwsAppError(
              AppErrorCode.inviteInvalid,
              'Invite was sent to a different email',
            ),
          );
          await Family.db.updateRow(
            fx.s,
            family.copyWith(deletedAt: DateTime.now().toUtc()),
          );
          await expectLater(
            endpoints.invite.accept(asUser(sessionBuilder, other), token),
            throwsAppError(AppErrorCode.inviteInvalid, 'Invite is not valid'),
          );
        },
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
