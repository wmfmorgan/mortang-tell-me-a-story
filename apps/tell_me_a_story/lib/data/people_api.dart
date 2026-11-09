import 'dart:typed_data';

import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/server/server_errors.dart';
import 'package:tell_me_a_story/data/server/wire.dart';

/// A person in a family tree. [familyId] is the person's home family;
/// [avatarPath] is the picture's blob key.
class Person {
  const Person({
    required this.id,
    required this.familyId,
    required this.name,
    this.email,
    this.birthDate,
    this.birthPrecision,
    this.passingDate,
    this.passingPrecision,
    this.about,
    this.avatarPath,
    this.userId,
    this.passedAway = false,
  });

  final String id;
  final String familyId;
  final String name;
  final String? email;
  final DateTime? birthDate;
  final String? birthPrecision;
  final DateTime? passingDate;
  final String? passingPrecision;
  final String? about;
  final String? avatarPath;
  final String? userId;
  final bool passedAway;

  factory Person.fromDto(server.PersonDto dto) => Person(
    id: dto.id.toString(),
    familyId: dto.homeFamilyId.toString(),
    name: dto.name,
    email: dto.email,
    birthDate: fromWireDate(dto.birthDate),
    birthPrecision: _precision(dto.birthPrecision),
    passingDate: fromWireDate(dto.deathDate),
    passingPrecision: _precision(dto.deathPrecision),
    about: dto.about,
    avatarPath: dto.avatarKey,
    userId: dto.userId?.toString(),
    passedAway: dto.passedAway,
  );
}

/// What the profile dialog shows. Never includes userId or email.
class PersonProfile {
  const PersonProfile({
    required this.id,
    required this.familyId,
    required this.name,
    required this.isLinked,
    this.birthDate,
    this.birthPrecision,
    this.about,
    this.avatarPath,
    this.passingDate,
    this.passingPrecision,
    this.passedAway = false,
  });

  final String id;
  final String familyId;
  final String name;
  final DateTime? birthDate;
  final String? birthPrecision;
  final String? about;
  final String? avatarPath;
  final DateTime? passingDate;
  final String? passingPrecision;
  final bool passedAway;
  final bool isLinked;

  factory PersonProfile.fromDto(server.PersonProfileDto dto) => PersonProfile(
    id: dto.id.toString(),
    familyId: dto.homeFamilyId.toString(),
    name: dto.name,
    isLinked: dto.isLinked,
    birthDate: fromWireDate(dto.birthDate),
    birthPrecision: _precision(dto.birthPrecision),
    about: dto.about,
    avatarPath: dto.avatarKey,
    passingDate: fromWireDate(dto.deathDate),
    passingPrecision: _precision(dto.deathPrecision),
    passedAway: dto.passedAway,
  );
}

String? _precision(server.DatePrecision? precision) =>
    precision == null ? null : precisionName(precision);

/// Year → YYYY-01-01, month → YYYY-MM-01, day → that date. Never a range.
({DateTime date, String precision}) storedPersonDate({
  required int year,
  int? month,
  int? day,
}) {
  if (month != null && day != null) {
    return (date: DateTime(year, month, day), precision: 'day');
  }
  if (month != null) {
    return (date: DateTime(year, month, 1), precision: 'month');
  }
  return (date: DateTime(year, 1, 1), precision: 'year');
}

/// Rejects an empty name, or an about longer than 500, before the network.
void ensureValidPersonCreate({required String name, String? about}) {
  if (name.trim().isEmpty) {
    throw ArgumentError.value(name, 'name', 'must not be empty');
  }
  if (about != null && about.length > 500) {
    throw ArgumentError.value(about, 'about', 'must be at most 500 characters');
  }
}

abstract class PeopleGateway {
  Future<List<Person>> listPeople(String familyId);

  /// People in [familyId]'s tree. Linked rows carry the account birth,
  /// coarsened by its visibility. The default reads [listPeople] so fakes
  /// stay unchanged.
  Future<List<Person>> listTreePeople(String familyId) => listPeople(familyId);

  Future<Person> createPerson({
    required String familyId,
    required String name,
    String? about,
    String? email,
    bool passedAway = false,
    List<int>? pictureBytes,
  });

  /// Tree-member row, including `userId` and `email`. Not [personProfile].
  Future<Person?> personForEdit(String personId) async => null;

  Future<PersonProfile?> personProfile(String personId) async => null;

  Future<Person> updatePerson({
    required String personId,
    required String name,
    bool passedAway = false,
    bool writePassedAway = false,
    String? about,
    bool writeAbout = false,
    String? email,
    bool writeEmail = false,
    List<int>? pictureBytes,
    bool clearPicture = false,
  }) async {
    throw UnimplementedError();
  }

  Future<List<Person>> listUnlinkedPeople(String familyId) async => const [];

  /// Home-family owner or co-owner. Other members, including owners of
  /// another family in the tree, are false.
  Future<bool> isHomeFamilySteward(String familyId) async => false;

