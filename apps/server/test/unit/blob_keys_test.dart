import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/media/blob_keys.dart';
import 'package:test/test.dart';

ByteData bytes(List<int> b) => ByteData.sublistView(Uint8List.fromList(b));

void main() {
  final family = UuidValue.fromString('0190d7a0-0000-7000-8000-000000000001');
  final story = UuidValue.fromString('0190d7a0-0000-7000-8000-000000000002');
  final photo = UuidValue.fromString('0190d7a0-0000-7000-8000-000000000003');
  final tree = UuidValue.fromString('0190d7a0-0000-7000-8000-000000000004');
  final person = UuidValue.fromString('0190d7a0-0000-7000-8000-000000000005');
  const blob = '0190d7a0-0000-7000-8000-0000000000ff';

  group('keys follow schema-design.md §4.2', () {
    test('photo original and edited', () {
      expect(
        photoOriginalKey(
          familyId: family,
          storyId: story,
          photoId: photo,
          mimeType: 'image/png',
        ),
        'families/$family/stories/$story/photos/$photo/original.png',
      );
      expect(
        photoEditedKey(
          familyId: family,
          storyId: story,
          photoId: photo,
          editVersion: 3,
        ),
        'families/$family/stories/$story/photos/$photo/edited-3.jpg',
      );
    });

    test('cover and avatars get a fresh blob id', () {
      expect(
        familyCoverKey(familyId: family, mimeType: 'image/webp', blobId: blob),
        'families/$family/cover/$blob.webp',
      );
      expect(
        personAvatarKey(treeId: tree, personId: person, blobId: blob),
        'trees/$tree/people/$person/avatar/$blob.jpg',
      );
      expect(
        userAvatarKey(authUserId: person, blobId: blob),
        'users/$person/avatar/$blob.jpg',
      );
      expect(
        familyCoverKey(familyId: family, mimeType: 'image/jpeg'),
        isNot(familyCoverKey(familyId: family, mimeType: 'image/jpeg')),
      );
    });

    test('keys use only lowercase, digits, dash, slash and dot', () {
      final key = familyCoverKey(familyId: family, mimeType: 'image/jpeg');
      expect(key, matches(RegExp(r'^[a-z0-9\-/.]+$')));
    });

    test('an unsupported type is a validation error', () {
      expect(
        () => familyCoverKey(familyId: family, mimeType: 'image/svg+xml'),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.validation,
          ),
        ),
      );
    });
  });

  group('sniffImageMime reads magic bytes', () {
    test('jpeg, png and webp', () {
      expect(sniffImageMime(bytes([0xFF, 0xD8, 0xFF, 0xE0, 0])), 'image/jpeg');
      expect(
        sniffImageMime(bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])),
        'image/png',
      );
      expect(
        sniffImageMime(
          bytes([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]),
        ),
        'image/webp',
      );
    });

    test('anything else, or too short, is null', () {
      expect(sniffImageMime(bytes('<svg'.codeUnits)), isNull);
      expect(sniffImageMime(bytes([0xFF, 0xD8])), isNull);
      expect(
        sniffImageMime(
          bytes([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WAVE'.codeUnits]),
        ),
        isNull,
      );
    });
  });
}
