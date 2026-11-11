import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:tell_me_a_story/core/domain/accept_invite_result.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/invite_link_repository.dart';
import 'package:tell_me_a_story/core/domain/invite_preview.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/server/app_session.dart';
import 'package:tell_me_a_story/core/session/app_session_provider.dart';
import 'package:tell_me_a_story/core/session/auth_refresh.dart';
import 'package:tell_me_a_story/features/auth/domain/otp_sign_in.dart';
import 'package:tell_me_a_story/features/auth/presentation/invite_sign_in_page.dart';

import '../../../support/fakes/fake_invite_repository.dart';
import '../../../support/pump_app.dart';

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
          builder: (context, state) =>
              InviteSignInPage(token: state.pathParameters['token']!),
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
    await pumpRouterApp(
      tester,
      router,
      overrides: _overrides(
        auth: auth,
        preview: _Preview(
          const InvitePreview(
            valid: true,
            familyId: 'fam',
            familyName: 'Ada',
            inviterName: 'Bea',
          ),
        ),
        invites: invites,
        otp: otp,
      ),
    );
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

    otp.signInError = const AppException(
      code: AppErrorCode.validation,
      message: "That code isn't right. Check it and try again.",
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
    // A fresh ProviderScope per app below.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(
      tester,
      const InviteSignInPage(key: Key('invite-dead-page'), token: 'dead'),
      overrides: _overrides(
        auth: _signedOut(),
        preview: _Preview(const InvitePreview(valid: false)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(inviteDeadLink), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await pumpApp(
      tester,
      const InviteSignInPage(key: Key('invite-noname-page'), token: 'noname'),
      overrides: _overrides(
        auth: _signedOut(),
        preview: _Preview(
          const InvitePreview(
            valid: true,
            familyName: 'Ada',
            inviterName: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-inviter')), findsNothing);
    expect(find.text('Join Ada'), findsOneWidget);

    final signed = _Invites();
    final signedRouter = GoRouter(
      initialLocation: '/invite/tok',
      routes: [
        GoRoute(
          path: '/invite/:token',
          builder: (context, state) => const InviteSignInPage(token: 'tok'),
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
    addTearDown(signedRouter.dispose);
    await tester.pumpWidget(const SizedBox());
    await pumpRouterApp(
      tester,
      signedRouter,
      overrides: _overrides(
        auth: _signedIn(),
        preview: _Preview(
          const InvitePreview(
            valid: true,
            familyId: 'fam',
            familyName: 'Ada',
            inviterName: 'Bea',
          ),
        ),
        invites: signed,
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
            builder: (context, state) => const InviteSignInPage(token: 'tok'),
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
      await pumpRouterApp(
        tester,
        router,
        overrides: _overrides(
          auth: _signedIn(),
          preview: _Preview(
            const InvitePreview(valid: false),
            onValidate: () => validated++,
          ),
          invites: invites,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('landing-home'), findsOneWidget);
      expect(find.text(inviteDeadLink), findsNothing);
      expect(invites.accepts, 1);
      expect(validated, 0);
    },
  );

  testWidgets('signed-in wrong account shows the reason and switches account', (
    tester,
  ) async {
    final auth = _signedIn();
    final invites = _Invites()
      ..acceptInviteError = const AppException(
        code: AppErrorCode.inviteInvalid,
        message: 'Invite was sent to a different email',
      );
    await pumpApp(
      tester,
      const InviteSignInPage(token: 'tok'),
      overrides: [
        ..._overrides(
          auth: auth,
          preview: _Preview(
            const InvitePreview(
              valid: true,
              familyId: 'fam',
              familyName: 'Ada',
            ),
          ),
          invites: invites,
        ),
        appSessionProvider.overrideWithValue(
          _Session(onSignOut: () => auth.setSignedIn(false)),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Invite was sent to a different email'), findsOneWidget);
    expect(find.text(inviteDeadLink), findsNothing);
    expect(invites.accepts, 1);

    await tester.tap(find.byKey(const Key('invite-switch-account')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-email')), findsOneWidget);
    expect(find.text('Join Ada'), findsOneWidget);
  });

  testWidgets('accept network failure offers Try again', (tester) async {
    final invites = _Invites()..acceptInviteError = Exception('offline');
    final router = GoRouter(
      initialLocation: '/invite/tok',
      routes: [
        GoRoute(
          path: '/invite/:token',
          builder: (context, state) => const InviteSignInPage(token: 'tok'),
        ),
        GoRoute(
          path: AppRoutes.familyLanding,
          builder: (context, state) => const Text('landing-home'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpRouterApp(
      tester,
      router,
      overrides: _overrides(
        auth: _signedIn(),
        preview: _Preview(const InvitePreview(valid: true, familyName: 'Ada')),
        invites: invites,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isA<Exception>());
    expect(find.text('Request failed'), findsOneWidget);
    expect(find.byKey(const Key('invite-retry')), findsOneWidget);

    invites.acceptInviteError = null;
    await tester.tap(find.byKey(const Key('invite-retry')));
    await tester.pumpAndSettle();
    expect(find.text('landing-home'), findsOneWidget);
    expect(invites.accepts, 2);
  });
}

/// Repositories and session for one pumped app. [invites] defaults to one
/// that counts accepts; [otp] to a fresh fake.
List<Override> _overrides({
  required AuthRefresh auth,
  required InviteLinkRepository preview,
  InviteRepository? invites,
  OtpSignIn? otp,
}) => [
  authRefreshProvider.overrideWithValue(auth),
  inviteLinkRepositoryProvider.overrideWithValue(preview),
  inviteRepositoryProvider.overrideWithValue(invites ?? _Invites()),
  otpSignInProvider.overrideWithValue(otp ?? _Otp()),
];

AuthRefresh _signedOut() => _session(signedIn: false);

AuthRefresh _signedIn() => _session(signedIn: true);

AuthRefresh _session({required bool signedIn}) {
  final auth = AuthRefresh(initiallySignedIn: signedIn);
  addTearDown(auth.dispose);
  return auth;
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

class _Preview implements InviteLinkRepository {
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
class _Invites extends FakeInviteRepository {
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

class _Session extends AppSession {
  _Session({required this.onSignOut});

  final void Function() onSignOut;

  @override
  String? get currentUserId => 'u1';

  @override
  Future<void> signOut() async => onSignOut();
}
