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

    group('accept: person rows', () {
      // BR 112
      test(
        'when the invite person is already linked to someone then no '
        'duplicate row is made and accept succeeds',
        () async {
          final family = await fx.family(await fx.tree());
          final other = await fx.user();
          final person = await fx.person(family, userId: other, name: 'Ada');
          final (invite: _, :token) = await fx.tokenInvite(
            family,
            personId: person.id,
          );
          final joiner = await fx.user();

          expect(
            await endpoints.invite.accept(
              asUser(sessionBuilder, joiner),
              token,
            ),
            family.id,
          );

          final reread = (await Person.db.findById(fx.s, person.id!))!;
          expect(reread.userId, other);
          expect(reread.name, 'Ada');
          expect(await fx.linkedPeople(family.treeId, other), hasLength(1));
          expect(await fx.linkedPeople(family.treeId, joiner), hasLength(1));
        },
      );

      // BR 113
      test(
        'when the invite person is unlinked then it is linked to the '
        'acceptor and takes their display name',
        () async {
          final family = await fx.family(await fx.tree());
          final person = await fx.person(family, name: 'Ada', passedAway: true);
          final (invite: _, :token) = await fx.tokenInvite(
            family,
            personId: person.id,
          );
          final joiner = await fx.userWithEmail(
            uniqueEmail('kim'),
            displayName: ' Kim ',
          );

          await endpoints.invite.accept(asUser(sessionBuilder, joiner), token);

          final reread = (await Person.db.findById(fx.s, person.id!))!;
          expect(reread.userId, joiner);
          expect(reread.name, 'Kim');
          expect(await fx.linkedPeople(family.treeId, joiner), hasLength(1));
        },
      );

      // BR 113
      test(
        'when the acceptor has no display name then the linked person keeps '
        'its name',
        () async {
          final family = await fx.family(await fx.tree());
          final person = await fx.person(family, name: 'Ada');
          final (invite: _, :token) = await fx.tokenInvite(
            family,
            personId: person.id,
          );
          final joiner = await fx.userWithEmail(
            uniqueEmail('blank'),
            displayName: '   ',
          );

          await endpoints.invite.accept(asUser(sessionBuilder, joiner), token);

          final reread = (await Person.db.findById(fx.s, person.id!))!;
          expect(reread.userId, joiner);
          expect(reread.name, 'Ada');
        },
      );

      // BR 113
      test(
        'when the acceptor is already linked in the tree then the invite '
        'person stays unlinked',
        () async {
          final tree = await fx.tree();
          final family = await fx.family(tree);
          final joiner = await fx.user();
          final own = await fx.person(family, userId: joiner, name: 'Me');
          final person = await fx.person(family, name: 'Ada');
          final (invite: _, :token) = await fx.tokenInvite(
            family,
            personId: person.id,
          );

          await endpoints.invite.accept(asUser(sessionBuilder, joiner), token);

          expect((await Person.db.findById(fx.s, person.id!))!.userId, isNull);
          expect(
            (await fx.linkedPeople(tree.id!, joiner)).single.id,
            own.id,
          );
        },
      );

      // BR 114
      test(
        'when the invite has no person then exactly one linked row is '
        'created for the acceptor',
        () async {
          final family = await fx.family(await fx.tree());
          final (invite: _, :token) = await fx.tokenInvite(family);
          final joiner = await fx.userWithEmail(
            uniqueEmail('lee'),
            displayName: 'Lee',
          );

          await endpoints.invite.accept(asUser(sessionBuilder, joiner), token);
          await endpoints.invite.accept(asUser(sessionBuilder, joiner), token);

          final linked = await fx.linkedPeople(family.treeId, joiner);
          expect(linked, hasLength(1));
          expect(linked.single.name, 'Lee');
          expect(linked.single.homeFamilyId, family.id);
        },
      );

      // BR 114
      test(
        'when the acceptor is already linked elsewhere in the tree then no '
        'row is added',
        () async {
          final tree = await fx.tree();
          final parent = await fx.family(tree);
          final branch = await fx.family(
            tree,
            parentId: parent.id,
            branchYear: 1990,
          );
          final joiner = await fx.user();
          final own = await fx.person(parent, userId: joiner);
          final (invite: _, :token) = await fx.tokenInvite(branch);

          await endpoints.invite.accept(asUser(sessionBuilder, joiner), token);

          expect((await fx.linkedPeople(tree.id!, joiner)).single.id, own.id);
        },
      );

      test(
        'when a linked person for the acceptor commits mid-accept then the '
        'accept reruns once and reuses it',
        () async {
          final tree = await fx.tree();
          final family = await fx.family(tree);
          final (:invite, :token) = await fx.tokenInvite(family);
          final joiner = await fx.user();
          final release = await holdOpen(
            fx.s,
            (t) => Person.db.insertRow(
              fx.s,
              Person(
                treeId: tree.id!,
                homeFamilyId: family.id!,
                userId: joiner,
                name: 'Racer',
              ),
              transaction: t,
            ),
          );
          final accepting = endpoints.invite.accept(
            asUser(sessionBuilder, joiner),
            token,
          );
          await Future<void>.delayed(raceDelay);
          release();

          expect(await accepting, family.id);
          expect(
            (await fx.linkedPeople(tree.id!, joiner)).single.name,
            'Racer',
          );
          expect((await fx.reload(invite)).acceptedById, joiner);
          expect(await fx.membershipOf(family, joiner), isNotNull);
        },
      );
    });

    group('sendEmail', () {
      test(
        'when a member sends a pending emailed invite then the invite email '
        'goes out with the accept link',
        () async {
          final member = await fx.user();
          final family = await familyOf(member, name: 'Mortang');
          final created = await endpoints.invite.create(
            asUser(sessionBuilder, member),
            family.id!,
            email: 'Kim@Example.com',
          );

          await endpoints.invite.sendEmail(
            asUser(sessionBuilder, member),
            created.inviteId,
            created.token,
          );

          final sent = mail.sent.single;
          expect(sent.to, 'kim@example.com');
          expect(sent.subject, 'Invite to Mortang');
          expect(
            sent.text,
            "You're invited to join Mortang on Tell Me a Story.\n\n"
            'Accept the invite: ${created.inviteUrl}\n\n'
            'This link expires in 7 days and can only be used once.',
          );
          expect(sent.html, contains('<strong>Mortang</strong>'));
        },
      );

      test(
        'when the invite is unknown then NOT_FOUND "Invite not found"; a '
        'non-member gets FORBIDDEN "Not a family member"',
        () async {
          final family = await fx.family(await fx.tree());
          final (:invite, :token) = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
          );
          final stranger = asUser(sessionBuilder, await fx.user());

          await expectLater(
            endpoints.invite.sendEmail(
              stranger,
              UuidValue.fromString('00000000-0000-4000-8000-000000000000'),
              token,
            ),
            throwsAppError(AppErrorCode.notFound, 'Invite not found'),
          );
          await expectLater(
            endpoints.invite.sendEmail(stranger, invite.id!, token),
            throwsAppError(AppErrorCode.forbidden, 'Not a family member'),
          );
          expect(mail.sent, isEmpty);
        },
      );

      test(
        'when the token is not the invite token then INVITE_INVALID and no '
        'mail',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final (invite: invite, token: _) = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
          );

          await expectLater(
            endpoints.invite.sendEmail(
              asUser(sessionBuilder, member),
              invite.id!,
              newInviteToken(),
            ),
            throwsAppError(AppErrorCode.inviteInvalid, 'Invite is not valid'),
          );
          expect(mail.sent, isEmpty);
        },
      );

      // BR 131
      test(
        'when the invite is not pending, expired or has no email then '
        'INVITE_INVALID / INVITE_EXPIRED / VALIDATION',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final session = asUser(sessionBuilder, member);
          final accepted = await fx.tokenInvite(
            family,
            acceptedById: await fx.user(),
          );
          final revoked = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
            revoked: true,
          );
          final expired = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
            expired: true,
          );
          final linkOnly = await fx.tokenInvite(family);

          for (final notPending in [accepted, revoked]) {
            await expectLater(
              endpoints.invite.sendEmail(
                session,
                notPending.invite.id!,
                notPending.token,
              ),
              throwsAppError(
                AppErrorCode.inviteInvalid,
                'Invite is not pending',
              ),
            );
          }
          await expectLater(
            endpoints.invite.sendEmail(
              session,
              expired.invite.id!,
              expired.token,
            ),
            throwsAppError(AppErrorCode.inviteExpired, 'Invite link expired'),
          );
          await expectLater(
            endpoints.invite.sendEmail(
              session,
              linkOnly.invite.id!,
              linkOnly.token,
            ),
            throwsAppError(
              AppErrorCode.validation,
              'Invite has no email address to send to',
            ),
          );
          expect(mail.sent, isEmpty);
        },
      );

      test(
        'when email is not configured then VALIDATION "Email is not '
        'configured"; when the provider fails then VALIDATION "Could not '
        'send invite email"',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final (:invite, :token) = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
          );
          final session = asUser(sessionBuilder, member);

          mailTransportOverride = RecordingMailTransport(configured: false);
          await expectLater(
            endpoints.invite.sendEmail(session, invite.id!, token),
            throwsAppError(AppErrorCode.validation, 'Email is not configured'),
          );
          mailTransportOverride = RecordingMailTransport(fails: true);
          await expectLater(
            endpoints.invite.sendEmail(session, invite.id!, token),
            throwsAppError(
              AppErrorCode.validation,
              'Could not send invite email',
            ),
          );
        },
      );
    });

    group('resend', () {
      // BR 127
      test(
        'when a plain member resends then FORBIDDEN "owner or co-owner only"',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final (:invite, token: _) = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
          );

          await expectLater(
            endpoints.invite.resend(asUser(sessionBuilder, member), invite.id!),
            throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
          );
          expect((await fx.reload(invite)).tokenHash, invite.tokenHash);
          expect(mail.sent, isEmpty);
        },
      );

      test(
        'when the invite is unknown then NOT_FOUND "invite not found"',
        () async {
          await expectLater(
            endpoints.invite.resend(
              asUser(sessionBuilder, await fx.user()),
              UuidValue.fromString('00000000-0000-4000-8000-000000000000'),
            ),
            throwsAppError(AppErrorCode.notFound, 'invite not found'),
          );
        },
      );

      // BR 128
      test(
        'when the invite is accepted or revoked then INVITE_INVALID "invite '
        'is not pending"; link-only then VALIDATION "invite has no email '
        'address"',
        () async {
          final owner = await fx.user();
          final family = await familyOf(owner, role: MembershipRole.owner);
          final session = asUser(sessionBuilder, owner);
          final accepted = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
            acceptedById: await fx.user(),
          );
          final revoked = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
            revoked: true,
          );
          final linkOnly = await fx.tokenInvite(family);

          for (final notPending in [accepted.invite, revoked.invite]) {
            await expectLater(
              endpoints.invite.resend(session, notPending.id!),
              throwsAppError(
                AppErrorCode.inviteInvalid,
                'invite is not pending',
              ),
            );
          }
          await expectLater(
            endpoints.invite.resend(session, linkOnly.invite.id!),
            throwsAppError(
              AppErrorCode.validation,
              'invite has no email address',
            ),
          );
          expect(mail.sent, isEmpty);
        },
      );

      // BR 129
      test(
        'when a co-owner resends an expired pending invite then the token '
        'rotates, expiresAt moves to now+7d, it stays pending and the email '
        'carries the new link',
        () async {
          final coOwner = await fx.user();
          final family = await familyOf(
            coOwner,
            role: MembershipRole.coOwner,
            name: 'Mortang',
          );
          final (:invite, :token) = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
            expired: true,
          );
          final before = DateTime.now().toUtc();

          final expiresAt = await endpoints.invite.resend(
            asUser(sessionBuilder, coOwner),
            invite.id!,
          );

          final row = await fx.reload(invite);
          expect(row.tokenHash, isNot(invite.tokenHash));
          expect(row.expiresAt, expiresAt);
          expect(
            expiresAt.difference(before.add(inviteLifetime)).inSeconds.abs(),
            lessThan(5),
          );
          expect(row.lastSentAt.isAfter(invite.lastSentAt), isTrue);
          expect(row.acceptedAt, isNull);
          expect(row.revokedAt, isNull);

          final sent = mail.sent.single;
          expect(sent.to, 'kim@example.com');
          expect(sent.subject, 'Invite to Mortang');
          final newToken = RegExp(
            r'invite=([0-9a-f]{64})',
          ).firstMatch(sent.text)!.group(1)!;
          expect(hashInviteToken(newToken), row.tokenHash);
          expect(newToken, isNot(token));
        },
      );

      // BR 129
      test(
        'when email is not configured then VALIDATION "Email is not '
        'configured" before the token rotates',
        () async {
          final owner = await fx.user();
          final family = await familyOf(owner, role: MembershipRole.owner);
          final (:invite, token: _) = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
          );
          mailTransportOverride = RecordingMailTransport(configured: false);

          await expectLater(
            endpoints.invite.resend(asUser(sessionBuilder, owner), invite.id!),
            throwsAppError(AppErrorCode.validation, 'Email is not configured'),
          );
          expect((await fx.reload(invite)).tokenHash, invite.tokenHash);
        },
      );

      // BR 129
      test(
        'when the provider fails then VALIDATION "Could not send invite '
        'email" and the token stays rotated',
        () async {
          final owner = await fx.user();
          final family = await familyOf(owner, role: MembershipRole.owner);
          final (:invite, token: _) = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
          );
          mailTransportOverride = RecordingMailTransport(fails: true);

          await expectLater(
            endpoints.invite.resend(asUser(sessionBuilder, owner), invite.id!),
            throwsAppError(
              AppErrorCode.validation,
              'Could not send invite email',
            ),
          );
          expect((await fx.reload(invite)).tokenHash, isNot(invite.tokenHash));
        },
      );
    });

    group('revoke', () {
      // BR 127
      test(
        'when a plain member revokes then FORBIDDEN "owner or co-owner only"',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final (:invite, token: _) = await fx.tokenInvite(family);

          await expectLater(
            endpoints.invite.revoke(asUser(sessionBuilder, member), invite.id!),
            throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
          );
          expect((await fx.reload(invite)).revokedAt, isNull);
        },
      );

      test(
        'when the invite is unknown then NOT_FOUND "invite not found"',
        () async {
          await expectLater(
            endpoints.invite.revoke(
              asUser(sessionBuilder, await fx.user()),
              UuidValue.fromString('00000000-0000-4000-8000-000000000000'),
            ),
            throwsAppError(AppErrorCode.notFound, 'invite not found'),
          );
        },
      );

      // BR 130
      test(
        'when an owner revokes then the row is kept as revoked and accepting '
        'its token fails; revoking twice is a no-op; revoking an accepted '
        'invite is INVITE_INVALID',
        () async {
          final owner = await fx.user();
          final family = await familyOf(owner, role: MembershipRole.owner);
          final session = asUser(sessionBuilder, owner);
          final (:invite, :token) = await fx.tokenInvite(family);

          await endpoints.invite.revoke(session, invite.id!);
          final revoked = await fx.reload(invite);
          expect(revoked.revokedAt, isNotNull);
          expect(revoked.tokenHash, invite.tokenHash);
          await expectLater(
            endpoints.invite.accept(
              asUser(sessionBuilder, await fx.user()),
              token,
            ),
            throwsAppError(AppErrorCode.inviteInvalid, 'Invite is not valid'),
          );

          await endpoints.invite.revoke(session, invite.id!);
          expect((await fx.reload(invite)).revokedAt, revoked.revokedAt);

          final accepted = await fx.tokenInvite(
            family,
            acceptedById: await fx.user(),
          );
          await expectLater(
            endpoints.invite.revoke(session, accepted.invite.id!),
            throwsAppError(AppErrorCode.inviteInvalid, 'invite is not pending'),
          );
          expect((await fx.reload(accepted.invite)).revokedAt, isNull);
        },
      );

      // BR 137 (invite part)
      test(
        'Given a soft-deleted family, when its member sends or its owner '
        'resends or revokes one of its invites then FORBIDDEN and nothing '
        'changes',
        () async {
          final owner = await fx.user();
          final family = await familyOf(
            owner,
            role: MembershipRole.owner,
            deletedAt: DateTime.now().toUtc(),
          );
          final (:invite, :token) = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
          );
          final session = asUser(sessionBuilder, owner);

          await expectLater(
            endpoints.invite.sendEmail(session, invite.id!, token),
            throwsAppError(AppErrorCode.forbidden, 'Not a family member'),
          );
          await expectLater(
            endpoints.invite.resend(session, invite.id!),
            throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
          );
          await expectLater(
            endpoints.invite.revoke(session, invite.id!),
            throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
          );
          final row = await fx.reload(invite);
          expect(row.tokenHash, invite.tokenHash);
          expect(row.revokedAt, isNull);
          expect(mail.sent, isEmpty);
        },
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
