import 'dart:typed_data';

import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/domain/compressed_photo.dart';
import 'package:tell_me_a_story/core/data/server/server_errors.dart';
import 'package:tell_me_a_story/core/data/server/wire.dart';
import 'package:tell_me_a_story/core/domain/people_repository.dart';
import 'package:tell_me_a_story/core/domain/person.dart';
import 'package:tell_me_a_story/core/domain/person_profile.dart';

Person personFromDto(server.PersonDto dto) => Person(
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

PersonProfile personProfileFromDto(server.PersonProfileDto dto) =>
    PersonProfile(
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

String? _precision(server.DatePrecision? precision) =>
    precision == null ? null : precisionName(precision);

/// People of a family tree through the `people` endpoint; pictures through
/// `media`.
class ServerPeopleRepository implements PeopleRepository {
  ServerPeopleRepository({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  @override
  Future<List<Person>> listPeople(String familyId) async {
    final rows = await withServerErrors(
      () => _client.people.listFamily(_uuid(familyId)),
    );
    return rows.map(personFromDto).toList();
  }

  @override
  Future<List<Person>> listTreePeople(String familyId) async {
    final rows = await withServerErrors(
      () => _client.people.listTree(_uuid(familyId)),
    );
    return rows.map(personFromDto).toList();
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
    return personFromDto(row);
  }

  @override
  Future<Person?> personForEdit(String personId) async {
    final row = await withServerErrors(
      () => _client.people.forEdit(_uuid(personId)),
    );
    return row == null ? null : personFromDto(row);
  }

  @override
  Future<PersonProfile?> personProfile(String personId) async {
    final row = await withServerErrors(
      () => _client.people.profile(_uuid(personId)),
    );
    return personProfileFromDto(row);
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
    return personFromDto(row);
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
    return rows.map(personFromDto).toList();
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
