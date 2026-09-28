import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/timeline/timeline_page.dart';

const _familyId = '00000000-0000-0000-0000-000000000001';

class _FakeInviteApi implements InviteGateway {
  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    return const AcceptInviteResult(familyId: 'f', membershipId: 'm');
  }

  @override
  Future<String> createFamily(String name) async => _familyId;

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String?> currentFamilyId() async => _familyId;

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {}
}

class _FakeStoriesApi implements StoriesGateway {
  _FakeStoriesApi({List<Story>? published}) : published = [...?published];

  final List<Story> published;

  @override
  Future<Story> createDraft({
    required String familyId,
    required DateTime timeframeStart,
    DateTime? timeframeEnd,
    String? body,
    String? placeId,
    List<String> personIds = const [],
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Story> updateDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Story> publish(String storyId) {
    throw UnimplementedError();
  }

  @override
  Future<Story> getStory(String storyId) {
    throw UnimplementedError();
  }

  @override
  Future<Story?> getPublished(String storyId) async {
    for (final s in published) {
      if (s.id == storyId && s.status == StoryStatus.published) return s;
    }
    return null;
  }

  @override
  Future<List<Story>> listMyDrafts(String familyId) async => const [];

  @override
  Future<List<Story>> listPublished(String familyId) async {
    return published.where((s) => s.familyId == familyId).toList();
  }

  @override
  Future<void> discard(String storyId) async {}
}

class _SlowStoriesApi extends _FakeStoriesApi {
  _SlowStoriesApi() {
    _pending = Completer<List<Story>>();
  }

  late final Completer<List<Story>> _pending;

  @override
  Future<List<Story>> listPublished(String familyId) => _pending.future;
}

Story _published({
  String id = 's1',
  String familyId = _familyId,
  String? body = 'Jam',
  DateTime? timeframeStart,
  DateTime? timeframeEnd,
}) {
  return Story(
    id: id,
    familyId: familyId,
    authorId: 'u1',
    body: body,
    timeframeStart: timeframeStart ?? DateTime(1980, 1, 1),
    timeframeEnd: timeframeEnd ?? DateTime(1989, 12, 31),
    placeId: 'pl',
    status: StoryStatus.published,
    personIds: const ['p'],
    publishedAt: DateTime(2026, 9, 27),
  );
}

Widget _timeline({required StoriesGateway stories, ThemeData? theme}) {
  return MaterialApp(
    theme: theme,
    home: TimelinePage(
      api: _FakeInviteApi(),
      storiesApi: stories,
    ),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  testWidgets('empty published list shows locked empty copy', (tester) async {
    await tester.pumpWidget(_timeline(stories: _FakeStoriesApi(published: [])));
    await tester.pumpAndSettle();

    expect(
      find.text('No stories yet. Capture the first one for this family.'),
      findsOneWidget,
    );
    expect(find.text('Timeline'), findsWidgets);
  });

  testWidgets('published story preview appears after listPublished',
      (tester) async {
    await tester.pumpWidget(
      _timeline(stories: _FakeStoriesApi(published: [_published()])),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Jam'), findsOneWidget);
    expect(find.text('1980s'), findsOneWidget);
  });

  testWidgets('loading published shows small progress', (tester) async {
    await tester.pumpWidget(_timeline(stories: _SlowStoriesApi()));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AppBar actions are New story, Drafts, + Invite', (tester) async {
    await tester.pumpWidget(_timeline(stories: _FakeStoriesApi(published: [])));
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<TextButton>(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(TextButton),
          ),
        )
        .map((button) => (button.child as Text).data)
        .toList();
    expect(labels, ['New story', 'Drafts', '+ Invite']);
  });

  testWidgets('album AppBar fits at 320px without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(published: []),
        theme: albumTheme(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('New story'), findsOneWidget);
    expect(find.text('Drafts'), findsOneWidget);
    expect(find.text('+ Invite'), findsOneWidget);
  });

  testWidgets(
    'returning to timeline after publish reloads published list',
    (tester) async {
      final stories = _FakeStoriesApi(published: []);
      final auth = AuthRefresh(initiallySignedIn: true);
      final router = createAppRouter(
        authRefresh: auth,
        inviteApi: _FakeInviteApi(),
        storiesApi: stories,
      );

      await tester.pumpWidget(TellMeAStoryApp(router: router));
      await tester.pumpAndSettle();

      expect(
        find.text('No stories yet. Capture the first one for this family.'),
        findsOneWidget,
      );

      router.push(AppRoutes.drafts);
      await tester.pumpAndSettle();

      stories.published.add(_published(familyId: _familyId));

      router.go(AppRoutes.timeline);
      await tester.pumpAndSettle();

      expect(find.textContaining('Jam'), findsOneWidget);
      expect(
        find.text('No stories yet. Capture the first one for this family.'),
        findsNothing,
      );

      auth.dispose();
    },
  );

  testWidgets('tapping a published card pushes the story reader',
      (tester) async {
    final story = _published();
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: _FakeInviteApi(),
      storiesApi: _FakeStoriesApi(published: [story]),
    );

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    expect(find.textContaining('Jam'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);

    await tester.tap(find.byType(Card));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('story-reader')), findsOneWidget);
    final locations = router.routerDelegate.currentConfiguration.matches
        .map((m) => m.matchedLocation)
        .toList();
    expect(locations, contains(AppRoutes.storyPath(story.id)));

    auth.dispose();
  });
}
