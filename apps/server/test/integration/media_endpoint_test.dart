import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/photo_fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given MediaEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    setUp(() => fx = Fx(sessionBuilder.build()));

    Future<List<int>?> read(UuidValue user, String key) async {
      final data = await endpoints.media.get(asUser(sessionBuilder, user), key);
      return data == null ? null : bytesOf(data);
    }

    test('when an anonymous caller reads then unauthenticated', () async {
      await expectLater(
        endpoints.media.get(sessionBuilder, 'users/x/avatar/y.jpg'),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    // BR 90
    test(
      'Given draft edit, then author reads original and edited blobs; other '
      'member cannot read edited blob; tree reader reads published original',
      () async {
        final author = await fx.user();
        final other = await fx.user();
        final reader = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, author);
        await fx.join(family, other);
        final child = await fx.family(
          Tree(id: family.treeId),
          parentId: family.id,
        );
        await fx.join(child, reader);
        final draft = await fx.story(
          family,
          authorId: author,
          status: StoryStatus.draft,
        );
        final edited = await fx.photo(draft, uploaderId: author, edited: true);
        final published = await fx.photo(
          await fx.story(family, authorId: author),
          uploaderId: author,
        );

        expect(await read(author, edited.originalKey), bytesOf(jpegBytes()));
        expect(await read(author, edited.editedKey!), bytesOf(pngBytes()));
        expect(await read(other, edited.editedKey!), isNull);
        expect(await read(reader, edited.originalKey), isNull);
        expect(
          await read(reader, published.originalKey),
          bytesOf(jpegBytes()),
        );
      },
    );

    // BR 80
    test(
      'Given malformed or unknown keys, then get returns null without errors',
      () async {
        final user = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, user);
        for (final key in [
          '',
          '../etc/passwd',
          'families/${family.id}/x/y/original.jpg',
          'families/${family.id}/stories/not-a-uuid/photos/1/original.jpg',
          'families/${family.id}/stories/${const Uuid().v7()}/photos/'
              '${const Uuid().v7()}/original.jpg',
        ]) {
          expect(await read(user, key), isNull, reason: key);
        }
      },
    );

    // BR 80
    test(
      'Given tree reader, when getMany mixes readable, unreadable and unknown '
      'keys, then only the readable ones come back',
      () async {
        final author = await fx.user();
        final reader = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, author);
        final child = await fx.family(
          Tree(id: family.treeId),
          parentId: family.id,
        );
        await fx.join(child, reader);
        final visible = await fx.photo(
          await fx.story(family, authorId: author),
        );
        final hidden = await fx.photo(
          await fx.story(family, authorId: author, status: StoryStatus.draft),
        );

        final got = await endpoints.media.getMany(
          asUser(sessionBuilder, reader),
          [visible.originalKey, hidden.originalKey, 'families/x/../../y', ''],
        );

        expect(got.keys, [visible.originalKey]);
        expect(bytesOf(got[visible.originalKey]!), bytesOf(jpegBytes()));
      },
    );

    test(
      'when the row exists but its blob is missing then get returns null '
      'and getMany omits it',
      () async {
        final author = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, author);
        final photo = await fx.photo(await fx.story(family, authorId: author));
        await fx.s.storage.deleteFile(
          storageId: 'private',
          path: photo.originalKey,
        );

        expect(await read(author, photo.originalKey), isNull);
        expect(
          await endpoints.media.getMany(asUser(sessionBuilder, author), [
            photo.originalKey,
          ]),
          isEmpty,
        );
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
