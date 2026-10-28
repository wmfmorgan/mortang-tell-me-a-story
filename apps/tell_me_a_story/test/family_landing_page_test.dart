import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/theme/album_header.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family/family_landing_page.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FamilySelection.clear();
  });

  tearDown(FamilySelection.clear);

  testWidgets('empty week keeps the hero and View all stories', (tester) async {
    await _pump(tester, role: 'member', stories: const []);

    expect(find.byKey(const Key('family-landing')), findsOneWidget);
    expect(find.byKey(const Key('family-landing-hero')), findsOneWidget);
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('Added in the past 7 days.'), findsOneWidget);
    expect(find.text('No stories added in the past 7 days.'), findsOneWidget);
    expect(find.byKey(const Key('family-landing-view-all')), findsOneWidget);
    expect(find.byKey(const Key('family-landing-hero-edit')), findsNothing);
    expect(find.text('Add a family photo'), findsNothing);
    expect(find.text('Featured'), findsNothing);
    expect(find.text('Oldest'), findsNothing);
    expect(find.text('Untitled'), findsNothing);
    expect(find.byKey(const Key('header-underline-timeline')), findsNothing);
    expect(
      tester.getRect(find.byKey(const Key('family-landing-view-all'))).bottom,
      lessThan(900),
    );

    await tester.ensureVisible(
      find.byKey(const Key('family-landing-view-all')),
    );
    await tester.tap(find.byKey(const Key('family-landing-view-all')));
    await tester.pumpAndSettle();
    expect(find.text('timeline-page'), findsOneWidget);
    expect(find.byKey(const Key('header-underline-timeline')), findsOneWidget);
  });

  testWidgets('Stories from Landing opens the timeline underlined', (
    tester,
  ) async {
    await _pump(tester, role: 'member', stories: const []);
    await tester.tap(find.byKey(const Key('timeline-nav')));
    await tester.pumpAndSettle();
    expect(find.text('timeline-page'), findsOneWidget);
    expect(find.byKey(const Key('header-underline-timeline')), findsOneWidget);
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
}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  FamilySelection.remember('fam-1');
  final router = GoRouter(
    initialLocation: AppRoutes.familyLanding,
    routes: [
      GoRoute(
        path: AppRoutes.familyLanding,
        builder: (context, state) => FamilyLandingPage(
          familiesApi: _Families(role),
          loadLatest: (_) async => stories,
          now: () => now ?? DateTime.utc(2026, 10, 28),
        ),
      ),
      GoRoute(
        path: AppRoutes.timeline,
        builder: (context, state) => Scaffold(
          appBar: AlbumHeader(
            page: AlbumHeaderPage.timeline,
            familyName: 'The Morgans',
            families: [
              MemberFamily(
                id: 'fam-1',
                name: 'The Morgans',
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
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

class _Families extends FamiliesGateway {
  _Families(this.role);

  final String role;

  @override
  Future<List<MemberFamily>> listMine() async {
    return [
      MemberFamily(
        id: 'fam-1',
        name: 'The Morgans',
        createdAt: DateTime.utc(2020),
        role: role,
      ),
    ];
  }

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];
}
