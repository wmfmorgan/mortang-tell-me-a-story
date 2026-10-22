import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tell_me_a_story/core/supabase/supabase_init.dart';
import 'package:tell_me_a_story/main.dart' as app;

import 'support/prod_guard.dart';
import 'support/relay_client.dart';
import 'support/test_users.dart';
import 'support/waits.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(assertLocalSupabase);

  testWidgets('C1 magic-link sign-in lands on timeline', (tester) async {
    final email = e2eEmail(flow: 1, n: 1);
    final name = 'Ada $e2eRunId';

    await app.main();
    await pumpUntilFound(tester, find.byKey(const Key('magic-link-email')));
    await _enterText(tester, find.byKey(const Key('magic-link-email')), email);
    final send = find.text('Email me a sign-in link');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await _untilLinkSent(tester);

    final location = await magicLinkLocation(email);
    expect(_handOff(location), 'pkce', reason: 'magic-link callback hand-off');

    await recoverSessionFromAuthCallback(location);
    await pumpUntilFound(
      tester,
      find.byKey(const Key('header-avatar')),
      timeout: const Duration(seconds: 45),
    );
    await tester.tap(find.byKey(const Key('header-avatar')));
    await pumpUntilFound(tester, find.byKey(const Key('header-menu-settings')));
    await tester.tap(find.byKey(const Key('header-menu-settings')));
    await pumpUntilFound(tester, find.byKey(const Key('settings-name')));
    await pumpUntilFound(tester, find.text(email));

    await _enterText(tester, find.byKey(const Key('settings-name')), name);
    final save = find.byKey(const Key('settings-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await pumpUntilFound(tester, find.text('All changes saved to album cloud'));

    await tester.tap(find.byKey(const Key('timeline-nav')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('header-underline-timeline')),
    );
    expect(
      find.text('No stories yet. Capture the first one for this family.'),
      findsOneWidget,
    );
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<void> _enterText(WidgetTester tester, Finder finder, String text) async {
  final editable = tester.widget<EditableText>(
    find.descendant(of: finder, matching: find.byType(EditableText)),
  );
  editable.controller.text = text;
  await tester.pump();
}

String _handOff(Uri location) {
  if (location.queryParameters.containsKey('code')) return 'pkce';
  final fragment = Uri.splitQueryString(location.fragment);
  if (fragment.containsKey('access_token')) return 'implicit';
  return 'other';
}

Future<void> _untilLinkSent(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.text('Check your email').evaluate().isNotEmpty) return;
    if (find.textContaining('rate limit').evaluate().isNotEmpty) {
      fail('email rate limit');
    }
  }
  throw TestFailure('sign-in link was not confirmed before the deadline');
}
