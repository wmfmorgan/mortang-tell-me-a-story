import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/family_thread_page.dart';
import 'package:tell_me_a_story/features/family_thread/thread_skeleton.dart';

import '../../support/family_thread_surface.dart';
import '../../support/quiet_gateways.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(FamilySelection.clear);

  testWidgets('shows skeleton and Loading stories while loading', (
    tester,
  ) async {
    final pending = Completer<List<Story>>();
    await tester.pumpWidget(
      _host(
        stories: ThreadStories(const [], pending: pending.future),
        families: _Families(),
      ),
    );

    expect(find.byType(ThreadSkeleton), findsOneWidget);
    expect(find.byKey(const Key('thread-skeleton-beat')), findsNWidgets(5));
    expect(find.bySemanticsLabel('Loading stories'), findsOneWidget);

    pending.complete([_story('kept')]);
    await tester.pumpAndSettle();
    expect(find.byType(ThreadSkeleton), findsNothing);
    expect(find.byKey(const Key('family-thread-loaded')), findsOneWidget);
  });

  testWidgets('shows FT-37 text when zero published', (tester) async {
    await tester.pumpWidget(
      _host(stories: ThreadStories(const []), families: _Families()),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No stories yet. Capture the first one for this family.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Retry'), findsNothing);
    expect(find.byType(ThreadSkeleton), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Title && widget.title == 'Family Thread',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Family Thread'), findsWidgets);
  });

  testWidgets(
    "shows Couldn't load stories. and Retry on gateway error; Retry reloads",
    (tester) async {
      final stories = ThreadStories(const [], fail: true);
      await tester.pumpWidget(_host(stories: stories, families: _Families()));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load stories."), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(stories.listCalls, 1);

      stories.fail = false;
      stories.rows = [_story('kept')];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load stories."), findsNothing);
      expect(find.byKey(const Key('family-thread-loaded')), findsOneWidget);
      expect(stories.listCalls, 2);
    },
  );

  testWidgets('merges a published origin story once', (tester) async {
    final stories = ThreadStories(const [], origin: _story('origin'));
    await tester.pumpWidget(
      _host(
        stories: stories,
        families: _Families(originStoryId: 'origin'),
      ),
    );
    await tester.pumpAndSettle();

    expect(stories.getPublishedIds, ['origin']);
    expect(find.byKey(const Key('family-thread-loaded')), findsOneWidget);
    expect(
      find.text('No stories yet. Capture the first one for this family.'),
      findsNothing,
    );

    final present = ThreadStories([_story('origin')]);
    await tester.pumpWidget(
      _host(
        stories: present,
        families: _Families(originStoryId: 'origin'),
      ),
    );
    await tester.pumpAndSettle();
    expect(present.getPublishedIds, isEmpty);
    expect(find.byKey(const Key('family-thread-loaded')), findsOneWidget);

    final draft = ThreadStories(
      const [],
      origin: _story('origin', status: StoryStatus.draft),
    );
    await tester.pumpWidget(
      _host(
        stories: draft,
        families: _Families(originStoryId: 'origin'),
      ),
    );
    await tester.pumpAndSettle();
    expect(draft.getPublishedIds, ['origin']);
    expect(
      find.text('No stories yet. Capture the first one for this family.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the load error and Retry when the families read fails', (
    tester,
  ) async {
    final families = _Families(fail: true);
    await tester.pumpWidget(
      _host(stories: ThreadStories(const []), families: families),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load stories."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    families.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load stories."), findsNothing);
    expect(
      find.text('No stories yet. Capture the first one for this family.'),
      findsOneWidget,
    );
  });
}

Widget _host({required ThreadStories stories, required _Families families}) {
  return MaterialApp(
    theme: albumTheme(),
    home: FamilyThreadPage(
      key: UniqueKey(),
      storiesApi: stories,
      familiesApi: families,
      currentUserId: () => 'user-1',
      live: FakeTimelineLive(),
    ),
  );
}

class _Families extends FamiliesGateway with QuietFamiliesDefaults {
  _Families({this.originStoryId, this.fail = false});

  final String? originStoryId;
  bool fail;

  @override
  Future<List<MemberFamily>> listMine() async {
    if (fail) throw const FormatException('families');
    return [_member];
  }

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];

  @override
  Future<List<TreeFamily>> listFamilyTree(String familyId) async {
    return [
      TreeFamily(id: _familyId, name: 'Ada', originStoryId: originStoryId),
    ];
  }
}

const _familyId = 'fam-1';

final _member = MemberFamily(
  id: _familyId,
  name: 'Ada',
  createdAt: DateTime.utc(2020),
);

Story _story(String id, {StoryStatus status = StoryStatus.published}) {
  return Story(
    id: id,
    familyId: _familyId,
    authorId: 'author',
    status: status,
    timeframeStart: DateTime.utc(1982, 1, 1),
  );
}
