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
    _checkLinkedWrite(person, uid, input);
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
        _checkLinkedWrite(current, uid, input);
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

  /// A linked row is written only by its linked self, keeping the account's
  /// name and leaving passed-away and death to stewards. Run on the read row
  /// (so a refused write stores no picture) and again on the locked row, so
  /// a person linked meanwhile is not edited by someone else.
  void _checkLinkedWrite(
    Person person,
    UuidValue caller,
    PersonWriteDto input,
  ) {
    final linkedId = person.userId;
    if (linkedId == null) return;
    if (linkedId != caller) throw forbidden();
    if (input.name.trim() != person.name) {
      throw forbidden('linked_person_name_locked');
    }
    if (input.writePassedAway &&
        (input.passedAway ?? false) != person.passedAway) {
      throw forbidden();
    }
    if (input.writeDeath) throw forbidden();
  }

  /// The invite picker: people in [familyId]'s tree who are unlinked, not
  /// passed away, and have no pending invite (not accepted, not revoked,
  /// unexpired), by name.
  Future<List<PersonDto>> listUnlinked(
    Session session,
    UuidValue familyId,
  ) async {
    final authz = Authz(session);
    final family = await _readableFamily(authz, familyId);
    if (family == null) throw notFound('family not found');
    final people = await Person.db.find(
      session,
      where: (t) =>
          t.treeId.equals(family.treeId) &
          t.userId.equals(null) &
          t.passedAway.equals(false),
      orderByList: (t) => [t.name.asc(), t.id.asc()],
    );
    if (people.isEmpty) return const [];
    final invited = await Invite.db.find(
      session,
      where: (t) =>
          t.personId.inSet(people.map((p) => p.id!).toSet()) &
          t.acceptedAt.equals(null) &
          t.revokedAt.equals(null) &
          (t.expiresAt > DateTime.now().toUtc()),
    );
    final pending = invited.map((i) => i.personId).toSet();
    return _toDtos(session, authz, [
      for (final p in people)
        if (!pending.contains(p.id)) p,
    ]);
  }

  /// Whether the caller is an owner or co-owner of live [familyId].
  Future<bool> isHomeFamilySteward(Session session, UuidValue familyId) =>
      Authz(session).isLiveSteward(familyId);

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

  /// Sets or clears a passed linked person's death date. Owner of the live
  /// home family only, never the person themselves (decision 2026-11-07;
  /// co-owners may toggle the flag but not the date). Same check order as
  /// [markPassedAway]. Unlinked people's death dates go through [update].
  Future<void> setDeathDate(
    Session session,
    UuidValue personId,
    DateTime? deathDate,
    DatePrecision? deathPrecision,
  ) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    final person = await _readablePerson(authz, personId);
    if (person == null) throw notFound('person not found');
    if (person.userId == null) throw validation('person has not signed in');
    if (person.userId == uid) throw validation('cannot mark yourself');
    await authz.requireLiveOwner(person.homeFamilyId);
    final death = normalizeLifeDate('death', deathDate, deathPrecision);
    await session.db.transaction((t) async {
      final current = await Person.db.findById(
        session,
        personId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      );
      if (current == null) throw notFound('person not found');
      if (current.userId == null) {
        throw validation('person has not signed in');
      }
      if (death.date != null && !current.passedAway) {
        throw validation('death date needs passed away');
      }
      final birth = current.birthDate;
      if (birth != null &&
          death.date != null &&
          death.date!.year < birth.year) {
        throw validation('death is before birth');
      }
      await Person.db.updateRow(
        session,
        current.copyWith(
          deathDate: death.date,
          deathPrecision: death.precision,
          updatedAt: DateTime.now().toUtc(),
        ),
        transaction: t,
      );
    });
  }

  /// Deletes an unlinked person (D5): owner or co-owner of the live home
  /// family only. Tags and kinships cascade; invites keep a null person. The
  /// avatar key is queued for deletion in the same transaction.
  Future<void> delete(Session session, UuidValue personId) async {
    final authz = Authz(session);
    final person = await Person.db.findById(session, personId);
    if (person == null) throw forbidden('owner or co-owner only');
    await authz.requireLiveSteward(person.homeFamilyId);
    if (person.userId != null) {
      throw validation('person is linked to an account');
    }
    await session.db.transaction((t) async {
      final current = await Person.db.findById(
        session,
        personId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      );
      if (current == null) return;
      if (current.userId != null) {
        throw validation('person is linked to an account');
      }
      await queueBlobDeletions(session, [current.avatarKey], transaction: t);
      await Person.db.deleteRow(session, current, transaction: t);
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
