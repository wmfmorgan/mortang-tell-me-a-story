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

  /// Events for [storyId]: whoever may read the story (`canReadStory`).
  Stream<LiveEventDto> watchStory(Session session, UuidValue storyId) async* {
    final story = await Story.db.findById(session, storyId);
    if (story == null || !await Authz(session).canReadStory(story)) {
      throw forbidden();
    }
    yield* session.messages.createStream<LiveEventDto>(storyChannel(storyId));
  }
}
