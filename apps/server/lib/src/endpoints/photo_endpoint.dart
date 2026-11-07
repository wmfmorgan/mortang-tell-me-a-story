import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';

/// Story photos (business-rules.md §2.7 without edit save/reset, §4.5; upload
/// flow schema-design.md §4.2).
class PhotoEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// The story's photos, hero first.
  Future<List<PhotoDto>> list(Session session, UuidValue storyId) async {
    final story = await Story.db.findById(session, storyId);
    if (story == null || !await Authz(session).canReadStory(story)) {
      throw forbidden();
    }
    final rows = await Photo.db.find(
      session,
      where: (t) => t.storyId.equals(storyId),
      orderByList: _order,
    );
    return [for (final photo in rows) _dto(photo, story)];
  }

  static List<Order> _order(PhotoTable t) => [
    t.sortOrder.asc(),
    t.createdAt.asc(),
    t.id.asc(),
  ];

  static PhotoDto _dto(Photo photo, Story story) => PhotoDto(
    id: photo.id!,
    storyId: photo.storyId,
    familyId: story.familyId,
    uploaderId: photo.uploaderId,
    originalKey: photo.originalKey,
    editedKey: photo.editedKey,
    editVersion: photo.editVersion,
    sortOrder: photo.sortOrder,
  );
}
