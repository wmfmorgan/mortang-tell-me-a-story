@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/search_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';

import 'support/live_server.dart';
import 'support/story_fixtures.dart';

void main() {
  setUpAll(waitForLiveServer);

  test('facets and filters cover the family\'s published stories', () async {
    final client = await signInLive(freshEmail('search'));
    final family = await seedFamily(client);
    final ada = family.personId;
    final porch = family.placeId;
    final bea = await seedPerson(client, family.familyId, name: 'Bea');
    final mill = await seedPlace(client, family.familyId, label: 'Old Mill');
    final stories = StoriesApi();

    final summer = await stories.createDraft(
      familyId: family.familyId,
      timeframeStart: DateTime(1984, 6, 1),
      datePrecision: 'day',
      title: 'Summer Afternoon',
      body: 'We shelled peas on the porch.',
      placeId: porch,
      personIds: [ada],
    );
    await stories.publish(summer.id);
    final winter = await stories.createDraft(
      familyId: family.familyId,
      timeframeStart: DateTime(1962),
      timeframeEnd: DateTime(1962, 12, 31),
      datePrecision: 'year',
      title: 'Winter Mill',
      body: 'Snow on the wheel.',
      placeId: mill,
      personIds: [ada, bea],
    );
    await stories.publish(winter.id);
    await stories.createDraft(
      familyId: family.familyId,
      timeframeStart: DateTime(1999, 1, 1),
      title: 'Unpublished porch draft',
    );

    final api = SearchApi();
    final facets = await api.facets(family.familyId);
    expect(facets.decades, [1960, 1980]);
    expect(facets.people, [(id: ada, name: 'Ada'), (id: bea, name: 'Bea')]);
    expect(facets.places, [
      (id: porch, label: 'Back Porch'),
      (id: mill, label: 'Old Mill'),
    ]);

    Future<List<String>> ids(SearchRequest request) async => [
      for (final story in await api.search(request)) story.id,
    ];
    SearchRequest request({
      String text = '',
      List<String> personIds = const [],
      String? placeId,
      List<int> decades = const [],
      SearchSort sort = SearchSort.relevant,
    }) => SearchRequest(
      familyId: family.familyId,
      text: text,
      personIds: personIds,
      placeId: placeId,
      decades: decades,
      sort: sort,
    );

    expect(await ids(request(text: 'porch')), [summer.id]);
    expect(await ids(request(personIds: [ada, bea])), [winter.id]);
    expect(
      await ids(request(personIds: [ada], sort: SearchSort.chronological)),
      [summer.id, winter.id],
    );
    expect(await ids(request(placeId: mill)), [winter.id]);
    expect(await ids(request(decades: const [1980])), [summer.id]);
    expect(await ids(request(sort: SearchSort.recentlyAdded)), [
      winter.id,
      summer.id,
    ]);

    final hit = (await api.search(request(text: 'winter'))).single;
    expect(hit.title, 'Winter Mill');
    expect(hit.placeLabel, 'Old Mill');
    expect(hit.personNames, ['Ada', 'Bea']);
    expect(hit.timeframeStart, DateTime(1962));
    expect(hit.datePrecision, StoryDatePrecision.year);

    final stranger = SearchApi(
      client: await signInLive(freshEmail('search-stranger')),
    );
    await expectLater(
      stranger.facets(family.familyId),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.forbidden,
        ),
      ),
    );
  });
}
