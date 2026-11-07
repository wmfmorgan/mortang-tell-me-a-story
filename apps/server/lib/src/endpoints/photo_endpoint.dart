import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';
import '../media/blob_keys.dart';

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

  /// Photos per story (business-rules.md §4.5).
  static const maxPhotos = 20;

  /// Authorizes an upload of [byteLength] bytes of [mimeType] and returns the
  /// server-built key with its upload description.
  Future<PhotoUploadTicketDto> startUpload(
    Session session,
    UuidValue storyId,
    String mimeType,
    int byteLength,
  ) async {
    final story = await _contributable(session, storyId);
    final photoId = const Uuid().v7obj();
    final key = photoOriginalKey(
      familyId: story.familyId,
      storyId: storyId,
      photoId: photoId,
      mimeType: mimeType,
    );
    if (byteLength <= 0) throw validation('photo is empty');
    if (byteLength > photoMaxBytes) throw validation('photo is too large');
    final count = await Photo.db.count(
      session,
      where: (t) => t.storyId.equals(storyId),
    );
    if (count >= maxPhotos) throw _photoCap();
    final description = await session.storage.createUploadDescription(
      storageId: blobStorageId,
      path: key,
      options: UploadOptions(
        maxFileSize: photoMaxBytes,
        contentLength: byteLength,
        preventOverwrite: true,
      ),
    );
    return PhotoUploadTicketDto(
      photoId: photoId,
      key: key,
      uploadDescription: description,
    );
  }

  /// The story when the caller may add photos to it (`canContribute`).
  Future<Story> _contributable(Session session, UuidValue storyId) async {
    final story = await Story.db.findById(session, storyId);
    if (story == null || !await Authz(session).canContribute(story)) {
      throw forbidden();
    }
    return story;
  }

  static AppException _photoCap() =>
      AppException(code: AppErrorCode.photoCap, message: 'photo limit reached');

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
