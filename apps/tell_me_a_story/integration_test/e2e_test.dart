import 'package:flutter/foundation.dart';
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

    await _c1Step('boot', () async {
      await app.main();
      await pumpUntilFound(tester, find.byKey(const Key('magic-link-email')));
    });
    await _c1Step('send-link', () async {
      await tester.enterText(find.byKey(const Key('magic-link-email')), email);
      await tester.pump();
      final send = find.text('Email me a sign-in link');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await _untilLinkSent(tester);
    });

    final location = await _c1Step('magic-link', () async {
      final location = await magicLinkLocation(email);
      expect(
        _handOff(location),
        'pkce',
        reason: 'magic-link callback hand-off',
      );
      return location;
    });

    await _c1Step('recover-session', () async {
      await recoverSessionFromAuthCallback(location);
    });
    await _c1Step('avatar', () async {
      await pumpUntilFound(
        tester,
        find.byKey(const Key('header-avatar')),
        timeout: const Duration(seconds: 45),
      );
    });
    await _c1Step('menu-settings', () async {
      await tester.tap(find.byKey(const Key('header-avatar')));
      await pumpUntilFound(
        tester,
        find.byKey(const Key('header-menu-settings')),
      );
    });
    await _c1Step('settings-name', () async {
      await tester.tap(find.byKey(const Key('header-menu-settings')));
      await pumpUntilFound(tester, find.byKey(const Key('settings-name')));
    });
    await _c1Step('settings-email', () async {
      await pumpUntilFound(tester, find.text(email));
    });

    await _c1Step('save', () async {
      await tester.enterText(find.byKey(const Key('settings-name')), name);
      await tester.pump();
      final save = find.byKey(const Key('settings-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await pumpUntilFound(
        tester,
        find.text('All changes saved to album cloud'),
      );
    });

    await _c1Step('timeline-nav', () async {
      await tester.tap(find.byKey(const Key('timeline-nav')));
      await pumpUntilFound(
        tester,
        find.byKey(const Key('header-underline-timeline')),
      );
    });
    await _c1Step('empty-state', () async {
      expect(
        find.text('No stories yet. Capture the first one for this family.'),
        findsOneWidget,
      );
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<T> _c1Step<T>(String label, Future<T> Function() body) async {
  try {
    return await body();
  } catch (e) {
    throw TestFailure('C1 step $label: $e');
  }
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
