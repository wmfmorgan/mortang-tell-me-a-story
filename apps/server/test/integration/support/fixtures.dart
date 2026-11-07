import 'dart:math';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import '../test_tools/serverpod_test_tools.dart';

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

/// Throws an [AppException] with [code] and, when given, exactly [message].
Matcher throwsAppError(AppErrorCode code, [String? message]) {
  var m = isA<AppException>().having((e) => e.code, 'code', code);
  if (message != null) {
    m = m.having((e) => e.message, 'message', message);
  }
  return throwsA(m);
}

/// A session authenticated as [user], or anonymous when [user] is null.
Session sessionFor(TestSessionBuilder sessionBuilder, UuidValue? user) =>
    asUser(sessionBuilder, user).build();

/// [sessionBuilder] authenticated as [user], or anonymous when [user] is null.
/// Pass the result to `endpoints.<name>.<method>(...)`.
TestSessionBuilder asUser(TestSessionBuilder sessionBuilder, UuidValue? user) =>
    user == null
    ? sessionBuilder
    : sessionBuilder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(
          user.uuid,
          {},
        ),
      );

final _random = Random.secure();

/// A well-formed, unique token hash (invites_token_hash_uidx is global).
String tokenHash() =>
    List.generate(64, (_) => _random.nextInt(16).toRadixString(16)).join();

/// Row builders. Every test makes its own users and trees, so tests stay
/// independent on the shared (non-rolled-back) test database.
class Fx {
  Fx(this.s);

  final Session s;

  /// A new auth user. `configureAuth` must have run (its hook creates the
  /// matching `users` row).
  Future<UuidValue> user() async =>
      (await AuthServices.instance.authUsers.create(s)).id;

  /// A new auth user with an email login, as the email-code sign-up leaves
  /// it, and optionally a display name on the app's `users` row.
  Future<UuidValue> userWithEmail(String email, {String? displayName}) async {
    final id = await user();
    await EmailAccount.db.insertRow(
      s,
      EmailAccount(authUserId: id, email: email, passwordHash: ''),
    );
    if (displayName != null) {
      final appUser = await AppUser.db.findFirstRow(
        s,
        where: (t) => t.authUserId.equals(id),
      );
      await AppUser.db.updateRow(
        s,
        appUser!.copyWith(displayName: displayName),
      );
    }
    return id;
  }

  Future<Membership> join(
    Family family,
    UuidValue user, [
    MembershipRole role = MembershipRole.member,
  ]) => Membership.db.insertRow(
    s,
    Membership(familyId: family.id!, userId: user, role: role),
  );

  Future<Tree> tree() => Tree.db.insertRow(s, Tree());

  Future<Family> family(
    Tree tree, {
    UuidValue? parentId,
    int? branchYear,
    String name = 'Mortang',
    DateTime? deletedAt,
  }) => Family.db.insertRow(
    s,
    Family(
      treeId: tree.id!,
      parentId: parentId,
      name: name,
      branchYear: branchYear,
      deletedAt: deletedAt,
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

  /// A year-precision story in 1950, published unless [status] says otherwise.
  Future<Story> story(
    Family family, {
    UuidValue? treeId,
    UuidValue? placeId,
    UuidValue? authorId,
    StoryStatus status = StoryStatus.published,
  }) => Story.db.insertRow(
    s,
    Story(
      familyId: family.id!,
      treeId: treeId ?? family.treeId,
      authorId: authorId,
      title: 'A story',
      status: status,
      dateStart: DateTime.utc(1950),
      dateEnd: DateTime.utc(1950, 12, 31),
      datePrecision: DatePrecision.year,
      placeId: placeId,
      publishedAt: status == StoryStatus.published
          ? DateTime.now().toUtc()
          : null,
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
