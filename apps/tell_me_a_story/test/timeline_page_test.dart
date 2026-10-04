import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/core/theme/album_header.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/data/timeline_live.dart';
import 'package:tell_me_a_story/features/invites/invite_modal.dart';
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

class _RecordingStories extends _FakeStoriesApi {
  _RecordingStories({super.published});

  final loads = <String>[];

  @override
  Future<List<Story>> listPublished(String familyId) async {
    loads.add(familyId);
    return super.listPublished(familyId);
  }
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
  String? placeLabel,
  List<String> personNames = const [],
  int photoCount = 0,
  int commentCount = 0,
  List<String> photoPaths = const [],
  String? authorDisplayName,
}) {
  return Story(
    id: id,
    familyId: familyId,
    authorId: 'u1',
    title: title,
    body: body,
    timeframeStart: timeframeStart ?? DateTime(1980, 1, 1),
    timeframeEnd: timeframeEnd ?? DateTime(1989, 12, 31),
    placeId: placeLabel == null ? 'pl' : 'pl',
    status: StoryStatus.published,
    personIds: const ['p'],
    placeLabel: placeLabel,
    personNames: personNames,
    photoCount: photoCount,
    commentCount: commentCount,
    photoPaths: photoPaths,
    authorDisplayName: authorDisplayName,
    publishedAt: DateTime(2026, 9, 27),
  );
}

Widget _timeline({
  required StoriesGateway stories,
  ThemeData? theme,
  FamiliesGateway? families,
  TimelineLive? live,
  PhotosGateway? photos,
}) {
  return MaterialApp(
    theme: theme,
    home: TimelinePage(
      api: _FakeInviteApi(),
      storiesApi: stories,
      familiesApi: families,
      live: live,
      photosApi: photos,
    ),
  );
}

class _FakePhotos implements PhotosGateway {
  static final _png = Uint8List.fromList(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);

  @override
  Future<void> deleteAllForStory({
    required String familyId,
    required String storyId,
  }) async {}

  @override
  Future<void> deletePhoto(Photo photo) async {}

  @override
  Future<Uint8List> downloadBytes(String storagePath) async => _png;

  @override
  Future<List<Photo>> listPhotos(String storyId) async => const [];

  @override
  Future<Photo> uploadPhoto({
    required String familyId,
    required String storyId,
    required Uint8List bytes,
    required int sortOrder,
  }) {
    throw UnimplementedError();
  }
}

