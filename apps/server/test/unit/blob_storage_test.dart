import 'package:tell_me_a_story_server/src/media/blob_storage.dart';
import 'package:test/test.dart';

void main() {
  group('Given chooseBlobStorage', () {
    test('when the server is local then blobs stay in the database', () {
      expect(
        chooseBlobStorage(local: true, gcsBucket: null),
        isA<DatabaseBlobStorage>(),
      );
    });

    test('when the server is local and a bucket is set then blobs still '
        'stay in the database', () {
      expect(
        chooseBlobStorage(local: true, gcsBucket: 'story-line-app-blobs'),
        isA<DatabaseBlobStorage>(),
      );
    });

    test('when the server is not local and a bucket is set then blobs go '
        'to that GCS bucket', () {
      final choice = chooseBlobStorage(
        local: false,
        gcsBucket: ' story-line-app-blobs ',
      );
      expect(
        choice,
        isA<GcsBlobStorage>().having(
          (c) => c.bucket,
          'bucket',
          'story-line-app-blobs',
        ),
      );
    });

    for (final bucket in [null, '', '   ']) {
      test('when the server is not local and the bucket is "$bucket" then it '
          'fails closed', () {
        expect(
          () => chooseBlobStorage(local: false, gcsBucket: bucket),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('gcsBucket'),
            ),
          ),
        );
      });
    }
  });
}
