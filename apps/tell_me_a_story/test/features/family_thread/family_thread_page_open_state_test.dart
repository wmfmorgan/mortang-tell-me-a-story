import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/family_thread_density.dart';
import 'package:tell_me_a_story/data/family_thread_open_state.dart';
import 'package:tell_me_a_story/data/family_thread_open_state_store.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/family_thread_page.dart';
import 'package:tell_me_a_story/features/family_thread/thread_skeleton.dart';

import '../../fakes/quiet_stories.dart';
import '../../support/family_thread_surface.dart';
import '../../support/quiet_gateways.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(FamilySelection.clear);

  testWidgets('restores saved density and story before first frame', (
    tester,
  ) async {
    final stories = Completer<List<Story>>();
    final store = _MemoryStore(gate: Completer<FamilyThreadOpenState?>());
    await tester.pumpWidget(
      _host(ThreadStories(const [], pending: stories.future), store: store),
    );
    expect(find.byType(ThreadSkeleton), findsOneWidget);

    await tester.pump();
    stories.complete(_pair());
    await tester.pump();
    expect(find.byType(ThreadSkeleton), findsOneWidget);

    store.gate!.complete(
      const FamilyThreadOpenState(
        density: FamilyThreadDensity.read,
        storyId: 'older',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(ThreadSkeleton), findsNothing);
    expectOnFocusLine(tester, 'Older');
    expect(find.text('Older letter'), findsOneWidget);
    expect(find.text('Newest letter'), findsNothing);
  });

  testWidgets('nothing saved opens Browse on newest', (tester) async {
    final store = _MemoryStore();
    await tester.pumpWidget(_host(ThreadStories(_pair()), store: store));
    await tester.pumpAndSettle();

    expectOnFocusLine(tester, 'Newest');
    expect(find.text('Newest letter'), findsNothing);
    expect(find.text('Older'), findsOneWidget);
  });

  testWidgets(
    'storage failure (store read returns null) opens Browse on newest',
    (tester) async {
      var preferenceCalls = 0;
      final store = FamilyThreadOpenStateStore(
        currentUserId: () => _failUser,
        preferences: () {
          preferenceCalls += 1;
          throw PlatformException(code: 'failed');
        },
      );
      await tester.pumpWidget(
        _host(
          ThreadStories(_pair()),
          families: TestFamilies([
            MemberFamily(
              id: _failFamily,
              name: 'Ada',
              createdAt: DateTime.utc(2020),
            ),
          ]),
          store: store,
        ),
      );
      await tester.pumpAndSettle();

      expect(preferenceCalls, 1);
      expectOnFocusLine(tester, 'Newest');
      expect(find.text('Newest letter'), findsNothing);
    },
  );

  testWidgets('saved story gone opens saved density on newest', (tester) async {
    final store = _MemoryStore(
      saved: {
        'fam-1': const FamilyThreadOpenState(
          density: FamilyThreadDensity.overview,
          storyId: 'missing',
        ),
      },
    );
    await tester.pumpWidget(_host(ThreadStories(_pair()), store: store));
    await tester.pumpAndSettle();

    expectOnFocusLine(tester, '2000s · 1 story');
    expect(find.text('Newest letter'), findsNothing);
  });

  testWidgets('filters never restored', (tester) async {
    final store = _MemoryStore(
      saved: {
        'fam-1': const FamilyThreadOpenState(
          density: FamilyThreadDensity.browse,
          storyId: 'older',
        ),
      },
    );
    await tester.pumpWidget(_host(ThreadStories(_pair()), store: store));
    await tester.pumpAndSettle();

    expect(find.text('Older'), findsOneWidget);
    expect(find.text('Newest'), findsOneWidget);
  });

  testWidgets('writes on settle and on density change', (tester) async {
    final store = _MemoryStore();
    await tester.pumpWidget(_host(ThreadStories(_pair()), store: store));
    await tester.pumpAndSettle();
    expect(store.writes, isEmpty);

    await _drag(tester, const Offset(0, 90));
    await tester.pumpAndSettle();
    expect(store.writes.single.familyId, 'fam-1');
    expect(store.writes.single.state.storyId, 'older');
    expect(store.writes.single.state.density, FamilyThreadDensity.browse);

    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    expect(store.writes.last.state.density, FamilyThreadDensity.read);
    expect(store.writes.last.state.storyId, 'older');
  });

  testWidgets('family switch reads the new family key', (tester) async {
    final store = _MemoryStore(
      saved: {
        'fam-a': const FamilyThreadOpenState(
          density: FamilyThreadDensity.browse,
          storyId: 'a-old',
        ),
        'fam-b': const FamilyThreadOpenState(
          density: FamilyThreadDensity.read,
          storyId: 'b-story',
        ),
      },
    );
    await tester.pumpWidget(
      _host(_ByFamily(_branches()), families: _twoFamilies, store: store),
    );
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, 'Ada older');

    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu-item-fam-b')));
    await tester.pumpAndSettle();

    expect(store.reads, contains('fam-b'));
    expectOnFocusLine(tester, 'Branch story');
    expect(find.text('Branch letter'), findsOneWidget);
  });

  testWidgets(
    'stored story not in list falls back and no gateway call uses it',
    (tester) async {
      final stories = _RecordingStories(_pair());
      final store = _MemoryStore(
        saved: {
          'fam-1': const FamilyThreadOpenState(
            density: FamilyThreadDensity.browse,
            storyId: 'stored-missing',
          ),
        },
      );
      await tester.pumpWidget(_host(stories, store: store));
      await tester.pumpAndSettle();

      expect(stories.listed, ['fam-1']);
      expect(stories.getPublishedIds, isNot(contains('stored-missing')));
      expectOnFocusLine(tester, 'Newest');
      expect(find.text('Newest letter'), findsNothing);
    },
  );

  testWidgets(
    'family missing from memberships removes its key and opens default',
    (tester) async {
      FamilySelection.remember('fam-gone');
      final store = _MemoryStore(
        saved: {
          'fam-gone': const FamilyThreadOpenState(
            density: FamilyThreadDensity.read,
            storyId: 'older',
          ),
        },
      );
      await tester.pumpWidget(
        _host(
          _ByFamily({'fam-gone': _pair(), 'fam-home': _pair()}),
          families: _TreeOnly(),
          store: store,
        ),
      );
      await tester.pumpAndSettle();

      expect(store.removed, ['fam-gone']);
      expect(store.reads, isNot(contains('fam-gone')));
      expectOnFocusLine(tester, 'Newest');
      expect(find.text('Older letter'), findsNothing);
    },
  );
}

