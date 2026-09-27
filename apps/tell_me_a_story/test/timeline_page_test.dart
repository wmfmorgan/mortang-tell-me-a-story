import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
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
  Future<List<Story>> listMyDrafts(String familyId) async => const [];

  @override
  Future<List<Story>> listPublished(String familyId) async {
    return published.where((s) => s.familyId == familyId).toList();
  }

  @override
  Future<void> discard(String storyId) async {}
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
  String? body = 'Jam',
  DateTime? timeframeStart,
  DateTime? timeframeEnd,
}) {
  return Story(
    id: id,
    familyId: _familyId,
    authorId: 'u1',
    body: body,
    timeframeStart: timeframeStart ?? DateTime(1980, 1, 1),
    timeframeEnd: timeframeEnd ?? DateTime(1989, 12, 31),
    placeId: 'pl',
    status: StoryStatus.published,
    personIds: const ['p'],
    publishedAt: DateTime(2026, 9, 27),
  );
}

Widget _timeline({required StoriesGateway stories}) {
  return MaterialApp(
    home: TimelinePage(
      api: _FakeInviteApi(),
      storiesApi: stories,
    ),
  );
}

void main() {
  testWidgets('empty published list shows locked empty copy', (tester) async {
    await tester.pumpWidget(_timeline(stories: _FakeStoriesApi(published: [])));
    await tester.pumpAndSettle();

    expect(
      find.text('No stories yet. Capture the first one for this family.'),
      findsOneWidget,
    );
    expect(find.text('Timeline'), findsWidgets);
  });

  testWidgets('published story preview appears after listPublished',
      (tester) async {
    await tester.pumpWidget(
      _timeline(stories: _FakeStoriesApi(published: [_published()])),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Jam'), findsOneWidget);
    expect(find.text('1980s'), findsOneWidget);
  });

  testWidgets('loading published shows small progress', (tester) async {
    await tester.pumpWidget(_timeline(stories: _SlowStoriesApi()));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AppBar actions are New story, Drafts, + Invite', (tester) async {
    await tester.pumpWidget(_timeline(stories: _FakeStoriesApi(published: [])));
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<TextButton>(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(TextButton),
          ),
        )
        .map((button) => (button.child as Text).data)
        .toList();
    expect(labels, ['New story', 'Drafts', '+ Invite']);
  });
}
