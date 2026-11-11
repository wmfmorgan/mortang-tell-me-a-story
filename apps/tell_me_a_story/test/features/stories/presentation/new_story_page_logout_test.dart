import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/mapbox_search_repository.dart';
import 'package:tell_me_a_story/core/domain/people_repository.dart';
import 'package:tell_me_a_story/core/domain/person.dart';
import 'package:tell_me_a_story/core/domain/photos_repository.dart';
import 'package:tell_me_a_story/core/domain/places_repository.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';
import 'package:tell_me_a_story/core/widgets/navigation/unsaved_guard.dart';
import 'package:tell_me_a_story/features/stories/presentation/new_story_page.dart';

import '../../../support/fakes/fake_invite_repository.dart';
import '../../../support/fakes/fake_mapbox_search.dart';
import '../../../support/fakes/fake_photos_repository.dart';
import '../../../support/fakes/fake_places_repository.dart';
import '../../../support/fakes/fake_stories_repository.dart';
import '../../../support/pump_app.dart';

const _ada = 'ada';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Save runs before onLogout', (tester) async {
    await _surface(tester);
    final order = <String>[];
    final router = await _mount(tester, stories: _Stories(order));
    await tester.enterText(find.byKey(const Key('story-date-year')), '1987');
    await tester.pump();
    await tester.tap(find.byKey(const Key('story-capture-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leave this story?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(order, ['createDraft']);
    expect(find.text('Leave this story?'), findsNothing);
    expect(router.state.uri.path, '/timeline');
    expect(find.byKey(const Key('header-menu-logout')), findsNothing);
  });
}

Future<void> _surface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

GoRouter? _router;

Future<GoRouter> _mount(
  WidgetTester tester, {
  required _Stories stories,
}) async {
  final previous = _router;
  _router = null;
  previous?.dispose();
  final router = GoRouter(
    initialLocation: '/stories/new',
    routes: [
      GoRoute(
        path: '/timeline',
        builder: (_, _) => const Text('timeline-marker'),
      ),
      GoRoute(
        path: '/stories/new',
        onExit: (context, state) => UnsavedGuards.onExit(context, state),
        builder: (_, _) => NewStoryPage(
          hasMapboxToken: false,
          mapBuilder: ({double? lat, double? lng}) => const SizedBox.shrink(),
          pickImageBytes: () async => null,
        ),
      ),
    ],
  );
  _router = router;
  addTearDown(() {
    if (_router == router) {
      _router = null;
      router.dispose();
    }
  });
  await pumpRouterApp(
    tester,
    router,
    overrides: [
      inviteRepositoryProvider.overrideWithValue(
        FakeInviteRepository(
          familyId: _ada,
          createdFamilyId: _ada,
          acceptedFamilyId: _ada,
        ),
      ),
      peopleRepositoryProvider.overrideWithValue(_People()),
      placesRepositoryProvider.overrideWithValue(FakePlacesRepository()),
      mapboxSearchRepositoryProvider.overrideWithValue(FakeMapboxSearch()),
      storiesRepositoryProvider.overrideWithValue(stories),
      photosRepositoryProvider.overrideWithValue(FakePhotosRepository()),
    ],
  );
  await tester.pumpAndSettle();
  return router;
}

class _Stories extends FakeStoriesRepository {
  _Stories(this.order);

  final List<String> order;
  var createDraftCalls = 0;

  @override
  Future<Story> createDraft({
    String? id,
    required String familyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    bool allowUndated = false,
    List<String> personIds = const [],
  }) async {
    order.add('createDraft');
    createDraftCalls++;
    return Story(
      id: id ?? 's1',
      familyId: familyId,
      authorId: 'u1',
      title: title,
      body: body,
      timeframeStart: timeframeStart,
      status: StoryStatus.draft,
      personIds: personIds,
    );
  }

  @override
  Future<bool> autosaveDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) async => true;
}

class _People extends PeopleRepository {
  @override
  Future<List<Person>> listPeople(String familyId) async => const [];

  @override
  Future<Person> createPerson({
    required String familyId,
    required String name,
    String? about,
    String? email,
    bool passedAway = false,
    List<int>? pictureBytes,
  }) async {
    throw UnimplementedError();
  }
}
