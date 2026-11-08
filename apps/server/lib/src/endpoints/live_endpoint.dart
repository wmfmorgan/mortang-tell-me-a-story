import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';
import '../live/live_events.dart';

/// Live change streams. Authorized once, at subscribe.
class LiveEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Events for [familyId]: live members and tree readers.
  Stream<LiveEventDto> watchFamily(Session session, UuidValue familyId) async* {
    final authz = Authz(session);
    if (!await authz.isLiveMember(familyId) &&
        !await authz.isTreeReadable(familyId)) {
      throw forbidden('member only');
    }
    yield* session.messages.createStream<LiveEventDto>(familyChannel(familyId));
  }

  /// Events for every live family in [familyId]'s tree (`tree:<treeId>`):
  /// story, photo and note events of each family, and a `family` event when
  /// a family of the tree is created, soft-deleted or recovered. Tree readers
  /// of live [familyId] (`isTreeReadable`, which every live member passes).
  Stream<LiveEventDto> watchTree(Session session, UuidValue familyId) async* {
    if (!await Authz(session).isTreeReadable(familyId)) {
      throw forbidden('member only');
    }
    final family = (await Family.db.findById(session, familyId))!;
    yield* session.messages.createStream<LiveEventDto>(
      treeChannel(family.treeId),
    );
  }

  /// Events for [storyId]: whoever may read the story (`canReadStory`).
  Stream<LiveEventDto> watchStory(Session session, UuidValue storyId) async* {
    final story = await Story.db.findById(session, storyId);
    if (story == null || !await Authz(session).canReadStory(story)) {
      throw forbidden();
    }
    yield* session.messages.createStream<LiveEventDto>(storyChannel(storyId));
  }
}
