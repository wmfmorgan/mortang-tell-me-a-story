@Tags(['live'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story/core/data/server_stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/session/server_timeline_live.dart';

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
    final stories = ServerStoriesRepository(client: client);
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

  test('the tree hears a new branch and a publish in it', () async {
    final client = await signInLive(freshEmail('live-tree'));
    final family = await seedFamily(client);
    final stories = ServerStoriesRepository(client: client);
    Future<Story> draftIn(String familyId, String title) => stories.createDraft(
      familyId: familyId,
      timeframeStart: DateTime(1975, 7, 4),
      title: title,
      body: 'Over the lake.',
      placeId: family.placeId,
      personIds: [family.personId],
    );
    final origin = await stories.publish(
      (await draftIn(family.familyId, 'Origin')).id,
    );
    final live = ServerTimelineLive(client: client);
    addTearDown(live.dispose);

    var changed = Completer<void>();
    live.watchTree(
      familyId: family.familyId,
      onChange: () {
        if (!changed.isCompleted) changed.complete();
      },
    );
    await Future<void>.delayed(_subscribed);
    final branchId = await client.family.createBranch(
      parentFamilyId: UuidValue.fromString(family.familyId),
      originStoryId: UuidValue.fromString(origin.id),
      name: 'Branch',
      branchYear: 1995,
      ownerUserId: client.auth.authInfo!.authUserId,
      personIds: const [],
    );
    await changed.future.timeout(_deadline);

    final draft = await draftIn(branchId.toString(), 'Branch story');
    changed = Completer<void>();
    await stories.publish(draft.id);
    await changed.future.timeout(_deadline);
  });
}
