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

  withServerpod('Given NoteEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    late Clan c;
    TestSessionBuilder by(UuidValue user) => asUser(sessionBuilder, user);

    setUp(() async {
      fx = Fx(sessionBuilder.build());
      c = await Clan.of(fx);
    });

    Future<NoteDto> comment(
      UuidValue user,
      Story story, {
      NoteKind kind = NoteKind.comment,
      String body = 'Hello',
    }) => endpoints.note.create(by(user), story.id!, kind, body);

    test('when an anonymous caller lists notes then it is refused', () async {
      final story = await c.published();
      await expectLater(
        endpoints.note.listForStory(sessionBuilder, story.id!),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    group('own notes and moderation', () {
      // BR 93
      test(
        'when member B creates, edits and deletes their own comment and '
        'perspective then each succeeds',
        () async {
          final story = await c.published();
          for (final kind in NoteKind.values) {
            final note = await comment(
              c.member,
              story,
              kind: kind,
              body: ' Hi ',
            );
            expect(note.body, 'Hi');
            expect(note.kind, kind);
            expect(note.authorId, c.member);
            expect(note.familyId, c.family.id);
            expect(note.canDelete, isTrue);
            await endpoints.note.update(by(c.member), note.id, 'Edited');
            final listed = await endpoints.note.listForStory(
              by(c.member),
              story.id!,
              kind: kind,
            );
            expect(listed.single.body, 'Edited');
            await endpoints.note.delete(by(c.member), note.id);
            expect(
              await endpoints.note.listForStory(by(c.member), story.id!),
              isEmpty,
            );
          }
        },
      );

      // BR 93
      test(
        'when member A edits or deletes B\'s note then FORBIDDEN, and A sees '
        'canDelete false',
        () async {
          final story = await c.published();
          final note = await comment(c.member, story);
          await expectLater(
            endpoints.note.update(by(c.author), note.id, 'x'),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.note.delete(by(c.author), note.id),
            throwsAppError(AppErrorCode.forbidden),
          );
          final listed = await endpoints.note.listForStory(
            by(c.author),
            story.id!,
          );
          expect(listed.single.body, 'Hello');
          expect(listed.single.canDelete, isFalse);
        },
      );

      // BR 93, D4
      test(
        'when owner or co_owner deletes B\'s note on a published story then '
        'it is deleted; editing it is FORBIDDEN',
        () async {
          final story = await c.published();
          for (final steward in [c.owner, c.coOwner]) {
            final note = await comment(c.member, story);
            final listed = await endpoints.note.listForStory(
              by(steward),
              story.id!,
            );
            expect(listed.single.canDelete, isTrue);
            await expectLater(
              endpoints.note.update(by(steward), note.id, 'x'),
              throwsAppError(AppErrorCode.forbidden),
            );
            await endpoints.note.delete(by(steward), note.id);
            expect(await StoryNote.db.findById(fx.s, note.id), isNull);
          }
        },
      );

      // BR 93, D4
      test(
        'when a child-family owner deletes a note on the parent origin story '
        'then FORBIDDEN',
        () async {
          final origin = await c.published();
          final branch = await c.branch(origin: origin);
          final note = await comment(c.member, origin);
          final listed = await endpoints.note.listForStory(
            by(branch.owner),
            origin.id!,
          );
          expect(listed.single.canDelete, isFalse);
          await expectLater(
            endpoints.note.delete(by(branch.owner), note.id),
            throwsAppError(AppErrorCode.forbidden),
          );
          expect(await StoryNote.db.findById(fx.s, note.id), isNotNull);
        },
      );

      // BR 93
      test('when a stranger comments then FORBIDDEN', () async {
        final story = await c.published();
        await expectLater(
          comment(c.stranger, story),
          throwsAppError(AppErrorCode.forbidden),
        );
      });

      // BR 94
      test(
        'when a note is edited then only its body changes',
        () async {
          final story = await c.published();
          final note = await fx.note(
            story,
            c.member,
            kind: NoteKind.perspective,
          );
          await endpoints.note.update(by(c.member), note.id!, 'New body');
          final row = (await StoryNote.db.findById(fx.s, note.id!))!;
          expect(row.body, 'New body');
          expect(row.storyId, note.storyId);
          expect(row.authorId, note.authorId);
          expect(row.kind, note.kind);
          expect(row.createdAt, note.createdAt);
        },
      );

      test(
        'when the body is blank then VALIDATION "body is required"',
        () async {
          final story = await c.published();
          await expectLater(
            comment(c.member, story, body: '  '),
            throwsAppError(AppErrorCode.validation, 'body is required'),
          );
          final note = await comment(c.member, story);
          await expectLater(
            endpoints.note.update(by(c.member), note.id, ''),
            throwsAppError(AppErrorCode.validation, 'body is required'),
          );
        },
      );

      test(
        'when listing by kind then only that kind comes back, oldest first',
        () async {
          final story = await c.published();
          final first = await comment(c.member, story, body: 'one');
          await comment(c.member, story, kind: NoteKind.perspective);
          final second = await comment(c.author, story, body: 'two');
          final comments = await endpoints.note.listForStory(
            by(c.member),
            story.id!,
            kind: NoteKind.comment,
          );
          expect(comments.map((n) => n.id), [first.id, second.id]);
          expect(
            await endpoints.note.listForStory(by(c.member), story.id!),
            hasLength(3),
          );
        },
      );
    });

    group('origin contributors', () {
      // BR 43
      test(
        'when a child member comments or adds a perspective on the origin '
        'story then allowed; on another parent story FORBIDDEN',
        () async {
          final origin = await c.published();
          final other = await c.published();
          final branch = await c.branch(origin: origin);
          for (final kind in NoteKind.values) {
            final note = await comment(branch.member, origin, kind: kind);
            expect(note.canDelete, isTrue);
            await expectLater(
              comment(branch.member, other, kind: kind),
              throwsAppError(AppErrorCode.forbidden),
            );
          }
        },
      );

      // BR 44
      test(
        'when a member of another branch or a stranger contributes to the '
        'origin story then FORBIDDEN',
        () async {
          final origin = await c.published();
          await c.branch(origin: origin);
          final sibling = await c.branch();
          for (final user in [sibling.member, sibling.owner, c.stranger]) {
            await expectLater(
              comment(user, origin),
              throwsAppError(AppErrorCode.forbidden),
            );
          }
        },
      );

      // BR 45
      test(
        'when the origin moves or is unpublished then the child member can no '
        'longer comment or edit their note',
        () async {
          final origin = await c.published();
          final elsewhere = await c.published();
          final branch = await c.branch(origin: origin);
          final note = await comment(branch.member, origin);

          await fx.origin(branch.family, elsewhere);
          await expectLater(
            comment(branch.member, origin),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.note.update(by(branch.member), note.id, 'x'),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.note.delete(by(branch.member), note.id),
            throwsAppError(AppErrorCode.forbidden),
          );

          await fx.origin(branch.family, origin);
          await fx.setStatus(origin, StoryStatus.draft);
          await expectLater(
            comment(branch.member, origin),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.note.update(by(branch.member), note.id, 'x'),
            throwsAppError(AppErrorCode.forbidden),
          );
          expect((await StoryNote.db.findById(fx.s, note.id))!.body, 'Hello');
        },
      );
    });

    group('tree reading', () {
      // BR 26 (comment/perspective part)
      test(
        'when a parent member reads a child published story then they see its '
        'comments and perspectives',
        () async {
          final branch = await c.branch();
          final story = await fx.story(branch.family, authorId: branch.member);
          await fx.note(story, branch.member);
          await fx.note(story, branch.owner, kind: NoteKind.perspective);
          final listed = await endpoints.note.listForStory(
            by(c.member),
            story.id!,
          );
          expect(listed.map((n) => n.kind).toSet(), {
            NoteKind.comment,
            NoteKind.perspective,
          });
          expect(listed.every((n) => !n.canDelete), isTrue);
        },
      );

      // BR 27 (comment/perspective part)
      test(
        'when a parent member comments on a child story then FORBIDDEN',
        () async {
          final branch = await c.branch();
          final story = await fx.story(branch.family, authorId: branch.member);
          for (final kind in NoteKind.values) {
            await expectLater(
              comment(c.member, story, kind: kind),
              throwsAppError(AppErrorCode.forbidden),
            );
          }
        },
      );

      // BR 28 (comment/perspective part), BR 74 (notes)
      test(
        'when a stranger or a member of an unrelated family lists notes then '
        'NOT_FOUND',
        () async {
          final branch = await c.branch();
          final story = await fx.story(branch.family, authorId: branch.member);
          await fx.note(story, branch.member);
          final b = await Clan.of(fx);
          final theirs = await b.published();
          await fx.note(theirs, b.member);
          await expectLater(
            endpoints.note.listForStory(by(c.stranger), story.id!),
            throwsAppError(AppErrorCode.notFound, 'story'),
          );
          await expectLater(
            endpoints.note.listForStory(by(c.member), theirs.id!),
            throwsAppError(AppErrorCode.notFound, 'story'),
          );
        },
      );
    });

    group('drafts', () {
      // BR 68 (comment/perspective part)
      test(
        'when a draft has notes then only its author reads them',
        () async {
          final draft = await c.draft();
          await fx.note(draft, c.author);
          await fx.note(draft, c.author, kind: NoteKind.perspective);
          final branch = await c.branch();
          expect(
            await endpoints.note.listForStory(by(c.author), draft.id!),
            hasLength(2),
          );
          for (final user in [c.member, c.owner, c.coOwner, branch.member]) {
            await expectLater(
              endpoints.note.listForStory(by(user), draft.id!),
              throwsAppError(AppErrorCode.notFound, 'story'),
            );
          }
        },
      );

      // BR 69 (comment/perspective part)
      test(
        'when a non-author member or the owner comments on someone\'s draft '
        'then FORBIDDEN',
        () async {
          final draft = await c.draft();
          for (final user in [c.member, c.owner]) {
            for (final kind in NoteKind.values) {
              await expectLater(
                comment(user, draft, kind: kind),
                throwsAppError(AppErrorCode.forbidden),
              );
            }
          }
        },
      );

      // BR 83 (comment/perspective part)
      test(
        'when story D reverts to draft then B cannot delete their notes on it; '
        'author A deletes their own; on published P, B deletes their own',
        () async {
          final d = await c.published();
          final p = await c.published();
          final bComment = await comment(c.member, d);
          final bPerspective = await comment(
            c.member,
            d,
            kind: NoteKind.perspective,
          );
          final aComment = await comment(c.author, d);
          final onP = await comment(c.member, p);
          await fx.setStatus(d, StoryStatus.draft);
          for (final note in [bComment, bPerspective]) {
            await expectLater(
              endpoints.note.delete(by(c.member), note.id),
              throwsAppError(AppErrorCode.forbidden),
            );
            expect(await StoryNote.db.findById(fx.s, note.id), isNotNull);
          }
          await endpoints.note.delete(by(c.author), aComment.id);
          expect(await StoryNote.db.findById(fx.s, aComment.id), isNull);
          await endpoints.note.delete(by(c.member), onP.id);
          expect(await StoryNote.db.findById(fx.s, onP.id), isNull);
        },
      );

      // D4: moderation needs a published story
      test('when the owner deletes a note on a draft then FORBIDDEN', () async {
        final draft = await c.draft();
        final note = await fx.note(draft, c.author);
        await expectLater(
          endpoints.note.delete(by(c.owner), note.id!),
          throwsAppError(AppErrorCode.forbidden),
        );
      });
    });

    group('live events', () {
      test(
        'when notes on a published story are created, edited and deleted then '
        'note events are posted on the family and story channels',
        () async {
          final story = await c.published();
          final family = liveEvents(fx.s, familyChannel(c.family.id!));
          final onStory = liveEvents(fx.s, storyChannel(story.id!));
          final note = await comment(c.member, story);
          await endpoints.note.update(by(c.member), note.id, 'x');
          await endpoints.note.delete(by(c.member), note.id);
          await settle();
          expect(family.map((e) => (e.kind, e.storyId, e.deleted)), [
            (LiveKind.note, story.id, false),
            (LiveKind.note, story.id, false),
            (LiveKind.note, story.id, true),
          ]);
          expect(family.first.storyStatus, StoryStatus.published);
          expect(onStory, hasLength(3));
        },
      );

      test(
        'when the author comments on their draft then nothing is posted',
        () async {
          final draft = await c.draft();
          final family = liveEvents(fx.s, familyChannel(c.family.id!));
          final note = await comment(c.author, draft);
          await endpoints.note.update(by(c.author), note.id, 'x');
          await endpoints.note.delete(by(c.author), note.id);
          await settle();
          expect(family, isEmpty);
        },
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
