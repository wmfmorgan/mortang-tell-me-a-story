import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';
import '../media/blob_keys.dart';
import '../media/blob_outbox.dart';
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

  /// Adds an unlinked person with [familyId] as home. A [picture] (JPEG,
  /// ≤ 2 MiB) is stored inline under a fresh `personAvatarKey`.
  Future<PersonDto> create(
    Session session,
    UuidValue familyId,
    PersonWriteDto input,
    ByteData? picture,
  ) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    await authz.requireLiveMember(familyId);
    final family = (await Family.db.findById(session, familyId))!;
    final person = applyPersonWrite(
      Person(
        id: UuidValue.fromString(const Uuid().v7()),
        treeId: family.treeId,
        homeFamilyId: familyId,
        name: '',
        createdById: uid,
      ),
      input,
    );
    if (picture != null) _checkPicture(picture);
    final key = picture == null
        ? null
        : await _storePicture(session, person, picture);
    final Person saved;
    try {
      saved = await session.db.transaction(
        (t) => Person.db.insertRow(
          session,
          person.copyWith(avatarKey: key),
          transaction: t,
        ),
      );
    } catch (_) {
      await queueBlobDeletions(session, [key]);
      rethrow;
    }
    return (await _toDtos(session, authz, [saved])).single;
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

  /// Edits a person. Unlinked: any tree member. Linked: only the linked self,
  /// with the name locked to the account, and no passed-away or death change.
  /// A [picture] replaces the avatar; [PersonWriteDto.clearPicture] removes
  /// it. The old key is queued for deletion in the same transaction.
  Future<PersonDto> update(
    Session session,
    UuidValue personId,
    PersonWriteDto input,
    ByteData? picture,
  ) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    final person = await _readablePerson(authz, personId);
    if (person == null) throw forbidden();
    final linkedId = person.userId;
    if (linkedId != null) {
      if (linkedId != uid) throw forbidden();
      if (input.name.trim() != person.name) {
        throw forbidden('linked_person_name_locked');
      }
      if (input.writePassedAway &&
          (input.passedAway ?? false) != person.passedAway) {
        throw forbidden();
      }
      if (input.writeDeath) throw forbidden();
    }
    applyPersonWrite(person, input);
    if (picture != null) _checkPicture(picture);
    final key = picture == null
        ? null
        : await _storePicture(session, person, picture);
    final Person saved;
    try {
      saved = await session.db.transaction((t) async {
        final current = await Person.db.findById(
          session,
          personId,
          transaction: t,
          lockMode: LockMode.forUpdate,
        );
        if (current == null) throw forbidden();
        var next = applyPersonWrite(
          current,
          input,
        ).copyWith(updatedAt: DateTime.now().toUtc());
        if (key != null || input.clearPicture) {
          await queueBlobDeletions(session, [
            current.avatarKey,
          ], transaction: t);
          next = next.copyWith(avatarKey: key);
        }
        return Person.db.updateRow(session, next, transaction: t);
      });
    } catch (_) {
      await queueBlobDeletions(session, [key]);
      rethrow;
    }
    return (await _toDtos(session, authz, [saved])).single;
  }

  /// Sets or clears a linked person's passed-away flag (old
  /// `mark_passed_away`). Checks in the business-rules.md §4.3 order;
  /// clearing the flag clears the death fields.
  Future<void> markPassedAway(
    Session session,
    UuidValue personId,
    bool value,
  ) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    final person = await _readablePerson(authz, personId);
    if (person == null) throw notFound('person not found');
    if (person.userId == null) throw validation('person has not signed in');
    if (person.userId == uid) throw validation('cannot mark yourself');
    if (!await authz.isLiveSteward(person.homeFamilyId)) throw forbidden();
    await session.db.transaction((t) async {
      final current = await Person.db.findById(
        session,
        personId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      );
      if (current == null) throw notFound('person not found');
      await Person.db.updateRow(
        session,
        current.copyWith(
          passedAway: value,
          deathDate: value ? current.deathDate : null,
          deathPrecision: value ? current.deathPrecision : null,
          updatedAt: DateTime.now().toUtc(),
        ),
        transaction: t,
      );
    });
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

  /// Person avatars are JPEG only, ≤ 2 MiB (schema-design.md §4.2).
  void _checkPicture(ByteData picture) {
    if (picture.lengthInBytes > avatarMaxBytes) {
      throw validation('picture is too large');
    }
    if (sniffImageMime(picture) != 'image/jpeg') {
      throw validation('picture must be a JPEG image');
    }
  }

  Future<String> _storePicture(
    Session session,
    Person person,
    ByteData picture,
  ) async {
    final key = personAvatarKey(treeId: person.treeId, personId: person.id!);
    await session.storage.storeFile(
      storageId: blobStorageId,
      path: key,
      byteData: picture,
      options: const StoreFileOptions(preventOverwrite: true),
    );
    return key;
  }
}
