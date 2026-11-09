import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// Channel names shared by every writer and by `LiveEndpoint` (slice 3f).
String familyChannel(UuidValue familyId) => 'family:$familyId';
String storyChannel(UuidValue storyId) => 'story:$storyId';
String treeChannel(UuidValue treeId) => 'tree:$treeId';

/// Posts [event] to its family channel, to the story channel when it names a
/// story, and to [treeId]'s tree channel. Call it only AFTER the write's
/// transaction has committed, so subscribers never see a change that rolled
/// back. Local delivery only (no Redis): one server instance, as in
/// serverpod-notes.md §8.
Future<void> postLiveEvent(
  Session session,
  LiveEventDto event, {
  required UuidValue treeId,
}) async {
  await session.messages.postMessage(familyChannel(event.familyId), event);
  final storyId = event.storyId;
  if (storyId != null) {
    await session.messages.postMessage(storyChannel(storyId), event);
  }
  await session.messages.postMessage(treeChannel(treeId), event);
}

/// Posts a `family` event for [family] to its tree channel only: the tree's
/// set of live families changed (a branch was created, or [family] was
/// soft-deleted when [deleted], or recovered). Same after-commit rule as
/// [postLiveEvent].
Future<void> postFamilyEvent(
  Session session,
  Family family, {
  bool deleted = false,
}) => session.messages.postMessage(
  treeChannel(family.treeId),
  LiveEventDto(familyId: family.id!, kind: LiveKind.family, deleted: deleted),
);
