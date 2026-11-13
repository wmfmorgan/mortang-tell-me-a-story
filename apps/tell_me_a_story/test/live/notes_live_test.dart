@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/comments_api.dart';
import 'package:tell_me_a_story/data/perspectives_api.dart';

import 'support/live_server.dart';
import 'support/story_fixture.dart';

void main() {
  setUpAll(waitForLiveServer);

  test('comments: create, list, update and delete', () async {
    final owner = await signInLive(freshEmail('comments'));
    final (familyId, storyId) = await liveFamilyStory(owner, publish: true);
    final api = CommentsApi();

    final created = await api.create(
      storyId: storyId,
      familyId: familyId,
      body: '  First note ',
    );
    expect(created.body, 'First note');
    expect(created.storyId, storyId);
    expect(created.familyId, familyId);
    expect(created.canDelete, isTrue);

    await api.update(id: created.id, body: 'Edited note');
    final listed = await api.listForStory(storyId);
    expect(listed.map((c) => c.body), ['Edited note']);
    expect(listed.single.authorId, isNotNull);

    await api.delete(created.id);
    expect(await api.listForStory(storyId), isEmpty);
  });

  test(
    'perspectives: create, list, update and delete, apart from comments',
    () async {
      final owner = await signInLive(freshEmail('perspectives'));
      final (familyId, storyId) = await liveFamilyStory(owner, publish: true);
      final api = PerspectivesApi();
      await CommentsApi().create(
        storyId: storyId,
        familyId: familyId,
        body: 'A comment',
      );

      final created = await api.create(
        storyId: storyId,
        familyId: familyId,
        body: 'My telling',
      );
      expect(created.canDelete, isTrue);

      await api.update(id: created.id, body: 'A clearer telling');
      expect((await api.listForStory(storyId)).map((p) => p.body), [
        'A clearer telling',
      ]);

      await api.delete(created.id);
      expect(await api.listForStory(storyId), isEmpty);
    },
  );

  test('canDelete: owner may delete a member note, member may not delete the '
      'owner note (D4)', () async {
    final owner = await signInLive(freshEmail('notes-owner'));
    final member = await signInLive(freshEmail('notes-member'));
    final (familyId, storyId) = await liveFamilyStory(owner, publish: true);
    await joinLiveFamily(owner, member, familyId);

    final ownerComments = CommentsApi(client: owner);
    final memberComments = CommentsApi(client: member);
    final ownerPerspectives = PerspectivesApi(client: owner);
    final memberPerspectives = PerspectivesApi(client: member);

    final ownerNote = await ownerComments.create(
      storyId: storyId,
      familyId: familyId,
      body: 'Owner note',
    );
    final memberNote = await memberComments.create(
      storyId: storyId,
      familyId: familyId,
      body: 'Member note',
    );
    final memberView = await memberPerspectives.create(
      storyId: storyId,
      familyId: familyId,
      body: 'Member telling',
    );

    final seenByMember = {
      for (final c in await memberComments.listForStory(storyId))
        c.id: c.canDelete,
    };
    expect(seenByMember, {ownerNote.id: false, memberNote.id: true});
    await expectLater(
      memberComments.delete(ownerNote.id),
      throwsA(isA<AppException>()),
    );

    final seenByOwner = {
      for (final c in await ownerComments.listForStory(storyId))
        c.id: c.canDelete,
    };
    expect(seenByOwner, {ownerNote.id: true, memberNote.id: true});
    expect(
      (await ownerPerspectives.listForStory(storyId)).single.canDelete,
      isTrue,
    );

    await ownerComments.delete(memberNote.id);
    await ownerPerspectives.delete(memberView.id);
    expect((await ownerComments.listForStory(storyId)).map((c) => c.id), [
      ownerNote.id,
    ]);
    expect(await ownerPerspectives.listForStory(storyId), isEmpty);
  });
}