Future<void> _openFullCards(WidgetTester tester, String storyId) async {
  await tester.tap(find.byKey(Key('timeline-dot-$storyId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('timeline-stub-$storyId')));
  await tester.pumpAndSettle();
}

void _pinch(WidgetTester tester, double scale) {
  final detector = tester.widget<GestureDetector>(
    find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onScaleUpdate != null,
    ),
  );
  detector.onScaleStart?.call(
    ScaleStartDetails(
      focalPoint: Offset.zero,
      localFocalPoint: Offset.zero,
      pointerCount: 2,
    ),
  );
  detector.onScaleUpdate?.call(
    ScaleUpdateDetails(
      focalPoint: Offset.zero,
      localFocalPoint: Offset.zero,
      scale: scale,
      horizontalScale: scale,
      verticalScale: scale,
      pointerCount: 2,
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

  testWidgets('shared header shows Invite, New story, and Drafts', (
    tester,
  ) async {
    await tester.pumpWidget(_timeline(stories: _FakeStoriesApi(published: [])));
    await tester.pumpAndSettle();

    expect(find.text('Tell Me a Story'), findsOneWidget);
    expect(find.text('Timeline'), findsWidgets);
    expect(find.text('Drafts'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('New story'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.byKey(const Key('timeline-search')), findsOneWidget);
    expect(find.byKey(const Key('header-underline-timeline')), findsOneWidget);
    expect(find.text('Save draft'), findsNothing);
    expect(find.text('Publish'), findsNothing);
    expect(find.text('Stories'), findsNothing);
    expect(find.text('Family Members'), findsNothing);
    expect(find.text('Places'), findsNothing);
    expect(find.text('Help'), findsNothing);
    expect(find.byKey(const Key('timeline-more')), findsNothing);
  });

  testWidgets('album AppBar fits at 320px without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(published: []),
        theme: albumTheme(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('timeline-search')), findsOneWidget);
    expect(find.text('Drafts'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('New story'), findsOneWidget);
  });

  testWidgets('1px layout pass does not overflow the timeline column', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1, 1));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(published: [_published(title: 'Jam')]),
        theme: albumTheme(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('above 320 the search chip shrinks before the wordmark', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1370, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(published: []),
        theme: albumTheme(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.renderObject<RenderBox>(find.byType(AlbumHeader)).size.height,
      72,
    );
    expect(
      tester.widget<Text>(find.text('Tell Me a Story')).style?.fontSize,
      24,
    );
    expect(
      tester.renderObject<RenderBox>(find.text('Tell Me a Story')).size.width,
      greaterThan(300),
    );
    final search = tester
        .renderObject<RenderBox>(find.byKey(const Key('timeline-search')))
        .size
        .width;
    expect(search, lessThan(224));
    expect(search, greaterThan(100));
  });

  testWidgets('family switch reloads that family and Invite uses it', (
    tester,
  ) async {
    addTearDown(FamilySelection.clear);
    const otherId = '00000000-0000-0000-0000-000000000002';
    final stories = _RecordingStories(published: [_published(title: 'Jam')]);
    final live = _FakeLive();
    await tester.pumpWidget(
      _timeline(
        stories: stories,
        live: live,
        families: _FakeFamilies([
          MemberFamily(
            id: _familyId,
            name: 'Ada',
            createdAt: DateTime.utc(2020),
          ),
          MemberFamily(id: otherId, name: 'Bea', createdAt: DateTime.utc(2021)),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(live.familyId, _familyId);
    expect(stories.loads, [_familyId]);

    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bea').last);
    await tester.pumpAndSettle();

    expect(stories.loads.last, otherId);
    expect(live.familyId, otherId);
    expect(find.byKey(const Key('timeline-dot-s1')), findsNothing);

    await tester.tap(find.byKey(const Key('header-invite')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<InviteModal>(find.byType(InviteModal)).familyId,
      otherId,
    );
  });

  testWidgets('Drafts and New story leave the timeline', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.timeline,
      routes: [
        GoRoute(
          path: AppRoutes.timeline,
          builder: (context, state) => TimelinePage(
            api: _FakeInviteApi(),
            storiesApi: _FakeStoriesApi(published: []),
          ),
        ),
        GoRoute(
          path: AppRoutes.drafts,
          builder: (context, state) => const Text('drafts-screen'),
        ),
        GoRoute(
          path: AppRoutes.newStory,
          builder: (context, state) => const Text('new-story-screen'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Drafts'));
    await tester.pumpAndSettle();
    expect(find.text('drafts-screen'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('New story'));
    await tester.pumpAndSettle();
    expect(find.text('new-story-screen'), findsOneWidget);
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
    expect(find.text('Zoom Level: 100% (Full Cards)'), findsOneWidget);
    expect(find.text('Jam'), findsOneWidget);
    expect(find.text('Currently Focused'), findsNothing);
    expect(find.text('Family Archive · Near Zoom View'), findsNothing);
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

  test('full cards fade with the same band as the far rail', () {
    const viewportHeight = 400.0;
    const band = viewportHeight * farFadeBand;

    expect(
      fullCardOpacity(
        rowTop: viewportHeight / 2 - 40,
        rowHeight: 80,
        viewportTop: 0,
        viewportHeight: viewportHeight,
      ),
      1,
    );
    expect(
      fullCardOpacity(
        rowTop: -40,
        rowHeight: 80,
        viewportTop: 0,
        viewportHeight: viewportHeight,
      ),
      0,
    );
    expect(
      fullCardOpacity(
        rowTop: band / 2 - 40,
        rowHeight: 80,
        viewportTop: 0,
        viewportHeight: viewportHeight,
      ),
      closeTo(0.5, 0.001),
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
    expect(find.text('Martinez Branch'), findsNothing);
    expect(find.text('← Martinez union joined archive'), findsNothing);
    expect(
      find.text('Martinez branch fork & merge indicator active'),
      findsNothing,
    );
    expect(find.byKey(const Key('timeline-spine')), findsOneWidget);
  });

  testWidgets('search chip opens /search on far, mid, and near', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: AppRoutes.timeline,
      routes: [
        GoRoute(
          path: AppRoutes.timeline,
          builder: (context, state) => TimelinePage(
            api: _FakeInviteApi(),
            storiesApi: _FakeStoriesApi(published: [_published(title: 'Jam')]),
          ),
        ),
        GoRoute(
          path: AppRoutes.search,
          builder: (context, state) => const Text('search-screen'),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: albumTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    Future<void> openAndBack() async {
      expect(find.byKey(const Key('timeline-search')), findsOneWidget);
      expect(find.text('Search archive...'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('timeline-search')));
      await tester.tap(find.byKey(const Key('timeline-search')));
      await tester.pumpAndSettle();
      expect(find.text('search-screen'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
    }

    await openAndBack();
    await tester.tap(find.byKey(const Key('timeline-dot-s1')));
    await tester.pumpAndSettle();
    await openAndBack();
    await tester.tap(find.byKey(const Key('timeline-stub-s1')));
    await tester.pumpAndSettle();
    await openAndBack();
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

  testWidgets('full cards list the whole family newest first', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const body = 'secret body line';
    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(
          published: [
            _published(
              id: 'wagon',
              title: 'Wagon',
              body: body,
              timeframeStart: DateTime(1989),
            ),
            _published(
              id: 'lawn',
              title: 'Lawn',
              body: body,
              timeframeStart: DateTime(1990),
            ),
            _published(
              id: 'canning',
              title: 'Canning',
              body: body,
              timeframeStart: DateTime(1991),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openFullCards(tester, 'lawn');

    expect(
      tester.getTopLeft(find.text('Canning')).dy,
      lessThan(tester.getTopLeft(find.text('Wagon')).dy),
    );
    expect(find.text(body), findsNothing);
  });

  testWidgets('a blank title stays Untitled on a full card', (tester) async {
    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(
          published: [
            _published(
              id: 'blank',
              title: null,
              body: 'First line of the body',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openFullCards(tester, 'blank');
    expect(find.text('Untitled'), findsWidgets);
    expect(find.text('First line of the body'), findsNothing);
  });

  testWidgets('full cards show people and place chips from stored fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(
          published: [
            _published(
              id: 'placed',
              title: 'Lawn',
              personNames: const ['Aunt Clara', 'Uncle Arthur'],
              placeLabel: 'University Lawn',
            ),
            _published(id: 'plain', title: 'Wagon'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openFullCards(tester, 'placed');
    expect(find.text('Aunt Clara'), findsOneWidget);
    expect(find.text('Uncle Arthur'), findsOneWidget);
    expect(find.text('University Lawn'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('timeline-card-plain')),
        matching: find.byIcon(Icons.location_on),
      ),
      findsNothing,
    );
  });

  testWidgets('the viewport center card is sharp and carries the byline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(
          published: [
            _published(
              id: 'early',
              title: 'Wagon',
              timeframeStart: DateTime(1989),
              authorDisplayName: 'Aunt Sarah',
            ),
            _published(
              id: 'mid',
              title: 'Lawn',
              timeframeStart: DateTime(1990),
              authorDisplayName: 'Aunt Sarah',
            ),
            _published(
              id: 'late',
              title: 'Canning',
              timeframeStart: DateTime(1991),
              authorDisplayName: 'Aunt Sarah',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openFullCards(tester, 'mid');

    double opacityFor(String id) {
      return tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byKey(Key('timeline-card-$id')),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
    }

    expect(opacityFor('mid'), greaterThan(opacityFor('late')));
    expect(opacityFor('mid'), greaterThan(opacityFor('early')));
    expect(find.text('Added by Aunt Sarah'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('timeline-card-late')),
        matching: find.textContaining('Added by'),
      ),
      findsNothing,
    );
  });

  testWidgets('the center card paints the first photo and the stored count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _timeline(
        photos: _FakePhotos(),
        stories: _FakeStoriesApi(
          published: [
            _published(
              id: 'lawn',
              title: 'Lawn',
              photoCount: 4,
              commentCount: 1,
              photoPaths: const ['families/a.jpg', 'families/b.jpg'],
            ),
            _published(id: 'plain', title: 'Wagon', photoCount: 0),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openFullCards(tester, 'lawn');

    expect(
      find.descendant(
        of: find.byKey(const Key('timeline-card-lawn')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(find.text('4 photos · 1 note'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('timeline-card-plain')),
        matching: find.byType(Image),
      ),
      findsNothing,
    );
  });

  testWidgets('full cards drop the zoom cluster and stay on one line at 320', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    await _openFullCards(tester, 's1');
    await tester.binding.setSurfaceSize(const Size(320, 640));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Zoom Level: 100% (Full Cards)'), findsOneWidget);
    expect(find.text('Macro'), findsOneWidget);
    expect(find.text('Mid'), findsOneWidget);
    expect(find.text('Full Cards'), findsOneWidget);
    expect(find.byKey(const Key('timeline-zoom-in')), findsNothing);
    expect(find.byKey(const Key('timeline-fit')), findsNothing);
    expect(find.textContaining('union joined archive'), findsNothing);
    expect(find.textContaining('Branch'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            (widget.painter?.runtimeType.toString().contains('Dash') ?? false),
      ),
      findsNothing,
    );

    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-zoom-macro')));
    await tester.pumpAndSettle();
    expect(find.text('CONTINUOUS FAMILY DIAL'), findsOneWidget);
    expect(find.text('MARTINEZ BRANCH'), findsOneWidget);
  });

  testWidgets('pinch uses the existing handler and the 0.5 reveal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _timeline(
        stories: _FakeStoriesApi(published: [_published(title: 'Jam')]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-dot-s1')));
    await tester.pumpAndSettle();

    _pinch(tester, 1.1);
    await tester.pumpAndSettle();
    expect(find.text('Zoom Level: 100% (Full Cards)'), findsOneWidget);

    final card = find.byKey(const Key('timeline-card-s1'));
    final scrollable = find
        .ancestor(of: card, matching: find.byType(Scrollable))
        .first;
    final delta =
        (tester.getRect(card).center.dy - tester.getRect(scrollable).center.dy)
            .abs();
    expect(delta, lessThan(48));

    _pinch(tester, 0.9);
    await tester.pumpAndSettle();
    expect(find.text('Continuous Family Dial'), findsOneWidget);
    expect(find.text('Zoom Level: 100% (Full Cards)'), findsNothing);
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
