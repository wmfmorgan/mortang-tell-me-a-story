import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/stories/story_dtos.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/stories_fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given stories with tags, photos, a place and notes', (
    sessionBuilder,
    endpoints,
  ) {
    test(
      'when assembled then every field is filled, photo keys are effective '
      'and notes are counted per kind',
      () async {
        final session = sessionBuilder.build();
        final fx = Fx(session);
        final author = await fx.user();
        await fx.profile(
          author,
          displayName: 'Ann',
          avatarKey: 'users/$author/avatar/a.jpg',
        );
        final tree = await fx.tree();
        final family = await fx.family(tree);
        final place = await fx.place(tree);
        final zoe = await fx.person(family, name: 'Zoe');
        final abe = await fx.person(family, name: 'Abe', userId: author);
        final story = await fx.story(
          family,
          authorId: author,
          placeId: place.id,
        );
        final bare = await fx.story(family, status: StoryStatus.draft);
        await fx.tag(story, zoe);
        await fx.tag(story, abe);
        final second = await fx.photo(story, sortOrder: 1);
        await fx.photo(story, editedKey: 'edited-1.jpg');
        await fx.note(story, author);
        await fx.note(story, author);
        await fx.note(story, author, kind: NoteKind.perspective);

        final dtos = await storyDtos(session, [story, bare]);

        expect(dtos.map((d) => d.id), [story.id, bare.id]);
        final dto = dtos.first;
        expect(dto.familyId, family.id);
        expect(dto.authorId, author);
        expect(dto.title, 'A story');
        expect(dto.dateStart, DateTime.utc(1950));
        expect(dto.dateEnd, DateTime.utc(1950, 12, 31));
        expect(dto.datePrecision, DatePrecision.year);
        expect(dto.status, StoryStatus.published);
        expect(dto.publishedAt, isNotNull);
        expect(dto.people.map((p) => p.name), ['Abe', 'Zoe']);
        expect(dto.people.first.userId, author);
        expect(dto.people.last.userId, isNull);
        expect(dto.photos.map((p) => p.key), [
          'edited-1.jpg',
          second.originalKey,
        ]);
        expect(dto.photos.map((p) => p.sortOrder), [0, 1]);
        expect(dto.placeId, place.id);
        expect(dto.placeLabel, 'Home');
        expect(dto.placeAddress, '1 Main St');
        expect(dto.authorName, 'Ann');
        expect(dto.authorAvatarKey, 'users/$author/avatar/a.jpg');
        expect(dto.commentCount, 2);
        expect(dto.perspectiveCount, 1);

        final empty = dtos.last;
        expect(empty.people, isEmpty);
        expect(empty.photos, isEmpty);
        expect(empty.placeLabel, isNull);
        expect(empty.authorName, isNull);
        expect(empty.commentCount, 0);
        expect(empty.perspectiveCount, 0);
        expect(await storyDtos(session, []), isEmpty);
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
