import 'dart:math';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/db/constraints.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// Postgres error with [code] (SQLSTATE), raised by [constraint] when given.
Matcher pgError(String code, [String? constraint]) {
  var m = isA<DatabaseQueryException>().having((e) => e.code, 'code', code);
  if (constraint != null) {
    m = m.having((e) => e.constraintName, 'constraintName', constraint);
  }
  return m;
}

const fkViolation = '23503';
const checkViolation = '23514';
const uniqueViolation = '23505';

final _random = Random.secure();

/// A well-formed, unique token hash (invites_token_hash_uidx is global).
String tokenHash() =>
    List.generate(64, (_) => _random.nextInt(16).toRadixString(16)).join();

/// Row builders. Every test makes its own trees, so tests stay independent
/// on the shared (non-rolled-back) test database.
class Fx {
  Fx(this.s);

  final Session s;

  Future<Tree> tree() => Tree.db.insertRow(s, Tree());

  Future<Family> family(
    Tree tree, {
    UuidValue? parentId,
    int? branchYear,
    String name = 'Mortang',
  }) => Family.db.insertRow(
    s,
    Family(
      treeId: tree.id!,
      parentId: parentId,
      name: name,
      branchYear: branchYear,
    ),
  );

  Future<Person> person(
    Family home, {
    UuidValue? treeId,
    UuidValue? userId,
    String name = 'Ada',
    DateTime? birthDate,
    DatePrecision? birthPrecision,
    DateTime? deathDate,
    DatePrecision? deathPrecision,
    bool passedAway = false,
  }) => Person.db.insertRow(
    s,
    Person(
      treeId: treeId ?? home.treeId,
      homeFamilyId: home.id!,
      userId: userId,
      name: name,
      birthDate: birthDate,
      birthPrecision: birthPrecision,
      deathDate: deathDate,
      deathPrecision: deathPrecision,
      passedAway: passedAway,
    ),
  );

  Future<Place> place(Tree tree, {String? mapboxPlaceId}) => Place.db.insertRow(
    s,
    Place(
      treeId: tree.id!,
      label: 'Home',
      address: '1 Main St',
      lat: 1,
      lng: 2,
      mapboxPlaceId: mapboxPlaceId,
    ),
  );

  /// A published, year-precision story in 1950.
  Future<Story> story(
    Family family, {
    UuidValue? treeId,
    UuidValue? placeId,
    UuidValue? authorId,
  }) => Story.db.insertRow(
    s,
    Story(
      familyId: family.id!,
      treeId: treeId ?? family.treeId,
      authorId: authorId,
      title: 'A story',
      status: StoryStatus.published,
      dateStart: DateTime.utc(1950),
      dateEnd: DateTime.utc(1950, 12, 31),
      datePrecision: DatePrecision.year,
      placeId: placeId,
      publishedAt: DateTime.now().toUtc(),
    ),
  );

  Future<StoryPerson> tag(Story story, Person person) =>
      StoryPerson.db.insertRow(
        s,
        StoryPerson(
          storyId: story.id!,
          personId: person.id!,
          treeId: story.treeId,
        ),
      );

  Future<Kinship> kinship(
    Person from,
    Person to, {
    KinshipKind kind = KinshipKind.parentOf,
    UuidValue? createdById,
  }) => Kinship.db.insertRow(
    s,
    Kinship(
      treeId: from.treeId,
      kind: kind,
      fromPersonId: from.id!,
      toPersonId: to.id!,
      createdById: createdById,
    ),
  );

  Future<Invite> invite(Family family, {UuidValue? personId}) =>
      Invite.db.insertRow(
        s,
        Invite(
          familyId: family.id!,
          treeId: family.treeId,
          personId: personId,
          tokenHash: tokenHash(),
          expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
        ),
      );

  /// Two people in one tree, ordered so `first.id < second.id` as Postgres
  /// compares uuids (byte order, which matches the canonical string order).
  Future<(Person, Person)> orderedPair(Family home) async {
    final a = await person(home, name: 'A');
    final b = await person(home, name: 'B');
    return a.id!.uuid.compareTo(b.id!.uuid) < 0 ? (a, b) : (b, a);
  }

