import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/live/live_events.dart';
import 'package:tell_me_a_story_server/src/stories/story_dates.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/stories_fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given StoryEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    late Clan c;
    TestSessionBuilder by(UuidValue user) => asUser(sessionBuilder, user);
    UuidValue newId() => UuidValue.fromString(const Uuid().v7());

    setUp(() async {
      fx = Fx(sessionBuilder.build());
      c = await Clan.of(fx);
    });

    test('when an anonymous caller reads a story then it is refused', () async {
      final story = await c.published();
      await expectLater(
        endpoints.story.get(sessionBuilder, story.id!),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    group('creating drafts', () {
      // BR 62
      test(
        'when a member saves a draft with null dates then start, end and '
        'precision are stored null',
        () async {
          final dto = await endpoints.story.createDraft(
            by(c.member),
            c.family.id!,
            write(title: ' Undated '),
            allowUndated: true,
          );
          expect((dto.dateStart, dto.dateEnd, dto.datePrecision), (
            null,
            null,
            null,
          ));
          expect(dto.status, StoryStatus.draft);
          expect(dto.authorId, c.member);
          expect(dto.title, 'Undated');
          final row = await Story.db.findById(fx.s, dto.id);
          expect(row!.dateStart, isNull);
          expect(row.treeId, c.tree.id);
        },
      );

      test(
        'when a draft has no start and allowUndated is false then VALIDATION '
        '"date required"',
        () async {
          await expectLater(
            endpoints.story.createDraft(
              by(c.member),
              c.family.id!,
              write(title: 'x'), allowUndated: false,
            ),
            throwsAppError(AppErrorCode.validation, 'date required'),
          );
        },
      );

      // BR 64
      test(
        'when a draft has a start with null end then end = start and precision day',
        () async {
          final dto = await endpoints.story.createDraft(
            by(c.member),
            c.family.id!,
            write(dateStart: DateTime.utc(1950, 6, 3)), allowUndated: false,
          );
          expect(dto.dateEnd, DateTime.utc(1950, 6, 3));
          expect(dto.datePrecision, DatePrecision.day);
        },
      );

      // BR 65
      test(
        'when a month draft does not start on the 1st then VALIDATION',
        () async {
          await expectLater(
            endpoints.story.createDraft(
              by(c.member),
              c.family.id!,
              write(
                dateStart: DateTime.utc(1950, 6, 3),
                datePrecision: DatePrecision.month,
              ), allowUndated: false,
            ),
            throwsAppError(AppErrorCode.validation, invalidDateMessage),
          );
        },
      );

      // BR 66
      test(
        'when a draft spans a decade then VALIDATION (decade precision is '
        'dropped, D9)',
        () async {
          await expectLater(
            endpoints.story.createDraft(
              by(c.member),
              c.family.id!,
              write(
                dateStart: DateTime.utc(1950),
                dateEnd: DateTime.utc(1959, 12, 31),
                datePrecision: DatePrecision.year,
              ), allowUndated: false,
            ),
            throwsAppError(AppErrorCode.validation, invalidDateMessage),
          );
        },
      );

      test(
        'when a stranger, or a member of a soft-deleted family, creates a '
        'draft then FORBIDDEN "member only"',
        () async {
          final input = write(dateStart: DateTime.utc(1950));
          await expectLater(
            endpoints.story.createDraft(by(c.stranger), c.family.id!, input, allowUndated: false,),
            throwsAppError(AppErrorCode.forbidden, 'member only'),
          );
          await fx.softDelete(c.family);
          await expectLater(
            endpoints.story.createDraft(by(c.member), c.family.id!, input, allowUndated: false,),
            throwsAppError(AppErrorCode.forbidden, 'member only'),
          );
          expect(
            await Story.db.count(
              fx.s,
              where: (t) => t.familyId.equals(c.family.id!),
            ),
            0,
          );
        },
      );

      test(
        'when the same id is created twice then there is one draft with the '
        'second input',
        () async {
          final id = newId();
          await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            write(title: 'First', dateStart: DateTime.utc(1950)),
            id: id, allowUndated: false,
          );
          final again = await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            write(title: 'Second', dateStart: DateTime.utc(1950)),
            id: id, allowUndated: false,
          );
          expect(again.id, id);
          expect(again.title, 'Second');
          expect(await Story.db.count(fx.s, where: (t) => t.id.equals(id)), 1);
        },
      );

      test('when two creates with the same id race then one draft exists', () async {
        final id = newId();
        final input = write(title: 'Twice', dateStart: DateTime.utc(1950));
        final results = await Future.wait([
          endpoints.story.createDraft(by(c.author), c.family.id!, input, id: id, allowUndated: false,),
          endpoints.story.createDraft(by(c.author), c.family.id!, input, id: id, allowUndated: false,),
        ]);
        expect(results.map((d) => d.id).toSet(), {id});
        expect(await Story.db.count(fx.s, where: (t) => t.id.equals(id)), 1);
      });

      test(
        'when another member retries a create with an existing id then '
        'FORBIDDEN and the story is unchanged',
        () async {
          final id = newId();
          final input = write(title: 'Mine', dateStart: DateTime.utc(1950));
          await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            input,
            id: id, allowUndated: false,
          );
          await expectLater(
            endpoints.story.createDraft(
              by(c.member),
              c.family.id!,
              write(title: 'Theirs', dateStart: DateTime.utc(1950)),
              id: id, allowUndated: false,
            ),
            throwsAppError(AppErrorCode.forbidden),
          );
          expect((await Story.db.findById(fx.s, id))!.title, 'Mine');
        },
      );

      test(
        'when a draft names people and a place then the story carries them once',
        () async {
          final person = await fx.person(c.family, name: 'Ada');
          final place = await fx.place(c.tree);
          final dto = await endpoints.story.createDraft(
            by(c.member),
            c.family.id!,
            write(
              dateStart: DateTime.utc(1950),
              placeId: place.id,
              personIds: [person.id!, person.id!],
            ), allowUndated: false,
          );
          expect(dto.people.map((p) => p.personId), [person.id]);
          expect(dto.placeLabel, 'Home');
        },
      );
    });

    group('editing', () {
      test(
        'when updating, null fields stay, a blank title clears and clearPlace '
        'clears the place',
        () async {
          final place = await fx.place(c.tree);
          final draft = await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            write(
              dateStart: DateTime.utc(1950),
              title: 'T',
              body: 'B',
              placeId: place.id,
            ), allowUndated: false,
          );
          final dto = await endpoints.story.updateDraft(
            by(c.author),
            draft.id,
            write(title: '  ', clearPlace: true),
          );
          expect(dto.title, isNull);
          expect(dto.body, 'B');
          expect(dto.placeId, isNull);
          expect(dto.dateStart, DateTime.utc(1950));
        },
      );

      // BR 71
      test(
        'when the author edits their draft and their published story then '
        'both change',
        () async {
          final draft = await c.draft();
          final published = await c.published();
          for (final story in [draft, published]) {
            final dto = await endpoints.story.updateDraft(
              by(c.author),
              story.id!,
              write(title: 'Edited', dateStart: DateTime.utc(1960)),
            );
            expect(dto.title, 'Edited');
            expect(dto.dateStart, DateTime.utc(1960));
          }
        },
      );

      // BR 71
      test(
        'when owner or co_owner edits a published story then it changes; '
        'a draft they did not write is FORBIDDEN',
        () async {
          final published = await c.published();
          final draft = await c.draft();
          for (final steward in [c.owner, c.coOwner]) {
            final dto = await endpoints.story.updateDraft(
              by(steward),
              published.id!,
              write(body: 'by $steward'),
            );
            expect(dto.body, 'by $steward');
            await expectLater(
              endpoints.story.updateDraft(
                by(steward),
                draft.id!,
                write(body: 'x'),
              ),
              throwsAppError(AppErrorCode.forbidden),
            );
          }
        },
      );

      // BR 71, BR 73
      test(
        'when a plain member, a stranger, or anyone on a missing story edits '
        'then FORBIDDEN',
        () async {
          final published = await c.published();
          for (final user in [c.member, c.stranger]) {
            await expectLater(
              endpoints.story.updateDraft(
                by(user),
                published.id!,
                write(title: 'x'),
              ),
              throwsAppError(AppErrorCode.forbidden),
            );
          }
          await expectLater(
            endpoints.story.updateDraft(by(c.author), newId(), write()),
            throwsAppError(AppErrorCode.forbidden),
          );
          expect((await Story.db.findById(fx.s, published.id!))!.title, 'A story');
        },
      );

      // BR 71
      test(
        'when a child-family owner edits the parent origin story then FORBIDDEN',
        () async {
          final origin = await c.published();
          final branch = await c.branch(origin: origin);
          await expectLater(
            endpoints.story.updateDraft(
              by(branch.owner),
              origin.id!,
              write(title: 'x'),
            ),
            throwsAppError(AppErrorCode.forbidden),
          );
        },
      );

      // BR 71
      test(
        'when the family is soft-deleted then nobody can edit, not even the author',
        () async {
          final published = await c.published();
          await fx.softDelete(c.family);
          for (final user in [c.author, c.owner]) {
            await expectLater(
              endpoints.story.updateDraft(
                by(user),
                published.id!,
                write(title: 'x'),
              ),
              throwsAppError(AppErrorCode.forbidden),
            );
          }
        },
      );

      // BR 72, BR 73
      test(
        'when an owner edits a published story then author, family, status, '
        'publishedAt and createdAt are unchanged',
        () async {
          final published = await c.published();
          await endpoints.story.updateDraft(
            by(c.owner),
            published.id!,
            write(title: 'Owner edit'),
          );
          final row = (await Story.db.findById(fx.s, published.id!))!;
          expect(row.title, 'Owner edit');
          expect(row.authorId, c.author);
          expect(row.familyId, c.family.id);
          expect(row.status, StoryStatus.published);
          expect(row.publishedAt, published.publishedAt);
          expect(row.createdAt, published.createdAt);
        },
      );

      test(
        'when autosaving then a draft changes and true is returned; a '
        'published story returns false and is unchanged',
        () async {
          final draft = await c.draft();
          expect(
            await endpoints.story.autosaveDraft(
              by(c.author),
              draft.id!,
              write(title: 'Saved'),
            ),
            isTrue,
          );
          expect((await Story.db.findById(fx.s, draft.id!))!.title, 'Saved');
          final published = await c.published();
          expect(
            await endpoints.story.autosaveDraft(
              by(c.author),
              published.id!,
              write(title: 'Nope'),
            ),
            isFalse,
          );
          expect(
            (await Story.db.findById(fx.s, published.id!))!.title,
            'A story',
          );
        },
      );

      test('when a non-author member autosaves then FORBIDDEN', () async {
        final draft = await c.draft();
        await expectLater(
          endpoints.story.autosaveDraft(by(c.member), draft.id!, write()),
          throwsAppError(AppErrorCode.forbidden),
        );
      });
    });

    group('tags', () {
      // BR 75
      test(
        'when an editor replaces tags then the story has exactly the new '
        'people; an empty list removes them all; null leaves them',
        () async {
          final a = await fx.person(c.family, name: 'A');
          final b = await fx.person(c.family, name: 'B');
          final story = await c.published();
          await fx.tag(story, a);
          var dto = await endpoints.story.updateDraft(
            by(c.owner),
            story.id!,
            write(personIds: [b.id!]),
          );
          expect(dto.people.map((p) => p.personId), [b.id]);
          dto = await endpoints.story.updateDraft(
            by(c.owner),
            story.id!,
            write(title: 'Kept tags'),
          );
          expect(dto.people.map((p) => p.personId), [b.id]);
          dto = await endpoints.story.updateDraft(
            by(c.owner),
            story.id!,
            write(personIds: []),
          );
          expect(dto.people, isEmpty);
        },
      );

      // BR 75
      test(
        'when tagging a person homed in a child timeline of the same tree '
        'then it succeeds',
        () async {
          final branch = await c.branch();
          final childPerson = await fx.person(branch.family, name: 'Kid');
          final story = await c.draft();
          await endpoints.story.linkPerson(
            by(c.author),
            story.id!,
            childPerson.id!,
          );
          final dto = await endpoints.story.get(by(c.author), story.id!);
          expect(dto.people.map((p) => p.personId), [childPerson.id]);
        },
      );

      test('when linking the same person twice then there is one tag', () async {
        final person = await fx.person(c.family);
        final story = await c.draft();
        await endpoints.story.linkPerson(by(c.author), story.id!, person.id!);
        await endpoints.story.linkPerson(by(c.author), story.id!, person.id!);
        expect(
          await StoryPerson.db.count(
            fx.s,
            where: (t) => t.storyId.equals(story.id!),
          ),
          1,
        );
      });

      // BR 76
      test(
        'when a member of two unrelated trees tags a person or uses a place '
        'from the other tree then FORBIDDEN',
        () async {
          final other = await Clan.of(fx);
          await fx.join(other.family, c.author);
          final foreigner = await fx.person(other.family);
          final foreignPlace = await fx.place(other.tree);
          final story = await c.draft();
          await expectLater(
            endpoints.story.linkPerson(by(c.author), story.id!, foreigner.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.story.updateDraft(
              by(c.author),
              story.id!,
              write(personIds: [foreigner.id!]),
            ),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.story.updateDraft(
              by(c.author),
              story.id!,
              write(placeId: foreignPlace.id),
            ),
            throwsAppError(AppErrorCode.forbidden),
          );
          expect(
            await StoryPerson.db.count(
              fx.s,
              where: (t) => t.storyId.equals(story.id!),
            ),
            0,
          );
        },
      );

      // BR 77
      test(
        'when tagging a person with a matching email or the owner then no '
        'membership is created or changed',
        () async {
          final email = 'tag-${newId()}@example.com';
          final invitee = await fx.userWithEmail(email);
          final emailed = await fx.person(c.family, name: 'Emailed');
          await Person.db.updateRow(fx.s, emailed.copyWith(email: email));
          final ownerPerson = await fx.person(c.family, userId: c.owner);
          final story = await c.draft();
          await endpoints.story.updateDraft(
            by(c.author),
            story.id!,
            write(personIds: [emailed.id!, ownerPerson.id!]),
          );
          expect(
            await Membership.db.count(
              fx.s,
              where: (t) => t.userId.equals(invitee),
            ),
            0,
          );
          final ownerRows = await Membership.db.find(
            fx.s,
            where: (t) => t.userId.equals(c.owner),
          );
          expect(ownerRows.map((m) => m.role), [MembershipRole.owner]);
        },
      );

      test(
        'when a plain member links a person to another member\'s story then '
        'FORBIDDEN',
        () async {
          final person = await fx.person(c.family);
          final story = await c.published();
          await expectLater(
            endpoints.story.linkPerson(by(c.member), story.id!, person.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
        },
      );
    });

    group('live events on edits', () {
      test(
        'when a draft is created, updated, autosaved or tagged then nothing '
        'is posted',
        () async {
          final family = liveEvents(fx.s, familyChannel(c.family.id!));
          final draft = await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            write(dateStart: DateTime.utc(1950)), allowUndated: false,
          );
          await endpoints.story.updateDraft(
            by(c.author),
            draft.id,
            write(title: 'x'),
          );
          await endpoints.story.autosaveDraft(
            by(c.author),
            draft.id,
            write(title: 'y'),
          );
          final person = await fx.person(c.family);
          await endpoints.story.linkPerson(by(c.author), draft.id, person.id!);
          await settle();
          expect(family, isEmpty);
        },
      );

      test(
        'when a published story is updated or tagged then a story event is '
        'posted on the family and story channels',
        () async {
          final story = await c.published();
          final family = liveEvents(fx.s, familyChannel(c.family.id!));
          final onStory = liveEvents(fx.s, storyChannel(story.id!));
          await endpoints.story.updateDraft(
            by(c.owner),
            story.id!,
            write(title: 'x'),
          );
          final person = await fx.person(c.family);
          await endpoints.story.linkPerson(by(c.author), story.id!, person.id!);
          await settle();
          expect(family, hasLength(2));
          expect(onStory, hasLength(2));
          final event = family.first;
          expect(event.familyId, c.family.id);
          expect(event.storyId, story.id);
          expect(event.kind, LiveKind.story);
          expect(event.storyStatus, StoryStatus.published);
          expect(event.deleted, isFalse);
        },
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
