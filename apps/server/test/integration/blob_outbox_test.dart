import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/media/blob_keys.dart';
import 'package:tell_me_a_story_server/src/media/blob_outbox.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given the blob deletion queue', (sessionBuilder, endpoints) {
    late Session session;

    String uniqueKey() => 'test/${const Uuid().v7()}.jpg';

    Future<List<BlobDeletion>> rowsFor(String key) =>
        BlobDeletion.db.find(session, where: (t) => t.key.equals(key));

    setUp(() => session = sessionBuilder.build());

    test(
      'when the queuing transaction fails then nothing is queued',
      () async {
        final key = uniqueKey();
        await expectLater(
          session.db.transaction((t) async {
            await queueBlobDeletions(session, [key, null], transaction: t);
            throw StateError('purge failed');
          }),
          throwsStateError,
        );
        expect(await rowsFor(key), isEmpty);
      },
    );

    test('when the drain runs then the blob and its row are gone', () async {
      final key = uniqueKey();
      await session.storage.storeFile(
        storageId: blobStorageId,
        path: key,
        byteData: ByteData.sublistView(Uint8List.fromList([1, 2, 3])),
      );
      await queueBlobDeletions(session, [key]);

      await drainBlobDeletions(session);

      expect(await rowsFor(key), isEmpty);
      expect(
        await session.storage.fileExists(storageId: blobStorageId, path: key),
        isFalse,
      );
    });

    test(
      'when a blob delete fails then its row stays with one more attempt',
      () async {
        final key = uniqueKey();
        await queueBlobDeletions(session, [key]);

        await drainBlobDeletions(
          session,
          delete: (k) async {
            if (k == key) throw StateError('storage down');
          },
        );

        final rows = await rowsFor(key);
        expect(rows.single.attempts, 1);
      },
    );

    test(
      'when one blob delete fails then the rest of the batch still drains',
      () async {
        final failing = uniqueKey();
        final good = uniqueKey();
        await queueBlobDeletions(session, [failing, good]);

        await drainBlobDeletions(
          session,
          delete: (k) async {
            if (k == failing) throw StateError('storage down');
          },
        );

        expect(await rowsFor(good), isEmpty);
        expect((await rowsFor(failing)).single.attempts, 1);
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
