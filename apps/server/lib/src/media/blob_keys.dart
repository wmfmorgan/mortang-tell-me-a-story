import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../errors.dart';

/// Every blob lives in this storage (schema-design.md §4.2).
const blobStorageId = 'private';

/// Size limits per object, same as the old buckets (schema-design.md §4.2).
const photoMaxBytes = 52428800;
const coverMaxBytes = 5242880;
const avatarMaxBytes = 2097152;

const _extByMime = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

/// File extension for a supported image MIME type; anything else is
/// `AppException(validation, 'unsupported image type')`.
String extForMime(String mimeType) =>
    _extByMime[mimeType] ?? (throw validation('unsupported image type'));

String _newBlobId() => const Uuid().v7();

String photoOriginalKey({
  required UuidValue familyId,
  required UuidValue storyId,
  required UuidValue photoId,
  required String mimeType,
}) =>
    'families/$familyId/stories/$storyId/photos/$photoId/original.'
    '${extForMime(mimeType)}';

String photoEditedKey({
  required UuidValue familyId,
  required UuidValue storyId,
  required UuidValue photoId,
  required int editVersion,
}) =>
    'families/$familyId/stories/$storyId/photos/$photoId/edited-$editVersion.jpg';

/// [blobId] defaults to a fresh UUID v7; every replacement gets a new key.
String familyCoverKey({
  required UuidValue familyId,
  required String mimeType,
  String? blobId,
}) =>
    'families/$familyId/cover/${blobId ?? _newBlobId()}.${extForMime(mimeType)}';

String personAvatarKey({
  required UuidValue treeId,
  required UuidValue personId,
  String? blobId,
}) => 'trees/$treeId/people/$personId/avatar/${blobId ?? _newBlobId()}.jpg';

String userAvatarKey({required UuidValue authUserId, String? blobId}) =>
    'users/$authUserId/avatar/${blobId ?? _newBlobId()}.jpg';

/// The image type named by the first bytes of [data]: JPEG `FF D8 FF`,
/// PNG `89 50 4E 47 0D 0A 1A 0A`, WebP `RIFF????WEBP`. Null for anything else.
String? sniffImageMime(ByteData data) {
  final b = Uint8List.sublistView(data);
  bool at(int offset, List<int> magic) {
    if (b.length < offset + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (b[offset + i] != magic[i]) return false;
    }
    return true;
  }

  if (at(0, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) return 'image/webp';
  return null;
}
