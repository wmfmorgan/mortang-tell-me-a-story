import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// Channel names shared by every writer and by `LiveEndpoint` (slice 3f).
String familyChannel(UuidValue familyId) => 'family:$familyId';
String storyChannel(UuidValue storyId) => 'story:$storyId';

/// Posts [event] to its family channel and, when it names a story, to the
/// story channel. Call it only AFTER the write's transaction has committed,
/// so subscribers never see a change that rolled back. Local delivery only
/// (no Redis): one server instance, as in serverpod-notes.md §8.
Future<void> postLiveEvent(Session session, LiveEventDto event) async {
  await session.messages.postMessage(familyChannel(event.familyId), event);
  final storyId = event.storyId;
  if (storyId != null) {
    await session.messages.postMessage(storyChannel(storyId), event);
  }
}
