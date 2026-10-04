import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/data/timeline_live.dart';
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
    String? title,
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
    String? title,
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

class _FakeFamilies implements FamiliesGateway {
  _FakeFamilies(this.rows);

  final List<MemberFamily> rows;

  @override
  Future<List<MemberFamily>> listMine() async => rows;
}

class _FakeLive implements TimelineLive {
  void Function()? onChange;
  String? familyId;

  @override
  void watch({required String familyId, required void Function() onChange}) {
    this.familyId = familyId;
    this.onChange = onChange;
  }

  @override
  void dispose() {}

  void emit() => onChange?.call();
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
  String? title,
  String? body = 'Jam',
  DateTime? timeframeStart,
  DateTime? timeframeEnd,
}) {
  return Story(
    id: id,
    familyId: familyId,
    authorId: 'u1',
    title: title,
    body: body,
    timeframeStart: timeframeStart ?? DateTime(1980, 1, 1),
    timeframeEnd: timeframeEnd ?? DateTime(1989, 12, 31),
    placeId: 'pl',
    status: StoryStatus.published,
    personIds: const ['p'],
    publishedAt: DateTime(2026, 9, 27),
  );
}

Widget _timeline({
  required StoriesGateway stories,
  ThemeData? theme,
  FamiliesGateway? families,
  TimelineLive? live,
}) {
  return MaterialApp(
    theme: theme,
    home: TimelinePage(
      api: _FakeInviteApi(),
      storiesApi: stories,
      familiesApi: families,
      live: live,
    ),
  );
}