Future<void> _drag(WidgetTester tester, Offset delta) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(ListView)),
  );
  await gesture.moveBy(delta);
  await tester.pump(const Duration(milliseconds: 70));
  await gesture.moveBy(Offset(0, delta.dy.sign));
  await tester.pump(const Duration(milliseconds: 70));
  await gesture.up();
}

Widget _host(
  StoriesGateway stories, {
  required FamilyThreadOpenStateStore store,
  FamiliesGateway? families,
}) {
  return MaterialApp(
    theme: albumTheme(),
    home: FamilyThreadPage(
      storiesApi: stories,
      familiesApi: families ?? _oneFamily,
      openStateStore: store,
      currentUserId: () => 'user-1',
      live: FakeTimelineLive(),
    ),
  );
}

class _MemoryStore extends FamilyThreadOpenStateStore {
  _MemoryStore({
    Map<String, FamilyThreadOpenState?> saved = const {},
    this.gate,
  }) : saved = Map<String, FamilyThreadOpenState?>.of(saved);

  final Map<String, FamilyThreadOpenState?> saved;
  final reads = <String>[];
  final writes = <({String familyId, FamilyThreadOpenState state})>[];
  final removed = <String>[];
  final Completer<FamilyThreadOpenState?>? gate;

  @override
  Future<FamilyThreadOpenState?> read({required String familyId}) {
    reads.add(familyId);
    final gate = this.gate;
    if (gate != null && !gate.isCompleted) return gate.future;
    return Future<FamilyThreadOpenState?>.value(saved[familyId]);
  }

  @override
  Future<void> write({
    required String familyId,
    required FamilyThreadOpenState state,
  }) async {
    writes.add((familyId: familyId, state: state));
    saved[familyId] = state;
  }

  @override
  Future<void> remove({required String familyId}) async {
    removed.add(familyId);
    saved.remove(familyId);
  }
}

class _ByFamily extends QuietStories {
  _ByFamily(this.byFamily);

  final Map<String, List<Story>> byFamily;

  @override
  Future<List<Story>> listPublished(String familyId) async {
    return byFamily[familyId] ?? const [];
  }
}

class _RecordingStories extends ThreadStories {
  _RecordingStories(super.rows);

  final listed = <String>[];

  @override
  Future<List<Story>> listPublished(String familyId) async {
    listed.add(familyId);
    return super.listPublished(familyId);
  }
}

class _TreeOnly extends FamiliesGateway with QuietFamiliesDefaults {
  @override
  Future<List<MemberFamily>> listMine() async => [
    MemberFamily(id: 'fam-home', name: 'Home', createdAt: DateTime.utc(2020)),
  ];

  @override
  Future<List<TreeFamily>> listFamilyTree(String familyId) async {
    final name = familyId == 'fam-gone' ? 'Gone' : 'Home';
    return [TreeFamily(id: familyId, name: name)];
  }

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];
}

List<Story> _pair() {
  return [
    _story('older', 1990, 'Older', body: 'Older letter'),
    _story('new', 2004, 'Newest', body: 'Newest letter'),
  ];
}

Map<String, List<Story>> _branches() {
  return {
    'fam-a': [
      _story('a-old', 1990, 'Ada older', familyId: 'fam-a'),
      _story('a-new', 2004, 'Ada newest', familyId: 'fam-a'),
    ],
    'fam-b': [
      _story(
        'b-story',
        1998,
        'Branch story',
        body: 'Branch letter',
        familyId: 'fam-b',
      ),
    ],
  };
}

Story _story(
  String id,
  int year,
  String title, {
  String? body,
  String familyId = 'fam-1',
}) {
  return Story(
    id: id,
    familyId: familyId,
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year, 6, 1),
    datePrecision: StoryDatePrecision.year,
    title: title,
    body: body,
  );
}

const _failUser = '22222222-2222-4222-8222-222222222222';
const _failFamily = '11111111-1111-4111-8111-111111111111';

final _oneFamily = TestFamilies([
  MemberFamily(id: 'fam-1', name: 'Ada', createdAt: DateTime.utc(2020)),
]);

final _twoFamilies = TestFamilies([
  MemberFamily(id: 'fam-a', name: 'Ada', createdAt: DateTime.utc(2020)),
  MemberFamily(id: 'fam-b', name: 'Branch', createdAt: DateTime.utc(2021)),
]);
