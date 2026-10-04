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
import 'package:tell_me_a_story/features/timeline/timeline_zoom.dart';

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

  testWidgets('far header has Publish, Save draft, and Drafts in More', (
    tester,
  ) async {
    await tester.pumpWidget(_timeline(stories: _FakeStoriesApi(published: [])));
    await tester.pumpAndSettle();

    expect(find.text('Publish'), findsOneWidget);
    expect(find.text('Save draft'), findsOneWidget);
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
    expect(find.text('Publish'), findsOneWidget);
    expect(find.text('Save draft'), findsOneWidget);
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
    expect(find.text('Continuous Family Dial'), findsOneWidget);
    expect(find.text('1980 · IN FOCUS'), findsOneWidget);
    expect(find.text('Mid'), findsOneWidget);
    expect(find.text('Zoom Level: 45% (Stubs & Eras)'), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.timeline,
    );

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
    expect(find.text('Continuous Family Dial'), findsOneWidget);
    expect(find.text('1980 · IN FOCUS'), findsOneWidget);
    expect(find.text('Mid-1980s'), findsNothing);

    await tester.tap(find.byKey(const Key('timeline-fit')));
    await tester.pumpAndSettle();
    expect(find.text('CONTINUOUS FAMILY DIAL'), findsOneWidget);
    expect(find.text('1980s · IN FOCUS'), findsOneWidget);
    expect(find.textContaining('Far (Decade dots)'), findsOneWidget);
    expect(find.text('Fit all'), findsWidgets);
  });

  testWidgets('mid dial keeps the center year sharp and fades the edges', (
    tester,
  ) async {
    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(
          published: [
            _published(
              id: 'early',
              title: 'Arrival',
              timeframeStart: DateTime(1954),
            ),
            _published(id: 'mid', title: 'Jam', timeframeStart: DateTime(1980)),
            _published(
              id: 'late',
              title: 'Willow',
              timeframeStart: DateTime(2024),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('2020s')).dy,
      lessThan(tester.getTopLeft(find.text('1950s')).dy),
    );
    double decadeOpacity(String label) {
      return tester
          .widget<Opacity>(
            find
                .ancestor(of: find.text(label), matching: find.byType(Opacity))
                .first,
          )
          .opacity;
    }

    expect(decadeOpacity('1980s'), 1);
    expect(decadeOpacity('2020s'), lessThan(1));
    expect(decadeOpacity('1950s'), lessThan(1));
    expect(find.text('Jam (1980)'), findsNothing);
    expect(_tooltipFor(tester, 'mid'), 'Jam (1980)');
    await tester.tap(find.byKey(const Key('timeline-dot-mid')));
    await tester.pumpAndSettle();

    expect(find.text('Continuous Family Dial'), findsOneWidget);
    expect(find.text('1980 · IN FOCUS'), findsOneWidget);
    expect(find.text('DIAL CENTER'), findsNothing);
    expect(find.text('Mid-1980s to Mid-1990s Era'), findsNothing);

    double opacityFor(String id) {
      return tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byKey(Key('timeline-stub-$id')),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
    }

    expect(opacityFor('mid') > opacityFor('early'), isTrue);
    expect(opacityFor('mid') > opacityFor('late'), isTrue);
    expect(find.byKey(const Key('timeline-stub-mid')), findsOneWidget);
  });

  test('a far decade dims before it reaches the viewport edge', () {
    const viewportHeight = 400.0;
    final band = viewportHeight * farFadeBand;

    expect(
      farEdgeOpacity(
        rowTop: viewportHeight / 2 - 40,
        rowHeight: 80,
        viewportTop: 0,
        viewportHeight: viewportHeight,
      ),
      1,
    );
    expect(
      farEdgeOpacity(
        rowTop: 30,
        rowHeight: 80,
        viewportTop: 0,
        viewportHeight: viewportHeight,
      ),
      closeTo(70 / band, 0.001),
    );
    expect(
      farEdgeOpacity(
        rowTop: viewportHeight - 110,
        rowHeight: 80,
        viewportTop: 0,
        viewportHeight: viewportHeight,
      ),
      closeTo(70 / band, 0.001),
    );
    expect(70 / band, lessThan(0.6));
    expect(
      farEdgeOpacity(
        rowTop: -120,
        rowHeight: 80,
        viewportTop: 0,
        viewportHeight: viewportHeight,
      ),
      0,
    );
  });

  testWidgets('a far decade fades as it leaves and sharpens when it returns', (
    tester,
  ) async {
    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(
          published: [
            _published(
              id: 'early',
              title: 'Arrival',
              timeframeStart: DateTime(1954),
            ),
            _published(id: 'mid', title: 'Jam', timeframeStart: DateTime(1980)),
            _published(
              id: 'late',
              title: 'Willow',
              timeframeStart: DateTime(2024),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    double decadeOpacity(String label) {
      return tester
          .widget<Opacity>(
            find
                .ancestor(of: find.text(label), matching: find.byType(Opacity))
                .first,
          )
          .opacity;
    }

    final scrollable = find
        .ancestor(of: find.text('2020s'), matching: find.byType(Scrollable))
        .first;
    final view = tester.renderObject<RenderBox>(scrollable);
    final row = tester.renderObject<RenderBox>(
      find
          .ancestor(of: find.text('2020s'), matching: find.byType(Opacity))
          .first,
    );
    final slack =
        row.localToGlobal(Offset.zero).dy - view.localToGlobal(Offset.zero).dy;
    expect(slack, greaterThan(0));
    final homeOpacity = decadeOpacity('2020s');

    final position = tester.state<ScrollableState>(scrollable).position;
    final home = position.pixels;
    position.jumpTo(home + slack + row.size.height / 2);
    await tester.pumpAndSettle();

    final leaving = tester.renderObject<RenderBox>(
      find
          .ancestor(of: find.text('2020s'), matching: find.byType(Opacity))
          .first,
    );
    final leavingView = tester.renderObject<RenderBox>(scrollable);
    final expected = farEdgeOpacity(
      rowTop: leaving.localToGlobal(Offset.zero).dy,
      rowHeight: leaving.size.height,
      viewportTop: leavingView.localToGlobal(Offset.zero).dy,
      viewportHeight: leavingView.size.height,
    );
    expect(expected, lessThan(homeOpacity));
    expect(decadeOpacity('2020s'), closeTo(expected, 0.02));

    position.jumpTo(home);
    await tester.pumpAndSettle();
    expect(decadeOpacity('2020s'), closeTo(homeOpacity, 0.02));
  });

  testWidgets('oldest published story can sit at the dial center', (
    tester,
  ) async {
    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(
          published: [
            _published(
              id: 'early',
              title: 'Arrival',
              timeframeStart: DateTime(1954),
            ),
            _published(id: 'mid', title: 'Jam', timeframeStart: DateTime(1980)),
            _published(
              id: 'late',
              title: 'Willow',
              timeframeStart: DateTime(2024),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-dot-early')));
    await tester.pumpAndSettle();

    final early = find.byKey(const Key('timeline-stub-early'));
    final row = tester.renderObject<RenderBox>(
      find.ancestor(of: early, matching: find.byType(Opacity)).first,
    );
    final view = tester.renderObject<RenderBox>(
      find.ancestor(of: early, matching: find.byType(Scrollable)).first,
    );
    final rowMid = row.localToGlobal(row.size.center(Offset.zero)).dy;
    final viewMid = view.localToGlobal(view.size.center(Offset.zero)).dy;
    expect((rowMid - viewMid).abs(), lessThan(1.5));
    expect(find.text('1954 · IN FOCUS'), findsOneWidget);

    final earlyTop = tester.getTopLeft(early).dy;
    final lateTop = tester
        .getTopLeft(find.byKey(const Key('timeline-stub-late')))
        .dy;
    expect(lateTop, lessThan(earlyTop));
  });

  testWidgets('mid stubs and near cards show the title without the body', (
    tester,
  ) async {
    const body = 'We spent the afternoon stirring the pot.';
    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(
          published: [_published(id: 's1', title: 'title2', body: body)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-dot-s1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('title2'), findsOneWidget);
    expect(find.text(body), findsNothing);

    await tester.tap(find.byKey(const Key('timeline-stub-s1')));
    await tester.pumpAndSettle();
    expect(find.text('title2'), findsOneWidget);
    expect(find.text(body), findsNothing);
  });

  testWidgets('mid branch rail runs from the join toward newer stories', (
    tester,
  ) async {
    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(
          published: [
            _published(
              id: 'early',
              title: 'Arrival',
              timeframeStart: DateTime(1954),
            ),
            _published(id: 'mid', title: 'Jam', timeframeStart: DateTime(1980)),
            _published(
              id: 'late',
              title: 'Willow',
              timeframeStart: DateTime(2024),
            ),
          ],
        ),
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
    await tester.tap(find.byKey(const Key('timeline-dot-mid')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-branch-late')), findsOneWidget);
    expect(find.byKey(const Key('timeline-branch-mid')), findsOneWidget);
    expect(find.byKey(const Key('timeline-branch-early')), findsNothing);
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
    expect(find.text('MARTINEZ BRANCH'), findsOneWidget);
    expect(find.text('← Martinez union joined archive'), findsOneWidget);

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
