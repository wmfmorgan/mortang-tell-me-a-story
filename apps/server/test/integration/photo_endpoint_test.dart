import 'dart:typed_data';

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

  withServerpod('Given PhotoEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    setUp(() => fx = Fx(sessionBuilder.build()));

    /// A live family with [members] and a story by [author].
    Future<(Family, Story)> familyStory(
      UuidValue author, {
      List<UuidValue> members = const [],
      StoryStatus status = StoryStatus.published,
      MembershipRole authorRole = MembershipRole.member,
    }) async {
      final family = await fx.family(await fx.tree());
      await fx.join(family, author, authorRole);
      for (final member in members) {
        await fx.join(family, member);
      }
      final story = await fx.story(family, authorId: author, status: status);
      return (family, story);
    }

    /// startUpload + client upload of [data] + finishUpload, as [user].
    Future<PhotoDto> upload(
      UuidValue user,
      Story story, {
      String mimeType = 'image/jpeg',
      ByteData? data,
      int sortOrder = 0,
    }) async {
      final bytes = data ?? jpegBytes();
      final as = asUser(sessionBuilder, user);
      final ticket = await endpoints.photo.startUpload(
        as,
        story.id!,
        mimeType,
        bytes.lengthInBytes,
      );
      await fx.clientUpload(ticket.key, bytes);
      return endpoints.photo.finishUpload(
        as,
        story.id!,
        ticket.photoId,
        sortOrder,
      );
    }

    test('when an anonymous caller lists then unauthenticated', () async {
      final story = (await familyStory(await fx.user())).$2;
      await expectLater(
        endpoints.photo.list(sessionBuilder, story.id!),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    test(
      'when a member lists a published story then photos come hero first '
      'with the familyId derived from the story',
      () async {
        final member = await fx.user();
        final (family, story) = await familyStory(member);
        final second = await fx.photo(story, sortOrder: 1);
        final hero = await fx.photo(story, sortOrder: 0);

        final photos = await endpoints.photo.list(
          asUser(sessionBuilder, member),
          story.id!,
        );

        expect(photos.map((p) => p.id), [hero.id, second.id]);
        expect(photos.first.familyId, family.id);
        expect(photos.first.originalKey, hero.originalKey);
      },
    );

    test(
      'when a tree reader lists a published story then allowed; '
      'a draft, a non-author on a draft or a stranger then FORBIDDEN',
      () async {
        final author = await fx.user();
        final other = await fx.user();
        final reader = await fx.user();
        final (family, published) = await familyStory(
          author,
          members: [other],
        );
        final draft = await fx.story(
          family,
          authorId: author,
          status: StoryStatus.draft,
        );
        final child = await fx.family(
          Tree(id: family.treeId),
          parentId: family.id,
        );
        await fx.join(child, reader);
        await fx.photo(published);

        expect(
          await endpoints.photo.list(
            asUser(sessionBuilder, reader),
            published.id!,
          ),
          hasLength(1),
        );
        for (final (user, story) in [
          (reader, draft),
          (other, draft),
          (await fx.user(), published),
        ]) {
          await expectLater(
            endpoints.photo.list(asUser(sessionBuilder, user), story.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
        }
      },
    );

    test(
      'when a member starts an upload then the ticket names a fresh key '
      "under the story's family",
      () async {
        final member = await fx.user();
        final (family, story) = await familyStory(member);

        final ticket = await endpoints.photo.startUpload(
          asUser(sessionBuilder, member),
          story.id!,
          'image/png',
          100,
        );

        expect(
          ticket.key,
          'families/${family.id}/stories/${story.id}/photos/'
          '${ticket.photoId}/original.png',
        );
        expect(ticket.uploadDescription, isNotEmpty);
      },
    );

    test(
      'when the type is unsupported or the size is out of range '
      'then VALIDATION',
      () async {
        final member = await fx.user();
        final story = (await familyStory(member)).$2;
        final as = asUser(sessionBuilder, member);
        for (final (mime, size, message) in [
          ('image/gif', 100, 'unsupported image type'),
          ('image/jpeg', 0, 'photo is empty'),
          ('image/jpeg', photoMaxBytes + 1, 'photo is too large'),
        ]) {
          await expectLater(
            endpoints.photo.startUpload(as, story.id!, mime, size),
            throwsAppError(AppErrorCode.validation, message),
          );
        }
      },
    );

    // BR 78
    test(
      'Given story with 20 photos, when attaching 21st, '
      'then "photo limit reached"',
      () async {
        final member = await fx.user();
        final story = (await familyStory(member)).$2;
        for (var i = 0; i < 20; i++) {
          await fx.photo(story, sortOrder: i);
        }
        await expectLater(
          endpoints.photo.startUpload(
            asUser(sessionBuilder, member),
            story.id!,
            'image/jpeg',
            100,
          ),
          throwsAppError(AppErrorCode.photoCap, 'photo limit reached'),
        );
      },
    );

    // BR 27
    test(
      'Given parent member (tree reader), when inserting photo on child '
      'story, then refused',
      () async {
        final parentMember = await fx.user();
        final childMember = await fx.user();
        final parent = await fx.family(await fx.tree());
        await fx.join(parent, parentMember);
        final child = await fx.family(
          Tree(id: parent.treeId),
          parentId: parent.id,
        );
        await fx.join(child, childMember);
        final story = await fx.story(child, authorId: childMember);

        await expectLater(
          endpoints.photo.startUpload(
            asUser(sessionBuilder, parentMember),
            story.id!,
            'image/jpeg',
            100,
          ),
          throwsAppError(AppErrorCode.forbidden),
        );
      },
    );

    test(
      'when a member finishes an upload then the row is written with the '
      'caller as uploader and the blob is verified',
      () async {
        final member = await fx.user();
        final (family, story) = await familyStory(member);

        final dto = await upload(member, story, sortOrder: 3);

        final row = await Photo.db.findById(fx.s, dto.id);
        expect(row!.uploaderId, member);
        expect(row.sortOrder, 3);
        expect(row.originalKey, dto.originalKey);
        expect(dto.familyId, family.id);
        expect(dto.originalKey, endsWith('/${dto.id}/original.jpg'));
        expect(await fx.blobExists(dto.originalKey), isTrue);
      },
    );

    test(
      'when the bytes are not an image or differ from the declared type '
      'then VALIDATION, no row, and the blob is queued',
      () async {
        final member = await fx.user();
        final story = (await familyStory(member)).$2;
        final as = asUser(sessionBuilder, member);
        for (final (mime, data, message) in [
          ('image/jpeg', textBytes(), 'unsupported image type'),
          ('image/png', jpegBytes(), 'image type does not match'),
        ]) {
          final ticket = await endpoints.photo.startUpload(
            as,
            story.id!,
            mime,
            data.lengthInBytes,
          );
          await fx.clientUpload(ticket.key, data);
          await expectLater(
            endpoints.photo.finishUpload(as, story.id!, ticket.photoId, 0),
            throwsAppError(AppErrorCode.validation, message),
          );
          expect(await Photo.db.findById(fx.s, ticket.photoId), isNull);
          expect(await fx.queued([ticket.key]), {ticket.key});
        }
      },
    );

    test(
      'when nothing was uploaded then STORAGE_FAILED and no row',
      () async {
        final member = await fx.user();
        final story = (await familyStory(member)).$2;
        final as = asUser(sessionBuilder, member);
        final ticket = await endpoints.photo.startUpload(
          as,
          story.id!,
          'image/jpeg',
          10,
        );
        await expectLater(
          endpoints.photo.finishUpload(as, story.id!, ticket.photoId, 0),
          throwsAppError(AppErrorCode.storageFailed, 'upload not found'),
        );
        expect(await Photo.db.findById(fx.s, ticket.photoId), isNull);
      },
    );

    test(
      'when the same upload is finished twice then VALIDATION and the '
      "row's blob is not queued",
      () async {
        final member = await fx.user();
        final story = (await familyStory(member)).$2;
        final dto = await upload(member, story);

        await expectLater(
          endpoints.photo.finishUpload(
            asUser(sessionBuilder, member),
            story.id!,
            dto.id,
            0,
          ),
          throwsAppError(AppErrorCode.validation, 'photo already added'),
        );
        expect(await fx.queued([dto.originalKey]), isEmpty);
        expect(await fx.blobExists(dto.originalKey), isTrue);
      },
    );

    // BR 78
    test(
      'Given story at 19 photos, when another photo lands between start and '
      'finish, then "photo limit reached" and the blob is queued',
      () async {
        final member = await fx.user();
        final story = (await familyStory(member)).$2;
        for (var i = 0; i < 19; i++) {
          await fx.photo(story, sortOrder: i);
        }
        final as = asUser(sessionBuilder, member);
        final ticket = await endpoints.photo.startUpload(
          as,
          story.id!,
          'image/jpeg',
          jpegBytes().lengthInBytes,
        );
        await fx.clientUpload(ticket.key, jpegBytes());
        await fx.photo(story, sortOrder: 19);

        await expectLater(
          endpoints.photo.finishUpload(as, story.id!, ticket.photoId, 20),
          throwsAppError(AppErrorCode.photoCap, 'photo limit reached'),
        );
        expect(await Photo.db.findById(fx.s, ticket.photoId), isNull);
        expect(await fx.queued([ticket.key]), {ticket.key});
      },
    );

    // BR 79
    test(
      'Given photo uploaded for story A, when finished against story B of '
      'the same family, then refused and no row',
      () async {
        final member = await fx.user();
        final (family, a) = await familyStory(member);
        final b = await fx.story(family, authorId: member);
        final as = asUser(sessionBuilder, member);
        final ticket = await endpoints.photo.startUpload(
          as,
          a.id!,
          'image/jpeg',
          jpegBytes().lengthInBytes,
        );
        await fx.clientUpload(ticket.key, jpegBytes());

        await expectLater(
          endpoints.photo.finishUpload(as, b.id!, ticket.photoId, 0),
          throwsAppError(AppErrorCode.storageFailed, 'upload not found'),
        );
        expect(await Photo.db.findById(fx.s, ticket.photoId), isNull);
      },
    );

    // BR 46
    test(
      'Given child member, when uploading for the origin story, then the key '
      'is under the parent family (never a child-family path); on any other '
      'parent story, then refused',
      () async {
        final parentAuthor = await fx.user();
        final childMember = await fx.user();
        final (parent, origin) = await familyStory(parentAuthor);
        final other = await fx.story(parent, authorId: parentAuthor);
        final child = await fx.branch(parent, origin);
        await fx.join(child, childMember);

        final dto = await upload(childMember, origin);

        expect(dto.familyId, parent.id);
        expect(dto.originalKey, startsWith('families/${parent.id}/'));
        expect(dto.originalKey, isNot(contains('${child.id}')));
        await expectLater(
          endpoints.photo.startUpload(
            asUser(sessionBuilder, childMember),
            other.id!,
            'image/jpeg',
            100,
          ),
          throwsAppError(AppErrorCode.forbidden),
        );
      },
    );

    test(
      'when a photo is added to a published story then a photo event posts; '
      'on a draft nothing posts',
      () async {
        final member = await fx.user();
        final (family, published) = await familyStory(member);
        final draft = await fx.story(
          family,
          authorId: member,
          status: StoryStatus.draft,
        );

        final events = await fx.eventsDuring(
          family,
          () => upload(member, published),
        );
        expect(events, hasLength(1));
        expect(events.single.kind, LiveKind.photo);
        expect(events.single.storyId, published.id);
        expect(events.single.deleted, isFalse);

        expect(
          await fx.eventsDuring(family, () => upload(member, draft)),
          isEmpty,
        );
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
