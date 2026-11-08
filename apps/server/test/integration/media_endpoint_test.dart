import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/media/blob_keys.dart';
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

    // BR 25
    test(
      'Given a family cover, member can read it; non-member cannot; member '
      'of soft-deleted family cannot',
      () async {
        final member = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, member);
        final key = await fx.cover(family);

        expect(await read(member, key), bytesOf(jpegBytes()));
        expect(await read(await fx.user(), key), isNull);

        await fx.softDelete((await Family.db.findById(fx.s, family.id!))!);
        expect(await read(member, key), isNull);
      },
    );

    test(
      'Given a person avatar, a member of any live family in the tree reads '
      "it, also after the person's home family is soft-deleted; an outsider "
      'cannot',
      () async {
        final cousin = await fx.user();
        final tree = await fx.tree();
        final home = await fx.family(tree);
        final other = await fx.family(tree, name: 'Other');
        await fx.join(other, cousin);
        final key = await fx.personAvatar(await fx.person(home));

        expect(await read(cousin, key), bytesOf(jpegBytes()));
        expect(await read(await fx.user(), key), isNull);

        await fx.softDelete(home);
        expect(await read(cousin, key), bytesOf(jpegBytes()));
      },
    );

    test(
      'Given a user avatar, the user and a co-member of a live family read '
      'it; a stranger, or a co-member only through a soft-deleted family, '
      'cannot',
      () async {
        final owner = await fx.user();
        final coMember = await fx.user();
        final formerCoMember = await fx.user();
        final live = await fx.family(await fx.tree());
        await fx.join(live, owner);
        await fx.join(live, coMember);
        final deleted = await fx.family(
          await fx.tree(),
          deletedAt: DateTime.now().toUtc(),
        );
        await fx.join(deleted, owner);
        await fx.join(deleted, formerCoMember);
        final key = await fx.userAvatar(owner);

        expect(await read(owner, key), bytesOf(jpegBytes()));
        expect(await read(coMember, key), bytesOf(jpegBytes()));
        expect(await read(formerCoMember, key), isNull);
        expect(await read(await fx.user(), key), isNull);
      },
    );

    test(
      'when getMany asks for a cover, a person avatar and a user avatar '
      'then each is checked on its own row',
      () async {
        final member = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, member);
        final cover = await fx.cover(family);
        final avatar = await fx.personAvatar(await fx.person(family));
        final mine = await fx.userAvatar(member);
        final strangers = await fx.userAvatar(await fx.user());

        final got = await endpoints.media.getMany(
          asUser(sessionBuilder, member),
          [cover, avatar, mine, strangers],
        );

        expect(got.keys.toSet(), {cover, avatar, mine});
      },
    );

    test(
      'when getMany asks for more than mediaManyMaxKeys keys then VALIDATION; '
      'exactly the cap is served',
      () async {
        final member = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, member);
        final cover = await fx.cover(family);
        final session = asUser(sessionBuilder, member);
        final atCap = [
          cover,
          for (var i = 1; i < mediaManyMaxKeys; i++) 'unknown/$i',
        ];

        expect(
          (await endpoints.media.getMany(session, atCap)).keys,
          [cover],
        );
        await expectLater(
          endpoints.media.getMany(session, [...atCap, 'one/more']),
          throwsAppError(AppErrorCode.validation, 'too many keys'),
        );
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
