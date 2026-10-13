import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/theme/album_header.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/features/auth/invite_sign_in_page.dart';
import 'package:tell_me_a_story/features/auth/magic_link_page.dart';
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

  testWidgets('landing copy, resend, 429, and a different email', (
    tester,
  ) async {
    final sender = _Sender();
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: MagicLinkPage(sender: sender)),
    );
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
    expect(find.text('Email me a sign-in link'), findsOneWidget);
    expect(find.text(landingPasswordNote), findsOneWidget);
    expect(
      find.text(
        'Private to your family. Stories stay inside the family you share them with.',
      ),
      findsOneWidget,
    );
    expect(find.text('Forgot password'), findsNothing);

    await tester.enterText(find.byKey(const Key('magic-link-email')), 'nope');
    await tester.ensureVisible(find.text('Email me a sign-in link'));
    await tester.tap(find.text('Email me a sign-in link'));
    await tester.pump();
    expect(find.text('Please enter a full email address.'), findsOneWidget);
    expect(sender.calls, 0);

    await tester.enterText(
      find.byKey(const Key('magic-link-email')),
      'a@b.co',
    );
    await tester.ensureVisible(find.text('Email me a sign-in link'));
    await tester.tap(find.text('Email me a sign-in link'));
    await tester.pumpAndSettle();
    expect(find.text('Check your email'), findsOneWidget);
    expect(sender.calls, 1);
    expect(sender.redirectTo, isNot(contains('invite')));

    sender.error = AuthException('Request failed', statusCode: '429');
    await tester.ensureVisible(find.text('Send it again'));
    await tester.tap(find.text('Send it again'));
    await tester.pumpAndSettle();
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.text('Request failed'), findsOneWidget);
    expect(sender.calls, 2);

    await tester.ensureVisible(find.text('Use a different email'));
    await tester.tap(find.text('Use a different email'));
    await tester.pump();
    expect(find.text('Sign in or get started'), findsOneWidget);
    expect(find.text('Check your email'), findsNothing);
  });

  testWidgets('invite page live, dead, null inviter, and signed-in accept', (
    tester,
  ) async {
    final sender = _Sender();
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
            sender: sender,
            signedIn: () => false,
          ),
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

    await tester.enterText(find.byKey(const Key('invite-email')), 'a@b.co');
    final send = find.text('Email me a sign-in link');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(
      find.text('We sent a sign-in link to a@b.co. Tap it to join Ada.'),
      findsOneWidget,
    );
    expect(sender.redirectTo, contains('/invite/tok'));

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
              path: AppRoutes.timeline,
              builder: (context, state) => const Text('timeline-home'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('timeline-home'), findsOneWidget);
    expect(signed.accepts, 1);
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
                  onPressed: () => showDeleteFamilyDialog(
                    context,
                    familyName: 'Ada',
                  ),
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
    expect(find.text('Invite'), findsOneWidget);
    final invite = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Invite'),
    );
    expect(invite.child, isA<Text>());
  });
}

class _Sender implements MagicLinkSender {
  int calls = 0;
  String? redirectTo;
  Object? error;

  @override
  Future<void> send(String email, {required String redirectTo}) async {
    calls++;
    this.redirectTo = redirectTo;
    final thrown = error;
    if (thrown != null) throw thrown;
  }
}

class _Preview implements InviteLinkGateway {
  _Preview(this.preview);

  final InvitePreview preview;

  @override
  Future<InvitePreview> validateInviteToken(String token) async => preview;
}

class _Invites implements InviteGateway {
  int accepts = 0;

  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    accepts++;
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
    DateTime? birthDate,
    String? birthPrecision,
    DateTime? passingDate,
    String? passingPrecision,
    String? about,
    String? email,
    List<int>? pictureBytes,
  }) {
    throw UnimplementedError();
  }
}
