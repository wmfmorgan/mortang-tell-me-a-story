import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    show EmailAccountRequestException, EmailAccountRequestExceptionReason;
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/core/theme/album_header.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/features/auth/invite_sign_in_page.dart';
import 'package:tell_me_a_story/features/auth/magic_link_page.dart';
import 'package:tell_me_a_story/features/auth/otp_sign_in.dart';
import 'package:tell_me_a_story/features/family/delete_family_dialog.dart';
import 'package:tell_me_a_story/features/people/add_person_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('buildInviteUrl uses /invite/<token>', () {
    expect(
      buildInviteUrl('abc', origin: 'http://127.0.0.1:3000/'),
      'http://127.0.0.1:3000/invite/abc',
    );
  });

  testWidgets('landing copy, bad email, send failure, and a different email', (
    tester,
  ) async {
    final otp = _Otp();
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: MagicLinkPage(otpSignIn: otp)));
    expect(find.text('Tell Me a Story'), findsOneWidget);
    expect(find.text(landingHeadline), findsOneWidget);
    expect(find.text(landingSubhead), findsOneWidget);
    expect(find.text('blackberry picking at the farm'), findsOneWidget);
    expect(find.text('summer, 1974'), findsOneWidget);
    expect(find.text('Sign in or get started'), findsOneWidget);
    expect(
      find.text('Enter your email to access your family archive.'),
      findsOneWidget,
    );
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Email me a sign-in code'), findsOneWidget);
    expect(
      find.text("We'll email you a 6-digit code. No password needed."),
      findsOneWidget,
    );
    expect(
      find.text(
        'Private to your family. Stories stay inside the family you share them with.',
      ),
      findsOneWidget,
    );
    expect(find.text('Forgot password'), findsNothing);

    await tester.enterText(find.byKey(const Key('magic-link-email')), 'nope');
    await _tapText(tester, 'Email me a sign-in code');
    expect(find.text('Please enter a full email address.'), findsOneWidget);
    expect(otp.sent, isEmpty);

    otp.sendError = Exception('offline');
    await tester.enterText(find.byKey(const Key('magic-link-email')), 'a@b.co');
    await _tapText(tester, 'Email me a sign-in code');
    expect(find.text('Request failed'), findsOneWidget);
    expect(find.text('Check your email'), findsNothing);

    otp.sendError = null;
    await _tapText(tester, 'Email me a sign-in code');
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.text('We sent a 6-digit code to a@b.co.'), findsOneWidget);
    expect(find.text('Sign-in code'), findsOneWidget);
    expect(find.byKey(const Key('sign-in-code')), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    final codeField = tester.widget<TextField>(
      find.byKey(const Key('sign-in-code')),
    );
    expect(codeField.decoration?.hintText, isNull);
    expect(otp.sent, ['a@b.co', 'a@b.co']);

    await _tapText(tester, 'Use a different email');
    expect(find.text('Sign in or get started'), findsOneWidget);
    expect(find.text('Check your email'), findsNothing);
  });

  testWidgets('landing code step: errors, a new code, and sign-in', (
    tester,
  ) async {
    final otp = _Otp();
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: MagicLinkPage(otpSignIn: otp)));
    await tester.enterText(
      find.byKey(const Key('magic-link-email')),
      ' a@b.co ',
    );
    await _tapText(tester, 'Email me a sign-in code');
    expect(otp.sent, ['a@b.co']);

    for (final (reason, copy) in [
      (
        EmailAccountRequestExceptionReason.invalid,
        "That code isn't right. Check it and try again.",
      ),
      (
        EmailAccountRequestExceptionReason.expired,
        'That code has expired. Send a new one.',
      ),
      (
        EmailAccountRequestExceptionReason.tooManyAttempts,
        'Too many tries. Wait a few minutes, then send a new code.',
      ),
    ]) {
      otp.signInError = EmailAccountRequestException(reason: reason);
      await _enterCode(tester, '123456');
      expect(find.text(copy), findsOneWidget);
    }

    otp.signInError = null;
    await _tapText(tester, 'Send a new code');
    expect(otp.sent, ['a@b.co', 'a@b.co']);
    expect(
      find.text('Too many tries. Wait a few minutes, then send a new code.'),
      findsNothing,
    );
    expect(find.text('Check your email'), findsOneWidget);

    final pending = Completer<void>();
    otp.signInGate = pending;
    await tester.enterText(find.byKey(const Key('sign-in-code')), '111111');
    await tester.tap(find.byKey(const Key('sign-in-code-submit')));
    await tester.pump();
    expect(find.text('Signing in…'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(otp.signIns.last, ('req-2', '111111'));
    expect(find.text('Sign in'), findsOneWidget);
  });

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
    final invites = _Invites()..acceptError = Exception('used');
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

  testWidgets('listed confirms use a blur shell and not AlertDialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: albumTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () =>
                      showDeleteFamilyDialog(context, familyName: 'Ada'),
                  child: const Text('open-delete'),
                ),
                TextButton(
                  onPressed: () => AddPersonModal.show(
                    context,
                    familyId: 'fam',
                    api: _People(),
                  ),
                  child: const Text('open-person'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-delete'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open-person'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byKey(const Key('add-person-picker')), findsOneWidget);
    expect(find.text('Create new person'), findsOneWidget);
    expect(find.text('+ Create new person'), findsNothing);
  });

  testWidgets('new story header uses a plus circle and invite does not', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: albumTheme(),
        home: Scaffold(
          appBar: AlbumHeader(
            page: AlbumHeaderPage.timeline,
            familyName: 'Ada',
            families: [
              MemberFamily(
                id: 'fam',
                name: 'Ada',
                createdAt: DateTime.utc(1980),
              ),
            ],
            currentFamilyId: 'fam',
            onFamilySelected: (_) {},
            onInvite: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('+ New story'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'New story'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Invite'), findsNothing);
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    final invite = find.byKey(const Key('family-menu-invite'));
    expect(invite, findsOneWidget);
    expect(
      find.descendant(
        of: invite,
        matching: find.byIcon(Icons.person_add_outlined),
      ),
      findsOneWidget,
    );
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

class _Invites implements InviteGateway {
  int accepts = 0;
  Object? acceptError;

  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    accepts++;
    final error = acceptError;
    if (error != null) throw error;
    return const AcceptInviteResult(familyId: 'fam', membershipId: 'm');
  }

  @override
  Future<String?> currentFamilyId() async => null;

  @override
  Future<String> createFamily(String name) async => 'fam';

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
    String? personId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {}
}

class _People extends PeopleGateway {
  @override
  Future<List<Person>> listPeople(String familyId) async => const [];

  @override
  Future<Person> createPerson({
    required String familyId,
    required String name,
    String? about,
    String? email,
    bool passedAway = false,
    List<int>? pictureBytes,
  }) {
    throw UnimplementedError();
  }
}
