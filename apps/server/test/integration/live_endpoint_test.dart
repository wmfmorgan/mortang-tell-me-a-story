import 'dart:async';

import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/live/live_events.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given LiveEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    setUp(() => fx = Fx(sessionBuilder.build()));

    LiveEventDto event(Family family, {Story? story}) => LiveEventDto(
      familyId: family.id!,
      storyId: story?.id,
      kind: story == null ? LiveKind.story : LiveKind.note,
      deleted: false,
    );

    /// Subscribes, lets the listener register, posts [sent], returns the
    /// first event received.
    Future<LiveEventDto> receive(
      Stream<LiveEventDto> stream,
      LiveEventDto sent,
    ) async {
      final first = stream.first;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await postLiveEvent(sessionBuilder.build(), sent);
      return first.timeout(const Duration(seconds: 5));
    }

    test('when a member watches the family then events arrive', () async {
      final member = await fx.user();
      final family = await fx.family(await fx.tree());
      await fx.join(family, member);
      final sent = event(family);

      final got = await receive(
        endpoints.live.watchFamily(asUser(sessionBuilder, member), family.id!),
        sent,
      );

      expect(got.familyId, family.id);
      expect(got.kind, sent.kind);
    });

    test('when a tree reader watches a family then events arrive', () async {
      final reader = await fx.user();
      final tree = await fx.tree();
      final parent = await fx.family(tree);
      final child = await fx.family(tree, parentId: parent.id);
      await fx.join(child, reader);

      final got = await receive(
        endpoints.live.watchFamily(asUser(sessionBuilder, reader), parent.id!),
        event(parent),
      );

      expect(got.familyId, parent.id);
    });

    test(
      'when a stranger watches a family then FORBIDDEN at subscribe',
      () async {
        final stranger = await fx.user();
        final family = await fx.family(await fx.tree());

        await expectLater(
          endpoints.live
              .watchFamily(asUser(sessionBuilder, stranger), family.id!)
              .first,
          throwsAppError(AppErrorCode.forbidden, 'member only'),
        );
      },
    );

    test(
      'when a member watches a soft-deleted family then FORBIDDEN',
      () async {
        final member = await fx.user();
        final family = await fx.family(
          await fx.tree(),
          deletedAt: DateTime.now().toUtc(),
        );
        await fx.join(family, member, MembershipRole.owner);

        await expectLater(
          endpoints.live
              .watchFamily(asUser(sessionBuilder, member), family.id!)
              .first,
          throwsAppError(AppErrorCode.forbidden, 'member only'),
        );
      },
    );

    test(
      'when a member watches a published story then its events arrive',
      () async {
        final member = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, member);
        final story = await fx.story(family);

        final got = await receive(
          endpoints.live.watchStory(asUser(sessionBuilder, member), story.id!),
          event(family, story: story),
        );

        expect(got.storyId, story.id);
      },
    );

    test(
      'when a member watches a published story in a soft-deleted family then '
      'FORBIDDEN at subscribe',
      () async {
        final member = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, member, MembershipRole.owner);
        final story = await fx.story(family);
        await Family.db.updateRow(
          fx.s,
          family.copyWith(deletedAt: DateTime.now().toUtc()),
        );

        await expectLater(
          endpoints.live
              .watchStory(asUser(sessionBuilder, member), story.id!)
              .first,
          throwsAppError(AppErrorCode.forbidden),
        );
      },
    );

    test(
      'when a stranger watches a story then FORBIDDEN at subscribe',
      () async {
        final stranger = await fx.user();
        final family = await fx.family(await fx.tree());
        final story = await fx.story(family);

        await expectLater(
          endpoints.live
              .watchStory(asUser(sessionBuilder, stranger), story.id!)
              .first,
          throwsAppError(AppErrorCode.forbidden),
        );
      },
    );

    test(
      'when a member watches another member\'s draft then FORBIDDEN',
      () async {
        final author = await fx.user();
        final member = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, author);
        await fx.join(family, member);
        final draft = await fx.story(
          family,
          authorId: author,
          status: StoryStatus.draft,
        );

        await expectLater(
          endpoints.live
              .watchStory(asUser(sessionBuilder, member), draft.id!)
              .first,
          throwsAppError(AppErrorCode.forbidden),
        );
      },
    );

    test('when an anonymous caller watches then unauthenticated', () async {
      final family = await fx.family(await fx.tree());

      await expectLater(
        endpoints.live.watchFamily(sessionBuilder, family.id!).first,
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