  Future<bool> constraintExists(String name) async {
    final rows = await s.db.unsafeQuery(
      "SELECT 1 FROM pg_constraint WHERE conname = '$name'",
    );
    return rows.isNotEmpty;
  }
}

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given the raw SQL constraints', (sessionBuilder, endpoints) {
    late Session session;
    late Fx fx;

    setUp(() async {
      session = sessionBuilder.build();
      fx = Fx(session);
      await session.db.unsafeSimpleExecute(constraintsSql);
    });

    test(
      'when a second owner is added to a family then the insert fails',
      () async {
        final a = await AuthServices.instance.authUsers.create(session);
        final b = await AuthServices.instance.authUsers.create(session);
        final family = await fx.family(await fx.tree());
        await Membership.db.insertRow(
          session,
          Membership(
            familyId: family.id!,
            userId: a.id,
            role: MembershipRole.owner,
          ),
        );

        await expectLater(
          Membership.db.insertRow(
            session,
            Membership(
              familyId: family.id!,
              userId: b.id,
              role: MembershipRole.owner,
            ),
          ),
          throwsA(pgError(uniqueViolation, 'memberships_one_owner_uidx')),
        );
      },
    );

    test(
      'when the constraints run twice then the second run succeeds',
      () async {
        await session.db.unsafeSimpleExecute(constraintsSql);
      },
    );

    test(
      'when a database still has a replaced constraint name then the run drops it',
      () async {
        await session.db.unsafeSimpleExecute(
          'ALTER TABLE users ADD CONSTRAINT users_birth_midnight '
          'CHECK ("birthDate" IS NULL)',
        );
        await session.db.unsafeSimpleExecute(
          'ALTER TABLE families ADD CONSTRAINT families_branch_year_range '
          'CHECK ("branchYear" IS NULL OR "branchYear" BETWEEN 1 AND 9999)',
        );

        await session.db.unsafeSimpleExecute(constraintsSql);

        expect(await fx.constraintExists('users_birth_midnight'), isFalse);
        expect(
          await fx.constraintExists('families_branch_year_range'),
          isFalse,
        );
        expect(await fx.constraintExists('users_birth_shape'), isTrue);
        expect(
          await fx.constraintExists('families_branch_year_1000_9999'),
          isTrue,
        );
      },
    );

    group('same-tree composite FKs', () {
      test('a story whose place is in another tree is rejected', () async {
        final family = await fx.family(await fx.tree());
        final foreign = await fx.place(await fx.tree());

        await expectLater(
          fx.story(family, placeId: foreign.id),
          throwsA(pgError(fkViolation, 'stories_place_tree_fk')),
        );
      });

      test('a story whose treeId is not its family tree is rejected', () async {
        final family = await fx.family(await fx.tree());
        final other = await fx.tree();

        await expectLater(
          fx.story(family, treeId: other.id),
          throwsA(pgError(fkViolation, 'stories_family_tree_fk')),
        );
      });

      test('tagging a person from another tree is rejected', () async {
        final story = await fx.story(await fx.family(await fx.tree()));
        final stranger = await fx.person(await fx.family(await fx.tree()));

        await expectLater(
          fx.tag(story, stranger),
          throwsA(pgError(fkViolation, 'story_people_person_tree_fk')),
        );
      });

      test('an invite for a person in another tree is rejected', () async {
        final family = await fx.family(await fx.tree());
        final stranger = await fx.person(await fx.family(await fx.tree()));

        await expectLater(
          fx.invite(family, personId: stranger.id),
          throwsA(pgError(fkViolation, 'invites_person_tree_fk')),
        );
      });

      test('an origin story from another tree is rejected', () async {
        final family = await fx.family(await fx.tree());
        final foreign = await fx.story(await fx.family(await fx.tree()));

        await expectLater(
          Family.db.updateRow(
            session,
            family.copyWith(originStoryId: foreign.id),
          ),
          throwsA(pgError(fkViolation, 'families_origin_tree_fk')),
        );
      });

      test('a kinship across trees is rejected', () async {
        final mine = await fx.person(await fx.family(await fx.tree()));
        final stranger = await fx.person(await fx.family(await fx.tree()));

        await expectLater(
          fx.kinship(mine, stranger),
          throwsA(pgError(fkViolation, 'kinships_to_tree_fk')),
        );
      });

      test(
        'a person whose home family is in another tree is rejected',
        () async {
          final home = await fx.family(await fx.tree());
          final other = await fx.tree();

          await expectLater(
            fx.person(home, treeId: other.id),
            throwsA(pgError(fkViolation, 'people_home_family_tree_fk')),
          );
        },
      );

      test('a branch whose parent is in another tree is rejected', () async {
        final foreignParent = await fx.family(await fx.tree());

        await expectLater(
          fx.family(await fx.tree(), parentId: foreignParent.id),
          throwsA(pgError(fkViolation, 'families_parent_same_tree_fk')),
        );
      });

      test(
        'one place serves stories in two families of one tree, and a person '
        'from a sibling family can be tagged',
        () async {
          final tree = await fx.tree();
          final root = await fx.family(tree);
          final branch = await fx.family(tree, parentId: root.id);
          final place = await fx.place(tree);
          final rootStory = await fx.story(root, placeId: place.id);
          final branchStory = await fx.story(branch, placeId: place.id);
          final rootPerson = await fx.person(root);

          final tag = await fx.tag(branchStory, rootPerson);

          expect(rootStory.placeId, place.id);
          expect(tag.treeId, tree.id);
        },
      );
    });

    group('kinships', () {
      test('a kinship to oneself is rejected', () async {
        final p = await fx.person(await fx.family(await fx.tree()));

        await expectLater(
          fx.kinship(p, p),
          throwsA(pgError(checkViolation, 'kinships_not_self')),
        );
      });

      test('partnerOf stored with the larger id first is rejected', () async {
        final (low, high) = await fx.orderedPair(
          await fx.family(await fx.tree()),
        );

        await expectLater(
          fx.kinship(high, low, kind: KinshipKind.partnerOf),
          throwsA(pgError(checkViolation, 'kinships_partner_canonical')),
        );
      });

      test('a duplicate kinship is rejected', () async {
        final (a, b) = await fx.orderedPair(await fx.family(await fx.tree()));
        await fx.kinship(a, b);

        await expectLater(
          fx.kinship(a, b),
          throwsA(pgError(uniqueViolation, 'kinships_from_to_kind_uidx')),
        );
      });

      test('an unknown kind is rejected', () async {
        final (a, b) = await fx.orderedPair(await fx.family(await fx.tree()));
        final k = await fx.kinship(a, b);

        await expectLater(
          session.db.unsafeExecute(
            "UPDATE kinships SET kind = 'siblingOf' WHERE id = '${k.id}'",
          ),
          throwsA(pgError(checkViolation, 'kinships_kind_valid')),
        );
      });

      test(
        'parentOf plus canonical partnerOf on one pair is accepted',
        () async {
          final (low, high) = await fx.orderedPair(
            await fx.family(await fx.tree()),
          );

          await fx.kinship(high, low);
          await fx.kinship(low, high, kind: KinshipKind.partnerOf);

          final edges = await Kinship.db.find(
            session,
            where: (t) => t.treeId.equals(low.treeId),
          );
          expect(edges, hasLength(2));
        },
      );
    });

    group('life dates', () {
      Future<Family> family() async => fx.family(await fx.tree());

      test('a death date without passedAway is rejected', () async {
        await expectLater(
          fx.person(
            await family(),
            deathDate: DateTime.utc(1990),
            deathPrecision: DatePrecision.year,
          ),
          throwsA(pgError(checkViolation, 'people_death_needs_passed_away')),
        );
      });

      test('a death year before the birth year is rejected', () async {
        await expectLater(
          fx.person(
            await family(),
            birthDate: DateTime.utc(1950),
            birthPrecision: DatePrecision.year,
            deathDate: DateTime.utc(1949, 6, 1),
            deathPrecision: DatePrecision.month,
            passedAway: true,
          ),
          throwsA(pgError(checkViolation, 'people_death_after_birth')),
        );
      });

      test(
        'a day-precision death in a year-precision birth year is accepted',
        () async {
          final p = await fx.person(
            await family(),
            birthDate: DateTime.utc(1950),
            birthPrecision: DatePrecision.year,
            deathDate: DateTime.utc(1950, 3, 4),
            deathPrecision: DatePrecision.day,
            passedAway: true,
          );

          expect(p.deathDate, DateTime.utc(1950, 3, 4));
        },
      );

      test('a month-precision birth on the 15th is rejected', () async {
        await expectLater(
          fx.person(
            await family(),
            birthDate: DateTime.utc(1950, 3, 15),
            birthPrecision: DatePrecision.month,
          ),
          throwsA(pgError(checkViolation, 'people_birth_shape')),
        );
      });

      test('a birth date with a time of day is rejected', () async {
        await expectLater(
          fx.person(
            await family(),
            birthDate: DateTime.utc(1950, 3, 15, 12),
            birthPrecision: DatePrecision.day,
          ),
          throwsA(pgError(checkViolation, 'people_birth_shape')),
        );
      });

      test('a birth date without a precision is rejected', () async {
        await expectLater(
          fx.person(await family(), birthDate: DateTime.utc(1950)),
          throwsA(pgError(checkViolation, 'people_birth_pair')),
        );
      });

      test('a death precision without a date is rejected', () async {
        await expectLater(
          fx.person(
            await family(),
            deathPrecision: DatePrecision.year,
            passedAway: true,
          ),
          throwsA(pgError(checkViolation, 'people_death_pair')),
        );
      });

      test('a year-precision death not on Jan 1 is rejected', () async {
        await expectLater(
          fx.person(
            await family(),
            deathDate: DateTime.utc(1990, 2),
            deathPrecision: DatePrecision.year,
            passedAway: true,
          ),
          throwsA(pgError(checkViolation, 'people_death_shape')),
        );
      });

      test(
        'an account birth on the 15th at month precision is rejected',
        () async {
          final user = await AuthServices.instance.authUsers.create(session);

          await expectLater(
            AppUser.db.insertRow(
              session,
              AppUser(
                authUserId: user.id,
                birthDate: DateTime.utc(1950, 3, 15),
                birthPrecision: DatePrecision.month,
              ),
            ),
            throwsA(pgError(checkViolation, 'users_birth_shape')),
          );
        },
      );

      test('an unknown birthVisibility is rejected', () async {
        final user = await AuthServices.instance.authUsers.create(session);

        await expectLater(
          session.db.unsafeExecute(
            "UPDATE users SET \"birthVisibility\" = 'bogus' "
            "WHERE \"authUserId\" = '${user.id}'",
          ),
          throwsA(pgError(checkViolation, 'users_birth_visibility_valid')),
        );
      });
    });

    group('families', () {
      test('a branchYear of 999 is rejected', () async {
        await expectLater(
          fx.family(await fx.tree(), branchYear: 999),
          throwsA(pgError(checkViolation, 'families_branch_year_1000_9999')),
        );
      });

      test('a blank family name is rejected', () async {
        await expectLater(
          fx.family(await fx.tree(), name: '  '),
          throwsA(pgError(checkViolation, 'families_name_not_blank')),
        );
      });

      test("deleting a family that is a person's home is refused", () async {
        final family = await fx.family(await fx.tree());
        await fx.person(family);

        await expectLater(
          Family.db.deleteRow(session, family),
          // Postgres reports ON DELETE RESTRICT as a plain FK violation.
          throwsA(pgError(fkViolation)),
        );
      });
    });

    group('places', () {
      test('a duplicate Mapbox place in one tree is rejected', () async {
        final tree = await fx.tree();
        await fx.place(tree, mapboxPlaceId: 'mb.1');

        await expectLater(
          fx.place(tree, mapboxPlaceId: 'mb.1'),
          throwsA(pgError(uniqueViolation, 'places_tree_mapbox_uidx')),
        );
      });

      test('the same Mapbox place in two trees is accepted', () async {
        await fx.place(await fx.tree(), mapboxPlaceId: 'mb.2');
        await fx.place(await fx.tree(), mapboxPlaceId: 'mb.2');
      });

      test(
        'deleting a place nulls the story place and keeps family and tree',
        () async {
          final tree = await fx.tree();
          final family = await fx.family(tree);
          final place = await fx.place(tree);
          final story = await fx.story(family, placeId: place.id);

          await Place.db.deleteRow(session, place);

          final after = await Story.db.findById(session, story.id!);
          expect(after!.placeId, isNull);
          expect(after.familyId, family.id);
          expect(after.treeId, tree.id);
        },
      );
    });

    group('carried-over checks', () {
      test('a blank person name is rejected', () async {
        await expectLater(
          fx.person(await fx.family(await fx.tree()), name: ' '),
          throwsA(pgError(checkViolation, 'people_name_not_blank')),
        );
      });

      test('the same account linked twice in one tree is rejected', () async {
        final user = await AuthServices.instance.authUsers.create(session);
        final family = await fx.family(await fx.tree());
        await fx.person(family, userId: user.id);

        await expectLater(
          fx.person(family, userId: user.id),
          throwsA(pgError(uniqueViolation, 'people_tree_user_uidx')),
        );
      });

      test('an unnormalized person email is rejected', () async {
        final family = await fx.family(await fx.tree());

        await expectLater(
          Person.db.insertRow(
            session,
            Person(
              treeId: family.treeId,
              homeFamilyId: family.id!,
              name: 'Ada',
              email: ' Ada@Example.com',
            ),
          ),
          throwsA(pgError(checkViolation, 'people_email_normalized')),
        );
      });

      test('story date shapes are enforced', () async {
        final family = await fx.family(await fx.tree());
        Story draft({
          DateTime? start,
          DateTime? end,
          DatePrecision? precision,
        }) => Story(
          familyId: family.id!,
          treeId: family.treeId,
          dateStart: start,
          dateEnd: end,
          datePrecision: precision,
        );

        // Month precision with the wrong month end.
        await expectLater(
          Story.db.insertRow(
            session,
            draft(
              start: DateTime.utc(1950, 2),
              end: DateTime.utc(1950, 2, 27),
              precision: DatePrecision.month,
            ),
          ),
          throwsA(pgError(checkViolation, 'stories_date_shape')),
        );
        // Partially null dates.
        await expectLater(
          Story.db.insertRow(session, draft(start: DateTime.utc(1950))),
          throwsA(pgError(checkViolation, 'stories_date_shape')),
        );
        // Year 999.
        await expectLater(
          Story.db.insertRow(
            session,
            draft(
              start: DateTime.utc(999),
              end: DateTime.utc(999, 12, 31),
              precision: DatePrecision.year,
            ),
          ),
          throwsA(pgError(checkViolation, 'stories_date_shape')),
        );
        // Time of day.
        await expectLater(
          Story.db.insertRow(
            session,
            draft(
              start: DateTime.utc(1950, 1, 1, 9),
              end: DateTime.utc(1950, 1, 1, 9),
              precision: DatePrecision.day,
            ),
          ),
          throwsA(pgError(checkViolation, 'stories_date_shape')),
        );
        // Undated but published.
        await expectLater(
          Story.db.insertRow(
            session,
            draft().copyWith(
              status: StoryStatus.published,
              publishedAt: DateTime.now().toUtc(),
            ),
          ),
          throwsA(pgError(checkViolation, 'stories_published_needs_date')),
        );
      });

      test(
        'a co-owner, two unlinked people in one tree, an undated draft and '
        'valid day, month and year spans are accepted',
        () async {
          final owner = await AuthServices.instance.authUsers.create(session);
          final coOwner = await AuthServices.instance.authUsers.create(session);
          final family = await fx.family(await fx.tree());
          for (final (user, role) in [
            (owner, MembershipRole.owner),
            (coOwner, MembershipRole.coOwner),
          ]) {
            await Membership.db.insertRow(
              session,
              Membership(familyId: family.id!, userId: user.id, role: role),
            );
          }
          await fx.person(family, name: 'Unlinked one');
          await fx.person(family, name: 'Unlinked two');

          for (final (start, end, precision) in [
            (null, null, null),
            (
              DateTime.utc(1984, 2, 29),
              DateTime.utc(1984, 2, 29),
              DatePrecision.day,
            ),
            (
              DateTime.utc(1984, 2),
              DateTime.utc(1984, 2, 29),
              DatePrecision.month,
            ),
            (
              DateTime.utc(1984),
              DateTime.utc(1984, 12, 31),
              DatePrecision.year,
            ),
          ]) {
            await Story.db.insertRow(
              session,
              Story(
                familyId: family.id!,
                treeId: family.treeId,
                dateStart: start,
                dateEnd: end,
                datePrecision: precision,
              ),
            );
          }

          expect(
            await Story.db.count(
              session,
              where: (t) => t.familyId.equals(family.id),
            ),
            4,
          );
        },
      );

      test(
        'deleting the accepting account nulls acceptedById and keeps the invite',
        () async {
          final user = await AuthServices.instance.authUsers.create(session);
          final family = await fx.family(await fx.tree());
          final invite = await fx.invite(family);
          await Invite.db.updateRow(
            session,
            invite.copyWith(
              acceptedById: user.id,
              acceptedAt: DateTime.now().toUtc(),
            ),
          );

          await AuthServices.instance.authUsers.delete(
            session,
            authUserId: user.id,
          );

          final after = await Invite.db.findById(session, invite.id!);
          expect(after!.acceptedById, isNull);
          expect(after.acceptedAt, isNotNull);
        },
      );

      test('a raw invite token instead of a hash is rejected', () async {
        final family = await fx.family(await fx.tree());

        await expectLater(
          Invite.db.insertRow(
            session,
            Invite(
              familyId: family.id!,
              treeId: family.treeId,
              tokenHash: 'raw-token',
              expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
            ),
          ),
          throwsA(pgError(checkViolation, 'invites_token_hash_shape')),
        );
      });

      test(
        'an invite whose treeId is not its family tree is rejected',
        () async {
          final family = await fx.family(await fx.tree());
          final other = await fx.tree();

          await expectLater(
            Invite.db.insertRow(
              session,
              Invite(
                familyId: family.id!,
                treeId: other.id!,
                tokenHash: tokenHash(),
                expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
              ),
            ),
            throwsA(pgError(fkViolation, 'invites_family_tree_fk')),
          );
        },
      );
    });

    group('deletes', () {
      test(
        'deleting a person removes their tags and kinships and unlinks invites',
        () async {
          final family = await fx.family(await fx.tree());
          final (a, b) = await fx.orderedPair(family);
          final story = await fx.story(family);
          await fx.tag(story, a);
          await fx.kinship(a, b);
          final invite = await fx.invite(family, personId: a.id);

          await Person.db.deleteRow(session, a);

          expect(
            await StoryPerson.db.count(
              session,
              where: (t) => t.personId.equals(a.id),
            ),
            0,
          );
          expect(
            await Kinship.db.count(
              session,
              where: (t) => t.fromPersonId.equals(a.id),
            ),
            0,
          );
          final after = await Invite.db.findById(session, invite.id!);
          expect(after!.personId, isNull);
          expect(after.treeId, family.treeId);
        },
      );

      test(
        'purging a non-last family keeps its people under a sibling and nulls '
        'origins that pointed at its stories',
        () async {
          final tree = await fx.tree();
          final root = await fx.family(tree);
          final branch = await fx.family(tree, parentId: root.id);
          final rootStory = await fx.story(root);
          await Family.db.updateRow(
            session,
            root.copyWith(originStoryId: rootStory.id),
          );
          await Family.db.updateRow(
            session,
            branch.copyWith(originStoryId: rootStory.id),
          );
          final person = await fx.person(root);

          await session.db.transaction((tx) async {
            await Person.db.updateRow(
              session,
              person.copyWith(homeFamilyId: branch.id),
              transaction: tx,
            );
            await Family.db.deleteWhere(
              session,
              where: (t) => t.id.equals(root.id),
              transaction: tx,
            );
          });

          final survivor = await Person.db.findById(session, person.id!);
          expect(survivor!.homeFamilyId, branch.id);
          expect(await Story.db.findById(session, rootStory.id!), isNull);
          final orphan = await Family.db.findById(session, branch.id!);
          expect(orphan!.originStoryId, isNull);
          expect(orphan.parentId, isNull);
        },
      );

      test('purging the last family removes the tree and its places', () async {
        final tree = await fx.tree();
        final family = await fx.family(tree);
        final place = await fx.place(tree);
        final (a, b) = await fx.orderedPair(family);
        final story = await fx.story(family, placeId: place.id);
        await fx.tag(story, a);
        await fx.kinship(a, b);
        await fx.invite(family, personId: b.id);

        await session.db.transaction((tx) async {
          await Person.db.deleteWhere(
            session,
            where: (t) => t.treeId.equals(tree.id),
            transaction: tx,
          );
          await Family.db.deleteRow(session, family, transaction: tx);
          await Tree.db.deleteRow(session, tree, transaction: tx);
        });

        expect(
          await Place.db.count(session, where: (t) => t.treeId.equals(tree.id)),
          0,
        );
        expect(await Story.db.findById(session, story.id!), isNull);
      });

      test(
        'deleting an account nulls its person link, authorship and kinship '
        'creator',
        () async {
          final user = await AuthServices.instance.authUsers.create(session);
          final family = await fx.family(await fx.tree());
          final linked = await fx.person(family, userId: user.id);
          final other = await fx.person(family, name: 'Other');
          final story = await fx.story(family, authorId: user.id);
          final edge = await fx.kinship(linked, other, createdById: user.id);

          await AuthServices.instance.authUsers.delete(
            session,
            authUserId: user.id,
          );

          expect(
            (await Person.db.findById(session, linked.id!))!.userId,
            isNull,
          );
          expect(
            (await Story.db.findById(session, story.id!))!.authorId,
            isNull,
          );
          expect(
            (await Kinship.db.findById(session, edge.id!))!.createdById,
            isNull,
          );
        },
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