  /// Sets or clears a linked person's passed-away flag (stewards only).
  Future<void> markPassedAway({required String personId, required bool value}) {
    throw UnimplementedError();
  }

  /// Picture bytes for the blob key [path] (a person's or a linked
  /// account's avatar). Null when there is no picture.
  Future<Uint8List?> pictureBytes({
    required String personId,
    String? path,
  }) async => null;
}

/// People of a family tree through the `people` endpoint; pictures through
/// `media`.
class PeopleApi implements PeopleGateway {
  PeopleApi({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  @override
  Future<List<Person>> listPeople(String familyId) async {
    final rows = await withServerErrors(
      () => _client.people.listFamily(_uuid(familyId)),
    );
    return rows.map(Person.fromDto).toList();
  }

  @override
  Future<List<Person>> listTreePeople(String familyId) async {
    final rows = await withServerErrors(
      () => _client.people.listTree(_uuid(familyId)),
    );
    return rows.map(Person.fromDto).toList();
  }

  @override
  Future<Person> createPerson({
    required String familyId,
    required String name,
    String? about,
    String? email,
    bool passedAway = false,
    List<int>? pictureBytes,
  }) async {
    final trimmedAbout = _aboutOrNull(about);
    ensureValidPersonCreate(name: name, about: trimmedAbout);
    final trimmedEmail = _emailOrNull(email);
    final input = server.PersonWriteDto(
      name: name.trim(),
      writeAbout: trimmedAbout != null,
      about: trimmedAbout,
      writeEmail: trimmedEmail != null,
      email: trimmedEmail,
      writePassedAway: true,
      passedAway: passedAway,
      writeBirth: false,
      writeDeath: false,
      clearPicture: false,
    );
    final picture = _picture(pictureBytes);
    final row = await withServerErrors(
      () => _client.people.create(_uuid(familyId), input, picture),
    );
    return Person.fromDto(row);
  }

  @override
  Future<Person?> personForEdit(String personId) async {
    final row = await withServerErrors(
      () => _client.people.forEdit(_uuid(personId)),
    );
    return row == null ? null : Person.fromDto(row);
  }

  @override
  Future<PersonProfile?> personProfile(String personId) async {
    final row = await withServerErrors(
      () => _client.people.profile(_uuid(personId)),
    );
    return PersonProfile.fromDto(row);
  }

  @override
  Future<Person> updatePerson({
    required String personId,
    required String name,
    bool passedAway = false,
    bool writePassedAway = false,
    String? about,
    bool writeAbout = false,
    String? email,
    bool writeEmail = false,
    List<int>? pictureBytes,
    bool clearPicture = false,
  }) async {
    final trimmedAbout = writeAbout ? _aboutOrNull(about) : null;
    ensureValidPersonCreate(
      name: name,
      about: writeAbout ? trimmedAbout : null,
    );
    final picture = _picture(pictureBytes);
    final input = server.PersonWriteDto(
      name: name.trim(),
      writePassedAway: writePassedAway,
      passedAway: writePassedAway ? passedAway : null,
      writeAbout: writeAbout,
      about: trimmedAbout,
      writeEmail: writeEmail,
      email: writeEmail ? _emailOrNull(email) : null,
      writeBirth: false,
      writeDeath: false,
      clearPicture: clearPicture && picture == null,
    );
    final row = await withServerErrors(
      () => _client.people.update(_uuid(personId), input, picture),
    );
    return Person.fromDto(row);
  }

  @override
  Future<bool> isHomeFamilySteward(String familyId) => withServerErrors(
    () => _client.people.isHomeFamilySteward(_uuid(familyId)),
  );

  @override
  Future<void> markPassedAway({required String personId, required bool value}) {
    return withServerErrors(
      () => _client.people.markPassedAway(_uuid(personId), value),
    );
  }

  @override
  Future<List<Person>> listUnlinkedPeople(String familyId) async {
    final rows = await withServerErrors(
      () => _client.people.listUnlinked(_uuid(familyId)),
    );
    return rows.map(Person.fromDto).toList();
  }

  @override
  Future<Uint8List?> pictureBytes({
    required String personId,
    String? path,
  }) async {
    if (path == null || path.isEmpty) return null;
    final data = await withServerErrors(() => _client.media.get(path));
    return data == null ? null : Uint8List.sublistView(data);
  }
}

/// [bytes] compressed to a 512 px JPEG, sent inline; null when empty.
ByteData? _picture(List<int>? bytes) {
  if (bytes == null || bytes.isEmpty) return null;
  final compressed = compressStoryPhoto(
    Uint8List.fromList(bytes),
    maxEdge: 512,
    quality: 80,
  );
  return ByteData.sublistView(compressed.bytes);
}

server.UuidValue _uuid(String id) => server.UuidValue.fromString(id);

String? _emailOrNull(String? email) {
  if (email == null) return null;
  final trimmed = email.trim();
  if (trimmed.isEmpty) return null;
  return trimmed;
}

String? _aboutOrNull(String? about) {
  if (about == null) return null;
  if (about.isEmpty) return null;
  return about;
}
