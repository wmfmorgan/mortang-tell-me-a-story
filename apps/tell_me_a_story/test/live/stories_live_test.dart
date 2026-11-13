@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:uuid/uuid.dart';

import 'support/live_server.dart';
import 'support/story_fixtures.dart';

Matcher clientError(AppErrorCode code) =>
    throwsA(isA<AppException>().having((e) => e.code, 'code', code));

void main() {
  setUpAll(waitForLiveServer);

  test('a draft becomes a published story the family reads', () async {
    final client = await signInLive(freshEmail('stories'));
    final family = await seedFamily(client);
    final api = StoriesApi();
    final id = const Uuid().v4();

    final draft = await api.createDraft(
      id: id,
      familyId: family.familyId,
      allowUndated: true,
      title: 'Jam',
    );
    expect(draft.id, id);
    expect(draft.familyId, family.familyId);
    expect(draft.authorId, client.auth.authInfo!.authUserId.toString());
    expect(draft.status, StoryStatus.draft);
    expect(draft.timeframeStart, isNull);

    final again = await api.createDraft(
      id: id,
      familyId: family.familyId,
      allowUndated: true,
      body: 'Porch',
    );
    expect(again.id, id);
    expect(again.title, 'Jam');
    expect(again.body, 'Porch');
    expect((await api.listMyDrafts(family.familyId)).map((s) => s.id), [id]);

    final updated = await api.updateDraft(
      storyId: id,
      timeframeStart: DateTime(1987, 3, 1),
      timeframeEnd: DateTime(1987, 3, 31),
      datePrecision: 'month',
      title: 'Blackberry jam',
      body: 'We made jam on the porch.',
      placeId: family.placeId,
      personIds: [family.personId],
    );
    expect(updated.timeframeStart, DateTime(1987, 3, 1));
    expect(updated.timeframeEnd, DateTime(1987, 3, 31));
    expect(updated.datePrecision, StoryDatePrecision.month);
    expect(updated.placeId, family.placeId);
    expect(updated.placeLabel, 'Back Porch');
    expect(updated.personIds, [family.personId]);
    expect(updated.people.single.name, 'Ada');

    expect(
      await api.autosaveDraft(storyId: id, title: 'Blackberry jam!'),
      isTrue,
    );
    expect((await api.getStory(id)).title, 'Blackberry jam!');

    await api.linkPerson(storyId: id, personId: family.personId);
    expect((await api.getStory(id)).personIds, [family.personId]);

    final photoKey = await seedPhoto(client, id);

    final published = await api.publish(id);
    expect(published.status, StoryStatus.published);
    expect(published.publishedAt, isNotNull);
    expect(await api.autosaveDraft(storyId: id, title: 'Too late'), isFalse);
    expect(await api.listMyDrafts(family.familyId), isEmpty);

    expect((await api.getPublished(id))?.photoPaths, [photoKey]);
    expect((await api.getPublishedOrigin(id))?.id, id);
    expect((await api.listPublished(family.familyId)).map((s) => s.id), [id]);
    expect((await api.listLatestPublished(family.familyId)).map((s) => s.id), [
      id,
    ]);

    final card = (await api.storiesForPerson(family.personId)).single;
    expect(card.id, id);
    expect(card.title, 'Blackberry jam!');
    expect(card.whenLabel, 'March 1987');
    expect(card.place, 'Back Porch');
    expect(card.photoCount, 1);
    expect(card.thumbBytes, livePng);

    final thumbs = await downloadFirstThumbs([published], null);
    expect(thumbs[id], livePng);

    await api.discard(id);
    expect(await api.getPublished(id), isNull);
    await expectLater(api.getStory(id), clientError(AppErrorCode.notFound));
  });

  test('another user neither reads nor discards the story', () async {
    final owner = await signInLive(freshEmail('stories-owner'));
    final family = await seedFamily(owner);
    final mine = StoriesApi(client: owner);
    final story = await mine.createDraft(
      familyId: family.familyId,
      timeframeStart: DateTime(1990),
      timeframeEnd: DateTime(1990, 12, 31),
      datePrecision: 'year',
      title: 'Kept',
      body: 'Body',
      placeId: family.placeId,
      personIds: [family.personId],
    );
    await mine.publish(story.id);

    final stranger = StoriesApi(
      client: await signInLive(freshEmail('stories-stranger')),
    );
    expect(await stranger.getPublished(story.id), isNull);
    await expectLater(
      stranger.discard(story.id),
      clientError(AppErrorCode.forbidden),
    );
    await expectLater(
      stranger.listPublished(family.familyId),
      clientError(AppErrorCode.forbidden),
    );
    expect((await mine.getPublished(story.id))?.title, 'Kept');
  });

  test('a root member reads a branch story through the tree read', () async {
    final client = await signInLive(freshEmail('stories-tree'));
    final family = await seedFamily(client);
    final api = StoriesApi(client: client);
    Future<Story> published(String familyId, int year, String title) async {
      final draft = await api.createDraft(
        familyId: familyId,
        timeframeStart: DateTime(year),
        timeframeEnd: DateTime(year, 12, 31),
        datePrecision: 'year',
        title: title,
        body: 'Body',
        placeId: family.placeId,
        personIds: [family.personId],
      );
      return api.publish(draft.id);
    }

    final origin = await published(family.familyId, 1990, 'Root');
    final branchId = await client.family.createBranch(
      parentFamilyId: UuidValue.fromString(family.familyId),
      originStoryId: UuidValue.fromString(origin.id),
      name: 'Branch',
      branchYear: 1995,
      ownerUserId: client.auth.authInfo!.authUserId,
      personIds: const [],
    );
    final branchStory = await published(branchId.toString(), 1950, 'Branch');

    expect((await api.listPublishedInTree(family.familyId)).map((s) => s.id), [
      branchStory.id,
      origin.id,
    ]);
    expect(
      (await api.listPublishedInTree(branchId.toString()))
          .map((s) => s.familyId),
      [branchId.toString(), family.familyId],
    );

    final stranger = StoriesApi(
      client: await signInLive(freshEmail('stories-tree-stranger')),
    );
    await expectLater(
      stranger.listPublishedInTree(family.familyId),
      clientError(AppErrorCode.forbidden),
    );
  });
}
