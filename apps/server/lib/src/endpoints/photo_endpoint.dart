import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';
import '../live/live_events.dart';
import '../media/blob_keys.dart';
import '../media/blob_outbox.dart';

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

  /// The image types a story photo may have.
  static const _mimeTypes = ['image/jpeg', 'image/png', 'image/webp'];

  /// Verifies the uploaded blob for [photoId], checks its bytes and the cap,
  /// and writes the row. On any failure the blob is queued for deletion,
  /// except when the row already exists (the blob is that row's).
  Future<PhotoDto> finishUpload(
    Session session,
    UuidValue storyId,
    UuidValue photoId,
    int sortOrder,
  ) async {
    final story = await _contributable(session, storyId);
    final uploaderId = Authz(session).requireUser();
    final (
      photo,
      error,
    ) = await session.db.transaction<(Photo?, AppException?)>((t) async {
      // Serializes the cap count and the double-finish check per story.
      await Story.db.findById(
        session,
        storyId,
        transaction: t,
        lockMode: LockMode.forNoKeyUpdate,
      );
      if (await Photo.db.findById(session, photoId, transaction: t) != null) {
        return (null, validation('photo already added'));
      }
      final keys = {
        for (final mime in _mimeTypes)
          mime: photoOriginalKey(
            familyId: story.familyId,
            storyId: storyId,
            photoId: photoId,
            mimeType: mime,
          ),
      };
      String? declared;
      for (final MapEntry(key: mime, value: key) in keys.entries) {
        if (await session.storage.verifyUpload(
          storageId: blobStorageId,
          path: key,
        )) {
          declared = mime;
          break;
        }
      }
      if (declared == null) {
        await queueBlobDeletions(session, keys.values, transaction: t);
        return (
          null,
          AppException(
            code: AppErrorCode.storageFailed,
            message: 'upload not found',
          ),
        );
      }
      final key = keys[declared]!;
      final refused = await _checkUpload(
        session,
        storyId,
        key,
        declared,
        t,
      );
      if (refused != null) {
        await queueBlobDeletions(session, [key], transaction: t);
        return (null, refused);
      }
      final row = await Photo.db.insertRow(
        session,
        Photo(
          id: photoId,
          storyId: storyId,
          uploaderId: uploaderId,
          originalKey: key,
          sortOrder: sortOrder,
        ),
        transaction: t,
      );
      return (row, null);
    });
    if (error != null) throw error;
    await _postIfPublished(session, story, deleted: false);
    return _dto(photo!, story);
  }

  /// Why the verified blob at [key] can't become a photo of its story, or
  /// null: size, sniffed type against [declared], then the cap (under the
  /// story lock held by [t]).
  Future<AppException?> _checkUpload(
    Session session,
    UuidValue storyId,
    String key,
    String declared,
    Transaction t,
  ) async {
    final ByteData bytes;
    try {
      bytes = await session.storage.retrieveFile(
        storageId: blobStorageId,
        path: key,
      );
    } on CloudStorageException {
      return AppException(
        code: AppErrorCode.storageFailed,
        message: 'upload not found',
      );
    }
    if (bytes.lengthInBytes > photoMaxBytes) {
      return validation('photo is too large');
    }
    final sniffed = sniffImageMime(bytes);
    if (sniffed == null) return validation('unsupported image type');
    if (sniffed != declared) return validation('image type does not match');
    final count = await Photo.db.count(
      session,
      where: (p) => p.storyId.equals(storyId),
      transaction: t,
    );
    return count >= maxPhotos ? _photoCap() : null;
  }

  /// Posts a `photo` event for a published [story]; drafts post nothing.
  Future<void> _postIfPublished(
    Session session,
    Story story, {
    required bool deleted,
  }) async {
    if (story.status != StoryStatus.published) return;
    await postLiveEvent(
      session,
      LiveEventDto(
        familyId: story.familyId,
        storyId: story.id,
        kind: LiveKind.photo,
        storyStatus: story.status,
        deleted: deleted,
      ),
    );
  }

  /// Deletes the row; its original and edited keys are queued in the same
  /// transaction.
  Future<void> delete(Session session, UuidValue photoId) async {
    final photo = await Photo.db.findById(session, photoId);
    final story = photo == null
        ? null
        : await Story.db.findById(session, photo.storyId);
    if (photo == null ||
        story == null ||
        !await _canChange(session, story, photo)) {
      throw forbidden();
    }
    await session.db.transaction((t) async {
      final deleted = await Photo.db.deleteWhere(
        session,
        where: (p) => p.id.equals(photoId),
        transaction: t,
      );
      await queueBlobDeletions(session, [
        for (final row in deleted) ...[row.originalKey, row.editedKey],
      ], transaction: t);
    });
    await _postIfPublished(session, story, deleted: true);
  }

  /// Delete and reorder: `canContribute` AND (uploader OR `canEditStory`)
  /// (business-rules.md §2.7).
  Future<bool> _canChange(Session session, Story story, Photo photo) async {
    final authz = Authz(session);
    final uid = authz.userId;
    final mayTouch =
        (uid != null && photo.uploaderId == uid) ||
        await authz.canEditStory(story);
    return mayTouch && await authz.canContribute(story);
  }

  /// Makes [photoId] the hero: one transaction rewrites the story's
  /// `sortOrder` to 0..n-1 with it first, keeping the others' order.
  Future<void> setHero(
    Session session,
    UuidValue storyId,
    UuidValue photoId,
  ) async {
    final photo = await Photo.db.findById(session, photoId);
    final story = await Story.db.findById(session, storyId);
    if (photo == null ||
        story == null ||
        photo.storyId != storyId ||
        !await _canChange(session, story, photo)) {
      throw forbidden();
    }
    await session.db.transaction((t) async {
      await Story.db.findById(
        session,
        storyId,
        transaction: t,
        lockMode: LockMode.forNoKeyUpdate,
      );
      final rows = await Photo.db.find(
        session,
        where: (p) => p.storyId.equals(storyId),
        orderByList: _order,
        transaction: t,
      );
      final ordered = [
        ...rows.where((p) => p.id == photoId),
        ...rows.where((p) => p.id != photoId),
      ];
      final changed = [
        for (final (i, p) in ordered.indexed)
          if (p.sortOrder != i) p.copyWith(sortOrder: i),
      ];
      if (changed.isEmpty) return;
      await Photo.db.update(
        session,
        changed,
        columns: (p) => [p.sortOrder],
        transaction: t,
      );
    });
    await _postIfPublished(session, story, deleted: false);
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
