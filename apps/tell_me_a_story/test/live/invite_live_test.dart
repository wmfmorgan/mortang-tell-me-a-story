@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/manage_families_api.dart';

import 'support/live_server.dart';

Matcher _code(AppErrorCode code) =>
    throwsA(isA<AppException>().having((e) => e.code, 'code', code));

void main() {
  setUpAll(waitForLiveServer);
  tearDown(FamilySelection.clear);

  test('create → send → preview → accept → resend → revoke', () async {
    final ownerClient = await signInLive(freshEmail('inv-owner'));
    final ownerInvites = InviteApi(client: ownerClient);
    final familyId = await ownerInvites.createFamily('Hendersons');
    final joinerEmail = freshEmail('inv-joiner');

    final created = await ownerInvites.createInvite(
      familyId: familyId,
      email: ' $joinerEmail ',
    );
    expect(created.token, isNotEmpty);
    expect(created.inviteUrl, contains(Uri.encodeComponent(created.token)));
    expect(created.expiresAt.isAfter(DateTime.now()), isTrue);
    await ownerInvites.sendInviteEmail(
      inviteId: created.inviteId,
      token: created.token,
    );
    await expectLater(
      ownerInvites.sendInviteEmail(inviteId: created.inviteId, token: 'nope'),
      _code(AppErrorCode.inviteInvalid),
    );

    final preview = await InviteLinkApi(client: ownerClient)
        .validateInviteToken(created.token);
    expect(preview.valid, isTrue);
    expect(preview.familyId, familyId);
    expect(preview.familyName, 'Hendersons');
    expect(
      (await InviteLinkApi(client: ownerClient)
              .validateInviteToken('not-a-token'))
          .valid,
      isFalse,
    );

    final joinerClient = await signInLive(joinerEmail);
    final accepted = await InviteApi(client: joinerClient)
        .acceptInvite(token: created.token);
    expect(accepted.familyId, familyId);
    expect(await InviteApi(client: joinerClient).currentFamilyId(), familyId);
    final joined = await FamiliesApi(client: joinerClient).listMine();
    expect(joined.single.role, 'member');

    final manage = ManageFamiliesApi(client: ownerClient);
    final pending = await ownerInvites.createInvite(
      familyId: familyId,
      email: freshEmail('inv-pending'),
    );
    final resent = await manage.resendInvite(pending.inviteId);
    expect(resent.isAfter(DateTime.now()), isTrue);
    expect(
      (await InviteLinkApi(client: ownerClient)
              .validateInviteToken(pending.token))
          .valid,
      isFalse,
      reason: 'resend rotates the token',
    );

    await manage.revokeInvite(pending.inviteId);
    final detail = await FamiliesApi(client: ownerClient).loadDetail(familyId);
    expect(detail!.pendingInvites, isEmpty);
  });

  test('accept refuses a different email (D2)', () async {
    final ownerClient = await signInLive(freshEmail('d2-owner'));
    final invites = InviteApi(client: ownerClient);
    final familyId = await invites.createFamily('Bound');
    final created = await invites.createInvite(
      familyId: familyId,
      email: freshEmail('d2-invited'),
    );
    final other = await signInLive(freshEmail('d2-other'));
    await expectLater(
      InviteApi(client: other).acceptInvite(token: created.token),
      _code(AppErrorCode.inviteInvalid),
    );
  });

  test('currentFamilyId: remembered family, else first, else null', () async {
    final client = await signInLive(freshEmail('current'));
    final invites = InviteApi(client: client);
    expect(await invites.currentFamilyId(), isNull);
    final first = await invites.createFamily('First');
    final second = await invites.createFamily('Second');
    expect(await invites.currentFamilyId(), first);
    FamilySelection.remember(second);
    expect(await invites.currentFamilyId(), second);
    FamilySelection.remember('00000000-0000-4000-8000-000000000000');
    expect(await invites.currentFamilyId(), first);
  });
}