String _tooltipFor(WidgetTester tester, String storyId) {
  return tester
          .widget<Tooltip>(
            find.ancestor(
              of: find.byKey(Key('timeline-dot-$storyId')),
              matching: find.byType(Tooltip),
            ),
          )
          .message ??
      '';
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

  testWidgets('published story preview appears after listPublished', (
    tester,
  ) async {
    await tester.pumpWidget(
      _timeline(stories: _FakeStoriesApi(published: [_published()])),
    );
    await tester.pumpAndSettle();

    expect(_tooltipFor(tester, 's1'), 'Untitled (1980)');
    expect(find.text('Jam'), findsNothing);
    expect(find.text('1980s'), findsOneWidget);
  });

  testWidgets('timeline card prefers a saved title', (tester) async {
    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(
          published: [
            _published(
              title: 'Making Blackberry Jam on the Back Porch',
              body: 'We spent the afternoon.',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _tooltipFor(tester, 's1'),
      'Making Blackberry Jam on the Back Porch (1980)',
    );
    expect(find.text('We spent the afternoon.'), findsNothing);
  });

  testWidgets('loading published shows small progress', (tester) async {
    await tester.pumpWidget(_timeline(stories: _SlowStoriesApi()));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('far header has New story, Invite, and Drafts in More', (
    tester,
  ) async {
    await tester.pumpWidget(_timeline(stories: _FakeStoriesApi(published: [])));
    await tester.pumpAndSettle();

    expect(find.text('New story'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('Tell Me a Story'), findsOneWidget);
    expect(find.byKey(const Key('timeline-search')), findsOneWidget);

    await tester.tap(find.byKey(const Key('timeline-more')));
    await tester.pumpAndSettle();
    expect(find.text('Drafts'), findsOneWidget);
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
    expect(find.text('Invite'), findsOneWidget);
  });

  testWidgets('returning to timeline after publish reloads published list', (
    tester,
  ) async {
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

    stories.published.add(_published(familyId: _familyId, title: 'Jam'));

    router.go(AppRoutes.timeline);
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .any((tip) => tip.message?.contains('Jam') ?? false),
      isTrue,
    );
    expect(
      find.text('No stories yet. Capture the first one for this family.'),
      findsNothing,
    );

    auth.dispose();
  });

  testWidgets('tapping a published card pushes the story reader', (
    tester,
  ) async {
    final story = _published(title: 'Jam');
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: _FakeInviteApi(),
      storiesApi: _FakeStoriesApi(published: [story]),
    );

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    expect(_tooltipFor(tester, story.id), contains('Jam'));

    await tester.tap(find.byKey(Key('timeline-dot-${story.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Mid'), findsOneWidget);
    expect(find.text('Zoom Level: 45% (Stubs & Eras)'), findsOneWidget);

    await tester.tap(find.byKey(Key('timeline-stub-${story.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Currently Focused'), findsOneWidget);
    expect(find.textContaining('photos · '), findsOneWidget);

    await tester.tap(find.byKey(Key('timeline-card-${story.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('story-reader')), findsOneWidget);
    final locations = router.routerDelegate.currentConfiguration.matches
        .map((m) => m.matchedLocation)
        .toList();
    expect(locations, contains(AppRoutes.storyPath(story.id)));

    auth.dispose();
  });

  testWidgets('Fit returns to the constellation from mid', (tester) async {
    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(published: [_published(title: 'Jam')]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-dot-s1')));
    await tester.pumpAndSettle();
    expect(find.text('Mid-1970s to Mid-1980s Era'), findsOneWidget);

    await tester.tap(find.byKey(const Key('timeline-fit')));
    await tester.pumpAndSettle();
    expect(find.text('Family Archive Constellation'), findsOneWidget);
    expect(find.text('Fit'), findsOneWidget);
  });

  testWidgets('a draft in the gateway list stays off the rail', (tester) async {
    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(
          published: [
            _published(title: 'Jam'),
            Story(
              id: 'draft-1',
              familyId: _familyId,
              authorId: 'u1',
              title: 'Secret draft',
              body: 'hidden',
              timeframeStart: DateTime(1990, 1, 1),
              status: StoryStatus.draft,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1990s'), findsNothing);
    expect(find.text('Secret draft'), findsNothing);
  });

  testWidgets('branch chrome appears only when a child family is visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(published: [_published(title: 'Jam')]),
        families: _FakeFamilies([
          MemberFamily(
            id: _familyId,
            name: 'Jenkins',
            createdAt: DateTime.utc(1970),
          ),
          MemberFamily(
            id: 'child',
            name: 'Martinez',
            parentFamilyId: _familyId,
            createdAt: DateTime.utc(1985),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Martinez branch'), findsOneWidget);

    await tester.tap(find.byKey(const Key('timeline-dot-s1')));
    await tester.pumpAndSettle();
    expect(find.text('Martinez Branch'), findsOneWidget);
    expect(find.text('← Martinez union joined archive'), findsOneWidget);

    await tester.tap(find.byKey(const Key('timeline-stub-s1')));
    await tester.pumpAndSettle();
    expect(
      find.text('Martinez branch fork & merge indicator active'),
      findsOneWidget,
    );
  });

  testWidgets('a published live event adds a dot', (tester) async {
    final stories = _FakeStoriesApi(published: []);
    final live = _FakeLive();
    await tester.pumpWidget(_timeline(stories: stories, live: live));
    await tester.pumpAndSettle();
    expect(
      find.text('No stories yet. Capture the first one for this family.'),
      findsOneWidget,
    );

    stories.published.add(_published(title: 'Jam'));
    live.emit();
    await tester.pumpAndSettle();
    expect(_tooltipFor(tester, 's1'), contains('Jam'));
  });

  test('other-family and draft events do not refresh the rail', () {
    expect(
      timelineEventMatters(
        familyId: _familyId,
        table: 'stories',
        eventFamilyId: 'other',
        status: 'published',
        isDelete: false,
      ),
      isFalse,
    );
    expect(
      timelineEventMatters(
        familyId: _familyId,
        table: 'stories',
        eventFamilyId: _familyId,
        status: 'draft',
        isDelete: false,
      ),
      isFalse,
    );
    expect(
      timelineEventMatters(
        familyId: _familyId,
        table: 'stories',
        eventFamilyId: _familyId,
        status: 'published',
        isDelete: false,
      ),
      isTrue,
    );
  });
}
