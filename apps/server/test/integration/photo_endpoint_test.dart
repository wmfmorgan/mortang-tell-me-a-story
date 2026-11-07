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

    // BR 47
    test(
      "Given child member, when deleting a parent member's photo, then "
      'refused and nothing changes; can delete own uploaded photo and blob',
      () async {
        final parentMember = await fx.user();
        final childMember = await fx.user();
        final (parent, origin) = await familyStory(parentMember);
        final child = await fx.branch(parent, origin);
        await fx.join(child, childMember);
        final theirs = await fx.photo(origin, uploaderId: parentMember);
        final mine = await fx.photo(origin, uploaderId: childMember);
        final as = asUser(sessionBuilder, childMember);

        await expectLater(
          endpoints.photo.delete(as, theirs.id!),
          throwsAppError(AppErrorCode.forbidden),
        );
        expect(await Photo.db.findById(fx.s, theirs.id!), isNotNull);
        expect(await fx.queued([theirs.originalKey]), isEmpty);

        await endpoints.photo.delete(as, mine.id!);
        expect(await Photo.db.findById(fx.s, mine.id!), isNull);
        expect(await fx.queued([mine.originalKey]), {mine.originalKey});
      },
    );

    // BR 82
    test(
      "Given parent owner, then can delete a child contributor's photo row "
      'and blobs on the published origin story; child-timeline owner '
      'deletes no parent photos',
      () async {
        final parentAuthor = await fx.user();
        final parentOwner = await fx.user();
        final childOwner = await fx.user();
        // A plain member authors the origin, so the owner's rights come from
        // the steward branch of canEditStory, not from authorship.
        final (parent, origin) = await familyStory(parentAuthor);
        await fx.join(parent, parentOwner, MembershipRole.owner);
        final child = await fx.branch(parent, origin);
        await fx.join(child, childOwner, MembershipRole.owner);
        final contributed = await fx.photo(
          origin,
          uploaderId: childOwner,
          edited: true,
        );
        final parentPhoto = await fx.photo(origin, uploaderId: parentOwner);

        await expectLater(
          endpoints.photo.delete(
            asUser(sessionBuilder, childOwner),
            parentPhoto.id!,
          ),
          throwsAppError(AppErrorCode.forbidden),
        );
        expect(await Photo.db.findById(fx.s, parentPhoto.id!), isNotNull);

        await endpoints.photo.delete(
          asUser(sessionBuilder, parentOwner),
          contributed.id!,
        );
        expect(await Photo.db.findById(fx.s, contributed.id!), isNull);
        expect(
          await fx.queued([contributed.originalKey, contributed.editedKey]),
          {contributed.originalKey, contributed.editedKey},
        );
      },
    );

    // BR 83
    test(
      "Given story D reverted to draft with member B's photo on it, when B "
      "deletes it, then nothing changes; author A can delete A's own photo "
      'on D; on published P, B deletes own photo and blob',
      () async {
        final a = await fx.user();
        final b = await fx.user();
        final (family, published) = await familyStory(a, members: [b]);
        final draft = await fx.story(
          family,
          authorId: a,
          status: StoryStatus.draft,
        );
        final bsOnDraft = await fx.photo(draft, uploaderId: b);
        final asOnDraft = await fx.photo(draft, uploaderId: a);
        final bsOnPublished = await fx.photo(published, uploaderId: b);

        await expectLater(
          endpoints.photo.delete(asUser(sessionBuilder, b), bsOnDraft.id!),
          throwsAppError(AppErrorCode.forbidden),
        );
        expect(await Photo.db.findById(fx.s, bsOnDraft.id!), isNotNull);

        await endpoints.photo.delete(asUser(sessionBuilder, a), asOnDraft.id!);
        expect(await Photo.db.findById(fx.s, asOnDraft.id!), isNull);

        await endpoints.photo.delete(
          asUser(sessionBuilder, b),
          bsOnPublished.id!,
        );
        expect(await Photo.db.findById(fx.s, bsOnPublished.id!), isNull);
        expect(await fx.queued([bsOnPublished.originalKey]), {
          bsOnPublished.originalKey,
        });
      },
    );

    test('when deleting a missing photo then FORBIDDEN', () async {
      await expectLater(
        endpoints.photo.delete(
          asUser(sessionBuilder, await fx.user()),
          const Uuid().v7obj(),
        ),
        throwsAppError(AppErrorCode.forbidden),
      );
    });

    test(
      'when a photo of a published story is deleted then a deleted photo '
      'event posts',
      () async {
        final member = await fx.user();
        final (family, story) = await familyStory(member);
        final photo = await fx.photo(story, uploaderId: member);

        final events = await fx.eventsDuring(
          family,
          () => endpoints.photo.delete(
            asUser(sessionBuilder, member),
            photo.id!,
          ),
        );
        expect(events, hasLength(1));
        expect(events.single.kind, LiveKind.photo);
        expect(events.single.deleted, isTrue);
      },
    );

    // BR 81
    test(
      'Given photos, when the uploader makes one the hero, then sortOrder '
      'becomes 0..n-1 with it first and no other field changes',
      () async {
        final member = await fx.user();
        final (family, story) = await familyStory(member);
        final p1 = await fx.photo(story, uploaderId: member, sortOrder: 0);
        final p2 = await fx.photo(story, uploaderId: member, sortOrder: 5);
        final p3 = await fx.photo(
          story,
          uploaderId: member,
          sortOrder: 9,
          edited: true,
        );

        final events = await fx.eventsDuring(
          family,
          () => endpoints.photo.setHero(
            asUser(sessionBuilder, member),
            story.id!,
            p3.id!,
          ),
        );

        final rows = await Photo.db.find(
          fx.s,
          where: (t) => t.storyId.equals(story.id!),
          orderBy: (t) => t.sortOrder,
        );
        expect(rows.map((p) => p.id), [p3.id, p1.id, p2.id]);
        expect(rows.map((p) => p.sortOrder), [0, 1, 2]);
        expect(rows.first.originalKey, p3.originalKey);
        expect(rows.first.editedKey, p3.editedKey);
        expect(rows.first.editVersion, 1);
        expect(rows.first.uploaderId, member);
        expect(events.single.kind, LiveKind.photo);
      },
    );

    // BR 81
    test(
      "Given published story, when an owner makes another member's photo "
      'the hero, then allowed; a plain member who did not upload it, or a '
      'photo of another story, then FORBIDDEN',
      () async {
        final author = await fx.user();
        final owner = await fx.user();
        final uploader = await fx.user();
        final bystander = await fx.user();
        // A plain member authors the story, so the owner's rights come from
        // the steward branch of canEditStory, not from authorship.
        final (family, story) = await familyStory(
          author,
          members: [uploader, bystander],
        );
        await fx.join(family, owner, MembershipRole.owner);
        final first = await fx.photo(story, uploaderId: owner);
        final theirs = await fx.photo(
          story,
          uploaderId: uploader,
          sortOrder: 1,
        );
        final elsewhere = await fx.photo(
          await fx.story(family, authorId: author),
          uploaderId: owner,
        );

        await expectLater(
          endpoints.photo.setHero(
            asUser(sessionBuilder, bystander),
            story.id!,
            theirs.id!,
          ),
          throwsAppError(AppErrorCode.forbidden),
        );
        await expectLater(
          endpoints.photo.setHero(
            asUser(sessionBuilder, owner),
            story.id!,
            elsewhere.id!,
          ),
          throwsAppError(AppErrorCode.forbidden),
        );

        await endpoints.photo.setHero(
          asUser(sessionBuilder, owner),
          story.id!,
          theirs.id!,
        );
        final photos = await endpoints.photo.list(
          asUser(sessionBuilder, owner),
          story.id!,
        );
        expect(photos.map((p) => p.id), [theirs.id, first.id]);
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
