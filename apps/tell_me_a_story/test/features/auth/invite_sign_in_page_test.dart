import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    show EmailAccountRequestException, EmailAccountRequestExceptionReason;
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/data/auth_refresh.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/features/auth/invite_sign_in_page.dart';
import 'package:tell_me_a_story/data/otp_sign_in.dart';

import '../../support/fakes/fake_invite_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('invite page live, dead, null inviter, and signed-in accept', (
    tester,
  ) async {
    final auth = AuthRefresh(initiallySignedIn: false);
    addTearDown(auth.dispose);
    final otp = _Otp()..onSignIn = () => auth.setSignedIn(true);
    final invites = _Invites();
    final router = GoRouter(
      initialLocation: '/invite/tok',
      routes: [
        GoRoute(
          path: '/invite/:token',
          builder: (context, state) => InviteSignInPage(
            token: state.pathParameters['token']!,
            previewApi: _Preview(
              const InvitePreview(
                valid: true,
                familyId: 'fam',
                familyName: 'Ada',
                inviterName: 'Bea',
              ),
            ),
            inviteApi: invites,
            otpSignIn: otp,
            authRefresh: auth,
            signedIn: () => auth.isSignedIn,
          ),
        ),
        GoRoute(
          path: AppRoutes.familyLanding,
          builder: (context, state) => const Text('landing-home'),
        ),
        GoRoute(
          path: AppRoutes.timeline,
          builder: (context, state) => const Text('timeline-home'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('YOU’RE INVITED'), findsOneWidget);
    expect(find.text('Join Ada'), findsOneWidget);
    expect(
      find.text(
        'Ada keeps its stories on Tell Me a Story. Sign in with your email to read them and add your own.',
      ),
      findsOneWidget,
    );
    expect(find.text('Bea invited you to Ada.'), findsOneWidget);
    expect(
      find.text("We'll email you a 6-digit code. No password needed."),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('invite-email')), 'a@b.co');
    await _tapText(tester, 'Email me a sign-in code');
    expect(
      find.text('We sent a code to a@b.co. Enter it to join Ada.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('invite-sent')), findsOneWidget);
    expect(otp.sent, ['a@b.co']);

    otp.signInError = EmailAccountRequestException(
      reason: EmailAccountRequestExceptionReason.invalid,
    );
    await _enterCode(tester, '000000');
    expect(
      find.text("That code isn't right. Check it and try again."),
      findsOneWidget,
    );
    expect(invites.accepts, 0);

    otp.signInError = null;
    await _enterCode(tester, '111111');
    expect(find.text('landing-home'), findsOneWidget);
    expect(invites.accepts, 1);
    expect(otp.signIns.last, ('req-1', '111111'));

    router.go('/invite/dead');
    await tester.pumpWidget(
      MaterialApp(
        home: InviteSignInPage(
          key: const Key('invite-dead-page'),
          token: 'dead',
          previewApi: _Preview(const InvitePreview(valid: false)),
          signedIn: () => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(inviteDeadLink), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: InviteSignInPage(
          key: const Key('invite-noname-page'),
          token: 'noname',
          previewApi: _Preview(
            const InvitePreview(
              valid: true,
              familyName: 'Ada',
              inviterName: null,
            ),
          ),
          signedIn: () => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-inviter')), findsNothing);
    expect(find.text('Join Ada'), findsOneWidget);

    final signed = _Invites();
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/invite/tok',
          routes: [
            GoRoute(
              path: '/invite/:token',
              builder: (context, state) => InviteSignInPage(
                token: 'tok',
                previewApi: _Preview(
                  const InvitePreview(
                    valid: true,
                    familyId: 'fam',
                    familyName: 'Ada',
                    inviterName: 'Bea',
                  ),
                ),
                inviteApi: signed,
                signedIn: () => true,
              ),
            ),
            GoRoute(
              path: AppRoutes.familyLanding,
              builder: (context, state) => const Text('landing-home'),
            ),
            GoRoute(
              path: AppRoutes.timeline,
              builder: (context, state) => const Text('timeline-home'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('landing-home'), findsOneWidget);
    expect(signed.accepts, 1);
  });

  testWidgets(
    'signed-in return to an already used invite opens Family Landing',
    (tester) async {
      final invites = _Invites();
      var validated = 0;
      final router = GoRouter(
        initialLocation: '/invite/tok',
        routes: [
          GoRoute(
            path: '/invite/:token',
            builder: (context, state) => InviteSignInPage(
              token: 'tok',
              previewApi: _Preview(
                const InvitePreview(valid: false),
                onValidate: () => validated++,
              ),
              inviteApi: invites,
              signedIn: () => true,
            ),
          ),
          GoRoute(
            path: AppRoutes.familyLanding,
            builder: (context, state) => const Text('landing-home'),
          ),
          GoRoute(
            path: AppRoutes.timeline,
            builder: (context, state) => const Text('timeline-home'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('landing-home'), findsOneWidget);
      expect(find.text(inviteDeadLink), findsNothing);
      expect(invites.accepts, 1);
      expect(validated, 0);
    },
  );

  testWidgets('signed-in invite that another account used stays dead', (
    tester,
  ) async {
    final invites = _Invites()..acceptInviteError = Exception('used');
    await tester.pumpWidget(
      MaterialApp(
        home: InviteSignInPage(
          token: 'used',
          previewApi: _Preview(const InvitePreview(valid: false)),
          inviteApi: invites,
          signedIn: () => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(inviteDeadLink), findsOneWidget);
    expect(invites.accepts, 1);
  });
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _enterCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(const Key('sign-in-code')), code);
  final submit = find.byKey(const Key('sign-in-code-submit'));
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

class _Otp implements OtpSignIn {
  final sent = <String>[];
  final signIns = <(String, String)>[];
  Object? sendError;
  Object? signInError;
  Completer<void>? signInGate;
  void Function()? onSignIn;

  @override
  Future<String> sendCode(String email) async {
    sent.add(email);
    final error = sendError;
    if (error != null) throw error;
    return 'req-${sent.length}';
  }

  @override
  Future<void> signIn({required String requestId, required String code}) async {
    signIns.add((requestId, code));
    final gate = signInGate;
    if (gate != null) await gate.future;
    final error = signInError;
    if (error != null) throw error;
    onSignIn?.call();
  }
}

class _Preview implements InviteLinkGateway {
  _Preview(this.preview, {this.onValidate});

  final InvitePreview preview;
  final void Function()? onValidate;

  @override
  Future<InvitePreview> validateInviteToken(String token) async {
    onValidate?.call();
    return preview;
  }
}

/// Counts every accept attempt, including ones that throw.
class _Invites extends FakeInviteGateway {
  _Invites()
    : super(familyId: null, createdFamilyId: 'fam', acceptedFamilyId: 'fam') {
    createInviteError = StateError('unexpected call');
  }

  int accepts = 0;

  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) {
    accepts++;
    return super.acceptInvite(token: token);
  }
}
