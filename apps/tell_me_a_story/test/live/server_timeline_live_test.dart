@Tags(['live'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/data/timeline_live.dart';

import 'support/live_server.dart';
import 'support/story_fixtures.dart';

/// Long enough for a fresh method stream to open on the WebSocket.
const _subscribed = Duration(seconds: 1);
const _deadline = Duration(seconds: 10);

void main() {
  setUpAll(waitForLiveServer);

  test('the timeline hears a publish and the reader an update', () async {
    final client = await signInLive(freshEmail('live'));
    final family = await seedFamily(client);
    final stories = StoriesApi(client: client);
    final draft = await stories.createDraft(
      familyId: family.familyId,
      timeframeStart: DateTime(1975, 7, 4),
      title: 'Fireworks',
      body: 'Over the lake.',
      placeId: family.placeId,
      personIds: [family.personId],
    );
    final live = ServerTimelineLive(client: client);
    addTearDown(live.dispose);

    final familyChanged = Completer<void>();
    live.watch(
      familyId: family.familyId,
      onChange: () {
        if (!familyChanged.isCompleted) familyChanged.complete();
      },
    );
    await Future<void>.delayed(_subscribed);
    await stories.publish(draft.id);
    await familyChanged.future.timeout(_deadline);

    final storyChanged = Completer<void>();
    live.watchStory(
      storyId: draft.id,
      onChange: () {
        if (!storyChanged.isCompleted) storyChanged.complete();
      },
    );
    await Future<void>.delayed(_subscribed);
    await stories.updateDraft(storyId: draft.id, title: 'Fireworks!');
    await storyChanged.future.timeout(_deadline);
  });
}
