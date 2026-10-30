import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/theme/album_header.dart';
import 'package:tell_me_a_story/data/comments_api.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/manage_families_api.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/perspectives_api.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/places_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/drafts/drafts_page.dart';
import 'package:tell_me_a_story/features/family/manage_families_page.dart';
import 'package:tell_me_a_story/features/family/start_timeline_dialog.dart';
import 'package:tell_me_a_story/features/stories/new_story_page.dart';
import 'package:tell_me_a_story/features/stories/story_reader_page.dart';
import 'package:tell_me_a_story/features/timeline/timeline_page.dart';

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

class _People extends PeopleGateway {
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

class _Families extends FamiliesGateway {
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

class _EmptyDirectory implements FamilyDirectoryGateway {
  @override
  Future<FamilyDirectory> listDirectory() async {
    return const FamilyDirectory(active: [], recoverable: []);
  }

  @override
  Future<FamilyDetail?> loadDetail(String familyId) async => null;
}

class _Manage implements ManageFamiliesGateway {
  Object? error;
  var calls = 0;
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
    calls++;
    this.parentFamilyId = parentFamilyId;
    this.originStoryId = originStoryId;
    this.name = name;
    this.branchYear = branchYear;
    this.ownerUserId = ownerUserId;
    this.personIds = personIds;
    final failure = error;
    if (failure != null) throw failure;
    return 'new-family';
  }

  @override
  Future<String> createRootFamily(String name) async => 'root';

  @override
  Future<void> renameFamily({
    required String familyId,
    required String name,
  }) async {}

  @override
  Future<void> addCoOwner({
    required String familyId,
    required String userId,
  }) async {}

  @override
  Future<void> removeCoOwner({
    required String familyId,
    required String userId,
  }) async {}

  @override
  Future<void> removeMember({
    required String familyId,
    required String userId,
  }) async {}

  @override
  Future<void> transferOwnership({
    required String familyId,
    required String newOwnerUserId,
    required String formerOwnerBecomes,
  }) async {}

  @override
  Future<void> softDeleteFamily(String familyId) async {}

  @override
  Future<void> recoverFamily(String familyId) async {}

  @override
  Future<DateTime> resendInvite(String inviteId) async => DateTime.utc(2026);

  @override
  Future<void> revokeInvite(String inviteId) async {}
}

class _Invite implements InviteGateway {
  _Invite(this.familyId);

  final String? familyId;

  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    return const AcceptInviteResult(familyId: 'f', membershipId: 'm');
  }

  @override
  Future<String> createFamily(String name) async => _parent;

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
    String? personId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String?> currentFamilyId() async => familyId;

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {}
}

class _Stories implements StoriesGateway {
  @override
  Future<List<Story>> listLatestPublished(
    String familyId, {
    int withinDays = 7,
    int limit = 3,
    DateTime? now,
  }) async => const [];

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
  Future<bool> autosaveDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) {
    throw UnimplementedError();
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
  Future<List<Story>> listMyDrafts(String familyId) async => const [];

  @override
  Future<List<Story>> listPublished(String familyId) async {
    return published.where((story) => story.familyId == familyId).toList();
  }

  @override
  Future<void> discard(String storyId) async {}

  @override
  Future<void> linkPerson({
    required String storyId,
    required String personId,
  }) async {}
}

class _Photos implements PhotosGateway {
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

  @override
  Future<void> deletePhoto(Photo photo) async {}

  @override
  @override
  Future<void> setHeroPhoto({
    required String storyId,
    required String photoId,
  }) async {}

  @override
  Future<void> deleteAllForStory({
    required String familyId,
    required String storyId,
  }) async {}

  @override
  Future<Uint8List> downloadBytes(String storagePath) async => Uint8List(0);
}

class _Places implements PlacesGateway {
  _Places(this.rows);

  final List<Place> rows;

  @override
  Future<List<Place>> listPlaces(String familyId) async => rows;

  @override
  Future<List<Place>> listFavorites(String familyId) async => rows;

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async =>
      rows;

