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
  }, rollbackDatabase: RollbackDatabase.disabled);
}
