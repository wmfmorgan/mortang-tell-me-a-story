import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';
import '../people/person_rules.dart';

/// People are tree-scoped: reads and unlinked edits need a live membership
/// somewhere in the person's tree (`Authz.isTreeMemberOf(person.treeId)`).
/// Steward-only actions (mark passed away, delete) check the live home family.
class PeopleEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// People whose home is [familyId], by name. The family must be live and
  /// in the caller's tree.
  Future<List<PersonDto>> listFamily(
    Session session,
    UuidValue familyId,
  ) async {
    final authz = Authz(session);
    if (!await authz.isTreeReadable(familyId)) throw forbidden();
    final people = await Person.db.find(
      session,
      where: (t) => t.homeFamilyId.equals(familyId),
      orderByList: (t) => [t.name.asc(), t.id.asc()],
    );
    return _toDtos(session, authz, people);
  }

  /// Every person in [familyId]'s tree, by name, in one call. Linked people
  /// carry their account birth, coarsened for everyone but themselves.
  Future<List<PersonDto>> listTree(Session session, UuidValue familyId) async {
    final authz = Authz(session);
    final family = await _readableFamily(authz, familyId);
    if (family == null) throw forbidden();
    final people = await Person.db.find(
      session,
      where: (t) => t.treeId.equals(family.treeId),
      orderByList: (t) => [t.name.asc(), t.id.asc()],
    );
    return _toDtos(session, authz, people);
  }

  /// The person row for the edit dialog, including `userId` and `email`, for
  /// any tree member; null when missing or outside the caller's trees.
  Future<PersonDto?> forEdit(Session session, UuidValue personId) async {
    final authz = Authz(session);
    final person = await _readablePerson(authz, personId);
    if (person == null) return null;
    return (await _toDtos(session, authz, [person])).single;
  }

  /// The profile dialog (old `person_profile`). Never carries `userId` or
  /// `email`. A linked account's about and avatar win when set; its birth is
  /// coarsened by `birthVisibility` for everyone but the linked self.
  Future<PersonProfileDto> profile(Session session, UuidValue personId) async {
    final authz = Authz(session);
    final person = await _readablePerson(authz, personId);
    if (person == null) throw notFound('person not found');
    final account = await _account(session, person.userId);
    final birth = _birth(person, account, authz.userId);
    return PersonProfileDto(
      id: person.id!,
      homeFamilyId: person.homeFamilyId,
      name: person.name,
      isLinked: person.userId != null,
      birthDate: birth.date,
      birthPrecision: birth.precision,
      deathDate: person.deathDate,
      deathPrecision: person.deathPrecision,
      about: account?.about ?? person.about,
      avatarKey: account?.avatarKey ?? person.avatarKey,
      passedAway: person.passedAway,
    );
  }

  /// [familyId] when it is live and in one of the caller's trees.
  Future<Family?> _readableFamily(Authz authz, UuidValue familyId) async {
    final family = await Family.db.findById(authz.session, familyId);
    if (family == null || family.deletedAt != null) return null;
    if (!await authz.isTreeMemberOf(family.treeId)) return null;
    return family;
  }

  /// [personId] when it exists and the caller is a member of its tree.
  Future<Person?> _readablePerson(Authz authz, UuidValue personId) async {
    final person = await Person.db.findById(authz.session, personId);
    if (person == null || !await authz.isTreeMemberOf(person.treeId)) {
      return null;
    }
    return person;
  }

  Future<AppUser?> _account(Session session, UuidValue? userId) =>
      userId == null
      ? Future.value()
      : AppUser.db.findFirstRow(
          session,
          where: (t) => t.authUserId.equals(userId),
        );

  /// The linked account's birth (coarsened unless [caller] is the linked
  /// self), else the person row's own birth.
  LifeDate _birth(Person person, AppUser? account, UuidValue? caller) =>
      person.userId == null
      ? (date: person.birthDate, precision: person.birthPrecision)
      : shownBirth(account, self: person.userId == caller);

  /// [people] as DTOs, loading every linked account in one query.
  Future<List<PersonDto>> _toDtos(
    Session session,
    Authz authz,
    List<Person> people,
  ) async {
    final userIds = {
      for (final p in people)
        if (p.userId != null) p.userId!,
    };
    final accounts = userIds.isEmpty
        ? const <UuidValue, AppUser>{}
        : {
            for (final a in await AppUser.db.find(
              session,
              where: (t) => t.authUserId.inSet(userIds),
            ))
              a.authUserId: a,
          };
    return [
      for (final p in people)
        _toDto(p, _birth(p, accounts[p.userId], authz.userId)),
    ];
  }

  PersonDto _toDto(Person p, LifeDate birth) => PersonDto(
    id: p.id!,
    treeId: p.treeId,
    homeFamilyId: p.homeFamilyId,
    name: p.name,
    email: p.email,
    about: p.about,
    avatarKey: p.avatarKey,
    userId: p.userId,
    passedAway: p.passedAway,
    birthDate: birth.date,
    birthPrecision: birth.precision,
    deathDate: p.deathDate,
    deathPrecision: p.deathPrecision,
  );
}
