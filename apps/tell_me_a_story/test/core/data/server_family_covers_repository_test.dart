import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/data/server_family_covers_repository.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/cover_photo_exception.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

void main() {
  test('a server refusal on a cover call shows the cover copy', () async {
    await expectLater(
      withCoverErrors<void>(
        () async => throw server.AppException(
          code: server.AppErrorCode.forbidden,
          message: 'owner or co-owner only',
        ),
      ),
      throwsA(
        isA<CoverPhotoException>().having(
          (e) => e.message,
          'message',
          'Couldn’t save the family photo. Try again.',
        ),
      ),
    );
  });

  test('a storage failure stays a StorageFailedException', () async {
    await expectLater(
      withCoverErrors<void>(() async => throw const StorageFailedException()),
      throwsA(isA<StorageFailedException>()),
    );
  });

  test('a successful call returns its value', () async {
    expect(await withCoverErrors(() async => 'key'), 'key');
  });
}
