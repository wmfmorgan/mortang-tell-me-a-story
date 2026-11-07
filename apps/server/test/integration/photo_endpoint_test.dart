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
  }, rollbackDatabase: RollbackDatabase.disabled);
}
