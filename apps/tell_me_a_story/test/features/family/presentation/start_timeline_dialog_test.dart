import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/comment.dart';
import 'package:tell_me_a_story/core/domain/comments_repository.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/family_detail.dart';
import 'package:tell_me_a_story/core/domain/family_directory.dart';
import 'package:tell_me_a_story/core/domain/family_directory_repository.dart';
import 'package:tell_me_a_story/core/domain/family_person.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/manage_families_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/people_repository.dart';
import 'package:tell_me_a_story/core/domain/person.dart';
import 'package:tell_me_a_story/core/domain/perspective.dart';
import 'package:tell_me_a_story/core/domain/perspectives_repository.dart';
import 'package:tell_me_a_story/core/domain/photos_repository.dart';
import 'package:tell_me_a_story/core/domain/place.dart';
import 'package:tell_me_a_story/core/domain/places_repository.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';
import 'package:tell_me_a_story/core/domain/story_thumbs.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/theme/album_forui_theme.dart';
import 'package:tell_me_a_story/core/widgets/album/album_header.dart';
import 'package:tell_me_a_story/features/drafts/presentation/drafts_page.dart';
import 'package:tell_me_a_story/features/family/presentation/manage_families_page.dart';
import 'package:tell_me_a_story/features/family/presentation/start_timeline_dialog.dart';
import 'package:tell_me_a_story/features/stories/presentation/new_story_page.dart';
import 'package:tell_me_a_story/features/stories/presentation/story_reader_page.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_branching.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_page.dart';

import '../../../support/fakes/fake_invite_repository.dart';
import '../../../support/fakes/fake_manage_families_repository.dart';
import '../../../support/fakes/fake_photos_repository.dart';
import '../../../support/fakes/fake_places_repository.dart';
import '../../../support/fakes/fake_stories_repository.dart';
import '../../../support/pump_app.dart';

const _parent = '00000000-0000-0000-0000-0000000000aa';
const _me = '00000000-0000-0000-0000-0000000000b1';
const _other = '00000000-0000-0000-0000-0000000000b2';

Story _story({
  String id = 'origin',
  String familyId = _parent,
  String? title = 'The beginning',
  int year = 1974,
  StoryStatus status = StoryStatus.published,
  List<String> personIds = const [],
  String? placeId,
}) {
  return Story(
    id: id,
    familyId: familyId,
    authorId: 'author',
    title: title,
    body: 'We made jam.',
    timeframeStart: DateTime(year, 1, 1),
    status: status,
    personIds: personIds,
    placeId: placeId,
  );
}

class _People extends PeopleRepository {
  _People(this.rows);

  final List<Person> rows;

  @override
  Future<List<Person>> listPeople(String familyId) async {
    return rows.where((row) => row.familyId == familyId).toList();
  }

  @override
  Future<Person> createPerson({
    required String familyId,
    required String name,
    String? about,
    String? email,
    bool passedAway = false,
    List<int>? pictureBytes,
  }) {
    throw UnimplementedError();
  }
}

/// The editor's tree people are [rows]; the family roster (timeline and
/// branch form) is empty, as when each page had its own people fake.
class _EditorPeople extends _People {
  _EditorPeople(super.rows);

  @override
  Future<List<Person>> listPeople(String familyId) async => const [];

  @override
  Future<List<Person>> listTreePeople(String familyId) =>
      super.listPeople(familyId);
}

class _Families extends FamiliesRepository {
  _Families({
    required this.mine,
    this.tree = const [],
    this.members = const [],
    this.stewarded = const [],
  });

  final List<MemberFamily> mine;
  final List<TreeFamily> tree;
  final List<FamilyPerson> members;
  final List<StewardFamily> stewarded;
  var treeLoads = 0;

  @override
  Future<List<MemberFamily>> listMine() async => mine;

  @override
  Future<List<StewardFamily>> listStewarded() async => stewarded;

  @override
  Future<List<TreeFamily>> listFamilyTree(String familyId) async {
    treeLoads++;
    return tree;
  }

  @override
  Future<List<FamilyPerson>> listMembers(String familyId) async => members;
}

class _EmptyDirectory implements FamilyDirectoryRepository {
  @override
  Future<FamilyDirectory> listDirectory() async {
    return const FamilyDirectory(active: [], recoverable: []);
  }

  @override
  Future<FamilyDetail?> loadDetail(String familyId) async => null;
}

class _Manage extends FakeManageFamiliesRepository {
  String? parentFamilyId;
  String? originStoryId;
  String? name;
  int? branchYear;
  String? ownerUserId;
  List<String> personIds = const [];

  @override
  Future<String> createBranchFamily({
    required String parentFamilyId,
    required String originStoryId,
    required String name,
    required int branchYear,
    required String ownerUserId,
    List<String> personIds = const [],
  }) async {
    this.parentFamilyId = parentFamilyId;
    this.originStoryId = originStoryId;
    this.name = name;
    this.branchYear = branchYear;
    this.ownerUserId = ownerUserId;
    this.personIds = personIds;
    await super.createBranchFamily(
      parentFamilyId: parentFamilyId,
      originStoryId: originStoryId,
      name: name,
      branchYear: branchYear,
      ownerUserId: ownerUserId,
      personIds: personIds,
    );
    return 'new-family';
  }
}

