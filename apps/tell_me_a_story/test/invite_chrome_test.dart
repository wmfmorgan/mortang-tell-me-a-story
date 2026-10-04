import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/config/env.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/features/invites/invite_modal.dart';
import 'package:tell_me_a_story/features/timeline/timeline_page.dart';

class _StubInviteApi implements InviteGateway {
  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    return const AcceptInviteResult(familyId: 'f', membershipId: 'm');
  }

  @override
  Future<String> createFamily(String name) async => 'family-1';

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
  }) async {
    return const CreateInviteResult(
      inviteId: 'i',
      token: 't',
      expiresAt: '2099-01-01T00:00:00Z',
      inviteUrl: 'http://127.0.0.1:3000/timeline?invite=t',
    );
  }

  @override
  Future<String?> currentFamilyId() async => 'family-1';

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {}
}

void main() {
  test('INVITE_APP_ORIGIN defaults to local web port', () {
    expect(Env.inviteAppOrigin, 'http://127.0.0.1:3000');
  });

  testWidgets('timeline far header shows Save draft and Publish', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: TimelinePage(api: _StubInviteApi())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Save draft'), findsOneWidget);
    expect(find.text('Publish'), findsOneWidget);
    expect(find.text('Timeline'), findsWidgets);
  });

  testWidgets('invite modal has Email and Link tabs only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InviteModal(
            familyId: '00000000-0000-0000-0000-000000000001',
            api: _StubInviteApi(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsWidgets);
    expect(find.text('Link'), findsOneWidget);
    expect(find.text('SMS'), findsNothing);
  });
}