  @override
  Future<Place> createPlace({
    required String familyId,
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    bool isFavorite = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Place> markUsed(String placeId) async => rows.first;

  @override
  Future<Place> setFavorite({
    required String placeId,
    required bool isFavorite,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Place?> findByMapboxPlaceId(
    String familyId,
    String mapboxPlaceId,
  ) async => null;

  @override
  Future<Place?> getPlace(String id) async => null;
}

class _Comments implements CommentsGateway {
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

class _Perspectives implements PerspectivesGateway {
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
  await tester.pumpWidget(
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
                  familiesApi: families,
                  peopleApi: people,
                  manageApi: manage,
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
    FamilySelection.clear();
  });

  tearDown(FamilySelection.clear);

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
      _reader(story: _story(), families: families, manage: _Manage()),
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
      ),
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
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add a family branch from this story'), findsNothing);
  });

  testWidgets('the family menu branch row sits above Manage', (tester) async {
    await tester.pumpWidget(_header(onStart: () {}));
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
    await tester.pumpWidget(
      MaterialApp(
        home: DraftsPage(
          inviteApi: _Invite(_parent),
          storiesApi: _Stories(published: const []),
          familiesApi: _Families(
            mine: [
              MemberFamily(
                id: _parent,
                name: 'Parent',
                createdAt: DateTime.utc(1970),
              ),
            ],
          ),
        ),
      ),
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
    FamilySelection.remember(_parent);
    addTearDown(FamilySelection.clear);
    await tester.pumpWidget(
      MaterialApp(
        home: ManageFamiliesPage(
          directoryApi: _EmptyDirectory(),
          familiesApi: _Families(
            mine: [
              MemberFamily(
                id: _parent,
                name: 'Parent',
                createdAt: DateTime.utc(1970),
              ),
            ],
          ),
          manageApi: _Manage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('family-menu-start-timeline')), findsOneWidget);
    expect(find.text('Add a family branch to Parent'), findsOneWidget);
    expect(find.byKey(const Key('family-menu-invite')), findsOneWidget);
  });

  testWidgets('a tree-read open family hides the timeline row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TimelinePage(
          api: _Invite('bea'),
          storiesApi: _Stories(
            published: [_story(id: 'bea-story', familyId: 'bea', title: 'Bea')],
          ),
          familiesApi: _Families(
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
              StewardFamily(id: _parent, name: 'Parent', role: 'owner'),
            ],
          ),
          currentUserId: _me,
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
    expect(manage.calls, 0);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-timeline-write')));
    await tester.pumpAndSettle();
    expect(wrote, isTrue);
    expect(manage.calls, 0);
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
          Person(
            id: 'p-blank',
            familyId: _parent,
            name: ' ',
            relationship: 'Cousin',
            createdBy: _me,
          ),
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

    manage.error = ManageFamiliesException(
      code: 'VALIDATION',
      message: 'too many levels',
    );
    await _tapCreate(tester);
    await tester.pumpAndSettle();
    expect(find.text('too many levels'), findsOneWidget);
    expect(find.textContaining('VALIDATION:'), findsNothing);
    expect(find.byKey(const Key('start-timeline-dialog')), findsOneWidget);

    manage.error = ManageFamiliesException(code: 'NOT_FOUND', message: 'story');
    await _tapCreate(tester);
    await tester.pumpAndSettle();
    expect(
      find.text("That story isn't available anymore. Pick another one."),
      findsOneWidget,
    );
    expect(find.text('story'), findsNothing);

    manage.error = ManageFamiliesException(
      code: 'FORBIDDEN',
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

    manage.error = ManageFamiliesException(
      code: 'VALIDATION',
      message: 'create_branch_family returned no id',
    );
    await _tapCreate(tester);
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('create_branch_family returned no id'), findsNothing);
    expect(find.byKey(const Key('start-timeline-dialog')), findsOneWidget);

    manage.error = ManageFamiliesException(
      code: 'VALIDATION',
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
      ..error = ManageFamiliesException(code: 'NOT_FOUND', message: 'story');
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
    FamilySelection.remember(_parent);
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
    await tester.pumpWidget(
      MaterialApp(
        home: TimelinePage(
          api: _Invite(_parent),
          storiesApi: stories,
          familiesApi: families,
          peopleApi: _People(const []),
          manageApi: manage,
          currentUserId: _me,
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
    expect(FamilySelection.id, _parent);
    expect(families.treeLoads, greaterThan(loadsBefore));
    expect(find.text('Origin · from Parent'), findsNothing);
  });

  testWidgets('the reader toasts and does not leave the story', (tester) async {
    FamilySelection.remember(_parent);
    final manage = _Manage();
    final router = _readerRouter(
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
    await tester.pumpWidget(TellMeAStoryApp(router: router));
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
    expect(FamilySelection.id, _parent);
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
              inviteApi: _Invite(_parent),
              peopleApi: _People(const [
                Person(
                  id: 'p1',
                  familyId: _parent,
                  name: 'Ada',
                  relationship: 'Aunt',
                  createdBy: _me,
                ),
              ]),
              placesApi: _Places(const [
                Place(
                  id: 'pl1',
                  familyId: _parent,
                  label: 'Park',
                  address: 'Town',
                  lat: 1,
                  lng: 2,
                  isFavorite: true,
                ),
              ]),
              storiesApi: stories,
              photosApi: _Photos(),
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
            builder: (context, state) => TimelinePage(
              api: _Invite(_parent),
              storiesApi: stories,
              familiesApi: families,
              peopleApi: _People(const []),
              manageApi: manage,
              currentUserId: _me,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(TellMeAStoryApp(router: router));
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Save draft'));
      await tester.pumpAndSettle();
      expect(stories.publishCalls, 0);
      expect(manage.calls, 0);
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
      expect(manage.calls, 0);
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
              inviteApi: _Invite(_parent),
              peopleApi: _People(const []),
              placesApi: _Places(const []),
              storiesApi: stories,
              photosApi: _Photos(),
              hasMapboxToken: false,
              draftId: state.uri.queryParameters['draft'],
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(TellMeAStoryApp(router: router));
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
            inviteApi: _Invite(_parent),
            peopleApi: _People(const [
              Person(
                id: 'p1',
                familyId: _parent,
                name: 'Ada',
                relationship: 'Aunt',
                createdBy: _me,
              ),
            ]),
            placesApi: _Places(const [
              Place(
                id: 'pl1',
                familyId: _parent,
                label: 'Park',
                address: 'Town',
                lat: 1,
                lng: 2,
                isFavorite: true,
              ),
            ]),
            storiesApi: stories,
            photosApi: _Photos(),
            hasMapboxToken: false,
            draftId: state.uri.queryParameters['draft'],
          ),
        ),
        GoRoute(
          path: AppRoutes.timeline,
          builder: (context, state) => TimelinePage(
            api: _Invite(_parent),
            storiesApi: stories,
            familiesApi: families,
            peopleApi: _People(const []),
            manageApi: manage,
            currentUserId: _me,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(TellMeAStoryApp(router: router));
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
    expect(manage.calls, 0);
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
      await tester.pumpWidget(
        MaterialApp(
          home: NewStoryPage(
            inviteApi: _Invite(_parent),
            storiesApi: stories,
            peopleApi: _People(const []),
            placesApi: _Places(const []),
            photosApi: _Photos(),
            hasMapboxToken: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(manage.calls, 0);
      expect(stories.publishCalls, 0);
    },
  );

  testWidgets('a dated mark in an empty decade still shows on the far rail', (
    tester,
  ) async {
    const side = '00000000-0000-0000-0000-0000000000dd';
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: TimelinePage(
          api: _Invite(_parent),
          storiesApi: _Stories(
            published: [_story(year: 1984, title: 'Eighties')],
          ),
          familiesApi: _Families(
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
                branchYear: 1955,
              ),
            ],
          ),
          currentUserId: _me,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mark = find.byKey(const Key('timeline-branch-mark-$side'));
    await tester.ensureVisible(mark);
    await tester.pumpAndSettle();
    expect(mark, findsOneWidget);
    final label = tester.widget<Text>(
      find.textContaining('A very long family name'),
    );
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
  });

  testWidgets('a 1990 branch sits below the 1950s band', (tester) async {
    const later = '00000000-0000-0000-0000-0000000000ee';
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: TimelinePage(
          api: _Invite(_parent),
          storiesApi: _Stories(
            published: [_story(year: 1952, title: 'Fifties')],
          ),
          familiesApi: _Families(
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
                branchYear: 1990,
              ),
            ],
          ),
          currentUserId: _me,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final band = find.byKey(const Key('timeline-decade-row-1950'));
    final mark = find.byKey(const Key('timeline-branch-mark-$later'));
    await tester.ensureVisible(band);
    await tester.ensureVisible(mark);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(mark).dy, greaterThan(tester.getTopLeft(band).dy));
  });

  testWidgets('tapping the far end of a rail slot does nothing', (
    tester,
  ) async {
    const side = '00000000-0000-0000-0000-0000000000ff';
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    FamilySelection.remember(_parent);
    await tester.pumpWidget(
      MaterialApp(
        home: TimelinePage(
          api: _Invite(_parent),
          storiesApi: _Stories(
            published: [_story(year: 1984, title: 'Eighties')],
          ),
          familiesApi: _Families(
            mine: [
              MemberFamily(
                id: _parent,
                name: 'Parent',
                createdAt: DateTime.utc(1970),
              ),
              MemberFamily(
                id: side,
                name: 'Side',
                createdAt: DateTime.utc(1990),
              ),
            ],
            tree: const [
              TreeFamily(id: _parent, name: 'Parent'),
              TreeFamily(
                id: side,
                name: 'Side',
                parentFamilyId: _parent,
                branchYear: 1955,
              ),
            ],
          ),
          currentUserId: _me,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mark = find.byKey(const Key('timeline-branch-mark-$side'));
    await tester.ensureVisible(mark);
    await tester.pumpAndSettle();
    final markRect = tester.getRect(mark);
    final label = tester.getRect(find.text('Side · 1955'));
    expect(label.left, greaterThan(markRect.left));
    expect(label.left, lessThan(markRect.left + 40));
    final slot = find.ancestor(of: mark, matching: find.byType(Row)).last;
    final slotRect = tester.getRect(slot);
    expect(label.right, lessThan(slotRect.right - 40));
    await tester.tapAt(Offset(slotRect.right - 4, markRect.center.dy));
    await tester.pumpAndSettle();
    expect(FamilySelection.id, _parent);
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

Widget _reader({
  required Story story,
  required _Families families,
  required _Manage manage,
  bool publishedLookup = true,
}) {
  return TellMeAStoryApp(
    router: _readerRouter(
      story: story,
      families: families,
      manage: manage,
      publishedLookup: publishedLookup,
    ),
  );
}

GoRouter _readerRouter({
  required Story story,
  required _Families families,
  required _Manage manage,
  bool publishedLookup = true,
}) {
  return GoRouter(
    initialLocation: '/stories/${story.id}',
    routes: [
      GoRoute(
        path: '/timeline',
        builder: (context, state) => const Text('timeline-dest'),
      ),
      GoRoute(
        path: '/stories/:storyId',
        builder: (context, state) => StoryReaderPage(
          storyId: story.id,
          storiesApi: _ReaderStories(story, honorStatus: publishedLookup),
          peopleApi: _People(const []),
          placesApi: _Places(const []),
          photosApi: _Photos(),
          commentsApi: _Comments(),
          perspectivesApi: _Perspectives(),
          familiesApi: families,
          manageApi: manage,
          currentUserId: _me,
        ),
      ),
    ],
  );
}

class _ReaderStories implements StoriesGateway {
  @override
  Future<List<Story>> listLatestPublished(
    String familyId, {
    int withinDays = 7,
    int limit = 3,
    DateTime? now,
  }) async => const [];

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
  }) {
    throw UnimplementedError();
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
  }) {
    throw UnimplementedError();
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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Story> publish(String storyId) => throw UnimplementedError();

  @override
  Future<Story> getStory(String storyId) => throw UnimplementedError();

  @override
  Future<List<Story>> listMyDrafts(String familyId) async => const [];

  @override
  Future<List<Story>> listPublished(String familyId) async => const [];

  @override
  Future<void> discard(String storyId) async {}

  @override
  Future<void> linkPerson({
    required String storyId,
    required String personId,
  }) async {}
}
