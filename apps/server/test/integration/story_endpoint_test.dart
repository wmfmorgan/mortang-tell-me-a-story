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
          expect(
            (dto.dateStart, dto.dateEnd, dto.datePrecision),
            (
              null,
              null,
              null,
            ),
          );
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
              write(title: 'x'),
              allowUndated: false,
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
            write(dateStart: DateTime.utc(1950, 6, 3)),
            allowUndated: false,
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
              ),
              allowUndated: false,
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
              ),
              allowUndated: false,
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
            endpoints.story.createDraft(
              by(c.stranger),
              c.family.id!,
              input,
              allowUndated: false,
            ),
            throwsAppError(AppErrorCode.forbidden, 'member only'),
          );
          await fx.softDelete(c.family);
          await expectLater(
            endpoints.story.createDraft(
              by(c.member),
              c.family.id!,
              input,
              allowUndated: false,
            ),
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
            id: id,
            allowUndated: false,
          );
          final again = await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            write(title: 'Second', dateStart: DateTime.utc(1950)),
            id: id,
            allowUndated: false,
          );
          expect(again.id, id);
          expect(again.title, 'Second');
          expect(await Story.db.count(fx.s, where: (t) => t.id.equals(id)), 1);
        },
      );

      test(
        'when two creates with the same id race then one draft exists',
        () async {
          final id = newId();
          final input = write(title: 'Twice', dateStart: DateTime.utc(1950));
          final results = await Future.wait([
            endpoints.story.createDraft(
              by(c.author),
              c.family.id!,
              input,
              id: id,
              allowUndated: false,
            ),
            endpoints.story.createDraft(
              by(c.author),
              c.family.id!,
              input,
              id: id,
              allowUndated: false,
            ),
          ]);
          expect(results.map((d) => d.id).toSet(), {id});
          expect(await Story.db.count(fx.s, where: (t) => t.id.equals(id)), 1);
        },
      );

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
            id: id,
            allowUndated: false,
          );
          await expectLater(
            endpoints.story.createDraft(
              by(c.member),
              c.family.id!,
              write(title: 'Theirs', dateStart: DateTime.utc(1950)),
              id: id,
              allowUndated: false,
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
            ),
            allowUndated: false,
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
            ),
            allowUndated: false,
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
          expect(
            (await Story.db.findById(fx.s, published.id!))!.title,
            'A story',
          );
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

      test(
        'when linking the same person twice then there is one tag',
        () async {
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
        },
      );

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
            write(dateStart: DateTime.utc(1950)),
            allowUndated: false,
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

    group('publish', () {
      // BR 63
      test(
        'when a dateless draft is published then VALIDATION "date required"; '
        'with dates set it publishes',
        () async {
          final ready = await c.ready();
          final draft = await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            write(
              title: ready.title,
              body: ready.body,
              placeId: ready.placeId,
              personIds: ready.personIds,
            ),
            allowUndated: true,
          );
          await expectLater(
            endpoints.story.publish(by(c.author), draft.id),
            throwsAppError(AppErrorCode.validation, 'date required'),
          );
          await endpoints.story.updateDraft(
            by(c.author),
            draft.id,
            write(
              dateStart: DateTime.utc(1950),
              datePrecision: DatePrecision.year,
            ),
          );
          final dto = await endpoints.story.publish(by(c.author), draft.id);
          expect(dto.status, StoryStatus.published);
          expect(dto.publishedAt, isNotNull);
        },
      );

      test(
        'when a draft misses a title, body or person then VALIDATION names '
        'what is missing',
        () async {
          final ready = await c.ready();
          final cases = {
            'title required': write(title: ' '),
            'body required': write(body: ''),
            'person required': write(personIds: []),
          };
          for (final MapEntry(key: message, value: gap) in cases.entries) {
            final draft = await endpoints.story.createDraft(
              by(c.author),
              c.family.id!,
              ready,
              allowUndated: false,
            );
            await endpoints.story.updateDraft(by(c.author), draft.id, gap);
            await expectLater(
              endpoints.story.publish(by(c.author), draft.id),
              throwsAppError(AppErrorCode.validation, message),
            );
          }
        },
      );

      test('when a draft has no place then it still publishes', () async {
        final draft = await endpoints.story.createDraft(
          by(c.author),
          c.family.id!,
          await c.ready(),
          allowUndated: false,
        );
        await endpoints.story.updateDraft(
          by(c.author),
          draft.id,
          write(clearPlace: true),
        );
        final dto = await endpoints.story.publish(by(c.author), draft.id);
        expect(dto.status, StoryStatus.published);
        expect(dto.placeId, isNull);
      });

      // BR 72
      test(
        'when an owner publishes the author\'s story then FORBIDDEN "field is '
        'locked"; the owner cannot publish a draft they cannot see',
        () async {
          final published = await c.published();
          await expectLater(
            endpoints.story.publish(by(c.owner), published.id!),
            throwsAppError(AppErrorCode.forbidden, 'field is locked'),
          );
          final draft = await c.draft();
          await expectLater(
            endpoints.story.publish(by(c.owner), draft.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
          expect(
            (await Story.db.findById(fx.s, draft.id!))!.status,
            StoryStatus.draft,
          );
        },
      );

      test(
        'when the story is published then one story event with status '
        'published is posted; publishing again posts nothing',
        () async {
          final draft = await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            await c.ready(),
            allowUndated: false,
          );
          final family = liveEvents(fx.s, familyChannel(c.family.id!));
          final first = await endpoints.story.publish(by(c.author), draft.id);
          final again = await endpoints.story.publish(by(c.author), draft.id);
          await settle();
          expect(again.publishedAt, first.publishedAt);
          expect(family, hasLength(1));
          expect(family.single.kind, LiveKind.story);
          expect(family.single.storyId, draft.id);
          expect(family.single.storyStatus, StoryStatus.published);
        },
      );
    });

    group('reading', () {
      // BR 68 (story part)
      test(
        'when a draft exists then only its author reads it; members, '
        'stewards and tree readers do not',
        () async {
          final draft = await c.draft();
          final branch = await c.branch();
          expect(
            (await endpoints.story.get(by(c.author), draft.id!)).id,
            draft.id,
          );
          for (final user in [c.member, c.owner, c.coOwner, branch.member]) {
            await expectLater(
              endpoints.story.get(by(user), draft.id!),
              throwsAppError(AppErrorCode.notFound, 'story'),
            );
          }
          expect(
            await endpoints.story.getPublished(by(c.author), draft.id!),
            isNull,
          );
          expect(
            (await endpoints.story.listMyDrafts(
              by(c.author),
              c.family.id!,
            )).map((s) => s.id),
            [draft.id],
          );
          expect(
            await endpoints.story.listMyDrafts(by(c.owner), c.family.id!),
            isEmpty,
          );
          expect(
            await endpoints.story.listPublished(by(c.author), c.family.id!),
            isEmpty,
          );
        },
      );

      // BR 70
      test(
        'when the author publishes then members, stewards and tree readers '
        'read the story with its tags and place',
        () async {
          final draft = await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            await c.ready(),
            allowUndated: false,
          );
          await endpoints.story.publish(by(c.author), draft.id);
          final branch = await c.branch();
          for (final user in [c.member, c.owner, c.coOwner, branch.member]) {
            final dto = await endpoints.story.get(by(user), draft.id);
            expect(dto.people, hasLength(1));
            expect(dto.placeLabel, 'Home');
            expect(
              await endpoints.story.getPublished(by(user), draft.id),
              isNotNull,
            );
            expect(
              (await endpoints.story.listPublished(
                by(user),
                c.family.id!,
              )).map((s) => s.id),
              [draft.id],
            );
          }
        },
      );

      // BR 26 (story part)
      test(
        'when a parent member reads a child family then they see its '
        'published story with tags and place, not its drafts',
        () async {
          final branch = await c.branch();
          final kid = await fx.person(branch.family, name: 'Kid');
          final place = await fx.place(c.tree);
          final story = await fx.story(
            branch.family,
            authorId: branch.member,
            placeId: place.id,
          );
          await fx.tag(story, kid);
          final draft = await fx.story(
            branch.family,
            authorId: branch.member,
            status: StoryStatus.draft,
          );
          final list = await endpoints.story.listPublished(
            by(c.member),
            branch.family.id!,
          );
          expect(list.map((s) => s.id), [story.id]);
          expect(list.single.people.map((p) => p.name), ['Kid']);
          expect(list.single.placeLabel, 'Home');
          await expectLater(
            endpoints.story.get(by(c.member), draft.id!),
            throwsAppError(AppErrorCode.notFound, 'story'),
          );
        },
      );

      // BR 28 (story part)
      test(
        'when a stranger reads a child published story then it is refused',
        () async {
          final branch = await c.branch();
          final story = await fx.story(branch.family, authorId: branch.member);
          await expectLater(
            endpoints.story.get(by(c.stranger), story.id!),
            throwsAppError(AppErrorCode.notFound, 'story'),
          );
          expect(
            await endpoints.story.getPublished(by(c.stranger), story.id!),
            isNull,
          );
          await expectLater(
            endpoints.story.listPublished(by(c.stranger), branch.family.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
        },
      );

      // BR 74 (stories)
      test(
        'when a member of family A reads family B then they see none of B\'s '
        'stories',
        () async {
          final b = await Clan.of(fx);
          final story = await b.published();
          await expectLater(
            endpoints.story.get(by(c.member), story.id!),
            throwsAppError(AppErrorCode.notFound, 'story'),
          );
          await expectLater(
            endpoints.story.listPublished(by(c.member), b.family.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.story.listLatestPublished(
              by(c.member),
              b.family.id!,
              withinDays: 7,
              limit: 3,
            ),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.story.listMyDrafts(by(c.member), b.family.id!),
            throwsAppError(AppErrorCode.forbidden, 'member only'),
          );
        },
      );

      // BR 67
      test(
        'when stories share a start then they are ordered year, month, day, '
        'then createdAt',
        () async {
          Future<Story> at(DatePrecision precision, DateTime end, int minute) =>
              Story.db.insertRow(
                fx.s,
                Story(
                  familyId: c.family.id!,
                  treeId: c.tree.id!,
                  authorId: c.author,
                  status: StoryStatus.published,
                  dateStart: DateTime.utc(1950),
                  dateEnd: end,
                  datePrecision: precision,
                  publishedAt: DateTime.now().toUtc(),
                  createdAt: DateTime.utc(2026, 1, 1, 0, minute),
                ),
              );
          final day = await at(DatePrecision.day, DateTime.utc(1950), 1);
          final month = await at(
            DatePrecision.month,
            DateTime.utc(1950, 1, 31),
            2,
          );
          final yearLater = await at(
            DatePrecision.year,
            DateTime.utc(1950, 12, 31),
            4,
          );
          final year = await at(
            DatePrecision.year,
            DateTime.utc(1950, 12, 31),
            3,
          );
          final list = await endpoints.story.listPublished(
            by(c.member),
            c.family.id!,
          );
          expect(list.map((s) => s.id), [
            year.id,
            yearLater.id,
            month.id,
            day.id,
          ]);
        },
      );

      test(
        'when listing the latest then published stories inside the window '
        'come newest first, at most limit',
        () async {
          Future<Story> publishedDaysAgo(int days) async {
            final story = await c.published();
            return Story.db.updateRow(
              fx.s,
              story.copyWith(
                publishedAt: DateTime.now().toUtc().subtract(
                  Duration(days: days, minutes: 1),
                ),
              ),
            );
          }

          final one = await publishedDaysAgo(1);
          final two = await publishedDaysAgo(2);
          final three = await publishedDaysAgo(3);
          await publishedDaysAgo(10);
          await c.draft();
          expect(
            (await endpoints.story.listLatestPublished(
              by(c.member),
              c.family.id!,
              withinDays: 7,
              limit: 3,
            )).map((s) => s.id),
            [one.id, two.id, three.id],
          );
          expect(
            (await endpoints.story.listLatestPublished(
              by(c.member),
              c.family.id!,
              withinDays: 30,
              limit: 2,
            )).map((s) => s.id),
            [one.id, two.id],
          );
        },
      );

      test(
        'when listing a person\'s stories then published stories tagging '
        'them across the tree come oldest first',
        () async {
          final person = await fx.person(c.family);
          final branch = await c.branch();
          final gone = await c.branch();
          final s1950 = await c.published();
          final s1940 = await Story.db.insertRow(
            fx.s,
            Story(
              familyId: branch.family.id!,
              treeId: c.tree.id!,
              authorId: branch.member,
              status: StoryStatus.published,
              dateStart: DateTime.utc(1940),
              dateEnd: DateTime.utc(1940, 12, 31),
              datePrecision: DatePrecision.year,
              publishedAt: DateTime.now().toUtc(),
            ),
          );
          final draft = await c.draft();
          final hidden = await fx.story(gone.family, authorId: gone.member);
          await fx.softDelete(gone.family);
          await c.published();
          for (final story in [s1950, s1940, draft, hidden]) {
            await fx.tag(story, person);
          }
          expect(
            (await endpoints.story.listForPerson(
              by(c.member),
              person.id!,
            )).map((s) => s.id),
            [s1940.id, s1950.id],
          );
          await expectLater(
            endpoints.story.listForPerson(by(c.stranger), person.id!),
            throwsAppError(AppErrorCode.notFound, 'person'),
          );
        },
      );

      test('when the story is missing then getPublished is null', () async {
        expect(
          await endpoints.story.getPublished(by(c.member), newId()),
          isNull,
        );
      });

      // D6b
      test(
        'when the story\'s family is soft-deleted then its former members '
        'read nothing: stories, drafts, search, facets and notes',
        () async {
          final published = await c.published();
          final draft = await c.draft();
          await fx.note(published, c.member);
          await fx.softDelete(c.family);
          for (final user in [c.author, c.member, c.owner]) {
            for (final story in [published, draft]) {
              await expectLater(
                endpoints.story.get(by(user), story.id!),
                throwsAppError(AppErrorCode.notFound, 'story'),
              );
            }
            await expectLater(
              endpoints.story.listPublished(by(user), c.family.id!),
              throwsAppError(AppErrorCode.forbidden),
            );
            await expectLater(
              endpoints.story.listMyDrafts(by(user), c.family.id!),
              throwsAppError(AppErrorCode.forbidden, 'member only'),
            );
            await expectLater(
              endpoints.story.search(
                by(user),
                StorySearchDto(
                  familyId: c.family.id!,
                  text: '',
                  personIds: [],
                  decades: [],
                  sort: SearchSort.relevant,
                ),
              ),
              throwsAppError(AppErrorCode.forbidden),
            );
            await expectLater(
              endpoints.story.facets(by(user), c.family.id!),
              throwsAppError(AppErrorCode.forbidden),
            );
            await expectLater(
              endpoints.note.listForStory(by(user), published.id!),
              throwsAppError(AppErrorCode.notFound, 'story'),
            );
          }
        },
      );
    });

    group('tree timeline', () {
      /// A story in [family] starting on [start] at [precision].
      Future<Story> storyAt(
        Family family,
        DateTime start, {
        DatePrecision precision = DatePrecision.year,
        StoryStatus status = StoryStatus.published,
        UuidValue? authorId,
        DateTime? createdAt,
      }) {
        final dates = normalizeStoryDates(start, null, precision);
        return Story.db.insertRow(
          fx.s,
          Story(
            familyId: family.id!,
            treeId: family.treeId,
            authorId: authorId,
            title: 'A story',
            status: status,
            dateStart: dates.start,
            dateEnd: dates.end,
            datePrecision: dates.precision,
            publishedAt: status == StoryStatus.published
                ? DateTime.now().toUtc()
                : null,
            createdAt: createdAt,
          ),
        );
      }

      Future<Family> child(Family parent, {String name = 'Branch'}) =>
          fx.family(c.tree, parentId: parent.id, branchYear: 1980, name: name);

      Future<List<UuidValue>> treeIds(UuidValue user, Family family) async => [
        for (final story in await endpoints.story.listPublishedInTree(
          by(user),
          family.id!,
        ))
          story.id,
      ];

      test(
        'when a branch member reads the tree then parent, sibling, child and '
        'own stories come interleaved in timeline order, without drafts or '
        'another tree',
        () async {
          final b1 = await c.branch();
          final b2 = await child(c.family, name: 'Sibling');
          final grandchild = await child(b1.family, name: 'Grandchild');
          final r1960 = await storyAt(c.family, DateTime.utc(1960));
          final b1y1940 = await storyAt(b1.family, DateTime.utc(1940));
          final b2y1950 = await storyAt(b2, DateTime.utc(1950));
          final cy1970 = await storyAt(grandchild, DateTime.utc(1970));
          final r1930 = await storyAt(c.family, DateTime.utc(1930));
          await storyAt(
            c.family,
            DateTime.utc(1945),
            status: StoryStatus.draft,
            authorId: c.author,
          );
          await storyAt(
            b1.family,
            DateTime.utc(1955),
            status: StoryStatus.draft,
            authorId: b1.member,
          );
          final other = await Clan.of(fx);
          await other.published();

          expect(await treeIds(b1.member, b1.family), [
            r1930.id,
            b1y1940.id,
            b2y1950.id,
            r1960.id,
            cy1970.id,
          ]);
          expect(
            (await endpoints.story.listPublishedInTree(
              by(b1.member),
              b1.family.id!,
            )).map((s) => s.familyId),
            [c.family.id, b1.family.id, b2.id, c.family.id, grandchild.id],
          );
          // Any live family of the tree names the same timeline.
          expect(
            await treeIds(c.member, c.family),
            await treeIds(b1.member, b1.family),
          );
        },
      );

      // D6b, D8
      test(
        'when a middle family is soft-deleted then its stories are absent and '
        'its parent and child still read each other',
        () async {
          final middle = await c.branch();
          final grandchild = await child(middle.family, name: 'Grandchild');
          final reader = await fx.user();
          await fx.join(grandchild, reader);
          final root = await storyAt(c.family, DateTime.utc(1930));
          await storyAt(middle.family, DateTime.utc(1940));
          final leaf = await storyAt(grandchild, DateTime.utc(1950));
          await fx.softDelete(middle.family);

          expect(await treeIds(c.member, c.family), [root.id, leaf.id]);
          expect(await treeIds(reader, grandchild), [root.id, leaf.id]);
        },
      );

      // BR 67 across families
      test(
        'when stories in different families share a start then the order is '
        'timelineOrder over the union of every family\'s published list',
        () async {
          final branch = await c.branch();
          final start = DateTime.utc(1950);
          final day = await storyAt(
            branch.family,
            start,
            precision: DatePrecision.day,
            createdAt: DateTime.utc(2026, 1, 1, 0, 1),
          );
          final month = await storyAt(
            c.family,
            start,
            precision: DatePrecision.month,
            createdAt: DateTime.utc(2026, 1, 1, 0, 2),
          );
          final yearLater = await storyAt(
            c.family,
            start,
            createdAt: DateTime.utc(2026, 1, 1, 0, 4),
          );
          final year = await storyAt(
            branch.family,
            start,
            createdAt: DateTime.utc(2026, 1, 1, 0, 3),
          );

          expect(await treeIds(c.member, c.family), [
            year.id,
            yearLater.id,
            month.id,
            day.id,
          ]);
          // timelineOrder: dateStart, datePrecision, createdAt, id.
          int timelineOrder(StoryDto a, StoryDto b) {
            for (final order in [
              a.dateStart!.compareTo(b.dateStart!),
              a.datePrecision!.index.compareTo(b.datePrecision!.index),
              a.createdAt.compareTo(b.createdAt),
            ]) {
              if (order != 0) return order;
            }
            return a.id.uuid.compareTo(b.id.uuid);
          }

          final union = [
            ...await endpoints.story.listPublished(by(c.member), c.family.id!),
            ...await endpoints.story.listPublished(
              by(c.member),
              branch.family.id!,
            ),
          ]..sort(timelineOrder);
          expect(
            await treeIds(c.member, c.family),
            union.map((s) => s.id).toList(),
          );
        },
      );

      test(
        'when a stranger, another tree\'s member or a member of a '
        'soft-deleted family reads the tree then FORBIDDEN',
        () async {
          final other = await Clan.of(fx);
          for (final user in [c.stranger, other.member]) {
            await expectLater(
              endpoints.story.listPublishedInTree(by(user), c.family.id!),
              throwsAppError(AppErrorCode.forbidden),
            );
          }
          await fx.softDelete(c.family);
          await expectLater(
            endpoints.story.listPublishedInTree(by(c.owner), c.family.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
        },
      );

      // D6b: tree reads need the caller's own family to be live too.
      test(
        'when a member whose only family is soft-deleted reads a live family '
        'of the same tree then FORBIDDEN',
        () async {
          final middle = await c.branch();
          await fx.story(c.family);
          await fx.softDelete(middle.family);

          await expectLater(
            endpoints.story.listPublishedInTree(
              by(middle.member),
              c.family.id!,
            ),
            throwsAppError(AppErrorCode.forbidden),
          );
        },
      );

      test('when an anonymous caller reads the tree then refused', () async {
        await expectLater(
          endpoints.story.listPublishedInTree(sessionBuilder, c.family.id!),
          throwsA(isA<ServerpodUnauthenticatedException>()),
        );
      });

      test('the tree order index leads with treeId', () async {
        final rows = await fx.s.db.unsafeQuery(
          "SELECT indexdef FROM pg_indexes WHERE indexname = "
          "'stories_tree_order_idx'",
        );
        expect(
          rows.single.single,
          contains(
            '("treeId", status, "dateStart", "datePrecision", "createdAt", id)',
          ),
        );
      });
    });

    group('discard', () {
      test(
        'when the author discards a story then it, its photos, notes and tags '
        'are gone and both photo keys are queued',
        () async {
          final story = await c.draft();
          final plain = await fx.photo(story);
          final edited = await fx.photo(
            story,
            sortOrder: 1,
            editedKey: 'families/x/edited-1.jpg',
          );
          await fx.note(story, c.author);
          await fx.tag(story, await fx.person(c.family));
          await endpoints.story.discard(by(c.author), story.id!);
          expect(await Story.db.findById(fx.s, story.id!), isNull);
          expect(
            await Photo.db.count(
              fx.s,
              where: (t) => t.storyId.equals(story.id!),
            ),
            0,
          );
          expect(
            await StoryNote.db.count(
              fx.s,
              where: (t) => t.storyId.equals(story.id!),
            ),
            0,
          );
          final queued = await BlobDeletion.db.find(
            fx.s,
            where: (t) => t.key.inSet({
              plain.originalKey,
              edited.originalKey,
              edited.editedKey!,
            }),
          );
          expect(queued, hasLength(3));
        },
      );

      // D4
      test(
        'when an owner discards another member\'s story then FORBIDDEN and it '
        'remains',
        () async {
          final story = await c.published();
          for (final user in [c.owner, c.coOwner, c.member]) {
            await expectLater(
              endpoints.story.discard(by(user), story.id!),
              throwsAppError(AppErrorCode.forbidden),
            );
          }
          expect(await Story.db.findById(fx.s, story.id!), isNotNull);
        },
      );

      // BR 137 (story part)
      test(
        'when its author discards a story in a soft-deleted family then '
        'FORBIDDEN and nothing changes',
        () async {
          final story = await c.published();
          final photo = await fx.photo(story);
          await fx.softDelete(c.family);
          await expectLater(
            endpoints.story.discard(by(c.author), story.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
          expect(await Story.db.findById(fx.s, story.id!), isNotNull);
          expect(
            await BlobDeletion.db.count(
              fx.s,
              where: (t) => t.key.equals(photo.originalKey),
            ),
            0,
          );
        },
      );

      test(
        'when a published story is discarded then a deleted story event is '
        'posted; discarding a draft posts nothing',
        () async {
          final published = await c.published();
          final draft = await c.draft();
          final family = liveEvents(fx.s, familyChannel(c.family.id!));
          await endpoints.story.discard(by(c.author), draft.id!);
          await endpoints.story.discard(by(c.author), published.id!);
          await settle();
          expect(family, hasLength(1));
          expect(family.single.storyId, published.id);
          expect(family.single.kind, LiveKind.story);
          expect(family.single.deleted, isTrue);
        },
      );
    });

    group('search', () {
      StorySearchDto query(
        UuidValue familyId, {
        String text = '',
        List<UuidValue> personIds = const [],
        UuidValue? placeId,
        DateTime? rangeStart,
        DateTime? rangeEnd,
        List<int> decades = const [],
        SearchSort sort = SearchSort.relevant,
      }) => StorySearchDto(
        familyId: familyId,
        text: text,
        personIds: personIds,
        placeId: placeId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        decades: decades,
        sort: sort,
      );

      Future<Story> dated(
        int year, {
        String? title,
        String? body,
        UuidValue? placeId,
        DateTime? publishedAt,
        StoryStatus status = StoryStatus.published,
      }) => Story.db.insertRow(
        fx.s,
        Story(
          familyId: c.family.id!,
          treeId: c.tree.id!,
          authorId: c.author,
          title: title,
          body: body,
          status: status,
          dateStart: DateTime.utc(year),
          dateEnd: DateTime.utc(year, 12, 31),
          datePrecision: DatePrecision.year,
          placeId: placeId,
          publishedAt: status == StoryStatus.published
              ? publishedAt ?? DateTime.now().toUtc()
              : null,
        ),
      );

      Future<List<UuidValue?>> ids(StorySearchDto q, [UuidValue? user]) async =>
          (await endpoints.story.search(
            by(user ?? c.member),
            q,
          )).map((s) => s.id).toList();

      test(
        'when text matches then title ranks over person and place, which '
        'rank over body and year',
        () async {
          final harbor = await Place.db.insertRow(
            fx.s,
            Place(
              treeId: c.tree.id!,
              label: 'Harbor House',
              address: '1 Main St',
              lat: 0,
              lng: 0,
            ),
          );
          final byTitle = await dated(1950, title: 'Harbor days');
          final byPlace = await dated(1960, placeId: harbor.id);
          final byPerson = await dated(1970);
          await fx.tag(byPerson, await fx.person(c.family, name: 'Ann HARBOR'));
          final byBody = await dated(1980, body: 'by the harbor');
          await dated(1990, title: 'Nothing here');
          expect(await ids(query(c.family.id!, text: ' harbor ')), [
            byTitle.id,
            byPerson.id,
            byPlace.id,
            byBody.id,
          ]);
        },
      );

      test(
        'when text is a year or a decade label then it matches, for any decade',
        () async {
          final old = await dated(1855);
          await dated(1950);
          for (final text in ['1850s', '1855', '185']) {
            expect(await ids(query(c.family.id!, text: text)), [old.id]);
          }
        },
      );

      test('when text holds % or _ then they match literally', () async {
        final percent = await dated(1950, title: '100% true');
        await dated(1950, title: '100 true');
        expect(await ids(query(c.family.id!, text: '0%')), [percent.id]);
        expect(await ids(query(c.family.id!, text: '_')), isEmpty);
      });

      test(
        'when people, a place, decades or a range are given then they filter',
        () async {
          final a = await fx.person(c.family, name: 'A');
          final b = await fx.person(c.family, name: 'B');
          final place = await fx.place(c.tree);
          final both = await dated(1950, placeId: place.id);
          final onlyA = await dated(1962);
          await fx.tag(both, a);
          await fx.tag(both, b);
          await fx.tag(onlyA, a);
          expect(
            await ids(query(c.family.id!, personIds: [a.id!, b.id!, a.id!])),
            [both.id],
          );
          expect(
            await ids(query(c.family.id!, personIds: [a.id!])),
            [onlyA.id, both.id],
          );
          expect(await ids(query(c.family.id!, placeId: place.id)), [both.id]);
          expect(
            await ids(
              query(
                c.family.id!,
                decades: [1960],
                rangeStart: DateTime.utc(1950),
                rangeEnd: DateTime.utc(1950, 12, 31),
              ),
            ),
            [onlyA.id],
          );
          expect(
            await ids(
              query(
                c.family.id!,
                rangeStart: DateTime.utc(1950, 6),
                rangeEnd: DateTime.utc(1951),
              ),
            ),
            [both.id],
          );
          expect(
            await ids(query(c.family.id!, rangeStart: DateTime.utc(1951))),
            [onlyA.id, both.id],
          );
        },
      );

      test(
        'when sorting chronologically then the newest timeframe comes first; '
        'recentlyAdded orders by publishedAt',
        () async {
          final now = DateTime.now().toUtc();
          final old = await dated(1900, publishedAt: now);
          final mid = await dated(
            1950,
            publishedAt: now.subtract(const Duration(days: 2)),
          );
          final recent = await dated(
            2000,
            publishedAt: now.subtract(const Duration(days: 1)),
          );
          expect(
            await ids(query(c.family.id!, sort: SearchSort.chronological)),
            [recent.id, mid.id, old.id],
          );
          expect(
            await ids(query(c.family.id!, sort: SearchSort.recentlyAdded)),
            [old.id, recent.id, mid.id],
          );
        },
      );

      test(
        'when searching then drafts and other families are excluded, tree '
        'readers may search, and strangers are FORBIDDEN',
        () async {
          final story = await dated(1950, title: 'Mine');
          await dated(1951, title: 'Mine draft', status: StoryStatus.draft);
          final other = await Clan.of(fx);
          await fx.story(other.family, authorId: other.author);
          final branch = await c.branch();
          expect(await ids(query(c.family.id!, text: 'mine')), [story.id]);
          expect(
            await ids(query(c.family.id!), branch.member),
            [story.id],
          );
          await expectLater(
            endpoints.story.search(by(c.stranger), query(c.family.id!)),
            throwsAppError(AppErrorCode.forbidden),
          );
        },
      );

      test(
        'when listing facets then decades ascend and people and places are '
        'counted over published stories only',
        () async {
          final branch = await c.branch();
          final zed = await fx.person(branch.family, name: 'Zed');
          final amy = await fx.person(c.family, name: 'Amy');
          final place = await fx.place(c.tree);
          final s1950 = await dated(1950, placeId: place.id);
          final s1955 = await dated(1955);
          await dated(1880);
          final draft = await dated(1990, status: StoryStatus.draft);
          await fx.tag(s1950, zed);
          await fx.tag(s1955, zed);
          await fx.tag(s1955, amy);
          await fx.tag(draft, amy);
          final facets = await endpoints.story.facets(
            by(c.member),
            c.family.id!,
          );
          expect(facets.decades.map((d) => (d.decade, d.storyCount)), [
            (1880, 1),
            (1950, 2),
          ]);
          expect(facets.people.map((p) => (p.personId, p.name, p.storyCount)), [
            (amy.id, 'Amy', 1),
            (zed.id, 'Zed', 2),
          ]);
          expect(facets.places.map((p) => (p.placeId, p.label, p.storyCount)), [
            (place.id, 'Home', 1),
          ]);
          await expectLater(
            endpoints.story.facets(by(c.stranger), c.family.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
        },
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
