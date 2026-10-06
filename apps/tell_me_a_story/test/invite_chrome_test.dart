import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/config/env.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/features/invites/invite_modal.dart';
import 'package:tell_me_a_story/features/timeline/timeline_page.dart';

class _StubInviteApi implements InviteGateway {
  int creates = 0;
  final emails = <String>[];
  String? lastEmail;
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
    creates += 1;
    lastEmail = email;
    return CreateInviteResult(
      inviteId: 'i',
      token: 't',
      expiresAt: '2099-01-01T00:00:00Z',
      inviteUrl: 'http://127.0.0.1:3000/timeline?invite=t$creates',
    );
  }

  @override
  Future<String?> currentFamilyId() async => 'family-1';

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {
    emails.add(inviteId);
  }
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('INVITE_APP_ORIGIN defaults to local web port', () {
    expect(Env.inviteAppOrigin, 'http://127.0.0.1:3000');
  });

  testWidgets('timeline header shows Invite and New story', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TimelinePage(api: _StubInviteApi())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('New story'), findsOneWidget);
    expect(find.text('Timeline'), findsWidgets);
    expect(find.text('Save draft'), findsNothing);
    expect(find.text('Publish'), findsNothing);
  });

  testWidgets('invite email screen sends the address and closes', (
    tester,
  ) async {
    final api = _StubInviteApi();
    await _open(tester, api);
    expect(find.text('Invite to the family archive'), findsOneWidget);
    expect(find.text('Any member can invite'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Text (SMS)'), findsOneWidget);
    expect(find.text('Link'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Send invite'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('invite-email')), 'a@b.co');
    await tester.tap(find.byKey(const Key('invite-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.lastEmail, 'a@b.co');
    expect(api.emails, ['i']);
    expect(find.byType(InviteModal), findsNothing);
  });

  testWidgets('text invite is a placeholder and does not create an invite', (
    tester,
  ) async {
    final api = _StubInviteApi();
    await _open(tester, api);
    await tester.tap(find.byKey(const Key('invite-tab-sms')));
    await tester.pump();
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('Send text invite'), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-sms-send')));
    await tester.pump();
    expect(api.creates, 0);
    expect(find.text('Text invites are not available yet.'), findsOneWidget);
    expect(find.byType(InviteModal), findsOneWidget);
  });

  testWidgets('link screen copies the url and can generate another', (
    tester,
  ) async {
    final api = _StubInviteApi();
    await _open(tester, api);
    await tester.tap(find.byKey(const Key('invite-tab-link')));
    await tester.pump();
    expect(find.text('Shareable invite link'), findsOneWidget);
    expect(find.textContaining('invite=t'), findsOneWidget);
    expect(
      find.text('Link expires in 7 days · Anyone can request to join'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Anyone with the link can request to join; a verified family member still confirms.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('invite-copy')));
    await tester.pump();
    expect(find.byType(InviteModal), findsOneWidget);

    final before = api.creates;
    await tester.tap(find.byKey(const Key('invite-generate')));
    await tester.pump();
    expect(api.creates, before + 1);

    await tester.ensureVisible(find.byKey(const Key('invite-done')));
    await tester.tap(find.byKey(const Key('invite-done')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(InviteModal), findsNothing);
  });
}

Future<void> _open(WidgetTester tester, _StubInviteApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => InviteModal.show(
              context,
              familyId: '00000000-0000-0000-0000-000000000001',
              familyName: 'Ada',
              api: api,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
