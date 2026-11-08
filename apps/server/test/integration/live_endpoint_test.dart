import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/live/live_events.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/stories_fixtures.dart';
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
      final family = await Family.db.findById(fx.s, sent.familyId);
      final first = stream.first;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await postLiveEvent(
        sessionBuilder.build(),
        sent,
        treeId: family!.treeId,
      );
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

    group('watchTree', () {
      late Clan c;
      setUp(() async => c = await Clan.of(fx));

      TestSessionBuilder by(UuidValue user) => asUser(sessionBuilder, user);

      /// Every event [stream] delivers while [action] runs.
      Future<List<LiveEventDto>> collect(
        Stream<LiveEventDto> stream,
        Future<void> Function() action,
      ) async {
        final events = <LiveEventDto>[];
        final sub = stream.listen(events.add);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await action();
        await settle();
        await sub.cancel();
        return events;
      }

      Stream<LiveEventDto> tree(UuidValue user, Family family) =>
          endpoints.live.watchTree(by(user), family.id!);

      test(
        'when a story in a branch is published then a root member watching '
        'the tree hears it with the branch id',
        () async {
          final branch = await c.branch();
          final draft = await endpoints.story.createDraft(
            by(branch.member),
            branch.family.id!,
            await c.ready(),
            allowUndated: false,
          );

          final events = await collect(
            tree(c.member, c.family),
            () => endpoints.story.publish(by(branch.member), draft.id),
          );

          final got = events.single;
          expect(got.familyId, branch.family.id);
          expect(got.storyId, draft.id);
          expect(got.kind, LiveKind.story);
          expect(got.storyStatus, StoryStatus.published);
        },
      );

      test(
        'when a branch member comments on a published story then the tree '
        'hears a note event',
        () async {
          final branch = await c.branch();
          final story = await fx.story(branch.family, authorId: branch.member);

          final events = await collect(
            tree(c.member, c.family),
            () => endpoints.note.create(
              by(branch.member),
              story.id!,
              NoteKind.comment,
              'Lovely',
            ),
          );

          expect(events.single.kind, LiveKind.note);
          expect(events.single.familyId, branch.family.id);
        },
      );

      test('when a draft in a branch is edited then nothing arrives', () async {
        final branch = await c.branch();
        final draft = await fx.story(
          branch.family,
          authorId: branch.member,
          status: StoryStatus.draft,
        );

        final events = await collect(
          tree(c.member, c.family),
          () => endpoints.story.updateDraft(
            by(branch.member),
            draft.id!,
            write(title: 'Draft'),
          ),
        );

        expect(events, isEmpty);
      });

      test('when another tree changes then nothing of it arrives', () async {
        final other = await Clan.of(fx);
        final theirs = await other.published();
        final ours = await c.published();

        final events = await collect(tree(c.member, c.family), () async {
          await endpoints.note.create(
            by(other.member),
            theirs.id!,
            NoteKind.comment,
            'Theirs',
          );
          await endpoints.note.create(
            by(c.member),
            ours.id!,
            NoteKind.comment,
            'Ours',
          );
        });

        expect(events.map((e) => e.familyId), [c.family.id]);
      });

      test(
        'when a branch is created, soft-deleted and recovered then the tree '
        'hears a family event for each, and the family channel none',
        () async {
          final origin = await c.published();
          late UuidValue branchId;
          late List<LiveEventDto> onFamily;

          final events = await collect(tree(c.member, c.family), () async {
            branchId = await endpoints.family.createBranch(
              by(c.owner),
              parentFamilyId: c.family.id!,
              originStoryId: origin.id!,
              name: 'Branch',
              branchYear: 1980,
              ownerUserId: c.owner,
              personIds: const [],
            );
            onFamily = liveEvents(fx.s, familyChannel(branchId));
            await endpoints.family.softDelete(by(c.owner), branchId);
            await endpoints.family.softDelete(by(c.owner), branchId);
            await endpoints.family.recover(by(c.owner), branchId);
          });

          expect(
            [for (final e in events) (e.kind, e.familyId, e.deleted)],
            [
              (LiveKind.family, branchId, false),
              (LiveKind.family, branchId, true),
              (LiveKind.family, branchId, false),
            ],
          );
          expect(events.map((e) => e.storyId), everyElement(isNull));
          expect(onFamily, isEmpty);
        },
      );

      test(
        'when a stranger or a member of a soft-deleted family watches then '
        'FORBIDDEN at subscribe',
        () async {
          await expectLater(
            tree(c.stranger, c.family).first,
            throwsAppError(AppErrorCode.forbidden, 'member only'),
          );
          await fx.softDelete(c.family);
          await expectLater(
            tree(c.owner, c.family).first,
            throwsAppError(AppErrorCode.forbidden, 'member only'),
          );
        },
      );

      // D6b: watching needs the caller's own family to be live too.
      test(
        'when a member whose only family is soft-deleted watches a live family '
        'of the same tree then FORBIDDEN at subscribe',
        () async {
          final middle = await c.branch();
          await fx.softDelete(middle.family);

          await expectLater(
            tree(middle.member, c.family).first,
            throwsAppError(AppErrorCode.forbidden, 'member only'),
          );
        },
      );

      test('when an anonymous caller watches then unauthenticated', () async {
        await expectLater(
          endpoints.live.watchTree(sessionBuilder, c.family.id!).first,
          throwsA(isA<ServerpodUnauthenticatedException>()),
        );
      });
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
