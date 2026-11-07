import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/invites/invites.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/invite_fixtures.dart';
import 'support/mail_fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given InvitePublicEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    setUp(() => fx = Fx(sessionBuilder.build()));

    final hidden = isA<InvitePreviewDto>()
        .having((p) => p.valid, 'valid', isFalse)
        .having((p) => p.familyId, 'familyId', isNull)
        .having((p) => p.familyName, 'familyName', isNull)
        .having((p) => p.inviterName, 'inviterName', isNull);

    // BR 121
    test(
      'when a signed-out caller previews a live invite then it is valid with '
      'the family and the trimmed inviter name',
      () async {
        final family = await fx.family(await fx.tree(), name: 'Mortang');
        final inviter = await fx.userWithEmail(
          uniqueEmail('inviter'),
          displayName: ' Ana ',
        );
        final (invite: _, :token) = await fx.tokenInvite(
          family,
          invitedById: inviter,
        );

        final preview = await endpoints.invitePublic.preview(
          sessionBuilder,
          token,
        );

        expect(preview.valid, isTrue);
        expect(preview.familyId, family.id);
        expect(preview.familyName, 'Mortang');
        expect(preview.inviterName, 'Ana');
      },
    );

    // BR 121
    test(
      'when the inviter has no display name or is gone then inviterName is '
      'null',
      () async {
        final family = await fx.family(await fx.tree());
        final blank = await fx.userWithEmail(
          uniqueEmail('blank'),
          displayName: '  ',
        );
        final withBlank = await fx.tokenInvite(family, invitedById: blank);
        final withNone = await fx.tokenInvite(family);

        for (final token in [withBlank.token, withNone.token]) {
          final preview = await endpoints.invitePublic.preview(
            sessionBuilder,
            token,
          );
          expect(preview.valid, isTrue);
          expect(preview.inviterName, isNull);
        }
      },
    );

    // BR 121
    test(
      'when the token is unknown or blank, the family is soft-deleted, or '
      'the invite is accepted, revoked or expired then it is invalid and '
      'hides the family and inviter',
      () async {
        final inviter = await fx.userWithEmail(
          uniqueEmail('inviter'),
          displayName: 'Ana',
        );
        final live = await fx.family(await fx.tree());
        final deleted = await fx.family(
          await fx.tree(),
          deletedAt: DateTime.now().toUtc(),
        );
        final tokens = [
          newInviteToken(),
          '  ',
          (await fx.tokenInvite(deleted, invitedById: inviter)).token,
          (await fx.tokenInvite(
            live,
            invitedById: inviter,
            acceptedById: await fx.user(),
          )).token,
          (await fx.tokenInvite(
            live,
            invitedById: inviter,
            revoked: true,
          )).token,
          (await fx.tokenInvite(
            live,
            invitedById: inviter,
            expired: true,
          )).token,
        ];

        for (final token in tokens) {
          expect(
            await endpoints.invitePublic.preview(sessionBuilder, token),
            hidden,
          );
        }
      },
    );

    test(
      'when a signed-in caller previews then the same answer comes back',
      () async {
        final family = await fx.family(await fx.tree());
        final (invite: _, :token) = await fx.tokenInvite(family);
        final preview = await endpoints.invitePublic.preview(
          asUser(sessionBuilder, await fx.user()),
          token,
        );
        expect(preview.valid, isTrue);
        expect(preview.familyId, family.id);
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
