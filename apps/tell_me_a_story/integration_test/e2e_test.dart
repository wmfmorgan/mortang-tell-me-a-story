import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/core/supabase/supabase_init.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/profile_api.dart';
import 'package:tell_me_a_story/data/profile_session.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/main.dart' as app;

import 'support/preconditions.dart';
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
      final nameField = find.byKey(const Key('settings-name'));
      await tester.ensureVisible(nameField);
      await tester.tap(nameField);
      await tester.pump();
      await tester.enterText(nameField, name);
      await tester.pump();
      final save = find.byKey(const Key('settings-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
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

  testWidgets('C2 start a family lands on its empty timeline', (tester) async {
    final email = e2eEmail(flow: 2, n: 1);
    final name = e2eFamilyName(flow: 2, n: 1);
    await _signIn(tester, 'C2', email);
    await _startFamily(tester, 'C2', name);
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('C3 capture and publish shows the card on the timeline', (
    tester,
  ) async {
    final email = e2eEmail(flow: 3, n: 1);
    final family = e2eFamilyName(flow: 3, n: 1);
    final title = 'Harbor $e2eRunId';
    const body = 'A story for the album.';
    final person = 'Nora $e2eRunId';
    final placeLabel = 'Harbor Park $e2eRunId';
    await _signIn(tester, 'C3', email);
    await _startFamily(tester, 'C3', family);
    final place = await _step('C3', 'favorite', () {
      return createFavoritePlace(label: placeLabel, address: '1 Archive Lane');
    });
    await _openCapture(tester, 'C3', family);
    await _enterYear(tester, 'C3');
    await _chooseFavorite(tester, 'C3', place.label);
    await _addPerson(tester, 'C3', person);
    await _enterStory(tester, 'C3', title: title, body: body);
    await _publish(tester, 'C3', title);
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('C4 draft autosaves, resumes from drafts and publishes', (
    tester,
  ) async {
    final email = e2eEmail(flow: 4, n: 1);
    final family = e2eFamilyName(flow: 4, n: 1);
    final title = 'Orchard $e2eRunId';
    const body = 'A draft for the album.';
    final person = 'Ida $e2eRunId';
    final placeLabel = 'Orchard Park $e2eRunId';
    await _signIn(tester, 'C4', email);
    await _startFamily(tester, 'C4', family);
    final place = await _step('C4', 'favorite', () {
      return createFavoritePlace(label: placeLabel, address: '2 Archive Lane');
    });
    await _openCapture(tester, 'C4', family);
    await _enterYear(tester, 'C4');
    await _chooseFavorite(tester, 'C4', place.label);
    await _addPerson(tester, 'C4', person);
    await _enterStory(tester, 'C4', title: title, body: body);
    await _step('C4', 'autosave', () async {
      await _untilDraftReady(tester, familyId: place.familyId, title: title);
      expect(find.text('Saved'), findsOneWidget);
    });
    await _step('C4', 'leave', () async {
      await tester.tap(find.byKey(const Key('timeline-nav')));
      await pumpUntilFound(
        tester,
        find.text('No stories yet. Capture the first one for this family.'),
      );
    });
    await _step('C4', 'drafts', () async {
      await tester.tap(find.byKey(const Key('drafts-nav')));
      await pumpUntilFound(
        tester,
        find.byKey(const Key('header-underline-drafts')),
      );
      await pumpUntilFound(tester, find.text(title));
    });
    await _step('C4', 'resume', () async {
      final resume = find.text('Continue writing');
      await tester.ensureVisible(resume);
      await tester.tap(resume);
      await pumpUntilFound(tester, find.byKey(const Key('story-title')));
      await pumpUntilFound(tester, find.text(title));
      await pumpUntilFound(tester, find.text(person));
      await pumpUntilFound(tester, find.text(place.label));
    });
    await _publish(tester, 'C4', title);
  }, timeout: const Timeout(Duration(minutes: 6)));
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

Future<T> _step<T>(String flow, String label, Future<T> Function() body) async {
  try {
    return await body();
  } catch (e) {
    throw TestFailure('$flow step $label: $e');
  }
}

// The test binding replaces the tree between tests. app.main sets the URL
// strategy once, so a later flow remounts the same client.
Future<void> _mountApp(WidgetTester tester) async {
  var ready = false;
  try {
    ready = Supabase.instance.isInitialized;
  } catch (e) {
    if (e is! AssertionError) rethrow;
    ready = false;
  }
  if (!ready) {
    await app.main();
    return;
  }
  final profileApi = ProfileApi();
  ProfileSession.loadOwn = profileApi.loadOwn;
  ProfileSession.downloadAvatar = profileApi.downloadAvatar;
  final authRefresh = AuthRefresh(
    authStateChanges: Supabase.instance.client.auth.onAuthStateChange,
    initiallySignedIn: Supabase.instance.client.auth.currentSession != null,
  );
  await tester.pumpWidget(
    TellMeAStoryApp(
      router: createAppRouter(
        authRefresh: authRefresh,
        familiesApi: FamiliesApi(),
        inviteApi: InviteApi(),
        peopleApi: PeopleApi(),
      ),
    ),
  );
}

Future<void> _untilChrome(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(const Key('header-avatar')).evaluate().isNotEmpty) return;
    if (find.byKey(const Key('magic-link-email')).evaluate().isNotEmpty) {
      return;
    }
  }
  throw TestFailure('sign-in chrome was not on screen before the deadline');
}

Future<void> _signIn(WidgetTester tester, String flow, String email) async {
  await _step(flow, 'boot', () async {
    await _mountApp(tester);
    await _untilChrome(tester);
    if (find.byKey(const Key('header-avatar')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('header-avatar')));
      await pumpUntilFound(tester, find.byKey(const Key('header-menu-logout')));
      await tester.tap(find.byKey(const Key('header-menu-logout')));
    }
    await pumpUntilFound(tester, find.byKey(const Key('magic-link-email')));
  });
  await _step(flow, 'send-link', () async {
    await tester.enterText(find.byKey(const Key('magic-link-email')), email);
    await tester.pump();
    final send = find.text('Email me a sign-in link');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await _untilLinkSent(tester);
  });
  final location = await _step(flow, 'magic-link', () async {
    final location = await magicLinkLocation(email);
    expect(_handOff(location), 'pkce', reason: 'magic-link callback hand-off');
    return location;
  });
  await _step(flow, 'recover-session', () async {
    await recoverSessionFromAuthCallback(location);
  });
  await _step(flow, 'timeline', () async {
    await pumpUntilFound(
      tester,
      find.byKey(const Key('family-menu')),
      timeout: const Duration(seconds: 45),
    );
  });
}

Future<void> _startFamily(WidgetTester tester, String flow, String name) async {
  await _step(flow, 'open-menu', () async {
    await tester.tap(find.byKey(const Key('family-menu')));
    await pumpUntilFound(tester, find.byKey(const Key('family-menu-start')));
  });
  await _step(flow, 'start-dialog', () async {
    await tester.tap(find.byKey(const Key('family-menu-start')));
    await pumpUntilFound(tester, find.byKey(const Key('start-family-name')));
  });
  await _step(flow, 'create-family', () async {
    final field = find.byKey(const Key('start-family-name'));
    await tester.ensureVisible(field);
    await tester.enterText(field, name);
    await tester.pump();
    await tester.tap(find.byKey(const Key('start-family-create')));
    await pumpUntilGone(tester, find.byKey(const Key('start-family-dialog')));
    await pumpUntilFound(tester, find.text(name));
    await pumpUntilFound(
      tester,
      find.text('No stories yet. Capture the first one for this family.'),
    );
  });
}

Future<void> _openCapture(
  WidgetTester tester,
  String flow,
  String family,
) async {
  await _step(flow, 'new-story', () async {
    final button = find.text('New story');
    await pumpUntilFound(tester, button);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await pumpUntilFound(tester, find.byKey(const Key('story-title')));
    await pumpUntilFound(tester, find.text(family));
    await tester.pump();
  });
}

Future<void> _enterYear(WidgetTester tester, String flow) async {
  await _step(flow, 'timeframe', () async {
    final year = find.byKey(const Key('story-date-year'));
    await tester.ensureVisible(year);
    await tester.enterText(year, '1987');
    await tester.pump();
  });
}

Future<void> _chooseFavorite(
  WidgetTester tester,
  String flow,
  String placeLabel,
) async {
  await _step(flow, 'place', () async {
    final choose = find.text('Choose place');
    await tester.ensureVisible(choose);
    await tester.tap(choose);
    final label = find.text(placeLabel);
    await pumpUntilFound(tester, label);
    await tester.ensureVisible(label);
    await tester.tap(label);
    final use = find.text('Use this place');
    await pumpUntilFound(tester, use);
    await tester.tap(use);
    await pumpUntilGone(tester, use);
    expect(find.text(placeLabel), findsWidgets);
  });
}

Future<void> _addPerson(WidgetTester tester, String flow, String name) async {
  await _step(flow, 'add-person', () async {
    final open = find.text('Add person');
    await tester.ensureVisible(open);
    await tester.tap(open);
    await pumpUntilFound(tester, find.byKey(const Key('add-person-create')));
    await tester.tap(find.byKey(const Key('add-person-create')));
    await pumpUntilFound(tester, find.byKey(const Key('add-person-name')));
    await tester.enterText(find.byKey(const Key('add-person-name')), name);
    await tester.pump();
    final save = find.text('Add person').last;
    await tester.ensureVisible(save);
    await tester.tap(save);
    await pumpUntilGone(tester, find.byKey(const Key('add-person-picker')));
    expect(find.text(name), findsWidgets);
  });
}

Future<void> _enterStory(
  WidgetTester tester,
  String flow, {
  required String title,
  required String body,
}) async {
  await _step(flow, 'title-text', () async {
    final titleField = find.byKey(const Key('story-title'));
    await tester.ensureVisible(titleField);
    await tester.enterText(titleField, title);
    await tester.pump();
    final bodyField = find.byKey(const Key('story-body'));
    await tester.ensureVisible(bodyField);
    await tester.enterText(bodyField, body);
    await tester.pump();
  });
}

Future<void> _publish(WidgetTester tester, String flow, String title) async {
  await _step(flow, 'publish', () async {
    final publish = find.text('Publish story');
    await tester.ensureVisible(publish);
    await tester.tap(publish);
    await pumpUntilFound(
      tester,
      find.byKey(const Key('header-underline-timeline')),
      timeout: const Duration(seconds: 45),
    );
  });
  await _step(flow, 'card', () async {
    final full = find.byKey(const Key('timeline-zoom-full'));
    await pumpUntilFound(tester, full);
    expect(
      find.text('No stories yet. Capture the first one for this family.'),
      findsNothing,
    );
    await tester.ensureVisible(full);
    await tester.tap(full);
    await pumpUntilFound(tester, find.text(title));
  });
}

Future<void> _untilDraftReady(
  WidgetTester tester, {
  required String familyId,
  required String title,
}) async {
  final stories = StoriesApi();
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    final drafts = await stories.listMyDrafts(familyId);
    for (final draft in drafts) {
      final savedBody = (draft.body ?? '').trim();
      if (draft.title == title &&
          savedBody.isNotEmpty &&
          draft.timeframeStart != null &&
          draft.placeId != null &&
          draft.personIds.isNotEmpty) {
        return;
      }
    }
  }
  throw TestFailure('draft $title was not autosaved before the deadline');
}
