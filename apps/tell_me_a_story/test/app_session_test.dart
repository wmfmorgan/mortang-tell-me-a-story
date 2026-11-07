import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/server/app_session.dart';
import 'package:tell_me_a_story/core/theme/album_header.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() => AppSession.instance = const SupabaseAppSession());

  test('the default session is Supabase-backed', () {
    expect(AppSession.instance, isA<SupabaseAppSession>());
  });

  test('the Supabase session has no user before Supabase starts', () {
    expect(const SupabaseAppSession().currentUserId, isNull);
  });

  testWidgets('header Logout without onLogout signs out through AppSession', (
    tester,
  ) async {
    final session = _FakeSession('u1');
    AppSession.instance = session;
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AlbumHeader(
            page: AlbumHeaderPage.timeline,
            familyName: 'Morgan',
            families: const [],
            currentFamilyId: null,
            onFamilySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('header-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('header-menu-logout')));
    await tester.pumpAndSettle();

    expect(session.signOutCalls, 1);
  });
}

class _FakeSession extends AppSession {
  _FakeSession(this.currentUserId);

  @override
  final String? currentUserId;

  var signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}
