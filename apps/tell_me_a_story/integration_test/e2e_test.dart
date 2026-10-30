import 'package:flutter/material.dart' show TextField, FilledButton;
import 'package:flutter/widgets.dart';
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

  testWidgets('C2 start a family lands on family landing', (tester) async {
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
    await _publish(
      tester,
      'C3',
      title,
      body: body,
      person: person,
      placeLabel: place.label,
    );
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
      await pumpUntilFound(
        tester,
        find.text('Saved'),
        timeout: const Duration(seconds: 10),
      );
      expect(find.text('Not saved'), findsNothing);
    });
    await _step('C4', 'leave', () async {
      await tester.tap(find.byKey(const Key('timeline-nav')));
      await pumpUntilGone(tester, find.byKey(const Key('story-title')));
      await pumpUntilFound(
        tester,
        find.text('No stories yet. Capture the first one for this family.'),
      );
      expect(find.text(title), findsNothing);
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
    await _publish(
      tester,
      'C4',
      title,
      body: body,
      person: person,
      placeLabel: place.label,
    );
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('C5 reader adds a comment and a perspective', (tester) async {
    final email = e2eEmail(flow: 5, n: 1);
    final family = e2eFamilyName(flow: 5, n: 1);
    final title = 'Lantern $e2eRunId';
    const body = 'A story for the reader.';
    final person = 'Ruth $e2eRunId';
    final placeLabel = 'Lantern Park $e2eRunId';
    const comment = 'A short note from the reader';
    const perspective = 'Another telling from the reader';
    final story = await _publishAlbumStory(
      tester,
      'C5',
      email: email,
      family: family,
      title: title,
      body: body,
      person: person,
      placeLabel: placeLabel,
      address: '5 Archive Lane',
    );
    await _openPublished(tester, 'C5', story);
    await _addComment(tester, 'C5', comment);
    await _addPerspective(tester, 'C5', perspective);
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('C6 invite link lets a second user join and see the timeline', (
    tester,
  ) async {
    final host = e2eEmail(flow: 6, n: 1);
    final guest = e2eEmail(flow: 6, n: 2);
    final family = e2eFamilyName(flow: 6, n: 1);
    await _signIn(tester, 'C6', host);
    await _startFamily(tester, 'C6', family);
    final link = await _linkTabInvite(tester, 'C6');
    final location = _inviteLocation(link);
    await _step('C6', 'close-invite', () async {
      await tester.tap(find.byKey(const Key('invite-close')));
      await pumpUntilGone(tester, find.byKey(const Key('invite-link')));
    });
    await _step('C6', 'guest-signed-out', () async {
      await resetAppState();
      await pumpUntilFound(tester, find.byKey(const Key('magic-link-email')));
    });
    await _step('C6', 'open-invite', () async {
      _go(tester, location);
      await pumpUntilFound(tester, find.byKey(const Key('invite-email')));
    });
    await _step('C6', 'send-link', () async {
      await tester.enterText(find.byKey(const Key('invite-email')), guest);
      await tester.pump();
      final send = find.text('Email me a sign-in link');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await pumpUntilFound(tester, find.byKey(const Key('invite-sent')));
    });
    final callback = await _step('C6', 'magic-link', () async {
      final callback = await magicLinkLocation(guest);
      expect(
        _handOff(callback),
        'pkce',
        reason: 'magic-link callback hand-off',
      );
      return callback;
    });
    await _step('C6', 'recover-session', () async {
      await recoverSessionFromAuthCallback(callback);
    });
    await _step('C6', 'joined-timeline', () async {
      await pumpUntilFound(
        tester,
        find.byKey(const Key('family-landing')),
        timeout: const Duration(seconds: 45),
      );
      await pumpUntilFound(tester, find.text(family));
      await tester.tap(find.byKey(const Key('timeline-nav')));
      await pumpUntilFound(
        tester,
        find.byKey(const Key('header-underline-timeline')),
      );
      expect(find.byKey(const Key('invite-email')), findsNothing);
    });
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('C7 search by person, place and timeframe finds the story', (
    tester,
  ) async {
    final email = e2eEmail(flow: 7, n: 1);
    final family = e2eFamilyName(flow: 7, n: 1);
    final title = 'Meadow $e2eRunId';
    const body = 'A story for the search.';
    final person = 'Leah $e2eRunId';
    final placeLabel = 'Meadow Park $e2eRunId';
    final story = await _publishAlbumStory(
      tester,
      'C7',
      email: email,
      family: family,
      title: title,
      body: body,
      person: person,
      placeLabel: placeLabel,
      address: '7 Archive Lane',
    );
    await _searchStory(tester, 'C7', story: story, person: person);
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('C8 user from another family sees no content on a story url', (
    tester,
  ) async {
    final host = e2eEmail(flow: 8, n: 1);
    final guest = e2eEmail(flow: 8, n: 2);
    final familyA = e2eFamilyName(flow: 8, n: 1);
    final familyB = e2eFamilyName(flow: 8, n: 2);
    final title = 'Cedar $e2eRunId';
    const body = 'A private story for family A.';
    final person = 'Mina $e2eRunId';
    final placeLabel = 'Cedar Park $e2eRunId';
    final story = await _publishAlbumStory(
      tester,
      'C8',
      email: host,
      family: familyA,
      title: title,
      body: body,
      person: person,
      placeLabel: placeLabel,
      address: '8 Archive Lane',
    );
    await _signIn(tester, 'C8', guest);
    await _startFamily(tester, 'C8', familyB);
    await _step('C8', 'other-family', () async {
      _go(tester, '/stories/${story.id}');
      await _untilOtherFamilySeesNoStory(
        tester,
        storyId: story.id,
        title: title,
        body: body,
      );
    });
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('C9 sign out redirects guarded routes to the landing page', (
    tester,
  ) async {
    final email = e2eEmail(flow: 9, n: 1);
    await _signIn(tester, 'C9', email);
    await _signOut(tester);
    for (final route in const [
      '/family',
      '/timeline',
      '/drafts',
      '/search',
      '/settings',
    ]) {
      await _step('C9', route, () async {
        await _expectGuardedRedirect(tester, route);
      });
    }
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

Future<T> _step<T>(String flow, String label, Future<T> Function() body) async {
  try {
    return await body();
  } catch (e) {
    throw TestFailure('$flow step $label: $e');
  }
}

bool _supabaseReady() {
  try {
    return Supabase.instance.isInitialized;
  } catch (e) {
    if (e is! AssertionError) rethrow;
    return false;
  }
}

// The test binding replaces the tree between tests. app.main sets the URL
// strategy once, so a later flow remounts the same client.
Future<void> _mountApp(WidgetTester tester) async {
  if (!_supabaseReady()) {
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

Future<void> _signIn(WidgetTester tester, String flow, String email) async {
  await _step(flow, 'boot', () async {
    if (_supabaseReady()) {
      await resetAppState();
    }
    await _mountApp(tester);
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
    await pumpUntilFound(
      tester,
      find.byKey(const Key('family-menu-manage')).hitTestable(),
    );
  });
  await _step(flow, 'open-hub', () async {
    await tester.tap(find.byKey(const Key('family-menu-manage')).hitTestable());
    await pumpUntilFound(
      tester,
      find.byKey(const Key('manage-families-start')).hitTestable(),
    );
  });
  await _step(flow, 'start-dialog', () async {
    await tester.tap(
      find.byKey(const Key('manage-families-start')).hitTestable(),
    );
    await pumpUntilFound(tester, find.byKey(const Key('start-family-name')));
  });
  await _step(flow, 'create-family', () async {
    final field = find.byKey(const Key('start-family-name'));
    await tester.ensureVisible(field);
    await tester.enterText(field, name);
    await pumpUntilFound(tester, find.text(name));
    final create = find.byKey(const Key('start-family-create'));
    await tester.ensureVisible(create);
    await tester.tap(create);
    await pumpUntilGone(tester, find.byKey(const Key('start-family-dialog')));
    await pumpUntilFound(tester, find.text(name));
    await pumpUntilFound(tester, find.byKey(const Key('family-landing')));
    await pumpUntilFound(
      tester,
      find.text('No stories added in the past 7 days.'),
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
    // Text("Use this place") is always in the modal; the FilledButton stays
    // disabled until markUsed finishes and _pending is set. Wait for enabled.
    final use = find.widgetWithText(FilledButton, 'Use this place');
    await pumpUntilFound(tester, use);
    await tester.ensureVisible(use);
    final enabledDeadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(enabledDeadline)) {
      if (tester.widget<FilledButton>(use).onPressed != null) break;
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (tester.widget<FilledButton>(use).onPressed == null) {
      throw TestFailure(
        '$use stayed disabled within 0:00:30.000000 (url: ${Uri.base})',
      );
    }
    await tester.tap(use);
    await pumpUntilGone(tester, use);
    await pumpUntilFound(tester, find.text(placeLabel));
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
    await _untilField(tester, const Key('story-title'), title);
    await _untilField(tester, const Key('story-body'), body);
  });
}

String? _fieldText(WidgetTester tester, Key key) {
  final finder = find.byKey(key);
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<TextField>(finder).controller?.text;
}

bool _fieldHolds(WidgetTester tester, Key key, String value) {
  return (_fieldText(tester, key) ?? '').trim() == value.trim();
}

/// [WidgetTester.enterText] is dropped on the multiline story body under web
/// drive (`updateEditingValue` no-ops when the input connection is not open).
/// Write the editing value directly so publish can see the body.
Future<void> _putField(WidgetTester tester, Key key, String value) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  final editable = tester.state<EditableTextState>(
    find.descendant(of: finder, matching: find.byType(EditableText)),
  );
  editable.userUpdateTextEditingValue(
    TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    ),
    SelectionChangedCause.keyboard,
  );
  await tester.pump();
}

Future<void> _untilField(
  WidgetTester tester,
  Key key,
  String value, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    if (_fieldHolds(tester, key, value)) return;
    await _putField(tester, key, value);
    if (_fieldHolds(tester, key, value)) return;
    if (!DateTime.now().isBefore(deadline)) {
      final saw = _fieldText(tester, key);
      throw TestFailure(
        '$key did not keep its text within $timeout (url: ${Uri.base}) '
        'saw=${saw == null ? 'absent' : saw.length}',
      );
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _publish(
  WidgetTester tester,
  String flow,
  String title, {
  required String body,
  required String person,
  required String placeLabel,
}) async {
  await _step(flow, 'publish', () async {
    String captureStatus() {
      if (find.text('Saved').evaluate().isNotEmpty) return 'Saved';
      if (find.text('Not saved').evaluate().isNotEmpty) return 'Not saved';
      return 'none';
    }

    String? fieldText(Key key) {
      final finder = find.byKey(key);
      if (finder.evaluate().isEmpty) return null;
      return tester.widget<TextField>(finder).controller?.text;
    }

    List<String> missingFields() {
      final missing = <String>[];
      final titleText = fieldText(const Key('story-title'))?.trim() ?? '';
      if (titleText.isEmpty) missing.add('title');
      final bodyText = fieldText(const Key('story-body'))?.trim() ?? '';
      if (bodyText.isEmpty) missing.add('body');
      final yearText = fieldText(const Key('story-date-year'))?.trim() ?? '';
      if (yearText.isEmpty || int.tryParse(yearText) == null) {
        missing.add('timeframe');
      }
      if (find.text(person).evaluate().isEmpty) missing.add('person');
      if (find.text(placeLabel).evaluate().isEmpty) missing.add('place');
      return missing;
    }

    // Pre-tap settle (15s). FORBIDDEN: wait on find.text('Saved') here.
    // Do not tap while the body is empty: publish stays on /stories/new and
    // shows the highlighted-fields banner.
    final readyDeadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(readyDeadline)) {
      if (!_fieldHolds(tester, const Key('story-body'), body)) {
        final bodyField = find.byKey(const Key('story-body'));
        if (bodyField.evaluate().isNotEmpty) {
          await _putField(tester, const Key('story-body'), body);
        }
      }
      if (missingFields().isEmpty) break;
      await tester.pump(const Duration(milliseconds: 100));
    }
    final missingAtTap = missingFields();
    if (missingAtTap.isNotEmpty) {
      throw TestFailure(
        'refusing to publish with missing=${missingAtTap.join(',')} '
        '(url: ${Uri.base})',
      );
    }

    final publish = find.text('Publish story');
    await tester.ensureVisible(publish);
    await tester.pump(const Duration(milliseconds: 100));
    if (!_fieldHolds(tester, const Key('story-body'), body)) {
      await _untilField(
        tester,
        const Key('story-body'),
        body,
        timeout: const Duration(seconds: 5),
      );
      await tester.ensureVisible(publish);
    }
    final stillMissing = missingFields();
    if (stillMissing.isNotEmpty) {
      throw TestFailure(
        'refusing to publish with missing=${stillMissing.join(',')} '
        '(url: ${Uri.base})',
      );
    }
    final statusAtTap = captureStatus();
    await tester.tap(publish);
    final finder = find.byKey(const Key('header-underline-timeline'));
    const timeout = Duration(seconds: 45);
    final deadline = DateTime.now().add(timeout);
    var bannerSeen = false;
    var snackbarSeen = false;
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .text('Finish the highlighted fields to publish.')
          .evaluate()
          .isNotEmpty) {
        bannerSeen = true;
      }
      if (find
          .text('Couldn’t publish story. Try again.')
          .evaluate()
          .isNotEmpty) {
        snackbarSeen = true;
      }
      if (finder.evaluate().isNotEmpty) return;
    }
    final status = captureStatus();
    final missing = missingFields();
    final missingBit = missing.isEmpty
        ? 'missing=none'
        : 'missing=${missing.join(',')}';
    throw TestFailure(
      '$finder not found within $timeout (url: ${Uri.base})'
      ' banner=${bannerSeen ? 'y' : 'n'}'
      ' snackbar=${snackbarSeen ? 'y' : 'n'}'
      ' statusAtTap=$statusAtTap status=$status'
      ' $missingBit',
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

TellMeAStoryApp _app(WidgetTester tester) {
  return tester.widget<TellMeAStoryApp>(find.byType(TellMeAStoryApp));
}

void _go(WidgetTester tester, String location) {
  _app(tester).router.go(location);
}

String _path(WidgetTester tester) {
  return _app(tester).router.routerDelegate.currentConfiguration.uri.path;
}

Future<Story> _publishedStory({
  required String familyId,
  required String title,
}) async {
  final rows = await StoriesApi().listPublished(familyId);
  for (final story in rows) {
    if (story.title == title) return story;
  }
  throw TestFailure('published story $title was not listed');
}

Future<Story> _publishAlbumStory(
  WidgetTester tester,
  String flow, {
  required String email,
  required String family,
  required String title,
  required String body,
  required String person,
  required String placeLabel,
  required String address,
}) async {
  await _signIn(tester, flow, email);
  await _startFamily(tester, flow, family);
  final place = await _step(flow, 'favorite', () {
    return createFavoritePlace(label: placeLabel, address: address);
  });
  await _openCapture(tester, flow, family);
  await _enterYear(tester, flow);
  await _chooseFavorite(tester, flow, place.label);
  await _addPerson(tester, flow, person);
  await _enterStory(tester, flow, title: title, body: body);
  await _publish(
    tester,
    flow,
    title,
    body: body,
    person: person,
    placeLabel: place.label,
  );
  return _step(flow, 'published', () {
    return _publishedStory(familyId: place.familyId, title: title);
  });
}

Future<void> _openPublished(
  WidgetTester tester,
  String flow,
  Story story,
) async {
  await _step(flow, 'open-story', () async {
    final card = find.byKey(Key('timeline-card-${story.id}'));
    await pumpUntilFound(tester, card);
    await tester.ensureVisible(card);
    await tester.tap(card);
    await pumpUntilFound(tester, find.byKey(const Key('story-reader-modal')));
    final title = story.title;
    if (title == null || title.isEmpty) {
      throw TestFailure('published story has no title');
    }
    await pumpUntilFound(tester, find.text(title));
  });
}

Future<void> _addComment(
  WidgetTester tester,
  String flow,
  String comment,
) async {
  await _step(flow, 'comment', () async {
    final add = find.text('+ Add comment');
    await pumpUntilFound(tester, add);
    await tester.ensureVisible(add);
    await tester.tap(add);
    final composer = find.byKey(const Key('comment-composer'));
    await pumpUntilFound(tester, composer);
    await tester.enterText(composer, comment);
    await tester.pump();
    final post = find.text('Post');
    await pumpUntilFound(tester, post);
    await tester.ensureVisible(post);
    await tester.tap(post);
    await pumpUntilFound(tester, find.text(comment));
  });
}

Future<void> _addPerspective(
  WidgetTester tester,
  String flow,
  String perspective,
) async {
  await _step(flow, 'perspective', () async {
    final add = find.text('+ Add your perspective');
    await tester.ensureVisible(add);
    await tester.tap(add);
    final body = find.byKey(const Key('perspective-body'));
    await pumpUntilFound(tester, body);
    await tester.enterText(body, perspective);
    await tester.pump();
    final publish = find.text('Publish perspective');
    await tester.ensureVisible(publish);
    await tester.tap(publish);
    await pumpUntilGone(tester, body);
    await pumpUntilFound(tester, find.text(perspective));
  });
}

Future<String> _linkTabInvite(WidgetTester tester, String flow) async {
  return _step(flow, 'link-tab', () async {
    final menu = find.byKey(const Key('family-menu'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    final invite = find.byKey(const Key('family-menu-invite'));
    await pumpUntilFound(tester, invite);
    await tester.ensureVisible(invite);
    await tester.tap(invite);
    final linkTab = find.byKey(const Key('invite-tab-link'));
    await pumpUntilFound(tester, linkTab);
    await tester.tap(linkTab);
    final someoneNew = find.byKey(const Key('invite-person-new'));
    await pumpUntilFound(tester, someoneNew);
    await tester.ensureVisible(someoneNew);
    await tester.tap(someoneNew);
    final link = find.byWidgetPredicate((widget) {
      if (widget.key != const Key('invite-link')) return false;
      final text = (widget as dynamic).controller?.text;
      return text is String &&
          (text.contains('invite=') || text.contains('/invite/'));
    });
    await pumpUntilFound(tester, link);
    return _controllerText(tester, link);
  });
}

String _controllerText(WidgetTester tester, Finder field) {
  final controller = (tester.widget(field) as dynamic).controller;
  final text = controller?.text;
  if (text is! String) {
    throw TestFailure('invite link field has no text');
  }
  return text.trim();
}

String _inviteLocation(String url) {
  final uri = Uri.parse(url);
  final token = uri.queryParameters['invite'];
  if ((token == null || token.isEmpty) && !uri.path.contains('/invite/')) {
    throw TestFailure('Link tab did not show an invite link');
  }
  if (!uri.hasScheme) return url;
  final path = uri.path.isEmpty ? '/' : uri.path;
  if (!uri.hasQuery) return path;
  return '$path?${uri.query}';
}

Future<void> _searchStory(
  WidgetTester tester,
  String flow, {
  required Story story,
  required String person,
}) async {
  await _step(flow, 'search', () async {
    final placeId = story.placeId;
    if (placeId == null || placeId.isEmpty || story.personIds.isEmpty) {
      throw TestFailure('published story is missing a person or place');
    }
    final open = find.byKey(const Key('timeline-search'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await pumpUntilFound(tester, find.byKey(const Key('search-field')));
    final placeChip = find.byKey(Key('search-suggest-place-$placeId'));
    await pumpUntilFound(tester, placeChip);
    final addPerson = find.byKey(const Key('search-add-person'));
    await tester.ensureVisible(addPerson);
    await tester.tap(addPerson);
    final personTile = find.text(person).hitTestable();
    await pumpUntilFound(tester, personTile);
    await tester.tap(personTile.last);
    await pumpUntilFound(
      tester,
      find.byKey(Key('search-filter-person-${story.personIds.first}')),
    );
    await tester.ensureVisible(placeChip);
    await tester.tap(placeChip);
    await pumpUntilFound(tester, find.byKey(const Key('search-filter-place')));
    final decade = find.byKey(const Key('search-add-decade'));
    await tester.ensureVisible(decade);
    await tester.tap(decade);
    final eighties = find.text('1980s').hitTestable();
    await pumpUntilFound(tester, eighties);
    await tester.tap(eighties);
    await pumpUntilFound(tester, find.byKey(const Key('search-filter-decade')));
    await pumpUntilFound(tester, find.byKey(Key('search-result-${story.id}')));
  });
}

Future<void> _untilOtherFamilySeesNoStory(
  WidgetTester tester, {
  required String storyId,
  required String title,
  required String body,
}) async {
  await pumpUntilFound(
    tester,
    find.descendant(
      of: find.byKey(const Key('story-reader-modal')),
      matching: find.text('Not found'),
    ),
  );
  expect(find.text('Try again'), findsNothing);
  expect(find.text(title), findsNothing);
  expect(find.text(body), findsNothing);
  expect(await StoriesApi().getPublished(storyId), isNull);
}

Future<void> _signOut(WidgetTester tester) async {
  await _step('C9', 'sign-out', () async {
    final avatar = find.byKey(const Key('header-avatar'));
    await tester.ensureVisible(avatar);
    await tester.tap(avatar);
    await pumpUntilFound(
      tester,
      find.byKey(const Key('header-menu-logout')).hitTestable(),
    );
    await tester.tap(find.byKey(const Key('header-menu-logout')).hitTestable());
    await pumpUntilFound(tester, find.byKey(const Key('magic-link-email')));
    expect(find.byKey(const Key('family-menu')), findsNothing);
    expect(_path(tester), '/');
  });
}

Future<void> _expectGuardedRedirect(WidgetTester tester, String route) async {
  _go(tester, route);
  final home = find.byWidgetPredicate((widget) {
    if (widget is! TellMeAStoryApp) return false;
    if (_path(tester) != '/') return false;
    if (find.byKey(const Key('family-menu')).evaluate().isNotEmpty) {
      return false;
    }
    if (find.byKey(const Key('settings-name')).evaluate().isNotEmpty) {
      return false;
    }
    if (find.byKey(const Key('search-field')).evaluate().isNotEmpty) {
      return false;
    }
    if (find.byKey(const Key('story-title')).evaluate().isNotEmpty) {
      return false;
    }
    return find.byKey(const Key('magic-link-email')).evaluate().isNotEmpty;
  });
  await pumpUntilFound(tester, home);
  expect(find.byKey(const Key('magic-link-email')), findsOneWidget);
  expect(_path(tester), '/');
}