class _Stories extends FakeStoriesRepository {
  _Stories({List<Story>? published, this.draft}) : published = [...?published];

  final List<Story> published;
  Story? draft;
  var publishCalls = 0;
  var createCalls = 0;
  var updateCalls = 0;
  String? lastUpdatedId;

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
    createCalls++;
    final start = timeframeStart ?? DateTime(1980, 1, 1);
    draft = _story(
      id: 'draft-kept',
      familyId: familyId,
      title: title ?? '',
      year: start.year,
      status: StoryStatus.draft,
      personIds: personIds,
      placeId: placeId,
    );
    return draft!;
  }

  @override
  Future<Story> updateDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) async {
    updateCalls++;
    lastUpdatedId = storyId;
    final current = draft ?? _story(id: storyId);
    draft = _story(
      id: storyId,
      familyId: current.familyId,
      title: title ?? current.title,
      year: timeframeStart?.year ?? current.timeframeStart!.year,
      status: StoryStatus.draft,
      personIds: personIds ?? current.personIds,
      placeId: placeId ?? current.placeId,
    );
    return draft!;
  }

  @override
  Future<Story> publish(String storyId) async {
    publishCalls++;
    final source = draft ?? _story(id: storyId);
    final row = _story(
      id: storyId,
      familyId: source.familyId,
      title: source.title,
      year: source.timeframeStart!.year,
      personIds: source.personIds,
      placeId: source.placeId,
    );
    published
      ..removeWhere((story) => story.id == storyId)
      ..add(row);
    return row;
  }

  @override
  Future<Story> getStory(String storyId) async => draft ?? _story(id: storyId);

  @override
  Future<Story?> getPublished(String storyId) async {
    for (final story in published) {
      if (story.id == storyId) return story;
    }
    return null;
  }

  @override
  Future<List<Story>> listPublished(String familyId) async {
    return published.where((story) => story.familyId == familyId).toList();
  }
}

class _Places extends FakePlacesRepository {
  _Places(List<Place> rows) : super(places: rows);

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async =>
      places;

  @override
  Future<Place> markUsed(String placeId) async => places.first;

  @override
  Future<Place?> getPlace(String id) async => null;
}

class _Comments implements CommentsRepository {
  @override
  Future<List<Comment>> listForStory(String storyId) async => const [];

