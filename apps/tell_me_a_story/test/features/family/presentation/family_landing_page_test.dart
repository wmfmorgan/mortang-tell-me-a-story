import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/widgets/album/album_header.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_date_precision.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';
import 'package:tell_me_a_story/core/domain/story_thumbs.dart';
import 'package:tell_me_a_story/features/family/presentation/family_landing_page.dart';

import '../../../support/fakes/fake_stories_repository.dart';
import '../../../support/pump_app.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('empty week keeps the hero and no all-stories button', (
    tester,
  ) async {
    await _pump(tester, role: 'member', stories: const []);

    expect(find.byKey(const Key('family-landing')), findsOneWidget);
    expect(find.byKey(const Key('family-landing-hero')), findsOneWidget);
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('Added in the past 7 days.'), findsOneWidget);
    expect(find.text('No stories added in the past 7 days.'), findsOneWidget);
    expect(find.byKey(const Key('family-landing-view-all')), findsNothing);
    expect(find.textContaining('View all stories'), findsNothing);
    expect(find.byKey(const Key('family-landing-hero-edit')), findsNothing);
    expect(find.text('Add a family photo'), findsNothing);
    expect(find.text('Featured'), findsNothing);
    expect(find.text('Oldest'), findsNothing);
    expect(find.text('Untitled'), findsNothing);
    expect(find.byKey(const Key('header-underline-stories')), findsNothing);
  });

  testWidgets('Stories from Landing opens the timeline underlined', (
    tester,
  ) async {
    await _pump(tester, role: 'member', stories: const []);
    await tester.tap(find.byKey(const Key('header-nav-stories')));
    await tester.pumpAndSettle();
    expect(find.text('all-stories-page'), findsOneWidget);
    expect(find.byKey(const Key('header-underline-stories')), findsOneWidget);
  });

  testWidgets('owner and co-owner see the camera; a member does not', (
    tester,
  ) async {
    await _pump(tester, role: 'owner', stories: const []);
    expect(find.byKey(const Key('family-landing-hero-edit')), findsOneWidget);
    expect(find.text('Add a family photo'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera), findsOneWidget);

    await _pump(tester, role: 'co_owner', stories: const []);
    expect(find.byKey(const Key('family-landing-hero-edit')), findsOneWidget);

    await _pump(tester, role: 'member', stories: const []);
    expect(find.byKey(const Key('family-landing-hero-edit')), findsNothing);
  });

  testWidgets('cards open the reader and omit a blank title', (tester) async {
    final now = DateTime.utc(2026, 10, 28);
    await _pump(
      tester,
      role: 'member',
      now: now,
      stories: [
        _story('newer', title: 'Harbor', daysAgo: 1, year: 1987),
        _story('older', title: null, daysAgo: 3),
        _story('outside', title: 'Gone', daysAgo: 8, year: 1970),
        _story('fourth', title: 'Extra', daysAgo: 2, year: 1991),
        _story('fifth', title: 'Also', daysAgo: 2, year: 1992),
      ],
    );

    expect(find.byKey(const Key('family-landing-card-newer')), findsOneWidget);
    expect(find.byKey(const Key('family-landing-card-fourth')), findsOneWidget);
    expect(find.byKey(const Key('family-landing-card-fifth')), findsOneWidget);
    expect(find.byKey(const Key('family-landing-card-older')), findsNothing);
    expect(find.byKey(const Key('family-landing-card-outside')), findsNothing);
    expect(find.text('Harbor'), findsOneWidget);
    expect(find.text('1987'), findsOneWidget);
    expect(find.text('Untitled'), findsNothing);
    expect(find.text('No stories added in the past 7 days.'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const Key('family-landing-card-newer')),
    );
    await tester.tap(find.byKey(const Key('family-landing-card-newer')));
    await tester.pumpAndSettle();
    expect(find.text('reader-newer'), findsOneWidget);
  });
}

Story _story(
  String id, {
  required String? title,
  required int daysAgo,
  int? year,
}) {
  final now = DateTime.utc(2026, 10, 28);
  return Story(
    id: id,
    familyId: 'fam-1',
    authorId: 'author',
    title: title,
    status: StoryStatus.published,
    publishedAt: now.subtract(Duration(days: daysAgo)),
    timeframeStart: year == null ? null : DateTime.utc(year),
    datePrecision: StoryDatePrecision.year,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required String role,
  required List<Story> stories,
  DateTime? now,
  String familyName = 'The Morgans',
}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // A fresh ProviderScope per pump, so a new role is read from scratch.
  await tester.pumpWidget(const SizedBox.shrink());
  final clock = _Clock(now ?? DateTime.utc(2026, 10, 28));
  final router = GoRouter(
    initialLocation: AppRoutes.familyLanding,
    routes: [
      GoRoute(
        path: AppRoutes.familyLanding,
        builder: (context, state) => FamilyLandingPage(now: clock.call),
      ),
      GoRoute(
        path: AppRoutes.allStories,
        builder: (context, state) => Scaffold(
          appBar: AlbumHeader(
            page: AlbumHeaderPage.allStories,
            familyName: familyName,
            families: [
              MemberFamily(
                id: 'fam-1',
                name: familyName,
                createdAt: DateTime.utc(2020),
                role: role,
              ),
            ],
            currentFamilyId: state.pathParameters['id'],
            onFamilySelected: (_) {},
          ),
          body: const Text('all-stories-page'),
        ),
      ),
      GoRoute(
        path: AppRoutes.timeline,
        builder: (context, state) => Scaffold(
          appBar: AlbumHeader(
            page: AlbumHeaderPage.timeline,
            familyName: familyName,
            families: [
              MemberFamily(
                id: 'fam-1',
                name: familyName,
                createdAt: DateTime.utc(2020),
                role: role,
              ),
            ],
            currentFamilyId: 'fam-1',
            onFamilySelected: (_) {},
          ),
          body: const Text('timeline-page'),
        ),
      ),
      GoRoute(
        path: '/stories/:storyId',
        builder: (context, state) =>
            Text('reader-${state.pathParameters['storyId']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await pumpRouterApp(
    tester,
    router,
    overrides: [
      familiesRepositoryProvider.overrideWithValue(_Families(role, familyName)),
      storiesRepositoryProvider.overrideWithValue(_Stories(stories)),
      storyThumbsLoaderProvider.overrideWithValue((_) async => const {}),
    ],
  );
  await tester.pumpAndSettle();
}

class _Families extends FamiliesRepository {
  _Families(this.role, this.familyName);

  final String role;
  final String familyName;

  @override
  Future<List<MemberFamily>> listMine() async {
    return [
      MemberFamily(
        id: 'fam-1',
        name: familyName,
        createdAt: DateTime.utc(2020),
        role: role,
      ),
    ];
  }

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];
}

/// Returns [latest] as the server window, like the old `loadLatest` hook.
class _Stories extends FakeStoriesRepository {
  _Stories(this.latest);

  final List<Story> latest;

  @override
  Future<List<Story>> listLatestPublished(
    String familyId, {
    int withinDays = 7,
    int limit = 3,
    DateTime? now,
  }) async => latest;
}

/// Stable clock tear-off target; the landing provider is keyed by it.
class _Clock {
  const _Clock(this.now);

  final DateTime now;

  DateTime call() => now;
}
