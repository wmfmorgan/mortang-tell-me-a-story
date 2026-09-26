import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/features/auth/magic_link_page.dart';
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
  testWidgets('signed-out user is redirected from /timeline to magic-link',
      (tester) async {
    final auth = AuthRefresh(initiallySignedIn: false);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: _StubInviteApi(),
    );

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go(AppRoutes.timeline);
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.magicLink);
    expect(find.byType(MagicLinkPage), findsOneWidget);
    expect(find.byType(TimelinePage), findsNothing);

    auth.dispose();
  });

  testWidgets('signed-in user is redirected from magic-link to /timeline',
      (tester) async {
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: _StubInviteApi(),
    );

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.timeline);
    expect(find.byType(TimelinePage), findsOneWidget);
    expect(find.byType(MagicLinkPage), findsNothing);

    auth.dispose();
  });

  testWidgets('auth refresh moves signed-out user to timeline after sign-in',
      (tester) async {
    final auth = AuthRefresh(initiallySignedIn: false);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: _StubInviteApi(),
    );

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();
    expect(find.byType(MagicLinkPage), findsOneWidget);

    auth.setSignedIn(true);
    await tester.pumpAndSettle();

    expect(find.byType(TimelinePage), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.timeline,
    );

    auth.dispose();
  });

  testWidgets('invite query is preserved when redirecting to timeline',
      (tester) async {
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: _StubInviteApi(),
    );

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go('/?invite=abc123');
    await tester.pumpAndSettle();

    final uri = router.routerDelegate.currentConfiguration.uri;
    expect(uri.path, AppRoutes.timeline);
    expect(uri.queryParameters['invite'], 'abc123');

    auth.dispose();
  });
}