  @override
  Future<Comment> create({
    required String storyId,
    required String familyId,
    required String body,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> update({required String id, required String body}) async {}

  @override
  Future<void> delete(String id) async {}
}

class _Perspectives implements PerspectivesRepository {
  @override
  Future<List<Perspective>> listForStory(String storyId) async => const [];

  @override
  Future<Perspective> create({
    required String storyId,
    required String familyId,
    required String body,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> update({required String id, required String body}) async {}

  @override
  Future<void> delete(String id) async {}
}

FamilyPerson _member(String id, {String? name}) {
  return FamilyPerson(userId: id, role: 'member', displayName: name);
}

/// Repository overrides for one test. Unset repositories get quiet fakes.
List<Override> _repos({
  InviteRepository? invite,
  StoriesRepository? stories,
  FamiliesRepository? families,
  PeopleRepository? people,
  PlacesRepository? places,
  PhotosRepository? photos,
  ManageFamiliesRepository? manage,
  FamilyDirectoryRepository? directory,
}) {
  return [
    inviteRepositoryProvider.overrideWithValue(
      invite ??
          FakeInviteRepository(
            familyId: _parent,
            createdFamilyId: _parent,
            acceptedFamilyId: 'f',
          ),
    ),
    storiesRepositoryProvider.overrideWithValue(stories ?? _Stories()),
    familiesRepositoryProvider.overrideWithValue(
      families ?? _Families(mine: const []),
    ),
    peopleRepositoryProvider.overrideWithValue(people ?? _People(const [])),
    placesRepositoryProvider.overrideWithValue(places ?? _Places(const [])),
    photosRepositoryProvider.overrideWithValue(
      photos ?? FakePhotosRepository(),
    ),
    commentsRepositoryProvider.overrideWithValue(_Comments()),
    perspectivesRepositoryProvider.overrideWithValue(_Perspectives()),
    manageFamiliesRepositoryProvider.overrideWithValue(manage ?? _Manage()),
    familyDirectoryRepositoryProvider.overrideWithValue(
      directory ?? _EmptyDirectory(),
    ),
    storyThumbsLoaderProvider.overrideWithValue((_) async => const {}),
  ];
}

/// A container with [defaultTestOverrides] then [overrides], disposed at
/// the end of the test. [selected] seeds the remembered family.
ProviderContainer _container(List<Override> overrides, {String? selected}) {
  final replaced = {for (final override in overrides) override.origin};
  final container = ProviderContainer(
    overrides: [
      for (final override in defaultTestOverrides)
        if (!replaced.contains(override.origin)) override,
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  if (selected != null) {
    container.read(familySelectionProvider.notifier).remember(selected);
  }
  return container;
}

/// [child] inside [container].
Widget _scoped(ProviderContainer container, Widget child) =>
    UncontrolledProviderScope(container: container, child: child);

/// The app shell on [router], like `App` in production.
Widget _app(ProviderContainer container) => _scoped(container, const App());

Future<void> _openForm(
  WidgetTester tester, {
  Story? origin,
  bool allowChange = true,
  List<Story> stories = const [],
  required _Families families,
  required _People people,
  required _Manage manage,
  VoidCallback? onWriteStory,
}) async {
  final container = _container(
    _repos(families: families, people: people, manage: manage),
  );
  await tester.pumpWidget(
    _scoped(
      container,
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showStartTimelineDialog(
                    context,
                    parentId: _parent,
                    parentName: 'Parent',
                    stories: stories,
                    currentUserId: _me,
                    origin: origin,
                    allowChange: allowChange,
                    onWriteStory: onWriteStory,
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _tapCreate(WidgetTester tester) async {
  final button = find.byKey(const Key('start-timeline-create'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('the reader item is only for a member of that story family', (
    tester,
  ) async {
    final families = _Families(
      mine: [
        MemberFamily(
          id: _parent,
          name: 'Parent',
          createdAt: DateTime.utc(1970),
        ),
      ],
      tree: const [TreeFamily(id: _parent, name: 'Parent')],
      members: [_member(_me, name: 'Bill')],
    );
    await tester.pumpWidget(
      _reader(story: _story(), families: families, manage: _Manage()).widget,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reader-overflow')));
    await tester.pumpAndSettle();
    expect(find.text('Add a family branch from this story'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reader-start-timeline')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start-timeline-change')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('start-timeline-year')))
          .controller!
          .text,
      '1974',
    );
  });

  testWidgets('a draft hides the reader item', (tester) async {
    await tester.pumpWidget(
      _reader(
        story: _story(status: StoryStatus.draft),
        families: _Families(
          mine: [
            MemberFamily(
              id: _parent,
              name: 'Parent',
              createdAt: DateTime.utc(1970),
            ),
          ],
        ),
        manage: _Manage(),
        publishedLookup: false,
      ).widget,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader-start-timeline')), findsNothing);
  });

  testWidgets('a tree reader of a borrowed origin does not see the item', (
    tester,
  ) async {
    const child = '00000000-0000-0000-0000-0000000000cc';
    await tester.pumpWidget(
      _reader(
        story: _story(),
        families: _Families(
          mine: [
            MemberFamily(
              id: child,
              name: 'Child',
              createdAt: DateTime.utc(1990),
            ),
          ],
          tree: const [
            TreeFamily(id: _parent, name: 'Parent'),
            TreeFamily(
              id: child,
              name: 'Child',
              parentFamilyId: _parent,
              originStoryId: 'origin',
            ),
          ],
        ),
        manage: _Manage(),
      ).widget,
    );
    await tester.pumpAndSettle();
    expect(find.text('Add a family branch from this story'), findsNothing);
  });

  testWidgets('the family menu branch row sits above Manage', (tester) async {
    await tester.pumpWidget(
      _scoped(_container(_repos()), _header(onStart: () {})),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    final timeline = tester
        .getTopLeft(find.byKey(const Key('family-menu-start-timeline')))
        .dy;
    final manage = tester.getTopLeft(find.text('Manage families')).dy;
    expect(timeline, lessThan(manage));
    expect(find.text('+ Start a new timeline'), findsNothing);
    expect(find.text('Your families'), findsNothing);
    expect(find.text('Related families'), findsNothing);
    expect(find.text('Start a family'), findsNothing);
  });

  testWidgets('the drafts header shows the branch row for a member family', (
    tester,
  ) async {
    final container = _container(
      _repos(
        stories: _Stories(published: const []),
        families: _Families(
          mine: [
            MemberFamily(
              id: _parent,
              name: 'Parent',
              createdAt: DateTime.utc(1970),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      _scoped(container, const MaterialApp(home: DraftsPage())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('family-menu-start-timeline')), findsOneWidget);
    expect(find.text('Add a family branch to Parent'), findsOneWidget);
    expect(find.byKey(const Key('family-menu-invite')), findsOneWidget);
    expect(find.text('Start a family'), findsNothing);
  });

  testWidgets('Manage families shows the branch row for the header family', (
    tester,
  ) async {
    final container = _container(
      _repos(
        directory: _EmptyDirectory(),
        families: _Families(
          mine: [
            MemberFamily(
              id: _parent,
              name: 'Parent',
              createdAt: DateTime.utc(1970),
            ),
          ],
        ),
        manage: _Manage(),
      ),
      selected: _parent,
    );
    await tester.pumpWidget(
      _scoped(container, const MaterialApp(home: ManageFamiliesPage())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('family-menu-start-timeline')), findsOneWidget);
    expect(find.text('Add a family branch to Parent'), findsOneWidget);
    expect(find.byKey(const Key('family-menu-invite')), findsOneWidget);
  });

  testWidgets('a tree-read open family hides the timeline row', (tester) async {
    final container = _container(
      _repos(
        invite: FakeInviteRepository(
          familyId: 'bea',
          createdFamilyId: _parent,
          acceptedFamilyId: 'f',
        ),
        stories: _Stories(
          published: [_story(id: 'bea-story', familyId: 'bea', title: 'Bea')],
        ),
        families: _Families(
          mine: [
            MemberFamily(
              id: _parent,
              name: 'Parent',
              createdAt: DateTime.utc(1970),
            ),
          ],
          tree: const [
            TreeFamily(id: _parent, name: 'Parent'),
            TreeFamily(id: 'bea', name: 'Bea'),
          ],
          stewarded: [
            const StewardFamily(id: _parent, name: 'Parent', role: 'owner'),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      _scoped(
        container,
        const MaterialApp(
          builder: albumAppBuilder,
          home: TimelinePage(currentUserId: _me),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Start a family'), findsNothing);
    expect(find.text('Manage families'), findsOneWidget);
    expect(find.byKey(const Key('family-menu-start-timeline')), findsNothing);
  });

  testWidgets('the picker lists published parent stories and can write one', (
    tester,
  ) async {
    final manage = _Manage();
    var wrote = false;
    final stories = [
      _story(id: 'jam', title: 'Blackberry Jam', year: 1972),
      _story(id: 'draft', title: 'Still drafting', status: StoryStatus.draft),
      _story(id: 'other', familyId: 'other', title: 'Elsewhere'),
      _story(id: 'park', title: 'The park', year: 1981),
    ];
    await _openForm(
      tester,
      stories: stories,
      families: _Families(
        mine: const [],
        members: [_member(_me, name: 'Bill')],
      ),
      people: _People(const []),
      manage: manage,
      onWriteStory: () => wrote = true,
    );
    expect(find.text('Pick the origin story'), findsOneWidget);
    expect(find.text('Published stories from Parent'), findsOneWidget);
    expect(find.text('Blackberry Jam'), findsOneWidget);
    expect(find.text('The park'), findsOneWidget);
    expect(find.text('Still drafting'), findsNothing);
    expect(find.text('Elsewhere'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('start-timeline-search')),
      'JAM',
    );
    await tester.pump();
    expect(find.text('Blackberry Jam'), findsOneWidget);
    expect(find.text('The park'), findsNothing);

    await tester.enterText(find.byKey(const Key('start-timeline-search')), '');
    await tester.pump();
    expect(find.text('The park'), findsOneWidget);

    await tester.tap(find.byKey(const Key('start-timeline-picker-cancel')));
    await tester.pumpAndSettle();
    expect(manage.calls, isEmpty);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-timeline-write')));
    await tester.pumpAndSettle();
    expect(wrote, isTrue);
    expect(manage.calls, isEmpty);
  });

  testWidgets('year prefills from the picked story and stays editable', (
    tester,
  ) async {
    final first = _story(id: 'a', title: 'First', year: 1962);
    final second = _story(id: 'b', title: 'Second', year: 1988);
    await _openForm(
      tester,
      origin: first,
      stories: [first, second],
      families: _Families(
        mine: const [],
        members: [_member(_me, name: 'Bill')],
      ),
      people: _People(const []),
      manage: _Manage(),
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('start-timeline-year')))
          .controller!
          .text,
      '1962',
    );
    await tester.tap(find.byKey(const Key('start-timeline-change')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-timeline-story-b')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('start-timeline-year')))
          .controller!
          .text,
      '1988',
    );
    await tester.enterText(
      find.byKey(const Key('start-timeline-year')),
      '2099',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('start-timeline-year')))
          .controller!
          .text,
      '2099',
    );
  });

  testWidgets(
    'create stays disabled until name, owner, and a four-digit year',
    (tester) async {
      final manage = _Manage();
      await _openForm(
        tester,
        origin: _story(),
        families: _Families(
          mine: const [],
          members: [
            _member(_me, name: 'Bill'),
            _member(_other, name: '   '),
          ],
        ),
        people: _People(const [
          Person(id: 'p-blank', familyId: _parent, name: ' '),
        ]),
        manage: manage,
      );
      expect(find.text('You'), findsWidgets);
      expect(find.text('Member'), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('start-timeline-create')),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const Key('start-timeline-name')),
        '  Side line  ',
      );
      await tester.enterText(
        find.byKey(const Key('start-timeline-year')),
        '987',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('start-timeline-create')),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const Key('start-timeline-year')),
        '2099',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('start-timeline-create')),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('start-timeline-owner')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Member').last);
      await tester.pumpAndSettle();
      await _tapCreate(tester);
      await tester.pumpAndSettle();
      expect(manage.parentFamilyId, _parent);
      expect(manage.originStoryId, 'origin');
      expect(manage.name, 'Side line');
      expect(manage.branchYear, 2099);
      expect(manage.ownerUserId, _other);
      expect(manage.personIds, isEmpty);
    },
  );

  testWidgets('errors stay inline and the modal stays open', (tester) async {
    final manage = _Manage();
    await _openForm(
      tester,
      origin: _story(),
      families: _Families(
        mine: const [],
        members: [_member(_me, name: 'Bill')],
      ),
      people: _People(const []),
      manage: manage,
    );
    await tester.enterText(
      find.byKey(const Key('start-timeline-name')),
      'Side',
    );
    await tester.pump();

    manage.error = const AppException(
      code: AppErrorCode.validation,
      message: 'too many levels',
    );
    await _tapCreate(tester);
    await tester.pumpAndSettle();
    expect(find.text('too many levels'), findsOneWidget);
    expect(find.textContaining('VALIDATION:'), findsNothing);
    expect(find.byKey(const Key('start-timeline-dialog')), findsOneWidget);

    manage.error = const AppException(
      code: AppErrorCode.notFound,
      message: 'story',
    );
    await _tapCreate(tester);
    await tester.pumpAndSettle();
    expect(
      find.text("That story isn't available anymore. Pick another one."),
      findsOneWidget,
    );
    expect(find.text('story'), findsNothing);

    manage.error = const AppException(
      code: AppErrorCode.forbidden,
      message: 'member only',
    );
    await _tapCreate(tester);
    await tester.pumpAndSettle();
    expect(find.text("You're not a member of Parent anymore."), findsOneWidget);
    expect(find.text('member only'), findsNothing);

    manage.error = Exception(
      'duplicate key value violates unique constraint "families_pkey"',
    );
    await _tapCreate(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('duplicate key'), findsNothing);
    expect(find.textContaining('families_pkey'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const Key('start-timeline-dialog')), findsOneWidget);

    manage.error = const AppException(
      code: AppErrorCode.validation,
      message: 'create_branch_family returned no id',
    );
    await _tapCreate(tester);
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('create_branch_family returned no id'), findsNothing);
    expect(find.byKey(const Key('start-timeline-dialog')), findsOneWidget);

    manage.error = const AppException(
      code: AppErrorCode.validation,
      message: 'Request failed',
    );
    await _tapCreate(tester);
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Request failed'), findsNothing);
    expect(find.byKey(const Key('start-timeline-dialog')), findsOneWidget);
  });

  testWidgets('the reader path uses the short missing-story sentence', (
    tester,
  ) async {
    final manage = _Manage()
      ..error = const AppException(
        code: AppErrorCode.notFound,
        message: 'story',
      );
    await _openForm(
      tester,
      origin: _story(),
      allowChange: false,
      families: _Families(
        mine: const [],
        members: [_member(_me, name: 'Bill')],
      ),
      people: _People(const []),
      manage: manage,
    );
    await tester.enterText(
      find.byKey(const Key('start-timeline-name')),
      'Side',
    );
    await tester.pump();
    await _tapCreate(tester);
    await tester.pumpAndSettle();
    expect(find.text("That story isn't available anymore."), findsOneWidget);
    expect(find.textContaining('Pick another'), findsNothing);
    expect(find.byKey(const Key('start-timeline-dialog')), findsOneWidget);
  });

  testWidgets('create stays on the parent timeline and toasts the name', (
    tester,
  ) async {
    final families = _Families(
      mine: [
        MemberFamily(
          id: _parent,
          name: 'Parent',
          createdAt: DateTime.utc(1970),
        ),
      ],
      tree: const [TreeFamily(id: _parent, name: 'Parent')],
      members: [_member(_me, name: 'Bill')],
      stewarded: const [
        StewardFamily(id: _parent, name: 'Parent', role: 'owner'),
      ],
    );
    final manage = _Manage();
    final stories = _Stories(published: [_story(title: 'The beginning')]);
    final container = _container(
      _repos(
        invite: FakeInviteRepository(
          familyId: _parent,
          createdFamilyId: _parent,
          acceptedFamilyId: 'f',
        ),
        stories: stories,
        families: families,
        people: _People(const []),
        manage: manage,
      ),
      selected: _parent,
    );
    await tester.pumpWidget(
      _scoped(
        container,
        const MaterialApp(
          builder: albumAppBuilder,
          home: TimelinePage(currentUserId: _me),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final loadsBefore = families.treeLoads;
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu-start-timeline')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-timeline-story-origin')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('start-timeline-year')))
          .controller!
          .text,
      '1974',
    );
    await tester.enterText(
      find.byKey(const Key('start-timeline-name')),
      'Side line',
    );
    await tester.pump();
    await _tapCreate(tester);
    await tester.pumpAndSettle();
    expect(find.text('Side line timeline created'), findsOneWidget);
    expect(container.read(familySelectionProvider), _parent);
    expect(families.treeLoads, greaterThan(loadsBefore));
    expect(find.text('Origin · from Parent'), findsNothing);
  });

  testWidgets('the reader toasts and does not leave the story', (tester) async {
    final manage = _Manage();
    final reader = _reader(
      selected: _parent,
      story: _story(),
      families: _Families(
        mine: [
          MemberFamily(
            id: _parent,
            name: 'Parent',
            createdAt: DateTime.utc(1970),
          ),
        ],
        tree: const [TreeFamily(id: _parent, name: 'Parent')],
        members: [_member(_me, name: 'Bill')],
      ),
      manage: manage,
    );
    final container = reader.container;
    final router = reader.router;
    await tester.pumpWidget(reader.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reader-overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reader-start-timeline')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('start-timeline-name')),
      'Side line',
    );
    await tester.pump();
    await _tapCreate(tester);
    await tester.pumpAndSettle();
    expect(find.text('Side line timeline created'), findsOneWidget);
    expect(container.read(familySelectionProvider), _parent);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/stories/origin',
    );
  });

  testWidgets(
    'save draft clears newTimelineFrom so a later publish stays closed',
    (tester) async {
      final stories = _Stories(
        draft: _story(
          id: 'draft-1',
          title: 'Written origin',
          year: 1970,
          status: StoryStatus.draft,
          personIds: const ['p1'],
          placeId: 'pl1',
        ),
      );
      final manage = _Manage();
      final families = _Families(
        mine: [
          MemberFamily(
            id: _parent,
            name: 'Parent',
            createdAt: DateTime.utc(1970),
          ),
        ],
        members: [_member(_me, name: 'Bill')],
      );
      final router = GoRouter(
        initialLocation: '/stories/new?newTimelineFrom=$_parent&draft=draft-1',
        routes: [
          GoRoute(
            path: AppRoutes.newStory,
            builder: (context, state) => NewStoryPage(
              hasMapboxToken: false,
              draftId: state.uri.queryParameters['draft'],
            ),
          ),
          GoRoute(
            path: '/stories/:storyId',
            builder: (_, state) =>
                Text('reader-${state.pathParameters['storyId']}'),
          ),
          GoRoute(
            path: AppRoutes.timeline,
            builder: (context, state) => const TimelinePage(currentUserId: _me),
          ),
        ],
      );
      final container = _container([
        ..._repos(
          stories: stories,
          families: families,
          manage: manage,
          people: _EditorPeople(const [
            Person(id: 'p1', familyId: _parent, name: 'Ada'),
          ]),
          places: _Places(const [
            Place(
              id: 'pl1',
              label: 'Park',
              address: 'Town',
              lat: 1,
              lng: 2,
              isFavorite: true,
            ),
          ]),
        ),
        appRouterProvider.overrideWithValue(router),
      ]);
      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Save draft'));
      await tester.pumpAndSettle();
      expect(stories.publishCalls, 0);
      expect(manage.calls, isEmpty);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.newStory,
      );
      expect(
        router
            .routerDelegate
            .currentConfiguration
            .uri
            .queryParameters['newTimelineFrom'],
        isNull,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Publish story'));
      await tester.pumpAndSettle();
      expect(stories.publishCalls, 1);
      expect(manage.calls, isEmpty);
      expect(find.byKey(const Key('start-timeline-change')), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.storyPath('draft-1'),
      );
    },
  );

  testWidgets(
    'a second save draft updates the same draft after newTimelineFrom is cleared',
    (tester) async {
      final stories = _Stories();
      final router = GoRouter(
        initialLocation: '/stories/new?newTimelineFrom=$_parent',
        routes: [
          GoRoute(
            path: AppRoutes.newStory,
            builder: (context, state) => NewStoryPage(
              hasMapboxToken: false,
              draftId: state.uri.queryParameters['draft'],
            ),
          ),
        ],
      );
      final container = _container([
        ..._repos(stories: stories),
        appRouterProvider.overrideWithValue(router),
      ]);
      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('story-date-year')), '1980');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save draft'));
      await tester.pumpAndSettle();

      final query =
          router.routerDelegate.currentConfiguration.uri.queryParameters;
      expect(query['newTimelineFrom'], isNull);
      expect(stories.createCalls, 1);
      expect(stories.updateCalls, 0);
      expect(query['draft'], stories.draft?.id);

      await tester.enterText(
        find.byKey(const Key('story-body')),
        'Second pass',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save draft'));
      await tester.pumpAndSettle();

      expect(stories.createCalls, 1);
      expect(stories.updateCalls, 1);
      expect(stories.lastUpdatedId, stories.draft?.id);
      expect(
        router
            .routerDelegate
            .currentConfiguration
            .uri
            .queryParameters['newTimelineFrom'],
        isNull,
      );
    },
  );

  testWidgets('publish with newTimelineFrom still opens the form', (
    tester,
  ) async {
    final stories = _Stories(
      draft: _story(
        id: 'draft-1',
        title: 'Written origin',
        year: 1970,
        status: StoryStatus.draft,
        personIds: const ['p1'],
        placeId: 'pl1',
      ),
    );
    final manage = _Manage();
    final families = _Families(
      mine: [
        MemberFamily(
          id: _parent,
          name: 'Parent',
          createdAt: DateTime.utc(1970),
        ),
      ],
      members: [_member(_me, name: 'Bill')],
    );
    final router = GoRouter(
      initialLocation: '/stories/new?newTimelineFrom=$_parent&draft=draft-1',
      routes: [
        GoRoute(
          path: AppRoutes.newStory,
          builder: (context, state) => NewStoryPage(
            hasMapboxToken: false,
            draftId: state.uri.queryParameters['draft'],
          ),
        ),
        GoRoute(
          path: AppRoutes.timeline,
          builder: (context, state) => const TimelinePage(currentUserId: _me),
        ),
      ],
    );
    final container = _container([
      ..._repos(
        stories: stories,
        families: families,
        manage: manage,
        people: _EditorPeople(const [
          Person(id: 'p1', familyId: _parent, name: 'Ada'),
        ]),
        places: _Places(const [
          Place(
            id: 'pl1',
            label: 'Park',
            address: 'Town',
            lat: 1,
            lng: 2,
            isFavorite: true,
          ),
        ]),
      ),
      appRouterProvider.overrideWithValue(router),
    ]);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Publish story'));
    await tester.pumpAndSettle();
    expect(stories.publishCalls, 1);
    expect(find.byKey(const Key('start-timeline-change')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('start-timeline-year')))
          .controller!
          .text,
      '1970',
    );
    await tester.tap(find.byKey(const Key('start-timeline-cancel')));
    await tester.pumpAndSettle();
    expect(manage.calls, isEmpty);
    expect(
      router
          .routerDelegate
          .currentConfiguration
          .uri
          .queryParameters['newTimelineOrigin'],
      isNull,
    );
  });

  testWidgets(
    'leaving new story without publishing does not create a timeline',
    (tester) async {
      final manage = _Manage();
      final stories = _Stories();
      final container = _container(_repos(stories: stories, manage: manage));
      await tester.pumpWidget(
        _scoped(
          container,
          const MaterialApp(home: NewStoryPage(hasMapboxToken: false)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(manage.calls, isEmpty);
      expect(stories.publishCalls, 0);
    },
  );

  testWidgets('a dated branch callout ellipsizes on the origin story', (
    tester,
  ) async {
    const side = '00000000-0000-0000-0000-0000000000dd';
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = _container(
      _repos(
        invite: FakeInviteRepository(
          familyId: _parent,
          createdFamilyId: _parent,
          acceptedFamilyId: 'f',
        ),
        stories: _Stories(published: [_story(year: 1984, title: 'Eighties')]),
        families: _Families(
          mine: [
            MemberFamily(
              id: _parent,
              name: 'Parent',
              createdAt: DateTime.utc(1970),
            ),
          ],
          tree: const [
            TreeFamily(id: _parent, name: 'Parent'),
            TreeFamily(
              id: side,
              name: 'A very long family name that should ellipsize inside the dial slot',
              parentFamilyId: _parent,
              originStoryId: 'origin',
              branchYear: 1955,
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      _scoped(
        container,
        const MaterialApp(
          builder: albumAppBuilder,
          home: TimelinePage(currentUserId: _me),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ring = find.byKey(const Key('timeline-branch-callout-ring-origin'));
    final label = find.byKey(const Key('timeline-branch-callout-$side'));
    await tester.ensureVisible(label);
    await tester.pumpAndSettle();
    expect(ring, findsOneWidget);
    expect(
      (tester.getCenter(ring) -
              tester.getCenter(find.byKey(const Key('timeline-dot-origin'))))
          .distance,
      lessThanOrEqualTo(1),
    );
    expect(find.byKey(const Key('timeline-branch-mark-$side')), findsNothing);
    expect(find.byKey(const Key('timeline-decade-row-1950')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('timeline-decade-row-1980')),
        matching: ring,
      ),
      findsOneWidget,
    );
    final text = tester.widget<Text>(
      find.descendant(
        of: label,
        matching: find.textContaining('A very long family name'),
      ),
    );
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.data, contains('Branch'));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is CalloutLeaderPainter,
      ),
      findsWidgets,
    );
  });

  testWidgets('a 1990 branch callout sits on the 1950s origin story', (
    tester,
  ) async {
    const later = '00000000-0000-0000-0000-0000000000ee';
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = _container(
      _repos(
        invite: FakeInviteRepository(
          familyId: _parent,
          createdFamilyId: _parent,
          acceptedFamilyId: 'f',
        ),
        stories: _Stories(published: [_story(year: 1952, title: 'Fifties')]),
        families: _Families(
          mine: [
            MemberFamily(
              id: _parent,
              name: 'Parent',
              createdAt: DateTime.utc(1970),
            ),
          ],
          tree: const [
            TreeFamily(id: _parent, name: 'Parent'),
            TreeFamily(
              id: later,
              name: 'Later line',
              parentFamilyId: _parent,
              originStoryId: 'origin',
              branchYear: 1990,
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      _scoped(
        container,
        const MaterialApp(
          builder: albumAppBuilder,
          home: TimelinePage(currentUserId: _me),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final band = find.byKey(const Key('timeline-decade-row-1950'));
    final ring = find.byKey(const Key('timeline-branch-callout-ring-origin'));
    final label = find.byKey(const Key('timeline-branch-callout-$later'));
    await tester.ensureVisible(band);
    await tester.ensureVisible(ring);
    await tester.pumpAndSettle();
    expect(ring, findsOneWidget);
    expect(find.text('Later line Branch'), findsOneWidget);
    expect(tester.getRect(band).contains(tester.getCenter(ring)), isTrue);
    expect(tester.getRect(band).contains(tester.getCenter(label)), isTrue);
    expect(find.byKey(const Key('timeline-branch-mark-$later')), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is CalloutLeaderPainter,
      ),
      findsWidgets,
    );
  });

  testWidgets('tapping the far end of a rail slot does nothing', (
    tester,
  ) async {
    const side = '00000000-0000-0000-0000-0000000000ff';
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = _container(
      _repos(
        invite: FakeInviteRepository(
          familyId: _parent,
          createdFamilyId: _parent,
          acceptedFamilyId: 'f',
        ),
        stories: _Stories(published: [_story(year: 1984, title: 'Eighties')]),
        families: _Families(
          mine: [
            MemberFamily(
              id: _parent,
              name: 'Parent',
              createdAt: DateTime.utc(1970),
            ),
            MemberFamily(id: side, name: 'Side', createdAt: DateTime.utc(1990)),
          ],
          tree: const [
            TreeFamily(id: _parent, name: 'Parent'),
            TreeFamily(
              id: side,
              name: 'Side',
              parentFamilyId: _parent,
              originStoryId: 'origin',
              branchYear: 1955,
            ),
          ],
        ),
      ),
      selected: _parent,
    );
    await tester.pumpWidget(
      _scoped(
        container,
        const MaterialApp(
          builder: albumAppBuilder,
          home: TimelinePage(currentUserId: _me),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ring = find.byKey(const Key('timeline-branch-callout-ring-origin'));
    final label = find.byKey(const Key('timeline-branch-callout-$side'));
    await tester.ensureVisible(ring);
    await tester.pumpAndSettle();
    final dot = find.byKey(const Key('timeline-dot-origin'));
    expect(
      (tester.getCenter(ring) - tester.getCenter(dot)).distance,
      lessThanOrEqualTo(1),
    );
    expect(find.text('Side Branch'), findsOneWidget);
    expect(tester.getCenter(label).dx, greaterThan(tester.getCenter(dot).dx));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is CalloutLeaderPainter,
      ),
      findsWidgets,
    );
    final row = find.byKey(const Key('timeline-decade-row-1980'));
    final rowRect = tester.getRect(row);
    final labelRect = tester.getRect(label);
    expect(labelRect.right, lessThan(rowRect.right - 8));
    await tester.tapAt(Offset(rowRect.right - 4, labelRect.center.dy));
    await tester.pumpAndSettle();
    expect(container.read(familySelectionProvider), _parent);

    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(container.read(familySelectionProvider), side);
  });

  testWidgets('the dialog form title reads Add a family branch to the parent', (
    tester,
  ) async {
    final origin = _story(id: 'a', title: 'First', year: 1962);
    await _openForm(
      tester,
      origin: origin,
      families: _Families(
        mine: const [],
        members: [_member(_me, name: 'Bill')],
      ),
      people: _People(const []),
      manage: _Manage(),
    );
    expect(find.text('Add a family branch to Parent'), findsOneWidget);
    expect(find.text('Start a new timeline'), findsNothing);
  });
}

Widget _header({
  AlbumHeaderPage page = AlbumHeaderPage.timeline,
  VoidCallback? onStart,
}) {
  return MaterialApp(
    home: Scaffold(
      appBar: AlbumHeader(
        page: page,
        familyName: 'Parent',
        families: [
          MemberFamily(
            id: _parent,
            name: 'Parent',
            createdAt: DateTime.utc(1970),
          ),
        ],
        currentFamilyId: _parent,
        onFamilySelected: (_) {},
        stewarded: const [
          StewardFamily(id: _parent, name: 'Parent', role: 'owner'),
        ],
        relatedFamilies: const [TreeFamily(id: 'bea', name: 'Bea')],
        onStartTimeline: onStart,
      ),
    ),
  );
}

/// The reader on its own router inside a scoped app.
class _ReaderApp {
  _ReaderApp(this.container);

  final ProviderContainer container;

  GoRouter get router => container.read(appRouterProvider);

  Widget get widget => _app(container);
}

_ReaderApp _reader({
  required Story story,
  required _Families families,
  required _Manage manage,
  bool publishedLookup = true,
  String? selected,
}) {
  final router = GoRouter(
    initialLocation: '/stories/${story.id}',
    routes: [
      GoRoute(
        path: '/timeline',
        builder: (context, state) => const Text('timeline-dest'),
      ),
      GoRoute(
        path: '/stories/:storyId',
        builder: (context, state) =>
            StoryReaderPage(storyId: story.id, currentUserId: _me),
      ),
    ],
  );
  return _ReaderApp(
    _container([
      ..._repos(
        stories: _ReaderStories(story, honorStatus: publishedLookup),
        families: families,
        manage: manage,
      ),
      appRouterProvider.overrideWithValue(router),
    ], selected: selected),
  );
}

class _ReaderStories extends FakeStoriesRepository {
  _ReaderStories(this.story, {required this.honorStatus});

  final Story story;
  final bool honorStatus;

  @override
  Future<Story?> getPublished(String storyId) async {
    if (storyId != story.id) return null;
    if (honorStatus && story.status != StoryStatus.published) return null;
    if (!honorStatus) return story;
    return story;
  }
}
